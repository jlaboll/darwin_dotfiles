#!/bin/sh

# Android development environment configuration for macOS
# Sets ANDROID_HOME and adds Android SDK tools to PATH

# Source common functions if available
if [ -f "$DOTFILES_ROOT/lib/darwin/common.sh" ]; then
  source "$DOTFILES_ROOT/lib/darwin/common.sh"
fi

if [ -d "$HOME/Library/Android/sdk" ]; then
  export ANDROID_HOME="$HOME/Library/Android/sdk"
  # Add Android SDK tools to PATH
  add_to_path "$ANDROID_HOME/tools" 2>/dev/null || export PATH="$PATH:$ANDROID_HOME/tools"
  add_to_path "$ANDROID_HOME/tools/bin" 2>/dev/null || export PATH="$PATH:$ANDROID_HOME/tools/bin"
  add_to_path "$ANDROID_HOME/platform-tools" 2>/dev/null || export PATH="$PATH:$ANDROID_HOME/platform-tools"
fi

if [ -d "/Applications/Android Studio.app/Contents/jbr/Contents/Home/" ]; then
  export ANDROID_STUDIO_JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home/"
  export JAVA_HOME="${JAVA_HOME:-$ANDROID_STUDIO_JAVA_HOME}"
fi