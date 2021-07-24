#!/bin/sh

cp -r ~/dotfiles/home/. ~/

if [ "$(expr substr $(uname -s) 1 10)" == 'MINGW32_NT' ]; then
  cp ~/dotfiles/.hyper.win.js /mnt/c/Users/foola/AppData/Roaming/Hyper/.hyper.js
fi
