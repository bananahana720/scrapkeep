# HF-06b assignment A1

GOAL: Complete HF-06b revision 1 against the full exact card below: one save column value per HF-06a row (json-projection, transient-reconstructed or immutable-by-id with rationale), codec and projection and TH-22 proof ownership for json rows, in Markdown and CSV keyed by the HF-06a row IDs.

SCOPE: /home/andrew/Projects/scrapkeep-wt-HF-06b, branch wt/HF-06b, verified base 2d33632136918703a2d64d9ca8f05bf03d45fcd4, exclusive lease HF-06b-L1, attempt HF-06b-A1. Writer scrapkeep-writer (claude-fable-5-1, effort pinned by the agent definition; report the runtime CLAUDE_EFFORT value). Permitted files: docs/tech/sections/HF-06b-persistence-projection.md; docs/tech/sections/HF-06b-persistence-projection.csv; artifacts/local/tasks/HF-06b/.

CONTEXT: Full foundation authorization TRACKING EV-0078 (documentation-only, no approval pauses) applies. Read AGENTS.md, docs/project/README.md, CONTRIBUTING.md, ORCHESTRATOR.md (Handoff and review), both project task/verify skills under .agents/skills, and every exact card source below. Current source claims come from inspection. All dependency sections are the admitted bytes at this base; cite them by path and line. Already admitted S0 proofs and retained receipts are historical evidence, never new execution. Required section headings come from docs/tech/sections/README.md (Sources, Contract, Scenarios, Unresolved questions, Re-verification triggers, Procedure performed, Evidence limits). Known gotchas: HF-05 section line 8 cites TADR-004 where TADR-003:41 is correct, do not propagate it; scripts/check-docs.mjs scans only .md files and resolves relative links against the containing file, so a CSV output gets no automated link or parity check and you must supply one in your paper check.

Card-specific notes. Dependency bytes at this base: HF-06a section sha256 c83973f76c9e057b87d6af52c112e22ca2af13a37e631a3b842742a1dbcf403b, HF-06a CSV sha256 efc090287ed9a6bcfe481da2a0d73c6e462e135b6ed1ac04c55c6917dcac37e6 (67 rows F-01 to F-08 and N-001 to N-059; key your machine-readable copy by exactly these IDs), HF-05 section sha256 7ef95df2fb25f05b7b544cd7dbf2239cd1106c382aab0e8bc5e76288146259a6. Registered non-blocking questions: Q-P14 (BACKLOG.md:2978), Q-P15 (:2992), Q-E09 (:2726); their engineering-half protocols are recorded as proposed, not answered, at TRACKING EV-0144, so your device, companion and discovery rows must hold under every candidate answer and must not assume the proposals. TADR-004 § Decision is adr/TADR-004-persistence.md:22-34 and TADR-003 § Consequences is adr/TADR-003-content-pipeline.md:37 onward. The executable roundtrip proof owner to name for json-projection rows is TH-22 (BACKLOG.md:1813). The integrated read (artifacts/foundation-sprint-2026-09/integrated-read-1/report.md, N3) asks that HF-06b and HF-07a be cited by their BACKLOG card titles; HF-06a's review (artifacts/foundation-sprint-2026-09/tasks/HF-06a/review.md) notes that N-052 names no parent row and that N-050 and N-012 stretch their producer cards, so treat those three rows with an explicit rationale rather than silently. Do not copy retain_revision-at-replacement or read_initial_snapshot from HF-04b. The CSV must carry exactly the Markdown rows with the same IDs and save-column values; provide the md/csv parity check in your paper check because check:docs does not read CSV. S0-08 is done, so the DoD 2 re-verify trigger has already fired: reconcile by source review of docs/tech/proofs/S0-08*.md and its retained receipts without executing anything.

ACCEPTANCE: Every item in the exact card below, the required section headings, exact source identities, scenario receipts and limitations. Do not merely restate the DoD; produce the complete usable contract.

VERIFY: In the worktree: npm run check:scope -- 2d33632136918703a2d64d9ca8f05bf03d45fcd4 <candidate> --no-build; npm run check:docs; npm run check:project; plus the card-specific paper checks. Save an executable paper check under artifacts/local/tasks/HF-06b/ (ignored) that accepts an explicit repository root and an --out directory for its receipts, so the coordinator can rerun it from a retained copy without rewriting retained files; never write into artifacts/foundation-sprint-2026-09/. The coordinator independently reruns and retains receipts.

TIMEBOX: Checkpoint within 15 active minutes and at handoff with actual paths, artifacts and blockers. Initial target 60 minutes for M; reassess from evidence; never claim elapsed time as progress.

FORBIDDEN: No edits to TRACKING.md, ORCHESTRATOR.md or BACKLOG.md; no builds, no native or browser execution, no dependency, asset or runtime changes, no publication, no invented product answers, no push, no rebase, no touching main. A registered non-blocking question keeps every candidate answer open: the contract must hold under each, and an engineering-half protocol may be submitted only as a proposal in your report, never written as an answer. If a source contradiction prevents the exact DoD, stop affected work and submit an amendment request in the form of docs/project/sprint-0/amendment-request.md under artifacts/local/tasks/HF-06b/; do not silently weaken the contract.

REPORT: Commit only permitted output files on your branch and leave the tracked worktree clean. Report candidate SHA, base, changed paths, sha256 of each output, DoD coverage item by item, commands run with exit codes, receipt paths, CLAUDE_EFFORT value, proposed question protocols if any, deviations and follow-ups, and state explicitly that you have stopped.

## Exact card

### HF-06b: Map matrix rows to persistence projections

**Card revision:** 1 · **Owner:** Persistence · **Size:** M · **Lane:** foundation

**Source and inputs:**

- [adr/TADR-004-persistence.md § Decision](adr/TADR-004-persistence.md#decision)
- [adr/TADR-003-content-pipeline.md § Consequences](adr/TADR-003-content-pipeline.md#consequences)
- [BIBLE.md § 6. Core Systems](BIBLE.md#6-core-systems) (Product invariants; cite the specific relevant system pages in the output.)
- `docs/tech/sections/HF-05-content-admission.md` from [HF-05](#hf-05)
- `docs/tech/sections/HF-06a-schema-inventory.md` and `.csv` from [HF-06a](#hf-06a) (must be admitted before assignment)

**Dependencies:** [HF-06a](#hf-06a). **Blocking questions:** None. **Registered non-blocking questions:** [Q-P14](#q-p14), [Q-P15](#q-p15), [Q-E09](#q-e09). The contract must hold under every candidate answer; the card may submit a proposed protocol for the engineering half of a question as `proposed` in TRACKING, never as an answer.

**Files touched:** `docs/tech/sections/HF-06b-persistence-projection.md`; `docs/tech/sections/HF-06b-persistence-projection.csv`; `artifacts/local/tasks/HF-06b/`.

**Definition of done:**

1. For every HF-06a row, one save column value from json-projection, transient-reconstructed or immutable-by-id; the latter two carry a rationale. Immutable Resources are not serialized as live engine objects.
2. For each json-projection row, name the authoring codec, the save projection and the card owning the executable roundtrip proof (TH-22). Re-verify when S0-08 lands.
3. A machine-readable copy keyed by the HF-06a row IDs.
4. Device, companion and discovery rows hold under every candidate answer to Q-P15 and Q-E09.

**Verification and evidence:**

- Check every HF-06a row has exactly one save column value.
- Check no row serializes a Resource as a live engine object.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

