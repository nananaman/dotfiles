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

PATH="@HELPER_PATH@:$PATH"
export PATH

exec @BUN@ @CLI@ "$@"
