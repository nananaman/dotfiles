#!/usr/bin/env python3
"""Preview or explicitly change only the declared Codex discovery settings."""
import argparse
import copy
import importlib.util
import json
import os
from pathlib import Path
import selectors
import subprocess
import sys
import tempfile
import time
import tomllib

SPEC = importlib.util.spec_from_file_location("routing_plugins", Path(__file__).with_name("agent-plugins.py"))
PLUGINS = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PLUGINS)
RECEIPT_NAME = ".dotfiles-pstack-routing-receipt.json"
RUNTIME_KEYS = ("features.multi_agent", "agents.enabled", "agents.max_threads", "agents.max_concurrent_threads_per_session")


class RoutingError(Exception):
    pass


class NativeConfig:
    """The vendor config editor preserves TOML outside the explicitly edited keys."""
    def __init__(self, codex, home):
        env = {key: os.environ[key] for key in ("HOME", "USER", "LOGNAME", "PATH", "LANG", "TMPDIR") if key in os.environ}
        env["CODEX_HOME"] = str(home)
        self.process = subprocess.Popen([codex, "--disable", "hooks", "app-server", "--listen", "stdio://"],
                                        cwd="/", env=env, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                        stderr=subprocess.DEVNULL, bufsize=0)
        self.selector = selectors.DefaultSelector()
        self.selector.register(self.process.stdout, selectors.EVENT_READ)
        self.buffer = b""
        self.next_id = 0

    def __enter__(self):
        try:
            self.request("initialize", {"clientInfo": {"name": "dotfiles-codex-routing", "version": "1"},
                                        "capabilities": {"experimentalApi": True}})
            self.process.stdin.write(b'{"method":"initialized","params":{}}\n')
            self.process.stdin.flush()
            return self
        except Exception:
            self.__exit__()
            raise

    def request(self, method, params):
        self.next_id += 1
        request_id = self.next_id
        self.process.stdin.write((json.dumps({"id": request_id, "method": method, "params": params}) + "\n").encode())
        self.process.stdin.flush()
        deadline = time.monotonic() + 15
        while time.monotonic() < deadline:
            while b"\n" in self.buffer:
                line, self.buffer = self.buffer.split(b"\n", 1)
                response = json.loads(line)
                if response.get("id") == request_id:
                    if "error" in response:
                        raise RoutingError(f"native config API rejected {method} ({response['error'].get('code')})")
                    return response["result"]
            for key, _ in self.selector.select(min(1, max(0, deadline - time.monotonic()))):
                data = os.read(key.fileobj.fileno(), 65536)
                if not data:
                    raise RoutingError("native config API ended before responding")
                self.buffer += data
        raise RoutingError("native config API timed out; inspect the target before retrying")

    def __exit__(self, *args):
        self.selector.close()
        self.process.stdin.close()
        try:
            self.process.wait(timeout=2)
        except subprocess.TimeoutExpired:
            self.process.kill()
            self.process.wait(timeout=2)
        self.process.stdout.close()


def plugin_readiness(manifest, home, codex):
    return PLUGINS.manage(manifest, home, apply=False, codex=codex)


def skill_name(row, names, user_home):
    path = row.get("path")
    if path is None and isinstance(row.get("name"), str) and row["name"].strip():
        return None
    if not isinstance(path, str):
        raise RoutingError("skill configuration entries require a path or name")
    if path.startswith("~/"):
        path = str(user_home / path[2:])
    path = Path(os.path.normpath(path))
    if path.name == "SKILL.md":
        path = path.parent
    # Keep the declared logical path stable across APM symlink/cache updates.
    base = user_home / ".agents/skills"
    return path.name if path.parent == base and path.name in names else None


def skill_rows(config):
    rows = config.get("skills", {}).get("config", [])
    if not isinstance(rows, list) or any(not isinstance(row, dict) for row in rows):
        raise RoutingError("unsupported skill configuration array")
    return rows


def projection(config, policy, user_home):
    legacy = config.get("plugins", {}).get(policy["legacy_plugin"])
    return {"skills": [copy.deepcopy(row) for row in skill_rows(config)
                       if skill_name(row, policy["legacy_apm_skills"], user_home)],
            "legacy_present": legacy is not None,
            "legacy_enabled": legacy.get("enabled", True) if legacy is not None else None,
            "runtime": {key: leaf(config, key) for key in RUNTIME_KEYS}}


def leaf(config, path):
    table, key = path.split(".")
    values = config.get(table, {})
    return {"present": key in values, "value": values.get(key)}


def restore_leaf(config, path, state):
    table, key = path.split(".")
    values = config.setdefault(table, {})
    if state["present"]:
        values[key] = state["value"]
    else:
        values.pop(key, None)


def changed_config(config, policy, user_home):
    desired = copy.deepcopy(config)
    rows = copy.deepcopy(skill_rows(config))
    found = set()
    for row in rows:
        name = skill_name(row, policy["legacy_apm_skills"], user_home)
        if name:
            found.add(name)
            row["enabled"] = False
    for name in policy["legacy_apm_skills"]:
        if name not in found:
            rows.append({"path": str(user_home / ".agents/skills" / name / "SKILL.md"), "enabled": False})
    desired.setdefault("skills", {})["config"] = rows
    legacy = desired.get("plugins", {}).get(policy["legacy_plugin"])
    if legacy is not None:
        legacy["enabled"] = False
    agents = desired.setdefault("agents", {})
    if "max_threads" in agents and "max_concurrent_threads_per_session" in agents:
        raise RoutingError("duplicate native thread-limit aliases require inspection")
    cap_key = "max_concurrent_threads_per_session" if "max_concurrent_threads_per_session" in agents else "max_threads"
    agents[cap_key] = policy.get("max_threads", 2)
    agents["enabled"] = True
    desired.setdefault("features", {})["multi_agent"] = True
    return desired


def edits_between(before, after, policy):
    edits = []
    if skill_rows(before) != skill_rows(after):
        edits.append({"keyPath": "skills.config", "value": skill_rows(after), "mergeStrategy": "replace"})
    legacy = policy["legacy_plugin"]
    old = before.get("plugins", {}).get(legacy)
    new = after.get("plugins", {}).get(legacy)
    if old is not None and new is not None and old.get("enabled", True) != new.get("enabled", True):
        edits.append({"keyPath": "plugins." + legacy + ".enabled", "value": new["enabled"], "mergeStrategy": "replace"})
    for key in RUNTIME_KEYS:
        if leaf(before, key) != leaf(after, key):
            state = leaf(after, key)
            edits.append({"keyPath": key, "value": state["value"] if state["present"] else None, "mergeStrategy": "replace"})
    return edits


def save_receipt(path, value, *, create=False):
    if path.is_symlink():
        raise RoutingError("routing receipt must not be a symlink")
    if create:
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        file = os.fdopen(fd, "w")
        temporary = None
    else:
        file = tempfile.NamedTemporaryFile(mode="w", dir=path.parent, prefix=".routing-receipt-", delete=False)
        temporary = Path(file.name)
    try:
        json.dump(value, file, ensure_ascii=False, indent=2)
        file.write("\n")
        file.flush()
        os.fsync(file.fileno())
        file.close()
        if temporary:
            os.replace(temporary, path)
    finally:
        file.close()
        if temporary:
            temporary.unlink(missing_ok=True)


def write_native(home, before_bytes, before, after, edits, codex, client_factory):
    path = home / "config.toml"
    if path.is_symlink():
        raise RoutingError("routing apply refuses a symlinked config")
    with client_factory(codex, home) as client:
        reply = client.request("config/read", {"includeLayers": True, "cwd": "/"})
        layers = [layer for layer in reply.get("layers") or []
                  if layer["name"].get("type") == "user" and not layer.get("disabledReason")
                  and Path(layer["name"].get("file", "")).resolve() == path.resolve()
                  and not layer["name"].get("profile")]
        if len(layers) != 1 or layers[0]["config"] != before or path.read_bytes() != before_bytes:
            raise RoutingError("configuration changed before the scoped native write")
        client.request("config/batchWrite", {"edits": edits, "filePath": str(path),
                                            "expectedVersion": layers[0]["version"], "reloadUserConfig": False})
    # The native editor may remove an empty table when its last owned leaf is deleted.
    def comparable(value):
        return {key: item for key, item in value.items() if key not in {"agents", "features"} or item != {}}
    if comparable(tomllib.loads(path.read_text())) != comparable(after):
        raise RoutingError("configuration changed during apply; inspect partial state without broad restoration")


def route(manifest, codex_home, *, mode="plan", codex="codex", user_home=None,
          client_factory=NativeConfig, readiness=plugin_readiness):
    if mode not in {"plan", "apply", "rollback"}:
        raise RoutingError("unsupported routing mode")
    declaration = PLUGINS.load_declaration(manifest)
    policy = declaration.get("codex_routing")
    if policy is None:
        raise RoutingError("manifest has no Codex routing policy")
    home = Path(codex_home).expanduser().resolve()
    user_home = Path(user_home or Path.home()).expanduser().resolve()
    path = home / "config.toml"
    receipt_path = home / RECEIPT_NAME
    if mode != "plan" and path.is_symlink():
        raise RoutingError("routing apply refuses a symlinked config")
    before_bytes = path.read_bytes() if path.exists() else b""
    before = tomllib.loads(before_bytes.decode())
    desired = changed_config(before, policy, user_home)
    receipt = None
    if mode == "rollback":
        if receipt_path.is_symlink():
            raise RoutingError("routing receipt must not be a symlink")
        receipt = json.loads(receipt_path.read_text())
        if receipt.get("version") != 1 or receipt["codex_home"] != str(home) or receipt["user_home"] != str(user_home) or receipt["policy"] != policy:
            raise RoutingError("receipt belongs to a different home or policy")
        current = projection(before, policy, user_home)
        if current == receipt["before"]:
            if receipt.get("status") != "rolled_back":
                receipt["status"] = "rolled_back"
                save_receipt(receipt_path, receipt)
            return {"status": "noop", "codex_home": str(home)}
        if receipt.get("status") == "rolled_back":
            raise RoutingError("completed rollback receipt cannot change later owned settings")
        if current != receipt["after"]:
            raise RoutingError("owned discovery settings changed since apply; rollback would overwrite them")
        desired = copy.deepcopy(before)
        desired.setdefault("skills", {})["config"] = [copy.deepcopy(row) for row in skill_rows(before)
                                                     if not skill_name(row, policy["legacy_apm_skills"], user_home)] + receipt["before"]["skills"]
        if receipt["before"]["legacy_present"]:
            desired["plugins"][policy["legacy_plugin"]]["enabled"] = receipt["before"]["legacy_enabled"]
        for key, state in receipt["before"]["runtime"].items():
            restore_leaf(desired, key, state)
    edits = edits_between(before, desired, policy)
    if mode == "plan":
        return {"status": "planned" if edits else "noop", "codex_home": str(home), "edits": edits,
                "prerequisites_validated": False, "requires": [item["selector"] for item in declaration["plugins"]]}
    if mode == "apply":
        if readiness(manifest, home, codex).get("status") != "noop":
            raise RoutingError("declared plugins must be fully installed and verified before routing apply")
    if not edits:
        return {"status": "noop", "codex_home": str(home)}
    if mode == "apply":
        receipt = {"version": 1, "status": "prepared", "codex_home": str(home), "user_home": str(user_home), "policy": policy,
                   "before": projection(before, policy, user_home), "after": projection(desired, policy, user_home)}
        reuse = receipt_path.exists()
        if reuse:
            if receipt_path.is_symlink():
                raise RoutingError("routing receipt must not be a symlink")
            previous = json.loads(receipt_path.read_text())
            if (previous.get("version") != 1 or previous.get("status") != "rolled_back"
                    or any(previous.get(key) != receipt[key] for key in ("codex_home", "user_home", "policy", "before"))):
                raise RoutingError("existing receipt is not a matching completed rollback; inspect it before applying")
        save_receipt(receipt_path, receipt, create=not reuse)
    try:
        write_native(home, before_bytes, before, desired, edits, codex, client_factory)
    except Exception:
        receipt["status"] = "needs_inspection"
        save_receipt(receipt_path, receipt)
        raise
    receipt["status"] = "rolled_back" if mode == "rollback" else "applied"
    save_receipt(receipt_path, receipt)
    return {"status": receipt["status"], "codex_home": str(home), "receipt": str(receipt_path), "edits": edits}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", nargs="?", choices=("plan", "apply", "rollback"), default="plan")
    parser.add_argument("--manifest", type=Path, default=Path(__file__).resolve().parents[1] / "agent-plugins.toml")
    parser.add_argument("--codex-home", type=Path)
    parser.add_argument("--codex", default="codex")
    args = parser.parse_args(argv)
    if args.mode != "plan" and args.codex_home is None:
        parser.error("apply/rollback require explicit --codex-home")
    try:
        home = args.codex_home or Path(os.environ.get("CODEX_HOME", str(Path.home() / ".codex")))
        print(json.dumps(route(args.manifest, home, mode=args.mode, codex=args.codex), ensure_ascii=False, indent=2))
        return 0
    except (RoutingError, PLUGINS.SyncError, OSError, ValueError, TypeError, KeyError) as error:
        print(f"Codex routing not completed: {type(error).__name__}: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
