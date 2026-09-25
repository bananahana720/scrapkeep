# Scenarios and arms

A scenario is a spawn, an objective, a time limit and a success predicate. An arm answers each snapshot with one intent. Arms are compared on the same scenarios, seeds and physics modes.

## Add a scenario to ball-lab

1. Add the id to `IDS` in `sketches/ball-lab/src/jev/scenarios.gd` and a `make()` branch with spawn, objective, time limit and predicate, using the coordinates in `sketches/ball-lab/src/field.gd`. Label a new limit as initial, not calibrated.
2. If the scenario offers choices, wrap it in `_jittered()` so trial i starts at the same seeded point on every arm (SKL-16).
3. Add canned snapshots for the id to `scripts/lab/fake-godot.mjs` if Node tests or `scrapkeep lab run` should exercise it.
4. Add a test under `sketches/ball-lab/tests/` and run `npm run sketch:smoke` and `npm test`.
5. Run the arms through real Godot from your own frozen worktree (SKL-23), for example `node scripts/lab/godot-launch.mjs <scenario> --arm scripted -n 20 --seed 1 --mode kinematic`, then the random arm, then both in rigid mode. The scripted and random arms never call Jev. The call cap must be a whole number of at least 1 (`scripts/lab/harness.mjs:672-675`), so `--call-cap 0` is a usage error; when no Jev call is authorized, do not run the jev arm.
6. Check the share of snapshots that offer two or more options. A scenario where every snapshot offers only `push_objective` forces every answer and cannot separate arms (SKL-30).
7. Report success counts with Wilson intervals and differences with Newcombe intervals. Label every metric chosen after seeing the data as post hoc, in the result file itself, not only in the script (`artifacts/jev-lab-2026-09-25/reviews/JL-21.md:17`).

Do not use a later comparison's pre-registered trial seeds for exploratory batches. JL-28 moved to seeds 2000 to 2019 because the lab cards had already run 1000 to 1019 (SKL-29).

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

The JL-21b rule is a card at this base, not merged code: `sketches/ball-lab/src/jev/jev_state.gd` still exports knocked dummies until JL-21b is admitted.

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
