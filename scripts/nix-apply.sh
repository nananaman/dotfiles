#!/usr/bin/env bash
set -euo pipefail

#-------------------------------------------------------
# Nix apply script
# Applies the latest Nix / home-manager configuration
# Detects OS and runs the appropriate command
#-------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== Nix Apply ==="
echo "Dotfiles: $DOTFILES_DIR"
echo "User:     $USER"
echo "OS:       $(uname -s)"
echo ""

case "$(uname -s)" in
  Darwin)
    echo "Detected macOS — running darwin-rebuild switch..."
    nix run nix-darwin/master -- switch --flake "$DOTFILES_DIR" --impure
    ;;
  Linux)
    echo "Detected Linux — running home-manager switch..."
    nix run home-manager/master -- switch --flake "$DOTFILES_DIR" --impure
    ;;
  *)
    echo "Unsupported OS: $(uname -s)" >&2
    exit 1
    ;;
esac

echo ""
echo "=== Configuration applied successfully ==="
