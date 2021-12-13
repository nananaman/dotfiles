#!/bin/sh

cp -r ~/dotfiles/home/. ~/

# is WSL
WSL_VERSION_FILE="/proc/version"
if [[ -e $WSL_VERSION_FILE && $(grep WSL $WSL_VERSION_FILE) ]]; then
  if [[ ! -e $APPDATA ]]; then
    echo '[ERROR] Please set the environment variable "WSLENV=APPDATA/l"'
  else
    cp ~/dotfiles/home/.hyper.win.js $APPDATA/Hyper/.hyper.js
  fi
fi
