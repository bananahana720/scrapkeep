# park_flume dressing, wave 18 re-proof

Base: merge of the Dressing foundation aaeb5e10 (stage/alpha-w18 9cd6805e plus the `scatter_row` rule) into the flume branch, then on 2026-10-22 merges of stage/alpha-w18 (b0e64a40, which holds b22a2ca3 and #175) and the line_clear_m/telegraph foundation (07748516); the commit "Apply flume line_clear_m and telegraph rules" (8d109d1c27a262dc1ea58493a853088e44215ef8) follows them. Final merge (2026-10-22): stage/alpha-w18 f259e8cf421fc3c305b53ae104005dda40af9a41, then the accepted foundation e72fff7d96a88118e622f30658bcddb3105ae206 (gate round 7). The foundation commits after 07748516 change only the audit, static checks and `park_props_test`, so the pin is unchanged (plan check fingerprint 4063400762 equals the pin). The w18d audit below stands; no new audit and no `--open` windows were run.
Brief: `sketches/core-loop/design-v3/park/dressing/KITS.md` (lands in #269), flume section.
Method: automated headless Godot 4.7.2 on cloud llvmpipe (OpenGL compatibility proxy, not a frame-cost proof, not human feel).

## What and why

Flume is the canal park. The giant machines are the humans' utility fleet: construction, mining and manufacturing. Some are corrupted, some are loyal drones, and some are looping workers. The dressing reads as plush crews living among those working giants, so the scale contrast is the point: small camps, laundry, tea and tool pegs at the foot of big machinery.
This unit keeps the camps honest to their rules. Washlines (laundry) stay 30 m clear of ride lines so they do not read as grind or grapple lines (KITS.md brief). Props stay out of the `bend_relic_wakes` telegraph so a waking relic never lands on a camp.

## Plan check

`tools/park_props_plan.gd --map=park_flume --check`: `park_props_plan: park_flume 1113 instances (433 litter), 0 violations, fingerprint 4063400762`. Pin history: 875855731 (merge), 1477437796 (density fix), 2392297130 (30 m moves), 4063400762 (line_clear_m plus telegraph).
The expected `scatter_row` failure in `horseshoe_gorge` did not appear: no tall or hero instance lies inside that scatter row.

## Density fix (two windows, each filled)

The first w18 run failed two windows at 2 kinds (saltbush, bent_numbers): cannon 1200 m near (-9.6, 206) and tally 1050 m near (-16.6, 226). Each window has one sample, camera facing about +z. North of z 235 is blocked: `home_clear` (25 m of home wasteway_chasers) plus `line_clear` and `keepout` on siphon_runout_pier; a 5 m probe grid of single low pieces over x -60..40, z 190..280 found only a handful of legal cells. Added two single-piece spots on legal ground between the windows and the existing scrub: flume_s094 (mini_ties, timber_ties) at (-5, 225) and flume_s095 (mini_cup, tea_hearth) at (-5, 230). No line, landing or telegraph is touched (0 violations).

## Telegraph zones

`bend_relic_wakes` (machine_eruption, site `bend_overlook`, half 15 x 70, `hold_clear_m` 15) holds the zone. The rule is `park_props.gd` `check_one` ("telegraph": no prop inside the event's geometry grown by `hold_clear_m`; damage and telegraph share the committed geometry, DRESSING-KITS.md). Litter that fails is dropped by `expand`; authored spots fail the plan check.
- Inside before: 16 authored instances (flume_v72 9, flume_v80 2, flume_v82 5) plus 7 litter (440 to 433 litter instances).
- Spots moved: flume_v72 [150.0, -70.0] to [186.0, -70.0] (36 m); flume_v80 [130.0, 30.0] to [131.0, 33.9] (4 m); flume_v82 [120.0, -130.0] to [120.0, -162.0] (32 m). Each is the nearest of a 15-degree by 2 m ring search (to 60 m) whose every instance passes `check_one`.
- `near` labels: flume_v82 is now `bend_zip_pier_18` (30.1 m, grind_line). flume_v72 stays `bend_overlook` (still nearest, 37.4 m, bank). flume_v80 moved 4 m and is unchanged.
- Story check: v72 tie yard, v80 tie yard and v82 sluice shed remain beside the bend; v82's shed now stands 30 m from a zip pier, not at the water, which the kit story ("sluice shed with its wheel") does not name; flagged for World/Art.
- Plan check after: 0 violations.

## Tests (each run alone, GODOT_BIN 4.7.2, 2026-10-22)

park_props_test, park_park_flume_test, park_dressing_pin_test, pocket_line_clear_test, asset_registry_test and run_tier_test each exit 0 (the smoke runner prints verdicts, not assert counts, for passing runs). scatter_rows_test timed out at the runner's 180 s on a loaded box with every assert PASS, then exit 0 in 113.8 s on a rerun. `sketch:lint` 0 findings; `check:docs` pass (178 files, 0 failures). Registry fold unchanged.

## Audit (w18d, after line_clear_m and telegraph; default run, mid camera, step 25 m, 238 samples)

Method: `park_props_audit.gd` via the lock wrapper, OpenGL compatibility on cloud llvmpipe (not a frame-cost proof). Before values are the w18 run below. The brief's "density 2 of 10" figure does not match that run's summary (36 of 36 non-exempt); this run is compared with the summary.
- density: 36 of 45 windows pass, 9 exempt (arena 5, telegraph 4), `density_fail_windows` empty (before: 36 of 36, 9 exempt)
- props-only draw delta: max 46, median 24.5 (before 46, 24.0); draw calls max 429, median 308.0, p95 407.6
- bare share 21.8 percent (52 of 238; before 21.0), longest bare run 100 m, void poses 0
- Artifacts: `artifacts/local/dressing/flume/w18d/park_flume/` (local, not committed)

### Previous audit (w18, before this unit)

- props-only draw delta: max 46, median 24.0 (peak pose idx 149 at -48.7, -111.6)
- draw calls: max 467, median 317.5, p95 428.6 (llvmpipe, varies run to run); primitives max 811390 (median 658772)
- density: 36 of 36 non-exempt windows pass (1.0; 9 exempt: 5 arena, 4 telegraph); no failing windows
- bare share 21.0 percent (50 of 238), longest bare run 100 m; bare ground share 21.0, longest 100 m; void poses 0
- median dressing core in view within 60 m 11.0, distinct kinds within 120 m median 18

## 12-pose replay

Before and after both come from replays of the same poses (before = same tree with `props/park_flume.json` moved aside; after = replay with the file), so each pose is taken at the same moment. The earlier before frame at 235,123 caught a hazard telegraph and the post at 101,-204 was a timing difference; both are gone.
Pixel change (share of pixels with a channel difference over 12): 101,-204 3.75 (residual shadow and light, post present in both); 107,169 0.07; 137,213 1.92; 149,-49 0.66; 208,-104 2.01; 227,32 0.61; 235,123 0.02; 30,-298 0.66; 59,-20 0.46; 8,-468 0.00; 89,-213 0.59; 91,-232 0.18. Median 0.60.
The poses are the barest places, mostly in keepouts, so props rarely fill the frame there. Replay draws: after max 427, median 293.5; before max 441, median 288; replay props-only delta max 50, median 14.

Stills: `artifacts/local/dressing/flume/w18/{before,after}/park_flume/` (replays), `after-full/` (default run), sheet `before_after.png` (local, not committed).

## 30 m brief kinds

Kind `washline`. Brief line (lane KITS.md, flume): "At least 30 m from lines". Measure: edge-to-line, `Context.line_distance(centre)` minus the instance radius, as `check_one` uses for `line_clear`. Target 30.5 m or more. The spot schema has no per-spot override, so offenders were moved, not stripped.

| spot | edge_m before | edge_m after | old `at` | new `at` |
|---|---|---|---|---|
| flume_v10 | 21.82 | 53.53 | -340.0, -570.0 | -348.3, -539.1 |
| flume_v42 | 27.57 | 31.14 | -130.0, -440.0 | -126.0, -440.0 |
| flume_v65 | 28.49 | 31.50 | 10.0, -120.0 | 9.0, -123.9 |
| flume_v69 | 26.52 | 31.70 | 50.0, -30.0 | 50.0, -24.0 |
| flume_v96 | 29.42 | 30.86 | -50.0, 340.0 | -48.1, 339.5 |
| flume_v99 | 22.43 | 32.13 | -120.0, 360.0 | -130.0, 360.0 |
| flume_v105 | 17.90 | 38.87 | 120.0, 300.0 | 164.5, 255.5 |
| flume_v47_r8_4 | 28.58 | 32.24 | -244.0, -103.1 | -248.0, -103.1 |

The other 9 instances already passed and are unchanged. flume_v10 (32 m move) and flume_v105 (63 m move; nothing legal within 45 m) changed `near` to the nearest park row by centre: weir_trestles and bluff_ride_pier_9. Pin 1477437796 to 2392297130. Plan check: 0 violations. Probe: under30_edge=0.

The `washline` kind now carries `line_clear_m: 30` in `tools/blender/park/props/flume.py` (manifest `"line_clear_m": 30.0`), and `park_props.gd` `check_one` takes the larger of the tier and the kind value, so the plan check enforces it. The 8 moves above stay valid under it.

Do the moved spots' stories still hold? Nearest feature is from `park_flume.json` park_rows (ground rows excluded), by centre:
- flume_v10 (32 m move, washday "by the trestles"): nearest is weir_trestles (anchor_field), 23.1 m. Holds, the label is now `weir_trestles`.
- flume_v105 (63 m move, camp_corner): nearest is bluff_ride_pier_9 (grind_line), 16.7 m, then bluff_ride_pier_12. A crew camp in the lee of a pier. Holds, the label is now `bluff_ride_pier_9`; a camp corner has no row-specific story.
- The other six moved 1 to 10 m; their nearest rows and stories are unchanged.

## ART-MISTAKES entries checked

`project-guide/handoff/ART-MISTAKES.md`, read before the unit:
- 2026-10-21 World #242 lane width ("read the function before describing a flag"): I read `park_props.gd` `expand()` and `check_one` before saying the spot schema has no per-spot override, and read the telegraph rule before describing it.
- 2026-10-21 Modeling M1 anchor gap tool (a run line copied without running it): the Blender rebuild command was run, exit 0, and the diff confirmed only the manifest `line_clear_m` line changed.
- 2026-10-21 Animation #261 receipt (SHAs typed from memory): SHAs in this unit's report are pasted from `git rev-parse`.
- 2026-10-21 Animation A1 (pkill by text pattern): no process was killed by pattern.

## Reference boards

Rulings 6330671507 (reference before making) and 6331210075 (board grounding). Boards settle look only, not mechanics, scale numbers or collision. I opened each board image before citing it.

Boards (under `docs/art/reference/`):
- `spillway/spillway-props-moodboard.jpg`, `spillway/spillway-landmarks-flume-carry.jpg`, `spillway/spillway-landmarks-moodboard.jpg`;
- `style/style-palette-moodboard.jpg`, `style/style-materials-moodboard.jpg`, `style/style-shape-moodboard.jpg`;
- `pilots/pilots-balls-heft-moodboard.jpg` (scale, relative only).

**Palette roles.** The Spillway props board sets sandstone, oxide, charcoal, petrol, bone and copper; the carry board shows timber trestles, sage shrubs and sandstone ground. The kit palette (`C` in `tools/blender/park/props/kit.py` lines 59-67, used by `flume.py`) sits in the Terrain and Harmless roles: sandstone, timber, concrete and canvas (Drying alcove cloth, Survey bag); charcoal/iron/cable for the Seals and hoses blacks; bone; `verdigris` (5f8a7c, 4 uses in `flume.py`) for the petrol enamel of the sluice and pump panels. Kit colours outside the board's 13 chips: the concrete greys, timber browns, canvas tints, `rust`, and the shrub greens `leaf`, `leaf_dark`, `dry_grass`. The boards show all of them as materials and vegetation (trestles, stone, shrubs, Oxide rust), not as roles, so I read them as inside the board's world. `kit.py` line 69 bans HAZARD, ANCIENT and MINT hexes plus near colours.

**Shape language.** Broad worn, soft toy shapes: `flume.py` builds with `style="round"` and `hard_smooth` blobs, low sleepers (line 61, "never a crate"), draped shirts, and rounded shed and hearth masses, like the Pump repair and Wheelhouse panels. Silhouettes stay low and wide beside the tall machinery.

**Materials.** The kit uses no brass anywhere: no `d9b44a`, `brass`, amber or copper hex appears in `flume.py` and none in the `C` table. Fittings are iron, iron_light and rust (steel and oxide), per the Materials board's rule that brass is Fleet ownership.

**Scale to the pilot ball.** The ball radius is 1.0 m, so diameter 2.0 m (`src/movement/tuning.gd:95`; `anchor_fit.json` `ball_radius_m` 1.0). Manifest kit heights against it, relative only: tea_hearth 0.8 (0.4 ball), bent_numbers 0.9 to 1.0, saltbush 0.8 to 1.0, washline 1.46, tool_peg 1.5 to 1.6, bunk_cots 1.0 to 1.95 (under one ball), skiff_on_blocks 3.1 to 3.4, boom_crane_wreck 4.8 and sluice_shed 5.6 (about 2.4 and 2.8 balls). Camp props stay under or near one ball and the sheds sit at a few balls: the plush-crew-among-giants contrast. No new metres asserted.

**Avoid list** (checked against the kit and the manifest):
- no emission: pass. `kit.py` line 567 asserts no `emissiveFactor` in any GLB, and the flume manifest has 0 `emissive` entries;
- no hazard stripes or coral: pass. No stripe code in `flume.py`; `kit.py` bans ff5a3c and near colours and hazard-like hues (line 105);
- no cache-shaped containers: pass. Sleepers are "never a crate" (line 61); the only box-like props are the sheds;
- no taut or decorative grapple cables: pass with a note. The washline is a draped slack line (line 449, "never taut"). The boom_crane_wreck chains (lines 152 to 158) are heaped slack chain with sag 0.2 to 0.7, a wreck's rigging, not a line; variant a at 0.2 is the least slack, so review should look at it;
- no fake ride surfaces: pass. All props are low clutter or sheds; `check_one` keeps them off ride rows;
- no glowing lamps: pass. The crane's lantern (lines 159 to 162) is unlit chalk white `e6e3d6`, with no emission;
- no ancient-green or uranium-green: pass. No 9dff3c or near colour (`kit.py` line 70); the leaf greens are olive (6f7f4a, 4f5e38), not the board's bright Ancient green;
- Highdraft items: not applicable to flume.

**GROUNDING rows read** (`GROUNDING.md` (main cb534a2d), scratchpad copy):
- line 159 (carry board): not a prop row; the unit keeps props off the carry and ride rows through `check_one`. No Conflict.
- line 161 (Canal country and Surge tower): destination read stays the landmark; props stay low. No Conflict.
- line 167 (props: no emission, stripes, cache silhouettes, taut cables, fake ride surfaces; short clothesline domestic only): the avoid list above; the washline is the domestic line.
- line 172 (ancient light only on the distant beacon): no kit prop carries ancient light.
- line 173 (intakes, bunk ledges and siphon pieces as route structures): not changed; the camps sit beside them.
- No Conflict row in 159, 161, 167, 172 or 173: nothing marked "not copied".

## Board drift (for review)

None found that blocks. Two things for the reviewer: boom_crane_wreck variant a chain sag (0.2) is the nearest to a taut read, and the concrete, timber and canvas neutrals are outside the 13 palette chips though present in the boards' materials. The kit is not changed in this unit.
