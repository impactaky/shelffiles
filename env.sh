#!/bin/sh

# Get the absolute path of the script directory
SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
export SHELFFILES="$SCRIPT_DIR"

# Create a unique ID based on the path, user ID and group ID to avoid conflicts
PATH_ID=$(echo "${SHELFFILES}_$(id -u)_$(id -g)" | tr '/:' '__')

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

USER_ENV_FILE="$SHELFFILES/user_env.sh"
if [ -f "$USER_ENV_FILE" ]; then
  . "$USER_ENV_FILE"
fi
