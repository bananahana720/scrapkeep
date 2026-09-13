# HF-10-A2 coverage review (second fresh reviewer)

Reviewer: fresh scrapkeep-reviewer (claude-fable-5-1, effort medium pinned by agent definition; did not write either attempt or the first coverage review; CLAUDE_EFFORT not exposed). Reviewed identity: worktree /home/andrew/Projects/scrapkeep-wt-HF-10, head d951df5c5fa238470c8a6c9ceba3a377bfe49994, base 52423b18c8075ac5b8e18f6aa6f8b1a1a0a0a6f8, report sha256 ba7e4cf9e5d0c50fb8f4bb438f737e60d9fd6702baaabcaabaab86018826da30. Verbatim report follows.

---

**Verdict: PASS+NOTES on coverage.** Evidence level 3 (walked) for G1, G2, G3 counts and G5; level 2 (file:line) for G4 and the ORCHESTRATOR citation note; level 4 (coordinator receipt) for G6, the report hash, and the changed-path list. No note violates the definition of done.

## Acceptance lines

**1. G1 — PASS (level 3).** Six named findings each have an item with a reason: N4 → N-17 (report:108); N6 → N-18 (:110); HF-04b line 52 → N-19 (:112); check_patterns.py any-column → N-20 (:114); HF-06a N-050/N-012 → N-21 (:116); HF-07a three overstated claims → N-22 (:118). Disposition table at report:126-180 has 55 rows. Carried-findings finding lines counted: 16; the table cites exactly those 16 line refs and the sub-finding rows reconcile to 55. `paper.log:25` agrees (level 4).

**2. G2 — PASS (level 3).** HF-01's six bullets at `HF-01:93-98` and HF-02's eight cases at `HF-02:74-81` are walked at report:260 and :261 with the same evidence-level form as the other walks; spot-checked support lines HF-01:39, :87-89, HF-02:17, :50 say what the walks attribute; DoD 3 tally at report:302 opens "6 + 8 + 11 + 51 + …".

**3. G3 — PASS (level 3).** `attempt-2/rerun-consolidated.txt` holds exactly fifteen `EXIT=` lines in the table's order with codes 0,0,1,1,0,1,1,0,0,0,0,0,0,0,0 matching row by row; every count matches its log line; `rerun/HF-01/coverage.json` and `rerun/HF-02/focused-check.json` exist; the 346→347 correction is stated at report:236 and :243 and shown at log:62.

**4. G4 — PASS (level 2).** RF-1 to RF-9 (report:54-70) and N-01 to N-22 (:76-118) each end with an evidence-level sentence; the disposition table carries a level column.

**5. G5 — PASS (level 3).** All sixteen hashes and receipt counts at report:17-32 match `manifest.json`. Matrix at :190-202: PASS 32, NOTES 25, FAIL 8, equal to :204; the eight FAIL cells each carry a path and line. RF-1 to RF-9 present with the citations the first review spot-verified. "Unchanged in substance" is an inference from `paper.log:11-13` and the citation match. Eleven other walks at :262-271, question state at :208-212, both cross-reads at :214-228 present.

**6. G6 — PASS on receipts (level 4).** `verification.json:43-61` scope/docs/project exit 0; `paper.log:29` 28 checks 0 failed with the new assertion and its negative control; `attempt-2/checks.json:9-41` records the writer-side exits.

**Boundary.** `verification.json:9-25` lists 15 changed paths: the report plus 14 files under `tasks/HF-10/attempt-2/`; Glob confirms exactly those; `cleanTracked: true`.

## Remaining coverage gap

None that fails an acceptance line. Notes:
1. Report:36 cites ORCHESTRATOR "§ Handoff and review (lines 96 to 110)" and report:324 cites `ORCHESTRATOR.md:104`; in the worktree the section starts at :78, the fresh-reviewer rule is :90, :96 opens § Serial integration and :104 is the done-transition sentence. Citation defect only. Level 2.
2. Report:310 states the `check:scope` handoff sentence twice. Wording only.
3. Disposition row :159 (about 21 of 841 assertions cannot fail) is "recorded and not recounted" at level 2; the one carried item the report did not independently verify.
4. Row :126 (N1) maps to "Cross-read 2" rather than an N-item; report:228 states it is a note rather than a required fix, so the form is met.
