#!/bin/bash
set -euo pipefail

CONFIG=/app/config/organize.yaml
CRONTAB=/app/config/crontab
DEFAULT_CRONTAB=/app/config/crontab.default

if [ ! -f "$CONFIG" ]; then
    echo "entrypoint: $CONFIG not found -- mount your organize rules there (see config/organize.yaml.example)" >&2
    exit 1
fi

echo "entrypoint: validating $CONFIG"
organize check "$CONFIG"

if [ -f "$CRONTAB" ]; then
    echo "entrypoint: using mounted crontab at $CRONTAB"
else
    echo "entrypoint: no crontab mounted, using baked-in default at $DEFAULT_CRONTAB"
    CRONTAB="$DEFAULT_CRONTAB"
fi

echo "entrypoint: starting supercronic with $CRONTAB"
exec supercronic "$CRONTAB"
