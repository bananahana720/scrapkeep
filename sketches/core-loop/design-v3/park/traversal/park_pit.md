# park_pit traversal measurements

## Greybox, 2026-10-12, merged candidate

Runtime input head `078320e470795ac8089cc5fec8aacf4e53db34d6`. Later page-only edits do not change the measured park, lines or code. Eight seeds per completed line. Floor flow share is reported only under kd-common-r.md item 4.

| Line | Measure | Band | Median | Worst seed | Verdict |
| --- | --- | --- | --- | --- | --- |
| sable | reached_warden | 8 of 8 seeds | 8 | True (seed 1) | PASS |
| sable | time_to_warden_s | median 60.0 to 120.0 s; no seed over 150.0 s | 61.78 | 66.77 (seed 2) | PASS |
| sable | segment_s | each segment's median 12.0 to 45.0 s | [13.81, 20.96, 27.23] | 28.59 (seed 6) | PASS |
| sable | flow_share | median at least 0.7; no seed under 0.6 | 0.959 | 0.9293 (seed 2) | PASS |
| sable | airborne_share | 0.12 to 0.45 | 0.2917 | 0.2646 (seed 1) | PASS |
| sable | dead_stops | 0 on every seed | 0.0 | 0 (seed 1) | PASS |
| sable | peak_speed_mps | at least 26.6 m/s (the blazing tier) on every seed | 56.9 | 56.9 (seed 1) | PASS |
| sable | tier3_s | median at least 3.0 s at the blazing tier | 48.305 | 47.46 (seed 7) | PASS |
| sable | quiet_max_s | at most 20.0 s | 6.995 | 8.41 (seed 4) | PASS |
| sable | max_anchor_gap_m | at most 40.0 m | 29.0 | 32.3 (seed 3) | PASS |
| sable | distinct_verbs | at least 3 different ride facts | 4.0 | 4 (seed 1) | PASS |
| sable | length_ratio | 1.3 to 2.0 | 1.74 | 1.77 (seed 2) | PASS |
| sable | Floor-line comparison | measured once, on floor row | N/A | N/A | N/A |
| rivet | reached_warden | 8 of 8 seeds | 8 | True (seed 1) | PASS |
| rivet | time_to_warden_s | median 60.0 to 120.0 s; no seed over 150.0 s | 100.945 | 101.38 (seed 3) | PASS |
| rivet | segment_s | each segment's median 12.0 to 45.0 s | [18.8, 38.2, 43.97] | 44.19 (seed 3) | PASS |
| rivet | flow_share | median at least 0.7; no seed under 0.6 | 0.7725 | 0.7521 (seed 3) | PASS |
| rivet | airborne_share | 0.12 to 0.45 | 0.1789 | 0.1744 (seed 7) | PASS |
| rivet | dead_stops | 0 on every seed | 0.0 | 0 (seed 1) | PASS |
| rivet | peak_speed_mps | at least 26.6 m/s (the blazing tier) on every seed | 31.855 | 31.4 (seed 1) | PASS |
| rivet | tier3_s | median at least 3.0 s at the blazing tier | 8.415 | 8.37 (seed 1) | PASS |
| rivet | quiet_max_s | at most 20.0 s | 16.415 | 16.6 (seed 1) | PASS |
| rivet | max_anchor_gap_m | at most 40.0 m | 28.15 | 29.5 (seed 4) | PASS |
| rivet | distinct_verbs | at least 3 different ride facts | 4.0 | 4 (seed 1) | PASS |
| rivet | length_ratio | 1.3 to 2.0 | 1.64 | 1.64 (seed 1) | PASS |
| rivet | Floor-line comparison | measured once, on floor row | N/A | N/A | N/A |
| kest | reached_warden | 8 of 8 seeds | 8 | True (seed 1) | PASS |
| kest | time_to_warden_s | median 60.0 to 120.0 s; no seed over 150.0 s | 96.755 | 99.15 (seed 8) | PASS |
| kest | segment_s | each segment's median 12.0 to 45.0 s | [18.45, 36.44, 42.06] | 42.42 (seed 4) | PASS |
| kest | flow_share | median at least 0.7; no seed under 0.6 | 0.7838 | 0.6674 (seed 4) | PASS |
| kest | airborne_share | 0.12 to 0.45 | 0.2487 | 0.2408 (seed 4) | PASS |
| kest | dead_stops | 0 on every seed | 0.0 | 0 (seed 1) | PASS |
| kest | peak_speed_mps | at least 26.6 m/s (the blazing tier) on every seed | 29.2 | 29.2 (seed 1) | PASS |
| kest | tier3_s | median at least 3.0 s at the blazing tier | 6.98 | 6.01 (seed 8) | PASS |
| kest | quiet_max_s | at most 20.0 s | 11.51 | 12.89 (seed 8) | PASS |
| kest | max_anchor_gap_m | at most 40.0 m | 17.6 | 17.7 (seed 7) | PASS |
| kest | distinct_verbs | at least 3 different ride facts | 5.0 | 5 (seed 1) | PASS |
| kest | length_ratio | 1.3 to 2.0 | 1.72 | 1.73 (seed 1) | PASS |
| kest | Floor-line comparison | measured once, on floor row | N/A | N/A | N/A |
| tarn | reached_warden | 8 of 8 seeds | 8 | True (seed 1) | PASS |
| tarn | time_to_warden_s | median 60.0 to 120.0 s; no seed over 150.0 s | 74.95 | 75.42 (seed 2) | PASS |
| tarn | segment_s | each segment's median 12.0 to 45.0 s | [17.46, 35.5, 21.94] | 36.07 (seed 6) | PASS |
| tarn | flow_share | median at least 0.7; no seed under 0.6 | 0.9304 | 0.9211 (seed 7) | PASS |
| tarn | airborne_share | 0.12 to 0.45 | 0.2362 | 0.232 (seed 6) | PASS |
| tarn | dead_stops | 0 on every seed | 0.0 | 0 (seed 1) | PASS |
| tarn | peak_speed_mps | at least 26.6 m/s (the blazing tier) on every seed | 31.415 | 31.41 (seed 1) | PASS |
| tarn | tier3_s | median at least 3.0 s at the blazing tier | 10.93 | 10.51 (seed 2) | PASS |
| tarn | quiet_max_s | at most 20.0 s | 11.63 | 11.94 (seed 5) | PASS |
| tarn | max_anchor_gap_m | at most 40.0 m | 32.75 | 35.1 (seed 5) | PASS |
| tarn | distinct_verbs | at least 3 different ride facts | 4.0 | 4 (seed 1) | PASS |
| tarn | length_ratio | 1.3 to 2.0 | 1.44 | 1.44 (seed 1) | PASS |
| tarn | Floor-line comparison | measured once, on floor row | N/A | N/A | N/A |
| tally | reached_warden | 8 of 8 seeds | 8 | True (seed 1) | PASS |
| tally | time_to_warden_s | median 60.0 to 120.0 s; no seed over 150.0 s | 79.725 | 80.99 (seed 6) | PASS |
| tally | segment_s | each segment's median 12.0 to 45.0 s | [19.45, 36.72, 23.75] | 37.23 (seed 5) | PASS |
| tally | flow_share | median at least 0.7; no seed under 0.6 | 0.8706 | 0.778 (seed 1) | PASS |
| tally | airborne_share | 0.12 to 0.45 | 0.2575 | 0.2505 (seed 7) | PASS |
| tally | dead_stops | 0 on every seed | 0.0 | 0 (seed 1) | PASS |
| tally | peak_speed_mps | at least 26.6 m/s (the blazing tier) on every seed | 31.135 | 31.13 (seed 3) | PASS |
| tally | tier3_s | median at least 3.0 s at the blazing tier | 7.325 | 7.3 (seed 1) | PASS |
| tally | quiet_max_s | at most 20.0 s | 15.33 | 15.72 (seed 5) | PASS |
| tally | max_anchor_gap_m | at most 40.0 m | 34.0 | 35.6 (seed 3) | PASS |
| tally | distinct_verbs | at least 3 different ride facts | 4.0 | 4 (seed 1) | PASS |
| tally | length_ratio | 1.3 to 2.0 | 1.355 | 1.35 (seed 1) | PASS |
| tally | Floor-line comparison | measured once, on floor row | N/A | N/A | N/A |
| cannon | reached_warden | 8 of 8 seeds | 8 | True (seed 1) | PASS |
| cannon | time_to_warden_s | median 60.0 to 120.0 s; no seed over 150.0 s | 97.635 | 98.99 (seed 1) | PASS |
| cannon | segment_s | each segment's median 12.0 to 45.0 s | [18.12, 39.06, 40.59] | 41.56 (seed 4) | PASS |
| cannon | flow_share | median at least 0.7; no seed under 0.6 | 0.8867 | 0.8653 (seed 1) | PASS |
| cannon | airborne_share | 0.12 to 0.45 | 0.1571 | 0.1541 (seed 4) | PASS |
| cannon | dead_stops | 0 on every seed | 0.0 | 0 (seed 1) | PASS |
| cannon | peak_speed_mps | at least 26.6 m/s (the blazing tier) on every seed | 30.895 | 30.89 (seed 3) | PASS |
| cannon | tier3_s | median at least 3.0 s at the blazing tier | 11.055 | 10.79 (seed 4) | PASS |
| cannon | quiet_max_s | at most 20.0 s | 13.175 | 14.6 (seed 1) | PASS |
| cannon | max_anchor_gap_m | at most 40.0 m | 18.6 | 29.5 (seed 6) | PASS |
| cannon | distinct_verbs | at least 3 different ride facts | 4.0 | 4 (seed 1) | PASS |
| cannon | length_ratio | 1.3 to 2.0 | 1.71 | 1.72 (seed 1) | PASS |
| cannon | Floor-line comparison | measured once, on floor row | N/A | N/A | N/A |
| floor | reached_warden | 8 of 8 seeds | 8 | True (seed 1) | PASS |
| floor | time_to_warden_s | median 60.0 to 120.0 s; no seed over 150.0 s | 90.41 | 93.23 (seed 8) | PASS |
| floor | segment_s | each segment's median 12.0 to 45.0 s | [19.53, 39.41, 31.59] | 42.01 (seed 8) | PASS |
| floor | flow_share | median at least 0.7; no seed under 0.6 | 0.6974 | 0.6039 (seed 3) | REPORTED ONLY |
| floor | airborne_share | 0.12 to 0.45 | 0.1391 | 0.1302 (seed 3) | PASS |
| floor | dead_stops | 0 on every seed | 0.0 | 0 (seed 1) | PASS |
| floor | peak_speed_mps | at least 26.6 m/s (the blazing tier) on every seed | 31.135 | 31.13 (seed 3) | PASS |
| floor | tier3_s | median at least 3.0 s at the blazing tier | 9.75 | 9.36 (seed 3) | PASS |
| floor | quiet_max_s | at most 20.0 s | 12.58 | 14.26 (seed 8) | PASS |
| floor | max_anchor_gap_m | at most 40.0 m | 34.6 | 35.3 (seed 6) | PASS |
| floor | distinct_verbs | at least 3 different ride facts | 4.0 | 4 (seed 1) | PASS |
| floor | length_ratio | 1.3 to 2.0 | 1.45 | 1.44 (seed 1) | PASS |
| floor | floor | reaches the Warden in at most 2.0 times rivet's median time, 0 dead stops | 90.41 | 93.23 (seed 8) | PASS |

Peak speed and blazing time are split into two rows above; PARK.md groups them as one band. Distinct-lines measurement is recorded separately below. Progress is reported only and is now measured by the repaired reader.

Distinct lines, all 8 seeds. Exact 3D nearest-trace-point comparison at 8 m, both directions must be below 0.5.

| Seed | Pair | First share | Second share | Verdict |
| --- | --- | --- | --- | --- |
| 1 | rivet / kest | 0.3354 | 0.3500 | PASS |
| 1 | rivet / tarn | 0.3154 | 0.3720 | PASS |
| 1 | kest / tarn | 0.4081 | 0.4659 | PASS |
| 2 | rivet / kest | 0.3333 | 0.3341 | PASS |
| 2 | rivet / tarn | 0.3142 | 0.3733 | PASS |
| 2 | kest / tarn | 0.4012 | 0.4702 | PASS |
| 3 | rivet / kest | 0.3266 | 0.3354 | PASS |
| 3 | rivet / tarn | 0.3089 | 0.3747 | PASS |
| 3 | kest / tarn | 0.3822 | 0.4603 | PASS |
| 4 | rivet / kest | 0.3282 | 0.3382 | PASS |
| 4 | rivet / tarn | 0.3097 | 0.3726 | PASS |
| 4 | kest / tarn | 0.3968 | 0.4654 | PASS |
| 5 | rivet / kest | 0.3280 | 0.3460 | PASS |
| 5 | rivet / tarn | 0.3099 | 0.3763 | PASS |
| 5 | kest / tarn | 0.4066 | 0.4658 | PASS |
| 6 | rivet / kest | 0.3348 | 0.3501 | PASS |
| 6 | rivet / tarn | 0.3156 | 0.3726 | PASS |
| 6 | kest / tarn | 0.4038 | 0.4742 | PASS |
| 7 | rivet / kest | 0.3392 | 0.3519 | PASS |
| 7 | rivet / tarn | 0.3177 | 0.3757 | PASS |
| 7 | kest / tarn | 0.4034 | 0.4672 | PASS |
| 8 | rivet / kest | 0.3275 | 0.3569 | PASS |
| 8 | rivet / tarn | 0.3122 | 0.3724 | PASS |
| 8 | kest / tarn | 0.4137 | 0.4644 | PASS |

Floor time 90.41 s / all-pilot median 88.24 s = 1.025, limit 2.0.
