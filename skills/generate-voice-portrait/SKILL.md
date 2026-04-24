---
name: generate-voice-portrait
description: Generate a 3-frame lip-sync portrait set for a speak voice and upload it to the daemon. Use when adding a new voice or refreshing an existing portrait.
allowed-tools: Skill, Bash, Read
---

# Generate Voice Portrait

Creates the three portraits (mouth closed / slightly open / wide open) the dashboard uses to animate lip-sync, then uploads them to the speak daemon.

> Paths below use `{base}` as shorthand for this skill's base directory, provided via the "Base directory for this skill" context injected when the skill loads.

## Inputs

- `name` (required) — voice name, e.g. `Josh`. Used in the upload URL and to key portraits.
- `style` (required) — short descriptor of the character, e.g. "deep-voiced confident male, short dark hair".
- `kind` (optional, default `default`) — portrait flavor:
  - `default` → stylized portrait avatar, neutral lighting, shoulders-up
  - `codex` → robotic, terminal green glow, ASCII/monospace motifs
  - `user` → warm, human, friendly
  - `custom` → use visual notes verbatim (freeform)
- `notes` (optional) — extra visual details (outfit, palette, seed). For `kind: custom`, this becomes the character description.

## Workflow

### 1. Compose the base character prompt

Pick the flavor template for `kind`, then concatenate `style` and `notes`:

- `default`: `"stylized portrait avatar of <style>, shoulders-up, neutral studio lighting, solid pastel background"`
- `codex`: `"robotic avatar of <style>, terminal green CRT glow, ASCII/monospace motifs, dark background, shoulders-up"`
- `user`: `"warm friendly human portrait of <style>, soft natural lighting, approachable, shoulders-up, solid background"`
- `custom`: use `notes` verbatim as the character description

Keep the description fixed across all three frames. Only the mouth shape varies.

### 2. Generate 3 frames via the `generate-image` skill

Invoke the `generate-image` skill three times. Every prompt MUST include this exact clause:

> `identical character, same face, same hair, same outfit, same background color, only the mouth shape changes`

Per-frame mouth direction:

| frame | mouth direction |
|-------|----|
| `default` | `mouth closed, relaxed neutral expression` |
| `slight` | `mouth slightly open mid-speech, small gap between lips` |
| `open` | `mouth wide open in a vowel shape, teeth visible` |

Each call returns a saved PNG path (under `Archive/Files/...`). Record the three paths.

### 3. Upload each PNG to the daemon

```bash
{base}/scripts/generate.sh --name <Name> --frame default --file <path-to-default.png>
{base}/scripts/generate.sh --name <Name> --frame slight  --file <path-to-slight.png>
{base}/scripts/generate.sh --name <Name> --frame open    --file <path-to-open.png>
```

The helper POSTs raw PNG bytes to `http://127.0.0.1:7865/portraits/{name}?frame={frame}` with `Content-Type: image/png` and exits non-zero on any HTTP error.

### 4. Verify

```bash
{base}/scripts/generate.sh --status
```

Confirms all three frames are registered for the voice.

## Rules

- Do NOT reimplement image generation — always delegate to `generate-image`.
- Reuse the exact same character description across frames; change only the mouth clause.
- If a frame comes back off-model (different face/outfit/background), regenerate just that frame before uploading.
- The speak daemon must be running (`uv run daemon/server.py`). If `--status` reports unreachable, surface that to the user instead of retrying blindly.
- Voice `name` should match the name used by `say.sh --voice <Name>` and the entry in `voices.json`.
