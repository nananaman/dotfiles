#!/bin/sh

# Install zsh

if ! command -v zsh &> /dev/null; then
  echo "Installing zsh..."
  # macOS
  if command -v brew &> /dev/null; then
    brew install zsh
  # Ubuntu
  elif command -v apt-get &> /dev/null; then
    sudo apt-get install zsh
  fi
fi

echo "Installing sheldon"

cargo install sheldon
