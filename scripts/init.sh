#!/bin/sh

echo "[Info] start setup..."

echo "[Info] Install tools..."
bash install_tools.sh

echo "[Info] Install vim8..."
bash install_nvim.sh

# echo "[Info] Install fish..."
# bash install_fish.sh

echo "[Info] Install nushell..."
bash install_nushell.sh

echo "[Info] Install fonts..."
bash install_fonts.sh

echo "[Info] Install wezterm..."
bash install_wezterm.sh

cat << END

**************************
**    SETUP FINISHED!   **
**************************

END
