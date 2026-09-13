#!/usr/bin/env bash
set -euo pipefail
[[ "$(uname -s)" == Darwin ]] || exit 0
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
mise_bin=${MISE_BIN:-mise}
flags=()
case "${1:-}" in
--dry-run) flags+=(--dry-run) ;;
'')
  if [[ ! -f /opt/homebrew/opt/pam-reattach/lib/pam/pam_reattach.so ]]; then
    echo 'dotfiles: install pam-reattach before applying Touch ID settings.' >&2
    exit 1
  fi
  if ! grep -q 'auth.*include.*sudo_local' /etc/pam.d/sudo; then
    echo 'dotfiles: /etc/pam.d/sudo must include sudo_local; leaving PAM unchanged.' >&2
    exit 1
  fi
  if [[ (-e /etc/pam.d/sudo_local || -L /etc/pam.d/sudo_local) && ! -e /etc/pam.d/sudo_local.pre-mise && ! -L /etc/pam.d/sudo_local.pre-mise ]]; then
    sudo cp -P /etc/pam.d/sudo_local /etc/pam.d/sudo_local.pre-mise
  fi
  ;;
*)
  echo 'usage: scripts/macos.sh [--dry-run]' >&2
  exit 64
  ;;
esac
# The native file engine replaces the old Nix symlink atomically.
MISE_GLOBAL_CONFIG_FILE="$root/scripts/macos.toml" \
  "$mise_bin" --cd / bootstrap --only files,user "${flags[@]}"

# Raw defaults values do not expand mise templates.
if [[ "${1:-}" == --dry-run ]]; then
  printf 'would set screenshot location to %q\n' "$HOME/Pictures/Screenshots"
else
  defaults write com.apple.screencapture location -string "$HOME/Pictures/Screenshots"
fi
