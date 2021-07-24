#!/bin/sh

echo "[Info] start setup..."

echo "[Info] Install tools..."
sh install_tools.sh

echo "[Info] Install tmux..."
sh install_tmux.sh

echo "[Info] Install vim8..."
sh install_vim8.sh

echo "[Info] Install fish..."
sh install_fish.sh

cat << END

**************************
**    SETUP FINISHED!   **
**************************

END
