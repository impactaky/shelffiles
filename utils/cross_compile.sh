#!/bin/bash

# Helper script for cross-compilation workflows
# Automatically determines the opposite architecture and builds for it

set -euo pipefail

# Detect current architecture
CURRENT_ARCH=$(uname -m)
CURRENT_OS="linux"
if [[ "$OSTYPE" == "darwin"* ]]; then
    CURRENT_OS="darwin"
fi

# Map to Nix system names
case "$CURRENT_ARCH" in
    x86_64)
        CURRENT_SYSTEM="x86_64-${CURRENT_OS}"
        TARGET_SYSTEM="aarch64-${CURRENT_OS}"
        ;;
    aarch64|arm64)
        CURRENT_SYSTEM="aarch64-${CURRENT_OS}"
        TARGET_SYSTEM="x86_64-${CURRENT_OS}"
        ;;
    *)
        echo "Error: Unsupported architecture: $CURRENT_ARCH" >&2
        exit 1
        ;;
esac

echo "Current system: $CURRENT_SYSTEM"
echo "Cross-compiling for: $TARGET_SYSTEM"
echo ""

# Run setup.sh with cross-compilation flag
exec "$(dirname "$0")/../setup.sh" --system "$TARGET_SYSTEM" "$@"
