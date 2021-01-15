#!/usr/bin/env xonsh
# test.xsh

width = '80%'
height = '80%'
session = $(tmux display-message -p -F "#{session_name}")
if "popup" in session:
  ![tmux detach-client]
else:
  ![tmux popup -d '#{{pane_current_path}}' -xC -yC -w@(width) -h@(height) -K -E -R 'tmux attach -t popup || tmux new -s popup']
