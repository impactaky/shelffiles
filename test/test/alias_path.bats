#!/usr/bin/env bats

setup() {
  repo_root="$(CDPATH='' cd -- "$BATS_TEST_DIRNAME" && pwd)"
  # Walk up until we find the repo root that contains entrypoint/.
  while [ ! -d "$repo_root/entrypoint" ] && [ "$repo_root" != "/" ]; do
    repo_root="$(dirname "$repo_root")"
  done
  alias_dir="$repo_root/alias"
}

@test "entrypoint/bash prepends alias directory to PATH" {
  run ./entrypoint/bash -i -c 'echo $PATH'

  echo "Status: $status"
  echo "Output: $output"

  [ "$status" -eq 0 ]

  [[ "$output" == *"$alias_dir"* ]]
}
