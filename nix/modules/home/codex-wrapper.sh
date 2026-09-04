@CANONICALIZE_HERDR_SOCKET@
export CODEX_EXECUTABLE_PATH="$HOME/.local/share/nono-agent-wrappers/codex"
export DISABLE_AUTOUPDATER=1
HERDR_AGENT=codex exec @CODEX@ "$@"
