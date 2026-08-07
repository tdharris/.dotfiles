#!/usr/bin/env bash

# Bitwarden Aliases

function bw_running_and_unlocked {
    bw status | jq -r '.status' | grep -q "unlocked" || bw unlock
}

function bw_generate_password {
    local -r length="${1:-20}"
    bw generate -u -l -n -s --length "$length"
}

# Retrieves the specified fields (Username, Password, TOTP) for a given Bitwarden item and copies them to the clipboard.
function bw_get_login {
    local -r item_name="$1"
    if [[ -z "$item_name" ]]; then
        echo "Usage: bw_get_login <item_name>"
        return 1
    fi

    if ! command -v gum &> /dev/null; then
        echo "Error: 'gum' is not installed. Please install it to use this function."
        return 1
    fi

    local selected_fields
    selected_fields="$(gum choose "Username" "Password" "TOTP" --no-limit --header "Select the fields to retrieve for item '$item_name':" </dev/tty)" || return 1
    [[ -z "$selected_fields" ]] && return 0

    local field
    local field_index=0
    local selected_count
    local bw_field

    selected_count="$(printf '%s\n' "$selected_fields" | wc -l)"
    while IFS= read -r field; do
        field_index=$((field_index + 1))
        case "$field" in
            Username)
                bw_field=username
                ;;
            Password)
                bw_field=password
                ;;
            TOTP)
                bw_field=totp
                ;;
            *)
                echo "Error: Invalid field selection."
                return 1
                ;;
        esac

        gum spin --spinner dot --title "Retrieving $field..." -- bw get "$bw_field" "$item_name" | copy
        gum style --foreground 2 "$field copied to clipboard."

        if ((field_index < selected_count)) && ! gum confirm "Retrieve the next selected field?" </dev/tty; then
            return 0
        fi
    done <<< "$selected_fields"
}

# Bitwarden Secrets Manager

# Retrieve a secret from Bitwarden Secrets Manager, parse the value as JSON,
# and export the key-value pairs as environment variables.
# Usage: bws_env <secret_uuid>
function bws_env {
    local -r id="$1"
    local -r value="$(bws secret get "$id" | jq -r '.value')"

    # Ensure the value is a JSON object with at least one key
    if [[ "$(echo "$value" | jq -r 'type')" != "object" ]] || [[ -z "$(echo "$value" | jq -r 'keys | length')" ]]; then
        echo "Error: Value is not a JSON object or is empty"
        return 1
    fi

    # Export each key as an environment variable
    while IFS= read -r key; do
        local value_key="$(echo "$value" | jq -r --arg key "$key" '.[$key]')"
        export "$key"="$value_key"
    done < <(echo "$value" | jq -r 'keys[]')
}
