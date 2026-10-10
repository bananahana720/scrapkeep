# Sprite brief

The forge renders a small sprite sheet from a 3D model: you build (or load) the model, the forge
owns the camera, the lights and the palette. You write `recipe.py` and may set one config dict.

## Contract

- `import bpy` and `import common` as in the model brief. Either define `build(params) -> root`
  (a Blender empty with every mesh under it, built with `common.Part`, palette roles only), or,
  when `reference/source.glb` exists, define no `build` and the forge loads that model. A recipe
  can also call `load_reference()` inside `build` to load the source and add or hide parts.
- If `reference/source.glb` exists the request is a sprite OF THAT MODEL. You cannot read a GLB
  (it is binary), so do not rebuild it from the prompt's words: write only the `SPRITE` dict (no
  `build`), run, and judge the preview. Build your own model only when there is no source.glb.
- Optionally set a module-level dict, every key optional:
  `SPRITE = {"size": 64, "directions": 4, "fit": "tight", "elevation": 30.0, "outline": True, "margin": 2}`
  - `size`: frame edge in px (square), 8 to 256. Take it from the prompt ("64px"); else pick
    32 for a small prop, 64 for a crate-sized one.
  - `directions`: 1, 4 or 8 views around the model, front first. Take it from the prompt.
  - `fit`: `"sphere"` keeps the model the same size in every view; `"tight"` fills the frame
    (use it for icons).
  - `elevation`: camera pitch in degrees (30 is the game's tilt), `outline`: 1 px dark outline,
    `margin`: empty px around the model.
- Do not touch the camera, lights, render settings or files. Do not type hex colours.

## What the forge does with it

It renders each direction at 4x, box-downsamples, cuts alpha at 50%, and snaps every pixel to
the nearest colour of the shade ramp: every palette role at four steps (shadow x0.42, dark
x0.68, base, light 28% toward white). So colour is what the palette roles give your model; light
and shade come from the rig. The sheet is one column, one row per direction.

## Look

- Chunky, readable silhouettes. Few colours. It must read at 1x: the preview shows every frame
  large and again at the real size, so judge the small one.
- A part thinner than the frame divided by 24 vanishes or speckles. Thicken thin parts; drop
  details that become single stray pixels.
- Keep one clear value pattern: light top, mid sides, dark underside. Use two or three palette
  roles, not eight.
- Look at `preview/sheet.png` before you finish: check each direction for speckle, muddy
  value, or a silhouette that reads as a different thing.
