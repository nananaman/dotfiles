#!/bin/sh

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  if !(type add-apt-repository >/dev/null 2>&1); then
    sudo apt-get install -y software-properties-common
  fi
  sudo apt-add-repository ppa:fish-shell/release-3
  sudo apt-get update
  sudo apt-get install -y fish
elif [[ "$OSTYPE" == "darwin"* ]]; then
  # Mac OSX
  brew install fish
else
  # Unknown.
  continue
fi

sudo chsh $USER -s `which fish`

fish

# fisher
curl -sL https://git.io/fisher | source && fisher install jorgebucaran/fisher

# extentions
fisher install jethrokuan/z
fisher install PatrickF1/fzf.fish
fisher install decors/fish-ghq
