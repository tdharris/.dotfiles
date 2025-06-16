#!/usr/bin/env bash

#################################################################
#
# gh Aliases
#
#################################################################

# shellcheck disable=SC2120
function gh_api_limits {
    gh api rate_limit | jq '.rate'
}

function gh_pr_checkout {
    local -r search="$1"
    local -r label="$2"

    local -r pr_selection="$(gh pr list --search "$search" --state "open" --label "$label" | fzf --prompt " Please select the PR > ")"
    local -r pr="$(echo "$pr_selection" | awk '{print $1}')"

    if [[ -z "$pr" ]]; then
        log warn "No PR selected, exiting."
        return 1
    fi

    gh pr checkout "$pr"
}

function gh_pr_comment {
    local -r comment="$1"

    gh pr comment --body "$comment"
}
