# Codex sessionではagent wrapper directoryがnonoのTool Sandbox shimよりPATHの前に置かれる。
# Homebrew launcherを直接実行するとlibexec/containerが親sandboxに拒否されるため、
# nonoが生成したshimへ明示的に委譲する。
if [ -n "${NONO_TOOL_SANDBOX_SHIM_DIR:-}" ] &&
  [ -x "$NONO_TOOL_SANDBOX_SHIM_DIR/container" ]; then
  exec "$NONO_TOOL_SANDBOX_SHIM_DIR/container" "$@"
fi
exec @CONTAINER@ "$@"
