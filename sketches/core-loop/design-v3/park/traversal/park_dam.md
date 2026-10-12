# Traversal table: park_dam (world 1, stage 1)

The bands are PARK.md section 8. Each line ran 8 seeds (1 to 8) through `tools/traversal_line.gd -- --table=park --stage=1` at `--fixed-fps 90`; the waypoints are `tools/park_lines/park_dam.json`. Each cell gives the median, the worst seed in brackets, and pass or miss.

## Greybox fix round, 2026-10-12 (current)

Measured on the shipped park file (`park_sha256` 99ce445c in `assets/park/park_dam/graph.json`) with the tool on head 1b2cb49 plus this round's working tree. Two changes since the 2026-10-11 pass. First, `saguaro_26` fills the bare strip south of the drop (the density rule). Second, the floor line's last stretch now takes the bucket flight (spillway tunnel, `outlet_bucket` kicker, plunge pool) in place of the centre incline. All seven lines ran again, one process at a time, at a 1-minute load of 10 to 31.

| Band | sable | rivet | kest | tarn | tally | cannon | floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Reached the Warden (8 of 8) | 8, pass | 8, pass | 8, pass | 8, pass | 8, pass | 8, pass | 8, pass |
| Time to Warden, s (median 60 to 120, no seed over 150) | 62.62 (worst 65.09), pass | 81.835 (worst 82.29), pass | 83.755 (worst 86.02), pass | 74.72 (worst 76.1), pass | 81.07 (worst 82.3), pass | 84.25 (worst 85.69), pass | 85.98 (worst 87.16), pass |
| Segment medians, s (each 12 to 45) | 27.65/17.08/17.63 (worst 27.65), pass | 38.29/29.59/13.49 (worst 38.29), pass | 30.37/30.55/22.38 (worst 30.65), pass | 31.63/26.62/16.31 (worst 31.63), pass | 31.94/31.26/17.17 (worst 32.27), pass | 29.54/29.48/25.28 (worst 29.735), pass | 38.7/31.42/15.85 (worst 38.7), pass |
| Flow share (median 0.70, no seed under 0.60) | 0.9362 (worst 0.9305), pass | 0.8348 (worst 0.7978), pass | 0.7681 (worst 0.7012), pass | 0.9673 (worst 0.9432), pass | 0.7601 (worst 0.6945), pass | 0.9345 (worst 0.9), pass | 0.7817 (worst 0.7468), pass |
| Airborne share (0.12 to 0.45) | 0.2453, pass | 0.1633, pass | 0.2832, pass | 0.2158, pass | 0.1643, pass | 0.1704, pass | 0.1148, MISS (open, see notes) |
| Dead stops (0 every seed) | 0.0 (worst 0.0), pass | 0.0 (worst 0.0), pass | 0.0 (worst 0.0), pass | 0.0 (worst 0.0), pass | 0.0 (worst 0.0), pass | 0.0 (worst 0.0), pass | 0.0 (worst 0.0), pass |
| Peak speed, m/s (26.6 every seed) | 53.835 (worst 52.58), pass | 42.625 (worst 42.28), pass | 31.65 (worst 27.61), pass | 39.595 (worst 38.06), pass | 44.58 (worst 43.61), pass | 36.545 (worst 35.54), pass | 42.7 (worst 42.18), pass |
| Blazing tier, s (median at least 3) | 47.37, pass | 10.325, pass | 5.935, pass | 12.995, pass | 8.9, pass | 12.665, pass | 11.44, pass |
| Quiet stretch, s (at most 20) | 8.29 (worst 8.41), pass | 12.215 (worst 13.0), pass | 11.8 (worst 12.13), pass | 10.515 (worst 10.88), pass | 12.345 (worst 13.3), pass | 10.91 (worst 11.59), pass | 12.255 (worst 12.82), pass |
| Max anchor gap, m (at most 40) | 36.4 (worst 41.2), pass | 33.2 (worst 33.2), pass | 36.8 (worst 36.8), pass | 35.6 (worst 35.6), pass | 33.7 (worst 38.8), pass | 35.0 (worst 35.0), pass | 33.1 (worst 33.1), pass |
| Distinct ride facts, PARK.md section 4 set (at least 3) | 5.5 (worst 5.0), pass | 6.0 (worst 6.0), pass | 7.0 (worst 7.0), pass | 6.0 (worst 6.0), pass | 6.0 (worst 6.0), pass | 7.0 (worst 6.0), pass | 5.0 (worst 5.0), pass |
| Length ratio (1.3 to 2.0) | 1.645, pass | 1.325, pass | 1.34, pass | 1.38, pass | 1.32, pass | 1.45, pass | 1.38, pass |
| Floor line (at most 2.0 times the pilot median, 0 dead stops) | - | - | - | - | - | - | median 85.98 s against Rivet's 81.84 s, ratio 1.05, 0 dead stops, pass |
| Distinct lines (at least 3 across the six pilots) | 3 or more (unchanged waypoints since the 2026-10-11 traces), pass | (stage) | (stage) | (stage) | (stage) | (stage) | (stage) |
| Progress, m/s of d_landmark (reported, no band) | 21.075 | 16.125 | 15.78 | 17.64 | 16.295 | 15.63 | 15.33 |

Notes:

- The six pilot lines are unchanged and read the same as on 2026-10-11 to the hundredth, except Tally (a 0.1 s shift). The new field's posts stand at least 30 m south of the drop and every line, so no pilot meets them.
- The floor line's airborne share is 0.115, under the 0.12 to 0.45 band. PARK.md section 8 gives the floor line no `bar` object (line 505), and line 581 asks for the bands to be met for the floor line, so whether the airborne band judges the floor is open for a ruling. Three other floor cuts were measured, and each fixed the airborne share but missed another band:

| Floor cut (8 seeds each) | Airborne | The band it missed |
| --- | --- | --- |
| Start west over the domes: drop, [-260, -660], [-300, -590], [-250, -530] | 0.129 | max anchor gap 51.3 m (band 40); length ratio 1.29 (band 1.3) |
| The same start hugging the anchor fields: [-240, -705], [-330, -700], [-405, -640], [-365, -565] | 0.129 | dead stops 2 median, 4 worst, on the dome edges at [-216, -702], [-277, -704] and [-339, -555]; segment 1 48.9 s (band 45) |
| East start as shipped, then the west wash (Tally's middle) | 0.127 | flow share 0.68 median, 0.65 worst (band 0.70) |

- The anchor-gap miss on the west-domes start could be fixed by a small anchor field between the drop and the domes, but Sable's line runs through the same strip, so it would need her shelf loop re-cut as well. That is left for the ruling.

## Greybox pass on the KB9 head, 2026-10-11 (superseded 2026-10-12)

Measured on the shipped park file (`park_sha256` c40d1307 in `assets/park/park_dam/graph.json`) with the KB7b traversal tool on head 5de33a4 plus this unit's working tree. KB9 places the rows at runtime, so every row's ride sensor fires: the distinct ride facts row counts PARK.md section 4's set only (`lift_fired`, `crater_ride` and `wall_crumbled` are left out by the tool), and progress is measured (the R12 read defect no longer prints on this head). Cannon's eight seeds ran after `crest_trebuchet` moved 22 m off her line; that move changes only `graph.bin` (the ground, surface, holes and apron bytes are identical), so the other six lines' runs stand on the same terrain.

| Band | sable | rivet | kest | tarn | tally | cannon | floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Reached the Warden (8 of 8) | 8, pass | 8, pass | 8, pass | 8, pass | 8, pass | 8, pass | 8, pass |
| Time to Warden, s (median 60 to 120, no seed over 150) | 62.62 (worst 65.09), pass | 81.835 (worst 82.29), pass | 83.755 (worst 86.02), pass | 74.72 (worst 76.1), pass | 80.96 (worst 82.3), pass | 84.25 (worst 85.69), pass | 82.725 (worst 83.86), pass |
| Segment medians, s (each 12 to 45) | 27.65/17.08/17.63 (worst 27.65), pass | 38.29/29.59/13.49 (worst 38.29), pass | 30.37/30.55/22.38 (worst 30.65), pass | 31.63/26.62/16.31 (worst 31.63), pass | 31.94/31.26/17.27 (worst 32.13), pass | 29.54/29.48/25.28 (worst 29.735), pass | 38.7/31.42/12.53 (worst 38.7), pass |
| Flow share (median 0.70, no seed under 0.60) | 0.9362 (worst 0.9305), pass | 0.8348 (worst 0.7978), pass | 0.7681 (worst 0.7012), pass | 0.9673 (worst 0.9432), pass | 0.7605 (worst 0.6945), pass | 0.9345 (worst 0.9), pass | 0.7732 (worst 0.7368), pass |
| Airborne share (0.12 to 0.45) | 0.2453, pass | 0.1633, pass | 0.2832, pass | 0.2158, pass | 0.1653, pass | 0.1704, pass | 0.1092, miss (pilot band, not the floor's) |
| Dead stops (0 every seed) | 0.0 (worst 0.0), pass | 0.0 (worst 0.0), pass | 0.0 (worst 0.0), pass | 0.0 (worst 0.0), pass | 0.0 (worst 0.0), pass | 0.0 (worst 0.0), pass | 0.0 (worst 0.0), pass |
| Peak speed, m/s (26.6 every seed) | 53.835 (worst 52.58), pass | 42.625 (worst 42.28), pass | 31.65 (worst 27.61), pass | 39.595 (worst 38.06), pass | 44.375 (worst 43.61), pass | 36.545 (worst 35.54), pass | 43.6 (worst 42.54), pass |
| Blazing tier, s (median at least 3) | 47.37, pass | 10.325, pass | 5.935, pass | 12.995, pass | 8.945, pass | 12.665, pass | 9.59, pass |
| Quiet stretch, s (at most 20) | 8.29 (worst 8.41), pass | 12.215 (worst 13.0), pass | 11.8 (worst 12.13), pass | 10.515 (worst 10.88), pass | 12.345 (worst 13.3), pass | 10.91 (worst 11.59), pass | 12.255 (worst 12.82), pass |
| Max anchor gap, m (at most 40) | 36.4 (worst 41.2), pass | 33.2 (worst 33.2), pass | 36.8 (worst 36.8), pass | 35.6 (worst 35.6), pass | 33.7 (worst 38.8), pass | 35.0 (worst 35.0), pass | 33.1 (worst 33.1), pass |
| Distinct ride facts, PARK.md section 4 set (at least 3) | 5.5 (worst 5.0), pass | 6.0 (worst 6.0), pass | 7.0 (worst 7.0), pass | 6.0 (worst 6.0), pass | 6.0 (worst 6.0), pass | 7.0 (worst 6.0), pass | 5.0 (worst 5.0), pass |
| Length ratio (1.3 to 2.0) | 1.645, pass | 1.325, pass | 1.34, pass | 1.38, pass | 1.32, pass | 1.45, pass | 1.32, pass |
| Floor line (at most 2.0 times the pilot median, 0 dead stops) | - | - | - | - | - | - | reaches the Warden in at most 2.0 times rivet's median time, 0 dead stops: median 82.725, worst 163.67, pass |
| Distinct lines (at least 3 across the six pilots) | 3 or more (seed 1 traces: sable, rivet and kest mutually distinct; rivet and tarn share; tally and cannon not traced), pass | (stage) | (stage) | (stage) | (stage) | (stage) | (stage) |
| Progress, m/s of d_landmark (reported, no band) | 21.075 | 16.125 | 15.78 | 17.64 | 16.32 | 15.63 | 15.93 |

Notes:

- Every band passes for all six pilots. The floor line misses the pilots' airborne band (0.109); the floor's own band is reaching the Warden within 2.0 times Rivet's median with no dead stop, and it passes (82.7 s against 81.8 s).
- Max anchor gap is judged on the median by the tool; Sable's worst seed reads 41.2 m (median 36.4 m), and Tally's 38.8 m.
- The tightest cells: Kest's slowest seed peaks at 27.6 m/s (band 26.6) and Tally's worst flow share is 0.69 (band 0.60).
- Progress is reported with no band.

## Greybox pass on the pre-KB9 head, 2026-10-11 (superseded: no row was placed at runtime, so no row sensor fired and no row collided)

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
