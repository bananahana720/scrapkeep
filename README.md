# World lane (second session) evidence

Disposable evidence for this session's PRs against `stage/alpha-w17`. Not for merging.

## w19-p6-dam-gates

P6: the dam's spillway gates (`landmark_dam.glb` gate_l and gate_r) at rest (left) and at the rig's open angle (right, OPEN_RAD 0.62 rad = 35.52 deg).

- `asset-*-shut-vs-open.jpg`: in game, `tools/asset_capture.gd` (with #154's `--glb`) on cloud llvmpipe under Xvfb, shared cameras asset-rear30 (the downstream face) and asset-side30. GLB placed at (0, 400, 0); anchor `landmark_dam_root` with offset (0, 44, -8), the trunnion line; the leaves posed with `--freeze=.../gate_l=<deg>,0,0` (and gate_r). `shut-frames.json` and `open-frames.json` hold the recorded cameras. The two runs share every camera value, but `--pair` refuses them because the frozen state differs on purpose.
- `dam-gates-cycles-shut-vs-open.jpg`: Cycles CPU, 24 samples, from the same recorded eye, target and fov (`gate_stills.py`, the leaves turned about local X). Top row is rear30, bottom row is side30; left is 0 deg, right is 35.5 deg.
