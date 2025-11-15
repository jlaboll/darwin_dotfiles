#!/bin/sh

# Dotfiles update function
# Requires:
# - git installed
# - DOTFILES_ROOT must be set

# Update dotfiles from git repository and reinitialize
# Pulls latest changes from remote and runs dotfiles-init to apply updates
# Usage: up
function up () {
  git -C "$DOTFILES_ROOT" pull
  dotfiles_init
  echo "Dotfiles updated."
}
