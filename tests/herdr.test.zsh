#!/usr/bin/env zsh
set -u

SCRIPT_DIR="${0:A:h}"
REPO_ROOT="${SCRIPT_DIR:h}"
HOME_PACKAGES="$REPO_ROOT/nix/modules/home/packages.nix"
DOTFILES_MODULE="$REPO_ROOT/nix/modules/home/dotfiles.nix"

failures=0

pass() {
  print -ru2 -- "ok - $1"
}

fail() {
  print -ru2 -- "not ok - $1"
  failures=$((failures + 1))
}

assert_contains() {
  local name="$1"
  local haystack="$2"
  local needle="$3"

  if [[ "$haystack" == *"$needle"* ]]; then
    pass "$name"
  else
    fail "$name: expected content to contain <$needle>"
  fi
}

test_sandboxed_agent_wrappers_report_agent_kind_to_herdr() {
  # Arrange: Home Manager renders the three public agent wrappers from one Nix module.
  local packages
  packages="$(<"$HOME_PACKAGES")"

  # Act & Assert: Each outer nono launch carries the agent kind consumed by Herdr.
  assert_contains "Codex wrapper は Herdr に codex として報告する" \
    "$packages" 'HERDR_AGENT=codex exec ${nono-cli}/bin/nono run'
  assert_contains "Claude wrapper は Herdr に claude として報告する" \
    "$packages" 'HERDR_AGENT=claude exec ${nono-cli}/bin/nono run'
  assert_contains "Pi wrapper は Herdr に pi として報告する" \
    "$packages" 'HERDR_AGENT=pi exec ${nono-cli}/bin/nono run'
}

test_hunk_plugin_uses_global_registry_without_server_session() {
  # Arrange: Home Manager owns the persistent Hunk Review plugin registration.
  local dotfiles_module
  dotfiles_module="$(<"$DOTFILES_MODULE")"

  # Act & Assert: Registration is queried and linked through the global plugin CLI.
  assert_contains "Hunk plugin はglobal registryから検索する" \
    "$dotfiles_module" 'herdr plugin list --plugin hunk-review --json'
  assert_contains "Hunk plugin はmanaged pathをlinkする" \
    "$dotfiles_module" 'herdr plugin link "$plugin_path"'
}

test_hunk_plugin_relink_preserves_disabled_state() {
  # Arrange: A user may have disabled a previously linked Hunk Review plugin.
  local dotfiles_module
  dotfiles_module="$(<"$DOTFILES_MODULE")"

  # Act & Assert: Relinking a stale path keeps the explicit disabled state.
  assert_contains "Hunk plugin のdisabled状態を再link時に保持する" \
    "$dotfiles_module" 'herdr plugin link "$plugin_path" --disabled'
}

test_sandboxed_agent_wrappers_report_agent_kind_to_herdr
test_hunk_plugin_uses_global_registry_without_server_session
test_hunk_plugin_relink_preserves_disabled_state

if (( failures > 0 )); then
  print -ru2 -- "$failures test(s) failed"
  exit 1
fi

print -ru2 -- "all Herdr tests passed"
