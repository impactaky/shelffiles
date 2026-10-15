# shellcheck shell=sh

# Portable wrappers can select an environment extension for this invocation.
# Consume the exported handoff before sourcing it so it does not leak into the
# launched shell. The selected extension is responsible for loading this file
# again without the handoff to get the ordinary environment first.
if [ -n "${SHELFFILES_ENV_FILE:-}" ]; then
    shelffiles_env_file=$SHELFFILES_ENV_FILE
    unset SHELFFILES_ENV_FILE
    # shellcheck disable=SC1090
    . "$shelffiles_env_file"
    shelffiles_env_status=$?
    unset shelffiles_env_file
    [ "$shelffiles_env_status" -eq 0 ] || exit "$shelffiles_env_status"
    unset shelffiles_env_status
    return 0
fi

# A caller sourcing this file can provide the root explicitly. Entrypoint
# wrappers set it from their own location before loading this file.
if [ -z "${SHELFFILES:-}" ]; then
  SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
  SHELFFILES="$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd)"
fi

# Check if SHELFFILES variable is set
if [ -z "$SHELFFILES" ]; then
  echo "Error: SHELFFILES variable is not set. Please define it before sourcing this script."
  return 1 2>/dev/null
fi
export SHELFFILES

# Load shelffiles configuration
if [ -f "$SHELFFILES/config/shelffiles.conf" ]; then
    # shellcheck disable=SC1091
    . "$SHELFFILES/config/shelffiles.conf"
fi

# Create a unique ID based on the path, user ID and group ID to avoid conflicts
USER_ID=$(id -u)
GROUP_ID=$(id -g)
PATH_ID=$(echo "${SHELFFILES}_${USER_ID}_${GROUP_ID}" | tr '/:' '__')

# Set XDG environment variables to use directories within the repository
export XDG_CONFIG_HOME="$SHELFFILES/config"
export XDG_CACHE_HOME="$SHELFFILES/cache/${PATH_ID}"
export XDG_DATA_HOME="$SHELFFILES/share/${PATH_ID}"
export XDG_STATE_HOME="$SHELFFILES/state/${PATH_ID}"
export PATH="$SHELFFILES/result/bin:$PATH"

# Create necessary directories
mkdir -p "$XDG_CACHE_HOME"
mkdir -p "$XDG_DATA_HOME"
mkdir -p "$XDG_STATE_HOME"

USER_ENV_FILE="$SHELFFILES/user_env.sh"
if [ -f "$USER_ENV_FILE" ]; then
  # shellcheck disable=SC1090
  . "$USER_ENV_FILE"
fi

# Provide the packaged CA bundle to TLS clients unless the caller or user
# configuration supplied a non-empty value. Keep unexported markers so the
# portable extension can replace only defaults established here.
unset shelffiles_default_ssl_cert_file \
  shelffiles_default_nix_ssl_cert_file \
  shelffiles_default_system_certificate_path
shelffiles_ca_bundle="$SHELFFILES/result/etc/ssl/certs/ca-bundle.crt"
# shellcheck disable=SC2034
if [ -z "${SSL_CERT_FILE:-}" ]; then
  SSL_CERT_FILE=$shelffiles_ca_bundle
  shelffiles_default_ssl_cert_file=1
fi
# shellcheck disable=SC2034
if [ -z "${NIX_SSL_CERT_FILE:-}" ]; then
  NIX_SSL_CERT_FILE=$shelffiles_ca_bundle
  shelffiles_default_nix_ssl_cert_file=1
fi
# shellcheck disable=SC2034
if [ -z "${SYSTEM_CERTIFICATE_PATH:-}" ]; then
  SYSTEM_CERTIFICATE_PATH=$shelffiles_ca_bundle
  shelffiles_default_system_certificate_path=1
fi
export SSL_CERT_FILE NIX_SSL_CERT_FILE SYSTEM_CERTIFICATE_PATH
unset shelffiles_ca_bundle
