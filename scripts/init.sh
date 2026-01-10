#!/bin/sh

#-------------------------------------------------------
# Dotfiles initialization script
# Main entry point for setting up the development environment
#-------------------------------------------------------

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/utils.sh"

# Print welcome message
cat << EOF

#-------------------------------------------------------
# Dotfiles Installation
# Starting setup process...
#-------------------------------------------------------

EOF

# Run each installation script in sequence
run_script() {
  script_name="$1"
  log_info "Running $script_name..."
  
  if [ -f "$SCRIPT_DIR/$script_name" ]; then
    bash "$SCRIPT_DIR/$script_name"
    
    if [ $? -eq 0 ]; then
      log_success "$script_name completed successfully"
    else
      log_error "$script_name failed with exit code $?"
      exit 1
    fi
  else
    log_error "Script $script_name not found"
    exit 1
  fi
  
  echo # Add newline for better readability
}

# Install tools first
run_script "install_tools.sh"

# Install Neovim
run_script "install_nvim.sh"

# Install Zsh
run_script "install_zsh.sh"

# Install fonts
run_script "install_fonts.sh"

# Install macOS applications
run_script "install_apps.sh"

# Print completion message
cat << EOF

#-------------------------------------------------------
#                SETUP FINISHED!
#       Your dotfiles have been installed.
#-------------------------------------------------------

What's next:
1. Apply changes: chezmoi apply
2. Restart your terminal

EOF