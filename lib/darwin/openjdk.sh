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

# Check if brew is available and openjdk is installed
if is-command-installed brew 2>/dev/null; then
	local brew_prefix="${HOMEBREW_PREFIX:-$(get-homebrew-prefix 2>/dev/null)}"
	if [ -n "$brew_prefix" ] && [ -d "$brew_prefix/opt/openjdk/bin" ]; then
		# Add openjdk to PATH
		add-to-path "$brew_prefix/opt/openjdk/bin" 2>/dev/null || export PATH="$brew_prefix/opt/openjdk/bin:$PATH"
		
		# Set JAVA_HOME
		export OPENJDK_JAVA_HOME="$brew_prefix/opt/openjdk/libexec/openjdk.jdk/Contents/Home/"
		export JAVA_HOME="${JAVA_HOME:-$OPENJDK_JAVA_HOME}"
	fi
fi
