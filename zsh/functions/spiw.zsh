function spiw() {
  local settings="$HOME/.config/srt/pi.json"
  local repo_root

  repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "spiw: not inside a git repository" >&2
    return 1
  }

  if ! git -C "$repo_root" diff --quiet --ignore-submodules -- 2>/dev/null || \
     ! git -C "$repo_root" diff --cached --quiet --ignore-submodules -- 2>/dev/null || \
     [ -n "$(git -C "$repo_root" ls-files --others --exclude-standard 2>/dev/null)" ]; then
    echo "spiw: warning: current checkout has uncommitted changes; worktree starts from origin/HEAD" >&2
  fi

  if git -C "$repo_root" remote get-url origin >/dev/null 2>&1; then
    if ! git -C "$repo_root" fetch origin; then
      echo "spiw: warning: git fetch origin failed; using local origin/HEAD" >&2
    fi
    if ! git -C "$repo_root" rev-parse --verify --quiet origin/HEAD >/dev/null; then
      git -C "$repo_root" remote set-head origin -a >/dev/null 2>&1
    fi
  else
    echo "spiw: warning: origin remote not found; using local origin/HEAD" >&2
  fi

  if ! git -C "$repo_root" rev-parse --verify --quiet origin/HEAD >/dev/null; then
    echo "spiw: origin/HEAD not found; cannot create fresh worktree" >&2
    return 1
  fi

  local name
  name="$(mktemp -u "spi-$(date +%Y%m%d-%H%M%S)-XXXXXX")"
  local worktree_dir="$repo_root/.pi/worktrees/$name"
  local branch="spi/$name"

  mkdir -p "${worktree_dir:h}" || return 1

  if ! git -C "$repo_root" worktree add -b "$branch" "$worktree_dir" origin/HEAD; then
    echo "spiw: failed to create worktree: $worktree_dir" >&2
    return 1
  fi

  echo "spiw: created worktree $worktree_dir ($branch)" >&2

  if [[ -f "$worktree_dir/mise.toml" ]] && command -v mise >/dev/null 2>&1; then
    mise trust "$worktree_dir/mise.toml" || return 1
  fi

  (cd "$worktree_dir" && srt --settings "$settings" pi --name "$name" "$@")
}
