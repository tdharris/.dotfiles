#!/usr/bin/env bash

DOTFILES_DIR="$HOME/.dotfiles"

function source_aliases {
	local -r aliases_dir="$1"

	for alias_file in "$aliases_dir"/*_aliases; do
		if [[ -f "$alias_file" ]]; then
			# shellcheck disable=SC1090
			source "$alias_file"
		fi
	done
}

# Source public aliases
source_aliases "$DOTFILES_DIR/bash"

# Source private aliases
for git_submodule in personal wrk; do
	sm="$DOTFILES_DIR/$git_submodule/bash"
	if [[ -d "$sm" ]]; then
		source_aliases "$sm"
	fi
done

source "$DOTFILES_DIR/util/auth_env.sh"
