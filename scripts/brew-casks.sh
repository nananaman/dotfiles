#!/usr/bin/env bash
set -euo pipefail
[[ "$(uname -s)" == Darwin ]] || exit 0
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
flags=(--no-upgrade)
case "${1:-}" in
--dry-run)
  echo 'Would install these third-party casks with Homebrew:'
  cat "$root/scripts/Brewfile"
  exit 0
  ;;
--upgrade) flags=(--upgrade) ;;
'') ;;
*)
  echo 'usage: scripts/brew-casks.sh [--dry-run|--upgrade]' >&2
  exit 64
  ;;
esac
exec brew bundle install --file "$root/scripts/Brewfile" "${flags[@]}"
