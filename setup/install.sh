#!/bin/sh

# Installation script for darwin_dotfiles
# Clones the repository and runs initialization

DOTFILES_ROOT=${DOTFILES_ROOT:-"$HOME/.darwin_dotfiles"}

# Check if git is installed
if ! command -v git >/dev/null 2>&1; then
    echo "Error: git is not installed. Please install git first."
    echo "You can install it via Homebrew: brew install git"
    exit 1
fi

# Check if DOTFILES_ROOT already exists
if [ -d "$DOTFILES_ROOT" ]; then
    echo "Warning: $DOTFILES_ROOT already exists."
    echo "Skipping clone. If you want to reinstall, remove the directory first."
else
    # Clone the repository
    echo "Cloning darwin_dotfiles to $DOTFILES_ROOT..."
    if ! git clone git@github.com:jlaboll/darwin_dotfiles.git "$DOTFILES_ROOT"; then
        echo "Error: Failed to clone repository. Trying HTTPS fallback..."
        if ! git clone https://github.com/jlaboll/darwin_dotfiles.git "$DOTFILES_ROOT"; then
            echo "Error: Failed to clone repository via both SSH and HTTPS."
            exit 1
        fi
    fi
fi

# Run initialization
if [ -f "$DOTFILES_ROOT/setup/init.sh" ]; then
    echo "Running initialization..."
    "$DOTFILES_ROOT/setup/init.sh"
else
    echo "Error: Initialization script not found at $DOTFILES_ROOT/setup/init.sh"
    exit 1
fi