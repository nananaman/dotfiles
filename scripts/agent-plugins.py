#!/usr/bin/env python3
"""Plan or explicitly sync declared Codex native plugins without trusting hooks."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import tomllib
from urllib.parse import urlsplit


class SyncError(Exception):
    pass


class RevisionMismatch(SyncError):
    pass


NAME = re.compile(r"[a-z0-9][a-z0-9_-]*\Z")
SHA = re.compile(r"[0-9a-f]{40}\Z")


def load_declaration(path):
    path = Path(path)
    data = tomllib.loads(path.read_text())
    required = {"version", "marketplaces", "plugins"}
    if not required.issubset(data) or set(data) - required - {"codex_routing"} or data["version"] != 1:
        raise SyncError("unsupported native plugin manifest")
    for name, market in data["marketplaces"].items():
        kind = market.get("kind")
        if not NAME.fullmatch(name) or kind not in {"git", "local"}:
            raise SyncError("invalid marketplace name or kind")
        fields = {"kind", "source", "ref"} if kind == "git" else {"kind", "source"}
        if set(market) != fields or not isinstance(market["source"], str) or not market["source"].strip():
            raise SyncError("invalid marketplace source declaration")
        if kind == "git":
            url = urlsplit(market["source"])
            if url.scheme != "https" or not url.hostname or url.username or url.password or url.query or url.fragment:
                raise SyncError("git source must be a credential-free HTTPS URL")
            if not isinstance(market["ref"], str) or not SHA.fullmatch(market["ref"]):
                raise SyncError("git ref must be a full lowercase SHA")
        else:
            source = Path(market["source"]).expanduser()
            market["source"] = str((source if source.is_absolute() else path.parent / source).resolve())
    seen = set()
    for plugin in data["plugins"]:
        if set(plugin) != {"selector", "runtime", "expected_version"} or plugin["runtime"] != "codex":
            raise SyncError("unsupported plugin declaration")
        selector = plugin["selector"]
        parts = selector.split("@")
        if len(parts) != 2 or not all(NAME.fullmatch(part) for part in parts) or parts[1] not in data["marketplaces"]:
            raise SyncError("invalid plugin selector")
        if selector in seen or not isinstance(plugin["expected_version"], str) or not plugin["expected_version"].strip():
            raise SyncError("duplicate selector or missing expected version")
        seen.add(selector)
    if "codex_routing" in data:
        routing = data["codex_routing"]
        if not {"legacy_plugin", "legacy_apm_skills"}.issubset(routing) or set(routing) - {"legacy_plugin", "legacy_apm_skills", "max_threads"}:
            raise SyncError("unsupported Codex routing declaration")
        parts = routing["legacy_plugin"].split("@")
        if len(parts) != 2 or not all(NAME.fullmatch(part) for part in parts) or routing["legacy_plugin"] in seen:
            raise SyncError("invalid or conflicting legacy plugin selector")
        names = routing["legacy_apm_skills"]
        if not isinstance(names, list) or not names or any(not isinstance(name, str) or not NAME.fullmatch(name) for name in names) or len(set(names)) != len(names):
            raise SyncError("legacy APM skill names must be unique simple names")
        if type(routing.get("max_threads", 2)) is not int or routing.get("max_threads", 2) < 1:
            raise SyncError("Codex thread limit must be a positive integer")
    return data


def check_source(row, definition):
    source = row.get("marketplaceSource", {})
    expected = definition["source"]
    actual = source.get("source", "")
    if source.get("sourceType") != definition["kind"]:
        raise SyncError("registered marketplace source kind differs from declaration")
    if definition["kind"] == "local":
        matches = bool(actual) and Path(actual).expanduser().resolve() == Path(expected)
    else:
        matches = actual.rstrip("/").removesuffix(".git") == expected.rstrip("/").removesuffix(".git")
    if not matches:
        raise SyncError("registered marketplace source differs from declaration")


def execute(command, env):
    result = subprocess.run(command, env=env, cwd="/", capture_output=True, text=True, timeout=120, check=False)
    if result.returncode:
        raise SyncError(f"command failed with exit {result.returncode}: {command[0]}")
    return result.stdout


def verify_git_tree(root, definition, run, env):
    root = Path(root).resolve()
    ref = definition["ref"]
    native_metadata = ".codex-marketplace-install.json"
    command = ["git", "-c", "core.hooksPath=/dev/null", "-C", str(root)]
    if run([*command, "rev-parse", "HEAD"], env).strip() != ref:
        raise RevisionMismatch("marketplace checkout does not match the declared full SHA")
    expected = set()
    for entry in run([*command, "ls-tree", "-rz", ref], env).split("\0"):
        if not entry:
            continue
        meta, relative = entry.split("\t", 1)
        mode, kind, digest = meta.split()
        if relative == native_metadata:
            raise SyncError("pinned tree uses the reserved native metadata path")
        path = root / relative
        if kind != "blob" or mode not in {"100644", "100755"} or not path.resolve().is_relative_to(root):
            raise SyncError("pinned tree contains unsupported paths")
        if path.is_symlink() or not path.is_file():
            raise SyncError("pinned tree has missing or linked files")
        data = path.read_bytes()
        observed = hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()
        if observed != digest or bool(path.stat().st_mode & 0o111) != (mode == "100755"):
            raise SyncError("marketplace content differs from the pinned tree")
        expected.add(relative)
    metadata_path = root / native_metadata
    if metadata_path.exists() or metadata_path.is_symlink():
        if metadata_path.is_symlink() or not metadata_path.is_file():
            raise SyncError("native marketplace metadata must be a regular file")
        metadata = json.loads(metadata_path.read_text())
        if set(metadata) != {"source_type", "source", "ref_name", "sparse_paths", "revision"}:
            raise SyncError("unsupported native marketplace metadata")
        check_source({"marketplaceSource": {"sourceType": metadata["source_type"], "source": metadata["source"]}}, definition)
        if metadata["ref_name"] != ref or metadata["revision"] != ref or metadata["sparse_paths"] != []:
            raise SyncError("native marketplace metadata differs from the declared full SHA")
    actual = set()
    for path in root.rglob("*"):
        if path.relative_to(root).parts[0] == ".git" or path == metadata_path:
            continue
        if path.is_symlink():
            raise SyncError("pinned tree contains unexpected links")
        if path.is_file():
            actual.add(path.relative_to(root).as_posix())
    if actual != expected:
        raise SyncError("marketplace file inventory differs from the pinned tree")


def plugin_source(root, name, version, market=None):
    root = Path(root).resolve()
    catalog_file = root / ".agents/plugins/marketplace.json"
    if not catalog_file.resolve().is_relative_to(root):
        raise SyncError("marketplace catalog escapes the declared source")
    catalog = json.loads(catalog_file.read_text())
    if market is not None and catalog.get("name") != market:
        raise SyncError("marketplace catalog name differs from declaration")
    matches = [item for item in catalog["plugins"] if item["name"] == name]
    if len(matches) != 1 or matches[0].get("source", {}).get("source") != "local":
        raise SyncError(f"expected one local plugin source for {name}")
    source = (root / matches[0]["source"]["path"]).resolve()
    if not source.is_relative_to(root):
        raise SyncError("plugin source escapes marketplace")
    if any(path.is_symlink() for path in source.rglob("*")):
        raise SyncError("source symlinks require manual verification before install")
    candidates = [source / ".codex-plugin/plugin.json", source / "plugin.json"]
    metadata = next((path for path in candidates if path.is_file()), None)
    if metadata is None:
        raise SyncError(f"native manifest missing for {name}")
    if not metadata.resolve().is_relative_to(source):
        raise SyncError("native manifest escapes plugin source")
    data = json.loads(metadata.read_text())
    if data.get("name") != name or data.get("version") != version:
        raise SyncError(f"expected version {version} and name {name}")
    return source


def verify_copy(source, installed):
    installed = Path(installed)
    if installed.is_symlink() or any(path.is_symlink() for path in installed.rglob("*")):
        raise SyncError("installed plugin contains unexpected links")
    installed = installed.resolve()
    expected_skills = {str(path.relative_to(source)) for path in source.glob("skills/**/SKILL.md")}
    actual_skills = {str(path.relative_to(installed)) for path in installed.glob("skills/**/SKILL.md")}
    if expected_skills != actual_skills:
        raise SyncError("installed skill inventory differs from the verified source")
    expected_files = {str(path.relative_to(source)) for path in source.rglob("*") if path.is_file()}
    actual_files = {str(path.relative_to(installed)) for path in installed.rglob("*") if path.is_file()}
    if expected_files != actual_files:
        raise SyncError("installed file inventory differs from the verified source")
    for path in source.rglob("*"):
        if path.is_symlink():
            raise SyncError("source symlinks require manual verification")
        if path.is_file():
            target = installed / path.relative_to(source)
            if not target.resolve().is_relative_to(installed) or not target.is_file() or path.read_bytes() != target.read_bytes():
                raise SyncError("installed plugin content differs from the verified source")
            if os.name == "posix" and (path.stat().st_mode & 0o111) != (target.stat().st_mode & 0o111):
                raise SyncError("installed executable mode differs from source")


def config_bytes(home):
    path = home / "config.toml"
    return path.read_bytes() if path.exists() else b""


def protected_config(raw, selected):
    data = tomllib.loads(raw.decode())
    for plugin in selected:
        selector = plugin["selector"]
        market = selector.split("@")[1]
        data.get("marketplaces", {}).pop(market, None)
        data.get("plugins", {}).pop(selector, None)
    for key in ("marketplaces", "plugins"):
        if data.get(key) == {}:
            data.pop(key)
    return data


def write_config_ref(home, market, old, new, definition):
    path = home / "config.toml"
    if path.is_symlink():
        raise SyncError("ref update refuses a symlinked config")
    before = path.read_bytes()
    parsed = tomllib.loads(before.decode())
    saved = parsed.get("marketplaces", {}).get(market, {})
    check_source({"marketplaceSource": {"sourceType": saved.get("source_type"), "source": saved.get("source")}}, definition)
    if saved.get("ref") != old or saved.get("sparse_paths"):
        raise SyncError("marketplace ref changed concurrently")
    lines = before.decode().splitlines(keepends=True)
    headers = {f"[marketplaces.{market}]", f'[marketplaces."{market}"]', f"[marketplaces.'{market}']"}
    inside = False
    changed = 0
    for index, line in enumerate(lines):
        stripped = line.split("#", 1)[0].strip()
        if stripped.startswith("["):
            inside = stripped in headers
        elif inside and re.match(r"^\s*ref\s*=", line):
            comment = " #" + line.split("#", 1)[1].rstrip("\r\n") if "#" in line else ""
            lines[index] = f"ref = {json.dumps(new)}{comment}\n"
            changed += 1
    if changed != 1:
        raise SyncError("ref update requires one regular marketplace table and ref field")
    after = "".join(lines).encode()
    parsed["marketplaces"][market]["ref"] = new
    if tomllib.loads(after.decode()) != parsed or path.read_bytes() != before:
        raise SyncError("config changed while preparing the scoped ref update")
    with tempfile.NamedTemporaryFile(dir=home, prefix=".plugin-ref-", delete=False) as file:
        temporary = Path(file.name)
        try:
            os.fchmod(file.fileno(), path.stat().st_mode & 0o777)
            file.write(after)
            file.flush()
            os.fsync(file.fileno())
            if path.read_bytes() != before:
                raise SyncError("config changed concurrently")
            os.replace(temporary, path)
        finally:
            temporary.unlink(missing_ok=True)
    return before, after


def manage(manifest, codex_home, *, selectors=(), apply=False, codex="codex", runner=None):
    if apply and not selectors:
        raise SyncError("sync requires explicit plugin selectors")
    desired = load_declaration(manifest)
    known = {item["selector"] for item in desired["plugins"]}
    if set(selectors) - known:
        raise SyncError("unknown explicit plugin selector")
    home = Path(codex_home).expanduser().resolve()
    env = {**os.environ, "CODEX_HOME": str(home)}
    run = runner or execute
    lock = home / ".dotfiles-plugin-sync.lock"
    lock_fd = None
    if apply:
        home.mkdir(parents=True, exist_ok=True)
        try:
            lock_fd = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
        except FileExistsError as error:
            raise SyncError("another sync or an unresolved sync lock exists") from error
    try:
        return reconcile(desired, home, selectors, apply, codex, run, env)
    finally:
        if lock_fd is not None:
            os.close(lock_fd)
            lock.unlink()


def reconcile(desired, home, selectors, apply, codex, run, env):

    def cli(*args):
        return json.loads(run([codex, "--disable", "hooks", "plugin", *args, "--json"], env))

    if home.exists():
        marketplaces = {item["name"]: item for item in cli("marketplace", "list")["marketplaces"]}
        installed = {item["pluginId"]: item for item in cli("list")["installed"]}
    else:
        marketplaces, installed = {}, {}
    actions = []
    selected = [plugin for plugin in desired["plugins"] if not selectors or plugin["selector"] in selectors]
    original = config_bytes(home)
    config = tomllib.loads(original.decode())
    touched = set()

    def verify_market(market, listing):
        row = listing[market]
        definition = desired["marketplaces"][market]
        check_source(row, definition)
        if definition["kind"] == "git":
            saved = tomllib.loads(config_bytes(home).decode()).get("marketplaces", {}).get(market, {})
            check_source({"marketplaceSource": {"sourceType": saved.get("source_type"), "source": saved.get("source")}}, definition)
            if saved.get("ref") != definition["ref"] or saved.get("sparse_paths"):
                raise SyncError("persisted marketplace ref or full-tree layout differs from declaration")
            verify_git_tree(row["root"], definition, run, env)
        elif Path(row["root"]).resolve() != Path(definition["source"]):
            raise SyncError("local marketplace root differs from source")
        return row["root"]

    refresh = set()
    for plugin in selected:
        selector = plugin["selector"]
        name, market = selector.split("@")
        definition = desired["marketplaces"][market]
        if market in marketplaces:
            check_source(marketplaces[market], definition)
        if definition["kind"] == "local":
            plugin_source(definition["source"], name, plugin["expected_version"], market)
            if market in marketplaces:
                verify_market(market, marketplaces)
        if market not in touched:
            touched.add(market)
            if market not in marketplaces:
                actions.append({"action": "register", "marketplace": market})
                refresh.add(market)
            elif definition["kind"] == "git":
                market_action_start = len(actions)
                saved = config.get("marketplaces", {}).get(market, {})
                check_source({"marketplaceSource": {"sourceType": saved.get("source_type"), "source": saved.get("source")}}, definition)
                previous = saved.get("ref", "")
                if not SHA.fullmatch(previous):
                    raise SyncError("existing marketplace must have a full SHA in user config")
                if previous != definition["ref"]:
                    actions.append({"action": "set-ref", "marketplace": market, "from": previous, "to": definition["ref"]})
                    refresh.add(market)
                else:
                    try:
                        verify_market(market, marketplaces)
                    except RevisionMismatch:
                        refresh.add(market)
                if market in refresh:
                    configured = set(config.get("plugins", {})) | set(installed)
                    unselected = {item for item in configured if item.endswith("@" + market)} - {item["selector"] for item in selected}
                    if unselected:
                        raise SyncError("upgrade would touch unselected configured plugins in the marketplace")
                    actions.insert(market_action_start, {"action": "preflight", "marketplace": market})
                    actions.append({"action": "upgrade", "marketplace": market})
        if market in marketplaces and market not in refresh:
            plugin_source(marketplaces[market]["root"], name, plugin["expected_version"], market)
        needs_install = market in refresh or selector not in installed or installed[selector].get("version") != plugin["expected_version"] or not installed[selector].get("enabled")
        if not needs_install:
            source = plugin_source(marketplaces[market]["root"], name, plugin["expected_version"], market)
            try:
                verify_copy(source, home / "plugins/cache" / market / name / plugin["expected_version"])
            except SyncError:
                needs_install = True
        if needs_install:
            actions.append({"action": "install", "selector": selector})
        elif installed[selector].get("marketplaceSource"):
            check_source({"marketplaceSource": installed[selector]["marketplaceSource"]}, definition)
    if not apply or not actions:
        return {"status": "planned" if actions else "noop", "codex_home": str(home), "actions": actions,
                "plugins": selected, "marketplaces": {name: desired["marketplaces"][name] for name in touched}}
    edits = {}
    for action in actions:
        if action["action"] == "preflight":
            market = action["marketplace"]
            definition = desired["marketplaces"][market]
            with tempfile.TemporaryDirectory(dir=home, prefix=".plugin-preflight-") as directory:
                stage = Path(directory)
                stage_env = {**env, "CODEX_HOME": str(stage)}
                result = json.loads(run([codex, "--disable", "hooks", "plugin", "marketplace", "add", definition["source"],
                                         "--ref", definition["ref"], "--json"], stage_env))
                root = Path(result["installedRoot"]).resolve()
                if result.get("marketplaceName") != market or not root.is_relative_to(stage):
                    raise SyncError("preflight source was not isolated as requested")
                verify_git_tree(root, definition, run, stage_env)
                for plugin in selected:
                    if plugin["selector"].endswith("@" + market):
                        plugin_source(root, plugin["selector"].split("@")[0], plugin["expected_version"], market)
                catalog = json.loads((root / ".agents/plugins/marketplace.json").read_text())
                for entry in catalog["plugins"]:
                    if entry.get("policy", {}).get("installation") == "INSTALLED_BY_DEFAULT" and entry["name"] + "@" + market not in selectors:
                        raise SyncError("preflight found an unselected default-installed plugin")
        elif action["action"] == "register":
            definition = desired["marketplaces"][action["marketplace"]]
            args = ["marketplace", "add", definition["source"]]
            if definition["kind"] == "git":
                args += ["--ref", definition["ref"]]
            result = cli(*args)
            if result.get("marketplaceName") != action["marketplace"]:
                raise SyncError("registered marketplace name differs from declaration; inspect partial state")
        elif action["action"] == "set-ref":
            market = action["marketplace"]
            edits[market] = write_config_ref(home, market, action["from"], action["to"], desired["marketplaces"][market])
        elif action["action"] == "upgrade":
            market = action["marketplace"]
            try:
                result = cli("marketplace", "upgrade", market)
                if result.get("errors"):
                    raise SyncError("marketplace upgrade reported errors")
            except Exception:
                if market in edits:
                    before, after = edits[market]
                    if config_bytes(home) == after:
                        write_config_ref(home, market, desired["marketplaces"][market]["ref"], tomllib.loads(before.decode())["marketplaces"][market]["ref"], desired["marketplaces"][market])
                    else:
                        raise SyncError("upgrade failed and config changed; the new ref was not restored")
                raise
        else:
            plugin = next(item for item in selected if item["selector"] == action["selector"])
            name, market = plugin["selector"].split("@")
            listing = {item["name"]: item for item in cli("marketplace", "list")["marketplaces"]}
            root = verify_market(market, listing)
            source = plugin_source(root, name, plugin["expected_version"], market)
            result = cli("add", plugin["selector"])
            if result.get("pluginId") != plugin["selector"] or result.get("version") != plugin["expected_version"]:
                raise SyncError("install result does not match the declaration")
            if not Path(result["installedPath"]).resolve().is_relative_to(home / "plugins/cache"):
                raise SyncError("installed path is outside this CODEX_HOME plugin cache")
            verify_copy(source, result["installedPath"])
    final = {item["pluginId"]: item for item in cli("list")["installed"]}
    if any(final.get(item["selector"], {}).get("version") != item["expected_version"] or not final.get(item["selector"], {}).get("enabled") for item in selected):
        raise SyncError("installed version readback did not match the declaration")
    if protected_config(original, selected) != protected_config(config_bytes(home), selected):
        raise SyncError("unrelated configuration changed; inspect partial state")
    return {"status": "synced", "codex_home": str(home), "actions": actions}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", nargs="?", choices=("plan", "sync", "validate"), default="plan")
    parser.add_argument("--manifest", type=Path, default=Path(__file__).resolve().parents[1] / "agent-plugins.toml")
    parser.add_argument("--codex-home", type=Path)
    parser.add_argument("--codex", default="codex")
    parser.add_argument("--plugin", action="append", default=[])
    args = parser.parse_args(argv)
    if args.mode == "sync" and (not args.codex_home or not args.plugin):
        parser.error("sync requires explicit --codex-home and --plugin")
    try:
        if args.mode == "validate":
            declaration = load_declaration(args.manifest)
            result = {"status": "valid", "plugins": len(declaration["plugins"])}
        else:
            home = args.codex_home or Path(os.environ.get("CODEX_HOME", str(Path.home() / ".codex")))
            result = manage(args.manifest, home, selectors=args.plugin, apply=args.mode == "sync", codex=args.codex)
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0
    except (SyncError, OSError, ValueError, KeyError, TypeError, StopIteration, subprocess.TimeoutExpired) as error:
        print(f"native plugin operation not completed: {type(error).__name__}: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
