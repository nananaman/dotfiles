GITHUB_URL='https://github.com/nananaman/dotfiles.git'

# install git
if !(type git >/dev/null 2>&1); then
  if [ "$(uname)" == 'Darwin' ]; then
    brew install git
  elif [ "$(expr substr $(uname -s) 1 5)" == 'Linux' ]; then
    sudo apt-get install git
  fi
fi

git clone --recursive "$GITHUB_URL" '~/.dotfiles'

cd ~/dotfiles
make deploy
make init
