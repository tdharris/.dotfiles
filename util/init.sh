#!/usr/bin/env bash

function symlink_tool_versions {
    local -r target="$HOME/.tool-versions"
    local -r source="$HOME/.dotfiles/.tool-versions"
    
    if [[ -f "$target" ]]; then
        echo "Backing up $target to $target.bak"
        mv "$target" "$target.bak"
    fi

    echo "Symlinking $target to $source"
    ln -s "$source" "$target"
}

symlink_tool_versions
