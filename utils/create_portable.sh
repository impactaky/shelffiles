#!/usr/bin/env bash
set -euo pipefail

# Export the already-built result closure into a runtime-only relocated copy.
# This script intentionally has no build step and never writes to /nix/store.

fail() {
  printf 'Portable export failed: %s\n' "$1" >&2
  exit 1
}

force_regeneration=0
case $# in
  0) ;;
  1)
    [[ $1 == --force ]] || \
      fail "unknown argument: $1 (usage: utils/create_portable.sh [--force])"
    force_regeneration=1
    ;;
  *) fail 'usage: utils/create_portable.sh [--force]' ;;
esac

readonly source_prefix=/nix/store
readonly managed_config_suffix=' # managed by utils/create_portable.sh'
readonly temporary_entry_prefix=.shelffiles-portable-tmp.
script_dir="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly script_dir
checkout_root="$(CDPATH='' cd -- "$script_dir/.." && pwd -P)"
readonly checkout_root
readonly source_result="$checkout_root/result"
readonly portable_root="$checkout_root/portable"
readonly portable_nix="$portable_root/nix"
readonly portable_store="$portable_nix/store"
readonly portable_result="$portable_root/result"
readonly config_file="$checkout_root/config/shelffiles.conf"

closure_inventory=
regular_inventory=
symlink_inventory=
backup_inventory=
temporary_inventory=
store_inventory=
temporary_path=
staged_nix=
result_temporary=
config_temporary=
old_nix_backup=
old_nix_was_successful=0
previous_result_target=
full_switch_committed=0
store_permissions_changed=0

cleanup_on_exit() {
  local status=$?
  trap - EXIT
  set +e

  if [[ -n $old_nix_backup && ( -e $old_nix_backup || -L $old_nix_backup ) ]]; then
    if ((old_nix_was_successful && !full_switch_committed)); then
      if remove_generated_tree "$portable_nix" &&
        mv -- "$old_nix_backup" "$portable_nix"; then
        old_nix_backup=
        if [[ -n $previous_result_target ]] && {
          [[ ! -L $portable_result ]] ||
            [[ $(readlink -- "$portable_result") != "$previous_result_target" ]]
        }; then
          result_temporary="$portable_root/.result.shelffiles-portable-rollback.$$"
          rm -f -- "$result_temporary"
          if ln -s -- "$previous_result_target" "$result_temporary" &&
            mv -Tf -- "$result_temporary" "$portable_result"; then
            result_temporary=
          else
            printf 'Portable export rollback could not restore result metadata: %s\n' \
              "$portable_result" >&2
          fi
        fi
      else
        printf 'Portable export rollback could not restore backup: %s\n' \
          "$old_nix_backup" >&2
      fi
    else
      remove_generated_tree "$old_nix_backup"
      old_nix_backup=
    fi
  fi
  if [[ -n $temporary_path && ( -e $temporary_path || -L $temporary_path ) ]]; then
    chmod -R u+w -- "$temporary_path" 2>/dev/null
    rm -rf -- "$temporary_path"
  fi
  if [[ -n $staged_nix && ( -e $staged_nix || -L $staged_nix ) ]]; then
    chmod -R u+w -- "$staged_nix" 2>/dev/null
    rm -rf -- "$staged_nix"
  fi
  if [[ -n $result_temporary && ( -e $result_temporary || -L $result_temporary ) ]]; then
    rm -rf -- "$result_temporary"
  fi
  if [[ -n $config_temporary && ( -e $config_temporary || -L $config_temporary ) ]]; then
    rm -f -- "$config_temporary"
  fi
  if ((store_permissions_changed)) && [[ -d $portable_nix && ! -L $portable_nix ]]; then
    chmod a-w -- "$portable_store" "$portable_nix" 2>/dev/null
  fi
  [[ -z $closure_inventory ]] || rm -f -- "$closure_inventory" 2>/dev/null
  [[ -z $regular_inventory ]] || rm -f -- "$regular_inventory" 2>/dev/null
  [[ -z $symlink_inventory ]] || rm -f -- "$symlink_inventory" 2>/dev/null
  [[ -z $backup_inventory ]] || rm -f -- "$backup_inventory" 2>/dev/null
  [[ -z $temporary_inventory ]] || rm -f -- "$temporary_inventory" 2>/dev/null
  [[ -z $store_inventory ]] || rm -f -- "$store_inventory" 2>/dev/null

  exit "$status"
}
trap cleanup_on_exit EXIT

validate_runtime_prefix() {
  local prefix=$1
  if [[ ! $prefix =~ ^/tmp/[A-Za-z0-9]{5}$ ]]; then
    printf 'Portable export failed: SHELFFILES_PORTABLE_PREFIX must match /tmp/[A-Za-z0-9]{5}; got %q\n' \
      "$prefix" >&2
    exit 1
  fi
}

is_store_name() {
  [[ $1 =~ ^[0123456789abcdfghijklmnpqrsvwxyz]{32}-.+ ]]
}

remove_generated_tree() {
  local path=$1
  if [[ -e $path || -L $path ]]; then
    if [[ -d $path && ! -L $path ]]; then
      chmod -R u+w -- "$path" 2>/dev/null || true
    fi
    rm -rf -- "$path"
  fi
}

count_final_store_entries() {
  local store=$1
  local entry entry_name count=0 inventory

  if [[ ! -d $store || -L $store ]]; then
    printf '0\n'
    return
  fi
  inventory="$(mktemp /tmp/shelffiles-portable-count.XXXXXX)"
  if ! find "$store" -mindepth 1 -maxdepth 1 -print0 >"$inventory"; then
    rm -f -- "$inventory"
    return 1
  fi
  while IFS= read -r -d '' entry; do
    entry_name=${entry##*/}
    if is_store_name "$entry_name"; then
      ((count += 1))
    fi
  done <"$inventory"
  rm -f -- "$inventory"
  printf '%s\n' "$count"
}

read_completed_export_prefix_at() {
  local nix_root=$1
  local store=$nix_root/store
  local metadata=$nix_root/runtime-prefix
  local recorded_prefix unexpected_line result_target result_name

  [[ -d $nix_root && ! -L $nix_root ]] || return 1
  [[ -d $store && ! -L $store ]] || return 1
  [[ -f $metadata && ! -L $metadata ]] || return 1
  if ! {
    IFS= read -r recorded_prefix &&
      ! IFS= read -r unexpected_line &&
      [[ -z $unexpected_line ]]
  } <"$metadata"; then
    return 1
  fi
  [[ $recorded_prefix =~ ^/tmp/[A-Za-z0-9]{5}$ ]] || return 1

  [[ -L $portable_result ]] || return 1
  result_target=$(readlink -- "$portable_result") || return 1
  [[ $result_target == nix/store/* ]] || return 1
  result_name=${result_target#nix/store/}
  [[ $result_name != */* ]] || return 1
  is_store_name "$result_name" || return 1
  [[ -d $store/$result_name && ! -L $store/$result_name ]] || return 1

  printf '%s\n' "$recorded_prefix"
}

read_completed_export_prefix() {
  read_completed_export_prefix_at "$portable_nix"
}

recover_interrupted_backups() {
  local backup recoverable_backup='' active_completed=0

  backup_inventory="$(mktemp /tmp/shelffiles-portable-backups.XXXXXX)"
  if ! find "$portable_root" -mindepth 1 -maxdepth 1 \
    -name '.nix.shelffiles-portable-old.*' -print0 >"$backup_inventory"; then
    fail 'could not enumerate interrupted portable backups'
  fi

  if read_completed_export_prefix >/dev/null 2>&1; then
    active_completed=1
  fi

  while IFS= read -r -d '' backup; do
    if ((active_completed)); then
      remove_generated_tree "$backup"
      continue
    fi
    if read_completed_export_prefix_at "$backup" >/dev/null 2>&1; then
      [[ -z $recoverable_backup ]] || \
        fail 'multiple interrupted portable backups are recoverable; refusing to choose one'
      recoverable_backup=$backup
    fi
  done <"$backup_inventory"

  if ((active_completed)); then
    rm -f -- "$backup_inventory"
    backup_inventory=
    return
  fi
  if [[ -n $recoverable_backup ]]; then
    remove_generated_tree "$portable_nix"
    mv -- "$recoverable_backup" "$portable_nix"
    printf 'Recovered interrupted portable export\n'
  fi

  while IFS= read -r -d '' backup; do
    remove_generated_tree "$backup"
  done <"$backup_inventory"
  rm -f -- "$backup_inventory"
  backup_inventory=
}

rewrite_and_verify_entry() {
  local entry=$1
  local file_path reference_count file_mode parent_dir parent_mode grep_status
  local link_path link_target replacement
  local residual_regular=0 residual_symlinks=0

  regular_inventory="$(mktemp /tmp/shelffiles-portable-files.XXXXXX)"
  symlink_inventory="$(mktemp /tmp/shelffiles-portable-links.XXXXXX)"
  if ! find "$entry" -type f -print0 >"$regular_inventory"; then
    fail "could not enumerate regular files under copied entry: $entry"
  fi
  if ! find "$entry" -type l -print0 >"$symlink_inventory"; then
    fail "could not enumerate symlinks under copied entry: $entry"
  fi

  while IFS= read -r -d '' file_path; do
    if LC_ALL=C grep -aF -- "$source_prefix" "$file_path" >/dev/null; then
      :
    else
      grep_status=$?
      ((grep_status == 1)) && continue
      fail "could not inspect regular file for source references: $file_path"
    fi

    if ! reference_count="$(LC_ALL=C grep -aobF -- "$source_prefix" "$file_path" | wc -l)"; then
      fail "could not count source references in regular file: $file_path"
    fi
    file_mode="$(stat -c %a -- "$file_path")"
    parent_dir="$(dirname -- "$file_path")"
    parent_mode="$(stat -c %a -- "$parent_dir")"
    chmod u+w -- "$parent_dir" "$file_path"
    LC_ALL=C sed -i "s|$source_prefix|$runtime_prefix|g" "$file_path"
    chmod "$file_mode" -- "$file_path"
    chmod "$parent_mode" -- "$parent_dir"
    ((regular_files_rewritten += 1))
    ((regular_references_rewritten += reference_count))
  done <"$regular_inventory"

  while IFS= read -r -d '' link_path; do
    link_target="$(readlink -- "$link_path")"
    [[ $link_target == *"$source_prefix"* ]] || continue
    replacement=${link_target//$source_prefix/$runtime_prefix}
    parent_dir="$(dirname -- "$link_path")"
    parent_mode="$(stat -c %a -- "$parent_dir")"
    chmod u+w -- "$parent_dir"
    ln -sfn -- "$replacement" "$link_path"
    chmod "$parent_mode" -- "$parent_dir"
    ((symlinks_rewritten += 1))
  done <"$symlink_inventory"

  while IFS= read -r -d '' file_path; do
    if LC_ALL=C grep -aF -- "$source_prefix" "$file_path" >/dev/null; then
      printf 'Residual regular-file reference: %s\n' "$file_path" >&2
      ((residual_regular += 1))
    else
      grep_status=$?
      ((grep_status == 1)) || \
        fail "could not verify regular file after relocation: $file_path"
    fi
  done <"$regular_inventory"

  while IFS= read -r -d '' link_path; do
    link_target="$(readlink -- "$link_path")"
    if [[ $link_target == *"$source_prefix"* ]]; then
      printf 'Residual symlink reference: %s -> %s\n' "$link_path" "$link_target" >&2
      ((residual_symlinks += 1))
    fi
  done <"$symlink_inventory"

  rm -f -- "$regular_inventory" "$symlink_inventory"
  regular_inventory=
  symlink_inventory=

  if ((residual_regular != 0 || residual_symlinks != 0)); then
    fail "residual $source_prefix references remain (files=$residual_regular, symlinks=$residual_symlinks)"
  fi
}

copy_entry_to_store() {
  local store_path=$1
  local destination_store=$2
  local store_name=${store_path##*/}
  local final_path=$destination_store/$store_name

  temporary_path="$destination_store/$temporary_entry_prefix$store_name.$$.${copied_count}"
  [[ ! -e $temporary_path && ! -L $temporary_path ]] || \
    fail "temporary store path already exists: $temporary_path"
  cp -a --no-preserve=ownership -- "$store_path" "$temporary_path"
  rewrite_and_verify_entry "$temporary_path"
  chmod -R a-w -- "$temporary_path"
  mv -- "$temporary_path" "$final_path"
  temporary_path=
  ((copied_count += 1))
}

switch_portable_result() {
  local target="nix/store/$result_name"

  if [[ -L $portable_result ]] && [[ $(readlink -- "$portable_result") == "$target" ]]; then
    return
  fi
  result_temporary="$portable_root/.result.shelffiles-portable-tmp.$$"
  rm -f -- "$result_temporary"
  ln -s -- "$target" "$result_temporary"
  if [[ -d $portable_result && ! -L $portable_result ]]; then
    remove_generated_tree "$portable_result"
  fi
  mv -Tf -- "$result_temporary" "$portable_result"
  result_temporary=
}

persist_environment_prefix() {
  local config_dir=${config_file%/*}
  local line had_newline wrote_any=0 last_had_newline=1
  local config_mode=

  mkdir -p -- "$config_dir"
  config_temporary="$(mktemp "$config_dir/.shelffiles.conf.shelffiles-portable-tmp.XXXXXX")"

  if [[ -f $config_file && ! -L $config_file ]]; then
    config_mode="$(stat -c %a -- "$config_file")"
    while true; do
      line=
      if IFS= read -r line; then
        had_newline=1
      else
        had_newline=0
        [[ -n $line ]] || break
      fi

      [[ $line == SHELFFILES_PORTABLE_PREFIX=*"$managed_config_suffix" ]] && continue
      wrote_any=1
      last_had_newline=$had_newline
      printf '%s' "$line" >>"$config_temporary"
      ((had_newline)) && printf '\n' >>"$config_temporary"
    done <"$config_file"
  elif [[ -e $config_file || -L $config_file ]]; then
    fail "configuration path is not a regular file: $config_file"
  fi

  if ((wrote_any && !last_had_newline)); then
    printf '\n' >>"$config_temporary"
  fi
  printf 'SHELFFILES_PORTABLE_PREFIX=%s%s\n' \
    "$runtime_prefix" "$managed_config_suffix" >>"$config_temporary"

  [[ -z $config_mode ]] || chmod "$config_mode" -- "$config_temporary"

  if mv -- "$config_temporary" "$config_file"; then
    config_temporary=
  else
    printf 'Portable export warning: export completed but prefix configuration could not be saved: %s\n' \
      "$config_file" >&2
  fi
}

portable_prefix_from_environment=0
environment_portable_prefix=
if [[ ${SHELFFILES_PORTABLE_PREFIX+x} == x ]]; then
  portable_prefix_from_environment=1
  environment_portable_prefix=$SHELFFILES_PORTABLE_PREFIX
fi

if [[ -f $config_file ]]; then
  # shellcheck disable=SC1090
  source "$config_file"
fi

if ((portable_prefix_from_environment)); then
  runtime_prefix=$environment_portable_prefix
elif [[ ${SHELFFILES_PORTABLE_PREFIX+x} == x ]]; then
  runtime_prefix=$SHELFFILES_PORTABLE_PREFIX
else
  fail 'SHELFFILES_PORTABLE_PREFIX is required in the process environment or config/shelffiles.conf'
fi
readonly runtime_prefix
validate_runtime_prefix "$runtime_prefix"

for tool in chmod cp dirname find grep ln mkdir mktemp mv readlink rm sed sort stat uname wc; do
  command -v "$tool" >/dev/null 2>&1 || fail "required command is missing: $tool"
done

[[ $(uname -s) == Linux ]] || fail 'only Linux is supported'
source_bytes="$(LC_ALL=C printf %s "$source_prefix" | wc -c)"
runtime_bytes="$(LC_ALL=C printf %s "$runtime_prefix" | wc -c)"
[[ $source_bytes == "$runtime_bytes" ]] || \
  fail "prefixes must have equal byte lengths ($source_bytes != $runtime_bytes)"

[[ -e $source_result ]] || fail "ordinary result is missing: $source_result"
resolved_result="$(readlink -f -- "$source_result")" || \
  fail "could not resolve ordinary result: $source_result"
[[ $resolved_result == "$source_prefix/"* ]] || \
  fail "ordinary result must resolve under $source_prefix: $resolved_result"
[[ -d $resolved_result ]] || fail "resolved ordinary result is not a directory: $resolved_result"
result_name=${resolved_result##*/}
is_store_name "$result_name" || fail "ordinary result is not a Nix store path: $resolved_result"

if command -v nix-store >/dev/null 2>&1; then
  nix_store="$(command -v nix-store)"
elif [[ -x $source_result/bin/nix-store ]]; then
  nix_store=$source_result/bin/nix-store
else
  fail 'nix-store is unavailable (install Nix or include nix-store in result)'
fi
readonly nix_store

closure_inventory="$(mktemp /tmp/shelffiles-portable-closure.XXXXXX)"
LC_ALL=C "$nix_store" --query --requisites "$resolved_result" \
  | LC_ALL=C sort -u >"$closure_inventory" || fail 'could not query result closure'
[[ -s $closure_inventory ]] || fail 'nix-store returned an empty closure'

declare -A required_store_names=()
result_in_closure=0
while IFS= read -r store_path; do
  [[ -n $store_path ]] || fail 'closure contains an empty path'
  [[ $(dirname -- "$store_path") == "$source_prefix" ]] || \
    fail "closure contains a path outside $source_prefix: $store_path"
  store_name=${store_path##*/}
  is_store_name "$store_name" || fail "closure contains a non-Nix store path: $store_path"
  [[ -e $store_path || -L $store_path ]] || fail "closure path is missing: $store_path"
  required_store_names["$store_name"]=1
  [[ $store_path == "$resolved_result" ]] && result_in_closure=1
done <"$closure_inventory"
[[ $result_in_closure == 1 ]] || fail 'queried closure does not contain the ordinary result'

mkdir -p -- "$portable_root"
temporary_inventory="$(mktemp /tmp/shelffiles-portable-temporary.XXXXXX)"
if ! find "$portable_root" -mindepth 1 -maxdepth 1 \
  \( -name '.nix.shelffiles-portable-tmp.*' \
  -o -name '.result.shelffiles-portable-tmp.*' \) \
  -print0 >"$temporary_inventory"; then
  fail 'could not enumerate interrupted portable temporary paths'
fi
while IFS= read -r -d '' temporary_path; do
  remove_generated_tree "$temporary_path"
  temporary_path=
done <"$temporary_inventory"
rm -f -- "$temporary_inventory"
temporary_inventory=
recover_interrupted_backups

completed_prefix=
if completed_prefix="$(read_completed_export_prefix 2>/dev/null)"; then
  completed_export=1
else
  completed_export=0
fi

incremental_export=0
if ((!force_regeneration && completed_export)) && [[ $completed_prefix == "$runtime_prefix" ]]; then
  incremental_export=1
fi

reused_count=0
copied_count=0
removed_count=0
regular_files_rewritten=0
regular_references_rewritten=0
symlinks_rewritten=0

if ((incremental_export)); then
  store_permissions_changed=1
  chmod u+w -- "$portable_nix" "$portable_store"
  chmod a-w -- "$portable_nix/runtime-prefix"

  temporary_inventory="$(mktemp /tmp/shelffiles-portable-temporary.XXXXXX)"
  if ! find "$portable_store" -mindepth 1 -maxdepth 1 \
    -name "$temporary_entry_prefix*" -print0 >"$temporary_inventory"; then
    fail 'could not enumerate temporary portable store paths'
  fi
  while IFS= read -r -d '' temporary_path; do
    chmod -R u+w -- "$temporary_path" 2>/dev/null || true
    rm -rf -- "$temporary_path"
    temporary_path=
  done <"$temporary_inventory"
  rm -f -- "$temporary_inventory"
  temporary_inventory=

  while IFS= read -r store_path; do
    store_name=${store_path##*/}
    final_path=$portable_store/$store_name
    if [[ -e $final_path || -L $final_path ]]; then
      ((reused_count += 1))
      continue
    fi
    copy_entry_to_store "$store_path" "$portable_store"
  done <"$closure_inventory"

  [[ -d $portable_store/$result_name && ! -L $portable_store/$result_name ]] || \
    fail "transformed result is missing: $portable_store/$result_name"
  store_inventory="$(mktemp /tmp/shelffiles-portable-store.XXXXXX)"
  if ! find "$portable_store" -mindepth 1 -maxdepth 1 \
    -print0 >"$store_inventory"; then
    fail 'could not enumerate portable store before result switch'
  fi
  switch_portable_result

  while IFS= read -r -d '' final_path; do
    store_name=${final_path##*/}
    is_store_name "$store_name" || continue
    if [[ -n ${required_store_names[$store_name]+present} ]]; then
      continue
    fi
    chmod -R u+w -- "$final_path" 2>/dev/null || \
      printf 'Portable export warning: could not make stale store path writable: %s\n' \
        "$final_path" >&2
    if rm -rf -- "$final_path"; then
      ((removed_count += 1))
    else
      printf 'Portable export warning: could not remove stale store path: %s\n' \
        "$final_path" >&2
      chmod -R a-w -- "$final_path" 2>/dev/null || \
        printf 'Portable export warning: could not restore stale store path permissions: %s\n' \
          "$final_path" >&2
    fi
  done <"$store_inventory"
  if rm -f -- "$store_inventory"; then
    store_inventory=
  else
    printf 'Portable export warning: could not remove verified store inventory: %s\n' \
      "$store_inventory" >&2
  fi

  if chmod a-w -- "$portable_store" "$portable_nix"; then
    store_permissions_changed=0
  else
    printf 'Portable export warning: new result is active but generated directory permissions could not be restored\n' >&2
  fi
else
  removed_count="$(count_final_store_entries "$portable_store")"
  staged_nix="$(mktemp -d "$portable_root/.nix.shelffiles-portable-tmp.XXXXXX")"
  staged_store=$staged_nix/store
  mkdir -p -- "$staged_store"

  while IFS= read -r store_path; do
    copy_entry_to_store "$store_path" "$staged_store"
  done <"$closure_inventory"
  [[ -d $staged_store/$result_name && ! -L $staged_store/$result_name ]] || \
    fail "transformed result is missing: $staged_store/$result_name"
  printf '%s\n' "$runtime_prefix" >"$staged_nix/runtime-prefix"
  chmod a-w -- "$staged_nix/runtime-prefix" "$staged_store" "$staged_nix"

  old_nix_backup="$portable_root/.nix.shelffiles-portable-old.$$"
  old_nix_was_successful=0
  previous_result_target=
  full_switch_committed=0
  remove_generated_tree "$old_nix_backup"
  if [[ -e $portable_nix || -L $portable_nix ]]; then
    if ((completed_export)) && [[ -L $portable_result ]]; then
      previous_result_target="$(readlink -- "$portable_result")"
      old_nix_was_successful=1
    fi
    mv -- "$portable_nix" "$old_nix_backup"
  fi
  mv -- "$staged_nix" "$portable_nix"
  staged_nix=
  switch_portable_result
  full_switch_committed=1
  if remove_generated_tree "$old_nix_backup"; then
    old_nix_backup=
  else
    printf 'Portable export warning: new result is active but old generated backup could not be removed: %s\n' \
      "$old_nix_backup" >&2
    chmod -R a-w -- "$old_nix_backup" 2>/dev/null || true
  fi
fi

if ((portable_prefix_from_environment)); then
  persist_environment_prefix
fi

printf 'Portable export complete\n'
printf '  Result: %s -> %s\n' "$portable_result" "$(readlink -- "$portable_result")"
printf '  Store paths reused: %s\n' "$reused_count"
printf '  Store paths copied: %s\n' "$copied_count"
printf '  Store paths removed: %s\n' "$removed_count"
printf '  Regular files rewritten: %s (%s references)\n' \
  "$regular_files_rewritten" "$regular_references_rewritten"
printf '  Symlink targets rewritten: %s\n' "$symlinks_rewritten"
printf '  Runtime prefix: %s\n' "$runtime_prefix"
