#!/usr/bin/env bash
set -euo pipefail

#-------------------------------------------------------
# Nix installer script
# Installs Nix using the Determinate Systems installer
#-------------------------------------------------------

echo "=== Nix Install ==="

# Check if Nix is already installed
if command -v nix &>/dev/null; then
  echo "Nix is already installed: $(nix --version)"
  echo "Skipping installation."
  exit 0
fi

echo "Installing Nix via Determinate Systems installer..."
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

echo ""
echo "=== Nix installed successfully ==="
echo "Please restart your shell (or run 'exec \$SHELL') then run:"
echo "  bash scripts/nix-apply.sh"
