#!/usr/bin/env bash

set -euo pipefail

source_profile="${1:-nono/profiles/chouge-agent-common.jsonc}"
source_profile_dir="$(dirname "$source_profile")"
source_profile_json="$(sed '/^[[:space:]]*[/][/]/d' "$source_profile")"
test_config_root="$(mktemp -d "${TMPDIR:-/tmp}/nono-profile-test.XXXXXX")"
profile_dir="$test_config_root/nono/profiles"
gh_command="/etc/profiles/per-user/$USER/bin/gh"
if [[ ! -x "$gh_command" ]]; then
  gh_command="$(command -v gh)"
fi
gh_bin="$(realpath "$gh_command")"
mkdir -p "$profile_dir"
touch "$test_config_root/gh-config.yml"
for source in "$source_profile_dir"/*.jsonc; do
  sed \
    -e "s|@GH_BIN@|$gh_bin|g" \
    -e "s|\\\$HOME/.config/gh/config.yml|$test_config_root/gh-config.yml|g" \
    "$source" >"$profile_dir/$(basename "$source")"
done
ln -s "$HOME/.config/nono/packages" "$test_config_root/nono/packages"
trap 'rm -rf "$test_config_root"' EXIT
export XDG_CONFIG_HOME="$test_config_root"
profile="$profile_dir/$(basename "$source_profile")"

assert_profile_value() {
  local jq_filter="$1"
  local expected="$2"
  local actual

  # Arrange: Read the source profile so generated-profile permissions remain reviewable.
  # Act: Select the single capability that defines the child sandbox boundary.
  actual="$(jq -r "$jq_filter" <<<"$source_profile_json")"

  # Assert: The source profile grants only the explicitly reviewed capability.
  if [[ "$actual" != "$expected" ]]; then
    printf 'expected profile value %q, got %q\n' "$expected" "$actual" >&2
    return 1
  fi
}

assert_profile_array_contains() {
  local jq_filter="$1"
  local expected="$2"

  # Arrange: JSONC sourceを正規化した値から、宣言されたcapabilityだけを検査する。
  # Act & Assert: 必須のgroupまたはdomainがsource profileに明記されていることを確認する。
  if ! jq -e --arg expected "$expected" "$jq_filter | index(\$expected) != null" \
    <<<"$source_profile_json" >/dev/null; then
    printf 'expected profile array %s to contain %q\n' "$jq_filter" "$expected" >&2
    return 1
  fi
}

assert_host_decision() {
  local expected="$1"
  local host="$2"
  local output

  # Arrange: 外部接続を発生させず、source profileのnetwork policyを直接評価する。
  # Act: nonoにHTTPS接続の判定を問い合わせる。
  output="$(nono why --profile "$profile" --host "$host" --port 443)"

  # Assert: 開発用endpointと境界外domainが意図した判定になることを確認する。
  if [[ "${output%%$'\n'*}" != "$expected" ]]; then
    printf 'expected %s for %s:443, got:\n%s\n' "$expected" "$host" "$output" >&2
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

assert_path_decision() {
  local expected="$1"
  local target_path="$2"
  local operation="$3"
  local output

  # Arrange: 実際のfilesystemを変更せず、source profileのpath境界を評価する。
  # Act: nonoに対象pathとoperationの判定を問い合わせる。
  output="$(nono why --profile "$profile" --path "$target_path" --op "$operation")"

  # Assert: 開発資産に必要なaccessだけが意図した判定になることを確認する。
  if [[ "${output%%$'\n'*}" != "$expected" ]]; then
    printf 'expected %s for %s access to %s, got:\n%s\n' \
      "$expected" "$operation" "$target_path" "$output" >&2
    return 1
  fi
}

assert_agent_network_boundary() {
  local agent="$1"
  local provider_domain="$2"
  local source_profile="$profile_dir/chouge-$agent.jsonc"
  local output

  # Arrange: Use the JSONC source profile so comments and inheritance are
  # exercised through nono's public profile loader.

  # Act: Classify the shared GitHub endpoint.
  output="$(nono why --profile "$source_profile" --host api.github.com --port 443)"
  # Assert: Every agent can reach GitHub through the shared grant.
  [[ "${output%%$'\n'*}" == "ALLOWED" ]] || return 1

  # Act: Classify this agent's configured provider endpoint.
  output="$(nono why --profile "$source_profile" --host "$provider_domain" --port 443)"
  # Assert: The agent-specific provider endpoint is reachable.
  [[ "${output%%$'\n'*}" == "ALLOWED" ]] || return 1

}

test_protected_credentials_remain_unreadable() {
  assert_path_read_is_denied "$HOME/.config/gh/hosts.yml"
}

test_github_credential_files_are_not_granted_to_the_parent_session() {
  # Arrange: hosts.ymlはgh childだけにgrantし、agent本体のprotected path denyを維持する。
  # Act & Assert: 親profileのfilesystemとenvironmentにはgh credential例外を持たない。
  assert_profile_value \
    '.filesystem.read_file | index("$HOME/.config/gh/config.yml") == null' \
    'true'
  assert_profile_value '.environment.set_vars.GH_CONFIG_DIR // null' 'null'
  assert_profile_value '.network.credentials // [] | index("github") == null' 'true'
}

test_ssh_private_key_remains_unreadable() {
  assert_path_read_is_denied "$HOME/.ssh/id_ed25519"
}

test_common_profile_includes_general_development_groups() {
  local group

  for group in \
    bun_runtime \
    go_runtime \
    go_runtime_linux \
    go_runtime_macos \
    java_runtime \
    mise_manager \
    nix_runtime \
    node_runtime \
    python_runtime \
    rust_runtime; do
    assert_profile_array_contains '.groups.include' "$group"
  done
}

test_common_profile_keeps_sensitive_data_denied_by_group() {
  local group

  for group in \
    deny_credentials \
    deny_keychains_macos \
    deny_keychains_linux \
    deny_browser_data_macos \
    deny_browser_data_linux \
    deny_macos_private \
    deny_shell_history \
    deny_shell_configs; do
    assert_profile_array_contains '.groups.include' "$group"
  done
}

test_common_profile_uses_enterprise_network() {
  assert_profile_value \
    '.network.network_profile' \
    'enterprise'
}

test_common_profile_allows_development_endpoints() {
  local host

  for host in \
    artifactregistry.googleapis.com \
    chatgpt.com \
    proxy.golang.org \
    sum.golang.org \
    gcr.io \
    us-docker.pkg.dev; do
    assert_host_decision "ALLOWED" "$host"
  done
}

test_common_profile_denies_unconfigured_clouds() {
  assert_host_decision "DENIED" management.azure.com
}

test_common_profile_allows_all_ghq_repositories() {
  assert_path_decision \
    "ALLOWED" \
    "$HOME/ghq/github.com/openai/symphony" \
    "readwrite"
}

test_common_profile_allows_new_ghq_clone_destinations() {
  assert_path_decision \
    "ALLOWED" \
    "$HOME/ghq/github.com/example-owner/example-repository" \
    "readwrite"
}

test_github_credential_is_scoped_to_the_tool_sandbox() {
  local packages_module='nix/modules/home/packages.nix'
  local dotfiles_module='nix/modules/home/dotfiles.nix'

  # Arrange: ghはKeychain依存のTLS interceptionを使わず、nono標準shimからNix packageの実体を実行する。
  # Act: ghのcredential、network、filesystem境界とpackage構成を確認する。
  # Assert: hosts.ymlはghだけが読み、重複wrapperやsandbox内での二段execなしにGitHub操作を自走できる。
  assert_profile_value \
    '.command_policies.commands.gh.from.session.sandbox.fs_read_file | index("$HOME/.config/gh/hosts.yml") != null' \
    'true'
  assert_profile_value \
    '.command_policies.commands.gh.from.session.sandbox.network.allow_all' \
    'true'
  assert_profile_value \
    '.command_policies.commands.gh.from.session.invocation_policy.default' \
    'allow'
  rg -q '^[[:space:]]+gh$' "$packages_module"
  if rg -q 'gh-sandboxed' "$packages_module"; then
    printf 'expected gh to use the standard nono shim without a duplicate wrapper\n' >&2
    return 1
  fi
  rg -Fq '"${pkgs.gh}/bin/.gh-wrapped"' "$dotfiles_module"
}

test_github_auth_token_is_captured_with_a_per_intercept_sandbox() {
  # Arrange: ghは認証済みhosts.ymlを利用するが、実tokenをagentのstdoutへ返してはならない。
  # Act: auth token用interceptのactionと置換sandboxを確認する。
  # Assert: 実tokenをambient credentialへcaptureし、通常gh sandboxとは分離する。
  assert_profile_value \
    '.command_policies.commands.gh.intercept[] | select(.args == ["auth", "token"]) | .action.type' \
    'capture_credential'
  assert_profile_value \
    '.command_policies.commands.gh.intercept[] | select(.args == ["auth", "token"]) | .action.credential' \
    'github'
  assert_profile_value \
    '.command_policies.commands.gh.intercept[] | select(.args == ["auth", "token"]) | .sandbox.fs_read_file | index("$HOME/.config/gh/hosts.yml") != null' \
    'true'
}

test_github_credential_changes_are_denied_without_approval() {
  # Arrange: agentはGitHub APIを自走できるが、host側のlogin状態は変更しない。
  # Act & Assert: credential変更commandをdenyし、approve decisionを導入しない。
  assert_profile_value \
    '[.command_policies.commands.gh.from.session.invocation_policy.deny[].argv.prefix] | any(. == ["auth", "login"])' \
    'true'
  assert_profile_value \
    '[.command_policies.commands.gh.from.session.invocation_policy.deny[].argv.prefix] | any(. == ["auth", "logout"])' \
    'true'
  assert_profile_value \
    '[.. | strings | select(. == "approve")] | length' \
    '0'
}

test_command_policies_never_require_human_approval() {
  # Arrange: agent commandは対話待ちを発生させず、allowまたはdenyで即時決定する。
  # Act & Assert: approval backend、approve decision、default approveを一切持たない。
  assert_profile_value '.command_policies | has("approval_backends")' 'false'
  assert_profile_value '.command_policies | has("approval_defaults")' 'false'
  assert_profile_value '[.. | strings | select(. == "approve")] | length' '0'
  assert_profile_value \
    '.command_policies.commands.container.from.session.invocation_policy.default' \
    'deny'
}

test_container_wrapper_prefers_the_tool_sandbox_shim() {
  local packages_module='nix/modules/home/packages.nix'

  # Arrange: Codex sessionではagent wrapper directoryがnonoのshimよりPATHの前に置かれる。
  # Act: PATH順序を補正するcontainer wrapperのdispatch条件をsourceから確認する。
  # Assert: Homebrew launcherからlibexecを直接起動せず、生成済みshimへ委譲する。
  rg -q 'NONO_TOOL_SANDBOX_SHIM_DIR.*/container' "$packages_module"
  rg -q 'container-sandboxed' "$packages_module"
}

test_local_agent_tools_use_the_parent_sandbox() {
  local command

  # Arrange: PiとHerdrは、既存agent sessionのfilesystem/network境界を再利用する。
  for command in pi herdr; do
    # Act: source profileに個別のTool Sandbox定義があるか確認する。
    # Assert: 二重sandboxやlocal orchestrationのargv制限を避けるため、個別定義を持たない。
    assert_profile_value \
      ".command_policies.commands | has(\"$command\")" \
      'false'
  done
}

test_codex_allows_chatgpt_subscription_endpoint() {
  assert_agent_network_boundary codex chatgpt.com
}

test_claude_allows_anthropic_api_endpoint() {
  assert_agent_network_boundary claude api.anthropic.com
}

test_pi_allows_configured_openai_codex_endpoint() {
  assert_agent_network_boundary pi chatgpt.com
}

test_protected_credentials_remain_unreadable
test_github_credential_files_are_not_granted_to_the_parent_session
test_ssh_private_key_remains_unreadable
test_common_profile_includes_general_development_groups
test_common_profile_keeps_sensitive_data_denied_by_group
test_common_profile_uses_enterprise_network
test_common_profile_allows_development_endpoints
test_common_profile_denies_unconfigured_clouds
test_common_profile_allows_all_ghq_repositories
test_common_profile_allows_new_ghq_clone_destinations
test_github_credential_is_scoped_to_the_tool_sandbox
test_github_auth_token_is_captured_with_a_per_intercept_sandbox
test_github_credential_changes_are_denied_without_approval
test_command_policies_never_require_human_approval
test_container_wrapper_prefers_the_tool_sandbox_shim
test_local_agent_tools_use_the_parent_sandbox
test_codex_allows_chatgpt_subscription_endpoint
test_claude_allows_anthropic_api_endpoint
test_pi_allows_configured_openai_codex_endpoint
