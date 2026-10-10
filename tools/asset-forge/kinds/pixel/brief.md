# Pixel brief

Write `recipe.py`: pure Python run by the forge, never by you. You draw pixel art on an integer
grid with `pixkit`. Colours are palette role names, never RGB, so the palette holds by
construction.

## Contract

- `import pixkit as px`. Define `build(params) -> Canvas` for a still, or a list of Canvases of
  equal size for an animation. Optionally `PIXEL = {"fps": 8}`.
- Take the canvas size and frame count from the prompt ("16x16", "4-frame"): `px.Canvas(16, 16)`.
  The validator fails a size or frame count that differs from the prompt.
- No imports besides `pixkit` and the standard library. No files, sockets or processes. Be
  deterministic.
- Draw at 1 px per cell. Art authored in 2x2 or bigger blocks and scaled up fails
  (`native_grid`): every pixel is a decision.

## pixkit

- Colour: `"oxide"` (base step), `"oxide.dark"`, `("oxide", 3)`, or `None` to erase. Steps, dark
  to light: `shadow` (x0.42), `dark` (x0.68), `base`, `light` (28% toward white). Roles are in
  `params["palette"]`. `px.shift_step("oxide", -1)` moves a colour one step along its ramp.
- `Canvas(w, h)`: `put(x, y, c)`, `rect(x, y, w, h, c, filled=True)`, `line(x0, y0, x1, y1, c)`,
  `circle(cx, cy, r, c, filled=True)` (use `7.5` as the centre of a 16 px canvas),
  `ellipse(cx, cy, rx, ry, c)`, `fill(x, y, c)` (flood), `paste(other, x, y)`, `replace(old, new)`.
- `mirror_x()` copies the left half onto the right, `mirror_y()` the top onto the bottom;
  `flip_x()`, `flip_y()`, `shift(dx, dy, wrap=False)`, `copy()`.
- `outline(colour=None)`: a 1 px outer outline. With no colour it is selective: each outline
  pixel is the `shadow` step of the role it touches. `outline("charcoal.shadow")` for one colour.
- `dither(x, y, w, h, a, b, level=0.5, pattern="bayer4")`: ordered dither between two ramp
  shades over a rectangle (only on pixels already drawn).

## Look

- Chunky, readable silhouettes. Few colours: two roles, three shades each, plus an outline is
  plenty. The colour budget warns when exceeded.
- Light from the top left: lighter steps top and left, darker steps bottom and right. One
  1 px highlight beats a gradient.
- It must read at 1x. The preview shows the frames at 8x and again at real size: judge the
  small one. Fewer, bolder pixels.
- Animation: keep the silhouette stable, move one thing. A spin is the width changing, not a
  rotation.
- Look at `preview/sheet.png` before you finish.
