# Lab lessons ledger

Each lesson is one rule the lab learned, with the evidence that set it. The skill body and the other references cite these ids; a rule line that cites no id is a design choice.

Status values:

- `established`: two independent sources support it (a run and a review, or two runs), or a recorded coordinator ruling or owner decision sets it.
- `provisional`: one run or one review supports it. Promote it only when a second independent run or review cites it.
- `retracted`: a later result overturned it. Keep the text, fill `Overturned by`, and edit the citing rule line in the same commit.

Evidence names TRACKING events (`EV-nnnn`), retained reviews as `artifacts/jev-lab-2026-09-25/reviews/<card>.md:<line>`, and other files by repository path and line. Every line was opened and checked on 2026-09-25: SKL-01 to SKL-30 at base `0d02138`, and SKL-31, SKL-32 and the revised origin-map rows after merging the coordinator branch at a1f2eda. SKL-33 to SKL-36 and the re-pointed SKL-16 and SKL-31 lines were checked on 2026-09-26 at base 64bd9cf, after JL-21b's merge; SKL-31's promotion and the SKL-33 and SKL-34 line numbers were re-checked after merging the coordinator branch at d450bd8, which contains JL-21b-A3 (82d2a96).

## Lessons

- **SKL-01** · status: established · since: 2026-09-25 · origin: JL-05 protocol, JL-09 Godot port, JL-17 bridge
  Godot and Node talk only through files in one trial directory. Each file has one writer, is written as `.tmp` and renamed, carries the protocol string, and has a closed schema. A new field, event kind or rule is a new protocol string, never an edit to v1.
  Evidence: `tools/jev-player/protocol/PROTOCOL.md:7-11`, `:188`; EV-0513 (a Godot validator built from the document accepts all 73 valid and rejects all 19 invalid fixtures); EV-0542.
  Overturned by: —

- **SKL-02** · status: established · since: 2026-09-25 · origin: JL-17 real-process bridge
  Godot blocks inside `_physics_process` with `OS.delay_msec` until the intent arrives, never with `tree.paused`, and applies it at exactly tick t + k. Keep k < D so the next state's held intent is always the previous answer.
  Evidence: `tools/jev-player/protocol/PROTOCOL.md:104`, `:107`; `artifacts/jev-lab-2026-09-25/reviews/JL-17.md:27` (every intent event at seq × 90 + 26 in both physics modes); EV-0542.
  Overturned by: —

- **SKL-03** · status: established · since: 2026-09-25 · origin: JL-17 bridge, JL-21 repeats
  `trace_hash` covers `events.ndjson` and nothing else, and Godot files hold ticks, never wall time. The hash then stays identical whatever Node's response delays.
  Evidence: `tools/jev-player/protocol/PROTOCOL.md:13`, `:180`; `artifacts/jev-lab-2026-09-25/reviews/JL-17.md:27` (one hash per mode across three responder-delay patterns); EV-0546 (360 of 360 kinematic repeat pairs). The JL-17 evidence alone was narrow, one scenario with forced answers (`artifacts/jev-lab-2026-09-25/reviews/JL-17.md:17`); JL-21 widened it.
  Overturned by: —

- **SKL-04** · status: established · since: 2026-09-25 · origin: JL-09 port, JL-05c fix
  A closed set (event kinds, arms, option ids, gate rules) matches only its own string keys. Prototype names such as `constructor` and arrays such as `["ram_target"]` are errors, never members, and a validator never throws on them. Plain `Object.hasOwn` still accepts the one-element array.
  Evidence: `tools/jev-player/protocol/PROTOCOL.md:12`; EV-0513 (Node accepted `constructor` and `["takeoff"]` and threw on `toString`); EV-0524 (base Node accepted 5 and threw on 4 of 27 new fixtures; fixed with own-string-key guards).
  Overturned by: —

- **SKL-05** · status: provisional · since: 2026-09-25 · origin: JL-09 Godot port
  Build a second validator from the text of `tools/jev-player/protocol/PROTOCOL.md`, not from `tools/jev-player/protocol/protocol.mjs`. Re-deriving from the document found three Node defects and three spec gaps that code review had not.
  Evidence: EV-0513.
  Overturned by: —

- **SKL-06** · status: established · since: 2026-09-25 · origin: JL-09 fixtures, JL-26 and JL-27 ports
  Keep one canonical fixture set and byte-copy it to each Godot side with a drift test. A stage port copies `sketches/ball-lab/src/jev/jev_io.gd` byte for byte and adds a drift test for it.
  Evidence: `tools/jev-player/protocol/PROTOCOL.md:186`; EV-0513 (drift test fails on a one-byte change or an extra file); `artifacts/jev-lab-2026-09-25/reviews/JL-26.md:63-67`; EV-0553 (JL-27-A2 adds a byte-drift test for its copy).
  Overturned by: —

- **SKL-07** · status: established · since: 2026-09-25 · origin: JL-05c review, JL-18b fix
  Trial outcomes follow a total order: watchdog `stall` first, then a Node-side rejection (`invalid`), then the final file, else `crash`. A Node rejection outranks a later engine crash.
  Evidence: `tools/jev-player/protocol/PROTOCOL.md:129`; `artifacts/jev-lab-2026-09-25/reviews/JL-05c.md:20`; EV-0524.
  Overturned by: —

- **SKL-08** · status: established · since: 2026-09-25 · origin: JL-21 ball-lab repeats, JL-26 Cable Bench repeats
  Kinematic mode reproduces exactly: the same scenario, seed and D/k give the same `trace_hash`.
  Evidence: EV-0546 (ball-lab, 360 of 360 repeat pairs); `artifacts/jev-lab-2026-09-25/reviews/JL-21.md:15`; EV-0550 (Cable Bench, 120 of 120).
  Overturned by: —

- **SKL-09** · status: established · since: 2026-09-25 · origin: JL-21 repeats, JL-26-A2 repeats
  Rigid (Jolt) mode does not reproduce exactly, and a divergence can flip the outcome. On ball-lab about 1 repeat pair in 20 diverges, and one pair went `timeout` against `success` on the same seed. On Cable Bench A1 saw 120 of 120 identical pairs, then A2 saw 119 and 118 of 120, so one clean repeat does not prove a rigid scenario deterministic.
  Evidence: `artifacts/jev-lab-2026-09-25/reviews/JL-21.md:15`; EV-0546; EV-0550; EV-0553.
  Overturned by: —

- **SKL-10** · status: provisional · since: 2026-09-25 · origin: JL-25 gate qualification; open until JL-28
  The gate splits by physics mode. Kinematic records are held to exact trace and replay equality. Rigid records need n ≥ 20 on each side and use a nondeterminism floor of 0.05, but the rigid gate compares no rate yet: it checks sample size and reachability only.
  Evidence: `scripts/lab/gate.mjs:40-46`; `artifacts/jev-lab-2026-09-25/reviews/JL-25.md:11` (F2: no batch metric in `RATES`; the rigid pin has 0 of 20 successes, so reachability never fires); EV-0551 (pass line reworded to "no rate compared until JL-28").
  Overturned by: —

- **SKL-11** · status: established · since: 2026-09-25 · origin: JL-25 gate qualification
  A kinematic gate exit 1 means "behaviour differs from the pin", not "worse". An injected −10% `drive_accel` run succeeded 14 of 20, the same as the pin, and still exited 1 because every trace hash differed. Whether a change is worse is JL-28's question.
  Evidence: `artifacts/jev-lab-2026-09-25/reviews/JL-25.md:9`; EV-0550.
  Overturned by: —

- **SKL-12** · status: provisional · since: 2026-09-25 · origin: JL-21 determinism test
  Prove a hash oracle is sensitive before trusting it: change k (54 against 26) or one answer and confirm the hash changes while the events before the change stay byte-identical.
  Evidence: `artifacts/jev-lab-2026-09-25/reviews/JL-21.md:34`; EV-0546.
  Overturned by: —

- **SKL-13** · status: provisional · since: 2026-09-25 · origin: JL-21 admission
  Batches run on a dirty tree are not evidence for the merged head until one kinematic batch re-run at the clean head matches their trace hashes trial for trial. That re-run is minutes, not the full batch set.
  Evidence: `artifacts/jev-lab-2026-09-25/reviews/JL-21.md:21` (F5); EV-0546 (scripted `dummy-knock` kinematic re-run at 93799e9 matched 20 of 20). Related: EV-0536 (a live run on a dirty tree kept with `tree-at-run.txt`).
  Overturned by: —

- **SKL-14** · status: established · since: 2026-09-25 · origin: JL-21 calibration
  A scripted rule ladder with no memory and no "threat neutralised" condition can score below the random floor. Ball-lab's ladder stomps any dummy within 12 m, dummies chase without end, and scripted `run-to-pad` went 0 of 20. Fix such a floor in the shared state every arm reads, not in the ladder.
  Evidence: `artifacts/jev-lab-2026-09-25/reviews/JL-21.md:9-13` (F1, mechanism traced in `scripts/lab/arms.mjs` and `sketches/ball-lab/src/enemy.gd`); EV-0546.
  Overturned by: —

- **SKL-15** · status: established · since: 2026-09-25 · origin: coordinator ruling "stage-threat-rule 2"
  The rule for when a threat leaves the exported state is per stage and is an instrument epoch. A threat leaves only when the game has taken it out of play. On ball-lab a knocked dummy counts as out of play (dummies cannot die; JL-21b applies this). On Cable Bench and Spillway Drop a knocked foe keeps its health and keeps chasing, so it stays a threat until it is dead or freed. This is a coordinator ruling that changed the rule for those stages; the JL-26 and JL-27 writers had applied the JL-21b rule as instructed. Under rule 2, `forge-charge` and `stage-run` stayed at 0 of 80, so the knocked-foe confound was not what kept them at zero.
  Evidence: EV-0550 (ruling); `artifacts/jev-lab-2026-09-25/reviews/JL-26.md:18-23` (N1, the confound); EV-0553 (JL-26-A2 and JL-27-A2 re-run under rule 2).
  Overturned by: —

- **SKL-16** · status: provisional · since: 2026-09-25 · origin: JL-21 calibration
  A choice scenario jitters the spawn from the trial seed, and trial i gets the same point on every arm. Without it a deterministic arm's 20 trials are one trial repeated.
  Evidence: `sketches/ball-lab/src/jev/scenarios.gd:10-13` (lines 13-16 before JL-21b's merge moved the header); `artifacts/jev-lab-2026-09-25/reviews/JL-21.md:41`.
  Overturned by: —

- **SKL-17** · status: provisional · since: 2026-09-25 · origin: JL-21 calibration
  A time limit derived as max(initial, 2 × scripted p90) is valid only when the scripted p90 is uncensored. Check the input distribution before trusting the rule; JL-21 kept every limit because the ladder defect censored p90 on all four choice scenarios.
  Evidence: `artifacts/jev-lab-2026-09-25/reviews/JL-21.md:23` (F6); EV-0546 (recorded inconclusive, limits provisional).
  Overturned by: —

- **SKL-18** · status: established · since: 2026-09-25 · origin: JL-21 review, JL-26 port
  A precondition that checks present state for a target reachable only by future action is a category error. `hit_kicker` was gated on the ball's current speed against the lip speed, so it almost never survived the gate and `bench-climb` stayed 0 of 20 for every arm and mode. Gate on reachable geometry instead.
  Evidence: `artifacts/jev-lab-2026-09-25/reviews/JL-21.md:19` (F4); `scripts/lab/gate.mjs:51-55` (`bench-climb` exempt from `unreachable_scenarios`); `artifacts/jev-lab-2026-09-25/reviews/JL-26.md:72` (the Cable Bench port offers `hit_kicker` with no `requires_speed_ms`).
  Overturned by: —

- **SKL-19** · status: provisional · since: 2026-09-25 · origin: JL-21 lip probe
  Derive physics constants from physics-only probes (spawn before the lip, launch at set speeds, record lip speed), separate from any arm trial. Otherwise a tuning result reads as a policy result.
  Evidence: `artifacts/jev-lab-2026-09-25/reviews/JL-21.md:40`; EV-0546 (`requires_speed_ms` 16.1 to 17.2 m/s from the physics-only sweep).
  Overturned by: —

- **SKL-20** · status: established · since: 2026-09-25 · origin: JL-25 review, admission fix
  A pin that stands for a build outside the harness worktree needs its own content identity. Cut it with `--subject-commit` and `--subject-path` so its `artifacts/jev-lab-2026-09-25/pins/<name>/pin.json` names the commit, path and tree hash.
  Evidence: `artifacts/jev-lab-2026-09-25/reviews/JL-25.md:13` (F3); EV-0551 (`andrew-anchor` gains a `subject` block for dc94b2c, tree `6e6f12bd`).
  Overturned by: —

- **SKL-21** · status: provisional · since: 2026-09-25 · origin: JL-25 and JL-26 reviews
  A record's `dirty` flag and source hashes cover only the declared source paths of the Node repository. An untracked file elsewhere, or a sketch in another repository, is not covered; the sketch's own head and dirty flag are stamped once at launch.
  Evidence: `artifacts/jev-lab-2026-09-25/reviews/JL-25.md:23` (F8); `artifacts/jev-lab-2026-09-25/reviews/JL-26.md:46` (N6).
  Overturned by: —

- **SKL-22** · status: established · since: 2026-09-25 · origin: JL-25 review F6
  Scripted and random runs carry no instrument identity, so a change to the exported state reads as trace divergence (exit 1), not as an instrument change. Re-cut the scripted pins when a state rule changes.
  Evidence: `artifacts/jev-lab-2026-09-25/reviews/JL-25.md:19`; EV-0550 (JL-21b's admission must re-cut the two scripted `dummy-knock` pins); EV-0551.
  Overturned by: —

- **SKL-23** · status: established · since: 2026-09-25 · origin: coordinator correction at JL-26-A2
  Launch batches from the writer's own frozen worktree, never from the coordinator worktree. The coordinator worktree moved during a run when another card merged, and 11 of 12 records were downgraded to inconclusive for changed sources.
  Evidence: EV-0553.
  Overturned by: —

- **SKL-24** · status: established · since: 2026-09-25 · origin: program plan, JL-03 incident
  Nothing on the gate path calls Jev. Every live batch carries a call cap. Before running any script that can call Jev, read its usage and use `--dry-run`; a `--help` passed to a script without argument handling once made 16 unplanned live calls.
  Evidence: `artifacts/jev-lab-2026-09-25/plan.md:203`; EV-0484 (call cap per batch); EV-0493 (incident); EV-0521 (`tools/jev-player/score.mjs` guard added).
  Overturned by: —

- **SKL-25** · status: established · since: 2026-09-25 · origin: evidence retention across JL-14 to JL-27
  Disposable evidence stays under `artifacts/local/`. At admission the coordinator copies retained evidence to `artifacts/jev-lab-2026-09-25/live/<card>/` or `artifacts/jev-lab-2026-09-25/pins/` after a secret and home-path scan. Per-trial directories stay local.
  Evidence: EV-0523; EV-0544 (scan clean); EV-0546 (844 MB of per-trial directories kept local); EV-0553.
  Overturned by: —

- **SKL-26** · status: established · since: 2026-09-25 · origin: coordinator assignment for JL-18
  The packet for anyone who writes question text forbids the blind corpus, its provenance file, `artifacts/jev-lab-2026-09-25/blind-diagnostic.json`, every review that names blind cases, and TRACKING, which names blind cases in its rows.
  Evidence: EV-0525.
  Overturned by: —

- **SKL-27** · status: established · since: 2026-09-25 · origin: JL-18c pre-registered run, results review, owner decision
  Jev-as-player is parked for this program; the scripted and random arms carry the mechanics metrics. The per-option yes/no (preference Noul) method cleared the 0.2 margin in 0 of 6 orders: `take_cache` was top-rated in all 18 free-cache calls, but its lead was 0.10 to 0.14. The goal-framing effect and the absence of position bias under Nouls are leads, not results.
  Evidence: EV-0527 (decision rule); EV-0540; EV-0541; `artifacts/jev-lab-2026-09-25/experiments/jl18c/RESULTS.md:14`, `:18`.
  Overturned by: —

- **SKL-28** · status: established · since: 2026-09-25 · origin: program plan, q1 and q2 epochs
  A new question set or resolved model starts an instrument epoch that stays invalid until its live controls and the blind corpus both re-pass. A live jev batch runs the controls first and exits 6 before any record or Godot process when they fail.
  Evidence: `artifacts/jev-lab-2026-09-25/plan.md:67-70`; `scripts/lab/harness.mjs:33-35`; EV-0526 (q2 epoch invalid); EV-0542 (exit 6 after 12 preflight calls).
  Overturned by: —

- **SKL-29** · status: established · since: 2026-09-25 · origin: JL-26 review, JL-28 revision 3
  Exploratory batches must not use a later comparison's pre-registered trial seeds. The Cable Bench batches used seeds 1000 to 1019, JL-28's planned seeds, so JL-28 moved to 2000 to 2019.
  Evidence: `artifacts/jev-lab-2026-09-25/reviews/JL-26.md:25` (N2); EV-0550.
  Overturned by: —

- **SKL-30** · status: established · since: 2026-09-25 · origin: JL-17 review, JL-21 calibration
  A scenario separates arms only if its snapshots offer two or more options. On `downhill-run` every snapshot offered only `push_objective`, so every answer was forced and the arms produced identical traces. Report the multi-option share with every arm comparison.
  Evidence: `artifacts/jev-lab-2026-09-25/reviews/JL-17.md:13` (N3); EV-0542; EV-0546 (JL-21 raised the share to 0.71 to 1.00 on four scenarios).
  Overturned by: —

- **SKL-31** · status: established · since: 2026-09-25 · origin: JL-21b-A1 handoff; JL-21b Fable review
  The executor must act on the threat the exported state reports. A state rule that hides a threat is incomplete while the executor picks its own target. Before JL-21b-A2, ball-lab's `_goal()` passed no target for stomp or ram, so the executor stomped the nearest dummy, knocked or not, and scripted trials still averaged 36 to 64 stomp stretches after the state fix.
  Evidence: EV-0556 (the finding and the JL-21b-A2 lease widening; before A2, `_goal()` returned a target only for `push_objective`). The fix is merged (EV-0564): `sketches/ball-lab/src/jev/jev_run.gd:300-313` now targets the threat the state reported. The independent Fable review confirmed the fix, red then green, with no path to a knocked target at apply time (`artifacts/jev-lab-2026-09-25/reviews/JL-21b.md:29`); scripted `dummy-knock` kinematic stomp stretches fell from 63.6 to 3.3 (EV-0563); A3 added a mutation-red test for the fallback branch (EV-0566).
  Overturned by: —

- **SKL-32** · status: provisional · since: 2026-09-25 · origin: JL-27 review, coordinator ruling
  Decide per stage whether a trial ends at death before the first batch, and record the choice as the stage's instrument epoch. A Spillway Drop trial kept running after death, so roughly half to two thirds of rigid snapshots came after it and every per-snapshot measure pooled them; the success predicate was unaffected. The ruling ends a Spillway trial at death, as Cable Bench's does.
  Evidence: `artifacts/jev-lab-2026-09-25/reviews/JL-27.md:17` (F1); EV-0555 (ruling, new epoch, JL-27-A3).
  Overturned by: —

- **SKL-33** · status: provisional · since: 2026-09-26 · origin: JL-30 DoD 3 exercise 2 (new ball-lab scenario)
  Every ball-lab scenario gets the same six dummies, whatever it is. No per-scenario dummy hook exists, so a scenario that needs a different set must add one, defaulting to all six so existing traces do not change.
  Evidence: `sketches/ball-lab/src/field.gd:84-87` (the six spots); `sketches/ball-lab/src/lab.gd:51-56` (one dummy spawned per spot); `sketches/ball-lab/src/jev/scenarios.gd:159-167` (`place()` moves only the ball); `artifacts/jev-lab-2026-09-25/skills/exercises/2-lab-scenario.md:22`, `:86` (the exercise had to add a hook).
  Overturned by: —

- **SKL-34** · status: provisional · since: 2026-09-26 · origin: JL-30 DoD 3 exercise 2
  The ball-lab state test hardcodes the scenario count, the jittered count and a per-id predicate table, so a new scenario id fails it until all three are edited.
  Evidence: `sketches/ball-lab/tests/jev_state_test.gd:559` (`ids.size() == 7`), `:561-569` (`cases`), `:608` (`jittered == 4`); `artifacts/jev-lab-2026-09-25/skills/exercises/2-lab-scenario.md:87`.
  Overturned by: —

- **SKL-35** · status: provisional · since: 2026-09-26 · origin: JL-30 DoD 3 exercise 2
  The fake Godot's `soak` stream cycles through every other scripted scenario, so adding a fake scenario changes `soak`. A fake entry is needed only when Node tests or `scrapkeep lab run` drive the scenario; the real launcher needs no Node-side registration.
  Evidence: `scripts/lab/fake-godot.mjs:143-148` (the cycle), `:190-193` (an unknown id throws); `scripts/lab/godot-launch.mjs:103` (the id passes straight to Godot); `artifacts/jev-lab-2026-09-25/skills/exercises/2-lab-scenario.md:27`, `:88` (real batches ran with no fake entry).
  Overturned by: —

- **SKL-36** · status: provisional · since: 2026-09-26 · origin: JL-30 DoD 3 exercise 2 and its grading
  The gate's like-for-like refusal exits 2 before either record is validated, so a batch gated against a mismatched pin gets no validation at all.
  Evidence: `scripts/lab/gate.mjs:604-627` (type and batch-mismatch checks throw `UsageError` before `assessRun()`); `artifacts/jev-lab-2026-09-25/skills/exercises/2-lab-scenario.md:43-45` (exit 2 on a scenario mismatch).
  Overturned by: —

- **SKL-37** · status: established · since: 2026-10-24 · origin: coordinator ruling on the PC machine changes of 2026-10-24
  Machine notes for GPU evidence on Andrew's PC. (a) 4080 frame-time or GPU-timing captures taken before 2026-10-24 ran with the live wallpaper on the GPU (about 1.3 GB VRAM and its load); label them "wallpaper running" when comparing with later captures, and do not edit the old capture files. Since then the wallpaper pauses while any `blender` or `godot` process runs (`omarchy-live-bg status`). (b) `godot --headless` uses a dummy renderer and cannot produce frame times. Run GPU-rendered Godot off screen with `gamescope --backend headless --prefer-vk-device 10de:2704 -r 1000 --immediate-flips -W 3840 -H 2160 -w 3840 -h 2160 -- godot --path <project> --gpu-index 0`; without `-r 1000 --immediate-flips` it locks at 60 fps and reads as GPU-idle. (c) Blender Cycles runs on OptiX on both GPUs through Andrew's prefs, but a headless script started with `--factory-startup` stays on CPU unless it sets devices itself: `cy = bpy.context.preferences.addons["cycles"].preferences; cy.compute_device_type = "OPTIX"; cy.refresh_devices(); for d in cy.devices: d.use = d.type == "OPTIX"`, then `scene.cycles.device = "GPU"`. Older .blend files keep their saved device. (d) A dual-GPU render must fit the 3060's 12 GB and competes with model jobs routed to the 3060, so use the 4080 alone for big scenes or while a model job runs. The power caps (4080 at 280 W, 3060 at 140 W) cost about 1% in a worst-case 4K Forward+ scene, so captures at the cap are representative.
  Evidence: measurements by the PC bottleneck session, 2026-10-24 (wallpaper VRAM 2462 to 1166 MiB; Cycles both GPUs 26.3 s against 32.5 s on the 4080 alone; 4K Forward+ 103.6 against 104.6 fps), dotfiles commit a463c67; held outside this repository.
  Overturned by: —

## External caveat

Token figures on the board that came from the delegate ledger before EV-0498 are inflated: the ledger summed usage over repeated transcript records instead of deduplicating by request id. The fix lives outside this repository (EV-0498). Treat those figures as upper bounds.

## RML origin map

Each row maps one lesson in the `reactive-model-loop` ledger to where it came from in this repository. The ids are those of the merged ledger (the JL-30 portable-skill writer at 2b77c41, merged into the coordinator branch as a1f2eda), which has RML-01 to RML-46; JL-30 writer d, attempt A1, appended RML-47 to RML-55 from the DoD 3 portable exercise, and their rows were opened and confirmed at base 64bd9cf; attempt A2 appended RML-56 to RML-62 from the blind exercise 1b and confirmed those rows after merging the coordinator branch at d450bd8, which contains the JL-21b-A3 merge 82d2a96. If that ledger renumbers or revises an id, this table changes in the same commit. Every citation below was opened and confirmed on this branch after that merge; the rows for the ids its review revised (RML-02, 05, 22, 27, 28, 41 and 43) were re-read against the revised lesson text. A citation marked "unconfirmed" was named by the inventory but not found at the stated place.

| RML id | SKL id or citation |
| --- | --- |
| RML-01 | Public prior art, unaudited: `artifacts/jev-lab-2026-09-25/skills/prior-art-jev-games.md:40` (every surveyed project splits intent from execution) |
| RML-02 | SKL-18; `artifacts/jev-lab-2026-09-25/reviews/JL-21.md:19`; the lab/cable-bench header in its jev_state.gd, lines 22-25 |
| RML-03 | SKL-24; `artifacts/jev-lab-2026-09-25/plan.md:203`; `artifacts/jev-lab-2026-09-25/reviews/JL-19.md:40`; `artifacts/jev-lab-2026-09-25/reviews/JL-20.md:36` |
| RML-04 | `tools/jev-player/decide.mjs:25-26`; `artifacts/jev-lab-2026-09-25/reviews/JL-03.md:15-17` (N2, N3); `tools/jev-player/protocol/PROTOCOL.md:154`, `:158` |
| RML-05 | `artifacts/jev-lab-2026-09-25/reviews/JL-15.md:22` (N5); `artifacts/jev-lab-2026-09-25/reviews/JL-18b.md:23`; EV-0521. Public survey, unaudited: `artifacts/jev-lab-2026-09-25/skills/prior-art-jev-games.md:45` (three projects named) and `:64` ("four of six"), the disagreement the lesson notes |
| RML-06 | `tools/jev-player/decide.mjs:21-24` (the floor constant is at 24); `artifacts/jev-lab-2026-09-25/reviews/JL-03.md:33`; `artifacts/jev-lab-2026-09-25/audit/README.md:100` (A6), `:110` (A13). The inventory's `artifacts/jev-lab-2026-09-25/reviews/JL-15.md:22` is unconfirmed: that line is N5, about the model alias |
| RML-07 | `artifacts/jev-lab-2026-09-25/audit/README.md:13-14` (findings 1 and 2); `artifacts/jev-lab-2026-09-25/plan.md:47` (A1); EV-0485 |
| RML-08 | `artifacts/jev-lab-2026-09-25/experiments/jl18c/RESULTS.md:32`, `:40`; EV-0540 |
| RML-09 | Public prior art, unaudited: `artifacts/jev-lab-2026-09-25/skills/prior-art-jev-games.md:33` (the "Limits of Jev 1.13" quote) |
| RML-10 | `artifacts/jev-lab-2026-09-25/audit/README.md:15` (finding 3), `:108` (A11); EV-0485 |
| RML-11 | `artifacts/jev-lab-2026-09-25/reviews/JL-15.md:61` (question 7, no cache read); `artifacts/jev-lab-2026-09-25/reviews/JL-19.md:36` (finding 4); EV-0534 |
| RML-12 | `artifacts/jev-lab-2026-09-25/reviews/JL-18.md:56`; `artifacts/jev-lab-2026-09-25/experiments/jl18c/RESULTS.md:43`; `artifacts/jev-lab-2026-09-25/experiments/jl18c/PREREGISTRATION.md:46`, `:120` |
| RML-13 | `artifacts/jev-lab-2026-09-25/reviews/JL-18.md:18` (N3); `artifacts/jev-lab-2026-09-25/experiments/jl18c/PREREGISTRATION.md:120` |
| RML-14 | `artifacts/jev-lab-2026-09-25/reviews/JL-18.md:16` (N2); `tools/jev-player/preflight.mjs:214` |
| RML-15 | `artifacts/jev-lab-2026-09-25/reviews/JL-15.md:14` (N1); `artifacts/jev-lab-2026-09-25/reviews/JL-18.md:14` (N1); EV-0526 |
| RML-16 | `artifacts/jev-lab-2026-09-25/audit/README.md:111` (A14); `artifacts/jev-lab-2026-09-25/reviews/JL-03.md:34`; `artifacts/jev-lab-2026-09-25/reviews/JL-15.md:51`; `tools/jev-player/preflight.mjs:117-121` |
| RML-17 | SKL-27; `artifacts/jev-lab-2026-09-25/experiments/jl18c/RESULTS.md:14`, `:18`, `:157`; EV-0540; EV-0541 |
| RML-18 | `artifacts/jev-lab-2026-09-25/plan.md:82-87`; `artifacts/jev-lab-2026-09-25/reviews/JL-04-A1.md`, `artifacts/jev-lab-2026-09-25/reviews/JL-04-A2.md`, `artifacts/jev-lab-2026-09-25/reviews/JL-04-A3.md`; EV-0490; EV-0496 |
| RML-19 | SKL-26 in part; `artifacts/jev-lab-2026-09-25/reviews/JL-19.md:21` (finding 2); EV-0532 (ruling); EV-0525 |
| RML-20 | `artifacts/jev-lab-2026-09-25/reviews/JL-04-A3.md:11` (N1), `:17` (N2); `artifacts/jev-lab-2026-09-25/reviews/JL-04-A2.md:11` (F1); EV-0496 |
| RML-21 | `artifacts/jev-lab-2026-09-25/audit/README.md:16` (finding 4), `:78-89`; EV-0532; EV-0549 |
| RML-22 | SKL-14; SKL-15 for the caveat that hiding after a hit is right only where the mechanic removes the threat. Public reports, unaudited: `artifacts/jev-lab-2026-09-25/skills/prior-art-jev-games.md:46` (one project tied a hand-coded heuristic); the article claim that a scripted bot would win is not in that survey and is unconfirmed here |
| RML-23 | SKL-16 |
| RML-24 | `artifacts/jev-lab-2026-09-25/experiments/jl18c/PREREGISTRATION.md:170`, `:202-210`; `artifacts/jev-lab-2026-09-25/experiments/jl18c/RESULTS.md:46-56`; EV-0538; EV-0540 |
| RML-25 | `artifacts/jev-lab-2026-09-25/experiments/jl18c/PREREGISTRATION.md:154`; `artifacts/jev-lab-2026-09-25/experiments/jl18c/RESULTS.md:42-44` |
| RML-26 | EV-0485; EV-0492; `artifacts/jev-lab-2026-09-25/audit/README.md:118` |
| RML-27 | `artifacts/jev-lab-2026-09-25/audit/README.md:99` (A5); EV-0501; EV-0545 |
| RML-28 | `artifacts/jev-lab-2026-09-25/plan.md:112`; `artifacts/jev-lab-2026-09-25/reviews/JL-18b.md:12` (N2) |
| RML-29 | `artifacts/jev-lab-2026-09-25/reviews/JL-19.md:28` (finding 3); EV-0532; EV-0534 |
| RML-30 | `artifacts/jev-lab-2026-09-25/reviews/JL-19.md:63` (the inventory's `:215-274` are source lines quoted inside that review) |
| RML-31 | `artifacts/jev-lab-2026-09-25/reviews/JL-19.md:13` (finding 1); `artifacts/jev-lab-2026-09-25/reviews/JL-20.md:42` (finding 5); EV-0484 |
| RML-32 | `artifacts/jev-lab-2026-09-25/reviews/JL-15.md:24` (N6); `artifacts/jev-lab-2026-09-25/reviews/JL-18b.md:23` |
| RML-33 | SKL-04 |
| RML-34 | SKL-05; SKL-06; EV-0517 |
| RML-35 | SKL-24; EV-0493 |
| RML-36 | `artifacts/jev-lab-2026-09-25/reviews/JL-15.md:18` (N3); EV-0520; EV-0521; EV-0523 |
| RML-37 | `artifacts/jev-lab-2026-09-25/reviews/JL-15.md:18` (N3); EV-0520 |
| RML-38 | EV-0498 (the fix lives outside this repository); see the external caveat above |
| RML-39 | `artifacts/jev-lab-2026-09-25/audit/README.md:52`, `:74-75`, `:112` (A15); EV-0485. The inventory's reference to the JL-15 review is unconfirmed: that review states no latency figure |
| RML-40 | Public prior art, unaudited: `artifacts/jev-lab-2026-09-25/skills/prior-art-jev-games.md:18` (a persisted dollar cap) |
| RML-41 | `artifacts/jev-lab-2026-09-25/reviews/JL-21.md:21` (F5, batches on a dirty tree); EV-0536 (`tree-at-run.txt` retained beside the head) |
| RML-42 | `artifacts/jev-lab-2026-09-25/audit/README.md:13-17`; EV-0485; EV-0491; EV-0538 |
| RML-43 | SKL-02; SKL-08; SKL-09; `tools/jev-player/protocol/PROTOCOL.md:98-107`, `:178-182`; EV-0546 (360 of 360 kinematic repeat pairs; rigid about 1 in 20) |
| RML-44 | SKL-15; EV-0550; `artifacts/jev-lab-2026-09-25/reviews/JL-26.md:18-23` |
| RML-45 | SKL-12; `artifacts/jev-lab-2026-09-25/reviews/JL-21.md:34` |
| RML-46 | SKL-13; EV-0546 |
| RML-47 | `artifacts/jev-lab-2026-09-25/skills/exercises/1-portable-drone.md:117-118` (identity from the decider file's hash; the key throws on null), `:139` (gap 1) |
| RML-48 | `artifacts/jev-lab-2026-09-25/skills/exercises/1-portable-drone.md:66-69` (margin 0.0584, SD 0.0078, the floor decided), `:140` (gap 2) |
| RML-49 | `artifacts/jev-lab-2026-09-25/skills/exercises/1-portable-drone.md:76-77` (the wording swap failed only on fallbacks), `:81-83` (15 of 240 fallbacks), `:141` (gap 3, about 0.79 computed) |
| RML-50 | `artifacts/jev-lab-2026-09-25/skills/exercises/1-portable-drone.md:88`, `:90` (state and risk size had no effect), `:98` (the decider never reads label text), `:142` (gap 4); `artifacts/jev-lab-2026-09-25/skills/exercises/1b-portable-robot-blind.md:10` (planted trigger word missed, swap shift 0.007), `:21` (the sealed key's trigger word) |
| RML-51 | `artifacts/jev-lab-2026-09-25/skills/exercises/1-portable-drone.md:94-97` (deterministic per process; one warm-up call moved the hash), `:143` (gap 5) |
| RML-52 | `artifacts/jev-lab-2026-09-25/skills/exercises/1-portable-drone.md:96` (the perturbation), `:144` (gap 6) |
| RML-53 | `artifacts/jev-lab-2026-09-25/skills/exercises/1-portable-drone.md:72` (never chosen, probability 0.128 to 0.310), `:145` (gap 7) |
| RML-54 | `artifacts/jev-lab-2026-09-25/skills/exercises/1-portable-drone.md:83-84` (15 of 15 fallbacks chose the first option; storm first in two orders), `:129` |
| RML-55 | `artifacts/jev-lab-2026-09-25/skills/exercises/1-portable-drone.md:86` (r = 0.068 over 225 model answers) |
| RML-56 | `artifacts/jev-lab-2026-09-25/skills/exercises/1b-portable-robot-blind.md:11` (symptom found, cause misread), `:22` (the sealed key's 4% misreport), `:90` (2 of 210 non-argmax choices read as sampling) |
| RML-57 | `artifacts/jev-lab-2026-09-25/skills/exercises/1b-portable-robot-blind.md:74` (210 of 210 `source: "model"`), `:94` (self-set field; sub-millisecond latency), `:139` (gap 7) |
| RML-58 | `artifacts/jev-lab-2026-09-25/skills/exercises/1b-portable-robot-blind.md:41` (cell X), `:63` (X 4 of 6, failing only with the dominant option first), `:141` (gap 9) |
| RML-59 | `artifacts/jev-lab-2026-09-25/skills/exercises/1b-portable-robot-blind.md:49` (one uncounted probe, logged first), `:135` (gap 3) |
| RML-60 | `artifacts/jev-lab-2026-09-25/skills/exercises/1b-portable-robot-blind.md:136` (gap 4, the pinned hash went stale) |
| RML-61 | `artifacts/jev-lab-2026-09-25/skills/exercises/1b-portable-robot-blind.md:43` (the mixed pass rule), `:65` (the 0.10 floor set the noise line), `:137-138` (gaps 5 and 6) |
| RML-62 | `artifacts/jev-lab-2026-09-25/skills/exercises/1-portable-drone.md:146` (gap 8); `artifacts/jev-lab-2026-09-25/skills/exercises/1b-portable-robot-blind.md:48` (no reviewer; parent review asked), `:134` (gap 2) |
| RML-63 | `artifacts/jev-lab-2026-09-25/skills/exercises/1-portable-drone.md:68` (last-position boost); `artifacts/jev-lab-2026-09-25/skills/exercises/1b-portable-robot-blind.md:70` (first position chosen 0 of 60), `:98-99` (code-owned dominance; ordering fixes change the instrument), `:140` (gap 8, no fix named) |

## Changelog

| Date | Change type | Ids touched | Evidence or commit | Reviewer |
| --- | --- | --- | --- | --- |
| 2026-09-25 | New lesson (not overturning) | SKL-01 to SKL-30 | JL-30 skill writer b, attempt A1, base `0d02138` | pending |
| 2026-09-25 | Origin map | RML-01 to RML-43 | `reactive-model-loop` candidate 85d16a5; each citation re-checked against the primary file | pending |
| 2026-09-25 | New lesson (not overturning) | SKL-31, SKL-32 | EV-0555, EV-0556, `artifacts/jev-lab-2026-09-25/reviews/JL-27.md:17`; JL-30 writer b, attempt A2 | pending |
| 2026-09-25 | New lesson (not overturning); closest type for the origin map, which adds no lesson | RML-44 to RML-46 mapped; RML-02, 05, 22, 27, 28, 41 and 43 re-read against the revised ledger, RML-05, 22, 41 and 43 re-pointed; RML-04 and RML-06 line numbers corrected | merged `reactive-model-loop` at a1f2eda; writer b review B1 and N1 | pending |
| 2026-09-25 | New lesson (not overturning); correction of the change type above | none | The "Origin map" row above uses a type outside the section 4a list; its closest type is "New lesson (not overturning)". Row kept as written, since this log is append-only (writer b review N5) | pending |
| 2026-09-26 | New lesson (not overturning) | SKL-33 to SKL-36 added; SKL-16 and SKL-31 evidence re-pointed after JL-21b's merge (EV-0564); RML-47 to RML-55 mapped | JL-30 DoD 3 exercises 1 and 2 (`artifacts/jev-lab-2026-09-25/skills/exercises/`) and the coordinator's grading addendum; JL-30 writer d, attempt A1 | pending |
| 2026-09-26 | New lesson (not overturning); closest type for a promotion and an origin-map update, which add no lesson | SKL-31 promoted to established (second, independent source); SKL-33 and SKL-34 line numbers re-pointed after the JL-21b-A3 merge; RML-56 to RML-62 mapped and RML-50's row extended | `artifacts/jev-lab-2026-09-25/reviews/JL-21b.md:29`, EV-0563, EV-0566; `artifacts/jev-lab-2026-09-25/skills/exercises/1b-portable-robot-blind.md`; JL-30 writer d, attempt A2 | pending |
| 2026-09-26 | New lesson (not overturning); closest type for an origin-map update and a port-table correction, which add no SKL lesson | RML-63 mapped; the port reference's Spillway Drop row brought up to JL-27's close (EV-0559, lab head 45446ff) and the Cable Bench row given its lab head 7d5adda (EV-0553) | review of JL-30 writer d's candidate, B1 and N5; JL-30 writer d, attempt A3 | pending |
| 2026-10-24 | New lesson (not overturning) | SKL-37 added | coordinator ruling on the PC machine changes of 2026-10-24 (wallpaper pause, Cycles OptiX, gamescope, power caps) | pending |
