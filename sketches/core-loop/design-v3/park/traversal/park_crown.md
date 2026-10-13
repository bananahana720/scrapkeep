# Traversal: stage 6, the crown (`park_crown`)

## Round 6, 13 October 2026: current qualification

FIX. Automated native evidence level 4. Geometry head `bcfc1dec0bfae92e0f7536e71e5ab9c847c36934` follows STEP 0 merge `8d46221e5fbe3ba62b42122f028b52de140b58d6` of candidate `afbd8e6d0755a88504cd25a549de9592acdbc96d`. All round-6 receipts live in `/home/andrew/scratch/w13/sol/kd6-crown-r6`. The third and final Tarn launch trial was withdrawn after its 46 m anchor gap breached the unchanged 40 m limit by 15%. Its airborne median was 0.24105, still a measured MISS. No fourth repair is authorized. `withdrawal.json` retains the trial and agreeing trace. The restored source, shared runtime and all eight bake/graph files match the post-STEP-0 baseline across 421 recorded inputs in `restored-input-equality.json`. The table reports those byte-identical restored-input measurements, not a new post-withdrawal run. Fresh distinctness and completionist engagement remain absent under the exhausted-repair stop, so qualification remains FIX. Previous rounds below are dated history.

The committed traversal tool has SHA-256 `37e98e4ac7e0a5d4141d97828f5834a083d3267e83a90efccc26248b69ec574a`. `commands.ndjson` records argv, head, input hashes, output paths and exits. The current table comes from `baseline-measurements.json`, independently recomputed from raw post-STEP-0 baseline batch rows. Scalar cells show the midpoint median, the actual worst seed and both seed extrema. Segment cells show the three medians and seed ranges. The maximum anchor gap, peak speed, quiet interval and terrain stops are judged from their seed extrema. The floor gates only its own reach/time/zero-stop row; its other measures are reporting only.

| Measure | Sable | Rivet | Kest | Tarn | Tally | Cannon | Floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| reached_warden | 8/8; PASS | 8/8; PASS | 8/8; PASS | 8/8; PASS | 8/8; PASS | 8/8; PASS | 8/8; reported, pilot band, not the floor's |
| time_to_warden_s | 61.67 (worst seed 2: 62.85); min 56.19 seed 4, max 62.85 seed 2; PASS | 70.475 (worst seed 3: 70.97); min 70.47 seed 4, max 70.97 seed 3; PASS | 67.58 (worst seed 2: 71.53); min 67.16 seed 1, max 71.53 seed 2; PASS | 80.86 (worst seed 2: 81.71); min 80.36 seed 6, max 81.71 seed 2; PASS | 76.04 (worst seed 6: 78.28); min 75.88 seed 2, max 78.28 seed 6; PASS | 73.87 (worst seed 1: 74.27); min 71.14 seed 6, max 74.27 seed 1; PASS | 57.59 (worst seed 5: 57.64); min 57.17 seed 3, max 57.64 seed 5; reported, pilot band, not the floor's |
| segment_s | 18.12/21.4/22.13; seed ranges 18.12 to 19.05/16.11 to 23.07/20.72 to 22.25; PASS | 16.63/39.5/14.31; seed ranges 16.35 to 16.64/39.36 to 39.67/14.3 to 14.8; PASS | 16.335/19.255/32.08; seed ranges 16.12 to 16.37/19.12 to 21.78/30.77 to 33.43; PASS | 15.03/36.76/29.015; seed ranges 14.98 to 15.08/36.62 to 37.51/28.31 to 29.94; PASS | 16.91/37.905/21.48; seed ranges 16.65 to 16.93/37.62 to 38.81/20.48 to 23.3; PASS | 15.84/36.19/21.82; seed ranges 15.84 to 16.25/33.48 to 36.21/21.4 to 22.04; PASS | 21.11/21.29/15.165; seed ranges 20.76 to 21.19/21.29 to 22.28/14.23 to 15.19; reported, pilot band, not the floor's |
| flow_share | 0.9503 (worst seed 1: 0.9401); min 0.9401 seed 1, max 0.9504 seed 7; PASS | 0.8756 (worst seed 1: 0.8658); min 0.8658 seed 1, max 0.8837 seed 6; PASS | 0.8028 (worst seed 2: 0.7064); min 0.7064 seed 2, max 0.8164 seed 5; PASS | 0.9025 (worst seed 3: 0.893); min 0.893 seed 3, max 0.9132 seed 2; PASS | 0.8344 (worst seed 3: 0.8225); min 0.8225 seed 3, max 0.8366 seed 1; PASS | 0.9081 (worst seed 3: 0.9081); min 0.9081 seed 3, max 0.946 seed 6; PASS | 0.9392 (worst seed 1: 0.9392); min 0.9392 seed 1, max 0.9462 seed 5; reported, pilot band, not the floor's |
| airborne_share | 0.304 (worst seed 4: 0.1817); min 0.1817 seed 4, max 0.3132 seed 2; PASS | 0.3399 (worst seed 3: 0.3274); min 0.3274 seed 3, max 0.3533 seed 1; PASS | 0.2552 (worst seed 2: 0.2398); min 0.2398 seed 2, max 0.2589 seed 4; PASS | 0.2224 (worst seed 6: 0.2123); min 0.2123 seed 6, max 0.2311 seed 2; MISS | 0.3737 (worst seed 6: 0.3658); min 0.3658 seed 6, max 0.3805 seed 2; PASS | 0.3761 (worst seed 3: 0.3761); min 0.3761 seed 3, max 0.3902 seed 2; PASS | 0.1691 (worst seed 6: 0.1687); min 0.1687 seed 6, max 0.189 seed 3; reported, pilot band, not the floor's |
| dead_stops | 0.0 (worst seed 1: 0); min 0 seed 1, max 0 seed 1; PASS | 0.0 (worst seed 1: 0); min 0 seed 1, max 0 seed 1; PASS | 0.0 (worst seed 1: 0); min 0 seed 1, max 0 seed 1; PASS | 0.0 (worst seed 1: 0); min 0 seed 1, max 0 seed 1; PASS | 0.0 (worst seed 1: 0); min 0 seed 1, max 0 seed 1; PASS | 0.0 (worst seed 1: 0); min 0 seed 1, max 0 seed 1; PASS | 0.0 (worst seed 1: 0); min 0 seed 1, max 0 seed 1; reported, pilot band, not the floor's |
| peak_speed_mps | 51.79 (worst seed 2: 51.43); min 51.43 seed 2, max 53.28 seed 4; PASS | 43.75 (worst seed 2: 43.57); min 43.57 seed 2, max 44.77 seed 1; PASS | 39.09 (worst seed 3: 38.97); min 38.97 seed 3, max 39.99 seed 1; PASS | 42.81 (worst seed 1: 42.25); min 42.25 seed 1, max 43.72 seed 2; PASS | 43.41 (worst seed 2: 42.66); min 42.66 seed 2, max 44.55 seed 1; PASS | 41.99 (worst seed 2: 38.0); min 38.0 seed 2, max 41.99 seed 3; PASS | 44.4 (worst seed 8: 43.5); min 43.5 seed 8, max 44.4 seed 1; reported, pilot band, not the floor's |
| tier3_s | 31.71 (worst seed 2: 31.16); min 31.16 seed 2, max 33.24 seed 4; PASS | 9.975 (worst seed 3: 9.32); min 9.32 seed 3, max 9.99 seed 4; PASS | 9.385 (worst seed 3: 7.94); min 7.94 seed 3, max 9.6 seed 4; PASS | 9.03 (worst seed 2: 8.9); min 8.9 seed 2, max 11.07 seed 6; PASS | 8.33 (worst seed 1: 7.91); min 7.91 seed 1, max 8.63 seed 2; PASS | 8.74 (worst seed 1: 8.3); min 8.3 seed 1, max 8.74 seed 3; PASS | 11.91 (worst seed 6: 11.9); min 11.9 seed 6, max 13.02 seed 5; reported, pilot band, not the floor's |
| quiet_max_s | 4.31 (worst seed 4: 6.4); min 4.31 seed 3, max 6.4 seed 4; PASS | 5.695 (worst seed 6: 6.49); min 5.57 seed 4, max 6.49 seed 6; PASS | 5.58 (worst seed 5: 7.4); min 5.43 seed 4, max 7.4 seed 5; PASS | 5.52 (worst seed 3: 5.63); min 5.34 seed 2, max 5.63 seed 3; PASS | 5.39 (worst seed 1: 6.07); min 5.01 seed 2, max 6.07 seed 1; PASS | 9.73 (worst seed 2: 10.93); min 8.59 seed 1, max 10.93 seed 2; PASS | 4.7 (worst seed 8: 5.78); min 4.7 seed 1, max 5.78 seed 8; reported, pilot band, not the floor's |
| max_anchor_gap_m | 37.2 (worst seed 1: 37.2); min 37.2 seed 1, max 37.2 seed 1; PASS | 38.55 (worst seed 4: 39.0); min 35.9 seed 1, max 39.0 seed 4; PASS | 25.5 (worst seed 2: 31.6); min 25.4 seed 4, max 31.6 seed 2; PASS | 21.3 (worst seed 2: 23.1); min 18.9 seed 1, max 23.1 seed 2; PASS | 38.0 (worst seed 2: 38.5); min 34.6 seed 3, max 38.5 seed 2; PASS | 35.7 (worst seed 1: 37.2); min 35.7 seed 3, max 37.2 seed 1; PASS | 102.2 (worst seed 1: 102.2); min 102.2 seed 1, max 102.2 seed 1; reported, pilot band, not the floor's |
| distinct_verbs | 5.0 (worst seed 4: 4); min 4 seed 4, max 5 seed 1; PASS | 5.0 (worst seed 1: 5); min 5 seed 1, max 5 seed 1; PASS | 4.0 (worst seed 1: 4); min 4 seed 1, max 4 seed 1; PASS | 4.0 (worst seed 1: 4); min 4 seed 1, max 4 seed 1; PASS | 5.0 (worst seed 1: 5); min 5 seed 1, max 5 seed 1; PASS | 5.0 (worst seed 1: 5); min 5 seed 1, max 5 seed 1; PASS | 4.0 (worst seed 1: 4); min 4 seed 1, max 4 seed 1; reported, pilot band, not the floor's |
| length_ratio | 1.49 (worst seed 4: 1.46); min 1.46 seed 4, max 1.5 seed 7; PASS | 1.25 (worst seed 1: 1.25); min 1.25 seed 1, max 1.26 seed 3; MISS | 1.28 (worst seed 1: 1.28); min 1.28 seed 1, max 1.3 seed 3; MISS | 1.57 (worst seed 2: 1.56); min 1.56 seed 2, max 1.57 seed 1; PASS | 1.34 (worst seed 2: 1.34); min 1.34 seed 2, max 1.35 seed 1; PASS | 1.38 (worst seed 1: 1.34); min 1.34 seed 1, max 1.38 seed 3; PASS | 1.15 (worst seed 1: 1.15); min 1.15 seed 1, max 1.16 seed 5; reported, pilot band, not the floor's |
| Distinct lines, at least 3 | pending eight-seed tick witness; FIX | | | | | | |
| Floor own row: all seeds reach, time within 2 x Rivet median, zero stops | | | | | | | max 57.64 s / limit 140.95 s; PASS |


### Ruling 29 open rows

| Pilot | Measured ratio | Unchanged band | Receipt | Owner and status |
| --- | --- | --- | --- | --- |
| rivet | 1.25 | 1.3 to 2.0 | `/home/andrew/scratch/w13/sol/kd6-crown-r6/baseline-rivet/rivet.json` | MISS; conditional carry awaits every other acceptance line |
| kest | 1.28 | 1.3 to 2.0 | `/home/andrew/scratch/w13/sol/kd6-crown-r6/baseline-kest/kest.json` | MISS; conditional carry awaits every other acceptance line |

The two Rivet ride attempts and two Kest launch/ride attempts are documented in the dated round-5 report. No new ratio repair is authorized in round 6. Measured misses retain MISS in the table; a carried row does not make the measured value green.

### Current stops and replay

The restored-input 56 seed rows record 0 dead stops. Terrain stops require zero on every seed. No enemy-pack exemption is inferred from a batch outcome.
The agreeing baseline Tarn seed-1 batch/solo/traced controls are in `baseline-tarn-check.json`. Required final 33-case equality and distinctness remain absent after the repair stop. Full raw-result batch/solo/traced comparisons, when present, are retained in `/home/andrew/scratch/w13/sol/kd6-crown-r6/analysis.json`; current equality status is FIX until all required controls agree.

The historical Sable seed 4 and Kest seed 2 mast contacts were terrain. Their preceding 90-tick windows contained the mast collider and terrain only. Current matching controls and the final batches decide whether those stops remain; the old classifications are not an enemy-pack exception.

### Current distinctness

Pending final eight-seed Sable/Cannon/Kest 3D witness; FIX. The round-5 gate witness is dated history and does not qualify changed geometry.

### Current completionist engagement proof

Wrapper `/home/andrew/scratch/w13/sol/kd6-crown-r6/win.gd` extends `res://tools/bot_run.gd` and changes only `driver.stage_limit` to 600.0 before tick zero. Each seed runs `--table=park --policy=completionist --from-stage=6 --stages=6 --seeds=<seed> --trace=1` through the eight-core CPU queue and a 1,500 s outer cap. Ruling 23 requires every seed to engage without a traversal-cause stall. Warden break time and engage-to-break duration are reported, never gated here.

| Seed | Engaged s | Broken s | Engage to break s | Outcome and receipt |
| --- | --- | --- | --- | --- |
| 1 | pending; FIX | pending | pending | missing current-head receipt |
| 2 | pending; FIX | pending | pending | missing current-head receipt |
| 3 | pending; FIX | pending | pending | missing current-head receipt |

## Historical round 5, retained

All sections below are superseded history and do not qualify the round-6 head.

### Historical round 5 qualification

FIX. Automated native evidence level 4. Qualification is incomplete until all seven final eight-seed batches, the matching solo/traced controls, distinctness and the fresh completionist engagement proof are complete. The table reports only final-geometry receipts retained in `/home/andrew/scratch/w13/sol/kd6-crown-r5`. An absent receipt remains pending; earlier rounds remain dated history.

STEP 0 merge `77161880e12c5e070d97160b6757a121cfaff09a` imports candidate `51eb3c2` or its fetched descendant. The final geometry is recorded at `55f655ae539814e571e85e9d23d6878474b458e3`. Ruling 28 requires the committed `res://tools/traversal_line.gd`, SHA-256 `37e98e4ac7e0a5d4141d97828f5834a083d3267e83a90efccc26248b69ec574a`. `commands.ndjson` retains argv, source/bake/graph input hashes, output paths, exits and the checked head. Pilot waypoints, kits, Warden pins and PARK.md bands stay fixed. The retired export is not used.

The table is generated from `final-measurements.json`, independently recomputed from raw `final-<pilot>/<pilot>.json` rows. Cells give medians and actual worst seed values. Segment cells give all three segment medians. The maximum anchor gap and terrain stops gate every seed. The floor's own row gates reach, its maximum time against twice the Rivet median and zero terrain stops; its other cells are reporting only.

| Measure | Sable | Rivet | Kest | Tarn | Tally | Cannon | Floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| reached_warden | 8/8; PASS | 8/8; PASS | 8/8; PASS | 8/8; PASS | pending; FIX | pending; FIX | 8/8; reported, pilot band, not the floor's |
| time_to_warden_s | 61.67 (seed 2: 62.85); PASS | 70.475 (seed 3: 70.97); PASS | 67.58 (seed 2: 71.53); PASS | 80.86 (seed 2: 81.71); PASS | pending; FIX | pending; FIX | 57.59 (seed 5: 57.64); reported, pilot band, not the floor's |
| segment_s | 18.12/21.4/22.13; PASS | 16.63/39.5/14.31; PASS | 16.335/19.255/32.08; PASS | 15.03/36.76/29.015; PASS | pending; FIX | pending; FIX | 21.11/21.29/15.165; reported, pilot band, not the floor's |
| flow_share | 0.9503 (seed 1: 0.9401); PASS | 0.8756 (seed 1: 0.8658); PASS | 0.8028 (seed 2: 0.7064); PASS | 0.9025 (seed 3: 0.893); PASS | pending; FIX | pending; FIX | 0.9392 (seed 1: 0.9392); reported, pilot band, not the floor's |
| airborne_share | 0.304 (seed 4: 0.1817); PASS | 0.3399 (seed 3: 0.3274); PASS | 0.2552 (seed 2: 0.2398); PASS | 0.2224 (seed 6: 0.2123); MISS | pending; FIX | pending; FIX | 0.1691 (seed 6: 0.1687); reported, pilot band, not the floor's |
| dead_stops | 0.0 (seed 1: 0); PASS | 0.0 (seed 1: 0); PASS | 0.0 (seed 1: 0); PASS | 0.0 (seed 1: 0); PASS | pending; FIX | pending; FIX | 0.0 (seed 1: 0); reported, pilot band, not the floor's |
| peak_speed_mps | 51.79 (seed 2: 51.43); PASS | 43.75 (seed 2: 43.57); PASS | 39.09 (seed 3: 38.97); PASS | 42.81 (seed 1: 42.25); PASS | pending; FIX | pending; FIX | 44.4 (seed 8: 43.5); reported, pilot band, not the floor's |
| tier3_s | 31.71 (seed 2: 31.16); PASS | 9.975 (seed 3: 9.32); PASS | 9.385 (seed 3: 7.94); PASS | 9.03 (seed 2: 8.9); PASS | pending; FIX | pending; FIX | 11.91 (seed 6: 11.9); reported, pilot band, not the floor's |
| quiet_max_s | 4.31 (seed 4: 6.4); PASS | 5.695 (seed 6: 6.49); PASS | 5.58 (seed 5: 7.4); PASS | 5.52 (seed 3: 5.63); PASS | pending; FIX | pending; FIX | 4.7 (seed 8: 5.78); reported, pilot band, not the floor's |
| max_anchor_gap_m | 37.2 (seed 1: 37.2); PASS | 38.55 (seed 4: 39.0); PASS | 25.5 (seed 2: 31.6); PASS | 21.3 (seed 2: 23.1); PASS | pending; FIX | pending; FIX | 102.2 (seed 1: 102.2); reported, pilot band, not the floor's |
| distinct_verbs | 5.0 (seed 4: 4); PASS | 5.0 (seed 1: 5); PASS | 4.0 (seed 1: 4); PASS | 4.0 (seed 1: 4); PASS | pending; FIX | pending; FIX | 4.0 (seed 1: 4); reported, pilot band, not the floor's |
| length_ratio | 1.49 (seed 4: 1.46); PASS | 1.25 (seed 1: 1.25); MISS | 1.28 (seed 1: 1.28); MISS | 1.57 (seed 2: 1.56); PASS | pending; FIX | pending; FIX | 1.15 (seed 1: 1.15); reported, pilot band, not the floor's |
| Distinct lines, at least 3 | pending eight-seed tick witness; FIX | | | | | | |
| Floor own row: all seeds reach, time within 2 x Rivet median, zero stops | | | | | | | max 57.64 s / limit 140.95 s; PASS |


## Current stop classification

- Original sable seed 4: terrain, tick 4319, [-253.56, 7.01, 287.09], `Park_signal_masts/Collider`; no enemy contact in the preceding 90 ticks. Matching original solo-traced receipt: `/home/andrew/scratch/w13/cgate/kd6-crown-r4/trace-sable-4/sable-seed-4-trace.json`. The new approach regression checks physical collider clearance and excludes the ridge footprint at both recorded approaches; original geometry fails it.
  Current solo-traced outcome: engaged, 0 stops, 56.19 s to engage. Receipt: `/home/andrew/scratch/w13/sol/kd6-crown-r5/current-sable-4-trace/sable.json`; full-result batch/ordinary/traced comparisons are in `final-repeatability.json`.
- Original kest seed 2: terrain, tick 5084, [-247.13, 6.12, 287.53], `Park_signal_masts/Collider`; no enemy contact in the preceding 90 ticks. Matching original solo-traced receipt: `/home/andrew/scratch/w13/cgate/kd6-crown-r4/trace-kest-2/kest-seed-2-trace.json`. The new approach regression checks physical collider clearance and excludes the ridge footprint at both recorded approaches; original geometry fails it.
  Current solo-traced outcome: engaged, 0 stops, 71.53 s to engage. Receipt: `/home/andrew/scratch/w13/sol/kd6-crown-r5/current-kest-2-trace/kest.json`; full-result batch/ordinary/traced comparisons are in `final-repeatability.json`.
Every completed final batch records zero dead stops. A partial sweep does not qualify unmeasured seeds; no enemy-pack exception is claimed.

## Current distinctness

Pending final eight-seed 3D witness; FIX. The prior gate witness is historical evidence at d673404, not qualification of this merged geometry.

## Current completionist engagement proof

Wrapper: `/home/andrew/scratch/w13/sol/kd6-crown-r5/win.gd`, extending `res://tools/bot_run.gd`; the only override is `driver.stage_limit=600.0` before tick zero. Runs use `--table=park --policy=completionist --from-stage=6 --stages=6 --seeds=<seed>` through the required eight-core CPU queue with the 1,500 s wall cap. Ruling 23 gates engagement without a pre-engagement traversal stall. Break times are reported for the Warden units; they do not gate this stage.

| Seed | Engaged s | Broken s | Engage to break s | Outcome |
| --- | --- | --- | --- | --- |
| 1 | pending; FIX | pending | pending | missing current-head receipt |
| 2 | pending; FIX | pending | pending | missing current-head receipt |
| 3 | pending; FIX | pending | pending | missing current-head receipt |

## Historical round 4, retained

## Round 4, 13 October 2026

BLOCKED. Automated native evidence level 4. The two-hour timebox leaves pilot-band repair, the final post-repair sweep, the eight-seed distinctness witness and a fresh win proof incomplete. These numbers describe the completed initial 56-row sweep before the sentinel clearance repair, not qualification of the current geometry. The unqualified band-geometry trial was withdrawn. Pending cells and misses remain FIX.

STEP 0 merge `4d14964eaca8f1072045c57b07b741f33fffee7d` imports candidate `3debeb8` and TRAV-DET2. Ruling 28 supersedes every earlier measurement, including the round-3 committed-tool diagnostics and the verifier's retired-export results. They remain in their original evidence folders. This round uses only the committed `tools/traversal_line.gd`, SHA-256 `37e98e4ac7e0a5d4141d97828f5834a083d3267e83a90efccc26248b69ec574a`, verified before every invocation. No shared measuring tool, pilot waypoint, kit, Warden pin or band changed.

Evidence: `/home/andrew/scratch/w13/sol/kd6-crown-r4`. The table is generated from `baseline-measurements.json`, independently recomputed from the seven raw batch files. Each pilot cell gives median (actual worst seed where applicable). Segment cells give the three segment medians. `commands.ndjson` records argv, tool pin, input hashes, output paths and exits. Batch/solo/traced equality is PASS in `repeatability.json`.

| Measure | Sable | Rivet | Kest | Tarn | Tally | Cannon | Floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| reached_warden | 8/8; PASS | 8/8; PASS | 8/8; PASS | 8/8; PASS | 8/8; PASS | 8/8; PASS | 8/8; reported, pilot band, not the floor's |
| time_to_warden_s | 60.6 (seed 2: 61.99); PASS | 69.56 (seed 3: 70.01); PASS | 65.64 (seed 2: 68.47); PASS | 77.32 (seed 2: 78.58); PASS | 76.75 (seed 6: 78.28); PASS | 74.93 (seed 3: 74.93); PASS | 56.59 (seed 5: 56.8); reported, pilot band, not the floor's |
| segment_s | 18.12/21.4/21.07; PASS | 16.63/39.5/13.4; PASS | 16.335/19.255/30.14; PASS | 15.03/36.76/25.58; PASS | 16.91/37.905/21.77; PASS | 15.84/36.19/22.89; PASS | 21.11/21.29/14.13; reported, pilot band, not the floor's |
| flow_share | 0.9575 (seed 4: 0.9171); PASS | 0.8739 (seed 1: 0.864); PASS | 0.8148 (seed 2: 0.8069); PASS | 0.9373 (seed 3: 0.9331); PASS | 0.8344 (seed 2: 0.7828); PASS | 0.8848 (seed 3: 0.8848); PASS | 0.9382 (seed 6: 0.9381); reported, pilot band, not the floor's |
| airborne_share | 0.391 (seed 4: 0.1789); PASS | 0.328 (seed 3: 0.3103); PASS | 0.2459 (seed 2: 0.235); MISS | 0.2177 (seed 3: 0.2164); MISS | 0.3737 (seed 6: 0.3658); PASS | 0.3743 (seed 3: 0.3743); PASS | 0.1519 (seed 6: 0.147); reported, pilot band, not the floor's |
| dead_stops | 0.0 (seed 4: 1); MISS | 0.0 (seed 1: 0); PASS | 0.0 (seed 2: 1); MISS | 0.0 (seed 1: 0); PASS | 0.0 (seed 1: 0); PASS | 0.0 (seed 1: 0); PASS | 0.0 (seed 1: 0); reported, pilot band, not the floor's |
| peak_speed_mps | 51.79 (seed 2: 51.43); PASS | 43.75 (seed 2: 43.57); PASS | 39.09 (seed 3: 38.97); PASS | 42.81 (seed 1: 42.25); PASS | 43.41 (seed 2: 42.66); PASS | 41.99 (seed 2: 38.0); PASS | 44.4 (seed 8: 43.5); reported, pilot band, not the floor's |
| tier3_s | 36.34 (seed 4: 34.09); PASS | 12.03 (seed 3: 11.42); PASS | 8.8 (seed 3: 7.24); PASS | 8.99 (seed 4: 8.38); PASS | 8.33 (seed 1: 7.91); PASS | 8.74 (seed 1: 8.3); PASS | 13.73 (seed 7: 13.68); reported, pilot band, not the floor's |
| quiet_max_s | 4.31 (seed 4: 6.4); PASS | 5.695 (seed 6: 6.49); PASS | 5.17 (seed 2: 5.34); PASS | 5.52 (seed 3: 5.63); PASS | 5.39 (seed 1: 6.07); PASS | 9.73 (seed 2: 10.93); PASS | 4.7 (seed 8: 5.78); reported, pilot band, not the floor's |
| max_anchor_gap_m | 37.2 (seed 2: 56.0); MISS | 38.55 (seed 4: 39.0); PASS | 25.5 (seed 2: 31.6); PASS | 21.3 (seed 2: 23.1); PASS | 38.0 (seed 2: 38.5); PASS | 35.7 (seed 1: 37.2); PASS | 102.2 (seed 1: 102.2); reported, pilot band, not the floor's |
| distinct_verbs | 5.0 (seed 4: 4); PASS | 5.0 (seed 1: 5); PASS | 4.0 (seed 1: 4); PASS | 4.0 (seed 1: 4); PASS | 5.0 (seed 1: 5); PASS | 5.0 (seed 1: 5); PASS | 4.0 (seed 1: 4); reported, pilot band, not the floor's |
| length_ratio | 1.49 (seed 4: 1.44); PASS | 1.245 (seed 4: 1.24); MISS | 1.265 (seed 4: 1.26); MISS | 1.54 (seed 2: 1.53); PASS | 1.34 (seed 2: 1.34); PASS | 1.38 (seed 1: 1.34); PASS | 1.15 (seed 3: 1.14); reported, pilot band, not the floor's |
| Distinct lines, at least 3 | pending eight-seed tick witness; FIX | | | | | | |
| Floor own row: all seeds reach, time within 2 x Rivet median, zero stops | | | | | | | max 56.8 s / limit 139.12 s; PASS |

## Current stop records

- sable seed 4: {"at": [-253.6, 287.1], "time": 47.97}; classification and matching solo trace required; FIX.
- kest seed 2: {"at": [-247.1, 287.5], "time": 56.4}; classification and matching solo trace required; FIX.

## Historical win proof, superseded for this merged head

The round-3 wrapper at `/home/andrew/scratch/w13/sol/kd6-crown-r3/win.gd` extends `res://tools/bot_run.gd` and only sets `driver.stage_limit=600.0` before the first tick. Those completed receipts recorded every seed engaging and two breaking. They are history; a fresh merged-head proof is still required. Ruling 23 makes engagement the stage criterion and assigns duration to WT-PARK.

| Seed | Class | Engaged s | Broken s | Engage to break s | Outcome |
| --- | --- | --- | --- | --- | --- |
| 1 | runner_gunner | 115.86 | 466.24 | 350.38 | stalled; gates |
| 2 | demolitions_caster | 116.25 | 431.56 | 315.31 | stalled; gates |
| 3 | tarn | 160.8 | not broken in 600 s | not applicable | stalled; beacon |

## Geometry checks

The 59 metadata-only coverage rows are replaced by 106 greybox field patches, with 5,538 physical posts loaded by the real stage loader. Their footprints keep 24 m corridors around the fixed pilot lines and the gate approach, plus 44 m pocket and cradle clearances. The Crown-specific density check excludes non-producing rows and reads the existing 80 m limit from `park_density_test.gd`. Effective density is 62.264095 m worst over 40,650 open nodes; emptying one coverage row while retaining its metadata produces 200.0 m and fails after freshness is restored.

The physical perch check reads placed collider centres and tops against mind.md's approved positions and 12 m tops. The Warden anchor [0,18,515] and flight path are unchanged. A height-only mutation fails at a 15.000 m top after a fresh bake and graph. These mechanical passes do not establish traversal preservation or human feel.

The map-aware docking probe derives both cradles from the authored gate slots, passes the active ParkMap, requires both bounds/height checks with AND, and checks live docking. The retired no-map probe's red log is history in `legacy-dock.log`; no gate or shared bay bound was moved.
