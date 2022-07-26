#!/bin/sh

# fzf
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
yes | ~/.fzf/install

# if use bash
# echo '[ -f ~/.fzf.bash ] && source ~/.fzf.bash' >> ~/.bashrc

# install go
if [ "$(uname)" == 'Darwin' ]; then
  brew install go
elif [ "$(expr substr $(uname -s) 1 5)" == 'Linux' ]; then
  cd /tmp
  if !(type wget >/dev/null 2>&1); then
    sudo apt-get install wget
  fi
  wget https://go.dev/dl/go1.17.4.linux-amd64.tar.gz
  sudo tar -C /usr/local/ -xzf go1.17.4.linux-amd64.tar.gz
  export PATH=$PATH:/usr/local/go/bin
  cd -
else
  echo "Your platform ($(uname -a)) is not supported."
  exit 1
fi

# ghq
go install github.com/x-motemen/ghq@latest

# memo
go install github.com/mattn/memo@latest

# lazygit
go install github.com/jesseduffield/lazygit@latest

# code2img
git clone https://github.com/skanehira/code2img
cd code2img && go install


# deno
curl -fsSL https://deno.land/x/install/install.sh | sh
# dex
deno install --allow-read --allow-write --allow-run --reload --force --name dex https://pax.deno.dev/kawarimidoll/deno-dex/main.ts


# install rust
curl https://sh.rustup.rs -sSf > /tmp/install_rust.sh
sh /tmp/install_rust.sh -y
source $HOME/.cargo/env

if [ "$(expr substr $(uname -s) 1 5)" == 'Linux' ]; then
  sudo apt-get install gcc -y
fi

# lsd
cargo install lsd

# bat
if [ "$(uname)" == 'Darwin' ]; then
  sudo apt-get install bat fd-find
  sudo ln -s /usr/bin/batcat /usr/local/bin/bat
elif [ "$(expr substr $(uname -s) 1 5)" == 'Linux' ]; then
  brew install bat
fi

# delta
cargo install delta

# silicon
cargo install silicon

# starship
curl -fsSL https://starship.rs/install.sh > /tmp/install_starship.sh
sh /tmp/install_starship.sh -y
