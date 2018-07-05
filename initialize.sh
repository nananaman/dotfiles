#!/bin/sh
# xonsh
pip install xonsh

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

# nodejs npm
curl -sL https://deb.nodesource.com/setup_10.x | sudo -E bash -
sudo apt-get install -y nodejs

# instant-markdown-d
sudo npm -g install instant-markdown-d

# xonsh実行
echo ^# run xonsh >> ~/.bashrc
echo alias x='xonsh' >> 
echo x
xonsh

# xonshtrib導入
pip install xonsh-apt-tabcomplete
pip install xontrib-z
