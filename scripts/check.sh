#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
cd "$root"

shellcheck scripts/*.sh home/.local/bin/* home/.config/git/hooks/pre-push
shfmt -d -i 2 scripts/*.sh home/.local/bin/* home/.config/git/hooks/pre-push
taplo format --check mise.toml scripts/*.toml home/.config/mise/config.toml \
  home/.config/starship.toml home/.config/hunk/config.toml
zsh -n home/.zshenv home/.zshrc home/.config/zsh/functions/*.zsh
python3 - <<'PY'
import json
from pathlib import Path
import tomllib

for path in Path("home").rglob("*.json"):
    json.loads(path.read_text())
json.loads(Path("scripts/windows-terminal.json").read_text())
for path in Path("home").rglob("*.toml"):
    tomllib.loads(path.read_text())
print("JSON / TOML syntax: OK")
PY
python3 -m unittest discover -s tests -p 'test_*.py'
