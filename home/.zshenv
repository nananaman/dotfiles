# Available to non-interactive shells and GUI-launched terminals as well.
typeset -U path
path=("$HOME/.local/bin" "$HOME/.local/share/mise/shims" $path)
if [[ -d /opt/homebrew/bin ]]; then
  path+=(/opt/homebrew/bin /opt/homebrew/sbin)
elif [[ -d /home/linuxbrew/.linuxbrew/bin ]]; then
  path+=(/home/linuxbrew/.linuxbrew/bin /home/linuxbrew/.linuxbrew/sbin)
fi
export PATH
export NVIM_LOG_FILE=/dev/null
export RTK_TELEMETRY_DISABLED=1
