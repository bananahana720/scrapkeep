# CLOSURE-A writer handoff

Writer scrapkeep-writer (claude-opus-5 high per agent definition; CLAUDE_EFFORT=high reported). Final report retained verbatim from the agent transcript.

# CLOSURE-A handoff (lease CLOSURE-A-L1, EV-0454)

**Verdict: PASS+NOTES.** All of CLOSURE-A's factual repairs are committed. The scope, docs and project checks pass. Both drift checks fail, but every mismatch is a stated hash of a file I changed, and you run that fixpoint at integration. The repair wording itself is checked only to level 2: I pointed at each file and line. The check results are level 4: I ran them.

## Identity
- **Worktree and branch:** `/home/andrew/Projects/scrapkeep-wt-CLOSURE-A` on `wt/CLOSURE-A`.
- **Base:** checked before any edit at `6f580b7d3586de944ed8307399d901711b9c33c1`. It matched.
- **Candidate:** `0f55274f0ae70c126560f0863d21486a540234ca`. The tracked tree is clean (`git status --porcelain` printed nothing).
- **Model and effort:** `env | grep CLAUDE_EFFORT` printed `CLAUDE_EFFORT=high`. The model is claude-opus-5 according to the harness. I can't verify that independently.

## Changed paths and repairs
Line numbers are at the candidate.
- **SC-01:**
  - A17: line 5 now says attempt 3; line 560 says SA-50 to SA-54; line 633 adds EC-03; line 635 adds the SC-06 action-reference trigger.
  - A18: Seam 3 at line 535 now states the ability versus attack difference.
  - A3: the Seam 5 sentence at line 539 is replaced.
  - A19: SP-14 and SP-15 at lines 511 and 512.
  - Seam status: lines 25, 194, 421, 425 and 426.
- **SC-02:**
  - A13: lines 96, 516 and 560.
  - A2: the S08 diagnostic, now at line 396.
  - A18: a new row FR-13 at line 380 for SC-03 `effects[].action_ids` and `result.action_ids`.
  - A19: SP-34, now at line 508.
  - Seam status: lines 27, 363, 514 and 518.
- **SC-04:**
  - A14: lines 23, 46, 71, and the "Attempt-1 procedure" label at line 596.
  - Stale amendment language at lines 433 and 580.
  - Seam status at lines 24, 251 and 415.
- **SC-05:**
  - A15: lines 385, 387 and 513.
  - N1: "task FR-07" at lines 5, 25 and 678; "local reference FR-07" at lines 84 and 491.
  - N7: "an illustrative pair of records" at line 278.
  - Amendment language at lines 18 and 484; seam status at lines 26 and 505.
- **SC-06:**
  - Line 26 now labels the digest as SC-03 first-admission bytes. Line 543 is labelled "Attempt-1 procedure".
  - Amendment language at lines 338, 339 and 449.
  - N3 citation fix at line 451.
  - Seam status at lines 140, 141, 199, 200, 252, 253, 303, 304, 532 and 539.
- **TH-07:** line 110 (N3) and line 253 (PX-02) only.
- **TH-12:** line 155 (UI-03) only. O1 now reads "RL2, RL3, RL7 and RL8".
- **TH-19:**
  - A8: lines 14, 210, 216, 290 and 404.
  - A9: a new W3.5 row, with the old W3.5 to W3.8 renumbered W3.6 to W3.9.
  - N3: AQ-02 at line 272 adds the loop-header anchor at lines 752 and 753.
  - N4: line 220.
  - A19: lines 72, 244, 280, 284, 375 and 379.
  - Seam status at lines 294, 296 and 298.
- **AM-H8-004 request:** status rows 14, 58 and 62. The original pending and open wording is kept as history.

## Commands and exit codes
| Command | Exit code |
| --- | --- |
| `npm run -s check:scope -- 6f580b7… 0f55274… --no-build` | 0 (documentation-only, 9 paths) |
| `npm run -s check:docs` | 0 |
| `npm run -s check:project` | 0 |
| `npm run -s check:drift` | 1 |
| `node scripts/check-drift.mjs --sections docs/tech/schemas` | 1 |

**Drift mismatches.** `check:drift` found 4 and the schemas scan found 10. Every stated value is the base hash of a file I changed:
- **TH-07:** `4c6c673d…` became `2a28b790…`. Stated in TH-12:20, PD-02:20, SC-01:17, SC-03:20, SC-05:18 and SC-08:19.
- **TH-12:** `9e25a650…` became `7917a917…`. Stated in TH-18:19 and PD-03:28.
- **SC-04:** `f216f7c9…` became `8ab8f0cc…`. Stated in SC-01:21, SC-02:25, SC-05:24 and SC-08:25.
- **SC-06:** `de5f7b7b…` became `4dd01d6a…`. Stated in SC-01:22 and SC-02:26.

**Retained paper checks.** I ran copies from `artifacts/local/tasks/CLOSURE-A/checks/`. All eight exited 0 on the unedited base. On the candidate:
- **Pass (exit 0):** SC-04, SC-06, TH-07 and TH-19.
- **Exit 1 on hash pins only:**
  - SC-01: `C02-hashes` for TH-07, SC-04 and SC-06.
  - SC-02: `C11-hash` for SC-04 and SC-06.
  - SC-05 (run with `--main-root`): `A8-stated-hashes` for TH-07 and SC-04.
  - TH-12: `sources:hash` for TH-07.

**Phrase pins I kept instead of reporting.** Three checks pin exact phrases, so I adjusted my wording and left the checks unchanged:
- SC-01 C11, SC-02 C10a and TH-19 AQ-10/AQ-14 require the value cell to be exactly `unset`.
- TH-19 `gates-absent-at-base` requires IG-05 to be exactly `open`.
- SC-05 A2/A5/A6 need the label `**Illustrative authored record, not canon.**`.

Because of this, A19's partial-selection text sits in the parameter or gate description column, and the value cells stay `unset`/`open`. That also keeps each production gate.

## Deviations
1. **Status fixes beyond the listed lines.** I also fixed identical "concurrent / not admitted" wording in the same permitted files:
   - SC-01 lines 394 and 395, and the Seam 3 heading at 535.
   - SC-04 line 143.
   - SC-06 lines 335, 340 and 341.
   - SC-02 line 518: SC-03's revision sentence is now past tense.
2. **FR-13 row choice is my inference.** The read gave only the field names. I took the HF-06a rows N-015, N-025, F-08 and N-026 from SC-03's own row table. SC-02 line 363 now says FR-13 names two SC-03 fields.
3. **Line shifts.** The FR-13 row moves SC-02 lines from 380 onward down by one. The new W3.5 row does the same to TH-19 from line 363 onward. A grep of `docs` and `BACKLOG.md` found no line citations into either file.
4. **Wording I composed.** The read gave no exact text for TH-19 lines 14, 216 and 404, so I wrote them.
   - A3 keeps "Nothing here references the objective" as its own sentence.
   - SC-06 lines 338 and 449 take only the "FR-07 applied…" sentence. The respec sentence was off-topic there.

## Follow-ups
Stale wording I left in place, either because it is not on the packet's lists or because it records history:
- SC-01:639, a procedure record.
- SC-02:587 and 607.
- SC-04:592 and 612.
- SC-05:25 and 678, where the FR-07 trigger is already met, and 680.
- SC-06:549, a procedure record.
- TH-19:371 says "none is answered" next to recorded partial answers.
- EV-0397 N3's directory-removal mechanism belongs to the runner implementation card.

I have stopped.