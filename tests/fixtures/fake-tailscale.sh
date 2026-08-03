#!/usr/bin/env bash
set -euo pipefail

case "$*" in
  "status --json")
    if [ "${FAKE_TAILSCALE_STATUS_FAIL:-0}" = 1 ]; then exit 1; fi
    cat "$FAKE_TAILSCALE_STATUS"
    ;;
  "serve status --json")
    if [ "${FAKE_TAILSCALE_SERVE_FAIL:-0}" = 1 ]; then exit 1; fi
    cat "$FAKE_TAILSCALE_SERVE"
    ;;
  "serve --bg --https=443 http://127.0.0.1:9417")
    if [ -n "${FAKE_TAILSCALE_MUTATION_LOG:-}" ]; then printf 'serve\n' >>"$FAKE_TAILSCALE_MUTATION_LOG"; fi
    cp "$FAKE_TAILSCALE_AFTER_SETUP" "$FAKE_TAILSCALE_SERVE"
    ;;
  *) echo "unexpected tailscale argv: $*" >&2; exit 64 ;;
esac
