set -euo pipefail

case "${1:-}" in
  publish)
    if [ "$#" -ne 4 ] || [ "$3" != "--name" ]; then
      echo "usage: host-artifact publish PATH --name NAME" >&2
      exit 64
    fi
    ;;
  remove)
    if [ "$#" -ne 3 ] || [ "$2" != "--name" ]; then
      echo "usage: host-artifact remove --name NAME" >&2
      exit 64
    fi
    ;;
  status|setup)
    if [ "$#" -ne 1 ]; then
      echo "usage: host-artifact ${1}" >&2
      exit 64
    fi
    ;;
  *)
    echo "usage: host-artifact <publish PATH --name NAME | remove --name NAME | status | setup>" >&2
    exit 64
    ;;
esac

shim_dir="${NONO_TOOL_SANDBOX_SHIM_DIR:-}"
case "$shim_dir" in
  /*) ;;
  *) echo "host-artifact: command-policy shim directory is unavailable" >&2; exit 69 ;;
esac
if [ ! -d "$shim_dir" ]; then
  echo "host-artifact: command-policy shim directory is unavailable" >&2
  exit 69
fi
for helper in host-artifact-service host-artifact-tailscale host-artifact-workspace; do
  if [ ! -x "$shim_dir/$helper" ]; then
    echo "host-artifact: required command-policy shim is unavailable: $helper" >&2
    exit 69
  fi
done
PATH="$shim_dir:$PATH"
export PATH

exec @BUN@ @CLI@ "$@"
