#!/bin/sh

#-------------------------------------------------------
# Neovim installer script
# Installs or updates Neovim
#-------------------------------------------------------

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/utils.sh"

log_info "Installing Neovim..."

if is_linux; then
  log_info "Downloading Neovim AppImage..."
  download_file "https://github.com/neovim/neovim/releases/download/nightly/nvim.appimage" "/tmp/nvim.appimage"
  chmod u+x /tmp/nvim.appimage
  
  ensure_dir "/usr/local/bin"
  sudo mv /tmp/nvim.appimage /usr/local/bin/nvim
  
  log_success "Neovim installed to /usr/local/bin/nvim"
elif is_macos; then
  # Ensure brew is installed
  ensure_package_manager
  
  if brew list neovim &>/dev/null; then
    log_info "Upgrading Neovim..."
    brew upgrade neovim
  else
    log_info "Installing Neovim..."
    brew install --HEAD neovim
  fi
  
  log_success "Neovim installed via Homebrew"
else
  log_error "Unsupported OS: $(uname -s)"
  exit 1
fi