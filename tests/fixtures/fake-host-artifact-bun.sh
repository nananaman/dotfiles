#!/usr/bin/env bash
set -euo pipefail

shift
for helper in host-artifact-service host-artifact-tailscale host-artifact-workspace; do
  resolved="$(command -v "$helper")"
  case "$resolved" in
    "$HOST_ARTIFACT_EXPECTED_HELPER_DIR"/*) ;;
    *) echo "helper did not use fixed package path: $helper -> $resolved" >&2; exit 1 ;;
  esac
done
printf '%s\n' "$*" >>"$HOST_ARTIFACT_FAKE_BUN_LOG"
