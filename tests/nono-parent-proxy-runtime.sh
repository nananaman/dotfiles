#!/usr/bin/env bash

set -euo pipefail

profile="${1:-nono/profiles/chouge-agent-common.json}"
nono_bin="${NONO_BIN:-$(command -v nono)}"
gh_wrapped="${GH_WRAPPED_BIN:-}"

if [[ -n "${NONO_CAP_FILE:-}" ]]; then
  printf 'SKIP: nested nono cannot initialize a second macOS Seatbelt sandbox\n'
  exit 77
fi

if [[ -z "$gh_wrapped" ]]; then
  gh_wrapped="$(realpath "$(command -v gh)")"
fi

test_dir="$(mktemp -d "${TMPDIR:-/tmp}/nono-parent-proxy.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT
runtime_profile="$test_dir/profile.json"
bin_dir="$test_dir/bin"
state_dir="$test_dir/state"
mkdir -p "$bin_dir" "$state_dir"
ln -s "$gh_wrapped" "$bin_dir/gh"

# Arrange: Resolve source placeholders and retain the real parent-network/gh-child
# policy while excluding unrelated commands from executable discovery.
jq \
  --arg home "$HOME" \
  --arg gh_wrapped "$gh_wrapped" \
  '{
    extends: "default",
    network: .network,
    command_policies: {
      approval_backends: .command_policies.approval_backends,
      approval_defaults: .command_policies.approval_defaults,
      commands: {gh: .command_policies.commands.gh}
    }
  }
  | walk(
      if type == "string"
      then gsub("@HOME@"; $home) | gsub("@GH_WRAPPED@"; $gh_wrapped)
      else .
      end
    )' \
  "$profile" >"$runtime_profile"

# Act: Start the parent sandbox and make the HTTPS request that regressed.
# A bounded probe turns the observed indefinite wait into a deterministic failure.
set +e
output="$(
  XDG_STATE_HOME="$state_dir" \
    PATH="$bin_dir:/usr/bin:/bin" \
    /usr/bin/perl -e 'alarm 15; exec @ARGV' \
      "$nono_bin" run \
      --silent \
      --no-audit \
      --no-rollback \
      --profile "$runtime_profile" \
      -- \
      /bin/sh -c 'gh api /rate_limit' 2>&1
)"
status=$?
set -e

# Assert: The real gh child completed through the parent proxy and returned the
# expected public response shape without exposing credential or proxy values.
if ((status != 0)); then
  printf 'expected gh API probe to complete through the parent proxy (status %d)\n' "$status" >&2
  exit 1
fi
if ! jq -e '.resources.core.limit | numbers' >/dev/null 2>&1 <<<"$output"; then
  printf 'expected GitHub rate-limit response shape\n' >&2
  exit 1
fi
