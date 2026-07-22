#!/usr/bin/env python3

import json
import os
import shlex
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Mapping, Protocol


class PluginError(RuntimeError):
    pass


class GitOutput(Protocol):
    def output(self, repo: Path, args: list[str]) -> str | None: ...


class HerdrClient(Protocol):
    def json(self, args: list[str]) -> dict: ...


@dataclass(frozen=True)
class ReviewContext:
    workspace_id: str
    pane_id: str
    cwd: Path


class SubprocessGit:
    def output(self, repo: Path, args: list[str]) -> str | None:
        result = subprocess.run(
            ["git", "-C", str(repo), *args],
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
        )
        if result.returncode != 0:
            return None
        value = result.stdout.strip()
        return value or None


def _parse_herdr_output(output: str) -> dict:
    if not output.strip():
        return {}
    for line in reversed(output.splitlines()):
        try:
            payload = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(payload, dict):
            return payload
    raise PluginError("Herdr returned invalid JSON")


class SubprocessHerdr:
    def __init__(self, executable: str):
        self.executable = executable

    def json(self, args: list[str]) -> dict:
        result = subprocess.run(
            [self.executable, *args],
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        if result.returncode != 0:
            message = result.stderr.strip() or result.stdout.strip()
            raise PluginError(message or f"Herdr command failed: {' '.join(args)}")
        return _parse_herdr_output(result.stdout)


class PaneState:
    def __init__(self, path: Path):
        self.path = path

    @staticmethod
    def _key(workspace_id: str, mode: str, placement: str) -> str:
        return f"{workspace_id}:{mode}:{placement}"

    def _read(self) -> dict[str, str]:
        try:
            payload = json.loads(self.path.read_text())
        except (FileNotFoundError, json.JSONDecodeError):
            return {}
        return payload if isinstance(payload, dict) else {}

    def get(self, workspace_id: str, mode: str, placement: str) -> str | None:
        value = self._read().get(self._key(workspace_id, mode, placement))
        return value if isinstance(value, str) else None

    def set(self, workspace_id: str, mode: str, placement: str, pane_id: str) -> None:
        payload = self._read()
        payload[self._key(workspace_id, mode, placement)] = pane_id
        self.path.parent.mkdir(parents=True, exist_ok=True)
        temporary = self.path.with_suffix(".tmp")
        temporary.write_text(json.dumps(payload, sort_keys=True) + "\n")
        os.chmod(temporary, 0o600)
        temporary.replace(self.path)

    def remove(self, workspace_id: str, mode: str, placement: str) -> None:
        payload = self._read()
        payload.pop(self._key(workspace_id, mode, placement), None)
        if not payload:
            self.path.unlink(missing_ok=True)
            return
        self.path.write_text(json.dumps(payload, sort_keys=True) + "\n")


def review_context(env: Mapping[str, str], git: GitOutput) -> ReviewContext:
    try:
        payload = json.loads(env.get("HERDR_PLUGIN_CONTEXT_JSON", "{}"))
    except json.JSONDecodeError as error:
        raise PluginError("invalid Herdr plugin context") from error

    workspace_id = payload.get("workspace_id") or env.get("HERDR_WORKSPACE_ID")
    pane_id = payload.get("focused_pane_id") or env.get("HERDR_PANE_ID")
    cwd = (
        payload.get("focused_pane_cwd")
        or payload.get("workspace_cwd")
        or env.get("PWD")
    )
    if not isinstance(workspace_id, str) or not workspace_id:
        raise PluginError("missing Herdr workspace id")
    if not isinstance(pane_id, str) or not pane_id:
        raise PluginError("missing focused Herdr pane id")
    if not isinstance(cwd, str) or not cwd:
        raise PluginError("missing focused pane cwd")

    repo = git.output(Path(cwd), ["rev-parse", "--show-toplevel"])
    if repo is None:
        raise PluginError(f"not a Git repository: {cwd}")
    return ReviewContext(workspace_id, pane_id, Path(repo))


def build_hunk_argv(mode: str, repo: Path, git: GitOutput) -> list[str]:
    if mode == "worktree":
        return ["hunk", "diff", "--watch", "--no-transparent-bg"]

    upstream = git.output(
        repo,
        ["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}"],
    )
    comparison_ref = upstream or "origin/main"
    if git.output(repo, ["rev-parse", "--verify", comparison_ref]) is None:
        raise PluginError("unable to resolve a branch comparison ref")

    return [
        "hunk",
        "diff",
        f"{comparison_ref}...HEAD",
        "--watch",
        "--no-transparent-bg",
    ]


def _pane_from(payload: object) -> str | None:
    if isinstance(payload, dict):
        pane_id = payload.get("pane_id")
        if isinstance(pane_id, str):
            return pane_id
        for value in payload.values():
            found = _pane_from(value)
            if found:
                return found
    if isinstance(payload, list):
        for value in payload:
            found = _pane_from(value)
            if found:
                return found
    return None


def _open_args(mode: str, placement: str, context: ReviewContext) -> list[str]:
    args = [
        "plugin",
        "pane",
        "open",
        "--plugin",
        "hunk-review",
        "--entrypoint",
        "review",
        "--placement",
        placement,
        "--workspace",
        context.workspace_id,
    ]
    if placement in {"split", "popup"}:
        args.extend(["--target-pane", context.pane_id])
    if placement == "split":
        args.extend(["--direction", "right"])
    args.extend(
        [
            "--cwd",
            str(context.cwd),
            "--env",
            f"HUNK_REVIEW_MODE={mode}",
            "--focus",
        ]
    )
    return args


def _run_command(mode: str, repo: Path, git: GitOutput) -> str:
    return shlex.join(["exec", *build_hunk_argv(mode, repo, git)])


def open_review(
    mode: str,
    placement: str,
    context: ReviewContext,
    herdr: HerdrClient,
    state: PaneState,
    git: GitOutput,
) -> str | None:
    if mode not in {"worktree", "branch"}:
        raise PluginError(f"unsupported review mode: {mode}")
    if placement not in {"split", "tab", "popup"}:
        raise PluginError(f"unsupported review placement: {placement}")

    if placement != "popup":
        pane_id = state.get(context.workspace_id, mode, placement)
        if pane_id:
            try:
                pane = herdr.json(["pane", "get", pane_id])
            except PluginError:
                state.remove(context.workspace_id, mode, placement)
            else:
                workspace_id = pane.get("result", {}).get("pane", {}).get("workspace_id")
                if workspace_id == context.workspace_id:
                    herdr.json(["plugin", "pane", "focus", pane_id])
                    return pane_id
                state.remove(context.workspace_id, mode, placement)

    if placement == "split":
        opened = herdr.json(
            [
                "pane",
                "split",
                context.pane_id,
                "--direction",
                "right",
                "--cwd",
                str(context.cwd),
                "--env",
                f"HUNK_REVIEW_MODE={mode}",
                "--focus",
            ]
        )
        pane_id = _pane_from(opened)
        if pane_id is None:
            raise PluginError("Herdr did not return a managed pane id")
        herdr.json(["pane", "rename", pane_id, "hunk"])
        herdr.json(["pane", "run", pane_id, _run_command(mode, context.cwd, git)])
        state.set(context.workspace_id, mode, placement, pane_id)
        return pane_id

    opened = herdr.json(_open_args(mode, placement, context))
    if placement == "popup":
        return None

    pane_id = _pane_from(opened)
    if pane_id is None:
        raise PluginError("Herdr did not return a managed pane id")
    state.set(context.workspace_id, mode, placement, pane_id)
    return pane_id


def _run_hunk(mode: str, git: GitOutput) -> None:
    repo = git.output(Path.cwd(), ["rev-parse", "--show-toplevel"])
    if repo is None:
        raise PluginError(f"not a Git repository: {Path.cwd()}")
    argv = build_hunk_argv(mode, Path(repo), git)
    os.chdir(repo)
    os.execvp(argv[0], argv)


def main(argv: list[str], env: Mapping[str, str]) -> int:
    try:
        if len(argv) == 3 and argv[0] == "open":
            _, mode, placement = argv
            if shutil.which("hunk") is None:
                raise PluginError("hunk executable was not found")
            git = SubprocessGit()
            context = review_context(env, git)
            herdr = SubprocessHerdr(env.get("HERDR_BIN_PATH", "herdr"))
            state_dir = env.get("HERDR_PLUGIN_STATE_DIR")
            if not state_dir:
                raise PluginError("missing Herdr plugin state directory")
            open_review(
                mode,
                placement,
                context,
                herdr,
                PaneState(Path(state_dir) / "panes.json"),
                git,
            )
            return 0

        if argv == ["run"]:
            mode = env.get("HUNK_REVIEW_MODE", "")
            if mode not in {"worktree", "branch"}:
                raise PluginError(f"unsupported review mode: {mode}")
            _run_hunk(mode, SubprocessGit())
            return 0

        raise PluginError("usage: hunk_review.py open <worktree|branch> <split|tab|popup> | run")
    except PluginError as error:
        print(f"hunk-review: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:], os.environ))
