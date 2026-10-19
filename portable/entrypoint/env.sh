# shellcheck shell=sh

# This file is selected by the portable wrappers through SHELFFILES_ENV_FILE.
# Load the ordinary environment first so config, state, and XDG behavior remain
# shared with the normal entrypoints.
PORTABLE_ENTRYPOINT_DIR="$(
  CDPATH='' cd -- "$(dirname -- "${shelffiles_env_file:?portable environment file is not set}")" && pwd -P
)"
PORTABLE_ROOT="$(CDPATH='' cd -- "$PORTABLE_ENTRYPOINT_DIR/../.." && pwd -P)"

# shellcheck disable=SC1091
. "$PORTABLE_ROOT/entrypoint/env.sh"

ensure_portable_alias() {
  alias_path=$1
  expected_store=$2

  if [ -L "$alias_path" ]; then
    actual_store="$(readlink "$alias_path")"
    if [ "$actual_store" = "$expected_store" ]; then
      return 0
    fi
    printf 'Portable alias conflict: %s points to %s; expected %s\n' \
      "$alias_path" "$actual_store" "$expected_store" >&2
    return 73
  fi

  if [ -e "$alias_path" ]; then
    printf 'Portable alias conflict: %s exists and is not a symlink\n' \
      "$alias_path" >&2
    return 73
  fi

  if ln -s "$expected_store" "$alias_path" 2>/dev/null; then
    return 0
  fi

  # A concurrent creator may have won the race. Accept only the exact target.
  if [ -L "$alias_path" ]; then
    actual_store="$(readlink "$alias_path")"
    if [ "$actual_store" = "$expected_store" ]; then
      return 0
    fi
    printf 'Portable alias conflict: %s points to %s; expected %s\n' \
      "$alias_path" "$actual_store" "$expected_store" >&2
    return 73
  fi
  if [ -e "$alias_path" ]; then
    printf 'Portable alias conflict: %s exists and is not a symlink\n' \
      "$alias_path" >&2
    return 73
  fi

  printf 'Could not create portable alias %s -> %s\n' \
    "$alias_path" "$expected_store" >&2
  return 1
}

activate_portable_environment() {
  alias_path=$1
  expected_store=$2
  portable_result=$3

  ensure_portable_alias "$alias_path" "$expected_store" || return $?
  export PATH="$portable_result/bin:$PATH"
}

read_portable_prefix() {
  metadata_path=$1
  portable_prefix=
  unexpected_line=

  if [ ! -f "$metadata_path" ] || [ -L "$metadata_path" ]; then
    printf 'Portable runtime prefix metadata is missing: %s\n' \
      "$metadata_path" >&2
    return 1
  fi

  if ! {
    IFS= read -r portable_prefix &&
      ! IFS= read -r unexpected_line &&
      [ -z "$unexpected_line" ]
  } <"$metadata_path"; then
    printf 'Portable runtime prefix metadata must contain exactly one line: %s\n' \
      "$metadata_path" >&2
    return 1
  fi

  case "$portable_prefix" in
    /tmp/[A-Za-z0-9][A-Za-z0-9][A-Za-z0-9][A-Za-z0-9][A-Za-z0-9]) ;;
    *)
      printf 'Portable runtime prefix metadata must match /tmp/[A-Za-z0-9]{5}: %s\n' \
        "$metadata_path" >&2
      return 1
      ;;
  esac

  printf '%s\n' "$portable_prefix"
}

PORTABLE_STORE="$(CDPATH='' cd -- "$PORTABLE_ROOT/portable/nix/store" 2>/dev/null && pwd -P)" || {
  printf 'Portable store is missing. Run utils/create_portable.sh first.\n' >&2
  return 1
}
PORTABLE_RUNTIME_PREFIX="$(read_portable_prefix "$PORTABLE_ROOT/portable/nix/runtime-prefix")" || {
  return 1
}
PORTABLE_RESULT="$PORTABLE_ROOT/portable/result"
PORTABLE_RESULT_RESOLVED="$(CDPATH='' cd -- "$PORTABLE_RESULT" 2>/dev/null && pwd -P)" || {
  printf 'Portable result is missing or broken. Run utils/create_portable.sh first.\n' >&2
  return 1
}
case "$PORTABLE_RESULT_RESOLVED" in
  "$PORTABLE_STORE"/*) ;;
  *)
    printf 'Portable result resolves outside the portable store: %s\n' \
      "$PORTABLE_RESULT_RESOLVED" >&2
    return 1
    ;;
esac

activate_portable_environment \
  "$PORTABLE_RUNTIME_PREFIX" "$PORTABLE_STORE" "$PORTABLE_RESULT" || {
  portable_status=$?
  return "$portable_status"
}

portable_ca_bundle="$PORTABLE_RESULT/etc/ssl/certs/ca-bundle.crt"
if [ "${shelffiles_default_ssl_cert_file:-0}" = 1 ]; then
  SSL_CERT_FILE=$portable_ca_bundle
fi
if [ "${shelffiles_default_nix_ssl_cert_file:-0}" = 1 ]; then
  NIX_SSL_CERT_FILE=$portable_ca_bundle
fi
if [ "${shelffiles_default_system_certificate_path:-0}" = 1 ]; then
  SYSTEM_CERTIFICATE_PATH=$portable_ca_bundle
fi
export SSL_CERT_FILE NIX_SSL_CERT_FILE SYSTEM_CERTIFICATE_PATH
unset portable_ca_bundle \
  shelffiles_default_ssl_cert_file \
  shelffiles_default_nix_ssl_cert_file \
  shelffiles_default_system_certificate_path

# Consumed by the ordinary shell entrypoint after this sourced extension
# returns. Keep it unexported so it does not leak into the launched shell.
# shellcheck disable=SC2034
shelffiles_portable_active=1
