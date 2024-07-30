#!/bin/sh

# install neovim
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  curl -LO https://github.com/neovim/neovim/releases/download/nightly/nvim.appimage
  chmod u+x nvim.appimage
  sudo mv ./nvim.appimage /usr/local/bin/nvim
elif [[ "$OSTYPE" == "darwin"* ]]; then
  brew upgrade neovim
  brew install --HEAD neovim
else
  # Unknown.
  continue
fi
