#!/usr/bin/env bash

#################################################################
#
# Terragrunt Aliases
#
#################################################################

function wgrep {
	grep --exclude=\*.{svg,otf} --exclude-dir={\*.git\*,\*.terraform\*,\*.terragrunt-cache\*,\*_dev_ref\*,\*bridge-website\*,\*node_modules\*} -r "$@" .
}

function wfind {
	find . -not -path "*/.terragrunt-cache/*" "$@"
}

alias tgaf="terragrunt apply"   # "fast"
alias tgpf="terragrunt plan"    # "fast"
alias tga="terragrunt apply --terragrunt-source-update"
alias tgp="terragrunt plan --terragrunt-source-update"
alias tgd="terragrunt destroy"
alias tgf="terragrunt fmt"
alias tgim="terragrunt import"
alias tgin="terragrunt init"
alias tgo="terragrunt output"
alias tgpr="terragrunt providers"
alias tgr="terragrunt refresh"
alias tgsh="terragrunt show"
alias tgt="terragrunt taint"
alias tgut="terragrunt untaint"
alias tgv="terragrunt validate"
alias tgw="terragrunt workspace"
alias tgs="terragrunt state"
alias tgfu="terragrunt force-unlock"
alias tgwst="terragrunt workspace select"
alias tgwsw="terragrunt workspace show"
alias tgssw="terragrunt state show"
alias tgwde="terragrunt workspace delete"
alias tgwls="terragrunt workspace list"
alias tgsls="terragrunt state list"
alias tgwnw="terragrunt workspace new"
alias tgsmv="terragrunt state mv"
alias tgspl="terragrunt state pull"
alias tgsph="terragrunt state push"
alias tgsrm="terragrunt state rm"
alias tgay="terragrunt apply -auto-approve"
alias tgdy="terragrunt destroy -auto-approve"
alias tginu="terragrunt init -upgrade"
alias tgpd="terragrunt plan --destroy"

# Source local modules (find dynamically from $FOCUSSAAS_INFRA_MODULES)
alias tgpl="terragrunt_local_module_source plan"
alias tgal="terragrunt_local_module_source apply"
alias tgdl="terragrunt_local_module_source destroy"
alias tgrl="terragrunt_local_module_source refresh"
alias tgol="terragrunt_local_module_source output"
alias tginl="terragrunt_local_module_source init"
alias tgprl="terragrunt_local_module_source providers"

function terragrunt_local_module_source {
	local -r action="${1:-apply}"; shift;
	local -r INFRA_MODULES="${FOCUSSAAS_INFRA_MODULES}"
	local -r hcl_file="terragrunt.hcl"

	if [[ -z "$INFRA_MODULES" || ! -d "$INFRA_MODULES" ]]; then
		echo "ERROR: INFRA_MODULES is not set or is not a directory: $INFRA_MODULES"
		return 1
	fi
	if [[ ! -f "$hcl_file" ]]; then echo "ERROR: No $hcl_file file found in current directory"; return 1; fi

	local args=()
	while [[ $# -gt 0 ]]; do
		key="$1"
		case $key in
			-b | --branch)
				local -r branch="$2"; shift ;;
			-i | --infra-modules)
				INFRA_MODULES="$2"; shift ;;
			*)
				args+=("$1"); shift ;;
		esac
	done

	# if there is a value for "branch" and it's not empty, let's use it
	if [[ -n "$branch" ]]; then
		local -r current_source="$(grep -r 'source\s*=' $hcl_file | grep -v '^#\|\s*#' | sed 's|source\s*=\s*"||g' | tr -d "[:blank:]" | sed 's|"$||' | head -n1)"
		local -r source="$(echo "$current_source" | sed "s|?ref=.*|?ref="$branch"|")"
		# local -r source="${current_source//?ref=.*/?ref=$branch}"
	else
		local -r source="$(echo "$INFRA_MODULES//$(grep -r 'source\s*=' $hcl_file | grep -v '^#\|\s*#' | sed 's|.*//||' | sed 's|?ref.*||g' | sed 's|"$||' | head -n1)")"
		if [[ ! -d "$source" ]]; then
			echo "ERROR: source is not a directory: $source"
			return 1
		fi
	fi

	echo terragrunt "$action" --terragrunt-source-update --terragrunt-source "$source" "${args[@]}"
	if [[ "${#args[@]}" -ne 0 ]]; then
		terragrunt "$action" --terragrunt-source-update --terragrunt-source "$source" "${args[@]}"
	else
		terragrunt "$action" --terragrunt-source-update --terragrunt-source "$source"
	fi
}

function iac-helm-diff-plan {
	local -r plan="tf.plan"

	terragrunt plan --terragrunt-source-update -no-color >"$plan" &&
		cat "$plan" | awk '/helm_release/,/^    }/' | awk '/- <<-EOT/,/EOT,/' >old.yaml &&
		cat "$plan" | awk '/helm_release/,/^    }/' | awk '/+ <<-EOT/,/EOT,/' >new.yaml &&
		git diff --no-index old.yaml new.yaml

	if [[ ! -s "old.yaml" || ! -s "new.yaml"  ]]; then
		echo "ERROR: Failed to obtain helm chart diff"
		cat "$plan"
		rm old.yaml new.yaml "$plan" 2>/dev/null
		return 1
	else
		echo -e "\n$plan\nold.yaml\nnew.yaml"
		if ask "Do you want to delete these temporary files?"; then
			rm -v old.yaml new.yaml "$plan"
		fi
	fi
}
