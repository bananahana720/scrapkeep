# Scenarios and arms

A scenario is a spawn, an objective, a time limit and a success predicate. An arm answers each snapshot with one intent. Arms are compared on the same scenarios, seeds and physics modes.

## Add a scenario to ball-lab

1. Add the id to `IDS` in `sketches/ball-lab/src/jev/scenarios.gd` and a `make()` branch with spawn, objective, time limit and predicate, using the coordinates in `sketches/ball-lab/src/field.gd`. Label a new limit as initial, not calibrated.
2. If the scenario offers choices, wrap it in `_jittered()` so trial i starts at the same seeded point on every arm (SKL-16).
3. Decide the dummies. Every ball-lab scenario gets the same six dummies: `sketches/ball-lab/src/field.gd:84-87` lists their spots and `sketches/ball-lab/src/lab.gd:51-56` spawns one at each, whatever the scenario. `Scenarios.place()` (`sketches/ball-lab/src/jev/scenarios.gd:159-167`) moves only the ball. No per-scenario dummy hook exists today (SKL-33). A card whose scenario needs a different set must add one, for example an optional `dummies` key that `place()` reads, with the default keeping all six so existing scenarios' traces do not change. It must also add a state-test check that each scenario places the dummies it names.
4. Update the state test's hardcoded counts (SKL-34). `sketches/ball-lab/tests/jev_state_test.gd` fails for any new id until three places change: the id count `ids.size() == 7` at line 559, the per-id `cases` table of predicate pass and fail states at lines 561-569, and the jitter count `jittered == 4` at line 608 (only if the new scenario jitters).
5. Add the id to the fake Godot only if a Node test or `scrapkeep lab run` will drive the scenario through it. The fake throws on an id it does not know (`scripts/lab/fake-godot.mjs:190-193`). The real launcher needs no Node-side registration: it passes `--scenario=<id>` to Godot (`scripts/lab/godot-launch.mjs:103`), and Godot resolves the id from `IDS`. If you do add a fake entry, note that the fake `soak` stream cycles through every other entry in `base` (`scripts/lab/fake-godot.mjs:143-148`), so the new entry changes `soak` and anything that depends on its sequence (SKL-35).
6. Run the sketch test headless, then `npm run sketch:smoke` and `npm test`.
7. Run the arms through real Godot from your own frozen worktree (SKL-23), for example `node scripts/lab/godot-launch.mjs <scenario> --arm scripted -n 20 --seed 3 --mode kinematic`, then the random arm, then both in rigid mode. Pick the seed by the rule under "Seeds" below. The scripted and random arms never call Jev. The call cap must be a whole number of at least 1 (`scripts/lab/harness.mjs:698-701`), so `--call-cap 0` is a usage error; when no Jev call is authorized, do not run the jev arm.
8. Report the multi-option share, defined below. A scenario where every snapshot offers only `push_objective` forces every answer and cannot separate arms (SKL-30).
9. Report success counts with Wilson intervals and differences with Newcombe intervals. With n = 5 a difference is exploratory.
10. Label every metric chosen after seeing the data as post hoc in the result file itself, not only in the script that computed it (`artifacts/jev-lab-2026-09-25/reviews/JL-21.md:17`). In a TSV that is a header or label row; in JSON, a field; in Markdown, the heading. When the card has a retained evidence directory, the file lives there. When it has none, as in an exercise or an exploratory batch, keep the file with the task receipts under `artifacts/local/tasks/<task-id>/` and repeat the label in the handoff, because that directory is gitignored and disposable (design choice).

## Seeds

Trial i of a batch with seed s runs with trial seed s × 1000 + i (`scripts/lab/harness.mjs:51-52`, `TRIAL_SEED_STRIDE` at `:122`, applied at `:870`; each record's config stores it as `trial_seed_stride` at `:814`). A batch is therefore capped at 1000 trials, and batches with different seeds share no trial seed.

| Batch seed | Trial seeds | Use |
| --- | --- | --- |
| 1 | 1000 onward | The lab cards' batches so far. It is also the default when `--seed` is omitted (`scripts/lab/harness.mjs:112`), so an unseeded batch lands on this range. |
| 2 | 2000 to 2019 | Reserved for JL-28's pre-registered comparison (SKL-29, EV-0550). Never use it for anything else. |
| 3 or higher | 3000 onward | Exploratory batches, exercises and new-scenario trials. Name the seed in the handoff so a later pre-registration can avoid it. |

Ask the coordinator for a reservation before pre-registering a new comparison, and do not reuse a seed another comparison has reserved (SKL-29).

## Multi-option share

The multi-option share of a batch is the fraction of snapshots, after the precondition gate, that offered two or more options: the sum of `arm_calls` over the sum of `snapshots` across its trials (design choice). The gate runs first: `offeredOptions()` in `tools/jev-player/decide.mjs:137-142` drops options whose preconditions fail and falls back to `push_objective` when none survive. The harness then counts a snapshot with one offered option as `forced` and every other snapshot as an arm call (`scripts/lab/harness.mjs:425-447`). The launcher prints `snapshots`, `arm calls` and `forced` for every trial (`scripts/lab/godot-launch.mjs:272`), so the share can be read from its output. A batch stopped by its call cap has one more snapshot than arm calls plus forced answers in its last trial; say so if it happens.

## Calibrate a scenario

- **Time limits.** The rule is max(initial, 2 × scripted p90 over 20 trials per mode). Check that the scripted p90 is uncensored first; if trials still hit the limit at 3 × the limit, record the limit as inconclusive and leave it unchanged (SKL-17).
- **Physics constants.** Measure them with a physics-only probe, such as a spawn just before the kicker lip at set launch speeds, not from arm trials (SKL-19).
- **Offer conditions.** Gate an option on what the ball can reach from here, not on its present speed or position for a target it reaches only later. `hit_kicker` gated on current speed was almost never offered (SKL-18).

## Decide the threat rule for each stage

The exported threat list decides what every arm sees, so its rule is part of the instrument, and changing it starts a new epoch (SKL-15).

| Stage | Can a foe die or be freed? | Rule |
| --- | --- | --- |
| ball-lab | No; dummies have no health and chase without end | A dummy knocked in this trial leaves the threat list (JL-21b) |
| Cable Bench | Yes; a knocked foe keeps its health and keeps chasing | Stage-threat-rule 2: only a dead or freed foe leaves |
| Spillway Drop | Yes; same as Cable Bench | Stage-threat-rule 2 |

Stage-threat-rule 2 is a coordinator ruling (EV-0550). It changed the rule for stages whose foes survive a hit; the JL-26 and JL-27 writers had applied the JL-21b rule as instructed, and their A2 attempts re-ran under the ruling (EV-0553). For a new stage, answer the middle column from the stage's own source before the first batch, and ask the coordinator for a ruling if the answer is mixed.

### Ball-lab since JL-21b

JL-21b is done: A2 merged at 7ba2d0d (EV-0564) and A3 at 82d2a96 (EV-0566). On this base a dummy knocked in the trial leaves the exported state (`sketches/ball-lab/src/jev/jev_state.gd:220-226`, filtered at `:246-252`), and stomp and ram act on the threat the state reported, falling back to the nearest live threat if that one was knocked before the intent applied (`sketches/ball-lab/src/jev/jev_run.gd:300-313`; SKL-31). The scripted ladder no longer loops on stomp: `dummy-knock` kinematic scripted stomp stretches fell from 63.6 to 3.3 per trial (EV-0563). One re-stomp within a single hold is still possible and is a known property of this epoch (`artifacts/jev-lab-2026-09-25/reviews/JL-21b.md:16`).

What follows for reading results:

- A batch from before this epoch that shows scripted below random on a scenario with dummies records the stomp loop. Read it as an instrument artefact, not as a scenario defect or a policy result (SKL-14).
- Scripted is not guaranteed above random under the new epoch. After the fix only `pillar-weave` kinematic and `run-to-pad` rigid separate the arms, with random above scripted (EV-0563, EV-0564). A new dummy scenario should be expected to separate weakly or not at all until its batches show otherwise.
- Every limit now rests on the merged executor. A3 re-ran `bench-climb` and `pillar-weave` rigid with their 3× probes at the merged head; both stay censored and keep their initial limits. It also re-ran `downhill-run` and `kicker-gap` in both modes, with limits kept and hashes equal to A1 (EV-0566). A3 changed no limit. The only per-mode override left is `run-to-pad` kinematic at 61 s, set in A2, when `dummy-knock` kinematic went back to its initial 60 s (EV-0563; `sketches/ball-lab/src/jev/scenarios.gd:38-48`).
- The two scripted `dummy-knock` pins were re-cut under `artifacts/jev-lab-2026-09-26/pins/`, and the gate resolves those names to the new cut. The 2026-09-25 copies record the old epoch (EV-0566; [records-gates-pins.md](records-gates-pins.md)).

Whether a trial ends at death is the same kind of per-stage instrument choice. Ball-lab's dummies deal no damage (`artifacts/jev-lab-2026-09-25/reviews/JL-21.md:11`); Cable Bench and Spillway Drop end the trial at death (SKL-32).

## Arms

| Arm | Role | Allowed `source` values |
| --- | --- | --- |
| `random` | Seeded floor | `seeded`, `forced` |
| `scripted` | Rule-ladder baseline in `scripts/lab/arms.mjs` | `rule`, `forced` |
| `jev` | Candidate; parked as a player for this program (SKL-27) | `live`, `cache`, `forced` |

- When exactly one option is offered, every arm answers it with `source: "forced"` and no arm is called.
- A hand-written ladder needs a termination or memory condition. Without one it can fall below random, as ball-lab's did when it stomped chasing dummies forever (SKL-14). Fix the shared state or the scenario, not the ladder, so no arm is tuned to the result.
- Steering changes in `sketches/ball-lab/src/jev/jev_agent.gd` are hands every arm shares. Make them general fixes, never tuned to one scenario's result.
- Adding an arm changes a closed set in the protocol: follow the change procedure in [protocol.md](protocol.md).
- The jev arm needs a valid epoch; a live jev batch runs the preflight controls first and exits 6 when they fail (SKL-28). The rules for its controls, cache and cost fields are in `reactive-model-loop`.
