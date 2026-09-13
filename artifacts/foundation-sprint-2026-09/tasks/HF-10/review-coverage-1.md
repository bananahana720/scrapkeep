# HF-10-A1 coverage review (second fresh reviewer)

Reviewer: fresh scrapkeep-reviewer (claude-fable-5-1, effort medium pinned by agent definition; CLAUDE_EFFORT not exposed). Reviewed identity: worktree /home/andrew/Projects/scrapkeep-wt-HF-10, head 07a5347c4c1f194c842f136499507f12579980cb, report sha256 b94095adf1281f954cde27d1bff05cca6a20e020965deb54b3767a2ba38bd8b3. Verbatim report follows.

---

**Verdict: FAIL on coverage** (evidence level 2 file:line for the gaps; level 4 receipt for the rerun-log findings).

## Coverage gaps, ranked

**G1. Six carried findings have no disposition** (assignment.md:9: each must appear as a required fix, a note, or an explicit rejection with reason). Grep of the report for each finding's distinguishing terms returned no match:
- Integrated N4 (`carried-findings.md:9`): capacities routed to Q-E03 under B-memory/N-memory with no such HF-02 row.
- Integrated N6 (`carried-findings.md:11`): validators straddling HF-01:36, HF-03a:23,34 and HF-05:45-52.
- HF-04b (`carried-findings.md:15`): "line 52 is a source reading under an assertion-established column" and "check_patterns.py accepts an owner name in any column".
- HF-06a (`carried-findings.md:17`): "N-050 and N-012 stretch SC-07 and SC-08 cover lists".
- HF-07a (`carried-findings.md:19`): "three coverage claims overstate".

**G2. DoD 3: HF-01 and HF-02 scenarios are neither walked nor script-replayed.** HF-01 has six scenario bullets at `HF-01-production-conventions.md:93-98`; HF-02 has eight numbered cases at `HF-02-constraints-evidence.md:74-81`. The report's hand-walk list (report:180-191) and its tally at report:222 start at HF-03a. The scripts do not substitute: `rerun/HF-01/check-coverage.py:69-76` is a hardcoded string list, and `rerun/HF-02/check-register.py:26-33` mutates five register properties that touch HF-02 scenarios 2-3 only.

**G3. Rerun receipts do not support the report's rerun table (level 4).** Retained `attempt-1/rerun-log.txt` holds 7 of the 15 rows. Its HF-05 entry is a `FileNotFoundError` traceback, `EXIT=1` (rerun-log.txt:1049-1060), not the "126 checks, 1 failure" at report:168; `rerun/HF-05/paper-check.json` shows a later run consistent with the report, but the logs of that run (`rerun-log2.txt`, `rerun-log3.txt`) were not retained under attempt-1. `rerun/HF-01/` and `rerun/HF-02/` contain only the `.py`; no `coverage.json`/`focused-check.json`, so those two exit codes rest on the report's word. `paper.log:23` only checks that the report's table has exit-code text.

**G4 (note).** DoD 1 evidence level is stated once in aggregate (report:46, :72), not per finding.

## Items that pass

- Identities: all 16 SHA256 values at report:17-32 match `manifest.json`; receipt counts per row match; `paper.log:4` confirms 16 verified (receipt).
- Matrix: 13 rows, five named columns (report:110-124); 32 PASS, 25 NOTES, 8 FAIL, equal to report:126; every FAIL cell carries a path and line; RF-1,2,3,4,6,7,8,9 each map to a FAIL cell; RF-5 is declared out of matrix at report:126.
- Scenario artefacts covered for the other eleven sections (HF-03a M01-M11, HF-03b W1-W3, HF-04a T1-T5, HF-04b R1-R8, HF-05 T1-T4, HF-06a C01-C10, HF-06b C01-C14, HF-07a S1-S8, HF-07b C1-C4 and :141-149 matrix, HF-08 R8 20 rows + V1-V6 + AC-1..8, HF-09 W1-W5). Two derivative summary tables (`HF-07b:249-257`, `HF-09:355-366`) are not named explicitly (minor).
- Independence and boundary: report:5, :232, :236-244 claim no native behaviour; `verification.json:9-11` lists the report as the only changed file (receipt). Report:3 labels its Opus 5 self-description as unverified.
- Question state and both cross-reads present at report:130-150.

## Spot verification

- RF-7 real (`HF-07b:34`, :71, :80, :89, :100, :239-241; caveat that `:73` lists `offered_choices` under A, so the fix may fold presentation into A).
- RF-8 real (`HF-08:52`, :125, :167, :184).
- RF-1 real, with one soft spot: `HF-04b:82` literally exempts helper names as sketch-local, so the report's cross-module reading is a reading; the HF-04b/HF-03b divergence is nonetheless real.

## Accepted notes

- Demotion of HF-07a `mount_id` to N-12(a) and Transition D to N-14(a) are accompanied by reasons. Acceptable.
- Report:3 and :216 record HEAD as the base, consistent with the retained workflow.

PASS+NOTES is not admissible: G1 violates the card-specific disposition requirement and G2 leaves two sections' scenarios unreproduced against DoD 3. Fix scope is small: add six dispositions, walk HF-01:93-98 and HF-02:74-81, and retain the missing rerun logs and outputs.
