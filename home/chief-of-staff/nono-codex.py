#!/usr/bin/env python3
"""Run Codex in nono from the caller's authorized working directory."""

import os
from pathlib import Path
import re
import shutil
import sys
import tempfile
import tomllib


# hc 0.1.17: crates/herdr-core/src/{paths.rs,platform/unix.rs}.
session = os.environ.get("HC_SESSION", "").strip(" \t\r\n\v\f") or "default"
if session in (".", "..") or not re.fullmatch(r"[A-Za-z0-9_.-]+", session):
    sys.exit("HC_SESSION must be a single name using letters, digits, _ . -")

home = Path.home()
state = Path(os.environ.get("XDG_STATE_HOME") or home / ".local/state") / "herdr-core" / session
runtime = os.environ.get("XDG_RUNTIME_DIR")
if not runtime and Path(f"/run/user/{os.getuid()}").is_dir():
    runtime = f"/run/user/{os.getuid()}"
socket_dir = Path(runtime) / "herdr-core" if runtime else state
socket = os.environ.get("HC_SOCKET")
if not socket:
    config = Path(os.environ.get("XDG_CONFIG_HOME") or home / ".config") / "herdr-core/config.toml"
    try:
        with config.open("rb") as source:
            socket = tomllib.load(source).get("socket")
    except FileNotFoundError:
        pass
    except (OSError, tomllib.TOMLDecodeError) as error:
        sys.exit(f"Cannot resolve hc socket: {error}")
    if socket is not None and (not isinstance(socket, str) or not socket):
        sys.exit("hc config socket must be a nonempty path")
socket = socket or str(socket_dir / f"{session}.sock")

app = shutil.which("herdr-app")
if not app:
    sys.exit("herdr-app is required")
cwd = os.getcwd()
log_fd, log_path = tempfile.mkstemp(prefix="chief-nono-", suffix=".log")
os.close(log_fd)
print(f"nono log: {log_path}", file=sys.stderr, flush=True)
argv = [
    "nono", "run", "--profile", "chouge-codex", "--log-file", log_path,
    "--workdir", cwd, "--allow-cwd", "--read", str(state),
    "--allow-unix-socket", socket,
    "--allow-unix-socket", str(home / ".config/herdr-app/herdr-app.sock"),
    "--read-file", app,
    "--", str(home / ".local/bin/codex"), "--no-daemon", "--sandbox", "danger-full-access",
    "--ask-for-approval", "never", "-C", cwd, *sys.argv[1:],
]
try:
    os.execvp(argv[0], argv)
except FileNotFoundError:
    print("nono is required", file=sys.stderr)
    sys.exit(127)
