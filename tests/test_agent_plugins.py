"""Native plugin contracts with a fake CLI; no upstream code is executed."""

import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import tomllib
import unittest


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("agent_plugins", ROOT / "scripts/agent-plugins.py")
MODULE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)


class FakeCodex:
    def __init__(self):
        self.calls = []
        self.marketplaces = []
        self.installed = []
        self.remote_roots = {}
        self.revisions = {}
        self.trees = {}
        self.stages = {}
        self.primary_home = None
        self.fail_upgrade = False
        self.corrupt_install = False
        self.keep_wrong_revision = False
        self.strip_executable = False
        self.extra_skill = False
        self.concurrent_edit = False

    def snapshot(self, root):
        rows = []
        for path in sorted(root.rglob("*")):
            if path.is_file():
                data = path.read_bytes()
                digest = hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()
                mode = "100755" if path.stat().st_mode & 0o111 else "100644"
                rows.append(f"{mode} blob {digest}\t{path.relative_to(root).as_posix()}\0")
        self.trees[str(root)] = "".join(rows)

    def install(self, selector, home, markets):
        name, market = selector.split("@")
        row = next(item for item in markets if item["name"] == market)
        source = Path(row["root"]) / "plugins" / name
        metadata = json.loads((source / ".codex-plugin/plugin.json").read_text())
        cache = home / "plugins/cache" / market / name / metadata["version"]
        if cache.exists():
            shutil.rmtree(cache)
        shutil.copytree(source, cache)
        if self.corrupt_install:
            (cache / "skills/example/SKILL.md").write_text("corrupted cached skill")
        if self.strip_executable:
            (cache / "hooks/check.sh").chmod(0o644)
        if self.extra_skill:
            (cache / "skills/unexpected").mkdir(parents=True)
            (cache / "skills/unexpected/SKILL.md").write_text("unexpected discovery entry")
        entry = {"pluginId": selector, "name": name, "marketplaceName": market,
                 "version": metadata["version"], "installed": True, "enabled": True,
                 "marketplaceSource": row["marketplaceSource"]}
        self.installed = [item for item in self.installed if item["pluginId"] != selector] + [entry]
        config_file = home / "config.toml"
        config = tomllib.loads(config_file.read_text())
        if selector not in config.get("plugins", {}):
            with config_file.open("a") as file:
                file.write(f'\n[plugins."{selector}"]\nenabled = true\n')
        return json.dumps({"pluginId": selector, "version": metadata["version"], "installedPath": str(cache)})

    def __call__(self, command, env):
        self.calls.append((command, {"CODEX_HOME": env["CODEX_HOME"]}))
        if command[0] == "git":
            root = command[command.index("-C") + 1]
            return self.trees[root] if "ls-tree" in command else self.revisions[root] + "\n"
        home = Path(env["CODEX_HOME"])
        if self.primary_home is None:
            self.primary_home = home
        primary = home == self.primary_home
        markets = self.marketplaces if primary else self.stages.setdefault(str(home), [])
        if command[-4:] == ["plugin", "marketplace", "list", "--json"]:
            return json.dumps({"marketplaces": markets})
        if command[-3:] == ["plugin", "list", "--json"]:
            return json.dumps({"installed": self.installed if primary else [], "available": []})
        args = command[command.index("plugin") + 1:]
        if args[:2] == ["marketplace", "add"]:
            remote = args[2] in self.remote_roots
            source_root = self.remote_roots[args[2]] if remote else Path(args[2])
            name = json.loads((source_root / ".agents/plugins/marketplace.json").read_text())["name"]
            root = home / "marketplaces" / name if remote else source_root
            if remote:
                shutil.copytree(source_root, root)
                self.snapshot(root)
            kind = "git" if remote else "local"
            source = {"sourceType": kind, "source": args[2]}
            markets.append({"name": name, "root": str(root), "marketplaceSource": source})
            home.mkdir(exist_ok=True)
            with (home / "config.toml").open("a") as file:
                file.write(f'\n[marketplaces.{name}]\nsource_type = {json.dumps(kind)}\nsource = {json.dumps(args[2])}\n')
                if remote:
                    ref = args[args.index("--ref") + 1]
                    file.write(f'ref = {json.dumps(ref)}\n')
                    self.revisions[str(root)] = ref
            return json.dumps({"marketplaceName": name, "installedRoot": str(root), "alreadyAdded": False})
        if args[:2] == ["marketplace", "upgrade"]:
            if self.fail_upgrade:
                if self.concurrent_edit:
                    with (home / "config.toml").open("a") as file:
                        file.write('\n[user]\nkeep = "concurrent"\n')
                raise MODULE.SyncError("fixture upgrade failed")
            market = args[2]
            config = tomllib.loads((home / "config.toml").read_text())
            row = next(item for item in markets if item["name"] == market)
            if not self.keep_wrong_revision:
                source_root = self.remote_roots[row["marketplaceSource"]["source"]]
                shutil.rmtree(row["root"])
                shutil.copytree(source_root, row["root"])
                self.snapshot(Path(row["root"]))
                self.revisions[row["root"]] = config["marketplaces"][market]["ref"]
                (Path(row["root"]) / ".codex-marketplace-install.json").write_text(json.dumps({
                    "source_type": "git", "source": row["marketplaceSource"]["source"],
                    "ref_name": config["marketplaces"][market]["ref"], "sparse_paths": [],
                    "revision": config["marketplaces"][market]["ref"],
                }))
            for selector in list(config.get("plugins", {})):
                if selector.endswith("@" + market):
                    self.install(selector, home, markets)
            return json.dumps({"selectedMarketplaces": [market], "upgradedRoots": [row["root"]], "errors": []})
        if args[0] == "add":
            return self.install(args[1], home, markets)
        raise AssertionError(f"Unexpected command: {command}")


class NativePluginContractTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = self.root / "codex home"
        self.repo = self.root / "source"
        self.manifest = self.root / "agent-plugins.toml"
        self.manifest.write_text(
            'version = 1\n[marketplaces.demo]\nkind = "local"\n'
            f'source = {json.dumps(str(self.repo))}\n'
            '[[plugins]]\nselector = "demo@demo"\nruntime = "codex"\nexpected_version = "1.0.0"\n'
        )
        plugin = self.repo / "plugins/demo"
        (plugin / ".codex-plugin").mkdir(parents=True)
        (plugin / ".codex-plugin/plugin.json").write_text('{"name":"demo","version":"1.0.0"}')
        (plugin / "skills/example").mkdir(parents=True)
        (plugin / "skills/example/SKILL.md").write_text('---\nname: example\ndescription: fixture\n---\n')
        (plugin / "hooks").mkdir()
        (plugin / "hooks/check.sh").write_text("#!/bin/sh\nexit 0\n")
        (plugin / "hooks/check.sh").chmod(0o755)
        (self.repo / ".agents/plugins").mkdir(parents=True)
        (self.repo / ".agents/plugins/marketplace.json").write_text(json.dumps({
            "name": "demo", "plugins": [{"name": "demo", "source": {"source": "local", "path": "./plugins/demo"}}]
        }))
        self.cli = FakeCodex()

    def test_default_plan_lists_install_without_writing_target_home(self):
        result = MODULE.manage(self.manifest, self.home, runner=self.cli)

        self.assertEqual("planned", result["status"])
        self.assertEqual(["register", "install"], [item["action"] for item in result["actions"]])
        self.assertFalse(self.home.exists())
        self.assertEqual([], self.cli.calls)

    def test_sync_requires_explicit_target_before_any_command(self):
        with self.assertRaisesRegex(MODULE.SyncError, "explicit"):
            MODULE.manage(self.manifest, self.home, apply=True, runner=self.cli)

        self.assertEqual([], self.cli.calls)
        self.assertFalse(self.home.exists())

    def test_selected_sync_installs_and_preserves_unrelated_configuration_and_trust(self):
        self.home.mkdir()
        unrelated = 'model = "keep-model"\n[hooks.state.sentinel]\nenabled = true\n'
        (self.home / "config.toml").write_text(unrelated)
        (self.home / "hooks.json").write_text('{"existing":"keep"}')

        result = MODULE.manage(self.manifest, self.home, selectors=("demo@demo",), apply=True, runner=self.cli)

        self.assertEqual("synced", result["status"])
        self.assertTrue((self.home / "config.toml").read_text().startswith(unrelated))
        self.assertEqual('{"existing":"keep"}', (self.home / "hooks.json").read_text())
        self.assertTrue(all(command[1:3] == ["--disable", "hooks"] for command, _ in self.cli.calls))

        before = len(self.cli.calls)
        second = MODULE.manage(self.manifest, self.home, selectors=("demo@demo",), apply=True, runner=self.cli)

        self.assertEqual("noop", second["status"])
        self.assertTrue(all("add" not in command for command, _ in self.cli.calls[before:]))

    def test_unknown_selector_is_rejected_before_external_commands(self):
        with self.assertRaisesRegex(MODULE.SyncError, "unknown"):
            MODULE.manage(self.manifest, self.home, selectors=("other@demo",), apply=True, runner=self.cli)
        self.assertEqual([], self.cli.calls)

    def test_unpinned_or_credential_bearing_git_source_is_rejected_before_commands(self):
        for source, ref in [("https://github.com/example/demo.git", "main"),
                            ("https://secret@example.com/demo.git", "a" * 40)]:
            with self.subTest(source=source, ref=ref):
                text = self.manifest.read_text()
                self.manifest.write_text(text.replace('kind = "local"', 'kind = "git"')
                                         .replace(f'source = {json.dumps(str(self.repo))}',
                                                  f'source = {json.dumps(source)}\nref = {json.dumps(ref)}'))
                try:
                    with self.assertRaises(MODULE.SyncError):
                        MODULE.manage(self.manifest, self.home, runner=self.cli)
                    self.assertEqual([], self.cli.calls)
                finally:
                    self.manifest.write_text(text)

    def test_existing_marketplace_from_another_source_is_not_adopted_or_modified(self):
        self.cli.marketplaces = [{"name": "demo", "root": str(self.repo),
                                  "marketplaceSource": {"sourceType": "local", "source": "/other"}}]
        with self.assertRaisesRegex(MODULE.SyncError, "source"):
            MODULE.manage(self.manifest, self.home, selectors=("demo@demo",), apply=True, runner=self.cli)
        self.assertTrue(all("add" not in command for command, _ in self.cli.calls))

    def test_wrong_local_version_fails_before_registration(self):
        path = self.repo / "plugins/demo/.codex-plugin/plugin.json"
        path.write_text('{"name":"demo","version":"0.9.0"}')
        with self.assertRaisesRegex(MODULE.SyncError, "expected version"):
            MODULE.manage(self.manifest, self.home, selectors=("demo@demo",), apply=True, runner=self.cli)
        self.assertTrue(all("add" not in command for command, _ in self.cli.calls))

    def make_git_declaration(self, ref):
        self.manifest.write_text(
            'version = 1\n[marketplaces.demo]\nkind = "git"\n'
            f'source = "https://github.com/example/demo.git"\nref = "{ref}"\n'
            '[[plugins]]\nselector = "demo@demo"\nruntime = "codex"\nexpected_version = "1.0.0"\n'
        )
        self.cli.remote_roots["https://github.com/example/demo.git"] = self.repo

    def test_git_install_uses_full_ref_and_declaration_can_roll_back_the_revision(self):
        self.make_git_declaration("a" * 40)
        first = MODULE.manage(self.manifest, self.home, selectors=("demo@demo",), apply=True, runner=self.cli)
        self.assertEqual("synced", first["status"])
        registration = next(command for command, _ in self.cli.calls if "marketplace" in command and "add" in command)
        self.assertIn("--ref", registration)
        self.assertEqual("a" * 40, registration[registration.index("--ref") + 1])

        for ref in ["b" * 40, "a" * 40]:
            self.make_git_declaration(ref)
            before = len(self.cli.calls)
            result = MODULE.manage(self.manifest, self.home, selectors=("demo@demo",), apply=True, runner=self.cli)
            self.assertEqual("synced", result["status"])
            self.assertEqual(ref, self.cli.revisions[self.cli.marketplaces[0]["root"]])
            config = tomllib.loads((self.home / "config.toml").read_text())
            self.assertEqual(ref, config["marketplaces"]["demo"]["ref"])
            changes = [cmd for cmd, _ in self.cli.calls[before:] if "upgrade" in cmd]
            self.assertEqual(1, len(changes))
            self.assertEqual("demo", changes[0][-2])
            noop = MODULE.manage(self.manifest, self.home, selectors=("demo@demo",), apply=True, runner=self.cli)
            self.assertEqual("noop", noop["status"])

    def test_native_snapshot_metadata_with_wrong_revision_is_rejected(self):
        self.make_git_declaration("a" * 40)
        MODULE.manage(self.manifest, self.home, selectors=("demo@demo",), apply=True, runner=self.cli)
        root = Path(self.cli.marketplaces[0]["root"])
        metadata = {"source_type": "git", "source": "https://github.com/example/demo.git",
                    "ref_name": "a" * 40, "sparse_paths": [], "revision": "c" * 40}
        (root / ".codex-marketplace-install.json").write_text(json.dumps(metadata))

        with self.assertRaisesRegex(MODULE.SyncError, "metadata"):
            MODULE.manage(self.manifest, self.home, selectors=("demo@demo",), apply=True, runner=self.cli)

    def test_failed_revision_refresh_restores_only_the_written_ref(self):
        self.make_git_declaration("a" * 40)
        MODULE.manage(self.manifest, self.home, selectors=("demo@demo",), apply=True, runner=self.cli)
        with (self.home / "config.toml").open("a") as file:
            file.write('\n[plugins.unrelated]\nenabled = false\n')
        before = (self.home / "config.toml").read_bytes()
        self.make_git_declaration("b" * 40)
        self.cli.fail_upgrade = True

        with self.assertRaisesRegex(MODULE.SyncError, "upgrade failed"):
            MODULE.manage(self.manifest, self.home, selectors=("demo@demo",), apply=True, runner=self.cli)

        self.assertEqual(before, (self.home / "config.toml").read_bytes())
        self.assertEqual("a" * 40, self.cli.revisions[self.cli.marketplaces[0]["root"]])

    def test_cache_content_mismatch_is_not_reported_as_installed_success(self):
        self.cli.corrupt_install = True
        with self.assertRaisesRegex(MODULE.SyncError, "content differs"):
            MODULE.manage(self.manifest, self.home, selectors=("demo@demo",), apply=True, runner=self.cli)
        self.assertFalse((self.home / ".dotfiles-plugin-sync.lock").exists())

    def test_checkout_mismatch_after_refresh_stops_before_plugin_install(self):
        self.make_git_declaration("a" * 40)
        MODULE.manage(self.manifest, self.home, selectors=("demo@demo",), apply=True, runner=self.cli)
        self.cli.revisions[self.cli.marketplaces[0]["root"]] = "c" * 40
        self.cli.keep_wrong_revision = True
        before = len(self.cli.calls)

        with self.assertRaisesRegex(MODULE.SyncError, "full SHA"):
            MODULE.manage(self.manifest, self.home, selectors=("demo@demo",), apply=True, runner=self.cli)

        self.assertTrue(all(cmd[3:5] != ["plugin", "add"] for cmd, _ in self.cli.calls[before:]))

    def test_existing_sync_lock_is_preserved_and_no_commands_run(self):
        self.home.mkdir()
        lock = self.home / ".dotfiles-plugin-sync.lock"
        lock.write_text("another operation")
        with self.assertRaisesRegex(MODULE.SyncError, "lock"):
            MODULE.manage(self.manifest, self.home, selectors=("demo@demo",), apply=True, runner=self.cli)
        self.assertEqual("another operation", lock.read_text())
        self.assertEqual([], self.cli.calls)

    def test_cli_defaults_to_preview_without_starting_codex_for_a_new_home(self):
        result = subprocess.run(
            [sys.executable, str(ROOT / "scripts/agent-plugins.py"), "--manifest", str(self.manifest),
             "--codex-home", str(self.home), "--codex", "/nonexistent-codex"],
            text=True, capture_output=True, check=False,
        )
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual("planned", json.loads(result.stdout)["status"])
        self.assertFalse(self.home.exists())

    def test_cli_sync_refuses_an_implicit_global_home(self):
        result = subprocess.run(
            [sys.executable, str(ROOT / "scripts/agent-plugins.py"), "sync", "--manifest", str(self.manifest),
             "--plugin", "demo@demo", "--codex", "/nonexistent-codex"],
            text=True, capture_output=True, check=False,
        )
        self.assertEqual(2, result.returncode)
        self.assertIn("explicit", result.stderr)

    def test_hook_executable_mode_is_part_of_install_verification(self):
        self.cli.strip_executable = True
        with self.assertRaisesRegex(MODULE.SyncError, "executable"):
            MODULE.manage(self.manifest, self.home, selectors=("demo@demo",), apply=True, runner=self.cli)

    def test_extra_skill_in_cache_is_rejected_as_unexpected_discovery(self):
        self.cli.extra_skill = True
        with self.assertRaisesRegex(MODULE.SyncError, "skill inventory"):
            MODULE.manage(self.manifest, self.home, selectors=("demo@demo",), apply=True, runner=self.cli)

    def test_failed_refresh_does_not_overwrite_a_concurrent_config_edit(self):
        self.make_git_declaration("a" * 40)
        MODULE.manage(self.manifest, self.home, selectors=("demo@demo",), apply=True, runner=self.cli)
        self.make_git_declaration("b" * 40)
        self.cli.fail_upgrade = True
        self.cli.concurrent_edit = True
        with self.assertRaises(MODULE.SyncError):
            MODULE.manage(self.manifest, self.home, selectors=("demo@demo",), apply=True, runner=self.cli)
        config = tomllib.loads((self.home / "config.toml").read_text())
        self.assertEqual("concurrent", config["user"]["keep"])
        self.assertEqual("b" * 40, config["marketplaces"]["demo"]["ref"])

    def test_retry_after_failed_copy_repairs_cache_instead_of_reporting_noop(self):
        self.cli.corrupt_install = True
        with self.assertRaises(MODULE.SyncError):
            MODULE.manage(self.manifest, self.home, selectors=("demo@demo",), apply=True, runner=self.cli)
        self.cli.corrupt_install = False

        result = MODULE.manage(self.manifest, self.home, selectors=("demo@demo",), apply=True, runner=self.cli)

        self.assertEqual("synced", result["status"])
        source = self.repo / "plugins/demo/skills/example/SKILL.md"
        cache = self.home / "plugins/cache/demo/demo/1.0.0/skills/example/SKILL.md"
        self.assertEqual(source.read_bytes(), cache.read_bytes())

    def test_git_worktree_edits_are_not_accepted_as_the_pinned_commit(self):
        self.make_git_declaration("a" * 40)
        MODULE.manage(self.manifest, self.home, selectors=("demo@demo",), apply=True, runner=self.cli)
        root = Path(self.cli.marketplaces[0]["root"])
        (root / "plugins/demo/skills/example/SKILL.md").write_text("uncommitted source edit")
        before = len(self.cli.calls)

        with self.assertRaisesRegex(MODULE.SyncError, "pinned"):
            MODULE.manage(self.manifest, self.home, selectors=("demo@demo",), apply=True, runner=self.cli)

        self.assertTrue(all("add" not in command and "upgrade" not in command for command, _ in self.cli.calls[before:]))

    def test_untracked_git_source_file_is_rejected_without_deleting_it(self):
        self.make_git_declaration("a" * 40)
        MODULE.manage(self.manifest, self.home, selectors=("demo@demo",), apply=True, runner=self.cli)
        extra = Path(self.cli.marketplaces[0]["root"]) / "untracked.sh"
        extra.write_text("untracked source file")

        with self.assertRaisesRegex(MODULE.SyncError, "inventory"):
            MODULE.manage(self.manifest, self.home, selectors=("demo@demo",), apply=True, runner=self.cli)

        self.assertEqual("untracked source file", extra.read_text())

    def test_unexpected_cached_hook_is_repaired_before_noop(self):
        MODULE.manage(self.manifest, self.home, selectors=("demo@demo",), apply=True, runner=self.cli)
        extra = self.home / "plugins/cache/demo/demo/1.0.0/hooks/unexpected.sh"
        extra.write_text("unexpected cached hook")

        result = MODULE.manage(self.manifest, self.home, selectors=("demo@demo",), apply=True, runner=self.cli)

        self.assertEqual("synced", result["status"])
        self.assertFalse(extra.exists())

    def test_wrong_version_is_detected_in_stage_before_target_upgrade(self):
        self.make_git_declaration("a" * 40)
        MODULE.manage(self.manifest, self.home, selectors=("demo@demo",), apply=True, runner=self.cli)
        before = (self.home / "config.toml").read_bytes()
        self.make_git_declaration("b" * 40)
        (self.repo / "plugins/demo/.codex-plugin/plugin.json").write_text('{"name":"demo","version":"0.9.0"}')
        count = len(self.cli.calls)

        with self.assertRaisesRegex(MODULE.SyncError, "expected version"):
            MODULE.manage(self.manifest, self.home, selectors=("demo@demo",), apply=True, runner=self.cli)

        self.assertEqual(before, (self.home / "config.toml").read_bytes())
        self.assertTrue(all("upgrade" not in command for command, _ in self.cli.calls[count:]))

    def test_upgrade_refuses_unselected_configured_plugins_in_same_marketplace(self):
        other = self.repo / "plugins/other/.codex-plugin"
        other.mkdir(parents=True)
        (other / "plugin.json").write_text('{"name":"other","version":"1.0.0"}')
        (other.parent / "marker.txt").write_text("old cache")
        self.make_git_declaration("a" * 40)
        MODULE.manage(self.manifest, self.home, selectors=("demo@demo",), apply=True, runner=self.cli)
        self.cli.install("other@demo", self.home, self.cli.marketplaces)
        before = (self.home / "config.toml").read_bytes()
        self.make_git_declaration("b" * 40)
        (other.parent / "marker.txt").write_text("unselected update")

        with self.assertRaisesRegex(MODULE.SyncError, "unselected"):
            MODULE.manage(self.manifest, self.home, selectors=("demo@demo",), apply=True, runner=self.cli)

        self.assertEqual(before, (self.home / "config.toml").read_bytes())
        self.assertEqual("old cache", (self.home / "plugins/cache/demo/other/1.0.0/marker.txt").read_text())
