#!/bin/bash

set -o pipefail

CONFIG_FILE="${REMOTE_ASSISTANCE_CONFIG:-/etc/remote-assistance.conf}"
NON_INTERACTIVE=false

usage() {
  cat <<'EOF'
Usage: remote-assistance.sh [--config FILE] [--non-interactive]

Starts the ClusterVision reverse SSH support tunnel.

Configuration is read from /etc/remote-assistance.conf by default. Values from
that file can be overridden by environment variables with the same names.
When --non-interactive is used, missing required values fail fast instead of
prompting; this is the mode used by remote-assistance.service.
EOF
}

while [ "$#" -gt 0 ]
do
  case "$1" in
    --config)
      [ -n "${2:-}" ] || { echo "--config requires a file path" >&2; exit 2; }
      CONFIG_FILE="$2"
      shift 2
      ;;
    --non-interactive)
      NON_INTERACTIVE=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ ! -t 0 ]
then
  NON_INTERACTIVE=true
fi

exit_requested() {
  echo "exit requested."
  exit 0
}
trap exit_requested INT TERM

if [ -t 1 ] && command -v tput >/dev/null 2>&1 && [ "$(tput colors 2>/dev/null || echo 0)" -gt 7 ]
then
  color_reset="\e[0m"
  color_red="\e[31m"
  color_green="\e[32m"
fi

log() {
  echo -e "${color_green:-}$*${color_reset:-}"
}

warn() {
  echo -e "${color_red:-}$*${color_reset:-}" >&2
}

die() {
  warn "$*"
  exit 1
}

is_yes() {
  case "${1:-}" in
    y|Y|yes|YES|true|TRUE|1) return 0 ;;
    *) return 1 ;;
  esac
}

expand_path() {
  case "$1" in
    '~') printf '%s\n' "$HOME" ;;
    '~/'*) printf '%s/%s\n' "$HOME" "${1#~/}" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

sanitize_path() {
  printf '%s' "$1" | sed 's/[^A-Za-z0-9._/-]/_/g'
}

sanitize_project() {
  printf '%s' "$1" | sed 's/[^A-Za-z0-9._-]/_/g'
}

sanitize_info() {
  local value
  value=$(printf '%s' "$1" | sed 's/[^A-Za-z0-9._/-]/_/g')
  printf '%s' "${value:0:120}"
}

prompt_value() {
  local __var="$1"
  local prompt="$2"
  local default="${3:-}"
  local value

  if [ "$NON_INTERACTIVE" = true ]
  then
    printf -v "$__var" '%s' "$default"
    return
  fi

  if ((BASH_VERSINFO[0] >= 4)) && [ -n "$default" ]
  then
    read -r -e -i "$default" -p "$prompt" value
  else
    read -r -e -p "$prompt" value
  fi
  [ -n "$value" ] || value="$default"
  printf -v "$__var" '%s' "$value"
}

# Defaults. The config file below may override these values.
REMOTE_ASSISTANCE_PRIVATE_KEY="${REMOTE_ASSISTANCE_PRIVATE_KEY:-${HOME}/.ssh/id_rsa}"
REMOTE_ASSISTANCE_PUBLIC_KEY="${REMOTE_ASSISTANCE_PUBLIC_KEY:-}"
REMOTE_ASSISTANCE_USE_PROXY="${REMOTE_ASSISTANCE_USE_PROXY:-n}"
REMOTE_ASSISTANCE_PROXY_ADDRESS="${REMOTE_ASSISTANCE_PROXY_ADDRESS:-}"
REMOTE_ASSISTANCE_PROXY_USER="${REMOTE_ASSISTANCE_PROXY_USER:-}"
REMOTE_ASSISTANCE_PROXY_PASSWORD="${REMOTE_ASSISTANCE_PROXY_PASSWORD:-}"
REMOTE_ASSISTANCE_USE_ALTERNATE_PORT="${REMOTE_ASSISTANCE_USE_ALTERNATE_PORT:-n}"
REMOTE_ASSISTANCE_PROJECT_NUMBER="${REMOTE_ASSISTANCE_PROJECT_NUMBER:-}"
REMOTE_ASSISTANCE_INFO="${REMOTE_ASSISTANCE_INFO:-}"
REMOTE_ASSISTANCE_SERVER="${REMOTE_ASSISTANCE_SERVER:-sandbox.clustervision.com}"
REMOTE_ASSISTANCE_ALTERNATE_HOST="${REMOTE_ASSISTANCE_ALTERNATE_HOST:-45.138.39.102}"
REMOTE_ASSISTANCE_ALTERNATE_PORT="${REMOTE_ASSISTANCE_ALTERNATE_PORT:-443}"
REMOTE_ASSISTANCE_STATIC_URL="${REMOTE_ASSISTANCE_STATIC_URL:-https://static.clustervision.com}"
REMOTE_ASSISTANCE_SUPPORT_KEY_URL="${REMOTE_ASSISTANCE_SUPPORT_KEY_URL:-${REMOTE_ASSISTANCE_STATIC_URL}/support.pub}"
REMOTE_ASSISTANCE_KEYS_URL="${REMOTE_ASSISTANCE_KEYS_URL:-https://sandbox.clustervision.com/cgi-bin/keys.py}"
REMOTE_ASSISTANCE_KEYS_USER="${REMOTE_ASSISTANCE_KEYS_USER:-trinityx:trinityx}"
REMOTE_ASSISTANCE_TARGET_HOST="${REMOTE_ASSISTANCE_TARGET_HOST:-localhost}"
REMOTE_ASSISTANCE_TARGET_PORT="${REMOTE_ASSISTANCE_TARGET_PORT:-22}"
REMOTE_ASSISTANCE_CONNECT_TIMEOUT="${REMOTE_ASSISTANCE_CONNECT_TIMEOUT:-15}"
REMOTE_ASSISTANCE_CURL_MAX_TIME="${REMOTE_ASSISTANCE_CURL_MAX_TIME:-30}"
REMOTE_ASSISTANCE_SERVER_ALIVE_INTERVAL="${REMOTE_ASSISTANCE_SERVER_ALIVE_INTERVAL:-30}"
REMOTE_ASSISTANCE_SERVER_ALIVE_COUNT_MAX="${REMOTE_ASSISTANCE_SERVER_ALIVE_COUNT_MAX:-10}"
REMOTE_ASSISTANCE_REQUEST_TTY="${REMOTE_ASSISTANCE_REQUEST_TTY:-no}"
REMOTE_ASSISTANCE_STRICT_HOST_KEY_CHECKING="${REMOTE_ASSISTANCE_STRICT_HOST_KEY_CHECKING:-accept-new}"
REMOTE_ASSISTANCE_USER="${REMOTE_ASSISTANCE_USER:-sandbox}"
REMOTE_ASSISTANCE_RETRY_SLEEP="${REMOTE_ASSISTANCE_RETRY_SLEEP:-5}"

if [ -f "$CONFIG_FILE" ]
then
  # shellcheck source=/dev/null
  . "$CONFIG_FILE"
fi

nc_bin=false
curl_bin=false
ssh_bin=false

if command -v ncat >/dev/null 2>&1
then
  nc_bin=$(command -v ncat)
elif command -v nc >/dev/null 2>&1
then
  nc_bin=$(command -v nc)
fi

if command -v ssh >/dev/null 2>&1
then
  ssh_bin=$(command -v ssh)
else
  die "ssh binary not found. please install the openssh client before running this again."
fi

if command -v curl >/dev/null 2>&1
then
  curl_bin=$(command -v curl)
else
  die "curl binary not found. please install curl before running this again."
fi

privkey=$(expand_path "$REMOTE_ASSISTANCE_PRIVATE_KEY")
if [ ! -f "$privkey" ]
then
  if [ "$NON_INTERACTIVE" = true ]
  then
    die "private key not found at $privkey; set REMOTE_ASSISTANCE_PRIVATE_KEY in $CONFIG_FILE"
  fi

  while [ ! -f "$privkey" ]
  do
    prompt_value privkey "no private key found. please enter private key path. (e.g. ~/.ssh/id_rsa): " ""
    privkey=$(expand_path "$(sanitize_path "$privkey")")
  done
else
  log "private key found at $privkey."
fi

if [ -n "$REMOTE_ASSISTANCE_PUBLIC_KEY" ]
then
  pubkey=$(expand_path "$REMOTE_ASSISTANCE_PUBLIC_KEY")
else
  pubkey="${privkey}.pub"
fi
[ -f "$pubkey" ] || die "public key not found at $pubkey; set REMOTE_ASSISTANCE_PUBLIC_KEY in $CONFIG_FILE"

if [ "$nc_bin" = false ]
then
  warn "netcat not found. proxy support is unavailable."
fi

if [ "$NON_INTERACTIVE" != true ]
then
  if [ "$nc_bin" != false ]
  then
    prompt_value REMOTE_ASSISTANCE_USE_PROXY "use http proxy server? (y/n): " "$REMOTE_ASSISTANCE_USE_PROXY"
    if is_yes "$REMOTE_ASSISTANCE_USE_PROXY"
    then
      prompt_value REMOTE_ASSISTANCE_PROXY_USER "proxy user (empty is none): " "$REMOTE_ASSISTANCE_PROXY_USER"
      prompt_value REMOTE_ASSISTANCE_PROXY_PASSWORD "proxy password (empty is none): " "$REMOTE_ASSISTANCE_PROXY_PASSWORD"
      prompt_value REMOTE_ASSISTANCE_PROXY_ADDRESS "proxy server address including port (e.g. proxy.clustervision.com:3128): " "$REMOTE_ASSISTANCE_PROXY_ADDRESS"
    else
      prompt_value REMOTE_ASSISTANCE_USE_ALTERNATE_PORT "use alternate ssh port and host (static.clustervision.com:443)? (y/n): " "$REMOTE_ASSISTANCE_USE_ALTERNATE_PORT"
      REMOTE_ASSISTANCE_USE_PROXY=n
    fi
  else
    prompt_value REMOTE_ASSISTANCE_USE_ALTERNATE_PORT "use alternate ssh port and host (static.clustervision.com:443)? (y/n): " "$REMOTE_ASSISTANCE_USE_ALTERNATE_PORT"
    REMOTE_ASSISTANCE_USE_PROXY=n
  fi
fi

if is_yes "$REMOTE_ASSISTANCE_USE_PROXY"
then
  [ "$nc_bin" != false ] || die "proxy requested but ncat/nc is not installed"
  [ -n "$REMOTE_ASSISTANCE_PROXY_ADDRESS" ] || die "REMOTE_ASSISTANCE_PROXY_ADDRESS is required when proxy is enabled"
fi

if [ -z "$REMOTE_ASSISTANCE_PROJECT_NUMBER" ] && [ -f /trinity/site ]
then
  REMOTE_ASSISTANCE_PROJECT_NUMBER=$(< /trinity/site)
fi

if [ "$NON_INTERACTIVE" != true ]
then
  prompt_value REMOTE_ASSISTANCE_PROJECT_NUMBER "clustervision project number (empty if unknown): " "$REMOTE_ASSISTANCE_PROJECT_NUMBER"
  prompt_value REMOTE_ASSISTANCE_INFO "additional information (limited to 120 chars): " "$REMOTE_ASSISTANCE_INFO"
fi

projectnumber=$(sanitize_project "$REMOTE_ASSISTANCE_PROJECT_NUMBER")
info=$(sanitize_info "$REMOTE_ASSISTANCE_INFO")

curl_args=(--insecure)
[ -n "$REMOTE_ASSISTANCE_CONNECT_TIMEOUT" ] && curl_args+=(--connect-timeout "$REMOTE_ASSISTANCE_CONNECT_TIMEOUT")
[ -n "$REMOTE_ASSISTANCE_CURL_MAX_TIME" ] && curl_args+=(--max-time "$REMOTE_ASSISTANCE_CURL_MAX_TIME")

if is_yes "$REMOTE_ASSISTANCE_USE_PROXY"
then
  proxy_url="$REMOTE_ASSISTANCE_PROXY_ADDRESS"
  case "$proxy_url" in
    http://*|https://*) ;;
    *) proxy_url="http://${proxy_url}" ;;
  esac
  curl_args+=(--proxy "$proxy_url")
  if [ -n "$REMOTE_ASSISTANCE_PROXY_USER" ]
  then
    curl_args+=(--proxy-user "${REMOTE_ASSISTANCE_PROXY_USER}:${REMOTE_ASSISTANCE_PROXY_PASSWORD}")
  fi
fi

if ! "$curl_bin" "${curl_args[@]}" -s "$REMOTE_ASSISTANCE_STATIC_URL" >/dev/null 2>&1
then
  die "failed to connect to $REMOTE_ASSISTANCE_STATIC_URL. is the domain whitelisted in the proxy?"
fi

cv_pubkey=$("$curl_bin" "${curl_args[@]}" -s "$REMOTE_ASSISTANCE_SUPPORT_KEY_URL")
[ -n "$cv_pubkey" ] || die "failed to retrieve support public key from $REMOTE_ASSISTANCE_SUPPORT_KEY_URL"

ssh_dir="${HOME}/.ssh"
mkdir -p "$ssh_dir"
chmod 700 "$ssh_dir"
touch "$ssh_dir/authorized_keys"
chmod 600 "$ssh_dir/authorized_keys"
if ! grep -s -q -F "$cv_pubkey" "$ssh_dir/authorized_keys"
then
  echo "$cv_pubkey" >> "$ssh_dir/authorized_keys"
fi

ssh_args=(
  "$REMOTE_ASSISTANCE_SERVER"
  -o "ServerAliveInterval=${REMOTE_ASSISTANCE_SERVER_ALIVE_INTERVAL}"
  -o "ServerAliveCountMax=${REMOTE_ASSISTANCE_SERVER_ALIVE_COUNT_MAX}"
  -o ExitOnForwardFailure=yes
  -o BatchMode=yes
  -o "User=${REMOTE_ASSISTANCE_USER}"
  -o "RequestTTY=${REMOTE_ASSISTANCE_REQUEST_TTY}"
  -o "IdentityFile=${privkey}"
)

if [ -n "$REMOTE_ASSISTANCE_STRICT_HOST_KEY_CHECKING" ]
then
  ssh_args+=(-o "StrictHostKeyChecking=${REMOTE_ASSISTANCE_STRICT_HOST_KEY_CHECKING}")
fi

if is_yes "$REMOTE_ASSISTANCE_USE_PROXY"
then
  proxy_hostport="${REMOTE_ASSISTANCE_PROXY_ADDRESS#http://}"
  proxy_hostport="${proxy_hostport#https://}"
  case "$proxy_hostport" in
    *[!A-Za-z0-9._:-]*) die "invalid proxy address for ssh ProxyCommand: $REMOTE_ASSISTANCE_PROXY_ADDRESS" ;;
  esac
  if [ -n "$REMOTE_ASSISTANCE_PROXY_USER" ]
  then
    ssh_args+=(-o "ProxyCommand=${nc_bin} --proxy ${proxy_hostport} --proxy-auth ${REMOTE_ASSISTANCE_PROXY_USER}:${REMOTE_ASSISTANCE_PROXY_PASSWORD} %h %p")
  else
    ssh_args+=(-o "ProxyCommand=${nc_bin} --proxy ${proxy_hostport} %h %p")
  fi
  ssh_args+=(-o "HostName=${REMOTE_ASSISTANCE_ALTERNATE_HOST}" -o "Port=${REMOTE_ASSISTANCE_ALTERNATE_PORT}")
elif is_yes "$REMOTE_ASSISTANCE_USE_ALTERNATE_PORT"
then
  ssh_args+=(-o "HostName=${REMOTE_ASSISTANCE_ALTERNATE_HOST}" -o "Port=${REMOTE_ASSISTANCE_ALTERNATE_PORT}")
fi

while true
do
  response=$("$curl_bin" "${curl_args[@]}" -s --user "$REMOTE_ASSISTANCE_KEYS_USER" -X POST -H 'Content-Type: multipart/form-data' -F "pub=$(< "$pubkey")" -F "info=${info}" -F "trid=${projectnumber}" "$REMOTE_ASSISTANCE_KEYS_URL")
  port=$(printf '%s' "$response" | sed -n 's/[^0-9]*\([0-9][0-9][0-9][0-9][0-9]\).*/\1/p' | sed -n '1p')

  if ! [[ "$port" =~ ^[0-9]{5}$ ]]
  then
    die "invalid port number received: ${response}"
  fi

  log "port received from sandbox is $port"
  "$ssh_bin" "${ssh_args[@]}" -R "${port}:${REMOTE_ASSISTANCE_TARGET_HOST}:${REMOTE_ASSISTANCE_TARGET_PORT}"
  ssh_rc=$?
  warn "ssh tunnel exited with status ${ssh_rc}; retrying in ${REMOTE_ASSISTANCE_RETRY_SLEEP}s"
  sleep "$REMOTE_ASSISTANCE_RETRY_SLEEP"
done
