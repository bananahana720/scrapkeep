# S0-04 runtime ownership proof

This page records the headless hello-world that proves the TADR-002 ownership rule and the TADR-005 pause rule on the pinned Godot 4.7.2 binary. It is a proof record for prepare-stage card S0-04, not a design document and not qualification evidence. The `native/` and `docs/tech/` paths are provisional pending HF-01.

Command, run from the repository root:

```sh
godot --headless --path native --script res://proofs/tadr-002/proof_runner.gd
godot --headless --path native --script res://proofs/tadr-002/proof_runner.gd -- --inject-fault
npm run native:smoke
```

The first command must exit 0 with twelve `S0-04 <phase> PASS` lines. The second must exit 1 with at least one `S0-04 B FAIL` line. The third runs both through [the smoke runner](../../../CONTRIBUTING.md#verification) as the checks `proof-tadr-002` and `proof-tadr-002-inject-fault`.

## Sources

- [TADR-002 § Decision](../../../adr/TADR-002-runtime-model.md#decision), line 26 (one session owner, one coordinator in a fixed physics callback, actor callbacks cannot advance combat, rendering never advances gameplay, tick rate deferred) and line 34 (release, cancellation and pause are distinct; focus loss clears held input and cancels prepared actions through the simulation boundary; resume cannot manufacture a cast).
- [TADR-002 § Consequences](../../../adr/TADR-002-runtime-model.md#consequences), line 38 (rules can be exercised without rendered scenes; the headless host is a possible test host, not proof of project correctness).
- [TADR-002 § Later qualification and reconsideration](../../../adr/TADR-002-runtime-model.md#later-qualification-and-reconsideration), line 46 (qualify a single owned tick and pause/resume).
- [TADR-005 § Decision](../../../adr/TADR-005-networking-scope.md#decision), line 31 (solo pause stops authoritative gameplay while menus remain interactive) and [§ Later qualification and reconsideration](../../../adr/TADR-005-networking-scope.md#later-qualification-and-reconsideration), line 39 (pausing and menu focus cannot advance combat or produce accidental actions).
- [ADR 0005](../../adr/0005-caster-input-and-dashboard.md), line 19 (held-key clearing at the UI boundary and simulation cancellation solve different problems; neither is optional).
- The browser precedent this proof differs from and does not port: `src/orchard/main.js` lines 747 to 760 and `src/orchard/simulation.js` line 140 and lines 417 to 421 (two accumulators), and `simulation.js` lines 347 to 353 (pause fused with `cancelActions()`).
- The design in `artifacts/ai-first-audit-2026-09-06/worker-results/B2-tadr-002-005.md`, sections 1 and 2 and its S0-02 card, which is this card under its earlier id.
- The Godot 4.7 documentation receipt `artifacts/local/tasks/S0-04/ctx7-godot.txt` (three `ctx7` queries against `/websites/godotengine_en_4_7`) and the engine probes under `artifacts/local/tasks/S0-04/probes/`. Both are disposable local evidence; the probe scripts and outputs are listed under Procedure performed.
- The scaffold this proof runs inside: [the native README](../../../native/README.md) and [the toolchain record](../native-toolchain.md).

## Contract

The proof lives under `native/proofs/tadr-002/` and runs inside the single scaffold project `native/project.godot`, whose warning keys make every untyped or inferred declaration an error. Seven typed scripts, no addon, no `Input` singleton, no accumulator and no wall-clock assertion.

| Script | Role | Owns |
| --- | --- | --- |
| `encounter_state.gd` | `RefCounted` record | `tick`, `prepared`, `casts_committed`; `snapshot()` returns a value copy |
| `encounter_coordinator.gd` | `Node`, the only writer of the record | `submit(cmd)` queues; `advance_external()` is rejected outside its own `_physics_process` and counted in `rejected_out_of_phase`; `_physics_process` applies the queue, reads one input frame, commits a cast on the release edge of `cast` when a cast is prepared, and increments `tick`; `published()` returns a snapshot |
| `input_adapter.gd` | held-state owner | `press`, `release`, `frame()` with `released = previous and not held`, `clear_held()` clears held and previous so no release edge is manufactured |
| `session_owner.gd` | session owner | `run_id`, a profile stub, the coordinator as its child; `pause()` and `resume()` set `SceneTree.paused`; `on_focus_lost()` clears held input, submits `cancel_prepared` and pauses; `_notification` reacts to `NOTIFICATION_APPLICATION_FOCUS_OUT`; `lose_focus()` propagates that notification and falls back to a direct call, logging `S0-04 focus trigger notification` or `direct-call` |
| `menu_probe.gd` | menu stand-in | `process_mode = PROCESS_MODE_ALWAYS`; counts `_process` calls |
| `intruder.gd` | second source | `_process` and a one-shot `SceneTreeTimer` `timeout` both call `advance_external()` and mutate a local snapshot copy; under `--inject-fault` it also writes `coordinator._state.tick` directly |
| `proof_runner.gd` | `SceneTree` script | builds the tree in `_initialize()`, prints `S0-04 PLACEHOLDER_TICK_RATE <n>`, sequences phases A to E with a 600-physics-frame ceiling per phase, prints one line per assertion and a `S0-04 SUMMARY <json>` line, then `quit(code)` |

Exit codes: 0 all assertions pass, 1 at least one assertion failed, 2 a phase exceeded its frame ceiling, 3 the tree was not built or the tick rate read as zero.

The tick rate is a placeholder. TADR-002 line 26 defers the rate to later Runtime Patterns and Constraints work, so the proof logs `Engine.physics_ticks_per_second` (60 on this host, the engine default) under the `PLACEHOLDER_TICK_RATE` label and asserts only invocation counts, never seconds.

The summary line carries the engine version token, the placeholder rate, `inject_fault`, assertion and failure counts, `ceiling_hit`, `tick`, `physics_calls`, `rejected_out_of_phase`, `accepted_in_phase`, `casts_committed`, the menu and intruder counters, `focus_trigger` and the exit code.

### Proven

Quoted from the B2 design: "Proves: one physics-callback writer holds against _process caller, signal handler, snapshot consumer; tree pause freezes gameplay while ALWAYS node updates; the three TADR-002:34 operations separable; resume yields no cast."

In this card's words: one physics-callback writer holds against a `_process` caller, a timer signal and a snapshot consumer; tree pause freezes gameplay while an always-mode node runs; release, cancel, pause and resume are separable; resume yields no cast.

### Not proven

Quoted from the B2 design: "Does NOT prove: controller feel, rendering interpolation, physics/collision correctness (TADR-002:28,46), real OS focus events, real Input singleton, tick-rate suitability, overload policy (HF-04 DoD1), scene replacement (separate hello-world), determinism (TADR-005:25)."

In this card's words: controller feel, rendering interpolation, physics-world correctness, real OS focus events, the real `Input` singleton, tick-rate suitability, overload policy, scene replacement, determinism.

## Scenarios

N is 10 physics frames. Every phase samples state right after an `await physics_frame`, which the probe showed is emitted before the nodes' `_physics_process` of that frame, so counts line up on frame boundaries.

| Phase | Steps | Assertions |
| --- | --- | --- |
| A owner | Record `tick`, `physics_calls` and `run_id`; wait N frames | `tick` and `physics_calls` each rose by N and are equal; `run_id` unchanged |
| B second source | Arm the intruder (snapshot copy, `_process` calls, one `SceneTreeTimer`); wait until the timer fired and at least one `_process` ran, then N more frames; disarm | `rejected_out_of_phase >= 2` and `accepted_in_phase == 0`; `tick == physics_calls`; the intruder's copy shows casts and a prepared action while the coordinator shows none |
| C positive control | Submit `prepare_cast`, hold `cast` two frames, release, two frames | prepared was `cast` while held with no cast; after release `casts_committed == 1` and prepared is empty |
| D pause | Submit `prepare_cast`, one frame, `pause()`, N frames | `tick` constant; menu probe `_process` count rose; prepared still `cast` (pause alone cancels nothing) |
| E focus loss | `resume()`, submit `prepare_cast`, hold `cast` two frames, `lose_focus()`, N frames, `resume()`, N frames | while paused: tree paused, no held or previous input, `tick` constant, `cancel_prepared` pending at the boundary; after resume: prepared empty, `casts_committed` still 1, `tick` advanced by N and equals `physics_calls` |

Fault injection replaces "uncomment a line". With `-- --inject-fault`, `OS.get_cmdline_user_args()` contains `--inject-fault`, the intruder writes `coordinator._state.tick` on every `_process` call, and phase B reports `S0-04 B FAIL tick 59 physics_calls 24` (numbers from the recorded run). Phase E's tick equality fails as the same drift propagates. The run exits 1.

Observed on this host (`artifacts/local/tasks/S0-04/proof-run.txt`): twelve PASS lines, `rejected_out_of_phase 35` from 34 `_process` calls and one timer, `focus_trigger` `notification`, final `tick 41 == physics_calls 41`, `casts_committed 1`.

## Unresolved questions

- The production tick rate (TADR-002 line 26, HF-04a DoD 1, Q-E03). The proof logs the engine default as a placeholder and takes no position.
- Whether the cancel submitted at focus loss should be applied while paused or, as here, at the coordinator's first step after resume, before it reads input. Both orders leave no cast because `clear_held()` also clears the previous frame, but HF-04a owns the order of the four operations.
- Whether `SceneTreeTimer` or a `Timer` node is the representative signal source. The receipt documents `SceneTreeTimer` as a one-shot timer processed after the nodes' process steps, so it was used; a `Timer` node was not exercised.
- Whether real OS focus events reach `NOTIFICATION_APPLICATION_FOCUS_OUT` on the target platforms. Only `propagate_notification` was exercised.

## Re-verification triggers

- A change to `native/project.godot` warning keys or the pinned engine version in [the toolchain record](../native-toolchain.md).
- A change to TADR-002 line 26 or 34, or TADR-005 line 31 or 39.
- HF-04a admission, whose DoD items 1 and 2 name this card, and HF-04b revision 2, which replaces its sketches with links to this source.
- HF-01 renaming `native/` or `docs/tech/`.
- A later proof (S0-05 to S0-08) that changes `scripts/native-smoke.mjs` proof discovery or the assertion line format.

## Procedure performed

All commands ran on 2026-09-06 from the `wt/S0-04` worktree on the host in the toolchain record, with the pinned binary at its recorded install path.

1. Fetched the 4.7 documentation with three `ctx7` queries into `artifacts/local/tasks/S0-04/ctx7-godot.txt`. The receipt names `Engine.is_in_physics_frame()`, `_physics_process`, `_process`, `Node.process_mode` with `PROCESS_MODE_ALWAYS` and `can_process()`, `SceneTree.paused`, `propagate_notification`, `SceneTree.quit()`, `OS.get_cmdline_args()`, `SceneTree.create_timer()` and `SceneTreeTimer.timeout`, and `Engine.get_physics_frames()`.
2. Probed every API the receipt does not name with `artifacts/local/tasks/S0-04/probes/probe.gd`, `probe_helper.gd` and `probe2.gd` (outputs in `probe-output.txt` and `probe2-output.txt`). Unverified by documentation and confirmed by probe:
   - `SceneTree.physics_frame` awaited from the `SceneTree` script: ten awaits produced exactly ten `_physics_process` calls, the first await resumed before any physics call, and the signal kept emitting while `paused` was true with the pausable node frozen and the always-mode node still processing.
   - `Engine.physics_ticks_per_second`: read 60.
   - `OS.get_cmdline_user_args()`: returned `["--inject-fault"]` for a run ending in `-- --inject-fault`.
   - `SceneTree.quit(3)`: the process exited 3.
   - `NOTIFICATION_APPLICATION_FOCUS_OUT`: the constant resolved to 2017, and `propagate_notification` from `root` and from the node itself each reached `_notification`.
   - `MainLoop._initialize()` on a `SceneTree` script: called with `root` valid; nodes added there report `is_inside_tree()` false at that instant and receive callbacks from the first frame.
   - `SceneTreeTimer.timeout` in a headless run: fired after four physics frames with `Engine.is_in_physics_frame()` false.
   - `Engine.get_version_info()`: returned the dictionary S0-01 already relies on.
   - Typed dictionaries `Dictionary[String, bool]`, an inner class used as a type through a preload constant, and a script preloading itself to type `snapshot()`: all parsed under the warning-as-error keys.
3. Wrote the seven scripts and ran the proof and the fault-injected proof directly; outputs with exit codes in `artifacts/local/tasks/S0-04/proof-run.txt` and `proof-run-inject-fault.txt`, the summary line extracted to `result.json`.
4. Extended `scripts/native-smoke.mjs` with proof discovery and ran `npm run native:smoke` (`artifacts/local/tasks/S0-04/native-smoke.txt`); the four S0-01 checks and the two proof checks pass and the report is `artifacts/local/native-smoke/report.json`.
5. Ran `npm run check:docs`, `npm run check:project`, `npm test` and `npx prettier --check scripts/native-smoke.mjs`; outputs under `artifacts/local/tasks/S0-04/`.

### Proposed HF-04b revision 2 text

Replace HF-04b DoD item 2 with: "For the game-loop, state-machine and scoped-signal patterns, link the S0-04 source under `native/proofs/tadr-002/` instead of an inline sketch: `encounter_coordinator.gd` for the single physics-callback owner and command admission, `session_owner.gd` and `input_adapter.gd` for the four separable operations (release, cancel, pause, resume), `menu_probe.gd` for an always-mode node under tree pause, and `intruder.gd` with `proof_runner.gd` phase B for the rejected second source. Each link names the assertion in [the S0-04 proof document](../proofs/S0-04-runtime-ownership.md) that executed it on the pinned binary. The scene-lifecycle pattern keeps its sketch marked unparsed until the scene-replacement proof lands." Keep item 3 and add to Verification: "Confirm each linked file exists, is typed under `native/project.godot`, and is run by `npm run native:smoke`."

## Evidence limits

The proof ran headless on one Linux developer machine with the pinned binary. It exercised no window, renderer, input device, physics body, scene file, save or export, and it drove focus loss through `propagate_notification`, not an OS event. The `input_adapter` stands in for the `Input` singleton; it proves the edge and clearing rules, not device behavior. Counts are invocation counts under the engine's default 60 ticks per second; nothing here chooses or validates a tick rate, an overload policy or determinism. The intruder proves that a `_process` caller and a timer signal are rejected outside the owner's phase and that direct state writes are detected by the assertions; it does not prove that GDScript prevents such writes, since the `_state` field is reachable by any script that holds the coordinator. Automated runs establish no human feel. Nothing here is qualification evidence under TADR-001 or a `verify` stage.
