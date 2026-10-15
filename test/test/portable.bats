#!/usr/bin/env bats

setup() {
  repo_root="$(CDPATH='' cd -- "$BATS_TEST_DIRNAME" && pwd -P)"
  while [ ! -d "$repo_root/entrypoint" ] && [ "$repo_root" != / ]; do
    repo_root="$(dirname -- "$repo_root")"
  done
  [ -d "$repo_root/entrypoint" ]
  test_root="$(mktemp -d /tmp/shelffiles-portable-test.XXXXXX)"
  checkout="$test_root/checkout"
  fake_bin="$test_root/bin"
  alias_token="$(printf '%04d' "$(((BATS_TEST_NUMBER * 97 + $$) % 10000))")"
  runtime_prefix="/tmp/a$alias_token"
  config_prefix="/tmp/b$alias_token"
  other_prefix="/tmp/c$alias_token"
  wrong_alias_target="/tmp/shelffiles-portable-wrong-$alias_token-$$"
  mkdir -p "$checkout" "$fake_bin"
  cp -a "$repo_root/entrypoint" "$repo_root/portable" "$repo_root/utils" "$checkout/"
}

teardown() {
  for alias_path in "$runtime_prefix" "$config_prefix" "$other_prefix"; do
    if [ -L "$alias_path" ]; then
      alias_target="$(readlink "$alias_path")"
      case "$alias_target" in
        "$checkout/portable/nix/store"|"$wrong_alias_target")
          rm -- "$alias_path"
          ;;
      esac
    elif [ -f "$alias_path" ] && [ "$(cat "$alias_path" 2>/dev/null)" = "$alias_token" ]; then
      rm -- "$alias_path"
    elif [ -d "$alias_path" ] && [ -f "$alias_path/$alias_token" ]; then
      rm -- "$alias_path/$alias_token"
      rmdir "$alias_path"
    fi
  done

  if [ -n "${result_path:-}" ] || [ -n "${dependency_path:-}" ]; then
    chmod -R u+w -- "${result_path:-/nonexistent}" \
      "${dependency_path:-/nonexistent}" 2>/dev/null || true
    rm -rf -- "${result_path:-/nonexistent}" "${dependency_path:-/nonexistent}"
  fi
  chmod -R u+w -- "$test_root" 2>/dev/null || true
  rm -rf -- "$test_root"
}

require_writable_nix_store() {
  mkdir -p /nix/store 2>/dev/null || skip 'requires an isolated writable /nix/store (provided by test/Dockerfile)'
  [ -w /nix/store ] || skip 'requires an isolated writable /nix/store (provided by test/Dockerfile)'
}

require_alias_available() {
  alias_path=$1
  if [ -e "$alias_path" ] || [ -L "$alias_path" ]; then
    skip "pre-existing $alias_path is left untouched"
  fi
}

create_export_fixture() {
  unique="${BATS_TEST_NUMBER}-$$"
  result_path="/nix/store/00000000000000000000000000000000-shelffiles-test-$unique"
  dependency_path="/nix/store/11111111111111111111111111111111-dependency-test-$unique"
  export FAKE_RESULT_PATH="$result_path"
  export FAKE_DEPENDENCY_PATH="$dependency_path"

  mkdir -p "$result_path/bin" "$dependency_path/lib"
  mkdir -p "$result_path/etc/ssl/certs"
  printf 'test CA bundle\n' >"$result_path/etc/ssl/certs/ca-bundle.crt"
  printf 'binary-prefix\0/nix/store\0binary-suffix\n' >"$dependency_path/lib/value"
  # shellcheck disable=SC2016
  printf '#!/bin/sh\nprintf "SHELL=%%s\\nPATH=%%s\\nSHELFFILES=%%s\\nSHELFFILES_ENV_FILE=%%s\\n" "$(basename "$0")" "$PATH" "$SHELFFILES" "${SHELFFILES_ENV_FILE-unset}"\n' \
    >"$result_path/bin/shell-template"
  # shellcheck disable=SC2016
  printf 'printf "SSL_CERT_FILE=%%s\\nNIX_SSL_CERT_FILE=%%s\\nSYSTEM_CERTIFICATE_PATH=%%s\\n" "${SSL_CERT_FILE-unset}" "${NIX_SSL_CERT_FILE-unset}" "${SYSTEM_CERTIFICATE_PATH-unset}"\\n[ -r "${SSL_CERT_FILE:-}" ] && printf "SSL_CERT_FILE_READABLE=yes\\n" || printf "SSL_CERT_FILE_READABLE=no\\n"\\n[ -r "${NIX_SSL_CERT_FILE:-}" ] && printf "NIX_SSL_CERT_FILE_READABLE=yes\\n" || printf "NIX_SSL_CERT_FILE_READABLE=no\\n"\\n[ -r "${SYSTEM_CERTIFICATE_PATH:-}" ] && printf "SYSTEM_CERTIFICATE_PATH_READABLE=yes\\n" || printf "SYSTEM_CERTIFICATE_PATH_READABLE=no\\n"\\n' >>"$result_path/bin/shell-template"
  chmod 0755 "$result_path/bin/shell-template"
  for shell_name in bash fish zsh; do
    cp -a "$result_path/bin/shell-template" "$result_path/bin/$shell_name"
  done
  ln -s "$dependency_path/lib/value" "$result_path/dependency-link"
  chmod -R a-w "$result_path" "$dependency_path"
  ln -s "$result_path" "$checkout/result"

  cat >"$fake_bin/nix-store" <<'EOF'
#!/bin/sh
if [ "$1" != --query ] || [ "$2" != --requisites ] || [ "$3" != "$FAKE_RESULT_PATH" ]; then
  printf 'unexpected nix-store invocation\n' >&2
  exit 2
fi
printf '%s\n' "$FAKE_DEPENDENCY_PATH" "$FAKE_RESULT_PATH"
EOF
  chmod 0755 "$fake_bin/nix-store"
}

donor_digest() {
  {
    find "$result_path" "$dependency_path" -type f -exec sha256sum {} \;
    find "$result_path" "$dependency_path" -type l -exec sh -c \
      'for link do printf "%s -> %s\\n" "$link" "$(readlink "$link")"; done' sh {} +
  } | LC_ALL=C sort | sha256sum
}

assert_default_certificates() {
  expected_ca=$1
  [[ "$output" == *"SSL_CERT_FILE=$expected_ca"* ]]
  [[ "$output" == *"NIX_SSL_CERT_FILE=$expected_ca"* ]]
  [[ "$output" == *"SYSTEM_CERTIFICATE_PATH=$expected_ca"* ]]
  [[ "$output" == *"SSL_CERT_FILE_READABLE=yes"* ]]
  [[ "$output" == *"NIX_SSL_CERT_FILE_READABLE=yes"* ]]
  [[ "$output" == *"SYSTEM_CERTIFICATE_PATH_READABLE=yes"* ]]
}

@test "portable certificate defaults use the readable portable result bundle for unset and empty values" {
  require_writable_nix_store
  require_alias_available "$runtime_prefix"
  create_export_fixture
  run env PATH="$fake_bin:$PATH" SHELFFILES_PORTABLE_PREFIX="$runtime_prefix" \
    "$checkout/utils/create_portable.sh"
  [ "$status" -eq 0 ]
  expected_ca="$checkout/portable/result/etc/ssl/certs/ca-bundle.crt"

  run env -u SSL_CERT_FILE -u NIX_SSL_CERT_FILE -u SYSTEM_CERTIFICATE_PATH \
    PATH="$fake_bin:$PATH" "$checkout/portable/entrypoint/bash"
  echo "$output"
  [ "$status" -eq 0 ]
  assert_default_certificates "$expected_ca"

  run env SSL_CERT_FILE= NIX_SSL_CERT_FILE= SYSTEM_CERTIFICATE_PATH= \
    PATH="$fake_bin:$PATH" "$checkout/portable/entrypoint/bash"
  echo "$output"
  [ "$status" -eq 0 ]
  assert_default_certificates "$expected_ca"
}

@test "portable certificate variables preserve each non-empty incoming value independently" {
  require_writable_nix_store
  require_alias_available "$runtime_prefix"
  create_export_fixture
  run env PATH="$fake_bin:$PATH" SHELFFILES_PORTABLE_PREFIX="$runtime_prefix" \
    "$checkout/utils/create_portable.sh"
  [ "$status" -eq 0 ]
  expected_ca="$checkout/portable/result/etc/ssl/certs/ca-bundle.crt"

  for preserved_variable in SSL_CERT_FILE NIX_SSL_CERT_FILE SYSTEM_CERTIFICATE_PATH; do
    custom_value="/caller/$preserved_variable.pem"
    run env -u SSL_CERT_FILE -u NIX_SSL_CERT_FILE -u SYSTEM_CERTIFICATE_PATH \
      "$preserved_variable=$custom_value" PATH="$fake_bin:$PATH" \
      "$checkout/portable/entrypoint/bash"
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

@test "environment-configured export rewrites and records the prefix without changing its donor" {
  require_writable_nix_store
  create_export_fixture
  donor_before="$(donor_digest)"
  printf 'keep entrypoint\n' >"$checkout/portable/entrypoint/sentinel"
  printf 'keep outside\n' >"$checkout/outside-sentinel"

  run env PATH="$fake_bin:$PATH" SHELFFILES_PORTABLE_PREFIX="$runtime_prefix" \
    "$checkout/utils/create_portable.sh"
  echo "$output"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Store paths copied: 2"* ]]
  [[ "$output" == *"Runtime prefix: $runtime_prefix"* ]]
  [ "$(donor_digest)" = "$donor_before" ]

  copied_result="$checkout/portable/nix/store/${result_path##*/}"
  copied_dependency="$checkout/portable/nix/store/${dependency_path##*/}"
  grep -aFq "$runtime_prefix" "$copied_dependency/lib/value"
  run grep -aFq /nix/store "$copied_dependency/lib/value"
  [ "$status" -ne 0 ]
  [ "$(readlink "$copied_result/dependency-link")" = "$runtime_prefix/${dependency_path##*/}/lib/value" ]
  [ "$(cat "$checkout/portable/nix/runtime-prefix")" = "$runtime_prefix" ]
  [ -x "$copied_result/bin/bash" ]
  [ "$(readlink "$checkout/portable/result")" = "nix/store/${result_path##*/}" ]
  [[ "$(readlink "$checkout/portable/result")" != /* ]]

  result_inode="$(stat -c %i "$copied_result")"
  dependency_inode="$(stat -c %i "$copied_dependency")"
  portable_before="$(find "$checkout/portable/nix/store" -type f -exec sha256sum {} \; | LC_ALL=C sort | sha256sum)"
  run env PATH="$fake_bin:$PATH" SHELFFILES_PORTABLE_PREFIX="$runtime_prefix" \
    "$checkout/utils/create_portable.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Store paths reused: 2"* ]]
  [[ "$output" == *"Store paths copied: 0"* ]]
  [[ "$output" == *"Store paths removed: 0"* ]]
  [ "$(stat -c %i "$copied_result")" = "$result_inode" ]
  [ "$(stat -c %i "$copied_dependency")" = "$dependency_inode" ]
  [ "$(find "$checkout/portable/nix/store" -type f -exec sha256sum {} \; | LC_ALL=C sort | sha256sum)" = "$portable_before" ]
  [ -f "$checkout/portable/entrypoint/sentinel" ]
  [ -f "$checkout/outside-sentinel" ]
  [ "$(donor_digest)" = "$donor_before" ]
}

@test "config fallback is unexported and process environment including empty takes precedence" {
  require_writable_nix_store
  create_export_fixture
  mkdir -p "$checkout/config"
  printf 'SHELFFILES_PORTABLE_PREFIX=%s\n' "$config_prefix" >"$checkout/config/shelffiles.conf"

  run env -u SHELFFILES_PORTABLE_PREFIX PATH="$fake_bin:$PATH" \
    "$checkout/utils/create_portable.sh"
  echo "$output"
  [ "$status" -eq 0 ]
  [ "$(cat "$checkout/portable/nix/runtime-prefix")" = "$config_prefix" ]

  run env PATH="$fake_bin:$PATH" SHELFFILES_PORTABLE_PREFIX="$runtime_prefix" \
    "$checkout/utils/create_portable.sh"
  echo "$output"
  [ "$status" -eq 0 ]
  [ "$(cat "$checkout/portable/nix/runtime-prefix")" = "$runtime_prefix" ]

  chmod u+w "$checkout/portable/nix"
  touch "$checkout/portable/nix/keep-after-empty"
  run env PATH="$fake_bin:$PATH" SHELFFILES_PORTABLE_PREFIX= \
    "$checkout/utils/create_portable.sh"
  echo "$output"
  [ "$status" -ne 0 ]
  [[ "$output" == *"must match /tmp/[A-Za-z0-9]{5}"* ]]
  [ -f "$checkout/portable/nix/keep-after-empty" ]
  [ "$(cat "$checkout/portable/nix/runtime-prefix")" = "$runtime_prefix" ]
}

@test "missing and invalid prefixes fail before replacing an existing export" {
  require_writable_nix_store
  create_export_fixture
  run env PATH="$fake_bin:$PATH" SHELFFILES_PORTABLE_PREFIX="$runtime_prefix" \
    "$checkout/utils/create_portable.sh"
  [ "$status" -eq 0 ]
  chmod u+w "$checkout/portable/nix"
  touch "$checkout/portable/nix/keep-after-invalid"
  result_target="$(readlink "$checkout/portable/result")"
  rm -f "$checkout/config/shelffiles.conf"

  run env -u SHELFFILES_PORTABLE_PREFIX PATH="$fake_bin:$PATH" \
    "$checkout/utils/create_portable.sh"
  echo "$output"
  [ "$status" -ne 0 ]
  [[ "$output" == *"SHELFFILES_PORTABLE_PREFIX is required"* ]]
  [ -f "$checkout/portable/nix/keep-after-invalid" ]
  [ "$(readlink "$checkout/portable/result")" = "$result_target" ]

  invalid_prefixes=(
    ''
    '/tmp/abcd'
    '/tmp/abcdef'
    '/tmp/ab_cd'
    '/tmp/ab cd'
    '/tmp/ab/12'
    'tmp/abcde'
    '/var/abcde'
    '/tmp/é1234'
  )
  for invalid_prefix in "${invalid_prefixes[@]}"; do
    run env PATH="$fake_bin:$PATH" SHELFFILES_PORTABLE_PREFIX="$invalid_prefix" \
      "$checkout/utils/create_portable.sh"
    echo "$output"
    [ "$status" -ne 0 ]
    [[ "$output" == *"must match /tmp/[A-Za-z0-9]{5}"* ]]
    [ -f "$checkout/portable/nix/keep-after-invalid" ]
    [ "$(cat "$checkout/portable/nix/runtime-prefix")" = "$runtime_prefix" ]
    [ "$(readlink "$checkout/portable/result")" = "$result_target" ]
  done
}

@test "residual source references fail before portable result is created" {
  require_writable_nix_store
  create_export_fixture
  donor_before="$(donor_digest)"
  cat >"$fake_bin/sed" <<'EOF'
#!/bin/sh
# Fault injection: report success without replacing bytes.
exit 0
EOF
  chmod 0755 "$fake_bin/sed"

  run env PATH="$fake_bin:$PATH" SHELFFILES_PORTABLE_PREFIX="$runtime_prefix" \
    "$checkout/utils/create_portable.sh"
  echo "$output"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Residual regular-file reference"* ]]
  [[ "$output" == *"residual /nix/store references remain"* ]]
  [ ! -e "$checkout/portable/result" ]
  [ ! -L "$checkout/portable/result" ]
  [ "$(donor_digest)" = "$donor_before" ]
}

@test "ordinary entrypoints stay ordinary and every portable wrapper uses the recorded prefix" {
  require_writable_nix_store
  require_alias_available "$runtime_prefix"
  require_alias_available "$config_prefix"
  require_alias_available "$other_prefix"
  create_export_fixture
  run env PATH="$fake_bin:$PATH" SHELFFILES_PORTABLE_PREFIX="$runtime_prefix" \
    "$checkout/utils/create_portable.sh"
  [ "$status" -eq 0 ]
  mkdir -p "$checkout/config"
  printf 'SHELFFILES_PORTABLE_PREFIX=%s\n' "$config_prefix" >"$checkout/config/shelffiles.conf"

  for shell_name in bash fish zsh; do
    run env PATH="$fake_bin:$PATH" SHELFFILES_PORTABLE_PREFIX="$other_prefix" \
      "$checkout/entrypoint/$shell_name"
    echo "$output"
    [ "$status" -eq 0 ]
    [[ "$output" == *":$checkout/result/bin:"* ]]
    [[ "$output" != *"$checkout/portable/result/bin"* ]]
  done

  expected_store="$checkout/portable/nix/store"
  for shell_name in bash fish zsh; do
    run env PATH="$fake_bin:$PATH" SHELFFILES_PORTABLE_PREFIX="$other_prefix" \
      "$checkout/portable/entrypoint/$shell_name"
    echo "$output"
    [ "$status" -eq 0 ]
    [ "$(readlink "$runtime_prefix")" = "$expected_store" ]
    [ ! -e "$config_prefix" ]
    [ ! -L "$config_prefix" ]
    [ ! -e "$other_prefix" ]
    [ ! -L "$other_prefix" ]
    [[ "$output" == *"PATH=$checkout/portable/result/bin:"* ]]
    [[ "$output" == *":$checkout/result/bin:"* ]]
    [[ "$output" == *"SHELFFILES_ENV_FILE=unset"* ]]
  done
}

@test "portable wrappers never fall back to bwrap when ordinary results are absent" {
  require_writable_nix_store
  require_alias_available "$runtime_prefix"
  create_export_fixture
  run env PATH="$fake_bin:$PATH" SHELFFILES_PORTABLE_PREFIX="$runtime_prefix" \
    "$checkout/utils/create_portable.sh"
  [ "$status" -eq 0 ]

  cat >"$checkout/entrypoint/launch_in_bwrap.sh" <<'EOF'
#!/bin/sh
printf 'BWRAP=%s\n' "$1"
exit 91
EOF
  chmod 0755 "$checkout/entrypoint/launch_in_bwrap.sh"
  rm -- "$checkout/result"

  for shell_name in bash fish zsh; do
    run env PATH="$fake_bin:$PATH" "$checkout/portable/entrypoint/$shell_name"
    echo "$output"
    [ "$status" -eq 0 ]
    [[ "$output" == *"SHELL=$shell_name"* ]]
    [[ "$output" != *"BWRAP="* ]]

    run env PATH="$fake_bin:$PATH" "$checkout/entrypoint/$shell_name"
    echo "$output"
    [ "$status" -eq 91 ]
    [[ "$output" == *"BWRAP=$shell_name"* ]]
  done
}

@test "configured portable alias conflicts retain status 73 and are never replaced" {
  require_writable_nix_store
  require_alias_available "$runtime_prefix"
  create_export_fixture
  run env PATH="$fake_bin:$PATH" SHELFFILES_PORTABLE_PREFIX="$runtime_prefix" \
    "$checkout/utils/create_portable.sh"
  [ "$status" -eq 0 ]

  ln -s "$wrong_alias_target" "$runtime_prefix"
  run env PATH="$fake_bin:$PATH" "$checkout/portable/entrypoint/bash"
  echo "$output"
  [ "$status" -eq 73 ]
  [ "$(readlink "$runtime_prefix")" = "$wrong_alias_target" ]
  rm -- "$runtime_prefix"

  printf %s "$alias_token" >"$runtime_prefix"
  run env PATH="$fake_bin:$PATH" "$checkout/portable/entrypoint/bash"
  echo "$output"
  [ "$status" -eq 73 ]
  [ "$(cat "$runtime_prefix")" = "$alias_token" ]
  rm -- "$runtime_prefix"

  mkdir "$runtime_prefix"
  touch "$runtime_prefix/$alias_token"
  run env PATH="$fake_bin:$PATH" "$checkout/portable/entrypoint/bash"
  echo "$output"
  [ "$status" -eq 73 ]
  [ -f "$runtime_prefix/$alias_token" ]
}

@test "missing malformed and invalid prefix metadata prevent alias creation and shell launch" {
  require_writable_nix_store
  require_alias_available "$runtime_prefix"
  create_export_fixture
  run env PATH="$fake_bin:$PATH" SHELFFILES_PORTABLE_PREFIX="$runtime_prefix" \
    "$checkout/utils/create_portable.sh"
  [ "$status" -eq 0 ]
  metadata="$checkout/portable/nix/runtime-prefix"
  chmod u+w "$checkout/portable/nix"
  rm -- "$metadata"

  run env PATH="$fake_bin:$PATH" SHELFFILES_PORTABLE_PREFIX="$other_prefix" \
    "$checkout/portable/entrypoint/bash"
  echo "$output"
  [ "$status" -ne 0 ]
  [[ "$output" == *"runtime prefix metadata is missing"* ]]
  [[ "$output" != *"SHELL=bash"* ]]
  [ ! -e "$runtime_prefix" ]
  [ ! -L "$runtime_prefix" ]

  printf '/tmp/abcd\n' >"$metadata"
  run env PATH="$fake_bin:$PATH" "$checkout/portable/entrypoint/bash"
  echo "$output"
  [ "$status" -ne 0 ]
  [[ "$output" == *"metadata must match /tmp/[A-Za-z0-9]{5}"* ]]
  [[ "$output" != *"SHELL=bash"* ]]
  [ ! -e "$runtime_prefix" ]
  [ ! -L "$runtime_prefix" ]

  printf '%s\n%s\n' "$runtime_prefix" "$other_prefix" >"$metadata"
  run env PATH="$fake_bin:$PATH" "$checkout/portable/entrypoint/bash"
  echo "$output"
  [ "$status" -ne 0 ]
  [[ "$output" == *"metadata must contain exactly one line"* ]]
  [[ "$output" != *"SHELL=bash"* ]]
  [ ! -e "$runtime_prefix" ]
  [ ! -L "$runtime_prefix" ]
}

@test "ordinary entrypoints continue when ordinary user environment returns nonzero" {
  require_writable_nix_store
  create_export_fixture
  printf 'return 42\n' >"$checkout/user_env.sh"

  for shell_name in bash fish zsh; do
    run env PATH="$fake_bin:$PATH" "$checkout/entrypoint/$shell_name"
    echo "$output"
    [ "$status" -eq 0 ]
    [[ "$output" == *"SHELL=$shell_name"* ]]
    [[ "$output" == *"SHELFFILES_ENV_FILE=unset"* ]]
  done
}

@test "portable wrappers reject a missing broken or misplaced result before launch" {
  require_writable_nix_store
  require_alias_available "$runtime_prefix"
  create_export_fixture
  run env PATH="$fake_bin:$PATH" SHELFFILES_PORTABLE_PREFIX="$runtime_prefix" \
    "$checkout/utils/create_portable.sh"
  [ "$status" -eq 0 ]

  rm -- "$checkout/portable/result"
  run env PATH="$fake_bin:$PATH" "$checkout/portable/entrypoint/bash"
  echo "$output"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Portable result is missing or broken"* ]]
  [[ "$output" != *"SHELL=bash"* ]]
  [ ! -e "$runtime_prefix" ]
  [ ! -L "$runtime_prefix" ]

  ln -s nix/store/missing-result "$checkout/portable/result"
  run env PATH="$fake_bin:$PATH" "$checkout/portable/entrypoint/bash"
  echo "$output"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Portable result is missing or broken"* ]]
  [[ "$output" != *"SHELL=bash"* ]]
  [ ! -e "$runtime_prefix" ]
  [ ! -L "$runtime_prefix" ]

  rm -- "$checkout/portable/result"
  ln -s ../result "$checkout/portable/result"
  run env PATH="$fake_bin:$PATH" "$checkout/portable/entrypoint/bash"
  echo "$output"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Portable result resolves outside the portable store"* ]]
  [[ "$output" != *"SHELL=bash"* ]]
  [ ! -e "$runtime_prefix" ]
  [ ! -L "$runtime_prefix" ]
}
