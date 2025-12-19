#!/bin/sh

# Environment variable exports for shell configuration
# Requires:
# - nano (for VISUAL)
# - less (for PAGER)

# Exports for visual editor, pager, colors, and less
# If DOTFILE_EXPORTS is set to "0", forces defaults even if variables are already set
# Otherwise, sets defaults only if variables are unset
# This allows users to override defaults when DOTFILE_EXPORTS != "0"
if [ ${DOTFILE_EXPORTS:-0} ]; then
  export VISUAL="${VISUAL:+nano}"

  export CLICOLOR="${CLICOLOR:+1}"
  export LSCOLORS="${LSCOLORS:+GxFxCxDxBxegedabagaced}"

  export PAGER="${PAGER:+less}"
  export LESS="${LESS:+-iMFXSx4R}"
else 
  export VISUAL="${VISUAL:-nano}"

  export CLICOLOR="${CLICOLOR:-1}"
  export LSCOLORS="${LSCOLORS:-GxFxCxDxBxegedabagaced}"

  export PAGER="${PAGER:-less}"
  export LESS="${LESS:--iMFXSx4R}"
fi 
