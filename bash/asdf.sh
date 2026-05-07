#!/usr/bin/env bash

#################################################################
#
# asdf Aliases
#
#################################################################

function asdf-upgrade {
    local update_plugin_repos=true
    local all_plugins=false
    local plugins=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -s | --skip-repos)
                update_plugin_repos=false
                shift
                ;;
            -h | --help)
                cat <<EOF

Usage: asdf-upgrade [options] <packages>

Update the asdf repositories and plugins to latest.

    -s --skip-repos: Don't update the plugin repositories.
    -h --help: Show this help message.

EOF
                return 0
                ;;
            *)
                plugins+=("$1")
                shift
                ;;
        esac
    done

    # Fallback to all installed plugins if none were provided
    if [[ ${#plugins[@]} -eq 0 ]]; then
        echo "Fetching all installed plugins..."
        plugins=($(asdf plugin list))
        all_plugins=true
    fi

    # Bail out early if no plugins exist locally
    if [[ ${#plugins[@]} -eq 0 ]]; then
        echo "No plugins found to upgrade."
        return 0
    fi

    if [[ "$update_plugin_repos" == true ]]; then
        echo -e "\nUpdating plugin repositories..."
        if [[ "$all_plugins" == true ]]; then
            # The $plugin variable was undefined in the original script's warning log here
            asdf plugin update --all || log warn "Failed to upgrade all plugin repos"
        else
            for plugin in "${plugins[@]}"; do
                asdf plugin update "$plugin" || log warn "Failed to upgrade $plugin plugin repo"
            done
        fi
    fi

    echo -e "\nUpgrading packages..."
    local install_out=""
    for plugin in "${plugins[@]}"; do
        # Capture stderr as well to ensure errors are caught in install_out
        install_out="$(asdf install "$plugin" latest 2>&1)" || {
            log warn "Failed to upgrade $plugin: \n$install_out"
            continue
        }
        
        echo "$install_out"
        
        # Set to latest only if it actually installed a new version
        if ! echo "$install_out" | grep -qi "is already installed"; then
            echo -e "\nUpdating global $plugin to latest..."
            # Note: standard asdf commands are `asdf global` or `asdf set --home` depending on your version.
            # Kept `set -u` assuming it is a specific alias you use.
            asdf set -u "$plugin" latest || log warn "Failed to set -u $plugin to latest"
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

function asdf_update_tool {
    local plugin="$1"
    local version="${2:-latest}"

    local -r log_ctx="asdf_update_tool"
    if [[ -z "$plugin" ]]; then
        log error "$log_ctx: plugin name is required"
        return 1
    fi

    log info "$log_ctx: updating $plugin to $version"
    local install_out
    if ! install_out="$(asdf install "$plugin" "$version" 2>&1)"; then
        log error "$log_ctx: failed to install $plugin $version: $install_out"
        return 1
    fi
    
    log info "$log_ctx: setting global $plugin to $version"
    if ! asdf set -u "$plugin" "$version"; then
        log error "$log_ctx: failed to set global $plugin to $version"
        return 1
    fi
    log info "$log_ctx: $plugin updated to $version and set globally"
}
