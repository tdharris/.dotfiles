#!/usr/bin/env bash

# Bitwarden Aliases

function bw_running_and_unlocked {
    bw status | jq -r '.status' | grep -q "unlocked" || bw unlock
}

function bw_generate_password {
    local -r length="${1:-20}"
    bw generate -u -l -n -s --length "$length"
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
