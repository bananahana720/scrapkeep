# park_dam dressing, wave 18 re-proof

Base: merge of the Dressing foundation aaeb5e10 (stage/alpha-w18 9cd6805e plus the `scatter_row` rule) into the dam branch.
Method: automated headless Godot 4.7.2 on cloud llvmpipe (OpenGL compatibility proxy, not a frame-cost proof, not human feel).

## Plan check

`tools/park_props_plan.gd --map=park_dam --check`: 834 instances (83 litter), 0 violations, fingerprint 1759471770. No spot moved. Pin 1759471770 unchanged (old and new).

## Tests (each run alone, GODOT_BIN 4.7.2)

park_props_test 162, park_park_dam_test 16, park_dressing_pin_test 8, pocket_line_clear_test 25, scatter_rows_test 82; set_dressing_test and asset_registry_test PASS (no count printed). Registry fold: 1053 assets, no change.

## Audit (default run, mid camera, step 25 m, 258 samples)

- props-only draw delta: max 56, median 11.5 (peak pose idx 72 at -280.7, -531.0). Earlier pass: max 59.
- draw calls: max 389, median 353.5, p95 383.45; primitives max 792164 (median 663818)
- density: 24 of 25 non-exempt windows pass (0.96; 24 exempt: 12 arena, 1 camp, 11 telegraph). Failing: kest start 900 m at (18.3, -32.4), 0 kinds, the corkscrew-slot hard keepout. Earlier pass: 24/25 with the same window.
- bare share 38.8 percent (100 of 258), longest bare run 175 m; bare ground share 38.8, longest 175 m; void poses 0
- median dressing core in view within 60 m 8.0, distinct kinds within 120 m median 16

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

- Kind `laundry_line`. Brief line: "keep at least 30 m from lines", because a washing line reads as a grind or grapple line. Measure: edge-to-line, ParkProps `line_distance(centre)` minus the instance radius, as `check_one` uses for `line_clear`. Target 30.5 m or more.
- Two of 14 instances were under: bunk_collapse_30 (v=c) edge 28.41 to 30.94; mid_laundry_142 (v=a) edge 29.14 to 31.10. The other 12 are 31.04 or more, unchanged.
- Spots moved: bunk_collapse_30 from (-15, -503) to (-12, -504), about 3.2 m; mid_laundry_142 from (-4, 300) to (-2, 300), 2 m. Neither move is near 20 m, so the `near` labels stay.
- Pin 617986039 to 47128334. Plan check: 834 instances, 0 violations. Probe: under30_edge=0.
- Audit pending the line_clear_m foundation merge.
