# Speak — TTS Skill for Claude Code

Text-to-speech skill that gives Claude Code a voice. Includes a multi-voice audio daemon with queuing, a web dashboard with animated portraits, and a simple CLI. Synthesis runs on Microsoft Edge TTS by default (free, no API key) or ElevenLabs V3 (`SPEAK_ENGINE=elevenlabs`).

## 🚀 5-Minute Quickstart

**macOS users:** See **[docs/SETUP_MAC.md](docs/SETUP_MAC.md)** for detailed setup.
**Linux users:** See **[docs/SETUP_LINUX.md](docs/SETUP_LINUX.md)** for detailed setup.

```bash
# 1. Install dependencies
brew install ffmpeg
curl -LsSf https://astral.sh/uv/install.sh | sh

# 2. Configure (Edge TTS is the default and needs no key;
#    for ElevenLabs set SPEAK_ENGINE=elevenlabs and ELEVENLABS_API_KEY=sk_your_key)
cp .env.example .env

# 3. Start daemon (detached; uv, or the repo .venv python)
scripts/daemon-start.sh

# 4. Test (in new terminal)
./scripts/say.sh "Hello, world!"
open http://127.0.0.1:7865  # Dashboard
```

Dashboard at **http://127.0.0.1:7865**

## Quick Start

```bash
# Clone
git clone <your-repo-url> speak
cd speak

# Configure (defaults to Edge TTS; edit .env for ElevenLabs)
cp .env.example .env

# Start / stop the daemon
scripts/daemon-start.sh
scripts/daemon-stop.sh

# Speak from any terminal
./scripts/say.sh "Hello, world!"
```

Dashboard at **http://127.0.0.1:7865**

## Requirements

- **macOS or Linux** (playback via `afplay` on macOS, `ffplay` on Linux; override with `SPEAK_PLAYER`)
- **Python >= 3.12**
- **[uv](https://docs.astral.sh/uv/)** (runs the daemon with inline deps — no venv needed)
- **ffmpeg** (`brew install ffmpeg` / `dnf install ffmpeg`) — playback (Linux), duration, envelope extraction, seeking
- **ElevenLabs API key** — only for `SPEAK_ENGINE=elevenlabs` ([get one here](https://elevenlabs.io)); the default Edge engine needs none

## Configuration

### `.env`

```bash
SPEAK_ENGINE=edge                  # edge (default, no key) or elevenlabs
EDGE_TTS_VOICE=                    # Edge fallback voice (default en-IE-EmilyNeural)
ELEVENLABS_API_KEY=your_key_here   # Required only for SPEAK_ENGINE=elevenlabs
ELEVENLABS_VOICE_ID=               # Default voice (optional, defaults to Claude)
SPEAK_CACHE_DIR=                   # Cache dir (default: ./cache)
SPEAK_PORT=                        # HTTP port (default: 7865)
```

Real environment variables always override `.env` values.

### `voices.json`

Each voice carries an ElevenLabs `id` and an Edge neural voice (`edge`). Add your own:

```json
{
  "name": "MyVoice",
  "id": "your-elevenlabs-voice-id",
  "edge": "en-GB-RyanNeural",
  "color": "#ff6600",
  "style": "Brief description"
}
```

With the Edge engine, names without an `edge` mapping use `EDGE_TTS_VOICE` (default `en-IE-EmilyNeural`); list Edge voices with `edge-tts --list-voices`. With the ElevenLabs engine, names not in `voices.json` are looked up on the ElevenLabs API.

## Usage

### CLI

```bash
# Basic
./scripts/say.sh "Hello"

# Choose voice
./scripts/say.sh "Deep thoughts" --voice Adam

# Channel tagging (for multi-agent filtering)
./scripts/say.sh "Status update" --voice Elli --channel researcher

# Session attribution (auto-resolved from the Claude Code environment; override explicitly)
./scripts/say.sh "Build done" --session "My Project Session"

# Priority (jumps queue)
./scripts/say.sh "Alert!" --priority

# Queue control
./scripts/say.sh --status
./scripts/say.sh --skip
./scripts/say.sh --pause
./scripts/say.sh --resume
./scripts/say.sh --clear
./scripts/say.sh --history --limit 10
./scripts/say.sh --replay <id>
```

### As a Claude Code Skill

Install as a skill in `~/.claude/skills/speak/` (or wherever you like), then reference `$SPEAK_DIR/scripts/say.sh` in your `SKILL.md`. See the included `SKILL.md` for the full prompt.

### Dashboard

The web dashboard shows:
- Animated portraits with lip-sync during playback
- Speaker attribution on every line: voice, session, and agent channel
- Transport controls (pause/resume, skip, seek)
- Queue panel with per-channel pause toggles
- History panel with replay and voice filtering

### Multi-Agent Teams

Assign each agent a unique voice for audio differentiation:

```bash
# Agent 1
./scripts/say.sh "Research complete" --voice Rachel --channel researcher

# Agent 2
./scripts/say.sh "Tests passing" --voice Adam --channel tester
```

## Architecture

```
speak/
  daemon/server.py       Starlette HTTP server — TTS (Edge or ElevenLabs), queue, SSE, dashboard
  scripts/daemon-start.sh  Start the daemon detached (idempotent); daemon-stop.sh stops it
  scripts/say.sh         CLI wrapper — talks to daemon, falls back to speak.py
  scripts/speak.py       Standalone TTS (no daemon needed)
  dashboard/index.html   Single-file web dashboard
  dashboard/portraits/   Voice portrait images (3 frames each for lip-sync)
  voices.json            Voice name/ID/color mappings
  cache/                 Cached audio for history replay
  .env                   Local configuration (git-ignored)
  SKILL.md               Claude Code skill prompt
```

### Key Design Decisions

- **No external dependencies in say.sh/speak.py** — only stdlib + `curl`/`afplay`/`python3`. The daemon uses `starlette`+`uvicorn` via `uv run`.
- **macOS-only playback** — uses `afplay` for playback, `afinfo` for duration, `ffmpeg` for seeking/trimming.
- **Single shared queue** — all agents enqueue to one `AudioQueue`. Channel-based filtering and per-channel pause allow multi-agent coordination without overlap.
- **SSE, not WebSocket** — dashboard uses Server-Sent Events for simplicity. Initial state on connect, then incremental `voice_active`, `history_update`, and `pause_state` events.
- **Envelope extraction** — `ffmpeg` decodes to raw PCM, computes RMS per 50ms chunk, normalizes to 0-1 for lip-sync animation.

### API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/speak` | Single-voice TTS |
| `POST` | `/speak/dialogue` | Multi-voice dialogue |
| `GET` | `/queue` | Queue status |
| `POST` | `/queue/skip` | Skip current |
| `POST` | `/queue/pause` | Pause playback |
| `POST` | `/queue/resume` | Resume playback |
| `POST` | `/queue/seek` | Seek within track |
| `POST` | `/queue/clear` | Clear queue |
| `GET` | `/history` | Playback history |
| `POST` | `/history/replay` | Replay cached audio |
| `GET` | `/voices` | Voice configuration |
| `GET` | `/events` | SSE event stream |
| `GET` | `/health` | Health check |
| `GET` | `/` | Dashboard |

## License

MIT
