#!/bin/sh

# Node.js configuration for macOS
# Requires:
# - Homebrew installed
# - node@18 installed via Homebrew
# Flags:
# - DOTFILES_NODE: If set, adds node@18 to PATH

# Source common functions if available
if [ -f "$DOTFILES_ROOT/lib/darwin/common.sh" ]; then
  source "$DOTFILES_ROOT/lib/darwin/common.sh"
fi

if is-command-installed brew 2>/dev/null && is-command-installed node 2>/dev/null; then
	# Add node@18 to PATH (handles both Apple Silicon and Intel)
	local brew_prefix="${HOMEBREW_PREFIX:-$(get-homebrew-prefix 2>/dev/null)}"
	if [ -n "$brew_prefix" ] && [ -d "$brew_prefix/opt/node@18/bin" ]; then
		add-to-path "$brew_prefix/opt/node@18/bin" 2>/dev/null || export PATH="$PATH:$brew_prefix/opt/node@18/bin"
	fi
fi