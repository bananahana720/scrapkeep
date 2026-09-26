# The Godot and Node protocol

`tools/jev-player/protocol/PROTOCOL.md` is the specification, and `tools/jev-player/protocol/protocol.mjs` is its executable half. Read the specification before changing either side; this page lists the rules that caused defects and the procedure for a change.

## Where each rule lives

| Topic | Specification section | Node code | Godot code |
| --- | --- | --- | --- |
| File rules, closed schemas, own names | "Rules for every file" | `tools/jev-player/protocol/protocol.mjs` | `sketches/ball-lab/src/jev/jev_io.gd` |
| Tick schedule (D = 90, k = 26) | "Tick schedule" | `scripts/lab/godot-launch.mjs` passes D and k | `sketches/ball-lab/src/jev/jev_run.gd` |
| Outcomes and precedence | "Timeouts and exit codes" | `scripts/lab/harness.mjs` | `sketches/ball-lab/src/jev/jev_run.gd` |
| Precondition gate and `GATE_VERSION` | "Precondition gate" | `tools/jev-player/decide.mjs` | `sketches/ball-lab/src/jev/jev_io.gd` |
| Verdict-cache key | "Verdict-cache key" | `scripts/lab/verdict-cache.mjs` | none; Godot never computes it |
| Determinism | "Determinism" | `scripts/lab/gate.mjs` | `sketches/ball-lab/src/jev/jev_run.gd` |

## Rules that caused defects

- **Own names only (SKL-04).** Look up a closed set with a guard that accepts only a string that is an own key. A JavaScript object lookup accepts `constructor` through the prototype chain, and an array such as `["ram_target"]` coerces to the string key, so plain `Object.hasOwn` is not enough. Return a validation error; never throw.
- **Whole numbers are exact (EV-0513, EV-0524).** A whole-number field allows no slack on either side. A "steps of 0.1" field allows 1e-9 of float slack around the grid line and is not a second, coarser grid.
- **Non-empty strings (EV-0513).** Every string the specification defines is non-empty, including each `buffs` entry and each option's `why`.
- **No wall clock in Godot files (SKL-03).** A time of day or elapsed milliseconds in a Godot file breaks `trace_hash` equality when Node answers slowly.
- **Absent is not zero (EV-0521, EV-0523).** The live Jev response carries only `input_tokens` and `output_tokens` under `usage`. Record an unreported field as `null`, never `0`, and never add priced token fields together.
- **Abort reasons are closed.** `<io>/abort.json` carries `interrupted`, `arm_error` or `replay_miss`. The run record adds `abort.cause` for the batch meaning, such as `model_mismatch`, which voids the batch (`scripts/lab/harness.mjs:30-32`).

## Change the protocol

1. Decide whether the change is compatible. Any new field, event kind or rule is a new protocol string (`"scrapkeep-jev/2"`), not an edit to v1 (SKL-01).
2. Edit the specification first. Then change `tools/jev-player/protocol/protocol.mjs` and `sketches/ball-lab/src/jev/jev_io.gd` separately, each from the specification text (SKL-05).
3. Add valid and invalid fixtures under `tools/jev-player/protocol/fixtures/` and list them in `tools/jev-player/protocol/fixtures/INDEX.json`. Copy the directory byte for byte to `sketches/ball-lab/src/jev/fixtures/`; `tests/jev-fixtures.test.js` fails on drift (SKL-06).
4. For a gate-rule change, bump `GATE_VERSION` in `tools/jev-player/decide.mjs`, `sketches/ball-lab/src/jev/jev_io.gd` and the specification together. The same test checks that all three agree. The version is part of the verdict-cache key, so old verdicts stop matching.
5. Run `npm test` and `npm run sketch:smoke`, then the rows `scrapkeep-verify` names for the change.
6. A port on a lab branch carries its own copy, `sketches/<stage>/src/jev/jev_io.gd`; update it byte for byte and keep its drift test passing.

A protocol change is consequential: route its review to `scrapkeep-reviewer`, who re-derives both validators from the specification (design choice).
