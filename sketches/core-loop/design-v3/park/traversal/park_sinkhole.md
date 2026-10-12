# Traversal bands: park_sinkhole (stage 4)

PARK.md section 8 bands, measured with `tools/traversal_line.gd` (KB7, with KB7b's park ride-fact set and graph access) on the park table, stage 4, seeds 1 to 8 per line, `--fixed-fps 90`. Each pass has its own dated table (R8). The coordinator's index is TRAVERSAL-PARK.md.

## Greybox pass, 2026-10-11 (KD4 continuation, on b0e4490 with KB9)

Park file `src/world/park/park_sinkhole.json`, lines `tools/park_lines/park_sinkhole.json`, bake and graph in `assets/park/park_sinkhole/` (this commit). An earlier table on this page predated KB9 (no park row placed at runtime, so no ride sensor fired) and is replaced. On this head the runtime places the rows and their sensors fire: every line earns `ride_chute`, `ride_drop` and `ride_bowl` besides `kicker_launch` and `ride_grapple_line`, so the old blocker is gone. KB7b's graph read works: `progress_m` prints a number and no `SCRIPT ERROR` line appears in any run.

Commands, one process at a time, with the machine's foreground load at or under 32 before each: `godot --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/traversal_line.gd -- --table=park --stage=4 --pilot=<key> --seeds=1,2,3,4,5,6,7,8 --out=<dir> --trace` for each pilot, and `--floor --ref=sable` for the floor line. Sable, Rivet, Tarn, Tally and the floor are from one round; Kest and the Cannon were re-run after their channel lanes were swapped (the Cannon's lane cost it 0.7 s over the first segment's 45 s band), on the same bake.

The tool judges each band on the median and prints the worst seed beside it.

| line | band | median | worst seed | result |
| --- | --- | --- | --- | --- |
| sable | reached_warden (8 of 8 seeds) | 8 | - | pass |
| sable | time_to_warden_s (median 60.0 to 120.0 s; no seed over 150.0 s) | 67.56 | 71.76 | pass |
| sable | segment_s (each segment's median 12.0 to 45.0 s) | 29.48 / 17.47 / 20.2 | 29.48 | pass |
| sable | flow_share (median at least 0.7; no seed under 0.6) | 0.937 | 0.932 | pass |
| sable | airborne_share (0.12 to 0.45) | 0.404 | - | pass |
| sable | dead_stops (0 on every seed) | 0 | 0 | pass |
| sable | peak_speed_mps (at least 26.6 m/s (the blazing tier) on every seed) | 54.235 | 52.56 | pass |
| sable | tier3_s (median at least 3.0 s at the blazing tier) | 49.34 | - | pass |
| sable | quiet_max_s (at most 20.0 s) | 6.76 | 8.04 | pass |
| sable | max_anchor_gap_m (at most 40.0 m) | 11.05 | 15.1 | pass |
| sable | distinct_verbs (at least 3 different ride facts) | 5.5 | 5 | pass |
| sable | length_ratio (1.3 to 2.0) | 1.665 | - | pass |
| rivet | reached_warden (8 of 8 seeds) | 8 | - | pass |
| rivet | time_to_warden_s (median 60.0 to 120.0 s; no seed over 150.0 s) | 105.14 | 106.45 | pass |
| rivet | segment_s (each segment's median 12.0 to 45.0 s) | 44.97 / 30.77 / 28.88 | 44.965 | pass |
| rivet | flow_share (median at least 0.7; no seed under 0.6) | 0.862 | 0.846 | pass |
| rivet | airborne_share (0.12 to 0.45) | 0.162 | - | pass |
| rivet | dead_stops (0 on every seed) | 0 | 0 | pass |
| rivet | peak_speed_mps (at least 26.6 m/s (the blazing tier) on every seed) | 33.975 | 33.5 | pass |
| rivet | tier3_s (median at least 3.0 s at the blazing tier) | 12.045 | - | pass |
| rivet | quiet_max_s (at most 20.0 s) | 10.785 | 11.04 | pass |
| rivet | max_anchor_gap_m (at most 40.0 m) | 29.5 | 41.4 | pass (median; worst seed over 40 m) |
| rivet | distinct_verbs (at least 3 different ride facts) | 5 | 5 | pass |
| rivet | length_ratio (1.3 to 2.0) | 1.66 | - | pass |
| kest | reached_warden (8 of 8 seeds) | 8 | - | pass |
| kest | time_to_warden_s (median 60.0 to 120.0 s; no seed over 150.0 s) | 97.665 | 98.23 | pass |
| kest | segment_s (each segment's median 12.0 to 45.0 s) | 43.86 / 26.5 / 27.19 | 43.86 | pass |
| kest | flow_share (median at least 0.7; no seed under 0.6) | 0.858 | 0.817 | pass |
| kest | airborne_share (0.12 to 0.45) | 0.211 | - | pass |
| kest | dead_stops (0 on every seed) | 0 | 0 | pass |
| kest | peak_speed_mps (at least 26.6 m/s (the blazing tier) on every seed) | 29.84 | 28.6 | pass |
| kest | tier3_s (median at least 3.0 s at the blazing tier) | 9.08 | - | pass |
| kest | quiet_max_s (at most 20.0 s) | 9.81 | 10.3 | pass |
| kest | max_anchor_gap_m (at most 40.0 m) | 27.4 | 31.7 | pass |
| kest | distinct_verbs (at least 3 different ride facts) | 5 | 5 | pass |
| kest | length_ratio (1.3 to 2.0) | 1.6 | - | pass |
| tarn | reached_warden (8 of 8 seeds) | 8 | - | pass |
| tarn | time_to_warden_s (median 60.0 to 120.0 s; no seed over 150.0 s) | 93.835 | 95.84 | pass |
| tarn | segment_s (each segment's median 12.0 to 45.0 s) | 40.71 / 29.35 / 23.84 | 40.71 | pass |
| tarn | flow_share (median at least 0.7; no seed under 0.6) | 0.955 | 0.942 | pass |
| tarn | airborne_share (0.12 to 0.45) | 0.213 | - | pass |
| tarn | dead_stops (0 on every seed) | 0 | 0 | pass |
| tarn | peak_speed_mps (at least 26.6 m/s (the blazing tier) on every seed) | 31.975 | 31.54 | pass |
| tarn | tier3_s (median at least 3.0 s at the blazing tier) | 12.65 | - | pass |
| tarn | quiet_max_s (at most 20.0 s) | 11.17 | 13.73 | pass |
| tarn | max_anchor_gap_m (at most 40.0 m) | 8.85 | 9 | pass |
| tarn | distinct_verbs (at least 3 different ride facts) | 5 | 5 | pass |
| tarn | length_ratio (1.3 to 2.0) | 1.64 | - | pass |
| tally | reached_warden (8 of 8 seeds) | 8 | - | pass |
| tally | time_to_warden_s (median 60.0 to 120.0 s; no seed over 150.0 s) | 95.28 | 98.98 | pass |
| tally | segment_s (each segment's median 12.0 to 45.0 s) | 42 / 25.08 / 28.21 | 42.005 | pass |
| tally | flow_share (median at least 0.7; no seed under 0.6) | 0.914 | 0.872 | pass |
| tally | airborne_share (0.12 to 0.45) | 0.167 | - | pass |
| tally | dead_stops (0 on every seed) | 0 | 0 | pass |
| tally | peak_speed_mps (at least 26.6 m/s (the blazing tier) on every seed) | 33.55 | 33.08 | pass |
| tally | tier3_s (median at least 3.0 s at the blazing tier) | 13.105 | - | pass |
| tally | quiet_max_s (at most 20.0 s) | 9.445 | 10.48 | pass |
| tally | max_anchor_gap_m (at most 40.0 m) | 9.1 | 11.3 | pass |
| tally | distinct_verbs (at least 3 different ride facts) | 6 | 5 | pass |
| tally | length_ratio (1.3 to 2.0) | 1.57 | - | pass |
| cannon | reached_warden (8 of 8 seeds) | 8 | - | pass |
| cannon | time_to_warden_s (median 60.0 to 120.0 s; no seed over 150.0 s) | 90.765 | 92.09 | pass |
| cannon | segment_s (each segment's median 12.0 to 45.0 s) | 42.39 / 21.55 / 26.6 | 42.385 | pass |
| cannon | flow_share (median at least 0.7; no seed under 0.6) | 0.975 | 0.954 | pass |
| cannon | airborne_share (0.12 to 0.45) | 0.186 | - | pass |
| cannon | dead_stops (0 on every seed) | 0 | 0 | pass |
| cannon | peak_speed_mps (at least 26.6 m/s (the blazing tier) on every seed) | 32.07 | 31.9 | pass |
| cannon | tier3_s (median at least 3.0 s at the blazing tier) | 12.24 | - | pass |
| cannon | quiet_max_s (at most 20.0 s) | 8.1 | 9.02 | pass |
| cannon | max_anchor_gap_m (at most 40.0 m) | 11.9 | 14.7 | pass |
| cannon | distinct_verbs (at least 3 different ride facts) | 5 | 5 | pass |
| cannon | length_ratio (1.3 to 2.0) | 1.51 | - | pass |
| floor | reached_warden (8 of 8 seeds) | 8 | - | pass |
| floor | time_to_warden_s (median 60.0 to 120.0 s; no seed over 150.0 s) | 98.73 | 99.7 | pass |
| floor | segment_s (each segment's median 12.0 to 45.0 s) | 42.47 / 27.03 / 29.13 | 42.47 | pass |
| floor | flow_share (median at least 0.7; no seed under 0.6) | 0.88 | 0.855 | pass |
| floor | airborne_share (0.12 to 0.45) | 0.161 | - | pass |
| floor | dead_stops (0 on every seed) | 0 | 0 | pass |
| floor | peak_speed_mps (at least 26.6 m/s (the blazing tier) on every seed) | 33.76 | 33.68 | pass |
| floor | tier3_s (median at least 3.0 s at the blazing tier) | 13.17 | - | pass |
| floor | quiet_max_s (at most 20.0 s) | 9.515 | 13.27 | pass |
| floor | max_anchor_gap_m (at most 40.0 m) | 9.25 | 13.1 | pass |
| floor | distinct_verbs (at least 3 different ride facts) | 5 | 5 | pass |
| floor | length_ratio (1.3 to 2.0) | 1.55 | - | pass |
| floor | floor (reaches the Warden in at most 2.0 times sable's median time, 0 dead stops) | 98.73 | 135.12 | pass |

Dead stops and reach, per line:

- sable: class pylon_engineer, reached 8 of 8, dead stops none
- rivet: class runner_gunner, reached 8 of 8, dead stops none
- kest: class demolitions_caster, reached 8 of 8, dead stops none
- tarn: class tarn, reached 8 of 8, dead stops none
- tally: class tally, reached 8 of 8, dead stops none
- cannon: class remembered_cannon, reached 8 of 8, dead stops none
- floor: class runner_gunner, reached 8 of 8, dead stops none

**Distinct lines across the six pilots (at least 3).** The tool does not compute this band, so it is measured on the ball traces of the same runs (`--trace`): two lines are distinct when fewer than half of each line's ticks lie within 8 m in plan of the other's. Sable, Rivet and Tarn are mutually distinct on all 8 seeds (seed 1: Sable and Rivet 0.44, Sable and Tarn 0.45, Rivet and Tarn 0.44), and so are Rivet, Kest and Tarn (0.40, 0.44, 0.43): pass. The lines share the lava channel, so Rivet rides the channel's left wall and Kest its right wall where the channel runs straight and no post stands within 10 m; the others ride its middle.

**Notes.**

- Rivet's max anchor gap is 29.5 m median, but seed 7 reads 41.4 m (over 40 m on that one seed); the tool judges the median. Rivet's first segment median is 44.97 s against the 45 s band, the tightest number on the page.
- The floor line's band is 2.0 times Sable's median (67.56 s), so 135.1 s; its slowest seed took 99.7 s.
- A dead stop counts any halving of speed in the contact window (`src/core/run_log.gd:108`). The traced fixes this pass: a fork pillar at the tube mouth and a bend post in the main upper tube moved off the inside of the line, the west breakthrough's last wash shortened to 20 m so a ball leaving the main lower tube onto the ring no longer lands across its bank, and the main-upper waypoint re-cut to (-42, -76) where the ball runs. One remaining source is a director enemy on the line: a Kest seed hit a cinder burrower in the channel (contact `CharacterBody3D` in the trace); on the channel's wall lane it no longer meets it.
