# Director Guide - Markdown B-roll Composition

Use this guide after the pipeline has produced a synced rough draft. The goal is
to turn transcript-like text into a polished Markdown board that feels directed,
not merely subtitled.

This guide answers: what should appear on screen, how it should be arranged, and
when the agent may add visual assets. Use it together with:

- `content-guide.md` for the meaning of effects such as `strikeText`, `ghostText`,
  `imeInput`, emoji, and checkboxes.
- `aroll-sync.md` for frame timing, anchors, FLOW segments, and validation.
- `API.md` for the exact `TextSegment` fields available in the Remotion engine.

## Director Pass Order

Do not polish everything at once. Work in passes so sync and taste stay
controllable.

1. **Transcript correction pass** - fix names, technical terms, Chinese
   homophones, and obvious Whisper errors.
2. **Markdown structure pass** - convert raw narration into headings, short
   paragraphs, quotes, lists, checklists, and code-like notes.
3. **Timing pass** - keep `delayFrames` only on beat anchors; remove unnecessary
   mid-sentence anchors; ensure each beat finishes before the narration moves on.
4. **Visual asset pass** - add screenshots, simple generated images, diagrams, or
   image stacks only where the narration references something visual.
5. **Performance pass** - add a small number of `deliberate`, `thinking`,
   `ghostText`, `strikeText`, `imeInput`, emoji, and checkbox effects.
6. **Validation pass** - run or reason through timing budgets; fix overrun, long
   idle gaps, and effect stacking.
7. **Preview pass** - preview in Remotion Studio before final render.

## Screen Text Principles

The board is not a subtitle track. It is a live note-taking performance.

- Keep the board as a simplified echo of the narration. Do not write a different
  idea just because it is clever.
- Preserve concrete nouns: product names, people, companies, dates, numbers,
  examples, URLs, and labels.
- Remove filler: "um", repeated clauses, hedges, and spoken false starts unless
  the hesitation is the point.
- Split one spoken sentence into multiple visual beats if the idea has multiple
  parts.
- If the speaker is explaining a framework, build it step by step instead of
  showing only the final conclusion.
- Any paused frame should look like a useful slide or notebook page.

## Markdown Composition Rules

Use Markdown as the visual layout language.

- Start chapters with a strong heading: `#`, `##`, or a short title line.
- Use blank lines intentionally. A paragraph break is a visual breath.
- Prefer short paragraphs: 1-2 lines on screen, then a blank line.
- Use numbered lists for process, sequence, ranking, or decisions.
- Use checklists for progress, milestones, feature completion, or debugging.
- Use blockquotes for definitions, claims, warnings, and "the core idea".
- Use code blocks or code-like snippets only when the narration is actually about
  code, commands, prompts, or configuration.
- Use arrows (`->`) for cause and effect, pipelines, and transformations.
- Use tables sparingly. They are high-density and should appear only when the
  speaker is explicitly comparing dimensions.

Good board text:

```tsx
{ text: "## Development path\n", mode: "burst", file: "dev-journey.md", language: "markdown" },
{ text: "1. Frame-by-frame analysis -> first prototype\n", mode: "normal" },
{ text: "2. Polish the prototype:\n", mode: "normal" },
{ text: "   - [ ] Chinese IME effect\n", mode: "burst", checkbox: { checkAfterFrames: 18 } },
{ text: "   - [ ] Storytelling pass\n", mode: "burst", checkbox: { checkAfterFrames: 22 } },
```

Weak board text:

```tsx
{ text: "Today I want to share how I made this thing and then I tried a few things and it finally worked...", mode: "normal" }
```

## Density And Rhythm

Aim for movement without clutter.

- Target one meaningful board update every 3-5 seconds.
- Avoid more than 6-8 visible lines unless the section is intentionally a list.
- If the cursor idles for more than 5 seconds, add a short connective note,
  image, checkbox, ghost text, or beat marker.
- Do not put `delayFrames` on every segment. Anchor the first segment of a beat,
  then let the rest FLOW.
- When a list is spoken quickly, only anchor the list title or first item; let the
  remaining items burst out.

## Visual Asset Rules

The agent may add images when they help the viewer understand what the speaker is
talking about. Images must be grounded in the narration.

Use images for:

- Product screenshots, app screens, dashboards, websites, pricing pages.
- Before/after comparisons.
- Video thumbnails or frames when the speaker refers to another video.
- Diagrams for workflows, architecture, funnels, decision trees, or feedback
  loops.
- Sponsor sections where the speaker mentions concrete features or UI.

Avoid images for:

- Generic decoration.
- Concepts that can be clearer as one Markdown line.
- Every paragraph. Images should be punctuation, not wallpaper.

Asset placement:

- Put project-specific images in `<project>/public/`.
- When the user provides or mentions image files outside the Remotion project
  (for example next to the source video or in the workspace root), copy them
  into `<project>/public/` before use. Do not move or delete the originals.
- Use concise filenames: `skill-grid.png`, `pricing-card.png`, `workflow-loop.png`.
- Reference copied assets with paths relative to `public/`, for example
  `image: { src: "screenshots/pricing-card.png", ... }`.
- Prefer focused crops over full-page screenshots.
- Insert single images with `image: { src, heightLines, width, animation }`.
- Insert rapid visual collections with `imageStack`.
- Use `fade` for evidence, `slide-up` for cards/lists, and `scale` for a reveal.

Example:

```tsx
{
  text: "The real problem: videos are not text.\n",
  mode: "normal",
  image: {
    src: "video-grid.png",
    heightLines: 5,
    width: 62,
    animation: "scale",
    alt: "Reference video grid"
  }
}
```

## Effect Taste Rules

Effects are performance marks. Use fewer than you think.

- `deliberate`: one key word or short phrase, not whole sentences.
- `thinking`: before a reveal, contradiction, or important next thought.
- `strikeText`: 1-2 strong reversals per video or chapter. Both the deleted and
  final phrase must make sense.
- `ghostText`: predictable audience reactions, obvious conclusions, callbacks,
  or rhetorical completions.
- `imeInput`: Chinese anchor words only. Prefer one thematic word per chapter.
- `emojiPicker`: emotional punctuation at peaks, not every joke.
- `checkbox`: progress, completion, debugging, feature lists, or milestones.
- `file`: use file switches as chapter changes or context shifts.
- `insertAt`: afterthoughts, caveats, corrections, or "oh wait" moments.

## Image Generation And Capture Guidance

When the source material needs an image and no usable screenshot exists, the
agent may create a simple supporting visual. Keep it editorial, not decorative.

Good generated assets:

- A clean workflow diagram.
- A mock dashboard card that represents the idea being explained.
- A thumbnail-like card for a referenced concept.
- A simple comparison board with two columns.

Bad generated assets:

- Photorealistic stock imagery unrelated to the narration.
- Random abstract backgrounds.
- Fake screenshots that imply a real product UI unless clearly used as a mock.

If generating or capturing images is not possible in the current environment,
use a placeholder segment name and continue the text choreography:

```tsx
// TODO(asset): add public/workflow-loop.png
{ text: "Workflow:\n", mode: "normal", image: { src: "workflow-loop.png", heightLines: 5, animation: "fade" } }
```

## Director Acceptance Checklist

Before render, verify:

- The first 5 seconds hook the viewer visually.
- Each beat is readable before the speaker moves on.
- The board text matches the narration closely enough that reading and listening
  do not conflict.
- The screen is not just a transcript; it has headings, lists, quotes, or visual
  hierarchy.
- Effects are sparse and meaningful.
- Images appear only when they add evidence or clarity.
- Any frame paused mid-video looks like an intentional note page.
- Timing has no obvious overrun, long idle gap, or mid-sentence anchor stall.
