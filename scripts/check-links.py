#!/usr/bin/env python3
"""Refuse to deploy through directory links left by the previous setup."""

from pathlib import Path
import platform
import sys
import tomllib


def linked_parents(config, home):
    os_name = "macos" if platform.system() == "Darwin" else "linux"
    conflicts = set()
    for name, entry in config["dotfiles"].items():
        variants = entry.get("variants", [])
        if variants and not any(v.get("os") == os_name for v in variants):
            continue
        if not name.startswith("~/"):
            raise ValueError(f"expected a home-relative dotfile target: {name}")
        target = home / name[2:]
        parent = target if entry.get("mode") == "symlink-each" else target.parent
        while parent != home:
            if parent.is_symlink():
                conflicts.add(parent)
            parent = parent.parent
    return sorted(conflicts)


def main():
    root = Path(__file__).resolve().parents[1]
    config = tomllib.loads((root / "mise.toml").read_text())
    conflicts = linked_parents(config, Path.home())
    if not conflicts:
        return 0
    print("Back up these directory symlinks before setup; their targets were not changed:", file=sys.stderr)
    for path in conflicts:
        print(f"  {path} -> {path.readlink()}", file=sys.stderr)
    print("Move the symlink itself, not its contents. See README.md for migration steps.", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
