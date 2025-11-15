#!/bin/sh

# Dotfiles initialization script
# This script is called after installation to set up the dotfiles
# It sources the core dotfiles functions and runs initialization

DOTFILES_ROOT=${DOTFILES_ROOT:-"$HOME/.darwin_dotfiles"}

# Check if DOTFILES_ROOT exists
if [ ! -d "$DOTFILES_ROOT" ]; then
    echo "Error: DOTFILES_ROOT directory not found: $DOTFILES_ROOT"
    exit 1
fi

# Source core functions and run initialization
if [ -f "$DOTFILES_ROOT/lib/core/dotfiles.sh" ]; then
    source "$DOTFILES_ROOT/lib/core/dotfiles.sh"
    dotfiles_init
else
    echo "Error: Core dotfiles script not found"
    exit 1
fi
