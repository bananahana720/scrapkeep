# Rail grove (lab pocket)

Lab-only greybox for Challenge's pocket-against-mobility sweeps. It is not in `assets/registry.json` or any shipping list, and the folder's `.gdignore` keeps Godot from importing or exporting it.

- **Size:** 32 x 24 m, 4x3 cells of the 8 m lattice. Mojulo frame: x along travel, y lateral, z up, entry at x = 0. In Godot, a mojulo point (x, y, z) is (x, z, -y).
- **Triangles:** 12436 (cap 50,000). **File:** `rail_grove.glb`, 1,339,244 bytes.
- **Geometry sha256** (positions and indices only): `ef6e84fbe1b09bd17a308751760e41cee74b710c6b0be3380da1f1969d2ff995`
- **What it is:** The floor lane passes under both rails, whose underside clears the floor by at least 3.52 m; riding a rail is a contraption, not physics, so it is not proven here.

## Mojulo command

From `sketches/core-loop`, with Node 22.14 or newer:

```bash
python3 tools/lab_pockets/build.py rail_grove
```

That runs `tools/lab_pockets/gen.py`, which writes `recipes/rail_grove.json`, then calls `npx -y mojulo@3.0.0 call mint_solid` with `{ kind: 'workbench', spec: <recipe> }` and `export_model { ref, format: 'glb', lit: true }`. The tool budget is raised to 600 s. It then decodes COLOR_0 from sRGB with gamma 2.2 and drops mojulo's studio plate and cameras. The last build minted `sk_nifpt5koon`.

## Ball proof

`tests/lab_pockets_test.gd`: a 0.92 m ball under gravity 26, with no damping, launched already rolling in headless Jolt. Verdict: `PASS (49 checks)`.

| Case | Start (m) | Velocity (m/s) | Expected | Result | Peak z (m) | Why |
|---|---|---|---|---|---|---|
| cruise-lane | [1, 0, 0.94] | [14.0, 0.0, 0.0] | pass | passed | 0.94 | all rules held |
| fast-lane | [1, 0, 0.94] | [37.0, 0.0, 0.0] | pass | passed | 0.94 | all rules held |
| control-into-pillar | [1, -7.8, 0.94] | [14.0, 0.0, 0.0] | fail | failed | 1.23 | never reached its exit |

Ride paths: the rails' underside stays at least 3.52 m over the walkable floor (DECISIONS, map design veto pass, 23 Oct). The test checks every rail vertex.
