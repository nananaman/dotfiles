#!/bin/zsh

function ghq-project-widget {
  if [ -n "$HERDR_ENV" ]; then
    herdr-ghq-workspace
  else
    cd-ghq-project
  fi

  zle reset-prompt
}
