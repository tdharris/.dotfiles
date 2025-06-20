#!/usr/bin/env bash

#################################################################
#
# Environment Aliases
#
#################################################################

#################################################################
# Helper Functions
#################################################################

function aws_auth {
	if [[ -z "$AWS_MFA_ARN" ]]; then
		echo "ERROR: Environment Variable 'AWS_MFA_ARN' is missing."
		return 1
	fi

	local totp_token
	if [[ -n "$BW_ITEM_NAME" ]]; then
		# Retrieve from bw cli if available
		totp_token="$(getmfa "$BW_ITEM_NAME")"
	else
		echo "$AWS_MFA_ARN"
		read -rsp "TOTP: " totp_token
		echo
	fi
	if [[ -z "$totp_token" ]]; then
		echo "ERROR: Failed to retrieve totp token." && return 1
	fi

	# Set USER Workaround to set --role-session-name
	USER="usage-patterns"
	local -r ROLE_DURATION_SECONDS="7200" # MaxSessionDuration for this role is 2 hours
	local result
	if [[ -z "$1" ]]; then
		result="$(aws-auth \
			--role-duration-seconds "$ROLE_DURATION_SECONDS" \
			--serial-number "$AWS_MFA_ARN" \
			--token-code "$totp_token")"
	else
		# assume_iam_role "$1"
		result="$(aws-auth \
			--role-duration-seconds "$ROLE_DURATION_SECONDS" \
			--serial-number "$AWS_MFA_ARN" \
			--token-code "$totp_token" \
			--role-arn "$1")"
	fi
	if [[ ! "$result" =~ "export " ]]; then
		echo "$result"
		echo "ERROR: Invalid aws_auth response"
		return 1
	fi

	eval "$result"
	USER="$(whoami)"
}

function getmfa {
	bw get totp "$1"
}

function env-aws-clear {
	local -r sts_vars=($(env | grep '^AWS_ARN_STS_' | awk -F'=' '{print $1}'))
	for var in $sts_vars; do unset $var; done
	unset AWS_SECRET_KEY AWS_MFA_ARN AWS_SECRET_ACCESS_KEY AWS_ACCESS_KEY_ID AWS_SESSION_TOKEN AWS_SESSION_EXPIRATION BW_ITEM_NAME
}

function c {
	if [[ -n "$HTTP_PROXY" ]]; then
		log info "Disabling proxy for code-insiders"
		local -r proxy_enabled=true
		local -r proxy_http="$HTTP_PROXY"
		local -r proxy_https="$HTTPS_PROXY"
		unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy
	fi

	if [[ -z "$1" ]]; then
		code-insiders .
	else
		code-insiders "$@"
	fi

	if [[ -n "$proxy_enabled" ]]; then
		log info "Re-enabling proxy"
		export HTTP_PROXY="$proxy_http"
		export http_proxy="$proxy_http"
		export HTTPS_PROXY="$proxy_https"
		export https_proxy="$proxy_https"
	fi
}

#################################################################
# BASH-COMMONS Functions
#################################################################
function source_if_exists {
	if [[ -f "$1" ]]; then
		source "$1"
	fi
}

source_if_exists "$BASH_COMMONS/modules/bash-commons/src/log.sh"
