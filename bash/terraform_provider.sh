#!/usr/bin/env bash

#################################################################
#
# Terraform Provider Development Aliases
#
#################################################################

function tf_provider_build {
    local -r output_dir="${1:-bin/}"

    local -r git_root="$(git rev-parse --show-toplevel)" || return 1
    local -r provider_name="$(basename "$git_root")"

    cd "$git_root" || return 1
    echo -e "Building $provider_name..."
    
    go build -v -o "$output_dir" ./... || {
        echo "Failed to build terraform provider"
        return 1
    }

    echo -e "Successfully built $provider_name"
    cd - &>/dev/null || return 1
}

function tf_provider_install {
    local -r git_root="$(git rev-parse --show-toplevel)" || return 1
    local -r provider_name="$(basename "$git_root")"

    cd "$git_root" || return 1
    echo -e "Installing $provider_name..."

    go install -v ./... || {
        echo "Failed to install terraform provider"
        return 1   
    }

    echo -e "Successfully installed $provider_name"
    cd - &>/dev/null || return 1
}
