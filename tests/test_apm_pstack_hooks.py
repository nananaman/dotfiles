"""Compatibility changes affect only APM-owned, unmodified pstack entries."""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import shlex
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("pstack_hooks", ROOT / "scripts/apm-pstack-hooks.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class PstackHookCompatibilityTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="pstack hooks '")
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name).resolve()
        self.package = self.home / "package with spaces"
        self.script = b"#!/bin/sh\nprintf '%s' \"$CLAUDE_PLUGIN_ROOT\"\n"
        hashes = {}
        for relative in module.HASHES:
            path = self.package / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            data = self.script if relative.endswith("session-start.sh") else b"inert fixture"
            path.write_bytes(data)
            hashes[relative] = hashlib.sha256(data).hexdigest()
        manifest = self.package / ".claude-plugin/plugin.json"
        manifest.parent.mkdir()
        manifest.write_text('{"name":"pstack","version":"0.9.114"}')
        self.addCleanup(patch.stopall)
        patch.object(module, "HASHES", hashes).start()
        self.unrelated = {"matcher": "startup", "hooks": [{"type": "command", "command": "unrelated-do-not-run"}]}
        for runtime, filename in (("codex", "hooks.json"), ("claude", "settings.json")):
            folder = self.home / ("." + runtime)
            exported = folder / "hooks/pstack/hooks/session-start.sh"
            exported.parent.mkdir(parents=True)
            exported.write_bytes(self.script)
            exported.chmod(0o700)
            entry = {"matcher": "startup|resume|clear|compact", "hooks": [{"type": "command", "command": f'"{exported}" {runtime}'}]}
            (folder / filename).write_text(json.dumps({"unrelated": {"enabled": False}, "hooks": {"SessionStart": [self.unrelated, entry], "Stop": [self.unrelated]}}))
            owned = {**copy.deepcopy(entry), "_apm_source": module.SOURCE}
            (folder / "apm-hooks.json").write_text(json.dumps({"SessionStart": [{**self.unrelated, "_apm_source": "unrelated"}, owned]}))

    def apply(self):
        for path, content in module.plan(self.home, self.package):
            path.write_text(json.dumps(content))

    def test_supplies_root_without_executing_hooks_and_is_idempotent(self):
        before = {p: p.read_bytes() for p in self.home.rglob("*.json")}
        changes = module.plan(self.home, self.package)
        self.assertEqual(before, {p: p.read_bytes() for p in self.home.rglob("*.json")})
        self.assertEqual(4, len(changes))

        self.apply()

        self.assertEqual([], module.plan(self.home, self.package))
        for runtime, filename in (("codex", "hooks.json"), ("claude", "settings.json")):
            document = json.loads((self.home / ("." + runtime) / filename).read_text())
            self.assertEqual({"enabled": False}, document["unrelated"])
            self.assertEqual([self.unrelated], document["hooks"]["Stop"])
            self.assertEqual(self.unrelated, document["hooks"]["SessionStart"][0])
            command = document["hooks"]["SessionStart"][1]["hooks"][0]["command"]
            run = subprocess.run(["/bin/sh", "-c", command], capture_output=True, text=True, timeout=5)
            self.assertEqual(0, run.returncode, run.stderr)
            self.assertEqual(str(self.package), run.stdout)

    def test_unknown_source_or_modified_export_fails_without_writing(self):
        (self.package / "hooks/session-start.sh").write_text("changed upstream")
        before = {p: p.read_bytes() for p in self.home.rglob("*.json")}
        with self.assertRaisesRegex(ValueError, "source changed"):
            module.plan(self.home, self.package)
        self.assertEqual(before, {p: p.read_bytes() for p in self.home.rglob("*.json")})

    def test_modified_command_preserves_user_changes_and_prevents_all_writes(self):
        path = self.home / ".claude/settings.json"
        data = json.loads(path.read_text())
        data["hooks"]["SessionStart"][1]["hooks"][0]["command"] = "custom-user-command"
        path.write_text(json.dumps(data))
        before = {p: p.read_bytes() for p in self.home.rglob("*.json")}
        with self.assertRaisesRegex(ValueError, "differs from APM ownership"):
            module.plan(self.home, self.package)
        self.assertEqual(before, {p: p.read_bytes() for p in self.home.rglob("*.json")})

    def test_partial_config_first_write_is_recoverable(self):
        path, content = module.plan(self.home, self.package)[0]
        path.write_text(json.dumps(content))
        self.apply()
        self.assertEqual([], module.plan(self.home, self.package))

    def test_custom_claude_config_directory_is_updated_instead_of_default(self):
        custom = self.home / "custom claude"
        (self.home / ".claude").rename(custom)
        exported = custom / "hooks/pstack/hooks/session-start.sh"
        for filename in ("settings.json", "apm-hooks.json"):
            path = custom / filename
            path.write_text(path.read_text().replace(str(self.home / ".claude/hooks/pstack/hooks/session-start.sh"), str(exported)))
        changes = module.plan(self.home, self.package, claude_config_dir=str(custom))
        self.assertEqual({custom / "settings.json", custom / "apm-hooks.json"}, {path for path, _ in changes if path.parent == custom})
        self.assertFalse((self.home / ".claude").exists())

    def test_missing_pstack_ownership_does_not_report_success(self):
        with self.assertRaisesRegex(ValueError, "exports missing"):
            module.plan(self.home, self.package, source="absent")


if __name__ == "__main__":
    unittest.main()
