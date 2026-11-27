# Outfits and the Till Bell

Built 2026-10-16 from `design-v3/COSMETICS-ART-BRIEFS.md`, sections "Outfits" and "Companion skin". Kest's Rigger Harness is cut (Andrew, 2026-10-16) and is not built.

| Item | GLB | Rides | Triangles (start) | Draws | Notes |
| --- | --- | --- | --- | --- | --- |
| Welding Hood (`outfit_rivet_hood`) | `assets/cosmetics/outfits/outfit_rivet_hood.glb` | `head` | 332 (350) | 1 | Rests lifted. `ult_windup` swings it 70° down over the goggles in 0.12 s and holds; `ult_recover` lifts it back over 0.25 s |
| Eyeshade (`outfit_tally_eyeshade`) | `assets/cosmetics/outfits/outfit_tally_eyeshade.glb` | `head`, `upper_arm.L`, `upper_arm.R` | 520 (300) | 3 | Mulberry band and bill with a copper rim; two mulberry garters |
| Steady Cap (`outfit_tarn_steady_cap`) | `assets/cosmetics/outfits/outfit_tarn_steady_cap.glb` | `head` > `Replace_Cap` | 272 (250) | 1 | Hides the battered `Cap`. Taller, clean crown, one Redjaw stripe, top button |
| Till Bell (`companion_skin_till_bell`) | `assets/cosmetics/companion_skins/companion_skin_till_bell.glb` | `Deck` | 312 (200; target 600) | 1 | All `copper`, at deck (0.07, -0.20), clear of both socket collars |

## Build and check

From `sketches/core-loop/tools/blender`:

```sh
blender -b --python-exit-code 1 -P outfits/build_outfits.py              # all four; or name items
blender -b --python-exit-code 1 -P outfits/preview.py -- outfit_rivet_hood [--down] [--bare]
```

From `sketches/core-loop`, after `godot --headless --import --path .`:

```sh
godot --headless --path . --script res://tests/outfit_art_test.gd
```

The recipe reads each rig's rest joint frames and skinned vertices straight from the shipped GLB (`rig_space.py`), models in pilot space against those vertices, then moves each part into its bone's frame. The GLB's scene roots are the bone nodes, so `hero_assets._mount_on_bones` mounts each with no offset. Two runs give byte-identical GLBs.

`preview.py` imports the rig and the exported GLB, puts each bone node at its rest frame, applies `Replace_`, and renders Cycles CPU stills. The glass dome and pod are left out so the head reads. Stills are in `artifacts/outfits-2026-10-16/`.

`outfit_art_test.gd` mounts each GLB on its shipped rig through `fit_outfit_scene` (outfits) or `_mount_on_bones` (the bell), and checks the bones, the triangle cap, no light or override, that each outfit stays inside the 0.98 m dome, the hood's two clips, and that the Steady Cap covers and hides the battered cap and restores it when removed.

## Port notes for the wave coordinator

> **Shipped status:** Steps 1–3 below (`mount-port.patch` bone/animation matching in `hero_assets._mount_on_bones`, `registry.d/` outfit fragments, and `Cosmetics` un-hiding + `MOUNT_PATCHED := true`) have landed on `main`; kept below for outfit asset context.

In order. Nothing here edits `src/`.

1. **Loader patch (`mount-port.patch`).** `git apply sketches/core-loop/tools/blender/outfits/mount-port.patch` from the repo root. It fixes two gaps in `hero_assets._mount_on_bones` that no outfit had hit yet:
   - glTF import renames a node `upper_arm.L` to `upper_arm_L`, so `find_bone` misses it and the Eyeshade's garters are dropped. The patch matches parts by the sanitised bone name.
   - An imported clip's tracks address `head/HoodShell`, but after the mount the part sits at `Outfit_head/head/HoodShell`, so the hood never moves. The patch rewrites each copied track to go through its attachment.

   The patch also sets `MOUNT_PATCHED := true` in `outfit_art_test.gd`, which turns the garters and the hood's motion into required checks. Checked here: with the patch, `outfit_art_test` passes 26 checks and `shell_layers_test` 136; without it, `outfit_art_test` passes 23 and reports the two gaps. Without the patch, the visor, hood (static, lifted), cap and bell all still mount.

2. **Registry rows: done on this branch** (Andrew's 2026-10-17 rule lets cloud threads edit `assets/` and `registry.d` on their own branches). One fragment per item in `assets/registry.d/` (`outfit_rivet_hood.json`, `outfit_tally_eyeshade.json`, `outfit_tarn_steady_cap.json`, `companion_skin_till_bell.json`), class `detail`, folded into `assets/registry.json`. The Eyeshade carries a `draws: 3` exception (visor plus two garters). `asset_registry_test` passes.

   If the Eyeshade's draw exception is not wanted, delete the two garter blocks from `tally_eyeshade()` and rebuild: the visor alone is one draw at 360 triangles.

3. **Un-hide.** Remove `outfit_rivet_hood`, `outfit_tally_eyeshade`, `outfit_tarn_steady_cap` and `companion_skin_till_bell` from `PENDING_ART` (`src/core/cosmetics.gd:27`) as each row lands. Then re-pin the tests the briefs' port notes name: `tests/rivet_set_piece_test.gd:849-850` (the hood is live), `tests/tally_set_piece_test.gd:645` and `tests/tarn_set_piece_test.gd:249` (the outfit is live), and run `customization_system_test` and `ui_customize_page_test`, which check that every non-pending row resolves to real art.

## Changes from the briefs

- **Welding Hood: one node, not two.** The brief puts the shell on `head` and the lens plate on `goggles`. The lens is a smoked-glass row of the shell instead, so the hood and its slot move as one piece on one clip. Rivet's own `goggles` bone moves only 8° in `ult_windup`, so it could not carry the snap.
- **Welding Hood: `ult_recover` added.** With only `ult_windup` the hood would stay down for the rest of the run after the first ultimate.
- **Copper in vertex colour.** Pins and rims on pilot-worn pieces are the `pilot` slot with copper baked in, which keeps the hood, the Eyeshade visor and the cap to one draw each (the `detail` class cap). The Till Bell is all `copper`, also one draw.
- **Over the start budgets.** The Eyeshade is 520 triangles against a 300 start, from the bill's copper rim and the 16-segment band; the bell is 312 against 200 (target 600). Both are well under the 1,500 cap.
- **Steady Cap is puffed up, not a straight copy.** Copying the battered cap without its dents left them indistinguishable from the chase camera, so the crown is 0.045 m high against 0.018 m, with a top button. The joke needs the swap to read.

## Not checked

The in-game look through the glass dome at the 7.5 m chase camera, the import colour space, and how the hood's snap feels against Rivet's wind-up. These need Godot with a GPU on Andrew's machine.
