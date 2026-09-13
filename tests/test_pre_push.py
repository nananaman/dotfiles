import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class PrePushTests(unittest.TestCase):
    def test_secretlint_executable_and_filename_can_contain_spaces(self):
        # Arrange: the globally installed CLI and repository both contain spaces.
        with tempfile.TemporaryDirectory(prefix="pre push ") as directory:
            root = Path(directory)
            repo = root / "repo"
            repo.mkdir()
            subprocess.run(["git", "init", "--quiet", str(repo)], check=True)
            (repo / "example file.txt").write_text("harmless\n")
            (repo / ".secretlintrc.json").write_text('{"rules": []}\n')
            subprocess.run(["git", "add", "example file.txt"], cwd=repo, check=True)
            tools = root / "fake tools"
            tools.mkdir()
            cli = tools / "secretlint"
            cli.write_text('#!/bin/sh\nprintf "%s\\n" "$@" > "$CALL_LOG"\n')
            cli.chmod(0o755)
            log = root / "calls"

            # Act: a new branch without an upstream scans tracked files.
            result = subprocess.run(
                ["bash", str(ROOT / "home/.config/git/hooks/pre-push")], cwd=repo,
                env={**os.environ, "PATH": f"{tools}:{os.environ['PATH']}", "CALL_LOG": str(log)},
                input=f"refs/heads/new {'1' * 40} refs/heads/new {'0' * 40}\n",
                text=True, capture_output=True, timeout=60,
            )

            # Assert: shell splitting does not truncate either path.
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(log.read_text().splitlines()[-1], "example file.txt")


if __name__ == "__main__":
    unittest.main()
