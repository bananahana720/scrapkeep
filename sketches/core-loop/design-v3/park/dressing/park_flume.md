# park_flume dressing, wave 18 re-proof

Base: merge of the Dressing foundation aaeb5e10 (stage/alpha-w18 9cd6805e plus the `scatter_row` rule) into the flume branch.
Method: automated headless Godot 4.7.2 on cloud llvmpipe (OpenGL compatibility proxy, not a frame-cost proof, not human feel).

## Plan check

`tools/park_props_plan.gd --map=park_flume --check`: 1120 instances (440 litter), 0 violations, fingerprint 1477437796 (merge pin was 875855731).
The expected `scatter_row` failure in `horseshoe_gorge` did not appear: no tall or hero instance lies inside that scatter row.

## Density fix (two windows, each filled)

The first w18 run failed two windows at 2 kinds (saltbush, bent_numbers): cannon 1200 m near (-9.6, 206) and tally 1050 m near (-16.6, 226). Each window has one sample, camera facing about +z. North of z 235 is blocked: `home_clear` (25 m of home wasteway_chasers) plus `line_clear` and `keepout` on siphon_runout_pier; a 5 m probe grid of single low pieces over x -60..40, z 190..280 found only a handful of legal cells. Added two single-piece spots on legal ground between the windows and the existing scrub: flume_s094 (mini_ties, timber_ties) at (-5, 225) and flume_s095 (mini_cup, tea_hearth) at (-5, 230). No line, landing or telegraph is touched (0 violations).

## Tests (each run alone, GODOT_BIN 4.7.2)

park_props_test 162, park_park_flume_test 127, park_dressing_pin_test 8, pocket_line_clear_test 25, scatter_rows_test 82; set_dressing_test and asset_registry_test PASS (no count printed). Registry fold: 1074 assets, no change.

## Audit (default run, mid camera, step 25 m, 238 samples, 5.95 km of union line)

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
