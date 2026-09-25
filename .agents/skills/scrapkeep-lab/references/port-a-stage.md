# Port the lab to a stage

A stage lab runs a light-play-lane sketch through the same harness, protocol and gate as ball-lab. The protocol layer copies unchanged; the state, scenarios and telemetry are rebuilt for the stage's mechanics. Cable Bench (JL-26) and Spillway Drop (JL-27) are the worked examples.

## Stages ported so far

| Stage | Lab branch and proto base | Node side | Threat rule | Notes |
| --- | --- | --- | --- | --- |
| Cable Bench | lab/cable-bench from proto/cable-bench at 29dcbcf | `STAGES` entry and `scripts/lab/metrics/cable-bench.mjs`, merged at 42fd4ce | Stage-threat-rule 2; a trial ends at death | `forge-charge` and `stage-run` 0 of 80 under both threat rules; contact damage and attack choice suspected (inference, EV-0553) |
| Spillway Drop | lab/spillway-drop from proto/spillway-drop at af89c89 | reuses Cable Bench's launcher and harness hook | Stage-threat-rule 2; a trial ends at death, a new epoch (EV-0555) | A1 and A2 passed review, then the end-at-death ruling sent it to JL-27-A3, in progress at EV-0556; needs its own geometry helper; deaths dominate every arm (EV-0550) |

Add a row when a stage is ported.

## Procedure

1. **Settle the threat rule first.** Read the stage's foe code and answer: can a foe die or be freed, and does a knocked foe keep chasing? Apply stage-threat-rule 2 (EV-0550) unless the coordinator rules otherwise, and record the rule as the stage's instrument epoch (SKL-15).
2. **Decide whether a trial ends at death, and what leaves the state, before the first batch.** A trial that keeps running after the ball dies keeps producing snapshots and offers, and every per-snapshot measure pools them. What leaves the state follows the threat ruling (EV-0550). Cable Bench records a death as the end of the trial (`artifacts/jev-lab-2026-09-25/reviews/JL-26.md:40`), and a Spillway Drop trial now ends at death too, as a new epoch (EV-0555). Record the choice as part of the stage's epoch (SKL-32), and ask the coordinator for a ruling when the stage's death handling is unclear. Make the executor act on the threat the state reports, so a state rule is not undone by the executor picking its own target (SKL-31).
3. **Branch.** Cut the lab branch from the stage's proto head in its own worktree. Record the proto head before and after; the proto branch must not move (EV-0550, EV-0553). The lab branch is never merged back into proto.
4. **Copy the protocol layer byte for byte.** Copy `sketches/ball-lab/src/jev/jev_io.gd` and the fixtures unchanged, and add a byte-drift test against ball-lab's copy (SKL-06). A stage token in that file is a defect.
5. **Rebuild the stage-specific files** under `sketches/<stage>/src/jev/`:
   - `sketches/<stage>/src/jev/jev_state.gd`: exported state from the stage's own nodes, with the threat rule from step 1 and offer conditions based on reachable geometry (SKL-18).
   - `sketches/<stage>/src/jev/scenarios.gd`: spawns, objectives, initial limits labelled as not calibrated, and seeded jitter for choice scenarios (SKL-16).
   - telemetry wiring onto the stage's own signals (Cable Bench uses `shockwave` and `struck`; Spillway Drop uses `enemy_struck`).
   - a geometry helper, `sketches/<stage>/src/jev/geo.gd`, when the stage has no ball-lab-style layout file (Spillway Drop has one).
   - `sketches/<stage>/src/jev/jev_run.gd`, keeping ball-lab's end-tick rule and intent timing.
6. **Seeds.** Add `seed_override := -1` to the stage so -1 keeps the hand-picked seeds and a batch seed overrides them. This is the only change to an existing gameplay file (`artifacts/jev-lab-2026-09-25/reviews/JL-26.md:55-56`). Seed 0 behaves as the default (`artifacts/jev-lab-2026-09-25/reviews/JL-26.md:44`).
7. **Node side.** Add one entry to `STAGES` in `scripts/lab/metrics/index.mjs` with a stage metrics file, and run the stage through `node scripts/lab/godot-launch.mjs <scenario> --sketch <path-to-sketch>`. `stageFor()` in `scripts/lab/godot-launch.mjs` keys on the sketch directory's name. Do not build a parallel launcher or change the harness; the `registry` and `measure` hook is already there (`artifacts/jev-lab-2026-09-25/reviews/JL-26.md:97-100`).
8. **Batches.** Launch from the writer's own frozen worktree (SKL-23). Run both arms in both modes, 20 trials each, with seeds that no later comparison has pre-registered (SKL-29). Repeat once to check determinism per mode (SKL-08, SKL-09), and report the multi-option share (SKL-30).
9. **Provenance.** The run record hashes only the Node repository; the sketch's head and dirty flag are stamped once at launch (SKL-21). Keep the lab branch's own diff and check logs as receipts, because `check:scope` runs on the Node diff only (`artifacts/jev-lab-2026-09-25/reviews/JL-26.md:48`).
10. **Findings.** Label every gameplay finding "automated; not a feel verdict", and label causal readings as inference. The reviewer checks findings against retained evidence, so keep the finding text in a file under the task's evidence directory.

## What to ask the coordinator for

- A threat-rule ruling when the stage's foes do not fit step 1 cleanly, and an end-of-trial ruling when step 2 is unclear.
- The seeds reserved for any pre-registered comparison.
- The lease scope for the Node-side files (`scripts/lab/metrics/index.mjs`, the stage metrics file and any shared launcher change), which another card may also hold.
