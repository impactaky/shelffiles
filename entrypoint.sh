#!/bin/sh

# Get the absolute path of the script directory
SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/env.sh"

# If arguments are provided, execute them
# Otherwise, start a shell
if [ $# -gt 0 ]; then
    exec "$@"
else
    # Use the user's preferred shell or fall back to bash
    if [ -n "$SHELL" ]; then
        exec "$SHELL"
    else
        exec bash
    fi
fi 