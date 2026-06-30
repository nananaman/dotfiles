#!/bin/zsh

function herdr-ghq-workspace {
  local selected_project project_dir workspace_label

  selected_project=$(ghq list | fzf +m --reverse --prompt="herdr workspace > ") || return

  project_dir="$(ghq root)/$selected_project"
  workspace_label="${selected_project:t}"

  if [ -n "$HERDR_ENV" ]; then
    herdr workspace create --cwd "$project_dir" --label "$workspace_label" --focus >/dev/null
  else
    cd "$project_dir"
  fi
}
