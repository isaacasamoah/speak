#!/usr/bin/env bash
# daemon-start.sh — start the voice daemon detached, idempotently.
#
# If /health already answers on the configured port, nothing happens.
# Otherwise the daemon is started in the background (uv if installed, else the
# repo's .venv python), logging to daemon.log, and its pid is written to daemon.pid.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG="$REPO_ROOT/daemon.log"
PIDFILE="$REPO_ROOT/daemon.pid"

# SPEAK_PORT from the environment wins; else .env; else 7865 (same rule as the daemon).
if [[ -z "${SPEAK_PORT:-}" && -f "$REPO_ROOT/.env" ]]; then
  SPEAK_PORT="$(sed -n 's/^SPEAK_PORT=[[:space:]]*//p' "$REPO_ROOT/.env" | tail -n1 | tr -d '"'"'")"
fi
PORT="${SPEAK_PORT:-7865}"
HEALTH="http://127.0.0.1:$PORT/health"

if curl -sf --connect-timeout 1 "$HEALTH" >/dev/null 2>&1; then
  echo "daemon already up: $HEALTH"
  exit 0
fi

if command -v uv >/dev/null 2>&1; then
  CMD=(uv run daemon/server.py)
elif [[ -x "$REPO_ROOT/.venv/bin/python" ]]; then
  CMD=("$REPO_ROOT/.venv/bin/python" daemon/server.py)
else
  echo "daemon-start: need uv or $REPO_ROOT/.venv/bin/python (with starlette, uvicorn, edge-tts)" >&2
  exit 1
fi

cd "$REPO_ROOT"
echo "=== daemon-start $(date '+%Y-%m-%d %H:%M:%S') via ${CMD[0]} ===" >> "$LOG"
nohup "${CMD[@]}" >> "$LOG" 2>&1 < /dev/null &
echo $! > "$PIDFILE"
disown

for _ in $(seq 1 30); do
  if curl -sf --connect-timeout 1 "$HEALTH" >/dev/null 2>&1; then
    echo "daemon up (pid $(cat "$PIDFILE")): $HEALTH"
    exit 0
  fi
  sleep 0.5
done

echo "daemon-start: no /health answer after 15s; see $LOG" >&2
exit 1
