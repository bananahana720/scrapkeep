# Islands park dressing note (Dressing lane)

Base line: branch head after merging `origin/stage/alpha-w18` (f259e8cf421fc3c305b53ae104005dda40af9a41, merge 9577225bbf5bb2ceeee1a76997a6b5a8cfc18407) and the foundation `claude/zealous-franklin-ed0sxr-lineclear` (e72fff7d96a88118e622f30658bcddb3105ae206, merge a4b4fc5b08b315b21531766569b64fc3ae33ce1c); then the foundation again at be6189ec5f5c8eb33591c33ecc76d72e56828394 (e72fff7d plus the stage f259e8cf merge; merge 628de2e1c3167fe83d2dbb843114b44f1f92a23b); then `origin/stage/alpha-w18` again at 3c83375501aa98543b8785e3129a0cd028e0b1e8 (merge 90cd90d031db3c604d8b1d1d118abc15ab7b52fc); previous head b117ddd0.
Plan check: `park_props_plan.gd --map=park_islands --check` reports 430 instances (50 litter), 0 violations, fingerprint 2348699063 = pin (w18g re-pin from 3322127868, which was the w18f pin after f450 and f600; history: 2014119072, 3660265306, 3322127868; the w18g prune removed the ten-spot even row w400 to w408 and w901, 480 to 430 instances).

Vignette file: `src/world/park/props/park_islands.json` (71 spots, 430 instances, 50 of them litter, pin 2348699063). Kit: `assets/models/park/props/islands/manifest.json`. Rules: `design-v3/park/DRESSING-KITS.md` (Readability rules, line 45 colours, lines 46 to 54 shapes to avoid) and the dressing brief `design-v3/park/dressing/KITS.md` (lands in #269; a stub here). Audit: `tools/park_props_audit.gd` via the lock wrapper; the current numbers are the "Audit (w18g)" section below (tree 1411f07f plus the w18g prune). Older numbers are labelled by run (7e05da67, w18e, w18f); the `stage/alpha-w18 8ee9e2c1` audit that this line used to cite is the older record.

## What and why (lore, #241 6329943362)

The giant machines are the humans' utility fleet: construction, mining and manufacturing. Some are corrupted, some are loyal drones and some are looping workers. The crew sites here (the net crews' mending yards and balloon landings, the fire lookout, the tram halt) read as plush crews living among working giants, so the scale contrast with the park's landforms and machines is the point. Nothing in this file is a machine and nothing is armed. The giant machines are never war machines.

## What each vignette shows and why it is there

Every template carries its `story` line in the file. Moments, by group:

- **Heroes (5 spots).** `lookout_post` x2 (a fire crew's stilted cab by the stair, the dam-era lookout story), `balloon_landing` and `balloon_graveyard` (the net crews' balloon that came down, patched in two stitch hands), `tram_halt` (the mining tram cabin set down on blocks, never hung). Hero heights 2.2 to 5.2 m come from the manifest (lookout_hut 5.18/5.17/3.99 m, balloon_basket_wreck 2.20/3.18/3.10 m, tram_car_parked 4.40/4.38/4.42 m). The hero spots sit at least 80 m from World's `fire_lookout` row at (150, -700), a distance I chose as 4x the 20 m TALL line clearance; the nearest hero is far beyond it.
- **Mids (11 spots).** `net_crew_corner`, `patchwork_rock`, `stair_marker`, `pine_ledge`, `ore_spill` (net menders' yard, sewing rock, hikers' numbered stones, relict pines, tipped ore bin) and one `mooring_spares` (winch drum, brass tag), which is only placed on a cell whose nearest row's society is `fleet` (mooring_pad_ramp). BRASS stays Fleet-only (DRESSING-KITS.md line 45).
- **Low story groups (55 spots).** `net_mending`, `chart_stones`, `dropped_bolt`, `rope_basket_rest`, `tuft_cairn`, `net_drying`, plus the earlier `stone_nook`, `rope_heap`, `cobble_pair`, `net_scrap`, `stool_rest`, `pine_cairn`. These are the Dressing-lane density answer: 3 or more distinct kinds per 150 m window of ride line (AMBITION-BRIEF, DRESSING-KITS "Density bar"). Each group has one moment (a mending spot, a chart-stone curve, a dropped bolt of cloth), with open ground between groups.
- Scales in the new low templates are 0.85 to 1.1, chosen so the scaled height is at most 1.0 m from manifest heights (net_bundle 0.60 to 0.85, mender_stool b/c 0.83/0.82, rope_basket a 0.87, patch_bolt 0.50 to 0.64, stair_stones 0.18 to 0.49, stone_scatter 0.36 to 0.85, grass_tufts a/b 0.86/0.61). `LOW_GROUND_MAX_M` is 1.0 m (park_props.gd).

## Why they read without blocking a line, a lander or a telegraph

- No pickup, crate, ramp, gate, rail, creature or hanging machine shape (DRESSING-KITS.md "Shapes to avoid", lines 46 to 54); rope coils lie flat; the tram is on blocks.
- The validator gives the placement: LOW 6 m, MID 10 m, TALL or hero 20 m from every `lines.json` leg, route lanes for TALL, 25 m from homes and camps, slope 25 degrees, seat 0.15 m. `park_props_plan.gd --check` reports 0 violations.
- The kicker lip and run-out capsules are untouched. They are the landing zones, so they are the named step-lip keepout (coordinator ruling): the 9 failing windows with no valid cell are all inside it.
- Colours: rope, wicker, patch cloth, sandstone, timber and slickrock were desaturated and darkened in `islands.py` after the first colour stills showed orange flecks under the low sun (stills #189, #210 in `before_after_even.png`). No hazard, mint or ancient hue; no emissive; no stripes.

## Ground surfaces (ground_rows and low_ground_rows)

- `low_ground_rows` is `lookout_mesa`, `twin_fins` (both sky_island at least 60 m on both axes, eligible per `file_errors`).
- `ground_rows` lists the six island tops plus every `*_step_N` drop row: lookout_step_1..4, run_step_1..5, saddle_step_1,2, fan_step_1..6, landing_step_1, anvil_step_1..4, carve_step_1..7. Each is a terrace tread, 32 to 50 m deep with a 2 to 4 m step-down between kicker lips (row sizes in `park_islands.json`); the tiers and kicker capsules govern them (coordinator ruling, 20 Oct). `anvil_face` (2 m) is never listed.
- World's #243 will turn `slickrock_run`, `fan_band`, `net_carve` and `isle_apron` into stamped ground. It is not in the stage yet, so placement there needs a re-check when it lands. I did not edit `park_islands.json`, `scatter.gd` or `park_map.gd`.
- `scatter_row` (new in the foundation) binds tall and hero props in scatter-dressed rows; the plan check reports none for islands, and `scatter_rows_test` lists no on-route scatter rows for park_islands.

## Telegraph zones

Rule: `park_props.gd` `check_one` rule `telegraph` keeps props out of each event's own geometry grown by `hold_clear_m`; DRESSING-KITS.md "Density bar" lists the same exempt zone ("an `event_rows` site footprint grown by `hold_clear_m`"). Authored spots that fail the plan check; litter that fails is dropped by `_litter`.
- `isle_shed` (west_wing grown 30 m): 68 instances inside in total (37 mid, 21 low, 10 hero instances, counted as telegraph violations) across 10 spots, plus litter. Spots moved to the nearest legal point found by a ring search around the old point (step 5 m, 24 angles, up to 150 m): h300 lookout_post (-255,100) to (-310,100), 55 m; m310 mooring_spares (-120,85) to (-109.4,74.4), 15 m; w327 rope_heap (-145,80) to (-116,87.8), 30 m; w329 net_scrap (-130,105) to (-115.5,101.1), 15 m; w332 dropped_bolt (-250,215) to (-327.8,137.2), 110 m (near label updated). Not placeable within 150 m, so removed: m307 stair_marker (-250,295), m309 ore_spill (-150,100), m312 patchwork_rock (-175,295), m313 stair_marker (-185,215), w012 net_drying (-180,375). One replacement mid (stair_marker at (-80,70), m500) was added from the valid cell list.
- `fin_rim_collapse` (twin_fins grown 25 m): w353 rope_basket_rest (55,-365) to (52.5,-369.3), 5 m.
- `mooring_burner_blow`, `mooring_dropship`, `lens_rocks_wake`: no instance inside.
- Litter: 62 before, 50 after, the 12 dropped by the telegraph rule.
- twin_fins stays a `low_ground_rows` row, but the 25 m hold zone leaves it little usable ground.

## 30 m brief kinds

None for islands (the brief names none), so no kind carries `line_clear_m` here.

## ART-MISTAKES entries checked (project-guide/handoff/ART-MISTAKES.md, read after the stage merge)

- Also checked this round: 2026-10-21 Animation A4 `seam_untested` (the audit's `density_open_checked` is compared to the window count, not just a pass line); 2026-10-21 Coordinator #231/#234 (merged the head the coordinator named, not an older receipt).

- 2026-10-21 World #242 "Called the LINE flag the actual ride line": I read `check_one` for the telegraph rule instead of inferring it from the name.
- 2026-10-21 Modeling M1 "ran command line copied from siblings": every command here was run as written (plan check, audits, tests).
- 2026-10-21 Coordinator #222 "measure at the moment it applies": the window probes use the same `check_one` the plan check uses, not a nearby proxy.

## What I checked

- Plan check: 0 violations, fingerprint 2348699063 equals the pin (w18g; the 2014119072 that this line once recorded is an old record).
- Tests (SMOKE_SLOTS=2): park_props_test, park_park_islands_test, park_dressing_pin_test, pocket_line_clear_test, set_dressing_test, asset_registry_test, scatter_rows_test all PASS (scatter_rows_test failed once, 1 of 90 checks, in the first batch run while the box was shared, then passed 90 of 90 twice on rerun; cause not identified).
- Audit of the current head: see "Audit (w18g)" below. The next two bullets are the older 7e05da67 audit (previous run, superseded).
- Audit, full run (7e05da67): 48 windows, 16 exempt (arena 10, telegraph 6), 21 pass, 11 fail (share 0.656; the pass count was 13 before this pass); draw delta median 3, max 64 (bar 120); primitives median 516,739, max 798,889; void poses 0; bare share 72.0%.
- Failing windows (centre; kinds in view): floor 150 (6, -559; 0), floor 750 (-282, -212; 0), floor 1350 (93, 205; 1), floor 1500 (32, 334; 1), rivet 150 (157, -568; 0), sable 300 (-100, -499; 0), sable 600 (153, -318; 2), sable 750 (262, -215; 0), sable 900 (229, -93; 0), tarn 150 (-130, -570; 0), tarn 300 (-60, -500; 0). Probe of a 4 m radius, 1.0 m prop on a 5 m grid within 70 m of each centre: 0 valid cells for 9 windows (kicker run-out 120 to 587 of about 613 cells each; kicker ramp, line_clear and ground_row also), and for floor 1500 and sable 600 the valid cells (41 and 46) lie 43 m or more from the line, mostly beyond the 40 m band; one low spot was added at (170, -370) for sable 600, which still shows 2 kinds.
- Stills: `artifacts/local/dressing/islands/before_after.png` and `before_after_even.png` (same-tree before frames with the vignette file moved aside, via `before.sh`). Pixel change per pose (pixels differing by more than 24 grey levels): 0.04 to 1.06 percent; this is small because low props are small in the frame and most poses sit in keepouts.

## Plant litter height

The litter schema has no scale or variant cap (scale 0.9 to 1.15 in `_litter`, grass_tufts c 1.27 m, pine_sapling a/b 1.11, 1.41 m, manzanita 1.39 to 1.47 m). But the `low_ground` rule drops any litter taller than 1.0 m in a listed low-ground row, so plant litter over 1.0 m cannot stand in `lookout_mesa` or `twin_fins`. Confirmed on the current file: 6 litter items stand inside those two rows, none over 1.0 m (maximum 0.89 m); 8 litter items over 1.0 m exist elsewhere, governed by the line tiers.

## Not met and named fails

Status after the w18g audit: no density window fails (see "Audit (w18g)"; w18f gave the same result with 10 more spots). The first two bullets and the test bullet below are the 7e05da67 record and are superseded; the run-out bullet is now the `--open` list.

- Sable 600 (153,-318): 9 more low spots (w400 to w408, plus w901) were once added in the 43 to 60 m band at (165..190, -378..-366). Removed in w18g: they were a zigzag line of 4 to 12 m spacing, all at yaw 137, reading as scatter (DECISIONS section 8, "vignettes, not scatter"), and f600 is what fills that window.
- Floor 1500 (32,334) has 0 legal cells within 80 m of its centre after the telegraph rule, so no fill is possible there.
- Windows with a kicker run-out within 40 m of the window centre (distance from the run-out capsule surface, from `park_map.kickers`, run-out capsule as in `kicker_keepouts`): floor 150 (6.3,-559) run_step_lip_1 (-5.0 m); floor 750 (-281.9,-211.6) fan_step_lip_3 (-8.4); floor 1350 (93,204.6) carve_step_lip_1 (-1.4); floor 1500 (32.3,333.5) carve_step_lip_5 (-7.5); rivet 150 (156.5,-567.9) lookout_lip (-6.3); sable 300 (-100.4,-499.1) run_step_lip_2 (-7.1); sable 750 (262.4,-215.2) fan_step_lip_3 (-4.8); sable 900 (228.6,-92.5) fan_step_lip_6 (-7.5); tarn 150 (-130.2,-570.2) lookout_lip (-10.2); tarn 300 (-59.5,-499.5) run_step_lip_2 (-7.5). Negative means the centre is inside the capsule. That 7e05da67 audit did not pass `--open`; superseded by the `--open` sections below.
- Tests: run_tier_test failed 20 of 192 checks, every failure a runtime-child timeout (`exit=-1 timeout=true`) with the box at load average 22; scatter_rows_test timed out twice for the same reason (it passed 90 of 90 on the previous head). The other tests passed (counts in the hand-back).

## Audit (w18f, --open, previous run), ruling 6329579296

Ruling 6329579296: an `--open` window carries a reason the audit checks. `runout:<kicker>` needs a kicker run-out within 40 m of the window centre, and the audit fails an `--open` window whose reason does not check out.

Pre-audit (`artifacts/local/w18e-pre`, no `--open`): 48 windows, 16 exempt (arena 10, telegraph 6), 20 pass, 12 fail. Ten of the failures are the windows below, centres matching to 0.1 m. Two more, kest 450 (-47.9, -366.1) and sable 600 (153.0, -317.8), had 2 kinds each and no run-out reason, so they were not `--open`ed; they are filled (next section).

`--open=x:z:10:runout:<kicker>`, one arg per window (the audit's arg loop does `open_spaces.append_array`):

| Window | Centre (x, z) | Kicker |
|---|---|---|
| floor 150 | 6.3, -559.0 | run_step_lip_1 |
| floor 750 | -281.9, -211.6 | fan_step_lip_3 |
| floor 1350 | 93.0, 204.6 | carve_step_lip_1 |
| floor 1500 | 32.3, 333.5 | carve_step_lip_5 |
| rivet 150 | 156.5, -567.9 | lookout_lip |
| sable 300 | -100.4, -499.1 | run_step_lip_2 |
| sable 750 | 262.4, -215.2 | fan_step_lip_3 |
| sable 900 | 228.6, -92.5 | fan_step_lip_6 |
| tarn 150 | -130.2, -570.2 | lookout_lip |
| tarn 300 | -59.5, -499.5 | run_step_lip_2 |

Result of the previous audit (w18f; `artifacts/local/w18f`, superseded by w18g; after the recolour and the two fill spots): 48 windows, exempt 26 (arena 10, `open:runout` 10, telegraph 6), pass 22, fail 0, density share 1.0; `density_open_checked` 10, `density_open_rejected` empty; void poses 0; props-only draw delta max 66, median 3.5 (bar 120); bare share 73.2 percent. The earlier w18e audit (before the fill) had 20 pass and 2 fail.

### The two filled windows (ruling #241 6332450092 not needed)

Coordinator ruling 6332450092 says a window that cannot be filled stays a documented density fail with no `--open`. Neither did: both filled.
- kest 450 (-47.9, -366.1): 2 kinds before (grass_tufts, stone_scatter). Probed with `fill_probe.gd` (a throwaway script that applies the audit's own camera, `camera_for` and `cell_visible`, 2.5 m grid, mid camera, within 60 m, over the window's 3 poses, and expands a whole template through `validate`): 29 cells where a whole `net_mending` passes, 41 for `rope_heap`, 35 for `net_scrap` and `net_drying`, 13 for `chart_stones`. Spot `f450` (`net_mending`, at (-98.8, -326.2), 22.5 m from the nearest pose).
- sable 600 (153.0, -317.8): 2 kinds before (stone_scatter, patch_bolt). 48 cells for `net_mending`, 60 for `net_scrap`, 55 for `rope_heap`, 30 for `stool_rest`. Spot `f600` (`net_mending`, at (171.2, -326.2), 20 m from the nearest pose).
- After: both windows show 6 kinds (grass_tufts, mender_stool, net_bundle, patch_bolt, rope_basket, stone_scatter) in `artifacts/local/w18f/park_islands/samples.json`. Plan check 0 violations, so every keepout, line-clear, slope and seat rule holds at both spots. Re-pin at the time: 3660265306 to 3322127868 (470 to 480 instances); w18g then re-pinned to 2348699063 (430).

## Recolour to the Highdraft props board (this round)

Reference: `docs/art/reference/highdraft/highdraft-props-moodboard.jpg`. I read the swatch strip: sandstone c6a274, oxide 9b513a, charcoal 242a28, petrol 365754, bone d2c5a5, copper b77843. Colour-only change; `kit.py` untouched. Constants added in `islands.py`: PETROL 365754 (line 41), BONE d2c5a5 (42), COPPER b77843 (43); OXIDE 9b513a (39) and BRASS d9b44a (40) existed.

Machine part to board panel (lines from grep of the final recipe):
- `tram_car_parked` (def line 265): body and cab planks PETROL (269), roof boards alternate PETROL and TIMBER_D (306), as the Heat shields panel's petrol enamel; corner straps OXIDE (319), the panel's oxide wear as bands; two short bone plates per side BONE (321), as the Closed furnace latch plate; copper fittings COPPER on the hanger stub (311) and the doorstep pail (315), as the Closed furnace pipework. Frame deck, hanger box and axle brackets are `C["charcoal"]`.
- `ore_trolley` (434): tub PETROL (438), as the Braked drum housing; rim BONE (441, and 457 tipped variant), oxide axle OXIDE (448), two copper hubs COPPER (447). Wheels TIMBER_D, or charcoal for variant c.
- `winch_drum` (488): drum and one housing end PETROL (493, 492), the other housing end BONE (492, the one bone panel), drum rims OXIDE (495), copper crank fittings COPPER (508, 509), the single BRASS tag kept (507, coordinator allows one Fleet requisition tag per site). Base slab charcoal.
- Copper counts: tram 2, ore_trolley 2, winch_drum 2 (kit WARN only, as expected). Timber, rope, wicker and plants are as before.
- Machines still using non-board colours, from grep of `C["iron`, `C["iron_light`, `C["rust`, `C["concrete`: none in the three machine kinds' bodies. Remaining uses are `lookout_hut` hardware (144, 148; a building, not a machine), the ore and ground rocks (337, 444), the winch rope (503), `rope_basket` (524, 525, 527), `patch_bolt` (603, 604, 606) and stair-stone chips (476).
- KIT_BUILT before (`artifacts/local/w18f/base.log`, built from the unchanged recipe) and after (`after.log`) are identical for all 8 variants: tram a `[10228, 5114, 1534]` radius 3.82 height 4.40, b `[11580, 5790, 1736]` 3.81 4.38, c `[13316, 6658, 1996]` 4.35 4.42; ore a `[2572, 1286, 386]` 1.16 1.33, b `[2932, 1466, 440]` 1.45 1.31, c `[2804, 1402, 420]` 1.53 1.57; winch a `[2528, 1264, 376]` 1.53 1.30, b `[1896, 948, 283]` 1.34 1.30.
- Previews: `sketches/core-loop/artifacts/local/dressing/islands/w18f/` (contact sheet and per-variant stills), opened and compared with the props board by eye: petrol bodies, bone and oxide accents and small copper fittings read as the board's machines; they are chunkier and flatter than the painted board (no chipped paint texture; one vertex colour material only).

## Audit (w18g)

Run: `artifacts/local/w18g` on the tree at 1411f07f plus the w18g prune (spots w400 to w408 and w901 removed; plan check 0 violations, 430 instances, pin 2348699063), the same ten `--open=x:z:10:runout:<kicker>` args as the w18f table above.

Ruling 6329579296: an `--open` window carries a reason the audit checks. `runout:<kicker>` needs a kicker run-out within 40 m of the window centre, and the audit fails an `--open` window whose reason does not check out.

- 48 windows; exempt 26 (arena 10, `open:runout` 10, telegraph 6); pass 22; fail 0; density share 1.0.
- `density_open_checked` 10; `density_open_rejected` empty.
- Props-only draw delta max 63, median 2.5 (bar 120); primitives median 515,597, max 797,289.
- Bare share 73.2 percent; void poses 0.
- No window newly failed from the prune, so no spot was restored from the row; sable 600 still passes on f600 and the earlier spots.

## Reference boards (rulings 6330671507, 6331210075)

Boards read (each opened and looked at): `docs/art/reference/highdraft/highdraft-props-moodboard.jpg`, `highdraft-crew-moodboard.jpg`, `highdraft-landmark-hanging-isle.jpg`, `docs/art/reference/era/era-space-ground-ends-moodboard.jpg`, `style/style-palette-moodboard.jpg`, `style-materials-moodboard.jpg`, `style-shape-moodboard.jpg`, `pilots/pilots-balls-heft-moodboard.jpg`. Boards settle look only.

Board colours. Props board swatch strip: sandstone c6a274, oxide 9b513a, charcoal 242a28, petrol 365754, bone d2c5a5, copper b77843. Crew board adds brass d9b44a (Fleet plate on the mooring winch) and life 8f84b3. The props board paints machine bodies (braked drum, heat shields, closed furnace door) as petrol enamel with bone panels, copper pipes and clamps, charcoal housings and oxide wear; its README says "broad material differences and contact wear" and "props remain matte".

**Palette roles.** Machine bodies now use the board's petrol, bone, oxide and copper (recolour section above). Bone and charcoal also appear as `C.bone`, `C.charcoal` and `C.cable`. Sandstone is a drift, not a match (see Board drift item 5). Non-machine kinds (rope, timber, wicker, plants, slickrock) keep their desaturated colours; see drift.

**Shape language.** Broad wear and soft toy shapes: low-poly lumps rounded by subsurf (`blob`, styles "soft" and "round"), flat-lying coils, a tub bin on stub axles, a three-legged stool, a tram on blocks. Silhouettes are low and wide like the board's benches and stools.

**Materials.** Brass: one BRASS tag on `winch_drum` (line 507) and nothing else (grep of `BRASS` in islands.py: definition 40 and use 507). It matches the crew board's Fleet plate and the coordinator's one-tag-per-site allowance. Fittings elsewhere are COPPER.

**Scale to the pilot ball.** Ball diameter is 2.0 m: `Tuning.RADIUS` is 1.0 (`src/movement/tuning.gd:95`). Ratios are manifest height / 2.0, relative only:
- Heroes: lookout_hut a 5.176/2.0=2.588, b 5.166/2.0=2.583, c 3.994/2.0=1.997; balloon_basket_wreck a 2.197/2.0=1.099, b 3.177/2.0=1.589, c 3.1/2.0=1.550; tram_car_parked a 4.398/2.0=2.199, b 4.377/2.0=2.188, c 4.424/2.0=2.212.
- Props: net_bundle 0.605/2.0=0.302 (a, b), c 0.849/2.0=0.424; mender_stool a 0.966/2.0=0.483, b 0.826/2.0=0.413, c 0.823/2.0=0.411; chart_post a 1.361/2.0=0.680, b 1.318/2.0=0.659, c 0.835/2.0=0.417; ore_trolley a 1.331/2.0=0.665, b 1.309/2.0=0.654, c 1.571/2.0=0.785; stair_stones a 0.183/2.0=0.091, b 0.22/2.0=0.110, c 0.494/2.0=0.247; winch_drum 1.304/2.0=0.652 (a, b); rope_basket a 0.869/2.0=0.434, b 1.001/2.0=0.500, c 0.898/2.0=0.449; pine_sapling a 1.112/2.0=0.556, b 1.406/2.0=0.703, c 0.822/2.0=0.411; manzanita a 1.471/2.0=0.736, b 1.397/2.0=0.699, c 1.388/2.0=0.694; grass_tufts a 0.861/2.0=0.430, b 0.611/2.0=0.305, c 1.272/2.0=0.636; patch_bolt a 0.637/2.0=0.319, b 0.585/2.0=0.292, c 0.502/2.0=0.251; stone_scatter a 0.677/2.0=0.339, b 0.358/2.0=0.179, c 0.851/2.0=0.425.

### Avoid list, per item (greps of `tools/blender/park/props/islands.py`, `kit.py` and `park_islands.json` after the final edit)

- No emission: grep `emissive` in islands.py hits only the comment at line 522 ("no emissive"); kit.py line 567 asserts every exported material has no `emissiveFactor`, and the kit export ran clean.
- No hazard stripes or coral: grep `stripe` and `coral` in islands.py: no hits. `hazard` hits only the comment at line 22. `ff5a3c` (hazard hex) no hits; kit.py line 69 BANNED holds it.
- No cache-shaped containers: grep `crate`: only the comment at line 435 ("not a crate"); the ore bin is a flared cylinder (line 438).
- No taut or decorative grapple cables: grep `cable` hits line 248 (stitch-tick colour `C["cable"]` on the balloon patch), 602 (comment on cable-dark thread); the kit has no cable geometry.
- No fake ride surfaces: grep `ramp` no hits; `rail` hits only the story at line 433 ("no rails anywhere").
- No glowing lamps: `lantern` hits lines 312 (unlit pail comment), 514 (story, unlit basket).
- No ancient-green or uranium-green: grep `9dff3c` and `8bf0d3` in islands.py no hits (both in kit.py BANNED, line 69).
- Closed furnace mouths only: grep `furnace` in islands.py no hits; `furnace` count in `park_islands.json` 0.
- Slack nets distinct from the netcaster silhouette: grep `mast` in islands.py no hits; `net_bundle` is at most 0.849 m high (ratio above).

### GROUNDING rows read (GROUNDING.md (main cb534a2d))

- Line 230 (hanging isle, tether, net bowl): look only; the kit places no isle or tether, World owns them. Followed by adding nothing near them.
- Line 234 (Conflict: closed furnace, heat shields, amber glow): not copied. No furnace, heat shield or amber emission in the kit or the file.
- Line 235 (net weavers): the kit has no weaver models; net_crew_corner and net_mending are the work spots only.
- Line 236 (Fleet mooring crew, Open question 2): no mooring crew; the one Fleet prop is winch_drum, a vacant winch, which fits the "vacant equipment" alternative.
- Line 237 (mended nets, slack bundles, mugs): followed by net_bundle, patch_bolt and mender_stool (a mug on the seat); rope fibres kept chunky.
- Line 238 (slack bundles distinct from netcaster): followed; see the avoid list.
- Line 239 (net-repair alcoves in the lee): spots are placed by the validator, clear of lines; no alcove geometry.
- Line 240 (rope-net bridge to the isle): not built; World's row.
- Line 241 (braked drum, heat exchanger, looping workers): winch_drum is a static drum (alpha keeps drums static).
- Line 419 (fallen satellite swarm as inert scrap field): the kit has no satellite shingles; nothing reads as a pickup. Not copied.

### Board drift (for review)

Recoloured this round: machine bodies (tram_car_parked, ore_trolley, winch_drum) now carry petrol, bone, oxide and copper. Still off the board's swatches, not changed:
1. Desaturated browns and greys with no swatch: ROPE, ROPE_D, WICKER, TIMBER, TIMBER_D, BARK, SLICK, SLICK_D, PATCH_B (islands.py lines 23 to 33 and 34 to 35) and `C.timber_grey`, used in lookout_hut, balloon_basket_wreck, tram_car_parked interior and ground, net_bundle, mender_stool, chart_post, rope_basket, winch_drum rope, patch_bolt, stair_stones, stone_scatter, pine_sapling, manzanita. Kept desaturated on purpose after the low sun showed orange flecks (stills #189, #210); the board's rope is bone-pale. Timber, rope, wicker and plants stay as they are under the coordinator's ruling.
2. Neutral greys `C.iron`, `C.iron_light`, `C.concrete`, `C.concrete_dark`: lookout_hut hardware (144, 148), the rock mixes (337, 444), stair-stone chips (476), rope_basket (524, 525, 527), patch_bolt tin (603, 604). Board metal is petrol, charcoal or copper.
3. Greens PINE, PINE_D, `C.leaf`, `C.leaf_dark`, `C.dry_grass`: foliage in lookout_hut, balloon_basket_wreck, pine_sapling, manzanita, grass_tufts, net_bundle, mender_stool, chart_post, ore_trolley, rope_basket, tram_car_parked: shown in the board's images but with no swatch.
4. Chunkier than the board: one vertex-colour material, so no chipped-paint wear (kit.py line 566 enforces one material and no images).
5. Sand family near, not equal to, the board swatch: SAND b5a384, SAND_D 9c8d73 and SAND_P c9bb9f (`islands.py` lines 36 to 38) against the board's sandstone c6a274; `C["sandstone"]` is unused. Colours not changed.
The reviewer rules on FAIL and the ART-MISTAKES line.

## Smoke, final tree (w18f round)

park_props_test, park_park_islands_test, park_dressing_pin_test and asset_registry_test PASS (load 3.9 to 4.2). scatter_rows_test PASS (95 checks); direct run at load 13.6: "no main-thread scatter step over 8 ms during the build, start() included] 3.81 ms -> PASS". run_tier_test PASS in 586 s (load 4.7 before, 15.0 after; `artifacts/local/run_tier-islands.log`, no FAIL and no timeout line). The earlier run on the merged tree failed 3 of 192 at load 6 to 16 and its failure lines were not kept, so I do not call it base-red.
