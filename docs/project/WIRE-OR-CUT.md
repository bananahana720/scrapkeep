# Wire or cut: the 51 open registry and attack rows

Checked 2026-10-17 against origin/main `cf63e622`, the wave-15 placeholder gate (`gate-w15-cf63e622.json`: 41 `registry` rows, 10 `attack` rows) and a dry run of `tools/coordinator/registry_sweep.py`. This is a list for the machine coordinator to apply. Nothing here edits `assets/registry.d` or `src/`.

Moves the alpha's zero-placeholder criterion. Applying every line clears all 51 rows from the gate.

## How to apply

A ready patch for everything except the `prop_fan` code change is in the project's shared folder at `alpha-status/wire-or-cut/apply-on-cf63e622.patch` (39 files: 37 registry fragments, the folded `registry.json`, `event_kinds.gd`, and the `content_registry.gd` re-pin). It passes `git apply --check` on `cf63e622`. To produce it by hand instead:

1. Run `python3 tools/coordinator/registry_sweep.py sketches/core-loop --write`. It flips the two Mind arena rows (group A1) by itself.
2. Edit the remaining `registry.d` fragments as the tables below say, then run `python3 tools/fold_registry.py --root sketches/core-loop`.
3. Edit the ten `ATTACK_ROWS` entries in `src/core/event_kinds.gd` as the attack table says, and set each row's `open` to `[]`.
4. Re-pin `event_kinds.ATTACK_ROWS` in `src/core/content_registry.gd:87` from `4c42883e…098b` to `e55948ddacee301bba1a3dbf096dca4c71e2f736201b5caefb5394406789746c`. That is the only pin the change moves.

Receipts from applying the patch to a scratch copy of `cf63e622` in the cloud (Godot 4.7.2 headless):

| Check | Before | After |
| --- | --- | --- |
| `npm run sketch:placeholders` | 1,442 in 140 findings | 1,392 in 90 findings (`prop_fan` stays until its code lands; then 1,391) |
| `attack_rows_test.gd` | PASS | PASS, `[open fields] 0` |
| `asset_registry_test.gd`, `content_registry_reach_test.gd` | PASS | PASS |
| `unit_suite_test.gd` | PASS (678 checks) | PASS (678 checks) with the re-pin; without it, 3 checks fail, all on the `ATTACK_ROWS` golden digest |
| `fold_registry.py` | PASS | PASS (415 assets) |

This is not a gate run on the wave-16 candidate. Rebase the patch onto `cand/alpha-w16` before admitting it.

"Relabel" means: keep the file and its recipe, keep `ships: false`, and replace the loader text with the reason given, so that it no longer matches the gate's `integration pending|wire it in` test. A relabel never deletes an asset.

## Registry rows (41)

### A. Wire by a registry flip: the game already loads them (16)

| Rows | Set | Evidence |
| --- | --- | --- |
| A1. `island_rim`, `island_rib` | `ships: true`, loader `src/presentation/arena_mind_dress.gd` | The Mind arena loads both GLBs (`arena_mind_dress.gd:10-11`). The sweep flips them on its own. |
| A2. 8 decal masks: `decal_fern_mask.png`, `decal_moth_mask.png`, `decal_mushroom_mask.png`, `decal_patch_mask.png`, `decal_paw_mask.png`, `decal_seashell_mask.png`, `decal_snail_shell_mask.png`, `decal_thimble_mask.png` | `ships: true`, loader `src/core/cosmetics.gd` | Each decal row names its mask by registry id (`cosmetics.gd:58-65`). `Cosmetics.asset_paths()` resolves that id to the path, and `cosmetic_presentation.gd:200-218` draws it. The sweep cannot see this load because no source file names the path. |
| A3. 6 trails: `trail_forge_chips`, `trail_ink_stitch`, `trail_moth_tuft`, `trail_plum_curl`, `trail_rose_wash`, `trail_salt_skip` | `ships: true`, loader `src/core/cosmetics.gd` | Same route: the trail rows name these ids (`cosmetics.gd:52-57`), and achievements grant them (`achievements.gd`, `grant_grammar_test.gd`). |

To stop A2 and A3 from going stale again, add one name-built rule to `registry_sweep.py` `NAME_BUILT` for the `res://assets/cosmetics/` folder with loader `src/core/cosmetics.gd`.

### B. Wire with a small code change (1)

| Row | Recommendation | Reason |
| --- | --- | --- |
| `prop_fan` | Wire in wave 19 dressing: add it to the Highdraft yard prop table in `highdraft_scenery.gd` (about line 699, weight 1, size about 2.0) and autoplay its `spin_loop` clip, then flip the row to `ships: true` with that loader. | Every other Highdraft yard prop is already placed there. The fan is the only one with a loop clip (`tools/blender/highdraft/props.py:332-335`), so it adds motion to a windy world for one table line. If wave 19 runs out of room, relabel it "unplaced yard prop" instead. |

### C. Relabel: not game content, or superseded (24)

| Rows | New loader text | Reason |
| --- | --- | --- |
| `trail_atlas.png` | `used by res://assets/cosmetics/trails/*.glb` | All six trail GLBs reference this atlas. It is a dependency of the A3 rows, the same pattern as the existing "embedded in ..." texture rows. |
| `decal_atlas.png` | `atlas behind the cua_manifest .tres AtlasTextures; decal rows read the per-mask PNGs` | The `.tres` files use it, but no cosmetic row resolves a `.tres` id. Every decal row reads its mask PNG (A2). |
| `bed_cut`, `bed_floor`, `bed_recess`, `bed_rubble` | `look-reference study (dig_stone manifest); not placed` | The kit's own notes say "Studies are look references; never tile them as walkable islands" (`assets/models/dig_stone/manifest.json`, `integration_notes`). The shared bed look ships through the stone material (decisions.tsv, P-R9, 2026-10-06). |
| `breach_socket` | `offline study, not fitted to the P-R6 12x12 / 14x10 breach rectangles` | That is the manifest's own wording. The breach drum ships from `breach_rim_sector`, `breach_tab` and the sized wedges (`dig_scenery.gd:434-490`). |
| `breach_wedge_a`, `breach_wedge_b`, `breach_wedge_c` | `superseded by the _12x12 and _14x10 sized wedges` | The sized variants ship through `dig_scenery.gd`. The base wedges carry the circular opening that P-R6 replaced (`dig_mechanical/manifest.json`, `ruling`). |
| `travel_vane` | `cut by P-R9 for readability (decisions.tsv 2026-10-06T20:55)` | The barge travel vane was already cut by that ruling. Only the registry row was never updated. |
| `spil9`, `primer_coil`, `primer_mesh`, `escape_rail`, `escape_vent` | `source piece for assets/models/companion/assembled/ pairs` | At runtime SPIL-9 loads only the 24 assembled `<socket0>__<socket1>.glb` pairs (`companion_body.gd:20`, `:209`). The single pieces are inputs to that build. `ram_prow` and `ram_spring` are listed as shipping with the same loader, but they are in the same position; relabel those two the same way for consistency (they are not in the gate count). |
| `scrap_crate`, `crate_icon_sheet`, `scrap_coin`, `sand_ground_albedo`, `sand_ground_ao`, `sand_ground_height`, `sand_ground_normal`, `sand_ground_roughness` | `asset-forge pipeline proof; not game content` | **Card for Andrew (below).** The forge test pieces have no place in the current game. Crates are already covered by `bet_crate.glb` and the Highdraft `prop_crate`. The scrap icon is the drawn `res_scrap.svg` in the icon set's SVG style. No icon id in the contract needs a crate. The ground is the `Palette.ground_material()` shader, so a photo-style sand set would add a second ground look. |

Count: A 16 + B 1 + C 24 = 41.

## Attack rows (10)

No consumer reads `pose` or `floor` yet (the rows are a frozen contract; `enemy.gd:655-670` uses only the owner and the threat). The values below follow `design-v3/research/attack-reads/ATTACK-READS.md`, whose floor codes are L (thin boundary), H (haze) and B (both). The precedents are the closed rows already in the table: damaging ground hits use B, holds and non-damaging reads use L.

| Row | Set | Reason |
| --- | --- | --- |
| E19 Burrower lane burst | keep pose `e19_mound_rise`; floor `B` | The script landed (`burrower.gd`; its `_pose` raises the marker lip). It is a damaging ground lunge along a lane, like E01. |
| E20 Drill crew breach | keep pose `e20_bit_lower`; floor `B` | The script landed. It is a damaging cave-in ring, like the other instant rings. Optional: rename the pose to `e20_bit_draw`, because `drill_crew.gd:106` draws the bit back during the wind-up instead of lowering it. |
| E21 Lamp swarm lure bloom | keep pose `e21_lamps_open`; floor `L` | The lure is a damage-free shove (`lamp_swarm.gd:6-10`). Haze would claim a hit, which ATTACK-READS rules out for non-damaging reads (E07 precedent). |
| E22 Line cutter throw | keep pose `e22_disc_cock`; floor `B` | It is a thrown disc with a landing ring and a sting (`line_cutter.gd:152`), like the E02 and E08 projectiles. |
| E23 Anchor crew winch | keep pose `e23_hook_swing`; floor `L` | It is a hold lane, like E11 winch drone and E06 hooker, both `L`. |
| E24 Kite drone dive | keep pose `e24_wings_fold`; floor `B` | It is a damaging dive onto a marked spot (`telegraph_record.gd` E24 entry). |
| W06 Mind Warden adaptation | keep color `Palette.SAND` | It is a neutral read with no hit (`telegraph_record.gd:108`; `fleet.gd:186`). HAZARD would take over an enemy warning, and BONE means a harmless lift. SAND is the neutral HUD colour. |
| B05 Ejection chase | keep color `Palette.BRASS` | ATTACK-READS asks for a non-hostile row with no hazard floor. BRASS is Brindle's own colour (`palette.gd:13-21`). |
| P11 Ram, crush and stomp | keep glyph `arrow`, color `Palette.SAND` | This is an all-pilot row, and P12 already closes the same way with fixed values. The hull colour is SAND, which fits contact damage. |
| P13 Pilot upgrade attacks | glyph `diamond`, color `Palette.SAND` (keep both); pose `p13_parent_pose`; warn `NONE`; release `NONE`; floor `L` | ATTACK-READS line 103 says upgrade procs reuse the parent pilot's pose and cue, instant procs get zero lead, and child blasts use the parent's floor once committed. The P13 row adds no cue of its own, so it uses NONE (the W07 precedent). `L` is the minimum floor, which keeps proc blasts from taking over an enemy warning. All values pass `attack_rows_test.gd` `_check_fields` and pose uniqueness. |

## Follow-ups found along the way

- When PR #19 lands, two new decals (`decal_curtain_call`, `decal_sable_spool`) have rows that name `*_mask.png` ids, but neither a registry row nor a manifest entry carries those ids. The cosmetic check will flag them. Add two registry rows (path `res://assets/cosmetics/decals/<id>_mask.png`, loader `src/core/cosmetics.gd`) when it merges.
- SPIL-9 is invisible until both sockets hold a module (`companion_body.gd:131` and `:205`, `visible = key != ""`). If the companion card picks "grow the one SPIL-9", COMPANION-GROWS can show `spil9.glb` alone and in single-module variants. Re-wire the chassis row then.

## Card for the project coordinator

**Should the asset-forge test pieces go into the game?**

- **Keep them out (recommended).** The crate, coin, crate icon and sand ground stay as proofs that the forge tool works. Eight placeholder rows clear and nothing on screen changes.
- **Find them a place.** A machine card places the forge crate as Spillway scatter and uses the coin as the shop's scrap icon. That is about one wave-19 dressing slot, and it mixes a second icon style into the HUD.

Recommendation: keep them out. The game already has its own crate models and a drawn scrap icon, so the forge pieces would only duplicate them in a different style.
