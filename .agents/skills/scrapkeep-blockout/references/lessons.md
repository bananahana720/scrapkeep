# Blockout lessons

## Lessons

- **BLK-01** · status: established · since: 2026-10-22 · origin: Andrew's ruling after the mojulo lab
  Mojulo is the go-forward base for map and gameplay blockout. Build systems on top of its pieces fast; layer detail afterwards.
  Evidence: the session hand-off to the wave 18-21 coordinator, 2026-10-22; `artifacts/mojulo-lab/local/RESULTS.md`.
  Overturned by: —
- **BLK-02** · status: provisional · since: 2026-10-22 · origin: cloud lab routine
  Local MCP plugins do not reach cloud routines, so a cloud box drives mojulo through the CLI only.
  Evidence: the schedule skill's connector note; `references/cloud-setup.md`.
  Overturned by: —
- **BLK-03** · status: provisional · since: 2026-10-22 · origin: Part A of the lab
  The CLI resolves a relative `@file` against another directory. Pass absolute paths.
  Evidence: the Part A mint retry, `artifacts/mojulo-lab/local/A/`.
  Overturned by: —
- **BLK-04** · status: established · since: 2026-10-22 · origin: Part B ladder
  `export_model` has a 120 s default budget. `MOJULO_MCP_TOOL_TIMEOUT_MS=600000` lets big exports finish.
  Evidence: `artifacts/mojulo-lab/local/B-notes.md`, the B1 row with 512 bores at 128 segments.
  Overturned by: —
- **BLK-05** · status: established · since: 2026-10-22 · origin: the workbench manual and the lab
  Exact fields take only rigid booleans, `transform` and `repeat`. `displace` after two or more shape terms errors, and a zero `transform` group fixes it.
  Evidence: `artifacts/mojulo-lab/local/C/t-d5.json` (fails), `artifacts/mojulo-lab/local/C/t-d6.json` (passes).
  Overturned by: —
- **BLK-06** · status: provisional · since: 2026-10-22 · origin: Part C hero
  A `code` program in sections builds a landmark hero quickly. The Spillway dam reached 134k triangles in three revisions, minting in under 30 s each.
  Evidence: `artifacts/mojulo-lab/local/C/dam.js`, `artifacts/mojulo-lab/local/RESULTS.md` section 4.
  Overturned by: —
- **BLK-07** · status: provisional · since: 2026-10-22 · origin: Part B ladder
  OpenSCAD is exact but slow: 40 × 40 holes at `$fn` 32 took 101 s, and `$fn` 128 passed 600 s.
  Evidence: `artifacts/mojulo-lab/local/B-ladder.tsv`, the B4 rows.
  Overturned by: —
- **BLK-08** · status: established · since: 2026-10-22 · origin: the trial and Part B
  Terrain worlds set mood and layout, not art direction. `plants: true` explodes the triangle and mesh counts, so leave plants off for game use.
  Evidence: the 92.7M-triangle river world in the first trial; the B5 rows in `B-ladder.tsv`.
  Overturned by: —
- **BLK-09** · status: provisional · since: 2026-10-22 · origin: Part C hero
  A one-shot plus up to three revisions, each checked against the board, is enough to reach a usable hero.
  Evidence: the stills in `artifacts/mojulo-lab/local/C/r1`, `r2`, `r3` and `r3lit`.
  Overturned by: —
- **BLK-10** · status: provisional · since: 2026-10-22 · origin: discussion with Andrew
  Detail splits by layer: shape detail in mojulo, surface look as a Blender bake, live effects in Godot.
  Evidence: design choice discussed on 2026-10-22, not yet built.
  Overturned by: —
- **BLK-11** · status: established · since: 2026-10-22 · origin: Part C hero
  The default glb is unlit. `lit: true` gives real PBR materials, and Blender then casts shadows.
  Evidence: `artifacts/mojulo-lab/local/C/r3/` against `artifacts/mojulo-lab/local/C/r3lit/`; the `export_model` schema.
  Overturned by: —
- **BLK-12** · status: provisional · since: 2026-10-22 · origin: Part C hero
  The lit glb stores sRGB values in `COLOR_0`. A gamma 2.2 decode restores the intended colours.
  Evidence: `artifacts/mojulo-lab/local/C/hero_stills.py`; `artifacts/mojulo-lab/local/C/r3lit/dam-board.jpg` before and after.
  Overturned by: —
- **BLK-13** · status: provisional · since: 2026-10-22 · origin: Part A
  The glb bytes change with the sketch ref, so determinism is proven with a geometry-only hash.
  Evidence: `artifacts/mojulo-lab/local/A-hashes.tsv` against `A-geomhash.tsv`.
  Overturned by: —
- **BLK-14** · status: established · since: 2026-10-22 · origin: the reach-exit level trial
  Mojulo's game packs lose the level's collision shape, facing and tuning, and its traversal audit passes gaps that physics fails.
  Evidence: the trial report to the coordinator, 2026-10-22; the project memory note on the mojulo trial.
  Overturned by: —
- **BLK-15** · status: established · since: 2026-10-22 · origin: the greybox set
  The headless Godot ball proof needs `--path` and zero damping.
  Evidence: `artifacts/mojulo-lab/inputs/ball_proof.gd` header.
  Overturned by: —
- **BLK-16** · status: provisional · since: 2026-10-22 · origin: the greybox set
  The ball is radius 0.92 m under gravity 26 m/s². The proof speeds are cruise 14, blazing 26.6 and a bot's measured 37 m/s.
  Evidence: `sketches/core-loop` tuning, read for the greybox brief.
  Overturned by: —
- **BLK-17** · status: established · since: 2026-10-22 · origin: the greybox set and Part C
  Every ball proof pairs with a control that must fail. In both the greybox set and the dam, the controls failed and the passes held.
  Evidence: `artifacts/mojulo-lab/local/C/godot/face.log` and `control.log`.
  Overturned by: —

## Changelog

| Date | Change |
|---|---|
| 2026-10-22 | Created from the mojulo trial, the greybox set and the local-vs-cloud lab. |
