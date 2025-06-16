#!/usr/bin/env bash

#################################################################
#
# git Aliases
#
#################################################################

# most aliases in ~/.gitconfig

function git_diff_branch {
    local -r main="$(git remote show "$(git remote)" | sed -n '/HEAD branch/s/.*: //p')"
    local -r current="$(git rev-parse --abbrev-ref HEAD)"

    git diff --name-only "$main"..."$current" | xargs dirname | sort | uniq
}

alias git_update_submodules_init='git submodule update --init --recursive'
alias git_update_submodules='git submodule update --recursive --remote'

function git_dir_last_commit_date  {
    local -r base_dir="${1:-.}"

    now=$(date +%s)
    printf "%-10s %-10s\n" "Age(Days)" "Directory"
    echo "-----------------------------"
    for dir in $(find "$base_dir" -maxdepth 1 -type d -printf '%P\n'); do
    if [ -z "$dir" ]; then continue; fi  # Skip the current directory
    last_commit=$(git log -1 --format="%ai" -- $dir)
    last_commit_unix=$(date -d "$last_commit" +%s)
    days_ago=$(( (now - last_commit_unix) / 86400 ))
    printf "%-10s %-10s\n" "$days_ago" "$dir"
    done | sort -rn
}
