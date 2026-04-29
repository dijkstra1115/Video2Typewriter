# Example - Sponsor Segment

Use this pattern when the speaker mentions a sponsor, tool, pricing page, or
product UI.

## Source Beat

"They have a generous free tier, the setup takes a few minutes, and the dashboard
shows exactly what is happening."

## Directed Segment Pattern

```tsx
const TEXT_SEGMENTS: TextSegment[] = [
  {
    text: "## Sponsor note\n\n",
    mode: "burst",
    file: "sponsor.md",
    language: "markdown",
  },
  { text: "Why it matters:\n", mode: "normal" },
  {
    text: "- [ ] generous free tier\n",
    mode: "burst",
    checkbox: { checkAfterFrames: 16 },
  },
  {
    text: "- [ ] setup in minutes\n",
    mode: "burst",
    checkbox: { checkAfterFrames: 18 },
  },
  {
    text: "- [ ] dashboard explains itself\n\n",
    mode: "burst",
    checkbox: { checkAfterFrames: 20 },
  },
  {
    text: "Dashboard preview:\n",
    mode: "normal",
    image: {
      src: "sponsor-dashboard.png",
      heightLines: 5,
      width: 70,
      animation: "slide-up",
      alt: "Sponsor dashboard",
    },
  },
];
```

## Why It Works

- The sponsor section becomes useful notes instead of ad copy.
- Checkboxes create satisfying progress.
- The screenshot is tied to a concrete spoken claim.

