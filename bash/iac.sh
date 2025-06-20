#!/usr/bin/env bash

################################################################
#
# Infrastructure As Code (IAC) Aliases
#
#################################################################

function pretty-csv {
	column -t -s, | less -F -S -X -K
}

function iac-replace {
	local -r original="$1"
	local -r new="$2"
	local -r auto_approve="${3:-false}"

	echo -e "Replacing '$original' with '$new' affecting the following:\n"
	if ! wgrep --exclude=\*.log "$original"; then
		echo "Found nothing to replace."
		return 1
	fi
	echo

	if [[ "$auto_approve" == "false" ]] && ! ask "Do you want to proceed with replacement?"; then
		return 1
	fi

	wgrep -l --exclude=\*.log "$original" | xargs sed -i -e "s|${original}|${new}|g" &&
		echo -e "\n✔️  Replaced '$original' with '$new'" || echo -e "\n❌  Failed to replace '$original' with '$new'"
}

# Replace all versions with target version
function iac-replace-all {
	target_version="$1"

	echo "Replacing all versions with $target_version: $*"

	for v in $(wgrep "\s*source\s*=\s*" | cut -d\? -f2- | sort | uniq | cut -d = -f2- | sed 's|"||'); do
		iac-replace "$v" "$target_version"
	done
}

# Replace version with target version for a file
function iac-replace-file {
	local -r original="$1"
	local -r new="$2"
	local -r file="$3"
	local -r auto_approve="${4:-false}"

	echo -e "Replacing '$original' with '$new' in '$file':\n"
	if ! grep "$original" "$file"; then
		echo "Found nothing to replace."
		return 1
	fi
	echo

	if [[ "$auto_approve" == "false" ]] && ! ask "Do you want to proceed with replacement?"; then
		return 1
	fi

	sed -i -e "s|${original}|${new}|g" "$file" &&
		echo -e "\n✔️  Replaced '$original' with '$new' in '$file'" || echo -e "\n❌  Failed to replace '$original' with '$new' in '$file'"
}

# Replace versions with target version for files provided
function iac-replace-files {
	target_version="$1"
	shift

	for f in "$@"; do
		v="$(grep "\s*source\s*=\s*" "$f" | cut -d\? -f2- | sort | uniq | cut -d = -f2- | sed 's|"||')"
		iac-replace-file "$v" "$target_version" "$f"
	done
}

function iac-discover-tf-version {
	local -r base_dir="${1:-.}"

	if [[ ! -d "$base_dir" ]]; then
		echo "ERROR: Directory does not exist: $base_dir."
		return 1
	fi

	if [[ -f "$base_dir/terragrunt.hcl" ]]; then
		iac-discover-tf-version-hcl "$base_dir"
	else
		for f in $(find "$base_dir" -name terragrunt.hcl | grep -v '.terragrunt-cache' | sort | uniq); do
			local dir="$(dirname "$f")"
			iac-discover-tf-version "$dir"
		done
	fi
}

function iac_cleanup {
	local -r dir="${1:-.}"

	echo "Cleaning up .terragrunt-cache directories from $dir"
	find "$dir" -type d -name .terragrunt-cache 2>/dev/null -exec rm -rf {} \;
	echo "Done."
}

function iac_hcl_fmt {
	local -r base_dir="${1:-.}"

	find "$base_dir" -name terragrunt.hcl -not -path "*/.terragrunt-cache/*" -exec hcledit fmt -u -f {} \;
}

function iac_hcl_find {
	local -r hcl_search="$1"

	if [[ -z "$hcl_search" ]]; then
		echo -e "ERROR: Missing \$1 as search string.\n\nExample: iac_hcl_find mgmt/vpc"
		return 1
	fi

	find . -not -path "*/.terragrunt-cache/*" -type f -name terragrunt.hcl | grep "$hcl_search"
}

function iac_discover_modules {
	wgrep "\s*source\s*=.*" | grep terragrunt.hcl | sed 's|.*source\s*=\s*||;s|^"||;s|"$||;s|.*.git//||;s|?ref=.*||' | sort | uniq
}
