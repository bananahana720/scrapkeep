---
name: scrapkeep-lab
description: "Run, extend or port Scrapkeep's headless Godot lab and produce its evidence: add a scenario or arm, run a batch through the harness, cut or compare a pin, run the lab gate on a batch and read its exit, cut an approved instrument epoch, or bring the lab to a new stage. Use for hands-on lab, harness, scenario, arm, pin, lab-gate or epoch work. Deciding what the lab should work on next, including whether to start an epoch, starts in plan-session, which pulls this skill in; verification checklists for a diff stay in scrapkeep-verify and admission in scrapkeep-task."
---

# Run and extend the Scrapkeep lab

Resolve this skill directory through symlinks, then run `git -C <resolved-skill-directory> rev-parse --show-toplevel` to identify the repository root. Read `AGENTS.md` and `docs/project/README.md`. Use root-relative source paths below. The linked Claude skill resolves to this same body.

This skill produces lab evidence and says what it means. `reactive-model-loop` owns the method for a model that decides inside a running system (controls, blind corpora, pre-registration, caching, cost fields); this skill applies it to the Godot lab. `scrapkeep-verify` owns which checks qualify a change, and `scrapkeep-task` owns admission, leases and review. Each rule line below cites a lesson in [references/lessons.md](references/lessons.md) or says it is a design choice.

## 1. Map

- Protocol and decider: `tools/jev-player/protocol/PROTOCOL.md` (the spec), `tools/jev-player/protocol/protocol.mjs` (Node validators), `tools/jev-player/decide.mjs`, `tools/jev-player/preflight.mjs`, `tools/jev-player/score.mjs`, question sets in `tools/jev-player/questions/`, controls in `tools/jev-player/controls/`.
- Harness: `scripts/lab/harness.mjs` (batches, outcomes, call cap), `scripts/lab/godot-launch.mjs` (real Godot, `--sketch`, `stageFor`), `scripts/lab/arms.mjs`, `scripts/lab/record.mjs`, `scripts/lab/gate.mjs`, `scripts/lab/verdict-cache.mjs`, `scripts/lab/metrics/index.mjs` (`METRICS`, `STAGES`).
- Godot side, under `sketches/ball-lab/src/jev/`: the runner `sketches/ball-lab/src/jev/jev_run.gd`, the validator `sketches/ball-lab/src/jev/jev_io.gd`, the exported state `sketches/ball-lab/src/jev/jev_state.gd`, steering in `sketches/ball-lab/src/jev/jev_agent.gd`, scenarios in `sketches/ball-lab/src/jev/scenarios.gd` and knock counting in `sketches/ball-lab/src/jev/telemetry.gd`.
- CLI (`scripts/play.mjs`): `scrapkeep lab run|program|verdicts|watch`, `scrapkeep gate <run> --against <pin>`, `scrapkeep stats`, `scrapkeep dash`. `scrapkeep lab run` is `scripts/lab/harness.mjs`, which drives the fake Godot in `scripts/lab/fake-godot.mjs`. Real batches run through `node scripts/lab/godot-launch.mjs <scenario> [--arm scripted|random|jev] [-n trials] [--seed N] [--mode kinematic|rigid] [--call-cap N] [--sketch dir]`.
- Watch view: `npm run play -- lab watch <scenario> --arm <arm>` (`scripts/lab/watch.mjs`) plays one trial in a visible Godot window with the decision overlay. It is a demo, never evidence: the gate refuses its record, a failed jev preflight does not stop it, and every live call counts against `--call-cap` (60 by default). Stage labs run through `--sketch` have no overlay yet. `scrapkeep watch` without `lab` is the sketch test watcher (EV-0562; design choice).
- `scrapkeep` is the wrapper `scripts/bin/scrapkeep` for `node scripts/play.mjs`. It runs the checkout named by `SCRAPKEEP_ROOT`, default the main checkout, so from a worktree run `node scripts/play.mjs` or set `SCRAPKEEP_ROOT` (SKL-23).
- Current state: pins under `artifacts/jev-lab-2026-09-25/pins/` and `artifacts/jev-lab-2026-09-26/pins/`, a name resolving to its newest day; epoch records under `EPOCHS_ROOT` in `tools/jev-player/preflight.mjs` (`artifacts/local/epochs/<key>.json`, disposable); rulings and card state in the latest TRACKING event rows for the card. A question-text author reads none of TRACKING and gets rulings from the packet (SKL-26).
- Evidence: retained under `artifacts/jev-lab-2026-09-25/live/`, `artifacts/jev-lab-2026-09-25/pins/`, `artifacts/jev-lab-2026-09-25/reviews/` and `artifacts/jev-lab-2026-09-25/experiments/`; disposable runs under `artifacts/local/runs/<run-id>/` and task receipts under `artifacts/local/tasks/<task-id>/`.

## 2. Protocol

Read [references/protocol.md](references/protocol.md) before changing a file format, a validator or the gate rules (design choice).

- Each protocol file has one writer, is written as `.tmp` then renamed, and has a closed schema; a new field is a new protocol string (SKL-01).
- Godot blocks with `OS.delay_msec`, never `tree.paused`; keep D = 90, k = 26 and k < D (SKL-02).
- `trace_hash` covers `events.ndjson` only, and Godot files carry ticks, never wall time (SKL-03).
- Closed sets match own string keys only; test `constructor` and `["ram_target"]` against every new validator (SKL-04).
- Port a validator from the spec text, not from the other implementation (SKL-05).
- Fixtures have one source, byte-copied with a drift test (SKL-06). Outcome precedence is a total order (SKL-07).
- A gate-rule change bumps `GATE_VERSION` in `tools/jev-player/decide.mjs`, `sketches/ball-lab/src/jev/jev_io.gd` and the spec together; `tests/jev-fixtures.test.js` checks all three (design choice).

## 3. Determinism per physics mode

Read [references/determinism.md](references/determinism.md) before reading or gating a rigid result (design choice).

- Kinematic runs reproduce exactly; treat a kinematic hash change as a real behaviour change (SKL-08).
- Rigid runs do not reproduce exactly and a divergence can flip the outcome; never hold a rigid record to trace equality (SKL-09).
- The rigid gate checks n ≥ 20 on each side and reachability, and compares no rate; JL-28 left a rigid rate comparison to a separate card (SKL-10).
- Before trusting a new hash oracle, perturb k or one answer and confirm the hash moves (SKL-12).

## 4. Scenarios and arms

Read [references/scenarios-and-arms.md](references/scenarios-and-arms.md) to add a scenario or an arm (design choice).

- A hand-written baseline needs a termination condition, or it scores below random; fix it in the shared state, not in one arm (SKL-14).
- Decide the threat-export rule per stage before the first batch. Stage-threat-rule 2 (EV-0550) is a coordinator ruling: a threat leaves the state only when the game has taken it out of play (SKL-15).
- The stomp and ram executor must act on the threat the state reports, or a state rule is only half applied; ball-lab does since JL-21b's merge (SKL-31, EV-0564).
- Decide per stage whether a trial ends at death before the first batch; post-death snapshots pollute per-snapshot measures (SKL-32).
- Jitter spawns from the trial seed so arms share paired starts (SKL-16).
- A new ball-lab scenario gets the fixed six dummies unless its card adds a hook, and it must update the state test's hardcoded counts (SKL-33, SKL-34).
- Add a fake-Godot entry only for tests that drive the scenario through the fake; it changes the fake `soak` stream (SKL-35).
- Report the multi-option share, arm calls over snapshots after the precondition gate; an all-forced scenario cannot separate arms (SKL-30).
- Trial seed = batch seed × 1000 + i. Batch seed 1 is the lab cards' range and the default, 2 is reserved for JL-28, and exploratory batches use 3 or higher (SKL-29).
- Check that a calibration input is uncensored before trusting a derived limit (SKL-17).
- Gate an option on reachable geometry, not on present state for a future target (SKL-18).
- Calibrate physics constants with physics-only probes, apart from arm trials (SKL-19).
- The jev arm is parked as a player for this program; run scripted and random for mechanics (SKL-27).

## 5. Records, gates, pins and epochs

Read [references/records-gates-pins.md](references/records-gates-pins.md) before cutting a pin or reporting a gate exit (design choice).

- Each batch writes one `"scrapkeep-run/1"` record in its own directory, claimed through `artifacts/local/runs/<run-id>/run-owner.json` with exclusive create (design choice).
- The gate exits 0 pass, 1 differs or red, 2 usage, 3 inconclusive, 4 instrument invalid (design choice). A not-like-for-like exit 2 comes before any record validation, so it validates nothing (SKL-36).
- Report a kinematic exit 1 as "behaviour differs from the pin", never as "worse" (SKL-11).
- A pin for a build outside the harness worktree needs `--subject-commit` and `--subject-path` (SKL-20).
- The `dirty` flag covers declared Node source paths only; record the sketch's own state separately (SKL-21).
- After a state-rule change, re-cut the scripted pins; scripted records carry no instrument identity (SKL-22).
- A new question set or resolved model is a new epoch, invalid until controls and the blind corpus re-pass (SKL-28).

## 6. Port the lab to a stage

Follow [references/port-a-stage.md](references/port-a-stage.md). Copy `sketches/ball-lab/src/jev/jev_io.gd` byte for byte with a drift test (SKL-06), rebuild the stage-specific state, scenarios and telemetry wiring, add one `STAGES` entry, and run the stage with `--sketch` (design choice). Settle the threat rule (SKL-15) and whether a trial ends at death (SKL-32) before the first batch. Work on a lab branch cut from the stage's proto head and confirm the proto head is unchanged before and after (design choice).

## 7. Evidence rules

- Nothing on the gate path calls Jev, every live batch has a call cap, and `--dry-run` comes before any live probe (SKL-24).
- Launch batches from your own frozen worktree, never the coordinator worktree (SKL-23).
- Re-run one kinematic batch at the clean head before citing dirty-tree batches (SKL-13).
- Retained evidence is copied at admission after a secret and home-path scan (SKL-25).
- A packet for anyone who writes question text forbids the blind corpus and TRACKING (SKL-26).
- Label automated play "automated; not a feel verdict". Only Andrew's play settles feel (design choice).

## 8. Lessons and updates

[references/lessons.md](references/lessons.md) holds SKL-01 onward, each with status (`established`, `provisional` or `retracted`), evidence and `Overturned by`, the RML origin map and the changelog. When a result changes, update the owning file in the same commit (the table below is a design choice):

| Change | Update | Reviewer |
| --- | --- | --- |
| New scenario | the scenarios reference if the procedure, dummies, test counts or seeds change; §4 only for a new rule; pins untouched unless an existing scenario's trace changes | `scrapkeep-reviewer-medium` |
| New mechanic in a stage | §4 and the scenarios reference; a new epoch per §5 if the model's options change | `scrapkeep-reviewer-medium`; `scrapkeep-reviewer` if the epoch changes |
| New stage | the port reference gains a row; §1 gains its paths | `scrapkeep-reviewer-medium` |
| Protocol change | the protocol reference, fixtures and both validators | `scrapkeep-reviewer` |
| Question set, instrument or model change | §5 epoch entry | `scrapkeep-reviewer`, blind to the question text |
| New result that overturns a lesson | mark it `retracted`, fill `Overturned by`, edit the citing rule line | `scrapkeep-reviewer` |
| New lesson | append as `provisional` with evidence | `scrapkeep-reviewer-medium` |

Add a changelog row for each change, using one of the change types in the table above (design choice). Run `npm run check:skills` before handing a skill edit to the coordinator.

## Host adapter

- Claude Code: `/scrapkeep-lab`. A project thread runs its lab card itself (ruling by: one thread, one writer). In a local coordinator session, cards that run Godot or other real processes go to `scrapkeep-writer`, not `scrapkeep-writer-low` (EV-0502; design choice).
- Codex: `$scrapkeep-lab`, with the configured Astra roles.
- Both apps read this same body. Report the actual model and `CLAUDE_EFFORT` or its absence.
