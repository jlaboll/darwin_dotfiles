#!/bin/sh

# Python 3 configuration for macOS
# Requires:
# - python3 installed
# - pip3 available

# Source common functions if available
if [ -f "$DOTFILES_ROOT/lib/darwin/common.sh" ]; then
  source "$DOTFILES_ROOT/lib/darwin/common.sh"
fi

if is_command_installed pip3 2>/dev/null; then
	if [ -d "$HOME/Library/Python" ]; then
		# Find user pip3 bin path
		PYTHON_3_BIN=$(find "$HOME/Library/Python" -type d -name bin -print -quit 2>/dev/null)
		
		if [ -d "$PYTHON_3_BIN" ]; then
			# Add Python user bin to PATH
			add_to_path "$PYTHON_3_BIN" 2>/dev/null || export PATH="$PATH:$PYTHON_3_BIN"
		fi
	fi

	# Function for pip3 completion (bash only)
	if [ -n "$BASH_VERSION" ]; then
		function _pip_completion() {
		    COMPREPLY=( $( COMP_WORDS="${COMP_WORDS[*]}" \
		                   COMP_CWORD=$COMP_CWORD \
		                   PIP_AUTO_COMPLETE=1 $1 2>/dev/null ) )
		}
		# Set pip3 completion
		complete -o default -F _pip_completion pip3
	fi
fi