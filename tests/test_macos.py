import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(sys.platform == "darwin", "macOS integration")
class MacOSSetupTests(unittest.TestCase):
    def test_preview_does_not_invoke_sudo_or_write_pam_files(self):
        # Arrange: native commands are recorded; sudo must never be invoked.
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            mise = root / "mise"
            log = root / "calls"
            mise.write_text('#!/bin/sh\nprintf "%s\\n" "$*" >> "$CALL_LOG"\n')
            mise.chmod(0o755)
            sudo = root / "sudo"
            sudo.write_text('#!/bin/sh\necho "unexpected sudo" >&2\nexit 99\n')
            sudo.chmod(0o755)

            # Act: preview the OS-specific integration.
            result = subprocess.run(
                ["bash", str(ROOT / "scripts/macos.sh"), "--dry-run"],
                env={**os.environ, "MISE_BIN": str(mise), "CALL_LOG": str(log),
                     "PATH": f"{root}:{os.environ['PATH']}"},
                capture_output=True, text=True, timeout=60,
            )

            # Assert: only the native files preview is delegated.
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("--dry-run", log.read_text())
            self.assertIn("--only files,user", log.read_text())
            self.assertIn("Pictures/Screenshots", result.stdout)
            self.assertNotIn("unexpected sudo", result.stderr)


if __name__ == "__main__":
    unittest.main()
