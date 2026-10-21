# park_flume dressing, wave 18 re-proof

Base: merge of the Dressing foundation aaeb5e10 (stage/alpha-w18 9cd6805e plus the `scatter_row` rule) into the flume branch.
Method: automated headless Godot 4.7.2 on cloud llvmpipe (OpenGL compatibility proxy, not a frame-cost proof, not human feel).

## Plan check

`tools/park_props_plan.gd --map=park_flume --check`: 1118 instances (440 litter), 0 violations, fingerprint 875855731.
No spot moved. The expected `scatter_row` failure in `horseshoe_gorge` (a scatter row) did not appear: no tall or hero instance in the
w18 `props/park_flume.json` lies inside that row's footprint. Pin: 875855731 unchanged (old and new).

## Tests (each run alone, GODOT_BIN 4.7.2)

park_props_test 162, park_park_flume_test 127, park_dressing_pin_test 8, pocket_line_clear_test 25, scatter_rows_test 82; set_dressing_test and asset_registry_test PASS (no count printed). Registry fold: 1074 assets, no change.

## Audit (default run, mid camera, step 25 m, 238 samples, 5.95 km of union line)

- props-only draw delta: max 49, median 24.5 (peak pose idx 55 at -97.2, 400.8)
- draw calls: max 429, median 302.5, p95 409.55; primitives max 818594 (median 659299)
- density: 34 of 36 non-exempt windows pass (0.944; 9 exempt: 5 arena, 4 telegraph). Failing: cannon start 1200 m at (-9.6, 206.0) 2 kinds; tally start 1050 m at (-16.6, 226.2) 2 kinds (the siphon_camp reach).
- bare share 21.0 percent (50 of 238), longest bare run 100 m; bare ground share 21.0, longest 100 m; void poses 0
- median dressing in view within 60 m 49.5 (props 6.5, scatter 38), distinct kinds within 120 m median 18

## 12-pose replay (before = same tree, `props/park_flume.json` moved aside, same poses; after = default run stills)

Pixel change (share of pixels with a channel difference over 12): 101,-204 8.64; 107,169 0.30; 137,213 1.87; 149,-49 1.37; 208,-104 2.10; 227,32 4.34; 235,123 89.10 (before frame shows a solid orange hazard-coloured surface that the after frame does not: a timing artifact of the replay, not props); 30,-298 2.15; 59,-20 0.57; 8,-468 0.04; 89,-213 1.27; 91,-232 0.25. Median 1.62.
The 12 poses are the barest places, mostly inside keepouts, so props rarely fill the frame there.
Pair 101,-204 differs by an animated item (a tall post present only in the before frame), not by dressing.
Props-off replay draws: max 387, median 271.5.

Stills: `artifacts/local/dressing/flume/w18/{before,after}/park_flume/`, sheet `artifacts/local/dressing/flume/w18/before_after.png` (local, not committed).
