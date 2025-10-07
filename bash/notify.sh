#!/usr/bin/env bash

#################################################################
#
# notify Aliases
#
#################################################################

# Usage:
#   notify "message"
#
# Environment variables:
#   NOTIFY_METHOD=<slack|discord>
#   NOTIFY_WEBHOOK_URL=<webhook_url>
#

function notify {
    local -r msg="$*"
    if [[ -z "$NOTIFY_METHOD" ]]; then
        echo "ERROR: NOTIFY_METHOD is not set"
        return 1
    fi

    if [[ -z "$NOTIFY_WEBHOOK_URL" ]]; then
        echo "ERROR: NOTIFY_WEBHOOK_URL is not set"
        return 1
    fi

    if [[ "$NOTIFY_METHOD" == "slack" ]]; then
        notify_slack "$msg"
    elif [[ "$NOTIFY_METHOD" == "discord" ]]; then
        notify_discord "$msg"
    fi
}

function notify_slack {
    local -r msg="$*"

    curl --header "Content-Type: application/json" \
        --request "POST" \
        --data "{\"text\": \"$msg\"}" \
        "$NOTIFY_WEBHOOK_URL"
}

function notify_discord {
    local -r msg="$*"

    curl --header "Content-Type: application/json" \
        --request "POST" \
        --data "{\"content\": \"$msg\"}" \
        "$NOTIFY_WEBHOOK_URL"
}
