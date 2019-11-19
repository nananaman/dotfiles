#!/bin/sh

set -u

# 実行場所のディレクトリを取得
THIS_DIR=$(cd $(dirname $0); pwd)

cd $THIS_DIR
git submodule init
git submodule update

echo "start setup..."
for f in .??*; do
    ["$f" = ".git" ] && continue
    ["$f" = ".cheatsheet.md" ] && continue
    ["$f" = ".gitconfig.local.template" ] && continue
    ["$f" = ".gitmodules" ] && continue

    ln -snfv ~/dotfiles/"$f" ~/
done

ln -snfv ~/dotfiles/coc-settings.json ~/.vim/coc-settings.json
ln -snfv ~/dotfiles/.tmux.conf ~/.tmux.conf

cat << END

**************************
DOTFILES SETUP FINISHED!
**************************

END
