#!/bin/sh
# Local Mac shim (2026-08-25): speak via Edge TTS — free Microsoft neural voices.
# Default voice is Emily (en-IE), chosen as Wren's stand-in after the ElevenLabs
# key was disabled (likely Sophiie-owned). Not present in fedora's copy of this
# repo — preserve this file and the _fallback_tts_cmd patch in speak.py if a
# future rsync from fedora overwrites the stack.
#
# Pause/queue: if $STATE/speak-paused exists, the line is appended to
# $STATE/speak-queue.txt instead of being played; scripts/speak-resume.sh
# removes the flag and plays the queue in order.
STATE="${HOME}/.local/state/the-lab"
mkdir -p "$STATE"
if [ -e "$STATE/speak-paused" ]; then
  printf '%s\t%s\n' "$(date '+%H:%M')" "$(printf '%s' "$1" | tr '\n' ' ')" >> "$STATE/speak-queue.txt"
  exit 0
fi
# BSD mktemp only substitutes trailing X's: a template like edge-say-XXXXXX.mp3 is taken literally, so a second
# run while the first file exists fails with "File exists" (seen 2026-09-17). Make the temp name first, add the
# extension after.
TMP=$(mktemp "${TMPDIR:-/tmp}/edge-say.XXXXXX") || exit 1
MP3="$TMP.mp3"
trap 'rm -f "$TMP" "$MP3"' EXIT
# Edge TTS can exit 0 and leave an empty or tiny file when the service hiccups; afplay then fails with
# "AudioFileOpen failed" (seen 2026-09-17). Synthesize, check the file is real audio, retry once, then play.
for attempt in 1 2; do
  /Users/isaac/the-workshop/speak/.venv/bin/edge-tts \
    --voice "${EDGE_TTS_VOICE:-en-IE-EmilyNeural}" \
    --text "$1" --write-media "$MP3" >/dev/null 2>&1
  if [ -s "$MP3" ] && [ "$(wc -c < "$MP3")" -gt 1000 ]; then
    afplay "$MP3"
    exit $?
  fi
  sleep 1
done
echo "edge-say: no audio produced after 2 attempts" >&2
exit 1
