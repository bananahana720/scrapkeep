# Model brief

Write `recipe.py`: a Blender Python module run by the forge, never by you.

## Contract

- Define `build(params) -> root`. `params` is the dict from `params.json`. `root` is the top
  object (an empty from `common.empty(name)`); every mesh must hang under it.
- `import bpy` and `import common` at the top. The forge puts the shared helper's directory
  on the path and resets the scene before calling `build`. Do not call `common.reset()`,
  `export()` or render anything yourself, and do not read or write files, open sockets or
  start processes.
- Be deterministic: seed any randomness with `random.Random("some-fixed-string")`.
- Build meshes with `common.Part` (box, cyl, rod, beam, ico, uv, prism, ring) and finish
  each with `part.to_object(origin, root)`. Use only the slot names in `params["slots"]`.
  The `paint` slot takes a colour: pass a palette role name (`"oxide"`) or a mix such as
  `common.mix("petrol", "sandstone", 0.35)`. Never type a hex colour. Colours must come from
  the palette roles in `params["palette"]`.

## Conventions

- Metres. Z up. The front faces -Y. The lowest point sits at z = 0. The model is centred on
  x = 0, y = 0 (bounding box centre). Size it as the real object would be in a game where
  the player's rolling ball is 1.7 m across.
- Stay inside the triangle band in `params["band"]`. `common.tris(obj)` counts a part;
  `common.tri_total(root)` counts all. When `params["max_vertices"]` is set, stay under it too.
- Each material slot you use is one draw call; `params["max_draw_calls"]` caps them. When the
  cap is 1 or 2, paint every colour as vertex colours in the `paint` slot instead of reaching
  for separate slots.
- Every part must touch the ground or another part. No floating pieces, no gaps, no holes.

## Build order

1. Silhouette: the one or two big shapes that make it read from across the room.
2. Secondary shapes: lids, handles, legs, panels. Overlap shapes instead of leaving seams.
3. Small detail: bolts, dents, straps, wear. Keep details chunky, never fussy.
4. Slot breakup: split the surfaces across slots so one flat colour never covers it all
   (painted body, bare metal edges, rubber feet, a single accent).

## Look

Chunky low-poly, one flat colour per slot, hard edges, strong shapes, no textures. The style
sections below are the project's rules. Look at the preview from every side before you
finish.

## Concept picture

If `reference/concept.png` exists, it is the target. Read it first. Match its silhouette,
proportions and how its surfaces break up into slots. The picture does not set colours or
slots: those still come from the palette roles and slot list in `params.json`.
