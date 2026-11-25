---
name: scrapkeep-blockout
description: "Build Scrapkeep blockout pieces and landmark heroes as mojulo recipes, export them as glb for Godot and Blender, prove them with the ball in headless Godot, and run mojulo in a cloud session. Use for mojulo greybox, blockout, hero landmark, detail-pass or cloud mojulo setup work; mojulo's own vocabulary stays in the mojulo:mojulo plugin skill, which checks qualify a change stay in scrapkeep-verify, and admission in scrapkeep-task."
---

# Build blockout with mojulo

Resolve this skill directory through symlinks, then run `git -C <resolved-skill-directory> rev-parse --show-toplevel` to identify the repository root. Read `AGENTS.md` and `project-guide/handoff/START-HERE.md`. Use root-relative source paths below. The linked Claude skill resolves to this same body.

Mojulo (npm `mojulo@3.0.0`) compiles small deterministic recipes into geometry. Andrew ruled on 2026-10-22 that it is the go-forward base for map and gameplay blockout, so the team can build movement, traversal, combat and event systems on top quickly (BLK-01). This skill owns the method: recipe, export, ball proof and stills. The `mojulo:mojulo` plugin skill owns the tool's vocabulary and manuals. `scrapkeep-verify` owns which checks qualify a change, and `scrapkeep-task` owns admission. Nothing goes onto a stage branch before the coordinator turns a proposal into a card.

Read [references/gotchas.md](references/gotchas.md) before the first call. It lists each pitfall with its fix. Read [references/cloud-setup.md](references/cloud-setup.md) before running mojulo in a cloud box.

## 1. Set up (5 minutes)

1. Node 22.14 or newer. Run `npx -y mojulo@3.0.0 orient` once. On the PC the plugin MCP tools also work; in a cloud box, only the CLI does (BLK-02).
2. Drive it with `npx -y mojulo@3.0.0 call <tool> --json @<absolute args file>`. Pass an absolute path: a relative args file resolves against another directory (BLK-03).
3. Export with `MOJULO_MCP_TOOL_TIMEOUT_MS=600000`. The 120 s default budget kills big exports and writes no glb (BLK-04).
4. Read the manual for a kind before using it: `call get_solid_vocab --json '{"id":"workbench"}'`, or `code`, `scad`, or `get_view_vocab` for `terrain`.
5. Keep work under `artifacts/` on a lab or greybox branch. Run CPU work at `nice -n 10`, and take no GPU while `~/scratch/w18/gates/timing.lock` is held (design choice).

## 2. Pick the input

| Need | Kind | Notes |
|---|---|---|
| A pocket, ramp, bowl or arena shape | `workbench` with `fields`, `exact: true` | Sharp booleans, but `blend`, `displace` and `round` are refused (BLK-05) |
| A hero with repeated parts (rails, joints, streaks, terraces) | `code`: a JavaScript program returning a workbench spec | Seeded `Math.random`, source up to 64 KB. The dam hero is 230 lines (BLK-06) |
| A machined part with many holes | OpenSCAD (`scad`) | Precise but slow at high `$fn` (BLK-07) |
| A wide landscape | `compose_world` with `base: 'terrain'` | Mood and layout only. Skip `plants` for game use (BLK-08) |

Work in mojulo units: cm, z up. Put the toe or floor at z = 0.

## 3. Build in layers

1. One-shot the whole piece first, then make at most three revisions. Keep each revision's still so the progression shows (BLK-09).
2. For a hero, write the program in sections: body, surface relief, crest or rim, service details, surroundings. Each new detail is a new section, so the recipe stays editable (BLK-06).
3. Budget triangles per piece: under 50k for a pocket and under 300k for a hero. Write down where the detail went.
4. Shape detail belongs in mojulo. Surface look (grime, wet streaks, edge wear) is a Blender bake. Moving effects (water, spray, event props) belong in Godot (BLK-10).

## 4. Export

1. `export_model { ref, format: 'glb', lit: true }`. The default glb is unlit, with light baked into the vertex colours (BLK-11).
2. Decode `COLOR_0` with gamma 2.2 in the Blender or Godot material. The lit glb stores sRGB values in a channel glTF defines as linear (BLK-12).
3. The glb bytes change with the sketch ref. To prove determinism, hash only the geometry with `artifacts/mojulo-lab/inputs/geomhash.py` (BLK-13).
4. Never ship mojulo's Godot game pack, and never treat its traversal audit as a gate (BLK-14).

## 5. Prove it with the ball

1. Copy `artifacts/mojulo-lab/inputs/ball_proof.gd` and `project.godot` next to the glb, then run `godot --headless --path <dir> --script res://ball_proof.gd -- <spec file>`. Without `--path` the physics does not step (BLK-15).
2. Use the game's ball: radius 0.92 m, gravity 26 m/s², damping 0, and entry speeds of cruise 14, blazing 26.6 and fast 37 m/s (BLK-16).
3. Pair every pass run with a control that must fail: too slow, the wrong line, or behind the piece. A proof whose control passes decides nothing (BLK-17).
4. Record the import ms, node count, triangle count and each verdict line.

## 6. Stills for Andrew

Render a board-camera still and a top-down still in Blender, Cycles on the CPU (`artifacts/mojulo-lab/local/C/hero_stills.py`). Keep each JPEG under 500 KB. Keep any glb over 50 MB out of git (design choice).

## Lessons and updates

[references/lessons.md](references/lessons.md) holds BLK-01 onward. Status is `established`, `provisional` or `retracted`. When a result overturns a lesson, retract it, fill `Overturned by`, change the rule line above in the same commit, and add a changelog row.

## Host adapter

- Antigravity: `/scrapkeep-blockout`. Use `blender_blender` MCP for scene inspection and stills alongside headless Godot ball proofs, and report active Gemini model/tier.
- Claude Code: `/scrapkeep-blockout`.
- Report the actual model and active effort or tier (or its absence).
