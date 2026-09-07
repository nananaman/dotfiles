#!/usr/bin/env bash

set -euo pipefail

if [[ -n "${EXPECTED_HERDR_AGENT:-}" && "${HERDR_AGENT:-}" != "$EXPECTED_HERDR_AGENT" ]]; then
  printf 'expected HERDR_AGENT=%s, got %s\n' "$EXPECTED_HERDR_AGENT" "${HERDR_AGENT:-<unset>}" >&2
  exit 1
fi

{
  printf '%s\n' '@NAME@'
  printf '%s\n' "$@"
} >>'@CALL_LOG@'
