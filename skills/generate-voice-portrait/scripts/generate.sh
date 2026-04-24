#!/usr/bin/env bash
# Upload a generated PNG portrait frame to the speak daemon.
# Usage:
#   generate.sh --name NAME --frame default|slight|open --file PATH
#   generate.sh --status
#   generate.sh --help

set -euo pipefail

PORT="${SPEAK_PORT:-7865}"
HOST="127.0.0.1"
BASE="http://${HOST}:${PORT}"

NAME=""
FRAME=""
FILE=""
STATUS=0

usage() {
  cat <<EOF
Usage:
  $(basename "$0") --name NAME --frame default|slight|open --file PATH
  $(basename "$0") --status
  $(basename "$0") --help

Uploads raw PNG bytes to the speak daemon:
  POST ${BASE}/portraits/{name}?frame={frame}
  Content-Type: image/png

--status pretty-prints portrait availability from GET /voices.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)   NAME="$2"; shift 2 ;;
    --frame)  FRAME="$2"; shift 2 ;;
    --file)   FILE="$2"; shift 2 ;;
    --status) STATUS=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "unknown arg: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ $STATUS -eq 1 ]]; then
  resp=$(curl -sS -f "${BASE}/voices") || {
    echo "error: daemon unreachable at ${BASE}" >&2
    exit 1
  }
  if command -v jq >/dev/null 2>&1; then
    echo "$resp" | jq -r '
      (.voices // .) as $vs |
      ($vs | if type=="array" then . else to_entries | map(.value + {name: .key}) end) as $list |
      $list[] |
      "\(.name // "?")\t"
      + "default=\(.portraits.default // .portrait_default // false)\t"
      + "slight=\(.portraits.slight // .portrait_slight // false)\t"
      + "open=\(.portraits.open // .portrait_open // false)"
    ' | column -t -s $'\t'
  else
    echo "$resp"
  fi
  exit 0
fi

if [[ -z "$NAME" || -z "$FRAME" || -z "$FILE" ]]; then
  echo "error: --name, --frame, and --file are required" >&2
  usage >&2
  exit 2
fi

case "$FRAME" in
  default|slight|open) ;;
  *) echo "error: --frame must be one of: default, slight, open" >&2; exit 2 ;;
esac

if [[ ! -f "$FILE" ]]; then
  echo "error: file not found: $FILE" >&2
  exit 2
fi

URL="${BASE}/portraits/${NAME}?frame=${FRAME}"

http_code=$(curl -sS -o /tmp/generate-voice-portrait.resp -w "%{http_code}" \
  -X POST "$URL" \
  -H "Content-Type: image/png" \
  --data-binary "@${FILE}") || {
    echo "error: upload failed (curl)" >&2
    exit 1
  }

body=$(cat /tmp/generate-voice-portrait.resp 2>/dev/null || true)
rm -f /tmp/generate-voice-portrait.resp

echo "HTTP ${http_code} ${URL}"
[[ -n "$body" ]] && echo "$body"

if [[ "$http_code" -lt 200 || "$http_code" -ge 300 ]]; then
  exit 1
fi
