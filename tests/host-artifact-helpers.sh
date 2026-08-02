#!/usr/bin/env bash
set -euo pipefail

test_root="$(mktemp -d "${TMPDIR:-/tmp}/host-artifact-helper-test.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT
repository_root="$(pwd -P)"

render_helpers() {
  cp "$repository_root/tests/fixtures/fake-tailscale.sh" "$test_root/tailscale"
  cp "$repository_root/tests/fixtures/fake-curl.sh" "$test_root/curl"
  chmod +x "$test_root/tailscale" "$test_root/curl"
  sed -e "s|@TAILSCALE_WRAPPER@|$test_root/tailscale|g" -e "s|@TAILSCALE_APP@|$test_root/missing-tailscale|g" \
    -e "s|@CURL@|$test_root/curl|g" \
    -e "s|@JQ@|$(command -v jq)|g" -e "s|@GREP@|/usr/bin/grep|g" -e "s|@TR@|/usr/bin/tr|g" \
    nix/modules/home/host-artifact-tailscale.sh >"$test_root/tailscale-helper"
  sed -e "s|@GIT@|$(command -v git)|g" -e "s|@JQ@|$(command -v jq)|g" \
    -e "s|@SHASUM@|/usr/bin/shasum|g" -e "s|@SED@|/usr/bin/sed|g" \
    -e "s|@TR@|/usr/bin/tr|g" -e "s|@CUT@|/usr/bin/cut|g" \
    nix/modules/home/host-artifact-workspace.sh >"$test_root/workspace-helper"
}

test_public_wrapper_uses_fixed_helpers_without_command_policy_shims() {
  local operation

  # Arrange: A hostile inherited PATH and broker shim directory contain failing helpers.
  mkdir "$test_root/wrappers" "$test_root/shims"
  cp "$repository_root/tests/fixtures/fake-host-artifact-bun.sh" "$test_root/fake-bun"
  chmod +x "$test_root/fake-bun"
  mkdir "$test_root/helpers"
  for helper in host-artifact-service host-artifact-tailscale host-artifact-workspace; do
    printf '#!/bin/sh\nexit 1\n' >"$test_root/wrappers/$helper"
    printf '#!/bin/sh\nexit 0\n' >"$test_root/shims/$helper"
    printf '#!/bin/sh\nexit 0\n' >"$test_root/helpers/$helper"
    chmod +x "$test_root/wrappers/$helper" "$test_root/shims/$helper" "$test_root/helpers/$helper"
  done
  sed -e "s|@BUN@|$test_root/fake-bun|g" -e "s|@CLI@|$test_root/cli.ts|g" \
    -e "s|@HELPER_PATH@|$test_root/helpers|g" \
    nix/modules/home/host-artifact.sh >"$test_root/host-artifact"
  : >"$test_root/bun.log"

  # Act: Exercise every accepted public operation through the generated wrapper.
  for operation in 'publish report.html --name report' 'remove --name report' 'status' 'setup'; do
    PATH="$test_root/wrappers:/usr/bin:/bin" NONO_TOOL_SANDBOX_SHIM_DIR="$test_root/shims" \
      HOST_ARTIFACT_EXPECTED_HELPER_DIR="$test_root/helpers" \
      HOST_ARTIFACT_FAKE_BUN_LOG="$test_root/bun.log" bash "$test_root/host-artifact" $operation
  done

  # Assert: Bun observed all operations with helpers pinned ahead of inherited paths and shims.
  [ "$(wc -l <"$test_root/bun.log" | tr -d ' ')" -eq 4 ]
}

write_online_status() {
  printf '%s\n' '{"Self":{"Online":true,"DNSName":"machine.tailnet.ts.net."}}' >"$test_root/status.json"
}

test_inspect_reports_configured_serve_without_exposing_external_state() {
  # Arrange: Tailscale is online and the HTTPS root proxies the fixed loopback service.
  write_online_status
  printf '%s\n' '{"Web":{"machine.tailnet.ts.net:443":{"Handlers":{"/":{"Proxy":"http://127.0.0.1:9417"}}}}}' >"$test_root/serve.json"

  # Act: Inspect through fake Tailscale output.
  output="$(FAKE_TAILSCALE_STATUS="$test_root/status.json" FAKE_TAILSCALE_SERVE="$test_root/serve.json" bash "$test_root/tailscale-helper" inspect)"

  # Assert: Only the stable origin and transport state cross the helper boundary.
  jq -e '. == {schemaVersion:1,available:true,configured:true,origin:"https://machine.tailnet.ts.net"}' <<<"$output" >/dev/null
}

test_inspect_rejects_conflicting_root_target() {
  # Arrange: A pre-existing root route belongs to another service.
  write_online_status
  printf '%s\n' '{"Web":{"machine.tailnet.ts.net:443":{"Handlers":{"/":{"Proxy":"http://127.0.0.1:9999"}}}}}' >"$test_root/serve.json"

  # Act & Assert: Inspection fails instead of overwriting or accepting the route.
  if FAKE_TAILSCALE_STATUS="$test_root/status.json" FAKE_TAILSCALE_SERVE="$test_root/serve.json" \
    bash "$test_root/tailscale-helper" inspect >/dev/null 2>&1; then return 1; fi
}

test_inspect_fails_closed_when_serve_status_fails() {
  # Arrange: Node status succeeds but Serve state cannot be obtained authoritatively.
  write_online_status
  : >"$test_root/serve.json"

  # Act & Assert: Inspection fails instead of misreporting an unconfigured transport.
  if FAKE_TAILSCALE_STATUS="$test_root/status.json" FAKE_TAILSCALE_SERVE="$test_root/serve.json" \
    FAKE_TAILSCALE_SERVE_FAIL=1 bash "$test_root/tailscale-helper" inspect >/dev/null 2>&1; then return 1; fi
}

test_inspect_fails_closed_when_node_status_command_fails() {
  # Arrange: The Tailscale CLI exists but cannot reach its local backend.
  write_online_status
  printf '%s\n' '{}' >"$test_root/serve.json"

  # Act & Assert: Command failure is distinct from an explicit offline JSON document.
  if FAKE_TAILSCALE_STATUS="$test_root/status.json" FAKE_TAILSCALE_STATUS_FAIL=1 \
    FAKE_TAILSCALE_SERVE="$test_root/serve.json" bash "$test_root/tailscale-helper" inspect >/dev/null 2>&1; then return 1; fi
}

test_inspect_fails_closed_for_empty_online_dns_name() {
  # Arrange: The node claims to be online without an authoritative MagicDNS hostname.
  printf '%s\n' '{"Self":{"Online":true,"DNSName":""}}' >"$test_root/status.json"
  printf '%s\n' '{}' >"$test_root/serve.json"

  # Act & Assert: Inspection fails before querying an ambiguous :443 Serve key.
  if FAKE_TAILSCALE_STATUS="$test_root/status.json" FAKE_TAILSCALE_SERVE="$test_root/serve.json" \
    bash "$test_root/tailscale-helper" inspect >/dev/null 2>&1; then return 1; fi
}

test_setup_rejects_malformed_online_dns_name_without_mutation() {
  # Arrange: An online response contains a hostname that cannot be a DNS FQDN.
  printf '%s\n' '{"Self":{"Online":true,"DNSName":"bad..tailnet.ts.net."}}' >"$test_root/status.json"
  printf '%s\n' '{}' >"$test_root/serve.json"
  : >"$test_root/mutations.log"

  # Act: Attempt setup while recording every mutating fake Tailscale call.
  if FAKE_TAILSCALE_STATUS="$test_root/status.json" FAKE_TAILSCALE_SERVE="$test_root/serve.json" \
    FAKE_TAILSCALE_MUTATION_LOG="$test_root/mutations.log" bash "$test_root/tailscale-helper" setup >/dev/null 2>&1; then return 1; fi

  # Assert: Invalid DNS state fails before Serve mutation.
  [ ! -s "$test_root/mutations.log" ]
}

test_setup_does_not_mutate_when_serve_status_fails() {
  # Arrange: Serve status is unavailable and mutation calls are recorded.
  write_online_status
  : >"$test_root/serve.json"
  : >"$test_root/mutations.log"

  # Act: Attempt setup without an authoritative pre-mutation Serve state.
  if FAKE_TAILSCALE_STATUS="$test_root/status.json" FAKE_TAILSCALE_SERVE="$test_root/serve.json" \
    FAKE_TAILSCALE_SERVE_FAIL=1 FAKE_TAILSCALE_MUTATION_LOG="$test_root/mutations.log" \
    bash "$test_root/tailscale-helper" setup >/dev/null 2>&1; then return 1; fi

  # Assert: Failure is closed before the mutating subcommand.
  [ ! -s "$test_root/mutations.log" ]
}

test_inspect_ignores_other_hosts_and_non_https_ports() {
  # Arrange: The current DNS HTTPS root is correct while unrelated routes coexist.
  write_online_status
  printf '%s\n' '{"Web":{
    "machine.tailnet.ts.net:443":{"Handlers":{"/":{"Proxy":"http://127.0.0.1:9417"}}},
    "machine.tailnet.ts.net:80":{"Handlers":{"/":{"Text":"redirect"}}},
    "other.tailnet.ts.net:443":{"Handlers":{"/":{"Proxy":"http://127.0.0.1:9999"}}}
  }}' >"$test_root/serve.json"

  # Act: Inspect the authoritative current-node HTTPS entry.
  output="$(FAKE_TAILSCALE_STATUS="$test_root/status.json" FAKE_TAILSCALE_SERVE="$test_root/serve.json" bash "$test_root/tailscale-helper" inspect)"

  # Assert: Unrelated host/port handlers do not create a false conflict.
  jq -e '.available and .configured and .origin == "https://machine.tailnet.ts.net"' <<<"$output" >/dev/null
}

test_setup_rejects_a_non_proxy_root_without_mutation() {
  # Arrange: An existing root text handler belongs to another Serve use.
  write_online_status
  printf '%s\n' '{"Web":{"machine.tailnet.ts.net:443":{"Handlers":{"/":{"Text":"already used"}}}}}' >"$test_root/serve.json"
  : >"$test_root/mutations.log"

  # Act: Attempt bounded setup against the conflicting route.
  if FAKE_TAILSCALE_STATUS="$test_root/status.json" FAKE_TAILSCALE_SERVE="$test_root/serve.json" \
    FAKE_TAILSCALE_AFTER_SETUP="$test_root/serve.json" FAKE_TAILSCALE_MUTATION_LOG="$test_root/mutations.log" \
    bash "$test_root/tailscale-helper" setup >/dev/null 2>&1; then return 1; fi

  # Assert: Conflict detection happens before the only mutating Tailscale command.
  [ ! -s "$test_root/mutations.log" ]
}

test_inspect_falls_back_to_the_app_executable() {
  local fallback_helper

  # Arrange: The conventional wrapper is absent but the app executable is available.
  write_online_status
  printf '%s\n' '{"Web":{"machine.tailnet.ts.net:443":{"Handlers":{"/":{"Proxy":"http://127.0.0.1:9417"}}}}}' >"$test_root/serve.json"
  fallback_helper="$test_root/tailscale-fallback-helper"
  sed -e "s|@TAILSCALE_WRAPPER@|$test_root/missing-tailscale|g" -e "s|@TAILSCALE_APP@|$test_root/tailscale|g" \
    -e "s|@CURL@|$test_root/curl|g" -e "s|@JQ@|$(command -v jq)|g" \
    -e "s|@GREP@|/usr/bin/grep|g" -e "s|@TR@|/usr/bin/tr|g" \
    nix/modules/home/host-artifact-tailscale.sh >"$fallback_helper"

  # Act: Inspect using the generated fallback selection.
  output="$(FAKE_TAILSCALE_STATUS="$test_root/status.json" FAKE_TAILSCALE_SERVE="$test_root/serve.json" bash "$fallback_helper" inspect)"

  # Assert: App-only installations retain the configured transport contract.
  jq -e '.available and .configured' <<<"$output" >/dev/null
}

test_inspect_degrades_when_tailscale_is_offline() {
  # Arrange: The CLI exists but reports an offline local node.
  printf '%s\n' '{"Self":{"Online":false,"DNSName":""}}' >"$test_root/status.json"
  printf '%s\n' '{}' >"$test_root/serve.json"

  # Act: Inspect the unavailable transport.
  output="$(FAKE_TAILSCALE_STATUS="$test_root/status.json" FAKE_TAILSCALE_SERVE="$test_root/serve.json" bash "$test_root/tailscale-helper" inspect)"

  # Assert: Offline is valid local-degradation state, not an unsafe setup attempt.
  jq -e '. == {schemaVersion:1,available:false,configured:false,reason:"tailscale-offline"}' <<<"$output" >/dev/null
}

test_setup_configures_only_an_empty_serve_root() {
  # Arrange: Tailscale is online with no Serve config, and the fake exposes the post-setup state.
  write_online_status
  printf '%s\n' '{}' >"$test_root/serve.json"
  printf '%s\n' '{"Web":{"machine.tailnet.ts.net:443":{"Handlers":{"/":{"Proxy":"http://127.0.0.1:9417"}}}}}' >"$test_root/after.json"

  # Act: Run the bounded setup operation.
  output="$(FAKE_TAILSCALE_STATUS="$test_root/status.json" FAKE_TAILSCALE_SERVE="$test_root/serve.json" \
    FAKE_TAILSCALE_AFTER_SETUP="$test_root/after.json" bash "$test_root/tailscale-helper" setup)"

  # Assert: Reinspection reports the configured stable origin.
  jq -e '.available and .configured and .origin == "https://machine.tailnet.ts.net"' <<<"$output" >/dev/null
}

test_verify_constructs_the_only_remote_url_and_checks_revision() {
  # Arrange: Serve is configured and curl returns the expected opaque revision header.
  write_online_status
  printf '%s\n' '{"Web":{"machine.tailnet.ts.net:443":{"Handlers":{"/":{"Proxy":"http://127.0.0.1:9417"}}}}}' >"$test_root/serve.json"
  revision="r-0123456789abcdef0123456789abcdef"

  # Act: Verify a grammar-valid artifact identity without accepting a URL argument.
  output="$(FAKE_TAILSCALE_STATUS="$test_root/status.json" FAKE_TAILSCALE_SERVE="$test_root/serve.json" \
    FAKE_CURL_REVISION="$revision" bash "$test_root/tailscale-helper" verify owner-repo~012345abcdef report "$revision")"

  # Assert: The verified URL is constructed solely from authoritative state and validated slugs.
  jq -e '.verified and .url == "https://machine.tailnet.ts.net/a/owner-repo~012345abcdef/report/"' <<<"$output" >/dev/null
}

test_verify_accepts_lowercase_http2_revision_header() {
  # Arrange: HTTP/2 normalizes the application response header name to lowercase.
  write_online_status
  printf '%s\n' '{"Web":{"machine.tailnet.ts.net:443":{"Handlers":{"/":{"Proxy":"http://127.0.0.1:9417"}}}}}' >"$test_root/serve.json"
  revision="r-0123456789abcdef0123456789abcdef"

  # Act: Verify the artifact against a lowercase revision header.
  output="$(FAKE_TAILSCALE_STATUS="$test_root/status.json" FAKE_TAILSCALE_SERVE="$test_root/serve.json" \
    FAKE_CURL_REVISION="$revision" FAKE_CURL_REVISION_HEADER="x-host-artifact-revision" \
    bash "$test_root/tailscale-helper" verify owner-repo~012345abcdef report "$revision")"

  # Assert: Header field names are matched case-insensitively as required by HTTP.
  jq -e '.verified == true' <<<"$output" >/dev/null
}

test_verify_rejects_a_case_mismatched_revision_value() {
  # Arrange: The header name is valid but the opaque revision value changes case.
  write_online_status
  printf '%s\n' '{"Web":{"machine.tailnet.ts.net:443":{"Handlers":{"/":{"Proxy":"http://127.0.0.1:9417"}}}}}' >"$test_root/serve.json"
  revision="r-0123456789abcdef0123456789abcdef"

  # Act: Verify against a response whose revision is not byte-for-byte equal.
  output="$(FAKE_TAILSCALE_STATUS="$test_root/status.json" FAKE_TAILSCALE_SERVE="$test_root/serve.json" \
    FAKE_CURL_REVISION="$revision" FAKE_CURL_RESPONSE_REVISION="R-0123456789ABCDEF0123456789ABCDEF" \
    bash "$test_root/tailscale-helper" verify owner-repo~012345abcdef report "$revision")"

  # Assert: Only the field name is case-insensitive; the opaque value remains exact.
  jq -e '. == {schemaVersion:1,verified:false,reason:"remote-verification-failed"}' <<<"$output" >/dev/null
}

test_verify_rejects_a_non_success_response_with_matching_revision() {
  # Arrange: A redirect happens to echo the expected revision header.
  write_online_status
  printf '%s\n' '{"Web":{"machine.tailnet.ts.net:443":{"Handlers":{"/":{"Proxy":"http://127.0.0.1:9417"}}}}}' >"$test_root/serve.json"
  revision="r-0123456789abcdef0123456789abcdef"

  # Act: Verify the artifact through a non-2xx remote response.
  output="$(FAKE_TAILSCALE_STATUS="$test_root/status.json" FAKE_TAILSCALE_SERVE="$test_root/serve.json" \
    FAKE_CURL_REVISION="$revision" FAKE_CURL_STATUS=302 bash "$test_root/tailscale-helper" verify owner-repo~012345abcdef report "$revision")"

  # Assert: A matching header cannot turn a non-success HTTP status into verification.
  jq -e '. == {schemaVersion:1,verified:false,reason:"remote-verification-failed"}' <<<"$output" >/dev/null
}

test_workspace_resolve_normalizes_a_remote_repository() {
  # Arrange: A repository has a conventional scp-like origin.
  mkdir "$test_root/repository"
  git -C "$test_root/repository" init -q
  git -C "$test_root/repository" remote add origin git@GitHub.COM:nananaman/skills.git

  # Act: Resolve identity from inside the repository.
  output="$(cd "$test_root/repository" && bash "$test_root/workspace-helper" resolve)"

  # Assert: The response exposes only a safe display name and deterministic segment.
  jq -e '.schemaVersion == 1 and .status == "ok" and .workspace.displayName == "nananaman/skills"
    and (.workspace.segment | test("^nananaman-skills~[a-f0-9]{12}$"))
    and (keys == ["schemaVersion","status","workspace"])' <<<"$output" >/dev/null
}

test_workspace_resolve_ignores_hostile_global_git_config() {
  # Arrange: The repository has a valid local origin while HOME contains malformed global config.
  mkdir "$test_root/scoped-repository" "$test_root/hostile-home"
  git -C "$test_root/scoped-repository" init -q
  git -C "$test_root/scoped-repository" remote add origin git@github.com:nananaman/skills.git
  printf '%s\n' '[broken' >"$test_root/hostile-home/.gitconfig"

  # Act: Resolve identity with the hostile global config selected by HOME.
  output="$(cd "$test_root/scoped-repository" && HOME="$test_root/hostile-home" bash "$test_root/workspace-helper" resolve)"

  # Assert: Only repository-local origin participates in the canonical identity.
  jq -e '.workspace.displayName == "nananaman/skills"
    and (.workspace.segment | test("^nananaman-skills~[a-f0-9]{12}$"))' <<<"$output" >/dev/null
}

test_workspace_resolve_falls_back_for_a_local_remote() {
  # Arrange: A local-path origin has no trustworthy host identity.
  mkdir "$test_root/local-repository"
  git -C "$test_root/local-repository" init -q
  git -C "$test_root/local-repository" remote add origin ../upstream.git

  # Act: Resolve the repository without interpreting the local path as a remote host.
  output="$(cd "$test_root/local-repository" && bash "$test_root/workspace-helper" resolve)"

  # Assert: The display remains a basename and no absolute path is emitted.
  jq -e '.workspace.displayName == "local-repository"
    and (.workspace.segment | test("^local-repository~[a-f0-9]{12}$"))' <<<"$output" >/dev/null
  if grep -Fq "$test_root" <<<"$output"; then return 1; fi
}

test_workspace_resolve_keeps_linked_worktree_identity() {
  # Arrange: A linked worktree shares common Git metadata and the same remote origin.
  mkdir "$test_root/main"
  git -C "$test_root/main" init -q
  git -C "$test_root/main" remote add origin https://github.com/nananaman/skills.git
  git -C "$test_root/main" -c user.name=test -c user.email=test@example.invalid commit --allow-empty -qm initial
  git -C "$test_root/main" worktree add -q -b linked "$test_root/linked"

  # Act: Resolve both working directories independently.
  main_output="$(cd "$test_root/main" && bash "$test_root/workspace-helper" resolve)"
  linked_output="$(cd "$test_root/linked" && bash "$test_root/workspace-helper" resolve)"

  # Assert: Common remote identity produces the same workspace segment.
  [ "$(jq -r '.workspace.segment' <<<"$main_output")" = "$(jq -r '.workspace.segment' <<<"$linked_output")" ]
}

render_helpers
test_public_wrapper_uses_fixed_helpers_without_command_policy_shims
test_inspect_reports_configured_serve_without_exposing_external_state
test_inspect_rejects_conflicting_root_target
test_inspect_fails_closed_when_serve_status_fails
test_inspect_fails_closed_when_node_status_command_fails
test_inspect_fails_closed_for_empty_online_dns_name
test_setup_rejects_malformed_online_dns_name_without_mutation
test_setup_does_not_mutate_when_serve_status_fails
test_inspect_ignores_other_hosts_and_non_https_ports
test_setup_rejects_a_non_proxy_root_without_mutation
test_inspect_falls_back_to_the_app_executable
test_inspect_degrades_when_tailscale_is_offline
test_setup_configures_only_an_empty_serve_root
test_verify_constructs_the_only_remote_url_and_checks_revision
test_verify_accepts_lowercase_http2_revision_header
test_verify_rejects_a_case_mismatched_revision_value
test_verify_rejects_a_non_success_response_with_matching_revision
test_workspace_resolve_normalizes_a_remote_repository
test_workspace_resolve_ignores_hostile_global_git_config
test_workspace_resolve_falls_back_for_a_local_remote
test_workspace_resolve_keeps_linked_worktree_identity
