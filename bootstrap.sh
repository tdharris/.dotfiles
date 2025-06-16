#!/usr/bin/env bash

DOTFILES_DIR="$HOME/.dotfiles"

function source_deps {
	local -r deps_dir="$1"

	if [[ ! -d "$deps_dir" ]]; then
		return 0
	fi
	
	# Source all shell scripts
	find "$deps_dir" -maxdepth 1 -name "*.sh" -type f 2>/dev/null | while read -r file; do
		# shellcheck disable=SC1090
		source "$file"
	done
	
	# Source all aliases files
	find "$deps_dir" -maxdepth 1 -name "*_aliases" -type f 2>/dev/null | while read -r file; do
		# shellcheck disable=SC1090
		source "$file"
	done
}

# Source public deps
source_deps "$DOTFILES_DIR/bash"
source_deps "$DOTFILES_DIR/bash/commons"

# Source private deps
for git_submodule in personal wrk; do
	sm="$DOTFILES_DIR/$git_submodule/bash"
	source_deps "$sm"
done

source "$DOTFILES_DIR/util/auth_env.sh"
