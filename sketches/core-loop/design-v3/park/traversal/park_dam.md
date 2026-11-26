# park_dam traversal receipts

> **Historical wave-13/18 traversal receipt:** Preserved measurement log; live park traversal qualification runs via `sketches/core-loop/tests/park_*_test.gd` and `sketches/core-loop/tests/w50_*_test.gd`.

## 2026-10-12: round 5 final greybox

Measured on runtime head `c3c143ed114d1c7194ace87cbd29039b498f0606`, after merge `76757a256dfc31145f92d06dbb105a629c8584fe` of candidate `d8e507777a8c46ef641b5842e04a83116de9bc83`, using the committed traversal tool at fixed 90 FPS through the CPU queue at nice 10. All seven untraced eight-seed batches are complete, 56 rows. The independent PARK.md section 8 audit judges each gated worst seed and each required median. The floor uses its own row with Rivet as reference. Later page edits preserve these runtime inputs, checked by SHA256 across 391 files. Verdict: PASS+NOTES, evidence level 4. Evidence: `/home/andrew/scratch/w13/sol/kd1-dam-r5/final-sweep/`.

| Band | sable | rivet | kest | tarn | tally | cannon | floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| reached_warden | 8 (worst -), PASS | 8 (worst -), PASS | 8 (worst -), PASS | 8 (worst -), PASS | 8 (worst -), PASS | 8 (worst -), PASS | 8 (worst -), PASS |
| time_to_warden_s | 63.48 (worst 64.99), PASS | 80.9 (worst 80.93), PASS | 80.22 (worst 86.43), PASS | 73.87 (worst 75.7), PASS | 80.27 (worst 80.86), PASS | 84.68 (worst 84.82), PASS | 86.57 (worst 86.57), reported, pilot band, not the floor's |
| segment_s | 27.53, 17.24, 18.7 (worst 28.51), PASS | 38.16, 29.26, 13.48 (worst 38.41), PASS | 30.08, 30.89, 19.24 (worst 31.26), PASS | 31.56, 26.13, 16.17 (worst 33.09), PASS | 32.31, 31.23, 16.71 (worst 32.46), PASS | 29.51, 29.22, 25.93 (worst 30.53), PASS | 39.01, 31.84, 15.7 (worst 39.27), reported, pilot band, not the floor's |
| flow_share | 0.9276 (worst 0.9241), PASS | 0.8445 (worst 0.8354), PASS | 0.7691 (worst 0.758), PASS | 0.9687 (worst 0.9433), PASS | 0.8156 (worst 0.7646), PASS | 0.9273 (worst 0.9003), PASS | 0.7684 (worst 0.7684), reported, pilot band, not the floor's |
| airborne_share | 0.2143 (worst 0.2143, 0.2598), PASS | 0.1633 (worst 0.1633, 0.1697), PASS | 0.3 (worst 0.2157, 0.325), PASS | 0.2128 (worst 0.2081, 0.2219), PASS | 0.1636 (worst 0.1636, 0.1681), PASS | 0.1889 (worst 0.1717, 0.1889), PASS | 0.1162 (worst 0.1082, 0.1162), reported, pilot band, not the floor's |
| dead_stops | 0 (worst 0), PASS | 0 (worst 0), PASS | 0 (worst 0), PASS | 0 (worst 0), PASS | 0 (worst 0), PASS | 0 (worst 0), PASS | 0 (worst 0), PASS |
| peak_speed_mps | 52.66 (worst 52.66); tier3 median 47.31 s, PASS | 42.55 (worst 42.49); tier3 median 10.16 s, PASS | 28.29 (worst 27.5); tier3 median 13.52 s, PASS | 39.7 (worst 38.5); tier3 median 12.62 s, PASS | 44.36 (worst 43.98); tier3 median 8.8 s, PASS | 35.74 (worst 35.74); tier3 median 12.44 s, PASS | 42.99 (worst 42.47); tier3 median 11.67 s, reported, pilot band, not the floor's |
| quiet_max_s | 8.41 (worst 8.41), PASS | 12.14 (worst 12.14), PASS | 11.8 (worst 12.31), PASS | 10.5 (worst 10.84), PASS | 12.06 (worst 12.49), PASS | 10.91 (worst 11.82), PASS | 12.53 (worst 12.58), reported, pilot band, not the floor's |
| max_anchor_gap_m | 36.4 (worst 36.4), PASS | 33.2 (worst 33.2), PASS | 36.8 (worst 36.8), PASS | 35.6 (worst 35.6), PASS | 33.7 (worst 33.7), PASS | 35 (worst 35), PASS | 33.1 (worst 33.1), reported, pilot band, not the floor's |
| distinct_verbs | 5 (worst 5), PASS | 6 (worst 6), PASS | 7 (worst 7), PASS | 6 (worst 6), PASS | 6 (worst 6), PASS | 6 (worst 6), PASS | 5 (worst 5), reported, pilot band, not the floor's |
| length_ratio | 1.65 (worst 1.65, 1.69), PASS | 1.33 (worst 1.32, 1.33), PASS | 1.34 (worst 1.34, 1.34), PASS | 1.38 (worst 1.38, 1.38), PASS | 1.32 (worst 1.32, 1.32), PASS | 1.45 (worst 1.45, 1.45), PASS | 1.38 (worst 1.38, 1.38), reported, pilot band, not the floor's |
| floor | - | - | - | - | - | - | 86.57 (worst 86.57); cap 161.8 s, PASS |
| distinct_lines | 4 mutually distinct, PASS | 4 mutually distinct, PASS | 4 mutually distinct, PASS | 4 mutually distinct, PASS | 4 mutually distinct, PASS | 4 mutually distinct, PASS | - |

| Line | time_to_warden_s: max | segment_s: max | flow_share: min | airborne_share: both | dead_stops: max | peak_speed_mps: min | tier3_s: min | quiet_max_s: max | max_anchor_gap_m: max | distinct_ride_facts: min | length_ratio: both |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| sable | 64.99 (seed 3) | 28.51 (seed 3) | 0.9241 (seed 3) | 0.2143 (seed 1,2,4,5,6,7,8) / 0.2598 (seed 3) | 0 (seed 1,2,3,4,5,6,7,8) | 52.66 (seed 1,2,4,5,6,7,8) | 47.18 (seed 3) | 8.41 (seed 1,2,4,5,6,7,8) | 36.4 (seed 1,2,3,4,5,6,7,8) | 5 (seed 1,2,4,5,6,7,8) | 1.65 (seed 1,2,4,5,6,7,8) / 1.69 (seed 3) |
| rivet | 80.93 (seed 4) | 38.41 (seed 4) | 0.8354 (seed 4) | 0.1633 (seed 1,2,3,5,6,7,8) / 0.1697 (seed 4) | 0 (seed 1,2,3,4,5,6,7,8) | 42.49 (seed 4) | 10.16 (seed 1,2,3,5,6,7,8) | 12.14 (seed 1,2,3,5,6,7,8) | 33.2 (seed 1,2,3,4,5,6,7,8) | 6 (seed 1,2,3,4,5,6,7,8) | 1.32 (seed 4) / 1.33 (seed 1,2,3,5,6,7,8) |
| kest | 86.43 (seed 4) | 31.26 (seed 4) | 0.758 (seed 3) | 0.2157 (seed 2) / 0.325 (seed 4) | 0 (seed 1,2,3,4,5,6,7,8) | 27.5 (seed 4) | 2.93 (seed 4) | 12.31 (seed 3) | 36.8 (seed 1,2,3,4,5,6,7,8) | 7 (seed 1,2,3,4,5,6,7,8) | 1.34 (seed 1,2,3,4,5,6,7,8) / 1.34 (seed 1,2,3,4,5,6,7,8) |
| tarn | 75.7 (seed 6) | 33.09 (seed 6) | 0.9433 (seed 6) | 0.2081 (seed 6) / 0.2219 (seed 3,4) | 0 (seed 1,2,3,4,5,6,7,8) | 38.5 (seed 3,4) | 12.62 (seed 1,2,5,7,8) | 10.84 (seed 6) | 35.6 (seed 1,2,3,4,5,6,7,8) | 6 (seed 1,2,3,4,5,6,7,8) | 1.38 (seed 1,2,3,4,5,6,7,8) / 1.38 (seed 1,2,3,4,5,6,7,8) |
| tally | 80.86 (seed 3) | 32.46 (seed 3) | 0.7646 (seed 3) | 0.1636 (seed 1,2,4,5,6,7,8) / 0.1681 (seed 3) | 0 (seed 1,2,3,4,5,6,7,8) | 43.98 (seed 3) | 8.8 (seed 1,2,4,5,6,7,8) | 12.49 (seed 3) | 33.7 (seed 1,2,3,4,5,6,7,8) | 6 (seed 1,2,3,4,5,6,7,8) | 1.32 (seed 1,2,3,4,5,6,7,8) / 1.32 (seed 1,2,3,4,5,6,7,8) |
| cannon | 84.82 (seed 3) | 30.53 (seed 3) | 0.9003 (seed 3) | 0.1717 (seed 3) / 0.1889 (seed 1,2,5,6,7,8) | 0 (seed 1,2,3,4,5,6,7,8) | 35.74 (seed 1,2,5,6,7,8) | 12.44 (seed 1,2,5,6,7,8) | 11.82 (seed 4) | 35 (seed 1,2,3,4,5,6,7,8) | 6 (seed 1,2,5,6,7,8) | 1.45 (seed 1,2,3,4,5,6,7,8) / 1.45 (seed 1,2,3,4,5,6,7,8) |
| floor | 86.57 (seed 1,2,3,5,7,8) | 39.27 (seed 6) | 0.7684 (seed 1,2,3,5,7,8) | 0.1082 (seed 4) / 0.1162 (seed 1,2,3,5,7,8) | 0 (seed 1,2,3,4,5,6,7,8) | 42.47 (seed 4) | 11.47 (seed 4) | 12.58 (seed 6) | 33.1 (seed 1,2,3,4,5,6,7,8) | 5 (seed 1,2,3,4,5,6,7,8) | 1.38 (seed 1,2,3,4,5,6,7,8) / 1.38 (seed 1,2,3,4,5,6,7,8) |

Raw stops: 0 on 56 rows. Terrain stops: 0. Pack stops: 0. The final runs contain no stop to attribute when this count is zero. Any unresolved final stop counts as terrain under ruling 25. The historical failure and full trace remain preserved below and in the round-4 and round-5 folders.

| Stop classification | sable | rivet | kest | tarn | tally | cannon | floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Terrain stops | 0 on every seed | 0 on every seed | 0 on every seed | 0 on every seed | 0 on every seed | 0 on every seed | 0 on every seed |
| Pack stops | 0 on every seed | 0 on every seed | 0 on every seed | 0 on every seed | 0 on every seed | 0 on every seed | 0 on every seed |

### Kest wall-tip repair

The merged pre-repair Kest seed-4 trace reproduces the round-4 terrain stop at tick 7583, 84.224 s, [54.37,0.94,531.97], and matches all 7875 ticks of the retained read-only enemy probe. Ground/Tiles/Tile5_8 is the only contact in the preceding 90 ticks. Inspection of every authored footprint within 40 m and the baked grid identifies `training_wall_east`'s ridge tip: at [52,532] it contributes 4.5 m, while [54,532] has no ridge contribution, a 4.413469 m rise over a 2 m cell after the apron offset. The stop occurs as the 1 m ball turns into this east face. Round 5 shortens this row only, length 65 to 45 m at unchanged [50,502.5], height 8, width 8 and yaw 0. Its end moves from z 535 to 525. The new committed regression checks the recorded approach against the wall footprint with the ball radius; restoring the old tip in a copied input fails that clearance check. The new solo seed 4 has zero stops and matches its eight-seed batch row. Evidence: `cause.json`, `nearby-rows.json`, `red-baked-grid.log`, `green-baked-grid.log`, `baseline-agreement.json`, `f1-committed-red.log`, `f1-stage-green.log`, `green-kest/` and `final-audit.json` in the round-5 folder.

Rivet, Kest and Cannon pass within 60 m of the old wall footprint. All seven lines were rerun; `affected-lines.json` gives the independent segment distances. The six seed-1 traced runs also match the untraced batch summaries and establish the distinct-line count.

### Mounted reactor win proof, round 5

| Seed | Outcome | Engage s | Break s | Engage to break s | Damage | After break |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | stages_done | 169.07 | 347.03 | 177.96 | {'ram': 243.8, 'runner': 54.2, 'slam': 297.9, 'stomp': 54.2} | stage 2, exit 355.62 s |
| 2 | stalled | 169.03 | None | None | {'ram': 243.9, 'slam': 243.9} | stage 1, exit 600.0 s |
| 3 | stalled | 157.49 | None | None | {'slam': 162.6, 'stomp': 162.6} | stage 1, exit 600.01 s |

Every completed seed uses the scratch wrapper with a 600 s stage limit before the first driver tick, through the eight-core CPU queue with an 1800 s TERM timeout and 10 s kill grace. The original serial sequence hit its wall-time cap with seeds 1 and 2 complete, exit 124, so it is INCONCLUSIVE for three seeds. Seed 3 completed separately in a fresh output and XDG folder under the same wrapper, policy and queue. The final proof combines these completed per-seed records, with source paths in final-audit.json; this is not presented as an exact replay of the interrupted child. Every seed must reach and engage under ruling 23. A fight that exceeds the limit belongs to WT-PARK. Ruling 26 requires no `get_rid` error; none occurs in any win log. The Warden row and authored dam-face anchor are unchanged.

## 2026-10-12: Eye OPEN history exception

ddd2be0 added the Eye OPEN control and guard together. The final guards work, but the committed-red order was not met for that commit. The coordinator accepted an explicit exception for round 5: the retained pre-fix scratch red receipts and final mutation evidence stand in for a committed red. Existing commits and mutation receipts remain intact; this exception does not authorize history rewriting or waive the new changes' red-first requirement. Evidence: `/home/andrew/scratch/w13/cgate/kd1-dam-r4/red-history.json`, `f3-parent-state.log`, and `/home/andrew/scratch/w13/sol/kd1-dam-r4/f3-red.log`. The round-4 report's blanket claim that all findings were fixed did not establish the required committed order.

## 2026-10-12: round 4 final greybox, superseded by round 5

Measured on the runtime inputs of merged head `1c3ef9f79b96afabcd418f14ff9eb6f0e832d486` using the committed candidate `tools/traversal_line.gd`, fixed 90 FPS, eight seeds per line, through the CPU queue at nice 10. All 56 rows are complete. Runtime hashes match the final branch; later commits change tests and pages only. This round supersedes earlier measurements. Verdict: FAIL, evidence level 4. Evidence: `/home/andrew/scratch/w13/sol/kd1-dam-r4/final-sweep/`. The floor is judged by its own row, using Rivet's median as the reference.

| Band | sable | rivet | kest | tarn | tally | cannon | floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| reached_warden | 8 (worst -), PASS | 8 (worst -), PASS | 8 (worst -), PASS | 8 (worst -), PASS | 8 (worst -), PASS | 8 (worst -), PASS | 8 (worst -), PASS |
| time_to_warden_s | 63.48 (worst 64.99), PASS | 80.9 (worst 80.93), PASS | 80.22 (worst 87.48), PASS | 73.87 (worst 75.7), PASS | 80.27 (worst 80.86), PASS | 84.69 (worst 84.82), PASS | 86.57 (worst 86.57), reported, pilot band, not the floor's |
| segment_s | 27.53, 17.24, 18.7 (worst 28.51), PASS | 38.16, 29.26, 13.48 (worst 38.41), PASS | 30.08, 30.89, 19.24 (worst 31.26), PASS | 31.56, 26.13, 16.17 (worst 33.09), PASS | 32.31, 31.23, 16.71 (worst 32.46), PASS | 29.51, 29.22, 25.94 (worst 30.53), PASS | 39.01, 31.84, 15.7 (worst 39.27), reported, pilot band, not the floor's |
| flow_share | 0.9276 (worst 0.9241), PASS | 0.8445 (worst 0.8354), PASS | 0.7691 (worst 0.7311), PASS | 0.9687 (worst 0.9433), PASS | 0.8156 (worst 0.7646), PASS | 0.9273 (worst 0.9003), PASS | 0.7684 (worst 0.7684), reported, pilot band, not the floor's |
| airborne_share | 0.2143 (worst 0.2143, 0.2598), PASS | 0.1633 (worst 0.1633, 0.1697), PASS | 0.3 (worst 0.2125, 0.3281), PASS | 0.2128 (worst 0.2081, 0.2219), PASS | 0.1636 (worst 0.1636, 0.1681), PASS | 0.1889 (worst 0.1717, 0.1889), PASS | 0.1162 (worst 0.1082, 0.1162), reported, pilot band, not the floor's |
| dead_stops | 0 (worst 0), PASS | 0 (worst 0), PASS | 0 (worst 1), MISS | 0 (worst 0), PASS | 0 (worst 0), PASS | 0 (worst 0), PASS | 0 (worst 0), PASS |
| peak_speed_mps | 52.66 (worst 52.66); tier3 median 47.31 s, PASS | 42.55 (worst 42.49); tier3 median 10.16 s, PASS | 28.29 (worst 27.5); tier3 median 13.52 s, PASS | 39.7 (worst 38.5); tier3 median 12.62 s, PASS | 44.36 (worst 43.98); tier3 median 8.8 s, PASS | 35.74 (worst 35.74); tier3 median 12.44 s, PASS | 42.99 (worst 42.47); tier3 median 11.67 s, reported, pilot band, not the floor's |
| quiet_max_s | 8.41 (worst 8.41), PASS | 12.14 (worst 12.14), PASS | 11.8 (worst 12.31), PASS | 10.5 (worst 10.84), PASS | 12.06 (worst 12.49), PASS | 10.91 (worst 11.82), PASS | 12.53 (worst 12.58), reported, pilot band, not the floor's |
| max_anchor_gap_m | 36.4 (worst 36.4), PASS | 33.2 (worst 33.2), PASS | 36.8 (worst 36.8), PASS | 35.6 (worst 35.6), PASS | 33.7 (worst 33.7), PASS | 35 (worst 35), PASS | 33.1 (worst 33.1), reported, pilot band, not the floor's |
| distinct_verbs | 5 (worst 5), PASS | 6 (worst 6), PASS | 7 (worst 7), PASS | 6 (worst 6), PASS | 6 (worst 6), PASS | 6 (worst 6), PASS | 5 (worst 5), reported, pilot band, not the floor's |
| length_ratio | 1.65 (worst 1.65, 1.69), PASS | 1.33 (worst 1.32, 1.33), PASS | 1.34 (worst 1.34, 1.35), PASS | 1.38 (worst 1.38, 1.38), PASS | 1.32 (worst 1.32, 1.32), PASS | 1.45 (worst 1.45, 1.45), PASS | 1.38 (worst 1.38, 1.38), reported, pilot band, not the floor's |
| floor | - | - | - | - | - | - | 86.57 (worst 86.57); cap 161.8 s, PASS |
| distinct_lines | 4 mutually distinct, PASS | 4 mutually distinct, PASS | 4 mutually distinct, PASS | 4 mutually distinct, PASS | 4 mutually distinct, PASS | 4 mutually distinct, PASS | - |

| Line | time_to_warden_s: max | segment_s: max | flow_share: min | airborne_share: both | dead_stops: max | peak_speed_mps: min | tier3_s: min | quiet_max_s: max | max_anchor_gap_m: max | distinct_ride_facts: min | length_ratio: both |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| sable | 64.99 (seed 3) | 28.51 (seed 3) | 0.9241 (seed 3) | 0.2143 (seed 1,2,4,5,6,7,8) / 0.2598 (seed 3) | 0 (seed 1,2,3,4,5,6,7,8) | 52.66 (seed 1,2,4,5,6,7,8) | 47.18 (seed 3) | 8.41 (seed 1,2,4,5,6,7,8) | 36.4 (seed 1,2,3,4,5,6,7,8) | 5 (seed 1,2,4,5,6,7,8) | 1.65 (seed 1,2,4,5,6,7,8) / 1.69 (seed 3) |
| rivet | 80.93 (seed 4) | 38.41 (seed 4) | 0.8354 (seed 4) | 0.1633 (seed 1,2,3,5,6,7,8) / 0.1697 (seed 4) | 0 (seed 1,2,3,4,5,6,7,8) | 42.49 (seed 4) | 10.16 (seed 1,2,3,5,6,7,8) | 12.14 (seed 1,2,3,5,6,7,8) | 33.2 (seed 1,2,3,4,5,6,7,8) | 6 (seed 1,2,3,4,5,6,7,8) | 1.32 (seed 4) / 1.33 (seed 1,2,3,5,6,7,8) |
| kest | 87.48 (seed 4) | 31.26 (seed 4) | 0.7311 (seed 3) | 0.2125 (seed 2) / 0.3281 (seed 4) | 1 (seed 4) | 27.5 (seed 4) | 2.93 (seed 4) | 12.31 (seed 3) | 36.8 (seed 1,2,3,4,5,6,7,8) | 7 (seed 1,2,3,4,5,6,7,8) | 1.34 (seed 1,3,4,5,6,7,8) / 1.35 (seed 2) |
| tarn | 75.7 (seed 6) | 33.09 (seed 6) | 0.9433 (seed 6) | 0.2081 (seed 6) / 0.2219 (seed 3,4) | 0 (seed 1,2,3,4,5,6,7,8) | 38.5 (seed 3,4) | 12.62 (seed 1,2,5,7,8) | 10.84 (seed 6) | 35.6 (seed 1,2,3,4,5,6,7,8) | 6 (seed 1,2,3,4,5,6,7,8) | 1.38 (seed 1,2,3,4,5,6,7,8) / 1.38 (seed 1,2,3,4,5,6,7,8) |
| tally | 80.86 (seed 3) | 32.46 (seed 3) | 0.7646 (seed 3) | 0.1636 (seed 1,2,4,5,6,7,8) / 0.1681 (seed 3) | 0 (seed 1,2,3,4,5,6,7,8) | 43.98 (seed 3) | 8.8 (seed 1,2,4,5,6,7,8) | 12.49 (seed 3) | 33.7 (seed 1,2,3,4,5,6,7,8) | 6 (seed 1,2,3,4,5,6,7,8) | 1.32 (seed 1,2,3,4,5,6,7,8) / 1.32 (seed 1,2,3,4,5,6,7,8) |
| cannon | 84.82 (seed 3) | 30.53 (seed 3) | 0.9003 (seed 3) | 0.1717 (seed 3) / 0.1889 (seed 1,2,5,6,7,8) | 0 (seed 1,2,3,4,5,6,7,8) | 35.74 (seed 1,2,5,6,7,8) | 12.44 (seed 1,2,5,6,7,8) | 11.82 (seed 4) | 35 (seed 1,2,3,4,5,6,7,8) | 6 (seed 1,2,5,6,7,8) | 1.45 (seed 1,2,3,4,5,6,7,8) / 1.45 (seed 1,2,3,4,5,6,7,8) |
| floor | 86.57 (seed 1,2,3,5,7,8) | 39.27 (seed 6) | 0.7684 (seed 1,2,3,5,7,8) | 0.1082 (seed 4) / 0.1162 (seed 1,2,3,5,7,8) | 0 (seed 1,2,3,4,5,6,7,8) | 42.47 (seed 4) | 11.47 (seed 4) | 12.58 (seed 6) | 33.1 (seed 1,2,3,4,5,6,7,8) | 5 (seed 1,2,3,4,5,6,7,8) | 1.38 (seed 1,2,3,4,5,6,7,8) / 1.38 (seed 1,2,3,4,5,6,7,8) |

Raw stops: 1 on 56 rows. Terrain stops: 1. Pack stops: 0.

kest seed 4: terrain stop at 84.224 s, [54.37, 0.94, 531.97]. Trace contacts at the stop: ['/root/Game/Stage1/Ground/Tiles/Tile5_8']. Enemy contacts in the preceding 90 ticks: []. The probe matches 7583 ticks through the stop, full trace equality=True. An unattributed stop counts as terrain under ruling 25; this does not claim a particular obstructing row. Evidence: stop-trace/, stop-probe/, stop-classification.json.

| Stop classification | sable | rivet | kest | tarn | tally | cannon | floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Terrain stops | 0 on every seed | 0 on every seed | 1 at seed 4, 84.224 s | 0 on every seed | 0 on every seed | 0 on every seed | 0 on every seed |
| Pack stops | 0 on every seed | 0 on every seed | 0 on every seed | 0 on every seed | 0 on every seed | 0 on every seed | 0 on every seed |

The six seed-1 solo summaries, Sable seed 4 and Kest seed 4 match their batch rows with identical runtime inputs. The traced seed-1 runs establish distinct lines by comparing XYZ tick positions in both directions.

### Mounted reactor win proof

| Seed | Outcome | Engage s | Break s | Engage to break s | Damage | After break |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | stalled | 169.07 | None | None | {'runner': 54.2, 'slam': 379.2, 'stomp': 54.2} | stage 1, exit 600.0 s |
| 2 | stages_done | 163.39 | 372.68 | 209.29 | {'ram': 81.3, 'slam': 487.6, 'stomp': 81.3} | stage 2, exit 380.58 s |
| 3 | stalled | 157.49 | None | None | {'ram': 81.3, 'slam': 325.1, 'stomp': 81.3} | stage 1, exit 600.01 s |

The scratch wrapper sets the stage limit to 600 s before every driver tick. The mounted reactor fights from its authored dam-face anchor. All seeds must reach and engage under ruling 23; fight-duration tuning belongs to WT-PARK. No `get_rid` error appeared.

## 2026-10-12: authorized ledge exception

The coordinator authorized `cliff_rooms_west` at [-165,330] as this stage's one ledge repair. The pre-repair Sable seed-4 run reproduced a 62.9 m anchor gap. The graph comparison records 314008 edges for the vent-only counterfactual and 314061 edges with the ledge repair. That difference is authorized under `kd-round-common.md` step 2; the vent-only restriction does not govern the final candidate. Round 4 retains both coordinate changes and rebuilds with the merged candidate tools. Fresh round-4 measurements supersede the round-3 acceptance table below.

## 2026-10-12: round 3 greybox, superseded by round 4

Measured on greybox head `3e58f96c803861f485af09416449b09c8f741fd4` with the SHA256-verified TRAV-DET export, eight seeds per line at fixed 90 FPS, through the CPU queue at nice 10. All 56 batch rows are complete. Final documentary commits preserve these runtime inputs. Evidence: `/home/andrew/scratch/w13/sol/kd1-dam-r3/final-sweep/`. Verdict: PASS+NOTES, evidence level 4. The anchor gap uses the worst seed. The floor is judged by its own row; other floor cells are reported.

| Band | sable | rivet | kest | tarn | tally | cannon | floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| reached_warden | 8 (worst -), PASS | 8 (worst -), PASS | 8 (worst -), PASS | 8 (worst -), PASS | 8 (worst -), PASS | 8 (worst -), PASS | 8 (worst -), PASS |
| time_to_warden_s | 63.48 (worst 64.99), PASS | 80.9 (worst 80.93), PASS | 80.22 (worst 86.87), PASS | 74.195 (worst 75.7), PASS | 80.565 (worst 84.15), PASS | 84.69 (worst 84.82), PASS | 86.57 (worst 86.57), reported, pilot band, not the floor's |
| segment_s | 27.53, 17.24, 18.7 (worst 29.05), PASS | 38.16, 29.26, 13.48 (worst 38.41), PASS | 30.08, 30.89, 19.24 (worst 30.89), PASS | 31.6, 26.2, 16.2 (worst 33.09), PASS | 32.31, 31.23, 16.74 (worst 33.15), PASS | 29.51, 29.22, 25.94 (worst 30.53), PASS | 39.01, 31.84, 15.7 (worst 39.27), reported, pilot band, not the floor's |
| flow_share | 0.9276 (worst 0.9241), PASS | 0.8445 (worst 0.8354), PASS | 0.7691 (worst 0.7311), PASS | 0.9673 (worst 0.9433), PASS | 0.7901 (worst 0.689), PASS | 0.9273 (worst 0.9003), PASS | 0.7684 (worst 0.7684), reported, pilot band, not the floor's |
| airborne_share | 0.2143 (worst 0.2143, 0.278), PASS | 0.1633 (worst 0.1633, 0.1697), PASS | 0.3 (worst 0.2048, 0.3242), PASS | 0.2128 (worst 0.2081, 0.2219), PASS | 0.1636 (worst 0.1509, 0.1681), PASS | 0.1889 (worst 0.1577, 0.1889), PASS | 0.1162 (worst 0.1082, 0.1162), reported, pilot band, not the floor's |
| dead_stops | 0 (worst 0), PASS | 0 (worst 0), PASS | 0 (worst 0), PASS | 0 (worst 0), PASS | 0 (worst 0), PASS | 0 (worst 0), PASS | 0 (worst 0), PASS |
| peak_speed_mps | 52.66 (worst 52.66); tier3 median 47.31 s, PASS | 42.55 (worst 42.49); tier3 median 10.16 s, PASS | 28.29 (worst 28.03); tier3 median 13.52 s, PASS | 39.7 (worst 38.5); tier3 median 12.825 s, PASS | 44.36 (worst 43.98); tier3 median 8.8 s, PASS | 35.74 (worst 35.74); tier3 median 12.44 s, PASS | 42.99 (worst 42.47); tier3 median 11.67 s, reported, pilot band, not the floor's |
| quiet_max_s | 8.41 (worst 8.41), PASS | 12.14 (worst 12.14), PASS | 11.8 (worst 12.31), PASS | 10.5 (worst 10.84), PASS | 12.275 (worst 13.27), PASS | 10.91 (worst 11.59), PASS | 12.53 (worst 12.58), reported, pilot band, not the floor's |
| max_anchor_gap_m | 36.4 (worst 36.4), PASS | 33.2 (worst 33.2), PASS | 36.8 (worst 36.8), PASS | 35.6 (worst 35.6), PASS | 33.7 (worst 33.7), PASS | 35 (worst 35), PASS | 33.1 (worst 33.1), reported, pilot band, not the floor's |
| distinct_verbs | 5 (worst 5), PASS | 6 (worst 6), PASS | 7 (worst 7), PASS | 6 (worst 6), PASS | 6 (worst 6), PASS | 6 (worst 6), PASS | 5 (worst 5), reported, pilot band, not the floor's |
| length_ratio | 1.65 (worst 1.63, 1.69), PASS | 1.33 (worst 1.32, 1.33), PASS | 1.34 (worst 1.34, 1.35), PASS | 1.38 (worst 1.38, 1.38), PASS | 1.32 (worst 1.32, 1.33), PASS | 1.45 (worst 1.45, 1.45), PASS | 1.38 (worst 1.38, 1.38), reported, pilot band, not the floor's |
| floor | - | - | - | - | - | - | 86.57 (worst 86.57); cap 161.8 s, PASS |
| distinct_lines | 4 mutually distinct, PASS | 4 mutually distinct, PASS | 4 mutually distinct, PASS | 4 mutually distinct, PASS | 4 mutually distinct, PASS | 4 mutually distinct, PASS | - |

| Line | time_to_warden_s: max | segment_s: max | flow_share: min | airborne_share: both | dead_stops: max | peak_speed_mps: min | tier3_s: min | quiet_max_s: max | max_anchor_gap_m: max | distinct_ride_facts: min | length_ratio: both |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| sable | 64.99 (seed 3) | 29.05 (seed 4) | 0.9241 (seed 3) | 0.2143 (seed 1,5,6,7,8) / 0.278 (seed 4) | 0 (seed 1,2,3,4,5,6,7,8) | 52.66 (seed 1,5,6,7,8) | 47.18 (seed 3) | 8.41 (seed 1,5,6,7,8) | 36.4 (seed 1,2,3,4,5,6,7,8) | 5 (seed 1,2,5,6,7,8) | 1.63 (seed 2) / 1.69 (seed 3) |
| rivet | 80.93 (seed 4) | 38.41 (seed 4) | 0.8354 (seed 4) | 0.1633 (seed 1,2,3,5,6,7,8) / 0.1697 (seed 4) | 0 (seed 1,2,3,4,5,6,7,8) | 42.49 (seed 4) | 10.16 (seed 1,2,3,5,6,7,8) | 12.14 (seed 1,2,3,5,6,7,8) | 33.2 (seed 1,2,3,4,5,6,7,8) | 6 (seed 1,2,3,4,5,6,7,8) | 1.32 (seed 4) / 1.33 (seed 1,2,3,5,6,7,8) |
| kest | 86.87 (seed 3) | 30.89 (seed 1,5,6,7,8) | 0.7311 (seed 3) | 0.2048 (seed 4) / 0.3242 (seed 3) | 0 (seed 1,2,3,4,5,6,7,8) | 28.03 (seed 3) | 2.97 (seed 3) | 12.31 (seed 3) | 36.8 (seed 1,2,3,4,5,6,7,8) | 7 (seed 1,2,3,4,5,6,7,8) | 1.34 (seed 1,3,5,6,7,8) / 1.35 (seed 2,4) |
| tarn | 75.7 (seed 6) | 33.09 (seed 6) | 0.9433 (seed 6) | 0.2081 (seed 6) / 0.2219 (seed 2,3,4) | 0 (seed 1,2,3,4,5,6,7,8) | 38.5 (seed 2,3,4) | 12.62 (seed 1,5,7,8) | 10.84 (seed 6) | 35.6 (seed 1,2,3,4,5,6,7,8) | 6 (seed 1,2,3,4,5,6,7,8) | 1.38 (seed 1,2,3,4,5,6,7,8) / 1.38 (seed 1,2,3,4,5,6,7,8) |
| tally | 84.15 (seed 7) | 33.15 (seed 7) | 0.689 (seed 7) | 0.1509 (seed 7) / 0.1681 (seed 1,3) | 0 (seed 1,2,3,4,5,6,7,8) | 43.98 (seed 1,3) | 8.73 (seed 5) | 13.27 (seed 7) | 33.7 (seed 1,2,3,4,5,6,7,8) | 6 (seed 1,2,3,4,5,6,7,8) | 1.32 (seed 1,2,3,4,5,6,8) / 1.33 (seed 7) |
| cannon | 84.82 (seed 3) | 30.53 (seed 3) | 0.9003 (seed 3) | 0.1577 (seed 2) / 0.1889 (seed 1,5,6,7,8) | 0 (seed 1,2,3,4,5,6,7,8) | 35.74 (seed 1,5,6,7,8) | 12.44 (seed 1,5,6,7,8) | 11.59 (seed 3) | 35 (seed 1,2,3,4,5,6,7,8) | 6 (seed 1,5,6,7,8) | 1.45 (seed 1,2,3,4,5,6,7,8) / 1.45 (seed 1,2,3,4,5,6,7,8) |
| floor | 86.57 (seed 1,2,3,5,7,8) | 39.27 (seed 6) | 0.7684 (seed 1,2,3,5,7,8) | 0.1082 (seed 4) / 0.1162 (seed 1,2,3,5,7,8) | 0 (seed 1,2,3,4,5,6,7,8) | 42.47 (seed 4) | 11.47 (seed 4) | 12.58 (seed 6) | 33.1 (seed 1,2,3,4,5,6,7,8) | 5 (seed 1,2,3,4,5,6,7,8) | 1.38 (seed 1,2,3,4,5,6,7,8) / 1.38 (seed 1,2,3,4,5,6,7,8) |

Terrain stops: 0 on all 56 rows. Pack stops: 0 on all 56 rows. No stop was excluded or waived.

| Stop classification | sable | rivet | kest | tarn | tally | cannon | floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Terrain stops | 0 on every seed | 0 on every seed | 0 on every seed | 0 on every seed | 0 on every seed | 0 on every seed | 0 on every seed |
| Pack stops | 0 on every seed | 0 on every seed | 0 on every seed | 0 on every seed | 0 on every seed | 0 on every seed | 0 on every seed |

The first bounded canyon repair moves the existing `cliff_rooms_west` ledge from [-190,330] to [-165,330]. Sable seed 4 reproduces the initial 62.9 m gap solo with identical input hashes and identical summary values. On the repaired head its batch gap is 36.4 m. No new hook rock, recipe chain or pilot line was added.

## 2026-10-12: merged-kit baseline

Measured on merged head `cd3a9bf`, which contains candidate `6710ac0` and admitted greybox `f58699e`. The park file is unchanged from the admitted greybox, SHA256 `99ce445c21b848f486e5d487c021895d3d6a2039cdf4736324d12fd55de20a4e`; its graph was rebuilt with the candidate's tool before these runs. Evidence: `/tmp/claude-1000/w13-sol/kd1-dam-r1/merged-baseline/`, seven lines, eight seeds each, one Godot process at a time at nice 10. This table separates the kit merge's effect from the subsequent anchor repair and dressed geometry.

Cells show median and worst seed, or observed range for airborne share and length ratio. The anchor band judges the worst seed, regardless of the tool's median verdict. The floor judges its own row only: all eight seeds must reach within twice Rivet's median and have zero dead stops. Other floor cells are reported. Peak speed and tier-3 duration share one band row. Distinct lines uses all six seed-1 traces, with the conservative maximum of both directions' tick overlap within 8 m.

| Band | sable | rivet | kest | tarn | tally | cannon | floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| reached_warden | 8 (worst -), PASS | 8 (worst -), PASS | 8 (worst -), PASS | 8 (worst -), PASS | 8 (worst -), PASS | 8 (worst -), PASS | 8 (worst -), PASS |
| time_to_warden_s | 62.03 (worst 66.86), PASS | 81.835 (worst 82.29), PASS | 83.755 (worst 86.02), PASS | 74.72 (worst 76.1), PASS | 81.07 (worst 82.3), PASS | 84.39 (worst 85.07), PASS | 85.98 (worst 87.16), reported, pilot band, not the floor's |
| segment_s | 27.65, 17.12, 17.31 (worst 29.71), PASS | 38.29, 29.59, 13.49 (worst 39.38), PASS | 30.37, 30.55, 22.38 (worst 30.89), PASS | 31.63, 26.62, 16.31 (worst 33.18), PASS | 31.94, 31.26, 17.17 (worst 33.56), PASS | 29.54, 29.6, 25.21 (worst 30.84), PASS | 38.7, 31.42, 15.85 (worst 39.62), reported, pilot band, not the floor's |
| flow_share | 0.939 (worst 0.92), PASS | 0.8348 (worst 0.7978), PASS | 0.7681 (worst 0.7012), PASS | 0.9673 (worst 0.9432), PASS | 0.7601 (worst 0.6945), PASS | 0.9286 (worst 0.9), PASS | 0.7817 (worst 0.7468), reported, pilot band, not the floor's |
| airborne_share | 0.2486 (worst 0.2153, 0.2756), PASS | 0.1633 (worst 0.1589, 0.1746), PASS | 0.2832 (worst 0.206, 0.3263), PASS | 0.2158 (worst 0.2111, 0.2318), PASS | 0.1643 (worst 0.1566, 0.1695), PASS | 0.1751 (worst 0.163, 0.1916), PASS | 0.1148 (worst 0.1051, 0.1207), reported, pilot band, not the floor's |
| dead_stops | 0 (worst 0), PASS | 0 (worst 0), PASS | 0 (worst 0), PASS | 0 (worst 0), PASS | 0 (worst 0), PASS | 0 (worst 0), PASS | 0 (worst 0), PASS |
| peak_speed_mps | 54.115 (worst 52.66); tier3 median 47.525 s, PASS | 42.625 (worst 42.28); tier3 median 10.325 s, PASS | 31.65 (worst 27.61); tier3 median 5.935 s, PASS | 39.595 (worst 38.06); tier3 median 12.995 s, PASS | 44.58 (worst 43.61); tier3 median 8.9 s, PASS | 36.67 (worst 35.18); tier3 median 12.155 s, PASS | 42.7 (worst 42.18); tier3 median 11.44 s, reported, pilot band, not the floor's |
| quiet_max_s | 8.25 (worst 8.41), PASS | 12.215 (worst 13), PASS | 11.8 (worst 12.13), PASS | 10.515 (worst 10.88), PASS | 12.345 (worst 13.3), PASS | 10.91 (worst 11.59), PASS | 12.255 (worst 12.82), reported, pilot band, not the floor's |
| max_anchor_gap_m | 36.4 (worst 45.3), MISS | 33.2 (worst 33.2), PASS | 36.8 (worst 36.8), PASS | 35.6 (worst 35.6), PASS | 33.7 (worst 38.8), PASS | 35 (worst 35), PASS | 33.1 (worst 33.1), reported, pilot band, not the floor's |
| distinct_verbs | 5.5 (worst 5), PASS | 6 (worst 6), PASS | 7 (worst 7), PASS | 6 (worst 6), PASS | 6 (worst 6), PASS | 6.5 (worst 6), PASS | 5 (worst 5), reported, pilot band, not the floor's |
| length_ratio | 1.64 (worst 1.63, 1.7), PASS | 1.325 (worst 1.32, 1.33), PASS | 1.34 (worst 1.33, 1.36), PASS | 1.38 (worst 1.38, 1.39), PASS | 1.32 (worst 1.31, 1.33), PASS | 1.45 (worst 1.44, 1.45), PASS | 1.38 (worst 1.38, 1.38), reported, pilot band, not the floor's |
| floor | - | - | - | - | - | - | 85.98 (worst 87.16); cap 163.67 s, PASS |
| distinct_lines | 4 mutually distinct, PASS | 4 mutually distinct, PASS | 4 mutually distinct, PASS | 4 mutually distinct, PASS | 4 mutually distinct, PASS | 4 mutually distinct, PASS | - |

Known miss: Sable seed 7 has a 45.3 m anchor gap. All other pilot bands and the floor row pass. The four mutually distinct lines are Sable, Rivet, Kest and Tally.

## Earlier receipts

The following tables retain the earlier measured numbers. Their headers identify earlier inputs; they are historical evidence. The floor labels now follow ruling 13. Earlier anchor passes on medians do not qualify ruling 14.

# Traversal table: park_dam (world 1, stage 1)

The bands are PARK.md section 8. Each line ran 8 seeds (1 to 8) through `tools/traversal_line.gd -- --table=park --stage=1` at `--fixed-fps 90`; the waypoints are `assets/park/park_dam/lines.json`. Each cell gives the median, the worst seed in brackets, and pass or miss.

## Greybox fix round, 2026-10-12 (superseded by round 3)

Measured on the shipped park file (`park_sha256` 99ce445c in `assets/park/park_dam/graph.json`) with the tool on head 1b2cb49 plus this round's working tree. Two changes since the 2026-10-11 pass. First, `saguaro_26` fills the bare strip south of the drop (the density rule). Second, the floor line's last stretch now takes the bucket flight (spillway tunnel, `outlet_bucket` kicker, plunge pool) in place of the centre incline. All seven lines ran again, one process at a time, at a 1-minute load of 10 to 31.

| Band | sable | rivet | kest | tarn | tally | cannon | floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Reached the Warden (8 of 8) | 8, pass | 8, pass | 8, pass | 8, pass | 8, pass | 8, pass | 8, pass |
| Time to Warden, s (median 60 to 120, no seed over 150) | 62.62 (worst 65.09), pass | 81.835 (worst 82.29), pass | 83.755 (worst 86.02), pass | 74.72 (worst 76.1), pass | 81.07 (worst 82.3), pass | 84.25 (worst 85.69), pass | 85.98 (worst 87.16), reported, pilot band, not the floor's |
| Segment medians, s (each 12 to 45) | 27.65/17.08/17.63 (worst 27.65), pass | 38.29/29.59/13.49 (worst 38.29), pass | 30.37/30.55/22.38 (worst 30.65), pass | 31.63/26.62/16.31 (worst 31.63), pass | 31.94/31.26/17.17 (worst 32.27), pass | 29.54/29.48/25.28 (worst 29.735), pass | 38.7/31.42/15.85 (worst 38.7), reported, pilot band, not the floor's |
| Flow share (median 0.70, no seed under 0.60) | 0.9362 (worst 0.9305), pass | 0.8348 (worst 0.7978), pass | 0.7681 (worst 0.7012), pass | 0.9673 (worst 0.9432), pass | 0.7601 (worst 0.6945), pass | 0.9345 (worst 0.9), pass | 0.7817 (worst 0.7468), reported, pilot band, not the floor's |
| Airborne share (0.12 to 0.45) | 0.2453, pass | 0.1633, pass | 0.2832, pass | 0.2158, pass | 0.1643, pass | 0.1704, pass | 0.1148, reported, pilot band, not the floor's |
| Dead stops (0 every seed) | 0.0 (worst 0.0), pass | 0.0 (worst 0.0), pass | 0.0 (worst 0.0), pass | 0.0 (worst 0.0), pass | 0.0 (worst 0.0), pass | 0.0 (worst 0.0), pass | 0.0 (worst 0.0), pass |
| Peak speed, m/s (26.6 every seed) | 53.835 (worst 52.58), pass | 42.625 (worst 42.28), pass | 31.65 (worst 27.61), pass | 39.595 (worst 38.06), pass | 44.58 (worst 43.61), pass | 36.545 (worst 35.54), pass | 42.7 (worst 42.18), reported, pilot band, not the floor's |
| Blazing tier, s (median at least 3) | 47.37, pass | 10.325, pass | 5.935, pass | 12.995, pass | 8.9, pass | 12.665, pass | 11.44, reported, pilot band, not the floor's |
| Quiet stretch, s (at most 20) | 8.29 (worst 8.41), pass | 12.215 (worst 13.0), pass | 11.8 (worst 12.13), pass | 10.515 (worst 10.88), pass | 12.345 (worst 13.3), pass | 10.91 (worst 11.59), pass | 12.255 (worst 12.82), reported, pilot band, not the floor's |
| Max anchor gap, m (at most 40) | 36.4 (worst 41.2), pass | 33.2 (worst 33.2), pass | 36.8 (worst 36.8), pass | 35.6 (worst 35.6), pass | 33.7 (worst 38.8), pass | 35.0 (worst 35.0), pass | 33.1 (worst 33.1), reported, pilot band, not the floor's |
| Distinct ride facts, PARK.md section 4 set (at least 3) | 5.5 (worst 5.0), pass | 6.0 (worst 6.0), pass | 7.0 (worst 7.0), pass | 6.0 (worst 6.0), pass | 6.0 (worst 6.0), pass | 7.0 (worst 6.0), pass | 5.0 (worst 5.0), reported, pilot band, not the floor's |
| Length ratio (1.3 to 2.0) | 1.645, pass | 1.325, pass | 1.34, pass | 1.38, pass | 1.32, pass | 1.45, pass | 1.38, reported, pilot band, not the floor's |
| Floor line (at most 2.0 times the pilot median, 0 dead stops) | - | - | - | - | - | - | median 85.98 s against Rivet's 81.84 s, ratio 1.05, 0 dead stops, pass |
| Distinct lines (at least 3 across the six pilots) | 3 or more (unchanged waypoints since the 2026-10-11 traces), pass | (stage) | (stage) | (stage) | (stage) | (stage) | (stage), reported, pilot band, not the floor's |
| Progress, m/s of d_landmark (reported, no band) | 21.075 | 16.125 | 15.78 | 17.64 | 16.295 | 15.63 | 15.33, reported, pilot band, not the floor's |

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
| Time to Warden, s (median 60 to 120, no seed over 150) | 62.62 (worst 65.09), pass | 81.835 (worst 82.29), pass | 83.755 (worst 86.02), pass | 74.72 (worst 76.1), pass | 80.96 (worst 82.3), pass | 84.25 (worst 85.69), pass | 82.725 (worst 83.86), reported, pilot band, not the floor's |
| Segment medians, s (each 12 to 45) | 27.65/17.08/17.63 (worst 27.65), pass | 38.29/29.59/13.49 (worst 38.29), pass | 30.37/30.55/22.38 (worst 30.65), pass | 31.63/26.62/16.31 (worst 31.63), pass | 31.94/31.26/17.27 (worst 32.13), pass | 29.54/29.48/25.28 (worst 29.735), pass | 38.7/31.42/12.53 (worst 38.7), reported, pilot band, not the floor's |
| Flow share (median 0.70, no seed under 0.60) | 0.9362 (worst 0.9305), pass | 0.8348 (worst 0.7978), pass | 0.7681 (worst 0.7012), pass | 0.9673 (worst 0.9432), pass | 0.7605 (worst 0.6945), pass | 0.9345 (worst 0.9), pass | 0.7732 (worst 0.7368), reported, pilot band, not the floor's |
| Airborne share (0.12 to 0.45) | 0.2453, pass | 0.1633, pass | 0.2832, pass | 0.2158, pass | 0.1653, pass | 0.1704, pass | 0.1092, reported, pilot band, not the floor's |
| Dead stops (0 every seed) | 0.0 (worst 0.0), pass | 0.0 (worst 0.0), pass | 0.0 (worst 0.0), pass | 0.0 (worst 0.0), pass | 0.0 (worst 0.0), pass | 0.0 (worst 0.0), pass | 0.0 (worst 0.0), pass |
| Peak speed, m/s (26.6 every seed) | 53.835 (worst 52.58), pass | 42.625 (worst 42.28), pass | 31.65 (worst 27.61), pass | 39.595 (worst 38.06), pass | 44.375 (worst 43.61), pass | 36.545 (worst 35.54), pass | 43.6 (worst 42.54), reported, pilot band, not the floor's |
| Blazing tier, s (median at least 3) | 47.37, pass | 10.325, pass | 5.935, pass | 12.995, pass | 8.945, pass | 12.665, pass | 9.59, reported, pilot band, not the floor's |
| Quiet stretch, s (at most 20) | 8.29 (worst 8.41), pass | 12.215 (worst 13.0), pass | 11.8 (worst 12.13), pass | 10.515 (worst 10.88), pass | 12.345 (worst 13.3), pass | 10.91 (worst 11.59), pass | 12.255 (worst 12.82), reported, pilot band, not the floor's |
| Max anchor gap, m (at most 40) | 36.4 (worst 41.2), pass | 33.2 (worst 33.2), pass | 36.8 (worst 36.8), pass | 35.6 (worst 35.6), pass | 33.7 (worst 38.8), pass | 35.0 (worst 35.0), pass | 33.1 (worst 33.1), reported, pilot band, not the floor's |
| Distinct ride facts, PARK.md section 4 set (at least 3) | 5.5 (worst 5.0), pass | 6.0 (worst 6.0), pass | 7.0 (worst 7.0), pass | 6.0 (worst 6.0), pass | 6.0 (worst 6.0), pass | 7.0 (worst 6.0), pass | 5.0 (worst 5.0), reported, pilot band, not the floor's |
| Length ratio (1.3 to 2.0) | 1.645, pass | 1.325, pass | 1.34, pass | 1.38, pass | 1.32, pass | 1.45, pass | 1.32, reported, pilot band, not the floor's |
| Floor line (at most 2.0 times the pilot median, 0 dead stops) | - | - | - | - | - | - | reaches the Warden in at most 2.0 times rivet's median time, 0 dead stops: median 82.725, worst 163.67, pass |
| Distinct lines (at least 3 across the six pilots) | 3 or more (seed 1 traces: sable, rivet and kest mutually distinct; rivet and tarn share; tally and cannon not traced), pass | (stage) | (stage) | (stage) | (stage) | (stage) | (stage), reported, pilot band, not the floor's |
| Progress, m/s of d_landmark (reported, no band) | 21.075 | 16.125 | 15.78 | 17.64 | 16.32 | 15.63 | 15.93, reported, pilot band, not the floor's |

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
| Time to Warden, s (median 60 to 120, no seed over 150) | 62.225 (worst 126.74), pass | 81.89 (worst 82.51), pass | 83.515 (worst 87.63), pass | 74.7 (worst 75.26), pass | 81.51 (worst 83.52), pass | 87.71 (worst 91.02), pass | 82.715 (worst 83.37), reported, pilot band, not the floor's |
| Segment medians, s (each 12 to 45) | 29.24/18.14/14.23 (worst 29.24), pass | 38.86/30.16/13.07 (worst 38.86), pass | 30.45/30.62/22.46 (worst 30.62), pass | 31.7/26.52/16.34 (worst 31.705), pass | 32.54/31.7/17.75 (worst 32.54), pass | 29.48/29.68/28.4 (worst 29.9), pass | 38.73/31.8/12.17 (worst 38.73), reported, pilot band, not the floor's |
| Flow share (median 0.70, no seed under 0.60) | 0.966 (worst 0.8816), pass | 0.82 (worst 0.7945), pass | 0.7286 (worst 0.7036), pass | 0.9693 (worst 0.9426), pass | 0.7281 (worst 0.6795), pass | 0.908 (worst 0.8908), pass | 0.7665 (worst 0.7427), reported, pilot band, not the floor's |
| Airborne share (0.12 to 0.45) | 0.2577, pass | 0.1606, pass | 0.2123, pass | 0.2146, pass | 0.1633, pass | 0.1588, pass | 0.0936, reported, pilot band, not the floor's |
| Dead stops (0 every seed) | 0.0 (worst 1.0), MISS | 0.0 (worst 0.0), pass | 0.0 (worst 0.0), pass | 0.0 (worst 0.0), pass | 0.0 (worst 0.0), pass | 0.0 (worst 0.0), pass | 0.0 (worst 0.0), pass |
| Peak speed, m/s (26.6 every seed) | 54.95 (worst 54.37), pass | 42.85 (worst 42.08), pass | 34.355 (worst 28.05), pass | 40.025 (worst 39.11), pass | 43.93 (worst 43.59), pass | 35.8 (worst 32.34), pass | 43.63 (worst 42.9), reported, pilot band, not the floor's |
| Blazing tier, s (median 3) | 49.27, pass | 10.45, pass | 6.255, pass | 12.805, pass | 9.0, pass | 9.03, pass | 9.67, reported, pilot band, not the floor's |
| Quiet stretch, s (at most 20) | 6.69 (worst 6.69), pass | 6.69 (worst 6.69), pass | 6.69 (worst 6.69), pass | 6.69 (worst 6.69), pass | 6.69 (worst 6.69), pass | 6.69 (worst 6.69), pass | 6.69 (worst 6.69), reported, pilot band, not the floor's |
| Max anchor gap, m (at most 40) | 36.4 (worst 39.6), pass | 33.2 (worst 33.2), pass | 36.8 (worst 36.8), pass | 35.6 (worst 35.6), pass | 33.7 (worst 38.3), pass | 35.0 (worst 35.0), pass | 33.1 (worst 33.1), reported, pilot band, not the floor's |
| Distinct ride facts, tool count (at least 3) | 3.0 (worst 2.0), pass | 3.0 (worst 3.0), pass | 4.0 (worst 4.0), pass | 3.0 (worst 3.0), pass | 3.0 (worst 3.0), pass | 4.0 (worst 4.0), pass | 2.0 (worst 2.0), reported, pilot band, not the floor's |
| Length ratio (1.3 to 2.0) | 1.68, pass | 1.32, pass | 1.35, pass | 1.38, pass | 1.32, pass | 1.45, pass | 1.32, reported, pilot band, not the floor's |
| Distinct ride facts after KB7b (lift_fired, wall_crumbled, crater_ride out; at least 3) | 2 (kicker_launch, ride_grapple_line), MISS | 2 (kicker_launch, ride_grapple_line), MISS | 2 (kicker_launch, ride_grapple_line), MISS | 2 (kicker_launch, ride_grapple_line), MISS | 2 (kicker_launch, ride_grapple_line), MISS | 2 (kicker_launch, ride_grapple_line), MISS | 1 (kicker_launch), reported, pilot band, not the floor's |
| Progress | not measured (KB7b, R12) | not measured (KB7b, R12) | not measured (KB7b, R12) | not measured (KB7b, R12) | not measured (KB7b, R12) | not measured (KB7b, R12) | not measured (KB7b, R12), reported, pilot band, not the floor's |

Floor line: median 82.72 s against Rivet's 81.89 s, ratio 1.01 (band at most 2.0); dead stops median 0.0, worst 0.0 (band 0): pass.

Notes on the open cells:

- Sable's dead stops: one stop on seed 4 and one on seed 6, both on the shelf A loop. A second cut of the loop (one stop on seed 3) dropped the line's distinct ride facts to 2, so the shipped cut is the first.
- The floor line's airborne share and distinct ride facts are listed for completeness. The floor's own band is reaching the Warden within 2.0 times the pilot median with no dead stop, and it passes.
- Distinct ride facts after KB7b: every row's ride sensor (`ride_chute`, `ride_bowl`, `ride_drop`, `ride_ledge`, `ride_hop`) comes from `ParkRecipes.place`, and nothing calls it at runtime on this head, so only contraption facts and kicker launches count. With `lift_fired` out, every line reaches 2 at most. Placing the row sensors is a loader change, out of this unit's scope.
- Progress is not measured: `traversal_line.gd` reads the stage graph into an empty instance (R12, KB7b).
