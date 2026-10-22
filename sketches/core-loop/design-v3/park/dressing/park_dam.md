# park_dam dressing, wave 18 re-proof

## What and why

The dam's crew sites (camps, bunks, benches, laundry) read as plush crews living among working giants: the giant machines are the humans' utility fleet (construction, mining, manufacturing), some corrupted, some loyal drones, some looping workers. Scale contrast is the point, so the crew props stay small, human-sized and homely beside them. This unit brings the dam onto the two checked rules: a per-kind line clearance for the brief's 30 m kind, and the telegraph keepout.

Base: head f419ac50 (dam branch). Merges: origin/stage/alpha-w18 at 9703fd14 and again at e83a21c2 (stage moved past b22a2ca3, #175 stacked), and origin/claude/zealous-franklin-ed0sxr-lineclear 07748516 at fd5a5c59. The earlier base was the foundation aaeb5e10.
Method: automated headless Godot 4.7.2 on cloud llvmpipe (OpenGL compatibility proxy, not a frame-cost proof, not human feel).

## Plan check

`tools/park_props_plan.gd --map=park_dam --check`: 834 instances (83 litter), 5 violations on the merged rules (all `telegraph`, spot mid_tool_bench_123), then 0 violations after the move below, fingerprint 1202620946. Pin 47128334 to 1202620946 (617986039 before the 30 m pass).

## Telegraph zones

Rule: `park_props.gd` `check_one` fails a prop inside an event's own geometry grown by `hold_clear_m` (a lightning strike is a `strike_m` circle at the site point; design in `DRESSING-KITS.md`), so no prop stands where a telegraph will be drawn and damage lands. Litter that fails is dropped automatically; authored spots fail the plan check.

- `dome_lightning` (site slickrock_domes at (-110, -520), `strike_m` 6, `hold_clear_m` 0): 5 instances of mid_tool_bench_123 (cable_drum, compressor_cart, lunch_pail, sandbags, desert_scrub) stood inside the circle. The spot moved from (-108, -521) to (-124, -530), 18.4 m, the smallest of the positions tried that cleared both the circle and the 10 m mid line clearance (nearer ones on the south side failed line_clear). The `near` label (dome_5) is unchanged since the move is under 20 m.
- Litter dropped: none (83 litter before and after).
- The other five events (plunge_pool_flood, west_wash_flash_flood, east_bench_dropship, toe_vents_wake, powerhouse_boiler) had no hits.

## Tests (each run alone, GODOT_BIN 4.7.2, box load about 20)

park_props_test, park_park_dam_test, park_dressing_pin_test, pocket_line_clear_test, asset_registry_test: smoke PASS (no counts printed). scatter_rows_test: smoke timed out twice at its 180 s cap under load; run directly it passes, 95 checks (3m43s). run_tier_test: FAIL, 16 of 192 checks, 892 s under load (not diagnosed; no run, tier or scatter file changed in this unit). `npm run sketch:lint` 0 findings; `npm run check:docs` 0 failures (178 files, 6978 links). Registry fold: 1053 assets, no change.

## Audit (w18d, default run, mid camera, step 25 m, 258 samples; w18b before in brackets)

- props-only draw delta: max 57, median 12.0 [53, 11.5]
- draw calls: max 390, median 353.0, p95 383.45
- density: 24 of 49 windows pass, 24 exempt (12 arena, 1 camp, 11 telegraph) [24 of 49, 24 exempt]. Failing: the same kest window at (18.3, -32.4), 0 kinds, the corkscrew-slot hard keepout
- bare share 38.8 percent [38.8], longest bare run 175 m; void poses 0

## 12-pose replay (before = same tree, `props/park_dam.json` moved aside, same poses; after = default run stills)

Pixel change (share of pixels with a channel difference over 12): 113,-105 6.80; 118,-85 0.38; 155,-50 5.07; 161,-15 0.55; 226,76 0.54; 232,2 0.05; 233,-132 0.17; 239,93 15.29; 24,-69 1.53; 249,163 1.09; 32,-32 0.03; 97,-85 0.90. Median 0.73.
The poses are the barest places; most sit on the canyon floor between walls, the slot keepouts and the corkscrew, where nothing legal can stand, so the change there is small. The pixel figures are not dressing evidence on their own. The independent review of the full-size stills found that the large values at 239,93 (15.29), 113,-105 (6.80) and 155,-50 (5.07) are world-state or render differences: no park prop is in frame at 239, and the slot_bulkhead plank state differs at 113. Visible dressing change is at 161 and 249, with far bits at 24 and 226. The bare share (38.8%) is structural. The lines run on slot-canyon floors 34 m wide, which are keepouts too narrow for low_ground_rows, and through the eye arena and telegraph sites. The density bar passes 24 of 25, and the one fail is inside the corkscrew_slot keepout.
Props-off replay draws: max 390, median 340.

Stills: `artifacts/local/dressing/dam/w18/{before,after}/park_dam/`, sheet `artifacts/local/dressing/dam/w18/before_after.png` (local, not committed).

## Kit heights to brief

The Fable kit review found two kinds built off the dam brief (`sketches/core-loop/design-v3/park/dressing/KITS.md`, dam section; the lead is adding that file in a separate docs PR, so the citation will resolve). Both are rescaled in `tools/blender/park/props/dam.py`, with no change to geometry, tri budgets or colours.

- `flood_staff` (brief: "water-level staff, 2.6 m"): a 4.579 to 2.604 m, b 4.67 to 2.600 m, c unchanged at 1.732 m (fallen). LOD0 tris a 1000 to 728, b 1072 to 800, c 2240. The two upright variants are no longer auto-tagged tall.
- `laundry_line` (brief: "two posts under 2 m"; "keep at least 30 m from lines"): a and b 2.423 to 1.857 m, c 2.85 to 1.900 m. LOD0 tris unchanged (2128, 1340, 2016).
- Distance of every placed laundry_line to the nearest ride line (ParkProps `line_distance`): 14 instances, 31.0 to 115.0 m. Four were under 30 m (mid_laundry_5 24.5, _113 29.8, _125 24.9, _147 25.6) and their spots moved: _5 to (-310, -598) 33.5 m, _113 to (9, 283) 33.4 m, _125 to (-197, -451) 33.3 m (62 m move; no site within 40 m cleared 30 m), _147 to (-33, -297) 34.1 m. Unmoved: crew_camp_20 33.6, bunk_collapse_30 31.0, crew_camp_81 40.6, bunk_collapse_86 47.5, crew_camp_124 35.6, bunk_collapse_135 49.2, mid_laundry_142 31.4, canyon_15 73.4, crew_camp_rim_24 101.3, bunk_collapse_rim_25 115.0.
- The plan pin moved 1759471770 to 617986039 (new kit heights and the four spot moves). Plan check: 834 instances, 0 violations.

## 30 m brief kinds

- Kind `laundry_line` now carries `line_clear_m: 30` (`tools/blender/park/props/dam.py` `@K.kind`, manifest `line_clear_m: 30.0`), so the plan check enforces it; GLBs are byte-identical, only the manifest gained the field. Brief line (`sketches/core-loop/design-v3/park/dressing/KITS.md`, dam section; the lead is adding that file in a separate docs PR, so the citation will resolve): "keep at least 30 m from lines", because a washing line reads as a grind or grapple line. Measure: edge-to-line, `line_distance(centre)` minus the instance radius.
- Two of 14 instances were under: bunk_collapse_30 (v=c) edge 28.41 to 30.94; mid_laundry_142 (v=a) edge 29.14 to 31.10. The other 12 are 31.04 or more, unchanged.
- Spots moved: bunk_collapse_30 from (-15, -503) to (-12, -504), about 3.2 m; mid_laundry_142 from (-4, 300) to (-2, 300), 2 m. Near labels unchanged.
- Pin 617986039 to 47128334 for this pass.

## ART-MISTAKES entries checked

`project-guide/handoff/ART-MISTAKES.md` has 9 rows on this head; applied:
- 2026-10-21 World, #242 lane width ("called the LINE flag the actual ride line"): read `check_one` and the event plan in `park_props.gd` before moving anything, rather than assuming what a telegraph zone is (it is a strike circle here, not the site box).
- 2026-10-21 Modeling, #241 lane map ("listed units as owed that the stage held byte for byte"): rebuilt only `laundry_line` and checked that `git status` showed no GLB change, only the manifest field.
- 2026-10-21 Modeling, M1 anchor gap tool (run line copied from siblings, exit 127): ran the Blender command from the packet verbatim and confirmed exit 0.
