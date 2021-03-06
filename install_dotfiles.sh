#!/bin/sh

set -u

# 実行場所のディレクトリを取得
THIS_DIR=$(cd $(dirname $0); pwd)

cd $THIS_DIR
git submodule init
git submodule update

ln -snfv ~/dotfiles/.vimrc ~/.vimrc
ln -snfv ~/dotfiles/.xonshrc ~/.xonshrc
ln -snfv ~/dotfiles/coc-settings.json ~/.vim/coc-settings.json
ln -snfv ~/dotfiles/.tmux.conf ~/.tmux.conf
ln -snfv ~/dotfiles/memo/config.toml ~/.config/memo/config.toml

if [ "$(expr substr $(uname -s) 1 10)" == 'MINGW32_NT' ]; then
  cp ~/dotfiles/.hyper.win.js /mnt/c/Users/foola/AppData/Roaming/Hyper/.hyper.js
else
  ln -snfv ~/dotfiles/.hyper.js ~/.hyper.js
fi
