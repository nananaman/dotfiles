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

cat << END

**************************
DOTFILES SETUP FINISHED!
**************************

END
