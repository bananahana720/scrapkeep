# Pixel kind

Palette-strict pixel art (icons, UI glyphs, pickups) drawn on an integer grid. The agent writes a
recipe against `pixkit.py`; the harness writes the PNG. No colour is ever typed as RGB: a colour is
a palette role and a ramp step, so the output is on the palette by construction and the validator
confirms it.

```sh
F=tools/asset-forge/forge.py
python3 $F make pixel --name scrap_coin "A 16x16 scrap coin pickup icon, 4-frame spin"
python3 $F promote scrap_coin v001
```

Runs in Blender's interpreter (`runner = "blender"`, same sandbox) but uses no Blender API, and
`entry.py` also runs under plain python3. Every `make` spends Claude quota; `run` does not.

## Recipe

```python
import pixkit as px

def build(params):                       # a Canvas, or a list of equal-size Canvases
    c = px.Canvas(16, 16)
    c.ellipse(7.5, 7.5, 6, 6.5, "amber").outline()
    return c

PIXEL = {"fps": 8}                       # optional
```

Colour specs: `"oxide"` (base), `"oxide.dark"`, `("oxide", 3)`, `None` (transparent). Ramp steps are
the sprite kind's: `shadow` x0.42, `dark` x0.68, `base`, `light` 28% toward white.

Canvas ops: `put`, `rect`, `line`, `circle`, `ellipse`, `fill`, `paste`, `replace`, `mirror_x`,
`mirror_y`, `flip_x`, `flip_y`, `shift(dx, dy, wrap)`, `copy`, `outline(colour=None)` (selective:
each outline pixel is the shadow step of the role it touches), `dither(x, y, w, h, a, b, level,
pattern)` (ordered, `bayer4` or `checker`). Ops clip at the canvas edge.

## Outputs and validation

`out/<asset>.png` (frames side by side), `out/<asset>.json` (frame size, frame count, fps, colours
used), `preview/sheet.png` (frames at x8 nearest, and again at 1x).

| Check | Fails when |
| --- | --- |
| `frames` | the image is not `frames` equal frames of the json's size side by side |
| `canvas_band` | frame edge outside the band (prop and kit 8 to 64, hero 16 to 128) |
| `frame_count` | frames outside 1 to 16 |
| `requested_size`, `requested_frames` | the prompt says "16x16" or "4-frame" and the image differs |
| `alpha` | any pixel has alpha other than 0 or 255 |
| `ramp` | any opaque pixel is not one of the 48 ramp colours |
| `content` | a frame is empty |
| `native_grid` | a frame is a uniform k x k upscale (k >= 2, at least a 4 x 4 cell grid): every aligned k x k block is one value |
| `colour_budget` (warn) | distinct colours over the budget (prop 12, kit 16, hero 24) |

## Limits

`native_grid` checks aligned blocks only; art that was scaled and then touched up passes. A prompt
with no size or frame count gets the band check only. The checks say nothing about whether the art
reads or is good: look at the preview. The Godot import should use nearest filtering and no
mipmaps. Promote copies the PNG, json and `<asset>.forge.json` sidecar to
`sketches/core-loop/assets/sprites/<asset>/`.
