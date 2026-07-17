#!/usr/bin/env zsh
set -u

SCRIPT_DIR="${0:A:h}"
REPO_ROOT="${SCRIPT_DIR:h}"
SOMP_SCRIPT="$REPO_ROOT/zsh/functions/somp.zsh"

failures=0
tmp_root=""

pass() {
  print -ru2 -- "ok - $1"
}

fail() {
  print -ru2 -- "not ok - $1"
  failures=$((failures + 1))
}

assert_eq() {
  local name="$1"
  local expected="$2"
  local actual="$3"

  if [[ "$actual" == "$expected" ]]; then
    pass "$name"
  else
    fail "$name: expected <$expected>, got <$actual>"
  fi
}

assert_contains() {
  local name="$1"
  local haystack="$2"
  local needle="$3"

  if [[ "$haystack" == *"$needle"* ]]; then
    pass "$name"
  else
    fail "$name: expected output to contain <$needle>, got <$haystack>"
  fi
}

assert_has_line() {
  local name="$1"
  local haystack="$2"
  local expected_line="$3"

  if print -r -- "$haystack" | grep -Fx -- "$expected_line" >/dev/null; then
    pass "$name"
  else
    fail "$name: expected output to contain line <$expected_line>, got <$haystack>"
  fi
}

json_array_contains() {
  local file="$1"
  local key="$2"
  local expected="$3"

  python3 - "$file" "$key" "$expected" <<'PY'
import json
import sys

file, dotted_key, expected = sys.argv[1:]
with open(file) as f:
    data = json.load(f)

value = data
for part in dotted_key.split('.'):
    value = value[part]

sys.exit(0 if expected in value else 1)
PY
}

assert_json_array_contains() {
  local name="$1"
  local file="$2"
  local key="$3"
  local expected="$4"

  if json_array_contains "$file" "$key" "$expected"; then
    pass "$name"
  else
    fail "$name: expected $key in $file to contain <$expected>"
  fi
}

assert_json_array_not_contains() {
  local name="$1"
  local file="$2"
  local key="$3"
  local unexpected="$4"

  if json_array_contains "$file" "$key" "$unexpected"; then
    fail "$name: expected $key in $file not to contain <$unexpected>"
  else
    pass "$name"
  fi
}

setup_tmp() {
  tmp_root="$(mktemp -d)"
}

teardown_tmp() {
  if [[ -n "$tmp_root" && -d "$tmp_root" ]]; then
    rm -rf "$tmp_root"
  fi
  tmp_root=""
}

run_somp() {
  local stdout_file="$tmp_root/stdout"
  local stderr_file="$tmp_root/stderr"
  local log_file="$tmp_root/srt.log"

  (
    export SRT_STUB_LOG="$log_file"
    source "$SOMP_SCRIPT"
    srt() {
      for arg in "$@"; do
        print -r -- "ARG=$arg" >> "$SRT_STUB_LOG"
      done
    }
    somp "$@"
  ) >"$stdout_file" 2>"$stderr_file"
}

test_somp_runs_omp_with_dedicated_sandbox_settings() {
  # Arrange
  setup_tmp

  # Act
  XDG_CONFIG_HOME="$tmp_root/xdg" run_somp --help
  local exit_code="$?"
  local log=""
  if [[ -f "$tmp_root/srt.log" ]]; then
    log="$(<"$tmp_root/srt.log")"
  fi

  # Assert
  assert_eq "somp は srt 起動まで成功する" "0" "$exit_code"
  assert_contains "somp は XDG_CONFIG_HOME 配下の OMP 用 sandbox 設定を使う" "$log" "ARG=$tmp_root/xdg/srt/omp.json"
  assert_has_line "srt option と OMP option は -- で区切る" "$log" "ARG=--"
  assert_contains "omp command が srt に渡される" "$log" "ARG=omp"
  assert_contains "引数は omp に転送される" "$log" "ARG=--help"

  teardown_tmp
}

test_srt_omp_allows_omp_state_writes_without_relaxing_local_binding() {
  # Arrange
  local settings="$REPO_ROOT/srt/omp.json"

  # Act & Assert
  assert_json_array_contains "OMP の状態ディレクトリへ書き込める" "$settings" "filesystem.allowWrite" "~/.omp"
  assert_json_array_not_contains "最小導入では worktree 外の Git metadata 書き込みを許可しない" "$settings" "filesystem.allowWrite" "../../../.git"

  local local_binding="$(python3 - "$settings" <<'PY'
import json
import sys
with open(sys.argv[1]) as f:
    data = json.load(f)
print(str(data["network"]["allowLocalBinding"]).lower())
PY
)"
  assert_eq "初期導入では local binding を許可しない" "false" "$local_binding"
  assert_json_array_contains "AWS credential は home 相対 path でも読み取り禁止にする" "$settings" "filesystem.denyRead" "~/.aws"
  assert_json_array_contains "Git hooks は引き続き書き込み禁止にする" "$settings" "filesystem.denyWrite" "../../../.git/hooks/"
  assert_json_array_contains "repo-local Git config による hook bypass を防ぐ" "$settings" "filesystem.denyWrite" ".git/config"
  assert_json_array_contains "worktree 元 Git config による hook bypass を防ぐ" "$settings" "filesystem.denyWrite" "../../../.git/config"
  assert_json_array_not_contains "OMP から Claude skills へは書き込ませない" "$settings" "filesystem.allowWrite" "~/.claude/skills"
  assert_json_array_not_contains "OMP から agent skills へは書き込ませない" "$settings" "filesystem.allowWrite" "~/.agents/skills"
  assert_json_array_contains "AGENTS source of truth は書き込み禁止にする" "$settings" "filesystem.denyWrite" "~/ghq/github.com/nananaman/dotfiles/agents/AGENTS.md"
}

test_home_packages_installs_omp_cli() {
  # Arrange
  local packages="$REPO_ROOT/nix/modules/home/packages.nix"
  local content="$(<"$packages")"

  # Act & Assert
  assert_contains "home packages は OMP CLI package module を読む" "$content" "omp-cli = import ../../../nix/packages/omp-cli { inherit pkgs; }"
  assert_contains "home packages は OMP CLI を install 対象に含める" "$content" "omp-cli"
}

test_omp_package_runs_with_supported_bun_runtime() {
  # Arrange
  local package_nix="$REPO_ROOT/nix/packages/omp-cli/default.nix"
  local content="$(<"$package_nix")"

  # Act & Assert
  assert_contains "OMP package は upstream が要求する Bun 1.3.14 を固定する" "$content" 'version = "1.3.14"'
  assert_contains "OMP package は upstream の engine 契約どおり Bun で起動する" "$content" '${bun_1_3_14}/bin/bun'
}

test_somp_runs_omp_with_dedicated_sandbox_settings
test_srt_omp_allows_omp_state_writes_without_relaxing_local_binding
test_home_packages_installs_omp_cli
test_omp_package_runs_with_supported_bun_runtime

if (( failures > 0 )); then
  print -ru2 -- "$failures test(s) failed"
  exit 1
fi

print -ru2 -- "all somp tests passed"
