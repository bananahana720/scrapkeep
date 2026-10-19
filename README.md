# World lane evidence (wave 17)

Disposable evidence for the World lane's PRs against `stage/alpha-w17`. Not for merging.
Left = base (stage 1a7a7299), right = head, unless a file name says otherwise.

- Cycles stills: `tools/blender/glb_stills.py` (Cycles CPU, 24 samples) or the recipe's own `--render`.
- In-game: `tools/asset_capture.gd --glb=...` with the shared camera table (asset-use6, asset-front30,
  asset-side30), paired base against head with `--pair` (pair.json, exit 0 = same cameras and state).
