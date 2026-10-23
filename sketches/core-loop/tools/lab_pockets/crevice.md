# Crevice (lab pocket)

Lab-only greybox for Challenge's pocket-against-mobility sweeps. It is not in `assets/registry.json` or any shipping list, and the folder's `.gdignore` keeps Godot from importing or exporting it.

- **Size:** 32 x 24 m, 4x3 cells of the 8 m lattice. Mojulo frame: x along travel, y lateral, z up, entry at x = 0. In Godot, a mojulo point (x, y, z) is (x, z, -y).
- **Triangles:** 76 (cap 50,000). **File:** `crevice.glb`, 11,128 bytes.
- **Geometry sha256** (positions and indices only): `69ff3d1fc615fcf02df990ccb6c9b44d8b5e314ffbb53add56ba783f392c3d43`
- **What it is:** A choke: the slick guide walls turn an off-line entry into the 5 m slot without scrubbing speed (cruise graze at 30 degrees); 4 m/s at 60 degrees stalls in the mouth (control).

## Mojulo command

From `sketches/core-loop`, with Node 22.14 or newer:

```bash
python3 tools/lab_pockets/build.py crevice
```

That runs `tools/lab_pockets/gen.py`, which writes `recipes/crevice.json`, then calls `npx -y mojulo@3.0.0 call mint_solid` with `{ kind: 'workbench', spec: <recipe> }` and `export_model { ref, format: 'glb', lit: true }`. The tool budget is raised to 600 s. It then decodes COLOR_0 from sRGB with gamma 2.2 and drops mojulo's studio plate and cameras. The last build minted `sk_nbw547f2zc`.

## Ball proof

`tests/lab_pockets_test.gd`: a 0.92 m ball under gravity 26, with no damping, launched already rolling in headless Jolt. Verdict: `PASS (49 checks)`.

| Case | Start (m) | Velocity (m/s) | Expected | Result | Peak z (m) | Why |
|---|---|---|---|---|---|---|
| cruise-funnel | [1, 4, 0.94] | [13.787, -2.431, 0.0] | pass | passed | 0.94 | all rules held |
| fast-funnel | [1, 4, 0.94] | [36.64, -5.149, 0.0] | pass | passed | 0.94 | all rules held |
| cruise-graze | [1, 6, 0.94] | [12.124, -7.0, 0.0] | pass | passed | 0.94 | all rules held |
| control-slow-graze | [1, 6, 0.94] | [2.0, -3.464, 0.0] | fail | failed | 0.94 | never reached its exit |

Choke: the guide walls and the slot walls are tagged `slick_*` (mesh names `slick_guide`, `slick_mouth`, `slick_slot`). A lab scene gives them friction 0, as the test does; the floor keeps its grip.
