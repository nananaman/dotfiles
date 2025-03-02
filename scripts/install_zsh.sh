#!/bin/sh

#-------------------------------------------------------
# Zsh installer script
# Installs Zsh and shell plugin manager (sheldon)
#-------------------------------------------------------

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/utils.sh"

log_info "Installing Zsh and related tools..."

# Install zsh
if ! command_exists zsh; then
  log_info "Installing Zsh..."
  
  if is_macos; then
    ensure_package_manager
    brew install zsh
  elif is_linux; then
    sudo apt-get install -y zsh
  else
    log_error "Unsupported OS for Zsh installation"
    exit 1
  fi
  
  log_success "Zsh installed successfully"
else
  log_info "Zsh is already installed"
fi

# Install sheldon (shell plugin manager)
if ! command_exists sheldon; then
  log_info "Installing sheldon shell plugin manager..."
  
  if ! command_exists cargo; then
    log_info "Installing Rust (required for sheldon)..."
    run_installer "https://sh.rustup.rs"
    # Source cargo environment
    . "$HOME/.cargo/env"
  fi
  
  install_cargo_package "sheldon"
  log_success "Sheldon installed successfully"
else
  log_info "Sheldon is already installed"
fi

log_success "Zsh setup completed"