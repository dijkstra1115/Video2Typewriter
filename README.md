# Video2Typewriter

Turn a video into a VS Code-style typewriter B-roll, frame-synced to its
spoken narration. Distributed as a [Claude Code agent skill](https://claude.com/claude-code).

> Pipeline: **video** → ffmpeg → Whisper word-level timestamps →
> auto-generated `TEXT_SEGMENTS` (with mode hints + `delayFrames`) → injected
> into a bundled [yammaku/typewriter-video](https://github.com/yammaku/typewriter-video)
> Remotion project → render to mp4.

## What it does

You give it a talking-head, screencast, or podcast clip. It produces a
typewriter animation that types out what the speaker is saying, in sync with
the audio, ready to be used as B-roll over the original or as a standalone
video.

## Why a separate skill

The upstream [`typewriter-video`](https://github.com/yammaku/typewriter-video)
skill expects you to author `TEXT_SEGMENTS` by hand. This skill bolts a
**Whisper-based transcription pipeline** in front of that, so you can start
from a video file instead of a script.

The Remotion engine itself is still upstream's — this repo bundles it under
`assets/template/` so a single `git clone` is self-sufficient.

## Install (as a Claude Code skill)

```bash
# Tell your AI agent to install this skill:
git clone https://github.com/dijkstra1115/Video2Typewriter.git \
  ~/.claude/skills/video2typewriter
```

Or just say to Claude Code: *"Install the skill at
https://github.com/dijkstra1115/Video2Typewriter"* — the agent will clone it
to the right place.

## Use

Once installed, ask your agent things like:

> 幫我把 demo.mp4 做成繁體中文的打字機影片

> Convert podcast-clip.mp4 into typewriter B-roll, English

The agent will read `SKILL.md`, ask any clarifying questions (Whisper model?
language? aspect ratio?), bootstrap a project from the bundled template, run
the pipeline, refine for storytelling, then render.

## Manual use (without an AI agent)

```bash
# 1. Bootstrap a project directory from the bundled template + scripts
SKILL=~/.claude/skills/video2typewriter
PROJECT=./my-typewriter-video
mkdir -p "$PROJECT"
cp -r "$SKILL/assets/template/"* "$PROJECT/"
cp "$SKILL/scripts/"*.py "$SKILL/scripts/pipeline.sh" "$PROJECT/"
chmod +x "$PROJECT/pipeline.sh"

# 2. Install JS deps (slow — Remotion pulls in Chromium)
cd "$PROJECT"
npm install

# 3. Install Python deps
pip install openai-whisper opencc-python-reimplemented

# 4. Run the pipeline
./pipeline.sh /path/to/video.mp4 --language zh --traditional --no-render

# 5. Edit src/Typewriter.tsx to polish, then preview / render
npm run studio    # interactive preview
npm run render    # output: out/typewriter.mp4
```

See [`SKILL.md`](SKILL.md) for the full workflow, and
[`references/pipeline-guide.md`](references/pipeline-guide.md) for hardware
notes, flag reference, refinement checklist, and troubleshooting.

## Requirements

| | |
|---|---|
| Python | ≥ 3.9 |
| ffmpeg | on PATH |
| Node.js | ≥ 18 |
| `openai-whisper` | `pip install openai-whisper` |
| `opencc-python-reimplemented` *(optional)* | for `--traditional` Chinese conversion |

Whisper model defaults to `medium` — good Chinese accuracy on consumer
hardware. See [`references/pipeline-guide.md`](references/pipeline-guide.md#whisper-hardware-tradeoff)
for the full hardware tradeoff table.

## Project layout

```
Video2Typewriter/
├── SKILL.md                # Skill manifest (frontmatter + workflow)
├── README.md               # this file
├── LICENSE                 # MIT (with upstream attribution)
├── THIRD_PARTY_LICENSES.md # Bundled fonts + sounds + typewriter-video
├── scripts/
│   ├── transcribe.py
│   ├── generate_segments.py
│   ├── inject_segments.py
│   └── pipeline.sh
├── assets/
│   └── template/           # Bundled Remotion typewriter-video skeleton (1.9 MB)
└── references/
    └── pipeline-guide.md
```

## Credits

- The Remotion typewriter engine, themes, sound packs, and template are from
  [yammaku/typewriter-video](https://github.com/yammaku/typewriter-video) (MIT).
- Mechanical keyboard sounds are from [cjlangan/MechSim](https://github.com/cjlangan/MechSim).
- Fonts: [Virgil](https://github.com/excalidraw/virgil) (Excalidraw), [Geist Pixel](https://github.com/vercel/geist-font) (Vercel).
- Transcription is [openai/whisper](https://github.com/openai/whisper).

See [`THIRD_PARTY_LICENSES.md`](THIRD_PARTY_LICENSES.md) for full license texts.

## License

MIT — see [`LICENSE`](LICENSE).
