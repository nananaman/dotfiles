#!/bin/sh

#-------------------------------------------------------
# Fonts installer script
# Installs programming fonts with nerd font patches
#-------------------------------------------------------

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/utils.sh"

log_info "Installing fonts..."

# HackGen Nerd Font
HACKGEN_VERSION="v2.5.2"
HACKGEN_FILENAME="HackGenNerd_${HACKGEN_VERSION#v}.zip"
HACKGEN_URL="https://github.com/yuru7/HackGen/releases/download/${HACKGEN_VERSION}/${HACKGEN_FILENAME}"
HACKGEN_FONT="HackGenNerdConsole-Bold.ttf"

log_info "Installing HackGen Nerd Console Font ${HACKGEN_VERSION}..."

# Set fonts directory based on OS
if is_linux; then
  # Ensure unzip is installed
  if ! command_exists unzip; then
    log_info "Installing unzip..."
    sudo apt-get install -y unzip
  fi
  
  FONTS_DIR="$HOME/.local/share/fonts"
elif is_macos; then
  FONTS_DIR="$HOME/Library/Fonts"
else
  log_error "Unsupported OS: $(uname -s)"
  exit 1
fi

# Create fonts directory if it doesn't exist
ensure_dir "$FONTS_DIR"

# Download and extract fonts
log_info "Downloading HackGen fonts..."
download_file "$HACKGEN_URL" "/tmp/${HACKGEN_FILENAME}"

log_info "Extracting fonts..."
cd /tmp && unzip -o "${HACKGEN_FILENAME}"

log_info "Installing fonts to $FONTS_DIR..."
cp "/tmp/HackGenNerd_${HACKGEN_VERSION#v}/${HACKGEN_FONT}" "$FONTS_DIR/"

# Clean up
rm -rf "/tmp/HackGenNerd_${HACKGEN_VERSION#v}" "/tmp/${HACKGEN_FILENAME}"

# Update font cache on Linux
if is_linux; then
  log_info "Updating font cache..."
  fc-cache -f -v >/dev/null
fi

log_success "HackGen Nerd Console Font installed successfully"