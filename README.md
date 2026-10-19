# World lane evidence (wave 17)

Disposable evidence for the World lane's PRs against `stage/alpha-w17`. Not for merging.
Left = base (stage 1a7a7299), right = head, unless a file name says otherwise.

- Cycles stills: `tools/blender/glb_stills.py` (Cycles CPU, 24 samples) or the recipe's own `--render`.
- In-game: `tools/asset_capture.gd --glb=...` with the shared camera table (asset-use6, asset-front30,
  asset-side30), paired base against head with `--pair` (pair.json, exit 0 = same cameras and state).

## w18-anchors

Anchor kit soft-toy pass, Cycles CPU (`tools/blender/glb_stills.py`, 16 samples). `anchors-base-vs-head.jpg`: top row stage 1a7a7299, bottom row head cd1fe126, three-quarter view. `anchor_*-low.jpg`: the low camera under the ledges, showing the floored joints (no see-through).
