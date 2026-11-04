import os
from pathlib import Path
import platform
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class LinkPreflightTests(unittest.TestCase):
    @unittest.skipUnless(platform.system() == "Darwin", "Herdr Desktop is macOS-only")
    def test_herdr_directory_symlink_is_reported_without_changing_its_source(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory) / "home"
            old = Path(directory) / "old-herdr-app"
            old.mkdir()
            settings = old / "settings.json"
            original = b'{"local": true}\n'
            settings.write_bytes(original)
            (home / ".config").mkdir(parents=True)
            (home / ".config/herdr-app").symlink_to(old, target_is_directory=True)

            result = subprocess.run(
                ["python3", str(ROOT / "scripts/check-links.py")],
                env={**os.environ, "HOME": str(home)}, capture_output=True,
                text=True, timeout=30,
            )

            self.assertEqual(result.returncode, 1, result.stderr)
            self.assertIn(str(home / ".config/herdr-app"), result.stderr)
            self.assertEqual(settings.read_bytes(), original)
            self.assertEqual(list(old.iterdir()), [settings])

    def test_old_directory_symlink_is_reported_without_changing_its_source(self):
        # Arrange: Home Manager links a directory into another checkout.
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory) / "home"
            old = Path(directory) / "old-checkout"
            old.mkdir()
            sentinel = old / "init.lua"
            sentinel.write_text("local changes\n")
            (home / ".config").mkdir(parents=True)
            (home / ".config/nvim").symlink_to(old, target_is_directory=True)

            # Act: preflight must block traversing the old directory link.
            result = subprocess.run(
                ["python3", str(ROOT / "scripts/check-links.py")],
                env={**os.environ, "HOME": str(home)}, capture_output=True,
                text=True, timeout=30,
            )

            # Assert: the diagnostic names the link; the old checkout is intact.
            self.assertEqual(result.returncode, 1, result.stderr)
            self.assertIn(str(home / ".config/nvim"), result.stderr)
            self.assertEqual(sentinel.read_text(), "local changes\n")
            self.assertEqual(list(old.iterdir()), [sentinel])


if __name__ == "__main__":
    unittest.main()
