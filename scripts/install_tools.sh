#!/bin/sh

#-------------------------------------------------------
# Tools installer script
# Installs various CLI tools and utilities
#-------------------------------------------------------

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/utils.sh"

log_info "Installing development tools..."

#-------------------------------------------------------
# Basic package manager and utilities
#-------------------------------------------------------

# Ensure package manager is installed
ensure_package_manager

# Install essential tools
if is_macos; then
  log_info "Installing essential macOS tools..."
  brew install wget
fi

#-------------------------------------------------------
# FZF - Fuzzy Finder
#-------------------------------------------------------

if ! command_exists fzf; then
  log_info "Installing fzf (fuzzy finder)..."
  
  # Clone fzf repository
  git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
  
  # Run the install script (yes to all prompts)
  yes | ~/.fzf/install
  
  log_success "fzf installed"
else
  log_info "fzf is already installed"
fi

#-------------------------------------------------------
# Ripgrep - Fast grep alternative
#-------------------------------------------------------

if ! command_exists rg; then
  log_info "Installing ripgrep..."
  
  if is_macos; then
    brew install ripgrep
  elif is_linux; then
    sudo apt-get install -y ripgrep
  fi
  
  log_success "ripgrep installed"
else
  log_info "ripgrep is already installed"
fi

#-------------------------------------------------------
# Go language and tools
#-------------------------------------------------------

if ! command_exists go; then
  log_info "Installing Go programming language..."
  
  if is_macos; then
    brew install go
  elif is_linux; then
    # Install wget if not available
    if ! command_exists wget; then
      sudo apt-get install -y wget
    fi
    
    GO_VERSION="1.21.0"
    cd /tmp
    download_file "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" "go${GO_VERSION}.linux-amd64.tar.gz"
    sudo tar -C /usr/local/ -xzf "go${GO_VERSION}.linux-amd64.tar.gz"
    
    # Add Go to PATH (temporarily for this script)
    export PATH=$PATH:/usr/local/go/bin
    
    # Add Go to path permanently if not already added
    add_line_to_file 'export PATH=$PATH:/usr/local/go/bin' "$HOME/.profile"
    
    cd - > /dev/null
  fi
  
  log_success "Go installed"
else
  log_info "Go is already installed"
fi

# Install Go tools
for go_pkg in "github.com/x-motemen/ghq@latest" "github.com/mattn/memo@latest" "github.com/jesseduffield/lazygit@latest"; do
  pkg_name=$(echo "$go_pkg" | cut -d'/' -f3 | cut -d'@' -f1)

  if ! command_exists "$pkg_name"; then
    log_info "Installing $pkg_name..."
    go install "$go_pkg"
    log_success "$pkg_name installed"
  else
    log_info "$pkg_name is already installed"
  fi
done

# Install git-wt (worktree manager)
if ! command_exists git-wt; then
  log_info "Installing git-wt..."
  go install github.com/k1LoW/git-wt@latest
  log_success "git-wt installed"
else
  log_info "git-wt is already installed"
fi

#-------------------------------------------------------
# Deno - JavaScript/TypeScript runtime
#-------------------------------------------------------

if ! command_exists deno; then
  log_info "Installing Deno..."
  run_installer "https://deno.land/x/install/install.sh"
  
  # Add Deno to PATH for the rest of this script
  export PATH="$HOME/.deno/bin:$PATH"
  
  log_success "Deno installed"
else
  log_info "Deno is already installed"
fi

# Install dex with Deno
if ! command_exists dex; then
  log_info "Installing dex..."
  deno install --allow-read --allow-write --allow-run --reload --force --name dex https://pax.deno.dev/kawarimidoll/deno-dex/main.ts
  log_success "dex installed"
else
  log_info "dex is already installed"
fi

#-------------------------------------------------------
# Rust language and tools
#-------------------------------------------------------

if ! command_exists cargo; then
  log_info "Installing Rust and cargo..."
  download_file "https://sh.rustup.rs" "/tmp/install_rust.sh"
  sh /tmp/install_rust.sh -y
  # Source cargo environment
  . "$HOME/.cargo/env"
  
  log_success "Rust installed"
else
  log_info "Rust is already installed"
fi

# Install compiler tools for Linux
if is_linux; then
  if ! command_exists gcc; then
    log_info "Installing GCC..."
    sudo apt-get install -y gcc
  fi
fi

# Install Rust tools
for cargo_pkg in "lsd" "git-delta" "atuin"; do
  if ! command_exists "$cargo_pkg"; then
    log_info "Installing $cargo_pkg..."
    install_cargo_package "$cargo_pkg"
    log_success "$cargo_pkg installed"
  else
    log_info "$cargo_pkg is already installed"
  fi
done

#-------------------------------------------------------
# Bat - Better cat alternative
#-------------------------------------------------------

if ! command_exists bat; then
  log_info "Installing bat..."
  
  if is_macos; then
    brew install bat
  elif is_linux; then
    sudo apt-get install -y bat
    
    # On some Linux systems, bat is installed as batcat
    if ! command_exists bat && command_exists batcat; then
      log_info "Creating symlink from batcat to bat..."
      sudo ln -s /usr/bin/batcat /usr/local/bin/bat
    fi
  fi
  
  log_success "bat installed"
else
  log_info "bat is already installed"
fi

#-------------------------------------------------------
# Silicon - Code screenshot tool
#-------------------------------------------------------

if ! command_exists silicon; then
  log_info "Installing silicon..."
  
  if is_macos; then
    install_cargo_package "silicon"
  elif is_linux; then
    brew install silicon
  fi
  
  log_success "silicon installed"
else
  log_info "silicon is already installed"
fi

#-------------------------------------------------------
# Starship - Cross-shell prompt
#-------------------------------------------------------

if ! command_exists starship; then
  log_info "Installing starship..."
  run_installer "https://starship.rs/install.sh"
  log_success "starship installed"
else
  log_info "starship is already installed"
fi

log_success "All tools installed successfully!"