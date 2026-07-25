#!/usr/bin/env bash

set -euo pipefail

profile="${1:-nono/profiles/chouge-agent-common.jsonc}"
nono_bin="${NONO_BIN:-$(command -v nono)}"
gh_bin="${GH_BIN:-}"

if [[ -n "${NONO_CAP_FILE:-}" ]]; then
  printf 'SKIP: nested nono cannot initialize a second macOS Seatbelt sandbox\n'
  exit 77
fi

if [[ -z "$gh_bin" ]]; then
  gh_bin="$(realpath "$(command -v gh)")"
fi
if [[ -x "$(dirname "$gh_bin")/.gh-wrapped" ]]; then
  gh_bin="$(dirname "$gh_bin")/.gh-wrapped"
fi

test_dir="$(mktemp -d "${TMPDIR:-/tmp}/nono-gh-tool-sandbox.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT
runtime_profile="$test_dir/profile.json"
state_dir="$test_dir/state"
mkdir -p "$state_dir"

# Arrange: ghのTool Sandbox境界だけを取り出し、host側のlogin情報をfixtureとして利用する。
sed '/^[[:space:]]*[/][/]/d' "$profile" |
  jq \
  --arg gh_bin "$gh_bin" \
  '{
    extends: "default",
    workdir: {access: "none"},
    command_policies: {
      credentials: .command_policies.credentials,
      commands: {
        gh: .command_policies.commands.gh
      }
    }
  }
  | walk(
      if type == "string"
      then
        gsub("@GH_BIN@"; $gh_bin)
      else .
      end
    )' >"$runtime_profile"

# Act: ghをchild sandboxで直接GitHubへ接続させる。
set +e
output="$(
  XDG_STATE_HOME="$state_dir" \
    PATH="$(dirname "$gh_bin"):/usr/bin:/bin" \
    /usr/bin/perl -e 'alarm 15; exec @ARGV' \
      "$nono_bin" run \
      --silent \
      --no-audit \
      --no-rollback \
      --profile "$runtime_profile" \
      -- \
      gh api /rate_limit 2>&1
)"
status=$?
set -e

# Assert: Keychain CAや親proxyを使わず、認証済みGitHub APIへ到達する。
if ((status != 0)); then
  printf 'expected gh API probe to complete through Tool Sandbox (status %d)\n' "$status" >&2
  exit 1
fi
if ! jq -e '.resources.core.limit | numbers' >/dev/null 2>&1 <<<"$output"; then
  printf 'expected GitHub rate-limit response shape\n' >&2
  exit 1
fi

# Act: credentialを表示するsubcommandをper-intercept sandboxで実行する。
captured="$(
  XDG_STATE_HOME="$state_dir" \
    PATH="$(dirname "$gh_bin"):/usr/bin:/bin" \
    "$nono_bin" run \
    --silent \
    --no-audit \
    --no-rollback \
    --profile "$runtime_profile" \
    -- \
    gh auth token
)"

# Assert: 実tokenではなくbroker nonceだけが呼び出し元へ返る。
if [[ ! "$captured" =~ ^nono_[[:xdigit:]]+$ ]]; then
  printf 'expected gh auth token to return a broker nonce\n' >&2
  exit 1
fi
