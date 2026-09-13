"""Exercise the real mise dotfile engine against an isolated home directory."""

import os
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


REPOSITORY = Path(__file__).resolve().parents[1]
MISE = os.environ.get("MISE_BIN", shutil.which("mise"))


class DotfileDeploymentTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="dotfiles test ")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()
        self.home = self.root / "home with spaces"
        self.home.mkdir()
        self.repo = self.root / "repository"
        self.repo.mkdir()
        if (REPOSITORY / "mise.toml").exists():
            shutil.copy(REPOSITORY / "mise.toml", self.repo / "mise.toml")
        if (REPOSITORY / "home").exists():
            shutil.copytree(REPOSITORY / "home", self.repo / "home", symlinks=True)
        self.env = {
            "PATH": os.environ["PATH"],
            "HOME": str(self.home),
            "MISE_CONFIG_DIR": str(self.home / ".config/mise"),
            "MISE_DATA_DIR": str(self.root / "data"),
            "MISE_CACHE_DIR": str(self.root / "cache"),
            "MISE_STATE_DIR": str(self.root / "state"),
            "MISE_SYSTEM_CONFIG_DIR": str(self.root / "system"),
            "MISE_TRUSTED_CONFIG_PATHS": str(self.root),
            "MISE_YES": "1",
            "MISE_COLOR": "0",
        }

    def apply(self, *targets, dry_run=False):
        command = [MISE, "bootstrap", "dotfiles", "apply", "--yes"]
        if dry_run:
            command.append("--dry-run")
        return subprocess.run(
            command + list(targets), cwd=self.repo, env=self.env,
            text=True, capture_output=True, timeout=30,
        )

    def test_shell_configuration_is_linked_and_reapplication_keeps_the_link(self):
        # Arrange: HOME contains no managed configuration.
        target = self.home / ".zshrc"

        # Act: use the real deployment command twice.
        first = self.apply("~/.zshrc")
        second = self.apply("~/.zshrc")

        # Assert: edits reach the repository, including when HOME contains spaces.
        self.assertEqual(first.returncode, 0, first.stderr)
        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertTrue(target.is_symlink())
        self.assertEqual(target.resolve(), self.repo / "home/.zshrc")

    def test_conflicting_regular_file_is_preserved(self):
        # Arrange: a user-owned file must not be replaced implicitly.
        target = self.home / ".zshrc"
        target.write_text("local configuration\n")

        # Act: request the same deployment without --force.
        result = self.apply("~/.zshrc")

        # Assert: conflict is observable and the original content survives.
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(target.is_symlink())
        self.assertEqual(target.read_text(), "local configuration\n")

    def test_dry_run_does_not_create_the_target(self):
        # Arrange: start without a shell configuration.
        target = self.home / ".zshrc"

        # Act: preview deployment.
        result = self.apply("~/.zshrc", dry_run=True)

        # Assert: preview has no deployment side effect.
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(target.exists())

    def test_agent_manifests_do_not_capture_installed_skills_or_apm_state(self):
        # Arrange: these writable directories contain application-owned state.
        skills = self.home / ".agents/skills/local/SKILL.md"
        state = self.home / ".apm/config.json"
        skills.parent.mkdir(parents=True)
        state.parent.mkdir(parents=True)
        skills.write_text("local skill\n")
        state.write_text('{"local": true}\n')

        # Act: deploy only the shared instructions and dependency manifest.
        result = self.apply("~/.agents/AGENTS.md", "~/.apm/apm.yml")

        # Assert: only the declared files are linked; runtime state stays local.
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.home / ".agents/AGENTS.md").is_symlink())
        self.assertTrue((self.home / ".apm/apm.yml").is_symlink())
        self.assertFalse((self.home / ".agents").is_symlink())
        self.assertFalse((self.home / ".apm").is_symlink())
        self.assertEqual(skills.read_text(), "local skill\n")
        self.assertEqual(state.read_text(), '{"local": true}\n')

    def test_shared_commands_exclude_the_macos_container_wrapper(self):
        # Arrange: the shared command directory is used on both supported OSes.
        target = self.home / ".local/bin"

        # Act: deploy only the cross-platform directory entry.
        result = self.apply("~/.local/bin")

        # Assert: Apple container requires its separate platform-specific entry.
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((target / "codex").is_symlink())
        self.assertFalse((target / "container").exists())

    def test_mise_activation_keeps_wrappers_ahead_of_raw_tools(self):
        # Arrange: the global config is deployed into an otherwise empty HOME.
        result = self.apply("~/.config/mise/config.toml")
        self.assertEqual(result.returncode, 0, result.stderr)

        # Act: ask the real mise engine for the environment used by activation.
        result = subprocess.run(
            [MISE, "--cd", "/", "env", "--json"], env=self.env,
            text=True, capture_output=True, timeout=60,
        )

        # Assert: each prompt/directory-change activation preserves wrappers.
        self.assertEqual(result.returncode, 0, result.stderr)
        path = json.loads(result.stdout)["PATH"].split(os.pathsep)
        self.assertEqual(path[0], str(self.home / ".local/bin"))


if __name__ == "__main__":
    unittest.main()
