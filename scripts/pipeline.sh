#!/usr/bin/env bash
set -u

usage() {
  cat >&2 <<'EOF'
Usage:
  pipeline.sh <video_path> [options]

Required:
  <video_path>          Source video to transcribe (.mp4 / .mov / .mkv / etc.)

Project location:
  --project-dir <DIR>   Target Remotion project directory. Default: current dir.
                        The project must already be bootstrapped — i.e. it has
                        package.json, src/Typewriter.tsx, and node_modules/.

Pipeline control:
  --dry-run             Stop after writing work/transcription.json and work/segments.ts.
  --no-render           Inject work/segments.ts into src/Typewriter.tsx but do not render.
  --skip-transcribe     Reuse <project-dir>/work/transcription.json from a prior run.
  --yes                 Render without the confirmation prompt.

Transcription / draft:
  --offset <frames>     Shift generated delayFrames by N frames.
  --language <code>     Whisper language hint, e.g. zh or en.
  --model <name>        Whisper model (default: medium). E.g. base, small, medium, large-v3.
  --traditional         Convert simplified Chinese output to Traditional Chinese.

EOF
}

fail() {
  echo "Error: $1" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "$1 is not available on PATH"
}

find_python() {
  for candidate in python3 python; do
    if command -v "$candidate" >/dev/null 2>&1 && "$candidate" --version >/dev/null 2>&1; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

run_step() {
  local label="$1"
  shift
  echo "==> $label"
  if ! "$@"; then
    fail "$label failed"
  fi
}

CALLER_DIR="$(pwd)"
VIDEO_ARG=""
PROJECT_DIR_ARG="."

DRY_RUN=0
OFFSET=0
LANGUAGE=""
MODEL="medium"
TRADITIONAL=0
SKIP_TRANSCRIBE=0
RENDER=1
YES=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --project-dir)
      [ "$#" -ge 2 ] || fail "--project-dir requires a path"
      PROJECT_DIR_ARG="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --no-render)
      RENDER=0
      shift
      ;;
    --yes)
      YES=1
      shift
      ;;
    --offset)
      [ "$#" -ge 2 ] || fail "--offset requires a frame value"
      OFFSET="$2"
      if ! [[ "$OFFSET" =~ ^-?[0-9]+$ ]]; then
        fail "--offset must be an integer"
      fi
      shift 2
      ;;
    --language)
      [ "$#" -ge 2 ] || fail "--language requires a language code"
      LANGUAGE="$2"
      shift 2
      ;;
    --model)
      [ "$#" -ge 2 ] || fail "--model requires a Whisper model name"
      MODEL="$2"
      shift 2
      ;;
    --traditional)
      TRADITIONAL=1
      shift
      ;;
    --skip-transcribe)
      SKIP_TRANSCRIBE=1
      shift
      ;;
    *)
      if [ -z "$VIDEO_ARG" ]; then
        VIDEO_ARG="$1"
        shift
      else
        fail "unknown argument: $1"
      fi
      ;;
  esac
done

[ -n "$VIDEO_ARG" ] || { usage; exit 1; }

# Resolve video path (may be relative to caller's cwd)
case "$VIDEO_ARG" in
  /*|[A-Za-z]:/*|[A-Za-z]:\\*)
    VIDEO_PATH="$VIDEO_ARG"
    ;;
  *)
    VIDEO_PATH="$CALLER_DIR/$VIDEO_ARG"
    ;;
esac
[ -f "$VIDEO_PATH" ] || fail "video file does not exist: $VIDEO_PATH"

# Resolve project dir to an absolute path (relative to caller's cwd, not script dir)
case "$PROJECT_DIR_ARG" in
  /*|[A-Za-z]:/*|[A-Za-z]:\\*)
    PROJECT_DIR="$PROJECT_DIR_ARG"
    ;;
  *)
    PROJECT_DIR="$CALLER_DIR/$PROJECT_DIR_ARG"
    ;;
esac
[ -d "$PROJECT_DIR" ] || fail "project dir does not exist: $PROJECT_DIR"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

# Sanity-check the project is bootstrapped
[ -f "$PROJECT_DIR/package.json" ] || fail "project not bootstrapped (no package.json in $PROJECT_DIR). Copy the skill template into it first."
[ -f "$PROJECT_DIR/src/Typewriter.tsx" ] || fail "missing src/Typewriter.tsx in $PROJECT_DIR. Is this really a typewriter-video project?"

if [ "$SKIP_TRANSCRIBE" -eq 0 ]; then
  require_command ffmpeg
fi
if [ "$RENDER" -eq 1 ]; then
  require_command node
fi
PYTHON_BIN="$(find_python)" || fail "python3 or python is not available on PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

WORK_DIR="$PROJECT_DIR/work"
mkdir -p "$WORK_DIR" || fail "cannot create work directory: $WORK_DIR"
TRANSCRIPTION_JSON="$WORK_DIR/transcription.json"
SEGMENTS_TS="$WORK_DIR/segments.ts"

if [ "$SKIP_TRANSCRIBE" -eq 0 ]; then
  TRANSCRIBE_ARGS=("$SCRIPT_DIR/transcribe.py" "$VIDEO_PATH" --project-dir "$PROJECT_DIR" --model "$MODEL")
  if [ -n "$LANGUAGE" ]; then
    TRANSCRIBE_ARGS+=(--language "$LANGUAGE")
  fi
  if [ "$TRADITIONAL" -eq 1 ]; then
    TRANSCRIBE_ARGS+=(--traditional)
  fi
  run_step "Transcribing video" "$PYTHON_BIN" "${TRANSCRIBE_ARGS[@]}"
else
  [ -f "$TRANSCRIPTION_JSON" ] || fail "missing $TRANSCRIPTION_JSON; cannot use --skip-transcribe"
  echo "==> Skipping transcription"
fi

run_step "Generating typewriter segments" "$PYTHON_BIN" "$SCRIPT_DIR/generate_segments.py" "$TRANSCRIPTION_JSON" --project-dir "$PROJECT_DIR" --offset "$OFFSET"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "Generated:"
  echo "  $TRANSCRIPTION_JSON"
  echo "  $SEGMENTS_TS"
  exit 0
fi

run_step "Injecting segments" "$PYTHON_BIN" "$SCRIPT_DIR/inject_segments.py" --project-dir "$PROJECT_DIR"

echo "Rough subtitles injected into $PROJECT_DIR/src/Typewriter.tsx"
echo "Next: let the Agent edit src/Typewriter.tsx to add features, then preview or render."
if [ "$RENDER" -eq 0 ]; then
  echo "Preview: cd $PROJECT_DIR && npm run studio"
  echo "Render:  cd $PROJECT_DIR && npm run render"
  exit 0
fi
if [ "$YES" -eq 0 ]; then
  read -r -p "Press Enter to render, or Ctrl+C to abort..."
fi
run_step "Rendering video" npm --prefix "$PROJECT_DIR" run render
echo "Done: $PROJECT_DIR/out/typewriter.mp4"
