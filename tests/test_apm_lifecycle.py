"""APM ownership and plugin layout contracts using inert sources in a private HOME."""
import json
import hashlib
import importlib.util
from unittest.mock import patch
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


@unittest.skipUnless(shutil.which("apm"), "installed APM CLI is required")
class ApmLifecycleTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="apm-contract-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.home = self.root / "home"
        self.home.mkdir()
        (self.home / ".apm").mkdir()
        self.apm = shutil.which("apm")
        (self.home / ".cache/apm").mkdir(parents=True)
        (self.home / ".cache/apm/last_version_check").touch()
        self.env = {"HOME": str(self.home), "USER": "fixture", "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
                    "VERSION": "0.29.0", "APM_NO_DIRECT_FALLBACK": "1", "LANG": "en_US.UTF-8", "TMPDIR": str(self.root), "NO_COLOR": "1", "CI": "1",
                    "XDG_CONFIG_HOME": str(self.home / ".config"), "XDG_CACHE_HOME": str(self.home / ".cache"),
                    "XDG_DATA_HOME": str(self.home / ".local/share"),
                    "CODEX_HOME": str(self.home / ".codex"), "CLAUDE_CONFIG_DIR": str(self.home / ".claude")}

    def skill(self, path, name, body="No actions.\n"):
        path.mkdir(parents=True)
        (path / "SKILL.md").write_text(f"---\nname: {name}\ndescription: Inert fixture, never execute.\n---\n{body}")
        return path

    def install(self, packages, targets=None):
        restriction = "\n      targets: [" + ", ".join(targets) + "]" if targets else ""
        dependencies = "\n".join("    - path: " + str(path) + restriction for path in packages) if packages else "    []"
        (self.home / ".apm/apm.yml").write_text(
            "name: lifecycle-fixture\nversion: 0.1.0\ntargets: [claude, codex, agent-skills]\n"
            "dependencies:\n  apm:\n" + dependencies + "\n")
        run = subprocess.run([self.apm, "install", "-g"], cwd=self.home, env=self.env,
                             capture_output=True, text=True, timeout=30)
        self.assertEqual(0, run.returncode, run.stdout + run.stderr)

    def test_full_global_install_removes_dropped_owned_skills_and_preserves_unmanaged_files(self):
        keep = self.skill(self.root / "keep", "keep")
        gone = self.skill(self.root / "gone", "gone")
        self.install([keep, gone])
        shared = self.home / ".agents/skills"
        self.assertTrue((shared / "gone/SKILL.md").is_file())
        unmanaged = self.skill(shared / "unmanaged", "unmanaged")

        self.install([keep])

        self.assertFalse((shared / "gone/SKILL.md").exists())
        self.assertFalse((self.home / ".claude/skills/gone/SKILL.md").exists())
        self.assertTrue((shared / "keep/SKILL.md").is_file())
        self.assertTrue((unmanaged / "SKILL.md").is_file())

        self.install([])
        self.assertFalse((shared / "keep/SKILL.md").exists())
        self.assertTrue((unmanaged / "SKILL.md").is_file())

    def test_compatibility_entries_remain_owned_across_real_apm_resync_and_removal(self):
        spec = importlib.util.spec_from_file_location("pstack_hooks", Path(__file__).resolve().parents[1] / "scripts/apm-pstack-hooks.py")
        hooks_module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(hooks_module)
        plugin = self.root / "pstack"
        self.skill(plugin / "skills/poteto-mode", "poteto-mode")
        (plugin / ".claude-plugin").mkdir()
        (plugin / ".claude-plugin/plugin.json").write_text('{"name":"pstack","version":"0.9.114"}')
        hashes = {}
        for relative in hooks_module.HASHES:
            path = plugin / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("inert fixture; never execute\n")
            hashes[relative] = hashlib.sha256(path.read_bytes()).hexdigest()
        for runtime, filename in (("codex", "codex-hooks.json"), ("claude", "hooks.json")):
            (plugin / "hooks" / filename).write_text(json.dumps({"hooks": {"SessionStart": [
                {"matcher": "startup|resume|clear|compact", "hooks": [{"type": "command", "command": '\"${CLAUDE_PLUGIN_ROOT}/hooks/session-start.sh\" ' + runtime}]}]}}))
        settings = self.home / ".claude/settings.json"
        settings.parent.mkdir()
        unrelated = {"matcher": "startup", "hooks": [{"type": "command", "command": "unrelated-never-execute"}]}
        settings.write_text(json.dumps({"hooks": {"SessionStart": [unrelated]}}))
        with patch.object(hooks_module, "HASHES", hashes):
            for repeat in range(2):
                root = self.home / ".apm/apm_modules/_local/pstack"
                if repeat:
                    for path, document in hooks_module.plan(self.home, root, "_local/pstack"):
                        path.write_text(json.dumps(document))
                self.install([plugin])
                changes = hooks_module.plan(self.home, root, "_local/pstack")
                for path, document in changes:
                    path.write_text(json.dumps(document))
                if not repeat:
                    sidecar = self.home / ".codex/apm-hooks.json"
                    original = json.loads(sidecar.read_text())
                    original["SessionStart"][0]["hooks"][0]["command"] = f'"{self.home / ".codex/hooks/pstack/hooks/session-start.sh"}" codex'
                    sidecar.write_text(json.dumps(original))
                for runtime, filename in (("codex", "hooks.json"), ("claude", "settings.json")):
                    data = json.loads((self.home / ("." + runtime) / filename).read_text())
                    commands = [hook["command"] for entry in data["hooks"]["SessionStart"] for hook in entry["hooks"]]
                    self.assertEqual(1, sum(command.startswith("env CLAUDE_PLUGIN_ROOT=") for command in commands))
                    self.assertEqual(1 if runtime == "codex" else 2, len(commands))
            removal = subprocess.run([self.apm, "uninstall", "-g", "_local/pstack"], cwd=self.home, env=self.env, capture_output=True, text=True, timeout=30)
            self.assertEqual(0, removal.returncode, removal.stdout + removal.stderr)
        self.assertEqual([unrelated], json.loads(settings.read_text())["hooks"]["SessionStart"])
        self.assertEqual([], json.loads((self.home / ".codex/hooks.json").read_text()).get("hooks", {}).get("SessionStart", []))

    def test_plugin_components_deploy_without_running_hooks_or_registering_native_plugin(self):
        plugin = self.root / "pstack-fixture"
        self.skill(plugin / "skills/poteto-mode", "poteto-mode", "Invoke pstack:tdd.\n[Sibling](../tdd/SKILL.md)\n")
        self.skill(plugin / "skills/tdd", "tdd")
        (plugin / ".claude-plugin").mkdir()
        (plugin / ".claude-plugin/plugin.json").write_text('{"name":"pstack-fixture","version":"1.0.0"}')
        (plugin / "agents").mkdir()
        (plugin / "agents/poteto-agent.md").write_text("---\nname: poteto-agent\ndescription: Inert fixture\n---\nNo actions.\n")
        (plugin / "hooks").mkdir()
        (plugin / "hooks/codex-hooks.json").write_text(json.dumps({"hooks": {"SessionStart": [
            {"hooks": [{"type": "command", "command": "__NO_SUCH_EXECUTABLE_HOOK__"}]}]}}))

        self.install([plugin])

        self.assertTrue((self.home / ".agents/skills/poteto-mode/SKILL.md").is_file())
        self.assertIn("pstack:tdd", (self.home / ".agents/skills/poteto-mode/SKILL.md").read_text())
        self.assertTrue((self.home / ".claude/agents/poteto-agent.md").is_file())
        self.assertTrue((self.home / ".codex/agents/poteto-agent.toml").is_file())
        hooks = json.loads((self.home / ".codex/hooks.json").read_text())
        self.assertEqual("__NO_SUCH_EXECUTABLE_HOOK__", hooks["hooks"]["SessionStart"][0]["hooks"][0]["command"])
        self.assertFalse((self.home / ".codex/plugins").exists())

    # 正常系: rootのAntigravity定義があってもCodex専用hookだけを選ぶ。
    def test_codex_dependency_target_excludes_competing_hooks_and_claude_outputs(self):
        # Arrange
        plugin = self.root / "multi-client-plugin"
        self.skill(plugin / "skills/poteto-mode", "poteto-mode")
        for directory in (".github/plugin", ".claude-plugin", "hooks", "agents"):
            (plugin / directory).mkdir(parents=True, exist_ok=True)
        (plugin / ".github/plugin/plugin.json").write_text(json.dumps({"name": "multi-client-plugin", "hooks": "hooks/copilot-hooks.json"}))
        (plugin / ".claude-plugin/plugin.json").write_text('{"name":"multi-client-plugin"}')
        (plugin / ".antigravity-plugin").mkdir()
        (plugin / ".antigravity-plugin/plugin.json").write_text('{"name":"multi-client-plugin","version":"1.0.0"}')
        (plugin / "hooks.json").write_text(json.dumps({"pstack-routing": {"SessionStart": [
            {"type": "command", "command": "__ANTIGRAVITY_MUST_NOT_EXECUTE__"}]} }))
        (plugin / "agents/poteto-agent.md").write_text("---\nname: poteto-agent\ndescription: Inert fixture\n---\nNo actions.\n")
        for filename, events in [("copilot-hooks.json", ["SessionStart", "PreToolUse"]), ("codex-hooks.json", ["SessionStart"])]:
            command = "__CODEX_MUST_NOT_EXECUTE__" if filename.startswith("codex") else "__COPILOT_MUST_NOT_EXECUTE__"
            (plugin / "hooks" / filename).write_text(json.dumps({"hooks": {event: [{"hooks": [{"type": "command", "command": command}]}] for event in events}}))

        # Act
        self.install([plugin], targets=["codex"])

        # Assert
        # 他runtimeのhookやClaude出力を追加せず、既存のCodex定義を使う。
        hooks = json.loads((self.home / ".codex/hooks.json").read_text())["hooks"]
        self.assertEqual({"SessionStart"}, set(hooks))
        self.assertEqual("__CODEX_MUST_NOT_EXECUTE__", hooks["SessionStart"][0]["hooks"][0]["command"])
        self.assertTrue((self.home / ".agents/skills/poteto-mode/SKILL.md").is_file())
        self.assertTrue((self.home / ".codex/agents/poteto-agent.toml").is_file())
        self.assertFalse((self.home / ".claude/apm-hooks.json").exists())
        self.assertFalse((self.home / ".claude/agents").exists())
        self.assertFalse((self.home / ".claude/skills").exists())
        self.assertFalse((self.home / ".github/hooks").exists())

    # 正常系: OMP packageやGrok専用skillが加わってもCodexの配布範囲を広げない。
    def test_codex_target_ignores_other_clients_routing_skill_and_extension(self):
        # Arrange
        plugin = self.root / "multi-client-plugin"
        self.skill(plugin / "skills/poteto-mode", "poteto-mode")
        self.skill(plugin / "grok/skills/pstack-routing", "pstack-routing")
        for directory in (".claude-plugin", ".codex-plugin", ".grok-plugin", "hooks", "omp"):
            (plugin / directory).mkdir(parents=True, exist_ok=True)
        (plugin / ".claude-plugin/plugin.json").write_text('{"name":"multi-client-plugin"}')
        (plugin / ".codex-plugin/plugin.json").write_text(json.dumps({
            "name": "multi-client-plugin", "skills": "./skills/", "hooks": "./hooks/codex-hooks.json"}))
        (plugin / ".grok-plugin/plugin.json").write_text(json.dumps({
            "name": "multi-client-plugin", "skills": ["./skills", "./grok/skills"]}))
        (plugin / "package.json").write_text(json.dumps({
            "name": "multi-client-plugin", "version": "1.0.0", "private": True,
            "omp": {"extensions": ["./omp/index.mjs"]}}))
        (plugin / "omp/index.mjs").write_text('throw new Error("OMP must not execute");\n')
        (plugin / "hooks/codex-hooks.json").write_text(json.dumps({"hooks": {"SessionStart": [
            {"hooks": [{"type": "command", "command": "__CODEX_MUST_NOT_EXECUTE__"}]}]}}))

        # Act
        self.install([plugin], targets=["codex"])

        # Assert
        # 共通skillとCodex hookだけを公開し、Grok routingやOMPの導入は行わない。
        shared = self.home / ".agents/skills"
        self.assertEqual({"poteto-mode"}, {path.name for path in shared.iterdir()})
        self.assertTrue((shared / "poteto-mode/SKILL.md").is_file())
        hooks = json.loads((self.home / ".codex/hooks.json").read_text())["hooks"]
        self.assertEqual({"SessionStart"}, set(hooks))
        self.assertEqual("__CODEX_MUST_NOT_EXECUTE__", hooks["SessionStart"][0]["hooks"][0]["command"])
        self.assertFalse((self.home / ".omp").exists())
        self.assertFalse((self.home / ".grok").exists())
        self.assertFalse((self.home / ".claude/skills").exists())


if __name__ == "__main__":
    unittest.main()
