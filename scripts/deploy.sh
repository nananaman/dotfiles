#!/bin/sh

cp -r ~/dotfiles/home/. ~/

# is WSL
WSL_VERSION_FILE="/proc/version"
if [[ -e $WSL_VERSION_FILE && $(grep WSL $WSL_VERSION_FILE) ]]; then
  cp ~/dotfiles/home/.hyper.win.js /mnt/c/Users/foola/AppData/Roaming/Hyper/.hyper.js
fi
