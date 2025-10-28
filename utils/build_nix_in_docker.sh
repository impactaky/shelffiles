#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"

# Parse command line arguments
TARGET_SYSTEM=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --system)
            TARGET_SYSTEM="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Usage: $0 [--system <SYSTEM>]" >&2
            echo "  --system <SYSTEM>  Target system for cross-compilation (e.g., aarch64-linux, x86_64-linux)" >&2
            exit 1
            ;;
    esac
done

# Determine the build target
if [ -n "$TARGET_SYSTEM" ]; then
    BUILD_TARGET=".#packages.${TARGET_SYSTEM}.default"
    echo "Cross-compiling for ${TARGET_SYSTEM}..."
else
    BUILD_TARGET=""
fi

docker create --name shelffiles -v "$(pwd):$(pwd)" --workdir "$(pwd)" nixos/nix sleep infinity
docker start shelffiles
docker exec shelffiles nix build -o result_docker --extra-experimental-features 'nix-command flakes' $BUILD_TARGET
sudo docker cp shelffiles:/nix "$SCRIPT_DIR"/../
