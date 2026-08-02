#!/usr/bin/env bash

set -euo pipefail

username="${1:-$(id -un)}"
shift || true

for configuration_name in "$@"; do
  if [[ "$username" == "$configuration_name" ]]; then
    printf '%s\n' "$username"
    exit 0
  fi
done

printf 'Unsupported macOS user: %s\n' "$username" >&2
exit 1
