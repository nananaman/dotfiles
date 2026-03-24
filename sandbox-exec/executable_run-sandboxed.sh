#!/usr/bin/env bash
set -euo pipefail

PROFILE_PATH="${HOME}/.config/sandbox-exec/agent.sb"

usage() {
  echo "Usage: $(basename "$0") [--workdir=/path] <command> [args...]"
  exit 1
}

# Parse --workdir flag
workdir=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --workdir=*)
      workdir="${1#--workdir=}"
      shift
      ;;
    --workdir)
      workdir="${2:-}"
      shift 2
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage
      ;;
    *)
      break
      ;;
  esac
done

[[ $# -eq 0 ]] && usage

# Resolve effective workdir: explicit flag → git root → pwd
if [[ -n "$workdir" ]]; then
  effective_workdir="$(cd "$workdir" && pwd -P)"
elif git_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  effective_workdir="$(cd "$git_root" && pwd -P)"
else
  effective_workdir="$(pwd -P)"
fi

# Detect git worktree: if the workdir is a worktree, also grant access to the main repo.
# Git worktrees need read/write to the main repo's .git/worktrees/<name> directory.
main_repo_dir=""
if git_common_dir="$(git -C "$effective_workdir" rev-parse --git-common-dir 2>/dev/null)"; then
  git_common_dir="$(cd "$effective_workdir" && cd "$git_common_dir" && pwd -P)"
  # git-common-dir returns the .git dir; the repo root is its parent
  main_repo_root="$(dirname "$git_common_dir")"
  # Only set main_repo_dir if it differs from the effective workdir
  if [[ "$main_repo_root" != "$effective_workdir" ]]; then
    main_repo_dir="$main_repo_root"
  fi
fi

# Build ancestor literal rules for a directory
build_ancestors() {
  local dir="$1"
  local ancestors=""
  local current
  current="$(dirname "$dir")"
  while [[ "$current" != "/" ]]; do
    ancestors="${ancestors}    (literal \"${current}\")
"
    current="$(dirname "$current")"
  done
  echo "$ancestors"
}

# Build the workdir + optional main repo grants
workdir_ancestors="$(build_ancestors "$effective_workdir")"
extra_grants=""

if [[ -n "$main_repo_dir" ]]; then
  main_repo_ancestors="$(build_ancestors "$main_repo_dir")"
  extra_grants=";; Main repo access for git worktree operations
(allow file-read*
${main_repo_ancestors}    (literal \"${main_repo_dir}\")
)
(allow file-read* file-write*
    (subpath \"${main_repo_dir}\")
)"
fi

inject_block=";; Ancestor literals for dynamic workdir
(allow file-read*
${workdir_ancestors})
${extra_grants}"

# Assemble the final profile
tmpfile="$(mktemp)"
inject_tmpfile="$(mktemp)"
trap 'rm -f "$tmpfile" "$inject_tmpfile"' EXIT

cp "$PROFILE_PATH" "$tmpfile"

# Replace __SAFEHOUSE_WORKDIR__ with the resolved path
sed -i '' "s|__SAFEHOUSE_WORKDIR__|${effective_workdir}|g" "$tmpfile"

# Inject ancestor + main-repo block before __WORKDIR_BLOCK_START__
echo "$inject_block" > "$inject_tmpfile"
sed -i '' "/;; __WORKDIR_BLOCK_START__/r ${inject_tmpfile}" "$tmpfile"

exec sandbox-exec -p "$(cat "$tmpfile")" "$@"
