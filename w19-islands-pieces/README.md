# Islands collider-locked pieces (World-2, wave 19)

Head: `claude/happy-mayer-rtqcu5-islands` b2b47558, built from `tools/blender/park/isle_pieces.py`.

- `isle-pieces-godot-lit.jpg`: rows are isle_keel_rib, isle_tram_head and isle_adit_portal; columns are the shared
  `tools/asset_capture.gd` cameras asset-front30, asset-side30 and asset-rear30. Lit mode, each GLB placed with `--glb`
  at (0, 400, 0), so the pieces float against the sky with the sun behind. The `*-frames.json` files record every
  camera.
- `isle-pieces-cycles.jpg`: Cycles CPU, 16 samples, through `tools/blender/glb_stills.py` (front and three-quarter
  views). `-col` meshes are hidden.
