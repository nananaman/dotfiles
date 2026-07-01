#!/usr/bin/env zsh
set -u

SCRIPT_DIR="${0:A:h}"
REPO_ROOT="${SCRIPT_DIR:h}"
SPIW_SCRIPT="$REPO_ROOT/zsh/functions/spiw.zsh"

failures=0
tmp_root=""
test_repo=""

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

assert_nonzero() {
  local name="$1"
  local actual="$2"

  if [[ "$actual" != "0" ]]; then
    pass "$name"
  else
    fail "$name: expected non-zero exit code"
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

assert_file_exists() {
  local name="$1"
  local path="$2"

  if [[ -e "$path" ]]; then
    pass "$name"
  else
    fail "$name: missing <$path>"
  fi
}

setup_repo_with_origin() {
  tmp_root="$(mktemp -d)"
  local origin="$tmp_root/origin.git"
  local repo="$tmp_root/repo"

  mkdir -p "$origin" "$repo"
  git -C "$origin" init --bare --initial-branch=main >/dev/null
  git -C "$origin" symbolic-ref HEAD refs/heads/main

  git -C "$repo" init --initial-branch=main >/dev/null
  git -C "$repo" config user.email test@example.com
  git -C "$repo" config user.name test
  git -C "$repo" config core.hooksPath /dev/null

  print -r -- "initial" > "$repo/README.md"
  git -C "$repo" add README.md
  git -C "$repo" commit -m init >/dev/null
  git -C "$repo" remote add origin "$origin"
  git -C "$repo" push --no-verify -u origin main >/dev/null 2>&1
  git -C "$repo" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main

  test_repo="$repo"
}

teardown_repo() {
  if [[ -n "$tmp_root" && -d "$tmp_root" ]]; then
    rm -rf "$tmp_root"
  fi
  tmp_root=""
  test_repo=""
}

run_spiw_in_repo() {
  local repo="$1"
  shift
  local stdout_file="$tmp_root/stdout"
  local stderr_file="$tmp_root/stderr"
  local log_file="$tmp_root/srt.log"

  (
    cd "$repo" || exit 1
    export SRT_STUB_LOG="$log_file"
    source "$SPIW_SCRIPT"
    srt() {
      print -r -- "PWD=$PWD" > "$SRT_STUB_LOG"
      for arg in "$@"; do
        print -r -- "ARG=$arg" >> "$SRT_STUB_LOG"
      done
    }
    spiw "$@"
  ) >"$stdout_file" 2>"$stderr_file"

  print -r -- "$?"
}

latest_worktree_dir() {
  local repo="$1"
  /usr/bin/find "$repo/.pi/worktrees" -mindepth 1 -maxdepth 1 -type d | sort | tail -n 1
}

worktree_count() {
  local repo="$1"
  /usr/bin/find "$repo/.pi/worktrees" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' '
}

test_spiw_creates_worktree_from_origin_head() {
  # Arrange
  setup_repo_with_origin
  local repo="$test_repo"

  # Act
  local exit_code="$(run_spiw_in_repo "$repo")"
  local worktree="$(latest_worktree_dir "$repo")"

  # Assert
  assert_eq "origin/HEAD 起点の worktree 作成は成功する" "0" "$exit_code"
  assert_file_exists "作成した worktree は git worktree として存在する" "$worktree/.git"
  assert_contains "作成した branch は spi prefix を持つ" "$(git -C "$worktree" branch --show-current)" "spi/spi-"
  assert_eq "worktree の内容は origin/HEAD と一致する" "initial" "$(<"$worktree/README.md")"

  teardown_repo
}

test_spiw_runs_pi_inside_created_worktree() {
  # Arrange
  setup_repo_with_origin
  local repo="$test_repo"

  # Act
  local exit_code="$(run_spiw_in_repo "$repo")"
  local worktree="$(latest_worktree_dir "$repo")"
  local log="$(<"$tmp_root/srt.log")"

  # Assert
  assert_eq "spiw は srt 起動まで成功する" "0" "$exit_code"
  assert_contains "srt は作成した worktree 内で実行される" "$log" "PWD=$worktree"
  assert_contains "pi command が srt に渡される" "$log" "ARG=pi"
  assert_contains "pi session name が設定される" "$log" "ARG=--name"

  teardown_repo
}

test_spiw_trusts_worktree_mise_config_before_entering_worktree() {
  # Arrange
  setup_repo_with_origin
  local repo="$test_repo"
  print -r -- '[tools]' > "$repo/mise.toml"
  git -C "$repo" add mise.toml
  git -C "$repo" commit -m 'add mise config' >/dev/null
  git -C "$repo" push --no-verify origin main >/dev/null 2>&1
  git -C "$repo" fetch origin >/dev/null 2>&1

  local stdout_file="$tmp_root/stdout"
  local stderr_file="$tmp_root/stderr"
  local log_file="$tmp_root/srt.log"
  local mise_log="$tmp_root/mise.log"

  # Act
  (
    cd "$repo" || exit 1
    export SRT_STUB_LOG="$log_file"
    export MISE_STUB_LOG="$mise_log"
    source "$SPIW_SCRIPT"
    mise() {
      for arg in "$@"; do
        print -r -- "ARG=$arg" >> "$MISE_STUB_LOG"
      done
    }
    srt() {
      print -r -- "PWD=$PWD" > "$SRT_STUB_LOG"
    }
    spiw
  ) >"$stdout_file" 2>"$stderr_file"
  local exit_code="$?"
  local worktree="$(latest_worktree_dir "$repo")"
  local mise_log_content="$(<"$mise_log")"
  local srt_log_content="$(<"$log_file")"

  # Assert
  assert_eq "mise.toml がある worktree でも spiw は成功する" "0" "$exit_code"
  assert_contains "worktree の mise.toml を trust する" "$mise_log_content" "ARG=trust"
  assert_contains "trust 対象は作成した worktree の mise.toml" "$mise_log_content" "ARG=$worktree/mise.toml"
  assert_contains "mise trust 後に worktree で srt を起動する" "$srt_log_content" "PWD=$worktree"

  teardown_repo
}

test_spiw_forwards_pi_arguments_unchanged() {
  # Arrange
  setup_repo_with_origin
  local repo="$test_repo"

  # Act
  local exit_code="$(run_spiw_in_repo "$repo" --model "sonnet:high" "hello world")"
  local log="$(<"$tmp_root/srt.log")"

  # Assert
  assert_eq "pi 引数を付けても spiw は成功する" "0" "$exit_code"
  assert_contains "model flag は pi に転送される" "$log" "ARG=--model"
  assert_contains "model value は pi に転送される" "$log" "ARG=sonnet:high"
  assert_contains "空白を含む prompt は 1 引数として転送される" "$log" "ARG=hello world"

  teardown_repo
}

test_spiw_warns_when_checkout_is_dirty() {
  # Arrange
  setup_repo_with_origin
  local repo="$test_repo"
  print -r -- "dirty" > "$repo/README.md"

  # Act
  local exit_code="$(run_spiw_in_repo "$repo")"
  local stderr="$(<"$tmp_root/stderr")"

  # Assert
  assert_eq "dirty checkout でも spiw は続行する" "0" "$exit_code"
  assert_contains "dirty checkout では警告を表示する" "$stderr" "uncommitted changes"

  teardown_repo
}

test_spiw_does_not_copy_dirty_changes_to_fresh_worktree() {
  # Arrange
  setup_repo_with_origin
  local repo="$test_repo"
  print -r -- "dirty" > "$repo/README.md"

  # Act
  local exit_code="$(run_spiw_in_repo "$repo")"
  local worktree="$(latest_worktree_dir "$repo")"

  # Assert
  assert_eq "dirty checkout からでも worktree 作成は成功する" "0" "$exit_code"
  assert_eq "dirty な tracked change は fresh worktree に入らない" "initial" "$(<"$worktree/README.md")"

  teardown_repo
}

test_spiw_creates_unique_worktrees_on_repeated_runs() {
  # Arrange
  setup_repo_with_origin
  local repo="$test_repo"

  # Act
  local first_exit_code="$(run_spiw_in_repo "$repo")"
  local second_exit_code="$(run_spiw_in_repo "$repo")"

  # Assert
  assert_eq "1 回目の spiw は成功する" "0" "$first_exit_code"
  assert_eq "2 回目の spiw も名前衝突せず成功する" "0" "$second_exit_code"
  assert_eq "連続実行では 2 つの worktree が作られる" "2" "$(worktree_count "$repo")"

  teardown_repo
}

test_spiw_fails_outside_git_repository() {
  # Arrange
  tmp_root="$(mktemp -d)"
  local stdout_file="$tmp_root/stdout"
  local stderr_file="$tmp_root/stderr"

  # Act
  (
    cd "$tmp_root" || exit 1
    source "$SPIW_SCRIPT"
    spiw
  ) >"$stdout_file" 2>"$stderr_file"
  local exit_code="$?"
  local stderr="$(<"$stderr_file")"

  # Assert
  assert_nonzero "git repo 外では spiw は失敗する" "$exit_code"
  assert_contains "git repo 外では理由を表示する" "$stderr" "not inside a git repository"

  teardown_repo
}

test_spiw_creates_worktree_from_origin_head
test_spiw_runs_pi_inside_created_worktree
test_spiw_trusts_worktree_mise_config_before_entering_worktree
test_spiw_forwards_pi_arguments_unchanged
test_spiw_warns_when_checkout_is_dirty
test_spiw_does_not_copy_dirty_changes_to_fresh_worktree
test_spiw_creates_unique_worktrees_on_repeated_runs
test_spiw_fails_outside_git_repository

if (( failures > 0 )); then
  print -ru2 -- "$failures test(s) failed"
  exit 1
fi

print -ru2 -- "all spiw tests passed"
