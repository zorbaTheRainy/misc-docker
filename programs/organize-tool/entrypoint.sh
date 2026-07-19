#!/bin/bash
set -euo pipefail

# ── UID/GID mapping (LSIO-style) ──────────────────────────────────
# Container starts as root; adjust appuser to match host PUID/PGID,
# then drop privileges for the rest of the process.
PUID="${PUID:-911}"
PGID="${PGID:-911}"

EXISTING_GROUP="$(getent group "$PGID" | cut -d: -f1)"
if [ -n "$EXISTING_GROUP" ]; then
    GROUP_NAME="$EXISTING_GROUP"
else
    GROUP_NAME="appgroup"
    groupmod -g "$PGID" "$GROUP_NAME"
fi

if [ "$(id -u appuser)" != "$PUID" ] || [ "$(id -g appuser)" != "$PGID" ]; then
    usermod -u "$PUID" -g "$PGID" appuser 2>/dev/null || true
fi

chown -R appuser:"$GROUP_NAME" /app

# ── Config validation ──────────────────────────────────────────────
CONFIG=/app/config/organize.yaml
CRONTAB=/app/config/crontab
DEFAULT_CRONTAB=/app/crontab.default

if [ ! -f "$CONFIG" ]; then
    echo "entrypoint: $CONFIG not found -- mount your organize rules there (see config/organize.yaml.example)" >&2
    exit 1
fi

echo "entrypoint: validating $CONFIG"
exec su -s /bin/bash -c "organize check '$CONFIG'" appuser

if [ -f "$CRONTAB" ]; then
    echo "entrypoint: using mounted crontab at $CRONTAB"
else
    echo "entrypoint: no crontab mounted, using baked-in default at $DEFAULT_CRONTAB"
    CRONTAB="$DEFAULT_CRONTAB"
fi

# ── Start supercronic as appuser ───────────────────────────────────
echo "entrypoint: starting supercronic with $CRONTAB"
exec su -s /bin/bash -c "exec supercronic '$CRONTAB'" appuser
