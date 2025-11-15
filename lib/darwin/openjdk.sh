#!/bin/sh

# OpenJDK configuration for macOS
# Requires:
# - Homebrew installed
# - openjdk installed via Homebrew
# Sets JAVA_HOME and adds openjdk to PATH

# Source common functions if available
if [ -f "$DOTFILES_ROOT/lib/darwin/common.sh" ]; then
  source "$DOTFILES_ROOT/lib/darwin/common.sh"
fi

if [ -f "$DOTFILES_ROOT/lib/darwin/brew.sh" ]; then
  source "$DOTFILES_ROOT/lib/darwin/brew.sh"
fi

# Check if brew is available and openjdk is installed
if is_command_installed brew 2>/dev/null; then
	if [ -d "$HOMEBREW_PREFIX/opt/openjdk/bin" ]; then
		# Add openjdk to PATH
		add_to_path "$HOMEBREW_PREFIX/opt/openjdk/bin" 2>/dev/null || export PATH="$HOMEBREW_PREFIX/opt/openjdk/bin:$PATH"
		
		# Set JAVA_HOME
		export OPENJDK_JAVA_HOME="$HOMEBREW_PREFIX/opt/openjdk/libexec/openjdk.jdk/Contents/Home/"
		export JAVA_HOME="${JAVA_HOME:-$OPENJDK_JAVA_HOME}"
	fi
fi
