#!/bin/sh

ln -s ~/dotfiles/_vimrc ~/.vimrc
ln -s ~/dotfiles/_latexmkrc ~/.latexmkrc

# powerline
sudo apt-get install fonts-powerline

# nodejs npm
sudo apt-get install -y nodejs npm
sudo npm cache clean
sudo npm install n -g
sudo n stable
sudo ln -sf /usr/local/bin/node /usr/bin/node
sudo apt-get purge -y nodejs npm

# instant-markdown-d
npm -g install instant-markdown-d

