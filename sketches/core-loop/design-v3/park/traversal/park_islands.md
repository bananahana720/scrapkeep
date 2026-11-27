# park_islands traversal

> **Historical wave-13/18 traversal receipt:** Preserved measurement log; live park traversal qualification runs via `sketches/core-loop/tests/park_*_test.gd` and `sketches/core-loop/tests/w50_*_test.gd`.

## Decoration-only pass, head vs base, 2026-10-19 (revised after review)

The pass draws six rows as decoration-only liners and sets three to `scatter` (see `stages/5-park_islands.md`); `slickrock_run`, `fan_band`, `net_carve` and `isle_apron` were reverted to their greybox recipes after review because a scatter row's sensor stands on the raw ground and scatter would have opened the `twin_fins`, `west_wing` and `lens_rocks` event footprints. Method: `tools/traversal_line.gd --table=park --stage=5 --seeds=1,2,3,4,5,6,7,8 --child-timeout=900`, headless, `--fixed-fps 90`, `nice`, for Rivet, Tally and Sable (Kest, Tarn, Cannon, the floor line and the skill line were not re-run for this revision). Head: the revision commit on `claude/eloquent-rubin-83eps3-islands`; base: `137db801`, the true parent (park_flume and park_pit liners, no islands change), in a detached worktree. One pilot at a time, head and base run side by side (two Godot children on a shared 4-vCPU box). Receipts (not committed): `artifacts/local/isles-trav-r2/` (`head/`, `base/` first batch; `re-head/`, `re-base/` the seeds 1, 2, 5, 7 rerun; `re6-head/`, `re6-base/` the seed 6 rerun; `sum.py` summarises them).

| Line | Head reached | Head dead stops (positions) | Head time_to_warden median (range) | Base reached | Base dead stops (positions) | Base time_to_warden median (range) |
| --- | --- | --- | --- | --- | --- | --- |
| rivet | 6 of 8 (seeds 6, 7 stall) | seeds 1, 2 at (157, -570), 13 to 17 s; seed 6 at (155, -562); seed 7 at (147, -513) repeatedly | 89.23 s (88.9 to 95.8) | 6 of 8 (seeds 1, 5 stall) | seed 1 at (155, -562); seed 5 at (147 to 157, -529) repeatedly; seed 7 at (156.5, -562) | 88.91 s (88.2 to 107.7) |
| tally | 8 of 8 | seed 3 at (0, -298); seed 4 at (159, -562); seed 6 at (98.5, -618) | 70.41 s (69.5 to 75.8) | 7 of 8 (seed 6 stalls) | seed 3 at (0, -298); seed 4 at (159, -562); seed 6 at (98.5, -618) and (156, -562); seed 8 at (157, -570) | 70.67 s (68.1 to 77.2) |
| sable | 7 of 8 (seed 1 stalls) | seed 1 around (-188 to -167, -561), 120 stops; seed 3 at (270, -125) | 59.71 s (57.5 to 67.4) | 7 of 8 (seed 1 stalls) | the same seed 1 and seed 3 stops; seed 8 at (-109, -690) | 59.96 s (59.1 to 67.4) |

Reading. Tally and Sable repeat the base's dead stops to the decimetre (the same seeds, positions and times), so the pass changed nothing they feel. Rivet is not repeatable run to run on either tree: the stop at (157, -570) hit head seeds 1 and 2 and base's Tally seed 8 in this batch, so I reran Rivet seeds 1, 2, 5 and 7 on both trees. Rerun: base reached all four with no stops (89.7, 88.7, 89.1, 89.1 s); head reached seeds 2, 5 and 7 clean (88.7, 89.1, 89.1 s) and seed 1 stalled once at (156.6, -562) at 14.6 s, the other known weak spot at the same place as base's first-batch seed 1 stop (155, -562) and Tally's (159, -562). So the stop at (157, -570) recurred on head in the first batch (2 seeds against 0 on base's Rivet) and did not recur in the rerun; the neighbouring (155 to 160, -562 to -570) pocket also stops base runs (Rivet seeds 1 and 7, Tally seeds 4, 6, 8). Head Rivet seed 6, which stalled at (155, -562) in the first batch, was not in that rerun set, so I reran it on both trees afterwards: head reached (90.4 s, 0 stops) and base reached (92.9 s) with one stop at (155.0, -562.7) at 16.3 s, so the same pocket stops both trees intermittently. The measure cannot separate a head-only effect from this run-to-run noise: the pass moves no collider and no ride sensor of consequence (plateau-row sensors up by at most 1 cm), but this is a bot trace, not a proof.

Round 3 (cross-lane clip, rims dropped, lane-edge cap) changed only draw geometry: no collider and no ride sensor moved, so the traversal was not re-run for it and the table above stands for the shipped state.

Limits: automated bot lines only, no feel and no human play; Kest, Tarn, Cannon, the floor line and Rivet's skill line were measured on the earlier unrevised candidate (all within about 2 s of base, 8 of 8) and not re-run here; two Godot children shared the box, so wall-clock-sensitive seeds vary.

## Round 5 measurement, 2026-10-13

Admission remains held. Candidate `3debeb8` merged without conflicts at
`1f4ad76`. The retained measurement programs are `05a0b56, faa5cd2`; the submitted head is `e496b0f`. Ruling 28
requires the committed `tools/traversal_line.gd`, SHA-256
`37e98e4ac7e0a5d4141d97828f5834a083d3267e83a90efccc26248b69ec574a`.
All measurements before the STEP 0 merge are superseded and retained below.
The design sections and shipped appendix remain current.

The valid tool logs have no script errors. The first merged-head runs exposed
KD5's missing `fin_rim_collapse.effect.fill_s`; those invalid rows are retained
and excluded. The stage row now declares its instantaneous landing explicitly
with `fill_s: 0.0`, after a committed red-first assertion. No shared tool,
pilot-line, Warden or combat value changed. The first Rivet batch was
INCONCLUSIVE after seed 5 hit the 120-second child wall cap. Its fresh
300-second-cap recovery retains all eight seeds; every complete row from
the capped batch matches its recovery. Only the wall bound changed.

Sable seed 2 and Rivet seed 4 agree in all fields between their untraced batch,
untraced solo and traced solo. No fields were removed or normalized.
The agreement receipt (`kd5-islands-r5/agreement.json`, historical scratch artifact outside the repo) retains the raw comparisons
and source fingerprints. The shared traversal/runtime disagreement is resolved
for these named seeds. The first complete batches remain the measurements.

The table comes from raw seed rows in the independent assessment (`kd5-islands-r5/bands-independent.json`, outside the repo).
There are 56 completed rows currently. Median and worst seed
or seed range appear together. Airborne and length are judged per seed, and
anchor gap uses the maximum seed. Segment and tier-3 gates retain their median
rules. The floor uses only reach, its time cap and zero stops, per ruling 13.
Current misses are `{"sable": ["time_median"], "tally": ["length"]}`.

| Band | Sable | Rivet | Kest | Tarn | Tally | Cannon | Floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Reached Warden | 8/8: PASS | 8/8: PASS | 8/8: PASS | 8/8: PASS | 8/8: PASS | 8/8: PASS | 8/8: PASS |
| Time to Warden, s | 59.055 / 60.58: FAIL | 89.39 / 90.86: PASS | 74.075 / 76.2: PASS | 81.19 / 81.19: PASS | 70.215 / 70.78: PASS | 82.015 / 83.4: PASS | 82.77 / 83.35: reported, pilot band, not the floor's |
| Segment medians / worst time, s | 15.22/22.04/21.82 / 23.16: PASS | 24.505/36.425/28.48 / 37.7: PASS | 22.68/22.61/28.73 / 28.81: PASS | 22.43/31.22/27.52 / 31.4: PASS | 24.43/18.07/27.085 / 27.96: PASS | 22.73/32.31/26.94 / 32.91: PASS | 24.8/33.03/24.92 / 34.16: reported, pilot band, not the floor's |
| Flow share | 0.9451 / 0.9287: PASS | 0.8754 / 0.8422: PASS | 0.9126 / 0.8705: PASS | 0.9685 / 0.9517: PASS | 0.9682 / 0.96: PASS | 0.9889 / 0.9824: PASS | 0.8954 / 0.8954: reported, pilot band, not the floor's |
| Airborne share | 0.4034 / 0.3776..0.4084: PASS | 0.33545 / 0.2598..0.3425: PASS | 0.3581 / 0.3385..0.3608: PASS | 0.2967 / 0.2875..0.2967: PASS | 0.3246 / 0.3209..0.3276: PASS | 0.35435 / 0.3485..0.3555: PASS | 0.2914 / 0.2899..0.293: reported, pilot band, not the floor's |
| Raw dead stops | 0 total / 0 worst: PASS | 0 total / 0 worst: PASS | 0 total / 0 worst: PASS | 0 total / 0 worst: PASS | 0 total / 0 worst: PASS | 0 total / 0 worst: PASS | 0 total / 0 worst: PASS |
| Peak speed / tier-3 time | 55.93 m/s, 46.1 s / 55.93 m/s, 39.67 s: PASS | 30.54 m/s, 8.405 s / 29.44 m/s, 7.52 s: PASS | 29.78 m/s, 6.71 s / 28.93 m/s, 6.2 s: PASS | 30.79 m/s, 10.29 s / 30.79 m/s, 10.29 s: PASS | 27.295 m/s, 6.5 s / 26.7 m/s, 4.31 s: PASS | 28.53 m/s, 10.91 s / 27.97 m/s, 5.88 s: PASS | 32.87 m/s, 12.41 s / 31.76 m/s, 9.28 s: reported, pilot band, not the floor's |
| Longest quiet, s | 4.38 / 4.38: PASS | 5.99 / 6.57: PASS | 3.285 / 3.56: PASS | 6.1 / 6.1: PASS | 3.525 / 3.72: PASS | 3.78 / 3.78: PASS | 7.62 / 7.62: reported, pilot band, not the floor's |
| Anchor gap, m | 32.1 / 34.5: PASS | 27.6 / 32.0: PASS | 26.0 / 33.7: PASS | 19.5 / 22.9: PASS | 19.25 / 19.8: PASS | 20.9 / 20.9: PASS | 38.4 / 38.4: reported, pilot band, not the floor's |
| Distinct ride facts | 6.0 / 6: PASS | 6.0 / 6: PASS | 6.0 / 6: PASS | 6.0 / 6: PASS | 6.0 / 6: PASS | 6.0 / 6: PASS | 6.0 / 6: reported, pilot band, not the floor's |
| Length / straight distance | 1.65 / 1.65..1.66: PASS | 1.455 / 1.45..1.46: PASS | 1.36 / 1.36..1.38: PASS | 1.54 / 1.54..1.54: PASS | 1.26 / 1.26..1.26: FAIL | 1.5 / 1.5..1.5: PASS | 1.45 / 1.45..1.45: reported, pilot band, not the floor's |
| Floor row | n/a | reference | n/a | n/a | n/a | n/a | worst 83.35 s / cap 178.78 s; 0 stops: PASS |
| Distinct lines | Sable, Rivet and Tarn distinct on all 8 seeds in both directions (worst overlap 0.391 under 0.5, planar 8 m method); Sable, Tarn and Cannon also distinct; Rivet and Cannon not (0.501). Receipt: /home/andrew/scratch/w13/cgate/kd5-islands-r5/comparison-result.json | n/a | n/a | n/a | n/a | n/a | n/a |
| Stop classification | 0 terrain / 0 pack | 0 terrain / 0 pack | 0 terrain / 0 pack | 0 terrain / 0 pack | 0 terrain / 0 pack | 0 terrain / 0 pack | 0 terrain / 0 pack |


One bounded bank repair per failing pilot was tried at `d55b1a5`.
The full eight-seed remeasurement still failed Sable's median time, 59.07 s,
and Tally's length, 1.26 on every seed. Both trial lines had zero stops.
The banks were reverted at `e496b0f`; exact runtime-byte equivalence restores
the complete baseline and fresh win receipts. The failed trial (`kd5-islands-r5/repair-band-assessment.json`, historical scratch artifact)
is retained. No further geometry repair is authorized by this packet.

Raw stops with no matching causal enemy receipt count as terrain. No pack
exemption is claimed from the older, superseded traces. Any nonzero current
stop remains held until its matching solo trace and ruling-25 enemy probe
identify its cause. Zero-stop rows need no causal exemption.

### Effective Warden criterion

The round-5 coordinator packet resolves the brief conflict. R23 is an
engagement-only proof: every seed reaches and engages the mind Warden,
with no traversal-caused stall before engagement. The two-of-three break
requirement in the earlier brief and focus question is superseded.
The wrapper changes only the driver's stage limit to 600 seconds before
its first tick. Break time and engage-to-break time are still reported.
WT-PARK and WT-BANDS own Warden duration. KD5 does not change the Warden
row, combat values or bot behavior.

| Seed | Outcome | Engage s | Break s | Engage to break s |
| --- | --- | --- | --- | --- |
| 1 | stalled | 139.15 | null | null |
| 2 | stalled | 133.73 | null | null |
| 3 | stalled | 127.96 | null | null |

R23 verdict: PASS. Breaks observed: 0/3. The fresh win receipt (`kd5-islands-r5/win-review.json`, historical scratch artifact) retains the complete rows.

These are automated headless receipts. Human feel, dressing, listening and
physical hardware acceptance remain unqualified.

## Superseded round 4 measurement

## Round 4 candidate measurement, 2026-10-12, program head 7e6368d

Admission remains held. Candidate `9467de7` merged without conflicts at `5223b95`.
The terrain and pilot lines are unchanged. Two independent bake/graph builds
are byte-identical. These new runs use the committed candidate traversal tool
at fixed FPS 90, nice 10, through the two-core queue with at most two traversal
processes together. Every run has fresh XDG state.

R22 stops geometry work because complete seed rows still disagree on identical
inputs. The agreement receipt (`kd5-islands-r4/agreement.json`, historical scratch artifact)
retains the complete rows and every changed field. All six comparison runs have
the same runtime digest `fa895d4e75cf2271d9d8be26d79ddbc93c59710bdabf7e1ecf4c4b13cd754c13`;
individual source and asset hashes are in each run's runtime-input manifest.
The coordinator must reopen TRAV-DET. No shared tool, enemy, pilot line, Warden
row or terrain was edited, and no terrain try was spent.

| Pilot and seed | Mode | Engage s | Airborne | Flow | Path m | Raw stops |
| --- | --- | --- | --- | --- | --- | --- |
| sable 2 | batches | null, stalled | 0.1094 | 0.1639 | 2482.8 | 110 |
| sable 2 | solo-sable | 58.92 | 0.4002 | 0.9496 | 2084.8 | 0 |
| sable 2 | traced-solo-sable | 58.92 | 0.4 | 0.9496 | 2084.7 | 0 |
| rivet 4 | batches | 89.16 | 0.3312 | 0.8724 | 1817.7 | 0 |
| rivet 4 | solo-rivet | 89.16 | 0.3312 | 0.8724 | 1817.7 | 0 |
| rivet 4 | traced-solo-rivet | 89.77 | 0.3304 | 0.8815 | 1825.2 | 0 |

Sable reaches 7/8 in the untraced batch. Seed 2 has null engage time, flow 0.1639,
airborne 0.1094, quiet time 23.38 s and 110 raw stops. Its matching solo reaches
at 58.92 s with zero stops. The traced solo also reaches at 58.92 s, but airborne
and path length differ from untraced solo. Rivet's untraced batch and solo seed 4
agree completely; its traced solo changes time, airborne, flow, path and other
fields. A traced batch was not run after this disagreement, following R22.
The other four pilot batches and new distinct-line traces are held for the
shared traversal/runtime repair. Earlier receipts do not qualify this program.

The batch table below is the measured result, not a qualifying pass. Values
are computed independently from raw seed rows in the band assessment (`kd5-islands-r4/bands-independent.json`, outside the repo).
Every cell shows median and worst seed or seed range. Sable's time median uses
its seven reached seeds; its worst seed is stalled with null time. Its three
segment medians likewise use seven completed rows, while seed 2 has all three
segments null. Sable's 58.98 s median also misses the unchanged 60 s minimum.
The airborne and length checks use every raw seed, and the anchor check uses
the maximum seed. Tier-3 and segment gates retain their authored median rules.
Only reach, the time cap and zero stops gate the floor, per R13.

| Band | Sable | Rivet | Kest | Tarn | Tally | Cannon | Floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Reached Warden | 7/8: FAIL | 8/8: PASS | not measured | not measured | not measured | not measured | 8/8: PASS |
| Time to Warden, s | 58.98 / null stalled seed; max reached 59.91: FAIL | 89.27 / 89.79: PASS | not measured | not measured | not measured | not measured | 81.9 / 84.09: reported, pilot band, not the floor's |
| Segment medians / worst time, s | 15.21/22.31/21.45 / 22.85: PASS | 24.435/36.385/28.425 / 36.78: PASS | not measured | not measured | not measured | not measured | 23.78/34.11/24.0 / 34.91: reported, pilot band, not the floor's |
| Flow share | 0.93275 / 0.1639: FAIL | 0.88225 / 0.8724: PASS | not measured | not measured | not measured | not measured | 0.9004 / 0.8882: reported, pilot band, not the floor's |
| Airborne share | 0.3889 / 0.1094..0.3971: FAIL | 0.33325 / 0.3295..0.3386: PASS | not measured | not measured | not measured | not measured | 0.2897 / 0.2878..0.2925: reported, pilot band, not the floor's |
| Raw dead stops | 110 total / 110 worst: FAIL | 0 total / 0 worst: PASS | not measured | not measured | not measured | not measured | 0 total / 0 worst: PASS |
| Peak speed / tier-3 time | 54.81 m/s, 45.955 s / 44.61 m/s, 6.03 s: PASS | 30.65 m/s, 8.95 s / 29.34 m/s, 7.74 s: PASS | not measured | not measured | not measured | not measured | 31.82 m/s, 9.64 s / 30.86 m/s, 7.98 s: reported, pilot band, not the floor's |
| Longest quiet, s | 4.38 / 23.38: FAIL | 6.14 / 6.81: PASS | not measured | not measured | not measured | not measured | 4.83 / 5.4: reported, pilot band, not the floor's |
| Anchor gap, m | 33.95 / 34.9: PASS | 28.9 / 33.7: PASS | not measured | not measured | not measured | not measured | 41.4 / 41.4: reported, pilot band, not the floor's |
| Distinct ride facts | 6.0 / 4: PASS | 6.0 / 6: PASS | not measured | not measured | not measured | not measured | 6.0 / 6: reported, pilot band, not the floor's |
| Length / straight distance | 1.66 / 1.64..1.99: PASS | 1.46 / 1.45..1.46: PASS | not measured | not measured | not measured | not measured | 1.46 / 1.45..1.46: reported, pilot band, not the floor's |
| Floor row | n/a | reference | n/a | n/a | n/a | n/a | worst 84.09 s / cap 178.54 s; 0 stops: PASS |
| Distinct lines | not measured; R22 hold | n/a | n/a | n/a | n/a | n/a | n/a |
| Stop classification | unresolved | 0 terrain / 0 pack | not measured | not measured | not measured | not measured | 0 terrain / 0 pack |

The floor reaches 8/8, with worst time 84.09 s against twice Rivet's 89.27 s median, a cap of 178.54 s. It has 0 raw stops.

Stop classification remains unresolved for Sable's 110 untraced stops. The solo
traces contain zero stops and cannot classify that different batch. No qualification with zero terrain stops or pack-contact exemption is claimed. Coordinates and
times are retained in the stop evidence (`kd5-islands-r4/stop-evidence.json`);
matching causal collider/enemy identities are missing. Rivet and the floor,
when their measured raw total is zero, require no stop classification receipt.
The historical 83 unclassified stops and 13 ground-contact increments below
remain evidence for `db2f034`, not classifications of this program's 110 stops.

The stage-local geometry assertion now reads all 18 step-lip markers from this
stage's authored appendix, retaining their 1 cm plateau specification. The
external mutation receipt (`kd5-islands-r4/mutations.json`)
shows waymark, rebuilt 3 m step-lip and Warden-family plants all make the stage
test red. Each was restored byte for byte with `git checkout --`. The restored
stage test passes 18 checks. Eight named smoke files pass with zero failures,
zero missing verdicts and zero omitted checks. Compilation against `9467de7`
and lint pass. These checks establish automated headless behavior, not human
feel, dressing, listening or hardware acceptance.

### R23 Warden proof on the same program

The external wrapper extends `res://tools/bot_run.gd` and sets only
`_driver.stage_limit = 600.0` before the first driver tick. The proof uses the
park table, completionist, `--from-stage=5 --stages=5`, with fresh state per seed.
R23 requires all three seeds to reach and engage with no pre-engage traversal
stall. A Warden unbroken at the limit is reported for the Warden tuning owner.
The win receipt (`kd5-islands-r4/win-review.json`)
retains every complete outcome row and the exact engage and break times.

| Seed | Outcome | Engage s | Break s | Engage to break s |
| --- | --- | --- | --- | --- |
| 1 | stalled | 141.79 | null | null |
| 2 | stalled | 132.4 | null | null |
| 3 | stalled | 126.14 | null | null |

R23 verdict: PASS. Breaks observed: 0/3. Missing or capped rows do not establish engagement.

## Acceptance review, 2026-10-12, submitted head db2f034

Admission on `db2f034` is held. The table below records the independent gate's
untraced Sable batch and the original Rivet miss. The round-3 table remains an
**earlier writer pass**, with its Rivet failure, rather than current acceptance.

| Active acceptance evidence on db2f034 | Sable | Rivet |
| --- | --- | --- |
| Reach | **FAIL: 7/8**, seed 2 stalled | 8/8 |
| Seed 2 engage time | **FAIL: null**, stalled | n/a |
| Flow minimum | **FAIL: 0.3064** | earlier writer table |
| Airborne minimum | **FAIL: 0.165** | **FAIL: 0.2482**, seed 4 |
| Length maximum | **FAIL: 2.79** | earlier writer table |
| Dead stops | **FAIL: 83 raw stops**, unclassified | 0 in earlier writer batch |
| Stop qualification | classification unresolved; zero terrain unqualified | batch/solo/trace agreement held |

The independent untraced batch (`w13-cgate/kd5-islands-r3/sable-recovery/sable.json`, historical scratch artifact)
and mode comparison (`w13-cgate/kd5-islands-r3/sable-mode-comparison.json`)
show why the earlier Sable pass cannot qualify this head. The differing traced
batch has 13 ground-contact increments, with Ground/Tiles contacts and no enemy
contact in the preceding 90 ticks. Its stop receipt (`w13-cgate/kd5-islands-r3/sable-batch-trace-stops.json`)
cannot classify the 83 untraced stops or supply a matching solo trace.

Rivet's batch/solo/traced-solo airborne values remain 0.2482/0.3070/0.3107.
The favorable repeat at 0.2517 does not replace the original miss. The
round-3 writer report (`w13-sol/kd5-islands-r3/REPORT.md`)
retains that disagreement. Coordinator ruling R22 authorizes measurement with
the candidate's imported TRAV-DET repair. Qualification requires new complete
seed-row agreement and the unchanged worst-seed bands; the two pages will use
those same receipts when they are available.


## Earlier writer pass: greybox round 3, 2026-10-12, program head 56fce8f

Verdict: FAIL, evidence level 4. These receipts use the merged candidate
560d177 and the external TRAV-DET traversal tool, SHA-256
`f013f06048853958072dbe3dbcb70d17d040c33b393cfe5b1cc1d0dca02ca2c2`.
All seven lines ran untraced, eight seeds per batch, at fixed FPS 90 and nice 10
through the two-core CPU queue, at most two lines together. The summaries are in
`/tmp/claude-1000/w13-sol/kd5-islands-r3/final-untraced/`.

Every cell reports the median and worst seed or seed range. Admission uses the
worst column, including the anchor cap and the airborne and length ranges. Each
segment's worst time and every tier-3 minimum are shown beside their median;
the tier-3 gate remains the authored median gate. The floor uses its own row,
with every seed checked against twice Rivet's median time. Its other values are
reported as pilot bands, not floor gates.

| Band | Sable | Rivet | Kest | Tarn | Tally | Cannon | Floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Reached Warden | 8 / n/a: pass | 8 / n/a: pass | 8 / n/a: pass | 8 / n/a: pass | 8 / n/a: pass | 8 / n/a: pass | 8 / n/a: pass |
| Time to Warden, s | 60.92 / 61.88: pass | 95.84 / 96.87: pass | 78.6 / 85.1: pass | 85.75 / 85.81: pass | 75.065 / 76.86: pass | 86.575 / 86.62: pass | 88.93 / 90.34: reported, pilot band, not the floor's |
| Segment medians, s | 15.21/22.31/23.53 / 23.81: pass | 24.43/36.39/34.7 / 36.78: pass | 22.63/23.62/32.21 / 33.97: pass | 22.58/31.6/31.62 / 31.74: pass | 24.81/17.98/31.95 / 32.82: pass | 23.07/32.02/31.38 / 32.17: pass | 23.78/34.11/31.03 / 34.91: reported, pilot band, not the floor's |
| Flow share | 0.9363 / 0.9324: pass | 0.8594 / 0.8456: pass | 0.9036 / 0.7952: pass | 0.963 / 0.9562: pass | 0.9705 / 0.9383: pass | 0.9909 / 0.9804: pass | 0.8582 / 0.8582: reported, pilot band, not the floor's |
| Airborne share | 0.3878 / 0.3747..0.4019: pass | 0.3116 / 0.2482..0.3156: MISS | 0.3497 / 0.3192..0.3516: pass | 0.2808 / 0.2801..0.2843: pass | 0.3096 / 0.3043..0.3157: pass | 0.3304 / 0.3293..0.3385: pass | 0.2694 / 0.2689..0.2734: reported, pilot band, not the floor's |
| Dead stops | 0.0 / 0.0: pass | 0.0 / 0.0: pass | 0.0 / 0.0: pass | 0.0 / 0.0: pass | 0.0 / 0.0: pass | 0.0 / 0.0: pass | 0.0 / 0.0: pass |
| Peak speed / tier-3 time | 54.915 m/s, 47.91 s / 54.29 m/s, 47.39 s: pass | 30.53 m/s, 8.99 s / 29.34 m/s, 7.74 s: pass | 30.01 m/s, 8.22 s / 27.12 m/s, 3.57 s: pass | 30.55 m/s, 10.595 s / 30.55 m/s, 10.59 s: pass | 27.065 m/s, 5.89 s / 26.86 m/s, 5.33 s: pass | 28.86 m/s, 8.965 s / 27.86 m/s, 5.21 s: pass | 31.82 m/s, 9.64 s / 30.86 m/s, 7.98 s: reported, pilot band, not the floor's |
| Longest quiet, s | 4.38 / 4.38: pass | 7.505 / 7.71: pass | 6.37 / 6.51: pass | 5.91 / 6.53: pass | 6.115 / 6.53: pass | 6.23 / 6.36: pass | 8.01 / 8.01: reported, pilot band, not the floor's |
| Anchor gap, m | 33.95 / 34.9: pass | 25.3 / 33.7: pass | 21.7 / 27.4: pass | 19.05 / 22.0: pass | 17.6 / 20.4: pass | 22.8 / 30.5: pass | 41.4 / 41.4: reported, pilot band, not the floor's |
| Distinct ride facts | 6.0 / 6.0: pass | 6.0 / 6.0: pass | 6.0 / 6.0: pass | 6.0 / 6.0: pass | 6.0 / 6.0: pass | 6.0 / 6.0: pass | 6.0 / 6.0: reported, pilot band, not the floor's |
| Length / straight distance | 1.73 / 1.71..1.74: pass | 1.54 / 1.54..1.55: pass | 1.44 / 1.44..1.47: pass | 1.61 / 1.61..1.62: pass | 1.33 / 1.33..1.34: pass | 1.57 / 1.57..1.58: pass | 1.54 / 1.54..1.54: reported, pilot band, not the floor's |
| Floor row | n/a | reference | n/a | n/a | n/a | n/a | 88.93 s / cap 191.68 s, stops 0: pass |
| Distinct lines | sable, kest, tarn: pass | n/a | n/a | n/a | n/a | n/a | n/a |
| Stop classification | 0 terrain / 0 pack | 0 terrain / 0 pack | 0 terrain / 0 pack | 0 terrain / 0 pack | 0 terrain / 0 pack | 0 terrain / 0 pack | 0 terrain / 0 pack |

Each cell is median / worst seed. Anchor gap uses the maximum seed, per ruling 14. Peak and tier-3 time share the PARK.md row. The airborne and length cells show the seed range beside the median. The floor uses its own row only, with Rivet as the shipped tool reference.

Progress is measured on the fixed graph reader and reported separately: sable 20.94 m/s; rivet 13.38 m/s; kest 16.225 m/s; tarn 14.875 m/s; tally 16.99 m/s; cannon 14.735 m/s; floor 14.42 m/s.

sable: 8 seed rows, stops [].

rivet: 8 seed rows, stops [].

kest: 8 seed rows, stops [].

tarn: 8 seed rows, stops [].

tally: 8 seed rows, stops [].

cannon: 8 seed rows, stops [].

floor: 8 seed rows, stops [].


Three distinct lines were measured separately with the same fixed tool and
eight seeds per line. The directed spatial overlap results are in
`/tmp/claude-1000/w13-sol/kd5-islands-r3/distinct-traces-distinct-lines.json`. These traces establish the
reported spatial result for their runs; they do not repair the failed seed-row
agreement. Receipts are in `/tmp/claude-1000/w13-sol/kd5-islands-r3/distinct-traces/`.

## Measurement hold

Rivet seed 4's batch airborne share is 0.2482, below the 0.25 floor. Its solo
value is 0.3070 and its traced solo value is 0.3107 on the same unchanged program
and external tool. Time, peak speed, anchor gap and tier-3 time differ too.
The fixed tool therefore does not meet its promised batch/solo/trace equality
on this head. The admission table retains the batch miss, not a rounded or
substituted solo value. Ruling 21 prevents geometry rework from this unreproduced
miss. No terrain, pilot line, enemy or shared tool was changed.

A repeated untraced batch changes four of eight Rivet seed rows; seed 4's
airborne share becomes 0.2517. The favorable repeat does not replace the original
batch in the admission table. Both raw batches and the comparison are retained.

| Run mode | Airborne share | Time to engage s | Anchor gap m | Peak m/s | Tier-3 s | Dead stops |
| --- | --- | --- | --- | --- | --- | --- |
| batch | 0.2482 | 92.67 | 23.1 | 30.38 | 11.04 | 0 |
| solo | 0.307 | 96.59 | 33.7 | 30.92 | 8.87 | 0 |
| traced solo | 0.3107 | 95.45 | 27.4 | 30.75 | 8.29 | 0 |


## Mind Warden proof on the same program head

Completionist seeds 1 to 3 use `--table=park --from-stage=5 --stages=5` through
the external wrapper extending `res://tools/bot_run.gd`. The wrapper sets only
the driver's `stage_limit` to 600.0 after construction, before its first tick;
each seed log records `ticks=0`. Seeds run as separate invocations because the
committed multi-seed runner launches `res://tools/bot_run.gd` directly and would
bypass the wrapper. All three invocations share the requested eight-core queue
grant and 1800 s wall cap. The mounting remains mind, under_island, anchored.

| Seed | Outcome | Stage reached | Engage s | Break s | Engage to break s | Warden damage | After break |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | stages_done | 6 | 143.43 | 260.74 | 117.31 | {'ram': 1250.0} | entered stage 6; stages_done |
| 2 | stages_done | 6 | 138.85 | 236.58 | 97.73 | {'ram': 781.3, 'slam': 156.3, 'stomp': 312.5} | entered stage 6; stages_done |
| 3 | stages_done | 6 | 130.47 | 196.88 | 66.41 | {'ram': 625.0, 'slam': 625.0} | entered stage 6; stages_done |


The full outcome rows are quoted in `/tmp/claude-1000/w13-sol/kd5-islands-r3/REPORT.md` and retained exactly in
`/tmp/claude-1000/w13-sol/kd5-islands-r3/win-rows.ndjson`. R11 is retired; no anchored-Warden stall exception is
claimed. No terrain rework was needed for the old Kest stop/anchor miss or the
old Tally peak miss on the merged head with the fixed tool.

## Verification and limits

The eight named smoke files, compile check against 560d177, lint, rebuild identity
and freshness positive control together pass.
Two fresh shipped-tool rebuilds reproduce all eight retained outputs byte for
byte. The stage test exercises planted failures for its pins; the external
freshness plant and restoration are retained in the round report. The writer's
tools diff against the merge commit is empty. Exact commands, exit codes and
source fingerprints are in `/tmp/claude-1000/w13-sol/kd5-islands-r3/commands.ndjson`.

These receipts establish headless game behavior. Human feel, visuals, listening
and physical hardware remain unqualified. Dressing is a separate later unit.

## Earlier rounds, archived

The text below predates TRAV-DET and the current candidate. It is historical;
its carried-state seeds and R11 exception do not qualify this round.

~~~~~~text
# park_islands traversal

## Greybox continuation, 2026-10-12, program head d6923b0

Verdict: FAIL, evidence level 4. Seven lines, eight seeds each, measured on one
frozen park file and lines file through the shipped traversal tool at fixed FPS 90
and nice 10. The complete JSON summaries and traces are in
`/tmp/claude-1000/w13-sol/kd5-islands-r2/greybox-final2/`.

Sable's stop is cleared and every Sable band passes. Kest reaches on all eight
seeds but seed 1 stops once at [-70, -511.4] and its anchor gap is 42.2 m against
40 m. The Run's two reworks are exhausted. Tally seed 7 peaks at 26.52 m/s against
the 26.6 m/s minimum. The dressed pass is not started.

The table applies the coordinator's current rulings. Anchor gap uses the worst
seed, not the tool's median-only Boolean. The floor is judged only by its own row;
its other numbers are reported. Ride facts use KB7b's narrowed set. The graph
reader is fixed on this head, so progress is measured and reported.

| Band | Sable | Rivet | Kest | Tarn | Tally | Cannon | Floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Reached Warden | 8 / n/a: pass | 8 / n/a: pass | 8 / n/a: pass | 8 / n/a: pass | 8 / n/a: pass | 8 / n/a: pass | 8 / n/a: pass |
| Time to Warden, s | 61.51 / 62.17: pass | 95.145 / 95.48: pass | 78.97 / 83.85: pass | 85.09 / 85.93: pass | 74.76 / 75.33: pass | 86.705 / 87.94: pass | 89.555 / 92.71: reported, pilot band, not the floor's |
| Segment medians, s | 15.3/22.4/23.99 / 24.36: pass | 24.35/36.33/34.54 / 36.59: pass | 22.72/23.56/32.09 / 32.82: pass | 22.29/30.96/31.61 / 32.01: pass | 24.35/18.09/32.13 / 32.47: pass | 23.12/31.92/31.63 / 33.08: pass | 24.77/33.85/31.0 / 34.46: reported, pilot band, not the floor's |
| Flow share | 0.9387 / 0.9321: pass | 0.8626 / 0.8519: pass | 0.8792 / 0.8502: pass | 0.9624 / 0.9534: pass | 0.9703 / 0.9424: pass | 0.9868 / 0.9803: pass | 0.869 / 0.8275: reported, pilot band, not the floor's |
| Airborne share | 0.3925 / 0.3728..0.4171: pass | 0.3135 / 0.2535..0.3199: pass | 0.3309 / 0.3252..0.3402: pass | 0.2817 / 0.2749..0.2883: pass | 0.3078 / 0.297..0.3309: pass | 0.327 / 0.3209..0.3431: pass | 0.2682 / 0.2579..0.2768: reported, pilot band, not the floor's |
| Dead stops | 0.0 / 0.0: pass | 0.0 / 0.0: pass | 0.0 / 1.0: MISS | 0.0 / 0.0: pass | 0.0 / 0.0: pass | 0.0 / 0.0: pass | 0.0 / 0.0: pass |
| Peak speed / tier-3 time | 55.515 m/s, 48.23 s / 54.24 m/s, 42.11 s: pass | 30.29 m/s, 9.11 s / 29.89 m/s, 6.82 s: pass | 30.11 m/s, 9.24 s / 27.48 m/s, 3.66 s: pass | 31.335 m/s, 11.32 s / 30.41 m/s, 9.94 s: pass | 27.075 m/s, 5.775 s / 26.52 m/s, 4.32 s: MISS | 28.55 m/s, 7.735 s / 27.28 m/s, 4.72 s: pass | 32.115 m/s, 10.53 s / 31.39 m/s, 8.47 s: reported, pilot band, not the floor's |
| Longest quiet, s | 4.38 / 4.38: pass | 7.385 / 8.09: pass | 6.355 / 6.5: pass | 6.1 / 6.54: pass | 6.155 / 6.52: pass | 6.325 / 6.4: pass | 7.475 / 8.14: reported, pilot band, not the floor's |
| Anchor gap, m | 34.15 / 38.9: pass | 29.3 / 32.6: pass | 27.65 / 42.2: MISS | 19.95 / 22.5: pass | 18.25 / 24.4: pass | 26.25 / 36.7: pass | 33.6 / 39.8: reported, pilot band, not the floor's |
| Distinct ride facts | 6.0 / 6.0: pass | 6.0 / 6.0: pass | 6.0 / 6.0: pass | 6.0 / 6.0: pass | 6.0 / 6.0: pass | 6.0 / 6.0: pass | 6.0 / 6.0: reported, pilot band, not the floor's |
| Length / straight distance | 1.73 / 1.69..1.74: pass | 1.54 / 1.54..1.54: pass | 1.44 / 1.43..1.47: pass | 1.61 / 1.61..1.62: pass | 1.33 / 1.33..1.34: pass | 1.58 / 1.57..1.58: pass | 1.54 / 1.54..1.54: reported, pilot band, not the floor's |
| Floor row | n/a | reference | n/a | n/a | n/a | n/a | 89.555 s / cap 190.29 s, stops 0: pass |
| Distinct lines | sable, rivet, kest, tarn, cannon: pass | n/a | n/a | n/a | n/a | n/a | n/a |

Each cell is median / worst seed. Anchor gap uses the maximum seed, per ruling 14. Peak and tier-3 time share the PARK.md row. The airborne and length cells show the seed range beside the median. The floor uses its own row only, with Rivet as the shipped tool reference.

Progress is measured on the fixed graph reader and reported separately: sable 20.74 m/s; rivet 13.475 m/s; kest 16.205 m/s; tarn 14.99 m/s; tally 17.065 m/s; cannon 14.71 m/s; floor 14.315 m/s.

sable: 8 seed rows, stops [].

rivet: 8 seed rows, stops [].

kest: 8 seed rows, stops [[1, [{"at": [-70.0, -511.4], "time": 16.41}]]].

tarn: 8 seed rows, stops [].

tally: 8 seed rows, stops [].

cannon: 8 seed rows, stops [].

floor: 8 seed rows, stops [].

## Warden proof on the same program head

Completionist seeds 1-3, --table=park --from-stage=5 --stages=5, through the
eight-core CPU queue with the specified 1500 s cap. The command exited 0.
All three reached the engaged anchored mind Warden and stalled at the beacon;
none recorded a break. This is the R11 deviation, with exact outcome rows
quoted in REPORT.md. No latch-cause claim is added beyond the brief's ruling.

| Seed | Outcome | Stage reached | Warden engage (s) | Warden break | Stall state |
| --- | --- | --- | --- | --- | --- |
| 1 | stalled | 5 | 141.62 | None | beacon |
| 2 | stalled | 5 | 142.82 | None | beacon |
| 3 | stalled | 5 | 141.82 | None | beacon |

## Verification and limits

The eight named smoke files pass, with import making nine runs, zero skipped
tests and zero missing verdicts. Compile checking against 6710ac0 selects three
scripts and reports zero bad. Lint reports zero findings. Two fresh shipped-tool
rebuilds reproduce all eight committed outputs byte for byte. The freshness
plant turns the stage test red on park_sha256, then restoration turns it green.
Receipts with the local-run prefix cover this program head.

These are program and headless game measurements. They do not establish human
feel, visual acceptance, listening acceptance or physical hardware support.

## Earlier inherited pass, archived

The following is retained as historical text. It describes the earlier c002df7
plus WIP candidate, not d6923b0. Its median-only anchor interpretation is obsolete:
the old Kest worst gap 44.1 m fails ruling 14, and floor-only pilot measures are
reported under ruling 13. The old R12 progress defect is fixed on the current head.

~~~~text
# Traversal bands: park_islands (stage 5, the Highdraft)

KD5's traversal table under ruling R8. One section per pass, newest first. The bands are PARK.md section 8's; stage 5's airborne band is 0.25 to 0.60. Seeds 1 to 8 per line, one process at a time, on the KD5 head (c002df7 plus this unit's stage files). KB9 is on this head: park rows are placed at runtime and the ride sensors fire (ride_chute, ride_bowl, ride_grapple_line, ride_drop, ride_hop and kicker_launch show on every line), so the first run's blocker (ParkRecipes.place had no caller in src/) is gone.

The progress band is not measured: traversal_line.gd reads the stage graph wrongly on this head (R12, KB7b), and every run prints that known out-of-bounds line. The ride-fact count is shown twice: the tool's own count, and the count without lift_fired, crater_ride and wall_crumbled (KB7b's narrowed set). Both are 6 on every line.

## Greybox pass, 2026-10-12 (commit c002df7+wip)

Eight seeds per line (1 to 8): `godot --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/traversal_line.gd -- --table=park --stage=5 --pilot=<key>|--floor --seeds=1,2,3,4,5,6,7,8 --trace`. Each cell is median / worst seed, then pass or miss against PARK.md section 8, as the tool's band rows report them. The airborne band is stage 5's, 0.25 to 0.60.

| Band | Rule | Sable | Rivet | Kest | Tarn | Tally | Cannon | Floor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Reached the Warden | 8 of 8 seeds | 8 / - pass | 8 / - pass | 8 / - pass | 8 / - pass | 8 / - pass | 8 / - pass | 8 / - pass |
| Time to Warden (s) | median 60.0 to 120.0 s; no seed over 150.0 s | 65.71 / 68.3 pass | 94.27 / 94.77 pass | 76.19 / 81.19 pass | 85.16 / 86.32 pass | 73.48 / 75.57 pass | 84.92 / 85.72 pass | 88.66 / 91.28 pass |
| Segment medians (s) | each segment's median 12.0 to 45.0 s | 19.15/23.17/21.38 / 25.09 pass | 24.32/36.28/33.55 / 36.28 pass | 22.19/23.35/31.44 / 31.43 pass | 22.13/31.16/31.95 / 32 pass | 24.73/17.95/30.66 / 30.66 pass | 23.17/31.97/29.95 / 31.97 pass | 24.63/33.96/29.78 / 33.96 pass |
| Flow share | median at least 0.7; no seed under 0.6 | 0.93 / 0.89 pass | 0.87 / 0.86 pass | 0.89 / 0.87 pass | 0.96 / 0.95 pass | 0.97 / 0.95 pass | 0.99 / 0.99 pass | 0.87 / 0.84 pass |
| Airborne share | 0.25 to 0.6 | 0.4 / - pass | 0.31 / - pass | 0.34 / - pass | 0.29 / - pass | 0.32 / - pass | 0.33 / - pass | 0.26 / - pass |
| Dead stops | 0 on every seed | 1 / 2 miss | 0 / 0 pass | 0 / 1 miss | 0 / 0 pass | 0 / 0 pass | 0 / 0 pass | 0 / 0 pass |
| Peak speed (m/s) | at least 26.6 m/s (the blazing tier) on every seed | 54.74 / 53.02 pass | 30.52 / 29.74 pass | 29.4 / 28.41 pass | 31.39 / 29.99 pass | 30.05 / 29.18 pass | 29.91 / 28.91 pass | 32.6 / 31.1 pass |
| Tier-3 time (s) | median at least 3.0 s at the blazing tier | 49.27 / - pass | 9.02 / - pass | 6.46 / - pass | 12.81 / - pass | 7.17 / - pass | 10.74 / - pass | 11.09 / - pass |
| Longest quiet (s) | at most 20.0 s | 6.36 / 7.51 pass | 5.97 / 6.64 pass | 3.22 / 3.33 pass | 6.12 / 6.57 pass | 3.32 / 3.33 pass | 3.3 / 3.84 pass | 4.78 / 7.98 pass |
| Max anchor gap (m) | at most 40.0 m | 35.1 / 36.6 pass | 29.65 / 33.1 pass | 35.5 / 44.1 pass | 17.05 / 23.4 pass | 17.15 / 21 pass | 31.7 / 38.6 pass | 37.2 / 40.4 pass |
| Distinct ride facts | at least 3 different ride facts | 6 / 6 pass | 6 / 6 pass | 6 / 6 pass | 6 / 6 pass | 6 / 6 pass | 6 / 6 pass | 6 / 6 pass |
| Length ratio | 1.3 to 2.0 | 1.74 / - pass | 1.54 / - pass | 1.43 / - pass | 1.62 / - pass | 1.33 / - pass | 1.57 / - pass | 1.53 / - pass |
| floor | reaches the Warden in at most 2.0 times rivet's median time, 0 dead stops | n/a | n/a | n/a | n/a | n/a | n/a | 88.66 / 188.53 pass |
| Distinct lines (stage) | at least 3 across the six pilots | 5 (cannon, kest, rivet, sable, tarn) pass |
| Ride facts, KB7b set | at least 3 without lift_fired, crater_ride, wall_crumbled | 6 / 6 pass | 6 / 6 pass | 6 / 6 pass | 6 / 6 pass | 6 / 6 pass | 6 / 6 pass | 6 / 6 pass |
| Progress | PARK.md section 8 | not measured (KB7b, R12) | not measured (KB7b, R12) | not measured (KB7b, R12) | not measured (KB7b, R12) | not measured (KB7b, R12) | not measured (KB7b, R12) | not measured (KB7b, R12) |

- Sable: verbs seen boost, kicker_launch, lift_fired, ride_bowl, ride_chute, ride_drop, ride_grapple_line, ride_hop, special.
- Rivet: verbs seen dash, kicker_launch, lift_fired, ride_bowl, ride_chute, ride_drop, ride_grapple_line, ride_hop, special, sprint.
- Kest: verbs seen blink, dash, jump, kicker_launch, lift_fired, ride_bowl, ride_chute, ride_drop, ride_grapple_line, ride_hop, special.
- Tarn: verbs seen dash, kicker_launch, lift_fired, ride_bowl, ride_chute, ride_drop, ride_grapple_line, ride_hop, special.
- Tally: verbs seen dash, kicker_launch, lift_fired, ride_bowl, ride_chute, ride_drop, ride_grapple_line, ride_hop, special.
- Cannon: verbs seen dash, kicker_launch, lift_fired, ride_bowl, ride_chute, ride_drop, ride_grapple_line, ride_hop, special.
- Floor: verbs seen kicker_launch, lift_fired, ride_bowl, ride_chute, ride_drop, ride_grapple_line, ride_hop.

Misses: sable dead_stops; kest dead_stops.

Notes on this pass.

- Sable: one dead stop on 5 of 8 seeds at the Saddle. The ball reaches the last leg before the waymark at 40 to 45 m/s heading north-east, overshoots the waymark by about 40 m across the saddle step at z -350, and climbs back. A re-cut approach (a curve that meets the Saddle heading east) was tried on 8 seeds: four seeds still stopped once, seed 4 stuck at (-80, -433) and missed the Warden, so the shipped line keeps the pass-4 approach. Open.
- Kest: one dead stop on seeds 1 and 4, at (-62, -514) and (-111, -195). Open.
- The anchor gap band is judged on the median, which passes everywhere. Kest's worst seed is 44.1 m and the floor's 40.4 m.
- The machine load ran 30 to 166 during the pass. The bands come from fixed-fps simulation and are not timing-gated.
~~~~
~~~~~~
