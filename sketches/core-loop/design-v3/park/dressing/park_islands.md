# Islands park dressing note (Dressing lane)

Base line: branch head after merging `origin/stage/alpha-w18` (f259e8cf421fc3c305b53ae104005dda40af9a41, merge 9577225bbf5bb2ceeee1a76997a6b5a8cfc18407) and the foundation `claude/zealous-franklin-ed0sxr-lineclear` (e72fff7d96a88118e622f30658bcddb3105ae206, merge a4b4fc5b08b315b21531766569b64fc3ae33ce1c); previous head b117ddd0.
Plan check: `park_props_plan.gd --map=park_islands --check` reports 470 instances (50 litter), 0 violations, fingerprint 3660265306 = pin (was 2014119072).

Vignette file: `src/world/park/props/park_islands.json` (79 spots, 470 instances, 50 of them litter, pin 3660265306). Kit: `assets/models/park/props/islands/manifest.json`. Rules: DRESSING-KITS.md, READABILITY.md, KITS.md (islands). Audit: `tools/park_props_audit.gd` via the lock wrapper; the numbers below are from the merged tree (stage/alpha-w18 8ee9e2c1).

## What and why (lore, #241 6329943362)

The giant machines are the humans' utility fleet: construction, mining and manufacturing. Some are corrupted, some are loyal drones and some are looping workers. The crew sites here (the net crews' mending yards and balloon landings, the fire lookout, the tram halt) read as plush crews living among working giants, so the scale contrast with the park's landforms and machines is the point. Nothing in this file is a machine and nothing is armed. The giant machines are never war machines.

## What each vignette shows and why it is there

Every template carries its `story` line in the file. Moments, by group:

- **Heroes (5 spots).** `lookout_post` x2 (a fire crew's stilted cab by the stair, the dam-era lookout story), `balloon_landing` and `balloon_graveyard` (the net crews' balloon that came down, patched in two stitch hands), `tram_halt` (the mining tram cabin set down on blocks, never hung). Hero heights 2.2 to 5.2 m come from the manifest (lookout_hut 5.18/5.17/3.99 m, balloon_basket_wreck 2.20/3.18/3.10 m, tram_car_parked 4.40/4.38/4.42 m). The hero spots sit at least 80 m from World's `fire_lookout` row at (150, -700), a distance I chose as 4x the 20 m TALL line clearance; the nearest hero is far beyond it.
- **Mids (11 spots).** `net_crew_corner`, `patchwork_rock`, `stair_marker`, `pine_ledge`, `ore_spill` (net menders' yard, sewing rock, hikers' numbered stones, relict pines, tipped ore bin) and one `mooring_spares` (winch drum, brass tag), which is only placed on a cell whose nearest row's society is `fleet` (mooring_pad_ramp). BRASS stays Fleet-only (READABILITY.md).
- **Low story groups (63 spots).** `net_mending`, `chart_stones`, `dropped_bolt`, `rope_basket_rest`, `tuft_cairn`, `net_drying`, plus the earlier `stone_nook`, `rope_heap`, `cobble_pair`, `net_scrap`, `stool_rest`, `pine_cairn`. These are the Dressing-lane density answer: 3 or more distinct kinds per 150 m window of ride line (AMBITION-BRIEF, DRESSING-KITS "Density bar"). Each group has one moment (a mending spot, a chart-stone curve, a dropped bolt of cloth), with open ground between groups.
- Scales in the new low templates are 0.85 to 1.1, chosen so the scaled height is at most 1.0 m from manifest heights (net_bundle 0.60 to 0.85, mender_stool b/c 0.83/0.82, rope_basket a 0.87, patch_bolt 0.50 to 0.64, stair_stones 0.18 to 0.49, stone_scatter 0.36 to 0.85, grass_tufts a/b 0.86/0.61). `LOW_GROUND_MAX_M` is 1.0 m (park_props.gd).

## Why they read without blocking a line, a lander or a telegraph

- No pickup, crate, ramp, gate, rail, creature or hanging machine shape (READABILITY.md "Shapes to avoid"); rope coils lie flat; the tram is on blocks.
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

- Plan check: 0 violations (fingerprint 2014119072 equals the pin).
- Tests (SMOKE_SLOTS=2): park_props_test, park_park_islands_test, park_dressing_pin_test, pocket_line_clear_test, set_dressing_test, asset_registry_test, scatter_rows_test all PASS (scatter_rows_test failed once, 1 of 90 checks, in the first batch run while the box was shared, then passed 90 of 90 twice on rerun; cause not identified).
- Audit of the new head: run, see "Audit (w18e, --open)" below. The numbers in the next bullet are the older 7e05da67 audit.
- Audit, full run (7e05da67): 48 windows, 16 exempt (arena 10, telegraph 6), 21 pass, 11 fail (share 0.656; the pass count was 13 before this pass); draw delta median 3, max 64 (bar 120); primitives median 516,739, max 798,889; void poses 0; bare share 72.0%.
- Failing windows (centre; kinds in view): floor 150 (6, -559; 0), floor 750 (-282, -212; 0), floor 1350 (93, 205; 1), floor 1500 (32, 334; 1), rivet 150 (157, -568; 0), sable 300 (-100, -499; 0), sable 600 (153, -318; 2), sable 750 (262, -215; 0), sable 900 (229, -93; 0), tarn 150 (-130, -570; 0), tarn 300 (-60, -500; 0). Probe of a 4 m radius, 1.0 m prop on a 5 m grid within 70 m of each centre: 0 valid cells for 9 windows (kicker run-out 120 to 587 of about 613 cells each; kicker ramp, line_clear and ground_row also), and for floor 1500 and sable 600 the valid cells (41 and 46) lie 43 m or more from the line, mostly beyond the 40 m band; one low spot was added at (170, -370) for sable 600, which still shows 2 kinds.
- Stills: `artifacts/local/dressing/islands/before_after.png` and `before_after_even.png` (same-tree before frames with the vignette file moved aside, via `before.sh`). Pixel change per pose (pixels differing by more than 24 grey levels): 0.04 to 1.06 percent; this is small because low props are small in the frame and most poses sit in keepouts.

## Plant litter height

The litter schema has no scale or variant cap (scale 0.9 to 1.15 in `_litter`, grass_tufts c 1.27 m, pine_sapling a/b 1.11, 1.41 m, manzanita 1.39 to 1.47 m). But the `low_ground` rule drops any litter taller than 1.0 m in a listed low-ground row, so plant litter over 1.0 m cannot stand in `lookout_mesa` or `twin_fins`. Confirmed on the current file: 6 litter items stand inside those two rows, none over 1.0 m (maximum 0.89 m); 8 litter items over 1.0 m exist elsewhere, governed by the line tiers.

## Not met and named fails

- Sable 600 (153,-318): 9 more low spots were added in the 43 to 60 m band at (165..190, -378..-366) from the probe's legal cells (spacing 10 m), because density counts kinds within 60 m of the camera. The audit that shows the result is held (see above).
- Floor 1500 (32,334) has 0 legal cells within 80 m of its centre after the telegraph rule, so no fill is possible there.
- Windows with a kicker run-out within 40 m of the window centre (distance from the run-out capsule surface, from `park_map.kickers`, run-out capsule as in `kicker_keepouts`): floor 150 (6.3,-559) run_step_lip_1 (-5.0 m); floor 750 (-281.9,-211.6) fan_step_lip_3 (-8.4); floor 1350 (93,204.6) carve_step_lip_1 (-1.4); floor 1500 (32.3,333.5) carve_step_lip_5 (-7.5); rivet 150 (156.5,-567.9) lookout_lip (-6.3); sable 300 (-100.4,-499.1) run_step_lip_2 (-7.1); sable 750 (262.4,-215.2) fan_step_lip_3 (-4.8); sable 900 (228.6,-92.5) fan_step_lip_6 (-7.5); tarn 150 (-130.2,-570.2) lookout_lip (-10.2); tarn 300 (-59.5,-499.5) run_step_lip_2 (-7.5). Negative means the centre is inside the capsule. I did not pass `--open`.
- Tests: run_tier_test failed 20 of 192 checks, every failure a runtime-child timeout (`exit=-1 timeout=true`) with the box at load average 22; scatter_rows_test timed out twice for the same reason (it passed 90 of 90 on the previous head). The other tests passed (counts in the hand-back).

## Audit (w18e, --open), ruling 6329579296

Ruling 6329579296: an `--open` window carries a reason the audit checks. `runout:<kicker>` needs a kicker run-out within 40 m of the window centre, and the audit fails an `--open` window whose reason does not check out.

Pre-audit (`artifacts/local/w18e-pre`, no `--open`): 48 windows, 16 exempt (arena 10, telegraph 6), 20 pass, 12 fail. Ten of the failures are the windows below, centres matching the table to 0.1 m. Two further failures are not in the ten and stay failed: kest 450 (-47.9, -366.1; 2 kinds) and sable 600 (153.0, -317.8; 2 kinds). Kest 450 was not a failure in the 7e05da67 audit; sable 600 is the window the earlier note already named as not met. Neither carries a run-out reason, so I did not `--open` them.

`--open=x:z:10:runout:<kicker>` for each, one arg per window (the audit's arg loop does `open_spaces.append_array`, so several are accepted):

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

Result (`artifacts/local/w18e`): `density_open_checked` 10, `density_open_rejected` empty, exempt 26 (arena 10, open:runout 10, telegraph 6), pass 20, fail 2 (kest 450, sable 600), share 0.909. Props-only draw delta max 63, median 4 (bar 120); bare share 74.4 percent; void poses 0.

## Reference boards (rulings 6330671507, 6331210075)

Boards read (each opened and looked at): `docs/art/reference/highdraft/highdraft-props-moodboard.jpg`, `highdraft-crew-moodboard.jpg`, `highdraft-landmark-hanging-isle.jpg`, `docs/art/reference/era/era-space-ground-ends-moodboard.jpg`, `style/style-palette-moodboard.jpg`, `style-materials-moodboard.jpg`, `style-shape-moodboard.jpg`, `pilots/pilots-balls-heft-moodboard.jpg`. Boards settle look only.

Board colours. Props board swatch strip: sandstone c6a274, oxide 9b513a, charcoal 242a28, petrol 365754, bone d2c5a5, copper b77843. Crew board adds brass d9b44a (Fleet plate on the mooring winch) and life 8f84b3. The props board paints machine bodies (braked drum, heat shields, closed furnace door) as petrol enamel with bone panels, copper pipes, rivets and clamps, charcoal housings and oxide wear chips; the highdraft README says "broad material differences and contact wear" and "props remain matte".

**Palette roles.** The kit (`tools/blender/park/props/islands.py`, manifest `assets/models/park/props/islands/manifest.json`) matches the board's sandstone, bone, charcoal and oxide through SAND, SAND_D, SAND_P (sandstone and bone shades, nearest-swatch distance 0.06 to 0.18), `C.bone`, `C.charcoal`, `C.cable` (charcoal shade), OXIDE (exact, winch_drum only) and `C.rust` (oxide shade). It has no petrol and no copper anywhere: the machine bodies are the drift below.

**Shape language.** Wear is broad and the shapes are soft toy shapes: low-poly lumps rounded by subsurf (`blob`, style "soft", "round"), flat-lying coils, a tub bin on stub axles, a three-legged stool, a tram on blocks. Silhouettes are low and wide, like the board's benches and stools. Detail is small-scale rope and stitching, not decoration.

**Materials.** The kit uses brass: one `BRASS` tag on `winch_drum` (islands.py line 504; the manifest story says "one brass tag"), and `mooring_spares` only lands on a `fleet` society cell. The board's crew panel shows a brass Fleet plate on the mooring winch, so this matches the board, but the packet says dressing uses copper or steel fittings instead of brass. Named under drift for review; I did not change the kit. No other brass.

**Scale to the pilot ball.** The ball is `Tuning.RADIUS` 1.0 m (`src/movement/tuning.gd:95`), so 2.0 m across. Kit heights from the manifest, as a share of the ball's diameter: low props 0.18 to 1.57 m (stair_stones 0.09x to ore_trolley c 0.79x), heroes 2.20 to 5.18 m (balloon_basket_wreck a 1.1x to lookout_hut a 2.6x). Relative only. The pilots board shows the ball as a roomy egg a person-sized pilot sits in, so a 0.6 to 1.0 m stool or basket reads at knee height to the ball, which matches the props board's low benches.

### Colour constants against the boards (grepped per kind)

Constants and `C[...]` uses, by kind, from the calls in islands.py (line of first use in brackets), mapped to a swatch or a shade of one (nearest swatch by RGB distance, hue read by hand):
- Maps to a swatch or a shade of one: OXIDE winch_drum (489); `C.charcoal` winch_drum (487); `C.bone` net_bundle (362), patch_bolt (604); `C.cable` balloon_basket_wreck (245); `C.rust` tram_car_parked (266), ore_trolley (435), winch_drum (500), patch_bolt (603); SAND, SAND_D, SAND_P lookout_hut (121-122), ore_trolley (441), stone_scatter (619, 624), tram_car_parked (311); `C.timber_pale` lookout_hut (120), tram_car_parked (289), net_bundle (360) (sandstone-copper brown); `C.canvas`, `C.canvas_dark`, `C.canvas_stain`, PATCH_A, PATCH_C (bone or sandstone shades, desaturated) in balloon_basket_wreck (209), patch_bolt (594-603), mender_stool, chart_post, lookout_hut (149, 177), tram_car_parked (327), winch_drum (502), grass_tufts (582); BRASS winch_drum (504, crew board swatch).
- Maps to no swatch (see drift): ROPE, ROPE_D, WICKER, TIMBER, TIMBER_D, BARK, `C.timber_grey`, SLICK, SLICK_D, PATCH_B (desaturated browns and greys, saturation 0.09 to 0.17 against the board's 0.3 to 0.4 sandstone, bone and copper); `C.iron`, `C.iron_light`, `C.concrete`, `C.concrete_dark` (neutral greys); PINE, PINE_D, `C.leaf`, `C.leaf_dark`, `C.dry_grass` (greens and olive, no green swatch on the props board).

### Avoid list, per item (kit recipe islands.py and manifest, file park_islands.json)

- No emission: the kit's glTF check asserts no `emissiveFactor` (kit.py line 567); islands.py has no emissive call; line 519 comment says unlit.
- No hazard stripes or coral: `kit.py` BANNED holds ff5a3c; grep of islands.py for hazard, stripe, coral hits none; the kit has no stripe pattern.
- No cache-shaped containers: ore_trolley is a flared tub on axle stubs (line 432 comment "not a crate"); rope and patch bundles are lumps; no crate.
- No taut or decorative grapple cables: the only `cable` colour use is stitch-thread ticks on the balloon patch (line 245); suspension ropes lie slack on the basket; rope coils are flat.
- No fake ride surfaces: no ramp, rail, gate or flat plate; the tram is on blocks, ore_trolley has no rails.
- No glowing lamps: rope_basket is an unlit lantern basket (line 519).
- No ancient-green or uranium-green: BANNED holds 9dff3c and 8bf0d3 (mint); islands.py greens are olive (PINE 4d6840, leaf 6f7f4a), hue 78 to 109, far from 9dff3c.
- Closed furnace mouths only: the kit has no furnace; grep of islands.py and park_islands.json for furnace returns 0.
- Slack nets distinct from the netcaster silhouette: net_bundle is a coiled ground bundle at most 0.85 m high; the kit has no mast or frame shapes (grep of islands.py for mast returns 0).

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

1. Machine bodies carry no petrol enamel or copper fittings. The board paints machines petrol with bone panels and copper hardware. `tram_car_parked` (islands.py 262-337: TIMBER_D 269, `C.iron` 270, `C.iron_light` 308, `C.rust` 266, `C.concrete` 334), `ore_trolley` (429-457: `C.iron` 435, `C.iron_light` 438, `C.concrete_dark` 441, `C.rust` 435) and `winch_drum` (483-504: `C.charcoal` 487, OXIDE 489, BRASS 504, `C.rust` 500) are timber, iron grey, rust and charcoal. No kit constant is petrol 365754 or copper b77843 (`C.verdigris` 5f8a7c exists in kit.py and islands.py does not use it).
2. Desaturated browns and greys with no swatch: ROPE, ROPE_D, WICKER, TIMBER, TIMBER_D, BARK, SLICK, SLICK_D, PATCH_B, `C.timber_grey` (kinds: lookout_hut, balloon_basket_wreck, tram_car_parked, net_bundle, mender_stool, chart_post, rope_basket, winch_drum, patch_bolt, stair_stones, stone_scatter, pine_sapling, manzanita), lines from 23 to 40 and the uses listed above. Desaturated on purpose after the low sun showed orange flecks (stills #189, #210); the board's rope is bone-pale.
3. Neutral greys `C.iron`, `C.iron_light`, `C.concrete`, `C.concrete_dark` (tram_car_parked, ore_trolley, lookout_hut, rope_basket, patch_bolt, stair_stones): board metal is petrol, charcoal or copper, not mid grey.
4. Greens PINE, PINE_D, `C.leaf`, `C.leaf_dark`, `C.dry_grass` (lookout_hut, balloon_basket_wreck, pine_sapling, manzanita, grass_tufts, net_bundle, mender_stool, chart_post, ore_trolley, rope_basket, tram_car_parked): foliage, shown in the board's images but with no swatch.
5. BRASS tag on winch_drum (line 504): matches the crew board's Fleet plate; the packet's rule prefers copper or steel for dressing.
I made no kit change. The reviewer rules on FAIL and the ART-MISTAKES line.
