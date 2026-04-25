#!/usr/bin/env python3
"""Extract word-level timestamps from a video with ffmpeg + Whisper."""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent


def fail(message: str, code: int = 1) -> None:
    print(f"Error: {message}", file=sys.stderr)
    raise SystemExit(code)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Transcribe a video file into word-level timestamps.",
    )
    parser.add_argument("video_path", help="Input video path (.mp4, .mov, .mkv, etc.)")
    parser.add_argument(
        "--language",
        help="Whisper language code, for example zh, en, ja. Omit for auto-detect.",
    )
    parser.add_argument(
        "--model",
        default="medium",
        help=(
            "Whisper model name. Default: medium (good Chinese accuracy on "
            "consumer hardware). Use large-v3 for best accuracy if you have "
            ">=10GB VRAM, or base/small to run faster on weak hardware."
        ),
    )
    parser.add_argument(
        "--traditional",
        action="store_true",
        help="Convert Chinese output to Traditional Chinese with OpenCC.",
    )
    parser.add_argument(
        "--output",
        default=str(SCRIPT_DIR / "work" / "transcription.json"),
        help="Output JSON path. Default: work/transcription.json.",
    )
    return parser.parse_args()


def extract_audio(video_path: Path, wav_path: Path) -> None:
    if shutil.which("ffmpeg") is None:
        fail("ffmpeg is not available on PATH.")

    command = [
        "ffmpeg",
        "-y",
        "-i",
        str(video_path),
        "-vn",
        "-acodec",
        "pcm_s16le",
        "-ar",
        "16000",
        "-ac",
        "1",
        str(wav_path),
    ]

    try:
        subprocess.run(command, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    except subprocess.CalledProcessError as exc:
        stderr = exc.stderr.decode("utf-8", errors="replace").strip()
        fail(f"ffmpeg failed while extracting audio.\n{stderr}")


def transcribe_words(
    wav_path: Path,
    model_name: str,
    language: str | None,
    traditional: bool,
) -> list[dict[str, float | int | str]]:
    try:
        import whisper
    except ImportError:
        fail("openai-whisper is not installed. Install it with: pip install openai-whisper")

    try:
        model = whisper.load_model(model_name)
        options: dict[str, str | bool] = {
            "task": "transcribe",
            "word_timestamps": True,
        }
        if language:
            options["language"] = language
        result = model.transcribe(str(wav_path), **options)
    except Exception as exc:  # Whisper can raise several backend-specific exceptions.
        fail(f"Whisper transcription failed: {exc}")

    converter = None
    if traditional:
        try:
            from opencc import OpenCC
        except ImportError:
            fail(
                "OpenCC is not installed. Install it with: "
                "pip install opencc-python-reimplemented"
            )
        converter = OpenCC("s2twp")

    words: list[dict[str, float | int | str]] = []
    for segment_index, segment in enumerate(result.get("segments", [])):
        for item in segment.get("words", []):
            word = str(item.get("word", "")).strip()
            if not word:
                continue
            if converter:
                word = converter.convert(word)
            try:
                start = float(item["start"])
                end = float(item["end"])
            except (KeyError, TypeError, ValueError):
                continue
            words.append({
                "word": word,
                "start": start,
                "end": end,
                "segment": segment_index,
            })
    return words


def main() -> int:
    args = parse_args()
    video_path = Path(args.video_path).expanduser().resolve()
    if not video_path.exists():
        fail(f"input video does not exist: {video_path}")
    if not video_path.is_file():
        fail(f"input path is not a file: {video_path}")

    output_path = Path(args.output).expanduser().resolve()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    temp_wav = Path(tempfile.NamedTemporaryFile(suffix=".wav", delete=False).name)

    try:
        print("Extracting audio...")
        extract_audio(video_path, temp_wav)

        print("Transcribing...")
        words = transcribe_words(temp_wav, args.model, args.language, args.traditional)

        output_path.write_text(
            json.dumps(words, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        print(f"Saved: {output_path}")
        return 0
    finally:
        temp_wav.unlink(missing_ok=True)


if __name__ == "__main__":
    raise SystemExit(main())
