# HF-10 assignment A2

GOAL: Revise the HF-10 foundation review report so it passes the second reviewer's coverage check: every carried finding dispositioned, HF-01 and HF-02 scenarios reproduced, and every rerun receipt retained.

SCOPE: /home/andrew/Projects/scrapkeep-wt-HF-10, branch wt/HF-10, current head 07a5347c4c1f194c842f136499507f12579980cb (attempt 1 candidate, built on base 52423b18c8075ac5b8e18f6aa6f8b1a1a0a0a6f8), exclusive lease HF-10-L2, attempt HF-10-A2. Writer scrapkeep-writer (claude-opus-5 high pinned by its agent definition; report CLAUDE_EFFORT and the self-described model). Permitted files: artifacts/foundation-sprint-2026-09/HF-10-foundation-review.md; artifacts/foundation-sprint-2026-09/tasks/HF-10/ (add your retained receipts under a new attempt-2 subdirectory only; do not modify attempt-1, carried-findings.md, manifest.json, manifest.mjs, assignment.md, assignment-A2.md or review-coverage-1.md); artifacts/local/tasks/HF-10/.

CONTEXT: Read the attempt-1 packet at artifacts/foundation-sprint-2026-09/tasks/HF-10/assignment.md (its card-specific notes and the exact card still govern), then the coverage review at artifacts/foundation-sprint-2026-09/tasks/HF-10/review-coverage-1.md in full. The attempt-1 report at HEAD is your starting text; keep every finding, identity, matrix cell and rerun row that the coverage review confirmed, and change only what the three gaps require. Note that manifest.json and manifest.mjs are now committed at artifacts/foundation-sprint-2026-09/tasks/HF-10/ in the main checkout (read-only for you) and match the hashes you recomputed.

ACCEPTANCE, one per line:
1. G1: each of the six carried findings named in review-coverage-1.md (integrated-read N4 and N6; HF-04b line 52 source-reading note and check_patterns.py any-column owner check; HF-06a N-050 and N-012 producer stretch; HF-07a three overstated coverage claims) appears in the report as a required fix, a note, or an explicit rejection with reason, and a disposition table maps every line of carried-findings.md to its report item so the reviewer confirms coverage by one lookup.
2. G2: the six HF-01 scenario bullets at docs/tech/sections/HF-01-production-conventions.md:93-98 and the eight HF-02 cases at HF-02-constraints-evidence.md:74-81 are walked by hand in the Scenarios section with the same evidence level statement as the other hand walks, and the DoD 3 tally includes them.
3. G3: rerun HF-01/check-coverage.py and HF-02/check-register.py from their retained copies (via your make-shadow-root.sh) with outputs captured under artifacts/local/tasks/HF-10/rerun/HF-01/ and rerun/HF-02/, and produce one consolidated rerun log covering all fifteen rows of your rerun table in which every exit code and count in the table is visible; name that log's path in the table caption. If any rerun result differs from the attempt-1 table, correct the table and say so.
4. G4: state the evidence level per required fix and per note, not only in aggregate.
5. Everything the coverage review listed under "Items that pass" is unchanged in substance: sixteen identities, the 13-by-5 matrix with its counts, RF-1 to RF-9, the eleven other sections' scenario coverage, the question-state and cross-read sections.
6. check:docs and check:project exit 0; your check_review.py exit 0, extended with one assertion that every carried-findings.md line has a disposition row.

VERIFY: npm run check:scope -- 52423b18c8075ac5b8e18f6aa6f8b1a1a0a0a6f8 <candidate> --no-build; npm run check:docs; npm run check:project; python3 artifacts/local/tasks/HF-10/check_review.py . --out artifacts/local/tasks/HF-10; the retained-script reruns above. The coordinator reruns and retains receipts.

TIMEBOX: 30 minutes; this is a bounded revision. Report partial progress and stop if the gaps prove larger than described.

FORBIDDEN: No edits to any docs/tech/sections file, TRACKING.md, ORCHESTRATOR.md or BACKLOG.md; no changes to the attempt-1 retained directory; no builds, native or browser execution; no push, rebase or touching main; no re-litigating findings the coverage review confirmed.

REPORT: Commit on wt/HF-10 and leave the tracked worktree clean. Report candidate SHA, changed paths, sha256 of the report, each acceptance line with its evidence, commands run with exit codes, the consolidated rerun log path, CLAUDE_EFFORT and self-described model, deviations, and state that you have stopped.
