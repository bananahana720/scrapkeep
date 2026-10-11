# Traversal bands: park_sinkhole (stage 4)

PARK.md section 8 bands, measured with `tools/traversal_line.gd` (KB7) on the park table, stage 4, seeds 1 to 8 per line, `--fixed-fps 90`. Each pass has its own dated table (R8). The coordinator's index is TRAVERSAL-PARK.md.

## Greybox pass, 2026-10-11 (KD4)

Commit: the KD4 greybox commit on this branch (base 5f2139b); park file `src/world/park/park_sinkhole.json`, lines `tools/park_lines/park_sinkhole.json`. Machine load during the runs: load average 48 to 62 (uptime at 08:59: 62.05, 50.25, 48.13).

Commands, one process at a time: `godot --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/traversal_line.gd -- --table=park --stage=4 --pilot=<key> --seeds=1,2,3,4,5,6,7,8 --out=<dir>` for each pilot, and the same with `--floor --ref=sable` for the floor line.

| line | band | median | worst seed | result |
| --- | --- | --- | --- | --- |
| sable | reached_warden (8 of 8 seeds) | 8 | None | pass |
| sable | time_to_warden_s (median 60.0 to 120.0 s; no seed over 150.0 s) | 68.59 | 218.5 | MISS |
| sable | segment_s (each segment's median 12.0 to 45.0 s) | [30.4, 16.8, 20.8] | 181.27 | pass |
| sable | flow_share (median at least 0.7; no seed under 0.6) | 0.933 | 0.6542 | pass |
| sable | airborne_share (0.12 to 0.45) | 0.4084 | None | pass |
| sable | dead_stops (0 on every seed) | 0.0 | 12.0 | MISS |
| sable | peak_speed_mps (at least 26.6 m/s (the blazing tier) on every seed) | 54.095 | 53.2 | pass |
| sable | tier3_s (median at least 3.0 s at the blazing tier) | 51.215 | None | pass |
| sable | quiet_max_s (at most 20.0 s) | 5.405 | 6.69 | pass |
| sable | max_anchor_gap_m (at most 40.0 m) | 12.0 | 18.0 | pass |
| sable | distinct_verbs (at least 3 different ride facts) | 3.0 | 3.0 | pass |
| sable | length_ratio (1.3 to 2.0) | 1.67 | None | pass |
| sable | distinct_verbs under KB7b's set (at least 3) | 2.0 | 2 | MISS |
| sable | progress_m | not measured (KB7b) | | |
| rivet | reached_warden (8 of 8 seeds) | 8 | None | pass |
| rivet | time_to_warden_s (median 60.0 to 120.0 s; no seed over 150.0 s) | 102.625 | 103.18 | pass |
| rivet | segment_s (each segment's median 12.0 to 45.0 s) | [42.2, 31.0, 29.0] | 43.77 | pass |
| rivet | flow_share (median at least 0.7; no seed under 0.6) | 0.8713 | 0.8305 | pass |
| rivet | airborne_share (0.12 to 0.45) | 0.1646 | None | pass |
| rivet | dead_stops (0 on every seed) | 0.0 | 0.0 | pass |
| rivet | peak_speed_mps (at least 26.6 m/s (the blazing tier) on every seed) | 33.715 | 33.11 | pass |
| rivet | tier3_s (median at least 3.0 s at the blazing tier) | 13.555 | None | pass |
| rivet | quiet_max_s (at most 20.0 s) | 6.69 | 6.69 | pass |
| rivet | max_anchor_gap_m (at most 40.0 m) | 36.55 | 44.4 | pass |
| rivet | distinct_verbs (at least 3 different ride facts) | 3.0 | 3.0 | pass |
| rivet | length_ratio (1.3 to 2.0) | 1.645 | None | pass |
| rivet | distinct_verbs under KB7b's set (at least 3) | 2.0 | 2 | MISS |
| rivet | progress_m | not measured (KB7b) | | |
| kest | reached_warden (8 of 8 seeds) | 8 | None | pass |
| kest | time_to_warden_s (median 60.0 to 120.0 s; no seed over 150.0 s) | 94.375 | 98.36 | pass |
| kest | segment_s (each segment's median 12.0 to 45.0 s) | [40.8, 26.6, 26.8] | 46.08 | pass |
| kest | flow_share (median at least 0.7; no seed under 0.6) | 0.8666 | 0.8333 | pass |
| kest | airborne_share (0.12 to 0.45) | 0.2109 | None | pass |
| kest | dead_stops (0 on every seed) | 0.0 | 0.0 | pass |
| kest | peak_speed_mps (at least 26.6 m/s (the blazing tier) on every seed) | 31.605 | 27.39 | pass |
| kest | tier3_s (median at least 3.0 s at the blazing tier) | 11.935 | None | pass |
| kest | quiet_max_s (at most 20.0 s) | 6.69 | 6.69 | pass |
| kest | max_anchor_gap_m (at most 40.0 m) | 26.25 | 31.5 | pass |
| kest | distinct_verbs (at least 3 different ride facts) | 3.0 | 3.0 | pass |
| kest | length_ratio (1.3 to 2.0) | 1.585 | None | pass |
| kest | distinct_verbs under KB7b's set (at least 3) | 2.0 | 2 | MISS |
| kest | progress_m | not measured (KB7b) | | |
| tarn | reached_warden (8 of 8 seeds) | 8 | None | pass |
| tarn | time_to_warden_s (median 60.0 to 120.0 s; no seed over 150.0 s) | 93.23 | 94.04 | pass |
| tarn | segment_s (each segment's median 12.0 to 45.0 s) | [41.0, 29.2, 23.1] | 41.73 | pass |
| tarn | flow_share (median at least 0.7; no seed under 0.6) | 0.972 | 0.9624 | pass |
| tarn | airborne_share (0.12 to 0.45) | 0.2153 | None | pass |
| tarn | dead_stops (0 on every seed) | 0.0 | 0.0 | pass |
| tarn | peak_speed_mps (at least 26.6 m/s (the blazing tier) on every seed) | 31.655 | 31.32 | pass |
| tarn | tier3_s (median at least 3.0 s at the blazing tier) | 12.28 | None | pass |
| tarn | quiet_max_s (at most 20.0 s) | 6.69 | 6.69 | pass |
| tarn | max_anchor_gap_m (at most 40.0 m) | 8.85 | 9.0 | pass |
| tarn | distinct_verbs (at least 3 different ride facts) | 3.0 | 3.0 | pass |
| tarn | length_ratio (1.3 to 2.0) | 1.635 | None | pass |
| tarn | distinct_verbs under KB7b's set (at least 3) | 2.0 | 2 | MISS |
| tarn | progress_m | not measured (KB7b) | | |
| tally | reached_warden (8 of 8 seeds) | 8 | None | pass |
| tally | time_to_warden_s (median 60.0 to 120.0 s; no seed over 150.0 s) | 95.585 | 101.75 | pass |
| tally | segment_s (each segment's median 12.0 to 45.0 s) | [41.9, 25.5, 28.3] | 47.69 | pass |
| tally | flow_share (median at least 0.7; no seed under 0.6) | 0.8979 | 0.8488 | pass |
| tally | airborne_share (0.12 to 0.45) | 0.1659 | None | pass |
| tally | dead_stops (0 on every seed) | 0.0 | 1.0 | MISS |
| tally | peak_speed_mps (at least 26.6 m/s (the blazing tier) on every seed) | 33.465 | 31.59 | pass |
| tally | tier3_s (median at least 3.0 s at the blazing tier) | 13.535 | None | pass |
| tally | quiet_max_s (at most 20.0 s) | 6.69 | 6.69 | pass |
| tally | max_anchor_gap_m (at most 40.0 m) | 8.95 | 13.6 | pass |
| tally | distinct_verbs (at least 3 different ride facts) | 3.0 | 3.0 | pass |
| tally | length_ratio (1.3 to 2.0) | 1.57 | None | pass |
| tally | distinct_verbs under KB7b's set (at least 3) | 2.0 | 2 | MISS |
| tally | progress_m | not measured (KB7b) | | |
| cannon | reached_warden (8 of 8 seeds) | 8 | None | pass |
| cannon | time_to_warden_s (median 60.0 to 120.0 s; no seed over 150.0 s) | 90.825 | 91.53 | pass |
| cannon | segment_s (each segment's median 12.0 to 45.0 s) | [42.5, 21.5, 26.6] | 42.93 | pass |
| cannon | flow_share (median at least 0.7; no seed under 0.6) | 0.9736 | 0.9581 | pass |
| cannon | airborne_share (0.12 to 0.45) | 0.1887 | None | pass |
| cannon | dead_stops (0 on every seed) | 0.0 | 0.0 | pass |
| cannon | peak_speed_mps (at least 26.6 m/s (the blazing tier) on every seed) | 32.31 | 30.96 | pass |
| cannon | tier3_s (median at least 3.0 s at the blazing tier) | 12.04 | None | pass |
| cannon | quiet_max_s (at most 20.0 s) | 6.69 | 6.69 | pass |
| cannon | max_anchor_gap_m (at most 40.0 m) | 12.25 | 14.2 | pass |
| cannon | distinct_verbs (at least 3 different ride facts) | 3.0 | 3.0 | pass |
| cannon | length_ratio (1.3 to 2.0) | 1.51 | None | pass |
| cannon | distinct_verbs under KB7b's set (at least 3) | 2.0 | 2 | MISS |
| cannon | progress_m | not measured (KB7b) | | |
| floor | reached_warden (8 of 8 seeds) | 8 | None | pass |
| floor | time_to_warden_s (median 60.0 to 120.0 s; no seed over 150.0 s) | 100.11 | 102.16 | pass |
| floor | segment_s (each segment's median 12.0 to 45.0 s) | [43.3, 27.3, 29.1] | 45.9 | pass |
| floor | flow_share (median at least 0.7; no seed under 0.6) | 0.8545 | 0.8358 | pass |
| floor | airborne_share (0.12 to 0.45) | 0.1562 | None | pass |
| floor | dead_stops (0 on every seed) | 0.0 | 1.0 | MISS |
| floor | peak_speed_mps (at least 26.6 m/s (the blazing tier) on every seed) | 33.65 | 32.35 | pass |
| floor | tier3_s (median at least 3.0 s at the blazing tier) | 12.91 | None | pass |
| floor | quiet_max_s (at most 20.0 s) | 6.69 | 6.69 | pass |
| floor | max_anchor_gap_m (at most 40.0 m) | 12.4 | 28.2 | pass |
| floor | distinct_verbs (at least 3 different ride facts) | 3.0 | 3.0 | pass |
| floor | length_ratio (1.3 to 2.0) | 1.55 | None | pass |
| floor | floor (reaches the Warden in at most 2.0 times sable's median time, 0 dead stops) | 100.11 | 137.18 | MISS |
| floor | distinct_verbs under KB7b's set (at least 3) | 2.0 | 2 | MISS |
| floor | progress_m | not measured (KB7b) | | |
| floor | time vs pilot median (at most 2.0x) | 1.07 x (100.1 s over 93.8 s) | | pass |

sable class pylon_engineer seeds 8 reached 8 dead stops at [{'at': [-193.8, -504.7], 'time': 85.87}, {'at': [-190.6, -519.6], 'time': 89.66}, {'at': [-190.5, -519.3], 'time': 89.71}, {'at': [-193.7, -483.6], 'time': 130.37}, {'at': [-194.8, -493.7], 'time': 143.95}, {'at': [-194.3, -509.8], 'time': 145.93}]
rivet class runner_gunner seeds 8 reached 8 dead stops at []
kest class demolitions_caster seeds 8 reached 8 dead stops at []
tarn class tarn seeds 8 reached 8 dead stops at []
tally class tally seeds 8 reached 8 dead stops at [{'at': [-618.7, -703.8], 'time': 6.97}, {'at': [8.1, -19.4], 'time': 67.4}]
cannon class remembered_cannon seeds 8 reached 8 dead stops at []
floor class runner_gunner seeds 8 reached 8 dead stops at [{'at': [-618.7, -703.7], 'time': 6.99}]

**Distinct lines across the six pilots (at least 3).** Measured on the lines file's waypoint polylines (more than 40% of a line's length more than 8 m from the other): the largest mutually distinct set is 3 (Sable, Rivet, Tarn): pass. The tool does not compute this band on ball traces.

**Notes.**

- progress_m is not measured: the tool's graph read is the known KB7b defect (R12), and its SCRIPT ERROR lines are that card.
- distinct_verbs counts ride facts. On this head no park row builds a ride sensor (`ParkRecipes.place` has no caller), so lines earn only `kicker_launch`, `ride_grapple_line`, `thermal_ride` (gliders) and `lift_fired` (the lift's own cycle, heard on every line). The row "distinct_verbs under KB7b's set" drops `lift_fired`; a miss there needs the runtime sensors, not a row change.
- A dead stop counts any halving of speed in the contact window (`src/core/run_log.gd:108`), so a director enemy hit on the line counts. Stops with no ground contact, no row within 18 m and the same seed and second on two lines are read as enemy hits (inference); see the unit report.
