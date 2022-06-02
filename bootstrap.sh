#!/usr/bin/env bash

DOTFILES_DIR="$HOME/.dotfiles"

function source_files {
    local -r aliases_dir="$1"
    local -r prefixes=(
        "asdf"
        "aws"
        "bw"
        "context"
        "env"
        "extract"
        "gruntwork"
        "gh"
        "git"
        "iac"
        "file"
        "k9s"
        "kubectl"
        "log"
        "prompts"
        "terraform"
        "terragrunt"
    )

    # shellcheck disable=SC2068
    for prefix in ${prefixes[@]}; do
        local alias_file="${aliases_dir}/${prefix}_aliases"
        if [[ -f "${alias_file}" ]]; then
            # shellcheck disable=SC1090
            source "${alias_file}"
        fi
    done
}

source_files "$DOTFILES_DIR/bash"

# Source any "_aliases" files in the git submodules
for git_submodule in personal wrk; do
    sm="$DOTFILES_DIR/$git_submodule/bash"
    if [[ -d "$sm" ]]; then
        for alias_file in "$sm"/*_aliases; do
            if [[ -f "$alias_file" ]]; then
                source "$alias_file"
            fi
        done
    fi
done

source "$DOTFILES_DIR/util/auth_env.sh"
