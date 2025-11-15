#!/bin/sh

# Homebrew setup for macOS
# Handles both Apple Silicon (/opt/homebrew) and Intel (/usr/local) architectures
# This file should be sourced early in the shell initialization

# Source common functions if available
if [ -f "$DOTFILES_ROOT/lib/darwin/common.sh" ]; then
  source "$DOTFILES_ROOT/lib/darwin/common.sh"
fi

# Add Homebrew to PATH (handles both Apple Silicon and Intel)
if [ -f "/opt/homebrew/bin/brew" ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -f "/usr/local/bin/brew" ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# Set HOMEBREW_PREFIX if not already set
if is-command-installed brew 2>/dev/null && [ -z "${HOMEBREW_PREFIX:-}" ]; then
  # Use helper function if available, otherwise fallback to direct check
  if command -v get-homebrew-prefix >/dev/null 2>&1; then
    export HOMEBREW_PREFIX=$(get-homebrew-prefix)
  else
    if [ -f "/opt/homebrew/bin/brew" ]; then
      export HOMEBREW_PREFIX="/opt/homebrew" 
    elif [ -f "/usr/local/bin/brew" ]; then
      export HOMEBREW_PREFIX="/usr/local"
    fi
  fi
fi