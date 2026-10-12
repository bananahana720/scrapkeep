# Traversal bands: park_sinkhole (stage 4)

PARK.md section 8 bands, measured with `tools/traversal_line.gd` (KB7, with KB7b's park ride-fact set and graph access) on the park table, stage 4, seeds 1 to 8 per line, `--fixed-fps 90`. Each pass has its own dated table (R8). The coordinator's index is TRAVERSAL-PARK.md.

## Greybox pass, fix round, 2026-10-12 (KD4, on 3f6a780 over b0e4490)

Park file `src/world/park/park_sinkhole.json`, lines `tools/park_lines/park_sinkhole.json`, bake and graph in `assets/park/park_sinkhole/` (this commit). This table replaces the greybox table of 2026-10-11, which came from `--trace` runs: on this head a traced run and an untraced run of the same seed can differ (seed 1 of the floor line: 0 dead stops traced, 2 untraced, at the same place), because the director's enemies are sensitive to what else the process allocates. Every number below is from the brief's command with no `--trace`; traced runs are diagnostics only.

Commands, one process at a time (at nice 10), each started when the 1-minute load was at most 32 or, after 300 s of waiting, the foreground load (runnable threads below nice 10) was at most 32: `godot --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/traversal_line.gd -- --table=park --stage=4 --pilot=<key> --seeds=1,2,3,4,5,6,7,8 --out=<dir>` for each pilot, and `--floor --ref=sable` for the floor line, in the order Sable, Rivet, Kest, Tarn, Tally, the Cannon, floor.

The tool judges most bands on the median and prints the worst seed beside it. Two bands are judged here on every seed, as PARK.md words them: the anchor gap (at most 40 m, PARK.md:519) on the worst seed, and the floor band (at most 2.0 times Sable's median to the Warden, 0 dead stops on every seed), which the tool leaves unjudged.

| line | band | median | worst seed | result |
| --- | --- | --- | --- | --- |
| sable | reached_warden (8 of 8 seeds) | 8 | - | pass |
| sable | time_to_warden_s (median 60.0 to 120.0 s; no seed over 150.0 s) | 65.975 | 70.23 | pass |
| sable | segment_s (each segment's median 12.0 to 45.0 s) | 29.39 / 16.06 / 20.1 | 29.39 | pass |
| sable | flow_share (median at least 0.7; no seed under 0.6) | 0.939 | 0.927 | pass |
| sable | airborne_share (0.12 to 0.45) | 0.398 | - | pass |
| sable | dead_stops (0 on every seed) | 0 | 1 | MISS |
| sable | peak_speed_mps (at least 26.6 m/s (the blazing tier) on every seed) | 54.24 | 53.14 | pass |
| sable | tier3_s (median at least 3.0 s at the blazing tier) | 51.195 | - | pass |
| sable | quiet_max_s (at most 20.0 s) | 5.68 | 7.34 | pass |
| sable | max_anchor_gap_m (at most 40.0 m) | 16.15 | 21.7 | pass |
| sable | distinct_verbs (at least 3 different ride facts) | 5 | 5 | pass |
| sable | length_ratio (1.3 to 2.0) | 1.665 | - | pass |
| rivet | reached_warden (8 of 8 seeds) | 8 | - | pass |
| rivet | time_to_warden_s (median 60.0 to 120.0 s; no seed over 150.0 s) | 102.695 | 104.49 | pass |
| rivet | segment_s (each segment's median 12.0 to 45.0 s) | 42.54 / 31.15 / 29.25 | 42.54 | pass |
| rivet | flow_share (median at least 0.7; no seed under 0.6) | 0.875 | 0.84 | pass |
| rivet | airborne_share (0.12 to 0.45) | 0.167 | - | pass |
| rivet | dead_stops (0 on every seed) | 0 | 0 | pass |
| rivet | peak_speed_mps (at least 26.6 m/s (the blazing tier) on every seed) | 33.575 | 32.77 | pass |
| rivet | tier3_s (median at least 3.0 s at the blazing tier) | 13.485 | - | pass |
| rivet | quiet_max_s (at most 20.0 s) | 10.48 | 10.87 | pass |
| rivet | max_anchor_gap_m (at most 40.0 m) | 14.15 | 14.6 | pass |
| rivet | distinct_verbs (at least 3 different ride facts) | 6 | 6 | pass |
| rivet | length_ratio (1.3 to 2.0) | 1.645 | - | pass |
| kest | reached_warden (8 of 8 seeds) | 8 | - | pass |
| kest | time_to_warden_s (median 60.0 to 120.0 s; no seed over 150.0 s) | 97.48 | 99.56 | pass |
| kest | segment_s (each segment's median 12.0 to 45.0 s) | 44.24 / 26.57 / 26.35 | 44.24 | pass |
| kest | flow_share (median at least 0.7; no seed under 0.6) | 0.887 | 0.839 | pass |
| kest | airborne_share (0.12 to 0.45) | 0.208 | - | pass |
| kest | dead_stops (0 on every seed) | 0 | 0 | pass |
| kest | peak_speed_mps (at least 26.6 m/s (the blazing tier) on every seed) | 29.905 | 28.38 | pass |
| kest | tier3_s (median at least 3.0 s at the blazing tier) | 9.02 | - | pass |
| kest | quiet_max_s (at most 20.0 s) | 10.11 | 10.92 | pass |
| kest | max_anchor_gap_m (at most 40.0 m) | 14.3 | 17.2 | pass |
| kest | distinct_verbs (at least 3 different ride facts) | 5 | 5 | pass |
| kest | length_ratio (1.3 to 2.0) | 1.59 | - | pass |
| tarn | reached_warden (8 of 8 seeds) | 8 | - | pass |
| tarn | time_to_warden_s (median 60.0 to 120.0 s; no seed over 150.0 s) | 94.175 | 95.08 | pass |
| tarn | segment_s (each segment's median 12.0 to 45.0 s) | 41.3 / 28.61 / 24 | 41.295 | pass |
| tarn | flow_share (median at least 0.7; no seed under 0.6) | 0.958 | 0.942 | pass |
| tarn | airborne_share (0.12 to 0.45) | 0.221 | - | pass |
| tarn | dead_stops (0 on every seed) | 0 | 0 | pass |
| tarn | peak_speed_mps (at least 26.6 m/s (the blazing tier) on every seed) | 32.025 | 31.47 | pass |
| tarn | tier3_s (median at least 3.0 s at the blazing tier) | 12.68 | - | pass |
| tarn | quiet_max_s (at most 20.0 s) | 10.45 | 11.37 | pass |
| tarn | max_anchor_gap_m (at most 40.0 m) | 10.95 | 11.5 | pass |
| tarn | distinct_verbs (at least 3 different ride facts) | 4 | 4 | pass |
| tarn | length_ratio (1.3 to 2.0) | 1.64 | - | pass |
| tally | reached_warden (8 of 8 seeds) | 8 | - | pass |
| tally | time_to_warden_s (median 60.0 to 120.0 s; no seed over 150.0 s) | 97.66 | 100.85 | pass |
| tally | segment_s (each segment's median 12.0 to 45.0 s) | 44.18 / 25.36 / 28.24 | 44.175 | pass |
| tally | flow_share (median at least 0.7; no seed under 0.6) | 0.902 | 0.87 | pass |
| tally | airborne_share (0.12 to 0.45) | 0.165 | - | pass |
| tally | dead_stops (0 on every seed) | 0 | 1 | MISS |
| tally | peak_speed_mps (at least 26.6 m/s (the blazing tier) on every seed) | 33.17 | 32.05 | pass |
| tally | tier3_s (median at least 3.0 s at the blazing tier) | 12.83 | - | pass |
| tally | quiet_max_s (at most 20.0 s) | 9.24 | 12.34 | pass |
| tally | max_anchor_gap_m (at most 40.0 m) | 13.75 | 14.6 | pass |
| tally | distinct_verbs (at least 3 different ride facts) | 6 | 5 | pass |
| tally | length_ratio (1.3 to 2.0) | 1.57 | - | pass |
| cannon | reached_warden (8 of 8 seeds) | 8 | - | pass |
| cannon | time_to_warden_s (median 60.0 to 120.0 s; no seed over 150.0 s) | 90.545 | 91.86 | pass |
| cannon | segment_s (each segment's median 12.0 to 45.0 s) | 42.33 / 21.42 / 26.72 | 42.33 | pass |
| cannon | flow_share (median at least 0.7; no seed under 0.6) | 0.97 | 0.961 | pass |
| cannon | airborne_share (0.12 to 0.45) | 0.189 | - | pass |
| cannon | dead_stops (0 on every seed) | 0 | 0 | pass |
| cannon | peak_speed_mps (at least 26.6 m/s (the blazing tier) on every seed) | 32.21 | 31.92 | pass |
| cannon | tier3_s (median at least 3.0 s at the blazing tier) | 12.27 | - | pass |
| cannon | quiet_max_s (at most 20.0 s) | 8.34 | 10.48 | pass |
| cannon | max_anchor_gap_m (at most 40.0 m) | 14.6 | 28.6 | pass |
| cannon | distinct_verbs (at least 3 different ride facts) | 5 | 5 | pass |
| cannon | length_ratio (1.3 to 2.0) | 1.51 | - | pass |
| floor | reached_warden (8 of 8 seeds) | 8 | - | pass |
| floor | time_to_warden_s (median 60.0 to 120.0 s; no seed over 150.0 s) | 100.4 | 101.2 | pass |
| floor | segment_s (each segment's median 12.0 to 45.0 s) | 43.95 / 27.51 / 29.27 | 43.945 | pass |
| floor | flow_share (median at least 0.7; no seed under 0.6) | 0.878 | 0.862 | pass |
| floor | airborne_share (0.12 to 0.45) | 0.16 | - | pass |
| floor | dead_stops (0 on every seed) | 0 | 0 | pass |
| floor | peak_speed_mps (at least 26.6 m/s (the blazing tier) on every seed) | 33.27 | 32.49 | pass |
| floor | tier3_s (median at least 3.0 s at the blazing tier) | 12.985 | - | pass |
| floor | quiet_max_s (at most 20.0 s) | 9.37 | 11.92 | pass |
| floor | max_anchor_gap_m (at most 40.0 m) | 16.05 | 17.4 | pass |
| floor | distinct_verbs (at least 3 different ride facts) | 5 | 5 | pass |
| floor | length_ratio (1.3 to 2.0) | 1.55 | - | pass |
| floor | floor (reaches the Warden in at most 2.0 times sable's median time, 0 dead stops) | 100.4 | 101.2 | pass |

Dead stops and reach, per line:

- sable: class pylon_engineer, reached 8 of 8, dead stops ['seed 7 at [-203.3, -450.4], 21.2 s']
- rivet: class runner_gunner, reached 8 of 8, dead stops none
- kest: class demolitions_caster, reached 8 of 8, dead stops none
- tarn: class tarn, reached 8 of 8, dead stops none
- tally: class tally, reached 8 of 8, dead stops ['seed 1 at [-622.2, -699.2], 7.1 s']
- cannon: class remembered_cannon, reached 8 of 8, dead stops none
- floor: class runner_gunner, reached 8 of 8, dead stops none

**Two misses: one dead stop each on Sable seed 7 and Tally seed 1.** Both are a ball rolling into a director enemy, not into a row. The evidence:

- The floor line's stop at (-618.7, -704.0), 7 s after the drop-in, reproduced untraced with a scratch copy of the tool that prints contacts at the stop: the contact was a `CharacterBody3D` enemy 1.8 m away, with two more within 9 m (a pack). The director lands its spawns from 4 s, 60% of them 60 to 90 m ahead of the ball within 35 degrees of its heading (`src/world/director.gd:11-12`, `:86-96`), and on seed 1 that puts the first pack on the channel about 60 m ahead of where the ball is at 4 s. `home_rows` are not read at runtime on this head, so the burrower home on `lava_channel_1` is not the source.
- The outcome is sensitive to what the process allocates: the same seed traced gives 0 stops, and the scratch tool's prints alone turned Sable seed 7's stop into 0. A row or waypoint change moves the stop to another seed rather than removing it. Measured: Sable's point (-199, -479) moved to (-193, -479) cleared seed 7 and stopped seed 3 at (-169.3, -402.0); Tally's opening at (-655, -714), (-636, -708) cleared seed 1 and stopped seeds 3 and 7. The floor line's opening (-655, -714), (-636, -708) clears all 8 seeds and is the one kept.
- What would remove the class: the director keeping its ahead spawns off the committed route lanes, or the traversal pilot steering round an enemy on its line. Both are outside this stage (follow-ups).

**What changed since the 2026-10-11 table.** Every row but the ground, the kickers and seven site markers carries a recipe (R10), so the anchor fields build posts at runtime; Rivet's worst anchor gap fell from 41.4 m (traced) to 14.6 m. Eight fillers closing the ring approach are gone. Rivet's left-wall points cost it about 3 s over the first segment once the posts were built (median 45.48 s against the 45 s band, round t1), so Rivet now rides the channel's middle (42.54 s) and Tarn takes the left wall over the channel's last six points to keep three lines distinct. The floor line enters the channel by its right side.

**Distinct lines across the six pilots (at least 3).** The tool does not compute this band. It is measured on the lines file's polylines, sampled every 2 m: two lines are distinct when fewer than half of each line's samples lie within 8 m in plan of the other's.

- pair sable-rivet: within 8 m 0.54 -> same
- pair sable-kest: within 8 m 0.65 -> same
- pair sable-tarn: within 8 m 0.41 -> distinct
- pair sable-tally: within 8 m 0.77 -> same
- pair sable-cannon: within 8 m 0.78 -> same
- pair rivet-kest: within 8 m 0.41 -> distinct
- pair rivet-tarn: within 8 m 0.39 -> distinct
- pair rivet-tally: within 8 m 0.76 -> same
- pair rivet-cannon: within 8 m 0.56 -> same
- pair kest-tarn: within 8 m 0.30 -> distinct
- pair kest-tally: within 8 m 0.41 -> distinct
- pair kest-cannon: within 8 m 0.65 -> same
- pair tarn-tally: within 8 m 0.39 -> distinct
- pair tarn-cannon: within 8 m 0.42 -> distinct
- pair tally-cannon: within 8 m 0.55 -> same
- largest mutually distinct set: 3 ['rivet', 'kest', 'tarn']


## Sol continuation, 2026-10-12

Selected geometry restores the exact merged-baseline park bytes. The complete 56-run merged baseline is the selected artifact's traversal receipt. Two passage reworks were tested and discarded because they stopped more Sable seeds. No traced run enters these tables. The distinct-lines tick measurement remains unavailable in the untraced tool.

### Selected merged baseline

Values are median / worst seed. Segment cells list the three segment medians and the worst seed's longest segment. All source runs are untraced. Anchor gap uses the worst seed. Peak includes median tier-3 seconds.

| Band | sable | rivet | kest | tarn | tally | cannon | floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Reached Warden | 8 / -; PASS | 8 / -; PASS | 8 / -; PASS | 8 / -; PASS | 8 / -; PASS | 8 / -; PASS | 8 / -; PASS |
| Time to Warden, s | 66.67 / 71.08; PASS | 102.365 / 104.13; PASS | 97.48 / 99.56; PASS | 94.175 / 94.68; PASS | 97.66 / 100; PASS | 89.935 / 91.54; PASS | 100.37 / 101.2; judged in floor row |
| Segment medians, s | 29.39 / 16.39 / 19.97 / 33.41; PASS | 42.5 / 31.15 / 29.05 / 43.27; PASS | 44.24 / 26.57 / 26.35 / 45.44; PASS | 41.3 / 28.61 / 23.82 / 41.68; PASS | 44.18 / 25.36 / 28.19 / 46.94; PASS | 42.33 / 21.38 / 26.29 / 42.64; PASS | 43.95 / 27.17 / 29.27 / 44.91; reported, pilot band, not the floor's |
| Flow share | 0.946 / 0.925; PASS | 0.878 / 0.859; PASS | 0.887 / 0.839; PASS | 0.958 / 0.94; PASS | 0.902 / 0.87; PASS | 0.971 / 0.966; PASS | 0.885 / 0.862; reported, pilot band, not the floor's |
| Airborne share | 0.412 / 0.3886..0.4518; PASS | 0.167 / 0.1581..0.1702; PASS | 0.208 / 0.2028..0.2206; PASS | 0.221 / 0.2101..0.2315; PASS | 0.162 / 0.1545..0.1709; PASS | 0.189 / 0.1751..0.1959; PASS | 0.16 / 0.1478..0.1645; reported, pilot band, not the floor's |
| Dead stops | 0 / 1; MISS | 0 / 0; PASS | 0 / 0; PASS | 0 / 0; PASS | 0 / 0; PASS | 0 / 0; PASS | 0 / 0; PASS |
| Peak speed, m/s; tier-3 time, s | 54.24 / 53.14; tier 3 52.22; PASS | 33.685 / 32.77; tier 3 13.505; PASS | 29.905 / 28.38; tier 3 9.02; PASS | 32.025 / 31.47; tier 3 12.63; PASS | 33.12 / 31.55; tier 3 12.83; PASS | 32.09 / 31.92; tier 3 12.3; PASS | 33.07 / 32.49; tier 3 12.945; reported, pilot band, not the floor's |
| Quiet stretch, s | 6.125 / 7.17; PASS | 10.485 / 10.97; PASS | 10.11 / 10.92; PASS | 10.45 / 11.37; PASS | 8.87 / 12.34; PASS | 8.955 / 10.48; PASS | 9.305 / 11.92; reported, pilot band, not the floor's |
| Anchor gap, m | 20.65 / 30.4; PASS | 14.05 / 14.6; PASS | 14.3 / 17.2; PASS | 10.75 / 11.3; PASS | 13.7 / 14.7; PASS | 21.25 / 28.6; PASS | 14.75 / 17.4; reported, pilot band, not the floor's |
| Distinct ride facts | 5 / 5; PASS | 6 / 6; PASS | 5 / 5; PASS | 4 / 4; PASS | 6 / 5; PASS | 5 / 5; PASS | 5 / 5; reported, pilot band, not the floor's |
| Length / straight distance | 1.66 / 1.63..1.73; PASS | 1.645 / 1.64..1.65; PASS | 1.59 / 1.59..1.60; PASS | 1.64 / 1.63..1.65; PASS | 1.57 / 1.56..1.58; PASS | 1.51 / 1.51..1.52; PASS | 1.55 / 1.55..1.56; reported, pilot band, not the floor's |
| Floor row | stage floor row | stage floor row | stage floor row | stage floor row | stage floor row | stage floor row | 100.37 / 101.2; cap 204.73; PASS |
| Distinct lines | not measured in untraced tool | not measured in untraced tool | not measured in untraced tool | not measured in untraced tool | not measured in untraced tool | not measured in untraced tool | not measured in untraced tool |

Stop coordinates from untraced runs:
- sable: seed 7: [-203.3, -450.4] at 21.19 s
- rivet: none
- kest: none
- tarn: none
- tally: none
- cannon: none
- floor: none


### Discarded wider bend

Values are median / worst seed. Segment cells list the three segment medians and the worst seed's longest segment. All source runs are untraced. Anchor gap uses the worst seed. Peak includes median tier-3 seconds.

| Band | sable | rivet | kest | tarn | tally | cannon | floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Reached Warden | 8 / -; PASS | not measured | not measured | not measured | not measured | not measured | not measured |
| Time to Warden, s | 68.155 / 73.91; PASS | not measured | not measured | not measured | not measured | not measured | not measured |
| Segment medians, s | 31.29 / 17.58 / 20.13 / 32.5; PASS | not measured | not measured | not measured | not measured | not measured | not measured |
| Flow share | 0.926 / 0.907; PASS | not measured | not measured | not measured | not measured | not measured | not measured |
| Airborne share | 0.391 / 0.3549..0.4202; PASS | not measured | not measured | not measured | not measured | not measured | not measured |
| Dead stops | 1 / 1; MISS | not measured | not measured | not measured | not measured | not measured | not measured |
| Peak speed, m/s; tier-3 time, s | 54.24 / 53.14; tier 3 50.065; PASS | not measured | not measured | not measured | not measured | not measured | not measured |
| Quiet stretch, s | 6.435 / 8.33; PASS | not measured | not measured | not measured | not measured | not measured | not measured |
| Anchor gap, m | 15.8 / 23.4; PASS | not measured | not measured | not measured | not measured | not measured | not measured |
| Distinct ride facts | 5 / 5; PASS | not measured | not measured | not measured | not measured | not measured | not measured |
| Length / straight distance | 1.695 / 1.65..1.72; PASS | not measured | not measured | not measured | not measured | not measured | not measured |
| Floor row | stage floor row | not measured | not measured | not measured | not measured | not measured | not measured |
| Distinct lines | not measured in untraced tool | not measured | not measured | not measured | not measured | not measured | not measured |

Stop coordinates from untraced runs:
- sable: seed 1: [-174.9, -390.9] at 22.4 s; seed 2: [18.6, -162.4] at 42.64 s; seed 4: [-177.4, -383.8] at 22.13 s; seed 5: [-170.4, -396.8] at 22.07 s; seed 6: [-176.9, -384.5] at 22.4 s

Only Sable was remeasured on this discarded geometry. The other lines are not measured in this table.

### Discarded short kicker

Values are median / worst seed. Segment cells list the three segment medians and the worst seed's longest segment. All source runs are untraced. Anchor gap uses the worst seed. Peak includes median tier-3 seconds.

| Band | sable | rivet | kest | tarn | tally | cannon | floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Reached Warden | 8 / -; PASS | not measured | not measured | not measured | not measured | not measured | not measured |
| Time to Warden, s | 67.925 / 68.76; PASS | not measured | not measured | not measured | not measured | not measured | not measured |
| Segment medians, s | 29.05 / 17.81 / 19.7 / 31.67; PASS | not measured | not measured | not measured | not measured | not measured | not measured |
| Flow share | 0.923 / 0.909; PASS | not measured | not measured | not measured | not measured | not measured | not measured |
| Airborne share | 0.413 / 0.3952..0.4361; PASS | not measured | not measured | not measured | not measured | not measured | not measured |
| Dead stops | 0.5 / 2; MISS | not measured | not measured | not measured | not measured | not measured | not measured |
| Peak speed, m/s; tier-3 time, s | 54.24 / 53.14; tier 3 50.41; PASS | not measured | not measured | not measured | not measured | not measured | not measured |
| Quiet stretch, s | 5.835 / 6.94; PASS | not measured | not measured | not measured | not measured | not measured | not measured |
| Anchor gap, m | 17.9 / 22.7; PASS | not measured | not measured | not measured | not measured | not measured | not measured |
| Distinct ride facts | 5 / 5; PASS | not measured | not measured | not measured | not measured | not measured | not measured |
| Length / straight distance | 1.65 / 1.63..1.69; PASS | not measured | not measured | not measured | not measured | not measured | not measured |
| Floor row | stage floor row | not measured | not measured | not measured | not measured | not measured | not measured |
| Distinct lines | not measured in untraced tool | not measured | not measured | not measured | not measured | not measured | not measured |

Stop coordinates from untraced runs:
- sable: seed 1: [-173.1, -392.2] at 21.89 s; seed 2: [18.9, -159.9] at 37.44 s; seed 4: [-166.2, -404.9] at 21.99 s; seed 5: [-172.8, -395.8] at 21.9 s; seed 5: [-175.4, -390.3] at 22.53 s

Only Sable was remeasured on this discarded geometry. The other lines are not measured in this table.
