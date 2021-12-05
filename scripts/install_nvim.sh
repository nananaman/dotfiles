#!/bin/sh

# install neovim
curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim.appimage
chmod u+x nvim.appimage
sudo mv ./nvim.appimage /usr/local/bin/nvim

# nodejs
# npm
curl -sL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt-get install -y nodejs

# yarn
sudo npm install -g yarn
