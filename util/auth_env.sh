#!/usr/bin/env bash

# bitwarden session
if command -v bwl &>/dev/null; then
	eval "$(bwl)" && echo -e "🔓 \e[32mBitwarden Unlocked\e[0m"
fi
