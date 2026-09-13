#!/usr/bin/env bash
set -euo pipefail
case "$(uname -s):$(uname -r)" in
Linux:*icrosoft*) ;;
*)
  echo 'Windows integration skipped (not WSL).'
  exit 0
  ;;
esac
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
flags=()
case "${1:-}" in
--dry-run) flags+=(-WhatIf) ;;
'') ;;
*)
  echo 'usage: scripts/wsl.sh [--dry-run]' >&2
  exit 64
  ;;
esac
if ! command -v wslpath >/dev/null || ! command -v powershell.exe >/dev/null; then
  echo 'dotfiles: WSL Windows interoperability is required to install fonts and Terminal settings.' >&2
  exit 1
fi
powershell.exe -NoProfile -ExecutionPolicy Bypass \
  -File "$(wslpath -w "$root/scripts/windows.ps1")" \
  -Settings "$(wslpath -w "$root/scripts/windows-terminal.json")" \
  -Fonts "$(wslpath -w "${XDG_DATA_HOME:-$HOME/.local/share}/fonts")" \
  "${flags[@]}"
