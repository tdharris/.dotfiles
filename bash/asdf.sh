#!/usr/bin/env bash

#################################################################
#
# asdf Aliases
#
#################################################################

function fail {
    echo -e "asdf-upgrade: $*"
    exit 1
}

function asdf-upgrade {
    local update_plugin_repos=true
    local all_plugins=false

    function show_help {
        cat <<EOF

Usage: asdf-upgrade [options] <packages>

Update the asdf repositories and plugins to latest.

    -s --skip-repos: Don't update the plugin repositories.
    -h --help: Show this help message.

EOF
    }

    local plugins=()
    while [[ $# -gt 0 ]]; do
        key="$1"
        case $key in
        -s | --skip-repos) update_plugin_repos=false ;;
        -h | --help)
            show_help
            shift
            ;;
        *)
            plugins+=("$1")
            shift
            ;;
        esac
    done

    if [[ ${#plugins[@]} -eq 0 ]]; then
        echo "Fetching plugins"
        plugins=("$(asdf plugin list)")
        all_plugins=true
    fi

    if "$update_plugin_repos"; then
        echo -e "\nUpdating plugin repositories..."
        if "$all_plugins"; then
            asdf plugin update --all || fail "Failed to upgrade $plugin plugin repo"
        else
            for plugin in "${plugins[@]}"; do
                asdf plugin update "$plugin" || fail "Failed to upgrade $plugin plugin repo"
            done
        fi
    fi

    echo -e "\nUpgrading packages..."
    for plugin in $plugins; do
        local install_out="$(asdf install "$plugin" latest)" || fail "Failed to upgrade $plugin: \n$install_out"
        echo "$install_out"
        if echo "$install_out" | grep "has been installed\|installation was successful" &>/dev/null; then
            echo -e "\nUpdating global $plugin to latest..."
            asdf global "$plugin" latest || fail "Failed to set global $plugin to latest"
        fi
    done

    echo -e "\nDone.\n"
}

function asdf_add_plugins {
    local tool_versions="$1"

    local -r log_ctx="asdf_add_plugins"
    if [[ -z "$tool_versions" ]]; then
        tool_versions="$(file_find_in_parent_folders ".tool-versions")" || {
            log error "$log_ctx: .tool-versions not found"
            return 1
        }
        log info "$log_ctx: using $tool_versions"
    fi

    if ! file_exists "$tool_versions"; then
        log error "$log_ctx: $tool_versions does not exist"
        return 1
    fi

    for plugin in $(grep -v "#" "$tool_versions" | awk '{print $1}'); do
        log info "$log_ctx: adding $plugin"
        asdf plugin add "$plugin"
    done
}
