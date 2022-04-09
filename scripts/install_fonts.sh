#!/bin/sh

# install HackGenNerdConsole
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  sudo apt-get install unzip
  mkdir -p ~/.local/share/fonts
  cd /tmp && wget https://github.com/yuru7/HackGen/releases/download/v2.5.2/HackGenNerd_v2.5.2.zip \
	  && unzip HackGenNerd_v2.5.2.zip \
	  && cp HackGenNerd_v2.5.2/HackGenNerdConsole-Bold.ttf ~/.local/share/fonts
elif [[ "$OSTYPE" == "darwin"* ]]; then
  cd ~/Library/Fonts && curl -fLo "HackGenNerdConsole-Bold.ttf" https://github.com/yuru7/HackGen/raw/master/build/HackGenNerdConsole-Bold.ttf
  cd /tmp && wget https://github.com/yuru7/HackGen/releases/download/v2.5.2/HackGenNerd_v2.5.2.zip \
	  && unzip HackGenNerd_v2.5.2.zip \
	  && cp HackGenNerd_v2.5.2/HackGenNerdConsole-Bold.ttf ~/Library/Fonts
else
  # Unknown.
  continue
fi

