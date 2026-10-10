# Terrain brief

This kind makes a seamless ground material, not a 3D model. Read this brief over the system
brief wherever they disagree: there are no triangles, no slots and no turntable. The "band" in
`params.json` is the allowed texture size in pixels. The preview `preview/sheet.png` is one
picture: a 2 x 2 repeat of the lit tile on top, and below it the five maps side by side
(albedo, normal, roughness, ao, height). Look at the repeat for visible seams, a bright
spot that repeats like wallpaper, or lines at the middle cross.

Write `recipe.py`: a Python module run by the forge inside Blender's Python (numpy is there),
never by you.

## Contract

```python
import numpy as np
import texlib as tl          # the forge puts it on the path; its full API is below

def build(params):
    n = 512                  # power of two, between params["band"][0] and params["band"][1]
    ...
    return {"height": h, "albedo": rgb}
```

`build` returns a dict:

| Key | Type | |
| --- | --- | --- |
| `height` | float (n, n), 0 to 1 | required. Becomes the 16-bit height map and drives the normal map |
| `albedo` | float (n, n, 3), sRGB 0 to 1 | required. Build it with `tl.ramp` |
| `roughness` | float (n, n), 0 to 1 | optional, default 0.9 flat. Dry ground is 0.8 to 1.0 |
| `ao` | float (n, n), 0 to 1 | optional, default `tl.ao_from_height(height)` |
| `normal_strength` | float | optional, default 1.5. 1 gentle, 3 deep |
| `uv_scale` | float | optional, default 1.0, written into the `.tres` |

The normal map (OpenGL / Y+, what Godot reads) is always made from your height, so it cannot
disagree with it. Do not read or write files, open sockets or start processes. Be
deterministic: every generator takes a `seed`.

## Rules (the validator checks the first four)

- Seamless. Use only `tl` generators and filters on the whole tile: they all wrap. Never crop
  noise, never draw a shape that is cut by the tile edge, never add a border or vignette,
  never multiply by a gradient across the tile. Seam score must stay near 1.0 (warn above 2,
  fail above 3).
- Palette only. Colours come from `params["palette"]` roles through `tl.ramp`. Never type a
  hex colour. Do not blend two ramped images with a mask: the mix leaves the palette lines.
  Make one scalar field, then ramp it. For colour variety use a ramp with several roles.
- Painted, chunky, not photoreal. Few large shapes, flat bands (`steps=` in `tl.ramp`, or
  `tl.posterize`), visible brush-like warping. The project style sections are below.
- No per-pixel white noise anywhere, and no linear ramps. Every height feature spans many pixels.
- Size is a power of two inside the band. 512 is the default; use 256 for small props,
  1024 only for a hero ground.
- Before you finish, look at the preview. Fix repeats you can see: if one big feature
  stands out and repeats, lower its contrast or add a second scale of variation.

## Ground design hints

- Jungle-gym landforms: a ground tile reads at one metre and under a rolling ball. Big
  shapes at `period` 2 to 4, mid shapes at 6 to 12, grit only as a faint third layer.
- A good height field: `tl.warp(tl.fbm(n, 3, 5, seed), 24, 3, seed)` for the broad form,
  plus `tl.worley(n, 7, seed, "edge")` for cracks or plates, combined by `np.maximum`
  or a weighted sum, then `tl.normalize`.
- Roughness can follow the height (pits rougher than crests) or a separate fbm.

## texlib API

All functions are deterministic from `seed` and return float32 numpy arrays. `n` is the
tile size. A "field" is (n, n) in 0 to 1.

Generators (periodic):

- `tl.value_noise(n, period, seed=0)`: smooth value noise on a `period` x `period` wrapped lattice.
- `tl.gradient_noise(n, period, seed=0)`: Perlin-style, centred on 0.5.
- `tl.fbm(n, period, octaves=4, seed=0, kind="gradient", gain=0.5, lacunarity=2)`: fractal
  sum; the period is multiplied by `lacunarity` (an integer) each octave. Normalised 0 to 1.
  `kind="value"` for softer blobs.
- `tl.ridged(n, period, octaves=4, seed=0)`: crests.
- `tl.worley(n, cells, seed=0, mode="f1")`: cellular noise, wrapped neighbour search. Modes
  `"f1"` (bumps), `"f2"`, `"edge"` (cell borders near 0: cracks, plates), `"id"` (flat random
  value per cell).

Field tools:

- `tl.normalize(a, lo=0, hi=1)`: min-max stretch. `tl.remap(a, in_lo, in_hi, out_lo=0, out_hi=1)`.
- `tl.smoothstep(e0, e1, x)`, `tl.contrast(a, amount)`.
- `tl.blur(a, sigma)`: wrapped Gaussian by FFT, sigma in pixels. Works on fields and images.
- `tl.warp(a, amount, period=3, seed=0)`: wrapped domain warp, `amount` is the largest shift in pixels.
- `tl.shift(a, dy, dx)`: whole-pixel roll (wraps).
- `tl.posterize(t, levels, soften=0.0)`: flat bands; `soften` 0 to 1 rounds the steps.

Colour:

- `tl.ramp(t, stops, palette, steps=None)`: field to colour along palette roles. `stops` is
  `["petrol", "sandstone", "bone"]` (evenly spaced) or `[(0.0, "oxide"), (0.6, "sandstone"), (1.0, "bone")]`.
  `steps=5` posterizes t into 5 flat bands first. Returns (n, n, 3). Pass `params["palette"]`.
- `tl.palette_rgb(palette, role)`: one role as an (r, g, b) float triple.

Derived maps (the entry calls these for you unless you override):

- `tl.normal_from_height(h, strength=1.0)`, `tl.ao_from_height(h, radius=None, strength=1.0)`.

Checks you can run yourself in `build`: `tl.seam_metric(array)` returns the seam score for
one map (about 1.0 is seamless). The forge reports the real score from the written PNGs.

## Work loop for this kind

Read `prompt.md` and `params.json`, write `recipe.py`, run the forge, read the check list,
read `preview/sheet.png`, fix, repeat; at most about six runs. After the first run,
`reference/texlib.py` holds the library source. The final reply says what ground you made
and the artistic calls you made.
