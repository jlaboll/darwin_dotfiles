#!/bin/sh

# Git aliases and helper functions
# Requires:
# - git installed and in PATH

# Git CLI aliases for common operations
# ga: git add -A (stage all changes)
# gb: git branch --list (list branches)
# gc: git commit -am (commit all changes with message)
# gs: git status (show status)
# gp: git push (push to remote)

# Initialize a new git repository with standard setup
# Usage: gi "git@github.com:user/repo.git"
# Creates README.md, .gitignore, initial commit, and sets up remote
alias ga="git add -A"
alias gb="git branch --list"
alias gc="git commit -am"
alias gs="git status"
alias gp="git push"

function gi () {
	git init
	touch README.md 
	touch .gitignore
	git add -A 
	git commit -m "init"
	git branch -M main
	git remote add origin "$1"
	git push -u origin main
}

# Remove a file from git tracking
# Usage: grm "path/to/file"
function grm () {
	git rm "$1"
}

# Update git repository (pull and fetch with submodule support)
# Usage: gu
# Pulls latest changes and fetches with submodule recursion, prunes deleted branches
function gu () {
	git pull --recurse-submodules
	git fetch --prune --recurse-submodules
}
