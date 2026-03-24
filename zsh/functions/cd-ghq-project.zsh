#!/bin/zsh

function cd-ghq-project {
  local selected_project=$(ghq list | fzf +m --reverse --prompt="Project > ")

  if [ -n "$selected_project" ]; then
    cd $(ghq root)/$selected_project
  fi
}
