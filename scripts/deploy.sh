#!/bin/sh

cp -r ~/dotfiles/home/. ~/

# is WSL
if [[ $(grep WSL /proc/version) ]]; then
  cp ~/dotfiles/.hyper.win.js /mnt/c/Users/foola/AppData/Roaming/Hyper/.hyper.js
fi
