# CLOSURE-A review R2

Reviewer scrapkeep-reviewer-medium (claude-opus-5 high per agent definition; runtime effort not readable by the reviewer). Final report retained verbatim from the agent transcript.

**Verdict: PASS+NOTES.** Attempt 2 (`da9471484406df1d3f42e9c17391b7c31e8567db`) closes B1, B2 and B3 with support from the sources, and applies notes 1 to 5. I found no rule, field, gate, parameter, diagnostic or question state that changed, and no TH-07 line outside the permitted ones. The five notes below are wording tensions or scope refinements, and none of them fails a completion criterion.

**Evidence level:** I read the files directly; I had no shell, so I ran no `git diff` and no checks.
- **Branch:** `.git/refs/heads/wt/CLOSURE-A` reads `da94714…`, and the worktree HEAD points at that branch.
- **Comparison:** I read all six changed files in full, in the worktree and in main (which does not yet contain CLOSURE-A), and compared them line by line. Every difference is either on R1's attempt-1 line list, one of the attempt-2 lines, or a main-side hash re-point. Where attempt 1 and attempt 2 touched the same line (SC-02:96 and 379, SC-05:513 and 678, TH-19:216), I judged the resulting text and could not split the two attempts' contributions.
- **Line counts:** the SC-04, SC-05 and SC-06 changes are single-line replacements, so no cited line moved.
- **Coordinator receipts (not verified by me):**
  - Clean tree and one commit on attempt 1 (`coordinator-candidate-A2/identity.txt:3-4`).
  - The attempt-1 to attempt-2 path list and the TH-07 hunks at 110, 253, 376, 381 and 484 only (`identity.txt:5-19`).
  - `check-scope-A2`, `check-scope-total`, `check-docs` and `check-project` exit 0 (`coordinator-candidate-A2/exits.txt`).
  - Merged view: clean merge, six-pass fixpoint, drift scans exit 0, and all 35 paper checks pass, including SC-05 at 12 of 12 controls caught (`coordinator-view-A2/exits.txt`, `fixpoint.log:41`, `paper-reruns.log:34,37`).
- **Not read:** I did not read `assignment-A2.md`, because my instructions forbid reading the writer's brief.

## Findings table

| Item | Status | Lines and support |
|---|---|---|
| B1 | Closed | SC-02:33 now says "thirteen foreign reference rows". The table at SC-02:367-379 holds FR-01 to FR-13, and no other count in SC-02 names the rows. |
| B2 | Closed | SC-02:167 now reads "FR-04, FR-06 to FR-10, FR-12 and FR-13". Each of those rows lists `AttackDefinition` (SC-02:370-379), and FR-11 lists only `AbilityDefinition` (:377). |
| B3 | Closed | TH-19:216 uses R1's wording. It agrees with :10 (lines 597-612 run only in export mode), :200 and :207 (RR-04 reuses lines 598-604). The excerpt documents `--import` at `command-line-excerpt.md:15-16`, and AQ-20 at :290 matches. |
| Note 1 | Done | SC-02:96 now has a lowercase "player-facing". |
| Note 2 | Done | SC-02:379 cites SC-03 lines 39 and 41. Those lines are identical in the worktree base SC-03 and in main's SC-03 (`ItemDefinition` N-015/N-025; `RecipeDefinition` F-08/N-026). I could not hash the bytes to confirm `2a59d68d…`. |
| Note 3 | Done | TH-07:376 and :381 now say only PT-04 rejects the tree, and the totals can still be 15, 14 and 8. That agrees with PX-02 at :253, PT-04 at :60 ("one child or three is malformed") and SC-01 SA-40 to SA-44 at :308-312. TH-07:484 is still a history record, now in past tense; the new parenthetical is true (TH-07:110 now reads "an authored F-04 objective definition"). |
| Note 4 | Done | SC-02:587 and 607; SC-04:584, 592 and 612; SC-05:678 and 704; SC-06:463 and 537; TH-19:29 and 386. The admitted states match `TRACKING.md:137,163,164,177-182,184`. |
| Note 5 | Done | SC-05:513 now says `level_role` is not a profile vocabulary, SP-24 fixes it (:472) and DG-07 checks it (:366). The fixture JSON at :523 is unchanged and consistent with that. The retained check model agrees: it skips `level_role` in the prefix check (`check_sc05-repinned.py:476`). |

## The writer's two disclosed deviations

1. **Evidence-limits paragraphs (SC-02:607, SC-04:612): accepted.** Both keep the time-of-writing fact in past tense and add the admitted status. No limit or claim was removed.
2. **Triggers that had already fired: accepted, with note 1 below.**
   - SC-02:587 (seams now fire "when revised"), SC-04:584 (HF-06b line 114 "changes again"), SC-04:592 and SC-05:678 (N-024 "changes again") each keep their original scope and fire on the next change.
   - SC-06:537 is broader than the original trigger (note 1).

## Blocking findings

None.

## Non-blocking notes

1. **SC-06:537 now fires on any change to HF-06a or HF-06b.** "When HF-06a or HF-06b change again after FR-07 applied…" is no longer limited to the parts the amendments touched. In practice this adds nothing, because SC-06:9-10 pin both hashes and the drift scan already flags any byte change (inference). Proposed wording: "when HF-06a or HF-06b change again in the rows or cells FR-07 edited under AM-H8-003 and AM-H8-004 (EV-0437)".
2. **SC-05:578 (TA.4) says "Every token and container key … is known to the fixture profile".** The T4 records carry the `level_role` tokens `ordinary` and `boss`, which :513 now says are not a profile vocabulary. Proposed wording: "Every token and container key the rule profile governs, including `finale_rule`'s, is known to the fixture profile".
3. **SC-05:528 says "Under the production rule profile, DG-18 refuses every one of these records".** Since attempt 1's :387 (accepted by R1) made SP-24's role tokens part of the known profile, the exit records carry no DG-18-governed token. Neither attempt touched this line. Proposed wording: "…DG-18 refuses every one of these records that carries an `illustrative-` token or container key."
4. **SC-06:559 still says "an admitted attack type that do not exist".** This is the stale sense that :463 corrected. Proposed wording: "…conditional on a Q-P15 answer and an admitted attack definition, neither of which exists…".
5. **SC-02:379 cites the row allocation but not the field targets.** SC-03 lines 39 and 41 type the rows; the lines that make `effects[].action_ids` and `result.action_ids` target F-02 are SC-03 lines 79 and 188 in the worktree base (79 and 185 in main). Citing those would close R1's note 2 fully.

## Model and effort

The runtime describes this reviewer as Opus 5 (`claude-opus-5[1m]`); that is self-description I can't verify. `CLAUDE_EFFORT` is not exposed to me, so it is unavailable. AGENTS.md pins Fable 5.1 medium for consequential review. If this review counts as consequential, running it on Opus 5 is a substitution, which AGENTS.md says to report as a blocker. That call is yours.

Relevant paths:
- /home/andrew/Projects/scrapkeep-wt-CLOSURE-A/docs/tech/schemas/SC-02.md
- /home/andrew/Projects/scrapkeep-wt-CLOSURE-A/docs/tech/schemas/SC-04.md
- /home/andrew/Projects/scrapkeep-wt-CLOSURE-A/docs/tech/schemas/SC-05.md
- /home/andrew/Projects/scrapkeep-wt-CLOSURE-A/docs/tech/schemas/SC-06.md
- /home/andrew/Projects/scrapkeep-wt-CLOSURE-A/docs/tech/sections/TH-07-four-slots-and-milestone-progression.md
- /home/andrew/Projects/scrapkeep-wt-CLOSURE-A/docs/tech/sections/TH-19-asset-import-export.md
- /home/andrew/Projects/scrapkeep/artifacts/handoff-8-2026-09-16/closure/CLOSURE-A/coordinator-view-A2/check_sc05-repinned.py