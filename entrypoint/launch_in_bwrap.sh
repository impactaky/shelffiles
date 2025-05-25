#!/bin/bash

set -eu

# Source environment and config
SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/env.sh"

NIX_HOST_PATH="${SHELFFILES}/nix"

if [ ! -d "$NIX_HOST_PATH" ]; then
  echo "Error: Directory not found: ${NIX_HOST_PATH}" >&2
  exit 1
fi

BWRAP_ARGS=(
  --share-net
  --proc /proc
  --dev /dev
  --tmpfs /tmp
)

if [ -e /run ]; then
  BWRAP_ARGS+=(--bind /run /run)
elif [ ! -h /run ]; then # Create if not exists and not a broken symlink
  BWRAP_ARGS+=(--dir /run)
fi

if [ -e /sys ]; then
  BWRAP_ARGS+=(--ro-bind /sys /sys)
fi

while IFS= read -r entry_path; do
  entry_name="$(basename "$entry_path")"
  case "$entry_name" in
    proc|dev|tmp|sys|run|nix|lost+found) # Exclude special directories/mount points
      ;;
    *)
      # Check the type of the entry *at the path* (don't follow links for the check)
      if [ -L "$entry_path" ]; then
        BWRAP_ARGS+=(--bind "$entry_path" "$entry_path")
      elif [ -d "$entry_path" ]; then
        BWRAP_ARGS+=(--bind "$entry_path" "$entry_path")
      elif [ -f "$entry_path" ]; then
        # It's a regular file, bind it read-only for safety
        BWRAP_ARGS+=(--ro-bind "$entry_path" "$entry_path")
      fi
      ;;
  esac
done < <(find / -maxdepth 1 -mindepth 1)

# Handle /nix
BWRAP_ARGS+=(--dir /nix)
BWRAP_ARGS+=(--bind "$NIX_HOST_PATH" /nix)

# Use sudo mount launcher if enabled, otherwise use bwrap
if [ "${SUDO_MOUNT_ENABLED:-0}" -eq 1 ] && [ -x "$SCRIPT_DIR/launch_with_nsenter.sh" ]; then
  exec "$SCRIPT_DIR/launch_with_nsenter.sh" "$@"
else
  exec bwrap "${BWRAP_ARGS[@]}" "$@"
fi
