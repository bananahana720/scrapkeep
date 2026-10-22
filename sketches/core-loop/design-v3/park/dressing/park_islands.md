# Islands park dressing note (Dressing lane)

Vignette file: `src/world/park/props/park_islands.json` (75 spots, 476 instances, 62 of them litter, pin 2014119072). Kit: `assets/models/park/props/islands/manifest.json`. Rules: DRESSING-KITS.md, READABILITY.md, KITS.md (islands). Audit: `tools/park_props_audit.gd` via the lock wrapper; the numbers below are from the merged tree (stage/alpha-w18 8ee9e2c1).

## What each vignette shows and why it is there

Every template carries its `story` line in the file. Moments, by group:

- **Heroes (5 spots).** `lookout_post` x2 (a fire crew's stilted cab by the stair, the dam-era lookout story), `balloon_landing` and `balloon_graveyard` (the net crews' balloon that came down, patched in two stitch hands), `tram_halt` (the mining tram cabin set down on blocks, never hung). Hero heights 2.2 to 5.2 m come from the manifest (lookout_hut 5.18/5.17/3.99 m, balloon_basket_wreck 2.20/3.18/3.10 m, tram_car_parked 4.40/4.38/4.42 m). The hero spots sit at least 80 m from World's `fire_lookout` row at (150, -700), a distance I chose as 4x the 20 m TALL line clearance; the nearest hero is far beyond it.
- **Mids (14 spots).** `net_crew_corner`, `patchwork_rock`, `stair_marker`, `pine_ledge`, `ore_spill` (net menders' yard, sewing rock, hikers' numbered stones, relict pines, tipped ore bin) and one `mooring_spares` (winch drum, brass tag), which is only placed on a cell whose nearest row's society is `fleet` (mooring_pad_ramp). BRASS stays Fleet-only (READABILITY.md).
- **Low story groups (56 spots).** `net_mending`, `chart_stones`, `dropped_bolt`, `rope_basket_rest`, `tuft_cairn`, `net_drying`, plus the earlier `stone_nook`, `rope_heap`, `cobble_pair`, `net_scrap`, `stool_rest`, `pine_cairn`. These are the Dressing-lane density answer: 3 or more distinct kinds per 150 m window of ride line (AMBITION-BRIEF, DRESSING-KITS "Density bar"). Each group has one moment (a mending spot, a chart-stone curve, a dropped bolt of cloth), with open ground between groups.
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

## What I checked

- Plan check: 0 violations (fingerprint 2014119072 equals the pin).
- Tests (SMOKE_SLOTS=2): park_props_test, park_park_islands_test, park_dressing_pin_test, pocket_line_clear_test, set_dressing_test, asset_registry_test, scatter_rows_test all PASS (scatter_rows_test failed once, 1 of 90 checks, in the first batch run while the box was shared, then passed 90 of 90 twice on rerun; cause not identified).
- Audit, full run: 48 windows, 16 exempt (arena 10, telegraph 6), 21 pass, 11 fail (share 0.656; the pass count was 13 before this pass); draw delta median 3, max 64 (bar 120); primitives median 516,739, max 798,889; void poses 0; bare share 72.0%.
- Failing windows (centre; kinds in view): floor 150 (6, -559; 0), floor 750 (-282, -212; 0), floor 1350 (93, 205; 1), floor 1500 (32, 334; 1), rivet 150 (157, -568; 0), sable 300 (-100, -499; 0), sable 600 (153, -318; 2), sable 750 (262, -215; 0), sable 900 (229, -93; 0), tarn 150 (-130, -570; 0), tarn 300 (-60, -500; 0). Probe of a 4 m radius, 1.0 m prop on a 5 m grid within 70 m of each centre: 0 valid cells for 9 windows (kicker run-out 120 to 587 of about 613 cells each; kicker ramp, line_clear and ground_row also), and for floor 1500 and sable 600 the valid cells (41 and 46) lie 43 m or more from the line, mostly beyond the 40 m band; one low spot was added at (170, -370) for sable 600, which still shows 2 kinds.
- Stills: `artifacts/local/dressing/islands/before_after.png` and `before_after_even.png` (same-tree before frames with the vignette file moved aside, via `before.sh`). Pixel change per pose (pixels differing by more than 24 grey levels): 0.04 to 1.06 percent; this is small because low props are small in the frame and most poses sit in keepouts.
- ART-MISTAKES.md did not exist after the stage merge, so no entries were checked.

## Not met

- Plant litter at 1.0 m or lower: the litter schema has no scale or variant cap; litter scale is 0.9 to 1.15 (`_litter`), so grass_tufts c (1.27 m), pine_sapling a/b (1.11, 1.41 m) and manzanita (1.39 to 1.47 m) can reach 1.0 to 1.7 m. The validator's tier rule still binds them (LOW up to 1.2 m, 6 m clear; MID 10 m).
- Every window not in the step-lip keepout passing: sable 600 and floor 1350 and 1500 still show 1 or 2 kinds; no valid cell inside the 60 m view.
