#!/bin/sh

# Get the absolute path of the script directory
SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/env.sh"

# Set the shell to use based on the first argument
if [ -n "$1" ]; then
    SHELFFILES_SHELL="$1"
fi

# Export the shell setting
export SHELFFILES_SHELL 