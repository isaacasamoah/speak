#!/bin/sh
# Resume voice: remove the pause flag and play every queued line in order,
# prefixed with the time it was queued, then clear the queue.
STATE="${HOME}/.local/state/the-lab"
rm -f "$STATE/speak-paused"
Q="$STATE/speak-queue.txt"
[ -s "$Q" ] || { echo "nothing queued"; exit 0; }
n=$(wc -l < "$Q" | tr -d ' ')
/Users/isaac/the-workshop/speak/scripts/edge-say.sh "Welcome back. $n message$( [ "$n" = 1 ] || echo s ) queued while you were away."
while IFS="$(printf '\t')" read -r t msg; do
  /Users/isaac/the-workshop/speak/scripts/edge-say.sh "At $t: $msg"
done < "$Q"
: > "$Q"
echo "played $n queued message(s)"
