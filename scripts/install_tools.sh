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
  wget https://golang.org/dl/go1.16.6.linux-amd64.tar.gz
  sudo tar -C /usr/local/ -xzf go1.16.6.linux-amd64.tar.gz
  export PATH=$PATH:/usr/local/go/bin
  cd -
else
  echo "Your platform ($(uname -a)) is not supported."
  exit 1
fi

# ghq
go get github.com/x-motemen/ghq

# memo
go get github.com/mattn/memo

# code2img
git clone https://github.com/skanehira/code2img
cd code2img && go install


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
cargo install bat

# fd
cargo install fd-find

# starship
sh -c "$(curl -fsSL https://starship.rs/install.sh)"
curl -fsSL https://starship.rs/install.sh > /tmp/install_starship.sh
sh /tmp/install_starship.sh -y
