#!/bin/sh

# vim8
sudo apt-get install -y git build-essential ncurses-dev lua5.2 lua5.2-dev luajit python-dev python3-dev
sudo apt build-dep vim
cd /opt/
sudo git clone https://github.com/vim/vim
cd vim/
sudo ./configure --with-features=huge --enable-gui=auto --enable-gtk2-check --with-x --enable-multibyte --enable-luainterp=dynamic --enable-gpm --enable-cscope --enable-fontset --enable-fail-if-missing --prefix=/usr/local --enable-pythoninterp=dynamic --enable-python3interp=dynamic
sudo make
sudo make install

# powerline
sudo apt-get install fonts-powerline

if [ "$(uname)" == 'Darwin' ]; then
  # Mac
  cd ~/Library/Fonts && curl -fLo "HackGenNerdConsole-Bold.ttf" https://github.com/yuru7/HackGen/raw/master/build/HackGenNerdConsole-Bold.ttf
elif [ "$(expr substr $(uname -s) 1 5)" == 'Linux' ]; then
  # nerd fonts
  mkdir -p ~/.local/share/fonts
  cd ~/.local/share/fonts && curl -fLo "HackGenNerdConsole-Bold.ttf" https://github.com/yuru7/HackGen/raw/master/build/HackGenNerdConsole-Bold.ttf

elif [ "$(expr substr $(uname -s) 1 10)" == 'MINGW32_NT' ]; then
  cd /mnt/c/Users/foola/AppData/Local/Microsoft/Windows/Fonts && curl -fLo "HackGenNerdConsole-Bold.ttf" https://github.com/yuru7/HackGen/raw/master/build/HackGenNerdConsole-Bold.ttf
  # Cygwin
else
  echo "Your platform ($(uname -a)) is not supported."
  exit 1
fi
# nodejs npm
curl -sL https://deb.nodesource.com/setup_10.x | sudo -E bash -
sudo apt-get install -y nodejs

# yarn
npm install -g yarn
