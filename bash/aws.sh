#!/usr/bin/env bash

#################################################################
#
# AWS Aliases
#
#################################################################

# Login Docker to AWS ECR
alias dlogin-dev="dlogin DEV us-east-2"

function awsme {
	aws sts get-caller-identity --no-cli-pager
}

# Assume an IAM Role
function assume_iam_role {
	local -r iam_role_arn="$1"

	echo "Assuming IAM role $iam_role_arn"

	local assume_role_response
	local access_key_id
	local secret_access_key
	local session_token

	assume_role_response=$(aws sts assume-role --role-arn "$iam_role_arn" --role-session-name "usage-patterns") || {
		echo >&2 -e "\nERROR: Failed to assume_iam_role: $iam_role_arn"
		return 1
	}

	access_key_id=$(echo "$assume_role_response" | jq -r '.Credentials.AccessKeyId')
	secret_access_key=$(echo "$assume_role_response" | jq -r '.Credentials.SecretAccessKey')
	session_token=$(echo "$assume_role_response" | jq -r '.Credentials.SessionToken')

	export AWS_ACCESS_KEY_ID="$access_key_id"
	export AWS_SECRET_ACCESS_KEY="$secret_access_key"
	export AWS_SESSION_TOKEN="$session_token"
}

function aws_identity_is_iam_role {
	local -r iam_role="${1:-$TERRAGRUNT_IAM_ROLE}"
	local -r current_identity="$(aws sts get-caller-identity)" || return 1

	local -r current_account="$(echo "$current_identity" | jq -r '.Account')"
	local -r current_name="$(echo "$current_identity" | jq -r '.Arn' | cut -d: -f6)"

	local -r iam_role_account="$(echo "$iam_role" | cut -d: -f5)"
	local -r iam_role_name="$(echo "$iam_role" | cut -d: -f6)"

	if [[ "$iam_role_account" != "$current_account" ]]; then
		return 1
	elif [[ "$iam_role_name" =~ "$current_name" ]]; then
		return 1
	else
		return 0
	fi
}

function aws_sts_start_privileged_session {
	local -r iam_role="${1:-$TERRAGRUNT_IAM_ROLE}"

	# Assume role if needed
	if ! aws_identity_is_iam_role "$iam_role"; then
		# Validate AWS Caller Identity exists
		# Set globally for use in 'aws_sts_end_privileged_session'
		unset AWS_CURRENT_ACCESS_KEY_ID AWS_CURRENT_SECRET_ACCESS_KEY AWS_CURRENT_SESSION_TOKEN
		AWS_CURRENT_ACCESS_KEY_ID="$(printenv AWS_ACCESS_KEY_ID)" || {
			echo "ERROR Missing AWS_ACCESS_KEY_ID Environment Variable."
			exit 1
		}
		AWS_CURRENT_SECRET_ACCESS_KEY="$(printenv AWS_SECRET_ACCESS_KEY)" || {
			echo "ERROR Missing AWS_SECRET_ACCESS_KEY Environment Variable."
			exit 1
		}
		AWS_CURRENT_SESSION_TOKEN="$(printenv AWS_SESSION_TOKEN)" || { echo "WARNING Missing AWS_SESSION_TOKEN Environment Variable. May be required for sts:AssumeRole."; }

		assume_iam_role "$iam_role"
	fi
}

function aws_sts_end_privileged_session {
	if [[ -n "$AWS_CURRENT_ACCESS_KEY_ID" && -n "$AWS_CURRENT_SECRET_ACCESS_KEY" && -n "$AWS_CURRENT_SESSION_TOKEN" ]]; then
		echo "Finished privileged session, switching to previous AWS Caller Identity."
		export AWS_ACCESS_KEY_ID="$AWS_CURRENT_ACCESS_KEY_ID"
		export AWS_SECRET_ACCESS_KEY="$AWS_CURRENT_SECRET_ACCESS_KEY"
		export AWS_SESSION_TOKEN="$AWS_CURRENT_SESSION_TOKEN"
	fi
}

# Docker Login to AWS ECR
# Depends on: 'AWS_ARN_STS_<ACCOUNT>' env vars
# E.g. dlogin DEV
function dlogin {
	local current_shell="$(ps -hp $$|awk '{print $5}')"
	if [[ "$current_shell" == "-zsh" ]]; then
		local ARN_NAME="AWS_ARN_STS_${1:u}"
	else
		local ARN_NAME="AWS_ARN_STS_${1^^}"
	fi

	local ARN="$(printenv "${ARN_NAME}")"
	local ACCOUNT="$(echo "$ARN" | cut -d: -f5)"
	local REGION="${2:-${AWS_DEFAULT_REGION:-us-east-2}}"

	if [[ -z "$ACCOUNT" ]]; then
		echo "dlogin is missing ACCOUNT, can't determine from Environment Variable '$ARN_NAME':'$ARN'"
		return 1
	fi
	if [[ -z "$REGION" ]]; then
		echo "dlogin is missing REGION: '$REGION'"
		return 1
	fi

	echo "Logging Docker into AWS ECR: https://$ACCOUNT.dkr.ecr.$REGION.amazonaws.com ..."
	aws ecr get-login-password --region "$REGION" | docker login -u AWS --password-stdin "https://$ACCOUNT.dkr.ecr.$REGION.amazonaws.com"
}

function aws_ecr_latest_versions {
	local -r repo_name="$1"
	local -r latest_count="${2:-1}"

	# Ensure repo name is provided
	if [[ -z "$repo_name" ]]; then
		echo "ERROR: Missing repo_name argument"
		return 1
	fi

	log info "Latest ECR image(s) from $repo_name:"
	aws ecr describe-images \
		--repository-name "$repo_name" \
		--query "reverse(sort_by(imageDetails,& imagePushedAt))[:$latest_count].[{imageTag: imageTags[0], imagePushedAt: imagePushedAt}]" \
		--no-cli-pager \
		--output table
}
