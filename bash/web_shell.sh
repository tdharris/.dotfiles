#!/usr/bin/env bash

#################################################################
#
# Web Shell Helpers
#
#################################################################

function web-shell {
	local -r work_dir="$(realpath -- "${1:-$PWD}")"
	local -r port="${WEB_SHELL_REMOTE_PORT:-8080}"
	local -r host="${WEB_SHELL_REMOTE_HOST:-desktop.home}"
	local -r username="${WEB_SHELL_REMOTE_USER:-dev}"
	local pin="${WEB_SHELL_REMOTE_PIN:-}"
	local -r session_suffix="$(printf '%s' "$work_dir" | sha256sum | cut -c1-12)"
	local -r session_name="web-shell-$session_suffix"

	if [[ ! -d "$work_dir" ]]; then
		echo "ERROR: Directory does not exist: $work_dir"
		return 1
	fi

	if ! command -v ttyd >/dev/null 2>&1; then
		echo "ERROR: ttyd is required but not installed"
		return 1
	fi

	if ! command -v tmux >/dev/null 2>&1; then
		echo "ERROR: tmux is required but not installed"
		return 1
	fi

	if ! command -v sha256sum >/dev/null 2>&1; then
		echo "ERROR: sha256sum is required but not installed"
		return 1
	fi

	if [[ -z "$pin" ]]; then
		if command -v node >/dev/null 2>&1; then
			pin="$(node -e 'console.log(Math.random().toString(36).substring(2, 8))')"
		else
			pin="$(tr -dc 'a-z0-9' </dev/urandom | head -c 6)"
		fi
	fi

	local -r display_url="http://$host:$port"
	local -r auth_url="http://$username:$pin@$host:$port"
	local -r theme='{"background":"#0f172a","foreground":"#f1f5f9","cursor":"#818cf8"}'

	echo -e "\n\033[1;34mRemote Shell Relay\033[0m"
	echo -e "\033[1;36mContext: $work_dir\033[0m"
	echo -e "\033[1;33mUsername: $username | Password: $pin\033[0m"
	echo -e "\033[1;32m$display_url\033[0m\n"

	if command -v npx >/dev/null 2>&1; then
		npx -y qrcode-terminal "$auth_url"
	else
		echo "QR skipped: npx not found"
		echo "Auth URL: $auth_url"
	fi

	echo -e "\nStarting ttyd on port $port. Press Ctrl+C here to stop the server."

	ttyd -p "$port" -i 0.0.0.0 -c "$username:$pin" -W \
			-t fontSize=20 \
			-t enableButtons=true \
			-t disableScrollbar=true \
			-t cursorBlink=true \
			-t disableLeaveAlert=true \
			-t theme="$theme" \
			tmux new-session -A -s "$session_name" -c "$work_dir" -- \
			zsh -lc "tmux set status off; tmux set mouse on; exec zsh -il"
}

alias ws="web-shell"
