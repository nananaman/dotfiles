#!/bin/sh

#-------------------------------------------------------
# WezTerm installer script
# Installs WezTerm terminal emulator
#-------------------------------------------------------

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/utils.sh"

log_info "Installing WezTerm terminal emulator..."

if is_linux; then
  WEZTERM_VERSION="20220408-101518-b908e2dd"
  WEZTERM_FILENAME="WezTerm-${WEZTERM_VERSION}-Ubuntu18.04.AppImage"
  WEZTERM_URL="https://github.com/wez/wezterm/releases/download/${WEZTERM_VERSION}/${WEZTERM_FILENAME}"
  
  log_info "Downloading WezTerm AppImage..."
  download_file "$WEZTERM_URL" "/tmp/${WEZTERM_FILENAME}"
  chmod +x "/tmp/${WEZTERM_FILENAME}"
  
  ensure_dir "$HOME/bin"
  ensure_dir "/usr/local/bin"
  
  sudo mv "/tmp/${WEZTERM_FILENAME}" "/usr/local/bin/wezterm"
  
  log_success "WezTerm installed to /usr/local/bin/wezterm"
elif is_macos; then
  # Ensure brew is installed
  ensure_package_manager
  
  log_info "Installing WezTerm via Homebrew..."
  brew tap wez/wezterm
  brew install --cask wez/wezterm/wezterm
  
  log_success "WezTerm installed via Homebrew"
else
  log_error "Unsupported OS: $(uname -s)"
  exit 1
fi