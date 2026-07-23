#!/usr/bin/env bash

set -euo pipefail

profile="${1:-nono/profiles/chouge-agent-common.json}"
profile_dir="$(dirname "$profile")"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/nono-network-profile.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT

assert_profile_value() {
  local jq_filter="$1"
  local expected="$2"
  local actual

  # Arrange: Read the source profile so generated-profile permissions remain reviewable.
  # Act: Select the single capability that defines the child sandbox boundary.
  actual="$(jq -r "$jq_filter" "$profile")"

  # Assert: The source profile grants only the explicitly reviewed capability.
  if [[ "$actual" != "$expected" ]]; then
    printf 'expected profile value %q, got %q\n' "$expected" "$actual" >&2
    return 1
  fi
}

assert_decision() {
  local expected="$1"
  shift
  local output

  # Arrange: Evaluate the source profile directly so installed profile state cannot hide drift.
  # Act: Ask nono to classify the command without executing it.
  output="$(nono why --profile "$profile" --command gh -- "$@")"

  # Assert: The first line is nono's public allow/deny decision for this argv boundary.
  if [[ "${output%%$'\n'*}" != "$expected" ]]; then
    printf 'expected %s for gh' "$expected" >&2
    printf ' %q' "$@" >&2
    printf ', got:\n%s\n' "$output" >&2
    return 1
  fi
}

assert_path_read_is_denied() {
  local path="$1"
  local output

  # Arrange: Query the same profile without a command-specific sandbox exception.
  # Act: Ask nono whether the agent can read the protected path directly.
  output="$(nono why --profile "$profile" --path "$path" --op read)"

  # Assert: Direct reads remain denied independently of command policy.
  if [[ "${output%%$'\n'*}" != "DENIED" ]]; then
    printf 'expected DENIED for direct read of %s, got:\n%s\n' "$path" "$output" >&2
    return 1
  fi
}

assert_agent_network_boundary() {
  local agent="$1"
  local provider_domain="$2"
  local denied_domain="$3"
  local source_profile="$profile_dir/chouge-$agent.json"
  local resolved_profile="$test_dir/chouge-$agent.json"
  local output

  # Arrange: Flatten only the reviewed common and provider grants so installed
  # profile state cannot hide source drift.
  jq -n \
    --argjson common "$(jq '.network.allow_domain' "$profile")" \
    --argjson provider "$(jq '.network.allow_domain' "$source_profile")" \
    '{extends: "default", network: {allow_domain: ($common + $provider)}}' \
    >"$resolved_profile"

  # Act: Classify the shared GitHub endpoint.
  output="$(nono why --profile "$resolved_profile" --host api.github.com --port 443)"
  # Assert: Every agent can reach GitHub through the shared grant.
  [[ "${output%%$'\n'*}" == "ALLOWED" ]] || return 1

  # Act: Classify this agent's configured provider endpoint.
  output="$(nono why --profile "$resolved_profile" --host "$provider_domain" --port 443)"
  # Assert: The agent-specific provider endpoint is reachable.
  [[ "${output%%$'\n'*}" == "ALLOWED" ]] || return 1

  # Act: Classify a provider endpoint not assigned to this agent.
  output="$(nono why --profile "$resolved_profile" --host "$denied_domain" --port 443)"
  # Assert: Unassigned providers remain outside this agent's boundary.
  if [[ "${output%%$'\n'*}" != "DENIED" ]]; then
    printf 'expected DENIED for %s from %s, got:\n%s\n' "$denied_domain" "$agent" "$output" >&2
    return 1
  fi
}

test_git_credential_helper_can_supply_git_credentials() {
  assert_decision "ALLOWED" auth git-credential get
}

test_git_credential_helper_changes_are_denied() {
  local operation

  for operation in store erase; do
    assert_decision "DENIED" auth git-credential "$operation"
  done
}

test_credential_changes_are_denied() {
  local subcommand

  for subcommand in login logout refresh setup-git switch; do
    assert_decision "DENIED" auth "$subcommand"
  done
}

test_direct_credential_read_is_denied() {
  assert_decision "DENIED" auth token
}

test_github_rate_limit_probe_is_allowed() {
  assert_decision "ALLOWED" api /rate_limit
}

test_pull_request_creation_is_allowed() {
  assert_decision "ALLOWED" pr create --repo nananaman/skills
}

test_skills_pull_request_api_is_allowed() {
  assert_decision "ALLOWED" api repos/nananaman/skills/pulls --method POST
}

test_unclassified_auth_command_requires_approval() {
  assert_decision "APPROVAL REQUIRED" auth status
}

test_protected_credentials_remain_unreadable() {
  assert_path_read_is_denied "$HOME/.config/gh/hosts.yml"
}

test_ssh_private_key_remains_unreadable() {
  assert_path_read_is_denied "$HOME/.ssh/id_ed25519"
}

test_gh_child_can_read_working_directory() {
  assert_profile_value \
    '.command_policies.commands.gh.from.session.sandbox.fs_read | join("\n")' \
    '$WORKDIR'
}

test_gh_child_can_execute_only_the_pinned_nix_binary() {
  assert_profile_value \
    '.command_policies.commands.gh.from.session.sandbox.unsafe_macos_seatbelt_rules[0]' \
    '(allow process-exec (literal "@GH_WRAPPED@"))'
}

test_gh_child_can_reach_the_parent_proxy() {
  assert_profile_value \
    '.command_policies.commands.gh.from.session.sandbox.unsafe_macos_seatbelt_rules[1]' \
    '(allow network-outbound (remote tcp "localhost:*"))'
}

test_gh_child_reuses_parent_network_proxy() {
  assert_profile_value \
    '.command_policies.commands.gh.from.session.sandbox | has("network")' \
    'false'
}

test_common_profile_allows_only_github_api() {
  assert_profile_value \
    '.network | tojson' \
    '{"allow_domain":["api.github.com"]}'
}

test_gh_child_inherits_parent_proxy_environment() {
  assert_profile_value \
    '.command_policies.commands.gh.from.session.sandbox | has("environment")' \
    'false'
}

test_codex_allows_chatgpt_subscription_endpoint() {
  assert_agent_network_boundary codex chatgpt.com api.anthropic.com
}

test_claude_allows_anthropic_api_endpoint() {
  assert_agent_network_boundary claude api.anthropic.com chatgpt.com
}

test_pi_allows_configured_openai_codex_endpoint() {
  assert_agent_network_boundary pi chatgpt.com api.anthropic.com
}

test_git_credential_helper_can_supply_git_credentials
test_git_credential_helper_changes_are_denied
test_credential_changes_are_denied
test_direct_credential_read_is_denied
test_github_rate_limit_probe_is_allowed
test_pull_request_creation_is_allowed
test_skills_pull_request_api_is_allowed
test_unclassified_auth_command_requires_approval
test_protected_credentials_remain_unreadable
test_ssh_private_key_remains_unreadable
test_gh_child_can_read_working_directory
test_gh_child_can_execute_only_the_pinned_nix_binary
test_gh_child_can_reach_the_parent_proxy
test_gh_child_reuses_parent_network_proxy
test_common_profile_allows_only_github_api
test_gh_child_inherits_parent_proxy_environment
test_codex_allows_chatgpt_subscription_endpoint
test_claude_allows_anthropic_api_endpoint
test_pi_allows_configured_openai_codex_endpoint
