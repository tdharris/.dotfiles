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

    if [[ -n "$HTTP_PROXY" ]]; then
        log info "Disabling proxy to send notification"
        local -r proxy_enabled=true
        local -r proxy_http="$HTTP_PROXY"
        local -r proxy_https="$HTTPS_PROXY"
        unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy
    fi

    if [[ "$NOTIFY_METHOD" == "slack" ]]; then
        notify_slack "$msg"
    elif [[ "$NOTIFY_METHOD" == "discord" ]]; then
        notify_discord "$msg"
    fi

    if [[ -n "$proxy_enabled" ]]; then
        log info "Re-enabling proxy"
        export HTTP_PROXY="$proxy_http"
        export http_proxy="$proxy_http"
        export HTTPS_PROXY="$proxy_https"
        export https_proxy="$proxy_https"
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
