#!/usr/bin/env bash
# daemon-stop.sh — stop the voice daemon started by daemon-start.sh.
#
# Uses daemon.pid when present, otherwise the process listening on the daemon
# port. Only a process running daemon/server.py is ever signalled: TERM first,
# then KILL if it is still alive after the grace period.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PIDFILE="$REPO_ROOT/daemon.pid"
GRACE_SECONDS=10

if [[ -z "${SPEAK_PORT:-}" && -f "$REPO_ROOT/.env" ]]; then
  SPEAK_PORT="$(sed -n 's/^SPEAK_PORT=[[:space:]]*//p' "$REPO_ROOT/.env" | tail -n1 | tr -d '"'"'")"
fi
PORT="${SPEAK_PORT:-7865}"

is_daemon() {  # $1 = pid
  ps -p "$1" -o command= 2>/dev/null | grep -q 'daemon/server.py'
}

PID=""
if [[ -f "$PIDFILE" ]] && is_daemon "$(cat "$PIDFILE")"; then
  PID="$(cat "$PIDFILE")"
else
  for p in $(lsof -nP -ti "tcp:$PORT" -sTCP:LISTEN 2>/dev/null); do
    if is_daemon "$p"; then PID="$p"; break; fi
  done
fi

if [[ -z "$PID" ]]; then
  echo "daemon not running on port $PORT"
  rm -f "$PIDFILE"
  exit 0
fi

kill "$PID"
for _ in $(seq 1 $((GRACE_SECONDS * 2))); do
  if ! kill -0 "$PID" 2>/dev/null; then
    rm -f "$PIDFILE"
    echo "daemon stopped (pid $PID)"
    exit 0
  fi
  sleep 0.5
done

echo "daemon-stop: pid $PID ignored TERM for ${GRACE_SECONDS}s; sending KILL" >&2
kill -9 "$PID" 2>/dev/null || true
sleep 0.5
if kill -0 "$PID" 2>/dev/null; then
  echo "daemon-stop: pid $PID still alive after KILL" >&2
  exit 1
fi
rm -f "$PIDFILE"
echo "daemon stopped (pid $PID, forced)"
