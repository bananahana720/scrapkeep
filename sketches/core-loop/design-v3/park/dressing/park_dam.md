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
The poses are the barest places; most sit on the canyon floor between walls, the slot keepouts and the corkscrew, where nothing legal can stand, so the change there is small. The largest change is pose 239,93 (lows by the arch); the rest are small or sit on pose-state differences (a target marker, a replay timing artifact).
Props-off replay draws: max 390, median 340.

Stills: `artifacts/local/dressing/dam/w18/{before,after}/park_dam/`, sheet `artifacts/local/dressing/dam/w18/before_after.png` (local, not committed).
