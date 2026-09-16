# SC-08 assignment A2 (changes requested)

GOAL: Revise SC-08 revision 1 so no rule fixes an unsourced discovery cardinality, and correct the review notes below, leaving every passed item intact.

SCOPE: /home/andrew/Projects/scrapkeep-wt-SC-08, branch wt/SC-08, building on your A1 candidate d9920812f511a3083a9a1c729c139ec121f037df (base 87e88ccd578a999c79f25755bc9fa8a56bfc154a). Exclusive lease SC-08-L2, attempt SC-08-A2, the second of at most three attempts. Permitted files unchanged: docs/tech/schemas/SC-08.md; artifacts/local/tasks/SC-08/ (ignored), including your paper check.

CONTEXT: Review R1 (scrapkeep-reviewer-medium, claude-opus-5 high) returned FAIL: artifacts/handoff-8-2026-09-16/tasks/SC-08/review-R1.md in the main checkout /home/andrew/Projects/scrapkeep. Items 1, 2 and 3, the row allocation, exclusions, save treatment and walks passed and must not regress. Since your base, SC-03 (EV-0402) and SC-04 (EV-0409) are admitted at docs/tech/schemas/SC-03.md and SC-04.md in the main checkout: you may cite their bytes and hashes and must replace 'none is admitted' where it names them. Accepted, unapplied amendments: AM-H8-001 (a slot definition row), AM-H8-003 (kit actions reference abilities), AM-H8-004 (respec opportunities and event and secret-room types are F-04 objectives), under artifacts/handoff-8-2026-09-16/amendments/.

REQUIRED CHANGES:
1. B1 (blocking). DT4-02 (line 311) and Seam 6 (line 445) must not limit discoveries to one per subject set: either restrict DT4-02 to discoveries whose subject_ids is exactly one T2 exchange (the case Seam 6 needs), or remove it and add a parameter row 'whether several discoveries may share a subject set: unset, Q-P37, Q-P14'. Add a negative control for whichever rule remains.
2. Note 1. Cite admitted SC-03 and SC-04; re-read your References cells for F-04 and N-023 against SC-04 lines 423 to 426, where both rows sit on T1 to T4, and state which SC-04 type each reference resolves to.
3. Note 2. State which SC-08 type a row-level reference to N-012 or N-017 resolves to (SC-04 SR-08 line 408 references the N-012 narrative identity family).
4. Note 3. State that the T1 stub comes from a declared compatible dependency revision, or remove it from the staged candidate in WV.
5. Note 4. Narrow the N-058 'by construction' and N-040 exclusion claims to what the status-token check enforces and name the TADR-003 line 35 review that carries the rest.
6. Note 5. Route the slot-tree exclusions from T4 subjects and T5 grants to SP-10 and SP-13, or cite a source; note AM-H8-001 may move the slot row.
7. Notes 7 and 8. Cite HF-07a CSV line 24 for the stored slot access state; give WS's restore failure its own label rather than reusing DC-07.
8. Paper check. Replace the json identity round trip with a field-and-reference preservation check against the declared field tables; add walks or negative controls exercising at least DC-02, DT4-01 and DT4-02 (as revised).

VERIFY: In the worktree: npm run check:scope -- 87e88ccd578a999c79f25755bc9fa8a56bfc154a <candidate> --no-build; npm run check:docs; npm run check:project; node scripts/check-drift.mjs --sections docs/tech/schemas (your stated SC-03 and SC-04 hashes must bind: the worktree lacks those files, so run this one check additionally from a copy of your file placed beside the main checkout's schemas, or state the binding limit and let the coordinator verify at integration); npm run check:drift; the revised paper check with --out under artifacts/local/tasks/SC-08/. Record exit codes and counts.

TIMEBOX: Checkpoint at handoff. Target 40 minutes.

FORBIDDEN: As A1: only the permitted files; no Resource, roster, count, dialogue line or value; no answer to Q-P37, Q-P14, Q-P28, Q-P08, Q-P06 or Q-P31; no builds, no native execution, no push, no rebase, no touching main or its files. If a change needs an admitted row altered, stop and submit an amendment request under artifacts/local/tasks/SC-08/.

REPORT: Commit only the permitted file on your branch and leave the tracked worktree clean. Report the new candidate SHA, file sha256, each required change item by item with line references, commands with exit codes, paper-check counts, CLAUDE_EFFORT, deviations, and state that you have stopped.
