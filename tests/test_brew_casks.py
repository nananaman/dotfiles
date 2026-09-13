import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class BrewCaskTests(unittest.TestCase):
    def run_script(self, *args):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            log = root / 'calls'
            for name, content in {
                'uname': '#!/bin/sh\necho Darwin\n',
                'brew': '#!/bin/sh\nprintf "%s\\n" "$*" >> "$CALL_LOG"\n',
            }.items():
                executable = root / name
                executable.write_text(content)
                executable.chmod(0o755)
            result = subprocess.run(
                ['bash', str(ROOT / 'scripts/brew-casks.sh'), *args],
                env={**os.environ, 'PATH': f"{root}:{os.environ['PATH']}", 'CALL_LOG': str(log)},
                capture_output=True, text=True, timeout=60,
            )
            return result, log.read_text() if log.exists() else ''

    def test_preview_does_not_install_or_upgrade_casks(self):
        # Arrange: replace Homebrew at the host boundary.
        # Act: preview the declared fallback applications.
        result, calls = self.run_script('--dry-run')
        # Assert: no installation takes place and the scope is visible.
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(calls, '')
        self.assertIn('aerospace', result.stdout)
        self.assertIn('orca', result.stdout)

    def test_setup_preserves_installed_cask_versions(self):
        # Arrange: use a recording Homebrew executable.
        # Act: apply the fallback dependencies.
        result, calls = self.run_script()
        # Assert: routine setup does not upgrade installed applications.
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('bundle install', calls)
        self.assertIn('--no-upgrade', calls)

    def test_explicit_update_upgrades_declared_casks(self):
        # Arrange: use a recording Homebrew executable.
        # Act: explicitly request upgrades.
        result, calls = self.run_script('--upgrade')
        # Assert: the update is limited to the same Brewfile.
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('--upgrade', calls)
        self.assertIn('scripts/Brewfile', calls)


if __name__ == '__main__':
    unittest.main()
