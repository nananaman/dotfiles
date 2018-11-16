#!/bin/sh

# xonsh
pip install xonsh

# xonsh実行
echo \# run xonsh >> ~/.bashrc
echo alias x='xonsh' >> ~/.bashrc
echo x >> ~/.bashrc
xonsh

# xonshtrib導入
pip install xonsh-apt-tabcomplete
pip install xontrib-z
