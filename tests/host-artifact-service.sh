#!/usr/bin/env bash

set -euo pipefail

module="nix/modules/home/host-artifact.nix"
packages_module="nix/modules/home/packages.nix"
dotfiles_module="nix/modules/home/dotfiles.nix"
profile="nono/profiles/chouge-agent-common.jsonc"
server_profile="nono/profiles/host-artifact-server.jsonc"
apm_manifest="apm/apm.yml"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/host-artifact-service-test.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT

render_server_profile() {
  local output="$1"
  local repository_root

  repository_root="$(pwd -P)"
  sed \
    -e "s|@HOME@/.agents/skills/host-artifact|$repository_root/nix/modules/home|g" \
    -e "s|@HOME@/.local/share/host-artifact/public|$repository_root/tests/fixtures/host-artifact-public|g" \
    "$server_profile" >"$output"
}

assert_server_path_decision() {
  local expected="$1"
  local target_path="$2"
  local operation="$3"
  local rendered_profile="$test_root/host-artifact-server.jsonc"
  local output

  # Arrange: Render the generic profile against immutable repository fixtures.
  render_server_profile "$rendered_profile"

  # Act: Ask nono to classify the exact server filesystem operation.
  output="$(nono why --profile "$rendered_profile" --path "$target_path" --op "$operation")"

  # Assert: Only the declared read-only roots cross the server boundary.
  if [[ "${output%%$'\n'*}" != "$expected" ]]; then
    printf 'expected %s for %s access to %s, got:\n%s\n' \
      "$expected" "$operation" "$target_path" "$output" >&2
    return 1
  fi
}

test_launch_agent_uses_the_shared_service_contract() {
  # Arrange: The service contract is shared with the installed host-artifact skill.
  # Act: Inspect the declarative user service definition.
  # Assert: The label, port, publish root, skill root, and health path are fixed.
  rg -q 'com\.nananaman\.host-artifact' "$module"
  rg -q '9417' "$packages_module"
  rg -q '\.local/share/host-artifact' "$module"
  rg -q 'publishRoot = ".*public"' "$module"
  rg -q '\.agents/skills/host-artifact' "$packages_module"
  rg -q '/\.well-known/host-artifact/health' "$packages_module"
}

test_launch_agent_is_persistent_and_has_dedicated_logs() {
  # Arrange: A shared service must survive individual Codex sessions.
  # Act: Inspect its lifecycle and logging declarations.
  # Assert: Login starts it, failures restart it, and output has dedicated paths.
  rg -q 'RunAtLoad = true' "$module"
  rg -q 'KeepAlive' "$module"
  rg -q 'host-artifact-stdout\.log' "$module"
  rg -q 'host-artifact-stderr\.log' "$module"
}

test_ensure_wrapper_exposes_only_the_ensure_operation() {
  # Arrange: The sandbox may recover one fixed LaunchAgent but may not control others.
  # Act: Inspect the generated wrapper's argument and launchctl invocation.
  # Assert: Only exact "ensure" is accepted and kickstart fixes the user label.
  rg -q 'if \[ "\$#" -ne 1 \] || \[ "\$1" != "ensure" \]' "$packages_module"
  rg -q '/bin/launchctl kickstart -k "gui/\$UID/com\.nananaman\.host-artifact"' "$packages_module"
}

test_ensure_wrapper_uses_a_finite_health_check() {
  # Arrange: Service recovery must not leave an agent waiting indefinitely.
  # Act: Inspect the health check and retry bounds.
  # Assert: Requests have a timeout and readiness retries are finite.
  rg -q '/usr/bin/curl.*--max-time' "$packages_module"
  rg -q 'seq 1 [0-9]' "$packages_module"
  rg -q 'http://127\.0\.0\.1:9417/\.well-known/host-artifact/health' "$packages_module"
}

test_ensure_wrapper_requires_the_server_identity() {
  # Arrange: An unrelated process can occupy the fixed port and return HTTP 200.
  # Act: Inspect the readiness predicate used before and after kickstart.
  # Assert: Only the versioned host-artifact health document counts as healthy.
  rg -q '\{"service":"host-artifact","version":1,"status":"ok"\}' "$packages_module"
  rg -q '\[ "\$health_body" = "\$expected_health" \]' "$packages_module"
}

test_profile_grants_only_the_publish_root_and_exact_ensure_command() {
  local profile_json

  # Arrange: Strip JSONC comments so policy values can be queried structurally.
  profile_json="$(sed '/^[[:space:]]*[/][/]/d' "$profile")"

  # Act: Select the filesystem and command capabilities added for artifact hosting.
  # Assert: The writable path and executable are exact, and every other argv is denied.
  jq -e '
    .filesystem.allow
    | index("$HOME/.local/share/host-artifact/public") != null
  ' <<<"$profile_json" >/dev/null
  jq -e '
    .filesystem.allow
    | index("$HOME/.local/share/host-artifact") == null
  ' <<<"$profile_json" >/dev/null
  jq -e '
    .filesystem.bypass_protection
    | index("$HOME/.local/share/host-artifact") == null
  ' <<<"$profile_json" >/dev/null
  jq -e '
    .command_policies.commands["host-artifact-service"]
      .executable == "@HOME@/.local/share/nono-agent-wrappers/host-artifact-service"
  ' <<<"$profile_json" >/dev/null
  jq -e '
    .command_policies.commands["host-artifact-service"].from.session.invocation_policy
      == {"default":"deny","allow":[{"argv":{"exact":["ensure"]}}]}
  ' <<<"$profile_json" >/dev/null
}

test_ensure_command_sandbox_executes_only_its_fixed_dependencies() {
  local profile_json

  # Arrange: Normalize the source profile without resolving it against host state.
  profile_json="$(sed '/^[[:space:]]*[/][/]/d' "$profile")"

  # Act: Select files executable by the fixed ensure implementation.
  # Assert: The child sandbox exposes only launchctl and its bounded health helpers.
  jq -e '
    .command_policies.commands["host-artifact-service"].from.session.sandbox.fs_read_file
      == ["/bin/launchctl", "/bin/sleep", "/usr/bin/curl", "/usr/bin/seq"]
  ' <<<"$profile_json" >/dev/null
  jq -e '
    .command_policies.commands["host-artifact-service"].from.session.sandbox
      | has("network") | not
  ' <<<"$profile_json" >/dev/null
  jq -e '
    .command_policies.commands["host-artifact-service"].from.session.sandbox
      .unsafe_macos_seatbelt_rules
      | index("(allow network-outbound (remote tcp \"localhost:9417\"))") != null
  ' <<<"$profile_json" >/dev/null
}

test_server_profile_is_read_only_and_listens_only_on_the_service_port() {
  local profile_json

  # Arrange: Normalize the dedicated server profile as declarative policy.
  profile_json="$(sed '/^[[:space:]]*[/][/]/d' "$server_profile")"

  # Act: Select filesystem and network grants.
  # Assert: The server can only read its code/content and can only listen on 9417.
  jq -e '
    .filesystem.read
      == [
        "@HOME@/.agents/skills/host-artifact",
        "@HOME@/.local/share/host-artifact/public"
      ]
  ' <<<"$profile_json" >/dev/null
  jq -e '.filesystem | has("allow") | not' <<<"$profile_json" >/dev/null
  jq -e '.network == {"block":true,"open_port":[9417]}' <<<"$profile_json" >/dev/null
  jq -e 'has("extends") | not' <<<"$profile_json" >/dev/null
  jq -e '
    .groups.include
      == [
        "system_read_macos",
        "system_write_macos",
        "deny_credentials",
        "deny_keychains_macos",
        "deny_browser_data_macos",
        "deny_macos_private",
        "deny_shell_history",
        "deny_shell_configs"
      ]
  ' <<<"$profile_json" >/dev/null
}

test_launch_agent_runs_typescript_with_bun_through_nono() {
  # Arrange: The persistent process must not inherit the unrestricted LaunchAgent context.
  # Act: Inspect the fixed server wrapper and LaunchAgent argv.
  # Assert: nono applies the dedicated profile before Bun runs checked-in TypeScript.
  rg -q 'host-artifact-server\.jsonc' "$packages_module"
  rg -q 'nono run --silent' "$packages_module"
  rg -Fq '${pkgs.bun}/bin/bun' "$packages_module" || return 1
  rg -q 'src/server-main\.ts' "$packages_module" || return 1
  if rg -q 'dist/server\.js' "$packages_module"; then return 1; fi
  rg -q 'host-artifact-server' "$module"
  rg -q 'hostArtifactServerProfile' "$dotfiles_module"
  rg -q 'host-artifact-server\.jsonc' "$dotfiles_module"
}

test_server_wrapper_refreshes_the_authoritative_tailscale_address() {
  # Arrange: The fixed host wrapper runs before the server enters its nono sandbox.
  # Act: Inspect how it discovers and passes the Tailscale listener address.
  # Assert: Only the Tailscale CLI result becomes the server's authoritative candidate.
  rg -Fq '/usr/local/bin/tailscale ip -4' "$packages_module" || return 1
  rg -Fq 'while /bin/sleep 15' "$packages_module" || return 1
  rg -Fq -- '--tailscale-address-file "$tailscale_address_file"' "$packages_module" || return 1
}

test_activation_installs_frozen_bun_dependencies_before_service_use() {
  # Arrange: APM deploys TypeScript sources without generated JavaScript or node_modules.
  # Act: Inspect the Home Manager activation contract.
  # Assert: Production dependencies are prepared from the committed Bun lockfile.
  rg -q 'bun install --frozen-lockfile --production' "$module" || return 1
  rg -q 'bun\.lock' "$module" || return 1
}

test_agent_cli_runs_typescript_through_a_fixed_bun_wrapper() {
  local profile_json

  # Arrange: Direct bun invocation is unavailable in the parent agent sandbox.
  profile_json="$(sed '/^[[:space:]]*[/][/]/d' "$profile")"

  # Act: Inspect the wrapper and its command-policy boundary.
  # Assert: The trusted wrapper runs only the installed CLI source with bounded public argv.
  rg -q 'writeShellScriptBin "host-artifact"' "$packages_module" || return 1
  rg -q 'src/cli\.ts' "$packages_module" || return 1
  jq -e '
    .command_policies.commands["host-artifact"].can_use
      == ["host-artifact-service"]
  ' <<<"$profile_json" >/dev/null
  jq -e '
    .command_policies.commands["host-artifact"].from.session.sandbox
      | has("network") | not
  ' <<<"$profile_json" >/dev/null
  jq -e '
    .command_policies.commands["host-artifact"].from.session.sandbox.fs_read
      | index("/nix/store") != null
  ' <<<"$profile_json" >/dev/null || return 1
  jq -e '
    .command_policies.commands["host-artifact"].from.session.sandbox
      .unsafe_macos_seatbelt_rules
      | index("(allow network-outbound (remote tcp \"localhost:9417\"))") != null
  ' <<<"$profile_json" >/dev/null
  jq -e '
    .command_policies.commands["host-artifact"].from.session.invocation_policy
      == {
        "default":"deny",
        "allow":[
          {"argv":{"exact":["status"]}},
          {"argv":{"prefix":["host"]}},
          {"argv":{"prefix":["remove"]}}
        ]
      }
  ' <<<"$profile_json" >/dev/null
  jq -e '
    .command_policies.commands["host-artifact-service"]
      .from["host-artifact"].invocation_policy
      == {"default":"deny","allow":[{"argv":{"exact":["ensure"]}}]}
  ' <<<"$profile_json" >/dev/null
}

test_server_profile_reads_published_content_but_not_its_neighbor() {
  local repository_root
  repository_root="$(pwd -P)"

  # Arrange: Published content and a neighboring sentinel both exist.
  # Act & Assert: The explicit publish root is readable and the neighbor is denied.
  assert_server_path_decision \
    "ALLOWED" \
    "$repository_root/tests/fixtures/host-artifact-public/report.txt" \
    "read"
  assert_server_path_decision \
    "DENIED" \
    "$repository_root/tests/fixtures/host-artifact-neighbor-sentinel.txt" \
    "read"
}

test_server_profile_cannot_write_published_content() {
  local repository_root
  repository_root="$(pwd -P)"

  # Arrange: The published fixture is covered only by filesystem.read.
  # Act & Assert: The dedicated server cannot modify agent-published content.
  assert_server_path_decision \
    "DENIED" \
    "$repository_root/tests/fixtures/host-artifact-public/report.txt" \
    "write"
}

test_server_profile_cannot_replace_the_publish_root() {
  local repository_root
  repository_root="$(pwd -P)"

  # Arrange: Replacing "public" requires write access to its parent directory.
  # Act & Assert: The server has no write grant on the parent that owns the root entry.
  assert_server_path_decision \
    "DENIED" \
    "$repository_root/tests/fixtures" \
    "write"
}

test_server_profile_cannot_follow_a_publish_symlink_outside_the_root() {
  local repository_root
  repository_root="$(pwd -P)"

  # Arrange: A publish-root symlink resolves to the neighboring sentinel.
  # Act & Assert: Canonical path enforcement denies the outside target.
  assert_server_path_decision \
    "DENIED" \
    "$repository_root/tests/fixtures/host-artifact-public/outside-link.txt" \
    "read"
}

test_apm_installs_the_host_artifact_skill() {
  # Arrange: The LaunchAgent wrapper references the globally installed skill path.
  # Act: Inspect the source-of-truth APM dependency list.
  # Assert: host-artifact is installed without removing explain-diff.
  rg -q 'path: ~/ghq/github\.com/nananaman/skills/productivity/host-artifact$' "$apm_manifest"
  rg -q 'path: ~/ghq/github\.com/nananaman/skills/engineering/explain-diff$' "$apm_manifest"
}

test_launch_agent_uses_the_shared_service_contract
test_launch_agent_is_persistent_and_has_dedicated_logs
test_ensure_wrapper_exposes_only_the_ensure_operation
test_ensure_wrapper_uses_a_finite_health_check
test_ensure_wrapper_requires_the_server_identity
test_profile_grants_only_the_publish_root_and_exact_ensure_command
test_ensure_command_sandbox_executes_only_its_fixed_dependencies
test_server_profile_is_read_only_and_listens_only_on_the_service_port
test_launch_agent_runs_typescript_with_bun_through_nono || exit 1
test_activation_installs_frozen_bun_dependencies_before_service_use || exit 1
test_agent_cli_runs_typescript_through_a_fixed_bun_wrapper || exit 1
test_server_profile_reads_published_content_but_not_its_neighbor
test_server_profile_cannot_write_published_content
test_server_profile_cannot_replace_the_publish_root
test_server_profile_cannot_follow_a_publish_symlink_outside_the_root
test_apm_installs_the_host_artifact_skill
