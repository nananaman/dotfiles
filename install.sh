GITHUB_URL='https://github.com/nananaman/dotfiles.git'

# install git
if !(type git >/dev/null 2>&1); then
  if [ "$(uname)" == 'Darwin' ]; then
    brew install git
  elif [ "$(expr substr $(uname -s) 1 5)" == 'Linux' ]; then
    if !(type sudo >/dev/null 2>&1); then
      apt-get install sudo
    fi
    sudo apt-get install git
  fi
fi

git clone --recursive "$GITHUB_URL" ~/dotfiles

cd ~/dotfiles
if !(type make >/dev/null 2>&1); then
  if [ "$(uname)" == 'Darwin' ]; then
    brew install make
  elif [ "$(expr substr $(uname -s) 1 5)" == 'Linux' ]; then
    sudo apt-get install make
  fi
fi
make deploy
make init
