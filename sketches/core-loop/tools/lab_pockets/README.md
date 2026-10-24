# Lab pockets

Five greybox pockets for Challenge's pocket-against-mobility sweeps (board #241, Challenge option (a)). Each is one lab arena glb: `half_pipe`, `rolling_wall`, `crevice`, `hazard_field` and `rail_grove`. Each `<shape>.md` holds its size, triangle count, mojulo command and ball-proof table.

They are lab-only:
- Never add them to `assets/registry.json`, `assets/registry.d` or any shipping list.
- `.gdignore` keeps Godot from importing this folder and keeps it out of every export preset.
- A lab scene loads them at runtime with `GLTFDocument.append_from_file("res://tools/lab_pockets/<shape>.glb", state)`, then builds trimesh colliders. Give meshes whose names start with `slick` friction 0, as `tests/lab_pockets_test.gd` does.

## Files

| File | What it is |
|---|---|
| `gen.py` | The recipes and proof cases, authored in metres. Writes `recipes/<shape>.json` and `proofs.json` |
| `build.py` | Mints each recipe with mojulo 3.0.0, exports it lit, decodes COLOR_0 (gamma 2.2), drops the studio plate and cameras, and writes `<shape>.glb` and `build.json` |
| `report.py` | Writes each `<shape>.md` from `build.json`, `proofs.json` and a test log |
| `recipes/` | The mojulo workbench specs (the source of each glb) |

## Rebuild

From `sketches/core-loop`:

```bash
python3 tools/lab_pockets/build.py
```

```bash
godot --headless --path . --script res://tests/lab_pockets_test.gd > /tmp/lab_pockets.log
```

```bash
python3 tools/lab_pockets/report.py /tmp/lab_pockets.log
```

The method and the mojulo gotchas are in the `scrapkeep-blockout` skill (branch `claude/mojulo-plugin-exploration-a455a3` until it merges).
