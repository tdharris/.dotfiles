#!/usr/bin/env bash

#################################################################
#
# k9s Aliases
#
#################################################################

# Wrapper for k9s to assume_iam_role if necessary automatically
function env-k9s-assume-iam-role {
	local -r iam_role="$TERRAGRUNT_IAM_ROLE"

	# Skip if iam_role env var not set or if KUBECONFIG is set
	if [[ -z "$iam_role" || -n "$KUBECONFIG" ]]; then
		command k9s "$@"
	fi

	# Start privileged session if necessary
	aws_sts_start_privileged_session "$iam_role" || { return 1; }

	command k9s "$@"

	aws_sts_end_privileged_session
}
alias k9sa="env-k9s-assume-iam-role"
