# CLAUDE.md

TTS skill for Claude Code. Agents speak aloud via a shared audio queue backed by an HTTP daemon.
Synthesis engine is Microsoft Edge TTS by default (free, no key); ElevenLabs V3 is the alternative.

## Running

```bash
# Start / stop the daemon detached (idempotent; logs to daemon.log)
scripts/daemon-start.sh
scripts/daemon-stop.sh

# Or in the foreground (uv, or the repo .venv python)
uv run daemon/server.py

# Speak (daemon must be running)
scripts/say.sh "Hello"
scripts/say.sh "Hello" --voice Adam --channel my-agent

# Standalone fallback (no daemon)
python3 scripts/speak.py "Hello" --voice VOICE_ID --sync
```

## Environment

Set in `.env` (copy from `.env.example`) or export in shell:

- `SPEAK_ENGINE` — `edge` (default, no key needed) or `elevenlabs`
- `EDGE_TTS_VOICE` — Edge voice for names with no `edge` mapping in `voices.json` (default `en-IE-EmilyNeural`)
- `ELEVENLABS_API_KEY` — Required only when `SPEAK_ENGINE=elevenlabs`
- `ELEVENLABS_VOICE_ID` — Default ElevenLabs voice ID (optional)
- `SPEAK_PORT` — HTTP port (default: 7865)
- `SPEAK_CACHE_DIR` — Audio cache directory (default: ./cache)

## Architecture

1. **`scripts/say.sh`** — Bash CLI. Parses args, POSTs to daemon. Falls back to `speak.py` if daemon is down.
2. **`daemon/server.py`** — Starlette+Uvicorn HTTP server (PEP 723 inline deps). TTS via Edge TTS or the ElevenLabs API (`SPEAK_ENGINE`), audio queue with the platform player (`afplay` on macOS, `ffplay` on Linux), caching, SSE, dashboard. All queue logic lives here.
3. **`scripts/speak.py`** — Standalone fallback. Calls API directly, plays via the platform player, falls back to the platform speech synthesizer (`say` / `spd-say` / `espeak-ng`). No queue.
4. **`dashboard/index.html`** — Single-file web app. Connects via SSE (`/events`). Portraits in `dashboard/portraits/` have three frames per voice for lip-sync.
5. **`voices.json`** — Voice name/ID/color mappings plus each voice's Edge neural voice (`edge`). Loaded by server and dashboard.
6. **`scripts/daemon-start.sh` / `daemon-stop.sh`** — Detached start (uv, else `.venv/bin/python`) with `daemon.log` and `daemon.pid`; stop by pid or port.
7. **`cache/`** — MP3s keyed by history ID for replay. Auto-cleaned after 24h.

## Audio Tags

V3 tags in brackets direct voice *acting* — they're stage directions, not sound effects.
They only apply to the ElevenLabs engine; the Edge engine strips bracketed tags before synthesis.

**Works:** emotions (`[deadpan]`, `[conspiratorial]`), intensity shifts (`[slowly, building intensity]` → `[suddenly shouting]`), character voices (`[old timey radio announcer]`), singing (`[singing softly]`), theatrical asides, compound directions (`[whispering, conspiratorial]`).

**Doesn't work:** sound effects (`[car driving by]`), physical states (`[out of breath]`), volume control (`[even quieter]`).

## Key Design Decisions

- No external deps in say.sh/speak.py — stdlib + curl + the platform audio player + python3 only. Daemon uses starlette+uvicorn via `uv run`.
- macOS + Linux — playback via `afplay` (macOS) or `ffplay`/`mpv` (Linux, `SPEAK_PLAYER` to override); duration via `ffprobe`; seeking via `ffmpeg`.
- Single shared queue — all agents enqueue to one AudioQueue. Channel-based filtering prevents overlap.
- SSE, not WebSocket — simpler. Initial state on connect, then incremental events.
- MP3 validation with auto-retry — `_fetch_tts` and `_fetch_dialogue` validate response headers and retry up to 2 times on invalid audio; `_edge_synthesize` requires >1000 bytes of real MP3 and retries once (Edge can finish cleanly with an empty file).
- Engine switch is one dispatch point — `synthesize_speech` / `synthesize_dialogue`; everything after synthesis (queue, cache, history, SSE, dashboards) is engine-agnostic.
