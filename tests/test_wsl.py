import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class WSLSetupTests(unittest.TestCase):
    def test_non_wsl_linux_skips_windows_integration(self):
        # Arrange: a regular Linux host has no Windows bridge.
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            uname = root / "uname"
            uname.write_text('#!/bin/sh\nif [ "$1" = -s ]; then echo Linux; else echo generic; fi\n')
            uname.chmod(0o755)

            # Act: run the WSL-specific portion of setup.
            result = subprocess.run(
                ["bash", str(ROOT / "scripts/wsl.sh")],
                env={**os.environ, "PATH": f"{root}:{os.environ['PATH']}"},
                capture_output=True, text=True, timeout=60,
            )

            # Assert: no attempt is made to find or modify a Windows profile.
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("Windows integration skipped", result.stdout)


if __name__ == "__main__":
    unittest.main()
