#!/bin/sh

echo "[Info] start setup..."

echo "[Info] Install dotfiles..."
sh install_dotfiles.sh

echo "[Info] Install fzf..."
sh install_fzf.sh

echo "[Info] Install tmux..."
sh install_tmux.sh

echo "[Info] Install vim8..."
sh install_vim8.sh

echo "[Info] Install python..."
sh install_pyenv.sh

echo "[Info] Install xonsh..."
sh install_xonsh.sh

cat << END

**************************
**    SETUP FINISHED!   **
**************************

END
