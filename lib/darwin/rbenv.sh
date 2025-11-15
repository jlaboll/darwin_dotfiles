#!/bin/sh

# Requires:
# - rbenv
# - DOTFILES_ROOT must be set (sourced from dotfiles.sh)

# Source common functions if available
if [ -f "$DOTFILES_ROOT/lib/darwin/common.sh" ]; then
  source "$DOTFILES_ROOT/lib/darwin/common.sh"
fi

if [ -d "$HOME/.rbenv/bin" ]; then
	# Add rbenv to PATH
	add_to_path "$HOME/.rbenv/bin" 2>/dev/null || export PATH="$PATH:$HOME/.rbenv/bin"
	
	# RbEnv init - detect shell and use appropriate init command
	# Source is_shell_bash function if available
	if [ -f "$DOTFILES_ROOT/lib/core/dotfiles.sh" ]; then
		source "$DOTFILES_ROOT/lib/core/dotfiles.sh"
	fi
	
	if is_shell_bash 2>/dev/null; then
		eval "$(rbenv init - bash)"
	else
		eval "$(rbenv init - zsh)"
	fi
fi
