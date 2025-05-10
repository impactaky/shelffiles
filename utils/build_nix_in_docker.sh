#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"

docker create --name shelffiles -v "$(pwd):$(pwd)" --workdir "$(pwd)" nixos/nix sleep infinity
docker start shelffiles
docker exec shelffiles nix build -o result_docker --extra-experimental-features 'nix-command flakes'
sudo docker cp shelffiles:/nix "$SCRIPT_DIR"/../
