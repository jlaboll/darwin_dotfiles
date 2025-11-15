#!/bin/sh

# Custom PS1 (prompt) configuration for bash
# Requires:
# - git installed
# Flags:
# - DOTFILES_PS1: If set to zero, enables custom prompt

# Custom prompt shows:
# - Current time
# - Username and hostname (or "local" for non-SSH sessions)
# - Current working directory
# - Git branch and dirty status (* if uncommitted changes)
# - Different colors for SSH vs local sessions

if [[ -n "${DOTFILES_PS1:-}" ]] && [ ${DOTFILES_PS1:-0} ]; then
	# Check if current session is SSH
	# Returns 0 if SSH, 1 if local
	is_ssh(){
		if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then
			echo 0
		else 
			echo 1
		fi
	}

	# Parse git dirty status - returns "*" if there are uncommitted changes
	function parse_git_dirty {
	  [[ $(git status 2> /dev/null | tail -n1) != "nothing to commit (working directory clean)" ]] && echo "*"
	}
	 
	# Parse current git branch name with dirty indicator
	# Returns branch name with "*" suffix if dirty
	function parse_git_branch {
	  ref=$(git symbolic-ref HEAD 2> /dev/null) || return
	  echo " ("${ref#refs/heads/}$(parse_git_dirty)")"
	}

	check_ssh=$(is_ssh)

	# Configure prompt and editor based on session type
	if [ $check_ssh -eq 0 ]; then
		# SSH session: use nano, show username@hostname
		export EDITOR=nano
		export PS1="\[\e[96m\]\t \[\e[38;5;202m\]\u\[\e[0m\]@\[\e[38;5;214m\]\h \[\e[92m\][\w]\[\033[38;5;9m\]\$(parse_git_branch)\[\e[0m\] \$ "
	else 
		# Local session: prefer Sublime Text if available, otherwise nano
		# Show "local" instead of username@hostname
		if [ -f "/Applications/Sublime Text.app/Contents/SharedSupport/bin/subl" ]; then
			export EDITOR="/Applications/Sublime Text.app/Contents/SharedSupport/bin/subl -w"
		else
			export EDITOR=nano
		fi

		export PS1="\[\e[96m\]\t \[\e[95m\]local \[\e[92m\][\w]\[\033[38;5;9m\]\$(parse_git_branch)\[\e[0m\] \$ "
	fi
fi
