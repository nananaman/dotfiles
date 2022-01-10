#!/bin/sh

# install neovim
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  curl -LO https://github.com/neovim/neovim/releases/nightly/download/nvim.appimage
  chmod u+x nvim.appimage
  sudo mv ./nvim.appimage /usr/local/bin/nvim
elif [[ "$OSTYPE" == "darwin"* ]]; then
  brew upgrade neovim
  brew install --HEAD neovim
else
  # Unknown.
  continue
fi

# nodejs
# npm
curl -sL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt-get install -y nodejs

# yarn
sudo npm install -g yarn

# deno
curl -fsSL https://deno.land/x/install/install.sh | sh

# dein
curl https://raw.githubusercontent.com/Shougo/dein.vim/master/bin/installer.sh > installer.sh
# For example, we just use `~/.cache/dein` as installation directory
sh ./installer.sh ~/.cache/dein
