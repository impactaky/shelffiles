#!/bin/bash

set -eu

# Parse arguments
NO_ROOT=0
while [[ $# -gt 0 ]]; do
    case $1 in
        --no-root)
            NO_ROOT=1
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [[ "$OSTYPE" == "darwin"* ]] && [ "$NO_ROOT" -eq 1 ]; then
    echo "Error: --no-root is not supported on macOS"
    exit 1
fi

if [ "$NO_ROOT" -eq 0 ]; then
    if [ -e "$HOME"/.nix-profile/etc/profile.d/nix.sh ]; then
        # shellcheck disable=SC1091
        . "$HOME"/.nix-profile/etc/profile.d/nix.sh
    fi
    if ! command -v nix &> /dev/null; then
        echo "Installing Nix..."
        sh <(curl -L https://nixos.org/nix/install)
        # shellcheck disable=SC1091
        . "$HOME"/.nix-profile/etc/profile.d/nix.sh
    fi
elif [ ! -e nix-portable ]; then
    echo "Installing nix-portable..."
    curl -L https://github.com/DavHau/nix-portable/releases/download/v012/nix-portable-"$(arch)" -o nix-portable
    chmod +x nix-portable
fi

echo "Building..."
if [ "$NO_ROOT" -eq 0 ]; then
    nix build --extra-experimental-features nix-command --extra-experimental-features flakes
else
    ./nix-portable nix build --extra-experimental-features nix-command --extra-experimental-features flakes --store "$(pwd)"
fi
