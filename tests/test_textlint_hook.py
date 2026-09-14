"""APM で配布する Markdown 編集後 hook の公開契約。"""

import json
import os
import shutil
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
HOOK = ROOT / "home/.apm/packages/textlint-ai/hooks/check.py"


class TextlintHookTests(unittest.TestCase):
    def test_apm_deploys_both_hooks_once_and_preserves_existing_settings(self):
        # Arrange: 配布時と同じ package symlink と manifest の依存宣言を使う。
        with tempfile.TemporaryDirectory(prefix="apm textlint ") as directory:
            home = Path(directory)
            package = home / ".apm/packages/textlint-ai"
            package.parent.mkdir(parents=True)
            package.symlink_to(HOOK.parents[1], target_is_directory=True)
            source = (ROOT / "home/.apm/apm.yml").read_text()
            dependency = next(line for line in source.splitlines() if "path:" in line and "textlint-ai" in line)
            (home / ".apm/apm.yml").write_text(
                "name: hook-test\nversion: 0.1.0\ntargets: [claude, codex]\ndependencies:\n  apm:\n"
                + dependency + "\n"
            )
            settings = home / ".claude/settings.json"
            settings.parent.mkdir()
            settings.write_text(json.dumps({"env": {"PRESERVE_ME": "yes"}}))
            env = {**os.environ, "HOME": str(home)}

            # Act: 別の cwd から user-scope install を二度実行する。
            for _ in range(2):
                result = subprocess.run(
                    [shutil.which("apm"), "install", "-g"], cwd=ROOT,
                    env=env, capture_output=True, text=True, timeout=60,
                )
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

            # Assert: 両 agent に一件ずつ登録され、配布先 script が存在する。
            for target, name in [("claude", "settings.json"), ("codex", "hooks.json")]:
                data = json.loads((home / f".{target}" / name).read_text())
                hooks = data["hooks"]["PostToolUse"]
                self.assertEqual(len(hooks), 1, data)
                self.assertIn("apply_patch", hooks[0]["matcher"])
                self.assertEqual(len(list((home / f".{target}/hooks").rglob("check.py"))), 1)
            self.assertEqual(json.loads(settings.read_text())["env"], {"PRESERVE_ME": "yes"})

    def test_markdown_edit_passes_filename_to_textlint(self):
        # Arrange: agent の起動環境に PATH がなくても HOME のコマンドを使える。
        with tempfile.TemporaryDirectory(prefix="textlint hook ") as directory:
            home = Path(directory)
            command = home / ".local/bin/textlint-ai"
            command.parent.mkdir(parents=True)
            command.write_text('#!/bin/sh\nprintf "%s\\n" "$@" > "$HOME/args"\n')
            command.chmod(0o755)
            payload = {"tool_input": {"file_path": "/project/docs/file with spaces.md"}}

            # Act: Claude Code の PostToolUse と同じ stdin を渡す。
            result = subprocess.run(
                [sys.executable, str(HOOK)], input=json.dumps(payload),
                env={**os.environ, "HOME": str(home)}, capture_output=True,
                text=True, timeout=60,
            )

            # Assert: 一つのファイル引数として渡し、成功する。
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((home / "args").read_text(), "/project/docs/file with spaces.md\n")

    def test_codex_patch_checks_added_updated_and_moved_markdown(self):
        # Arrange: 一つの patch に追加・変更・移動・削除と対象外ファイルがある。
        with tempfile.TemporaryDirectory(prefix="codex hook ") as directory:
            home = Path(directory)
            command = home / ".local/bin/textlint-ai"
            command.parent.mkdir(parents=True)
            command.write_text('#!/bin/sh\nprintf "%s\\n" "$@" > "$HOME/args"\n')
            command.chmod(0o755)
            patch = "\n".join([
                "*** Begin Patch", "*** Add File: docs/new.md", "+文章",
                "*** Update File: docs/edited.md", "@@", "-旧", "+新",
                "*** Update File: docs/old.md", "*** Move to: docs/moved file.md",
                "@@", "-旧", "+新", "*** Delete File: docs/deleted.md",
                "*** Add File: code.py", "+pass", "*** End Patch",
            ])
            payload = {"tool_name": "apply_patch", "cwd": "/project", "tool_input": {"command": patch}}

            # Act: Codex が渡す patch を通知する。
            result = subprocess.run(
                [sys.executable, str(HOOK)], input=json.dumps(payload),
                env={**os.environ, "HOME": str(home)}, capture_output=True,
                text=True, timeout=60,
            )

            # Assert: 削除元や非 Markdown を除き、cwd から解決した全対象を渡す。
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((home / "args").read_text().splitlines(), [
                "/project/docs/new.md", "/project/docs/edited.md", "/project/docs/moved file.md",
            ])

    def test_lint_findings_are_returned_to_the_agent(self):
        # Arrange: textlint が指摘を stdout に出して終了コード 1 を返す。
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            command = home / ".local/bin/textlint-ai"
            command.parent.mkdir(parents=True)
            command.write_text('#!/bin/sh\necho "ai-words-ja/no-ai-words: finding"\nexit 1\n')
            command.chmod(0o755)

            # Act: Markdown の編集イベントを渡す。
            result = subprocess.run(
                [sys.executable, str(HOOK)], input=json.dumps({"tool_input": {"file_path": "/project/a.md"}}),
                env={**os.environ, "HOME": str(home)}, capture_output=True,
                text=True, timeout=60,
            )

            # Assert: Claude にフィードバックする exit 2 と stderr に変換する。
            self.assertEqual(result.returncode, 2)
            self.assertIn("ai-words-ja/no-ai-words: finding", result.stderr)
            self.assertEqual(result.stdout, "")

    def test_non_markdown_and_missing_file_path_do_not_run_textlint(self):
        # Arrange: textlint を導入していない HOME で対象外のイベントを渡す。
        with tempfile.TemporaryDirectory() as directory:
            for payload in [{"tool_input": {"file_path": "/project/code.py"}}, {"tool_input": {}}]:
                with self.subTest(payload=payload):
                    # Act: 対象外の編集を通知する。
                    result = subprocess.run(
                        [sys.executable, str(HOOK)], input=json.dumps(payload),
                        env={**os.environ, "HOME": directory}, capture_output=True,
                        text=True, timeout=60,
                    )

                    # Assert: lint 環境の有無に関係なく何も出力しない。
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(result.stdout + result.stderr, "")


if __name__ == "__main__":
    unittest.main()
