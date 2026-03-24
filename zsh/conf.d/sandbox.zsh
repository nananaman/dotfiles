claude() { ~/.config/sandbox-exec/run-sandboxed.sh claude --dangerously-skip-permissions "$@" }
gemini() { NO_BROWSER=true ~/.config/sandbox-exec/run-sandboxed.sh gemini --yolo "$@" }
