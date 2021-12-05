#!/bin/sh

cp -r ~/dotfiles/home/. ~/

# is WSL
WSL_VERSION_FILE="/proc/version"
if [[ -e $WSL_VERSION_FILE && $(grep WSL $WSL_VERSION_FILE) ]]; then
  if [[ ! -e $APPDATA ]]; then
    echo '[ERROR] Please set the environment variable "WSLENV=APPDATA/l"'
  else
    cp ~/dotfiles/home/.config/alacritty/alacritty.win.yml  $APPDATA/alacritty/alacritty.yml
  fi
fi
