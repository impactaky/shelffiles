#!/usr/bin/env bats

setup() {
  repo_root="$(CDPATH='' cd -- "$BATS_TEST_DIRNAME" && pwd)"
  while [ ! -d "$repo_root/entrypoint" ] && [ "$repo_root" != / ]; do
    repo_root="$(dirname -- "$repo_root")"
  done
  [ -d "$repo_root/entrypoint" ]
  expected_ca="$repo_root/result/etc/ssl/certs/ca-bundle.crt"
  # shellcheck disable=SC2016
  certificate_probe='printf "SSL_CERT_FILE=%s\\nNIX_SSL_CERT_FILE=%s\\nSYSTEM_CERTIFICATE_PATH=%s\\n" "$SSL_CERT_FILE" "$NIX_SSL_CERT_FILE" "$SYSTEM_CERTIFICATE_PATH"; [ -r "$SSL_CERT_FILE" ] && printf "SSL_CERT_FILE_READABLE=yes\\n"; [ -r "$NIX_SSL_CERT_FILE" ] && printf "NIX_SSL_CERT_FILE_READABLE=yes\\n"; [ -r "$SYSTEM_CERTIFICATE_PATH" ] && printf "SYSTEM_CERTIFICATE_PATH_READABLE=yes\\n"'
}

assert_default_certificate_output() {
  [[ "$output" == *"SSL_CERT_FILE=$expected_ca"* ]]
  [[ "$output" == *"NIX_SSL_CERT_FILE=$expected_ca"* ]]
  [[ "$output" == *"SYSTEM_CERTIFICATE_PATH=$expected_ca"* ]]
  [[ "$output" == *"SSL_CERT_FILE_READABLE=yes"* ]]
  [[ "$output" == *"NIX_SSL_CERT_FILE_READABLE=yes"* ]]
  [[ "$output" == *"SYSTEM_CERTIFICATE_PATH_READABLE=yes"* ]]
}

@test "ordinary certificate defaults use the readable built result bundle for unset and empty values" {
  [ -r "$expected_ca" ]

  run env -u SSL_CERT_FILE -u NIX_SSL_CERT_FILE -u SYSTEM_CERTIFICATE_PATH \
    "$repo_root/entrypoint/bash" -c "$certificate_probe"
  echo "$output"
  [ "$status" -eq 0 ]
  assert_default_certificate_output

  run env SSL_CERT_FILE= NIX_SSL_CERT_FILE= SYSTEM_CERTIFICATE_PATH= \
    "$repo_root/entrypoint/bash" -c "$certificate_probe"
  echo "$output"
  [ "$status" -eq 0 ]
  assert_default_certificate_output
}

@test "ordinary certificate variables preserve each non-empty incoming value independently" {
  for preserved_variable in SSL_CERT_FILE NIX_SSL_CERT_FILE SYSTEM_CERTIFICATE_PATH; do
    custom_value="/caller/$preserved_variable.pem"
    # shellcheck disable=SC2016
    run env -u SSL_CERT_FILE -u NIX_SSL_CERT_FILE -u SYSTEM_CERTIFICATE_PATH \
      "$preserved_variable=$custom_value" "$repo_root/entrypoint/bash" -c \
      'printf "SSL_CERT_FILE=%s\\nNIX_SSL_CERT_FILE=%s\\nSYSTEM_CERTIFICATE_PATH=%s\\n" "$SSL_CERT_FILE" "$NIX_SSL_CERT_FILE" "$SYSTEM_CERTIFICATE_PATH"'
    echo "$output"
    [ "$status" -eq 0 ]

    case "$preserved_variable" in
      SSL_CERT_FILE)
        [[ "$output" == *"SSL_CERT_FILE=$custom_value"* ]]
        [[ "$output" == *"NIX_SSL_CERT_FILE=$expected_ca"* ]]
        [[ "$output" == *"SYSTEM_CERTIFICATE_PATH=$expected_ca"* ]]
        ;;
      NIX_SSL_CERT_FILE)
        [[ "$output" == *"SSL_CERT_FILE=$expected_ca"* ]]
        [[ "$output" == *"NIX_SSL_CERT_FILE=$custom_value"* ]]
        [[ "$output" == *"SYSTEM_CERTIFICATE_PATH=$expected_ca"* ]]
        ;;
      SYSTEM_CERTIFICATE_PATH)
        [[ "$output" == *"SSL_CERT_FILE=$expected_ca"* ]]
        [[ "$output" == *"NIX_SSL_CERT_FILE=$expected_ca"* ]]
        [[ "$output" == *"SYSTEM_CERTIFICATE_PATH=$custom_value"* ]]
        ;;
    esac
  done
}
