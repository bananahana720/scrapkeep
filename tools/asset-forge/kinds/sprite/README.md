# Sprite kind

Renders a palette-true sprite sheet from a 3D model at fixed directions. The recipe supplies the
model (built with `common.Part`, or `reference/source.glb` from `--reference model.glb`) and an
optional `SPRITE` dict. The harness owns the camera, the lights and every pixel's colour.

```sh
F=tools/asset-forge/forge.py
python3 $F make sprite --name crate_icon --reference sketches/core-loop/assets/models/scrap_crate.glb "A 4-direction 64px icon of the scrap crate"
python3 $F promote crate_icon v001
```

Needs Blender (the same sandboxed run as the model kind). Every `make` spends Claude quota; `run` does not.

## SPRITE keys

| Key | Default | Meaning |
| --- | --- | --- |
| `size` | 64 | square frame edge in px, 8 to 256 |
| `directions` | 4 | 1, 4 or 8 views; row k is the camera moved k steps anticlockwise from the model's front (-Y) |
| `fit` | `sphere` | `sphere`: one scale for every view; `tight`: fills the frame |
| `elevation` | 30.0 | camera pitch in degrees, 0 to 80 |
| `outline` | `True` | 1 px outline in the ramp's darkest colour |
| `margin` | 2 | empty px around the model, 0 to size/4 |
| `supersample` | 4 | render at this multiple, then box-downsample |

## Pipeline

1. Orthographic camera framed from the model's bounds; transparent film; Eevee.
2. Three sun lamps parented to the camera, so every direction is lit the same: key (3.2, casts
   shadow), fill (1.0), rim (2.0), plus a sandstone/bone world at 0.45.
3. Each direction renders at `size x supersample`, box-downsamples, and a cell is opaque when its
   mean alpha is at least 50% (binary alpha).
4. Every opaque pixel snaps to the nearest ramp colour (redmean distance).
5. Optional outline, then the frames stack top to bottom into `out/<asset>_sheet.png`.

## Shade ramp

Every palette role at four steps, shared with the pixel kind (`spritekit.py`):

| Step | Value |
| --- | --- |
| `shadow` | role x 0.42 |
| `dark` | role x 0.68 |
| `base` | the role |
| `light` | role moved 28% toward white |

12 roles x 4 steps = 48 colours. Roles come from `palette.gd` through the pack, never copied.

## Outputs and validation

`out/<asset>_sheet.png`, `out/<asset>.json` (frame size, directions, rows, `pivot` = pixel where
the ground under the model's centre lands, elevation, ramp steps), `preview/sheet.png` (frames
at x4 and again at 1x).

| Check | Fails when |
| --- | --- |
| `frames` | the sheet does not divide into `directions` whole frames of the json's size |
| `frame_band` | frame edge outside the pack band (prop 16 to 96, kit 16 to 128, hero 32 to 192) |
| `requested_size`, `requested_directions` | the prompt says "64px" or "4-direction" and the sheet differs |
| `alpha` | any pixel has alpha other than 0 or 255 |
| `ramp` | any opaque pixel is not one of the 48 ramp colours |
| `content` | a frame is empty |
| `pivot` | the json has no `[x, y]` pivot |
| `colour_budget` (warn) | distinct colours over the budget (prop 20, kit 24, hero 32) |
| `model_size` (warn) | the model's longest edge is outside the pack size range |

## Limits

The preview and checks say nothing about taste or in-engine look. Parts thinner than about
`size / 24` speckle or vanish at 50% alpha. The Godot import should use nearest filtering and no
mipmaps. Promote copies the sheet, json and a `<asset>.forge.json` sidecar to
`sketches/core-loop/assets/sprites/<asset>/`; the recipe is not copied (its hash is recorded).
