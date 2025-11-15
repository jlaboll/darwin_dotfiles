#!/bin/sh

# Common utility functions for Darwin (macOS) dotfiles
# This file provides reusable functions for checking installations and managing paths

# Check if a command is installed and available in PATH
# Usage: if is_command_installed git; then ...
# Returns: 0 if installed, 1 if not
function is_command_installed() {
  if command -v "$1" >/dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

# Check if a Homebrew package is installed
# Usage: if is_brew_package_installed node@18; then ...
# Returns: 0 if installed, 1 if not
# Requires: Homebrew must be installed and in PATH
function is_brew_package_installed() {
  if is_command_installed brew && brew list "$1" >/dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

# Get the Homebrew prefix path (handles both Apple Silicon and Intel)
# Usage: brew_prefix=$(get_homebrew_prefix)
# Returns: /opt/homebrew (Apple Silicon) or /usr/local (Intel) or empty string
function get_homebrew_prefix() {
  if [ -f "/opt/homebrew/bin/brew" ]; then
    echo "/opt/homebrew"
  elif [ -f "/usr/local/bin/brew" ]; then
    echo "/usr/local"
  else
    echo ""
  fi
}

# Add a directory to PATH if it exists and is not already in PATH
# Usage: add_to_path "/some/directory"
# This prevents duplicate PATH entries
function add_to_path() {
  local dir="$1"
  if [ -d "$dir" ] && [[ ":$PATH:" != *":$dir:"* ]]; then
    export PATH="$PATH:$dir"
  fi
}

# Installation function for development tools
# Installs and updates common development tools via Homebrew
# Installs: Homebrew (if needed), node@18, openjdk, jq, flutter/fvm
# Usage: install_devtools [-v]
# Options:
#   -v: Verbose mode - shows installation progress messages
function install_devtools() {
  local verbose_mode=false

  # Parse command line arguments
  for arg in "$@"; do
      case "$arg" in
          -v)
              verbose_mode=true
              ;;
      esac
  done

  # Install/update Homebrew
  if ! is_command_installed brew; then
    [ "$verbose_mode" == true ] && echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add Homebrew to PATH (handles both Apple Silicon and Intel)
    local brew_prefix=$(get_homebrew_prefix)
    if [ -n "$brew_prefix" ] && [ -f "$brew_prefix/bin/brew" ]; then
      eval "$($brew_prefix/bin/brew shellenv)"
    fi
  else
    [ "$verbose_mode" == true ] && echo "Homebrew already installed, updating..."
    brew update -q
  fi
  
  # Set HOMEBREW_PREFIX if not already set
  if [ -z "${HOMEBREW_PREFIX:-}" ]; then
    local brew_prefix=$(get_homebrew_prefix)
    if [ -n "$brew_prefix" ]; then
      export HOMEBREW_PREFIX="$brew_prefix"
    fi
  fi
  
  # Install openjdk 
  if ! is_brew_package_installed openjdk; then
    [ "$verbose_mode" == true ] && echo "Installing OpenJDK..."
    brew install openjdk -q
  else
    [ "$verbose_mode" == true ] && echo "OpenJDK already installed, updating..."
    brew upgrade openjdk -q
  fi
  
  # Install jq
  if ! is_brew_package_installed jq; then
    [ "$verbose_mode" == true ] && echo "Installing jq..."
    brew install jq -q
  else
    [ "$verbose_mode" == true ] && echo "jq already installed, updating..."
  fi

  # Install flutter
  if is_command_installed flutter; then
    [ "$verbose_mode" == true ] && echo "Flutter already installed, updating..."
    if is_brew_package_installed flutter; then
      brew upgrade flutter -q
    else
      flutter upgrade -q
    fi
  else
    # Install fvm 
    if ! is_command_installed fvm; then
      [ "$verbose_mode" == true ] && echo "Installing FVM..."
      brew install fvm -q
    else
      [ "$verbose_mode" == true ] && echo "FVM already installed, updating..."
      brew upgrade fvm -q
    fi
  fi
  
  echo ""
  echo "Installation complete."
  echo "Installed:"
  echo "  ✓ Homebrew"
  echo "  ✓ OpenJDK"
  echo "  ✓ Flutter"
  is_command_installed fvm && echo "  ✓ FVM"
}