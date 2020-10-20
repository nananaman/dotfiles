#!/bin/sh

# ptk
pip install prompt_toolkit

# xonsh
pip install xonsh

# xonsh実行
echo \# run xonsh >> ~/.bashrc
echo alias x='xonsh' >> ~/.bashrc
echo x >> ~/.bashrc
xonsh

# xonshtrib導入
xpip install xontrib-z
