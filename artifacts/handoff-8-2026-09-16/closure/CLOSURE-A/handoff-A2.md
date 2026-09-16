# CLOSURE-A writer handoff, attempt 2

Writer scrapkeep-writer (claude-opus-5 high per agent definition; CLAUDE_EFFORT=high reported). Final report retained verbatim from the agent transcript.

# CLOSURE-A attempt 2 handoff (lease CLOSURE-A-L1)

**Verdict: PASS+NOTES.** All three blocking findings and notes 1 to 5 from review R1 are fixed in one commit on top of attempt 1. The scope, docs and project checks pass. The retained paper checks fail only on stated hashes of files this branch changed, which your integration fixpoint re-points. The wording fixes are checked only to level 2, where I pointed at each file and line. The check results are level 4, from running them.

## Identity
- **Worktree and branch:** `/home/andrew/Projects/scrapkeep-wt-CLOSURE-A` on `wt/CLOSURE-A`.
- **Base:** checked before any edit at `0f55274f0ae70c126560f0863d21486a540234ca`. It matched.
- **Candidate:** `da9471484406df1d3f42e9c17391b7c31e8567db`. It is one commit, and the tracked tree is clean (`git status --porcelain` printed nothing).
- **Effort:** `env | grep CLAUDE_EFFORT` printed `CLAUDE_EFFORT=high`. The harness says the model is claude-opus-5; I can't verify that myself.

## Changed paths and lines, by item
1. **B1.** SC-02 line 33 now says "thirteen foreign reference rows".
2. **B2.** SC-02 line 167 now reads "Inbound references are FR-04, FR-06 to FR-10, FR-12 and FR-13." This is the reviewer's wording.
3. **B3.** TH-19 line 216 now uses the reviewer's wording: RR-09's first run is "the first proof-mode observation of the RR-04 import, which reuses the argument list of lines 598 to 604."
4. **Note 1.** SC-02 line 96 now has a lowercase "player-facing" after the semicolon.
5. **Note 2.** The FR-13 row (SC-02 line 379) now cites SC-03 lines 39 and 41. At this base those lines type `ItemDefinition` under N-015/N-025 and `RecipeDefinition` under F-08/N-026 (SC-03 sha256 `2a59d68d…`).
6. **Note 3.** TH-07 lines 376, 381 and 484:
   - **Line 376:** the tree has 15 nodes and 14 edges, and "Its endpoint count can still be eight, so only PT-04 rejects it."
   - **Line 381 (WM.2):** the three-child and one-child nodes fail PT-04. The totals can still be 15, 14 and eight, so PT-01 to PT-03 don't reject it.
   - **Line 484:** "keeps" said PR-01 still had the old wording, which is false. It now reads "At that revision PR-01 at line 110 kept 'an authored event definition'", followed by a note that CLOSURE-A later replaced that wording. The rest of the history paragraph is unchanged.
7. **Note 4.** Stale status and already-fired triggers are corrected at these lines:
   - SC-02 lines 587 and 607.
   - SC-04 lines 584, 592 and 612.
   - SC-05 lines 678 and 704.
   - SC-06 line 463 ("although SC-02 is admitted…, no catalogue has admitted an attack definition") and line 537.
   - TH-19 line 29 (the sibling list, now marked admitted at the closure target) and line 386 (the trigger is narrowed to whether a `--script` run imports).
8. **Note 5.** I corrected SC-05 line 513 and left the fixture JSON as it is. The sources point that way: DG-07 (line 366) checks `level_role` against SP-24 (line 472), and the retained check model also leaves `level_role` out of the profile prefix rule. Line 513 now says only `illustrative-` tokens are profile vocabulary, and that `level_role` is fixed by SP-24 and checked by DG-07.

I left notes 6 and 7 unchanged, as the packet says.

## Commands and exit codes
| Command | Exit code |
| --- | --- |
| `npm run -s check:scope -- 0f55274… da94714… --no-build` | 0 (documentation-only, 6 paths) |
| `npm run -s check:docs` | 0 |
| `npm run -s check:project` | 0 |

**Retained paper checks.** These are the attempt 1 copies, run with `checks/run_all.sh a2`:
- **Pass (exit 0):** SC-04, SC-06, TH-07 (confirms the revised WM walk against its shape model) and TH-19 (21 of 21, 11 of 11 controls).
- **Exit 1 on stated-hash pins only:**
  - **SC-01:** `C02-hashes` for TH-07, SC-04 and SC-06.
  - **SC-02:** `C11-hash` for SC-04 and SC-06.
  - **SC-05:** `A8-stated-hashes` for TH-07 and SC-04.
  - **TH-12:** `sources:hash` for TH-07.

  Every stated value is the pre-CLOSURE-A hash of a file this branch changed. No other check failed, and every negative control was still caught.

## Deviations
- **SC-02 line 607 and SC-04 line 612 are Evidence limits paragraphs.** I kept what they record about the time of writing, in past tense, and added the current admitted status.
- **Some triggers had already fired.** At SC-02:587, SC-04:584 and 592, SC-05:678 and SC-06:537, I reworded each to fire on the next change. No other recheck condition changed.

I have stopped.