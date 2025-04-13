#!/usr/bin/env bats

setup() {
  # Clear environment variables that might affect the test (optional)
  unset SHELFFILES_ZSH_TEST
}

@test "entrypoint/zsh loads config/zsh/.zshrc implicitly via ZDOTDIR" {
  run ./entrypoint/zsh -i -c 'echo $SHELFFILES_ZSH_TEST'

  # For debugging
  echo "Status: $status"
  echo "Output: $output"

  # Check if the command sequence executed successfully (status 0)
  [ "$status" -eq 0 ]

  [[ "$output" == "loaded" ]]
}
