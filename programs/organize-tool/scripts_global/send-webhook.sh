#!/bin/sh
#
# generic_webhook_sender.sh
# ==========================
#
# A generic webhook relay script that can be placed in any program's hooks folder.
# Captures all arguments passed to the script and relays them to the webhook daemon
# via the 'hook_relay' service, which can then route based on script name and args.
#
# Contract:
#   Accepts any number of positional arguments ($@).
#   Sets WEBHOOK_BASE_URL environment variable to override default daemon URL.
#   Always exits 0 (never blocks caller, even on HTTP failure).
#
# Payload structure (JSON):
# {
#   "script_path": "/path/to/script",
#   "script_name": "script.sh",
#   "arg_count": 3,
#   "args": ["arg1", "arg2", "arg3"],
#   "hostname": "container-hostname",
#   "timestamp": "2026-06-19T12:00:00Z"
# }
#
# HTTP fallback chain: curl → wget → python3 → python → perl
# All methods are silent and never block; errors are suppressed.
#

# Webhook base URL (can be overridden by environment variable)
WEBHOOK_BASE_URL="${WEBHOOK_BASE_URL:-http://localhost:5432/webhook/"}${1}

# Webhook site name (can be overridden by environment variable)
WEBHOOK_SITE="${WEBHOOK_SITE:-hook_relay}"

# Construct the full webhook URL
WEBHOOK_URL="${WEBHOOK_BASE_URL%/}/${WEBHOOK_SITE}"

# This is a debugging tool
# Log file (can be overridden by environment variable)
WEBHOOK_SENDER_LOG="${WEBHOOK_SENDER_LOG:-.}/generic_webhook_sender.log"
WEBHOOK_SENDER_LOG_ON="${WEBHOOK_SENDER_LOG_ON:-0}"

# #####################
# !!!! WARNING  !!!!
# This is a debugging tool
# Running this in production causes massive security risks (e.g., exposing API keys in clear text)
# It is HIGHLY recommended to set WEBHOOK_SEND_ALL_ENVS=0 in production to avoid exposing sensitive data
# #####################
# Include all environment variables in payload (can be overridden by environment variable)
WEBHOOK_SEND_ALL_ENVS="${WEBHOOK_SEND_ALL_ENVS:-0}"

# Env vars whose names start with this prefix are always forwarded (empty = disabled)
WEBHOOK_ENV_PREFIX="${WEBHOOK_ENV_PREFIX:-}"

# Derive script path and name (no external basename needed)
SCRIPT_PATH="$0"
SCRIPT_NAME="${0##*/}"

# Print cwd and script info to stdout early (always visible for debugging)
# echo "[$(date '+%Y-%m-%d %H:%M:%S')] cwd=$PWD script=$SCRIPT_NAME args=$#"

# Get hostname, with fallback
HOSTNAME="$(hostname 2>/dev/null || echo 'unknown')"

# Get UTC timestamp (BusyBox date supports -u and %z format)
TIMESTAMP="$(date -u +'%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || echo 'unknown')"

# Get IANA timezone (preferred), fallback to offset, then UTC
TIMEZONE="$(cat /etc/timezone 2>/dev/null || date +%:z 2>/dev/null || echo 'UTC')"

# Get container ID from cgroup (if running in a container), else empty
CONTAINER_ID="$(grep -o '[0-9a-f]\{64\}' /proc/self/cgroup 2>/dev/null | head -1)"

# Find a writable temp directory: prefer TMPDIR env, then /tmp, then /var/tmp, else cwd
_WORK_DIR=""
for _try in "${TMPDIR:-}" /tmp /var/tmp; do
  if [ -n "$_try" ] && [ -d "$_try" ] && [ -w "$_try" ]; then
    _WORK_DIR="$_try"
    break
  fi
done
_WORK_DIR="${_WORK_DIR:-.}"

# Announce the work directory to the user
echo "[generic_webhook_sender.sh] Temporary files → $_WORK_DIR"
echo '[generic_webhook_sender.sh] Any immediately previous "Permission denied" errors were about finding a writable temp directory.'

# JSON string escape function (handles backslash, quote, tab)
_json_escape_string() {
  printf '%s' "$1" | sed \
    -e 's/\\/\\\\/g' \
    -e 's/"/\\"/g' \
    -e 's/	/\\t/g'
}

# Build arg list as JSON array with proper escaping
ARG_JSON="["
ARG_COUNT=0
for arg in "$@"; do
  if [ "$ARG_COUNT" -gt 0 ]; then
    ARG_JSON="$ARG_JSON,"
  fi
  ESCAPED_ARG="$(_json_escape_string "$arg")"
  ARG_JSON="$ARG_JSON\"$ESCAPED_ARG\""
  ARG_COUNT=$((ARG_COUNT + 1))
done
ARG_JSON="$ARG_JSON]"

# Build filtered environment variables JSON object
ENV_JSON="{}"
if [ "$WEBHOOK_SEND_ALL_ENVS" = "1" ] || [ -n "$WEBHOOK_ENV_PREFIX" ]; then
  _env_body=""
  _env_count=0
  while IFS= read -r _line; do
    _ename="${_line%%=*}"
    _evalue="${_line#*=}"
    # Decide whether to include this var
    _include=0
    [ "$WEBHOOK_SEND_ALL_ENVS" = "1" ] && _include=1
    if [ -n "$WEBHOOK_ENV_PREFIX" ]; then
      case "$_ename" in
        "${WEBHOOK_ENV_PREFIX}"*) _include=1 ;;
      esac
    fi
    [ "$_include" = "0" ] && continue
    # Credential filter always applies
    case "$(echo "$_ename" | tr '[:upper:]' '[:lower:]')" in
      *key*|*secret*|*password*|*passwd*|*token*|*credential*|*auth*|*api*) continue ;;
    esac
    _esc_name="$(_json_escape_string "$_ename")"
    _esc_val="$(_json_escape_string "$_evalue")"
    if [ "$_env_count" -gt 0 ]; then
      _env_body="$_env_body,"
    fi
    _env_body="${_env_body}\"${_esc_name}\":\"${_esc_val}\""
    _env_count=$((_env_count + 1))
  done <<ENVEOF
$(env)
ENVEOF
  ENV_JSON="{${_env_body}}"
fi

# Pre-escape all string fields that go into the JSON heredoc
_ESC_SCRIPT_PATH="$(_json_escape_string "$SCRIPT_PATH")"
_ESC_SCRIPT_NAME="$(_json_escape_string "$SCRIPT_NAME")"
_ESC_WORK_DIR="$(_json_escape_string "$_WORK_DIR")"
_ESC_TIMEZONE="$(_json_escape_string "$TIMEZONE")"
_ESC_HOSTNAME="$(_json_escape_string "$HOSTNAME")"
_ESC_PWD="$(_json_escape_string "$PWD")"

# Create JSON payload
PAYLOAD=$(cat <<EOF
{
  "script_path": "$_ESC_SCRIPT_PATH",
  "script_name": "$_ESC_SCRIPT_NAME",
  "script_tmp_dir": "$_ESC_WORK_DIR",
  "container_id": "$CONTAINER_ID",
  "arg_count": $ARG_COUNT,
  "args": $ARG_JSON,
  "timestamp": "$TIMESTAMP",
  "timezone": "$_ESC_TIMEZONE",
  "hostname": "$_ESC_HOSTNAME",
  "cwd": "$_ESC_PWD",
  "env": $ENV_JSON
}
EOF
)

# Write to log file (only if enabled)
if [ "$WEBHOOK_SENDER_LOG_ON" = "1" ]; then
  {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Script: $SCRIPT_NAME | Args: $ARG_COUNT"
    echo "$PAYLOAD"
    echo ""
  } >> "$WEBHOOK_SENDER_LOG" 2>/dev/null || true
fi

# Temp file with PID to avoid collisions on concurrent calls
TEMP_FILE="${_WORK_DIR}/hook_relay_$$.json"

# Detect temp file creation failure and prepare error webhook if needed
_SEND_ERROR=""
if ! echo "$PAYLOAD" > "$TEMP_FILE" 2>/dev/null; then
  _SEND_ERROR="Failed to create temp file in $_WORK_DIR (cwd=$PWD)"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $_SEND_ERROR"
fi

# HTTP POST with fallback chain
_http_post() {
  local url="$1"
  local file="$2"

  # Try curl first
  if command -v curl >/dev/null 2>&1; then
    curl --silent --fail --output /dev/null -X POST \
         -H "Content-Type: application/json" \
         --data-binary "@$file" \
         "$url" 2>/dev/null && return 0
  fi

  # Try wget (BusyBox wget in containers)
  if command -v wget >/dev/null 2>&1; then
    wget --quiet --output-document=/dev/null \
         --post-file="$file" \
         --header="Content-Type: application/json" \
         "$url" 2>/dev/null && return 0
  fi

  # Try python3
  if command -v python3 >/dev/null 2>&1; then
    _WBHK_URL="$url" _WBHK_FILE="$file" python3 -c '
import os, sys, json
try:
  from urllib.request import Request, urlopen
  url = os.environ["_WBHK_URL"]
  fpath = os.environ["_WBHK_FILE"]
  with open(fpath, "rb") as f:
    data = f.read()
  req = Request(url, data=data, headers={"Content-Type": "application/json"})
  urlopen(req, timeout=5)
except:
  pass
' 2>/dev/null && return 0
  fi

  # Try python (Python 2)
  if command -v python >/dev/null 2>&1; then
    _WBHK_URL="$url" _WBHK_FILE="$file" python -c '
import os, sys, json
try:
  import urllib2
  url = os.environ["_WBHK_URL"]
  fpath = os.environ["_WBHK_FILE"]
  with open(fpath, "rb") as f:
    data = f.read()
  req = urllib2.Request(url, data=data, headers={"Content-Type": "application/json"})
  urllib2.urlopen(req, timeout=5)
except:
  pass
' 2>/dev/null && return 0
  fi

  # Try perl (HTTP::Tiny in core since 5.14)
  if command -v perl >/dev/null 2>&1; then
    _WBHK_URL="$url" _WBHK_FILE="$file" perl -e '
use strict; use warnings;
eval {
  require HTTP::Tiny;
  my $url = $ENV{_WBHK_URL};
  my $fpath = $ENV{_WBHK_FILE};
  open my $fh, "<", $fpath or die;
  my $data = do { local $/; <$fh> };
  close $fh;
  my $http = HTTP::Tiny->new(timeout => 5);
  $http->request("POST", $url, {
    headers => { "Content-Type" => "application/json" },
    content => $data
  });
};
' 2>/dev/null && return 0
  fi

  # All methods failed; silently return
  return 1
}

# Send payload or error webhook
if [ -n "$_SEND_ERROR" ]; then
  # Send error webhook inline (no temp file available)
  _ESC_ERR="$(_json_escape_string "$_SEND_ERROR")"
  _ERR_PAYLOAD="{\"script_name\":\"$_ESC_SCRIPT_NAME\",\"cwd\":\"$_ESC_PWD\",\"work_dir\":\"$_ESC_WORK_DIR\",\"error\":\"$_ESC_ERR\",\"args\":$ARG_JSON}"
  if command -v curl >/dev/null 2>&1; then
    echo "$_ERR_PAYLOAD" | curl --silent --output /dev/null -X POST \
         -H "Content-Type: application/json" --data-binary @- "$WEBHOOK_URL" 2>/dev/null || true
  fi
else
  # Normal path: send via temp file
  _http_post "$WEBHOOK_URL" "$TEMP_FILE" 2>/dev/null || true
  rm -f "$TEMP_FILE"
fi

exit 0
