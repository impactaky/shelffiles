#!/usr/bin/env bats

setup() {
  repo_root="$(CDPATH='' cd -- "$BATS_TEST_DIRNAME" && pwd)"
  # Walk up until we find the repo root that contains entrypoint/.
  while [ ! -d "$repo_root/entrypoint" ] && [ "$repo_root" != / ]; do
    repo_root="$(dirname -- "$repo_root")"
  done
}

@test "entrypoint/bash puts result bins at the start of PATH" {
  run ./entrypoint/bash -i -c 'printf "PATH=%s\n" "$PATH"'

  echo "Status: $status"
  echo "Output: $output"

  [ "$status" -eq 0 ]
  [[ "$output" == *"PATH=$repo_root/result/bin:"* ]]
}
