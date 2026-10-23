# Mojulo gotchas

What cost time on 2026-10-22, each with its symptom and fix. The evidence is in `artifacts/mojulo-lab/local/` (`artifacts/mojulo-lab/local/RESULTS.md`, `artifacts/mojulo-lab/local/B-notes.md`) and the lessons file.

## Calling it

| Symptom | Cause | Fix |
|---|---|---|
| `call … --json @<file>` cannot find the file | The CLI resolves a relative `@file` against another directory | Pass an absolute path |
| `export_model exceeded its 120000ms budget`, and no glb written | A 120 s default budget for each tool call | `MOJULO_MCP_TOOL_TIMEOUT_MS=600000` |
| The JSON from a big mint will not parse | The CLI cuts stdout at 65,536 bytes; the mint itself succeeded | Read `"ref": "sk_…"` from the head of the output |
| A deprecation warning about `module.register()` | Node 26 | Harmless. Filter stderr |
| "Object sinks N cm below the grid" | A part goes below z = 0 | Harmless for terrain and rivers. Otherwise raise the base |

## Recipes

| Symptom | Cause | Fix |
|---|---|---|
| `field shape kind must be one of sphere \| ellipsoid \| …` on a valid spec | `displace` placed after two or more shape terms, a mojulo 3.0.0 fault | Wrap the shapes in `{ op:'transform', translate:[0,0,0], terms:[…] }`, then `displace`. Repro: `artifacts/mojulo-lab/local/C/t-d5.json`; fixed: `artifacts/mojulo-lab/local/C/t-d6.json` |
| An exact field refuses `blend`, `stroke`, `displace`, `shell`, `round` or `expr` | Exact mode supports only rigid booleans | Drop `exact`, or move that detail into its own sampled field |
| `memory access out of bounds` at mint | The exact-boolean memory ceiling: 512 bores at 256 segments | Lower `segments`. About 280k triangles per exact field is the practical top |
| `feature must be one of river, range, lake, plateau, volcano, coast` | Sizes such as `cordillera` or `mesa` belong in `size`, not `feature` | `{ feature:'range', size:'cordillera' }` |
| A terrain world reports tens of millions of triangles | `plants: true` counts every instance, and exports each plant as its own mesh | No plants for game use. A 92.7M-triangle world took 19 s to import into Godot |
| Painted terrain keeps the same size at any span | `span` and `detail` do not change mesh density | Size the world some other way |

## Export and engines

| Symptom | Cause | Fix |
|---|---|---|
| Blender and Godot show no lighting or shadows | The default glb is `KHR_materials_unlit`, with light baked into the vertex colours | `export_model { lit: true }` |
| The lit glb looks washed out | `COLOR_0` holds sRGB values, which glTF reads as linear | Add a gamma 2.2 node on the colour attribute (`artifacts/mojulo-lab/local/C/hero_stills.py`). In Godot, convert the vertex colour from sRGB to linear in the material |
| The same recipe gives a different glb hash | The sketch ref is written into the file | Hash only the geometry: `artifacts/mojulo-lab/inputs/geomhash.py` |
| Export takes minutes | Export, not mint, is the slow step, and it grows faster than linearly | Budget it: 283k triangles of exact booleans took 273 s; 10,000 code-kind treads took 30 s |
| The page export (`world.html`) stalls a headless browser | The page is about 9 MB | Use mojulo's own film renderer, or Blender stills |

## Godot proofs

| Symptom | Cause | Fix |
|---|---|---|
| The ball never moves | Godot was run without `--path`, so physics does not step | `godot --headless --path <dir> --script res://ball_proof.gd -- <spec file>` |
| The ball slows on flat ground | Godot's default damping of 0.1 | Linear and angular damping 0 (the harness sets this) |
| Global transforms are empty during setup | They are not ready in `_init` | Set up in the first physics frame |
| A mojulo game pack plays on a flat floor, walks sideways and drops your tuning | The pack keeps no collision for the level's shape, faces the wrong way, and resets speed, jump and gravity to defaults | Do not use game packs. Import the glb and build trimesh collision |
| Mojulo's traversal audit passes a gap the ball can't clear | Its controller snaps onto ledges from below, ignores momentum off slopes, and checks hazard zones in plan only, ignoring height | Treat it as a hint only. Godot physics is the gate |

## Frames

- **Mojulo:** cm, z up.
- **Blender:** the glTF importer brings mojulo's frame back as metres, z up.
- **Godot:** a mojulo point `(x, y, z)` becomes `(x, z, -y)`.
