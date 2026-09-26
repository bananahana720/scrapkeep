# JL-28 results: scripted and random arms across the three sketches

**Automated; not a feel verdict.** Headless Godot 4.7.2 with the scripted and random arms. Only Andrew's play settles feel.

**Card:** JL-28 revision 3 · **Attempt:** JL-28-A1 · **Lease:** JL-28-L1 · **Phase:** B, run once as [PREREGISTRATION.md](PREREGISTRATION.md) fixes it (approved commit `d5142a0`, board EV-0572).

Tags: **V** is measured, from a retained record in this session; **U** is computed or estimated. Every count, interval and p value below is V, from `artifacts/local/tasks/JL-28/live/2026-09-26T01-15-24-360Z/analysis/results.{md,json}` (local; trial directories kept, 489 MB). The pinned `analyze.mjs` run again on the retained records gave byte-identical `results.md` and `results.json`.

## Run and provenance

- **Command:** `node artifacts/jev-lab-2026-09-25/experiments/arms/run.mjs --live`, from `/home/andrew/Projects/scrapkeep-wt-JL-28` at `d5142a0b645c1b4f68d08c8363b96a218fc1746c`, clean tree. Runner exit 0, empty stderr (V). `STARTED.json` stamp `2026-09-26T01:15:24.360Z`; it stays in place.
- **Pre-registration hash:** `provenance-before.json` and `provenance-after.json` both record `4c191ba60683ee3cefa437169fbcf931bee3b6552b73028c0713897f3cc58800`, equal to the approved value (V).
- **Heads, before and after:** harness `d5142a0`, status clean; Cable Bench lab `7d5adda`, clean, `proto/cable-bench` `29dcbcf`; Spillway lab `45446ff`, clean, `proto/spillway-drop` `af89c89` (V). Every precondition in `provenance-after.json` passed, so no cell is blocked by the after-run rule.
- **Canary:** ball-lab `dummy-knock` scripted kinematic, seed 1, launch exit 0; gate against `artifacts/jev-lab-2026-09-26/pins/ball-lab-scripted-dummy-knock-kinematic` exit 0, 20 of 20 trials reproduce (V).
- **Batches:** 36 of 36 exited 0 with a record; 1080 trials; every record `dirty: false`, sources matched, at the stated heads; zero Jev calls (V, V2 to V4 pass for every cell).
- **Load:** 36 batches, four at a time, load before/after 0.82/15.53 (one-minute load average, 32 CPUs; five-minute 1.32/15.53) (V). Wall time 18.7 min from start to the after-run check (01:15:24Z to 01:34:09Z), against an estimate of 24.6 min (U).

## Confirmatory cells

Exact one-sided McNemar in the pre-registered direction, Holm over the five cells, α = 0.05. Intervals are 95% Newcombe method 10 on paired data, R − S.

| Cell | Direction | n pairs | Scripted | Random | Both / R only / S only / neither | R − S paired | One-sided p | Holm p | Verdict | Reversal |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| bl-pillar-weave-kinematic | random > scripted | 40 | 4 | 22 | 3 / 19 / 1 / 17 | 0.45 [0.25, 0.60] | 2.0e-5 | 8.0e-5 | **SUPPORTED** | no |
| bl-run-to-pad-rigid | random > scripted | 40 | 12 | 38 | 12 / 26 / 0 / 2 | 0.65 [0.46, 0.77] | 1.5e-8 | 7.5e-8 | **SUPPORTED** | no |
| cb-bench-one-kinematic | scripted > random | 80 | 48 | 23 | 14 / 9 / 34 / 23 | −0.31 [−0.45, −0.16] | 8.5e-5 | 2.6e-4 | **SUPPORTED** | no |
| cb-bench-one-rigid | scripted > random | 40 | 4 | 1 | 0 / 1 / 4 / 35 | −0.08 [−0.21, 0.05] | 0.188 | 0.188 | NOT SUPPORTED | no |
| sd-mid-climb-kinematic | scripted > random | 80 | 33 | 23 | 12 / 11 / 21 / 36 | −0.13 [−0.26, 0.01] | 0.055 | 0.110 | NOT SUPPORTED | no |

Every trial paired by seed; 0 pairs dropped; 0 cells blocked or invalid; run not blocked (V).

## Readings that fired

| Reading | Fired? | Numbers |
| --- | --- | --- |
| Replication | **Yes** | `bl-pillar-weave-kinematic` and `bl-run-to-pad-rigid` both SUPPORTED (Holm 8.0e-5 and 7.5e-8). JL-21's "random above scripted" holds on fresh seeds on these two ball-lab cells at this epoch. |
| Stage direction | **Yes**, one cell | `cb-bench-one-kinematic` SUPPORTED: scripted 48/80 against random 23/80. The arms' order is stage-specific. |
| Unresolved | **Yes**, two cells | `cb-bench-one-rigid` (4/40 against 1/40, interval spans 0) and `sd-mid-climb-kinematic` (33/80 against 23/80, Holm 0.110). Planning power was 0.71 to 0.92 and 0.74 to 0.91 (U), and the winner's curse made those optimistic. Neither result is evidence that the arms are equal. |
| Reversal | No | No confirmatory cell moved against its direction. |
| All-forced | No | Smallest multi-option share 0.65 (`bl-pillar-weave-kinematic` scripted). |

Decisions this drives, per the pre-registration: `bl-pillar-weave-kinematic`, `bl-run-to-pad-rigid` and `cb-bench-one-kinematic` are the candidates for the success-rate comparison JL-25 deferred to JL-28 (a separate card); `cb-bench-one-rigid` and `sd-mid-climb-kinematic` get no rate comparison. No floor or ceiling cell left its class: `cb-forge-charge-rigid` (random 1/20), `cb-stage-run-rigid` (scripted 1/20) and `sd-mid-climb-rigid` (1/20 each) stay inside the floor rule.

## Other cells, as they fell (not tested)

| Cell | Class | Scripted | Random | R − S paired | Two-sided p (exploratory) | Multi share S / R |
| --- | --- | --- | --- | --- | --- | --- |
| sd-flood-hatch-kinematic | exploratory | 10/20 | 1/20 | −0.45 [−0.65, −0.18] | 0.004 | 0.93 / 0.94 |
| bl-pillar-weave-rigid | exploratory | 2/20 | 6/20 | 0.20 [−0.08, 0.45] | 0.289 | 0.91 / 0.88 |
| bl-dummy-knock-rigid | exploratory | 0/20 | 2/20 | 0.10 [−0.08, 0.30] | 0.500 | 0.96 / 0.84 |
| bl-run-to-pad-kinematic | ceiling | 20/20 | 20/20 | 0.00 [−0.16, 0.16] | 1.000 | 0.67 / 0.72 |
| bl-dummy-knock-kinematic | ceiling | 20/20 | 20/20 | 0.00 [−0.16, 0.16] | 1.000 | 1.00 / 1.00 |
| bl-bench-climb-kinematic | floor | 0/20 | 0/20 | 0.00 [−0.16, 0.16] | 1.000 | 0.73 / 0.83 |
| bl-bench-climb-rigid | floor | 0/20 | 0/20 | 0.00 [−0.16, 0.16] | 1.000 | 0.90 / 0.90 |
| cb-forge-charge-kinematic | floor | 0/20 | 0/20 | 0.00 [−0.16, 0.16] | 1.000 | 0.97 / 0.95 |
| cb-forge-charge-rigid | floor | 0/20 | 1/20 | 0.05 [−0.12, 0.24] | 1.000 | 0.99 / 0.90 |
| cb-stage-run-kinematic | floor | 0/20 | 0/20 | 0.00 [−0.16, 0.16] | 1.000 | 0.83 / 0.82 |
| cb-stage-run-rigid | floor | 1/20 | 0/20 | −0.05 [−0.24, 0.12] | 1.000 | 0.73 / 0.76 |
| sd-mid-climb-rigid | floor | 1/20 | 1/20 | 0.00 [−0.19, 0.19] | 1.000 | 1.00 / 1.00 |
| sd-flood-hatch-rigid | floor | 0/20 | 0/20 | 0.00 [−0.16, 0.16] | 1.000 | 0.92 / 0.93 |

`sd-flood-hatch-kinematic` was exploratory because its prior difference (0.15) was under the 0.20 line. Its exploratory two-sided p of 0.004 is not a test and supports no claim here. A new pre-registration would be needed to test it.

## Exploratory measures (not pre-registered as tests)

Per cell and arm: stuck episodes per trial, deaths, the least-used speed tier's share of 10 Hz trace samples, and knocks. The full table is in the local `results.md`. Headlines (V):

- **Stuck** (`stuck_begin` per trial, now reportable because trial directories are kept):
  - The random arm sticks more on Cable Bench bench-one: 6.99 against 2.86 kinematic, 6.83 against 2.52 rigid.
  - It also sticks more on ball-lab rigid choice scenarios: pillar-weave 7.00 against 2.05, dummy-knock 5.85 against 0.00, bench-climb 4.10 against 1.25.
  - On Spillway kinematic the scripted arm sticks more: mid-climb 5.06 against 3.55, flood-hatch 5.20 against 3.50.
  - The ceiling cells stay low: run-to-pad and dummy-knock kinematic 0.15 to 1.75.
- **Dead tier:**
  - Blazing is the least-used tier in 34 of 36 cell-arms.
  - ball-lab barely reaches it: share 0 in 10 of 16 cell-arms, 0.008 at most.
  - Cable Bench kinematic spends 6 to 10% of samples at blazing on bench-one and stage-run, under 1% on forge-charge.
  - Spillway spends 0 to 3% there.
  - The exceptions are `cb-forge-charge-rigid` random and `cb-stage-run-rigid` scripted, where fast is least used (0.046 and 0.103). Both of those cell-arms hold the tunnelled trials below, which fall at blazing speed.
- **Deaths:**
  - Cable Bench bench-one kinematic: scripted 15/80, random 35/80. Rigid: 35/40 and 37/40.
  - Spillway mid-climb kinematic: 20/80 and 34/80.
  - Spillway flood-hatch kinematic: 10/20 and 19/20.
  - Every other stage cell: 17 to 20 of 20.
  - ball-lab has no death.
- **Anomalies:** exactly two trials had any, both rigid Cable Bench. Their counts: `cb-stage-run-rigid` scripted seed 2019, 1 tunnel and 10 overspeed; `cb-forge-charge-rigid` random seed 2015, 1 tunnel and 1 overspeed. Both are the only successes in those cells; see below.
- **Stomps in rigid:** ball-lab rigid stomp knocks 0.30 to 1.40 per trial, against 3.00 to 11.10 in kinematic.
- **Time to success:** ball-lab run-to-pad kinematic p50/p90 21.9/25.0 s scripted, 25.8/42.9 s random. Dummy-knock kinematic 5.4/6.4 s and 7.8/11.4 s.

## Phase B observations, not pre-registered

1. **The only full-stage clear and the only forge clear on Cable Bench are tunnelling artifacts.**
   - `cb-stage-run-rigid` scripted, seed 2019:
     - The ball, climbing at walk speed, recorded a `tunnel` anomaly at tick 2627 near (−34.4, 14.8, 47.5).
     - By tick 3006 it was at y −183 m, falling at 79.7 m/s.
     - By tick 5760 it was at y −2842 m.
     - The trial was recorded `success` at tick 39543 (439 s), tier 10.
   - `cb-forge-charge-rigid` random, seed 2015:
     - Tunnel at tick 3858 near (−33.8, 54.7, −138.3).
     - At y −145 m, falling at 79.8 m/s, by tick 4230.
     - `success` at tick 9555 (106 s).
   - Observed from `events.ndjson` in those trials' directories.
   - Inference: the success predicate credits a ball that has left the world (no `out_of_bounds` anomaly fired), possibly because the forge charge counts horizontal position only. Both tunnels sit at x ≈ −34, which may be one geometry seam.
   - Neither cell was tested, and both stay floor. But a "1 in 80 clears the stage" reading would be wrong.
2. **sd-flood-hatch-kinematic** separated in the exploratory cell: 10/20 against 1/20 (two-sided p 0.004, exploratory). The prior was 5 against 2.
3. **The run took 18.7 min and the one-minute load reached 15.5** with four batches running (V). No trial aborted and every batch completed. Kinematic trials are tick-driven, so load cannot change them. The canary's 20 of 20 trace match supports that on one cell.

## Limits

- Automated play through each lab's steering; a comparison of decision policies, not of players.
- Rigid trials are not exactly reproducible (about 1 in 20 to 1 in 120 repeat pairs differ, by sketch); no rigid trace is gated.
- Cable Bench records carry no epoch field; its epoch rests on its lab head.
- Trial directories and full batch records are local under `artifacts/local/tasks/JL-28/live/`; retaining them is the coordinator's admission step.
