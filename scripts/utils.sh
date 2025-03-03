#!/bin/sh

#-------------------------------------------------------
# Dotfiles Installer Utilities
# Common functions for dotfiles installation scripts
#-------------------------------------------------------

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

#-------------------------------------------------------
# Logging functions
#-------------------------------------------------------

log_info() {
  echo "[INFO] $1"
}

log_warn() {
  echo "[WARN] $1" >&2
}

log_error() {
  echo "[ERROR] $1" >&2
}

log_success() {
  echo "[SUCCESS] $1"
}

#-------------------------------------------------------
# OS Detection
#-------------------------------------------------------

# Returns "darwin" for macOS, "linux" for Linux
get_os() {
  os="unknown"
  case "$(uname -s)" in
    Darwin*)  os="darwin" ;;
    Linux*)   os="linux" ;;
  esac
  echo "$os"
}

is_macos() {
  [ "$(get_os)" = "darwin" ]
}

is_linux() {
  [ "$(get_os)" = "linux" ]
}

#-------------------------------------------------------
# Package Manager Detection/Installation
#-------------------------------------------------------

# Ensure package manager is available
ensure_package_manager() {
  if is_macos; then
    if ! command -v brew >/dev/null 2>&1; then
      log_info "Installing Homebrew..."
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
  elif is_linux; then
    if ! command -v apt-get >/dev/null 2>&1; then
      log_error "This script requires apt-get on Linux."
      exit 1
    fi
    
    log_info "Updating package lists..."
    sudo apt-get update
  fi
}

#-------------------------------------------------------
# Package Installation
#-------------------------------------------------------

# Install a package using the appropriate package manager
install_package() {
  package="$1"
  log_info "Installing $package..."
  
  if is_macos; then
    brew install "$package"
  elif is_linux; then
    sudo apt-get install -y "$package"
  else
    log_error "Unsupported OS for package installation."
    exit 1
  fi
}

# Check if a command/binary exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Install a cargo package
install_cargo_package() {
  package="$1"
  log_info "Installing $package with cargo..."
  
  if ! command_exists cargo; then
    log_error "Cargo is not installed. Please install Rust first."
    exit 1
  fi
  
  cargo install "$package"
}

# Install a Go package
install_go_package() {
  package="$1"
  log_info "Installing $package with go..."
  
  if ! command_exists go; then
    log_error "Go is not installed. Please install Go first."
    exit 1
  fi
  
  go install "$package"
}

#-------------------------------------------------------
# Download and execution
#-------------------------------------------------------

# Download a file from a URL
download_file() {
  url="$1"
  output="$2"
  
  if command_exists curl; then
    curl -fsSL "$url" -o "$output"
  elif command_exists wget; then
    wget -q "$url" -O "$output"
  else
    log_error "Neither curl nor wget found. Cannot download file."
    exit 1
  fi
}

# Run an installer script from a URL
run_installer() {
  url="$1"
  
  if command_exists curl; then
    sh -c "$(curl -fsSL "$url")"
  elif command_exists wget; then
    sh -c "$(wget -qO- "$url")"
  else
    log_error "Neither curl nor wget found. Cannot run installer."
    exit 1
  fi
}

#-------------------------------------------------------
# Environment setup
#-------------------------------------------------------

# Create directory if it doesn't exist
ensure_dir() {
  dir="$1"
  if [ ! -d "$dir" ]; then
    log_info "Creating directory $dir"
    mkdir -p "$dir"
  fi
}

# Add a line to a file if it doesn't exist
add_line_to_file() {
  line="$1"
  file="$2"
  
  if [ ! -f "$file" ]; then
    log_info "Creating $file"
    touch "$file"
  fi
  
  if ! grep -q "$line" "$file"; then
    log_info "Adding line to $file"
    echo "$line" >> "$file"
  fi
}