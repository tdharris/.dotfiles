#!/usr/bin/env bash

#################################################################
#
# glab Aliases
# - Requires "charmbracelet/gum" for interactive input
#
#################################################################

function glab_issue_create {
    local title description assignee label
    title="$(gum input --placeholder title)"
    description="$(gum write --placeholder description)"
    assignee="$(gum input --placeholder assignee)"
    label="$(gum input --header label --value enhancement)"

    gum confirm "Create issue?" && glab issue create \
        --title "$title" \
        --description "$description" \
        --assignee "$assignee" \
        --label "$label"
}

# Retrieve all logs for a particular pipeline to view/search
# Allows picking from recent pipelines via fzf if no pipeline ID is provided
function glab_pipeline_logs {
    if ! command -v glab &>/dev/null; then
        log error "The command 'glab' is required but not installed or not in PATH."
        return 1
    fi
    if ! command -v jq &>/dev/null; then
        log error "The command 'jq' is required but not installed or not in PATH."
        return 1
    fi

    local pipeline_id=""

    if [[ -n "$1" && "$1" =~ ^#?[0-9]+$ ]]; then
        pipeline_id="${1#\#}"
        shift
    else
        if ! command -v fzf &>/dev/null; then
            log error "The command 'fzf' is required for interactive selection but not installed or not in PATH."
            return 1
        fi

        log info "Fetching recent pipelines..."
        local -r pipeline_selection="$(glab ci list --per-page 30 "$@" | fzf --ansi --prompt " Select a pipeline > " --header "Select a pipeline to view logs (ESC to cancel)")"

        if [[ -z "$pipeline_selection" ]]; then
            log warn "No pipeline selected, exiting."
            return 1
        fi

        if [[ "$pipeline_selection" =~ \#([0-9]+) ]]; then
            pipeline_id="${BASH_REMATCH[1]:-${match[1]}}"
        elif [[ "$pipeline_selection" =~ ([0-9]{4,}) ]]; then
            pipeline_id="${BASH_REMATCH[1]:-${match[1]}}"
        fi

        if [[ -z "$pipeline_id" ]]; then
            pipeline_id="$(printf '%s\n' "$pipeline_selection" | grep -oE '#[0-9]+' | head -n 1 | tr -d '#')"
        fi

        if [[ -z "$pipeline_id" ]]; then
            log error "Could not parse pipeline ID from selection: $pipeline_selection"
            return 1
        fi
    fi

    if [[ -z "$pipeline_id" ]]; then
        log error "Pipeline ID is missing or invalid."
        return 1
    fi

    log info "Fetching jobs for pipeline #$pipeline_id..."
    local jobs_json
    jobs_json="$(glab api --paginate "projects/:id/pipelines/${pipeline_id}/jobs?per_page=100" 2>/dev/null)"

    if [[ -z "$jobs_json" ]]; then
        log error "Failed to fetch jobs for pipeline #$pipeline_id."
        return 1
    fi

    if ! printf '%s\n' "$jobs_json" | jq -e 'type == "array"' &>/dev/null; then
        local error_msg
        error_msg="$(printf '%s\n' "$jobs_json" | jq -r '.message // .error // empty' 2>/dev/null)"
        if [[ -n "$error_msg" ]]; then
            log error "Failed to fetch jobs for pipeline #${pipeline_id}: $error_msg"
        else
            log error "Failed to fetch jobs for pipeline #$pipeline_id."
        fi
        return 1
    fi

    local -r job_count="$(printf '%s\n' "$jobs_json" | jq 'length' 2>/dev/null)"
    if [[ -z "$job_count" || "$job_count" -eq 0 ]]; then
        log warn "No jobs found for pipeline #$pipeline_id."
        return 1
    fi

    local -r log_file="$(mktemp "${TMPDIR:-/tmp}/glab_pipeline_${pipeline_id}_XXXXXX.log")"
    local -r tmp_jobs_dir="$(mktemp -d "${TMPDIR:-/tmp}/glab_pipeline_${pipeline_id}_jobs_XXXXXX")"
    log info "Retrieving logs for $job_count jobs in parallel (saving to $log_file)..."

    {
        echo "================================================================================"
        echo "=== Pipeline Logs: #${pipeline_id}"
        echo "=== Total Jobs: ${job_count}"
        echo "=== Timestamp: $(date +"%Y-%m-%d %H:%M:%S")"
        echo "================================================================================"
    } > "$log_file"

    printf '%s\n' "$jobs_json" | jq -r 'sort_by(.id) | to_entries[] | "\(.key)\n\(.value.id)\n\(.value.name // "unknown")\n\(.value.stage // "unknown")\n\(.value.status // "unknown")"' | \
    xargs -P 8 -n 5 sh -c '
        tmp_dir="$1"
        idx="$2"
        job_id="$3"
        job_name="$4"
        job_stage="$5"
        job_status="$6"
        padded_idx=$(printf "%04d" "$idx")
        trace=$(glab api "projects/:id/jobs/${job_id}/trace" 2>/dev/null)
        {
            echo ""
            echo "================================================================================"
            echo "=== STAGE: ${job_stage} | JOB: ${job_name} (ID: ${job_id}) | STATUS: ${job_status}"
            echo "================================================================================"
            echo ""
            if [ -n "$trace" ]; then
                printf "%s\n" "$trace" | sed -E "s/\r$//; s/\r/\n/g"
            else
                echo "(No log output available for job ${job_name})"
            fi
        } > "${tmp_dir}/${padded_idx}.log"
    ' _ "$tmp_jobs_dir"

    # Concatenate ordered job logs and clean up temp files
    if compgen -G "${tmp_jobs_dir}/*.log" > /dev/null 2>&1 || ls "${tmp_jobs_dir}"/*.log > /dev/null 2>&1; then
        cat "${tmp_jobs_dir}"/*.log >> "$log_file"
    fi
    rm -rf "$tmp_jobs_dir"

    log info "Finished retrieving pipeline logs: $log_file"

    if [[ -t 1 ]]; then
        ${PAGER:-less -R} "$log_file"
    else
        cat "$log_file"
    fi
}

# Checkout a merge request using an interactive selection menu
function glab_mr_checkout {
    local -r search="$1"
    local -r label="$2"
    local -a repo_args=("${@:3}")

    local -r pr_selection="$(glab mr list "${repo_args[@]}" --search "$search" --label "$label" | grep -v '^$\|Showing.*(Page.*)' | fzf --prompt " Please select the MR > ")"
    local -r pr="$(echo "$pr_selection" | awk '{print $1}')"

    if [[ -z "$pr" ]]; then
        log warn "No MR selected, exiting."
        return 1
    fi

    glab mr checkout "$pr" "${repo_args[@]}"
}

# Replace text in the merge request title and description using sed syntax with | as the delimiter
function glab_mr_replace {
    local original="" new="" auto_approve=false mr="" repo="" mr_search="" mr_label="" option
    local new_set=false search_set=false label_set=false
    local -a mr_args=() repo_args=()

    while [[ "$#" -gt 0 ]]; do
        option="$1"
        case "$option" in
            --from|--to|--mr|--repo|--search|--label)
                if [[ "$#" -lt 2 || "$2" == --* ]]; then
                    log error "Missing value for $option."
                    return 1
                fi
                case "$option" in
                    --from) original="$2" ;;
                    --to) new="$2"; new_set=true ;;
                    --mr) mr="$2" ;;
                    --repo) repo="$2" ;;
                    --search) mr_search="$2"; search_set=true ;;
                    --label) mr_label="$2"; label_set=true ;;
                esac
                if [[ -z "$2" && "$option" != --to && "$option" != --search && "$option" != --label ]]; then
                    log error "$option cannot be empty."
                    return 1
                fi
                shift 2
                ;;
            --auto-approve) auto_approve=true; shift ;;
            --help|-h)
                printf '%s\n' 'Usage: glab_mr_replace [--mr ID/branch] [--repo REPO] [--search TEXT] [--label LABEL] [--from PATTERN] [--to TEXT] [--auto-approve]'
                return 0
                ;;
            *) log error "Unknown argument: $option. Use --help for usage."; return 1 ;;
        esac
    done
    [[ -z "$mr" ]] || mr_args+=("$mr")
    if [[ -n "$repo" ]]; then
        repo_args=(--repo "$repo")
        mr_args+=("${repo_args[@]}")
    fi

    assert_is_installed glab
    assert_is_installed jq
    assert_is_installed sed
    assert_is_installed gum

    # MR selection
    if [[ -z "$mr" ]]; then
        assert_is_installed fzf
        log info "No MR target specified, prompting for MR selection."
        if [[ "$search_set" == false ]]; then
            mr_search="$(gum input --header "Filter merge requests (optional)" --placeholder "Search MR titles and descriptions")" || return 1
        fi
        if [[ "$label_set" == false ]]; then
            mr_label="$(gum input --header "Filter by label (optional)" --placeholder "Label")" || return 1
        fi
        glab_mr_checkout "$mr_search" "$mr_label" "${repo_args[@]}" || return 1
    fi

    local mr_json title description updated_title updated_description
    if ! mr_json="$(glab mr view "${mr_args[@]}" --output json)"; then
        log error "Failed to fetch the merge request."
        return 1
    fi
    if ! title="$(printf '%s\n' "$mr_json" | jq -r '(.title // "") | if type == "string" then . else error("Invalid MR title") end')"; then
        log error "Failed to read the merge request title."
        return 1
    fi
    if ! description="$(printf '%s\n' "$mr_json" | jq -r '(.description // "") | if type == "string" then . else error("Invalid MR description") end')"; then
        log error "Failed to read the merge request description."
        return 1
    fi
    printf '\nMR Title:\n%s\n\nCurrent Description:\n%s\n\n' "$title" "$description"

    # Prompt for the text to replace if not provided as an argument
    if [[ -z "$original" ]]; then
        original="$(gum input --header "Text to replace (sed pattern)" --placeholder "Search text")" || return 1
        if [[ -z "$original" ]]; then
            log error "Text to replace cannot be empty."
            return 1
        fi
    fi
    if [[ "$new_set" == false ]]; then
        new="$(gum input --header "Replacement text (leave empty to delete)" --placeholder "Replacement text")" || return 1
    fi

    if ! updated_title="$(printf '%s\n' "$title" | sed -e "s|${original}|${new}|g")"; then
        log error "Failed to replace text in the merge request title."
        return 1
    fi
    if ! updated_description="$(printf '%s\n' "$description" | sed -e "s|${original}|${new}|g")"; then
        log error "Failed to replace text in the merge request description."
        return 1
    fi
    if [[ -z "${updated_title//[[:space:]]/}" ]]; then
        log error "The merge request title cannot be empty."
        return 1
    fi
    if [[ "$title" == "$updated_title" && "$description" == "$updated_description" ]]; then
        log warn "No changes to the merge request title or description."
        return 1
    fi

    printf 'Replacing %s with %s in the merge request title and description:\n\nBefore:\nTitle: %s\nDescription:\n%s\n\n--\nAfter:\nTitle: %s\nDescription:\n%s\n\n' \
        "$original" "$new" "$title" "$description" "$updated_title" "$updated_description"
    if [[ "$auto_approve" == "false" ]] && ! gum confirm "Update the merge request title and description?"; then
        return 1
    fi

    if ! glab mr update "${mr_args[@]}" --title "$updated_title" --description "$updated_description" --yes; then
        log error "Failed to update the merge request title and description."
        return 1
    fi
    log info "Updated the merge request title and description."
}
