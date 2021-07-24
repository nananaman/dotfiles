#!/bin/sh

# fzf
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
yes | ~/.fzf/install

echo '[ -f ~/.fzf.bash ] && source ~/.fzf.bash' >> ~/.bashrc


# install go
if [ "$(uname)" == 'Darwin' ]; then
  brew install go
elif [ "$(expr substr $(uname -s) 1 5)" == 'Linux' ]; then
  cd /tmp
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
curl https://sh.rustup.rs -sSf | sh
source $HOME/.cargo/env

# lsd
cargo install lsd

# bat
cargo install bat

# fd
cargo install fd-find

# starship
sh -c "$(curl -fsSL https://starship.rs/install.sh)"
