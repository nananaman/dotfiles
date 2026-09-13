#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
mise_bin=${MISE_BIN:-mise}
dry_run=false
case "${1:-}" in
'') ;;
--dry-run) dry_run=true ;;
*)
  echo 'usage: scripts/bootstrap.sh [--dry-run]' >&2
  exit 64
  ;;
esac

version=$("$mise_bin" --version)
IFS=. read -r major minor patch <<<"${version%% *}"
if ((major < 2026 || (major == 2026 && minor < 9) || (major == 2026 && minor == 9 && patch < 5))); then
  echo 'dotfiles: mise 2026.9.5 or newer is required; update mise before setup.' >&2
  exit 1
fi

# A fresh machine has no global symlink yet. Use the same source in every phase.
export MISE_GLOBAL_CONFIG_FILE="$root/home/.config/mise/config.toml"
if "$dry_run"; then
  "$mise_bin" --cd "$root" bootstrap --skip task --dry-run
  "$mise_bin" --cd / install --dry-run
  bash "$root/scripts/brew-casks.sh" --dry-run
  case "$(uname -s)" in
  Darwin) bash "$root/scripts/macos.sh" --dry-run ;;
  Linux)
    MISE_GLOBAL_CONFIG_FILE="$root/scripts/linux.toml" \
      "$mise_bin" --cd / bootstrap user apply --dry-run
    ;;
  esac
  echo 'After native setup: install the locked secretlint runtime, APM skills, and OS integration.'
  exit 0
fi

# Python is also used by validation and by the safe migration preflight.
"$mise_bin" --cd / install python
python=$("$mise_bin" --cd / which --tool python python3)
"$python" "$root/scripts/check-links.py"

"$mise_bin" --cd "$root" bootstrap --only packages
bash "$root/scripts/brew-casks.sh"
"$mise_bin" --cd / install
# Template sources can resolve installed tools now. No tool list is duplicated.
"$mise_bin" --cd "$root" bootstrap --skip packages,tools,task

tool_paths=$("$mise_bin" --cd / bin-paths | paste -sd ':' -)
export PATH="$HOME/.local/bin:$tool_paths:$PATH"
mkdir -p "$HOME/.local/state/nono-agent-tools/"{wrangler,pub-cache,agent-browser/sockets,tmp}
mkdir -p "$HOME/.dart-tool" "$HOME/.dartServer" "$HOME/.config/flutter" "$HOME/.azure"
mkdir -p "$HOME/Pictures/Screenshots"

npm=$("$mise_bin" --cd / which --tool node npm)
"$npm" ci --prefix "$HOME/.local/share/dotfiles/secretlint" --ignore-scripts --no-audit --no-fund
case "$(uname -s)" in
Darwin) bash "$root/scripts/macos.sh" ;;
Linux)
  MISE_GLOBAL_CONFIG_FILE="$root/scripts/linux.toml" \
    "$mise_bin" --cd / bootstrap user apply
  "$HOME/.local/bin/agent-browser" install --with-deps
  bash "$root/scripts/wsl.sh"
  ;;
esac
if [[ ! -d "$HOME/.config/nono/packages/nolabs-ai/pi" ]]; then
  "$mise_bin" --cd / exec -- nono pull nolabs-ai/pi
fi
"$mise_bin" --cd / exec -- apm install -g
echo 'Setup complete. Open a new login shell.'
