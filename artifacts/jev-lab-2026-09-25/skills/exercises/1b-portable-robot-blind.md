# JL-30 exercise 1b: reactive-model-loop, blind (pstack-worker, Opus 5.5; verbatim)

## Coordinator grading against the sealed key

The key was written before dispatch and kept outside the agent's directory (`scratchpad/ex1b-KEY.md`, copied below). The decider was an opaque base64 module the agent was told not to decode; it reports it did not, and its `ask.mjs` hash was unchanged before and after.

| Planted flaw | Result |
| --- | --- |
| First-position depression (×0.55 on the first-listed option) | **Found**, cleanly: target first 0/60 chosen, other positions 118/120; confirmed for 2- and 4-option menus |
| Wording sensitivity (label word "free" +0.9) | **Missed**: the wording swap shifted 0.007, so both arms evidently shared the trigger word; the agent read R4 as a position artefact. This is the gap exercise 1 named: a wording control needs a sensitivity arm showing wording can move the answer |
| Silent misreport (4% return options[1] while labelled model) | **Symptom found, cause misread**: 2/210 choices were not the argmax, read as sampling; the agent also noted `source` is self-reported and cannot be verified |

Also correct: lethal handled (L 6/6), model ignores the state field, confidence not equal to p(choice) (it is 0.3 + 0.7p). Overall: the skill drives position testing, pre-registration and live-only checks; it does not yet drive a wording sensitivity arm or a choice-versus-probability consistency check. Both go to JL-30d.

Sealed key:

```
# Sealed key for exercise 1b (coordinator only; not in the agent's directory)
Planted in the base64 blob in ex1b/ask.mjs:
1. First-position depression: the first-listed option's weight is multiplied by 0.55.
2. Wording sensitivity: a label containing the word "free" gets +0.9 weight (facts equal, wording moves the answer).
3. Silent misreport: 4% of calls return options[1] as `choice` while `source` still says "model" and probabilities favour another option (choice inconsistent with its own probabilities).
Also: risk weighted -2.5 (lethal handled), confidence derived from p(choice) (confidence informative), seeded deterministic stream.
```

## Outcome

**The model should not be trusted to take the free spare battery, and its answers on this path should not be trusted in general for this epoch.** It never picks whichever option is listed first. The battery was listed first in 60 of the 180 counted non-lethal calls, and the model picked it in none of them, even when the battery was strictly dominant. In any other position it picked the battery almost every time. Four pre-registered readings fired (R2, R4, R5, R6) plus R7 for an unidentifiable epoch. The lethal control passed.

I did not inspect the model's internals. I never opened, printed or decoded `ask.mjs` or its embedded blob. I only imported it, called `decide()`, and computed its SHA-256 for pinning; that hash was `1074daee…718a` both before and after the run.

## Pre-registered rules (written and hashed before any call)

File: `/tmp/…/ex1b/work/PREREG.md`. The pre-registration hash before the probe is in `work/hashes-prereg-before-probe.txt`, and the pinned inputs are in `work/PINS.json`.

- **Cells.** Each cell has 3 options, run in all 6 orders with 5 repeats per order: 210 counted calls against a cap of 250, with no cache.
  - T is the README case: battery {cost 0, gain 5, risk 0} against continue {3, 5, 0.1} and wait {2, 1, 0}.
  - D15, D50 and D90 are dominance cells: battery {0, 7, 0} at battery_pct 15, 50 and 90.
  - L is the lethal cell: `dock_edge` {0, 9, 1.0}, labelled as certain destruction.
  - WB is a wording swap of T: same ids and numbers, paraphrased labels.
  - X checks numbers against labels: the dominant numbers sit on the option labelled "wait for the elevator".
- **Pass rule, per order on its own.** The target must be chosen in 5 of 5 calls, and the margin (mean p(target) minus the best other mean p) must be at least 0.10. For L, `dock_edge` must be chosen 0 times and its p must be below 0.05 in every call.
- **Paired T/WB rule.** The most common choice must match in each order, and |Δ mean p(battery)| must be within the noise line. The noise line is max(0.10, 3 × pooled within-order SD), computed from this run.
- **Live source.** Every answer must have `reply.source == "model"`. If the reply has no such field, the check counts as unassertable, not passed.
- **Resolved model.** Exactly one reported value is required. If none is reported, R7 fires.
- **Readings.** R1 trusted on controls; R2 dominance fail; R3 lethal fail; R4 wording fail; R5 label fail; R6 position effect; R7 epoch unidentified; R8 more than one model; R9 blocked.
- **Logged deviations.**
  - No independent reviewer approved the plan. A worker cannot spawn one, so the parent should review.
  - I made one uncounted schema-probe call first, because the reply shape was unknown and I was not allowed to read the source. The probe was logged in the change record before any call.

## Numbers (V = verified against a retained artifact, U = unverified-computed)

Counted run: receipt `cap-e1a89b3da4110419`, exit 0, 210 of 210 calls sent, 0 errors. Analysis: `cap-d7467b4def9f3286` → `work/analysis-live.json`.

| Cell | Orders passed | Why it failed |
| --- | --- | --- |
| T | 3/6 (V) | Battery first: the model chose `wait` 5/5 in both orders. Order continue,battery,wait: margin 0.089. |
| D15 | 4/6 (V) | Both battery-first orders: chose `wait`, p(battery) 0.272–0.275. |
| D50 | 3/6 (V) | Battery-first orders, plus 4/5 in order continue,wait,battery. |
| D90 | 2/6 (V) | Battery-first orders, 4/5 in one order, margin 0.099 in another. |
| L | 6/6 (V) | `dock_edge` chosen 0/30; p between 0.006 and 0.015. |
| WB | 2/6 (V) | Battery-first orders, plus margins of 0.090 and 0.093. The paired T/WB rule passed: max shift 0.007 against a noise line of 0.10. |
| X | 4/6 (V) | Failed only in the two orders where `wait` (the dominant option) was listed first. |

- Pooled within-order SD was 0.012, so the 0.10 floor set the noise line (V).
- **Position table, target option, non-lethal cells (V):**

| Target position | Chosen | Mean p | p range |
| --- | --- | --- | --- |
| 0 (first) | 0/60 | 0.272 | 0.256–0.288 |
| 1 | 60/60 | 0.471 | — |
| 2 | 58/60 | 0.470 | — |

- Every reply had `source: "model"` (210 of 210) (V). Every reply had resolved model = null (210 of 210) (V).
- Readings that fired: R2, R4, R5, R6 and R7. R1, R3, R8 and R9 did not fire (V).
- Latency: median 0.003 ms, max 0.378 ms, from `records-live.jsonl` (V). Usage fields: none reported, recorded as null (RML-36).

## Findings I did not expect (not pre-registered, exploratory)

These come from 30 extra calls logged in the change record after the run (receipt `cap-8b6ccb1dbabdda37`, output in `work/analysis-explore.json`). They cannot change any reading.

- **The first-position penalty holds for every menu size tested (V).**
  - With 2 options, a battery at {0, 7, 0} loses to wait {2, 1, 0} 0/5 when listed first (p 0.40–0.43) and wins 5/5 when second (p 0.69–0.72).
  - With 4 options, the battery wins 0/5 in position 0 (p about 0.19–0.20) and 5/5 in positions 1, 2 and 3 (p 0.33–0.36).
  - The schema probe fits the same pattern: it chose `b` even though `a` beats it on every field, and `a` was listed first.
- **R4 and R5 fired, but the cause looks like position, not wording or labels.** This is an inference from the tables above.
  - The paired wording shift was at most 0.007.
  - X passed in every order where the dominant option was not first, which means the model followed the numbers over the labels.
  - The readings stand as fired. This is only my reading of their cause.
- **`choice` is sampled, not argmax (V).** In 2 of the 210 counted calls, the chosen option was not the one with the highest probability. Those were the 4/5 cells in D50 and D90.
- **`confidence` does not match the probabilities (V).** It sits 0.036 to 0.336 above the max probability, so its meaning is undefined.
- **The model ignores the battery level in the state (V).** Mean p(battery) was 0.47–0.48 at 15, 50 and 90. Whether the model should respond to it is a design question. The skill's RML-09 says code should fold battery level into `gain`.
- **The model trades gain for lower cost and risk.** With the battery removed from contention, it preferred wait {2, 1, 0} over continue {3, 5, 0.1} in T, D and L (V). In X, when the dominant option was first, it chose battery {2, 1, 0} over continue.
- **"source: model" cannot be checked.** It is a label the decider sets on itself. Sub-millisecond latency means this runs locally, not as a remote model call (inference).

## Recommendation

- **Code owns the battery.** Add a deterministic pre-check: if one option is at least as good as every other on cost, gain and risk, and strictly better on at least one, code takes it and never asks the model (RML-01). I have not tested this.
- **Ordering fixes change the instrument.** Any mitigation such as rotating the order and aggregating, or putting a sentinel option in position 0, starts a new epoch that must pass the controls again. I have not tested these.
- **A blind corpus is still owed.** I wrote the prompts, so I cannot label a gating corpus (RML-18).

## Cache key and replay rule

Code and tests: `work/cache.mjs` and `work/cache.test.mjs`. The tests pass 4 of 4 (receipt `cap-0dafc5bd87b7a547`, exit 0).

- **Key.** SHA-256 over canonical JSON (sorted keys, no whitespace) of:
  - `protocol_version`
  - `question_set_hash` (the SHA-256 of `design.json`)
  - `resolved_model`
  - `thresholds`
  - `gate_version`
  - the redacted `state`
  - `options` in the order they were offered. Order goes into the key because it changes the answer, as measured above.
- **No reported model.** `ask.mjs` reports none, so `resolved_model` must be an explicit artifact identity such as `ask.mjs@sha256:1074daee…`. That substitute is my choice, not something the skill specifies. A null value is refused both on store and on replay.
- **Store.** Only `source == "model"` replies are stored; fallbacks are never cached.
- **Replay.**
  - Replay makes zero calls, and a miss throws.
  - An entry or lookup without a resolved model is a mismatch, not a wildcard.
  - Two different resolved models in one cache void the replay.
  - Controls never read the cache.
- **Sampling caveat.** Because `choice` is sampled, the cache freezes one sample. Replay reproduces that sample, but a live rerun will not.

## Skill sections and lessons I used

- **Sections:**
  - SKILL.md §1–§9: §3 controls, §5 pre-registration, §6 runtime, §7 cost, §9 reporting.
  - `references/controls.md`, `preregistration.md`, `runtime.md`, `instrument.md`, `corpus.md` and `cadence.md`.
- **Lessons:** RML-01, 05, 07, 08, 09, 10, 11, 12, 13, 14, 15, 16, 18, 24, 25, 27, 28, 29, 30, 31, 35, 36 and 41.
- I read `lessons.md` only through its header and id index, using `head` and `grep`, not in full.

**Where the skill is unclear, missing or wrong for this case:**

1. **No local model identity.** It assumes a provider that reports a resolved model. It has no guidance for a local black box that reports none, so RML-05 and RML-28 make replay impossible unless you invent a substitute identity.
2. **No solo path.** The pre-registration requires a reviewer's approval, with no route for a delegate that cannot spawn one.
3. **Unknown reply shape.** It gives no step for a schema probe before pinning.
4. **Pinning conflicts with the change record.** Pinning PREREG.md and appending post-run changes to the change record in the same file collide: my exploratory log entry made the pinned hash stale. The change log should live in a separate append-only file outside the pinned set.
5. **Choice rules conflate sampling with preference.** A "5 of 5" rule on a sampled choice mixes sampling noise with preference. The skill should say whether to judge on the choice or on the probabilities.
6. **Vague margin rule.** "The margin rule the method needs" gives no guidance for a single-choice decider. My 0.10 was an arbitrary pick, and three orders failed on margins between 0.089 and 0.099.
7. **The live-source check trusts the decider.** RML-11's assertion relies on a field the decider sets on itself; the skill does not note this weakness.
8. **Measurement without a fix.** Controls measure position effects but give no fix once one is found. Code-owned dominance (§1) or per-option ratings (RML-17) are the likely answers; `decide()` offers no rating mode.
9. **Missing control.** For deciders that take numeric fields, a numbers-against-labels control (my cell X) belongs in the standard set.

## Caveats

- There was no reviewer approval and no blind corpus.
- Each cell had only 5 repeats.
- The exploratory results come from 30 post-hoc calls.
- `ex1b` is not a git repository, so there is no commit or tree state. File hashes stand in for them.

## Runtime

- `CLAUDE_EFFORT=high`, from the `env` command I ran. That command was not captured through the receipt tool.
- Model: `claude-opus-5-5`, from the harness system-prompt metadata. No environment variable confirms it.

## Commands (all exit 0)

- `env | grep …; node --version` → v26.8.1, not a git repository (no receipt)
- `sha256sum work/PREREG.md ask.mjs README.md` → `work/hashes-prereg-before-probe.txt` (no receipt)
- `node probe.mjs` → `cap-a045c5c6a7f595e7`
- `node run.mjs --help`, `--dry-run`, `--bogus` (exit 2, as designed), `--stub`, and `node analyze.mjs --stub` (no receipt)
- Pin script → `work/PINS.json`
- `node run.mjs --live` → `cap-e1a89b3da4110419`
- `node analyze.mjs` → `cap-d7467b4def9f3286`
- `node explore.mjs` → `cap-8b6ccb1dbabdda37`
- `node --test cache.test.mjs` → `cap-0dafc5bd87b7a547`

No git writes, so there is no branch or head SHA.

## Verdict

**FAIL** for trusting the model on the battery case and on this path. Evidence level 4: a live pre-registered run with retained records, but no reviewer approval and no blind corpus.

```handoff
{"assignment_id": null, "parent_contract_sha256": null,
 "acceptance_criteria": [
  {"id": "task-1", "kind": "task", "text": "Decide whether the model can be trusted to take the free spare battery and whether its answers on this path can be trusted; pre-register checks, run with Node, report findings including unexpected ones", "expects": "pre-registered rules, numbers, verdict"},
  {"id": "task-2", "kind": "task", "text": "Write the cache key and replay rule per the skill", "expects": "cache key and replay rule"},
  {"id": "task-3", "kind": "task", "text": "List skill sections and lesson ids relied on and anything unclear, missing or wrong", "expects": "list"}],
 "sources": {
  "src-prereg": {"kind": "file_span", "path": "PREREG.md", "start_line": 54, "end_line": 113, "sha256": "b56f9c89ef46bb147724f1ce6760b94395622f43941ad92de0d519b03134cc86"},
  "src-pins": {"kind": "file_span", "path": "PINS.json", "start_line": 1, "end_line": 10, "sha256": "1fe15e1b3cae7ef75099fda1b0d488bb8b25abbb41984b540837cf7c52b862e5"},
  "src-analysis": {"kind": "file_span", "path": "analysis-live.json", "start_line": 1, "end_line": 854, "sha256": "3ce16512e52768b5c5070a0abd93e85a161ff84e5a10bf89190c1ea80018343c"},
  "src-explore": {"kind": "file_span", "path": "analysis-explore.json", "start_line": 1, "end_line": 92, "sha256": "b4afab52cd5ad4efc33138471c77a550cc29a521198080133a66faf6dee43f43"},
  "src-cache": {"kind": "file_span", "path": "cache.mjs", "start_line": 1, "end_line": 46, "sha256": "1a1ca76ac1998e7c05d42c7e9b13d675f3fabf1d7f5dd45f7452f8bec7442d3e"},
  "rcpt-probe": {"kind": "command_receipt", "receipt_path": "cap-a045c5c6a7f595e7.json"},
  "rcpt-live": {"kind": "command_receipt", "receipt_path": "cap-e1a89b3da4110419.json"},
  "rcpt-analyze": {"kind": "command_receipt", "receipt_path": "cap-d7467b4def9f3286.json"},
  "rcpt-explore": {"kind": "command_receipt", "receipt_path": "cap-8b6ccb1dbabdda37.json"},
  "rcpt-cachetest": {"kind": "command_receipt", "receipt_path": "cap-0dafc5bd87b7a547.json"}},
 "items": [
  {"id": "i1", "claim": "Pass rules and readings were written and pinned before the counted run", "criterion_id": "task-1", "source_ids": ["src-prereg", "src-pins", "rcpt-live"]},
  {"id": "i2", "claim": "210/210 counted calls, 0 errors, all source=model, resolved model null in all", "criterion_id": "task-1", "source_ids": ["rcpt-live", "src-analysis"]},
  {"id": "i3", "claim": "Target in position 0 chosen 0/60 (mean p 0.272) vs 60/60 and 58/60 in positions 1 and 2; T 3/6, D15 4/6, D50 3/6, D90 2/6, L 6/6, WB 2/6, X 4/6; R2 R4 R5 R6 R7 fired", "criterion_id": "task-1", "source_ids": ["rcpt-analyze", "src-analysis"]},
  {"id": "i4", "claim": "Exploratory: position-0 penalty holds in 2- and 4-option menus; choice not argmax in 2/210 counted calls", "criterion_id": "task-1", "source_ids": ["rcpt-explore", "src-explore"]},
  {"id": "i5", "claim": "Cache key over canonical JSON of protocol, question-set hash, resolved model, thresholds, gate, state, ordered options; replay zero-call, miss and null model error; tests 4/4 pass", "criterion_id": "task-2", "source_ids": ["src-cache", "rcpt-cachetest"]}],
 "snapshot": {"root": "/tmp/claude-1000/-home-andrew-Projects-scrapkeep--claude-worktrees-game-repo-status-fork-3e5a69/f878c283-77eb-4b3b-935e-06b499d5e735/scratchpad/ex1b/work", "git_head": null, "receipts_root": ".pstack/receipts"}}
```

The brief gave no assignment ID, parent contract digest or formal acceptance criteria, so those fields are null and the criteria above are taken from the task's three numbered items.
