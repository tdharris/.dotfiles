#!/usr/bin/env bash

set -euo pipefail

DOTFILES_DIR="$HOME/.dotfiles"
APPLY_LINKS=0
DRY_RUN=0
FORCE=0

function usage {
	cat <<'EOF'
Usage: bootstrap.sh [options]

Options:
	--apply-links     Apply symlinks from discovered bootstrap manifests
	--dry-run         Show planned link changes without applying them (requires --apply-links)
	--force           Allow replacing existing non-symlink files/directories per manifest policy
	-h, --help        Show this help text
EOF
}

function parse_args {
	while [[ $# -gt 0 ]]; do
		case "$1" in
			--apply-links)
				APPLY_LINKS=1
				shift
				;;
			--dry-run)
				DRY_RUN=1
				shift
				;;
			--force)
				FORCE=1
				shift
				;;
			-h|--help)
				usage
				exit 0
				;;
			*)
				echo "Unknown option: $1" >&2
				usage >&2
				exit 1
				;;
		esac
	done

	if [[ "$DRY_RUN" -eq 1 && "$APPLY_LINKS" -ne 1 ]]; then
		echo "--dry-run requires --apply-links" >&2
		exit 1
	fi
}

function source_deps {
	local -r deps_dir="$1"

	if [[ ! -d "$deps_dir" ]]; then
		return 0
	fi
	
	# Source all shell scripts
	find "$deps_dir" -maxdepth 1 -name "*.sh" -type f 2>/dev/null | while read -r file; do
		# shellcheck disable=SC1090
		source "$file"
	done
	
	# Source all aliases files
	find "$deps_dir" -maxdepth 1 -name "*_aliases" -type f 2>/dev/null | while read -r file; do
		# shellcheck disable=SC1090
		source "$file"
	done
}

function expand_path {
	local path="$1"

	if [[ "$path" == "~" ]]; then
		path="$HOME"
	elif [[ "$path" == "~/"* ]]; then
		path="$HOME/${path#\~/}"
	elif [[ "$path" == "~"* ]]; then
		path="$HOME/${path#\~}"
	fi

	path="${path//\$\{HOME\}/$HOME}"
	path="${path//\$HOME/$HOME}"

	printf '%s\n' "$path"
}

function discover_plan_files {
	local -a plans=(
		"$DOTFILES_DIR/wrk/bootstrap.plan.yml"
		"$DOTFILES_DIR/personal/bootstrap.plan.yml"
	)
	local plan

	for plan in "${plans[@]}"; do
		if [[ -f "$plan" ]]; then
			printf '%s\n' "$plan"
		fi
	done
}

function handle_existing_target {
	local target="$1"
	local policy="$2"
	local force="$3"

	case "$policy" in
		error)
			echo "ERROR: target exists and is not a symlink: $target" >&2
			return 1
			;;
		skip)
			echo "SKIP: target exists and policy=skip: $target"
			return 2
			;;
		backup)
			if [[ "$force" -ne 1 ]]; then
				echo "ERROR: --force required for backup policy: $target" >&2
				return 1
			fi
			local backup_target
			backup_target="${target}.bak.$(date +%Y%m%d%H%M%S)"
			mv "$target" "$backup_target"
			echo "BACKUP: moved existing target to $backup_target"
			;;
		replace)
			if [[ "$force" -ne 1 ]]; then
				echo "ERROR: --force required for replace policy: $target" >&2
				return 1
			fi
			if [[ -d "$target" && ! -L "$target" ]]; then
				echo "ERROR: refusing to replace directory target: $target" >&2
				return 1
			fi
			rm -f "$target"
			echo "REPLACE: removed existing target: $target"
			;;
		*)
			echo "ERROR: unknown if_exists policy '$policy' for target $target" >&2
			return 1
			;;
	esac

	return 0
}

function path_matches_any_pattern {
	local path="$1"
	shift

	local pattern
	for pattern in "$@"; do
		if [[ "$path" == $pattern ]]; then
			return 0
		fi
	done

	return 1
}

function link_one_path {
	local source="$1"
	local target="$2"
	local if_exists="$3"
	local dry_run="$4"
	local force="$5"

	if [[ -L "$target" ]]; then
		local current_target
		current_target="$(readlink "$target")"
		if [[ "$current_target" == "$source" ]]; then
			echo "OK: already linked: $target -> $source"
			return 0
		fi
		if [[ "$dry_run" -eq 1 ]]; then
			echo "DRY-RUN: relink $target -> $source"
			return 0
		fi
		ln -sfn "$source" "$target"
		echo "LINK: updated symlink $target -> $source"
		return 0
	fi

	if [[ -e "$target" ]]; then
		if [[ "$dry_run" -eq 1 ]]; then
			echo "DRY-RUN: existing target policy '$if_exists' for $target"
			if [[ "$if_exists" == "error" ]]; then
				echo "ERROR: target exists and policy=error: $target" >&2
				return 1
			fi
			if [[ "$if_exists" == "skip" ]]; then
				return 0
			fi
		else
			handle_existing_target "$target" "$if_exists" "$force" || {
				local result=$?
				if [[ "$result" -eq 2 ]]; then
					return 0
				fi
				return 1
			}
		fi
	fi

	if [[ "$dry_run" -eq 1 ]]; then
		echo "DRY-RUN: link $target -> $source"
		return 0
	fi

	mkdir -p "$(dirname "$target")"
	ln -s "$source" "$target"
	echo "LINK: created symlink $target -> $source"
}

function apply_plan_file {
	local plan_file="$1"
	local dry_run="$2"
	local force="$3"

	if ! command -v yq >/dev/null 2>&1; then
		echo "ERROR: yq is required to apply bootstrap plans." >&2
		return 1
	fi

	local version
	version="$(yq -r '.version // ""' "$plan_file")"
	if [[ "$version" != "1" ]]; then
		echo "ERROR: unsupported plan version in $plan_file (expected version: 1)" >&2
		return 1
	fi

	local plan_dir
	plan_dir="$(dirname "$plan_file")"

	local count
	count="$(yq -r '.operations | length' "$plan_file")"
	echo "Applying plan: $plan_file ($count operations)"

	local idx
	for ((idx = 0; idx < count; idx++)); do
		local op
		op="$(yq -r ".operations[$idx].op // \"\"" "$plan_file")"
		if [[ -z "$op" ]]; then
			echo "ERROR: missing op at index $idx in $plan_file" >&2
			return 1
		fi

		if [[ "$op" != "symlink" && "$op" != "symlink_tree" ]]; then
			echo "SKIP: unsupported op '$op' at index $idx"
			continue
		fi

		if [[ "$op" == "symlink" ]]; then
			local raw_source raw_target if_exists
			raw_source="$(yq -r ".operations[$idx].source // \"\"" "$plan_file")"
			raw_target="$(yq -r ".operations[$idx].target // \"\"" "$plan_file")"
			if_exists="$(yq -r ".operations[$idx].if_exists // \"error\"" "$plan_file")"

			if [[ -z "$raw_source" || -z "$raw_target" ]]; then
				echo "ERROR: symlink op requires source and target at index $idx in $plan_file" >&2
				return 1
			fi

			local source target
			source="$(expand_path "$raw_source")"
			target="$(expand_path "$raw_target")"

			if [[ "$source" != /* ]]; then
				source="$plan_dir/$source"
			fi

			if [[ "$target" != /* ]]; then
				echo "ERROR: target path must resolve to absolute path at index $idx: $target" >&2
				return 1
			fi

			if [[ ! -e "$source" && ! -L "$source" ]]; then
				echo "ERROR: source does not exist at index $idx: $source" >&2
				return 1
			fi

			link_one_path "$source" "$target" "$if_exists" "$dry_run" "$force"
			continue
		fi

		local raw_source_dir raw_target_dir if_exists
		raw_source_dir="$(yq -r ".operations[$idx].source_dir // \"\"" "$plan_file")"
		raw_target_dir="$(yq -r ".operations[$idx].target_dir // \"\"" "$plan_file")"
		if_exists="$(yq -r ".operations[$idx].if_exists // \"error\"" "$plan_file")"

		if [[ -z "$raw_source_dir" || -z "$raw_target_dir" ]]; then
			echo "ERROR: symlink_tree op requires source_dir and target_dir at index $idx in $plan_file" >&2
			return 1
		fi

		local source_dir target_dir
		source_dir="$(expand_path "$raw_source_dir")"
		target_dir="$(expand_path "$raw_target_dir")"

		if [[ "$source_dir" != /* ]]; then
			source_dir="$plan_dir/$source_dir"
		fi

		if [[ "$target_dir" != /* ]]; then
			echo "ERROR: target_dir must resolve to absolute path at index $idx: $target_dir" >&2
			return 1
		fi

		if [[ ! -d "$source_dir" ]]; then
			echo "ERROR: source_dir does not exist at index $idx: $source_dir" >&2
			return 1
		fi

		local -a include_patterns=()
		local -a exclude_patterns=()
		mapfile -t include_patterns < <(yq -r ".operations[$idx].include[]?" "$plan_file")
		mapfile -t exclude_patterns < <(yq -r ".operations[$idx].exclude[]?" "$plan_file")

		local source_file rel_path target_path
		while IFS= read -r -d '' source_file; do
			rel_path="${source_file#"$source_dir"/}"

			if [[ "${#include_patterns[@]}" -gt 0 ]]; then
				if ! path_matches_any_pattern "$rel_path" "${include_patterns[@]}"; then
					continue
				fi
			fi

			if [[ "${#exclude_patterns[@]}" -gt 0 ]]; then
				if path_matches_any_pattern "$rel_path" "${exclude_patterns[@]}"; then
					continue
				fi
			fi

			target_path="$target_dir/$rel_path"
			link_one_path "$source_file" "$target_path" "$if_exists" "$dry_run" "$force"
		done < <(find "$source_dir" -type f -print0)
	done
}

function apply_discovered_plans {
	local dry_run="$1"
	local force="$2"
	local plan
	local found_any=0

	while IFS= read -r plan; do
		found_any=1
		apply_plan_file "$plan" "$dry_run" "$force"
	done < <(discover_plan_files)

	if [[ "$found_any" -eq 0 ]]; then
		echo "No bootstrap plan files found under $DOTFILES_DIR/wrk or $DOTFILES_DIR/personal"
	fi
}

parse_args "$@"

# Source public deps
source_deps "$DOTFILES_DIR/bash"
source_deps "$DOTFILES_DIR/bash/commons"

# Source private deps
for git_submodule in personal wrk; do
	sm="$DOTFILES_DIR/$git_submodule/bash"
	source_deps "$sm"
done

source "$DOTFILES_DIR/util/auth_env.sh"

if [[ "$APPLY_LINKS" -eq 1 ]]; then
	apply_discovered_plans "$DRY_RUN" "$FORCE"
fi
