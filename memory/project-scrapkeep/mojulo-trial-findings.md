---
name: mojulo-trial-findings
description: "Mojulo 3.0.0 plugin trial 2026-10-22: good for exact-size greybox glTF; its Godot game export and web traversal audits are not trustworthy"
metadata:
  node_type: memory
  type: project
  originSessionId: 97286b19-1c16-4e54-8dd9-aadd2bcf7608
  modified: 2026-10-23T00:59:55.565Z
---

Mojulo (MCP plugin, v3.0.0, store at ~/.mojulo) was trialled for Scrapkeep on 2026-10-22. Andrew liked the results and asked for its use on specified tasks, coordinated with the wave 18-21 coordinator (offer sent, option A = wave 19 greybox arenas and risk lines).

- Good: workbench `fields` with `exact: true` and `kind: 'scad'` (OpenSCAD) give exact-size solids; `export_model` glb lands in metres in Godot; a ball rolls on them with trimesh collision.
- Large recipes go through the CLI: `~/.npm/_npx/944e8abfdb21a75f/node_modules/.bin/mojulo call <tool> --json @file.json` (routes via the running server).
- Not trustworthy: `export_game target:'godot'` (kernel 0.3.0) uses a flat ground plane, drops level collision and custom `events` zones, and ignores platform tuning. Its ledger still says portable.
- The web `platform` controller has no slope momentum and snaps up onto ledges from below; `hazard-damage` and `reach-exit` zones are planar; the fall catch-box is fixed at z < -20. A traversal audit can pass an unbeatable level, so always run a walk-only negative control.
- Terrain worlds with `plants` export every plant as its own mesh (92.7M triangles).

Coordinator ruling 2026-10-22: a narrower option A. Greybox proposals only, behind Andrew's veto pass on the map design page, with nothing on a stage branch. The set of 8 (5 pockets, 3 arenas) was posted on #241 (comment 6354815943). Stills page: https://claude.ai/artifact/NhC1kCXBJh1g8NFssiPvmt. Files are in `artifacts/local/greybox/` of the mojulo-plugin-exploration worktree; that folder is gitignored, so it is lost if the worktree goes. Open owner decision: the W1 bowl holds an orbit only up to 20 m/s, so deepen it or keep it.
- Godot ball proof gotchas: run inside a project (`--path` to a dir with project.godot); without one the physics does not step. Set ball damping to 0, because Godot's 0.1 default bleeds about 1.5 m/s per second. Use game gravity 26 and collision radius 0.92. A steep foot on a hump bounces the ball back, so use smooth profiles.
- `update_sketch` refuses a full workbench manifest replace; patch by monomer id (`{op:'set', id, terms}`).

**How to apply:** use mojulo for geometry into our own Godot scenes, gated by Godot physics, and cite a board per [[art-purpose-before-making]]. Related: [[alpha-coordinator-handoff]].

2026-10-22 lab (artifacts/mojulo-lab, commit 3190f7048): the `code` kind built the Spillway dam hero (134k tris, three revisions, ball rides the face to the toe in Godot). Export with `lit: true` for Blender/Godot, then gamma-decode COLOR_0 (it holds sRGB). `displace` after 2+ shape terms errors; wrap the shapes in a zero `transform`. Andrew liked the result as a fast base to build movement, traversal, combat and event systems on (2026-10-22).

Playbook: the scrapkeep-blockout project skill (.agents/skills/scrapkeep-blockout, commit 046e37840 on claude/mojulo-plugin-exploration-a455a3) holds the procedure, gotchas and cloud setup. Load it before any mojulo work.

2026-10-23 props/critters trial (PR #382, artifacts/mojulo-prop-trial, page https://claude.ai/artifact/Bo8kUt8eCJ84ficQj1BK5U): dam wheelhouse ported to code kind matches the Blender kit look at 17.1k tris but beats it on nothing (exact rounded boxes cost ≥8 segments, so full bevels hit 29k vs 20k cap); verdict props "not yet". Toad body via smooth-union fields reads as one plush body (good for principle 12) but needs fine cells then Blender collapse to budget, and has no rig. `adopt.py` there is the kit-contract bridge (drops the `static` ground plate, welds, removes loose verts that floated LODs). Exact-field lit COLOR_0 arrived linear, so don't apply BLK-12 decode blindly. Card on "Mojulo for new creature bodies" sent to the coordinator, recommended yes.
