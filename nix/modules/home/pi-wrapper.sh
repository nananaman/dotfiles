@CANONICALIZE_HERDR_SOCKET@
pi_bin="$HOME/.vite-plus/bin/pi"
if [ ! -x "$pi_bin" ]; then
  echo "pi: raw executable not found: $pi_bin" >&2
  exit 127
fi
if [ -n "${NONO_CAP_FILE:-}" ]; then
  exec "$pi_bin" "$@"
fi
HERDR_AGENT=pi exec @NONO@ run --silent \
  --profile "$HOME/.config/nono/profiles/chouge-pi.jsonc" --allow-cwd -- "$pi_bin" "$@"
