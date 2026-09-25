# Godot–Node protocol v1 (`scrapkeep-jev/1`)

One Godot trial and the Node harness talk only through files in one `<io>` directory per trial. There are no sockets ([TADR-005](../../../adr/TADR-005-networking-scope.md)). [`protocol.mjs`](protocol.mjs) is the executable half of this document: one validator per message type, `validateTrial()` for a whole directory, and `writeAtomic()`. [`fixtures/`](fixtures/INDEX.json) holds the canonical examples.

## Rules for every file

- **One writer.** Each file has exactly one writer, shown below. Neither side writes, renames or deletes the other side's files. The harness may remove the whole directory only after Godot has exited.
- **Tmp-then-rename.** The writer writes `<name>.tmp` in the same directory, flushes it and renames it to `<name>`. Readers ignore `*.tmp`. Node uses `writeAtomic()`.
- **Versioned.** Every JSON file has `"protocol": "scrapkeep-jev/1"`.
- **Closed.** An unknown field is invalid, except inside `sim` (state) and `meta` (intent).
- **Non-empty strings.** Every string field this document defines is non-empty, including each `buffs` entry and each option's `why`. Values inside `sim` and `meta` are unchecked, except `meta.questions_sha`.
- **Own names only.** A closed set of names (event kinds, arms, intent ids, gate rules) matches only its own string entries. `constructor`, `__proto__`, `toString` and an array such as `["takeoff"]` are not members; a validator reports them as errors and never throws on them.
- **No wall clock in Godot files.** Godot's files hold ticks, never times of day or elapsed milliseconds. That keeps `trace_hash` identical when Node answers slowly.
- **Numbering.** `NNNNNN` is the snapshot's `seq`, zero-padded to six digits and starting at `000000`. `intent-NNNNNN.json` answers `state-NNNNNN.json`.
- **Closed directory.** `<io>` holds only the file names in the table below. Node ignores any file whose name ends in `.tmp`; `validateTrial()` rejects any other name.

## Files

| File | Writer | When |
| --- | --- | --- |
| `hello.json` | Godot | Once, before the first snapshot |
| `state-NNNNNN.json` | Godot | At every snapshot tick |
| `intent-NNNNNN.json` | Node | Once per snapshot, as soon as the arm has chosen |
| `abort.json` | Node | At most once, when Node ends the trial early |
| `events.ndjson` | Godot | Appended to as `events.ndjson.tmp` during the trial, then renamed into place before `done.json` or `error.json` |
| `error.json` | Godot | Last file, when Godot stops on an error; never beside `done.json` |
| `done.json` | Godot | Last file, when Godot ends cleanly or after an abort |

### `hello.json`

| Field | Rule |
| --- | --- |
| `sketch`, `scenario`, `physics_mode`, `godot` | Non-empty strings. `physics_mode` is the ball-lab mode (`kinematic` or `rigid`). `godot` is the engine version. |
| `seed` | Integer. The effective seed, after any `seed_override`. |
| `tick_hz`, `snapshot_every`, `hold_ticks`, `intent_timeout_s` | The schedule in force. v1 is 90, 90, 26 and 30. `tick_hz`, `snapshot_every` and `intent_timeout_s` must each be greater than 0; `hold_ticks` must be below `snapshot_every`. |

### `state-NNNNNN.json`

| Field | Rule |
| --- | --- |
| `seq` | The snapshot number, matching the file name |
| `tick` | `seq × snapshot_every` |
| `held` | The intent in force at this tick; `null` before the first intent applies |
| `jev` | `{state, options}`, pre-quantised to the corpus schema (below). This is exactly what an arm sees and what the verdict-cache key covers. |
| `sim` | Godot's own view: `pos` and `vel` as three finite numbers each. Extra keys are allowed and unchecked. Never shown to Jev, never hashed: not part of `trace_hash` (which covers `events.ndjson` only) and not part of the verdict-cache key. |

### `intent-NNNNNN.json`

| Field | Rule |
| --- | --- |
| `seq` | Matches the state it answers |
| `intent` | An intent id from `INTENTS` in `decide.mjs`, and one of the offered options (see Arms) |
| `arm` | `random`, `scripted` or `jev` |
| `source` | Which path chose it; allowed values depend on the arm (see Arms) |
| `meta` | Object. For the `jev` arm, `meta.questions_sha` (64 lowercase hex, from `instrumentIdentity()`) is required. Other keys are free, for example `model`, `confidence`, `low_confidence`, `raw_intent`, `latency_ms`, `cache_key`, `seed` and `rule`. |

### `abort.json`

| Field | Rule |
| --- | --- |
| `reason` | `interrupted`, `arm_error` (for example a Jev API failure) or `replay_miss` (`--replay` found no cached verdict) |
| `message` | Optional; when present, a non-empty string |

### `error.json`

| Field | Rule |
| --- | --- |
| `code` | `intent_timeout`, `intent_invalid` or `internal`; the exit code follows the table under Timeouts |
| `seq` | The snapshot concerned, or `null` |
| `tick` | The tick Godot stopped at. For `intent_timeout` this is the blocking tick, `state.tick + hold_ticks`. |
| `message` | Non-empty string |

### `done.json`

| Field | Rule |
| --- | --- |
| `reason` | `complete`, or `aborted` when `abort.json` exists |
| `tick` | The last simulated tick |
| `snapshots` | How many state files were written |
| `trace_hash` | SHA-256 (lowercase hex) of the bytes of `events.ndjson` |

### `events.ndjson`

One JSON object per line, LF-terminated, with a trailing newline after the last line; an empty file (no lines at all) is valid. Each line is `{tick, kind, ...}`, ticks never decreasing. Each kind has a closed set of fields:

| `kind` | Extra fields | When |
| --- | --- | --- |
| `trace` | `pos`, `vel`, `tier`, `grounded` | Every `tick_hz / 10` ticks (10 Hz) |
| `intent` | `seq`, `intent` | The tick an intent is applied |
| `tier` | `from`, `to` | Speed tier change |
| `takeoff`, `landing` | none | Leaving or reaching the ground |
| `knock` | `strength` | A shockwave hit: 0.6 is a stomp, 1.0 a ram |
| `stuck_begin`, `stuck_end` | none | Stuck detection |
| `anomaly` | `what`: `nan`, `tunnel`, `out_of_bounds` or `overspeed` | NaN, `y < Field.height − 0.5`, out of bounds, or speed above 80 m/s |

At an equal tick, an `intent` line comes before the `trace` line; `validateEvents()` enforces this.

## Tick schedule

Godot runs with `--fixed-fps 90`, so frames and physics ticks are 1:1. With D = `snapshot_every` = 90 and k = `hold_ticks` = 26:

1. At tick t = seq × D, Godot writes `state-seq`.
2. For ticks t to t + k − 1 it keeps flying the held intent. Before the first intent applies, input is neutral: no stick, no buttons.
3. At tick t + k it needs `intent-seq`. If the intent is not there, Godot blocks inside `_physics_process` (polling with `OS.delay_msec`), not with `tree.paused`. While blocking it also watches for `abort.json`.
4. When the intent arrives, Godot validates it, applies it at tick t + k exactly, and appends an `intent` event with that tick. The intent is held until the next one applies at t + D + k.

Because k < D, `state-(seq+1).held` is always `intent-seq`. Godot checks for `abort.json` at every snapshot and while blocking. A snapshot after seq 0 requires the previous intent file: `validateTrial()` rejects `state-seq` (seq > 0) when `intent-(seq-1)` is missing.

## Timeouts and exit codes

| Condition | Detected by | What happens | Godot exit | Node records |
| --- | --- | --- | --- | --- |
| Trial ends normally | Godot | `done.json`, reason `complete` | 0 | `complete` |
| `abort.json` seen | Godot | Finalise events; `done.json`, reason `aborted` | 0 | `aborted` |
| No intent 30 s after blocking | Godot | `error.json`, code `intent_timeout` | 5 | `error:intent_timeout` |
| Intent fails validation | Godot | `error.json`, code `intent_invalid` | 4 | `error:intent_invalid` |
| Any other failure Godot catches | Godot | `error.json`, code `internal` | 1 | `error:internal` |
| No new Godot file within `max(30 s, 20 × median step)` after Node's last intent | Node watchdog | SIGKILL | none | `stall` |
| Godot exits with no `done.json` or `error.json` | Node | nothing to read | any | `crash` |
| Godot writes `done.json` or `error.json` but does not exit within the watchdog limit | Node watchdog | SIGKILL | none | `stall` |
| `hello.json` or a state file fails its validator, or `hello.json` names another scenario | Node | `abort.json`, reason `arm_error`, with a message naming the file; stop reading | any | `invalid` |
| The arm fails: it throws, answers an intent that fails `validateIntent()`, reaches the batch call cap, or answers from a model other than the batch's anchor | Node | `abort.json`, reason `arm_error`, or `replay_miss` when `--replay` finds no cached verdict | 0 | `aborted` |
| `validateTrial()` fails on the finished directory | Node | nothing | any | `invalid` |

A **step** is the wall time from Node renaming `intent-N` into place to the next Godot file appearing. The median is nearest-rank, and the limit is 30 s until one step has completed (`watchdogMs()`). The watchdog also runs from spawn to `hello.json`, from `hello.json` to the first state, and from Godot's last file (`done.json` or `error.json`) to its exit.

Node writes `abort.json` on an invalid Godot file so that Godot finishes at once instead of blocking for an intent that will never come. v1's abort reasons are closed, and `arm_error` is the nearest: Node, not the engine, cannot go on. The trial is still recorded as `invalid`.

Outcomes are decided in this order, as the harness does. A trial killed by the watchdog is `stall`. Otherwise a file Node rejected (`hello.json` or a state) makes it `invalid`, even when Godot then exits with no final file: a Node-side rejection outranks `crash`. Otherwise `done.json` or `error.json` names the outcome, and a trial with neither is `crash`. `stall` and `crash` stand even when the files also fail `validateTrial()`; any other outcome becomes `invalid` when `validateTrial()` fails.

## Arms and `forced`

| Arm | Allowed `source` | Role |
| --- | --- | --- |
| `random` | `seeded`, `forced` | The floor; seeded |
| `scripted` | `rule`, `forced` | The baseline rule ladder |
| `jev` | `live`, `cache`, `forced` | The candidate. `cache` is a verdict-cache hit, as every `--replay` answer is. |

- **Offered options** are the state's `jev.options` after the precondition gate (below). If the gate removes everything, `push_objective` alone is offered (`offeredOptions()`).
- **Forced.** When exactly one option is offered, every arm answers it with `source: "forced"` and makes no API call. `forced` with more than one offered option is invalid.
- The intent must be an offered option. One exception: the `jev` arm may answer `push_objective` when it was not offered, because below the confidence floor `decide.mjs` holds `push_objective`.

## Precondition gate

`PRECONDITION` in `decide.mjs` removes each option the engine cannot execute before any arm sees it, and `jev_io.gd` ports the same rules. `self` and `objective` are the state's `jev.state.self` and `jev.state.objective`:

| Option id | Kept when |
| --- | --- |
| `stomp_target` | `self.grounded` is `true`, or `self.air_jump_available` is `true` |
| `ram_target` | `self.speed_tier` is `fast` or `blazing` |
| `hit_kicker` | The option has no `requires_speed_ms`, or `self.speed_ms` ≥ `requires_speed_ms` |
| `start_exit` | `objective` is absent, or `objective.inside_ring` is not `false` |

Any other id has no rule and is kept. Rules are found by own name only, so an invalid id such as `constructor` or `["ram_target"]` also has no rule; the state that carries it already fails its validator. `GATE_VERSION` is 1. A change to these rules or to the all-gated fallback bumps it in `decide.mjs`, in `jev_io.gd` and here, together; `tests/jev-fixtures.test.js` checks that all three agree. The version is part of the verdict-cache key.

## Verdict-cache key

`verdictKey(instrument, jev)` is the SHA-256 of `canonicalJson({protocol, questions_sha, model, confidence_floor, gate_version, state, options})`. `instrument` is `instrumentIdentity()` from `decide.mjs`. `state` and `options` are the `jev` block exactly as Godot wrote it, before the gate, because `gate_version` already covers gate changes. Canonical JSON sorts object keys at every depth, keeps array order and has no whitespace. Node computes the key; Godot never computes or checks it. The cache itself belongs to JL-14.

## The `jev` block (corpus schema)

Every whole-number field and every steps-of-0.1 field in this block is ≥ 0; there is no signed field in the `jev` block.

| Path | Type and quantisation |
| --- | --- |
| `state.self.speed_ms` (required) | ≥ 0, steps of 0.1 |
| `state.self.speed_tier` (required) | `walk`, `cruise`, `fast` or `blazing` |
| `state.self.grounded` (required) | boolean |
| `state.self.hp`, `air_jump_available`, `location`, `over` | whole number ≥ 0, boolean, string, string |
| `state.stage.name`, `time_s`, `tier` (all required) | string, whole seconds (`floor(tick / tick_hz)`, the elapsed time since the trial began), whole number |
| `state.threats` (required) | 0 to 3 entries, each with `kind` (string) and optionally `distance_m` and `damage` (whole numbers); `impact_in_s`, `arc_lands_in_s` and `water_rises_in_s` (steps of 0.1); `closing`, `on_current_line`, `targets_current_position`, `telegraphing` and `below` (booleans); `effect` and `lands_on` (strings) |
| `state.objective.kind`, `distance_m` (required) | string, whole metres; optionally `inside_ring` and `charge_started` (booleans) |
| `state.scrap.held`, `state.buffs` | whole number; list of strings |
| `options` | At least one, unique ids from `INTENTS`, each `{id, why}` plus optional `requires_speed_ms` (steps of 0.1) |

Every case in `corpus.json` passes this schema. A whole-number field is an exact integer on both sides, with no slack: `1.0000000001` is invalid. A "steps of 0.1" check allows up to `1e-9` of floating-point slack around the grid line, because tenths are not exact in binary; it is not a second, coarser grid.

## Determinism

- `trace_hash` covers all of `events.ndjson`. For the same scenario, seed and physics mode it must be identical whatever Node's response delays; the bridge test (JL-17) checks this.
- Ball-lab's only randomness is the visual camera jitter. Stage seeds come from `seed_override`, reported in `hello.seed`.
- If the rigid (Jolt) mode's hash diverges between identical runs, the result is reported as stochastic, not as a protocol failure.

## Fixtures and changes

`fixtures/INDEX.json` lists every fixture with its type, whether it is valid and, for an invalid one, the path its fault is reported at. It also lists the trial directories, each judged as a whole. JL-09 copies `fixtures/` byte for byte to `sketches/ball-lab/src/jev/fixtures/`, and a drift test compares the two.

Any new field, event kind or rule is a new protocol string (`scrapkeep-jev/2`), not an edit to v1.
