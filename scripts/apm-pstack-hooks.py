"""Supply the plugin root missing from APM 0.29's relocated pstack hooks."""
import argparse
import copy
import hashlib
import json
import os
from pathlib import Path
import shlex
import tempfile

SOURCE = "michael-denyer/pstack-claude/plugins/pstack"
HASHES = {
    "hooks/session-start.sh": "8863efcff6a0e888b3a6775331d59c45edf21add0586981328762bd9121331fe",
    "hooks/session-start-context.md": "39dc6bebcc7b50e6add4b28d470b2faf9f34391fad1bf847039bbe76f26e84e4",
    "skills/setup-pstack/scripts/read-sheet.sh": "46d240f8f48e6bcb0d3a7d8b6c098c7bfe20f3828437b7da5e4f1ac4512357bb",
}
HASHES_09126 = {
    **HASHES,
    "hooks/session-start.sh": "53dd48c37c3b2aefcd1b9c1bf174ecb7b0a09637911986eb0cd57bbb4bde9532",
}
HASHES_09129 = {
    **HASHES_09126,
    "hooks/session-start.sh": "4352086cc023886e891de7dc71a2efd22fb909ce8ce86b2fbf2b980296de168f",
}

HASHES_09130 = {
    **HASHES_09129,
    "hooks/session-start.sh": "06cff6e696476c22b25225faafd833c6cbe4f88025fb7e90bab96c2dd381252c",
}


def plan(home, package_root, source=SOURCE, claude_config_dir=None):
    """Return only verified pstack entry replacements, without writing or executing hooks."""
    manifest = json.loads((package_root / ".claude-plugin/plugin.json").read_text())
    if manifest.get("name") != "pstack" or manifest.get("version") not in ("0.9.114", "0.9.120", "0.9.126", "0.9.129", "0.9.130", "0.9.132"):
        raise ValueError("expected reviewed pstack 0.9.114, 0.9.120, 0.9.126, 0.9.129, 0.9.130 or 0.9.132")
    hashes = {"0.9.126": HASHES_09126, "0.9.129": HASHES_09129, "0.9.130": HASHES_09130, "0.9.132": HASHES_09130}.get(manifest["version"], HASHES)
    for relative, expected in hashes.items():
        if hashlib.sha256((package_root / relative).read_bytes()).hexdigest() != expected:
            raise ValueError(f"pstack source changed: {relative}; review the pinned compatibility fix")
    changes = []
    owned_count = 0
    for runtime, config_name in (("codex", "hooks.json"), ("claude", "settings.json")):
        directory = Path(claude_config_dir).expanduser().resolve() if runtime == "claude" and claude_config_dir else home / ("." + runtime)
        sidecar_path = directory / "apm-hooks.json"
        if not sidecar_path.exists():
            continue
        sidecar = json.loads(sidecar_path.read_text())
        entries = sidecar.get("SessionStart", [])
        owned = [entry for entry in entries if entry.get("_apm_source") == source]
        if not owned:
            continue
        if len(owned) != 1:
            raise ValueError(f"ambiguous {runtime} pstack hook ownership")
        owned_count += 1
        entry = owned[0]
        if entry.get("matcher") != "startup|resume|clear|compact" or len(entry.get("hooks", [])) != 1:
            raise ValueError(f"unexpected {runtime} pstack hook shape")
        hook = entry["hooks"][0]
        exported = directory / "hooks/pstack/hooks/session-start.sh"
        if hashlib.sha256(exported.read_bytes()).hexdigest() != hashes["hooks/session-start.sh"]:
            raise ValueError(f"modified {runtime} exported hook; preserve and inspect it")
        original = f'"{exported}" {runtime}'
        fixed = "env CLAUDE_PLUGIN_ROOT=" + shlex.quote(str(package_root)) + " " + original
        if hook.get("type") != "command" or hook.get("command") not in (original, fixed):
            raise ValueError(f"modified {runtime} pstack command; preserve and inspect it")
        config_path = directory / config_name
        if config_path.is_symlink() or sidecar_path.is_symlink():
            raise ValueError(f"symlinked {runtime} hook config; preserve and inspect it")
        config = json.loads(config_path.read_text())
        public = {key: value for key, value in entry.items() if key != "_apm_source"}
        public_fixed = copy.deepcopy(public)
        public_fixed["hooks"][0]["command"] = fixed
        configured = config.get("hooks", {}).get("SessionStart", [])
        matches = [candidate for candidate in configured if candidate in (public, public_fixed)]
        if len(matches) != 1:
            raise ValueError(f"{runtime} hook config differs from APM ownership; preserve and inspect it")
        if matches[0] != public_fixed:
            matches[0]["hooks"][0]["command"] = fixed
            changes.append((config_path, config))
        if hook["command"] != fixed:
            hook["command"] = fixed
            changes.append((sidecar_path, sidecar))
    if not owned_count:
        raise ValueError("APM hook exports missing; install the declared plugin first")
    return changes


def existing_ownership(home, claude_config_dir=None):
    directories = [home / ".codex", Path(claude_config_dir).expanduser().resolve() if claude_config_dir else home / ".claude"]
    for directory in directories:
        sidecar = directory / "apm-hooks.json"
        if sidecar.exists() and any(entry.get("_apm_source") == SOURCE for entry in json.loads(sidecar.read_text()).get("SessionStart", [])):
            return True
    return False


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="update the verified entries and their APM ownership records")
    parser.add_argument("--if-installed", action="store_true", help="repair existing ownership before an APM install; skip a fresh installation")
    args = parser.parse_args()
    home = Path.home()
    try:
        claude_config_dir = os.environ.get("CLAUDE_CONFIG_DIR")
        if args.if_installed and not existing_ownership(home, claude_config_dir):
            print("no existing pstack hook ownership")
            return
        changes = plan(home, home / ".apm/apm_modules" / SOURCE, claude_config_dir=claude_config_dir)
        for path, content in changes:
            print(("update " if args.apply else "would update ") + str(path))
            if args.apply:
                with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, prefix="." + path.name + ".", delete=False) as output:
                    temporary = Path(output.name)
                    output.write(json.dumps(content, ensure_ascii=False, indent=2) + "\n")
                try:
                    temporary.chmod(path.stat().st_mode & 0o777)
                    temporary.replace(path)
                finally:
                    temporary.unlink(missing_ok=True)
        if not changes:
            print("pstack hook roots already supplied")
    except (OSError, ValueError, KeyError, TypeError) as error:
        parser.exit(1, str(error) + "\n")


if __name__ == "__main__":
    main()
