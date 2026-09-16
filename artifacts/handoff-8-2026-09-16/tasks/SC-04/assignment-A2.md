# SC-04 assignment A2 (changes requested)

GOAL: Revise SC-04 revision 1 so its HF-06a row allocation follows the admitted rows' rationale text, and correct the review notes below, leaving every other passed item intact.

SCOPE: /home/andrew/Projects/scrapkeep-wt-SC-04, branch wt/SC-04, building on your A1 candidate b1427907f28ef7c353bf8cfe564f12dd97874791 (base 254f8e11147c41d4ec9d34bb1d4687ba006f09e0). Exclusive lease SC-04-L2, attempt SC-04-A2, the second of at most three attempts. Permitted files unchanged: docs/tech/schemas/SC-04.md; artifacts/local/tasks/SC-04/ (ignored, receipts), including your paper check.

CONTEXT: Independent review R1 (scrapkeep-reviewer-medium, claude-opus-5 high) returned FAIL with one blocking finding and six notes; it is at artifacts/handoff-8-2026-09-16/tasks/SC-04/review-R1.md in the main checkout /home/andrew/Projects/scrapkeep. The coordinator confirmed B1 at your lines 38 to 46 against HF-06a line 22 (a family row and a noun row describe the same type from two directions), line 69 (F-04 names enemy archetypes and their attacks) and line 96 with its CSV row (N-023: enemy archetype, wave, miniboss and boss definitions (F-04) referencing attacks and regions), and HF-06a line 46. Items 2, 3 and 4, the headings, the seams and the traces passed and must not regress. The same lesson failed SC-01 at EV-0388. Review note 1 (HF-06b line 114 says N-028's projection names the level and encounter by id, against TH-11 line 45 and HF-07a's closed field list) is an admitted-source contradiction: the coordinator has classified it as a factual correction to HF-06b under amendment AM-H8-002, to be applied by the foundation-repair card FR-07 after the schema cards land. Keep RS-01 and your migration claim on the TH-11 and HF-07a reading, cite AM-H8-002 at that seam, and do not route it to TH-20. Engine facts still come only from Context7 (/websites/godotengine_en_4_7).

REQUIRED CHANGES:
1. B1 (blocking). Map types to rows by their rationale text: F-04 is the family row covering T1, T3, T4, T5 and T7 (T2 and T6 embedded); N-023 is the noun row instantiating F-04 for T1 with T2, T3 and T4. Remove "each type maps to exactly one row" and "exactly one root type" and the false "only row naming enemy archetypes" claim at line 46. Make the save table and QO-05 agree with the corrected map (save outcomes are unchanged; both rows carry identical columns).
2. Note 1. Cite AM-H8-002 at the HF-06b line 114 seam as described above.
3. Note 2. D4-04 cites TH-11 line 103 (add it to Sources with its hash) and labels the finale-capable boss representation as a schema choice an answer to Q-P25 may revise.
4. Note 3. Give `durability`, `entries[].count`, `finale_capable`, `commitment_budget` and `pressure_budget` a value type (boolean, integer or a named symbolic type) so SD-03 can check them.
5. Note 4. Label `boss_id` at most one, D4-02's nonempty archetype list and D5-02's no-repeat rule as this contract's choices with the revision trigger each needs, and add two bosses in one encounter to the revision list.
6. Note 5. Correct the SA.4 and SA.5 gate labels to HF-05 line 83 and 84.
7. Note 6. Reword rule 1 so the reserved `illustrative.` prefix is stated as an exception.
8. Paper check. Compare each type's row allocation with the nouns in the row's rationale (HF-06a text and CSV), replace the identity json round trip with a field-and-reference preservation check against the declared field tables, and add a negative control that assigns a wave only to N-023's opposite row.

VERIFY: In the worktree: npm run check:scope -- 254f8e11147c41d4ec9d34bb1d4687ba006f09e0 <candidate> --no-build; npm run check:docs; npm run check:project; node scripts/check-drift.mjs --sections docs/tech/schemas (zero mismatches, zero unbound); npm run check:drift; your revised paper check with --out under artifacts/local/tasks/SC-04/. Record exit codes and counts. The coordinator reruns everything and a fresh reviewer reads the revision.

TIMEBOX: Checkpoint at handoff. Target 40 minutes.

FORBIDDEN: As A1: no edits outside the permitted files; no Resource, script, runtime content, roster, count or value; no answer to Q-P25, Q-E10, Q-P38, Q-P23 or Q-E14; no builds, no native or browser execution, no push, no rebase, no touching main. If a change needs an admitted row altered, stop and submit an amendment request in the form of docs/project/sprint-0/amendment-request.md under artifacts/local/tasks/SC-04/.

REPORT: Commit only the permitted file on your branch and leave the tracked worktree clean. Report the new candidate SHA, changed paths, file sha256, each required change item by item with line references, commands with exit codes, paper-check counts, CLAUDE_EFFORT, deviations, and state explicitly that you have stopped.
