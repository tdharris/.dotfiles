#!/usr/bin/env bash

# bitwarden session
if command -v bwl &>/dev/null; then
	echo "Loading bitwarden session..."
	eval "$(bwl)" && echo "✔ Success"
fi
