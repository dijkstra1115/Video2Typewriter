# Example - Tutorial Explainer

Use this pattern when the speaker teaches a process or framework.

## Source Beat

"The important thing is not to transcribe every word. First identify the
structure, then pick the visual beats, then sync those beats to the narration."

## Directed Segment Pattern

```tsx
const TEXT_SEGMENTS: TextSegment[] = [
  {
    text: "# Do not transcribe everything\n\n",
    mode: "burst",
    file: "method.md",
    language: "markdown",
  },
  {
    text: "The goal is not subtitles.\n",
    mode: "normal",
    strikeText: "more text",
    strikeDelete: "select",
  },
  { text: "\nThe goal is a visual explanation.\n\n", mode: "deliberate" },
  { text: "## Director pass\n", mode: "burst" },
  { text: "1. Find the structure\n", mode: "burst" },
  { text: "2. Pick visual beats\n", mode: "burst" },
  { text: "3. Sync to narration\n", mode: "burst" },
  {
    text: "\n> Board notes should finish as the speaker finishes the phrase.\n",
    mode: "normal",
    ghostText: "That is the whole trick.",
    ghostPauseFrames: 28,
  },
];
```

## Why It Works

- The strike shows a conceptual correction.
- The list gives the viewer a mental model.
- The quote line turns timing advice into a memorable rule.

