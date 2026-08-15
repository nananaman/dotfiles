#!/usr/bin/env bash

set -euo pipefail

source_profile="${1:-nono/profiles/chouge-agent-common.jsonc}"
source_profile_dir="$(dirname "$source_profile")"
normalize_jsonc_for_jq() {
  sed '/^[[:space:]]*[/][/]/d' "$1" | perl -0pe 's/,\s*([}\]])/$1/g'
}

source_profile_json="$(normalize_jsonc_for_jq "$source_profile")"
test_config_root="$(mktemp -d "${TMPDIR:-/tmp}/nono-profile-test.XXXXXX")"
test_publish_root="$test_config_root/host-artifact/public"
test_claude_state_root="$test_config_root/claude-state"
test_neovim_root="$test_config_root/neovim"
test_agent_tool_state_root="$test_config_root/agent-tool-state"
test_flutter_dart_root="$test_config_root/flutter-dart"
profile_dir="$test_config_root/nono/profiles"
mkdir -p \
  "$profile_dir" \
  "$test_publish_root/example" \
  "$test_claude_state_root/locks" \
  "$test_neovim_root/config" \
  "$test_neovim_root/share" \
  "$test_neovim_root/state" \
  "$test_agent_tool_state_root/wrangler" \
  "$test_agent_tool_state_root/pub-cache" \
  "$test_flutter_dart_root/dart-tool" \
  "$test_flutter_dart_root/dart-server" \
  "$test_flutter_dart_root/flutter-config"
for source in "$source_profile_dir"/*.jsonc; do
  cp "$source" "$profile_dir/$(basename "$source")"
done
cat >"$profile_dir/claude-code.jsonc" <<EOF
{
  "meta": {
    "name": "claude-code",
    "description": "Test-local Claude Code profile stub"
  },
  "filesystem": {
    "allow": ["$test_claude_state_root/locks"]
  },
  "open_urls": {
    "allow_origins": [
      "https://claude.ai",
      "https://claude.com",
      "https://api.anthropic.com",
      "https://platform.claude.com"
    ],
    "allow_localhost": true
  },
  "allow_launch_services": true
}
EOF
cat >"$profile_dir/pi.jsonc" <<'EOF'
{
  "meta": {
    "name": "pi",
    "description": "Test-local Pi profile stub"
  }
}
EOF
for copied_profile in "$profile_dir"/*.jsonc; do
  rendered_profile="$copied_profile.rendered"
  sed \
    -e "s|@HOME@|$HOME|g" \
    -e 's|$HOME/.local/share/host-artifact/public|'"$test_publish_root"'|g' \
    -e 's|$HOME/.local/state/claude/locks|'"$test_claude_state_root/locks"'|g' \
    -e 's|$HOME/.config/nvim|'"$test_neovim_root/config"'|g' \
    -e 's|$HOME/.local/share/nvim|'"$test_neovim_root/share"'|g' \
    -e 's|$HOME/.local/state/nvim|'"$test_neovim_root/state"'|g' \
    -e 's|$HOME/.local/state/nono-agent-tools|'"$test_agent_tool_state_root"'|g' \
    -e 's|$HOME/.dart-tool|'"$test_flutter_dart_root/dart-tool"'|g' \
    -e 's|$HOME/.dartServer|'"$test_flutter_dart_root/dart-server"'|g' \
    -e 's|$HOME/.config/flutter|'"$test_flutter_dart_root/flutter-config"'|g' \
    -e 's|$HOME/.local/share/mise/installs/flutter/3.35.4-stable/bin/cache|'"$test_flutter_dart_root/flutter-sdk-cache"'|g' \
    "$copied_profile" >"$rendered_profile"
  mv "$rendered_profile" "$copied_profile"
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

assert_agent_host_decision() {
  local agent="$1"
  local expected="$2"
  local host="$3"
  local port="$4"
  local source_profile="$profile_dir/chouge-$agent.jsonc"
  local output

  # Arrange: 外部接続せず、agent固有profileのhost/port境界を評価する。
  # Act: nonoに観測先endpointの判定を問い合わせる。
  output="$(nono why --profile "$source_profile" --host "$host" --port "$port")"

  # Assert: read-only observabilityに必要なexact endpointだけが許可される。
  if [[ "${output%%$'\n'*}" != "$expected" ]]; then
    printf 'expected %s for %s:%s in %s, got:\n%s\n' \
      "$expected" "$host" "$port" "$agent" "$output" >&2
    return 1
  fi
}

assert_agent_path_decision() {
  local agent="$1"
  local expected="$2"
  local target_path="$3"
  local operation="$4"
  local output

  # Arrange: Evaluate the shared setting through an actual inherited agent profile.
  # Act: Ask nono for the effective filesystem decision after profile composition.
  output="$(nono why --profile "$profile_dir/chouge-$agent.jsonc" --path "$target_path" --op "$operation")"

  # Assert: Every agent keeps the same cache and credential boundary.
  if [[ "${output%%$'\n'*}" != "$expected" ]]; then
    printf 'expected %s for chouge-%s %s access to %s, got:\n%s\n' \
      "$expected" "$agent" "$operation" "$target_path" "$output" >&2
    return 1
  fi
}

assert_agent_profile_value() {
  local agent="$1"
  local jq_filter="$2"
  local expected="$3"
  local agent_source_json
  local actual

  # Arrange: Normalize the checked-in agent profile while retaining it as the source of truth.
  agent_source_json="$(normalize_jsonc_for_jq "$source_profile_dir/chouge-$agent.jsonc")"

  # Act: Select the exact agent-specific capability under review.
  actual="$(jq -r "$jq_filter" <<<"$agent_source_json")"

  # Assert: The source profile contains only the explicitly reviewed boundary.
  if [[ "$actual" != "$expected" ]]; then
    printf 'expected agent profile value %q, got %q\n' "$expected" "$actual" >&2
    return 1
  fi
}

assert_container_command_decision() {
  local expected="$1"
  shift
  local output

  # Arrange: Use nono's policy evaluator so no container state is changed.
  # Act: Classify the requested Apple container CLI invocation.
  output="$(nono why --profile "$profile" --command container -- "$@")"

  # Assert: The command matches the reviewed allow or deny boundary.
  if [[ "${output%%$'\n'*}" != "$expected" ]]; then
    printf 'expected %s for container %q, got:\n%s\n' "$expected" "$*" "$output" >&2
    return 1
  fi
}

test_github_cli_uses_the_parent_sandbox() {
  # Arrange: ghはgitと同じ親sandboxでrepositoryと認証設定を利用する。
  # Act: gh固有のcommand policyとGitHub CLI設定directoryの権限を確認する。
  # Assert: child sandboxを作らず、親sandboxから設定を読み書きできる。
  assert_profile_value \
    '.command_policies.commands | has("gh")' \
    'false'
  assert_profile_value \
    '.filesystem.read | index("$HOME/.config/gh") != null' \
    'true'
  assert_profile_value \
    '.filesystem.bypass_protection | index("$HOME/.config/gh") != null' \
    'true'
  assert_path_decision \
    "ALLOWED" \
    "$HOME/.config/gh/hosts.yml" \
    "read"
  assert_path_decision \
    "DENIED" \
    "$HOME/.config/gh/hosts.yml" \
    "write"
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

test_common_profile_allows_neovim_external_editor_state() {
  # Arrange: Codexのexternal editorはuser設定を読み、Neovim専用data/stateへ書き込む。
  # Act & Assert: 必要な3 subtreeだけを宣言し、親directoryへ権限を広げない。
  assert_profile_array_contains '.filesystem.read' '$HOME/.config/nvim'
  assert_profile_array_contains '.filesystem.allow' '$HOME/.local/share/nvim'
  assert_profile_array_contains '.filesystem.allow' '$HOME/.local/state/nvim'
  assert_profile_value '.filesystem.read | index("$HOME/.config") == null' 'true'
  assert_profile_value '.filesystem.allow | index("$HOME/.local/share") == null' 'true'
  assert_profile_value '.filesystem.allow | index("$HOME/.local/state") == null' 'true'
}

test_common_profile_allows_claude_lock_state_without_broad_state_access() {
  # Arrange: Nested Claude Code launches resolve the registry profile lock directory.
  # Act & Assert: Only the Claude lock subtree is shared; broader state remains denied.
  assert_profile_array_contains '.filesystem.allow' '$HOME/.local/state/claude/locks'
  assert_profile_value '.filesystem.allow | index("$HOME/.local/state/claude") == null' 'true'
  assert_profile_value '.filesystem.allow | index("$HOME/.local/state") == null' 'true'
}

test_common_profile_keeps_chrome_data_outside_direct_agent_access() {
  # Arrange: Chrome bridge traffic uses its socket and does not require direct browser-data reads.
  # Act & Assert: No local agent receives a Chrome user-data read or protection bypass.
  assert_profile_value \
    '.platform_overrides.macos.filesystem.read | map(select(contains("Google/Chrome"))) | length' \
    '0'
  assert_profile_value \
    '(.platform_overrides.macos.filesystem.bypass_protection // []) | map(select(contains("Google/Chrome"))) | length' \
    '0'
}

test_common_profile_allows_only_the_chrome_bridge_socket_subtree() {
  # Arrange: Chrome bridge socket names are generated beneath one canonical macOS directory.
  # Act & Assert: All local agents may connect only within that browser bridge subtree.
  assert_profile_value \
    '[.unsafe_macos_seatbelt_rules[] | select(contains("codex-browser-use"))] | tojson' \
    '["(allow network-outbound (subpath \"/private/tmp/codex-browser-use\"))"]'
  assert_profile_value \
    '.platform_overrides.macos.filesystem | has("unix_socket_subtree")' \
    'false'
}

test_common_profile_allows_only_the_nix_daemon_socket() {
  # Arrange: macOSのmulti-user Nix buildは、symlink解決後の固定daemon socketへ接続する。
  # Act & Assert: 親sandboxには解決後のNix daemon exact socketだけを追加する。
  assert_profile_value \
    '[.unsafe_macos_seatbelt_rules[] | select(contains("nix-daemon.socket"))] | tojson' \
    '["(allow network-outbound (path \"/private/var/run/nix-daemon.socket\"))"]'

  # Act & Assert: system適用に必要なsudoは引き続きcommand policyで拒否する。
  local output
  output="$(nono why --profile "$profile" --command sudo -- -H nix run nix-darwin -- switch)"
  [[ "${output%%$'\n'*}" == "DENIED" ]] || return 1
}

test_common_profile_uses_a_dedicated_agent_tmpdir_for_unix_sockets() {
  # Arrange: go-pluginはTMPDIR直下にランダム名のUnix socketを作る。
  # Act & Assert: agent専用TMPDIRだけを使い、macOSのuser/session固有pathへ依存しない。
  assert_profile_value \
    '.platform_overrides.macos.environment.set_vars.TMPDIR' \
    '$HOME/.local/state/nono-agent-tools/tmp'
  assert_profile_value \
    '.platform_overrides.macos.filesystem.allow | index("$HOME/.local/state/nono-agent-tools/tmp") != null' \
    'true'
  assert_profile_value \
    '.environment.set_vars | has("TMPDIR")' \
    'false'
  assert_profile_value \
    '[.unsafe_macos_seatbelt_rules[] | select(contains("nono-agent-tools/tmp"))] | tojson' \
    '["(allow network-bind (subpath \"@HOME@/.local/state/nono-agent-tools/tmp\"))","(allow network-outbound (subpath \"@HOME@/.local/state/nono-agent-tools/tmp\"))"]'
  assert_profile_value \
    '[.unsafe_macos_seatbelt_rules[] | select(contains("/private/var/folders"))] | length' \
    '0'
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

test_common_profile_allows_only_the_terraform_provider_distribution_endpoints() {
  # Arrange & Act: Terraform providerのservice discovery先、配布先、隣接hostを評価する。
  # Assert: 公式配布のexact hostだけを共通profileから利用できる。
  assert_host_decision "ALLOWED" registry.terraform.io
  assert_host_decision "ALLOWED" releases.hashicorp.com
  assert_host_decision "DENIED" attacker.registry.terraform.io
  assert_host_decision "DENIED" unrelated.terraform.io
  assert_host_decision "DENIED" attacker.releases.hashicorp.com
  assert_host_decision "DENIED" unrelated.hashicorp.com
}

test_agent_profiles_inherit_terraform_provider_distribution_endpoints() {
  local agent
  local host
  local output

  # Arrange: 共通network policyを継承し、固有domainも追加する全agent profileを使う。
  for agent in codex claude pi; do
    for host in registry.terraform.io releases.hashicorp.com; do
      # Act: 合成後のprofileでTerraform provider配布hostを評価する。
      output="$(nono why --profile "$profile_dir/chouge-$agent.jsonc" --host "$host" --port 443)"

      # Assert: agent固有のnetwork設定が共通の配布許可を上書きしない。
      [[ "${output%%$'\n'*}" == "ALLOWED" ]] || return 1
    done
  done
}

test_common_profile_allows_github_actions_log_endpoint() {
  # Arrange & Act: GitHub CLIがActionsのjob log取得でredirectされるHTTPS hostを評価する。
  # Assert: 認証済みのgh run viewがlog archiveを取得できる。
  assert_host_decision "ALLOWED" results-receiver.actions.githubusercontent.com
}

test_common_profile_does_not_allow_all_github_actions_hosts() {
  # Arrange & Act: 許可したlog配信hostと同じ親domainの未設定hostを評価する。
  # Assert: GitHub Actions配下をwildcardで許可せず、exact hostの境界を保つ。
  assert_host_decision "DENIED" unrelated.actions.githubusercontent.com
}

test_common_profile_allows_github_actions_blob_log_endpoint() {
  # Arrange & Act: GitHub Actionsのlog archiveがredirectされるshard付きAzure Blob hostを評価する。
  # Assert: shard名が変わっても公式のlog配信suffix配下なら取得できる。
  assert_host_decision "ALLOWED" productionresultssa5.blob.core.windows.net
}

test_common_profile_does_not_allow_azure_blob_apex() {
  # Arrange & Act: wildcard対象外のAzure Blob apexを評価する。
  # Assert: subdomain用wildcardがapex自体へ権限を広げない。
  assert_host_decision "DENIED" blob.core.windows.net
}

test_common_profile_does_not_allow_adjacent_azure_storage_suffix() {
  # Arrange & Act: GitHub公式allowlistとは異なるAzure Storage suffixを評価する。
  # Assert: Azure Storage全体ではなくBlob endpointだけを許可する。
  assert_host_decision "DENIED" productionresultssa5.file.core.windows.net
}

test_common_profile_allows_tailscale_serve_origins() {
  # Arrange & Act: Evaluate a representative MagicDNS HTTPS origin without connecting to it.
  # Assert: Host-artifact can verify its Tailscale Serve URL through the parent sandbox.
  assert_host_decision "ALLOWED" "machine.tailnet.ts.net"
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

test_common_profile_configures_sandbox_compatible_javascript_tools() {
  local agent

  # Arrange: pnpm lifecycle scripts and Wrangler state must stay inside existing sandbox grants.
  # Act & Assert: Use the allowed system shell and dedicated Wrangler-only state paths.
  assert_profile_value '.environment.set_vars.npm_config_script_shell' '/bin/sh'
  assert_profile_value \
    '.environment.set_vars.WRANGLER_LOG_PATH' \
    '$HOME/.local/state/nono-agent-tools/wrangler/logs'
  assert_profile_value \
    '.environment.set_vars.WRANGLER_REGISTRY_PATH' \
    '$HOME/.local/state/nono-agent-tools/wrangler/registry'
  assert_profile_value \
    '.environment.set_vars.MINIFLARE_REGISTRY_PATH' \
    '$HOME/.local/state/nono-agent-tools/wrangler/registry'

  # Act & Assert: Dedicated state is reusable while global credential files remain non-writable.
  for agent in codex claude pi; do
    assert_agent_path_decision \
      "$agent" "ALLOWED" "$test_agent_tool_state_root/wrangler/logs/session.log" "readwrite"
    assert_agent_path_decision \
      "$agent" "ALLOWED" "$test_agent_tool_state_root/wrangler/registry/dev.json" "readwrite"
    assert_agent_path_decision \
      "$agent" "DENIED" "$HOME/.config/.wrangler/config/default.toml" "write"
    assert_agent_path_decision \
      "$agent" "DENIED" "$HOME/Library/Preferences/.wrangler/config/default.toml" "write"
  done

  # Assert: Home Manager creates the grant root before nono resolves filesystem capabilities.
  rg -q -F \
    '$DRY_RUN_CMD mkdir -p "${homeDirectory}/.local/state/nono-agent-tools/wrangler"' \
    nix/modules/home/dotfiles.nix
}

test_common_profile_allows_flutter_and_dart_runtime_state_without_home_wide_access() {
  local agent

  # Arrange: Flutter 3.35.4 and Dart use shared package data plus three product-specific state roots.
  # Act & Assert: Grant each runtime path only the mode required by standard generation, lint, and test commands.
  assert_profile_value '.environment.set_vars.PUB_CACHE' '$HOME/.local/state/nono-agent-tools/pub-cache'
  assert_profile_array_contains '.filesystem.allow' '$HOME/.local/state/nono-agent-tools/pub-cache'
  assert_profile_array_contains '.filesystem.allow' '$HOME/.dart-tool'
  assert_profile_array_contains '.filesystem.allow' '$HOME/.dartServer'
  assert_profile_array_contains '.filesystem.allow' '$HOME/.config/flutter'
  assert_profile_array_contains \
    '.filesystem.allow_file' \
    '$HOME/.local/share/mise/installs/flutter/3.35.4-stable/bin/cache/engine.stamp'
  assert_profile_array_contains \
    '.filesystem.allow_file' \
    '$HOME/.local/share/mise/installs/flutter/3.35.4-stable/bin/cache/engine.realm'
  assert_profile_array_contains \
    '.filesystem.allow_file' \
    '$HOME/.local/share/mise/installs/flutter/3.35.4-stable/bin/cache/lockfile'
  assert_profile_array_contains \
    '.filesystem.allow_file' \
    '$HOME/.local/share/mise/installs/flutter/3.35.4-stable/bin/cache/flutter_version_check.stamp'

  for agent in codex claude pi; do
    assert_agent_path_decision \
      "$agent" "ALLOWED" "$test_flutter_dart_root/dart-tool/dart-flutter-telemetry.log" "readwrite"
    assert_agent_path_decision \
      "$agent" "ALLOWED" "$test_agent_tool_state_root/pub-cache/hosted/pub.dev/example/package.dart" "readwrite"
    assert_agent_path_decision \
      "$agent" "ALLOWED" "$test_flutter_dart_root/dart-server/.analysis-driver" "readwrite"
    assert_agent_path_decision \
      "$agent" "ALLOWED" "$test_flutter_dart_root/flutter-config/tool_state" "readwrite"
    assert_agent_path_decision \
      "$agent" "ALLOWED" "$test_flutter_dart_root/flutter-sdk-cache/engine.stamp" "readwrite"
    assert_agent_path_decision \
      "$agent" "ALLOWED" "$test_flutter_dart_root/flutter-sdk-cache/engine.realm" "readwrite"
    assert_agent_path_decision \
      "$agent" "DENIED" "$HOME/.local/share/mise/installs/flutter/3.35.4-stable/bin/cache/flutter_tools.snapshot" "write"
    assert_agent_path_decision \
      "$agent" "DENIED" "$HOME/.local/share/mise/installs/flutter/3.35.4-stable/bin/cache/dart-sdk/bin/dart" "write"
    assert_agent_path_decision \
      "$agent" "DENIED" "$HOME/.local/share/mise/installs/flutter/3.32.6-stable/bin/cache/engine.stamp" "write"
  done

  # Assert: No parent directory broadens access to unrelated package, config, or mise installation data.
  assert_profile_value '.filesystem.allow | index("$HOME") == null' 'true'
  assert_profile_value '.filesystem.allow | index("$HOME/.config") == null' 'true'
  assert_profile_value '.filesystem.allow | index("$HOME/.local/share/mise") == null' 'true'
  assert_profile_value '.filesystem.read | index("$HOME/.pub-cache") == null' 'true'
  assert_profile_value '.filesystem.allow_file | any(contains("/.git/FETCH_HEAD"))' 'false'

  # Assert: Home Manager creates roots that nono must canonicalize before either tool can initialize them.
  rg -q -F \
    '$DRY_RUN_CMD mkdir -p "${homeDirectory}/.dart-tool" "${homeDirectory}/.dartServer" "${configHome}/flutter"' \
    nix/modules/home/dotfiles.nix
  rg -q -F \
    '$DRY_RUN_CMD mkdir -p "${homeDirectory}/.local/state/nono-agent-tools/wrangler" "${homeDirectory}/.local/state/nono-agent-tools/pub-cache"' \
    nix/modules/home/dotfiles.nix
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

test_container_policy_allows_mysql_integration_test_lifecycle() {
  # Arrange, Act & Assert: Repeated test setup and inspection operations are delegated.
  assert_container_command_decision "ALLOWED" image pull mysql:8.0.33
  assert_container_command_decision "ALLOWED" run --name katohome-mysql mysql:8.0.33
  assert_container_command_decision "ALLOWED" start katohome-mysql
  assert_container_command_decision "ALLOWED" exec katohome-mysql mysqladmin ping
  assert_container_command_decision "ALLOWED" copy ./fixture.sql katohome-mysql:/tmp/fixture.sql
  assert_container_command_decision "ALLOWED" stop katohome-mysql
}

test_container_policy_keeps_destructive_cleanup_denied() {
  # Arrange, Act & Assert: Destructive bulk or removal operations remain outside delegation.
  assert_container_command_decision "DENIED" delete katohome-mysql
  assert_container_command_decision "DENIED" prune
  assert_container_command_decision "DENIED" image prune --all
}

test_codex_wrapper_requires_the_parent_nono_capability() {
  local packages_module='nix/modules/home/packages.nix'

  # Arrange: Codex自身のsandboxは無効化し、外側のnonoだけをsecurity boundaryとして使う。
  # Act: nonoが起動するchild commandにcapability確認用guardがあるか調べる。
  # Assert: NONO_CAP_FILEが注入されなければ、raw Codexを起動する前に失敗する。
  rg -q 'codex-nono-guard' "$packages_module"
  rg -q 'codex: nono capability was not injected' "$packages_module"
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

test_host_artifact_publish_root_is_writable_without_broadening_its_parent() {
  # Arrange: Artifacts are copied into one dedicated service-owned subtree.
  # Act & Assert: The publish root is writable while an adjacent directory stays denied.
  assert_path_decision \
    "ALLOWED" \
    "$test_publish_root/example/report.html" \
    "readwrite"
  assert_path_decision \
    "DENIED" \
    "$test_config_root/host-artifact-private/report.html" \
    "readwrite"
  assert_path_decision \
    "DENIED" \
    "$HOME/.local/share/host-artifact" \
    "write"
}

test_host_artifact_uses_the_parent_sandbox_without_tool_policies() {
  local command

  # Arrange: Host-artifact wrappers validate their own bounded public arguments.
  for command in host-artifact host-artifact-service host-artifact-tailscale host-artifact-workspace; do
    # Act & Assert: None of the wrappers creates a nested Tool Sandbox boundary.
    assert_profile_value ".command_policies.commands | has(\"$command\")" 'false'
  done

  # Act & Assert: Parent capability remains limited to the fixed service and Tailscale daemon names.
  assert_profile_value \
    '[.unsafe_macos_seatbelt_rules[] | select(test("host-artifact|tailscale|localhost:9417"; "i"))] | tojson' \
    '["(allow network-outbound (remote tcp \"localhost:9417\"))","(allow mach-lookup (global-name \"io.tailscale.ipn.macsys-spks\"))","(allow mach-lookup (global-name \"io.tailscale.ipn.macsys-spki\"))"]'
}

test_bun_uses_the_outer_sandbox_with_exact_ancestor_rules() {
  # Arrange: Normalize the source profile before Home Manager substitutes the consumer home.
  # Act & Assert: Bun stays outside Tool Sandbox and receives only the proven exact ancestor grants.
  assert_profile_value \
    '.command_policies.commands | has("bun")' \
    'false'
  assert_profile_value \
    '[.unsafe_macos_seatbelt_rules[] | select(startswith("(allow file-read-"))] | tojson' \
    '["(allow file-read-metadata (literal \"/\"))","(allow file-read-data (literal \"/Users\"))","(allow file-read-data (literal \"@HOME@\"))"]'
}

test_codex_allows_chatgpt_subscription_endpoint() {
  assert_agent_network_boundary codex chatgpt.com
}

test_codex_allows_unrestricted_localhost_outbound_on_macos() {
  # Arrange, Act & Assert: Port zero is nono's canonical macOS localhost:* outbound grant.
  assert_agent_profile_value codex '.network.open_port | tojson' '[0]'
  assert_agent_profile_value \
    codex \
    '.network.allow_domain | tojson' \
    '["chatgpt.com",{"domain":"sentry.io","endpoints":[{"method":"GET","path":"/api/0/**"}]},{"domain":"api.cloudflare.com","endpoints":[{"method":"GET","path":"/client/v4/**"}]},"*.katohome.jp","*.nananaman.com","localhost","127.0.0.1"]'
}

test_codex_localhost_access_does_not_grant_the_container_vm_address() {
  # Arrange, Act & Assert: Non-loopback container VM addresses remain outside this grant.
  assert_agent_profile_value \
    codex \
    '.network.allow_domain | index("192.168.65.2") == null' \
    'true'
}

test_codex_allows_read_only_observability_endpoints() {
  # Arrange, Act & Assert: Observability uses exact hosts with GET-only API paths.
  assert_agent_host_decision \
    codex ALLOWED https://sentry.io/api/0/organizations/example 443
  assert_agent_host_decision \
    codex ALLOWED https://api.cloudflare.com/client/v4/zones 443
}

test_codex_injects_the_session_ca_for_python_https_clients() {
  # Arrange, Act & Assert: Python requests verifies intercepted TLS with nono's generated CA.
  assert_agent_profile_value \
    codex \
    '.network.tls_intercept.ca_env_vars | tojson' \
    '["REQUESTS_CA_BUNDLE"]'
}

test_codex_observability_does_not_allow_adjacent_hosts() {
  # Arrange, Act & Assert: Exact host grants do not expand to provider-wide suffixes.
  assert_agent_host_decision codex DENIED attacker.sentry.io 443
  assert_agent_host_decision codex DENIED https://sentry.io/not-api 443
  assert_agent_host_decision codex DENIED dash.cloudflare.com 443
  assert_agent_host_decision codex DENIED sparrow.cloudflare.com 443
  assert_agent_host_decision codex DENIED https://api.cloudflare.com/not-api 443
}

test_claude_allows_anthropic_api_endpoint() {
  assert_agent_network_boundary claude api.anthropic.com
}

test_claude_allows_login_endpoints_and_launch_services() {
  assert_agent_profile_value \
    claude \
    '.network.allow_domain | tojson' \
    '["claude.com"]'
  assert_agent_profile_value claude '.network.open_port | tojson' '[0]'
  assert_agent_profile_value claude '.allow_launch_services' 'null'
  rg -q -- '--allow-launch-services' nix/modules/home/packages.nix
}

test_claude_wrapper_runs_self_update_outside_the_sandbox() {
  local packages_module='nix/modules/home/packages.nix'

  # Arrange: `claude update`のsymlink置き換えは$HOME/.local/bin全体へのwriteを要求し、
  # 通常sessionのfilesystem境界では表現できない。
  # Act & Assert: update/upgradeはnono runへ渡す前にraw binaryを直接execする分岐を持つ。
  rg -q 'update \| upgrade\)' "$packages_module"
  rg -q -F 'Run it outside the sandbox' "$packages_module"
}

test_claude_wrapper_self_update_bypass_requires_exactly_one_argument() {
  local packages_module='nix/modules/home/packages.nix'

  # Arrange: claudeの`prompt`は位置引数のため、`claude update the readme`のような
  # 未クォートの自然文プロンプトも$1="update"になり得る。
  # Act & Assert: `update | upgrade)`のcase分岐が、単独の文字列一致ではなく
  # 引数個数1個のif guardの内側に入れ子になっていることを確認する。
  rg -U -q -- \
    'if \[ "\$#" -eq 1 \]; then\n\s*case "\$1" in\n\s*update \| upgrade\)' \
    "$packages_module"
}

test_pi_allows_configured_openai_codex_endpoint() {
  assert_agent_network_boundary pi chatgpt.com
}

test_github_cli_uses_the_parent_sandbox
test_ssh_private_key_remains_unreadable
test_common_profile_includes_general_development_groups
test_common_profile_keeps_sensitive_data_denied_by_group
test_common_profile_allows_neovim_external_editor_state
test_common_profile_allows_claude_lock_state_without_broad_state_access
test_common_profile_keeps_chrome_data_outside_direct_agent_access
test_common_profile_allows_only_the_chrome_bridge_socket_subtree
test_common_profile_allows_only_the_nix_daemon_socket
test_common_profile_uses_a_dedicated_agent_tmpdir_for_unix_sockets
test_common_profile_uses_enterprise_network
test_common_profile_allows_development_endpoints
test_common_profile_allows_only_the_terraform_provider_distribution_endpoints
test_agent_profiles_inherit_terraform_provider_distribution_endpoints
test_common_profile_allows_github_actions_log_endpoint
test_common_profile_does_not_allow_all_github_actions_hosts
test_common_profile_allows_github_actions_blob_log_endpoint
test_common_profile_does_not_allow_azure_blob_apex
test_common_profile_does_not_allow_adjacent_azure_storage_suffix
test_common_profile_allows_tailscale_serve_origins
test_common_profile_denies_unconfigured_clouds
test_common_profile_allows_all_ghq_repositories
test_common_profile_allows_new_ghq_clone_destinations
test_common_profile_configures_sandbox_compatible_javascript_tools
test_common_profile_allows_flutter_and_dart_runtime_state_without_home_wide_access
test_command_policies_never_require_human_approval
test_container_wrapper_prefers_the_tool_sandbox_shim
test_container_policy_allows_mysql_integration_test_lifecycle
test_container_policy_keeps_destructive_cleanup_denied
test_codex_wrapper_requires_the_parent_nono_capability
test_local_agent_tools_use_the_parent_sandbox
test_host_artifact_publish_root_is_writable_without_broadening_its_parent
test_host_artifact_uses_the_parent_sandbox_without_tool_policies
test_bun_uses_the_outer_sandbox_with_exact_ancestor_rules
test_codex_allows_chatgpt_subscription_endpoint
test_codex_allows_unrestricted_localhost_outbound_on_macos
test_codex_localhost_access_does_not_grant_the_container_vm_address
test_codex_allows_read_only_observability_endpoints
test_codex_injects_the_session_ca_for_python_https_clients
test_codex_observability_does_not_allow_adjacent_hosts
test_claude_allows_anthropic_api_endpoint
test_claude_allows_login_endpoints_and_launch_services
test_claude_wrapper_runs_self_update_outside_the_sandbox
test_claude_wrapper_self_update_bypass_requires_exactly_one_argument
test_pi_allows_configured_openai_codex_endpoint
