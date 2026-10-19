# Perch anchor: tall Dressing props as Dispatcher perches

Status: reader's contract, wave 18. The reader is `src/world/perch_points.gd` `props()`. The writer is the Dressing lane (`src/presentation/park_props.gd`, `tools/blender/park/props/kit.py`), which owns the kit manifests. No park JSON changes: coverage beyond posts and landform rims comes from dressing.

## Contract

An optional per-variant key `perch` in a `scrapkeep-park-props-kit/1` manifest.

| Item | Rule |
|---|---|
| Key | `perch`, on a variant row beside `lod`, `tris`, `radius`, `height`. Absent means the variant offers no perch. |
| Value | A list `[x, y, z]` of three finite JSON numbers, metres. |
| Frame | The prop's local frame: origin at the foot centre, Y up, as the GLB is authored (before instance yaw, tilt and scale). |
| Meaning | The centre of a deck where a Dispatcher may stand. The prop must hold the deck without a mast. |
| World position | `inst.pos + inst.basis * (inst.scale * local)`, for an instance from `ParkProps.expand()`. The perch top is that point's world y. |
| Collision | Dressing props carry none, so a prop's own footprint never blocks its own perch. |

## Validity rules (all in `PerchPoints.props`)

A prop top becomes a candidate only when every line holds. Same gates as the landform tops, applied to the world position.

| Rule | Value |
|---|---|
| Source | Not a litter instance; the variant carries a well-formed `perch`; instance `pos`, `basis`, `scale` finite (scale > 0). |
| Height | Top is 6 to 10 m above the ground under it (`PERCH_MIN`, `PERCH_MAX`). Scale and tilt move the top, so a 12 m top from scale 1.5 is refused. |
| Deck | The 3.6 m deck square (corners at +-1.8 m) is flat to within 1.5 m (`LEVEL_M`). |
| Clearance | 2.5 m (`DECK_CLEAR`) from every solid footprint, route lane and waymark chain, and the landmark. |
| Play area | Inside the play rect shrunk by 10 m (`PLAY_INSET_M`). |
| Spacing | Tops within 14 m (`SPACING_M`) of an earlier top keep the first, in x then z order, and also yield to landform tops already taken. |

The result is `[Vector4(x, top_y, z, ground_y)]`, sorted by x then z, and joins the landform list that `PerchPoints.pick()` reads. A kit with no `perch` key gives `[]`, and `terrain.perch_near` answers exactly as before (terrain.gd expands the vignette file only when the kit carries a `perch` key and passes its schema; the result is cached per stage with the other sources and cleared in `_free_stage`).

Validator for Dressing kit tests: `PerchPoints.perch_errors(kit)` returns one string per malformed entry: not three finite numbers, `y` at or below the foot, or `y` more than 0.5 m above the variant `height`. Expected result is `[]`. `PerchPoints.kit_has_perch(kit)` says whether any variant carries the key.

## Re-measuring coverage

`godot --headless --path sketches/core-loop --script res://tools/perch_coverage.gd [-- dam flume ...]` prints per park: posts, landform tops, prop tops (zero until a park has a vignette file with perch keys), and the share of 200 seeded pack points with a perch within 40 m. Baseline before props, stages 1, 2, 4, 5: 8, 19, 1.5, 34 percent. The `tests/perch_points_test.gd` floors must still pass; `tests/perch_props_test.gd` holds the fixture, planted negatives and the terrain wiring.

## Request to Dressing

1. In `tools/blender/park/props/kit.py`, export `perch` into the manifest for a tall variant from an empty (or node) named `perch` in the GLB: its location, converted to the prop's local frame in metres (Blender Z up to glTF Y up), written as `[x, y, z]`.
2. Aim the empty at 6 to 10 m over the foot at scale 1.0 on level ground, and give the deck a 3.6 m flat top that holds without a mast. Scale 0.75 to 1.25 stays in band for an 8 m anchor.
3. Call `PerchPoints.perch_errors(kit)` in the kit tests; it must return `[]`.
4. Place tall perch props off route lanes with 15 m or more of open flat ground around them, or the gates drop them.
