#!/usr/bin/env bash

set -euo pipefail

if [[ -n "${HERDR_AGENT:-}" ]]; then
  printf 'unexpected retired terminal integration: HERDR_AGENT=%s\n' "$HERDR_AGENT" >&2
  exit 1
fi

{
  printf '%s\n' '@NAME@'
  printf '%s\n' "$@"
} >>'@CALL_LOG@'
