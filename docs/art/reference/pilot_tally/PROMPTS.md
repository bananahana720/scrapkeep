# pilot_tally: turnaround prompts

Multi-angle reference set for Tally's ball cockpit vehicle with its pilot. The modeler works only from this set and the approved boards.

**Inputs (both required, in this order):**
1. Image 1: [`pilots/pilots-reference-tally-ledger-controls.jpg`](../pilots/pilots-reference-tally-ledger-controls.jpg), the approved board.
2. Image 2: [`style/style-shape-moodboard.jpg`](../style/style-shape-moodboard.jpg), the shape language.

**Local run:** Qwen-Image-Edit-2511 (Q4_K_M GGUF transformer, NF4 encoder) on the 4080, 1024x1024, 30 steps, true CFG 4.0, seed 23, one image per view. In ChatGPT: attach both images, then send one prompt per view.

Purpose: give the modeler every side of the body before modelling, so no part is guessed. Check each view against image 1; where they differ, image 1 wins.

## front

```text
Draw Tally's ball cockpit vehicle with its pilot from image 1 as a straight-on front orthographic view. Keep the exact same design, proportions, parts, colours and markings as image 1. Render it as a clean 3D game model reference: soft toy look, machines crisp with bevelled edges, the shape language of image 2. Isolated on a plain light grey background, even studio light, no text, no labels, no scenery, no other characters.
```

## side

```text
Draw Tally's ball cockpit vehicle with its pilot from image 1 as a straight-on right side orthographic view. Keep the exact same design, proportions, parts, colours and markings as image 1. Render it as a clean 3D game model reference: soft toy look, machines crisp with bevelled edges, the shape language of image 2. Isolated on a plain light grey background, even studio light, no text, no labels, no scenery, no other characters.
```

## back

```text
Draw Tally's ball cockpit vehicle with its pilot from image 1 as a straight-on back orthographic view. Keep the exact same design, proportions, parts, colours and markings as image 1. Render it as a clean 3D game model reference: soft toy look, machines crisp with bevelled edges, the shape language of image 2. Isolated on a plain light grey background, even studio light, no text, no labels, no scenery, no other characters.
```

## three_quarter

```text
Draw Tally's ball cockpit vehicle with its pilot from image 1 as a three-quarter front view from slightly above. Keep the exact same design, proportions, parts, colours and markings as image 1. Render it as a clean 3D game model reference: soft toy look, machines crisp with bevelled edges, the shape language of image 2. Isolated on a plain light grey background, even studio light, no text, no labels, no scenery, no other characters.
```

## top

```text
Draw Tally's ball cockpit vehicle with its pilot from image 1 as a top-down orthographic view looking straight down. Keep the exact same design, proportions, parts, colours and markings as image 1. Render it as a clean 3D game model reference: soft toy look, machines crisp with bevelled edges, the shape language of image 2. Isolated on a plain light grey background, even studio light, no text, no labels, no scenery, no other characters.
```

## closeup

```text
Draw Tally's ball cockpit vehicle with its pilot from image 1 as a close-up detail study of its most distinguishing parts (mechanisms, joints, markings). Keep the exact same design, proportions, parts, colours and markings as image 1. Render it as a clean 3D game model reference: soft toy look, machines crisp with bevelled edges, the shape language of image 2. Isolated on a plain light grey background, even studio light, no text, no labels, no scenery, no other characters.
```
