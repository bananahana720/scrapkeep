# SC-06 assignment A2 (changes requested)

GOAL: Revise SC-06 revision 1 so no rule changes TH-08's compatibility interface, and correct the review notes below, leaving every other passed item intact.

SCOPE: /home/andrew/Projects/scrapkeep-wt-SC-06, branch wt/SC-06, building on your A1 candidate 26afe716686622e6ba9df530f7781be6462a47ce (base 76ef591030cc35095ae332d57966d22c8678149a). Exclusive lease SC-06-L2, attempt SC-06-A2, the second of at most three attempts. Permitted files unchanged: docs/tech/schemas/SC-06.md; artifacts/local/tasks/SC-06/ (ignored, receipts), including your paper check.

CONTEXT: Independent review R1 (scrapkeep-reviewer-medium, claude-opus-5 high) returned FAIL with one blocking finding and six notes: artifacts/handoff-8-2026-09-16/tasks/SC-06/review-R1.md in the main checkout /home/andrew/Projects/scrapkeep. Items 1, 3 and 4, the row allocation, the save projection and the walks passed and must not regress. Since your base, accepted amendments AM-H8-003 (kit actions reference N-021 abilities that may commit F-02 attacks; Andrew's decision) and AM-H8-004 (respec opportunities and event and secret-room types are F-04 objectives) are recorded under artifacts/handoff-8-2026-09-16/amendments/; FR-07 will apply them to HF-06a and HF-06b later, so keep Seam 3 naming AM-H8-003 as accepted-but-unapplied and choose nothing that contradicts it. Engine facts only from Context7 (/websites/godotengine_en_4_7).

REQUIRED CHANGES:
1. B1 (blocking). SR-10 at line 65 and Seam 2 at line 443 must not change TH-08's compatibility query (EC-01 three inputs at TH-08 line 77, EC-03 line 79, EC-04 line 80, EQ-03 line 58, EP-31 line 293; TH-10 DE-04 line 94 and DE-05 line 95). Take option (a): make a device's or companion part's `compatibility_action_ids` an admission-time authored constraint only (EC-04's "satisfy the authored constraints"), so it changes no query outcome, and keep Seam 2 true; or option (b): drop the narrowing meaning and state it as an undecided seam against TH-08 EC-01 and EP-31 under Q-P15. State which and why.
2. N1. Correct TH-16 citations: RM-01 line 121, RM-02 line 122, RM-07 line 127, RM-08 line 128, at your lines 22, 66, 337 and 352.
3. N2. Cite TH-10 DO-09 at line 80 for ActionRequest (line 289).
4. N3. State in AV whether catalogue A is a first catalogue or a replacement, consistent with HF-05 lines 64 and 97.
5. N4. Do not apply this card's id grammar to F-02 attack ids in SA-08; state the seam with SC-02 (HF-05 line 18).
6. N5. Label `availability_rule` on the chassis only and the single `assembly_rule` fit model as this contract's choices under Q-P15, with the revision trigger each needs.
7. Paper check. Add an assertion that no SR or SA rule's effect changes a TH-08 EC query input or outcome (the check that would have caught B1); check that each cited section row ID appears on the cited line (catching N1 and N2); replace the json identity round trip with a field-and-reference preservation check against the declared field tables. Keep existing negative controls and add one that restores narrowing semantics.

VERIFY: In the worktree: npm run check:scope -- 76ef591030cc35095ae332d57966d22c8678149a <candidate> --no-build; npm run check:docs; npm run check:project; node scripts/check-drift.mjs --sections docs/tech/schemas; npm run check:drift; your revised paper check with --out under artifacts/local/tasks/SC-06/. Record exit codes and counts.

TIMEBOX: Checkpoint at handoff. Target 40 minutes.

FORBIDDEN: As A1: no edits outside the permitted files; no Resource, script, roster, count or value; no answer to Q-P15, Q-P29, Q-P14, Q-P19, Q-P11 or Q-E01; the EV-0144 and EV-0151 proposals are not answers; no builds, no native execution, no push, no rebase, no touching main. If a change needs an admitted row altered, stop and submit an amendment request under artifacts/local/tasks/SC-06/.

REPORT: Commit only the permitted file on your branch and leave the tracked worktree clean. Report the new candidate SHA, file sha256, each required change item by item with line references, commands with exit codes, paper-check counts, CLAUDE_EFFORT, deviations, and state explicitly that you have stopped.
