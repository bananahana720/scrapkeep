# Rolling wall (lab pocket)

Lab-only greybox for Challenge's pocket-against-mobility sweeps. It is not in `assets/registry.json` or any shipping list, and the folder's `.gdignore` keeps Godot from importing or exporting it.

- **Size:** 32 x 24 m, 4x3 cells of the 8 m lattice. Mojulo frame: x along travel, y lateral, z up, entry at x = 0. In Godot, a mojulo point (x, y, z) is (x, z, -y).
- **Triangles:** 200 (cap 50,000). **File:** `rolling_wall.glb`, 17,496 bytes.
- **Geometry sha256** (positions and indices only): `50ba4e26555d58974f023d87ffd2b6b74fcb7bbf8a422bc35b7080c69f1869d0`
- **What it is:** Cruise rolls over the 3 m crest; 37 m/s jumps it; 6 m/s rolls back (control).

## Mojulo command

From `sketches/core-loop`, with Node 22.14 or newer:

```bash
python3 tools/lab_pockets/build.py rolling_wall
```

That runs `tools/lab_pockets/gen.py`, which writes `recipes/rolling_wall.json`, then calls `npx -y mojulo@3.0.0 call mint_solid` with `{ kind: 'workbench', spec: <recipe> }` and `export_model { ref, format: 'glb', lit: true }`. The tool budget is raised to 600 s. It then decodes COLOR_0 from sRGB with gamma 2.2 and drops mojulo's studio plate and cameras. The last build minted `sk_et6vje38gm`.

## Ball proof

`tests/lab_pockets_test.gd`: a 0.92 m ball under gravity 26, with no damping, launched already rolling in headless Jolt. Verdict: `PASS (49 checks)`.

| Case | Start (m) | Velocity (m/s) | Expected | Result | Peak z (m) | Why |
|---|---|---|---|---|---|---|
| cruise-over | [1, 0, 0.94] | [14.0, 0.0, 0.0] | pass | passed | 3.92 | all rules held |
| fast-jump | [1, 0, 0.94] | [37.0, 0.0, 0.0] | pass | passed | 6.28 | all rules held |
| control-slow | [1, 0, 0.94] | [6.0, 0.0, 0.0] | fail | failed | 1.7 | never reached its exit |
