#!/usr/bin/env bash

#################################################################
#
# Gruntwork Aliases
#
#################################################################

# Wrapper to inject GITHUB_OAUTH_TOKEN for Github Enterprise
# Useful if GHE PAT is different from GH PAT
function env-ghe-gruntwork-install {
	local -r ghe_repo="$GHE_HOSTNAME"
	local -r current_gh_token="$(printenv GITHUB_OAUTH_TOKEN)"

	echo "$*" | grep -q "repo.*$ghe_repo" >/dev/null
	if [[ $? -eq 0 ]]; then
		echo "Fetching Github Enterprise PAT..."
		if [[ -z "$GH_ENTERPRISE_TOKEN" ]]; then
			echo "ERROR: GH_ENTERPRISE_TOKEN is not set."
			return 1
		fi
		export GITHUB_OAUTH_TOKEN="$GH_ENTERPRISE_TOKEN"
		echo "✔ Successfully set Github Enterprise GITHUB_OAUTH_TOKEN."
	fi

	# Runs gruntwork-install with arguments ignoring any shell function named gruntwork-install.
	command gruntwork-install "$@"

	# Set to the existing token
	export GITHUB_OAUTH_TOKEN="$current_gh_token"
}
alias gruntwork-install="env-ghe-gruntwork-install"
