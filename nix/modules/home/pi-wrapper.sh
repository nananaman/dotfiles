@CANONICALIZE_HERDR_SOCKET@
pi_bin="$HOME/.vite-plus/bin/pi"
if [ ! -x "$pi_bin" ]; then
  echo "pi: raw executable not found: $pi_bin" >&2
  exit 127
fi
HERDR_AGENT=pi exec "$pi_bin" "$@"
