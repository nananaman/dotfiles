#!/usr/bin/env python3

import tempfile
import tomllib
import unittest
from pathlib import Path

import hunk_review


PLUGIN_DIR = Path(__file__).resolve().parent
REPO_DIR = PLUGIN_DIR.parents[1]


class FakeGit:
    def __init__(self, responses: dict[tuple[str, ...], str | None]):
        self.responses = responses
        self.calls: list[tuple[str, ...]] = []

    def output(self, repo: Path, args: list[str]) -> str | None:
        self.calls.append(tuple(args))
        return self.responses.get(tuple(args))


class FakeHerdr:
    def __init__(self, responses: dict[tuple[str, ...], dict]):
        self.responses = responses
        self.calls: list[tuple[str, ...]] = []

    def json(self, args: list[str]) -> dict:
        key = tuple(args)
        self.calls.append(key)
        if key not in self.responses:
            raise AssertionError(f"unexpected Herdr call: {key}")
        return self.responses[key]


class ParseHerdrOutputTest(unittest.TestCase):
    def test_accepts_empty_success_output(self) -> None:
        # Arrange
        output = "\n"

        # Act
        payload = hunk_review._parse_herdr_output(output)

        # Assert
        self.assertEqual(payload, {})

    def test_uses_last_json_object_after_wrapper_output(self) -> None:
        # Arrange
        output = 'wrapper notice\n{"result":{"pane":{"pane_id":"w5:p2"}}}\n'

        # Act
        payload = hunk_review._parse_herdr_output(output)

        # Assert
        self.assertEqual(payload["result"]["pane"]["pane_id"], "w5:p2")


class ParseHerdrOutputErrorTest(unittest.TestCase):
    def test_rejects_output_without_json_object(self) -> None:
        # Arrange
        output = "wrapper notice only\n"

        # Act / Assert
        with self.assertRaisesRegex(hunk_review.PluginError, "invalid JSON"):
            hunk_review._parse_herdr_output(output)


class BuildHunkArgvTest(unittest.TestCase):
    def test_worktree_uses_continuous_watch(self) -> None:
        # Arrange
        repo = Path("/repo")
        git = FakeGit({})

        # Act
        argv = hunk_review.build_hunk_argv("worktree", repo, git)

        # Assert
        self.assertEqual(
            argv,
            ["hunk", "diff", "--watch", "--no-transparent-bg"],
        )
        self.assertEqual(git.calls, [])

    def test_branch_uses_upstream_merge_base_diff(self) -> None:
        # Arrange
        repo = Path("/repo")
        git = FakeGit(
            {
                ("rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}"): "origin/topic",
                ("rev-parse", "--verify", "origin/topic"): "abc123",
            }
        )

        # Act
        argv = hunk_review.build_hunk_argv("branch", repo, git)

        # Assert
        self.assertEqual(
            argv,
            ["hunk", "diff", "origin/topic...HEAD", "--watch", "--no-transparent-bg"],
        )


class BuildHunkArgvErrorTest(unittest.TestCase):
    def test_branch_rejects_repository_without_comparison_ref(self) -> None:
        # Arrange
        repo = Path("/repo")
        git = FakeGit(
            {
                ("rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}"): None,
                ("rev-parse", "--verify", "origin/main"): None,
            }
        )

        # Act / Assert
        with self.assertRaisesRegex(hunk_review.PluginError, "comparison ref"):
            hunk_review.build_hunk_argv("branch", repo, git)


class OpenReviewTest(unittest.TestCase):
    def test_split_opens_managed_pane_and_records_it(self) -> None:
        # Arrange
        context = hunk_review.ReviewContext(
            workspace_id="w5",
            pane_id="w5:p1",
            cwd=Path("/repo"),
        )
        split_args = (
            "pane",
            "split",
            "w5:p1",
            "--direction",
            "right",
            "--cwd",
            "/repo",
            "--env",
            "HUNK_REVIEW_MODE=worktree",
            "--focus",
        )
        run_args = (
            "pane",
            "run",
            "w5:p2",
            "exec hunk diff --watch --no-transparent-bg",
        )
        rename_args = ("pane", "rename", "w5:p2", "hunk")
        herdr = FakeHerdr(
            {
                split_args: {"result": {"pane": {"pane_id": "w5:p2"}}},
                rename_args: {"result": {"type": "pane_renamed"}},
                run_args: {"result": {"type": "pane_input_sent"}},
            }
        )

        with tempfile.TemporaryDirectory() as state_dir:
            state = hunk_review.PaneState(Path(state_dir) / "panes.json")

            # Act
            pane_id = hunk_review.open_review(
                "worktree", "split", context, herdr, state, FakeGit({})
            )

            # Assert
            self.assertEqual(pane_id, "w5:p2")
            self.assertEqual(state.get("w5", "worktree", "split"), "w5:p2")
            self.assertEqual(herdr.calls, [split_args, rename_args, run_args])

    def test_existing_managed_pane_is_focused_instead_of_duplicated(self) -> None:
        # Arrange
        context = hunk_review.ReviewContext(
            workspace_id="w5",
            pane_id="w5:p1",
            cwd=Path("/repo"),
        )
        herdr = FakeHerdr(
            {
                ("pane", "get", "w5:p2"): {
                    "result": {"pane": {"pane_id": "w5:p2", "workspace_id": "w5"}}
                },
                ("plugin", "pane", "focus", "w5:p2"): {
                    "result": {"type": "plugin_pane_focused"}
                },
            }
        )

        with tempfile.TemporaryDirectory() as state_dir:
            state = hunk_review.PaneState(Path(state_dir) / "panes.json")
            state.set("w5", "worktree", "split", "w5:p2")

            # Act
            pane_id = hunk_review.open_review(
                "worktree", "split", context, herdr, state, FakeGit({})
            )

            # Assert
            self.assertEqual(pane_id, "w5:p2")
            self.assertEqual(
                herdr.calls,
                [
                    ("pane", "get", "w5:p2"),
                    ("plugin", "pane", "focus", "w5:p2"),
                ],
            )

    def test_popup_is_not_recorded_as_a_pane(self) -> None:
        # Arrange
        context = hunk_review.ReviewContext(
            workspace_id="w5",
            pane_id="w5:p1",
            cwd=Path("/repo"),
        )
        open_args = (
            "plugin",
            "pane",
            "open",
            "--plugin",
            "hunk-review",
            "--entrypoint",
            "review",
            "--placement",
            "popup",
            "--workspace",
            "w5",
            "--target-pane",
            "w5:p1",
            "--cwd",
            "/repo",
            "--env",
            "HUNK_REVIEW_MODE=worktree",
            "--focus",
        )
        herdr = FakeHerdr({open_args: {"result": {"type": "plugin_popup_opened"}}})

        with tempfile.TemporaryDirectory() as state_dir:
            state = hunk_review.PaneState(Path(state_dir) / "panes.json")

            # Act
            pane_id = hunk_review.open_review(
                "worktree", "popup", context, herdr, state, FakeGit({})
            )

            # Assert
            self.assertIsNone(pane_id)
            self.assertIsNone(state.get("w5", "worktree", "popup"))

    def test_missing_managed_pane_is_recreated(self) -> None:
        # Arrange
        context = hunk_review.ReviewContext("w5", "w5:p1", Path("/repo"))
        split_args = (
            "pane",
            "split",
            "w5:p1",
            "--direction",
            "right",
            "--cwd",
            "/repo",
            "--env",
            "HUNK_REVIEW_MODE=worktree",
            "--focus",
        )
        run_args = (
            "pane",
            "run",
            "w5:p2",
            "exec hunk diff --watch --no-transparent-bg",
        )
        rename_args = ("pane", "rename", "w5:p2", "hunk")

        class StalePaneHerdr(FakeHerdr):
            def json(self, args: list[str]) -> dict:
                if args == ["pane", "get", "w5:p9"]:
                    self.calls.append(tuple(args))
                    raise hunk_review.PluginError("pane not found")
                return super().json(args)

        herdr = StalePaneHerdr(
            {
                split_args: {"result": {"pane": {"pane_id": "w5:p2"}}},
                rename_args: {"result": {"type": "pane_renamed"}},
                run_args: {"result": {"type": "pane_input_sent"}},
            }
        )

        with tempfile.TemporaryDirectory() as state_dir:
            state = hunk_review.PaneState(Path(state_dir) / "panes.json")
            state.set("w5", "worktree", "split", "w5:p9")

            # Act
            pane_id = hunk_review.open_review(
                "worktree", "split", context, herdr, state, FakeGit({})
            )

            # Assert
            self.assertEqual(pane_id, "w5:p2")
            self.assertEqual(state.get("w5", "worktree", "split"), "w5:p2")


class OpenReviewErrorTest(unittest.TestCase):
    def test_unknown_mode_is_rejected_before_calling_herdr(self) -> None:
        # Arrange
        context = hunk_review.ReviewContext("w5", "w5:p1", Path("/repo"))
        herdr = FakeHerdr({})

        with tempfile.TemporaryDirectory() as state_dir:
            state = hunk_review.PaneState(Path(state_dir) / "panes.json")

            # Act / Assert
            with self.assertRaisesRegex(hunk_review.PluginError, "mode"):
                hunk_review.open_review(
                    "shell", "split", context, herdr, state, FakeGit({})
                )
            self.assertEqual(herdr.calls, [])

    def test_unknown_placement_is_rejected_before_calling_herdr(self) -> None:
        # Arrange
        context = hunk_review.ReviewContext("w5", "w5:p1", Path("/repo"))
        herdr = FakeHerdr({})

        with tempfile.TemporaryDirectory() as state_dir:
            state = hunk_review.PaneState(Path(state_dir) / "panes.json")

            # Act / Assert
            with self.assertRaisesRegex(hunk_review.PluginError, "placement"):
                hunk_review.open_review(
                    "worktree", "overlay", context, herdr, state, FakeGit({})
                )
            self.assertEqual(herdr.calls, [])


class ReviewContextTest(unittest.TestCase):
    def test_plugin_context_resolves_repository_root(self) -> None:
        # Arrange
        git = FakeGit({("rev-parse", "--show-toplevel"): "/repo"})
        env = {
            "HERDR_PLUGIN_CONTEXT_JSON": (
                '{"workspace_id":"w5","focused_pane_id":"w5:p1",'
                '"focused_pane_cwd":"/repo/subdir"}'
            )
        }

        # Act
        context = hunk_review.review_context(env, git)

        # Assert
        self.assertEqual(context, hunk_review.ReviewContext("w5", "w5:p1", Path("/repo")))


class ReviewContextErrorTest(unittest.TestCase):
    def test_non_git_directory_is_rejected(self) -> None:
        # Arrange
        git = FakeGit({("rev-parse", "--show-toplevel"): None})
        env = {
            "HERDR_PLUGIN_CONTEXT_JSON": (
                '{"workspace_id":"w5","focused_pane_id":"w5:p1",'
                '"focused_pane_cwd":"/tmp"}'
            )
        }

        # Act / Assert
        with self.assertRaisesRegex(hunk_review.PluginError, "Git repository"):
            hunk_review.review_context(env, git)

    def test_missing_focused_pane_is_rejected(self) -> None:
        # Arrange
        git = FakeGit({("rev-parse", "--show-toplevel"): "/repo"})
        env = {
            "HERDR_PLUGIN_CONTEXT_JSON": (
                '{"workspace_id":"w5","focused_pane_cwd":"/repo"}'
            )
        }

        # Act / Assert
        with self.assertRaisesRegex(hunk_review.PluginError, "pane"):
            hunk_review.review_context(env, git)


class PluginManifestTest(unittest.TestCase):
    def test_manifest_exposes_all_review_modes_and_placements(self) -> None:
        # Arrange
        expected_commands = {
            ("worktree-split", "worktree", "split"),
            ("worktree-tab", "worktree", "tab"),
            ("worktree-popup", "worktree", "popup"),
            ("branch-split", "branch", "split"),
            ("branch-tab", "branch", "tab"),
            ("branch-popup", "branch", "popup"),
        }

        # Act
        manifest = tomllib.loads((PLUGIN_DIR / "herdr-plugin.toml").read_text())
        actual_commands = {
            (action["id"], action["command"][3], action["command"][4])
            for action in manifest["actions"]
        }

        # Assert
        self.assertEqual(actual_commands, expected_commands)
        self.assertEqual(manifest["id"], "hunk-review")
        self.assertEqual(manifest["min_herdr_version"], "0.7.0")
        self.assertEqual(
            manifest["panes"],
            [
                {
                    "id": "review",
                    "title": "Hunk review",
                    "placement": "split",
                    "command": ["python3", "hunk_review.py", "run"],
                }
            ],
        )


class HerdrConfigTest(unittest.TestCase):
    def test_prefix_d_opens_worktree_split_review(self) -> None:
        # Arrange
        config = tomllib.loads((REPO_DIR / "herdr" / "config.toml").read_text())

        # Act
        bindings = {
            command["key"]: (command["type"], command["command"])
            for command in config["keys"]["command"]
        }

        # Assert
        self.assertEqual(
            bindings["prefix+d"],
            ("plugin_action", "hunk-review.worktree-split"),
        )


if __name__ == "__main__":
    unittest.main()
