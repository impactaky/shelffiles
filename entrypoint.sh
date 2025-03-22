#!/bin/sh

# Get the absolute path of the script directory
SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"

# Source the environment setup
. "$SCRIPT_DIR/env.sh"

# Use the user's preferred shell or fall back to bash
case "$SHELFFILES_SHELL" in
    "fish")
        exec fish "$@"
        ;;
    "zsh")
        export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
        exec zsh "$@"
        ;;
    *)
        exec bash "$@"
        ;;
esac
