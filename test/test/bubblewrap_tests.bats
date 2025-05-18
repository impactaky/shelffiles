#!/usr/bin/env bats

setup() {
  # Get the absolute path of the script directory
  SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  export SHELFFILES="$SCRIPT_DIR"
  export BWRAP_TEST_DIR="$SCRIPT_DIR/test/bwrap_test_dir"
  
  # Create a test directory for bubblewrap tests
  mkdir -p "$BWRAP_TEST_DIR"
  echo "test_content" > "$BWRAP_TEST_DIR/test_file.txt"
  
  # Set up test environment variables without sourcing env.sh
  # This avoids permission issues with directory creation
  export XDG_CONFIG_HOME="$SHELFFILES/config"
  export XDG_CACHE_HOME="$SHELFFILES/test/cache"
  export XDG_DATA_HOME="$SHELFFILES/test/share"
  export XDG_STATE_HOME="$SHELFFILES/test/state"
  
  # Create test directories
  mkdir -p "$XDG_CACHE_HOME"
  mkdir -p "$XDG_DATA_HOME"
  mkdir -p "$XDG_STATE_HOME"
  
  # Create a test nix directory
  mkdir -p "$SHELFFILES/nix"
}

teardown() {
  # Clean up test directories
  rm -rf "$BWRAP_TEST_DIR"
  rm -rf "$SHELFFILES/test/cache"
  rm -rf "$SHELFFILES/test/share"
  rm -rf "$SHELFFILES/test/state"
}

@test "bubblewrap is installed and executable" {
  command -v bwrap
  [ "$?" -eq 0 ]
}

@test "launch_in_bwrap.sh correctly mounts specified directory" {
  # Run a command in bubblewrap that accesses the mounted test directory
  run "$SHELFFILES/entrypoint/launch_in_bwrap.sh" cat "$BWRAP_TEST_DIR/test_file.txt"
  
  # For debugging
  echo "Status: $status"
  echo "Output: $output"
  
  # Verify the command executed successfully and returned the expected content
  [ "$status" -eq 0 ]
  [ "$output" = "test_content" ]
}

@test "bubblewrap provides process isolation" {
  # Create a temporary file outside the container
  TEMP_FILE="/tmp/bwrap_isolation_test_$(date +%s)"
  echo "outside_content" > "$TEMP_FILE"
  
  # Try to access this file from inside bubblewrap without explicitly mounting it
  run "$SHELFFILES/entrypoint/launch_in_bwrap.sh" cat "$TEMP_FILE"
  
  # Clean up
  rm -f "$TEMP_FILE"
  
  # Verify the file is not accessible (command should fail)
  [ "$status" -ne 0 ]
}

@test "bubblewrap correctly sets up environment variables" {
  # Define a test environment variable
  export BWRAP_TEST_VAR="test_value"
  
  # Check if the variable is accessible inside bubblewrap
  run "$SHELFFILES/entrypoint/launch_in_bwrap.sh" bash -c 'echo $BWRAP_TEST_VAR'
  
  # For debugging
  echo "Status: $status"
  echo "Output: $output"
  
  # Verify the environment variable is passed through
  [ "$status" -eq 0 ]
  [ "$output" = "test_value" ]
}

@test "bubblewrap mounts /nix directory correctly" {
  # Check if /nix directory is mounted correctly
  run "$SHELFFILES/entrypoint/launch_in_bwrap.sh" ls -la /nix
  
  # For debugging
  echo "Status: $status"
  echo "Output: $output"
  
  # Verify the command executed successfully
  [ "$status" -eq 0 ]
}
