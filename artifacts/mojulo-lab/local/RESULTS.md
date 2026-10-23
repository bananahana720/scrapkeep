# Mojulo lab: local side results

22 October 2026, Andrew's PC. Mojulo `3.0.0` through its CLI (`mojulo call <tool> --json @file`), all work at nice 10 on the CPU.

## Machine

AMD Ryzen 9 5950X (16 cores), 62 GB RAM, Node 26.8.1, Godot 4.7.2, Blender 5.2.3. No GPU was used: the Blender renders ran Cycles on the CPU, and Godot ran headless.

## 1. What worked

- **Part A, determinism:** all three inputs minted and exported as glb and stl (`A-hashes.tsv`). The glb bytes change with the sketch ref, because the ref is written into the file. `A-geomhash.tsv` therefore hashes only the geometry (the glb binary chunk and the STL triangles), and that is the hash to compare across the two machines.
- **The `code` kind:** a 230-line JavaScript program (`C/dam.js`, about 18 KB) generates the whole hero: 189 fields and 290 sweeps per mint. Mojulo seeds `Math.random`, so the program is deterministic.
- **The lit export:** `export_model { lit: true }` writes real PBR materials. Blender then casts shadows, and the canyon wall's shadow falls across the dam face as it does on the board.
- **Godot:** every glb imported at runtime without errors, and trimesh collision built from it directly.

## 2. What broke

| Problem | Exact error or symptom | Workaround |
|---|---|---|
| `displace` after two or more shape terms | `field shape kind must be one of sphere \| ellipsoid \| roundCone \| box \| capsule \| lathe \| extrude \| sweep \| expr \| rock \| crystal` | Group the shapes in a zero `transform` and put `displace` after the group. The minimal repro is in `C/t-d5.json`, and the passing version in `C/t-d6.json` |
| The default glb is unlit | `KHR_materials_unlit` plus baked vertex colours, so Blender and Godot show no lighting | Export with `lit: true` |
| Lit glb colours come out pale | `COLOR_0` holds sRGB values, but glTF defines it as linear | Blender: a gamma 2.2 node between the colour attribute and Base Color (`C/hero_stills.py`). Godot will need the same fix in its material |
| Exact field B1, 512 bores at 256 segments | `memory access out of bounds` | none: this is the ceiling |
| Big exports | `export_model exceeded its 120000ms budget` | Set `MOJULO_MCP_TOOL_TIMEOUT_MS=600000` |

## 3. Highest-detail output reached

See `B-ladder.tsv`. The ladder was still running when this was written. The largest results so far:

| Ladder | Rung | Result |
|---|---|---|
| B1 exact field | 512 bores at 128 segments | 283k triangles, 20.9 MB, 286 s |
| B3 code kind | 10,000 boxes | 272k triangles, 18.0 MB, 33 s. 50,000 boxes timed out after 600 s |
| B4 OpenSCAD | 40 × 40 holes at `$fn` 32 | 213k triangles, 13.7 MB, 101 s. At `$fn` 128 it timed out |
| B5 terrain | 8 features with plants | 13.4M triangles, 30 MB, 37 s |
| B5 terrain | continent with plants | 41.7M triangles, 22.9 MB, 49 s |

The export is the slow step every time. Minting stays under 40 s.

## 4. Hero progression: the Spillway dam face

What I read off the board:
- A concave arch face whose section flares out into a skirt at the toe.
- Two petrol-capped towers with a truss gantry between them.
- A two-lane water sheet, with the reactor plinth standing in it.
- Thin vertical oxide streaks hanging from the crest.
- Canopied service shelves on both abutments.
- Red terraced sandstone that rises above the crest, with green shrubs on its ledges.
- A low camera at the toe.

| Revision | What changed | Faces at mint | glb triangles | Mint |
|---|---|---|---|---|
| r1, one shot | everything in the brief | 63,084 | 107,948 | 14 s |
| r2 | thin streaks instead of slabs, a centre pier splitting the sheet, spray ribbons, petrol gate frames and tower panels, ledge shrubs, a stronger toe flare | 86,560 | 131,954 | 23 s |
| r3 | bigger towers, 8 canyon terraces, shorter streaks, a lighter river, then the lit export with the colour fix | about 88k | 134,264 | 29 s |

Stills: `C/r1/`, `C/r2/`, `C/r3/` (unlit) and `C/r3lit/` (lit, the final). The glb files are not in git.

**Where the detail went:** about 40% to the face (the lathe body, 9 band grooves, 56 streak skins and 26 joint sweeps), 25% to the canyon (a sampled field at 112 cells), 20% to the crest (towers, gantry truss and 2 parapet rails with 96 posts each), and the rest to shrubs, boulders, the river and the plinth.

**Godot proof (r3 lit):**
- **Import:** 93 ms, 246 nodes, 239 meshes, 134,264 triangles.
- **Face run:** a 0.92 m ball under gravity 26 m/s², released 1.4 m in front of the face at z = 110 m, rides the skirt down. It reaches the toe at 3.4 s at 56 m/s and rolls out across the floor at 44 m/s. Verdict PASS.
- **Control:** the same ball dropped behind the dam, upstream, never reaches the toe. Verdict FAIL, as intended.

Specs and logs are in `C/godot/`.

**Blender proof:** the board-camera and top-down stills above, rendered with Cycles on the CPU in 12 to 27 s each.

## 5. Notes for the comparison

- **Cloud side:** it stopped two minutes in, on a Bash permission prompt that needs Andrew's approval.
- **Clock times:** mine are wall clock at nice 10, with other rungs running at the same time, so they are upper bounds.
