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

## 30 m brief kinds

- Kind: `windsock`. Brief line: "Tag it tall; keep 30 m from lines", because a mast reads as a harpoon anchor.
- Measure: edge-to-line, ParkProps `Context.line_distance(centre)` minus the instance radius (1.90 m), as `check_one` uses for `line_clear`. Target 30.5 m or more.
- Instance `edge_m`, before to after: pit_1109 23.30 to 31.25; pit_125 25.43 to 31.39; pit_271 26.90 to 31.40; pit_329 23.10 to 30.55; pit_526 24.80 to 31.30. pit_109 (51.57) and pit_396 (31.59) already passed and are unchanged.
- Spots moved (old `at` to new `at`): pit_1109 (-265, -314) to (-272.9, -313.1); pit_125 (337, -155) to (339.9, -160.2); pit_271 (98, -287) to (101.6, -289.7); pit_526 (-130, -37) to (-123.6, -38.1); pit_329 (357, -32) to (364.5, -45). pit_329 moved about 15.9 m, because straight away from the line lands on a slope over 25 degrees; its `near` label is unchanged (under 20 m).
- Pin: 2710067272 to 3170188153. Plan check: 1168 instances, 0 violations.
- Audit pending the line_clear_m foundation merge.
