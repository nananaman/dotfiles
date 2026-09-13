import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class SetupTests(unittest.TestCase):
    def test_old_mise_is_rejected_before_setup(self):
        # Arrange: the installed mise predates bootstrap support.
        with tempfile.TemporaryDirectory() as directory:
            mise = Path(directory) / "mise"
            mise.write_text('#!/bin/sh\necho "2025.9.19 macos-arm64"\n')
            mise.chmod(0o755)

            # Act: ask for setup with the unsupported executable.
            result = subprocess.run(
                ["bash", str(ROOT / "scripts/bootstrap.sh")],
                env={**os.environ, "MISE_BIN": str(mise)},
                capture_output=True, text=True, timeout=60,
            )

            # Assert: no misleading success from an older CLI's task fallback.
            self.assertEqual(result.returncode, 1)
            self.assertIn("2026.9.5 or newer", result.stderr)

    def test_dry_run_only_invokes_native_preview_commands(self):
        # Arrange: fake only the system boundary; record all mise invocations.
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            log = root / "calls"
            mise = root / "mise"
            mise.write_text(
                '#!/bin/sh\nprintf "%s\\n" "$*" >> "$CALL_LOG"\n'
                'if [ "$1" = --version ]; then echo "2026.9.5 macos-arm64"; fi\n'
            )
            mise.chmod(0o755)

            # Act: preview setup without installing tools or applying settings.
            result = subprocess.run(
                ["bash", str(ROOT / "scripts/bootstrap.sh"), "--dry-run"],
                env={**os.environ, "MISE_BIN": str(mise), "CALL_LOG": str(log)},
                capture_output=True, text=True, timeout=60,
            )

            # Assert: native operations are all previews and both scopes appear.
            self.assertEqual(result.returncode, 0, result.stderr)
            calls = log.read_text().splitlines()
            operations = [line for line in calls if line != "--version"]
            self.assertTrue(any("bootstrap" in line for line in operations))
            self.assertTrue(any("install" in line for line in operations))
            self.assertTrue(all("--dry-run" in line for line in operations), calls)


if __name__ == "__main__":
    unittest.main()
