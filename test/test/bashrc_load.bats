#!/usr/bin/env bats

setup() {
  # Clear environment variables that might affect the test
  unset SHELFFILES_BASH_TEST
}

@test "entrypoint/bash loads config/bash/.bashrc implicitly via BASH_ENV" {
  run ./entrypoint/bash -i -c 'echo $SHELFFILES_BASH_TEST'

  # For debugging
  echo "Status: $status"
  echo "Output: $output"

  # Check if the command sequence executed successfully (status 0)
  [ "$status" -eq 0 ]

  [[ "$output" == *"loaded" ]]
}
