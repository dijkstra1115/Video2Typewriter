#!/usr/bin/env bash
set -u

usage() {
  cat >&2 <<'EOF'
Usage:
  ./pipeline.sh <video_path> [options]

Primary Agent flow:
  <video_path>          Transcribe media and generate rough subtitle timing.
  --dry-run             Stop after writing work/transcription.json and work/segments.ts.
  --no-render           Inject work/segments.ts into src/Typewriter.tsx but do not render.
  --yes                 Render without the confirmation prompt.

Transcription/draft options:
  --offset <frames>     Shift generated delayFrames by N frames.
  --language <code>     Whisper language hint, e.g. zh or en.
  --model <name>        Whisper model, e.g. base, small, medium.
  --traditional         Convert Chinese output to Traditional Chinese.
  --skip-transcribe     Reuse work/transcription.json.

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
case "$VIDEO_ARG" in
  /*|[A-Za-z]:/*|[A-Za-z]:\\*)
    VIDEO_PATH="$VIDEO_ARG"
    ;;
  *)
    VIDEO_PATH="$CALLER_DIR/$VIDEO_ARG"
    ;;
esac
[ -f "$VIDEO_PATH" ] || fail "video file does not exist: $VIDEO_PATH"

if [ "$SKIP_TRANSCRIBE" -eq 0 ]; then
  require_command ffmpeg
fi
if [ "$RENDER" -eq 1 ]; then
  require_command node
fi
PYTHON_BIN="$(find_python)" || fail "python3 or python is not available on PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

if [ "${VIDEO_PATH:-}" ]; then
  WORK_DIR="$SCRIPT_DIR/work"
  mkdir -p "$WORK_DIR" || fail "cannot create work directory: $WORK_DIR"
  TRANSCRIPTION_JSON="$WORK_DIR/transcription.json"
  SEGMENTS_TS="$WORK_DIR/segments.ts"
fi

if [ "$SKIP_TRANSCRIBE" -eq 0 ]; then
  TRANSCRIBE_ARGS=(transcribe.py "$VIDEO_PATH" --model "$MODEL" --output "$TRANSCRIPTION_JSON")
  if [ -n "$LANGUAGE" ]; then
    TRANSCRIBE_ARGS+=(--language "$LANGUAGE")
  fi
  if [ "$TRADITIONAL" -eq 1 ]; then
    TRANSCRIBE_ARGS+=(--traditional)
  fi
  run_step "Transcribing video" "$PYTHON_BIN" "${TRANSCRIBE_ARGS[@]}"
else
  [ -f "$TRANSCRIPTION_JSON" ] || fail "missing work/transcription.json; cannot use --skip-transcribe"
  echo "==> Skipping transcription"
fi
run_step "Generating typewriter segments" "$PYTHON_BIN" generate_segments.py "$TRANSCRIPTION_JSON" --offset "$OFFSET" --output "$SEGMENTS_TS"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "Generated:"
  echo "  $TRANSCRIPTION_JSON"
  echo "  $SEGMENTS_TS"
  exit 0
fi

run_step "Injecting segments" "$PYTHON_BIN" inject_segments.py

echo "Rough subtitles injected into src/Typewriter.tsx"
echo "Next: let the Agent edit src/Typewriter.tsx to add features, then preview or render."
if [ "$RENDER" -eq 0 ]; then
  echo "Preview: run 'npm run studio'"
  echo "Render: run 'npm run render' when ready"
  exit 0
fi
if [ "$YES" -eq 0 ]; then
  read -r -p "Press Enter to render, or Ctrl+C to abort..."
fi
run_step "Rendering video" npm run render
echo "Done: out/typewriter.mp4"
