#!/bin/bash
set -euo pipefail

# ── UID/GID mapping (LSIO-style) ──────────────────────────────────
# Container starts as root; adjust appuser to match host PUID/PGID,
# then drop privileges for the rest of the process.
PUID="${PUID:-911}"
PGID="${PGID:-911}"

EXISTING_GROUP="$(getent group "$PGID" | cut -d: -f1 || true)"
if [ -n "$EXISTING_GROUP" ]; then
    GROUP_NAME="$EXISTING_GROUP"
else
    GROUP_NAME="appgroup"
    groupmod -g "$PGID" "$GROUP_NAME"
fi

if [ "$(id -u appuser)" != "$PUID" ] || [ "$(id -g appuser)" != "$PGID" ]; then
    if ! usermod -u "$PUID" -g "$PGID" appuser; then
        echo "entrypoint: WARNING: usermod failed; appuser may not match PUID/PGID=${PUID}/${PGID}" >&2
    fi
fi

# Writable paths only — /app/config may be a read-only mount
mkdir -p /app/state
chown -R appuser:"$GROUP_NAME" /home/appuser /app/state /app/crontab.default 2>/dev/null || true

# ── Config validation ──────────────────────────────────────────────
CONFIG=/app/config/organize.yaml
CRONTAB=/app/config/crontab
DEFAULT_CRONTAB=/app/crontab.default

echo "entrypoint: PUID=${PUID} PGID=${PGID} group=${GROUP_NAME}"
echo "entrypoint: PATH=${PATH}"
echo "entrypoint: organize binary: $(command -v organize || echo NOT_FOUND)"

if [ ! -f "$CONFIG" ]; then
    echo "entrypoint: $CONFIG not found -- mount your organize rules there (see config/organize.yaml.example)" >&2
    echo "entrypoint: /app/config contents:" >&2
    ls -la /app/config 2>&1 || true
    exit 1
fi

echo "entrypoint: validating $CONFIG"
runuser -u appuser -- organize check "$CONFIG"

if [ -f "$CRONTAB" ]; then
    echo "entrypoint: using mounted crontab at $CRONTAB"
else
    echo "entrypoint: no crontab at $CRONTAB; using baked-in default at $DEFAULT_CRONTAB"
    CRONTAB="$DEFAULT_CRONTAB"
fi

echo "entrypoint: ----- crontab (${CRONTAB}) -----"
sed 's/^/entrypoint: | /' "$CRONTAB"
echo "entrypoint: ----- end crontab -----"

# ── Start supercronic as appuser ───────────────────────────────────
# Job stdout/stderr is captured by supercronic and written to container logs.
# SUPERCRONIC_DEBUG=1 adds schedule/parse detail.
SC_ARGS=()
if [ "${SUPERCRONIC_DEBUG:-0}" = "1" ]; then
    SC_ARGS+=(-debug)
    echo "entrypoint: SUPERCRONIC_DEBUG=1 (verbose supercronic)"
fi

echo "entrypoint: starting supercronic ${SC_ARGS[*]} $CRONTAB"
echo "entrypoint: follow with: docker logs -f organize-watcher"
echo "entrypoint: shell with: docker exec -u appuser -it organize-watcher bash"
exec runuser -u appuser -- env PATH="$PATH" supercronic "${SC_ARGS[@]}" "$CRONTAB"
