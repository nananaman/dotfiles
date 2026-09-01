@CANONICALIZE_HERDR_SOCKET@
claude_bin="$HOME/.local/bin/claude"
if [ ! -x "$claude_bin" ]; then
  echo "claude: raw executable not found: $claude_bin" >&2
  exit 127
fi
if [ -n "${NONO_CAP_FILE:-}" ]; then
  exec "$claude_bin" "$@"
fi
if [ "$#" -eq 1 ]; then
  case "$1" in
    update | upgrade)
      # Native self-update replaces $HOME/.local/bin/claude via a rename, which needs
      # write access to the whole containing directory. Run it outside the sandbox
      # rather than granting that directory-wide write to every sandboxed session.
      # Guarded to exactly one argv so an unquoted prompt beginning with "update"
      # (claude's positional prompt argument) cannot also take this path.
      exec "$claude_bin" "$@"
      ;;
  esac
fi
HERDR_AGENT=claude exec @NONO@ run --silent \
  --profile "$HOME/.config/nono/profiles/chouge-claude.jsonc" --allow-cwd --allow-launch-services -- \
  "$claude_bin" --dangerously-skip-permissions "$@"
