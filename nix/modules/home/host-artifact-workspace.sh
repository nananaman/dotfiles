set -euo pipefail

if [ "$#" -ne 1 ] || [ "$1" != "resolve" ]; then
  echo "usage: host-artifact-workspace resolve" >&2
  exit 64
fi

git_bin="@GIT@"
jq_bin="@JQ@"
shasum_bin="@SHASUM@"
sed_bin="@SED@"
tr_bin="@TR@"
cut_bin="@CUT@"
GIT_CONFIG_NOSYSTEM=1
GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_NOSYSTEM GIT_CONFIG_GLOBAL
cwd="$(pwd -P)"
canonical="$cwd"
display="${cwd##*/}"

if root="$($git_bin rev-parse --show-toplevel 2>/dev/null)"; then
  remote="$($git_bin -C "$root" config --local --get remote.origin.url 2>/dev/null || true)"
  host=""
  path=""
  case "$remote" in
    *://*)
      without_scheme="${remote#*://}"
      host_and_path="${without_scheme#*@}"
      host="${host_and_path%%/*}"
      path="${host_and_path#*/}"
      ;;
    *@*:*|[A-Za-z0-9.-]*:*)
      host_and_path="${remote#*@}"
      host="${host_and_path%%:*}"
      path="${host_and_path#*:}"
      ;;
  esac
  path="${path%/}"
  path="${path%.git}"
  if [ -n "$host" ] && [ -n "$path" ] && [ "$path" != "$host_and_path" ]; then
    host="$(printf '%s' "$host" | "$tr_bin" '[:upper:]' '[:lower:]')"
    canonical="$host/$path"
    display="${path#*/}"
    case "$path" in
      */*) owner="${path%/*}"; display="${owner##*/}/${path##*/}" ;;
    esac
  else
    canonical="$(cd "$root" && pwd -P)"
    display="${canonical##*/}"
  fi
fi

prefix="$(printf '%s' "$display" | "$tr_bin" '[:upper:]' '[:lower:]' | "$sed_bin" -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' | "$cut_bin" -c1-48 | "$sed_bin" -E 's/-+$//')"
[ -n "$prefix" ] || prefix="workspace"
digest="$(printf '%s' "$canonical" | "$shasum_bin" -a 256 | "$cut_bin" -c1-12)"
segment="$prefix~$digest"

"$jq_bin" -cn --arg segment "$segment" --arg displayName "$display" \
  '{schemaVersion:1,status:"ok",workspace:{segment:$segment,displayName:$displayName}}'
