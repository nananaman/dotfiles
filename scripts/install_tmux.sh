if [ "$(uname)" == 'Darwin' ]; then
  # Mac
  brew install tmux
elif [ "$(expr substr $(uname -s) 1 5)" == 'Linux' ]; then
  # Debian, Ubuntu
  TZ=Asia/Tokyo
  ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
  sudo apt-get update
  sudo apt-get install -y automake bison build-essential pkg-config libevent-dev libncurses5-dev

  cd /usr/local/src/
  git clone https://github.com/tmux/tmux

  cd ./tmux/
  ./autogen.sh
  ./configure --prefix=/usr/local
  make

  sudo make install
elif [ "$(expr substr $(uname -s) 1 10)" == 'MINGW32_NT' ]; then
  :
  # Cygwin
else
  echo "Your platform ($(uname -a)) is not supported."
  exit 1
fi

# tpm
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
