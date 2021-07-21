#!/bin/sh

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  sudo apt-get install fish
elif [[ "$OSTYPE" == "darwin"* ]]; then
  # Mac OSX
  brew install fish fish fzf ghq fd bat
else
  # Unknown.
fi

chsh -s `which fish`

# fisher
curl -sL https://git.io/fisher | source && fisher install jorgebucaran/fisher

# extentions
fisher install jethrokuan/z
fisher install PatrickF1/fzf.fish
fisher install decors/fish-ghq

# starship
sh -c "$(curl -fsSL https://starship.rs/install.sh)"
