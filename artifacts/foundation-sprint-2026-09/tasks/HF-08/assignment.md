# HF-08 assignment A1

GOAL: Complete HF-08 revision 2 against the full exact card below: the single-writer protocol and write, flush, commit ordering with a per-OS qualification row, a failure-class by stage state table, corrupt and ambiguous file preservation with an ambiguity checklist, and an interruption matrix as enumerable test-case rows.

SCOPE: /home/andrew/Projects/scrapkeep-wt-HF-08, branch wt/HF-08, verified base 2db978b7e8220e8b414d808d2a7d782b72492b58, exclusive lease HF-08-L1, attempt HF-08-A1. Writer scrapkeep-writer (model and effort pinned by its agent definition under .claude/agents after TRACKING EV-0149; report the runtime CLAUDE_EFFORT value and the self-described model name). Permitted files: docs/tech/sections/HF-08-save-recovery.md; artifacts/local/tasks/HF-08/.

CONTEXT: Full foundation authorization TRACKING EV-0078 (documentation-only, no approval pauses) applies. Read AGENTS.md, docs/project/README.md, CONTRIBUTING.md, ORCHESTRATOR.md (Handoff and review), both project task/verify skills under .agents/skills, and every exact card source below. Current source claims come from inspection. All dependency sections are the admitted bytes at this base; cite them by path and line. Already admitted S0 proofs and retained receipts are historical evidence, never new execution. Required section headings come from docs/tech/sections/README.md (Sources, Contract, Scenarios, Unresolved questions, Re-verification triggers, Procedure performed, Evidence limits). Known gotchas: HF-05 section line 8 cites TADR-004 where TADR-003:41 is correct, do not propagate it; scripts/check-docs.mjs scans only .md files and resolves relative links against the containing file, so a CSV output gets no automated link or parity check and you must supply one in your paper check.

Card-specific notes. Dependency bytes at this base: HF-07a section sha256 1d295df34c40e60b9d0e66a22de7691ce3fcf261ffb84a4a80fe49b2eb91ea0a and CSV df4b60f562cc5dce2db2e23a7cb6a932e9e3c472572ad2114045070f3704753a (envelope keys schema_version, content_revision, generation, transaction_id at its line 172; run.checkpoint.interruption :148; run.lifecycle.revival_spent :156; rejected keys :174-182; RecoveryState is owned by Persistence per HF-03a:35,49), HF-07b section sha256 f07f6154e1947ef64f090271d6ec8ab826385a3f23d72a2d1dc38181d8b42863 (four transitions with stage, validate, commit, acknowledge lists; candidate policies P1 to P4 and R1 to R3 pending Q-P16; invariants N1 to N7; the decision that acknowledgement leaves no durable trace, and that a preferences write is not a critical write), HF-03a section sha256 95fbd03d067fd0da2d122130ae3c54284116adc92f40c7f69c91946fd941e4cc (Persistence and PD-02 interface-state seam at its lines 35, 49). TADR-004 § Decision is adr/TADR-004-persistence.md:22-34 (hold on a failed write :32) and § Consequences :36 onward (ordering, single writer). TADR-001 § Decision is adr/TADR-001-engine-language-platforms.md:21-30 (Windows 11 x64 and Linux x64 as the target OS families at :23). Coordinator-resolved Godot 4.7 FileAccess, DirAccess, OS and data-path documentation, fetched 2026-09-12 via Context7 library /websites/godotengine_en_4_7: https://docs.godotengine.org/en/4.7/classes/class_fileaccess.html , https://docs.godotengine.org/en/4.7/classes/class_diraccess.html , https://docs.godotengine.org/en/4.7/classes/class_os.html , https://docs.godotengine.org/en/4.7/tutorials/io/data_paths.html ; the receipt is committed at artifacts/foundation-sprint-2026-09/tasks/HF-08/ctx7-godot-fileaccess-os.txt (read-only for you; cite it). Every durability claim on paper stays marked unqualified per the card; never claim rename alone proves durability, and never claim flush proves durability on a given OS without the documentation reference and the evidence method that would qualify it. Cite HF-07a, HF-07b and HF-09 by their BACKLOG card titles. Do not copy retain_revision-at-replacement or read_initial_snapshot from HF-04b. Do not depend on equipment mount_id or on build, equipment or companion container rows (HF-07a review notes N2, N3). S0-08 is done, so the DoD 1 re-verify trigger has already fired: reconcile by source review of docs/tech/proofs/S0-08-save-evidence.md and its retained receipts without executing anything, and mark every stage for re-verification when TH-22's proof lands. Your paper check should enumerate the interruption matrix rows mechanically (every HF-07b commit stage times rewards, revival and terminal facts) so the reviewer confirms coverage with one command.
Reserved to HF-08 from the HF-07b review (artifacts/foundation-sprint-2026-09/tasks/HF-07b/review.md, note 6): the failure-handling half of a preferences write; HF-07b decided its stages and that it is not a critical write, HF-08 owns what a failed preferences write holds and shows.

ACCEPTANCE: Every item in the exact card below, the required section headings, exact source identities, scenario receipts and limitations. Do not merely restate the DoD; produce the complete usable contract.

VERIFY: In the worktree: npm run check:scope -- 2db978b7e8220e8b414d808d2a7d782b72492b58 <candidate> --no-build; npm run check:docs; npm run check:project; plus the card-specific paper checks. Save an executable paper check under artifacts/local/tasks/HF-08/ (ignored) that accepts an explicit repository root and an --out directory for its receipts, so the coordinator can rerun it from a retained copy without rewriting retained files; never write into artifacts/foundation-sprint-2026-09/. The coordinator independently reruns and retains receipts.

TIMEBOX: Checkpoint within 15 active minutes and at handoff with actual paths, artifacts and blockers. Initial target 60 minutes for M; reassess from evidence; never claim elapsed time as progress.

FORBIDDEN: No edits to TRACKING.md, ORCHESTRATOR.md or BACKLOG.md; no builds, no native or browser execution, no dependency, asset or runtime changes, no publication, no invented product answers, no push, no rebase, no touching main. A registered non-blocking question keeps every candidate answer open: the contract must hold under each, and an engineering-half protocol may be submitted only as a proposal in your report, never written as an answer. If a source contradiction prevents the exact DoD, stop affected work and submit an amendment request in the form of docs/project/sprint-0/amendment-request.md under artifacts/local/tasks/HF-08/; do not silently weaken the contract.

REPORT: Commit only permitted output files on your branch and leave the tracked worktree clean. Report candidate SHA, base, changed paths, sha256 of each output, DoD coverage item by item, commands run with exit codes, receipt paths, CLAUDE_EFFORT value, proposed question protocols if any, deviations and follow-ups, and state explicitly that you have stopped.

## Exact card

### HF-08: Specify save failure and conservative recovery

**Card revision:** 2 · **Owner:** Persistence · **Size:** M · **Lane:** foundation

**Source and inputs:**

- [adr/TADR-004-persistence.md § Decision](adr/TADR-004-persistence.md#decision) (hold on a failed write) and [§ Consequences](adr/TADR-004-persistence.md#consequences) (ordering and single writer)
- [adr/TADR-001-engine-language-platforms.md § Decision](adr/TADR-001-engine-language-platforms.md#decision) (target OS families)
- `docs/tech/sections/HF-03a-module-map.md` from [HF-03a](#hf-03a) (seam with PD-02 interface states)
- `docs/tech/sections/HF-07a-save-envelope.md` from [HF-07a](#hf-07a) and `docs/tech/sections/HF-07b-commit-boundaries.md` from [HF-07b](#hf-07b) (must be admitted before assignment)
- Godot 4.7 `FileAccess` and `OS` documentation, resolved by the coordinator and supplied in the packet.
- [BIBLE.md § 6. Core Systems](BIBLE.md#6-core-systems) (Product invariants; cite the specific relevant system pages in the output.)

**Dependencies:** [HF-07b](#hf-07b). **Blocking questions:** None.

**Files touched:** `docs/tech/sections/HF-08-save-recovery.md`; `artifacts/local/tasks/HF-08/`.

**Definition of done:**

1. Define the single-writer protocol and write/flush/commit ordering. For each TADR-001 target OS family, one row with the qualification question, the engine API surface by documentation reference and the evidence method. Never claim rename alone proves durability. Every stage is marked "unqualified on paper; re-verify when S0-08 lands, and again when the TH-22 proof lands".
2. A state table of failure class by transition stage giving the held state, message class, and permitted and forbidden actions, including user-visible retry and recovery states.
3. Preserve corrupt or ambiguous files and refuse rollback to a living/unspent generation when lifecycle continuity cannot be established. An ambiguity-conditions checklist names each condition.
4. An interruption matrix at every HF-07b commit stage for rewards, revival and terminal facts, stored in the output as enumerable test-case rows.

**Verification and evidence:**

- Review corrupt newest generation, unknown version, full disk and retry cases for false success or silent data loss.
- Check every matrix row names a stage, an outcome and a held state.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

