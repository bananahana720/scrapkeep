# VFX brief

You design a particle effect as DATA. You write `recipe.py` with `build(params) -> spec`, a plain
dict. You never write GDScript or a scene: the forge validates your spec, converts it to a Godot
scene of CPUParticles3D emitters and previews it. Ignore `reference/` for this kind (it holds Blender
helpers); the example below is all the format you need. Where the system brief says "triangle band"
or "model", read "particle budget" and "effect". `params["band"]` is `[1, budget]` particles for the
whole effect, `params["max_draw_calls"]` is the emitter cap, `params["size_range"][1]` is how far in
metres the cloud may travel from the origin, `params["palette"]` lists the colour roles.

## Contract

- `build(params)` returns a dict, JSON data only (numbers, strings, bools, lists, dicts).
  `import math` and `import random` are fine; do not read or write files, open sockets or start processes.
- Colours are palette ROLE NAMES in `color_ramp`, never hex. Roles: bone, sandstone, oxide, copper,
  charcoal, petrol, amber, mint, ancient, hazard, brass, ice. Any other value fails the palette check.
- The preview, `preview/sheet.png`, is a strip of 6 frames from t = 0.05 s to about the longest lifetime,
  seen from a fixed 3/4 camera over a ground ring (0.5 m radius). The vertical bar at the left of each
  frame is 1 m. It is a Python simulation, not the engine: motion is approximate and it has no bloom.
  Read it after every run.

## Spec

```python
def build(params):
    return {
        "schema": 1,
        "seed": 7,                       # int; fixes the randomness
        "emitters": [                    # 1 to params["max_draw_calls"]
            {
                "name": "shards",        # [a-z][a-z0-9_]{0,23}, unique
                "amount": 16,            # particles; the sum over emitters stays within the budget
                "lifetime": 0.3,         # seconds, 0.05 to 2.0
                "one_shot": True,        # default True; False loops
                "explosiveness": 1.0,    # 0..1, 1 = all at once (default 1)
                "randomness": 0.0,       # 0..1 (default 0)
                "offset": [0, 0, 0],     # emitter position, metres, each within +-3
                "shape": "point",        # point | sphere | box (default point)
                "extents": [0.1, 0.1, 0.1],   # sphere: [radius, _, _]; box: half extents; 0..2
                "direction": [0, 1, 0],  # non-zero; Y is up
                "spread": 80,            # degrees, 0..180 (180 = every way)
                "velocity": [4, 9],      # [min, max] m/s, 0..20
                "gravity": [0, -9, 0],   # m/s^2 per axis, +-40
                "damping": [0, 0],       # [min, max], 0..20
                "scale": [0.8, 1.2],     # [min, max] multiplier of mesh_size, 0.05..4
                "scale_curve": [[0, 1], [1, 0]],   # [t, value] keyframes, 2 to 6, t rising in 0..1, value 0..2
                "color_ramp": [          # 2 to 5 stops, t rising in 0..1; alpha 0..1 (default 1)
                    {"t": 0.0, "role": "bone"},
                    {"t": 0.3, "role": "amber"},
                    {"t": 1.0, "role": "oxide", "alpha": 0.0},
                ],
                "emissive": 1.0,         # 0..3 brightness multiplier (default 1)
                "blend": "mix",          # mix | add (additive, for glows)
                "mesh": "prism",         # quad | sphere | box | prism
                "mesh_size": [0.06, 0.06, 0.2],   # metres, each 0.02..1.0
                "align_y": True,         # long axis follows the velocity
            },
        ],
    }
```

Only `name`, `amount`, `lifetime` and `color_ramp` are required; every other field has the default shown.
An unknown field, a wrong type, an out-of-range value or an unknown role fails the run and the error says which.

## Design rules

- It must read in one glance at gameplay distance (a few metres to tens of metres). Chunky shapes
  over fine sparkle: keep particles at or above about 0.05 m while visible. Few big particles beat many small ones.
- Short lifetimes. A hit effect lasts 0.2 to 0.5 s; nothing over 1.2 s unless the prompt asks for a lingering effect.
- Palette roles carry meaning: mint (arc) and ice for energy and electricity, amber, copper and brass for
  heat, sparks and scrap, oxide, sandstone and bone for dust and debris, charcoal for smoke, petrol for
  coolant and steam, ancient for awakened machines. `hazard` ONLY for danger: a klaxon, a telegraph,
  something that will hurt the player.
- Fade by alpha at the end of the ramp and by `scale_curve`; add a bright first stop (bone, ice, brass) that
  cools to the body colour. One or two emitters usually say it: a body plus an optional flash.
- Match the game's conventions: one-shot, `explosiveness` 1, burst from a point, gravity in the -3 to -26
  range as in the existing sparks (speed 5 to 11, lifetime 0.28), debris (4 to 9, 0.7) and dust (soft, large).

## The loop

1. Read `prompt.md` and `params.json`. Write `recipe.py`.
2. Run the forge run command from the system brief. Fix every failed check. Then READ `preview/sheet.png` and ask: does the
   strip read as the thing in the prompt, are the shapes chunky, does it end cleanly? Adjust and rerun
   (about six runs at most).
3. A `godot_load` fail is real: the generated scene did not load with the right properties; report the
   output in your closing note rather than guessing.
