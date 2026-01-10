#!/bin/sh

#-------------------------------------------------------
# macOS Apps installer script
# Installs GUI applications for macOS
#-------------------------------------------------------

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/utils.sh"

log_info "Installing macOS applications..."

# Only run on macOS
if ! is_macos; then
  log_warn "This script is for macOS only, skipping..."
  exit 0
fi

# Ensure brew is installed
ensure_package_manager

#-------------------------------------------------------
# Ghostty - Terminal Emulator
#-------------------------------------------------------

if [ -d "/Applications/Ghostty.app" ]; then
  log_info "Ghostty is already installed"
else
  log_info "Installing Ghostty terminal emulator..."
  brew install --cask ghostty
  log_success "Ghostty installed"
fi

#-------------------------------------------------------
# AeroSpace - Tiling Window Manager
#-------------------------------------------------------

if command_exists aerospace; then
  log_info "AeroSpace is already installed"
else
  log_info "Installing AeroSpace window manager..."
  brew install --cask nikitabobko/tap/aerospace
  log_success "AeroSpace installed"
fi

log_success "All macOS applications installed successfully!"
