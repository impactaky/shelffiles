#!/usr/bin/env bats

setup() {
  repo_root="$(CDPATH='' cd -- "$BATS_TEST_DIRNAME/../.." && pwd)"
  alias_dir="$repo_root/alias"
}

@test "entrypoint/bash prepends alias directory to PATH" {
  run ./entrypoint/bash -i -c 'echo $PATH'

  echo "Status: $status"
  echo "Output: $output"

  [ "$status" -eq 0 ]

  [[ "$output" == *"$alias_dir"* ]]
}
