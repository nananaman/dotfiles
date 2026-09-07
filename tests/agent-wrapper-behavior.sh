#!/usr/bin/env bash

set -euo pipefail

# Arrange: 呼び出し元の端末設定を除き、wrapper 自身による環境変数の追加を検証する。
unset HERDR_AGENT

test_root="$(mktemp -d "${TMPDIR:-/tmp}/agent-wrapper-test.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT

call_log="$test_root/calls.log"
fake_claude="$test_root/home/.local/bin/claude"
fake_codex="$test_root/fake-codex"
fake_container="$test_root/fake-container"
fake_pi="$test_root/home/.vite-plus/bin/pi"
rendered_claude="$test_root/claude"
rendered_codex="$test_root/codex"
rendered_container="$test_root/container"
rendered_pi="$test_root/pi"

mkdir -p "$(dirname "$fake_claude")" "$(dirname "$fake_pi")"

write_call_recorder() {
  local output="$1"
  local name="$2"

  sed \
    -e "s|@NAME@|$name|g" \
    -e "s|@CALL_LOG@|$call_log|g" \
    tests/fixtures/fake-agent-command.sh >"$output"
  chmod +x "$output"
}

build_wrappers() {
  local repository_root
  local wrapper_outputs

  repository_root="$(pwd -P)"
  wrapper_outputs="$(
    REPOSITORY_ROOT="$repository_root" \
      FAKE_CODEX="$fake_codex" \
      FAKE_CONTAINER="$fake_container" \
      nix build --impure --no-link --print-out-paths --expr '
        let
          repositoryRoot = builtins.getEnv "REPOSITORY_ROOT";
          flake = builtins.getFlake repositoryRoot;
          pkgs = import flake.inputs.nixpkgs {
            system = builtins.currentSystem;
          };
          wrapper = import (repositoryRoot + "/nix/modules/home/agent-wrappers.nix") { inherit pkgs; };
        in
        [
          (wrapper.claude {})
          (wrapper.codex {
            codex = builtins.getEnv "FAKE_CODEX";
          })
          (wrapper.container {
            container = builtins.getEnv "FAKE_CONTAINER";
          })
          (wrapper.pi {})
        ]
      '
  )"

  while IFS= read -r wrapper_output; do
    if [[ -x "$wrapper_output/bin/claude" ]]; then
      rendered_claude="$wrapper_output/bin/claude"
    elif [[ -x "$wrapper_output/bin/codex" ]]; then
      rendered_codex="$wrapper_output/bin/codex"
    elif [[ -x "$wrapper_output/bin/container" ]]; then
      rendered_container="$wrapper_output/bin/container"
    elif [[ -x "$wrapper_output/bin/pi" ]]; then
      rendered_pi="$wrapper_output/bin/pi"
    fi
  done <<<"$wrapper_outputs"
}

assert_calls_equal() {
  local expected="$1"
  local actual

  actual="$(cat "$call_log")"
  if [[ "$actual" != "$expected" ]]; then
    printf 'expected calls:\n%s\nactual calls:\n%s\n' "$expected" "$actual" >&2
    return 1
  fi
}

test_claude_update_uses_the_raw_executable() {
  # Arrange: self-update先をargv記録用fakeへ置き換える。
  : >"$call_log"
  write_call_recorder "$fake_claude" claude

  # Act: directory全体の置換権限が必要なself-updateを起動する。
  env -u NONO_CAP_FILE HOME="$test_root/home" CALL_LOG="$call_log" \
    "$rendered_claude" update

  # Assert: self-updateをraw executableへ委譲する。
  assert_calls_equal 'claude
update'
}

test_claude_prompt_uses_the_raw_executable() {
  # Arrange: 通常のpromptをraw executableで観測できるようにする。
  : >"$call_log"
  write_call_recorder "$fake_claude" claude

  # Act: 通常のpromptをwrapperへ渡す。
  env -u NONO_CAP_FILE HOME="$test_root/home" CALL_LOG="$call_log" \
    "$rendered_claude" 'review the README'

  # Assert: nonoやpermission迂回flagを追加せずraw executableへ委譲する。
  assert_calls_equal 'claude
review the README'
}

test_claude_update_prefix_with_more_arguments_uses_the_raw_executable() {
  # Arrange: self-updateに似た通常promptをraw executableで観測する。
  : >"$call_log"
  write_call_recorder "$fake_claude" claude

  # Act: updateから始まる複数引数をwrapperへ渡す。
  env -u NONO_CAP_FILE HOME="$test_root/home" CALL_LOG="$call_log" \
    "$rendered_claude" update README

  # Assert: argvを変更せずraw executableへ委譲する。
  assert_calls_equal 'claude
update
README'
}

test_codex_parent_session_uses_the_raw_executable() {
  # Arrange: Codex実体をargv記録用fakeへ置き換える。
  : >"$call_log"
  write_call_recorder "$fake_codex" codex

  # Act: nono capabilityが未注入の親sessionからCodexを起動する。
  env -u NONO_CAP_FILE HOME="$test_root/home" CALL_LOG="$call_log" \
    "$rendered_codex" exec 'argument with spaces'

  # Assert: nonoやsandbox迂回flagを追加せずraw executableへ委譲する。
  assert_calls_equal 'codex
exec
argument with spaces'
}

test_codex_child_session_uses_the_raw_executable() {
  # Arrange: 既にnono内にいるsessionでCodex実体への委譲だけを観測する。
  : >"$call_log"
  write_call_recorder "$fake_codex" codex

  # Act: capabilityを注入済みとしてnested Codexを起動する。
  NONO_CAP_FILE="$test_root/cap.json" HOME="$test_root/home" CALL_LOG="$call_log" \
    "$rendered_codex" resume

  # Assert: 注入済みのnono環境でもraw Codexへargvだけを渡す。
  assert_calls_equal "codex
resume"
}

test_container_prefers_the_tool_sandbox_shim() {
  local shim_dir="$test_root/shims"

  # Arrange: Tool Sandbox shimとhost側containerの両方を観測可能にする。
  : >"$call_log"
  mkdir -p "$shim_dir"
  write_call_recorder "$shim_dir/container" container-shim
  write_call_recorder "$fake_container" container-host

  # Act: shimが注入されたsessionからcontainerを起動する。
  NONO_TOOL_SANDBOX_SHIM_DIR="$shim_dir" CALL_LOG="$call_log" \
    "$rendered_container" image list

  # Assert: host launcherではなくshimへargvを保持して委譲する。
  assert_calls_equal 'container-shim
image
list'
}

test_container_falls_back_to_the_host_executable_without_a_shim() {
  # Arrange: shimがない通常環境でhost側containerだけを観測可能にする。
  : >"$call_log"
  write_call_recorder "$fake_container" container-host

  # Act: Tool Sandbox shimなしでcontainerを起動する。
  env -u NONO_TOOL_SANDBOX_SHIM_DIR CALL_LOG="$call_log" \
    "$rendered_container" system status

  # Assert: host実体へargvを保持してfallbackする。
  assert_calls_equal 'container-host
system
status'
}

test_pi_parent_session_uses_the_raw_executable() {
  # Arrange: Pi実体をargv記録用fakeへ置き換える。
  : >"$call_log"
  write_call_recorder "$fake_pi" pi

  # Act: nono capabilityが未注入の親sessionからPiを起動する。
  env -u NONO_CAP_FILE HOME="$test_root/home" CALL_LOG="$call_log" \
    "$rendered_pi" --mode plan

  # Assert: nonoを介さずraw Piへargvを渡す。
  assert_calls_equal 'pi
--mode
plan'
}

test_pi_child_session_uses_the_raw_executable() {
  # Arrange: 既にnono内にいるsessionでPi実体への委譲だけを観測する。
  : >"$call_log"
  write_call_recorder "$fake_pi" pi

  # Act: capabilityを注入済みとしてnested Piを起動する。
  NONO_CAP_FILE="$test_root/cap.json" HOME="$test_root/home" CALL_LOG="$call_log" \
    "$rendered_pi" resume

  # Assert: 二重sandboxを作らずraw Piへargvを保持して委譲する。
  assert_calls_equal 'pi
resume'
}

write_call_recorder "$fake_claude" claude
write_call_recorder "$fake_codex" codex
write_call_recorder "$fake_container" container-host
write_call_recorder "$fake_pi" pi
build_wrappers

test_claude_update_uses_the_raw_executable
test_claude_prompt_uses_the_raw_executable
test_claude_update_prefix_with_more_arguments_uses_the_raw_executable
test_codex_parent_session_uses_the_raw_executable
test_codex_child_session_uses_the_raw_executable
test_container_prefers_the_tool_sandbox_shim
test_container_falls_back_to_the_host_executable_without_a_shim
test_pi_parent_session_uses_the_raw_executable
test_pi_child_session_uses_the_raw_executable
