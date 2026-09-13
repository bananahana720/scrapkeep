# HF-10 assignment A1

GOAL: Complete HF-10 revision 2 against the full exact card below: an independent foundation review report over the thirteen admitted outputs with required fixes, notes, evidence levels, exact reviewed identities, the thirteen-by-five check matrix, and every paper scenario reproduced from the retained receipts.

SCOPE: /home/andrew/Projects/scrapkeep-wt-HF-10, branch wt/HF-10, verified base 52423b18c8075ac5b8e18f6aa6f8b1a1a0a0a6f8, exclusive lease HF-10-L1, attempt HF-10-A1. Writer scrapkeep-writer (model and effort pinned by its agent definition under .claude/agents after TRACKING EV-0149; report the runtime CLAUDE_EFFORT value and the self-described model name). Permitted files: artifacts/foundation-sprint-2026-09/HF-10-foundation-review.md; artifacts/foundation-sprint-2026-09/tasks/HF-10/; artifacts/local/tasks/HF-10/.

CONTEXT: Full foundation authorization TRACKING EV-0078 (documentation-only, no approval pauses) applies. Read AGENTS.md, docs/project/README.md, CONTRIBUTING.md, ORCHESTRATOR.md (Handoff and review), both project task/verify skills under .agents/skills, and every exact card source below. Current source claims come from inspection. All dependency sections are the admitted bytes at this base; cite them by path and line. Already admitted S0 proofs and retained receipts are historical evidence, never new execution. Required section headings come from docs/tech/sections/README.md (Sources, Contract, Scenarios, Unresolved questions, Re-verification triggers, Procedure performed, Evidence limits). Known gotchas: HF-05 section line 8 cites TADR-004 where TADR-003:41 is correct, do not propagate it; scripts/check-docs.mjs scans only .md files and resolves relative links against the containing file, so a CSV output gets no automated link or parity check and you must supply one in your paper check.

Card-specific notes. This card is a review, not a section: your only tracked output is artifacts/foundation-sprint-2026-09/HF-10-foundation-review.md plus retained receipts under artifacts/foundation-sprint-2026-09/tasks/HF-10/ (the card permits that directory; keep the coordinator's carried-findings.md, manifest.json and manifest.mjs there unchanged and add your receipts beside them). You are the independent reviewer of the thirteen outputs; you wrote none of them. The exact reviewed identity of every output, with sha256 and its retained receipt directory listing, is in artifacts/foundation-sprint-2026-09/tasks/HF-10/manifest.json at this base; cite those hashes as the reviewed draft identities. Read artifacts/foundation-sprint-2026-09/tasks/HF-10/carried-findings.md first: it lists every note the per-card reviews and integrated read 1 (artifacts/foundation-sprint-2026-09/integrated-read-1/report.md) recorded, and each must appear in your report as a required fix, a note, or an explicit rejection with reason. DoD 2's matrix has thirteen rows (HF-01, HF-02, HF-03a, HF-03b, HF-04a, HF-04b, HF-05, HF-06a, HF-06b, HF-07a, HF-07b, HF-08, HF-09) and five columns (module boundaries, tick ownership, content/persistence coverage, transition order, unresolved parameter gates), each cell PASS, FAIL or NOTES with a path and line per FAIL. DoD 3 requires you to reproduce every paper scenario from the retained receipts: rerun each retained check script from its retained copy against this worktree with --out under artifacts/local/tasks/HF-10/ (check_graph.py for HF-03b, check_patterns.py for HF-04b, check_matrix.py for HF-06a, check_projection.py for HF-06b, check_envelope.py for HF-07a, check_boundaries.py for HF-07b, check_recovery.py for HF-08, check_migration.py for HF-09, and the HF-03a, HF-04a and HF-05 scripts under their attempt-1 directories, following the run-from-scratch cautions recorded at TRACKING EV-0096 and EV-0097), record every exit code and count, and walk the walkthroughs, traces, tabletop cases and the interruption matrix by hand where a script does not replay them. Question state at this base: Q-P14, Q-P15, Q-E09, Q-P16 and Q-E05 are proposed (engineering-half protocols only, TRACKING EV-0144, EV-0151, EV-0157, EV-0163, EV-0170) and Q-E03 is open; confirm no section treats any of them as settled. Two seams need an explicit cross-read: HF-08 line 367 versus HF-09's reject handling, and HF-04b's retain_revision and read_initial_snapshot names versus HF-03a, HF-03b and HF-05 (integrated-read N1 and N2). No cell asserts native behavior. Your report is review evidence the coordinator records; a second fresh reviewer checks its coverage before it is recorded, per ORCHESTRATOR § Handoff and review, so state your evidence level per finding and cite path and line for every claim.

ACCEPTANCE: Every item in the exact card below, the required section headings, exact source identities, scenario receipts and limitations. Do not merely restate the DoD; produce the complete usable contract.

VERIFY: In the worktree: npm run check:scope -- 52423b18c8075ac5b8e18f6aa6f8b1a1a0a0a6f8 <candidate> --no-build; npm run check:docs; npm run check:project; plus the card-specific paper checks. Save an executable paper check under artifacts/local/tasks/HF-10/ (ignored) that accepts an explicit repository root and an --out directory for its receipts, so the coordinator can rerun it from a retained copy without rewriting retained files; never write into artifacts/foundation-sprint-2026-09/. The coordinator independently reruns and retains receipts.

TIMEBOX: Checkpoint within 15 active minutes and at handoff with actual paths, artifacts and blockers. Initial target 60 minutes for M; reassess from evidence; never claim elapsed time as progress.

FORBIDDEN: No edits to TRACKING.md, ORCHESTRATOR.md or BACKLOG.md; no builds, no native or browser execution, no dependency, asset or runtime changes, no publication, no invented product answers, no push, no rebase, no touching main. A registered non-blocking question keeps every candidate answer open: the contract must hold under each, and an engineering-half protocol may be submitted only as a proposal in your report, never written as an answer. If a source contradiction prevents the exact DoD, stop affected work and submit an amendment request in the form of docs/project/sprint-0/amendment-request.md under artifacts/local/tasks/HF-10/; do not silently weaken the contract.

REPORT: Commit only permitted output files on your branch and leave the tracked worktree clean. Report candidate SHA, base, changed paths, sha256 of each output, DoD coverage item by item, commands run with exit codes, receipt paths, CLAUDE_EFFORT value, proposed question protocols if any, deviations and follow-ups, and state explicitly that you have stopped.

## Exact card

### HF-10: Review the complete foundation contract

**Card revision:** 2 · **Owner:** Independent review · **Size:** M · **Lane:** foundation

**Source and inputs:**

- [adr/TADR-001-engine-language-platforms.md](adr/TADR-001-engine-language-platforms.md)
- [adr/TADR-002-runtime-model.md](adr/TADR-002-runtime-model.md)
- [adr/TADR-003-content-pipeline.md](adr/TADR-003-content-pipeline.md)
- [adr/TADR-004-persistence.md](adr/TADR-004-persistence.md)
- [adr/TADR-005-networking-scope.md](adr/TADR-005-networking-scope.md)
- `docs/tech/sections/HF-01-production-conventions.md` from [HF-01](#hf-01) (must be admitted before assignment)
- `docs/tech/sections/HF-02-constraints-evidence.md` from [HF-02](#hf-02) (must be admitted before assignment)
- `docs/tech/sections/HF-03a-module-map.md` from [HF-03a](#hf-03a) and `docs/tech/sections/HF-03b-dependency-graph.md` from [HF-03b](#hf-03b) (must be admitted before assignment)
- `docs/tech/sections/HF-04a-runtime-lifecycle.md` from [HF-04a](#hf-04a) and `docs/tech/sections/HF-04b-runtime-patterns.md` from [HF-04b](#hf-04b) (must be admitted before assignment)
- `docs/tech/sections/HF-05-content-admission.md` from [HF-05](#hf-05) (must be admitted before assignment)
- `docs/tech/sections/HF-06a-schema-inventory.md` from [HF-06a](#hf-06a) and `docs/tech/sections/HF-06b-persistence-projection.md` from [HF-06b](#hf-06b) (must be admitted before assignment)
- `docs/tech/sections/HF-07a-save-envelope.md` from [HF-07a](#hf-07a) and `docs/tech/sections/HF-07b-commit-boundaries.md` from [HF-07b](#hf-07b) (must be admitted before assignment)
- `docs/tech/sections/HF-08-save-recovery.md` from [HF-08](#hf-08) (must be admitted before assignment)
- `docs/tech/sections/HF-09-schema-migration.md` from [HF-09](#hf-09) (must be admitted before assignment)
- The pinned card revision of each output above and its retained receipts under `artifacts/foundation-sprint-2026-09/tasks/ID/`
- [BIBLE.md § 6. Core Systems](BIBLE.md#6-core-systems) (Product invariants; cite the specific relevant system pages in the output.)

**Dependencies:** [HF-01](#hf-01), [HF-02](#hf-02), [HF-03a](#hf-03a), [HF-03b](#hf-03b), [HF-04a](#hf-04a), [HF-04b](#hf-04b), [HF-05](#hf-05), [HF-06a](#hf-06a), [HF-06b](#hf-06b), [HF-07a](#hf-07a), [HF-07b](#hf-07b), [HF-08](#hf-08), [HF-09](#hf-09). **Blocking questions:** None.

**Files touched:** `artifacts/foundation-sprint-2026-09/HF-10-foundation-review.md`; `artifacts/foundation-sprint-2026-09/tasks/HF-10/` (retained receipts); `artifacts/local/tasks/HF-10/`. The report is review evidence recorded by the coordinator, not a TECH_BIBLE section.

**Definition of done:**

1. Produce an independent report with required fixes, notes, evidence level and the exact reviewed draft identity (commit or content hash) of every output.
2. One matrix with one row per foundation output (the audit's nine-by-five form, extended to the thirteen outputs after the splits) and five check columns: module boundaries, tick ownership, content/persistence coverage, transition order and unresolved parameter gates. Each cell is PASS, FAIL or NOTES, with a path and line per FAIL.
3. Reproduce every paper scenario (walkthroughs, traces, tabletop cases and the interruption matrix) from the retained receipts. No cell asserts native behavior.
4. The reviewer reports only. The coordinator records the report, and a second fresh reviewer checks its coverage before it is recorded, per ORCHESTRATOR § Handoff and review.

**Verification and evidence:**

- Read all thirteen foundation outputs together and reproduce their paper scenarios from the retained receipts.
- Check author/reviewer independence and distinguish source review from future native qualification.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

