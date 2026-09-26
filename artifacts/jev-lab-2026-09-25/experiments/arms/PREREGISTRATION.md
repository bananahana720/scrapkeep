# JL-28 pre-registration: scripted and random arms across the three sketches

**Card:** JL-28 revision 3 · **Attempt:** JL-28-A1 · **Lease:** JL-28-L1 · **Phase:** A (fixed before any counted batch)

**Status.** Draft. No counted batch, canary or gate has run. This file, `design.json`, `analyze.mjs` and `run.mjs` are fixed at the commit that adds them. `run.mjs --live` refuses to start unless the sha256 of each of those three files appears under [Pinned inputs](#pinned-inputs), the harness worktree is clean, and every precondition below holds. Phase B starts only after an independent review of this file, runs once, and changes nothing here. Changes before Phase B go to the append-only [change record](CHANGES.md), which is outside the pinned set.

Every result this plan produces is automated play. It is not a feel verdict; only Andrew's play settles feel.

## Question

On each sketch's own scenarios, at the current instrument epoch, does the scenario's success predicate differ between the scripted arm and the random arm, in the direction the prior batches showed, on seeds no batch has used?

## Decision each outcome drives

| Outcome | Decision |
| --- | --- |
| A confirmatory cell is SUPPORTED | The cell is named as a candidate for the success-rate comparison JL-25 deferred to JL-28 (`margin_vs_scripted`, JL-25 review F1 and F2). Adding that comparison to the gate is a separate card. |
| A confirmatory cell is NOT SUPPORTED | No rate comparison on that cell. The report gives the interval and says the test could not resolve the difference; it is not evidence that the arms are equal. |
| Both ball-lab confirmatory cells SUPPORTED | JL-21's "random above scripted" replicates on fresh seeds where it was seen, at the stated epoch. |
| A stage confirmatory cell SUPPORTED (scripted above random) | "Random above scripted" is ball-lab-specific; the gameplay findings list says which arm did better on which stage and does not generalise across sketches. |
| A floor or ceiling cell leaves its class | Reported as an exploratory change of class, with its counts. It is not tested, and it goes on the findings list only if a finding cites it. |
| Run BLOCKED | No verdict. Retained records are reported as they fell. Any rerun is a new decision by the coordinator, with its own seeds. |

## Instrument and epochs

No Jev arm and no Jev call. The arms are `scripted` (the ladder in `scripts/lab/arms.mjs`) and `random` (mulberry32 seeded by the trial seed, `scripts/lab/arms.mjs:18-43`). Scripted and random records carry `instrument: null`, so each epoch is identified by source identity, as follows.

| Sketch | Source under test | Epoch |
| --- | --- | --- |
| ball-lab | This worktree's `sketches/ball-lab`, tree `0a9f59ce65f753a8f7dce5206fa15b188f6b7767`. That tree equals the subject of the 2026-09-26 re-cut pins (`6864bf7`), which carries the code merged at `7ba2d0d` plus JL-21b-A3's fallback test and threat-rule comment. `scripts/lab` and `tools/jev-player` are unchanged between `6864bf7` and this base (`git diff --stat 6864bf7 HEAD` on those paths is empty). | stage-threat-rule 2 + executor on the reported threat |
| Cable Bench | `../scrapkeep-lab-cable-bench`, branch `lab/cable-bench`, head `7d5adda5ea23dffe51bcb08d8b8f4513607186d4`; `proto/cable-bench` at `29dcbcf15569b309c6912577bcbd1856378b9076` | stage-threat-rule 2 |
| Spillway Drop | `../scrapkeep-lab-spillway-drop`, branch `lab/spillway-drop`, head `45446ffcc615d70c9e5a265cc882be1e59d34a7c`; `proto/spillway-drop` at `af89c89e56f1133fb6bf28bc0b958cabc7b2e065` | stage-threat-rule 2 + end-on-death; every trial's `scenario_result.epoch` must carry it |

Godot 4.7.2 headless (`scripts/sketch-smoke.mjs` binary), D = 90, k = 26 (harness defaults), each sketch's own time limits (ball-lab `MODE_LIMITS_S` raises run-to-pad kinematic to 61 s). Stage batches pass `--sketch` to the lab worktree; every batch is launched from this worktree, never the coordinator worktree (SKL-23).

## Pairing

Arms share the jittered start and the stage's random streams per trial seed in all three sketches, so trial i of the scripted batch and trial i of the random batch form a pair. Checked from source in this session:

- Harness: trial i of a batch with seed s runs with trial seed `s × 1000 + i`, and the random arm is seeded with that trial seed (`scripts/lab/harness.mjs:51-52`, `:869-871`).
- ball-lab: `jev_run.gd:197-199` calls `seed(trial seed)` and `Scenarios.place(lab, scenario, trial seed)`; `scenarios.gd:170-180` draws the spawn from an RNG seeded only by the trial seed. `run-to-pad`, `bench-climb`, `dummy-knock` and `pillar-weave` are jittered (`scenarios.gd:74-98`).
- Cable Bench: `jev_run.gd:35-36` sets `stage.seed_override` to the trial seed; `jev_run.gd:170-172` seeds and places with it; `scenarios.gd:11-14`, `:87-93` jitter by trial seed.
- Spillway Drop: `jev_run.gd:39` sets `stage.seed_override` from the trial seed; `jev_run.gd:178-180` seeds and places; `scenarios.gd:17-18`, `:78-84` jitter by trial seed.

`analyze.mjs` also checks pairing in the records: a cell is paired only when both arms hold the same set of trial seeds. A cell that does not pair gets no McNemar test and reports the unpaired Newcombe interval only; a confirmatory cell in that state counts as BLOCKED.

## Seeds

Batch seed 2: trial seeds 2000 to 2039 on the five confirmatory cells (n = 40) and 2000 to 2019 on the rest (n = 20). The card's revision 3 names 2000 to 2019; the confirmatory cells extend batch seed 2 to 40 trials rather than adding batch seed 4, so each confirmatory cell's first 20 pairs are the card's seeds. A grep of all 3730 `run.json` records under `/home/andrew/Projects/scrapkeep*` in this session found batch seeds 1, 3, 5, 7, 11 and 12 and no record with batch seed 2 or a trial seed from 2000 to 2099 (receipt `artifacts/local/tasks/JL-28/phase-a/seed-scan.txt`).

The canary uses seed 1 on purpose: it replays the pinned batch. It is not counted.

## Cells

Eighteen cells: every scenario that offers the arms a choice, in both physics modes, on all three sketches. Ball-lab's `downhill-run` and `kicker-gap` are left out because every snapshot there is forced to one option, so the arms produce the same trace (SKL-30; `reviews/JL-17.md:13`); `soak` has no success predicate.

**Classification rule, applied to the prior batches before writing this file.** Prior means the batches at the same epoch as above, seed 1, n = 20 per arm: ball-lab JL-21b-A2 at `bec6560` (the code merged at `7ba2d0d`) and JL-21b-A3 at `6864bf7` for bench-climb and pillar-weave rigid; Cable Bench JL-26-A2 at lab `7d5adda`; Spillway JL-27-A3 at lab `45446ff`.

- **Floor:** both arms at 0 or 1 success in 20, with the other arm at most 1. **Ceiling:** both arms at 19 or 20. Reported, not tested.
- **Confirmatory:** neither floor nor ceiling, prior |R − S| ≥ 0.20, and prior multi-option share ≥ 0.5 in both arms. The direction is the sign of the prior difference. 0.20 is used because a paired interval at n = 40 has a half-width of about 0.2 at mid rates (below), so a smaller prior effect has little chance of resolving.
- **Exploratory:** everything else. Reported with its interval and a two-sided exact McNemar p labelled exploratory; not in the multiplicity family.

| Cell | Class | Direction | n | Prior (seed 1) | Why |
| --- | --- | --- | --- | --- | --- |
| bl-pillar-weave-kinematic | confirmatory | random > scripted | 40 | S 1/20, R 11/20; R − S 0.50 [0.22, 0.70] | Separates at n = 20 (JL-21b review). |
| bl-run-to-pad-rigid | confirmatory | random > scripted | 40 | S 9/20, R 17/20; 0.40 [0.10, 0.62] | Separates at n = 20 (JL-21b review). |
| cb-bench-one-kinematic | confirmatory | scripted > random | 40 | S 12/20, R 8/20; −0.20 [−0.46, 0.10] | Meets the 0.20 line; JL-26 review N2 notes it runs against JL-21's direction. |
| cb-bench-one-rigid | confirmatory | scripted > random | 40 | S 4/20, R 0/20; −0.20 [−0.42, 0.00] | Meets the line; all 4 discordant prior pairs favour scripted. |
| sd-mid-climb-kinematic | confirmatory | scripted > random | 40 | S 8/20, R 3/20 | Meets the line. Under threat rule 1 it was 6 vs 6; rule 2 moved it (JL-27 review F2), so this cell also tests whether that shift holds on fresh seeds. |
| sd-flood-hatch-kinematic | exploratory | (prior scripted > random) | 20 | S 5/20, R 2/20 | Prior difference 0.15 is under the line. |
| bl-pillar-weave-rigid | exploratory | (prior random > scripted) | 20 | S 3/20, R 4/20 | 0.05, under the line. |
| bl-dummy-knock-rigid | exploratory | (prior random > scripted) | 20 | S 1/20, R 4/20 | 0.15, under the line; rigid knocks barely register (JL-21b review). |
| bl-run-to-pad-kinematic | ceiling | none | 20 | 20/20 both | Regression control; time-to-success is its exploratory measure. |
| bl-dummy-knock-kinematic | ceiling | none | 20 | 20/20 both | As above; scripted p90 5.5 s. |
| bl-bench-climb-kinematic | floor | none | 20 | 0/20 both | `hit_kicker` is unreachable under the gate (JL-21 F4). |
| bl-bench-climb-rigid | floor | none | 20 | 0/20 both | As above. |
| cb-forge-charge-kinematic | floor | none | 20 | 0/20 both | Every trial scrapped (JL-26 findings 4). |
| cb-forge-charge-rigid | floor | none | 20 | 0/20 both | As above. |
| cb-stage-run-kinematic | floor | none | 20 | 0/20 both | Every trial scrapped before the forge (JL-26 finding 3). |
| cb-stage-run-rigid | floor | none | 20 | 0/20 both | As above. |
| sd-mid-climb-rigid | floor | none | 20 | S 0/20, R 1/20 | 39 of 40 prior trials died. |
| sd-flood-hatch-rigid | floor | none | 20 | 0/20 both | Every prior trial died. |

The prior intervals above come from the reviews and the lab tables and were reproduced by `analyze.mjs --prior` (see [Analysis dry run](#analysis-dry-run-result)).

## Primary metric

Per cell, the scenario's own success predicate as the sketch judges it within its limit: a trial succeeds when `scenario_result.result` is `"success"`. Nothing else is primary.

## Statistic and decision rule

For each cell, with pairs by trial seed: `both`, `random only`, `scripted only`, `neither`.

- **Test (confirmatory cells only).** Exact one-sided McNemar in the pre-registered direction: with f discordant pairs in that direction and g against it, p = P(X ≥ f), X ~ Binomial(f + g, 1/2). No discordant pair gives p = 1.
- **Multiplicity.** Holm step-down over the five confirmatory cells at family-wise α = 0.05. A cell that is BLOCKED or INVALID enters the family with p = 1, so the family size stays five.
- **Verdict per confirmatory cell.** SUPPORTED when its Holm-adjusted p ≤ 0.05; otherwise NOT SUPPORTED. BLOCKED and INVALID as defined below.
- **Reversal flag.** A confirmatory cell whose paired difference has the opposite sign to its direction and whose two-sided exact McNemar p < 0.05 is flagged "reversal". The flag is descriptive, not a test.
- **Intervals, every cell.** 95% Newcombe interval for R − S on paired data (Newcombe 1998b, method 10, `analyze.mjs` `newcombePaired`), and the unpaired Newcombe hybrid score interval (method 10 of the 1998a paper) for comparison with the earlier lab tables. Wilson 95% per arm.
- **Resolution.** At n = 20 the unpaired half-width is about 0.26 to 0.28 at mid rates, so only differences of about 0.3 resolve; at n = 40 it is about 0.19 to 0.20, and pairing narrows it further when outcomes correlate within a pair (unverified-computed with `analyze.mjs`). With no discordant pair against the direction, the one-sided exact test needs at least 5 favoured pairs to reach 0.05 and 7 to reach 0.01.

## Validity checks

| Check | Rule | Consequence when it fails |
| --- | --- | --- |
| V1 multi-option share | Per cell and arm, Σ `arm_calls` / Σ `snapshots` over the included trials ≥ 0.5, as the JL-21b review computed it (`reviews/JL-21b.md:40`). The harness never asks an arm on a forced snapshot, so this is the share of snapshots that offered two or more options (SKL-30). | The cell is INVALID; a confirmatory cell enters Holm with p = 1. |
| V2 source identity | Every record: `provenance.dirty` false, `sources.matched` true, `provenance.head` equal to the head recorded in `provenance-before.json`; stage records: `sketch_head` equal to the head above and `sketch_dirty` "false". Before and after the run: harness worktree clean, ball-lab tree `0a9f59ce…`, both lab worktrees clean at their heads, both `proto/*` refs unchanged. | Batch invalid, cell BLOCKED. A precondition failure before the run means `--live` refuses and nothing runs. |
| V3 no Jev | Every record: arm `scripted` or `random`, `provenance.jev.calls` 0, `instrument` null. | Batch invalid, cell BLOCKED. |
| V4 completeness | Every batch: launcher exit 0, batch seed 2, n trials as planned, trial i at seed 2000 + i; every trial `outcome` "complete" with a `scenario_result` of `success` or `timeout`. | A failed trial drops its pair. A cell with more than 10% of pairs dropped is BLOCKED. A batch-level failure blocks the cell. |
| V5 epoch | Spillway: every trial's `scenario_result.epoch` is "stage-threat-rule 2 + end-on-death" (a mismatched trial drops its pair). ball-lab: the canary below exits 0. Cable Bench records carry no epoch field; its epoch rests on V2's head check. | As V4; canary failure stops the run before any counted batch. |
| V6 rigid | Rigid trials are not trace-reproducible (SKL-09), so no trace hash is compared on any rigid record, and no kinematic hash is compared either except in the canary. | None. |

**Canary.** Before any counted batch: ball-lab `dummy-knock`, scripted, kinematic, n = 20, seed 1, then `node scripts/lab/gate.mjs <canary run dir> --against artifacts/jev-lab-2026-09-26/pins/ball-lab-scripted-dummy-knock-kinematic`. Exit 0 (20 of 20 traces reproduce) shows the ball-lab code path is the pinned epoch. Any other exit stops the run with no counted batch launched; the report says so and nothing else runs under this pre-registration.

## Readings

| Reading | Fires when | Consequence |
| --- | --- | --- |
| Replication | `bl-pillar-weave-kinematic` and `bl-run-to-pad-rigid` both SUPPORTED | JL-21's direction holds on fresh seeds at this epoch. |
| Stage direction | Any of `cb-bench-one-kinematic`, `cb-bench-one-rigid`, `sd-mid-climb-kinematic` SUPPORTED | Scripted beats random on that stage cell; the arms' order is stage-specific. |
| Unresolved | A confirmatory cell NOT SUPPORTED | Reported with its interval and the planning power below; no claim of equality. |
| Reversal | A reversal flag on any confirmatory cell | Reported beside the verdict; not a finding until a new pre-registered test. |
| All-forced | V1 fails on any cell | That cell cannot separate the arms at this epoch; reported. |

The Phase B report states which readings fired, with numbers, and adds no rows. Every other observation goes under a heading that says it was not pre-registered.

## Exploratory measures

Reported per cell and arm, labelled "exploratory; not a test", with no decision attached: time to success p50 and p90 in seconds (`success_tick` / 90, successes only); deaths (`end` "scrapped" or `dead_tick` ≥ 0); stuck episodes per trial and trials with one (`stuck_begin` events, `stuck_per_trial`); dead tier, the least-used speed tier's share of 10 Hz trace samples (`dead_tier`); anomalies per trial and by kind; stomp and ram knocks per trial; ball-lab gates mean. The exploratory two-sided McNemar p on non-confirmatory cells is in this group too.

## Planning power (unverified-computed)

From the prior discordant-pair rates at n = 20, the chance the one-sided exact test rejects at n = 40 (`analyze.mjs` `pairedPower`), at α/5 (Holm's first step) and at α (its last):

| Cell | Prior favoured / against pairs | Power at α/5 | Power at α |
| --- | --- | --- | --- |
| bl-pillar-weave-kinematic | 10 / 0 | 1.00 | 1.00 |
| bl-run-to-pad-rigid | 11 / 3 | 0.75 | 0.92 |
| cb-bench-one-rigid | 4 / 0 | 0.71 | 0.92 |
| sd-mid-climb-kinematic | 8 / 3 | 0.36 | 0.64 |
| cb-bench-one-kinematic | 7 / 3 | 0.23 | 0.49 |

These treat the prior rates as true, which they are not. They say that a NOT SUPPORTED on the last two cells is weak evidence either way.

## Analysis dry run result

The pre-registration procedure's stub dry run becomes, for a run without a decider, the pinned analysis applied to the real prior records.

- **Date:** 2026-09-26, before any counted batch. **Input:** the four `prior_sources` in `design.json` (seed 1, trials 1000 to 1019, the epochs above). **Output:** `artifacts/local/tasks/JL-28/phase-a/prior-dry-run.txt` and `prior/results.json`.
- **Where the prior records live:** Cable Bench and Spillway in this repository under `artifacts/jev-lab-2026-09-25/live/`; ball-lab in the JL-21b writer worktrees `../scrapkeep-wt-JL-21b` and `../scrapkeep-wt-JL-21b-int`, which the repository does not retain.
- **Coverage:** 18 of 18 cells found, both arms, every cell paired by seed, 0 pairs dropped, 0 cells blocked.
- **Fields the readings need were present:** `config.trials[].seed`, `outcome`, `snapshots`, `arm_calls`, `scenario_result.result`, `success_tick`, `anomalies`, `knocks`, `end` or `dead_tick`, Spillway `epoch`, `provenance.dirty`, `sources.matched`, `versions.sketch_head`, `sketch_dirty`, `jev.calls`.
- **Cross-checks against earlier numbers:** pillar-weave kinematic unpaired 0.50 [0.22, 0.70] and scripted share 0.61; run-to-pad rigid 0.40 [0.10, 0.62]; bench-one −0.20 [−0.46, 0.10] and −0.20 [−0.42, 0.00]; pillar-weave gates 2.10 against 3.20. All match the JL-21b review and the JL-26 table.
- **Self-test:** `node analyze.mjs --self-test` passes (Wilson and Newcombe against five published intervals from the reviews and lab tables; exact tails; McNemar; Holm; the paired interval reduces to the unpaired one when the within-pair correlation is 0 and narrows when it is positive).
- **Gaps found:** the retained stage records keep `run.json` only, so stuck and dead-tier measures read "no events" for them. Phase B keeps its trial directories locally, so this does not affect the run. No other problem found; nothing changed in the pinned files after the dry run except the hashes recorded here.

## Run-once, blocked and stop rules

- `run.mjs --live` creates `artifacts/local/tasks/JL-28/live/STARTED.json` with exclusive create before anything runs and refuses if it exists. Removing it is a new coordinator decision, recorded in the change record.
- Batches run once, four at a time in the plan order, each with its own runs root. No batch is re-run, resumed or replaced.
- A crash of the runner mid-run is BLOCKED. The records already written are reported as they fell; there is no rerun into the same seeds.
- An infrastructure failure (launcher exit other than 0, a trial that did not complete, a changed source, a dirty sketch) blocks the affected cell under V2 to V4.
- The run as a whole is BLOCKED, with no verdict on any cell, when one third or more of the 18 cells are blocked.
- No row is added to Readings after the run.

## Phase B procedure

1. The coordinator confirms this commit is the reviewed one, the worktree is clean, and `node artifacts/jev-lab-2026-09-25/experiments/arms/run.mjs --dry-run` shows every pin matching and every precondition ok.
2. Run once from this worktree: `node artifacts/jev-lab-2026-09-25/experiments/arms/run.mjs --live`. It writes `provenance-before.json`, the canary and its gate log, one log pair per batch, `batches.ndjson`, `provenance-after.json` (with the preconditions re-checked) and `analysis/results.{json,md}` under `artifacts/local/tasks/JL-28/live/<start>/`.
3. Retain stdout, stderr and the exit code. Confirm `proto/cable-bench` 29dcbcf and `proto/spillway-drop` af89c89 after the run.
4. Write `RESULTS.md` beside this file: each reading that fired with its numbers, each cell as it fell, the exploratory table labelled as such, V/U/R tags on every number, and "automated; not a feel verdict" in its first lines. Then `FINDINGS.md` per DoD 2 below.

**Estimated wall time** (unverified-computed from the prior batches' `started_at` and `finished_at`; the Cable Bench and Spillway prior batches ran 8 to 12 at a time, so their times are upper bounds): 36 batches and 920 trials, about 79 min in sequence, about 20 min four at a time, plus about 15 s for the canary. `--dry-run` prints the same figures.

## DoD 2: the gameplay findings list for Andrew

**Format, fixed now.** `FINDINGS.md` beside this file, written in Phase B.

- A short "try first" list at the top: the three to five findings that most change a play session, each one line.
- Then one section per sketch (ball-lab, Cable Bench, Spillway Drop), findings ordered by how much each would change play.
- Each finding has five lines. **Claim:** one sentence. **Try:** what Andrew does, in which mode. **Look for:** what he should see if it holds. **Evidence:** the source, labelled observed, inference or unretained, with its epoch. **JL-28:** the Phase B number that bears on it, or "not re-measured".
- A last section, "Phase B observations, not pre-registered", for anything new the run shows.
- Every section opens with "automated; not a feel verdict".

**Inventory before Phase B** (the sources the list is compiled from; Phase B adds numbers, it does not add claims here):

| Sketch | Finding | Source | What JL-28 re-measures |
| --- | --- | --- | --- |
| ball-lab | In rigid mode a stomp landed centred on a dummy is never credited; `enemy_touched` reads post-bounce velocity. | EV-0531, EV-0534 (review confirmed) | Rigid stomp knocks per trial. |
| ball-lab | Rigid mode's grounded flag drops while rolling on flat ground, which cuts drive to air control and flickers jump and brake. | EV-0531, EV-0534 | Nothing directly; rigid stuck episodes as context. |
| ball-lab | The service ramp's top is a step of about 1.6 m. | EV-0534 | Not re-measured. |
| ball-lab | Tilted boxes' raised ends leave wedge gaps narrower than the ball; a pinned kinematic ball reports rising speed and a cruise tier while not moving. | EV-0534 | Kinematic stuck episodes. |
| ball-lab | No arm reached the bench in the 80 bench-climb trials at this epoch (JL-21b-A2 kinematic, A3 rigid) or in JL-21's 80; `hit_kicker` is offered only at a decision-time speed the run-up never has. Can a person reach it? | JL-21 review F4; EV-0566 | Bench-climb floor cells. |
| ball-lab | Dummies chase without end and cannot die, so a knocked dummy returns. | JL-21 review F1 | Not re-measured (design fact). |
| Cable Bench | Knocking a foe usually costs HP: about half of knocks, and most rams, land within 3 ticks of a foe's contact hit. | `live/JL-26/findings.md` 1 | Knocks per trial; the coincidence count is not re-measured. |
| Cable Bench | Rigid climbs road 0 near chaser speed (median 7.1 m/s, 48% of samples under 7 m/s). | `live/JL-26/findings.md` 2 | Not re-measured. |
| Cable Bench | No trial reached the forge on the full stage, so the cache-versus-clock choice never came up. | `live/JL-26/findings.md` 3 | stage-run success and deaths. |
| Cable Bench | The forge charge at tier 1 was never survived; 2.5 to 3.3 miniboss hits per trial. | `live/JL-26/findings.md` 4 | forge-charge success and deaths. |
| Cable Bench | A committed kicker run-up arrives at 38 to 45 m/s against the README's 26 m/s. | `live/JL-26/findings.md` 5 | Not re-measured. |
| Cable Bench | The gates remove more stomp and ram offers in rigid (stomp kept 0.80 against 0.97). | `live/JL-26/findings.md` 6 | Multi-option share per mode. |
| Spillway Drop | The ball dies in most trials; a stomp costs HP because the rebound keeps the ball inside the chaser's 2.6 m reach. | `live/JL-27/findings.md` 1; `findings-a3.md` | Deaths per arm and mode. |
| Spillway Drop | The chute beats the bypass: 1600 and 1236 ticks against 2263 and 2985. | `live/JL-27/findings.md` 2 | Not re-measured. |
| Spillway Drop | A 6 m kerb at 1.3 m per m stands between the bypass ramp and every shelf. | `live/JL-27/findings.md` 3; `findings-a3.md` | Not re-measured. |
| Spillway Drop | The mid shelf has one clear east-west line from the ramp. | `live/JL-27/findings.md` 4 | Not re-measured. |
| Spillway Drop | After death in the flood, the flood force keeps pushing the ball (the stage stops refreshing `external_accel`). | `live/JL-27/findings.md` 5; A3 0 anomalies in 160 trials | Anomalies per trial (the lab now ends at death, so it cannot see this). |
| Spillway Drop | The gate removes most ram offers; ram's tier gate reads the previous hold's speed. | `live/JL-27/findings.md` 6; `findings-a3.md` | Multi-option share. |
| Spillway Drop | The stage's own `exit_test.gd` fails about 1 run in 4 to 6 on the unmodified proto build; it reads the position one frame before a rigid teleport lands. | EV-0559; `live/JL-27/findings-a3.md` | Not re-measured. |

## What the report must say

- "Automated; not a feel verdict." in its first lines, and per sketch in `FINDINGS.md`.
- Each confirmatory cell's verdict with its counts, pairs, one-sided p, Holm p and paired interval; each other cell's counts and interval without a verdict.
- Which validity checks failed, if any, and which cells were blocked.
- The epoch and source identity of each sketch, and the canary's gate exit.
- That a NOT SUPPORTED is not evidence of equality, with the planning power.

## Known limits

- Rigid trials are not exactly reproducible: Cable Bench A2 repeat pairs 119, 119 and 118 of 120 (EV-0553), Spillway 79 of 80 in A2 and 80 of 80 in A3 (`live/JL-27/logs-a3/11-a1-a2-a3.tsv`), ball-lab about 1 in 20 (JL-21 review F2). A pair's outcome can flip on a rerun; this adds noise to the rigid cells, and no rigid trace is gated.
- The arms act through steering each lab wrote for its stage; the comparison is of decision policies on top of those hands, not of players.
- One ladder (`scripts/lab/arms.mjs`) runs on every sketch and sees only what each stage's state offers; nothing here compares sketches with each other.
- Classification and direction come from one prior batch per cell at n = 20. A cell can be misclassified; the exploratory cells still report intervals, so a missed effect stays visible.
- Cable Bench records carry no epoch field; its epoch is its lab head.
- The paired interval is my implementation of Newcombe's method 10 from the paper's formulas. Its self-tests are structural (it reduces to the unpaired interval when the within-pair correlation is 0); I did not check it against the paper's worked example in this session.
- Planning power and wall time are computed, not measured.

## Pinned inputs

`run.mjs --live` refuses to start unless every line below matches the file bytes in `artifacts/jev-lab-2026-09-25/experiments/arms/`.

- `design.json` sha256 `b64f814a50861facfd13e8d555f31785ef428df8a965438dd881b74d9bfffde4`
- `analyze.mjs` sha256 `f387c137e26baff35746a76d525a701d0ba59b1b92ff55be8632ce405f34058c`
- `run.mjs` sha256 `b361e8290e891837e50c1683f80fde8f65397b5e197d1e4e3bb13854f1863d18`

## Change record

Kept in [CHANGES.md](CHANGES.md), append-only and outside the pinned set: UTC time, change, requested by, reason, and whether it came before any counted batch.
