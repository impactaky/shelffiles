#!/bin/sh

# Get the absolute path of the script directory
SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
export SHELFFILES="$SCRIPT_DIR"

# Create a unique ID based on the path to avoid conflicts when using in multiple locations
PATH_ID=$(echo "$SHELFFILES" | tr '/:' '__')

# Set XDG environment variables to use directories within the repository
export XDG_CONFIG_HOME="$SHELFFILES/config"
export XDG_CACHE_HOME="$SHELFFILES/cache/${PATH_ID}"
export XDG_DATA_HOME="$SHELFFILES/share/${PATH_ID}"
export XDG_STATE_HOME="$SHELFFILES/state/${PATH_ID}"
export PATH="$SHELFFILES/result/bin:$PATH"

# Create necessary directories
mkdir -p "$XDG_CACHE_HOME"
mkdir -p "$XDG_DATA_HOME"
mkdir -p "$XDG_STATE_HOME"


# Application settings
# https://wiki.archlinux.org/title/XDG_Base_Directory

## starship
export STARSHIP_CONFIG="$XDG_CONFIG_HOME"/starship.toml
export STARSHIP_CACHE="$XDG_CACHE_HOME"/starship

## zsh
export ZDOTDIR="$DOTFILES/config/zsh"
