# Traversal, stage 3, park_pit

The measured PARK.md section 8 bands for The Pit, one table per pass (R8). Rows are the 13 bands. Columns are the six pilot lines and the floor line. Each cell is "median / worst seed, pass or MISS". For airborne share and length ratio the second number is the seed range. For distinct ride facts it is the lowest seed.

The band numbers are PARK.md section 8's; nothing here tunes them. Evidence is under `artifacts/local/alpha/push/w13/stages/park_pit/traversal/` (local, not committed). The lines are `tools/park_lines/park_pit.json`, and the stage page section 9 explains them.

## Greybox fix round, 2026-10-11 (KD3, on the KB9 and KB7b head)

This table supersedes the greybox pass below. It was measured on the fix-round worktree, based on 99864b5 (the first pass merged with cand/alpha-w13 at b0e4490), with the park file and lines file this round commits. On this head KB9 places every recipe row at runtime, so its ride sensor fires. KB7b's ride-fact set is in force: `lift_fired` is no ride fact, and the graph access defect of R12 is fixed (no out-of-bounds line in any log, and `progress_m` is measured). Evidence is in `artifacts/local/alpha/push/w13/stages/park_pit/traversal-fix-round/` in the candidate worktree: one summary JSON and one log per line, and `load.txt` (load average 18 to 80 while it ran; the tool runs at fixed fps, so game-time numbers do not depend on load).

Command, once per line, one process at a time; the floor line ran after Rivet, its reference:

```
godot --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/traversal_line.gd -- --table=park --stage=3 --pilot=<key> --seeds=1,2,3,4,5,6,7,8 --out=<dir>
```

| Band | sable | rivet | kest | tarn | tally | cannon | floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Reached the Warden (8 of 8) | 8 of 8 pass | 8 of 8 pass | 8 of 8 pass | 8 of 8 pass | 8 of 8 pass | 8 of 8 pass | 8 of 8 pass |
| time_to_warden_s (median 60-120, no seed over 150) | 62.0 / 66.8 pass | 100.9 / 101.4 pass | 96.8 / 99.2 pass | 75.0 / 75.4 pass | 79.7 / 81.0 pass | 97.5 / 98.9 pass | 90.4 / 93.2 pass |
| segment_s (each median 12-45) | 13.8-21.0-27.3 / 27.3 pass | 18.8-38.2-44.0 / 44.0 pass | 18.4-36.4-42.1 / 42.1 pass | 17.5-35.5-21.9 / 35.5 pass | 19.4-36.7-23.8 / 36.7 pass | 18.1-39.1-40.6 / 40.6 pass | 19.5-39.4-31.6 / 39.4 pass |
| flow_share (median 0.70, no seed under 0.60) | 0.96 / 0.93 pass | 0.77 / 0.75 pass | 0.78 / 0.67 pass | 0.93 / 0.92 pass | 0.87 / 0.78 pass | 0.90 / 0.87 pass | 0.70 / 0.60 (reported; 0.6961 is under 0.70) |
| airborne_share (0.12-0.45) | 0.29 / 0.26-0.31 pass | 0.18 / 0.17-0.18 pass | 0.25 / 0.24-0.25 pass | 0.24 / 0.23-0.24 pass | 0.26 / 0.25-0.26 pass | 0.16 / 0.16-0.16 pass | 0.14 / 0.13-0.15 pass |
| dead stops (0 every seed) | 0 / 0 pass | 0 / 0 pass | 0 / 0 pass | 0 / 0 pass | 0 / 0 pass | 0 / 0 pass | 0 / 0 pass |
| peak_speed_mps (26.6 every seed) | 56.9 / 56.9 pass | 31.9 / 31.4 pass | 29.2 / 29.2 pass | 31.4 / 31.4 pass | 31.1 / 31.1 pass | 30.9 / 30.9 pass | 31.1 / 31.1 pass |
| tier3_s (median at least 3 s) | 48.3 / 47.5 pass | 8.4 / 8.4 pass | 7.0 / 6.0 pass | 10.9 / 10.5 pass | 7.3 / 7.3 pass | 11.1 / 10.8 pass | 9.8 / 9.4 pass |
| quiet_max_s (at most 20 s) | 7.0 / 8.4 pass | 16.4 / 16.6 pass | 11.5 / 12.9 pass | 11.6 / 11.9 pass | 15.3 / 15.7 pass | 13.2 / 14.6 pass | 12.6 / 14.3 pass |
| max anchor gap m (at most 40) | 29 / 32 pass | 28 / 30 pass | 18 / 18 pass | 33 / 35 pass | 34 / 36 pass | 23 / 30 pass | 35 / 36 pass |
| distinct ride facts, KB7b set (at least 3) | 4 / 4 pass | 4 / 4 pass | 5 / 5 pass | 4 / 4 pass | 4 / 4 pass | 4 / 4 pass | 4 / 4 pass |
| length ratio (1.3-2.0) | 1.75 / 1.71-1.77 pass | 1.64 / 1.64-1.64 pass | 1.72 / 1.72-1.73 pass | 1.44 / 1.44-1.45 pass | 1.35 / 1.35-1.36 pass | 1.71 / 1.70-1.72 pass | 1.45 / 1.44-1.45 pass |
| progress_m, m/s (reported, not a band) | 20.3 | 12.5 | 13.0 | 16.8 | 15.8 | 12.9 | 13.9 |

**Ride facts, KB7b set, every seed.** Each pilot line fires `kicker_launch`, `ride_bowl`, `ride_chute` and `ride_grapple_line`; Kest adds `thermal_ride` from `dust_devil_floor`. None rests on `lift_fired`, so the distinct-verbs band passes without the facts R11 drops. The floor line fires the same four: the haul lanes and the collar dish are rows, not cables.

**Floor line.** 8 of 8 seeds reached the Warden, median 90.4 s, worst 93.2 s, against 2.0 times Rivet's 100.9 s median (201.9 s), with 0 dead stops: pass (PARK.md:522). The tool also judges the pilot flow band on it: median 0.6961, worst 0.6043, just under the 0.70 median. PARK.md:522 gives the floor line its own band, so this is reported, not counted as a miss.

**Distinct lines.** The seed traces were not re-cut in this round, so the 8 m share was not measured again. Rivet (B + E), Kest (A + W) and Tarn (C + S) share no head and no tail, which is how the greybox pass found them distinct (0.36, 0.37 and 0.47). At least 3 distinct lines, pass by construction; this is inference until a trace re-cut.

**Read with these limits.** These are bot numbers: they judge a bot, and Andrew's sitting judges the fun. Max anchor gap is judged on the median, with the worst seed beside it. Rivet's third segment (44.0 s) and Kest's (42.1 s) sit close to the 45 s edge.

## Greybox pass, 2026-10-11 (KD3), superseded

Measured before KB9 placed rows at runtime and before KB7b's set; kept as the record of the first pass.

Command, once per line, one process at a time:

```
godot --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/traversal_line.gd -- --table=park --stage=3 --pilot=<key> --seeds=1,2,3,4,5,6,7,8 --out=<dir>
```

The floor line ran with `--floor` in place of `--pilot`, after Rivet, which is its reference.

Measured on the kd3-pit worktree, based on 5f2139b, with the park file this pass commits. The park file sha256 is in `assets/park/park_pit/bake.json`.

| Band | sable | rivet | kest | tarn | tally | cannon | floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Reached the Warden (8 of 8) | 8 of 8 pass | 8 of 8 pass | 8 of 8 pass | 8 of 8 pass | 8 of 8 pass | 8 of 8 pass | 8 of 8 pass |
| time_to_warden_s (median 60-120, no seed over 150) | 64.6 / 67.3 pass | 97.7 / 98.4 pass | 90.9 / 92.2 pass | 74.5 / 75.1 pass | 78.2 / 78.8 pass | 94.5 / 95.2 pass | 88.2 / 89.3 pass |
| segment_s (each median 12-45) | 13.9-24.1-26.7 / 26.7 pass | 18.8-37.5-41.3 / 41.3 pass | 18.6-36.4-35.6 / 36.4 pass | 17.6-35.1-21.7 / 35.1 pass | 19.6-35.7-22.9 / 35.7 pass | 18.3-38.2-38.1 / 38.2 pass | 19.6-39.0-29.5 / 39.0 pass |
| flow_share (median 0.70, no seed under 0.60) | 0.93 / 0.90 pass | 0.86 / 0.84 pass | 0.86 / 0.82 pass | 0.93 / 0.91 pass | 0.90 / 0.85 pass | 0.93 / 0.91 pass | 0.79 / 0.74 pass |
| airborne_share (0.12-0.45) | 0.23 / 0.22-0.25 pass | 0.17 / 0.16-0.17 pass | 0.23 / 0.22-0.23 pass | 0.23 / 0.23-0.24 pass | 0.25 / 0.24-0.25 pass | 0.14 / 0.14-0.14 pass | 0.13 / 0.13-0.14 pass |
| dead stops (0 every seed) | 0 / 0 pass | 0 / 0 pass | 0 / 0 pass | 0 / 0 pass | 0 / 0 pass | 0 / 0 pass | 0 / 0 pass |
| peak_speed_mps (26.6 every seed) | 56.9 / 56.9 pass | 31.6 / 31.4 pass | 29.2 / 29.2 pass | 31.4 / 31.4 pass | 31.4 / 31.1 pass | 30.9 / 30.9 pass | 31.4 / 31.1 pass |
| tier3_s (median at least 3 s) | 47.3 / 46.5 pass | 8.5 / 8.5 pass | 6.5 / 6.0 pass | 10.7 / 10.5 pass | 7.4 / 7.3 pass | 11.3 / 10.3 pass | 9.3 / 9.1 pass |
| quiet_max_s (at most 20 s) | 6.7 / 6.7 pass | 6.7 / 6.7 pass | 6.7 / 6.7 pass | 6.7 / 6.7 pass | 6.7 / 6.7 pass | 6.7 / 6.7 pass | 6.7 / 6.7 pass |
| max anchor gap m (at most 40) | 31 / 34 pass | 30 / 31 pass | 18 / 23 pass | 33 / 36 pass | 35 / 37 pass | 31 / 33 pass | 34 / 34 pass |
| distinct ride facts (at least 3) | 3 (KB7b set 2) / 3 pass; KB7b MISS | 3 (KB7b set 2) / 3 pass; KB7b MISS | 3 (KB7b set 2) / 3 pass; KB7b MISS | 3 (KB7b set 2) / 3 pass; KB7b MISS | 3 (KB7b set 2) / 3 pass; KB7b MISS | 3 (KB7b set 2) / 3 pass; KB7b MISS | 2 (KB7b set 1) / 2 MISS; KB7b MISS |
| length ratio (1.3-2.0) | 1.77 / 1.74-1.80 pass | 1.63 / 1.63-1.63 pass | 1.68 / 1.67-1.68 pass | 1.44 / 1.43-1.44 pass | 1.35 / 1.35-1.36 pass | 1.71 / 1.70-1.71 pass | 1.45 / 1.45-1.45 pass |
| progress_m | not measured (KB7b) | not measured (KB7b) | not measured (KB7b) | not measured (KB7b) | not measured (KB7b) | not measured (KB7b) | not measured (KB7b) |

**Floor line.** The floor line reached the Warden on 8 of 8 seeds: median 88.2 s, worst 89.3 s, against the band's 195.4 s (2.0 times Rivet's 97.7 s median). It had 0 dead stops on every seed: pass. It rides no cable; its ride facts (kicker_launch, lift_fired) and its flow share (0.79) are reported, not judged.

**Distinct lines.** Measured on seed 1 traces of the shipped geometry: the share of one line's ticks within 8 m of the other's, the larger of the two directions. Rivet, Kest and Tarn are pairwise distinct (0.36, 0.37, 0.47), and so are Kest, Tally and the Cannon (0.42, 0.44, 0.40): at least 3 distinct lines, pass. The pairs that share a head or a tail are not distinct (Rivet and Tally 0.72, Tarn and the Cannon 0.72, the most-shared pairs).

**Read with these limits.**

1. **progress_m is not measured.** The tool's `_construct_graph` discards the stage graph (R12), so every `d_landmark` lookup prints the known out-of-bounds line and `progress_m` is built from zeros. KB7b fixes it.
2. **Distinct ride facts pass on the current tool only.** Every pilot line reaches 3 ride facts here: `kicker_launch`, `ride_grapple_line` and `lift_fired`. KB7b drops `lift_fired` from the set, which leaves 2. The cause is structural, not this stage's rows: no recipe row is placed at runtime on this head (`park_recipes.gd` `place` has no caller in `src/`). So the half-pipe, bowl, ledge and drop rows raise no `ride_chute`, `ride_bowl`, `ride_ledge` or `ride_drop` sensor. A non-gliding line can only reach kicker lips and contraptions. This is reported to the coordinator as a follow-up. The band is MISS under the KB7b set until runtime placement lands.
3. **Max anchor gap is judged on the median.** The worst seed is shown beside it.
4. **These are bot numbers.** They judge a bot. Andrew's sitting judges the fun.
