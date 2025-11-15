#!/bin/sh

# Core dotfiles functions
# Provides shell detection and initialization functions

# Returns TRUE (exit code 0) if the default shell is bash, FALSE otherwise
# Uses macOS Directory Services (dscl) for reliable detection, falls back to $SHELL
# Usage: if is_shell_bash; then ...
function is_shell_bash() {
    local default_shell=""
    
    # Try dscl first (most reliable on macOS)
    if command -v dscl >/dev/null 2>&1; then
        default_shell=$(dscl . -read /Users/$USER UserShell 2>/dev/null | awk '{print $2}')
    fi
    
    # Fallback to $SHELL environment variable if dscl didn't work
    if [[ -z "$default_shell" ]]; then
        default_shell="$SHELL"
    fi
    
    # Return TRUE (0) if bash, FALSE (1) otherwise
    if [[ "$default_shell" == *"bash"* ]]; then
        return 0
    else
        return 1
    fi
}

# Initializes the dotfiles in user home directory
# Copies all files from links/ directory to ~/.filename
# Then sources the appropriate profile file based on default shell
# Requires: DOTFILES_ROOT must be set
# Usage: dotfiles-init
function dotfiles-init() {
  txt_path_to_dotfiles=$(cd $DOTFILES_ROOT && pwd)
  txt_rc_files="$txt_path_to_dotfiles/links/*"

  # Helper function to copy a file from links/ to home directory
  # Removes existing file if present, then copies new one
  function link_file () {
    txt_source="$1"
    txt_file_name=$(basename "$txt_source")
    txt_dest="$HOME/.$txt_file_name"

    if [[ -f "$txt_dest" ]]; then
      rm "$txt_dest"
    fi
      
    cp "$txt_source" "$txt_dest"
  }

  # Copy all files from links directory
  for txt_rc_file in $txt_rc_files; do
    link_file "$txt_rc_file"  
  done

  # Source the appropriate profile based on default shell
  if is_shell_bash; then 
    source ~/.bash_profile
  else
    source ~/.zsh_profile
  fi

  echo "Shell setup complete."
}
