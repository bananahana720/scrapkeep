<!-- Retained verbatim. JL-05c-A1 independent review by scrapkeep-reviewer-medium (runtime claude-opus-5-5 per host prompt) on candidate d4f9b70, 2026-09-25. -->

## JL-05c-A1 review: `/home/andrew/Projects/scrapkeep-wt-JL-05c`, wt/JL-05c @ d4f9b70 (base 9ebdf69)

**Verdict: PASS+NOTES.** All five definition-of-done items are met, and none of the notes below breaks one.

**Evidence level:** I read the candidate files and compared them with the copies in `/home/andrew/Projects/scrapkeep-wt-JL-coord` and `/home/andrew/Projects/scrapkeep-wt-JL-14`. I could not run git or any other command. Every test count, diff and `diff -r` result below comes from the coordinator's receipts under `artifacts/local/tasks/JL-05c/receipts/` and is marked **[receipt]**. I did not open `corpus-blind.json`.

**Runtime:** the system context names the model as Opus 5.5 (`claude-opus-5-5`); I cannot confirm my identity beyond that. `CLAUDE_EFFORT` is not available to me.

**Base identity:** I could not check the JL-coord copies against 9ebdf69 without git. JL-coord `decide.mjs:120` still has the plain `PRECONDITION[option.id]`. That matches the minus side of the diff in [receipt] `16-invariants.log:2-18`, and JL-coord's `PROTOCOL.md` and `jev_io.gd` show the pre-change text.

### Findings (all non-blocking)

**N1. JL-14 makes one outcome row stale.** `PROTOCOL.md:122` says a failing arm always writes `abort.json` with reason `arm_error`. On the JL-14 candidate, a replay miss throws with reason `replay_miss` (`/home/andrew/Projects/scrapkeep-wt-JL-14/scripts/lab/arms.mjs:156-160`). The harness spreads that into the abort it writes (`.../JL-14/scripts/lab/harness.mjs:327-331, 368-372`). The recorded outcome is still `aborted`, so only the "What happens" column goes stale. JL-14 does not edit PROTOCOL.md, so the files won't conflict and the error only shows in the text. Whichever card integrates second should add "or `replay_miss` when `--replay` finds no cached verdict". The other JL-14 changes leave no row stale:
- `abort.cause` goes only into the run record; `abort.json` still carries protocol, reason and message (`:368-372`), so no message field is added.
- Batch ranking (`:83-111`) is outside PROTOCOL.md.
- The outcome precedence in `:417-431` matches the coordinator's `:341-354`.

**N2. Precedence prose is ambiguous in one edge case.** `PROTOCOL.md:127` says a trial with no final file is `crash` even when `validateTrial()` fails. In both harnesses, a Node-side rejection outranks `crash`: `rejected` becomes `invalid` before the crash branch (coord `harness.mjs:343-350`, JL-14 `:419-427`). So when hello or a state is rejected and Godot then exits without `done.json`, the harness records `invalid`, while the prose can be read as `crash`. Two smaller gaps:
- Row 121 does not mention that the harness also rejects a hello whose `scenario` doesn't match (coord `:227-229`).
- `PROTOCOL.md:125` does not list the watchdog wait from `abort.json` to `done.json` (coord `:310`).

**N3. Two untrusted keyed accesses remain, both outside this card's scope.**
- `protocol.mjs:639-640` and `:695` index `parsedStates`/`parsedIntents` by an untrusted `event.seq`/`error.seq`. A `"__proto__"` or `"constructor"` value there yields extra errors only; it is never accepted and never throws, because the field has already failed its `int` check.
- `decide.mjs:149` writes `criteria[option.id]`. That is an assignment, and an id of `__proto__` would set the prototype. Only schema-invalid options can reach it, and the card limits `decide.mjs` edits to the `PRECONDITION` lookup (BACKLOG.md:5703).

**N4. The validator can still throw on a state file containing literal `null` (predates this card, and I only read the code).** `validateTrial` stores `null` in `parsedStates[seq]`, and the guards at `protocol.mjs:646` and `:701` check only `!== undefined`. So `state.tick` throws when an intent event (or an `intent_timeout` `error.json`) names that seq. Base has the same code at `:639/:694`. It is outside DoD 1, which covers only the prototype names and array values, but it is worth a follow-up because the harness calls `validateTrial` outside its try block (coord `harness.mjs:334-335`).

**N5. A human-play step is printed but has no recorded disposition.** [receipt] `14-check-scope.log:74` prints "Andrew plays the sketch" because the diff touches `sketches/`. The change affects no gameplay: it is the validator plus the fixture copy. The coordinator should record that step as not applicable, with the reason, since the card asks for "every command it prints".

### 1. DoD items
1. **Own-name lookups: met.**
   - `ownKey` is defined at `protocol.mjs:53-54` and used for intent ids (`:81-86`), arms (`:324`) and event kinds (`:461-463`). The gate uses the same check in `decide.mjs:121-124`.
   - Fixtures cover `constructor`, `__proto__`, `toString` and an array value for all three tables: event kinds ×4, arms ×4, and option ids ×4 as both state and intent-with-context (INDEX.json:596-710).
   - Red run [receipt] `01-red-node.log:2-17`: 3 throws and 13 mismatches on base. Green run [receipt] `03-green-node-matrix.log:29`: 0 mismatches of 27.
2. **Numbers, strings and the gate agree: met.**
   - Whole numbers are exact on both sides. Node uses `kinds.int` (`protocol.mjs:61-62`). Godot maps every jev whole field to `"int"` (`jev_io.gd:94,99,102-103,115,117`), which calls `_is_int` (`:582-583`). The `"whole"` kind is removed; base had it at `jev_io.gd:540-541`.
   - PROTOCOL.md states the rule at `:174`, the non-empty string rule at `:11`, the four gate rules at `:145-150`, and `GATE_VERSION` 1 at `:152`.
   - `jev_io.gd:17` pins the same version, and `tests/jev-fixtures.test.js:49-69` asserts all three agree.
3. **Gate fixtures: met.** They cover stomp, ram and start_exit dropped, hit_kicker kept, and one invalid forced case (INDEX.json:726-783). Godot [receipt] `13-green-godot.log:4`: 81/81 valid accepted and 38/38 invalid rejected at the indexed path. Red Godot [receipt] `02-red-godot.log:5-6` failed only the exact-whole fixture.
4. **Abort and hang rows: met.** `PROTOCOL.md:121` and `:127` state the `abort{arm_error}` write on a Node-side invalid file. `:120` classifies a hang after `done.json` as `stall`.
5. **Protocol string and fields: met.** The string is `scrapkeep-jev/1` at `protocol.mjs:10` and `jev_io.gd:11`. The field tables in `protocol.mjs:133-173` and `jev_io.gd:45-132` match base: same fields, only the kind names changed.

### 2. Remaining `TABLE[untrusted]` patterns
In `protocol.mjs`, the remaining bracket reads are:
- `:107`: guarded by the `known` check.
- `:270`: fixed keys.
- `:301`: fixed keys.
- `:520`: keys come from `Object.keys`.
- `:639/640/695`: see N3.

`kinds.tier` (`:79-80`) and `oneOf` (`:88-89`) use `Array.includes` with strict equality, which is safe.

In `decide.mjs`, the remaining bracket accesses are `:42` (`index[version]`, which comes from a caller parameter, not protocol input) and `:149` (see N3).

### 3. The `decide.mjs` hunk
Behaviour is identical for every valid option id: no `INTENTS` key (`decide.mjs:85-96`) names an `Object.prototype` member, so `hasOwn` and the plain lookup agree. Only invalid ids change. On base they were dropped or threw ([receipt] `01-red-node.log:11,13`); now they are kept, which matches Godot's `match` default at `jev_io.gd:421-435`.

I agree no `GATE_VERSION` bump is needed. Every state carrying such an id already fails `validateState` (`protocol.mjs:171,81-82`), and the verdict key hashes the ungated block (`PROTOCOL.md:156`).

[receipt] `16-invariants.log:19` shows empty diffs for `gate.test.js`, `decide.test.js`, `questions`, `protocol.test.js` and `jev_io_test.gd`. [receipt] `10-npm-test.log:344-377,385-388`: the gate and q1 prompt-snapshot tests pass, 379 of 379 in total.

### 4. Whole numbers against what Godot writes
`jev_state.gd` (coord) produces exact integers:
- `time_s()` returns `int(floor(...))` (`:119-120`).
- `whole()` returns `int(round(...))` (`:262-263`), used for `distance_m` at `:191` and `:207`.
- `STAGE_TIER` is the integer constant `1` (`:20`).

Even an integral float would still pass, because `_is_int` accepts it (`jev_io.gd:583`) and `stringify` writes it without `.0` (`:641-642`, `:668-696`). Nothing newly rejected comes from Godot's own writer. The new fixture `1.0000000001` sits inside the old 1e-9 slack, so it tests the tightening.

### 5. Gate prose and the parity test
The prose matches `decide.mjs:105-113` rule by rule, including `=== true`, the fast/blazing tiers, "absent or ≥" for `requires_speed_ms`, and "absent or not `false`" for `inside_ring`.

The parity test fails loudly rather than silently passing:
- The Node and Godot patterns are line-anchored with the `m` flag (`tests/jev-fixtures.test.js:57,61`), and `assert.ok(found)` (`:52`) fails on no match. A type annotation, reformatted line or trailing comment therefore fails the test.
- The red run proves it: [receipt] `01-red-node.log:48`.
- The prose pattern (`:65`) is unanchored and takes the first match. That is acceptable.

### 6. Gate fixture contents
- `state-gate-stomp-dropped`: airborne with the air jump spent.
- `state-gate-ram-dropped`: cruise tier.
- `state-gate-start-exit-dropped`: `inside_ring` is `false`.
- `state-gate-kept`: speed 26 against `requires_speed_ms` 26, so hit_kicker is kept.
- `intent-gate-kept-forced`: invalid at `source`.

The three dropped intents are forced singles.

### 7. PROTOCOL.md outcome rows against the harness
Rows 120-123 match the coordinator's `harness.mjs:294-313, 314-326, 341-354`. See N1 for the row JL-14 makes stale and N2 for the precedence edge.

### 8. Fixture copy and existing fixtures
- I read six pairs across both trees: `state-gate-{stomp,ram,start-exit}-dropped`, `state-gate-kept`, `intent-gate-kept-forced` and `state-whole-not-exact`. Their content is identical as displayed. Byte identity rests on [receipt] `16-invariants.log:23-24` (`diff -r` exit 0) and the drift test at `10-npm-test.log`.
- `INDEX.json` is append-only: base ends its entries at `:594`, and the candidate appends from `:595`. The sample I checked at `:236-260` and the start of the trials list match base.
- The changed-path list, [receipt] `14-check-scope.log:9-71`, holds only new fixtures, the two `INDEX.json` files and the leased files, all within BACKLOG.md:5703.

### Paths
- `/home/andrew/Projects/scrapkeep-wt-JL-05c/tools/jev-player/protocol/{PROTOCOL.md,protocol.mjs}`
- `/home/andrew/Projects/scrapkeep-wt-JL-05c/tools/jev-player/decide.mjs`
- `/home/andrew/Projects/scrapkeep-wt-JL-05c/sketches/ball-lab/src/jev/jev_io.gd`
- `/home/andrew/Projects/scrapkeep-wt-JL-05c/tests/jev-fixtures.test.js`
- `/home/andrew/Projects/scrapkeep-wt-JL-coord/scripts/lab/harness.mjs`
- `/home/andrew/Projects/scrapkeep-wt-JL-coord/sketches/ball-lab/src/jev/jev_state.gd`
- `/home/andrew/Projects/scrapkeep-wt-JL-14/scripts/lab/{harness.mjs,arms.mjs}`
