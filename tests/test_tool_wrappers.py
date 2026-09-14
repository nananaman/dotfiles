"""Public wrapper contracts without downloads or credentials."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


REPOSITORY = Path(__file__).resolve().parents[1]


class ToolWrapperTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="tool wrappers ")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()
        self.home = self.root / "home"
        self.bin = self.home / ".local/bin"
        self.bin.mkdir(parents=True)
        source = REPOSITORY / "home/.local/bin"
        if source.exists():
            shutil.copytree(source, self.bin, dirs_exist_ok=True)
        self.work = self.root / "project"
        self.work.mkdir()
        self.raw = self.root / "raw"
        self.raw.mkdir()
        self.log = self.root / "call.json"
        self.mise = self.root / "mise"
        self.mise.write_text(
            "#!/bin/sh\n"
            'case " $* " in\n'
            '  *" which "*) printf "%s\\n" "$RAW_EXECUTABLE" ;;\n'
            '  *" bin-paths "*) printf "%s\\n" "$RAW_DIRECTORY" ;;\n'
            '  *" where "*) printf "%s\\n" "$RAW_DIRECTORY" ;;\n'
            '  *) exit 99 ;;\n'
            "esac\n"
        )
        self.mise.chmod(0o755)
        self.executable = self.raw / "codex"
        self.executable.write_text(
            f"#!{shutil.which('python3')}\n"
            "import json, os, sys\n"
            "from pathlib import Path\n"
            "Path(os.environ['CALL_LOG']).write_text(json.dumps({\n"
            " 'args': sys.argv[1:], 'cwd': os.getcwd(),\n"
            " 'path': os.environ['PATH'].split(os.pathsep),\n"
            " 'self': os.environ.get('CODEX_EXECUTABLE_PATH'),\n"
            " 'auto_update': os.environ.get('DISABLE_AUTOUPDATER')}))\n"
            "sys.exit(int(os.environ.get('RAW_EXIT', '0')))\n"
        )
        self.executable.chmod(0o755)
        self.env = {
            **os.environ, "HOME": str(self.home), "MISE_BIN": str(self.mise),
            "RAW_EXECUTABLE": str(self.executable), "RAW_DIRECTORY": str(self.raw),
            "CALL_LOG": str(self.log),
        }

    def run_codex(self, *args):
        return self.run_wrapper("codex", *args)

    def run_wrapper(self, name, *args):
        return subprocess.run(
            ["bash", str(self.bin / name), *args],
            cwd=self.work, env=self.env, text=True, capture_output=True, timeout=60,
        )

    def test_codex_preserves_arguments_working_directory_and_exit_status(self):
        # Arrange: the raw CLI records its public process context.
        self.env["RAW_EXIT"] = "17"

        # Act: execute from a project directory with a spaced argument.
        result = self.run_codex("exec", "argument with spaces")

        # Assert: resolving the global binary does not change the task's CWD.
        self.assertEqual(result.returncode, 17, result.stderr)
        call = json.loads(self.log.read_text())
        self.assertEqual(call["args"], ["exec", "argument with spaces"])
        self.assertEqual(call["cwd"], str(self.work))
        self.assertEqual(call["self"], str(self.bin / "codex"))
        self.assertEqual(call["auto_update"], "1")

    def test_codex_preserves_the_project_tool_path_for_child_commands(self):
        # Arrange: a project selected its own runtime before launching Codex.
        project_tools = self.work / "tools"
        project_tools.mkdir()
        self.env["PATH"] = f"{project_tools}:{self.env['PATH']}"

        # Act: resolving Codex globally should not replace project dependencies.
        result = self.run_codex("exec", "build the project")

        # Assert: only the wrapper directory may precede the project tool path.
        self.assertEqual(result.returncode, 0, result.stderr)
        path = json.loads(self.log.read_text())["path"]
        self.assertEqual(path[:2], [str(self.bin), str(project_tools)])

    def test_missing_raw_executable_fails_without_running_a_command(self):
        # Arrange: mise returns an installation that no longer exists.
        self.executable.unlink()

        # Act: invoke the public wrapper.
        result = self.run_codex("exec", "hello")

        # Assert: fail clearly instead of resolving a different PATH executable.
        self.assertEqual(result.returncode, 127)
        self.assertIn("invalid raw executable", result.stderr)
        self.assertFalse(self.log.exists())

    def test_resolving_the_wrapper_itself_is_rejected(self):
        # Arrange: an invalid lookup would recursively launch the same wrapper.
        self.env["RAW_EXECUTABLE"] = str(self.bin / "codex")

        # Act: invoke once.
        result = self.run_codex("exec", "hello")

        # Assert: the recursive target is rejected before exec.
        self.assertEqual(result.returncode, 127)
        self.assertIn("invalid raw executable", result.stderr)
        self.assertFalse(self.log.exists())

    def test_claude_passes_prompts_and_explicit_commands_without_added_flags(self):
        # Arrange: distinguish update from a prompt that merely starts with it.
        for args in [("update",), ("update", "README"), ("review the README",)]:
            with self.subTest(args=args):
                # Act: the wrapper delegates all arguments unchanged.
                result = self.run_wrapper("claude", *args)

                # Assert: no permission-bypass or sandbox flags are introduced.
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(json.loads(self.log.read_text())["args"], list(args))

    def test_pi_reuses_the_parent_session_without_wrapping_another_sandbox(self):
        # Arrange: simulate an existing session and a globally installed JS entry.
        cli = self.raw / "node_modules/@earendil-works/pi-coding-agent/dist/bundle/cli.js"
        cli.parent.mkdir(parents=True)
        cli.write_text("// JavaScript entry\n")
        self.env["NONO_CAP_FILE"] = str(self.root / "capability")

        # Act: resume through the pi wrapper.
        result = self.run_wrapper("pi", "resume")

        # Assert: only the raw pi invocation occurs.
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(self.log.read_text())["args"], [str(cli), "resume"])

    def test_omp_runs_the_javascript_entry_with_bun_not_the_npm_shell_shim(self):
        # Arrange: aube creates a shell shim but OMP requires a Bun JS entry.
        cli = self.raw / "node_modules/@oh-my-pi/pi-coding-agent/dist/cli.js"
        cli.parent.mkdir(parents=True)
        cli.write_text("// JavaScript entry\n")

        # Act: the fake Bun records which file it was asked to execute.
        result = self.run_wrapper("omp", "--version")

        # Assert: execute JS directly, keeping user arguments.
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(self.log.read_text())["args"], [str(cli), "--version"])

    def test_agent_browser_uses_the_global_node_entry(self):
        # Arrange: the package includes both its JS launcher and matching assets.
        package = self.raw / "node_modules/agent-browser"
        cli = package / "bin/agent-browser.js"
        cli.parent.mkdir(parents=True)
        cli.write_text("// JavaScript entry\n")
        (package / "skill-data").mkdir()

        # Act: launch through the wrapper, independently of project Node versions.
        result = self.run_wrapper("agent-browser", "--version")

        # Assert: Node receives the package entry and the original arguments.
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(self.log.read_text())["args"], [str(cli), "--version"])

    def test_textlint_ai_uses_shared_rules_and_preserves_process_context(self):
        # Arrange: mise 管理の CLI と共通設定を用意する。
        cli = self.raw / "node_modules/textlint/bin/textlint.js"
        cli.parent.mkdir(parents=True)
        cli.write_text("// JavaScript entry\n")
        config = self.home / ".config/textlint/.textlintrc.json"
        config.parent.mkdir(parents=True)
        config.write_text('{"rules": {"preset-ai-words-ja": true}}\n')
        self.env["RAW_EXIT"] = "1"

        # Act: 空白入りパスを別の project から検査する。
        result = self.run_wrapper("textlint-ai", "docs/file with spaces.md")

        # Assert: 共通設定とルールを使い、cwd・引数・検出時の終了コードを保つ。
        self.assertEqual(result.returncode, 1, result.stderr)
        call = json.loads(self.log.read_text())
        self.assertEqual(call["args"], [
            str(cli), "--config", str(config),
            "--rules-base-directory", str(config.parent / "node_modules"),
            "docs/file with spaces.md",
        ])
        self.assertEqual(call["cwd"], str(self.work))

    def test_container_prefers_the_injected_tool_sandbox_shim(self):
        # Arrange: an existing sandbox has already provided its safe launcher.
        shim = self.raw / "container"
        shutil.copy(self.executable, shim)
        self.env["NONO_TOOL_SANDBOX_SHIM_DIR"] = str(self.raw)

        # Act: dispatch a read-only container command.
        result = self.run_wrapper("container", "image", "list")

        # Assert: the host launcher is not invoked.
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(self.log.read_text())["args"], ["image", "list"])


if __name__ == "__main__":
    unittest.main()
