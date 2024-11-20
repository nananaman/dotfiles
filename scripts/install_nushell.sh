#!/bin/sh

cargo install --locked nu

touch ~/.config/nushell/local.nu

cat << 'EOF' >> ~/.bashrc

if [[ $- == *i* ]]; then
  # インタラクティブシェルの場合のみnushellを起動
  exec nu
fi
EOF
