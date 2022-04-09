#!/bin/sh

# install wezterm
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  curl -LO https://github.com/wez/wezterm/releases/download/20220408-101518-b908e2dd/WezTerm-20220408-101518-b908e2dd-Ubuntu18.04.AppImage
  chmod +x WezTerm-20220408-101518-b908e2dd-Ubuntu18.04.AppImage
  mkdir ~/bin
  mv ./WezTerm-20220408-101518-b908e2dd-Ubuntu18.04.AppImage /usr/local/bin/wezterm
elif [[ "$OSTYPE" == "darwin"* ]]; then
  brew tap wez/wezterm
  brew install --cask wez/wezterm/wezterm
else
  # Unknown.
  continue
fi
