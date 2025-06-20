#!/usr/bin/env bash

#################################################################
#
# glab Aliases
# - Requires "charmbracelet/gum" for interactive input
#
#################################################################

function glab_issue_create {
    local title="$(gum input --placeholder title)"
    local description="$(gum write --placeholder description)"
    local assignee="$(gum input --placeholder assignee)"
    local label="$(gum input --header label --value enhancement)"

    gum confirm "Create issue?" && glab issue create \
        --title "$title" \
        --description "$description" \
        --assignee "$assignee" \
        --label "$label"
}

