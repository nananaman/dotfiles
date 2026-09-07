@CANONICALIZE_HERDR_SOCKET@
claude_bin="$HOME/.local/bin/claude"
if [ ! -x "$claude_bin" ]; then
  echo "claude: raw executable not found: $claude_bin" >&2
  exit 127
fi
HERDR_AGENT=claude exec "$claude_bin" "$@"
