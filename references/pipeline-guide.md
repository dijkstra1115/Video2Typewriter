# Pipeline Guide — Deep Dive

Reference material for the `video2typewriter` skill. SKILL.md covers the happy
path; this file covers internals, hardware tradeoffs, and recovery from
failure modes.

## What the pipeline does

```
video.mp4
  │
  ├── transcribe.py ──► work/transcription.json
  │      • ffmpeg extracts mono 16 kHz wav
  │      • Whisper produces word-level timestamps
  │      • Optional OpenCC simplified → traditional Chinese conversion
  │
  ├── generate_segments.py ──► work/segments.ts
  │      • Groups words by silence gap (<0.25s = same segment)
  │      • Forces a new segment after 12 words OR 36 chars (whichever first)
  │      • Mode hint:
  │          - "burst"      inside a group
  │          - "normal"     when the inter-word gap is ≤ 0.7s
  │          - "thinking"   when the gap is > 0.7s (suspense beat)
  │          - "deliberate" when a single word lingers > 0.4s in duration
  │      • delayFrames = round(start_seconds × 29.97) + offset
  │      • Merges trailing tiny CJK segments (≤ 2 chars) into the previous
  │        segment if the gap is small
  │
  └── inject_segments.py
         • Backs up src/Typewriter.tsx → src/Typewriter.tsx.bak
         • Backs up src/Root.tsx → src/Root.tsx.bak
         • Replaces the TEXT_SEGMENTS block in place via regex
         • Estimates total typing duration from text length × mode speed
           (+ 60 frame tail) and writes DURATION_SECONDS into Root.tsx
```

The result is a **rough draft** — Whisper occasionally mishears, segment
boundaries are mechanical, and there's no storytelling polish.

## Whisper hardware tradeoff

| Model | RAM/VRAM | Chinese accuracy | Speed (1 min audio, CPU) | Notes |
|---|---|---|---|---|
| `tiny` | ~1 GB | ★★ | ~10s | Drafts only |
| `base` | ~1 GB | ★★★ | ~20s | Decent fallback |
| `small` | ~2 GB | ★★★★ | ~1 min | Solid balance |
| **`medium`** *(default)* | ~5 GB | ★★★★ | ~3 min | **Recommended for Chinese** |
| `large-v3` | ~10 GB VRAM | ★★★★★ | ~6 min on GPU; very slow on CPU | Best accuracy |

On Apple Silicon, all sizes run reasonably on CPU thanks to MPS. On Windows /
Linux without a CUDA GPU, `medium` may take several minutes per minute of
audio; `small` is a safer fallback for older hardware.

## Pipeline flag reference

| Flag | Where | Effect |
|---|---|---|
| `--language zh` | transcribe.py / pipeline.sh | Whisper language hint |
| `--model NAME` | transcribe.py / pipeline.sh | Whisper model name (default: `medium`) |
| `--traditional` | transcribe.py / pipeline.sh | Run OpenCC s2twp on every word |
| `--offset N` | generate_segments.py / pipeline.sh | Shift every `delayFrames` by N frames |
| `--max-words N` | generate_segments.py | Force a break after N words (default 12) |
| `--max-chars N` | generate_segments.py | Force a break before text exceeds N chars (default 36) |
| `--dry-run` | pipeline.sh | Stop after writing `work/segments.ts`, no injection, no render |
| `--no-render` | pipeline.sh | Inject but don't render (preview-friendly) |
| `--skip-transcribe` | pipeline.sh | Reuse cached `work/transcription.json` |
| `--yes` | pipeline.sh | Skip the pre-render confirmation prompt |

## Tuning segment splitting

`generate_segments.py` exposes `--max-words` and `--max-chars` but
**`pipeline.sh` does not forward them**. To experiment, run the script
directly on a cached transcription:

```bash
python scripts/generate_segments.py work/transcription.json \
    --max-words 8 --max-chars 24 \
    --offset 0 --output work/segments.ts
python scripts/inject_segments.py
```

Lower values produce more, shorter segments — useful for fast-paced narration.
Higher values produce fewer, longer segments — better for slow, thoughtful
content.

The silence-gap threshold (currently `gap < 0.25s` = same segment) is hard-
coded inside `build_segments()`. Edit it if Whisper's word timing is too
coarse for your source.

## Refinement workflow

After `--no-render`, the agent should re-read the upstream skill's
`references/content-guide.md` (storytelling techniques) and apply at minimum:

1. **Transcription corrections** — Whisper makes errors on proper nouns,
   technical terms, and Chinese homophones. Read the segments line by line.
2. **Mode promotion** — find 1–3 punchlines per minute and switch them from
   `burst` to `deliberate`. Keep `deliberate` to single words or short
   phrases.
3. **Suspense pauses** — look for moments before reveals or insights. The
   pipeline produces `thinking` only when Whisper records a > 0.7s gap — that
   misses many speaker pauses that *feel* like suspense but aren't long
   enough. Insert manually.
4. **Strike text** at 1–2 narrative turns per video (meaning reversal). The
   pipeline never produces these.
5. **Ghost text** for predictable phrases (rhetorical questions, callbacks).
6. **Emoji beats** (`emojiPicker: true`) at emotional peaks — the pipeline
   does not insert these because Whisper doesn't transcribe emoji.
7. **IME anchor word** (Chinese only): pick 1 thematic word per chapter,
   add `imeInput: true, imePauseFrames: 8`.
8. **Re-balance `delayFrames`** if your additions make a segment longer than
   the audio it's supposed to track. Bump the next segment's `delayFrames` by
   the overflow.

## Troubleshooting

**`openai-whisper is not installed`** — `pip install openai-whisper` (note
`whisper` is a different package). On Windows, may also need
`pip install setuptools-rust`.

**`ffmpeg is not available on PATH`** — install via your package manager and
ensure `ffmpeg -version` works in the same shell that runs the pipeline.

**Whisper kills the process / OOM** — drop one model size
(`--model small` or `base`).

**Garbled Chinese segments / merged English+Chinese** — pass `--language zh`
explicitly. Auto-detect picks wrong on short or mixed clips.

**Typewriter ends before the speaker finishes** — `DURATION_SECONDS` is auto-
computed from typed text length. If you want trailing silence, edit
`src/Root.tsx` after injection and bump the value (or accept the default
60-frame tail and add overrides manually).

**Typewriter races ahead of the speaker** — Whisper word boundaries are
tight; the engine starts typing right at `start_seconds`. Use `--offset 5`
(or so) to delay every segment uniformly, or hand-edit specific
`delayFrames` after injection.

**Typewriter falls behind during dense narration** — Look for segments where
typed text length × mode speed exceeds the inter-segment gap. The fix is
either (a) reduce text (drop filler words from `text`), (b) drop mode
weight (deliberate → burst on a less-critical word), or (c) shrink the
following `delayFrames` to compensate.

**Segments feel too short / too choppy** — raise `--max-words` and
`--max-chars`. To experiment without re-transcribing, see "Tuning segment
splitting" above.

**Segments feel too long / mash multiple beats together** — lower
`--max-words` / `--max-chars`, or reduce the silence-gap threshold inside
`build_segments()` (currently 0.25s).

## How `inject_segments.py` decides DURATION_SECONDS

Per-segment frame estimate:
- Typing: `len(text) × mode_speed` where speed is `{burst: 2, normal: 3, deliberate: 5, thinking: 2}`
- Ghost: +32 frames if `ghostText` is non-empty
- Strike: +`len(strikeText) × 2 + 32` frames if `strikeText` is set
- Final frame = max over segments of `(delayFrames + typing_frames)`

`DURATION_SECONDS = ceil((final_frame + 60) / 29.97)` — that 60 frame tail
gives a 2-second cursor blink at the end.

## Re-running the pipeline cleanly

The injection step is idempotent — repeated runs replace the entire
`TEXT_SEGMENTS` block, not append. To start completely fresh:

```bash
mv src/Typewriter.tsx.bak src/Typewriter.tsx
mv src/Root.tsx.bak src/Root.tsx
rm -rf work/
./pipeline.sh video.mp4 [...]
```

## Updating the bundled template from upstream

Periodically the upstream `yammaku/typewriter-video` ships new themes,
features, or sound packs. To resync:

```bash
git clone --depth 1 https://github.com/yammaku/typewriter-video.git /tmp/upstream
rsync -av --delete /tmp/upstream/assets/template/ assets/template/
rm -rf /tmp/upstream
```

Review the diff, update `THIRD_PARTY_LICENSES.md` if the upstream license
changes, and bump the `version` field in `SKILL.md`.
