#!/usr/bin/env bats

setup() {
  # Clear environment variables that might affect the test
  unset SHELFFILES_FISH_TEST
}

@test "entrypoint/fish loads config/fish/config.fish implicitly" {
  # shellcheck disable=SC2016
  run ./entrypoint/fish -i -c 'echo $SHELFFILES_FISH_TEST'

  # For debugging
  echo "Status: $status"
  echo "Output: $output"

  # Check if the command sequence executed successfully (status 0)
  [ "$status" -eq 0 ]

  # Check if the output contains "loaded", ignoring potential warnings
  [[ "$output" == *"loaded" ]]
}
