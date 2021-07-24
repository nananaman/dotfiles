#!/bin/sh

echo "[Info] start setup..."

echo "[Info] Install tools..."
bash install_tools.sh

echo "[Info] Install tmux..."
bash install_tmux.sh

echo "[Info] Install vim8..."
bash install_vim8.sh

echo "[Info] Install fish..."
bash install_fish.sh

cat << END

**************************
**    SETUP FINISHED!   **
**************************

END
