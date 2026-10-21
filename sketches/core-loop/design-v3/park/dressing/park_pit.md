# park_pit dressing, wave 18 re-proof

Base: merge of the Dressing foundation aaeb5e10 (stage/alpha-w18 9cd6805e plus the `scatter_row` rule) into the pit branch.
Method: automated headless Godot 4.7.2 on cloud llvmpipe (OpenGL compatibility proxy, not a frame-cost proof, not human feel).

## Plan check

`tools/park_props_plan.gd --map=park_pit --check`: 1168 instances (209 litter), 0 violations, fingerprint 2710067272. No spot moved. Pin 2710067272 unchanged (old and new).

## Tests (each run alone, GODOT_BIN 4.7.2)

park_props_test 162, park_park_pit_test 51, park_dressing_pin_test 8, pocket_line_clear_test 25, scatter_rows_test 82; set_dressing_test and asset_registry_test PASS (no count printed). Registry fold: 1044 assets, no change.

## Audit (default run, mid camera, step 25 m, 169 samples)

- props-only draw delta: max 70, median 28.0 (peak pose idx 108 at 67.8, -287.6). Earlier pass: max 73.
- draw calls: max 373, median 319.0, p95 362.8; primitives max 693848 (median 561903)
- density: 27 of 27 non-exempt windows pass (1.0; 4 exempt: 1 arena, 2 camp, 1 telegraph), no failing windows. Earlier pass: 27/27.
- bare share 21.3 percent (36 of 169), longest bare run 150 m; bare ground share 21.3, longest 150 m; void poses 0
- median dressing core in view within 60 m 13.0, distinct kinds within 120 m median 15

## Pose replay (before = same tree, `props/park_pit.json` moved aside, same poses; after = default run stills)

The default run wrote 11 stills (12 requested, one pose de-duplicated). Pixel change (share of pixels with a channel difference over 12):
106,-299 1.48; 126,-150 0.12; 135,-122 3.77; 148,-150 0.30; 153,-37 0.18; 21,-257 1.81; 47,205 0.38; 63,15 1.78; 79,337 0.41; 87,174 0.07; 9,-501 0.36. Median 0.38.
The poses are the barest places, mostly inside keepouts and over greybox rows. Props-off replay draws: max 354, median 280.

Stills: `artifacts/local/dressing/pit/w18/{before,after}/park_pit/`, sheet `artifacts/local/dressing/pit/w18/before_after.png` (local, not committed).
