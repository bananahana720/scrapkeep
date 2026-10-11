# Traversal table: park_dam (world 1, stage 1)

The bands are PARK.md section 8. Each line ran 8 seeds (1 to 8) through `tools/traversal_line.gd -- --table=park --stage=1` at `--fixed-fps 90`; the waypoints are `tools/park_lines/park_dam.json`. Each cell gives the median, the worst seed in brackets, and pass or miss.

## Greybox pass, 2026-10-11

Measured on park file v12 (`park_sha256` 3278a40e in `assets/park/park_dam/graph.json`) for Sable, Rivet and Tally. Kest, Tarn, Cannon and the floor line ran on v11, which differs from v12 only in `training_wall_west` ending 15 m shorter at its south end; the change removes wall and adds none, so it cannot add an obstacle to those routes.

| Band | sable | rivet | kest | tarn | tally | cannon | floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Reached the Warden (8 of 8) | 8, pass | 8, pass | 8, pass | 8, pass | 8, pass | 8, pass | 8, pass |
| Time to Warden, s (median 60 to 120, no seed over 150) | 62.225 (worst 126.74), pass | 81.89 (worst 82.51), pass | 83.515 (worst 87.63), pass | 74.7 (worst 75.26), pass | 81.51 (worst 83.52), pass | 87.71 (worst 91.02), pass | 82.715 (worst 83.37), pass |
| Segment medians, s (each 12 to 45) | 29.24/18.14/14.23 (worst 29.24), pass | 38.86/30.16/13.07 (worst 38.86), pass | 30.45/30.62/22.46 (worst 30.62), pass | 31.7/26.52/16.34 (worst 31.705), pass | 32.54/31.7/17.75 (worst 32.54), pass | 29.48/29.68/28.4 (worst 29.9), pass | 38.73/31.8/12.17 (worst 38.73), pass |
| Flow share (median 0.70, no seed under 0.60) | 0.966 (worst 0.8816), pass | 0.82 (worst 0.7945), pass | 0.7286 (worst 0.7036), pass | 0.9693 (worst 0.9426), pass | 0.7281 (worst 0.6795), pass | 0.908 (worst 0.8908), pass | 0.7665 (worst 0.7427), pass |
| Airborne share (0.12 to 0.45) | 0.2577, pass | 0.1606, pass | 0.2123, pass | 0.2146, pass | 0.1633, pass | 0.1588, pass | 0.0936, MISS |
| Dead stops (0 every seed) | 0.0 (worst 1.0), MISS | 0.0 (worst 0.0), pass | 0.0 (worst 0.0), pass | 0.0 (worst 0.0), pass | 0.0 (worst 0.0), pass | 0.0 (worst 0.0), pass | 0.0 (worst 0.0), pass |
| Peak speed, m/s (26.6 every seed) | 54.95 (worst 54.37), pass | 42.85 (worst 42.08), pass | 34.355 (worst 28.05), pass | 40.025 (worst 39.11), pass | 43.93 (worst 43.59), pass | 35.8 (worst 32.34), pass | 43.63 (worst 42.9), pass |
| Blazing tier, s (median 3) | 49.27, pass | 10.45, pass | 6.255, pass | 12.805, pass | 9.0, pass | 9.03, pass | 9.67, pass |
| Quiet stretch, s (at most 20) | 6.69 (worst 6.69), pass | 6.69 (worst 6.69), pass | 6.69 (worst 6.69), pass | 6.69 (worst 6.69), pass | 6.69 (worst 6.69), pass | 6.69 (worst 6.69), pass | 6.69 (worst 6.69), pass |
| Max anchor gap, m (at most 40) | 36.4 (worst 39.6), pass | 33.2 (worst 33.2), pass | 36.8 (worst 36.8), pass | 35.6 (worst 35.6), pass | 33.7 (worst 38.3), pass | 35.0 (worst 35.0), pass | 33.1 (worst 33.1), pass |
| Distinct ride facts, tool count (at least 3) | 3.0 (worst 2.0), pass | 3.0 (worst 3.0), pass | 4.0 (worst 4.0), pass | 3.0 (worst 3.0), pass | 3.0 (worst 3.0), pass | 4.0 (worst 4.0), pass | 2.0 (worst 2.0), MISS |
| Length ratio (1.3 to 2.0) | 1.68, pass | 1.32, pass | 1.35, pass | 1.38, pass | 1.32, pass | 1.45, pass | 1.32, pass |
| Distinct ride facts after KB7b (lift_fired, wall_crumbled, crater_ride out; at least 3) | 2 (kicker_launch, ride_grapple_line), MISS | 2 (kicker_launch, ride_grapple_line), MISS | 2 (kicker_launch, ride_grapple_line), MISS | 2 (kicker_launch, ride_grapple_line), MISS | 2 (kicker_launch, ride_grapple_line), MISS | 2 (kicker_launch, ride_grapple_line), MISS | 1 (kicker_launch), MISS |
| Progress | not measured (KB7b, R12) | not measured (KB7b, R12) | not measured (KB7b, R12) | not measured (KB7b, R12) | not measured (KB7b, R12) | not measured (KB7b, R12) | not measured (KB7b, R12) |

Floor line: median 82.72 s against Rivet's 81.89 s, ratio 1.01 (band at most 2.0); dead stops median 0.0, worst 0.0 (band 0): pass.

Notes on the open cells:

- Sable's dead stops: one stop on seed 4 and one on seed 6, both on the shelf A loop. A second cut of the loop (one stop on seed 3) dropped the line's distinct ride facts to 2, so the shipped cut is the first.
- The floor line's airborne share and distinct ride facts are listed for completeness. The floor's own band is reaching the Warden within 2.0 times the pilot median with no dead stop, and it passes.
- Distinct ride facts after KB7b: every row's ride sensor (`ride_chute`, `ride_bowl`, `ride_drop`, `ride_ledge`, `ride_hop`) comes from `ParkRecipes.place`, and nothing calls it at runtime on this head, so only contraption facts and kicker launches count. With `lift_fired` out, every line reaches 2 at most. Placing the row sensors is a loader change, out of this unit's scope.
- Progress is not measured: `traversal_line.gd` reads the stage graph into an empty instance (R12, KB7b).
