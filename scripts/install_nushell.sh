#!/bin/sh

cargo install --locked nu

cat << 'EOF' >> ~/.bashrc

if [[ $- == *i* ]]; then
  # インタラクティブシェルの場合のみnushellを起動
  exec nu
fi
EOF
