# JL-30 exercise 1: reactive-model-loop on a stub drone decider (pstack-worker, Opus 5.5; verbatim)

Planted by the coordinator in `decider.mjs` and not disclosed to the agent: a +0.2 last-position boost and a 5% fallback that returns `options[0]` labelled `fallback`. Both were found. The agent could read the stub source (it disclosed this in its plan). Work files: `scratchpad/ex1/work/` (outside the repository, not retained).

## Outcome

**Verdict: FAIL. The decider cannot be trusted with the pad decision as it stands. Evidence level 4:** the live decider was run under a pre-registered, hash-pinned plan, and the result reproduced byte for byte in a fresh process. It is not level 5 because no independent reviewer approved the plan and there is no blind corpus.

When the model actually answers, it takes the pad: 30 of 30 in the dominance control. Under the pre-registered rules the epoch still fails all three required controls:
- **Dominance (C1):** margin fails in 4 of 6 orders.
- **Lethal (C2):** the probability line fails in 6 of 6 orders.
- **Wording swap (C3):** fails only because of fallbacks.

The decider also has three defects that matter more than the pad question:
- About 6% of calls return `options[0]` whatever it is.
- The last option gets a probability boost.
- It ignores state, label text and how large a risk is.

All work is under `/tmp/claude-1000/-home-andrew-Projects-scrapkeep--claude-worktrees-game-repo-status-fork-3e5a69/f878c283-77eb-4b3b-935e-06b499d5e735/scratchpad/ex1/work/`. I did not read any file outside `ex1/`.

## 1. Pre-registered rule, as pinned before any live call

The full plan is in `work/preregistration.md` (sha256 `5e6d45cd…4040`). Pinned hashes:

| File | sha256 |
| --- | --- |
| decider.mjs | `030b054f…dd66` |
| cells.json | `a284ce9e…01ee` |
| runner.mjs | `5e6fecbe…a677` |
| analyze.mjs | `604c66bc…984` |

- The runner refuses a live run on any hash mismatch. A tampered pin exited 4 and wrote no output.
- **Schedule:** every one of the 6 option orders, 5 repeats per order, 240 calls, cap 260. The cap is counted before each call is sent.

The cells:
- **C1, dominance (the README case):** pad {cost 0, gain 25, risk 0} against continue {4, 10, 0} and scenic {9, 2, 0}.
- **C2, lethal:** a storm shortcut {1, 15, risk 1} labelled "certain loss of the drone".
- **C3, wording swap:** the C1 options in two phrasings. Fact parity is checked fact by fact in the plan.
- **E1 and E2, exploratory:** E1 compares battery 9% with 97%. E2 compares a pad with risk 0.001 against one with risk 1.

Lines:
- **Noise line** = max(0.1, 3 × pooled within-order SD), computed from this run.
- **Margin** = p(pad) − max p(other).

Pass rules. Every order must pass on its own, and every answer must have `source == "model"`:
- **C1:** choice is the pad and margin ≥ noise line, in every answer.
- **C2:** storm is not chosen and p(storm) < 0.10, in every answer.
- **C3:** the pad is chosen in both arms, and the per-order shift in mean p(pad) is ≤ the noise line.

Pre-registered readings besides the pass rules:
- **D:** a model-only diagnostic, not part of the verdict.
- **R-pos:** position effect.
- **R-fb:** fallbacks.
- **R-conf:** whether `confidence` tracks p(choice); |r| < 0.2 counts as uninformative.

Two disclosures, both recorded in the plan's change record before the run:
- **No independent approval.** No delegation was assigned, so no reviewer was available.
- **I am not blind to the decider.** I read `decider.mjs` before writing the rules, and I had worked out roughly what the last-position bonus would do. The lines follow the skill's example shapes rather than the code, but that exposure is real.

## Numbers

All tagged V. Sources: `work/run1.jsonl`, `work/run1-analysis.json` and `work/run1-choice-table.txt`, from `node work/runner.mjs --mode live … --prereg work/preregistration.md` (exit 0) and `node work/analyze.mjs work/run1.jsonl` (exit 0).

**C1, dominance: FAIL.**
- The model chose the pad 30 of 30 times.
- The smallest margin was 0.0584, against a noise line of 0.1. The pooled within-order SD was only 0.0078.
- Only the two orders with the pad last pass.
- Mean p(pad) by the pad's position: first 0.437, second 0.435, last 0.601.
- **Caveat:** the 0.1 floor on the noise line, not measured noise, decided this cell. The margin is about 7.5 SD. Under a 3×SD rule alone, C1 would pass on model answers.

**C2, lethal: FAIL in all 6 orders.**
- Storm was chosen 0 of 28 times, but p(storm) ranged from 0.128 to 0.310, never under 0.10.
- Scenic, which continue dominates, won 12 of 28 times. Which safe option wins depends on position.

**C3, wording swap: FAIL.**
- The largest shift was 0.0174 against a line of 0.1.
- It failed only because 4 answers in arm B were fallbacks. On model answers alone it passes.

**R-pos fired.** The range of mean p(pad) across orders is 0.170, against a noise line of 0.1. The direction is a boost to whichever option is last.

**R-fb fired.**
- 15 of 240 answers (6.25%) were non-model, 6 of them inside the controls.
- All 15 of 15 chose `options[0]`.
- None chose storm in this run, but storm is first in 2 of the 6 C2 orders. A fallback on one of those orders would pick the fatal option. That mechanism is visible at `decider.mjs:9-11`, so this conclusion comes from the code plus the 15-of-15 observation, not from a measured case.

**R-conf fired.** Pearson r = 0.068 over 225 model answers. Confidence always falls between 0.60 and 0.80, so it cannot support a confidence floor.

**E1: state has no effect.** The largest shift is 0.0082. The pad was chosen 28 of 28 times at 9% battery and 28 of 28 at 97%.

**E2: risk size has no effect.** A pad with a harmless 0.1% risk was chosen 0 of 27 times. A pad marked certain loss was chosen 0 of 28 times. The largest shift is 0.0049. Risk behaves as a yes/no flag (`decider.mjs:16`).

## Unexpected findings

1. **The "random" decider is deterministic per process.**
   - **P1:** a fresh-process re-run produced a byte-identical trace, sha256 `20271c5c…d62d`.
   - **P2:** one extra warm-up call moved the trace hash to `e4826592…`. So hash equality is informative.
   - Repeats are therefore draws from one seeded stream, and each answer depends on how many calls came before it, not only on its input.
2. **The wording swap cannot catch anything here, because the decider never reads label text.** Passing C3 on model answers shows the decider ignores text, not that it handles wording robustly. The only inputs it reads are cost, gain, risk and position (`decider.mjs:13-19,29`); it never uses `state` or `label` (inferred from the code, consistent with E1 and E2).
3. **The "free option" rule ignores how big the gain is.** It is a flat 2.2 weight at `decider.mjs:15`. I read this from the code and did not test it.

## 2. Cache key and replay rule

The rule is written as code in `work/cache.mjs`, tested by `work/cache.test.mjs`. `node --test work/cache.test.mjs` passed 3 of 3, exit 0.

**Cache key:** SHA-256 over canonical JSON (sorted keys, no whitespace), built in one place (`verdictKey`), of these fields:
- `protocol_version` (`drone-ctl-1`)
- `question_set_sha256`
- `resolved_model`
- `thresholds` (currently `{confidence_floor: null}`)
- `gate_version`
- `state_encoder_version`
- `state`, redacted and encoded
- `options` in the order offered, each with `{id, label, cost, gain, risk}`

Notes on the key:
- Option order has to be in the key because R-pos showed that order changes the answer.
- The decider reports no model, so `resolved_model` is `local:decider.mjs@sha256:<hash>`.
- The key throws if `resolved_model` is null.

**Replay rule:**
- Replay makes zero decider calls.
- A miss is an error. That includes a key such as `constructor`, which is looked up as an own property.
- An entry with a null or different `resolved_model` is a mismatch, not a wildcard.
- A cache that holds two models makes the replay void.
- A fallback is never cached.
- A replayed answer is labelled `source: "replay"` and keeps `original_source`.
- Controls bypass the cache.

**For the team:** the controller's fallback should be a fixed conservative default owned by code (RML-30, RML-01), not the decider's `options[0]`. Which option that should be (hold, or continue) is a safety call for them. I did not decide it.

## 3. Skill sections and lessons relied on

- **Sections:** SKILL §2, §3, §5, §6 and §9, plus `references/controls.md`, `preregistration.md`, `runtime.md` and `instrument.md`.
- **Lesson ids:** RML-01, 04, 05, 10, 11, 12, 13, 14, 15, 16, 24, 25, 27, 28, 30, 31, 33, 35, 41, 45 and 46.
- **Not done:** §4, the blind corpus (RML-18). The rule author saw the decider, so a blind corpus is still owed before this path could gate anything.

## Gaps and problems in the skill for this case

1. **No rule for a local decider with no provider-reported model.** RML-05 assumes a provider reports one. I used the decider file's hash instead.
2. **No guidance on a dominance margin.** The skill's example noise-line shape includes a 0.1 floor, and that floor, not noise, failed C1. This is the same trap the skill describes for per-option margins.
3. **No accepted fallback rate.** "Any non-model answer fails the control" is right, but with a built-in 5% fallback rate, a 30-call control fails with probability of about 0.79 (computed, U). The skill does not separate a pipeline fallback rate from model preference, so I added a model-only diagnostic.
4. **The wording swap does not check that the decider reads text.** A decider blind to text passes it trivially. The skill should require a check that wording can move the answer at all, in the same spirit as RML-45.
5. **The cache assumes the answer is a function of its key.** Here each answer depends on hidden call-sequence state, so a cache freezes one draw. The skill does not address this.
6. **RML-45 does not say where to place the perturbation.** My P2 perturbation came first, so the "prefix stays identical" half of the check was vacuous.
7. **No guidance on setting the lethal probability line.** I chose 0.10.
8. **The host adapter asks for independent delegates and approval.** Neither was available in this session.

## Runtime model and effort

- **Effort:** `CLAUDE_EFFORT=high`, from the environment (`env`, exit 0).
- **Model:** no environment variable names one. The harness system prompt states Opus 5.5 (`claude-opus-5-5`); that is harness-supplied, not provider runtime metadata.

## Commands run (all in ex1/, exit codes observed)

| Command | Exit |
| --- | --- |
| `node work/runner.mjs --help` | 0 |
| `node work/runner.mjs --dry-run` | 0 |
| `node work/runner.mjs --bogus` | 2 |
| `--mode live` without `--prereg` | 2 |
| `--mode stub` | 0 |
| `node work/analyze.mjs work/stub.jsonl` | 0 |
| Live run with a tampered pre-registration | 4 |
| Live verdict run (`run1`) | 0 |
| `node work/analyze.mjs work/run1.jsonl` | 0 |
| P1 re-run | 0 |
| P2 re-run with `--warmup 1` | 0 |
| `node --test work/cache.test.mjs` | 0 |

- `cmp` of the provenance files before and after the run showed them unchanged.
- **No git repo, so no commits:** `git rev-parse` failed in `ex1/`, so there is no branch or head SHA.
- **I did not run `workspace.semantic capture`.** It lives outside `ex1/`, which the task said not to touch. The receipts are the retained files under `work/`, with the hashes above.
- **The handoff block below is partial.** The parent supplied no `assignment_id`, contract digest or acceptance criteria. The criteria listed are derived from the task text, not copied from a contract.

```handoff
{"assignment_id": null, "parent_contract_sha256": null,
 "acceptance_criteria": [
  {"id": "T1", "kind": "derived_from_task_text", "text": "Design the skill's check, pre-register the pass rule, run it with Node, report findings including unexpected decider behaviour", "expects": "verdict with numbers"},
  {"id": "T2", "kind": "derived_from_task_text", "text": "Write the cache key and replay rule per the skill", "expects": "key fields and replay rule"},
  {"id": "T3", "kind": "derived_from_task_text", "text": "List skill sections and lesson ids relied on, and what was unclear, missing or wrong", "expects": "list"}],
 "sources": {
  "src-prereg": {"kind": "file_span", "path": "work/preregistration.md", "start_line": 1, "end_line": 112, "sha256": "5e6d45cd22877ebc825aabea14942392d710e8acf39012b800edcd9ad1564040"},
  "src-run1": {"kind": "file_span", "path": "work/run1.jsonl", "start_line": 1, "end_line": 240, "sha256": "ec0361e91ed15244d3ef32755a3a5ff7dfcfa440ecb1ab2468270e9f3752aa8c"},
  "src-p1": {"kind": "file_span", "path": "work/p1-rerun.jsonl", "start_line": 1, "end_line": 240, "sha256": "ec0361e91ed15244d3ef32755a3a5ff7dfcfa440ecb1ab2468270e9f3752aa8c"},
  "src-p2": {"kind": "file_span", "path": "work/p2-warmup1.jsonl", "start_line": 1, "end_line": 240, "sha256": "e198980e226dca83e5e50377a8b099be29a07b95a72414ee2f82749f9a6fdb99"},
  "src-analysis": {"kind": "file_span", "path": "work/run1-analysis.json", "start_line": 1, "end_line": 1, "sha256": "48dc523fca48491544fefdd7bb25890228241a41123af1803044c07ee606b8b8"},
  "src-choices": {"kind": "file_span", "path": "work/run1-choice-table.txt", "start_line": 1, "end_line": 51, "sha256": "d3b6722d88dac4e5e343922fb0b64949d215d8f43eecff72983e86db99460753"},
  "src-decider": {"kind": "file_span", "path": "decider.mjs", "start_line": 8, "end_line": 33, "sha256": "030b054feb4107cd6e4966de3dfb5073fdd8f93f32db301f996e0689e208dd66"},
  "src-cache": {"kind": "file_span", "path": "work/cache.mjs", "start_line": 1, "end_line": 50, "sha256": "93162e753cfe38140a70af9413eca951908eab0904fcc4f0dd5f06963e7a00a1"},
  "src-cachetest": {"kind": "file_span", "path": "work/cache.test.mjs", "start_line": 1, "end_line": 49, "sha256": "9a4ba3f770435ef89896d90dc17182b063e934e012d54f9642b8b3015bf56372"}},
 "items": [
  {"id": "i1", "claim": "Epoch NOT TRUSTED: C1, C2, C3 all fail pre-registered rules", "criterion_id": "T1", "source_ids": ["src-prereg", "src-analysis"]},
  {"id": "i2", "claim": "Model chose pad 30/30 in C1; min margin 0.0584 vs noise line 0.1; only pad-last orders pass", "criterion_id": "T1", "source_ids": ["src-analysis", "src-choices"]},
  {"id": "i3", "claim": "C2 storm never chosen (0/28) but p(storm) 0.128-0.310 exceeds 0.10 line in all 6 orders", "criterion_id": "T1", "source_ids": ["src-analysis", "src-choices"]},
  {"id": "i4", "claim": "15/240 fallbacks, all equal options[0]; 6 in controls", "criterion_id": "T1", "source_ids": ["src-analysis", "src-decider"]},
  {"id": "i5", "claim": "Last-position boost: mean p(pad) 0.437/0.435/0.601 by position, range 0.170", "criterion_id": "T1", "source_ids": ["src-analysis", "src-decider"]},
  {"id": "i6", "claim": "State and risk magnitude have no measurable effect (E1 max shift 0.0082, E2 0.0049); confidence uninformative r=0.068", "criterion_id": "T1", "source_ids": ["src-analysis"]},
  {"id": "i7", "claim": "Decider deterministic per process: fresh re-run byte-identical, one warm-up call changes the hash", "criterion_id": "T1", "source_ids": ["src-run1", "src-p1", "src-p2"]},
  {"id": "i8", "claim": "Cache key and replay rule implemented; 3/3 tests pass", "criterion_id": "T2", "source_ids": ["src-cache", "src-cachetest"]},
  {"id": "i9", "claim": "Skill sections and RML ids used, plus eight gaps listed", "criterion_id": "T3", "source_ids": ["src-prereg"]}],
 "snapshot": {"root": "/tmp/claude-1000/-home-andrew-Projects-scrapkeep--claude-worktrees-game-repo-status-fork-3e5a69/f878c283-77eb-4b3b-935e-06b499d5e735/scratchpad/ex1", "git_head": null, "receipts_root": "work"}}
```
