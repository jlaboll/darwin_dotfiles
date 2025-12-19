#!/bin/sh

# Flutter development environment configuration for macOS
# Requires:
# - Homebrew installed
# - flutter (from brew) OR fvm (from brew)
# - macOS (for quarantine bypass functionality)
# - Using dart's default .pub-cache directory

# Helper function to update Flutter and clear macOS quarantine flags
# Installs/updates dev tools, then updates Flutter via FVM or direct install
# Also removes quarantine attributes that macOS applies to downloaded executables
# Usage: bump_flutter
function bump_flutter() {
  install_devtools

  if is_command_installed fvm; then
    fvm global --unlink
    fvm remove stable
    fvm install stable -s
    fvm global stable
  fi

  if is_command_installed flutter; then
    unquarantine_flutter "$(flutter --version --machine | jq -r '.flutterRoot')"
  fi
}

# Flutter Quarantine Bypass function
# Removes macOS quarantine attributes from Flutter executables
# macOS applies quarantine flags to downloaded files, which can prevent execution
# This function removes those flags for all Flutter-related executables
# Usage: unquarantine_flutter "/path/to/flutter/root"
# Parameters:
#   $1: Path to Flutter root directory
function unquarantine_flutter() {
  local flutter_root="$1"
  for executable in dart dartaotruntime impellerrc gen_snapshot flutter_tester idevicesyslog iproxy "*.dylib"
  do 
    for filepath in $(find "$flutter_root" -type f -name "$executable")
    do 
      xattr -dr com.apple.quarantine $filepath
    done
  done
}

# Source common functions if available
if [ -f "$DOTFILES_ROOT/lib/darwin/common.sh" ]; then
  source "$DOTFILES_ROOT/lib/darwin/common.sh"
fi

# PATH for pub cache bash completion, if exists
if [ -d "$HOME/.pub-cache/bin" ]; then
  add_to_path "$HOME/.pub-cache/bin" 2>/dev/null || export PATH="$PATH:$HOME/.pub-cache/bin"
fi

# FVM configuration
if is_command_installed fvm 2>/dev/null && is_command_installed jq 2>/dev/null; then
  # FVM cache path env var override
  export FVM_CACHE_PATH=$(fvm api context | jq -r '.context.fvmDir')
fi

if is_command_installed fvm 2>/dev/null && [ -d "$DOTFILES_ROOT/bin" ]; then
  add_to_path "$DOTFILES_ROOT/bin" 2>/dev/null || export PATH="$PATH:$DOTFILES_ROOT/bin"
fi 

if is_command_installed flutter 2>/dev/null; then
  function flutter_run_web(){
    flutter run -d Chrome "$1" --web-browser-flag=--disable-web-security --web-browser-flag=--user-data-dir=~/chrome-dev-data
  }
fi 

## Generated 2025-11-14 22:38:24.434932Z
###-begin-flutter-completion-###
if type complete &>/dev/null; then
  function __flutter_completion() {
    local si="$IFS"
    IFS=$'\n' COMPREPLY=($(COMP_CWORD="$COMP_CWORD" \
                           COMP_LINE="$COMP_LINE" \
                           COMP_POINT="$COMP_POINT" \
                           flutter completion -- "${COMP_WORDS[@]}" \
                           2>/dev/null)) || return $?
    IFS="$si"
  }
  complete -F __flutter_completion flutter
elif type compdef &>/dev/null; then
  function __flutter_completion() {
    si=$IFS
    compadd -- $(COMP_CWORD=$((CURRENT-1)) \
                 COMP_LINE=$BUFFER \
                 COMP_POINT=0 \
                 flutter completion -- "${words[@]}" \
                 2>/dev/null)
    IFS=$si
  }
  compdef __flutter_completion flutter
elif type compctl &>/dev/null; then
  function __flutter_completion() {
    local cword line point words si
    read -Ac words
    read -cn cword
    let cword-=1
    read -l line
    read -ln point
    si="$IFS"
    IFS=$'\n' reply=($(COMP_CWORD="$cword" \
                       COMP_LINE="$line" \
                       COMP_POINT="$point" \
                       flutter completion -- "${words[@]}" \
                       2>/dev/null)) || return $?
    IFS="$si"
  }
  compctl -K __flutter_completion flutter
fi
###-end-flutter-completion-###