#!/bin/zsh

function tmux-ghq-session {
  local selected_project project_dir session_name

  selected_project=$(ghq list | fzf +m --reverse --prompt="tmux session > ") || return

  project_dir="$(ghq root)/$selected_project"
  session_name="$(printf '%s' "$selected_project" | tr '/:' '__')"

  if [ -n "$TMUX" ]; then
    if ! tmux has-session -t "$session_name" 2>/dev/null; then
      tmux new-session -d -s "$session_name" -c "$project_dir"
    fi
    tmux switch-client -t "$session_name"
  else
    tmux new-session -A -s "$session_name" -c "$project_dir"
  fi
}
