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

function gitsync {
    local current_dir=$(pwd)
    local target_dir=${1:-"."}

    cd "$target_dir" || return 1

    for dir in */; do
        # Use -d and check for .git to ensure it's a repo
        if [[ -d "$dir/.git" ]]; then
            (
                cd "$dir" || exit
                
                local default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
                if [[ -z "$default_branch" ]]; then
                    if git show-ref --verify --quiet refs/heads/main; then
                        default_branch="main"
                    else
                        default_branch="master"
                    fi
                fi

                local current_branch=$(git rev-parse --abbrev-ref HEAD)

                # Using [[ ]] is the modern standard for Zsh and Bash
                if [[ "$current_branch" == "$default_branch" ]]; then
                    echo -e "\033[0;32mUpdating [${dir%/}]...\033[0m"
                    git pull
                else
                    echo -e "\033[0;33mWARNING: [${dir%/}] is on '$current_branch', not '$default_branch'. Skipping.\033[0m"
                fi
            )
        fi
    done

    cd "$current_dir" || return
}

