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

# CloudWatch Logs Insights Query Function
# Usage: aws_cw_logs_query <log-group-name> <query-string> [start-time] [end-time]
#
#   <log-group-name>: The name of the CloudWatch log group.
#   <query-string>: The CloudWatch Logs Insights query.
#   [start-time]: (Optional) Unix epoch time in seconds. Defaults to 24 hour ago.
#   [end-time]:   (Optional) Unix epoch time in seconds. Defaults to now.
#
# Example:
# aws_cw_logs_query my-app-log-group "fields @timestamp, @message | sort @timestamp desc | limit 10"
function aws_cw_logs_query {
	local log_group_name="$1"
	local query_string="$2"
	local start_time="${3:-$(($(date +%s) - 86400))}"
	local end_time="${4:-$(date +%s)}"

	local polling_interval_seconds=2

	# Check if required arguments are provided
	if [[ -z "$log_group_name" || -z "$query_string" ]]; then
		echo "Usage: aws_cw_logs_query <log-group-name> <query-string> [start-time] [end-time]"
		return 1
	fi

	echo "Starting CloudWatch Logs Insights query..."

	# Step 1: Start the query and get the queryId
	local query_result; query_result="$(aws logs start-query \
		--log-group-name "$log_group_name" \
		--start-time "$start_time" \
		--end-time "$end_time" \
		--query-string "$query_string" \
		--output json)" || {
		echo "Error: Error starting query. Check log group name and AWS credentials."
		return 1
	}

	local query_id; query_id="$(echo "$query_result" | jq -r '.queryId')" || {
		echo "Error: parsing queryId from start-query response."
		return 1
	}
	echo "Query started with ID: $query_id"

	# Step 2: Poll for results until the query is complete
	echo "Polling for query results every $polling_interval_seconds seconds..."
	sleep $polling_interval_seconds
	while true; do
		echo -n "Checking status..."
		local results; results="$(aws logs get-query-results --query-id "$query_id" --output json 2>/dev/null)" || {
			echo "Error: retrieving query results."
			return 1
		}
		local query_status; query_status="$(echo -e "$results" | jq -r '.status // "Unknown"')" || {
			echo "Error: parsing status from query results."
			return 1
		}
		echo " status: $query_status"
		# Get status and handle different cases without storing in variables
		if [[ "$query_status" == "Running" || "$query_status" == "Scheduled" ]]; then
			echo " status: Running/Scheduled"
			sleep $polling_interval_seconds
			continue
		elif [[ "$query_status" == "Complete" ]]; then
			# Format results as a simple table using column command
			echo
			echo "Results:"
			echo "========"
			
			# Check if we have any results
			local result_count
			result_count=$(echo "$results" | jq -r '.results | length')
			
			if [[ "$result_count" -eq 0 ]]; then
				echo "No results found."
			else
				# Create a combined output with header and data, excluding @ptr column
				{
					# Print header
					echo "$results" | jq -r '.results[0] | map(select(.field != "@ptr") | .field) | @tsv'
					# Print data rows, excluding @ptr column
					echo "$results" | jq -r '.results[] | map(select(.field != "@ptr") | .value) | @tsv'
				} | column -t -s $'\t'
			fi
			break
		else
			echo "Error: query failed with status: $query_status"
      		echo "$results"
			break
		fi
	done
}

# Function to retrieve fluentbit-streamed workload logs from AWS CloudWatch into a simple application-focused format
# Usage: aws_logs [log-group-name] [log-stream-name] [region] [output-file]
function aws_logs {
	local log_group_name="${1:-}"
	local log_stream_name="${2:-}"
	local region="${3:-}"
	local output_file="${4:-}"

	if (( $# > 4 )); then
		printf 'Usage: aws_logs [log-group-name] [log-stream-name] [region] [output-file]\n' >&2
		return 1
	fi

	assert_is_installed jq
	assert_is_installed aws
	assert_is_installed gum

	if [[ -z "$log_group_name" || -z "$log_stream_name" || -z "$region" || -z "$output_file" ]]; then
		command -v gum >/dev/null 2>&1 || {
			printf 'Error: gum is required to prompt for missing arguments.\n' >&2
			return 1
		}
	fi

	if [[ -z "$log_group_name" ]]; then
		log_group_name="$(gum input --header 'CloudWatch log group:')" || return $?
	fi
	if [[ -z "$log_stream_name" ]]; then
		log_stream_name="$(gum input --header 'CloudWatch log stream:')" || return $?
	fi
	if [[ -z "$region" ]]; then
		region="$(gum input --header 'AWS region:' --value "${AWS_REGION:-${AWS_DEFAULT_REGION:-us-west-2}}")" || return $?
	fi
	if [[ -z "$log_group_name" || -z "$log_stream_name" || -z "$region" ]]; then
		printf 'Error: log group, log stream, and region must not be empty.\n' >&2
		return 1
	fi

	if [[ -z "$output_file" ]]; then
		local filename="${log_stream_name##*/}"
		filename="${filename%.log}"
		filename="${filename//[^a-zA-Z0-9._-]/_}"
		local suggested_file="/tmp/${filename:0:120}-retrieved-$(date +%Y%m%d-%H%M%S).log"
		output_file="$(gum input --header 'Output file:' --value "$suggested_file")" || return $?
		output_file="${output_file:-$suggested_file}"
	fi

	local response
	response="$(aws logs filter-log-events \
		--region "$region" \
		--log-group-name "$log_group_name" \
		--log-stream-names "$log_stream_name" \
		--no-cli-pager \
		--output json)" || return $?

	(
		umask 077
		set -o noclobber
		printf '%s\n' "$response" | jq -j '
			.events[].message | fromjson? | .log? | select(type == "string") |
			if endswith("\n") then . else . + "\n" end
		' | sed 's/\x1b\[[0-9;]*m//g' > "$output_file"
	) || {
		printf 'Error: could not save logs into %s (existing files are not overwritten).\n' "$output_file" >&2
		return 1
	}

	printf 'Logs saved to %s\n' "$output_file"
}
