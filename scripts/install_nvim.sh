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

# for WSL
if [[ -v $WSL_DISTRO_NAME ]]; then
  curl -sLo/tmp/win32yank.zip https://github.com/equalsraf/win32yank/releases/download/v0.0.4/win32yank-x64.zip
  unzip -p /tmp/win32yank.zip win32yank.exe > /tmp/win32yank.exe
  chmod +x /tmp/win32yank.exe
  sudo mv /tmp/win32yank.exe /usr/local/bin/
fi
