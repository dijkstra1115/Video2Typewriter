#!/usr/bin/env python3
"""Convert Whisper word timestamps into a minimal TEXT_SEGMENTS block."""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


FPS = 29.97


@dataclass
class Word:
    text: str
    start: float
    end: float
    segment: int | None = None


@dataclass
class Segment:
    words: list[Word]
    mode_hint: str
    delay_frames: int

    @property
    def text(self) -> str:
        return format_words(self.words) + " "

    @property
    def mode(self) -> str:
        if len(self.words) == 1 and (self.words[0].end - self.words[0].start) > 0.4:
            return "deliberate"
        return self.mode_hint


def fail(message: str, code: int = 1) -> None:
    print(f"Error: {message}", file=sys.stderr)
    raise SystemExit(code)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate a minimal TEXT_SEGMENTS block from transcription.json.",
    )
    parser.add_argument("transcription_json", help="Path to transcription.json")
    parser.add_argument(
        "--offset",
        type=int,
        default=0,
        help="Shift all delayFrames by this many frames.",
    )
    parser.add_argument(
        "--max-words",
        type=int,
        default=12,
        help="Force a new segment after this many words when no pause is detected.",
    )
    parser.add_argument(
        "--max-chars",
        type=int,
        default=36,
        help="Force a new segment before text grows beyond this many characters.",
    )
    parser.add_argument(
        "--project-dir",
        default=".",
        help=(
            "Target Remotion project directory. Output is written to "
            "<project-dir>/work/segments.ts unless --output overrides it. "
            "Default: current working directory."
        ),
    )
    parser.add_argument(
        "--output",
        default=None,
        help=(
            "Override output TypeScript path. Defaults to "
            "<project-dir>/work/segments.ts."
        ),
    )
    return parser.parse_args()


def load_words(path: Path) -> list[Word]:
    try:
        raw: Any = json.loads(path.read_text(encoding="utf-8-sig"))
    except FileNotFoundError:
        fail(f"transcription file does not exist: {path}")
    except json.JSONDecodeError as exc:
        fail(f"invalid JSON in {path}: {exc}")

    if not isinstance(raw, list):
        fail("transcription JSON must be a list of word objects.")

    words: list[Word] = []
    for index, item in enumerate(raw):
        if not isinstance(item, dict):
            fail(f"word entry {index} is not an object.")
        text = str(item.get("word", "")).strip()
        if not text:
            continue
        try:
            start = float(item["start"])
            end = float(item["end"])
        except (KeyError, TypeError, ValueError):
            fail(f"word entry {index} must include numeric start and end.")
        if end < start:
            fail(f"word entry {index} has end before start.")
        raw_segment = item.get("segment")
        segment = (
            int(raw_segment)
            if isinstance(raw_segment, (int, float, str))
            and str(raw_segment).isdigit()
            else None
        )
        words.append(Word(text=text, start=start, end=end, segment=segment))

    if not words:
        fail("transcription contains no non-empty words.")
    return words


def frame_at(seconds: float, offset: int) -> int:
    return max(0, round(seconds * FPS) + offset)


def is_cjk_char(char: str) -> bool:
    code = ord(char)
    return (
        0x3400 <= code <= 0x4DBF
        or 0x4E00 <= code <= 0x9FFF
        or 0xF900 <= code <= 0xFAFF
    )


def contains_cjk(text: str) -> bool:
    return any(is_cjk_char(char) for char in text)


def is_ascii_word(text: str) -> bool:
    return bool(re.fullmatch(r"[A-Za-z0-9]+", text))


def should_join_ascii_fragments(left: str, right: str) -> bool:
    if re.fullmatch(r"[0-9]+\.", left) and re.fullmatch(r"[0-9]+", right):
        return True
    if not (is_ascii_word(left) and is_ascii_word(right)):
        return False
    return min(len(left), len(right)) <= 2 and len(left) + len(right) <= 8


def needs_space(left: str, right: str, cjk_context: bool) -> bool:
    if not left or not right:
        return False
    if not cjk_context:
        return True

    left_last = left[-1]
    right_first = right[0]
    if contains_cjk(left_last) or contains_cjk(right_first):
        return False
    if should_join_ascii_fragments(left, right):
        return False
    return True


def format_words(words: list[Word]) -> str:
    parts: list[str] = []
    cjk_context = any(contains_cjk(word.text) for word in words)
    for word in words:
        text = word.text.strip()
        if not text:
            continue
        if parts and needs_space(parts[-1], text, cjk_context):
            parts.append(" ")
        parts.append(text)
    return "".join(parts)


def segment_char_count(words: list[Word]) -> int:
    if not words:
        return 0
    return len(format_words(words))


def build_segments(
    words: list[Word],
    offset: int,
    max_words: int = 12,
    max_chars: int = 36,
) -> list[Segment]:
    segments: list[Segment] = []
    current = Segment(
        words=[words[0]],
        mode_hint="burst",
        delay_frames=frame_at(words[0].start, offset),
    )

    for word in words[1:]:
        previous = current.words[-1]
        gap = word.start - previous.end
        segment_changed = (
            word.segment is not None
            and previous.segment is not None
            and word.segment != previous.segment
        )

        if gap < 0.25 and not segment_changed:
            would_exceed_words = len(current.words) >= max_words
            would_exceed_chars = segment_char_count(current.words + [word]) > max_chars
            if not would_exceed_words and not would_exceed_chars:
                current.words.append(word)
                continue

            segments.append(current)
            current = Segment(
                words=[word],
                mode_hint="burst",
                delay_frames=frame_at(word.start, offset),
            )
            continue

        segments.append(current)
        mode = "normal" if gap <= 0.7 else "thinking"
        current = Segment(
            words=[word],
            mode_hint=mode,
            delay_frames=frame_at(word.start, offset),
        )

    segments.append(current)
    return merge_tiny_segments(segments, max_chars)


def merge_tiny_segments(segments: list[Segment], max_chars: int) -> list[Segment]:
    result: list[Segment] = []
    for segment in segments:
        text = segment.text.strip()
        is_tiny = len(text) <= 2 and any(contains_cjk(word.text) for word in segment.words)
        if is_tiny and result:
            previous = result[-1]
            previous_end = previous.words[-1].end
            gap = segment.words[0].start - previous_end
            merged_chars = segment_char_count(previous.words + segment.words)
            if gap < 0.35 and merged_chars <= max_chars + 6:
                previous.words.extend(segment.words)
                continue
        result.append(segment)
    return result


def ts_string(value: str) -> str:
    return json.dumps(value, ensure_ascii=False)


def write_segments_ts(segments: list[Segment], path: Path) -> None:
    lines = [
        "// Generated by generate_segments.py. Paste or inject into src/Typewriter.tsx.",
        "export const TEXT_SEGMENTS: TextSegment[] = [",
    ]
    for segment in segments:
        lines.append(
            "  "
            + "{ "
            + f"text: {ts_string(segment.text)}, "
            + f"mode: {ts_string(segment.mode)}, "
            + f"delayFrames: {segment.delay_frames} "
            + "},"
        )
    lines.append("];")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    args = parse_args()
    transcription_path = Path(args.transcription_json).expanduser().resolve()
    words = load_words(transcription_path)
    if args.max_words < 1:
        fail("--max-words must be at least 1.")
    if args.max_chars < 1:
        fail("--max-chars must be at least 1.")

    segments = build_segments(words, args.offset, args.max_words, args.max_chars)

    project_dir = Path(args.project_dir).expanduser().resolve()
    if args.output:
        segments_ts = Path(args.output).expanduser().resolve()
    else:
        segments_ts = project_dir / "work" / "segments.ts"
    segments_ts.parent.mkdir(parents=True, exist_ok=True)
    write_segments_ts(segments, segments_ts)

    print(f"Saved: {segments_ts}")
    print(f"Segments: {len(segments)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
