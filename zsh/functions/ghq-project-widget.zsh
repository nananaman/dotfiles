#!/bin/zsh

function ghq-project-widget {
  if [ -n "$TMUX" ]; then
    tmux-ghq-session
  else
    cd-ghq-project
  fi

  zle reset-prompt
}
