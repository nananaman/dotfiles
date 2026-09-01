@CANONICALIZE_HERDR_SOCKET@
export CODEX_EXECUTABLE_PATH="$HOME/.local/share/nono-agent-wrappers/codex"
export DISABLE_AUTOUPDATER=1
if [ -n "${NONO_CAP_FILE:-}" ]; then
  exec @CODEX@ --sandbox danger-full-access --ask-for-approval never "$@"
fi
HERDR_AGENT=codex exec @NONO@ run --silent \
  --profile "$HOME/.config/nono/profiles/chouge-codex.jsonc" --allow-cwd -- \
  @CODEX_GUARD@ \
  @CODEX@ --sandbox danger-full-access --ask-for-approval never "$@"
