# JL-30d A1+A2 review (Opus 5.5, routine; verbatim)

## JL-30d (A1+A2) independent review: FAIL (one blocking finding, a one-line fix)

**Evidence level:** static source review of the files at `/home/andrew/Projects/scrapkeep-wt-JL-30d`. The branch ref `wt/JL-30d` resolves to 669fbdf1fc97… (`/home/andrew/Projects/scrapkeep/.git/refs/heads/wt/JL-30d`), and the worktree HEAD points at that ref. I have no shell, so I could not view the diff or confirm the tree is clean. I reviewed the resulting files, not the patch. `check:skills` 0 findings, `check:docs` pass, `check:drift` pass and the body line counts are **[coordinator receipt]** only.

### Findings

**B1 (blocking, criterion 7 staleness).** `.agents/skills/scrapkeep-lab/references/port-a-stage.md:10`, the Spillway Drop row, still reads "the end-at-death ruling sent it to JL-27-A3, in progress at EV-0556".
- The coordinator head says otherwise. TRACKING EV-0559 (`/home/andrew/Projects/scrapkeep-wt-JL-coord/TRACKING.md:860`) records JL-27-A3 merged at 763ef84 with lab 45446ff and "JL-27 done". EV-0567 (`:868`) sends JL-28 to Spillway at lab 45446ff.
- The row also leaves out the lab head and A3's outcome: 0 anomalies in 160 trials, and 80 of 80 rigid pairs.
- The file is in the JL-30d lease, and A2 edited it (it added "Foes with HP, and bosses", `:32-41`).
- Fix: mark JL-27 done at EV-0559 and name lab 45446ff. The Cable Bench row (`:9`) is not wrong but omits lab head 7d5adda; adding it is optional.

**N1 (non-blocking, accuracy).** RML-48, `reactive-model-loop/references/lessons.md:250`, says "The pooled within-order standard deviation was 0.008, about 7.5 standard deviations below the margin". That sentence is garbled: the margin was about 7.5 SD. The same fact is stated correctly at `controls.md:89`.

**N2 (non-blocking, accuracy).** RML-61 (`lessons.md:315`) and `controls.md:30` say "three orders failed on margins of 0.089 to 0.099". The count copies the agent's gap 6 (`1b-portable-robot-blind.md:138`). The agent's own table shows four margin failures: T 0.089 (`:57`), D90 0.099 (`:60`), and WB 0.090 and 0.093 (`:62`). Say "four", or "at least three".

**N3 (non-blocking, internal consistency).** The wording-swap row in `controls.md:49` makes "the sensitivity arm moves the answer" part of the pass condition. `controls.md:115` instead treats "no word moves it" as a result to interpret ("the decider ignores text"). Under the table, a numbers-only decider would fail the wording control; under `:115` it would be reported as text-blind. Align the two.

**N4 (non-blocking, test contamination).** `controls.md:113` gives "free" as the example trigger word. That is the sealed key's planted word (`1b-portable-robot-blind.md:21`). Any future blind re-run using the 1b decider no longer tests whether an agent finds the trigger unprompted. `plan-session/SKILL.md:3` likewise now reproduces exercise 3's prompt A almost word for word, so reusing prompt A no longer tests routing independently.

**N5 (non-blocking, gap coverage).** I found no new text for blind gap 8 ("measurement without a fix", `1b-portable-robot-blind.md:140`). The pre-existing rules partly cover it: code owns intent at `SKILL.md:14`, and per-option ratings are at `SKILL.md:17` and `controls.md:121-125`. No passage says what to do once a position effect is found. I could not see the writer's handoff, so I can't tell whether it was declined with a reason.

**N6 (non-blocking, F6).** The skill side now says outright that the real launcher needs no Node-side registration (`scenarios-and-arms.md:11`, SKL-35). The DESIGN's pass column (`DESIGN.md:191`, "and the Node registry") is unchanged; that file is outside the lease and marked verbatim. The coordinator should record F6 as closed on the skill side and declined for the DESIGN.

### 1. Gap coverage

**Exercise 1 (drone stub):**

| Gap | Where addressed |
| --- | --- |
| 1: no model reported | `SKILL.md:27`, `instrument.md:45`, template `preregistration.md:46` (RML-47) |
| 2: dominance margin | `controls.md:81-89`, `SKILL.md:41` (RML-48) |
| 3: fallback rate | `controls.md:32-41`, `runtime.md:59` (RML-49) |
| 4: wording swap vs a text-blind decider | `controls.md:109-119`, `SKILL.md:42` (RML-50) |
| 5: hidden sequence state | `runtime.md:21-29`, `SKILL.md:72`, `preregistration.md:47` (RML-51) |
| 6: where to place the perturbation | `preregistration.md:125`, `SKILL.md:66` (RML-52) |
| 7: lethal line | `controls.md:91-97`, `SKILL.md:41` (RML-53) |
| 8: host adapter | `SKILL.md:120` and `SKILL.md:61`, `preregistration.md:17` (RML-62) |

The unexpected findings were also absorbed: a positional fallback (`runtime.md:54`, RML-54) and uninformative confidence (`instrument.md:55`, `SKILL.md:30`, RML-55).

**Exercise 1b (blind):**

| Gap | Where addressed |
| --- | --- |
| 1: model identity | RML-47 |
| 2: no solo path | RML-62 |
| 3: schema probe | `preregistration.md:12`, RML-59 |
| 4: change record inside the pinned file | `preregistration.md:11`, `:92`, RML-60 |
| 5: choice vs probability | `controls.md:22-30`, RML-61 |
| 6: margin rule | RML-48 and RML-61 |
| 7: self-reported source | `controls.md:10`, `SKILL.md:44`, RML-57 |
| 8: no fix once measured | not visibly addressed (N5) |
| 9: numbers-against-labels control | `controls.md:50`, `SKILL.md:38`, RML-58 |

The two sealed-key misses are covered in question 4 below.

**Exercise 2 (lab scenario):**

| Gap | Where addressed |
| --- | --- |
| 1: per-scenario dummies | `scenarios-and-arms.md:9`, SKL-33, `SKILL.md:53` |
| 2: hardcoded test counts | `scenarios-and-arms.md:10`, SKL-34 |
| 3: fake `soak` coupling | `scenarios-and-arms.md:11`, SKL-35, `SKILL.md:54` |
| 4: seeds | `scenarios-and-arms.md:18-28`, `SKILL.md:56` |
| 5: multi-option share | `scenarios-and-arms.md:30-32`, `SKILL.md:55` |
| 6: what to expect from scripted | `scenarios-and-arms.md:52-61` |
| 7: where post-hoc labels go | `scenarios-and-arms.md:16` |
| 8: no update-table row for a new scenario | `SKILL.md:93` |
| 9: HP foes and bosses | `port-a-stage.md:32-41`, citing `PROTOCOL.md:171` and `:188` (both checked) |

**Exercise 3 and grading:**
- Exercise 3's A tie is resolved in both descriptions.
- Grading F1: see question 3.
- Grading F6: see N6.
- Grading F9: closed by the question 5 re-run.

### 2. Lesson accuracy

I checked all 16 new RML lessons (47-62), SKL-33 to SKL-36 and the promoted SKL-31 against their cited evidence.
- The RML numbers match the exercise reports: 0.0584 and 0.0078; 15 of 240 with 6 in controls; about 0.79 tagged unverified; 0.128-0.310; r = 0.068 over 225 answers; 210 of 210 `source: model`; X passing 4 of 6. The exceptions are N1 and N2.
- Every new RML lesson is provisional. The portable text labels examples "in one exercise", "in one blind exercise" or "in one lab" (`SKILL.md:17`, `controls.md`, `preregistration.md:17`, `runtime.md:29`, `:54`, `instrument.md:45`, `:55`).
- I opened more than 20 SKL citations and they hold:
  - `jev_run.gd:300-313`
  - `jev_state.gd:220-226` and `:246-252`
  - `jev_state_test.gd:559`, `:561-569` and `:608`
  - `field.gd:84-87`, `lab.gd:51-56`
  - `scenarios.gd:10-13`, `:38-48` and `:159-167`
  - `fake-godot.mjs:143-148` and `:190-193`
  - `godot-launch.mjs:103`
  - `gate.mjs:604-627`
  - `harness.mjs:112`, `:122`, `:698-701`, `:814` and `:870`
  - `decide.mjs:137-142`, `arms.mjs:78-79`
  - `reviews/JL-21b.md:16` and `:29`
- SKL-31's promotion rests on two independent sources, which meets the ledger's definition at `lessons.md:7`: the A1 writer's finding (EV-0556) and the independent Fable review's confirmation (`JL-21b.md:29`).
- Not checked: `harness.mjs:51-52`.

### 3. Noise floor

This criterion is met.
- `controls.md:73`: "This skill hands out no constant, and no floor to copy."
- `controls.md:75`: any floor is pre-registered with a reason tied to the consequence, and the report names measured line, floor and which one decided each cell.
- Also consistent: `SKILL.md:40`, template `preregistration.md:62-63`, and RML-13 (`lessons.md:75`, "no floor value is carried forward").
- A grep for `max(` and `3×` in `reactive-model-loop/**` finds no floor formula. The 0.1 values that remain are labelled cautionary examples (`controls.md:89`, `:97`).

### 4. Would the blind misses now be caught?

**Wording sensitivity: yes.** `SKILL.md:42`, the `controls.md:49` table row, the `controls.md:111-115` procedure and template `preregistration.md:59` all require it. `controls.md:114` says to vary each candidate word on its own "so a word shared by both paraphrase arms is still tested", which is exactly how 1b missed the trigger. Caveat (inference): catching a trigger still depends on the agent choosing the right candidate word. The example list at `:113` names the planted word (N4).

**Choice vs probability: yes.** `SKILL.md:43` and `controls.md:12-18` make the agent count every choice that is not the top-probability option. Sampling may not be assumed without provider documentation, and an unexplained mismatch leaves the instrument untrusted. 1b's 2 of 210 would become a failing reading instead of "sampling".

**Self-reported source: yes.** `SKILL.md:44` and `controls.md:10` require an out-of-band signal and a report that labels the check "self-reported" when the field is all there is.

### 5. Routing re-run

I read the five frontmatters plus the lab row at `scrapkeep-verify/SKILL.md:26`.

| Request | Route | Basis |
| --- | --- | --- |
| A: plan lab work, including whether to start an epoch | plan-session | `plan-session/SKILL.md:3` names it; `scrapkeep-lab/SKILL.md:3` defers ("Deciding what the lab should work on next, including whether to start an epoch, starts in plan-session") and now says "cut an approved instrument epoch". Tie resolved. |
| B: verify a harness diff | scrapkeep-verify | Description `:3`, the lab row `:26`, and the lab description's "verification checklists for a diff stay in scrapkeep-verify". Closes F9. |
| C: new stage with HP enemies | scrapkeep-lab | "bring the lab to a new stage", then `port-a-stage.md:32-41` |
| D: support-ticket router | reactive-model-loop | "a router" |
| E: implement JL-28 | scrapkeep-task | "approved Scrapkeep card" |

### 6. Portability and scenario review

**Portability.** I grepped `reactive-model-loop/**` for the DESIGN §4b forbidden list plus `Jev`, `TRACKING`, `SKL-`, `.gd` and `.mjs`: no matches.

**Ownership.** Nothing contradicts ORCHESTRATOR.md or AGENTS.md:
- Coordinator as sole admitter: `scrapkeep-lab/SKILL.md:101` hands edits to the coordinator. `scenarios-and-arms.md:28` and `port-a-stage.md:43-48` send reservations, rulings and lease scope to the coordinator, consistent with `ORCHESTRATOR.md:68`.
- Blind-author rule: kept at `SKILL.md:20` and `:84` (SKL-26).
- One writer per file: the portable skill's parent-review solo path (`SKILL.md:61`) defers to the host's reviewer. The update table's reviewer tiers match `ORCHESTRATOR.md:17`.

### 7. Staleness against the coordinator head

- JL-21b statements match EV-0563, EV-0564 and EV-0566 (`scenarios-and-arms.md:52-61`, `SKILL.md:50`, SKL-31).
- Pin statements match EV-0566, and the 2026-09-26 kinematic pin's subject is 6864bf7 (`pin.json:11-12`).
- JL-28 "until" wording is consistent with EV-0567 (in progress).
- JL-27 fails: see B1.

### Runtime

- **Model:** the host system prompt names Opus 5.5 (`claude-opus-5-5`). That is harness self-description, not runtime metadata.
- **CLAUDE_EFFORT:** unavailable (no shell).

### Key paths
- /home/andrew/Projects/scrapkeep-wt-JL-30d/.agents/skills/scrapkeep-lab/references/port-a-stage.md
- /home/andrew/Projects/scrapkeep-wt-JL-30d/.agents/skills/reactive-model-loop/references/controls.md
- /home/andrew/Projects/scrapkeep-wt-JL-30d/.agents/skills/reactive-model-loop/references/lessons.md
- /home/andrew/Projects/scrapkeep-wt-JL-coord/TRACKING.md

**Verdict: FAIL.** B1 violates criterion 7. After B1 is fixed, and N1 and N2 corrected if the coordinator wants, I expect PASS+NOTES.
