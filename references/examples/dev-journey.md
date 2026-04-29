# Example - Development Journey

Use this pattern when the speaker narrates how a tool, skill, product, or
experiment was built.

## Source Beat

"At first I tried using text to describe the video, but it was too hard. So the
solution became a video camera analysis skill. The AI analyzes frames one by one
and understands the video structure. The first version worked, then I continued
polishing Chinese IME and storytelling."

## Directed Segment Pattern

```tsx
const TEXT_SEGMENTS: TextSegment[] = [
  {
    text: "Describing video with text = hard 😤\n\n",
    mode: "burst",
    file: "dev-journey.md",
    language: "markdown",
    delayFrames: 0,
  },
  { text: "## Solution: video lens analysis Skill\n", mode: "burst" },
  { text: "AI scans frames -> understands structure\n\n", mode: "normal" },
  {
    text: "",
    mode: "burst",
    image: {
      src: "skill-demo.png",
      heightLines: 5,
      width: 62,
      animation: "scale",
      alt: "Skill demo screen",
    },
  },
  { text: "\nWant this Skill? Like the video 👍\n\n", mode: "burst" },
  { text: "## Development path\n", mode: "burst" },
  { text: "1. Frame analysis -> first prototype ✅\n", mode: "normal" },
  { text: "2. Continue polishing:\n", mode: "normal" },
  {
    text: "   - [ ] Chinese IME effect\n",
    mode: "burst",
    checkbox: { checkAfterFrames: 18 },
  },
  {
    text: "   - [ ] Storytelling pass\n",
    mode: "burst",
    checkbox: { checkAfterFrames: 24 },
  },
];
```

## Why It Works

- The first line is a hook, not a greeting.
- The solution is a short Markdown heading.
- The image appears as evidence after the concept is introduced.
- The checklist turns "still polishing" into visible progress.

