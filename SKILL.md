---
name: video2typewriter
description: >
  Turn a video file into a VS Code-style typewriter B-roll synced to its
  narration. Pipeline: ffmpeg extracts audio → Whisper produces word-level
  timestamps → automatic TEXT_SEGMENTS generation with mode hints (burst /
  normal / thinking / deliberate) and frame-accurate delayFrames → injection
  into a bundled Remotion template → render. Use when the user has a
  finished video (talking-head, screencast, podcast clip) and wants the
  typewriter to mirror what's spoken, frame-synced to the audio.
---

# Video2Typewriter

Auto-generate a typewriter B-roll synced to a source video's spoken narration.
A single `git clone` of this skill is self-sufficient — the Remotion engine,
sound packs, fonts, and reference docs are all bundled.

## Output

A working Remotion project where `TEXT_SEGMENTS` is populated by Whisper word-
level timestamps and `delayFrames` is synced to the source video's audio. The
agent then polishes for storytelling, previews in Remotion Studio, and renders
to `out/typewriter.mp4`.

## Supported agent hosts

This skill is usable from Codex and Claude Code. Keep only `name` and
`description` in this file's YAML frontmatter so Codex discovery and packaging
validation stay compatible. Host-specific install paths belong in instructions,
not frontmatter.

License: MIT. Author: dijkstra1115. Version: 0.1.

## Required prerequisites

| Requirement | Why | Install |
|---|---|---|
| **Python ≥ 3.9** | Pipeline scripts | python.org / pyenv / `winget install Python.Python.3.12` |
| **ffmpeg** on PATH | Extract audio from video | `brew install ffmpeg` / `winget install ffmpeg` / apt |
| **Node.js ≥ 18** | Remotion render | nodejs.org |
| **openai-whisper** | Word-level transcription | `pip install openai-whisper` |
| **opencc-python-reimplemented** *(optional)* | Simplified → Traditional Chinese | `pip install opencc-python-reimplemented` |

### Whisper model selection

Default is **`medium`** (good Chinese accuracy on consumer hardware). Override
with `--model` per the table in [references/pipeline-guide.md](references/pipeline-guide.md).
If unsure about the user's hardware, ask before running. Highest quality for
Chinese is `large-v3` and needs roughly 10 GB VRAM or a long CPU wait.

## Step 1: Bootstrap the project

Only the Remotion template needs to be copied into the user's project — the
pipeline scripts stay in the skill and are invoked by absolute path with
`--project-dir` pointing at the project. That way, bug fixes in the skill
propagate to existing projects automatically.

```bash
SKILL=<absolute path to this skill>
PROJECT=./typewriter-from-video   # or any name the user prefers

# Copy ONLY the bundled Remotion template into PROJECT
mkdir -p "$PROJECT"
cp -a "$SKILL/assets/template/." "$PROJECT/"

# Install JS deps (slow — Remotion pulls in Chromium)
(cd "$PROJECT" && npm install)
```

> Resolve `<SKILL>` to the real directory containing this `SKILL.md`. Common
> installs are `~/.codex/skills/video2typewriter` for Codex and
> `~/.claude/skills/video2typewriter` for Claude Code on macOS/Linux, or the
> matching `.codex\skills\video2typewriter` / `.claude\skills\video2typewriter`
> folder under `C:\Users\<user>` on Windows.

## Step 2: Install Python dependencies

```bash
pip install openai-whisper
pip install opencc-python-reimplemented   # only if --traditional will be used
```

The first run downloads the chosen Whisper model (~1.5 GB for `medium`,
~3 GB for `large-v3`). Cached afterwards.

## Step 3: Run the pipeline

Invoke the skill's `pipeline.sh` from anywhere — it takes the project location
as a flag, not as a working directory.

Before running or changing pipeline behavior, read
[`references/pipeline-guide.md`](references/pipeline-guide.md). It explains the
transcription → segment generation → injection flow, model/hardware tradeoffs,
advanced segment splitting, safe re-runs, and recovery from failed runs.

```bash
bash "$SKILL/scripts/pipeline.sh" /path/to/video.mp4 --project-dir "$PROJECT" [options]
```

### Most useful flags

| Flag | Effect |
|---|---|
| `--language zh` / `--language en` | Whisper language hint. Omit for auto-detect (slower, less reliable on short clips) |
| `--model medium` | Whisper model. Default `medium`. |
| `--traditional` | Convert simplified Chinese to Traditional (zh-TW). Requires OpenCC. |
| `--offset N` | Shift every `delayFrames` by N frames (use to compensate for a leading title card) |
| `--no-render` | Inject into `src/Typewriter.tsx` but don't render — gives the agent room to polish |
| `--dry-run` | Stop after writing `work/transcription.json` and `work/segments.ts` |
| `--skip-transcribe` | Reuse `work/transcription.json` from a prior run |
| `--yes` | Skip the confirmation prompt before rendering |

For Chinese (Taiwan), the recommended invocation is:
```bash
bash "$SKILL/scripts/pipeline.sh" demo.mp4 --project-dir "$PROJECT" \
    --language zh --traditional --no-render
```

`--no-render` is intentional — the agent should review and refine before rendering.

## Step 4: Director pass before rendering

The pipeline gives you sync, not direction. After `--no-render`, the agent must
turn the rough transcript into an intentional Markdown B-roll score before
preview or render.

Run refinement in passes, not as one giant edit:

1. transcript correction
2. Markdown structure
3. timing and anchor/FLOW cleanup
4. visual assets
5. performance effects
6. timing validation
7. Remotion Studio preview

Minimum director checklist:

1. **Fix transcription errors** — proper nouns, technical terms, homophones (especially Chinese)
2. **Promote key words** to `mode: "deliberate"` — punchlines, brand names, callouts
3. **Insert `thinking` pauses** before reveals (Whisper won't add suspense for you)
4. **Add `ghostText`** for predictable phrases the audience anticipates
5. **Use `strikeText`** at 1–2 dramatic turns (meaning reversal). The pipeline never produces strikes
6. **Drop emoji** at emotional beats (`emojiPicker: true` for the picker effect)
7. **Consider `imeInput: true`** on 1 anchor word per chapter (Chinese only)
8. **Re-balance `delayFrames`** if the typewriter falls behind — usually because polishing added strike/deliberate that lengthens segments

Additional director requirements:

1. **Structure the board as Markdown** - headings, short paragraphs, quotes, lists, checklists, and file switches
2. **Keep screen text close to narration** - a simplified echo, not unrelated copy
3. **Add visual assets when useful** - screenshots, focused crops, simple diagrams, or image stacks in `public/`
4. **Use animated checkboxes** for milestones, debugging, progress, and feature lists
5. **Validate visual density** - any paused frame should look like an intentional note page

The full director vocabulary lives inside the bundled template at
`src/Typewriter.tsx` (living tutorial) and the bundled references in this
skill. Read only the references needed for the current task:

| Reference | Priority | Use when |
|---|---|---|
| [`references/pipeline-guide.md`](references/pipeline-guide.md) | Conditional | Running, tuning, or debugging the pipeline: Whisper model choice, generated files, segmentation knobs, safe re-runs, troubleshooting. Read relevant sections before changing pipeline behavior. |
| [`references/director-guide.md`](references/director-guide.md) | Required after `--no-render` | Turning rough transcript into directed Markdown B-roll: layout, density, image usage, taste rules |
| [`references/content-guide.md`](references/content-guide.md) | Required when adding effects | Storytelling effect semantics: `deliberate`, `thinking`, `strikeText`, `ghostText`, IME, emoji, checkboxes |
| [`references/aroll-sync.md`](references/aroll-sync.md) | Required when adjusting sync | Re-balancing `delayFrames`, J-cut lead-ins, anchor/FLOW decisions, timing budget checks |
| [`references/API.md`](references/API.md) | Conditional | Looking up exact `TextSegment` fields or engine behavior: images, image stacks, checkboxes, `insertAt`, themes, overlays |
| [`references/audio.md`](references/audio.md) | Conditional | Switching sound packs or debugging keyboard audio sync |

For concrete patterns the agent can imitate, read at most one or two relevant
examples:

| Example | Use when |
|---|---|
| [`references/examples/dev-journey.md`](references/examples/dev-journey.md) | Showing a build process, progress checklist, or skill development story |
| [`references/examples/tutorial-explainer.md`](references/examples/tutorial-explainer.md) | Teaching a method, framework, or workflow |
| [`references/examples/sponsor-segment.md`](references/examples/sponsor-segment.md) | Turning sponsor/tool mentions into useful product notes and screenshots |

## Step 5: Preview, then render

```bash
(cd "$PROJECT" && npm run studio)    # interactive preview at http://localhost:3000
(cd "$PROJECT" && npm run render)    # output: $PROJECT/out/typewriter.mp4
```

To re-render after edits without re-transcribing:
```bash
(cd "$PROJECT" && npm run render)
```

Do not use `pipeline.sh --skip-transcribe` after a manual director pass unless
you intentionally want to regenerate `work/segments.ts` and re-inject
`src/Typewriter.tsx`; that overwrites the edited `TEXT_SEGMENTS` block.

## Files left in the project after a run

```
work/
├── transcription.json    # Whisper word-level output (cached for --skip-transcribe)
└── segments.ts           # Generated TEXT_SEGMENTS

src/
├── Typewriter.tsx        # Now contains the injected TEXT_SEGMENTS
├── Typewriter.tsx.bak    # Backup of pre-injection state
├── Root.tsx              # DURATION_SECONDS auto-updated
└── Root.tsx.bak          # Backup of pre-injection state
```

Re-running the pipeline is safe for regenerating a rough pass — the regex
replaces the whole `TEXT_SEGMENTS` block atomically. After manual edits, render
with `npm run render` instead of re-running the pipeline.

## Project structure (this skill)

```
video2typewriter/
├── SKILL.md
├── README.md                # GitHub README
├── LICENSE                  # MIT
├── THIRD_PARTY_LICENSES.md  # Bundled fonts + sounds + typewriter-video
├── scripts/
│   ├── transcribe.py        # ffmpeg + Whisper → work/transcription.json
│   ├── generate_segments.py # word timestamps → work/segments.ts
│   ├── inject_segments.py   # rewrite src/Typewriter.tsx + Root.tsx
│   └── pipeline.sh          # Orchestrator (calls the three above in order)
├── assets/
│   └── template/            # Bundled Remotion typewriter-video skeleton
└── references/
    ├── pipeline-guide.md    # Deep-dive on the pipeline, hardware, troubleshooting
    ├── content-guide.md     # Storytelling techniques (modes, strike, ghost, IME)
    ├── director-guide.md    # Director pass (Markdown layout, density, images, taste)
    ├── aroll-sync.md        # A-roll sync choreography (delayFrames math)
    ├── API.md               # TextSegment field reference + engine architecture
    ├── audio.md             # Sound packs + per-character audio overrides
    └── examples/            # Directed segment patterns agents can imitate
```

## Troubleshooting

See [references/pipeline-guide.md](references/pipeline-guide.md) for the full
troubleshooting section (Whisper OOM, language detection issues, sync drift,
segment splitting tuning).
