<!-- Retained verbatim. JL-18c-A1 Phase A pre-registration review by scrapkeep-reviewer (runtime claude-fable-5-1 per host prompt) on candidate c8aec3c, 2026-09-25, before any live call. -->

# JL-18c-A1 Phase A pre-registration review: APPROVE+NOTES

**Evidence level:** source review of every file in the packet at `/home/andrew/Projects/scrapkeep-wt-JL-18c` (head per `artifacts/local/tasks/JL-18c/receipts-c8aec3c/head.txt:1` = c8aec3ca182d3f59e01714de829e81ac05e04609), the full dry-run output, the JL-18 review, the JL-15/JL-18 live records, BACKLOG:5849-5873, ORCHESTRATOR:78-94, `decide.mjs`, `c2.json`, `q2-neutral.json`. I ran no commands and computed no hashes. Every `npm test`, `npm run verify`, `check:*` and dry-run outcome below is a coordinator-supplied receipt, labelled as such. I did not open `corpus-blind.json`, its PROVENANCE, `blind-diagnostic.json`, any `reviews/JL-04*` or `JL-18b*`, or TRACKING.md.

No defect would make the run uninterpretable or tunable after the fact. One decision (N1) should be made explicitly before the first call; the default is to run as written.

## 1. Do the designs separate what they claim?

**a. Position × repeats.** Yes. c2's two states verbatim (test `tests/jl18c.test.js:130-137`, receipt `npm-test.txt:400` pass), six permutations × 3 (`run.mjs:69-74,91-97`; test `:63-76`). Per-position P is reported (`run.mjs:273-284`) and the every-order rule is kept (`:315`), so position is measured, not averaged away. Matches JL-18 review § 6 design (1) (`reviews/JL-18.md:60`).

**b. Comprehension Nouls.** Yes for stated items: the body carries the option text, one yes/no question and the state, no rules (`questions.json:9`; dry-run line 38 for b-lethal confirms no "The rules:"; test `:213`). The state is present in the body, so "reading of that text alone" (PREREGISTRATION.md:61) is slightly overstated; harmless for stated items, which depend only on the quoted text. Implied items (`ram_target__ends_run`, which needs 8 HP and the "0 health ends the run" clause that is in the option text) are correctly excluded from the read verdict (`run.mjs:392`; Known limits :192).

**c. 2×2.** The four cells (a-free-cache, c-no-objective, c-free-cache-two, c-no-objective-two) form a proper objective-named × sibling-present square, and the share metric (`run.mjs:402-408`) puts two- and three-option cells on one scale. Two residuals, both already acknowledged and correctly scoped in the readings:
- The q2 rules preamble still says "The stage is cleared by holding a 60 second exit charge at the exit" in every c-cell (dry-run line 54; PREREGISTRATION.md:42). So "framing" tests removing the objective from state + id + text, not the exit's existence. The outcome row at :145 says exactly that. Fine.
- c-no-objective changes three things together (state key, option id, option text). It cannot say which carrier matters; the JL-18 review § 6 (3) proposed the bundle, and the reading names all three. Fine for a lead.
- The test at `jl18c.test.js:163-167` checks the word "objective" only in the c-cells, not b-no-objective or e-no-objective; the pre-reg :42 says "no body in the no-objective cells". By inspection of `questions.json:5,9` and `states.json:69-95` neither template nor state contains the word, so the claim holds; the test is narrower than the sentence. Cosmetic.

**d. Dominance probes.**
- `d-named-buff` changes one phrase (`states.json:114` vs `:22`), but that phrase changes two things: random → named, and it reveals a modest, specific buff (+20 max HP at 82 HP) while the rules still promise "one random buff" (Known limits :195). A positive lift reads cleanly as "random reward" (:147); a null or negative lift is ambiguous between "random discount" and "Jev values +20 max HP low". The pre-reg only fires the reading on positive lift, so this is one-sided, not confounded. Lead only, not a verdict cell.
- `d-free-heal` changes reward type and HP (82 → 8) together, which is unavoidable for a heal to be dominant. With no threats and "Health regenerates starting 5 seconds after the last hit" in the rules, the pad is only weakly dominant (regen would happen anyway); "0 scrap and no stop" keeps it dominant. Same implicit structure as take_cache (the option text does not say you keep heading to the exit), which is the right control for "is the discount cache-specific". Acceptable, see N1 on its role in the verdict.

**e. Preference Nouls.** Preamble is q2's intent text up to "at the exit." (dry-run line 98 vs `q2-neutral.json:6`; test `:170-173`). One Noul per option, keyed by id, in permutation order (`run.mjs:116-127`; test `:175-190`). "Is this the action to take now?" is neutral. A per-option Noul measures acceptability, and the margin rule turns it into a ranking (Known limits :193); an "everything is acceptable" answer pattern fails the gap and is visible in the reported `options` means (`run.mjs:359-364`). Separates asking method from position (JL-20 context :19 correctly labelled as not predictive).

**f. Intent-only.** Body equals the a-cell body minus danger and greedy (`run.mjs:113`; test `:116-128`; dry-run line 432). The runner reads only `answers.intent.probabilities` (`run.mjs:295`), so the missing danger/greedy answers cannot throw as they would in `decide.mjs:213-214`. Clean priming test of JL-18 N7.

## 2. Pass rules

- 0.6 / 0.2 lines: `design.json:8-9`, applied at `run.mjs:296-297`, identical to `c2.json:11,45`. Every-order rule: `run.mjs:315,357`. An order with no usable reading has `centre === null` → `passed false` (`:300-306`), as stated at :123.
- Preference rule implemented as stated: probe ≥ 0.6 and probe − max(other) ≥ 0.2; ram ≤ 0.2 and max(other) − ram ≥ 0.2 (`run.mjs:331-342`); requires every option mean non-null (`:332`).
- Noise line max(0.1, 3 × pooled within-order SD) (`:249-257,269-271`); position flag = range of per-position means > that line (`:286-291`); comparisons pool both cells' orders (`:411-427`). 0.2 margin = 3 × the 0.06 same-position noise I confirmed in `live/JL-18/controls-…json:27,148` (0.38 vs 0.32) and `:54,322` (0.52 vs 0.49).
- Trivial or impossible? No verdict cell can be passed by a constant answer: "yes to everything" fails the e gaps and e-lethal's ≤ 0.2; "no to everything" fails the ≥ 0.6 cells and the e-lethal gap (max(other) − ram < 0.2). None is impossible by construction. The comprehension "read" flag is all-or-nothing over six readings (`:385-388`) but feeds only the explanation table, not the verdict. A reading of exactly 0.5 counts as wrong either way; acceptable.
- Minor: an order with one or two failed calls passes on the mean of the survivors (`:299`), so "mean of its three repeats" (:123) is "mean of the usable repeats"; the minimum is reported and ≥ 10 failures block. Note only.

## 3. Overall verdict rule

Implemented at `run.mjs:508-526` from `design.json:45-51`. "Either method" is acceptable: each method's pass is a conjunction of 18 order-level tests (3 cells × 6 orders, each the mean of 3 repeats), and the Choice arm's observed values sit 0.08-0.22 below the line with SD ≈ 0.03-0.06, so a chance pass on either arm is negligible and the disjunction adds essentially no family-wise risk. The two methods are different instruments, and a Noul-method candidate does not rescue the Choice instrument; the pre-reg already routes any candidate to a follow-up card (:163). Requiring a-lethal for the Noul candidate would mix instruments; e-lethal already tests lethality under Nouls. Not needed.

**N1 (decision before the run, default keep).** The Choice candidate requires `d-free-heal` (`design.json:47`), a hypothetical mechanic outside the sketches (Known limits :191). If a-free-cache and a-lethal pass in every permutation but the heal fails, the verdict is park even though c2's actual controls now pass. BACKLOG:5868 says "a design that clears every control in every order"; whether the heal is a control is the author's choice, and the pre-reg gives the reason (:166, "a free dominant option of two kinds"). This is a stricter, pre-stated, non-tunable rule, so it is interpretable as written; but it raises the park probability on a mechanic the game does not have. Andrew/coordinator should confirm they want that before Phase B. If they do not, the change is one line in `design.json:47` (drop `d-free-heal`, leaving it as the scope diagnostic at `:43`), the matching sentence at PREREGISTRATION.md:160,166, and a re-pin of `design.json`'s sha at :204, all before any call.

## 4. Rendered bodies (dry-run at `receipts-c8aec3c/dry-run.txt`, exit 0, stderr empty; coordinator receipts)

- a-free-cache call 1 (line 2): `{model,state,questions}` compact; criteria order take>push>sweep; identical text to `c2.json:29,33,37`. Byte identity with `decide()` is asserted for all 90 Choice calls (`jl18c.test.js:87-114`; `npm-test.txt:398` pass, coordinator receipt).
- b-lethal call 19 (line 38): 7 Nouls, template exact, no rules.
- c-no-objective-two call 28 (line 54): state without `objective`; two criteria; danger and greedy present as in every "choice" call.
- c-free-cache-two call 29 (line 58): take_cache and push_objective only.
- d-named-buff call 37 (line 74): "its buff, +20 max health, stacks for the rest of the run."
- e-lethal call 49 (line 98) and e-free-heal call 55 (line 110): q2 rules verbatim, option in quotes, "Is this the action to take now?"; keys in permutation order.
- f call 216 (line 432): intent only, criteria sweep>push>take; last line "216 calls (budget 216); no call made".
- The pre-reg's six "call N of 216" examples match the dry-run headers (lines 1, 25, 41, 61, 85, 133).
- No leading words in any question text.

## 5. Integrity mechanics

- `--live` hashes the four inputs from disk, including `run.mjs` itself, and refuses unless each "`name` sha256 `hex`" line is in PREREGISTRATION.md (`run.mjs:31,44-67,608-612`); the test pins the same (`jl18c.test.js:395-399`). The plan is built in memory before the first call (`:597`), so an input edit mid-run cannot change later calls; `runPlan` refuses any length ≠ 216 (`:178-179`); each result is appended as it lands (`:623-625`); no retry, 30 s timeout, non-2xx recorded as error (`:185-189,211-226`).
- **What the hash check does not anchor** (notes, none blocking): (a) PREREGISTRATION.md itself is not hashed, so "edit input + re-pin the line" passes both the runner and the test; the anchor is commit c8aec3c plus a clean worktree, which Phase B step 1 requires. Recommend the coordinator retain `git rev-parse HEAD` and `git status --porcelain` immediately before and after the run beside stdout/stderr, and a `sha256sum PREREGISTRATION.md`. (b) The runner records `questions_sha` in the result (`:635`) but does not assert it equals the `fccb508a…` named at :24; `loadQuestionSet` checks bytes against INDEX.json, which is editable in the same commit. Git and the recorded sha catch it after the fact. (c) A 2xx reply with malformed answers is not counted as a failed call, so ten such replies would not block; they would show as null readings and failed orders. (d) `model: reply?.model ?? null` means a reply with no model field yields one model `null`, not a block. JL-18 returned `jev-1.13.0` on all 12 calls, so (c) and (d) are unlikely.
- `--out` changes only where results are written, not the plan (`:619`).
- Results land under `artifacts/local/tasks/JL-18c/live/` (`:28`), which AGENTS.md treats as disposable; JL-15 and JL-18 results were promoted to `artifacts/jev-lab-2026-09-25/live/`. The coordinator should copy the JSONL, JSON, stdout, stderr and exit code there after the run.

## 6. Budget

216 calls, sequential, at JL-18's ~800 input / ~80 output per Choice call (`live/JL-18/preflight.stdout:6`: 9518/12 ≈ 793) and roughly 3× the rules text per preference call, the 150k-250k input estimate is plausible and correctly labelled ASSERTED (:180). The EV-0484 basis ("Jev cost not a constraint") is packet-supplied; I did not open TRACKING. Acceptable.

## 7. Before Phase B

Nothing blocks. Ordered by value:
1. N1: confirm d-free-heal stays a verdict cell, or make the three-line change and re-pin before any call.
2. Retain HEAD, status and the pre-reg sha before and after the run (§ 5).
3. Promote the live record out of `artifacts/local/` after the run.
4. Cosmetic, no edit needed now: test coverage of the "objective" word is c-cells only; b bodies include the state.

Coordinator receipts read: `npm-test.txt` 469 pass / 0 fail incl. the 19 jl18c tests (`:395-413`); `npm-verify.exit`, `check-docs.exit`, `check-project.exit`, `check-drift.exit`, `check-scope.exit`, `dry-run.exit` all 0; `check-scope.txt` classifies the six paths as documentation-only + tooling and names those four commands. `red-before-runner.txt` shows the test failing before `run.mjs` existed, consistent with the TDD claim.

**Verdict: APPROVE+NOTES.** Run exactly as written at c8aec3c after the N1 confirmation.

**Runtime model:** the host prompt names `claude-fable-5-1`; that is self-description, not runtime evidence. `CLAUDE_EFFORT`: unavailable (no shell in this session).
