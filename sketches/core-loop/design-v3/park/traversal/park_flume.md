# Traversal: park_flume (stage 2)

> **Historical wave-13/18 traversal receipt:** Preserved measurement log; live park traversal qualification runs via `sketches/core-loop/tests/park_*_test.gd` and `sketches/core-loop/tests/w50_*_test.gd`.

KD2's table (ruling R8): the 13 bands of PARK.md section 8 for the six pilot lines and the floor line, 8 seeds each through the committed `tools/traversal_line.gd` (`--table=park --stage=2 --seeds=1,2,3,4,5,6,7,8`, `--fixed-fps 90`). Current batches are untraced; separate traced solos qualify replay and stop attribution. Each cell is median / worst seed, then pass or MISS. The lines are `assets/park/park_flume/lines.json`.

<!-- flume-current-table -->
## Current measurements and qualification, round 9

<!-- flume-current-receipts
{
  "receipt_root": "/home/andrew/scratch/w13/sol/kd2-flume-r9",
  "head": "e3a292d736c42dec397d3c3108591e2c1d886f96",
  "tool_sha256": "37e98e4ac7e0a5d4141d97828f5834a083d3267e83a90efccc26248b69ec574a"
}
-->

Measured runtime head `e3a292d736c42dec397d3c3108591e2c1d886f96`, merged from candidate `e8471670d479b0609d7a4f078e1066c84cb5479d`, at `0617cf3b1f1ab30264ac12b71d4c57c5822053fe`. Committed traversal tool SHA256 `37e98e4ac7e0a5d4141d97828f5834a083d3267e83a90efccc26248b69ec574a`. The final source, tool and bake inputs match all final batch, replay and win manifests. Subsequent documentation and regression commits do not change these runtime inputs.

All 56 untraced seed rows pass error qualification from their child logs. Acceptance also requires the five named replay comparisons reported below. Each pilot uses seeds 1–8 in a fresh child process. The cells show median / worst seed and a measured verdict. Per-seed criteria use the worst seed. Segments, airborne share, tier-3 time and length retain their explicitly median-based criteria. The floor is judged only by arrival, maximum time against twice Rivet median and zero terrain stops; its other cells are reports.

The committed stage fixture independently checks this publication with `--docs`. It reads the saved seed receipts, input manifests, child logs and traced stop probes, then recomputes the table and saved win values. Marker-only tables and rejected populations fail.

| Band | sable | rivet | kest | tarn | tally | cannon | floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Reached Warden, 8/8 | 8 / 8 pass | 8 / 8 pass | 8 / 8 pass | 8 / 8 pass | 8 / 8 pass | 8 / 8 pass | 8 / 8 pass |
| Time s, median 60–120; worst ≤150 | 62.36 / 65.06 pass | 96.675 / 99.57 pass | 85.785 / 92.01 pass | 80.5 / 81.5 pass | 93.085 / 96.22 pass | 81.515 / 84.82 pass | 96.245 / 98.49, reported, pilot band, not the floor's |
| Segments s, each median 12–45 | [21.6, 20.84, 19.9] / [21.89, 22.29, 21.68] pass | [27.28, 36.245, 33.31] / [28.71, 37.16, 34.47] pass | [25.6, 35.34, 25.005] / [29.29, 35.82, 26.89] pass | [23.38, 26.86, 29.98] / [24.81, 27.12, 30.5] pass | [27.83, 31.155, 34.65] / [29.12, 32.36, 34.91] pass | [25.64, 36.795, 18.91] / [25.87, 37.2, 22.19] pass | [28.38, 30.3, 37.63] / [28.86, 31.08, 38.86], reported, pilot band, not the floor's |
| Flow, median ≥.70; worst ≥.60 | 0.9333 / 0.931 pass | 0.7482 / 0.7349 pass | 0.7223 / 0.6587 pass | 0.94145 / 0.9307 pass | 0.70875 / 0.6193 pass | 0.93295 / 0.9075 pass | 0.59015 / 0.5654, reported, pilot band, not the floor's |
| Airborne, median .12–.45 | 0.2536 / [0.236, 0.2608] pass | 0.12685 / [0.1212, 0.1296] pass | 0.1608 / [0.143, 0.1645] pass | 0.17245 / [0.1652, 0.1807] pass | 0.13185 / [0.1231, 0.1448] pass | 0.1625 / [0.1313, 0.1768] pass | 0.1234 / [0.1169, 0.1321], reported, pilot band, not the floor's |
| Terrain or unclassified stops, every seed 0 | 0.0 / 0 pass | 0.0 / 0 pass | 0.0 / 0 pass | 0.0 / 0 pass | 0.0 / 0 pass | 0.0 / 0 pass | 0.0 / 0 pass |
| Peak m/s, worst ≥26.6 | 54.5 / 54.25 pass | 37.11 / 32.24 pass | 31.305 / 31.08 pass | 33.76 / 31.8 pass | 32.82 / 32.6 pass | 32.25 / 31.26 pass | 34.69 / 32.8, reported, pilot band, not the floor's |
| Tier-3 s, median ≥3 | 47.14 / 46.44 pass | 7.79 / 7.59 pass | 6.975 / 3.99 pass | 9.46 / 8.34 pass | 8.42 / 6.12 pass | 11.31 / 8.18 pass | 8.155 / 7.87, reported, pilot band, not the floor's |
| Quiet s, worst ≤20 | 7.7 / 8.21 pass | 11.715 / 12.13 pass | 17.385 / 17.57 pass | 8.72 / 8.87 pass | 15.205 / 15.48 pass | 12.53 / 13.2 pass | 12.48 / 12.82, reported, pilot band, not the floor's |
| Anchor gap m, worst ≤40 | 31.3 / 32.9 pass | 30.6 / 33.5 pass | 25.25 / 30.3 pass | 35.7 / 35.7 pass | 32.05 / 35.3 pass | 20.75 / 31.6 pass | 31.4 / 34.8, reported, pilot band, not the floor's |
| Ride facts, worst ≥3 | 5.0 / 5 pass | 5.0 / 5 pass | 4.0 / 4 pass | 5.0 / 5 pass | 5.0 / 5 pass | 4.5 / 4 pass | 5.0 / 5, reported, pilot band, not the floor's |
| Length ratio, median 1.3–2.0 | 1.51 / [1.51, 1.54] pass | 1.43 / [1.43, 1.44] pass | 1.33 / [1.32, 1.37] pass | 1.35 / [1.35, 1.36] pass | 1.34 / [1.33, 1.34] pass | 1.33 / [1.33, 1.34] pass | 1.35 / [1.35, 1.36], reported, pilot band, not the floor's |
| Floor, ≤2× Rivet median; zero terrain stops | not applicable | not applicable | not applicable | not applicable | not applicable | not applicable | 96.245 / max 98.49; cap 193.35 pass |

| Line | Qualified population receipt | Input provenance |
| --- | --- | --- |
| sable | `/home/andrew/scratch/w13/sol/kd2-flume-r9/population/sable/sable.json` | `/home/andrew/scratch/w13/sol/kd2-flume-r9/population-sable-inputs.json` |
| rivet | `/home/andrew/scratch/w13/sol/kd2-flume-r9/population/rivet/rivet.json` | `/home/andrew/scratch/w13/sol/kd2-flume-r9/population-rivet-inputs.json` |
| kest | `/home/andrew/scratch/w13/sol/kd2-flume-r9/population/kest/kest.json` | `/home/andrew/scratch/w13/sol/kd2-flume-r9/population-kest-inputs.json` |
| tarn | `/home/andrew/scratch/w13/sol/kd2-flume-r9/population/tarn/tarn.json` | `/home/andrew/scratch/w13/sol/kd2-flume-r9/population-tarn-inputs.json` |
| tally | `/home/andrew/scratch/w13/sol/kd2-flume-r9/population/tally/tally.json` | `/home/andrew/scratch/w13/sol/kd2-flume-r9/population-tally-inputs.json` |
| cannon | `/home/andrew/scratch/w13/sol/kd2-flume-r9/population/cannon/cannon.json` | `/home/andrew/scratch/w13/sol/kd2-flume-r9/population-cannon-inputs.json` |
| floor | `/home/andrew/scratch/w13/sol/kd2-flume-r9/population/floor/floor.json` | `/home/andrew/scratch/w13/sol/kd2-flume-r9/population-floor-inputs.json` |

### Distinct pilot lines

Mutually distinct lines: sable / seed 1, rivet / seed 5, tally / seed 5; PASS.

Each directed share counts all source trace ticks with any target tick within 8 m in XZ. All six directed shares are below 0.5. The committed documentation check recomputes the shares from qualified final-input traces and rejects a duplicated path.

| Directed overlap | Share within 8 m |
| --- | --- |
| sable → rivet | 0.27254 |
| sable → tally | 0.22590 |
| rivet → sable | 0.31723 |
| rivet → tally | 0.40292 |
| tally → sable | 0.25958 |
| tally → rivet | 0.43564 |
Trace receipt: `/home/andrew/scratch/w13/sol/kd2-flume-r9/solos/solo-sable1-trace/sable-seed-1-trace.json`.
Trace receipt: `/home/andrew/scratch/w13/sol/kd2-flume-r9/solos/solo-rivet5-trace/rivet-seed-5-trace.json`.
Trace receipt: `/home/andrew/scratch/w13/sol/kd2-flume-r9/solos/solo-tally5-trace/tally-seed-5-trace.json`.

### Stop classification

| Line / seed | Time s | Position XZ m | Classification | Enemy kind | Home or director provenance | Matching traced receipt |
| --- | --- | --- | --- | --- | --- | --- |
| All 56 seeds | none | none | zero observed stops | not applicable | not applicable | population receipts above |

No stops were observed in the final 56 qualified seeds, so no pack exemption or stop probe is required. Stop-replay records are in `/home/andrew/scratch/w13/sol/kd2-flume-r9/stop-replay-comparisons.json`. A pack exemption would require a matching traced solo, an observed enemy kind and spawning provenance inside the preceding 90 ticks. Ground-only contacts would count as terrain. The final population uses no exemption.

### Named replay qualification

| Line / seed | Batch / plain / traced equality | Qualification |
| --- | --- | --- |
| sable / 1 | equal | error-free qualified |
| rivet / 5 | equal | error-free qualified |
| sable / 4 | equal | error-free qualified |
| tally / 5 | equal | error-free qualified |
| floor / 1 | equal | error-free qualified |

Named replay acceptance: 5/5 qualified comparisons complete. Complete population cells above come from the 56 qualified child receipts; no rejected or missing row fills a cell.

Replay receipts and error qualification: `/home/andrew/scratch/w13/sol/kd2-flume-r9/replay-qualification.json`. Full runtime-input equality: `/home/andrew/scratch/w13/sol/kd2-flume-r9/input-equality.json`.

<!-- current-win-results -->
### Current win results, round 9

The unchanged scratch `win_600.gd` only sets the bot stage limit to 600 s before tick 1. Runs use `--table=park --from-stage=2 --stages=2 --policy=completionist`. Ruling 23 judges reach and engagement without a traversal-cause stall. Warden break times are reported separately and belong to the fight units and Andrew's task #5.

| Seed | Engage s | Break s | Engage to break s | Outcome | Stage stop | Receipt |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 116.69 | 289.03 | 172.34 | stalled | gates | `/home/andrew/scratch/w13/sol/kd2-flume-r9/win-seed-1/bots.ndjson` |
| 2 | 116.74 | not broken in 600 s | not applicable | stalled | beacon | `/home/andrew/scratch/w13/sol/kd2-flume-r9/win-seed-2/bots.ndjson` |
| 3 | 112.25 | not broken in 600 s | not applicable | stalled | beacon | `/home/andrew/scratch/w13/sol/kd2-flume-r9/win-seed-3/bots.ndjson` |

Every win seed reaches and engages. Child logs contain no collapse script error or missing park-cue error. ACE stem files are absent in this worktree, so these runs use the existing synth fallback. Listening is not qualified. Post-engagement fight or gate outcomes are reported above and do not change the stage traversal criterion.
<!-- /current-win-results -->

The physical event regression observes finite matching deck-to-floor mesh and collider surfaces at five span positions at landing, 0.5 s, 1 s and 2 s. Its independent grid interpolation defines the authorized depth. The stage keeps its authored form, trigger, six-second lead, 20 m hold-clear distance, swap and route changes. Both authored music cue IDs resolve through the common runtime event/music path.

The corrected candidate tests judge the music bar grid booked at announcement. Both ground-slump game fixtures and the complete Z1 shared suite pass. The candidate supplies the shared posture-comparison and Warden-wiring corrections. The complete eight-file stage smoke passes. Rivet also emits missing Fin.L/Fin.R control diagnostics, which the wrapper reports separately as a partial skip; all 127 flume geometry checks run and pass. KD2 leaves those shared files unchanged. The retained round-8 baseline and head failure logs establish the inherited defect before that candidate correction.
<!-- /flume-current-table -->



## Riding surface correction, round 9

Coordinator ruling V1 defines the intact riding surface as base plus height. The span remains at base y=44 m with height 2 m, so its mesh and solid collider top are 46 m. The warning sits 0.15 m above that top. The prepared replacement begins at the independently measured intact surface with zero fall progress. It falls continuously over the unchanged two seconds to the baked hollow floor, 23.5586042404175 m, giving depth 22.4413957595825 m. The 20 m hold-clear margin, predicted crossing hold, partial-fall pause, authored site, trigger, form, lead, swap and route changes remain fixed.

<!-- flume-historical-table-r8 -->
## Historical measurements and qualification, round 8

<!-- flume-historical-receipts-r8
{
  "receipt_root": "/home/andrew/scratch/w13/sol/kd2-flume-r8",
  "head": "395ba57bc8da9c6c260776ea04cc8c9520f427d0",
  "tool_sha256": "37e98e4ac7e0a5d4141d97828f5834a083d3267e83a90efccc26248b69ec574a"
}
-->

Measured runtime head `395ba57bc8da9c6c260776ea04cc8c9520f427d0`, merged from candidate `f6bc6b646ad728d53744ba99580514d463ab217f`, whose runtime code is `bc07122e` at `54ca9d8912fa39e4f9243fc02221ea98faa66623`. Committed traversal tool SHA256 `37e98e4ac7e0a5d4141d97828f5834a083d3267e83a90efccc26248b69ec574a`. The final source, tool and bake inputs match all final batch, replay and win manifests. Subsequent documentation and regression commits do not change these runtime inputs.

All 56 untraced seed rows pass error qualification from their child logs. Acceptance also requires the five named replay comparisons reported below. Each pilot uses seeds 1–8 in a fresh child process. The cells show median / worst seed and a measured verdict. Per-seed criteria use the worst seed. Segments, airborne share, tier-3 time and length retain their explicitly median-based criteria. The floor is judged only by arrival, maximum time against twice Rivet median and zero terrain stops; its other cells are reports.

The committed stage fixture independently checks this publication with `--docs`. It reads the saved seed receipts, input manifests, child logs and traced stop probes, then recomputes the table and saved win values. Marker-only tables and rejected populations fail.

| Band | sable | rivet | kest | tarn | tally | cannon | floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Reached Warden, 8/8 | 8 / 8 pass | 8 / 8 pass | 8 / 8 pass | 8 / 8 pass | 8 / 8 pass | 8 / 8 pass | 8 / 8 pass |
| Time s, median 60–120; worst ≤150 | 62.36 / 65.06 pass | 96.675 / 99.57 pass | 85.785 / 92.01 pass | 80.5 / 81.5 pass | 93.085 / 96.22 pass | 81.515 / 84.82 pass | 96.245 / 98.49, reported, pilot band, not the floor's |
| Segments s, each median 12–45 | [21.6, 20.84, 19.9] / [21.89, 22.29, 21.68] pass | [27.28, 36.245, 33.31] / [28.71, 37.16, 34.47] pass | [25.6, 35.34, 25.005] / [29.29, 35.82, 26.89] pass | [23.38, 26.86, 29.98] / [24.81, 27.12, 30.5] pass | [27.83, 31.155, 34.65] / [29.12, 32.36, 34.91] pass | [25.64, 36.795, 18.91] / [25.87, 37.2, 22.19] pass | [28.38, 30.3, 37.63] / [28.86, 31.08, 38.86], reported, pilot band, not the floor's |
| Flow, median ≥.70; worst ≥.60 | 0.9333 / 0.931 pass | 0.7482 / 0.7349 pass | 0.7223 / 0.6587 pass | 0.94145 / 0.9307 pass | 0.70875 / 0.6193 pass | 0.93295 / 0.9075 pass | 0.59015 / 0.5654, reported, pilot band, not the floor's |
| Airborne, median .12–.45 | 0.2536 / [0.236, 0.2608] pass | 0.12685 / [0.1212, 0.1296] pass | 0.1608 / [0.143, 0.1645] pass | 0.17245 / [0.1652, 0.1807] pass | 0.13185 / [0.1231, 0.1448] pass | 0.1625 / [0.1313, 0.1768] pass | 0.1234 / [0.1169, 0.1321], reported, pilot band, not the floor's |
| Terrain or unclassified stops, every seed 0 | 0.0 / 0 pass | 0.0 / 0 pass | 0.0 / 0 pass | 0.0 / 0 pass | 0.0 / 0 pass | 0.0 / 0 pass | 0.0 / 0 pass |
| Peak m/s, worst ≥26.6 | 54.5 / 54.25 pass | 37.11 / 32.24 pass | 31.305 / 31.08 pass | 33.76 / 31.8 pass | 32.82 / 32.6 pass | 32.25 / 31.26 pass | 34.69 / 32.8, reported, pilot band, not the floor's |
| Tier-3 s, median ≥3 | 47.14 / 46.44 pass | 7.79 / 7.59 pass | 6.975 / 3.99 pass | 9.46 / 8.34 pass | 8.42 / 6.12 pass | 11.31 / 8.18 pass | 8.155 / 7.87, reported, pilot band, not the floor's |
| Quiet s, worst ≤20 | 7.7 / 8.21 pass | 11.715 / 12.13 pass | 17.385 / 17.57 pass | 8.72 / 8.87 pass | 15.205 / 15.48 pass | 12.53 / 13.2 pass | 12.48 / 12.82, reported, pilot band, not the floor's |
| Anchor gap m, worst ≤40 | 31.3 / 32.9 pass | 30.6 / 33.5 pass | 25.25 / 30.3 pass | 35.7 / 35.7 pass | 32.05 / 35.3 pass | 20.75 / 31.6 pass | 31.4 / 34.8, reported, pilot band, not the floor's |
| Ride facts, worst ≥3 | 5.0 / 5 pass | 5.0 / 5 pass | 4.0 / 4 pass | 5.0 / 5 pass | 5.0 / 5 pass | 4.5 / 4 pass | 5.0 / 5, reported, pilot band, not the floor's |
| Length ratio, median 1.3–2.0 | 1.51 / [1.51, 1.54] pass | 1.43 / [1.43, 1.44] pass | 1.33 / [1.32, 1.37] pass | 1.35 / [1.35, 1.36] pass | 1.34 / [1.33, 1.34] pass | 1.33 / [1.33, 1.34] pass | 1.35 / [1.35, 1.36], reported, pilot band, not the floor's |
| Floor, ≤2× Rivet median; zero terrain stops | not applicable | not applicable | not applicable | not applicable | not applicable | not applicable | 96.245 / max 98.49; cap 193.35 pass |

| Line | Qualified population receipt | Input provenance |
| --- | --- | --- |
| sable | `/home/andrew/scratch/w13/sol/kd2-flume-r8/population/sable/sable.json` | `/home/andrew/scratch/w13/sol/kd2-flume-r8/population-sable-inputs.json` |
| rivet | `/home/andrew/scratch/w13/sol/kd2-flume-r8/population/rivet/rivet.json` | `/home/andrew/scratch/w13/sol/kd2-flume-r8/population-rivet-inputs.json` |
| kest | `/home/andrew/scratch/w13/sol/kd2-flume-r8/population/kest/kest.json` | `/home/andrew/scratch/w13/sol/kd2-flume-r8/population-kest-inputs.json` |
| tarn | `/home/andrew/scratch/w13/sol/kd2-flume-r8/population/tarn/tarn.json` | `/home/andrew/scratch/w13/sol/kd2-flume-r8/population-tarn-inputs.json` |
| tally | `/home/andrew/scratch/w13/sol/kd2-flume-r8/population/tally/tally.json` | `/home/andrew/scratch/w13/sol/kd2-flume-r8/population-tally-inputs.json` |
| cannon | `/home/andrew/scratch/w13/sol/kd2-flume-r8/population/cannon/cannon.json` | `/home/andrew/scratch/w13/sol/kd2-flume-r8/population-cannon-inputs.json` |
| floor | `/home/andrew/scratch/w13/sol/kd2-flume-r8/population/floor/floor.json` | `/home/andrew/scratch/w13/sol/kd2-flume-r8/population-floor-inputs.json` |

### Stop classification

| Line / seed | Time s | Position XZ m | Classification | Enemy kind | Home or director provenance | Matching traced receipt |
| --- | --- | --- | --- | --- | --- | --- |
| All 56 seeds | none | none | zero observed stops | not applicable | not applicable | population receipts above |

No stops were observed in the final 56 qualified seeds, so no pack exemption or stop probe is required. Stop-replay records are in `/home/andrew/scratch/w13/sol/kd2-flume-r8/stop-replay-comparisons.json`. A pack exemption would require a matching traced solo, an observed enemy kind and spawning provenance inside the preceding 90 ticks. Ground-only contacts would count as terrain. The final population uses no exemption.

### Named replay qualification

| Line / seed | Batch / plain / traced equality | Qualification |
| --- | --- | --- |
| sable / 1 | equal | error-free qualified |
| rivet / 5 | equal | error-free qualified |
| sable / 4 | equal | error-free qualified |
| tally / 5 | equal | error-free qualified |
| floor / 1 | equal | error-free qualified |

Named replay acceptance: 5/5 qualified comparisons complete. Complete population cells above come from the 56 qualified child receipts; no rejected or missing row fills a cell.

Replay receipts and error qualification: `/home/andrew/scratch/w13/sol/kd2-flume-r8/replay-qualification.json`. Full runtime-input equality: `/home/andrew/scratch/w13/sol/kd2-flume-r8/input-equality.json`.

<!-- historical-win-results-r8 -->
### Historical win results, round 8

The unchanged scratch `win_600.gd` only sets the bot stage limit to 600 s before tick 1. Runs use `--table=park --from-stage=2 --stages=2 --policy=completionist`. Ruling 23 judges reach and engagement without a traversal-cause stall. Warden break times are reported separately and belong to the fight units and Andrew's task #5.

| Seed | Engage s | Break s | Engage to break s | Outcome | Stage stop | Receipt |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 116.69 | 289.03 | 172.34 | stalled | gates | `/home/andrew/scratch/w13/sol/kd2-flume-r8/win-seed-1/bots.ndjson` |
| 2 | 116.74 | not broken in 600 s | not applicable | stalled | beacon | `/home/andrew/scratch/w13/sol/kd2-flume-r8/win-seed-2/bots.ndjson` |
| 3 | 112.25 | not broken in 600 s | not applicable | stalled | beacon | `/home/andrew/scratch/w13/sol/kd2-flume-r8/win-seed-3/bots.ndjson` |

Every win seed reaches and engages. Child logs contain no collapse script error or missing park-cue error. ACE stem files are absent in this worktree, so these runs use the existing synth fallback. Listening is not qualified. Post-engagement fight or gate outcomes are reported above and do not change the stage traversal criterion.
<!-- /historical-win-results-r8 -->

The physical event regression observes finite matching deck-to-floor mesh and collider surfaces at five span positions at landing, 0.5 s, 1 s and 2 s. Its independent grid interpolation defines the authorized depth. The stage keeps its authored form, trigger, six-second lead, 20 m hold-clear distance, swap and route changes. Both authored music cue IDs resolve through the common runtime event/music path.

<!-- /flume-historical-table-r8 -->


<!-- flume-historical-table-r7 -->
## Historical measurements and qualification, round 7

<!-- flume-historical-receipts-r7
{
  "receipt_root": "/home/andrew/scratch/w13/sol/kd2-flume-r7",
  "head": "dfde1de818f455214a0f1fc947e91bd21569a254",
  "tool_sha256": "37e98e4ac7e0a5d4141d97828f5834a083d3267e83a90efccc26248b69ec574a"
}
-->

Measured runtime head `dfde1de818f455214a0f1fc947e91bd21569a254`, merged from candidate `1afb24f59c04f692d7e7c038012c80ec9c63cc1b` at `7f381358948e4ce97bf70a6cc4943dc12b87a0a8`. Committed traversal tool SHA256 `37e98e4ac7e0a5d4141d97828f5834a083d3267e83a90efccc26248b69ec574a`. The final source, tool and bake inputs match all final batch, replay and win manifests. Subsequent documentation and regression commits do not change these runtime inputs.

All 56 untraced seed rows pass error qualification from their child logs. Acceptance also requires the five named replay comparisons reported below. Each pilot uses seeds 1–8 in a fresh child process. The cells show median / worst seed and a measured verdict. Per-seed criteria use the worst seed. Segments, airborne share, tier-3 time and length retain their explicitly median-based criteria. The floor is judged only by arrival, maximum time against twice Rivet median and zero terrain stops; its other cells are reports.

The committed stage fixture independently checks this publication with `--docs`. It reads the saved seed receipts, input manifests, child logs and traced stop probes, then recomputes the table and saved win values. Marker-only tables and rejected populations fail.

| Band | sable | rivet | kest | tarn | tally | cannon | floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Reached Warden, 8/8 | 8 / 8 pass | 8 / 8 pass | 8 / 8 pass | 8 / 8 pass | 8 / 8 pass | 8 / 8 pass | 8 / 8 pass |
| Time s, median 60–120; worst ≤150 | 63.06 / 64.02 pass | 96.675 / 99.42 pass | 85.665 / 91.41 pass | 80.185 / 81.43 pass | 92.825 / 94.99 pass | 81.415 / 84.87 pass | 96.465 / 97.59, reported, pilot band, not the floor's |
| Segments s, each median 12–45 | [21.6, 21.11, 20.33] / [21.89, 22.3, 22.1] pass | [27.28, 36.245, 33.25] / [28.71, 37.16, 34.42] pass | [25.6, 35.34, 24.945] / [29.29, 35.82, 26.56] pass | [23.38, 26.445, 30.2] / [24.81, 26.6, 30.4] pass | [27.83, 30.895, 34.32] / [29.12, 31.76, 35.56] pass | [25.64, 36.795, 18.85] / [25.87, 37.2, 22.2] pass | [28.38, 30.08, 37.88] / [28.86, 30.57, 38.61], reported, pilot band, not the floor's |
| Flow, median ≥.70; worst ≥.60 | 0.9325 / 0.929 pass | 0.7631 / 0.7329 pass | 0.714 / 0.6478 pass | 0.9417 / 0.9294 pass | 0.7097 / 0.6334 pass | 0.9376 / 0.9071 pass | 0.5998 / 0.5858, reported, pilot band, not the floor's |
| Airborne, median .12–.45 | 0.2459 / [0.225, 0.265] pass | 0.12045 / [0.1162, 0.1286] pass | 0.161 / [0.1433, 0.163] pass | 0.1689 / [0.1616, 0.1711] pass | 0.1262 / [0.1206, 0.1337] pass | 0.16445 / [0.1284, 0.1771] pass | 0.1173 / [0.1141, 0.1267], reported, pilot band, not the floor's |
| Terrain or unclassified stops, every seed 0 | 0.0 / 1 MISS | 0.0 / 0 pass | 0.0 / 0 pass | 0.0 / 0 pass | 0.0 / 0 pass | 0.0 / 0 pass | 0.0 / 0 pass |
| Peak m/s, worst ≥26.6 | 54.5 / 54.25 pass | 37.11 / 32.24 pass | 31.305 / 31.08 pass | 33.76 / 31.8 pass | 32.82 / 32.6 pass | 32.25 / 31.26 pass | 34.69 / 32.8, reported, pilot band, not the floor's |
| Tier-3 s, median ≥3 | 47.68 / 46.86 pass | 7.79 / 7.59 pass | 6.95 / 3.98 pass | 9.5 / 8.74 pass | 8.465 / 6.11 pass | 11.41 / 8.19 pass | 8.1 / 7.87, reported, pilot band, not the floor's |
| Quiet s, worst ≤20 | 7.7 / 8.21 pass | 11.715 / 12.13 pass | 17.375 / 18.29 pass | 8.72 / 8.87 pass | 15.265 / 16.41 pass | 12.525 / 13.22 pass | 12.48 / 12.82, reported, pilot band, not the floor's |
| Anchor gap m, worst ≤40 | 29.8 / 30.8 pass | 30.3 / 31.5 pass | 25.25 / 30.3 pass | 35.7 / 35.7 pass | 32.05 / 35.3 pass | 20.75 / 31.6 pass | 30.75 / 34.8, reported, pilot band, not the floor's |
| Ride facts, worst ≥3 | 5.0 / 5 pass | 5.0 / 5 pass | 4.0 / 4 pass | 5.0 / 5 pass | 5.0 / 5 pass | 4.0 / 4 pass | 5.0 / 5, reported, pilot band, not the floor's |
| Length ratio, median 1.3–2.0 | 1.5 / [1.5, 1.52] pass | 1.43 / [1.43, 1.44] pass | 1.325 / [1.32, 1.36] pass | 1.36 / [1.36, 1.36] pass | 1.34 / [1.33, 1.34] pass | 1.34 / [1.33, 1.34] pass | 1.35 / [1.35, 1.36], reported, pilot band, not the floor's |
| Floor, ≤2× Rivet median; zero terrain stops | not applicable | not applicable | not applicable | not applicable | not applicable | not applicable | 96.465 / max 97.59; cap 193.35 pass |

| Line | Qualified population receipt | Input provenance |
| --- | --- | --- |
| sable | `/home/andrew/scratch/w13/sol/kd2-flume-r7/population/sable/sable.json` | `/home/andrew/scratch/w13/sol/kd2-flume-r7/population-sable-inputs.json` |
| rivet | `/home/andrew/scratch/w13/sol/kd2-flume-r7/population/rivet/rivet.json` | `/home/andrew/scratch/w13/sol/kd2-flume-r7/population-rivet-inputs.json` |
| kest | `/home/andrew/scratch/w13/sol/kd2-flume-r7/population/kest/kest.json` | `/home/andrew/scratch/w13/sol/kd2-flume-r7/population-kest-inputs.json` |
| tarn | `/home/andrew/scratch/w13/sol/kd2-flume-r7/population/tarn/tarn.json` | `/home/andrew/scratch/w13/sol/kd2-flume-r7/population-tarn-inputs.json` |
| tally | `/home/andrew/scratch/w13/sol/kd2-flume-r7/population/tally/tally.json` | `/home/andrew/scratch/w13/sol/kd2-flume-r7/population-tally-inputs.json` |
| cannon | `/home/andrew/scratch/w13/sol/kd2-flume-r7/population/cannon/cannon.json` | `/home/andrew/scratch/w13/sol/kd2-flume-r7/population-cannon-inputs.json` |
| floor | `/home/andrew/scratch/w13/sol/kd2-flume-r7/population/floor/floor.json` | `/home/andrew/scratch/w13/sol/kd2-flume-r7/population-floor-inputs.json` |

### Stop classification

| Line / seed | Time s | Position XZ m | Classification | Enemy kind | Home or director provenance | Matching traced receipt |
| --- | --- | --- | --- | --- | --- | --- |
| sable / 2 | 41.48 | [-97.6, 159.4] | terrain |  |  | `/home/andrew/scratch/w13/sol/kd2-flume-r7/stops/stop-sable2-trace/sable-seed-2-trace.json` |

All stops are reproduced by matching batch, plain, traced and read-only probe records in `/home/andrew/scratch/w13/sol/kd2-flume-r7/stop-replay-comparisons.json`. The probe trace matches the standard trace tick for tick. Pack exemptions require an observed enemy kind and spawning provenance inside the preceding 90 ticks. Ground-only contacts count as terrain. Rejected raw records remain diagnostic.

### Named replay qualification

| Line / seed | Batch / plain / traced equality | Qualification |
| --- | --- | --- |
| sable / 1 | equal | error-free qualified |
| rivet / 5 | equal | error-free qualified |
| sable / 4 | equal | error-free qualified |

Named replay acceptance: 3/5 qualified comparisons complete. The stage is not admitted while this proof is incomplete. Complete population cells above come from the 56 qualified child receipts; no rejected or missing row fills a cell.

Replay receipts and error qualification: `/home/andrew/scratch/w13/sol/kd2-flume-r7/replay-qualification.json`. Full runtime-input equality: `/home/andrew/scratch/w13/sol/kd2-flume-r7/input-equality.json`.

<!-- historical-win-results-r7 -->
### Historical win results, round 7

The unchanged scratch `win_600.gd` only sets the bot stage limit to 600 s before tick 1. Runs use `--table=park --from-stage=2 --stages=2 --policy=completionist`. Ruling 23 judges reach and engagement without a traversal-cause stall. Warden break times are reported separately and belong to the fight units and Andrew's task #5.

| Seed | Engage s | Break s | Engage to break s | Outcome | Stage stop | Receipt |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 116.69 | 299.4 | 182.71 | stalled | gates | `/home/andrew/scratch/w13/sol/kd2-flume-r7/win-seed-1/bots.ndjson` |
| 2 | 116.96 | not broken in 600 s | not applicable | stalled | beacon | `/home/andrew/scratch/w13/sol/kd2-flume-r7/win-seed-2/bots.ndjson` |
| 3 | 111.66 | not broken in 600 s | not applicable | stalled | beacon | `/home/andrew/scratch/w13/sol/kd2-flume-r7/win-seed-3/bots.ndjson` |

Every win seed reaches and engages. Child logs contain no collapse script error or missing music cue. Post-engagement fight or gate outcomes are reported above and do not change the stage traversal criterion.
<!-- /historical-win-results-r7 -->

The physical event regression observes finite matching deck-to-floor mesh and collider surfaces at five span positions at landing, 0.5 s, 1 s and 2 s. Its independent grid interpolation defines the authorized depth. The stage keeps its authored form, trigger, six-second lead, 20 m hold-clear distance, swap and route changes. Both authored music cue IDs resolve through the common runtime event/music path.

The shared ground-slump game fixtures retain an upstream timing failure: canonical downbeat remainder 0.56098191214518 s exceeds their 0.2 s pin. The same failure occurs on unmodified STEP 0 shared code. Their geometry and clearance checks pass, as do cave-in, natural, projection and event-family fixtures. This prevents a claim that the full shared suite is green.
<!-- /flume-historical-table-r7 -->





**Historical round 6 qualification: BLOCKED.** Candidate `1f09c265a68f274c0ae62d2155769b643a79a233` merged without conflicts at `e69bd20c11a4acefa041a3004991f6045bba4181`. Coordinator F1 authorizes `depth_m = 20.4413957595825` and `fill_s = 2.0`. A direct read of the committed baked grid at the flume span midpoint `[-115, 5.5]` gives hollow floor `y=23.5586042404175`, below deck `y=44`; the interpolation and input hashes are in `/home/andrew/scratch/w13/sol/kd2-flume-r6/measured-depth.json`.

In round 6 those fields removed the collapse's missing-key script errors and allow the fall to finish in two seconds. The independent real-stage mesh and collider regression remains red: the shared handler projects the `trestle_hollow` footprint, not the flume span, and none of five span samples has a ramp surface. The merged music engine also logs `ERROR: music: missing park cue drop_collapse`. Registration, telegraph, landing and route facts alone cannot qualify the physical ride. Shared geometry and music fixes remain coordinator follow-ups; no substitute form, trigger, lead, hold-clear distance, route change or shared runtime edit was made.

Every earlier table remains historical. Round 6 reruns use the committed `res://tools/traversal_line.gd`, SHA256 `37e98e4ac7e0a5d4141d97828f5834a083d3267e83a90efccc26248b69ec574a`, with untraced eight-seed batches and separate plain/traced solos. Error-aware qualification rejects `ERROR:` and `SCRIPT ERROR` logs even when the tool accepts a raw row. There is no complete qualified current table: 30/56 rows qualify. Receipts and input manifests are in `/home/andrew/scratch/w13/sol/kd2-flume-r6/`.

Coordinator F2 corrects the stale two-of-three break requirement. Ruling 23 requires every seed to reach and engage the Warden with no traversal-cause stall; breaks are reported separately under the unchanged 600 s wrapper. Warden fight duration belongs to the Warden fight units and Andrew's task #5.


<!-- historical-win-results-r6 -->
## Historical win results, round 6

Measured with the unchanged scratch `win_600.gd`, which only sets `stage_limit = 600.0` before tick 1. Each process uses `--table=park --from-stage=2 --stages=2 --policy=completionist`. Coordinator F2 and ruling 23 require engagement; breaks are reported separately. Historical proofs below remain historical.

| Seed | Engage s | Break s | Engage to break s | Outcome | Stage stop | Receipt |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 116.69 | 299.4 | 182.71 | stalled | gates | `/home/andrew/scratch/w13/sol/kd2-flume-r6/win-seed-1/bots.ndjson` |
| 2 | 118.64 | not broken in 600 s | not applicable | stalled | beacon | `/home/andrew/scratch/w13/sol/kd2-flume-r6/win-seed-2/bots.ndjson` |
| 3 | 110.52 | not broken in 600 s | not applicable | stalled | beacon | `/home/andrew/scratch/w13/sol/kd2-flume-r6/win-seed-3/bots.ndjson` |

Every seed reaches and engages the Warden; none stalls before engagement. The logs contain no `get_rid` script error. Each win log contains the shared missing `drop_collapse` music cue. The reach/engagement observations satisfy ruling 23; these runs do not establish error-free whole-stage execution or the physical fallen ramp. Post-engagement beacon or gate stalls are reported above. Warden break duration stays with the Warden fight units and Andrew's task #5.
<!-- /historical-win-results-r6 -->

## Historical population qualification, round 6

Measured runtime head `ea4974b6cb21f79bd180effe5d441d140e4c2cfd`, which descends from candidate `1f09c26` through merge `e69bd20`. Later commits change the regression and these pages; runtime source, committed tool and bake/graph inputs remain identical. The committed tool SHA256 is `37e98e4ac7e0a5d4141d97828f5834a083d3267e83a90efccc26248b69ec574a`. Each line uses an untraced seeds-1-to-8 batch in its own output folder. Input manifests are `population-<pilot>-inputs.json`; raw logs are `population/<pilot>/children/<position>-seed-<seed>/child.log`. All paths below are under `/home/andrew/scratch/w13/sol/kd2-flume-r6/`.

| Line | Tool-accepted rows | Error-qualified rows | Qualification |
| --- | --- | --- | --- |
| sable | 8/8 | 8/8 | complete |
| rivet | 8/8 | 0/8 | blocked by log errors or incomplete population |
| kest | 8/8 | 6/8 | blocked by log errors or incomplete population |
| tarn | 8/8 | 8/8 | complete |
| tally | 8/8 | 0/8 | blocked by log errors or incomplete population |
| cannon | 8/8 | 8/8 | complete |
| floor | 8/8 | 0/8 | blocked by log errors or incomplete population |

Total: 56/56 tool-accepted rows, 30/56 error-qualified rows. `population-qualification.json` and its log reject `SCRIPT ERROR` and `ERROR:` lines. Matching rejected records are diagnostic. `replay-qualification.json` retains the five named batch/plain/traced comparisons; `input-equality.json` proves matching runtime inputs.

The round-6 complete 13-band table remained BLOCKED. No rejected record is copied into a current table; every earlier table remains historical. `band-table.md` contains fully qualified line diagnostics, with other lines explicitly unqualified. It is not the acceptance table. Rulings 13 and 14 retain the floor's own arrival/time/zero-terrain-stop row and per-seed anchor check. Every per-seed band uses its worst seed; explicitly median-based criteria retain their medians.

Round-6 stop attribution was in `stop-classification.json` and `stop-replay-comparisons.json`. Sable seed 2 stops at 41.48 s, [-97.6, 159.4]. Batch, plain solo, traced solo and read-only probe agree; all 5,761 trace ticks match. The preceding 90 ticks contain ground contacts only. It counts as terrain under ruling 25. Its 48.6 m anchor gap exceeds 40 m. No pack exemption is inferred. Other qualified stops and unqualified raw records remain in the receipts; missing or rejected attribution cannot qualify zero terrain stops. No repair budget is consumed while the authored physical collapse and shared cue remain blocked.

**Historical round 5 qualification: BLOCKED.** STEP 0 merged candidate `3debeb86e30a63756e7e83c9950e37a79d656b68` at `56a4b80f8e9313cea755f11133dffb157eedcab7`, without conflicts. Every earlier traversal measurement is superseded by ruling 28. The bake and graph were rebuilt; the committed measuring tool is `tools/traversal_line.gd`, SHA256 `37e98e4ac7e0a5d4141d97828f5834a083d3267e83a90efccc26248b69ec574a`. The first fresh Sable and Rivet children throw at `natural.gd:267` because the authored hollow-collapse effect lacks `depth_m`. TRAV-DET2 rejects those rows as INCONCLUSIVE. The population was stopped, so there is no accepted round-5 population, replay equality, band verdict or stop classification. No geometry repair was made. Evidence and input hashes are under `/home/andrew/scratch/w13/sol/kd2-flume-r5/`.

The real-stage stepped probe loads stage 2 and advances its director with tier 2 and one `chunk_2` notification. It records the reactor telegraph at 0.0611 s and land at 5.6111 s, with a live fallout hazard and `annex_ramp_line` open. It records the collapse telegraph at 0.2611 s and land fact at 13.9611 s, with `flume_mid` closed and `trestle_ramp_line` open. The collapse throws on missing `depth_m` during setup and `fill_s` at land. Its emitted facts do not prove a working fallen ramp. `events-stage-red.log`, `events-stage.json` and `events-verdict.json` retain the runtime result; the error-aware qualification is FAIL despite the probe's eight fact assertions passing.

Ruling 23, reaffirmed by ruling 28, makes the stage win criterion engagement-only. Engagement and breaks remain separate. The historical round-4 proof records 3/3 engages and 0/3 breaks under the wrapper that only sets `stage_limit = 600.0` before tick 1. 0/3 breaks does not pass a two-of-three break criterion. No round-5 completionist proof is claimed while the real-stage initialization has script errors. Warden fight duration stays with WT-PARK.

The two median-only tool flags remain unchanged under the coordinator's approved override. Current qualification reads raw seed records and takes the maximum anchor gap and quiet time against the unchanged 40 m and 20 s limits. `worst-controls.json` demonstrates rejection when seven passing seeds hide one 49.8 m anchor gap or one 20.59 s quiet interval. The independent checker refuses an incomplete population. The final complete table awaits a corrected shared collapse handler or approved authored depth and fill duration; historical cells below are not a current pass.


## Greybox pass, fix round, 2026-10-11

Measured on commit b2da61d (park file, bake and graph; the lines file unchanged since). Machine load average 20 to 71 during the runs (three runs started after the 10 minute load wait). The table that stood here before this round was withdrawn: it was not measured on the committed park and lines files.

| Band | sable | rivet | kest | tarn | tally | cannon | floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| reached Warden (every seed) | 8 / - pass | 8 / - pass | 8 / - pass | 8 / - pass | 8 / - pass | 8 / - pass | 8 / - pass |
| time to Warden s (median 60-120, none over 150) | 61.925 / 63.33 pass | 104.595 / 105.18 pass | 90.26 / 91.27 pass | 85.905 / 89.33 pass | 98.49 / 100.94 pass | 87.345 / 89.7 pass | 100.65 / 104.5 pass |
| segment s (each median 12-45) | [24.86, 15.96, 20.81] / 24.855 pass | [27.05, 43.57, 34.2] / 43.57 pass | [25.37, 39.13, 25.59] / 39.125 pass | [24.28, 32.76, 29.02] / 32.76 pass | [26.63, 33.29, 38.56] / 38.56 pass | [24.84, 39.06, 23.44] / 39.065 pass | [27.42, 36.5, 36.28] / 36.75 pass |
| flow share (median >= 0.70, none under 0.60) | 0.9177 / 0.895 pass | 0.7256 / 0.6902 pass | 0.6382 / 0.6024 MISS | 0.8782 / 0.843 pass | 0.6088 / 0.5746 MISS | 0.9296 / 0.9231 pass | 0.5976 / 0.5695 reported |
| airborne share (0.12-0.45) | 0.2309 / - pass | 0.13 / - pass | 0.1638 / - pass | 0.1639 / - pass | 0.1519 / - pass | 0.2609 / - pass | 0.1225 / - pass |
| dead stops (0 on every seed) | 0 / 1 MISS | 2 / 2 MISS | 0 / 1 MISS | 2.5 / 7 MISS | 3 / 5 MISS | 1 / 2 MISS | 1.5 / 2 MISS |
| peak m/s (>= 26.6 blazing on every seed) | 54.595 / 53.79 pass | 35.025 / 32.56 pass | 30.705 / 28.85 pass | 32.38 / 31.7 pass | 35.83 / 33.17 pass | 33.93 / 31.59 pass | 35.365 / 34.3 pass |
| tier-3 s (median >= 3) | 42.975 / - pass | 8.085 / - pass | 7.155 / - pass | 9 / - pass | 8.495 / - pass | 12.345 / - pass | 8.305 / - pass |
| quiet max s (<= 20) | 10.325 / 13.22 pass | 14.195 / 15.7 pass | 16.505 / 17.17 pass | 13.8 / 13.91 pass | 17.925 / 20.59 MISS | 18.475 / 19.6 pass | 16.4 / 17.24 pass |
| anchor gap m (<= 40) | 51.65 / 94.7 MISS | 25.65 / 34.7 pass | 61.25 / 68.5 MISS | 32 / 34.5 pass | 22.4 / 24.5 pass | 218.15 / 233.8 MISS | 31.4 / 33.7 pass |
| distinct ride facts (>= 3) | 4 / 4 pass | 5 / 5 pass | 4 / 4 pass | 5 / 5 pass | 5 / 5 pass | 5 / 4 pass | 5 / 5 pass |
| length ratio (1.3-2.0) | 1.47 / - pass | 1.44 / - pass | 1.34 / - pass | 1.375 / - pass | 1.35 / - pass | 1.44 / - pass | 1.355 / - pass |
| progress m/s | not measured (KB7b) | not measured (KB7b) | not measured (KB7b) | not measured (KB7b) | not measured (KB7b) | not measured (KB7b) | not measured (KB7b) |

**Progress** is not measured: `traversal_line.gd`'s `_construct_graph` drops the stage graph on this head (ruling R12, fixed by KB7b).

**Ride facts.** Every park row with a recipe is built in play with its collider and ride sensor (`terrain.gd:218-220`, `ParkRecipes.build_placed`), so the anchor gap and distinct ride facts are row bands on this head. `lift_fired`, `crater_ride` and `wall_crumbled` drop out at KB7b (R11); the per-line fact lists below show which facts each pass rests on. Without `lift_fired` every line still counts at least 4 facts, so distinct ride facts passes after KB7b.

**Distinct lines.** 4 mutually distinct lines (Sable, Rivet, Tally, the Cannon), from the seed-1 traces (shared share under 0.5 both ways); the band asks for 3.

**Row misses open at the timebox** (fixed by reworking rows in a later round, never the band):

- Dead stops, clustered at fixed sites: the hollow's south end near [-160, 145] (Tarn on every seed, the floor line), the rim bend's foot near [121, 1] (Rivet), the bench pads near [-45, 413] and [39, 408] (Tally), the siphon's east side near [17, 223] (the Cannon, every seed), the butte gap's mouth [-255, -263] (Sable, one seed) and [90, 33] (Kest, one seed).
- Flow share: Kest (median 0.638), Tally (0.609) and the floor line (0.598) under 0.70; these are the lines with the stall sites above.
- Anchor gap: Sable (median 51.7 m, the flume reaches between the weir and the gap), Kest (61.3 m, the bluff run) and the Cannon (218 m, the bend zip crossing, where the cable alone carries the line) over 40 m.
- Floor rule: the time holds (worst 209.19 s against 2.0 times Rivet's 104.6 s median), the dead stops (median 1.5) miss.

```
Floor rule (`floor`, reaches the Warden in at most 2.0 times rivet's median time, 0 dead stops): median 100.65, worst 209.19, MISS

sable seeds [1, 2, 3, 4, 5, 6, 7, 8]: dead stops at [{'at': [-255.2, -262.9], 'time': 23.05}]; ride facts ['boost', 'lift_fired', 'ride_bowl', 'ride_chute', 'ride_drop', 'ride_grapple_line', 'special']
rivet seeds [1, 2, 3, 4, 5, 6, 7, 8]: dead stops at [{'at': [122.6, 1.2], 'time': 54.17}, {'at': [-467.5, -460.1], 'time': 14.01}, {'at': [120.6, 1.3], 'time': 56.64}, {'at': [123.9, 1.3], 'time': 55.9}, {'at': [123.0, 0.2], 'time': 56.45}, {'at': [120.6, 1.3], 'time': 55.91}, {'at': [118.8, 0.2], 'time': 56.46}, {'at': [122.5, 1.3], 'time': 55.98}, {'at': [123.5, 1.3], 'time': 56.14}, {'at': [121.6, 1.3], 'time': 55.64}, {'at': [120.5, 0.2], 'time': 56.19}, {'at': [121.5, 1.3], 'time': 55.31}, {'at': [120.2, 0.4], 'time': 55.83}]; ride facts ['dash', 'kicker_launch', 'lift_fired', 'ride_bowl', 'ride_chute', 'ride_drop', 'ride_grapple_line', 'special', 'sprint']
kest seeds [1, 2, 3, 4, 5, 6, 7, 8]: dead stops at [{'at': [89.9, 32.6], 'time': 53.16}]; ride facts ['blink', 'dash', 'kicker_launch', 'lift_fired', 'ride_bowl', 'ride_chute', 'ride_drop', 'special']
tarn seeds [1, 2, 3, 4, 5, 6, 7, 8]: dead stops at [{'at': [-160.2, 143.4], 'time': 46.42}, {'at': [-160.2, 143.4], 'time': 47.1}, {'at': [-160.5, 145.0], 'time': 50.22}, {'at': [-163.0, 144.9], 'time': 51.11}, {'at': [-160.5, 145.7], 'time': 46.0}, {'at': [-160.3, 146.2], 'time': 46.68}, {'at': [-160.2, 143.6], 'time': 46.02}, {'at': [-160.3, 143.5], 'time': 46.77}, {'at': [-160.7, 144.8], 'time': 50.51}, {'at': [-160.5, 148.2], 'time': 51.4}, {'at': [-115.8, 154.5], 'time': 54.59}, {'at': [-160.4, 145.1], 'time': 46.26}, {'at': [-161.5, 144.1], 'time': 46.89}, {'at': [-160.3, 143.9], 'time': 47.29}, {'at': [-160.3, 144.0], 'time': 48.2}, {'at': [-160.5, 145.1], 'time': 50.45}, {'at': [-162.2, 145.5], 'time': 51.31}, {'at': [-160.6, 147.0], 'time': 52.51}, {'at': [-160.3, 144.3], 'time': 46.07}, {'at': [-159.4, 142.4], 'time': 47.03}, {'at': [-160.5, 146.4], 'time': 46.32}, {'at': [-158.4, 148.0], 'time': 47.07}, {'at': [-160.3, 144.3], 'time': 46.34}, {'at': [-159.7, 142.3], 'time': 47.3}, {'at': [-160.3, 144.2], 'time': 46.19}, {'at': [-160.3, 143.1], 'time': 47.07}, {'at': [-160.7, 144.8], 'time': 50.57}]; ride facts ['dash', 'jump', 'kicker_launch', 'lift_fired', 'ride_bowl', 'ride_chute', 'ride_drop', 'ride_grapple_line', 'special']
tally seeds [1, 2, 3, 4, 5, 6, 7, 8]: dead stops at [{'at': [-44.4, 414.1], 'time': 78.59}, {'at': [-42.4, 415.5], 'time': 79.24}, {'at': [39.4, 408.1], 'time': 85.99}, {'at': [-46.0, 412.5], 'time': 79.11}, {'at': [-44.5, 412.4], 'time': 79.75}, {'at': [-42.6, 415.7], 'time': 81.02}, {'at': [39.3, 407.9], 'time': 87.15}, {'at': [-46.6, 412.2], 'time': 78.91}, {'at': [-46.5, 413.5], 'time': 79.44}, {'at': [39.4, 409.8], 'time': 86.68}, {'at': [-46.4, 412.4], 'time': 80.53}, {'at': [-42.8, 414.7], 'time': 81.67}, {'at': [39.3, 407.2], 'time': 88.14}, {'at': [-46.5, 412.4], 'time': 78.28}, {'at': [-42.9, 414.9], 'time': 79.32}, {'at': [-46.7, 412.0], 'time': 79.57}, {'at': [-47.5, 411.6], 'time': 80.1}, {'at': [-46.8, 410.4], 'time': 80.71}, {'at': [39.3, 406.9], 'time': 87.76}, {'at': [45.5, 415.6], 'time': 89.07}, {'at': [-43.9, 415.1], 'time': 77.73}, {'at': [-43.4, 414.5], 'time': 77.84}, {'at': [39.5, 409.6], 'time': 85.46}, {'at': [-46.7, 412.1], 'time': 77.79}, {'at': [-44.4, 415.1], 'time': 80.71}]; ride facts ['dash', 'kicker_launch', 'lift_fired', 'ride_bowl', 'ride_chute', 'ride_drop', 'ride_grapple_line', 'special']
cannon seeds [1, 2, 3, 4, 5, 6, 7, 8]: dead stops at [{'at': [17.6, 222.7], 'time': 66.84}, {'at': [18.1, 221.2], 'time': 67.05}, {'at': [17.1, 223.1], 'time': 67.76}, {'at': [17.1, 223.2], 'time': 68.99}, {'at': [18.1, 222.4], 'time': 68.15}, {'at': [16.1, 224.4], 'time': 70.08}, {'at': [16.5, 223.6], 'time': 68.05}, {'at': [17.4, 222.7], 'time': 69.06}]; ride facts ['dash', 'kicker_launch', 'lift_fired', 'ride_bowl', 'ride_chute', 'ride_drop', 'ride_grapple_line', 'special']
floor seeds [1, 2, 3, 4, 5, 6, 7, 8]: dead stops at [{'at': [-160.6, 146.8], 'time': 55.09}, {'at': [-220.1, 105.1], 'time': 49.39}, {'at': [-159.8, 142.5], 'time': 55.58}, {'at': [-160.3, 144.0], 'time': 54.17}, {'at': [-160.4, 144.5], 'time': 54.99}, {'at': [-160.2, 143.4], 'time': 53.68}, {'at': [-159.7, 142.4], 'time': 54.36}, {'at': [-160.4, 144.3], 'time': 53.64}, {'at': [-160.1, 142.8], 'time': 54.52}, {'at': [-160.3, 143.5], 'time': 54.33}, {'at': [-160.2, 143.3], 'time': 53.77}, {'at': [-160.3, 144.1], 'time': 54.09}]; ride facts ['kicker_launch', 'lift_fired', 'ride_bowl', 'ride_chute', 'ride_drop', 'ride_grapple_line']

Shared share (ticks of row line within 8 m of column line), seed 1:
| | sable | rivet | kest | tarn | tally | cannon |
| --- | --- | --- | --- | --- | --- | --- |
| sable | 1.00 | 0.25 | 0.07 | 0.32 | 0.21 | 0.08 |
| rivet | 0.27 | 1.00 | 0.65 | 0.58 | 0.36 | 0.41 |
| kest | 0.06 | 0.71 | 1.00 | 0.31 | 0.31 | 0.45 |
| tarn | 0.37 | 0.58 | 0.30 | 1.00 | 0.63 | 0.32 |
| tally | 0.27 | 0.39 | 0.29 | 0.65 | 1.00 | 0.33 |
| cannon | 0.08 | 0.47 | 0.45 | 0.35 | 0.34 | 1.00 |

largest set of mutually distinct lines: 4 ['sable', 'rivet', 'tally', 'cannon']
```

## Continuation baseline-alignment, 2026-10-12

Source head `01afdeb0ebde5da40013d049de1728fa13132c9c`; evidence `/tmp/claude-1000/w13-sol/kd2-flume-r1/baseline-alignment`. Seeds per line: {"sable": 8, "rivet": 8, "kest": 8, "tarn": 1, "tally": 1, "cannon": 1, "floor": 1}. Mixed counts or fewer than eight seeds are diagnostic and do not qualify acceptance. Per-seed limits use the worst column, including quiet time and anchor gap. Floor flow is reported.

| Band | sable | rivet | kest | tarn | tally | cannon | floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Reached Warden, 8/8 | 8 / 8 seeds pass | 8 / 8 seeds pass | 8 / 8 seeds pass | 1 / 1 seeds MISS | 1 / 1 seeds MISS | 1 / 1 seeds MISS | 1 / 1 seeds MISS |
| Time s, median 60–120; worst ≤150 | 62.07 / 64.05 pass | 104.235 / 105.18 pass | 90.26 / 91.27 pass | 88.12 / 88.12 pass | 97.92 / 97.92 pass | 88.63 / 88.63 pass | 101 / 101 pass |
| Segments s, medians 12–45 | [24.815, 15.745, 20.62] / 25.63 pass | [27.045, 43.57, 34.205] / 43.9 pass | [25.365, 39.125, 25.59] / 40.46 pass | [24.32, 34.6, 29.19] / 34.6 pass | [25.94, 33.44, 38.53] / 38.53 pass | [26.09, 39.09, 23.43] / 39.09 pass | [27.43, 37, 36.56] / 37 pass |
| Flow, median ≥.70; worst ≥.60; floor reported | 0.9178 / 0.8935 pass | 0.7256 / 0.6937 pass | 0.6381 / 0.6024 MISS | 0.8774 / 0.8774 pass | 0.6128 / 0.6128 MISS | 0.8946 / 0.8946 pass | 0.5914 / 0.5914 reported |
| Airborne, median .12–.45 | 0.2348 / [0.2253, 0.2631] pass | 0.1285 / [0.122, 0.141] pass | 0.1638 / [0.1564, 0.1685] pass | 0.1651 / [0.1651, 0.1651] pass | 0.1463 / [0.1463, 0.1463] pass | 0.1913 / [0.1913, 0.1913] pass | 0.1217 / [0.1217, 0.1217] pass |
| Dead stops, every seed 0 | 0 / 1 MISS | 2 / 2 MISS | 0 / 1 MISS | 4 / 4 MISS | 3 / 3 MISS | 2 / 2 MISS | 1 / 1 MISS |
| Peak m/s / tier-3 s, worst peak ≥26.6; median time ≥3 | [54.835, 43.52] / [51.87, 40.46] pass | [35.025, 8.055] / [32.56, 7.69] pass | [30.705, 7.155] / [28.85, 4.79] pass | [32.41, 8.97] / [32.41, 8.97] pass | [35.77, 8.1] / [35.77, 8.1] pass | [33.08, 12.03] / [33.08, 12.03] pass | [35.21, 7.86] / [35.21, 7.86] pass |
| Quiet s, worst ≤20 | 10.285 / 13.2 pass | 14.195 / 15.7 pass | 16.505 / 17.17 pass | 13.81 / 13.81 pass | 17.16 / 17.16 pass | 20.14 / 20.14 MISS | 17.11 / 17.11 pass |
| Anchor gap m, worst ≤40 | 49.55 / 81.3 MISS | 25.75 / 34.7 pass | 61.25 / 68.5 MISS | 34.5 / 34.5 pass | 24.5 / 24.5 pass | 174.8 / 174.8 MISS | 29.6 / 29.6 pass |
| Ride facts, at least 3 | 4 / 4 pass | 5 / 5 pass | 4 / 4 pass | 5 / 5 pass | 5 / 5 pass | 5 / 5 pass | 5 / 5 pass |
| Length ratio, median 1.3–2.0 | 1.475 / [1.45, 1.5] pass | 1.44 / [1.44, 1.45] pass | 1.34 / [1.33, 1.35] pass | 1.38 / [1.38, 1.38] pass | 1.35 / [1.35, 1.35] pass | 1.42 / [1.42, 1.42] pass | 1.36 / [1.36, 1.36] pass |
| Floor, ≤2× Rivet median; 0 stops | not applicable | not applicable | not applicable | not applicable | not applicable | not applicable | 101 / max 101; cap 208.47 MISS |
| Distinct lines, at least 3 | 4 / stage pass | 4 / stage pass | 4 / stage pass | 4 / stage pass | 4 / stage pass | 4 / stage pass | 4 / stage pass |

Distinct seed-1 lines: 4 sable, rivet, tally, cannon.

| Shared fraction | sable | rivet | kest | tarn | tally | cannon |
| --- | --- | --- | --- | --- | --- | --- |
| sable | 1.000 | 0.252 | 0.081 | 0.304 | 0.207 | 0.087 |
| rivet | 0.276 | 1.000 | 0.647 | 0.578 | 0.364 | 0.413 |
| kest | 0.064 | 0.706 | 1.000 | 0.309 | 0.309 | 0.444 |
| tarn | 0.359 | 0.582 | 0.301 | 1.000 | 0.632 | 0.326 |
| tally | 0.272 | 0.392 | 0.294 | 0.652 | 1.000 | 0.318 |
| cannon | 0.075 | 0.468 | 0.445 | 0.349 | 0.339 | 1.000 |

Dead-stop sites by seed:

- sable seed 2: [{"at": [-156.1, -425.7], "time": 15.28}]
- rivet seed 1: [{"at": [122.6, 1.2], "time": 54.17}]
- rivet seed 2: [{"at": [-467.5, -460.1], "time": 14.01}, {"at": [120.6, 1.3], "time": 56.64}]
- rivet seed 3: [{"at": [123.9, 1.3], "time": 55.9}, {"at": [123.0, 0.2], "time": 56.45}]
- rivet seed 4: [{"at": [120.6, 1.3], "time": 55.91}, {"at": [118.8, 0.2], "time": 56.46}]
- rivet seed 5: [{"at": [122.5, 1.3], "time": 55.98}]
- rivet seed 6: [{"at": [122.2, 1.3], "time": 56.12}]
- rivet seed 7: [{"at": [121.6, 1.3], "time": 55.64}, {"at": [120.5, 0.2], "time": 56.19}]
- rivet seed 8: [{"at": [121.5, 1.3], "time": 55.31}, {"at": [120.2, 0.4], "time": 55.83}]
- kest seed 5: [{"at": [89.9, 32.6], "time": 53.16}]
- tarn seed 1: [{"at": [-160.2, 143.4], "time": 46.42}, {"at": [-160.2, 143.4], "time": 47.1}, {"at": [-160.5, 145.0], "time": 50.22}, {"at": [-163.0, 144.9], "time": 51.11}]
- tally seed 1: [{"at": [-44.4, 414.1], "time": 78.59}, {"at": [-42.4, 415.5], "time": 79.24}, {"at": [39.4, 408.1], "time": 85.99}]
- cannon seed 1: [{"at": [18.7, 221.8], "time": 70.05}, {"at": [19.0, 221.1], "time": 70.16}]
- floor seed 1: [{"at": [-160.6, 146.8], "time": 55.09}]

Progress from the fresh stage graph, reported:

- sable: median 22.035 m/s, worst 21.24 m/s.
- rivet: median 13.2 m/s, worst 13.07 m/s.
- kest: median 15.265 m/s, worst 15.13 m/s.
- tarn: median 15.6 m/s, worst 15.6 m/s.
- tally: median 14.03 m/s, worst 14.03 m/s.
- cannon: median 15.12 m/s, worst 15.12 m/s.
- floor: median 13.61 m/s, worst 13.61 m/s.

## Continuation rework1-probe, 2026-10-12

Source head `60f1a3fa882eeea84571e10528379b908440dace`; evidence `/tmp/claude-1000/w13-sol/kd2-flume-r1/rework1-probe`. Seeds per line: {"sable": 2, "rivet": 1, "kest": 1, "tarn": 1, "tally": 1, "cannon": 1, "floor": 1}. Mixed counts or fewer than eight seeds are diagnostic and do not qualify acceptance. Per-seed limits use the worst column, including quiet time and anchor gap. Floor flow is reported.

| Band | sable | rivet | kest | tarn | tally | cannon | floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Reached Warden, 8/8 | 2 / 2 seeds MISS | 1 / 1 seeds MISS | 1 / 1 seeds MISS | 1 / 1 seeds MISS | 1 / 1 seeds MISS | 1 / 1 seeds MISS | 1 / 1 seeds MISS |
| Time s, median 60–120; worst ≤150 | 64.785 / 65.4 pass | 107.47 / 107.47 pass | 95.01 / 95.01 pass | 80.69 / 80.69 pass | 94.62 / 94.62 pass | 94.71 / 94.71 pass | 100.72 / 100.72 pass |
| Segments s, medians 12–45 | [27.01, 18.24, 19.525] / 27.02 pass | [26.89, 46.33, 34.23] / 46.33 MISS | [26.2, 41.92, 26.88] / 41.92 pass | [23.48, 28.24, 28.96] / 28.96 pass | [26.48, 33.54, 34.59] / 34.59 pass | [25.9, 42.86, 25.94] / 42.86 pass | [27.95, 36, 36.77] / 36.77 pass |
| Flow, median ≥.70; worst ≥.60; floor reported | 0.8757 / 0.868 pass | 0.644 / 0.644 MISS | 0.5292 / 0.5292 MISS | 0.9456 / 0.9456 pass | 0.7364 / 0.7364 pass | 0.8189 / 0.8189 pass | 0.5828 / 0.5828 reported |
| Airborne, median .12–.45 | 0.236 / [0.2241, 0.2479] pass | 0.1181 / [0.1181, 0.1181] MISS | 0.1668 / [0.1668, 0.1668] pass | 0.169 / [0.169, 0.169] pass | 0.139 / [0.139, 0.139] pass | 0.2564 / [0.2564, 0.2564] pass | 0.1237 / [0.1237, 0.1237] pass |
| Dead stops, every seed 0 | 1.5 / 2 MISS | 4 / 4 MISS | 3 / 3 MISS | 1 / 1 MISS | 1 / 1 MISS | 7 / 7 MISS | 1 / 1 MISS |
| Peak m/s / tier-3 s, worst peak ≥26.6; median time ≥3 | [54.77, 39.005] / [54.52, 38.18] pass | [36.26, 7.77] / [36.26, 7.77] pass | [30.98, 6.92] / [30.98, 6.92] pass | [33.99, 9.06] / [33.99, 9.06] pass | [35.77, 8.28] / [35.77, 8.28] pass | [31.19, 12.7] / [31.19, 12.7] pass | [35.18, 8.68] / [35.18, 8.68] pass |
| Quiet s, worst ≤20 | 12.92 / 13.22 pass | 11.39 / 11.39 pass | 17.64 / 17.64 pass | 13.64 / 13.64 pass | 14.07 / 14.07 pass | 16.79 / 16.79 pass | 16.71 / 16.71 pass |
| Anchor gap m, worst ≤40 | 47.65 / 59.5 MISS | 53 / 53 MISS | 34.8 / 34.8 pass | 32.1 / 32.1 pass | 70.2 / 70.2 MISS | 218.5 / 218.5 MISS | 29.6 / 29.6 pass |
| Ride facts, at least 3 | 4 / 4 pass | 5 / 5 pass | 5 / 5 pass | 5 / 5 pass | 5 / 5 pass | 5 / 5 pass | 5 / 5 pass |
| Length ratio, median 1.3–2.0 | 1.445 / [1.43, 1.46] pass | 1.46 / [1.46, 1.46] pass | 1.35 / [1.35, 1.35] pass | 1.35 / [1.35, 1.35] pass | 1.34 / [1.34, 1.34] pass | 1.47 / [1.47, 1.47] pass | 1.36 / [1.36, 1.36] pass |
| Floor, ≤2× Rivet median; 0 stops | not applicable | not applicable | not applicable | not applicable | not applicable | not applicable | 100.72 / max 100.72; cap 214.94 MISS |
| Distinct lines, at least 3 | 4 / stage pass | 4 / stage pass | 4 / stage pass | 4 / stage pass | 4 / stage pass | 4 / stage pass | 4 / stage pass |

Distinct seed-1 lines: 4 sable, rivet, tally, cannon.

| Shared fraction | sable | rivet | kest | tarn | tally | cannon |
| --- | --- | --- | --- | --- | --- | --- |
| sable | 1.000 | 0.286 | 0.088 | 0.384 | 0.251 | 0.093 |
| rivet | 0.332 | 1.000 | 0.647 | 0.580 | 0.379 | 0.449 |
| kest | 0.074 | 0.699 | 1.000 | 0.317 | 0.313 | 0.470 |
| tarn | 0.407 | 0.646 | 0.332 | 1.000 | 0.685 | 0.341 |
| tally | 0.256 | 0.421 | 0.314 | 0.665 | 1.000 | 0.335 |
| cannon | 0.109 | 0.490 | 0.467 | 0.334 | 0.331 | 1.000 |

Dead-stop sites by seed:

- sable seed 1: [{"at": [-96.7, 159.0], "time": 42.48}]
- sable seed 2: [{"at": [-212.1, -528.1], "time": 10.77}, {"at": [-189.3, -513.3], "time": 12.17}]
- rivet seed 1: [{"at": [-280.6, -230.6], "time": 27.45}, {"at": [-248.6, -224.6], "time": 32.35}, {"at": [82.8, -44.5], "time": 54.45}, {"at": [83.3, -45.1], "time": 55.46}]
- kest seed 1: [{"at": [-281.3, -229.3], "time": 26.8}, {"at": [-248.4, -225.0], "time": 31.13}, {"at": [86.9, -36.0], "time": 52.69}]
- tarn seed 1: [{"at": [-282.0, -228.1], "time": 24.13}]
- tally seed 1: [{"at": [-281.9, -228.1], "time": 27.14}]
- cannon seed 1: [{"at": [-280.5, -230.8], "time": 26.51}, {"at": [-279.6, -232.5], "time": 27.21}, {"at": [-275.8, -240.3], "time": 28.45}, {"at": [-247.8, -226.2], "time": 31.47}, {"at": [68.0, 260.4], "time": 77.11}, {"at": [86.9, 278.5], "time": 79.7}, {"at": [86.0, 279.5], "time": 80.41}]
- floor seed 1: [{"at": [-280.8, -230.4], "time": 28.49}]

Progress from the fresh stage graph, reported:

- sable: median 21.13 m/s, worst 21.06 m/s.
- rivet: median 12.78 m/s, worst 12.78 m/s.
- kest: median 14.5 m/s, worst 14.5 m/s.
- tarn: median 17.03 m/s, worst 17.03 m/s.
- tally: median 14.56 m/s, worst 14.56 m/s.
- cannon: median 14.14 m/s, worst 14.14 m/s.
- floor: median 13.67 m/s, worst 13.67 m/s.

## Continuation rework2-probe, 2026-10-12

Source head `901f99b72b0f6a90e03d815da645e9de1480b7a4`; evidence `/tmp/claude-1000/w13-sol/kd2-flume-r1/rework2-probe`. Seeds per line: {"sable": 2, "rivet": 1, "kest": 1, "tarn": 1, "tally": 1, "cannon": 1, "floor": 1}. Mixed counts or fewer than eight seeds are diagnostic and do not qualify acceptance. Per-seed limits use the worst column, including quiet time and anchor gap. Floor flow is reported.

| Band | sable | rivet | kest | tarn | tally | cannon | floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Reached Warden, 8/8 | 2 / 2 seeds MISS | 1 / 1 seeds MISS | 1 / 1 seeds MISS | 1 / 1 seeds MISS | 1 / 1 seeds MISS | 1 / 1 seeds MISS | 1 / 1 seeds MISS |
| Time s, median 60–120; worst ≤150 | 57.765 / 57.78 MISS | 101.44 / 101.44 pass | 92.43 / 92.43 pass | 80.48 / 80.48 pass | 94.55 / 94.55 pass | 86.6 / 86.6 pass | 99.3 / 99.3 pass |
| Segments s, medians 12–45 | [22.04, 14.42, 21.29] / 22.69 pass | [26.89, 39.9, 34.63] / 39.9 pass | [26.2, 39.17, 27.06] / 39.17 pass | [23.48, 27.6, 29.39] / 29.39 pass | [26.48, 33.24, 34.81] / 34.81 pass | [25.9, 39.13, 21.56] / 39.13 pass | [27.95, 35.46, 35.89] / 35.89 pass |
| Flow, median ≥.70; worst ≥.60; floor reported | 0.9343 / 0.9204 pass | 0.7515 / 0.7515 pass | 0.5983 / 0.5983 MISS | 0.9678 / 0.9678 pass | 0.6845 / 0.6845 MISS | 0.9233 / 0.9233 pass | 0.6025 / 0.6025 reported |
| Airborne, median .12–.45 | 0.2777 / [0.2686, 0.2868] pass | 0.131 / [0.131, 0.131] pass | 0.1606 / [0.1606, 0.1606] pass | 0.1734 / [0.1734, 0.1734] pass | 0.136 / [0.136, 0.136] pass | 0.2711 / [0.2711, 0.2711] pass | 0.1185 / [0.1185, 0.1185] MISS |
| Dead stops, every seed 0 | 0.5 / 1 MISS | 0 / 0 pass | 0 / 0 pass | 0 / 0 pass | 0 / 0 pass | 0 / 0 pass | 0 / 0 pass |
| Peak m/s / tier-3 s, worst peak ≥26.6; median time ≥3 | [54.59, 45.175] / [54.39, 44.14] pass | [36.26, 7.87] / [36.26, 7.87] pass | [30.98, 6.99] / [30.98, 6.99] pass | [33.99, 9.27] / [33.99, 9.27] pass | [35.77, 8.44] / [35.77, 8.44] pass | [31.19, 12.76] / [31.19, 12.76] pass | [35.18, 8.56] / [35.18, 8.56] pass |
| Quiet s, worst ≤20 | 10.075 / 11.46 pass | 11.86 / 11.86 pass | 16.67 / 16.67 pass | 13.81 / 13.81 pass | 14.5 / 14.5 pass | 17.78 / 17.78 pass | 16.62 / 16.62 pass |
| Anchor gap m, worst ≤40 | 33.35 / 38.2 pass | 41 / 41 MISS | 64.7 / 64.7 MISS | 31.5 / 31.5 pass | 22 / 22 pass | 219.2 / 219.2 MISS | 31.4 / 31.4 pass |
| Ride facts, at least 3 | 4 / 4 pass | 5 / 5 pass | 4 / 4 pass | 5 / 5 pass | 5 / 5 pass | 5 / 5 pass | 5 / 5 pass |
| Length ratio, median 1.3–2.0 | 1.455 / [1.42, 1.49] pass | 1.43 / [1.43, 1.43] pass | 1.34 / [1.34, 1.34] pass | 1.36 / [1.36, 1.36] pass | 1.34 / [1.34, 1.34] pass | 1.44 / [1.44, 1.44] pass | 1.36 / [1.36, 1.36] pass |
| Floor, ≤2× Rivet median; 0 stops | not applicable | not applicable | not applicable | not applicable | not applicable | not applicable | 99.3 / max 99.3; cap 202.88 pass |
| Distinct lines, at least 3 | 4 / stage pass | 4 / stage pass | 4 / stage pass | 4 / stage pass | 4 / stage pass | 4 / stage pass | 4 / stage pass |

Distinct seed-1 lines: 4 sable, rivet, tally, cannon.

| Shared fraction | sable | rivet | kest | tarn | tally | cannon |
| --- | --- | --- | --- | --- | --- | --- |
| sable | 1.000 | 0.311 | 0.084 | 0.443 | 0.265 | 0.088 |
| rivet | 0.324 | 1.000 | 0.651 | 0.606 | 0.377 | 0.425 |
| kest | 0.062 | 0.704 | 1.000 | 0.321 | 0.325 | 0.468 |
| tarn | 0.440 | 0.642 | 0.326 | 1.000 | 0.685 | 0.340 |
| tally | 0.267 | 0.399 | 0.320 | 0.668 | 1.000 | 0.337 |
| cannon | 0.084 | 0.476 | 0.469 | 0.354 | 0.353 | 1.000 |

Dead-stop sites by seed:

- sable seed 2: [{"at": [29.6, 213.1], "time": 38.62}]

Progress from the fresh stage graph, reported:

- sable: median 23.805 m/s, worst 23.77 m/s.
- rivet: median 13.54 m/s, worst 13.54 m/s.
- kest: median 14.9 m/s, worst 14.9 m/s.
- tarn: median 16.9 m/s, worst 16.9 m/s.
- tally: median 14.57 m/s, worst 14.57 m/s.
- cannon: median 15.47 m/s, worst 15.47 m/s.
- floor: median 13.84 m/s, worst 13.84 m/s.

## Continuation carry-population, 2026-10-12

Source head `53283b50be494f9a2409b0499f2b06d283f0eeed`; evidence `/tmp/claude-1000/w13-sol/kd2-flume-r2/carry-population`. Seeds per line: {"sable": 8, "rivet": 8, "kest": 8, "tarn": 0, "tally": 0, "cannon": 0, "floor": 0}. Mixed counts or fewer than eight seeds are diagnostic and do not qualify acceptance. Per-seed limits use the worst column, including quiet time and anchor gap. Floor measures are reported except its own time-and-stop rule.

| Band | sable | rivet | kest | tarn | tally | cannon | floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Reached Warden, 8/8 | 8 / 8 seeds pass | 8 / 8 seeds pass | 8 / 8 seeds pass | pending | pending | pending | pending |
| Time s, median 60–120; worst ≤150 | 62.685 / 63.45 pass | 96.065 / 99.57 pass | 86.19 / 93.21 pass | pending | pending | pending | pending, reported, pilot band, not the floor's |
| Segments s, medians 12–45 | [21.63, 20.7, 19.695] / 22.36 pass | [27.55, 35.49, 32.85] / 37.29 pass | [25.665, 34.795, 25.27] / 38 pass | pending | pending | pending | pending, reported, pilot band, not the floor's |
| Flow, median ≥.70; worst ≥.60; floor reported | 0.9355 / 0.9315 pass | 0.7519 / 0.7215 pass | 0.7005 / 0.5394 MISS | pending | pending | pending | pending, reported, pilot band, not the floor's |
| Airborne, median .12–.45 | 0.246 / [0.2365, 0.2743] pass | 0.1217 / [0.1139, 0.1299] pass | 0.1573 / [0.1424, 0.1672] pass | pending | pending | pending | pending, reported, pilot band, not the floor's |
| Dead stops, every seed 0 | 0 / 0 pass | 0 / 0 pass | 0 / 0 pass | pending | pending | pending | pending |
| Peak m/s / tier-3 s, worst peak ≥26.6; median time ≥3 | [54.915, 46.715] / [54.6, 45.23] pass | [36.025, 8.225] / [32.01, 7.59] pass | [31.515, 6.785] / [31.19, 4.04] pass | pending | pending | pending | pending, reported, pilot band, not the floor's |
| Quiet s, worst ≤20 | 7.78 / 8.04 pass | 11.7 / 12.19 pass | 17.53 / 19.3 pass | pending | pending | pending | pending, reported, pilot band, not the floor's |
| Anchor gap m, worst ≤40 | 28.2 / 32.2 pass | 27.9 / 30.1 pass | 22.35 / 50.3 MISS | pending | pending | pending | pending, reported, pilot band, not the floor's |
| Ride facts, at least 3 | 5 / 4 pass | 5 / 5 pass | 4 / 4 pass | pending | pending | pending | pending, reported, pilot band, not the floor's |
| Length ratio, median 1.3–2.0 | 1.51 / [1.49, 1.52] pass | 1.43 / [1.43, 1.43] pass | 1.33 / [1.32, 1.35] pass | pending | pending | pending | pending, reported, pilot band, not the floor's |
| Floor, ≤2× Rivet median; 0 stops | not applicable | not applicable | not applicable | pending | pending | pending | pending |
| Distinct lines, at least 3 | 0 / stage not measured | 0 / stage not measured | 0 / stage not measured | pending | pending | pending | pending, reported, pilot band, not the floor's |

Distinct-line proof: not measured on these inputs.


Dead-stop sites by seed:


Progress from the fresh stage graph, reported:

- sable: median 21.995 m/s, worst 21.59 m/s.
- rivet: median 14.42 m/s, worst 13.9 m/s.
- kest: median 16.095 m/s, worst 14.88 m/s.

**Round-2 greybox verdict: FAIL, timebox closed.** The stock untraced final population completed 30 of 56 runs: Sable, Rivet and Kest eight each, Tarn six, and Tally, Cannon and floor unrun. All completed runs recorded zero dead stops. Kest seed 2 flow is 0.5394 against the per-seed minimum 0.60; seed 3 anchor gap is 50.3 m against 40 m. The current distinct-line proof and win proof remain unrun. The dressed prerequisite was not met. Partial Tarn console results remain diagnostic, without an eight-seed summary. See `/tmp/claude-1000/w13-sol/kd2-flume-r2/REPORT.md` and `carry-population/inputs.json` for the version-bound evidence.

The cutoff was 15:51:38 UTC; captured session 47094 stopped at 15:51:45 UTC with exit 130 through the tool call. No matching runner or Godot process remained. Gameplay hashes stayed identical; the closing commit changes only these evidence pages.

## Round3 greybox, fixed TRAV-DET, 2026-10-12

**Round-4 reconciliation pending.** R24 requires a new candidate-tool population before current bands are definitive. The table below preserves the round-3 writer measurements at `c9f2483`, not the round-4 verdict. The independent gate at `9cd1ec5` measured Sable worst time 64.88 s, Rivet airborne median 0.12135, and classified floor seed 1 as terrain at 50.303 s, [-189.34, 20.43, 142.24], from its matching ground-only traced replay. Receipts are `/tmp/claude-1000/w13-cgate/kd2-flume-r3/band-analysis.json` and `floor-solo1-trace-replay.json`. Round-3 writer Sable/Rivet values conflict with that gate, so their current verdicts are pending. The three anonymous pack exemptions are also pending until R25 contact attribution or candidate runs eliminate the stops.

**Historical round-3 writer verdict: FAIL.** All 56 final-geometry seed rows are complete with the fixed TRAV-DET export. The three completionist seeds break the Warden under the 600 s wrapper. Rivet misses airborne share and Tally misses flow, with the exact values in the table below. The floor's raw seed-1 stop remains unclassified: its untraced solo matches the batch, but both traced solos differ, including a later trace without another owned traversal. Kest seed 2, Tally seed 3 and Cannon seed 2 have confirmed pack contacts, separate from terrain. The export does not record enemy kind. No dressed pass was started. The bank received two bounded repairs, ending at 132×6×104 m, centre [-135,149], yaw 76. No third repair at that site was attempted.

**Measured round 3, 2026-10-12.** Geometry/code head `c9f24835d43005265aa05554d712110dc541a525`. Evidence `/tmp/claude-1000/w13-sol/kd2-flume-r3/bank2-clean-population`. All seven lines have eight seeds. Five unchanged complete batches are retained with matching input hashes. Kest and Cannon were repeated under the two-line cap after an earlier concurrency breach. No prior-geometry summary is used. Cells give median/worst, with ranges for bounded measures. Quiet and anchor limits use the worst seed. Floor measures are reported except its own time/stop rule. The table and raw-stop classification appear in `design-v3/park/traversal/park_flume.md` and `/tmp/claude-1000/w13-sol/kd2-flume-r3/REPORT.md`.

| Band | sable | rivet | kest | tarn | tally | cannon | floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Reached Warden, 8/8 | 8 / 8 seeds pass | 8 / 8 seeds pass | 8 / 8 seeds pass | 8 / 8 seeds pass | 8 / 8 seeds pass | 8 / 8 seeds pass | 8 / 8 seeds pass |
| Time s, median 60–120; worst ≤150 | 63.09 / 63.63 pass | 96.37 / 98.15 pass | 86.03 / 91.96 pass | 78.54 / 82.59 pass | 92.365 / 94.7 pass | 82.015 / 84.15 pass | 96.305 / 97.58, reported, pilot band, not the floor's |
| Segments s, medians 12–45 | [21.66, 21.54, 20.21] / 22.62 pass | [27.26, 36.23, 33.07] / 36.62 pass | [25.59, 35.19, 25.03] / 37.7 pass | [23.08, 26.01, 29.44] / 29.87 pass | [27.615, 30.74, 34.23] / 35.47 pass | [25.66, 36.865, 19.13] / 38.57 pass | [27.915, 31.055, 36.815] / 38.14, reported, pilot band, not the floor's |
| Flow, median ≥.70; worst ≥.60 | 0.927 / 0.9255 pass | 0.7606 / 0.7189 pass | 0.7161 / 0.6301 pass | 0.9697 / 0.9286 pass | 0.6918 / 0.5984 MISS | 0.9383 / 0.911 pass | 0.5871 / 0.5538, reported, pilot band, not the floor's |
| Airborne, median .12–.45 | 0.236 / [0.2209, 0.2601] pass | 0.1198 / [0.1123, 0.1308] MISS | 0.1603 / [0.1498, 0.1668] pass | 0.1645 / [0.1591, 0.1645] pass | 0.1277 / [0.1185, 0.1355] pass | 0.1635 / [0.1337, 0.1752] pass | 0.1142 / [0.1076, 0.1226], reported, pilot band, not the floor's |
| Terrain or unclassified stops, every seed 0 | 0 / 0 pass | 0 / 0 pass | 0 / 0 pass | 0 / 0 pass | 0 / 0 pass | 0 / 0 pass | 0 / 1 MISS |
| Peak m/s / tier-3 s, worst peak ≥26.6; median time ≥3 | [54.02, 46.11] / [52.11, 45.52] pass | [35.925, 8.085] / [32.76, 7.77] pass | [31.675, 6.965] / [31.19, 4.12] pass | [35.48, 9.29] / [33.17, 6.42] pass | [35.26, 8.36] / [33.22, 6.87] pass | [32.79, 11.51] / [31.64, 8.4] pass | [35.9, 8.185] / [33.14, 7.93], reported, pilot band, not the floor's |
| Quiet s, worst ≤20 | 7.81 / 8.03 pass | 11.64 / 12.19 pass | 17.61 / 17.96 pass | 8.76 / 9.5 pass | 13.785 / 14.61 pass | 12.74 / 13.88 pass | 12.5 / 12.69, reported, pilot band, not the floor's |
| Anchor gap m, worst ≤40 | 28.6 / 32.3 pass | 26.2 / 30.1 pass | 20.4 / 27.7 pass | 27.2 / 33.1 pass | 32.8 / 35.4 pass | 19.7 / 29.2 pass | 31.2 / 34.1, reported, pilot band, not the floor's |
| Ride facts, at least 3 | 5 / 5 pass | 5 / 5 pass | 4 / 4 pass | 5 / 5 pass | 5 / 5 pass | 4 / 4 pass | 5 / 5, reported, pilot band, not the floor's |
| Length ratio, median 1.3–2.0 | 1.52 / [1.51, 1.53] pass | 1.43 / [1.43, 1.43] pass | 1.325 / [1.32, 1.35] pass | 1.35 / [1.35, 1.36] pass | 1.335 / [1.33, 1.34] pass | 1.34 / [1.32, 1.37] pass | 1.35 / [1.35, 1.36], reported, pilot band, not the floor's |
| Floor, ≤2× Rivet median; 0 terrain stops | not applicable | not applicable | not applicable | not applicable | not applicable | not applicable | 96.305 / max 97.58; cap 192.74 MISS |
| Distinct lines, reported | not supplied by fixed tool; not gated | not supplied by fixed tool; not gated | not supplied by fixed tool; not gated | not supplied by fixed tool; not gated | not supplied by fixed tool; not gated | not supplied by fixed tool; not gated | not supplied by fixed tool; not gated |
| Pack dead stops, classified separately | 0 | 0 | seed 2, t 50.367, [49.11, 29.19, -59.58], kind not recorded | 0 | seed 3, t 49.889, [-148.14, 20.74, 129.0], kind not recorded | seed 2, t 49.167, [114.9, 26.85, -48.42], kind not recorded | classification pending |

Dead-stop sites by seed:

- kest seed 2: [{"at": [49.1, -59.6], "time": 50.37}]
- tally seed 3: [{"at": [-148.1, 129.0], "time": 49.89}]
- cannon seed 2: [{"at": [114.9, -48.4], "time": 49.17}]
- floor seed 1: [{"at": [-189.3, 142.2], "time": 50.3}]

### Win proof

| Seed | Engaged s | Broken s | Fight s | Damage | After break |
| --- | --- | --- | --- | --- | --- |
| 1 | 118.83 | 154.94 | 36.11 | 800.0 | gate approach stall; no stage clear or Brindle entry |
| 2 | 116.34 | 177.82 | 61.48 | 800.0 | gate approach stall; no stage clear or Brindle entry |
| 3 | 140.04 | 180.96 | 40.92 | 800.0 | entered Brindle; reached phase 2; boss_stalled at boss time 420.01 s |

The reactor runs without its park mounting until KF8-WIRE. No mounting or driver workaround was applied. The eight-file smoke, compile, lint and byte-determinism checks pass on unchanged game inputs. `graph.json` has `beacon_ok true` and `spawn.run true`. This is real headless physics, with no GPU, listening or human-feel verdict. Missing enemy-kind fields and the floor replay gap remain explicit follow-ups. The distinct-line proof is not supplied by this export and is reported, not gated.

## Round 4, historical candidate TRAV-DET, 2026-10-12

**Round-4 greybox verdict: FAIL.** Completed final-geometry summaries cover 40/56 seed rows. Missing summaries and incomplete live runs remain pending, not passes. Candidate baseline Rivet-5, Sable-4, Tally-5 and floor-1 all reproduced solo with identical inputs under R24. Current-head replay equality is PASS. Each measured table cell comes from the final population, with per-seed bounds judged from the worst seed. No band, pilot line, kit or shared tool changed in this round.

**Historical measured round 4, 2026-10-12; superseded by ruling 28.** Geometry head `7838cffbf84d61dca1c0b448082e93467f3d4ae7`; candidate `b1cc003`; tool SHA256 `902da5cd3879fcc555f6ccc83a83548479d7f318d6e7783738baad4e5d2fbfe6`. Evidence `/home/andrew/scratch/w13/sol/kd2-flume-r4/final-population`, input manifests and commands.ndjson in the same round folder. R24 replaces the old export with the candidate tool. The table gives median/worst, or ranges where the band is bounded. The floor gates only its reach, time cap and zero terrain stops. Historical writer and gate measurements remain in the traversal page.

| Band | sable | rivet | kest | tarn | tally | cannon | floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Reached Warden, 8/8 | 8 / 8 seeds pass | 8 / 8 seeds pass | pending | 8 / 8 seeds pass | 8 / 8 seeds pass | pending | 8 / 8 seeds pass |
| Time s, median 60–120; worst ≤150 | 63.73 / 64.8 pass | 96.055 / 98.71 pass | pending | 79.59 / 80.69 pass | 91.395 / 93.43 pass | pending | 96.77 / 98.42, reported, pilot band, not the floor's |
| Segments s, medians 12–45 | [21.66, 21.56, 20.51] / 22.08 pass | [26.99, 35.9, 33.315] / 36.62 pass | pending | [23.08, 26.01, 30.49] / 30.49 pass | [26.985, 30.355, 34.495] / 35.36 pass | pending | [27.975, 30.585, 38.2] / 38.97, reported, pilot band, not the floor's |
| Flow, median ≥.70; worst ≥.60 | 0.9262 / 0.9212 pass | 0.76255 / 0.7445 pass | pending | 0.9584 / 0.9146 pass | 0.72405 / 0.6119 pass | pending | 0.5791 / 0.5594, reported, pilot band, not the floor's |
| Airborne, median .12–.45 | 0.238 / [0.238, 0.2602] pass | 0.1221 / [0.1098, 0.1315] pass | pending | 0.1638 / [0.1638, 0.1725] pass | 0.1256 / [0.124, 0.1301] pass | pending | 0.11945 / [0.1129, 0.1234], reported, pilot band, not the floor's |
| Terrain or unclassified stops, every seed 0 | 0 / 0 pass | 0 / 0 pass | pending | 0 / 0 pass | 0 / 0 pass | pending | 0 / 0 pass |
| Peak m/s / tier-3 s, worst peak ≥26.6; median time ≥3 | [54.02, 45.69] / [54.02, 45.69] pass | [36.345, 8.37] / [32.76, 7.77] pass | pending | [35.48, 9.37] / [33.28, 8.71] pass | [36.41, 8.36] / [34.4, 8.14] pass | pending | [36.285, 8.11] / [34.12, 7.94], reported, pilot band, not the floor's |
| Quiet s, worst ≤20 | 7.74 / 8.03 pass | 11.69 / 12.15 pass | pending | 8.86 / 8.88 pass | 15.12 / 16.53 pass | pending | 12.515 / 12.78, reported, pilot band, not the floor's |
| Anchor gap m, worst ≤40 | 30.2 / 49.8 MISS | 30.7 / 32.6 pass | pending | 28.1 / 33.4 pass | 32.8 / 35.4 pass | pending | 32.3 / 39.5, reported, pilot band, not the floor's |
| Ride facts, at least 3 | 5 / 5 pass | 5 / 5 pass | pending | 5 / 5 pass | 5 / 5 pass | pending | 5 / 5, reported, pilot band, not the floor's |
| Length ratio, median 1.3–2.0 | 1.51 / [1.51, 1.54] pass | 1.43 / [1.43, 1.44] pass | pending | 1.36 / [1.36, 1.36] pass | 1.335 / [1.33, 1.34] pass | pending | 1.35 / [1.35, 1.36], reported, pilot band, not the floor's |
| Floor, ≤2× Rivet median; 0 terrain stops | not applicable | not applicable | pending | not applicable | not applicable | pending | 96.77 / max 98.42; cap 192.11 pass |
| Distinct lines, reported | not supplied by fixed tool; not gated | not supplied by fixed tool; not gated | pending | not supplied by fixed tool; not gated | not supplied by fixed tool; not gated | pending | not supplied by fixed tool; not gated |
| Pack dead stops, classified separately | 0 | 0 | pending | 0 | 0 | pending | 0 |

Dead-stop sites by seed:

- None in the 40 completed summary rows; unmeasured rows remain pending.

### Stop classification

All 40 completed final summary rows have zero raw stops; unmeasured rows remain pending. The candidate baseline had zero raw stops in 56/56 rows. The old Kest-2, Tally-3 and Cannon-2 exemptions are retired; no anonymous enemy contact is exempted. Floor seed 1 has zero stops in candidate baseline and matching solo. The old gate receipt remains classified as terrain. The R26 third siphon-bank repair was not used. The final bench grade is a separate site.

The independent round-3 gate classified floor seed 1 as terrain at 50.303 s, [-189.34,20.43,142.24], from its matching ground-only trace. Receipt: /tmp/claude-1000/w13-cgate/kd2-flume-r3/floor-solo1-trace-replay.json.

### Win proof under R23

The wrapper extends tools/bot_run.gd and only sets stage_limit to 600.0 while driver ticks are zero. KF8-WIRE mounts the reactor Warden at its authored anchor. The coordinator R23 criterion requires all three seeds to engage without a traversal stall; a fight that lasts the remaining stage limit belongs to Warden tuning.

| Seed | Engage s | Break s | Engage to break s | Outcome |
| --- | --- | --- | --- | --- |
| 1 | 116.39 | None | None | stalled / beacon |
| 2 | 117.43 | None | None | stalled / beacon |
| 3 | 143.06 | None | None | stalled / beacon |

R23 engage proof PASS. Raw receipts `/home/andrew/scratch/w13/sol/kd2-flume-r4/win-seed-*/bots.ndjson`. No Warden tuning or placement workaround was applied.

### Tarn journey probe, reported under R27

R27 keeps the bench line as the measured Tarn traversal for this round. That ruling does not amend the approved journey. A separate eight-seed probe steers from the siphon through [20,225], the entry kicker at [40,255], and along the last reach. Waypoints are in the round folder, never tools/park_lines. A reach counts only with ground contact on Park_flume_head_reach/Collider, within the authored 8 m-wide deck footprint and at its 25 m deck height. The coordinator owns the journey decision and text. No geometry was changed for the claw-up.

| Seed | Last reach reached | Reach s | To Warden s | Stops |
| --- | --- | --- | --- | --- |
| 1 | False | None | 74.42 | [{"at": [112.7, 355.1], "time": 64.5}] |
| 2 | False | None | 76.04 | [{"at": [113.5, 353.8], "time": 65.63}] |
| 3 | False | None | 73.74 | [{"at": [110.6, 351.6], "time": 63.76}] |
| 4 | False | None | 76.04 | [{"at": [113.5, 353.8], "time": 65.63}] |
| 5 | False | None | 72.87 | [] |
| 6 | False | None | 72.87 | [] |
| 7 | False | None | 74.42 | [{"at": [112.7, 355.1], "time": 64.5}] |
| 8 | False | None | 72.87 | [] |

Receipts `/home/andrew/scratch/w13/sol/kd2-flume-r4/journey-probe/tarn-seed-*-trace.json`; per-seed results `/home/andrew/scratch/w13/sol/kd2-flume-r4/journey-rows.json`.

