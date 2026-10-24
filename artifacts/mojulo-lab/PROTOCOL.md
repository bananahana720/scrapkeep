# Mojulo lab: local vs cloud split experiment

Started 22 October 2026 at Andrew's request: push mojulo (the 3D recipe compiler, npm `mojulo@3.0.0`) as far as it goes, and run the same experiment on his PC and in a Claude Code cloud box so the two can be compared. Output focus is 3D for Blender and Godot. No music or audio.

This is a lab, not game work. Nothing here goes onto a stage branch or into `sketches/`. It touches no `src/world/park`, `src/world/pockets`, dressing or registry files. A Warden body stays out: TADR-011 gates it behind Andrew's sheet approval.

Two sides run the same parts A to C. Each side writes only under `artifacts/mojulo-lab/<side>/`, where `<side>` is `local` or `cloud`.

## Running mojulo

- **MCP:** if the `plugin_mojulo_mojulo` tools are loaded, use them.
- **CLI:** otherwise run `npx -y mojulo@3.0.0 call <tool> --json @args.json`. It needs Node 22.14 or newer, and `npx -y mojulo@3.0.0 orient` explains the CLI. Large specs go through `@file.json`.
- Mojulo stores state under `~/.mojulo` and writes exports to `~/.mojulo/data/outcomes/<ref>/`. Copy what you keep into your side's folder.
- Read a kind's manual before using it: `get_solid_vocab({ id })` or `get_view_vocab({ id })`.

## Part A. Determinism across machines

1. Mint each recipe in `inputs/` (`half_pipe.json`, `crevice.json`, `arena_bowl.json`) with `mint_solid({ kind: 'workbench', spec: <file contents> })`.
2. Export each one with `export_model` twice: once as `glb` and once as `stl`.
3. In `A-hashes.tsv`, record the sha256 of `model.glb`, `model.stl` and the `recipe.json` mojulo wrote, plus the triangle count.

Don't look at the other side's hashes first.

## Part B. Limit ladder

Climb each ladder until a rung fails. A rung fails when mojulo refuses it, errors, takes more than 10 minutes, or makes a glb over 200 MB. Log every rung in `B-ladder.tsv` with these columns: rung, tool, key params, outcome (`ok` / `refused` / `error` / `timeout`), wall ms (from mojulo's ledger and your own clock), triangles, glb bytes, and the error text.

- **B1, exact booleans:** a 10 m workbench sphere `field` with `exact: true`, minus a `repeat` grid of bores. Grow the bore count 64 → 512 → 4096, and step `segments` 48 → 128 → 256.
- **B2, sampled field:** the same sphere without `exact`, plus `displace` noise and three `blend` strokes. Step `cells` 64 → 96 → 128.
- **B3, code kind:** a `code` program that returns N boxes (a stair or truss). Step N = 100 → 1000 → 10000 → 50000.
- **B4, OpenSCAD:** a 2 m plate with an H × H grid of holes. Step H = 10 → 40 → 100, with `$fn` 32 → 128.
- **B5, terrain world:** `compose_world({ base: 'terrain' })`. Read `get_view_vocab({ id: 'terrain' })` first. Start with its defaults, then use its largest size and detail knobs, then export with plants and without them.

## Part C. Hero: the Spillway dam face

Board: `docs/art/reference/spillway/spillway-landmarks-dam-face.jpg`, with its notes in `docs/art/reference/spillway/README.md`. Open the board before building, and note in your `C-hero.md` what you read off it.

**Build** the dam as a set of mojulo recipes, then compose or assemble them into one piece:
- a concrete arch dam, curved in plan, about 320 m along the crest, with a downstream face about 120 m tall and concave toward the viewer
- two crest towers flanking a two-gate spillway
- a falling water sheet down the face, as a translucent pale-blue solid
- a steel gantry bridge between the towers
- a parapet rail along the crest
- a small service shelf with canopies on each abutment
- horizontal mineral bands and vertical repair joints as shallow relief on the face
- terraced sandstone canyon walls on both sides
- a river apron at the toe
- an empty reactor plinth 22 m above the toe, with no Warden body

Colours, from the board's notes:
- warm sandstone
- pale concrete
- petrol-green enamel
- oxide
- brass
- a green-blue river

**Budget:** under 300k triangles for the whole piece, as glb in metres. Write down where the detail went.

**Iterate:** one-shot it first, then up to three revisions. Keep each revision's still so the progression is visible.

**Godot proof:** headless import. Record import ms, node count and triangle count. Then drop a 0.92 m radius ball under gravity 26 near the top of the face and confirm it rolls down the face to the toe. `inputs/ball_proof.gd` and `inputs/project.godot` are a working harness: run `godot --headless --path <dir with project.godot> --script res://ball_proof.gd -- spec.json`, and read its header for the spec format. Without `--path` the physics does not step. The harness sets damping to 0.

**Blender proof:** import the glb in `blender -b` and render a still from the board's camera (low, at the toe, looking up at the face) and a top-down still. `inputs/stills.py` is a starting point. Render on CPU with Cycles.

## Report

Each side writes `artifacts/mojulo-lab/<side>/RESULTS.md`:
1. What worked.
2. What broke, with the exact error text.
3. The highest-detail output reached, as triangles, bytes and time.
4. The hero's progression.
5. The machine: CPU, RAM, Node, Godot and Blender versions, and whether a GPU was used.

Keep stills as JPEG under 500 KB each, and leave any glb over 50 MB out of git.
