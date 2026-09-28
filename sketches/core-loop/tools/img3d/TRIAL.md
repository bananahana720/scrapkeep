# Image-to-3D trial, 2026-09-28

The visual track needs sculpted organic geometry that scripted Blender recipes do not produce. This trial asked whether a local image-to-3D model can supply it within Style A budgets. Tools, installs, licenses and VRAM are in [README.md](README.md). Evidence is under `artifacts/local/img3d/` in this worktree: `refs/`, `raw/`, `clean/`, `renders/` and `logs/`.

## Candidates

| Candidate | Outcome |
| --- | --- |
| microsoft/TRELLIS.2 | **Blocked before install.** Its image conditioner, `facebook/dinov3-vitl16-pretrain-lvd1689m`, is a manually gated repo, and the local Hugging Face token has no access. `artifacts/local/img3d/licenses/hf_auth_check.txt` records `auth_check` raising `GatedRepoError: 403` with `gated=manual`. The pipeline cannot run without it. The model card also states a 24 GB minimum. The repo is cloned, but nothing was built. |
| microsoft/TRELLIS (v1) | **Ran.** Installed in about 3 minutes from wheels only, with no CUDA extension built against nvcc 13.3. Mesh-only decode takes 6 to 11 s per asset after an 18 to 23 s model load, at 12.4 to 13.2 GB torch reserved. |
| Hunyuan3D 2.x | License read and quoted in the README. Not installed: the ordered list stopped at a working candidate, and its license excludes the EU, UK and South Korea. Stated VRAM: 2.0 needs "6 GB VRAM for shape generation and 16 GB for shape and texture generation in total", and 2.1 needs "10 GB VRAM for shape generation, 21GB for texture generation and 29GB for shape and texture generation in total" (`licenses/hunyuan3d-2.0_README.md:126` and `licenses/hunyuan3d-2.1_README.md:81`). |

## Results

The references came from Qwen-Image-2.1 at about 47 to 70 s each and 7.7 GB torch reserved. Every raw mesh is TRELLIS v1 output at the default 25 plus 25 sampler steps. Final triangle counts are after cleanup, and Godot's headless load check read the same counts.

| Asset | Candidate, reference, seed | Gen s | Peak VRAM | Raw tris | Final tris | Quality note |
| --- | --- | --- | --- | --- | --- | --- |
| A. Warden body, `trial_img3d_warden.glb` | TRELLIS v1, `ref_warden_clean_s11`, seed 1 | 8.2 | 12,384 MiB torch reserved; batch job peak 12,771 MiB | 652,518 | 5,969 | The front matches the concept: a round cracked shell in olive and rust, cyan seams, a caged reactor cap and four sandstone claw legs. The back is invented, a cluster of exhaust pipes the reference never showed. Seams are albedo only and fade at 12 m. It is one fused mesh with no hinge, jaw or shell-split parts. Size is 6.5 x 7.8 x 4.2 m. |
| B. Sandstone cliff chunk, `trial_img3d_cliff.glb` | TRELLIS v1, `ref_cliff_s23`, seed 3 | 7.0 | 12,738 MiB torch reserved; batch job peak 11,918 MiB | 685,164 | 2,984 | The best of the three. At 12 m the strata, terracotta bands and overhanging lip read. The layers are rounded and pillowy, so the chunk looks closer to a stacked block or brick wall than to the concept's craggy, eroded cliff. The shrub tufts are small sprigs on the top face; they show in the turntable but not in the chase still. The ends are cut flat along X for butting, but the end profiles do not match, so it is not truly tileable. Size is 6.0 x 3.8 x 5.0 m, now exact on X because the cleanup rescales after trimming. |
| C. Lantern on a post, `trial_img3d_prop.glb` | TRELLIS v1, `ref_prop_s23`, seed 1 | 6.2 | 13,016 MiB torch reserved; batch job peak 13,325 MiB | 220,840 | 995 | Clean on the first try: wooden post, sandstone plinth, curled iron bracket and a brass lantern with amber panes. The glow is albedo, not emission. Size is 1.3 x 2.6 x 0.8 m. |

Every attempt, including the rejects:

| Mesh | Result |
| --- | --- |
| `warden_a_s1` (ref s11, miniature wording) | Rejected. It stands on a hallucinated square base plate, and its steam plumes became black sheets. |
| `warden_b_s1..s3` (ref s23, miniature wording) | Rejected. Seed 1 has a tilted base plate, which a flat `--floor-cut 0.05` missed. Seeds 2 and 3 have white fins made from steam puffs. |
| `warden_c_s1`, `warden_c_s2` (clean ref s11, no steam, no base, floating) | Seed 1 picked. Seed 2 grew a malformed chest. |
| `warden_d_s1`, `warden_d_s2` (clean ref s37, grounded with a contact shadow) | Rejected. The base plate came back. |
| `cliff_a_s1` (ref s11) | Rejected. The unseen back became ragged flaps. |
| `cliff_b_s1`, `s2`, `s3` (ref s23) | Seed 3 picked. Seed 1 has a thin spike on top, and seed 2 has a flat white sheet through the top. |
| `prop_a_s1`, `prop_b_s1` | Both usable. `prop_b` has the cleaner silhouette. |

That makes 1 clean mesh out of 4 for the cliff, 1 out of 8 for the Warden and 2 out of 2 for the prop. Seeds are cheap at about 10 s each, so the practical workflow is three seeds per reference and keep the best.

The first TRELLIS batch exported every mesh upside down, because the axis conversion used a transposed matrix. `img3d_generate.py` now matches upstream `postprocessing_utils.to_glb`. The flipped batch is kept in `raw_v0_flipped_axis/`.

Renders:

| Asset | Turntable sheet | Chase still |
| --- | --- | --- |
| Warden | `renders/warden_c_s1_tt_sheet.png` | `renders/warden_c_s1_chase.png` |
| Cliff | `renders/cliff_b_s3_tt_sheet.png` | `renders/cliff_b_s3_chase.png` |
| Prop | `renders/prop_b_s1_tt_sheet.png` | `renders/prop_b_s1_chase.png` |

`renders/cliff_vs_scripted.png` puts the visual track's concept and current in-game world (`look-pass/final-low/overview-pair.png`, read only) above the TRELLIS cliff's chase still and one turntable view. `pre_fix_round/` keeps the first-round clean meshes and renders.

### Single-sided export and winding

The first-round GLBs exported `doubleSided: true`, which hid any winding fault and doubled fill cost. They now export single-sided, and Godot imports them with `cull_mode` back (`logs/godot-check-fix.log`). The winding report in `clean/clean.jsonl` finds 0 inconsistent and 0 non-manifold edges on every island of all three meshes, so no face is flipped against its neighbours. The cliff is closed. The Warden has 19 open edges and the prop's main island 142.

The backface check (`turntable_blender.py --backface-check`, `logs/backface-*.log`) measures how much of each object's pixels would open a hole under culling. A copy of the cliff with every normal flipped scores 99.6%, which confirms the check works.

| Mesh | Worst view, back-face share of object pixels | Where |
| --- | --- | --- |
| Warden | 0.13% | scattered pixels |
| Cliff | 2.55% | decimation folds, mostly one patch under the overhanging lip (`renders/cliff_b_s3_bf_7.png`) |
| Prop | 0.15% | scattered pixels |

The cliff's patch is a real defect. The collapse decimator pushed the underside of the lip through itself. Single-sided, it shows as a small hole under the lip, where double-sided showed a wrongly lit back face. It is small at 12 m, but a kit piece should be checked with `--backface-check` before use.

## Verdict

**Cliffs: promising, not proven better.** The chunk has banded strata, an overhanging lip and chunky cracks. The visual track's scoring (`look-pass/scores.md:88`) said the world needs these in place of its smooth boundary walls, and the current in-game walls lack them (`renders/cliff_vs_scripted.png`). It costs 3,000 triangles with a 1K painted texture, about 50 s of image generation, 7 s of TRELLIS and 15 s of Blender. Three limits keep this from being a clear win:

- The layers are rounded and pillowy, so it reads as stacked masonry more than the concept's craggy cliff.
- The shrubs vanish at chase distance.
- The comparison is not like for like. There is no Blender cliff recipe to compare against; the visual track's cliffs are scripted Godot geometry with a strata shader (`src/presentation/spillway_scenery.gd` in the visual workspace). The TRELLIS chunk was also rendered alone in Blender, not in the game scene under game lighting, and nobody scored it.

Seed variance is a further cost: three of four cliff meshes had hidden-side artifacts. The chunk is not tileable as generated. It needs overlap placement, or end caps hidden in a kit.

**Warden: no, not as a replacement.** TRELLIS gets the silhouette, palette and crack pattern, which the recipes struggle with. The in-game Warden, though, is a kit of articulated parts with hinges, a shell that splits open, animated emission and fitted shred ribbons (`WARDEN-ASSETS.md`), and a fused 6,000-triangle statue supports none of that. Hard edges also go soft after decimation to 6,000. The Cherenkov seams are baked into albedo, so they cannot pulse.

**Weak spots, in order of cost:**

1. Unseen sides are invented, and the output can differ from the concept behind the object.
2. Anything wispy in the reference becomes a solid sheet or fin: steam, sparks, electric arcs.
3. A contact shadow, or "miniature" in the prompt, produces a display base plate. A floating subject on a flat backdrop avoids it.
4. v1's mesh colour head is soft. It holds at 1K and chase distance, but not close up.
5. There is no part separation, emission mask or rig.
6. Rounded, even layering: sandstone strata come out as stacked blocks rather than sharp eroded ledges.
7. Collapse decimation to a few thousand triangles can fold thin overhangs through themselves. The cliff lip shows this.
8. Scale is not controlled by the model. The cleanup now rescales to the exact target after trimming, so this no longer affects the output.

**License blocker for shipping.** Qwen-Image-2.1 is licensed "FOR NON-COMMERCIAL PURPOSES ONLY", so these three GLBs count as evaluation assets. TRELLIS v1 itself is MIT. Shipped assets need references from a commercially clean source: concept art with cleared provenance (not checked in this trial), a hand paintover, or an image model whose license allows commercial use.

## Recommended next step for the Codex visual track

Run an in-engine cliff test before adopting TRELLIS v1 for the rock and cliff kit. Keep Blender recipes for the Warden's articulated parts.

1. Cliffs and rocks come first, as a scored test rather than an adoption. Place `trial_img3d_cliff.glb` in the Spillway scene next to the current boundary walls. Capture it at chase distance under game lighting and score it with the visual track's rubric against the concept. Adopt only if it beats the walls on that score. If it does, generate 4 to 6 kit pieces (straight wall, outside corner, lip overhang, pillar and two boulders). Use one reference, three TRELLIS seeds and `run_trial.sh` per piece, and prompt for sharper, craggier ledges than this chunk's rounded blocks. Check each piece with `--backface-check`. For seams, overlap pieces and hide ends in shrubs or water; do not try to make generated profiles match.
2. Warden: use TRELLIS per part rather than for the whole body. Generate one isolated reference per part (shell half, claw leg, reactor cap), run them through TRELLIS, and use the meshes as sculpt detail or retopo targets. The existing kit supplies the hinge pivots and emission masks.
3. Before any of this ships, replace Qwen-Image-2.1 as the reference source. Crop concept art once its provenance is cleared, or pick an image model with a commercial-use license.
4. Optional upgrade: TRELLIS.2 offers higher-resolution geometry and PBR textures. It needs Andrew to request DINOv3 access on Hugging Face and Meta to approve it. Then a test of `low_vram` at 512³ on 16 GB, with RGBA input so RMBG-2.0 (CC BY-NC) never loads.
