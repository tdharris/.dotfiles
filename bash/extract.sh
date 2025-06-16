#!/usr/bin/env bash

#################################################################
#
# Extract Aliases
#
#################################################################

function extract() {

    if [[ "$#" -lt 1 ]]; then
        echo "Usage: extract <path/file_name>.<zip|rar|bz2|gz|tar|tbz2|tgz|Z|7z|xz|ex|tar.bz2|tar.gz|tar.xz>"
        return 1
    fi

    if [[ ! -e "$1" ]]; then
        echo -e "File does not exist!"
        return 2
    fi

    local dst="."
    local file="$(basename "$1")"

    case "${file##*.}" in
    tar)
        echo -e "Extracting $1 to $dst: (uncompressed tar)"
        tar xvf "$1" -C "$dst"
        ;;
    gz)
        echo -e "Extracting $1 to $dst: (gip compressed tar)"
        tar xvfz "$1" -C "$dst"
        ;;
    tgz)
        echo -e "Extracting $1 to $dst: (gip compressed tar)"
        tar xvfz "$1" -C "$dst"
        ;;
    xz)
        echo -e "Extracting  $1 to $dst: (gip compressed tar)"
        tar xvf -J "$1" -C "$dst"
        ;;
    bz2)
        echo -e "Extracting $1 to $dst: (bzip compressed tar)"
        tar xvfj "$1" -C "$dst"
        ;;
    tbz2)
        echo -e "Extracting $1 to $dst: (tbz2 compressed tar)"
        tar xvjf "$1" -C "$dst"
        ;;
    zip)
        echo -e "Extracting $1 to $dst: (zipp compressed file)"
        unzip "$1" -d "$dst"
        ;;
    lzma)
        echo -e "Extracting $1 : (lzma compressed file)"
        unlzma "$1"
        ;;
    rar)
        echo -e "Extracting $1 to $dst: (rar compressed file)"
        unrar x "$1" "$dst"
        ;;
    7z)
        echo -e "Extracting $1 to $dst: (7zip compressed file)"
        7za e "$1" -o "$dst"
        ;;
    xz)
        echo -e "Extracting $1 : (xz compressed file)"
        unxz "$1"
        ;;
    exe)
        cabextract "$1"
        ;;
    *)
        echo -e "Unknown archieve format!"
        return
        ;;
    esac
}
