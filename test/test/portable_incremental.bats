#!/usr/bin/env bats

setup() {
  repo_root="$(CDPATH='' cd -- "$BATS_TEST_DIRNAME" && pwd -P)"
  while [ ! -d "$repo_root/entrypoint" ] && [ "$repo_root" != / ]; do
    repo_root="$(dirname -- "$repo_root")"
  done
  [ -d "$repo_root/entrypoint" ]

  test_root="$(mktemp -d /tmp/shelffiles-portable-incremental.XXXXXX)"
  checkout="$test_root/checkout"
  fake_bin="$test_root/bin"
  closure_file="$test_root/closure"
  unique="${BATS_TEST_NUMBER}-$$"
  token="$(printf '%04d' "$(((BATS_TEST_NUMBER * 193 + $$) % 10000))")"
  runtime_prefix="/tmp/d$token"
  config_prefix="/tmp/e$token"
  other_prefix="/tmp/f$token"
  result_path="/nix/store/00000000000000000000000000000000-incremental-result-$unique"
  dependency_path="/nix/store/11111111111111111111111111111111-incremental-dependency-$unique"
  changed_result_path="/nix/store/22222222222222222222222222222222-incremental-result-$unique"
  extra_path="/nix/store/33333333333333333333333333333333-incremental-extra-$unique"

  mkdir -p "$checkout" "$fake_bin"
  cp -a "$repo_root/entrypoint" "$repo_root/portable" "$repo_root/utils" "$checkout/"
}

teardown() {
  chmod -R u+w -- "$result_path" "$dependency_path" "$changed_result_path" \
    "$extra_path" "$test_root" 2>/dev/null || true
  rm -rf -- "$result_path" "$dependency_path" "$changed_result_path" \
    "$extra_path" "$test_root"
}

require_writable_nix_store() {
  mkdir -p /nix/store 2>/dev/null || skip 'requires an isolated writable /nix/store (provided by test/Dockerfile)'
  [ -w /nix/store ] || skip 'requires an isolated writable /nix/store (provided by test/Dockerfile)'
}

set_closure() {
  printf '%s\n' "$@" >"$closure_file"
}

create_fixture() {
  mkdir -p "$result_path/bin" "$result_path/etc/ssl/certs" "$dependency_path/lib"
  printf 'test CA bundle\n' >"$result_path/etc/ssl/certs/ca-bundle.crt"
  printf 'before\0/nix/store\0after\n' >"$dependency_path/lib/value"
  printf '#!/bin/sh\nprintf "portable fixture\\n"\n' >"$result_path/bin/bash"
  chmod 0755 "$result_path/bin/bash"
  ln -s "$dependency_path/lib/value" "$result_path/dependency-link"
  chmod -R a-w "$result_path" "$dependency_path"
  ln -s "$result_path" "$checkout/result"
  set_closure "$dependency_path" "$result_path"
  export FAKE_RESULT_PATH="$result_path"
  export FAKE_CLOSURE_FILE="$closure_file"

  cat >"$fake_bin/nix-store" <<'EOF'
#!/bin/sh
if [ "$1" != --query ] || [ "$2" != --requisites ] || [ "$3" != "$FAKE_RESULT_PATH" ]; then
  printf 'unexpected nix-store invocation\n' >&2
  exit 2
fi
cat "$FAKE_CLOSURE_FILE"
EOF
  chmod 0755 "$fake_bin/nix-store"
}

create_changed_result() {
  mkdir -p "$changed_result_path/bin" "$extra_path/lib"
  cp -a "$result_path/bin/bash" "$changed_result_path/bin/bash"
  printf 'new\0/nix/store\0dependency\n' >"$extra_path/lib/value"
  ln -s "$dependency_path/lib/value" "$changed_result_path/common-link"
  ln -s "$extra_path/lib/value" "$changed_result_path/extra-link"
  chmod -R a-w "$changed_result_path" "$extra_path"
  rm "$checkout/result"
  ln -s "$changed_result_path" "$checkout/result"
  set_closure "$dependency_path" "$changed_result_path" "$extra_path"
  export FAKE_RESULT_PATH="$changed_result_path"
}

assert_counts() {
  reused=$1
  copied=$2
  removed=$3
  [[ "$output" == *"Store paths reused: $reused"* ]]
  [[ "$output" == *"Store paths copied: $copied"* ]]
  [[ "$output" == *"Store paths removed: $removed"* ]]
}

@test "successful environment prefix persistence preserves config and becomes the next-run default" {
  require_writable_nix_store
  create_fixture
  mkdir -p "$checkout/config"
  printf '# keep this comment\nOTHER_SETTING=value\nSHELFFILES_PORTABLE_PREFIX=%s\n' \
    "$config_prefix" >"$checkout/config/shelffiles.conf"

  run env PATH="$fake_bin:$PATH" SHELFFILES_PORTABLE_PREFIX="$runtime_prefix" \
    "$checkout/utils/create_portable.sh"
  echo "$output"
  [ "$status" -eq 0 ]
  assert_counts 0 2 0
  grep -Fx '# keep this comment' "$checkout/config/shelffiles.conf"
  grep -Fx 'OTHER_SETTING=value' "$checkout/config/shelffiles.conf"
  grep -Fx "SHELFFILES_PORTABLE_PREFIX=$config_prefix" "$checkout/config/shelffiles.conf"
  grep -Fx "SHELFFILES_PORTABLE_PREFIX=$runtime_prefix # managed by utils/create_portable.sh" \
    "$checkout/config/shelffiles.conf"
  [ "$(grep -Fc '# managed by utils/create_portable.sh' "$checkout/config/shelffiles.conf")" -eq 1 ]

  config_before="$(sha256sum "$checkout/config/shelffiles.conf")"
  run env -u SHELFFILES_PORTABLE_PREFIX PATH="$fake_bin:$PATH" \
    "$checkout/utils/create_portable.sh"
  echo "$output"
  [ "$status" -eq 0 ]
  assert_counts 2 0 0
  [ "$(sha256sum "$checkout/config/shelffiles.conf")" = "$config_before" ]

  run env PATH="$fake_bin:$PATH" SHELFFILES_PORTABLE_PREFIX="$other_prefix" \
    "$checkout/utils/create_portable.sh"
  [ "$status" -eq 0 ]
  [ "$(grep -Fc '# managed by utils/create_portable.sh' "$checkout/config/shelffiles.conf")" -eq 1 ]
  grep -Fx "SHELFFILES_PORTABLE_PREFIX=$other_prefix # managed by utils/create_portable.sh" \
    "$checkout/config/shelffiles.conf"

  config_before="$(sha256sum "$checkout/config/shelffiles.conf")"
  run env PATH="$fake_bin:$PATH" SHELFFILES_PORTABLE_PREFIX= \
    "$checkout/utils/create_portable.sh"
  [ "$status" -ne 0 ]
  [ "$(sha256sum "$checkout/config/shelffiles.conf")" = "$config_before" ]
}

@test "config install failure warns after committing the export" {
  require_writable_nix_store
  create_fixture
  run env PATH="$fake_bin:$PATH" SHELFFILES_PORTABLE_PREFIX="$runtime_prefix" \
    "$checkout/utils/create_portable.sh"
  [ "$status" -eq 0 ]
  config_before="$(sha256sum "$checkout/config/shelffiles.conf")"

  real_mv="$(command -v mv)"
  cat >"$fake_bin/mv" <<'EOF'
#!/bin/sh
destination=
for argument do
  destination=$argument
done
if [ "$destination" = "$FAIL_MV_DESTINATION" ]; then
  exit 93
fi
exec "$REAL_MV" "$@"
EOF
  chmod 0755 "$fake_bin/mv"

  run env PATH="$fake_bin:$PATH" SHELFFILES_PORTABLE_PREFIX="$other_prefix" \
    FAIL_MV_DESTINATION="$checkout/config/shelffiles.conf" REAL_MV="$real_mv" \
    "$checkout/utils/create_portable.sh"
  echo "$output"
  [ "$status" -eq 0 ]
  [[ "$output" == *"export completed but prefix configuration could not be saved"* ]]
  [ "$(cat "$checkout/portable/nix/runtime-prefix")" = "$other_prefix" ]
  [ "$(sha256sum "$checkout/config/shelffiles.conf")" = "$config_before" ]
  [ -z "$(find "$checkout/config" -maxdepth 1 -name '.shelffiles.conf.shelffiles-portable-tmp.*' -print -quit)" ]
}

@test "exact rerun neither copies rewrites nor recursively scans reused entries" {
  require_writable_nix_store
  create_fixture
  run env PATH="$fake_bin:$PATH" SHELFFILES_PORTABLE_PREFIX="$runtime_prefix" \
    "$checkout/utils/create_portable.sh"
  [ "$status" -eq 0 ]
  copied_result="$checkout/portable/nix/store/${result_path##*/}"
  copied_dependency="$checkout/portable/nix/store/${dependency_path##*/}"
  result_inode="$(stat -c %i "$copied_result")"
  dependency_inode="$(stat -c %i "$copied_dependency")"
  real_find="$(command -v find)"

  cat >"$fake_bin/cp" <<'EOF'
#!/bin/sh
printf 'unexpected copy during reuse\n' >&2
exit 90
EOF
  cat >"$fake_bin/sed" <<'EOF'
#!/bin/sh
printf 'unexpected rewrite during reuse\n' >&2
exit 91
EOF
  cat >"$fake_bin/find" <<'EOF'
#!/bin/sh
for argument do
  if [ "$argument" = "$FORBIDDEN_RESULT" ] || [ "$argument" = "$FORBIDDEN_DEPENDENCY" ]; then
    printf 'unexpected recursive scan of reused entry\n' >&2
    exit 92
  fi
done
exec "$REAL_FIND" "$@"
EOF
  chmod 0755 "$fake_bin/cp" "$fake_bin/sed" "$fake_bin/find"
  metadata="$checkout/portable/nix/runtime-prefix"
  chmod u+w "$metadata"

  run env -u SHELFFILES_PORTABLE_PREFIX PATH="$fake_bin:$PATH" \
    FORBIDDEN_RESULT="$copied_result" FORBIDDEN_DEPENDENCY="$copied_dependency" \
    REAL_FIND="$real_find" \
    "$checkout/utils/create_portable.sh"
  echo "$output"
  [ "$status" -eq 0 ]
  assert_counts 2 0 0
  [ "$(stat -c %i "$copied_result")" = "$result_inode" ]
  [ "$(stat -c %i "$copied_dependency")" = "$dependency_inode" ]
  metadata_mode="$(stat -c %a "$metadata")"
  [ "$((8#$metadata_mode & 0222))" -eq 0 ]
}

@test "partial writable chmod failure restores the prior artifact permissions" {
  require_writable_nix_store
  create_fixture
  run env PATH="$fake_bin:$PATH" SHELFFILES_PORTABLE_PREFIX="$runtime_prefix" \
    "$checkout/utils/create_portable.sh"
  [ "$status" -eq 0 ]

  real_chmod="$(command -v chmod)"
  cat >"$fake_bin/chmod" <<'EOF'
#!/bin/sh
if [ "$1" = u+w ] && [ "$2" = -- ] && [ "$3" = "$FAIL_NIX" ] &&
  [ "$4" = "$FAIL_STORE" ]; then
  "$REAL_CHMOD" u+w -- "$FAIL_NIX"
  exit 92
fi
exec "$REAL_CHMOD" "$@"
EOF
  chmod 0755 "$fake_bin/chmod"

  run env -u SHELFFILES_PORTABLE_PREFIX PATH="$fake_bin:$PATH" \
    FAIL_NIX="$checkout/portable/nix" FAIL_STORE="$checkout/portable/nix/store" \
    REAL_CHMOD="$real_chmod" "$checkout/utils/create_portable.sh"
  echo "$output"
  [ "$status" -ne 0 ]
  nix_mode="$(stat -c %a "$checkout/portable/nix")"
  store_mode="$(stat -c %a "$checkout/portable/nix/store")"
  [ "$((8#$nix_mode & 0222))" -eq 0 ]
  [ "$((8#$store_mode & 0222))" -eq 0 ]
}

@test "changed result reuses common paths and prunes stale paths after completion" {
  require_writable_nix_store
  create_fixture
  run env PATH="$fake_bin:$PATH" SHELFFILES_PORTABLE_PREFIX="$runtime_prefix" \
    "$checkout/utils/create_portable.sh"
  [ "$status" -eq 0 ]
  dependency_inode="$(stat -c %i "$checkout/portable/nix/store/${dependency_path##*/}")"
  create_changed_result

  run env -u SHELFFILES_PORTABLE_PREFIX PATH="$fake_bin:$PATH" \
    "$checkout/utils/create_portable.sh"
  echo "$output"
  [ "$status" -eq 0 ]
  assert_counts 1 2 1
  [ "$(stat -c %i "$checkout/portable/nix/store/${dependency_path##*/}")" = "$dependency_inode" ]
  [ ! -e "$checkout/portable/nix/store/${result_path##*/}" ]
  [ "$(readlink "$checkout/portable/result")" = "nix/store/${changed_result_path##*/}" ]
  grep -aFq "$runtime_prefix" "$checkout/portable/nix/store/${extra_path##*/}/lib/value"
}

@test "post-commit prune failure warns and a later run removes the stale entry" {
  require_writable_nix_store
  create_fixture
  run env PATH="$fake_bin:$PATH" SHELFFILES_PORTABLE_PREFIX="$runtime_prefix" \
    "$checkout/utils/create_portable.sh"
  [ "$status" -eq 0 ]
  create_changed_result

  real_rm="$(command -v rm)"
  stale_path="$checkout/portable/nix/store/${result_path##*/}"
  failure_marker="$test_root/prune-failed"
  cat >"$fake_bin/rm" <<'EOF'
#!/bin/sh
for argument do
  if [ "$argument" = "$FAIL_RM_PATH" ] && [ ! -e "$FAILURE_MARKER" ]; then
    : >"$FAILURE_MARKER"
    exit 98
  fi
done
exec "$REAL_RM" "$@"
EOF
  chmod 0755 "$fake_bin/rm"

  run env -u SHELFFILES_PORTABLE_PREFIX PATH="$fake_bin:$PATH" \
    FAIL_RM_PATH="$stale_path" FAILURE_MARKER="$failure_marker" REAL_RM="$real_rm" \
    "$checkout/utils/create_portable.sh"
  echo "$output"
  [ "$status" -eq 0 ]
  [[ "$output" == *"warning: could not remove stale store path"* ]]
  [ "$(readlink "$checkout/portable/result")" = "nix/store/${changed_result_path##*/}" ]
  [ -e "$stale_path" ]
  [ -z "$(find "$stale_path" ! -type l -perm /222 -print -quit)" ]

  rm "$fake_bin/rm"
  run env -u SHELFFILES_PORTABLE_PREFIX PATH="$fake_bin:$PATH" \
    "$checkout/utils/create_portable.sh"
  echo "$output"
  [ "$status" -eq 0 ]
  assert_counts 3 0 1
  [ ! -e "$stale_path" ]
}

@test "post-commit permission restoration failure warns without reverting the new result" {
  require_writable_nix_store
  create_fixture
  run env PATH="$fake_bin:$PATH" SHELFFILES_PORTABLE_PREFIX="$runtime_prefix" \
    "$checkout/utils/create_portable.sh"
  [ "$status" -eq 0 ]
  create_changed_result

  real_chmod="$(command -v chmod)"
  failure_marker="$test_root/final-chmod-failed"
  cat >"$fake_bin/chmod" <<'EOF'
#!/bin/sh
if [ "$1" = a-w ] && [ "$2" = -- ] && [ "$3" = "$FAIL_STORE" ] &&
  [ "$4" = "$FAIL_NIX" ] &&
  [ ! -e "$FAILURE_MARKER" ]; then
  : >"$FAILURE_MARKER"
  exit 95
fi
exec "$REAL_CHMOD" "$@"
EOF
  chmod 0755 "$fake_bin/chmod"

  run env -u SHELFFILES_PORTABLE_PREFIX PATH="$fake_bin:$PATH" \
    FAIL_STORE="$checkout/portable/nix/store" FAIL_NIX="$checkout/portable/nix" \
    FAILURE_MARKER="$failure_marker" REAL_CHMOD="$real_chmod" \
    "$checkout/utils/create_portable.sh"
  echo "$output"
  [ "$status" -eq 0 ]
  [[ "$output" == *"new result is active but generated directory permissions could not be restored"* ]]
  [ "$(readlink "$checkout/portable/result")" = "nix/store/${changed_result_path##*/}" ]
  [ ! -e "$checkout/portable/nix/store/${result_path##*/}" ]
}

@test "store enumeration failure before incremental commit preserves the selected result" {
  require_writable_nix_store
  create_fixture
  run env PATH="$fake_bin:$PATH" SHELFFILES_PORTABLE_PREFIX="$runtime_prefix" \
    "$checkout/utils/create_portable.sh"
  [ "$status" -eq 0 ]
  previous_target="$(readlink "$checkout/portable/result")"
  stale_path="$checkout/portable/nix/store/${result_path##*/}"
  create_changed_result

  real_find="$(command -v find)"
  cat >"$fake_bin/find" <<'EOF'
#!/bin/sh
saw_name=0
for argument do
  [ "$argument" = -name ] && saw_name=1
done
if [ "$1" = "$FAIL_STORE" ] && [ "$saw_name" -eq 0 ]; then
  exit 94
fi
exec "$REAL_FIND" "$@"
EOF
  chmod 0755 "$fake_bin/find"

  run env -u SHELFFILES_PORTABLE_PREFIX PATH="$fake_bin:$PATH" \
    FAIL_STORE="$checkout/portable/nix/store" REAL_FIND="$real_find" \
    "$checkout/utils/create_portable.sh"
  echo "$output"
  [ "$status" -ne 0 ]
  [[ "$output" == *"could not enumerate portable store before result switch"* ]]
  [ "$(readlink "$checkout/portable/result")" = "$previous_target" ]
  [ -e "$stale_path" ]
}

@test "prefix changes and force rebuild every store entry" {
  require_writable_nix_store
  create_fixture
  run env PATH="$fake_bin:$PATH" SHELFFILES_PORTABLE_PREFIX="$runtime_prefix" \
    "$checkout/utils/create_portable.sh"
  [ "$status" -eq 0 ]
  old_inode="$(stat -c %i "$checkout/portable/nix/store/${dependency_path##*/}")"

  run env PATH="$fake_bin:$PATH" SHELFFILES_PORTABLE_PREFIX="$other_prefix" \
    "$checkout/utils/create_portable.sh"
  echo "$output"
  [ "$status" -eq 0 ]
  assert_counts 0 2 2
  [ "$(cat "$checkout/portable/nix/runtime-prefix")" = "$other_prefix" ]
  metadata_mode="$(stat -c %a "$checkout/portable/nix/runtime-prefix")"
  [ "$((8#$metadata_mode & 0222))" -eq 0 ]
  grep -aFq "$other_prefix" "$checkout/portable/nix/store/${dependency_path##*/}/lib/value"
  run grep -aFq "$runtime_prefix" "$checkout/portable/nix/store/${dependency_path##*/}/lib/value"
  [ "$status" -ne 0 ]
  [ "$(stat -c %i "$checkout/portable/nix/store/${dependency_path##*/}")" != "$old_inode" ]

  old_inode="$(stat -c %i "$checkout/portable/nix/store/${dependency_path##*/}")"
  run env -u SHELFFILES_PORTABLE_PREFIX PATH="$fake_bin:$PATH" \
    "$checkout/utils/create_portable.sh" --force
  echo "$output"
  [ "$status" -eq 0 ]
  assert_counts 0 2 2
  [ "$(stat -c %i "$checkout/portable/nix/store/${dependency_path##*/}")" != "$old_inode" ]
}

@test "unknown and extra arguments fail before export or config mutation" {
  require_writable_nix_store
  create_fixture
  run env PATH="$fake_bin:$PATH" SHELFFILES_PORTABLE_PREFIX="$runtime_prefix" \
    "$checkout/utils/create_portable.sh"
  [ "$status" -eq 0 ]
  config_before="$(sha256sum "$checkout/config/shelffiles.conf")"
  result_target="$(readlink "$checkout/portable/result")"
  dependency_inode="$(stat -c %i "$checkout/portable/nix/store/${dependency_path##*/}")"

  run env PATH="$fake_bin:$PATH" SHELFFILES_PORTABLE_PREFIX="$other_prefix" \
    "$checkout/utils/create_portable.sh" --unknown
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown argument"* ]]
  run env PATH="$fake_bin:$PATH" SHELFFILES_PORTABLE_PREFIX="$other_prefix" \
    "$checkout/utils/create_portable.sh" --force extra
  [ "$status" -ne 0 ]
  [[ "$output" == *"usage:"* ]]

  [ "$(sha256sum "$checkout/config/shelffiles.conf")" = "$config_before" ]
  [ "$(readlink "$checkout/portable/result")" = "$result_target" ]
  [ "$(stat -c %i "$checkout/portable/nix/store/${dependency_path##*/}")" = "$dependency_inode" ]
}

@test "failed incremental update preserves the prior export and later removes temporary entries" {
  require_writable_nix_store
  create_fixture
  run env PATH="$fake_bin:$PATH" SHELFFILES_PORTABLE_PREFIX="$runtime_prefix" \
    "$checkout/utils/create_portable.sh"
  [ "$status" -eq 0 ]
  result_target="$(readlink "$checkout/portable/result")"
  config_before="$(sha256sum "$checkout/config/shelffiles.conf")"

  mkdir -p "$extra_path/lib"
  printf 'still /nix/store here\n' >"$extra_path/lib/value"
  chmod -R a-w "$extra_path"
  set_closure "$dependency_path" "$result_path" "$extra_path"
  cat >"$fake_bin/sed" <<'EOF'
#!/bin/sh
# Fault injection: report success without replacing bytes.
exit 0
EOF
  chmod 0755 "$fake_bin/sed"

  run env -u SHELFFILES_PORTABLE_PREFIX PATH="$fake_bin:$PATH" \
    "$checkout/utils/create_portable.sh"
  echo "$output"
  [ "$status" -ne 0 ]
  [[ "$output" == *"residual /nix/store references remain"* ]]
  [ "$(readlink "$checkout/portable/result")" = "$result_target" ]
  [ -d "$checkout/portable/nix/store/${result_path##*/}" ]
  [ ! -e "$checkout/portable/nix/store/${extra_path##*/}" ]
  [ "$(sha256sum "$checkout/config/shelffiles.conf")" = "$config_before" ]
  [ -z "$(find "$checkout/portable/nix/store" -maxdepth 1 -name '.shelffiles-portable-tmp.*' -print -quit)" ]

  rm "$fake_bin/sed"
  chmod u+w "$checkout/portable/nix" "$checkout/portable/nix/store"
  interrupted="$checkout/portable/nix/store/.shelffiles-portable-tmp.interrupted"
  interrupted_staging="$checkout/portable/.nix.shelffiles-portable-tmp.interrupted"
  mkdir "$interrupted"
  mkdir "$interrupted_staging"
  printf 'partial\n' >"$interrupted/value"
  printf 'partial\n' >"$interrupted_staging/value"
  chmod -R a-w "$interrupted"
  chmod -R a-w "$interrupted_staging"
  chmod a-w "$checkout/portable/nix/store" "$checkout/portable/nix"
  set_closure "$dependency_path" "$result_path"

  run env -u SHELFFILES_PORTABLE_PREFIX PATH="$fake_bin:$PATH" \
    "$checkout/utils/create_portable.sh"
  [ "$status" -eq 0 ]
  assert_counts 2 0 0
  [ ! -e "$interrupted" ]
  [ ! -e "$interrupted_staging" ]
}

@test "enumeration and grep errors never publish a copied store entry" {
  require_writable_nix_store
  create_fixture
  run env PATH="$fake_bin:$PATH" SHELFFILES_PORTABLE_PREFIX="$runtime_prefix" \
    "$checkout/utils/create_portable.sh"
  [ "$status" -eq 0 ]
  result_target="$(readlink "$checkout/portable/result")"

  mkdir -p "$extra_path/lib"
  printf 'new /nix/store reference\n' >"$extra_path/lib/value"
  chmod -R a-w "$extra_path"
  set_closure "$dependency_path" "$result_path" "$extra_path"

  real_find="$(command -v find)"
  cat >"$fake_bin/find" <<'EOF'
#!/bin/sh
case "$1" in
  *.shelffiles-portable-tmp.*) exit 95 ;;
esac
exec "$REAL_FIND" "$@"
EOF
  chmod 0755 "$fake_bin/find"

  run env -u SHELFFILES_PORTABLE_PREFIX PATH="$fake_bin:$PATH" \
    REAL_FIND="$real_find" "$checkout/utils/create_portable.sh"
  echo "$output"
  [ "$status" -ne 0 ]
  [[ "$output" == *"could not enumerate regular files"* ]]
  [ "$(readlink "$checkout/portable/result")" = "$result_target" ]
  [ ! -e "$checkout/portable/nix/store/${extra_path##*/}" ]

  rm "$fake_bin/find"
  real_grep="$(command -v grep)"
  cat >"$fake_bin/grep" <<'EOF'
#!/bin/sh
for argument do
  case "$argument" in
    *.shelffiles-portable-tmp.*) exit 94 ;;
  esac
done
exec "$REAL_GREP" "$@"
EOF
  chmod 0755 "$fake_bin/grep"

  run env -u SHELFFILES_PORTABLE_PREFIX PATH="$fake_bin:$PATH" \
    REAL_GREP="$real_grep" "$checkout/utils/create_portable.sh"
  echo "$output"
  [ "$status" -ne 0 ]
  [[ "$output" == *"could not inspect regular file"* ]]
  [ "$(readlink "$checkout/portable/result")" = "$result_target" ]
  [ ! -e "$checkout/portable/nix/store/${extra_path##*/}" ]
}

@test "failed full rebuild leaves the successful export and config byte-identical" {
  require_writable_nix_store
  create_fixture
  run env PATH="$fake_bin:$PATH" SHELFFILES_PORTABLE_PREFIX="$runtime_prefix" \
    "$checkout/utils/create_portable.sh"
  [ "$status" -eq 0 ]
  result_target="$(readlink "$checkout/portable/result")"
  config_before="$(sha256sum "$checkout/config/shelffiles.conf")"
  dependency_before="$(sha256sum "$checkout/portable/nix/store/${dependency_path##*/}/lib/value")"
  cat >"$fake_bin/sed" <<'EOF'
#!/bin/sh
exit 0
EOF
  chmod 0755 "$fake_bin/sed"

  run env PATH="$fake_bin:$PATH" SHELFFILES_PORTABLE_PREFIX="$other_prefix" \
    "$checkout/utils/create_portable.sh"
  [ "$status" -ne 0 ]
  [ "$(cat "$checkout/portable/nix/runtime-prefix")" = "$runtime_prefix" ]
  [ "$(readlink "$checkout/portable/result")" = "$result_target" ]
  [ "$(sha256sum "$checkout/portable/nix/store/${dependency_path##*/}/lib/value")" = "$dependency_before" ]
  [ "$(sha256sum "$checkout/config/shelffiles.conf")" = "$config_before" ]
}

@test "failed initial export leaves environment prefix configuration absent" {
  require_writable_nix_store
  create_fixture
  cat >"$fake_bin/sed" <<'EOF'
#!/bin/sh
exit 0
EOF
  chmod 0755 "$fake_bin/sed"

  run env PATH="$fake_bin:$PATH" SHELFFILES_PORTABLE_PREFIX="$runtime_prefix" \
    "$checkout/utils/create_portable.sh"
  [ "$status" -ne 0 ]
  [ ! -e "$checkout/config/shelffiles.conf" ]
  [ ! -e "$checkout/portable/result" ]
}

@test "legacy successful export structure is immediately reusable" {
  require_writable_nix_store
  create_fixture
  mkdir -p "$checkout/portable/nix/store"
  cp -a "$dependency_path" "$result_path" "$checkout/portable/nix/store/"
  while IFS= read -r -d '' file_path; do
    chmod u+w "$file_path"
    sed -i "s|/nix/store|$runtime_prefix|g" "$file_path"
  done < <(find "$checkout/portable/nix/store" -type f -print0)
  link_path="$checkout/portable/nix/store/${result_path##*/}/dependency-link"
  rm "$link_path"
  ln -s "$runtime_prefix/${dependency_path##*/}/lib/value" "$link_path"
  printf '%s\n' "$runtime_prefix" >"$checkout/portable/nix/runtime-prefix"
  ln -s "nix/store/${result_path##*/}" "$checkout/portable/result"
  chmod -R a-w "$checkout/portable/nix"
  mkdir -p "$checkout/config"
  printf 'SHELFFILES_PORTABLE_PREFIX=%s\n' "$runtime_prefix" >"$checkout/config/shelffiles.conf"

  run env -u SHELFFILES_PORTABLE_PREFIX PATH="$fake_bin:$PATH" \
    "$checkout/utils/create_portable.sh"
  echo "$output"
  [ "$status" -eq 0 ]
  assert_counts 2 0 0
  [ "$(grep -Fc 'SHELFFILES_PORTABLE_PREFIX=' "$checkout/config/shelffiles.conf")" -eq 1 ]
}

@test "managed prefix is canonical after later manual assignments" {
  require_writable_nix_store
  create_fixture
  mkdir -p "$checkout/config"
  printf '# before\nSHELFFILES_PORTABLE_PREFIX=%s # managed by utils/create_portable.sh\nOTHER_SETTING=kept\nSHELFFILES_PORTABLE_PREFIX=%s\n# after\n' \
    "$config_prefix" "$other_prefix" >"$checkout/config/shelffiles.conf"

  run env PATH="$fake_bin:$PATH" SHELFFILES_PORTABLE_PREFIX="$runtime_prefix" \
    "$checkout/utils/create_portable.sh"
  echo "$output"
  [ "$status" -eq 0 ]
  [ "$(grep -Fc '# managed by utils/create_portable.sh' "$checkout/config/shelffiles.conf")" -eq 1 ]
  grep -Fx "SHELFFILES_PORTABLE_PREFIX=$other_prefix" "$checkout/config/shelffiles.conf"
  [ "$(tail -n 1 "$checkout/config/shelffiles.conf")" = \
    "SHELFFILES_PORTABLE_PREFIX=$runtime_prefix # managed by utils/create_portable.sh" ]

  config_before="$(sha256sum "$checkout/config/shelffiles.conf")"
  run env -u SHELFFILES_PORTABLE_PREFIX PATH="$fake_bin:$PATH" \
    "$checkout/utils/create_portable.sh"
  echo "$output"
  [ "$status" -eq 0 ]
  assert_counts 2 0 0
  [ "$(cat "$checkout/portable/nix/runtime-prefix")" = "$runtime_prefix" ]
  [ "$(sha256sum "$checkout/config/shelffiles.conf")" = "$config_before" ]
}

@test "full-regeneration switch failure restores the previous successful export" {
  require_writable_nix_store
  create_fixture
  run env PATH="$fake_bin:$PATH" SHELFFILES_PORTABLE_PREFIX="$runtime_prefix" \
    "$checkout/utils/create_portable.sh"
  [ "$status" -eq 0 ]
  result_target="$(readlink "$checkout/portable/result")"
  dependency_before="$(sha256sum "$checkout/portable/nix/store/${dependency_path##*/}/lib/value")"
  config_before="$(sha256sum "$checkout/config/shelffiles.conf")"
  real_mv="$(command -v mv)"
  failure_marker="$test_root/mv-failed"
  create_changed_result

  cat >"$fake_bin/mv" <<'EOF'
#!/bin/sh
destination=
for argument do
  destination=$argument
done
if [ "$destination" = "$FAIL_MV_DESTINATION" ] && [ ! -e "$FAILURE_MARKER" ]; then
  : >"$FAILURE_MARKER"
  exit 97
fi
exec "$REAL_MV" "$@"
EOF
  chmod 0755 "$fake_bin/mv"

  run env PATH="$fake_bin:$PATH" SHELFFILES_PORTABLE_PREFIX="$other_prefix" \
    FAIL_MV_DESTINATION="$checkout/portable/result" FAILURE_MARKER="$failure_marker" \
    REAL_MV="$real_mv" "$checkout/utils/create_portable.sh"
  echo "$output"
  [ "$status" -eq 97 ]
  [ -e "$failure_marker" ]
  [ "$(cat "$checkout/portable/nix/runtime-prefix")" = "$runtime_prefix" ]
  [ "$(readlink "$checkout/portable/result")" = "$result_target" ]
  [ "$(sha256sum "$checkout/portable/nix/store/${dependency_path##*/}/lib/value")" = "$dependency_before" ]
  [ "$(sha256sum "$checkout/config/shelffiles.conf")" = "$config_before" ]
  run "$checkout/portable/result/bin/bash"
  [ "$status" -eq 0 ]
  [ "$output" = 'portable fixture' ]
  [ -z "$(find "$checkout/portable" -maxdepth 1 -name '.nix.shelffiles-portable-old.*' -print -quit)" ]
}

@test "post-commit old backup removal failure warns and saves the new prefix" {
  require_writable_nix_store
  create_fixture
  run env PATH="$fake_bin:$PATH" SHELFFILES_PORTABLE_PREFIX="$runtime_prefix" \
    "$checkout/utils/create_portable.sh"
  [ "$status" -eq 0 ]

  real_rm="$(command -v rm)"
  failure_marker="$test_root/backup-remove-failed"
  cat >"$fake_bin/rm" <<'EOF'
#!/bin/sh
for argument do
  case "$argument" in
    *.nix.shelffiles-portable-old.*)
      if [ -e "$argument" ] && [ ! -e "$FAILURE_MARKER" ]; then
        : >"$FAILURE_MARKER"
        exit 93
      fi
      ;;
  esac
done
exec "$REAL_RM" "$@"
EOF
  chmod 0755 "$fake_bin/rm"

  run env PATH="$fake_bin:$PATH" SHELFFILES_PORTABLE_PREFIX="$other_prefix" \
    FAILURE_MARKER="$failure_marker" REAL_RM="$real_rm" \
    "$checkout/utils/create_portable.sh"
  echo "$output"
  [ "$status" -eq 0 ]
  [[ "$output" == *"new result is active but old generated backup could not be removed"* ]]
  [ "$(cat "$checkout/portable/nix/runtime-prefix")" = "$other_prefix" ]
  grep -Fx "SHELFFILES_PORTABLE_PREFIX=$other_prefix # managed by utils/create_portable.sh" \
    "$checkout/config/shelffiles.conf"
}

@test "scratch cleanup failure does not prevent full-switch rollback" {
  require_writable_nix_store
  create_fixture
  run env PATH="$fake_bin:$PATH" SHELFFILES_PORTABLE_PREFIX="$runtime_prefix" \
    "$checkout/utils/create_portable.sh"
  [ "$status" -eq 0 ]
  result_target="$(readlink "$checkout/portable/result")"
  dependency_before="$(sha256sum "$checkout/portable/nix/store/${dependency_path##*/}/lib/value")"
  create_changed_result

  real_mv="$(command -v mv)"
  real_rm="$(command -v rm)"
  failure_marker="$test_root/mv-failed"
  cat >"$fake_bin/mv" <<'EOF'
#!/bin/sh
destination=
for argument do
  destination=$argument
done
if [ "$destination" = "$FAIL_MV_DESTINATION" ] && [ ! -e "$FAILURE_MARKER" ]; then
  : >"$FAILURE_MARKER"
  exit 97
fi
exec "$REAL_MV" "$@"
EOF
  cat >"$fake_bin/rm" <<'EOF'
#!/bin/sh
if [ -e "$FAILURE_MARKER" ]; then
  for argument do
    case "$argument" in
      *.result.shelffiles-portable-tmp.*) exit 96 ;;
    esac
  done
fi
exec "$REAL_RM" "$@"
EOF
  chmod 0755 "$fake_bin/mv" "$fake_bin/rm"

  run env PATH="$fake_bin:$PATH" SHELFFILES_PORTABLE_PREFIX="$other_prefix" \
    FAIL_MV_DESTINATION="$checkout/portable/result" FAILURE_MARKER="$failure_marker" \
    REAL_MV="$real_mv" REAL_RM="$real_rm" "$checkout/utils/create_portable.sh"
  echo "$output"
  [ "$status" -eq 97 ]
  [ "$(cat "$checkout/portable/nix/runtime-prefix")" = "$runtime_prefix" ]
  [ "$(readlink "$checkout/portable/result")" = "$result_target" ]
  [ "$(sha256sum "$checkout/portable/nix/store/${dependency_path##*/}/lib/value")" = "$dependency_before" ]
  [ -z "$(find "$checkout/portable" -maxdepth 1 -name '.nix.shelffiles-portable-old.*' -print -quit)" ]
}

@test "startup restores the only successful old-tree backup and removes stale backups" {
  require_writable_nix_store
  create_fixture
  run env PATH="$fake_bin:$PATH" SHELFFILES_PORTABLE_PREFIX="$runtime_prefix" \
    "$checkout/utils/create_portable.sh"
  [ "$status" -eq 0 ]
  result_target="$(readlink "$checkout/portable/result")"
  dependency_before="$(sha256sum "$checkout/portable/nix/store/${dependency_path##*/}/lib/value")"

  interrupted_backup="$checkout/portable/.nix.shelffiles-portable-old.interrupted"
  mv "$checkout/portable/nix" "$interrupted_backup"
  mkdir -p "$checkout/portable/nix/store"
  printf '%s\n' "$other_prefix" >"$checkout/portable/nix/runtime-prefix"
  chmod -R a-w "$checkout/portable/nix"

  run env -u SHELFFILES_PORTABLE_PREFIX PATH="$fake_bin:$PATH" \
    "$checkout/utils/create_portable.sh"
  echo "$output"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Recovered interrupted portable export"* ]]
  assert_counts 2 0 0
  [ "$(cat "$checkout/portable/nix/runtime-prefix")" = "$runtime_prefix" ]
  [ "$(readlink "$checkout/portable/result")" = "$result_target" ]
  [ "$(sha256sum "$checkout/portable/nix/store/${dependency_path##*/}/lib/value")" = "$dependency_before" ]
  run "$checkout/portable/result/bin/bash"
  [ "$status" -eq 0 ]
  [ "$output" = 'portable fixture' ]
  [ ! -e "$interrupted_backup" ]

  stale_backup="$checkout/portable/.nix.shelffiles-portable-old.stale"
  cp -a "$checkout/portable/nix" "$stale_backup"
  run env -u SHELFFILES_PORTABLE_PREFIX PATH="$fake_bin:$PATH" \
    "$checkout/utils/create_portable.sh"
  [ "$status" -eq 0 ]
  assert_counts 2 0 0
  [ ! -e "$stale_backup" ]
}

@test "backup enumeration failure never deletes the recoverable export" {
  require_writable_nix_store
  create_fixture
  run env PATH="$fake_bin:$PATH" SHELFFILES_PORTABLE_PREFIX="$runtime_prefix" \
    "$checkout/utils/create_portable.sh"
  [ "$status" -eq 0 ]

  interrupted_backup="$checkout/portable/.nix.shelffiles-portable-old.interrupted"
  mv "$checkout/portable/nix" "$interrupted_backup"
  mkdir -p "$checkout/portable/nix/store"
  printf '%s\n' "$other_prefix" >"$checkout/portable/nix/runtime-prefix"

  real_find="$(command -v find)"
  real_cp="$(command -v cp)"
  find_failure_marker="$test_root/backup-find-failed"
  cat >"$fake_bin/find" <<'EOF'
#!/bin/sh
for argument do
  if [ "$argument" = '.nix.shelffiles-portable-old.*' ] &&
    [ ! -e "$FIND_FAILURE_MARKER" ]; then
    : >"$FIND_FAILURE_MARKER"
    exit 95
  fi
done
exec "$REAL_FIND" "$@"
EOF
  cat >"$fake_bin/cp" <<'EOF'
#!/bin/sh
printf 'later copy must not run after backup enumeration failure\n' >&2
exit 94
EOF
  chmod 0755 "$fake_bin/find" "$fake_bin/cp"

  run env -u SHELFFILES_PORTABLE_PREFIX PATH="$fake_bin:$PATH" \
    FIND_FAILURE_MARKER="$find_failure_marker" REAL_FIND="$real_find" REAL_CP="$real_cp" \
    "$checkout/utils/create_portable.sh"
  echo "$output"
  [ "$status" -ne 0 ]
  [[ "$output" == *"could not enumerate interrupted portable backups"* ]]
  [ -d "$interrupted_backup/store/${result_path##*/}" ]
  [ "$(cat "$interrupted_backup/runtime-prefix")" = "$runtime_prefix" ]
}
