# SC-06 assignment A3 (changes requested, final permitted attempt)

GOAL: Remove SC-06's cross-card eligibility rule SM-07 so the contract validates only its own four types, and fix the three R2 notes, leaving every other passed item intact. This is attempt 3, the last ORCHESTRATOR allows; a remaining failure returns SC-06 to blocked.

SCOPE: /home/andrew/Projects/scrapkeep-wt-SC-06, branch wt/SC-06, building on your A2 candidate d71b6f149ec336d85a5d15941aa0a9954f7a913d (base 76ef591030cc35095ae332d57966d22c8678149a). Exclusive lease SC-06-L3, attempt SC-06-A3. Permitted files unchanged: docs/tech/schemas/SC-06.md; artifacts/local/tasks/SC-06/ (ignored), including your paper check.

CONTEXT: Review R2 (fresh scrapkeep-reviewer-medium, claude-opus-5 high): artifacts/handoff-8-2026-09-16/tasks/SC-06/review-R2.md in the main checkout /home/andrew/Projects/scrapkeep. R1's B1 is resolved and R1 notes N1 to N5 are fixed; do not regress them. The coordinator accepts R2's B2 reading: TH-08 line 73 fixes no eligibility ("which is Q-P14's and SC-03's"), HF-06a lines 42 and 89 place N-016 declarations inside SC-03's gates, TH-10 DE-10 (line 100) validates an item's device or companion reference for existence and expected family only, and HF-06a line 54 holds that under every Q-P14 answer. SC-03 is already admitted (docs/tech/schemas/SC-03.md in the main checkout, EV-0402); you may cite it by backticked path and hash, since the worktree predates it.

REQUIRED CHANGES:
1. B2 (blocking). Delete SM-07 (line 105) and its four diagnostics rows (lines 151, 210, 264, 316). Keep `compatibility_action_ids` and `compatibility_attribute_keys` as authored declarations validated only by SA-10, SM-01, SM-02 and SM-05. Reword SR-10, line 85 and Seam 2 so none names SM-07. In Seam 4 state as undecided under Q-P14 whether SC-03's declarations must stay inside these lists, leaving that rule to SC-03 and Q-P14. Make lines 142, 202, 256 and 308 consistent with that.
2. R2-N2. Line 85 must not call ID-naming in N-016 declarations open: HF-06a line 89 already says attunement names device and companion IDs by expected family.
3. R2-N3. AX.3 (line 509) lists SM-04 alongside the rules it already names.
4. Paper check. Add an assertion that no admission rule's diagnostic referrer is a record outside the four SC-06 types, with a negative control that restores SM-07; keep all existing checks and controls.

VERIFY: In the worktree: npm run check:scope -- 76ef591030cc35095ae332d57966d22c8678149a <candidate> --no-build; npm run check:docs; npm run check:project; node scripts/check-drift.mjs --sections docs/tech/schemas; npm run check:drift; the revised paper check with --out under artifacts/local/tasks/SC-06/. Record exit codes and counts.

TIMEBOX: Checkpoint at handoff. Target 25 minutes.

FORBIDDEN: As A2. No new rule of any kind beyond the paper-check assertion; no answer to Q-P14, Q-P15, Q-P29, Q-P19, Q-P11 or Q-E01; no builds, no push, no rebase, no touching main.

REPORT: Commit only the permitted file on your branch and leave the tracked worktree clean. Report the new candidate SHA, file sha256, each required change with line references, commands with exit codes, paper-check counts, CLAUDE_EFFORT, deviations, and state that you have stopped.
