#!/bin/sh

set -u

# 実行場所のディレクトリを取得
THIS_DIR=$(cd $(dirname $0); pwd)

cd $THIS_DIR
git submodule init
git submodule update

echo "start setup..."

ln -snfv ~/dotfiles/.vimrc ~/.vimrc
ln -snfv ~/dotfiles/.xonshrc ~/.xonshrc
ln -snfv ~/dotfiles/coc-settings.json ~/.vim/coc-settings.json
ln -snfv ~/dotfiles/.tmux.conf ~/.tmux.conf

if [ "$(expr substr $(uname -s) 1 10)" == 'MINGW32_NT' ]; then
  ln -snfv ~/dotfiles/.hyper.win.js /mnt/c/Users/foola/AppData/Roaming/Hyper/.hyper.js
else
  ln -snfv ~/dotfiles/.hyper.js ~/.hyper.js
fi

cat << END

**************************
DOTFILES SETUP FINISHED!
**************************

END
