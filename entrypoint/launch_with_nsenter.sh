#!/bin/bash

set -eux

SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"

exec sudo unshare --mount bash -c "
  mount --bind '$SCRIPT_DIR/../nix' /nix
  exec su -P '$(id -un)' -c '$1'
"
