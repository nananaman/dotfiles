"""Public routing contracts against a fake native configuration service."""
import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import tomllib
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("codex_routing", ROOT / "scripts/codex-routing.py")
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def toml_value(value):
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, dict):
        return "{ " + ", ".join(json.dumps(k) + " = " + toml_value(v) for k, v in value.items()) + " }"
    if isinstance(value, list):
        return "[" + ", ".join(toml_value(v) for v in value) + "]"
    return json.dumps(value)


class FakeConfig:
    def __init__(self, home):
        self.path = home / "config.toml"
        self.calls = []
        self.version = "fixture-v1"
        self.fail_write = False
        self.omit_empty_tables = False

    def save(self, data):
        self.path.write_text("\n".join(json.dumps(k) + " = " + toml_value(v) for k, v in data.items()) + "\n")

    def read(self):
        return tomllib.loads(self.path.read_text())

    def __call__(self, codex, home):
        return self

    def __enter__(self):
        return self

    def __exit__(self, *args):
        return False

    def request(self, method, params):
        self.calls.append((method, copy.deepcopy(params)))
        if method == "config/read":
            return {"layers": [{"name": {"type": "user", "file": str(self.path), "profile": None},
                                "version": self.version, "config": self.read(), "disabledReason": None}]}
        if method != "config/batchWrite":
            raise AssertionError(method)
        if self.fail_write:
            raise MODULE.RoutingError("native config write rejected")
        assert params["filePath"] == str(self.path)
        assert params["expectedVersion"] == self.version
        assert params["reloadUserConfig"] is False
        data = self.read()
        for edit in params["edits"]:
            assert edit["mergeStrategy"] == "replace"
            keys = edit["keyPath"].split(".")
            target = data
            for key in keys[:-1]:
                target = target.setdefault(key, {})
            if edit["value"] is None:
                target.pop(keys[-1], None)
            else:
                target[keys[-1]] = edit["value"]
        if self.omit_empty_tables:
            for table in ("agents", "features"):
                if data.get(table) == {}:
                    data.pop(table)
        self.save(data)
        self.version = "fixture-v2"
        return {"status": "ok", "filePath": str(self.path), "version": self.version}


class CodexRoutingContractTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.home = self.root / "codex home"
        self.home.mkdir()
        self.user_home = self.root / "user home"
        self.manifest = self.root / "agent-plugins.toml"
        self.manifest.write_text('''version = 1
[marketplaces.demo]
kind = "local"
source = "."
[[plugins]]
selector = "pstack@demo"
runtime = "codex"
expected_version = "1.0.0"
[codex_routing]
legacy_plugin = "legacy@demo"
legacy_apm_skills = ["implement", "tdd"]
''')
        self.api = FakeConfig(self.home)
        self.unrelated = {"path": str(self.user_home / ".agents/skills/vendor/SKILL.md"), "enabled": True}
        self.original = {"model": "keep", "hooks": {"state": {"sentinel": {"trusted_hash": "keep"}}},
                         "plugins": {"legacy@demo": {"enabled": True}, "other@market": {"enabled": True}},
                         "skills": {"config": [self.unrelated]}}
        self.api.save(self.original)
        self.readiness_calls = []

    def ready(self, *args, **kwargs):
        self.readiness_calls.append((args, kwargs))
        return {"status": "noop"}

    def run_route(self, mode="plan", **kwargs):
        return MODULE.route(self.manifest, self.home, mode=mode, user_home=self.user_home,
                            client_factory=self.api, readiness=self.ready, **kwargs)

    def test_default_plan_preserves_files_and_does_not_start_native_configuration(self):
        before = (self.home / "config.toml").read_bytes()

        result = self.run_route()

        self.assertEqual("planned", result["status"])
        self.assertEqual(before, (self.home / "config.toml").read_bytes())
        self.assertEqual([], self.api.calls)
        self.assertEqual([], self.readiness_calls)
        self.assertFalse((self.home / MODULE.RECEIPT_NAME).exists())

    def test_apply_requires_verified_plugins_before_mutating_discovery(self):
        before = (self.home / "config.toml").read_bytes()
        with self.assertRaisesRegex(MODULE.RoutingError, "plugins"):
            MODULE.route(self.manifest, self.home, mode="apply", user_home=self.user_home,
                         client_factory=self.api, readiness=lambda *a, **k: {"status": "planned"})
        self.assertEqual(before, (self.home / "config.toml").read_bytes())
        self.assertEqual([], self.api.calls)

    def test_apply_changes_only_owned_codex_discovery_and_is_idempotent(self):
        claude = self.user_home / ".claude/skills/implement/SKILL.md"
        claude.parent.mkdir(parents=True)
        claude.write_text("keep legacy client capability")

        result = self.run_route("apply")

        self.assertEqual("applied", result["status"])
        data = self.api.read()
        self.assertFalse(data["plugins"]["legacy@demo"]["enabled"])
        self.assertEqual(self.original["hooks"], data["hooks"])
        self.assertTrue(data["plugins"]["other@market"]["enabled"])
        self.assertEqual("keep", data["model"])
        self.assertTrue(data["features"]["multi_agent"])
        self.assertTrue(data["agents"]["enabled"])
        self.assertEqual(2, data["agents"]["max_threads"])
        self.assertEqual(self.unrelated, data["skills"]["config"][0])
        self.assertEqual(2, len([r for r in data["skills"]["config"] if r.get("enabled") is False]))
        self.assertEqual("keep legacy client capability", claude.read_text())
        calls = len(self.api.calls)
        self.assertEqual("noop", self.run_route("apply")["status"])
        self.assertEqual(calls, len(self.api.calls))

    def test_folder_and_file_aliases_are_both_disabled_without_duplicate_entries(self):
        data = copy.deepcopy(self.original)
        data["skills"]["config"] += [
            {"path": str(self.user_home / ".agents/skills/tdd"), "enabled": True},
            {"path": str(self.user_home / ".agents/skills/tdd/SKILL.md"), "enabled": True}]
        self.api.save(data)

        self.run_route("apply")

        rows = self.api.read()["skills"]["config"]
        self.assertEqual(4, len(rows))
        self.assertTrue(rows[0]["enabled"])
        self.assertTrue(all(row["enabled"] is False for row in rows[1:]))

    def test_failed_native_write_preserves_configuration_and_keeps_receipt_for_inspection(self):
        self.api.fail_write = True
        before = (self.home / "config.toml").read_bytes()
        with self.assertRaises(MODULE.RoutingError):
            self.run_route("apply")
        self.assertEqual(before, (self.home / "config.toml").read_bytes())
        self.assertTrue((self.home / MODULE.RECEIPT_NAME).exists())

    def test_rollback_restores_owned_values_and_keeps_later_unrelated_changes(self):
        self.run_route("apply")
        data = self.api.read()
        later = {"path": "/later/skill", "enabled": True}
        data["skills"]["config"].append(later)
        data["model"] = "later-model"
        self.api.save(data)

        result = self.run_route("rollback")

        self.assertEqual("rolled_back", result["status"])
        data = self.api.read()
        self.assertTrue(data["plugins"]["legacy@demo"]["enabled"])
        self.assertEqual([self.unrelated, later], data["skills"]["config"])
        self.assertEqual("later-model", data["model"])
        self.assertEqual(self.original["hooks"], data["hooks"])
        self.assertNotIn("multi_agent", data.get("features", {}))
        self.assertNotIn("max_threads", data.get("agents", {}))

    def test_rollback_refuses_to_overwrite_a_later_owned_setting_change(self):
        self.run_route("apply")
        data = self.api.read()
        data["plugins"]["legacy@demo"]["enabled"] = True
        self.api.save(data)
        before = (self.home / "config.toml").read_bytes()
        with self.assertRaisesRegex(MODULE.RoutingError, "changed"):
            self.run_route("rollback")
        self.assertEqual(before, (self.home / "config.toml").read_bytes())

    def test_receipt_contains_only_owned_routing_values_and_uses_private_permissions(self):
        self.run_route("apply")
        path = self.home / MODULE.RECEIPT_NAME
        receipt = json.loads(path.read_text())
        self.assertNotIn("hooks", receipt["before"])
        self.assertNotIn("model", receipt["before"])
        self.assertEqual(0o600, path.stat().st_mode & 0o777)

    def test_symlinked_configuration_is_never_changed(self):
        path = self.home / "config.toml"
        other = self.root / "other.toml"
        path.rename(other)
        path.symlink_to(other)
        with self.assertRaisesRegex(MODULE.RoutingError, "symlink"):
            self.run_route("apply")
        self.assertEqual(self.original, tomllib.loads(other.read_text()))

    def test_cli_apply_requires_explicit_home_before_starting_any_native_command(self):
        result = subprocess.run([sys.executable, str(ROOT / "scripts/codex-routing.py"), "apply",
                                 "--manifest", str(self.manifest), "--codex", "/nonexistent"],
                                capture_output=True, text=True, check=False)
        self.assertEqual(2, result.returncode)
        self.assertIn("--codex-home", result.stderr)

    def test_native_transport_initializes_with_hooks_disabled_and_no_model_requests(self):
        executable = self.root / "fake-codex"
        executable.write_text("#!" + sys.executable + "\n" + '''import json, os, sys
from pathlib import Path
log = Path(__file__).with_suffix(".json")
calls = []
for line in sys.stdin:
    request = json.loads(line)
    calls.append({"method": request["method"], "argv": sys.argv[1:], "codex_home": os.environ["CODEX_HOME"]})
    log.write_text(json.dumps(calls))
    if "id" in request:
        result = {"sample": "config"} if request["method"] == "config/read" else {}
        print(json.dumps({"id": request["id"], "result": result}), flush=True)
''')
        executable.chmod(0o755)

        with MODULE.NativeConfig(str(executable), self.home) as client:
            result = client.request("config/read", {"includeLayers": True})

        self.assertEqual({"sample": "config"}, result)
        calls = json.loads(executable.with_suffix(".json").read_text())
        self.assertEqual(["initialize", "initialized", "config/read"], [r["method"] for r in calls])
        self.assertTrue(all(r["argv"] == ["--disable", "hooks", "app-server", "--listen", "stdio://"] for r in calls))
        self.assertTrue(all(r["codex_home"] == str(self.home) for r in calls))

    def test_completed_receipt_cannot_rollback_later_owned_changes(self):
        self.run_route("apply")
        applied = self.api.read()
        self.run_route("rollback")
        self.api.save(applied)
        before = (self.home / "config.toml").read_bytes()

        with self.assertRaisesRegex(MODULE.RoutingError, "completed rollback"):
            self.run_route("rollback")

        self.assertEqual(before, (self.home / "config.toml").read_bytes())

    def test_explicit_rollback_closes_unchanged_failed_apply_before_retry(self):
        self.api.fail_write = True
        with self.assertRaises(MODULE.RoutingError):
            self.run_route("apply")
        self.api.fail_write = False
        before = (self.home / "config.toml").read_bytes()

        self.assertEqual("noop", self.run_route("rollback")["status"])

        self.assertEqual(before, (self.home / "config.toml").read_bytes())
        receipt = json.loads((self.home / MODULE.RECEIPT_NAME).read_text())
        self.assertEqual("rolled_back", receipt["status"])
        self.assertEqual("applied", self.run_route("apply")["status"])

    def test_rollback_accepts_native_removal_of_empty_runtime_tables(self):
        self.api.omit_empty_tables = True
        self.run_route("apply")

        result = self.run_route("rollback")

        self.assertEqual("rolled_back", result["status"])
        self.assertEqual(self.original, self.api.read())

    def test_completed_rollback_can_be_applied_again_without_manual_state_changes(self):
        self.run_route("apply")
        self.run_route("rollback")

        result = self.run_route("apply")

        self.assertEqual("applied", result["status"])
        self.assertEqual("noop", self.run_route("apply")["status"])
        self.assertEqual("rolled_back", self.run_route("rollback")["status"])

    def test_unresolved_receipt_cannot_be_overwritten_by_a_retry(self):
        self.api.fail_write = True
        with self.assertRaises(MODULE.RoutingError):
            self.run_route("apply")
        receipt = (self.home / MODULE.RECEIPT_NAME).read_bytes()
        self.api.fail_write = False

        with self.assertRaisesRegex(MODULE.RoutingError, "completed rollback"):
            self.run_route("apply")

        self.assertEqual(receipt, (self.home / MODULE.RECEIPT_NAME).read_bytes())
        self.assertEqual(self.original, self.api.read())

    def test_name_only_skill_entries_are_preserved_during_apply_and_rollback(self):
        data = copy.deepcopy(self.original)
        named = {"name": "vendor-skill", "enabled": False}
        data["skills"]["config"].append(named)
        self.api.save(data)
        self.assertEqual("planned", self.run_route()["status"])
        self.run_route("apply")
        later = {"name": "another-vendor", "enabled": True}
        data = self.api.read()
        data["skills"]["config"].append(later)
        self.api.save(data)

        self.run_route("rollback")

        self.assertEqual([self.unrelated, named, later], self.api.read()["skills"]["config"])

    def test_existing_canonical_thread_limit_is_updated_without_adding_its_alias(self):
        data = copy.deepcopy(self.original)
        data["agents"] = {"max_concurrent_threads_per_session": 7, "default_subagent_model": "keep"}
        self.api.save(data)

        self.run_route("apply")
        after = self.api.read()
        self.assertEqual(2, after["agents"]["max_concurrent_threads_per_session"])
        self.assertNotIn("max_threads", after["agents"])
        self.assertEqual("keep", after["agents"]["default_subagent_model"])

        self.run_route("rollback")
        self.assertEqual(data["agents"], self.api.read()["agents"])


if __name__ == "__main__":
    unittest.main()
