#!/bin/bash
# Scheduled entry point for organize. Logs start/end and streams output so
# `docker logs` shows what each run did (or that nothing matched).
set -euo pipefail

CONFIG="${1:-/app/config/organize.yaml}"
STATE_DIR="${ORGANIZE_STATE_DIR:-/app/state}"
HEARTBEAT="${STATE_DIR}/heartbeat"

ts() { date -u +'%Y-%m-%dT%H:%M:%SZ'; }

echo "[run-organize] $(ts) === start ==="
echo "[run-organize] $(ts) config=${CONFIG}"
echo "[run-organize] $(ts) user=$(id -un) uid=$(id -u) gid=$(id -g) home=${HOME:-}"
echo "[run-organize] $(ts) path=${PATH}"
echo "[run-organize] $(ts) which organize=$(command -v organize || echo NOT_FOUND)"

if [ ! -f "$CONFIG" ]; then
    echo "[run-organize] $(ts) ERROR: config not found: $CONFIG" >&2
    exit 1
fi

if [ -d /watched ]; then
    echo "[run-organize] $(ts) /watched top-level:"
    ls -la /watched 2>&1 | sed 's/^/[run-organize]   /' || true
else
    echo "[run-organize] $(ts) WARNING: /watched is missing" >&2
fi

# Unbuffered Python so organize lines hit docker logs immediately
export PYTHONUNBUFFERED=1

set +e
organize run "$CONFIG" 2>&1 | sed 's/^/[organize] /'
rc=${PIPESTATUS[0]}
set -e

if [ "$rc" -eq 0 ]; then
    mkdir -p "$STATE_DIR"
    touch "$HEARTBEAT"
    echo "[run-organize] $(ts) === ok (heartbeat ${HEARTBEAT}) ==="
else
    echo "[run-organize] $(ts) === failed rc=${rc} (heartbeat not updated) ===" >&2
fi

exit "$rc"
