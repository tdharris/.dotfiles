#!/usr/bin/env bash

function install_bw_env {
    local -r INSTALL_PATH="$HOME/.local/bin"

    echo "Installing bw-env-tools..."
    curl -sSL https://raw.githubusercontent.com/tdharris/bitwarden-login/master/bwl -o "$INSTALL_PATH/bwl"
    curl -sSL https://raw.githubusercontent.com/envwarden/envwarden/master/envwarden -o "$INSTALL_PATH/envwarden"
    chmod +x "$INSTALL_PATH/bwl" "$INSTALL_PATH/envwarden"

    # config
    # set BW_ env vars within gitpod separately
    mkdir -p "$HOME/.bwl"
    cat << EOF >> "$HOME/.bwl/config"
# BW_CLIENTID=
# BW_CLIENTSECRET=
BWL_ENCRYPT_METHOD=gpg
GPG_RECIPIENT="$GITPOD_EMAIL"
EOF

    echo "Successfully installed bw-env-tools!"

}

function create_gpg_key {
    gpg --batch --gen-key <<EOF
Key-Type: 1
Key-Length: 2048
Subkey-Type: 1
Subkey-Length: 2048
Name-Real: gitpod
Name-Email: $GITPOD_EMAIL
Expire-Date: 0
%no-protection
EOF
}

function install_tools_for_gitpod {
    echo "Installing tools for gitpod..."
    create_gpg_key
    install_bw_env
    echo "Successfully installed tools for gitpod!"
}

install_tools_for_gitpod
