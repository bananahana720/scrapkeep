# Hazard field (lab pocket)

Lab-only greybox for Challenge's pocket-against-mobility sweeps. It is not in `assets/registry.json` or any shipping list, and the folder's `.gdignore` keeps Godot from importing or exporting it.

- **Size:** 32 x 32 m, 4x4 cells of the 8 m lattice. Mojulo frame: x along travel, y lateral, z up, entry at x = 0. In Godot, a mojulo point (x, y, z) is (x, z, -y).
- **Triangles:** 1124 (cap 50,000). **File:** `hazard_field.glb`, 112,464 bytes.
- **Geometry sha256** (positions and indices only): `3c0fdbdc9d0b8a05d9e4b447669eb2bb99fd225ac8244aa8662ea83c06440295`
- **What it is:** The straight lane misses every pit; a 12 degree line drops into one (control).

## Mojulo command

From `sketches/core-loop`, with Node 22.14 or newer:

```bash
python3 tools/lab_pockets/build.py hazard_field
```

That runs `tools/lab_pockets/gen.py`, which writes `recipes/hazard_field.json`, then calls `npx -y mojulo@3.0.0 call mint_solid` with `{ kind: 'workbench', spec: <recipe> }` and `export_model { ref, format: 'glb', lit: true }`. The tool budget is raised to 600 s. It then decodes COLOR_0 from sRGB with gamma 2.2 and drops mojulo's studio plate and cameras. The last build minted `sk_aliljulqgj`.

## Ball proof

`tests/lab_pockets_test.gd`: a 0.92 m ball under gravity 26, with no damping, launched already rolling in headless Jolt. Verdict: `PASS (49 checks)`.

| Case | Start (m) | Velocity (m/s) | Expected | Result | Peak z (m) | Why |
|---|---|---|---|---|---|---|
| cruise-lane | [1, 0, 0.94] | [14.0, 0.0, 0.0] | pass | passed | 0.94 | all rules held |
| fast-lane | [1, 0, 0.94] | [37.0, 0.0, 0.0] | pass | passed | 0.94 | all rules held |
| control-off-line | [1, 0, 0.94] | [13.694, 2.911, 0.0] | fail | failed | 1.9 | entered a hazard |
