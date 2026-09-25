<!-- Retained verbatim. JL-05b-A1 independent review by scrapkeep-reviewer (runtime claude-fable-5-1 per host prompt) on candidate 15b1be2, 2026-09-25. -->

## Review of JL-05b attempt A1 — candidate `/home/andrew/Projects/scrapkeep-wt-JL-05b`, wt/JL-05b, head 15b1be2 (as named in the packet; I could not run git), base bdf0bb6

**Verdict: PASS+NOTES.** Evidence level: source review of `PROTOCOL.md`, `protocol.mjs`, `protocol.test.js`, `fixtures/INDEX.json` and every new fixture file, compared line-by-line against the base copies in `/home/andrew/Projects/scrapkeep-wt-JL-coord/tools/jev-player/protocol/`; hand-trace of all nine new trial directories and both new events fixtures through the candidate validator, and of the two DoD-2 fixtures through the base validator. Command outcomes rest on the writer's receipts under `artifacts/local/tasks/JL-05b/`, which I read but could not re-run. No note below violates a DoD item.

Runtime model: the host system prompt states `claude-fable-5-1`; that is host-supplied text, not self-verifiable. `CLAUDE_EFFORT`: unavailable to me.

### Blocking findings

None.

### Non-blocking findings

1. **The packet's revert-and-rerun receipt does not exist on disk.** `artifacts/local/tasks/JL-05b/` holds nine files (`10-npm-test.txt`, `11-npm-verify.txt`, `12-check-scope.txt`, `13`–`15`, `16-verify.txt`, two `gen-fixtures-*.mjs`); a case-insensitive grep for `revert|git stash|git checkout|not ok|fail [1-9]` over the directory returns nothing. Coordinator-supplied claim, unverified. I replaced it with a hand-trace against the base validator (`scrapkeep-wt-JL-coord/.../protocol.mjs:433-475` and `:576-585`): `invalid/events-trace-before-intent.ndjson` (ticks 0, 26, 26; all shapes valid) returns `[]` on base, so `protocol.test.js:84-88` would fail with "should fail with exactly one error at events[2]"; `trial-missing-intent/` (state-000001 with `held: null`, no intent-000000) returns `[]` on base because `expected` is `null` at `:577-578`, so `:141-145` would fail. Both fixtures are red on base and green on candidate by construction. Recommend the coordinator either locate the receipt or record this trace as the substitute.

2. **Sign constraints stated only for some numeric fields (rule enforced only in code).** `protocol.mjs:56-57` (`int`) and `:62-63` (`tenth`) require `>= 0` for every whole-number and tenth-grid field. `PROTOCOL.md:145` states `≥ 0` for `hp` and `:142` for `speed_ms`; `:146-150` say only "whole number"/"whole seconds"/"whole metres"/"steps of 0.1" for `time_s`, `tier`, `distance_m`, `damage`, `impact_in_s`, `arc_lands_in_s`, `water_rises_in_s`, `requires_speed_ms`, `scrap.held`. No fixture carries a negative value, so a doc-only GDScript validator still agrees on every fixture; it would disagree on a negative `damage` or `tier`. Also `abort.message`: doc `:60` "Optional string", code `:396` rejects `""`. One clause in the jev-block table and one word at `:60` close both.

3. **Missing-intent invariant is stated by implication, not named.** `protocol.mjs:588-601` rejects `state-N` (N > 0) when `intent-(N-1)` is absent; `PROTOCOL.md:105` ("state-(seq+1).held is always intent-seq") implies it and `trial-missing-intent` pins it, but no sentence says "a snapshot after seq 0 requires the previous intent file". DoD 1's enumerated list does not include this rule, so not a DoD gap; it is the one trial-level rule a JL-09 implementer must derive from the fixture rather than read.

4. **`.tmp` handling wording vs code.** `PROTOCOL.md:13` says the directory may hold the listed names "plus their `.tmp` siblings"; `protocol.mjs:527` skips any name ending in `.tmp`, so `foo.tmp` is ignored by Node but would be rejected by a validator built from `:13`. No fixture covers it; cosmetic.

5. **Under the v1 schedule the equal-tick rule never fires.** With D = 90, k = 26, intent ticks are 90n + 26 ≡ 8 (mod 9) and trace ticks are multiples of 9 (`PROTOCOL.md:86`), so the collision only arises in other schedules (for example the JL-21 sweep's k = 0, where every intent tick is a trace tick). The rule is still correct and binding on JL-09's write order; noting so the sweep card knows it is live there.

### Judgements the packet asked for

**1. DoD and JL-05 notes**

| DoD | Where | Status |
| --- | --- | --- |
| 1. Doc states every enforced rule | grid tolerance `PROTOCOL.md:152` ↔ `protocol.mjs:47-49`; LF, trailing newline, empty valid `:82` ↔ `:438-441`; `tick_hz`/`snapshot_every`/`intent_timeout_s` > 0 `:33` ↔ `:268-271`; closed file-name set `:13` ↔ `:531-541`; `sim` unchecked and never hashed `:43` ↔ `:295-306`; `time_s = floor(tick / tick_hz)` `:146`; verdict key Node-only `:136`; watchdog after Node's last intent `:116` | Met |
| 2. Equal-tick order; state seq > 0 needs intent seq−1 | enforced at `protocol.mjs:447, 476-482`, stated `PROTOCOL.md:94`, fixtures `valid/events-intent-before-trace.ndjson` and `invalid/events-trace-before-intent.ndjson` (`INDEX.json:311-322`); missing-intent check `protocol.mjs:592-601`, fixture `trial-missing-intent` (`INDEX.json:624-629`) | Met |
| 3. Eight trial negatives, each failing for its stated reason | `INDEX.json:630-677`; hand-traces below | Met |
| 4. `deepEqual` on the exact path list | `protocol.test.js:84-88` (fixtures), `:141-145` (trials); both `errors.map(path)` vs `[entry.path]`, so exactly one error at exactly that path | Met |
| 5. Protocol string unchanged, no message field added | `protocol.mjs:10` still `"scrapkeep-jev/1"`; `EVENTS` `:415-430`, every `shape()` map in `:253-411` and the jev schema `:128-168` byte-identical to base `:128-168, :253-430`; `PROTOCOL.md:9` unchanged | Met |

JL-05 notes: 3 closed (`PROTOCOL.md:13, :33, :82, :94, :152` plus enforcement `:476-482`); 5 closed (`:43` "Never shown to Jev, never hashed", `:146` tick-derived); 6 closed (all eight negatives present; "out-of-order state ticks" remains untested but was outside the DoD); 7 closed (`protocol.mjs:592-601`); 8 closed (`PROTOCOL.md:116`); 10 closed (`protocol.test.js:84-88, :141-145`).

**2. Acid test.** A GDScript validator written from `PROTOCOL.md` plus fixtures agrees with `protocol.mjs` on every fixture: I found no fixture whose outcome depends on an undocumented rule. Rules still enforced only (or more strictly) in code, none exercised by a fixture: the `>= 0` on all `int`/`tenth` fields beyond `hp` and `speed_ms` (finding 2); non-empty `abort.message` (finding 2); any-`.tmp` skip (finding 4); `validateTrial` short-circuiting after an invalid `hello.json` (`protocol.mjs:549`) — not stated, but `trial-wrong-protocol` still yields one error either way because the rest of that directory is `trial-complete`; the missing-intent rule is implied at `:105` rather than named (finding 3). Everything else in `validateTrial` maps to a doc line: contiguity `:12/:20`, seq/tick `:39-40`, intent answers its state `:12`, held continuity `:41/:105`, done-beside-error `:24`, events before done/error `:23`, intent event tick `:103`, `done.snapshots` `:77`, aborted needs abort `:75`, `trace_hash` `:78`, `intent_timeout` tick `:68`.

**3. New enforcement correctness.** `validateEvents`: `traceTick` (`:447`) records the tick of the last `trace` line; an `intent` at the same tick (`:476`) can only occur after that trace because ticks are non-decreasing (`:470`), so it detects exactly trace-before-intent and nothing else. Nothing Godot legitimately produces trips it: the doc mandates intent-first (`:94, :103`), only one intent applies per snapshot, and the only case with two errors on one line (an intent at a tick below `last` that also equals `traceTick`) is already a backwards-tick fault. Missing-intent rule (`:592-601`): fires only when `seq > 0`, `state-(seq-1)` was parsed and `intent-(seq-1)` is absent. Every path Godot can take past tick t+k requires `intent-seq` (`:102-104`); abort, `intent_timeout` and `intent_invalid` all end the trial at t+k < t+D so `state-(seq+1)` never exists (`trial-aborted`, `trial-timeout` and `valid/error-intent-invalid.json` are consistent); k = 0 still blocks at t. The `parsedStates[seq-1] !== undefined` guard is what keeps `trial-noncontiguous` at one error: `parsedStates` is a sparse array, `forEach` skips the hole at 1, and for seq 2 the guard is false, so only `state-000001.json` "is missing" is reported. When an intent is missing and `held` is non-null the trial gets two errors (missing intent plus held mismatch); that is a doubly invalid trial, not a false rejection.

**4. Trial-level negatives, hand-traced through candidate `validateTrial`:**
- `trial-wrong-protocol`: `validateHello` returns `[protocol]` (`:73`), `:267` skips the >0 checks, `:549` returns → `[hello.json:protocol]`. The flat `hello.json` entry (`INDEX.json:342-347`) likewise `[protocol]`.
- `trial-intent-unsnapshotted`: `intents[1]` with `parsedStates[1]` undefined → `:578-583` error; context-free `validateIntent(intent1)` (jev/forced/valid sha) adds nothing; no done/error → `[intent-000001.json]`. INDEX correctly lists that intent with no `context` (`:405-410`).
- `trial-noncontiguous`: `states.length` 3, hole at 1 → `:555-560`; `state-000002` seq 2, tick 180 = 2×90, held null; forEach skips index 1; seq 2 guard false, expected null → `[state-000001.json]`.
- `trial-missing-intent`: `:592-601` fires for seq 1; `held: null` equals `expected` null → `[intent-000000.json]`.
- `trial-snapshots-mismatch`: `trial-complete` bytes plus `snapshots: 3` vs `parsedStates.length` 2 → `[done.json:snapshots]`; `trace_hash` `5ce97b…` equals `trial-complete/done.json:6`, applied set {0, 1} covers both due intents.
- `trial-hash-mismatch`: `d2165b…` is 64 hex so `validateDone` passes; `:668` mismatch → `[done.json:trace_hash]`.
- `trial-done-beside-error`: `:612-614` → `done.json`; `error.tick` 26 = 0 + 26 passes `:698`; `done.reason` complete needs no abort; hash `2ed9ae…` matches `trial-aborted/done.json:6` for identical event bytes → `[done.json]`.
- `trial-aborted-no-abort`: `:660-665` → `[done.json:reason]`.
- `trial-timeout-tick-mismatch`: `error.tick` 25 ≠ 26 → `[error.json:tick]`.
Events fixtures: `valid/events-intent-before-trace.ndjson` (trace 0, intent 26, trace 26) → `[]`; `invalid/events-trace-before-intent.ndjson` (trace 0, trace 26, intent 26) → `[events[2]]`. All nine trials and both events fixtures produce exactly one path, matching `INDEX.json`. `protocol.test.js:84-88` and `:141-145` compare the full path array to a one-element array, so any second error or a different path fails the test.

**5. Protocol string and message shapes.** Unchanged, see DoD 5 row. The `protocol.mjs` diff against base is confined to `validateEvents` (`:443-447, :476-482`) and the new block at `:588-601`; every export, constant and shape map is identical.

### Boundary and receipts

Change set per `12-check-scope.txt:8-58`: 50 paths, all under `tools/jev-player/protocol/**` and `tools/jev-player/tests/protocol.test.js`, matching the card's files-touched (`BACKLOG.md:5466`); no Godot code, no harness, no `decide.mjs` change. No existing fixture file is in the change list, so JL-09's future byte-for-byte copy is unaffected by anything but additions. `PROTOCOL.md:164` (any new rule is v2) is technically in tension with adding enforcement of an already-documented rule; the equal-tick rule was in the base doc at `:93`, so this is enforcement, not a new rule.

Receipts read, not re-run: `10-npm-test.txt` 318 pass / 0 fail, `head: 15b1be2` (`:323-332`); `16-verify.txt` six PASS stages with head (`:6-25`); `11-npm-verify.txt` same six stages, no head line; `12-check-scope.txt` base `bdf0bb6`, required commands check:docs, check:project, check:drift, verify (`:59-63`); `13` check:docs 0 failures with head; `14` check:project pass with head; `15` check:drift 0 mismatches with head. The revert-and-rerun receipt named in the packet is absent (finding 1).

### Suggested disposition

Admit. Carry findings 2–4 as a one-line doc touch on whichever card next edits `PROTOCOL.md` (JL-09 is the natural place, since its implementer is the reader who would hit them); carry finding 5 to JL-21. Record finding 1 as a receipt gap with the hand-trace above as the substitute evidence, or ask the writer to attach the missing file.
