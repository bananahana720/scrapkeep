# Half pipe (lab pocket)

Lab-only greybox for Challenge's pocket-against-mobility sweeps. It is not in `assets/registry.json` or any shipping list, and the folder's `.gdignore` keeps Godot from importing or exporting it.

- **Size:** 64 x 32 m, 8x4 cells of the 8 m lattice. Mojulo frame: x along travel, y lateral, z up, entry at x = 0. In Godot, a mojulo point (x, y, z) is (x, z, -y).
- **Triangles:** 108 (cap 50,000). **File:** `half_pipe.glb`, 8,868 bytes.
- **Geometry sha256** (positions and indices only): `51c565e11a629ad4d601f5d94158b612c71c4ac65be929374d39b3cba73d713f`
- **What it is:** The park's concrete channel section. Entry and off-centre drops at 8 m/s ride it out without stalling (the park test's roll); cruise and fast carve at 20 degrees; a 70 degree entry at 37 m/s clears the 10 m wall (control).

## Mojulo command

From `sketches/core-loop`, with Node 22.14 or newer:

```bash
python3 tools/lab_pockets/build.py half_pipe
```

That runs `tools/lab_pockets/gen.py`, which writes `recipes/half_pipe.json`, then calls `npx -y mojulo@3.0.0 call mint_solid` with `{ kind: 'workbench', spec: <recipe> }` and `export_model { ref, format: 'glb', lit: true }`. The tool budget is raised to 600 s. It then decodes COLOR_0 from sRGB with gamma 2.2 and drops mojulo's studio plate and cameras. The last build minted `sk_s8m7p6vb34`.

## Ball proof

`tests/lab_pockets_test.gd`: a 0.92 m ball under gravity 26, with no damping, launched already rolling in headless Jolt. Verdict: `PASS (49 checks)`.

| Case | Start (m) | Velocity (m/s) | Expected | Result | Peak z (m) | Why |
|---|---|---|---|---|---|---|
| entry-drop | [1, 0, 0.94] | [8.0, 0.0, 0.0] | pass | passed | 0.94 | all rules held |
| off-centre | [1, 7.5, 1.54] | [8.0, 0.0, 0.0] | pass | passed | 1.54 | all rules held |
| cruise-carve | [1, 0, 0.94] | [13.156, 4.788, 0.0] | pass | passed | 0.94 | all rules held |
| fast-carve | [1, 0, 0.94] | [34.769, 12.655, 0.0] | pass | passed | 3.3 | all rules held |
| control-fast-steep | [1, 0, 0.94] | [12.655, 34.769, 0.0] | fail | failed | 21.22 | never reached its exit; left the pocket before its exit |

## Against the park's half pipe

Measured by ray on both models (`assets/models/park/half_pipe_concrete.glb` gauges):

| | Lab | Park |
|---|---|---|
| Crest to crest (m) | 24.80 | 24.64 |
| Wall over the floor (m) | 10.00 | 10.00 |
| Floor fall | 3.00% | 3% (halfpipes.py GRADE) |

The lab's crest is read on a 0.1 m ray grid, so its width can read up to 0.2 m wide. The lab piece is 64 m long, to fit whole cells; the park's is 60 m.
