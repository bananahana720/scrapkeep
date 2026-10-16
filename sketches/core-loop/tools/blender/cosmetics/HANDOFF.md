# CUA handoff

PASS+NOTES, evidence level 4: Blender exports and real headless Godot imports/tests ran; malformed scratch assets fail loudly.
Branch `wt/dress-w2-custom-assets`, HEAD/base `955e7e55aa10a69c3d0f6c71d0bd2eb4763c5970`. No new commit. `git diff --stat 955e7e55aa10a69c3d0f6c71d0bd2eb4763c5970..HEAD` is empty because the coordinator commits the untracked files. No tracked or `src/` file changed.
Checked with Blender 5.2.2 LTS `d13f752e3b9c`, Godot 4.7.2 `ed1daf0bf`, and Python 3.14. All previews use Cycles CPU, two threads, eight samples. Finished within the 150-minute timebox.

## Acceptance and commands

- CUA-1 met. `python3 sketches/core-loop/tools/blender/cosmetics/inspect_cua.py --compare /tmp/scrapkeep-cua-rerun --previews artifacts/local/dress-preview/CUA --out artifacts/local/dress-preview/CUA/asset-inspection.json` prints `CUA_INSPECT: PASS (31 files; rerun byte-identical; 72 previews)`. It lists all files and sizes below and in its JSON receipt.
- CUA-2 met. `XDG_CONFIG_HOME=/tmp/scrapkeep-cua-godot-config node scripts/sketch-smoke.mjs --sketch core-loop --test dress_cua_assets_test` prints `PASS sketches/core-loop res://tests/dress_cua_assets_test.gd exit=0 1.0s`. Direct execution prints `CUA checks: 543; failures: 0` and `dress_cua_assets_test: PASS`. The final named run has zero skips and no missing verdicts. No existing test loads these new asset paths; the scoped source search matched only this test.
- CUA-3 met. Ran `blender -b --factory-startup --threads 2 -P sketches/core-loop/tools/blender/cosmetics/build_cua.py`, then the same command with `-- --out /tmp/scrapkeep-cua-rerun`. Both print `CUA_BUILD: PASS (6 animated trail GLBs, 8 decal resources/masks, 6 tint resources)`. All 31 authored asset files match byte for byte. Reproducibility is measured on this installed Blender version.
- CUA-4 met for this asset unit. The imported and independently parsed card counts are 2 T / 4 V / 1 surface. A tested 24-instance MultiMesh fixture is 48 T / 96 V / 1 surface, within scenery 120 T / 110 V / 2 draws. Decals and paints add 0 T / 0 V / 0 draws. Texture sides are 512, 1024 and 256, below 2048. Final shell and fitted-companion totals remain the modelling/wiring units' checks.
- CUA-5 met. `blender -b --factory-startup --threads 2 -P sketches/core-loop/tools/blender/cosmetics/preview_cua.py` authored trail previews; final decal/paint reruns used `-- --kind decals` and `-- --kind paints`, each ending `CUA_PREVIEWS: PASS`. Inventory confirms 72 nonempty views: 60 arena-scale views, six clip key poses and six 24-card threat fixtures. Four additional sheets include an eight-motif 24 px inspection.

## Broken-rule checks

Run the Godot script with `-- --cua-break=missing-node`, `-- --cua-break=missing-clip` or `-- --cua-break=reserved-pixel`. Each modifies a scratch copy only.
`CUA check -> FAIL: trail_salt_skip REQUIRED NODE ChalkPuff` followed by `dress_cua_assets_test: FAIL`.
`CUA check -> FAIL: trail_salt_skip REQUIRED CLIP fade_shrink` followed by `dress_cua_assets_test: FAIL`.
`CUA check -> FAIL: user://cua-reserved-pixel.png no mint/hazard/amber/brass pixels` followed by `dress_cua_assets_test: FAIL`.
Unmodified final assets: `dress_cua_assets_test: PASS`. Original files were never mutated by these probes.

## Files and budget numbers

Paths are under `sketches/core-loop/assets/cosmetics/`. For decal rows, the two files are `decals/<id>.tres` and `decals/<id>_mask.png`; sizes are listed in that order. Paint rows are `paints/<id>.tres`.

| File or id | Bytes | Added T / V / surfaces |
| --- | ---: | --- |
| trails/trail_salt_skip.glb | 10408 | 2 / 4 / 1 |
| trails/trail_ink_stitch.glb | 10208 | 2 / 4 / 1 |
| trails/trail_plum_curl.glb | 10932 | 2 / 4 / 1 |
| trails/trail_forge_chips.glb | 10532 | 2 / 4 / 1 |
| trails/trail_moth_tuft.glb | 10504 | 2 / 4 / 1 |
| trails/trail_rose_wash.glb | 10408 | 2 / 4 / 1 |
| decal_fern | 266 / 1595 | 0 / 0 / 0 |
| decal_patch | 268 / 1200 | 0 / 0 / 0 |
| decal_snail_shell | 268 / 1498 | 0 / 0 / 0 |
| decal_thimble | 268 / 1241 | 0 / 0 / 0 |
| decal_mushroom | 268 / 1072 | 0 / 0 / 0 |
| decal_paw | 270 / 1378 | 0 / 0 / 0 |
| decal_seashell | 270 / 1801 | 0 / 0 / 0 |
| decal_moth | 270 / 1568 | 0 / 0 / 0 |
| companion_paint_night | 198 | 0 / 0 / 0 |
| companion_paint_forge | 198 | 0 / 0 / 0 |
| companion_paint_plum | 198 | 0 / 0 / 0 |
| companion_paint_salt | 198 | 0 / 0 / 0 |
| companion_paint_dusk | 198 | 0 / 0 / 0 |
| companion_paint_moth | 198 | 0 / 0 / 0 |
| textures/trail_atlas.png, 512×512 | 6976 | shared atlas |
| textures/decal_atlas.png, 1024×1024 | 16005 | shared atlas |
| cua_manifest.json | 15652 | paths, hashes, clips, dimensions, contracts |

## Limits and design note

The GLBs carry transform animation. Core glTF cannot animate material alpha; the manifest supplies the fade envelope for the later consumer. It must suppress stationary/paused/airborne emission, enforce card/distance caps, fade cosmetics on threat overlap and batch cards into one draw. Peak alpha is 36/255; a straight densest wake retains at least 73.7578% threat contrast. Folded paths still require the consumer's threat fade.
Paint previews use a dimensioned SPIL-9 proxy, and decal previews use material composition on a 2 m shell fixture. Native shell UV attachment, final companion enamel exclusions, live chase-camera threat readability, runtime performance and Andrew's acceptance await integration. No companion body or mechanism asset is claimed here.
Design note for DESIGN-NOTES: treat customization as one material/atlas composition system. Apply companion swatch tints only to existing Hull/Deck enamel, and compose a selected decal into HeroCore paint with no sticker mesh. Reuse existing motion and state cues. The manifest's visible mask bounds keep decal metre dimensions separate from transparent gutters.

Evidence is untracked under `artifacts/local/dress-preview/CUA/`: `asset-inspection.json`, `godot-test.log`, `godot-direct.log`, three negative logs, three preview manifests, all 72 views, `trails_sheet.png`, `decals_sheet.png`, `paints_sheet.png` and `decals_24px_sheet.png`.

## Wave 19 extension: seven trails and decals 8 and 9

Branch `claude/cosmetics-trails-decals-uaaipf` from `origin/main` at `dfc86d8`, per `design-v3/COSMETICS-ART-BRIEFS.md`. Same recipe, same checks; counts are now 13 trails, 10 decals, 6 paints and 42 files. Every trail GLB re-exports because the shared atlas grew (each GLB still carries the dead embedded atlas bytes the export leaves behind); geometry, UVs and clips of the first six are unchanged. Two calls differ from the brief: Cable Stitch bakes `3f8f6a`, not field mint `8bf0d3`, because mint is reserved (`dress_cua_assets_test` RESERVED, VISUAL-LANGUAGE "Field mint"); Claw Marks sit 0.33 m apart, not 0.34 m, to keep the blur inside the tile.

Port notes for the wave coordinator (this branch edits neither `src/` nor the registry):

1. `assets/registry.d/`: add one fragment per new file, in the shape of `trail_salt_skip.json` and `decal_fern_mask.png.json`, then fold the registry. Trails (`class` scenery, `loader` "none (delivered model; runtime integration pending)"): `trail_sable_cable`, `trail_rivet_swarf`, `trail_kest_fuse_smoke`, `trail_tarn_claw_marks`, `trail_tally_punch_tape`, `trail_cannon_recital`, `trail_any_downbeat`, each at `res://assets/cosmetics/trails/<id>.glb`. Decal masks (`class` texture, `loader` "none (delivered cosmetic texture; runtime integration pending)"): `decal_sable_spool_mask.png`, `decal_curtain_call_mask.png`, at `res://assets/cosmetics/decals/<id>`. Provenance recipe `tools/blender/cosmetics/build_cua.py`. The decal rows matter: `cosmetics.gd` resolves `decal_*_mask.png` through the registry, while trails also resolve through the manifest.
2. `src/core/cosmetics.gd:27`: remove the nine ids from `PENDING_ART`.
3. `src/core/cosmetics.gd:77`: set the `trail_sable_cable` tint to `3f8f6a` so the Customize swatch matches the baked card. Andrew chose the deep green on the project-chat card, 2026-10-16 23:22Z.
4. Then run `customization_system_test` and `ui_customize_page_test`, which check that every non-pending row resolves to real art.
