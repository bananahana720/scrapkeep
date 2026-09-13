# HF-09 assignment A1

GOAL: Complete HF-09 revision 2 against the full exact card below: a compatibility predicate with an accept, migrate or reject table, ordered single-step chained migration committed through the HF-07b protocol, negative-case handling with one tabletop case each, and the named browser records preserved untouched under Q-E05.

SCOPE: /home/andrew/Projects/scrapkeep-wt-HF-09, branch wt/HF-09, verified base 2db978b7e8220e8b414d808d2a7d782b72492b58, exclusive lease HF-09-L1, attempt HF-09-A1. Writer scrapkeep-writer (model and effort pinned by its agent definition under .claude/agents after TRACKING EV-0149; report the runtime CLAUDE_EFFORT value and the self-described model name). Permitted files: docs/tech/sections/HF-09-schema-migration.md; artifacts/local/tasks/HF-09/.

CONTEXT: Full foundation authorization TRACKING EV-0078 (documentation-only, no approval pauses) applies. Read AGENTS.md, docs/project/README.md, CONTRIBUTING.md, ORCHESTRATOR.md (Handoff and review), both project task/verify skills under .agents/skills, and every exact card source below. Current source claims come from inspection. All dependency sections are the admitted bytes at this base; cite them by path and line. Already admitted S0 proofs and retained receipts are historical evidence, never new execution. Required section headings come from docs/tech/sections/README.md (Sources, Contract, Scenarios, Unresolved questions, Re-verification triggers, Procedure performed, Evidence limits). Known gotchas: HF-05 section line 8 cites TADR-004 where TADR-003:41 is correct, do not propagate it; scripts/check-docs.mjs scans only .md files and resolves relative links against the containing file, so a CSV output gets no automated link or parity check and you must supply one in your paper check.

Card-specific notes. Dependency bytes at this base: HF-06b section sha256 63cb58810eac36da3c70855868873c60ffb25f1c32c0c8e1b73e7adcceefd7f2 and CSV 8ba1476b42ad206eea09bc6ea411a5f297afdcb1f4d596cdf686b4afdf8cec15 (14 json-projection rows, 15 projection groups, rule 4 every projected ID is a JSON string at its line 34), HF-07a section sha256 1d295df34c40e60b9d0e66a22de7691ce3fcf261ffb84a4a80fe49b2eb91ea0a and CSV df4b60f562cc5dce2db2e23a7cb6a932e9e3c472572ad2114045070f3704753a (schema_version, content_revision, generation, transaction_id at its line 172; profile.discoveries, profile.recipes, profile.unlocks at :88-90), HF-07b section sha256 f07f6154e1947ef64f090271d6ec8ab826385a3f23d72a2d1dc38181d8b42863 (the commit protocol a migrated generation must pass through), HF-05 section sha256 7ef95df2fb25f05b7b544cd7dbf2239cd1106c382aab0e8bc5e76288146259a6 (content compatibility, missing-ID diagnostics ContentReferenceFailure :101 and ContentAdmissionFailure :117, pinning :74). TADR-003 § Consequences is adr/TADR-003-content-pipeline.md:37 onward; TADR-004 § Decision :22-34 and § Consequences :36 onward (browser storage preservation). Registered non-blocking question Q-E05 (BACKLOG.md:2670) gates any import; the contract must hold under every candidate answer and HF-09 reads none of the browser records. The two browser records to name by file and key were resolved by the coordinator and committed at artifacts/foundation-sprint-2026-09/tasks/HF-09/storage-keys.md: src/campaign.js:115 is the version-1 profile predicate for the record persisted by src/progress-store.js (createProgressStore at :8, version predicate at :45) under the key src/collection.js:29-31 selects, "scrapkeep.collection.v1" or "scrapkeep.qa.collection.v1" with the qa query flag; src/main.js:48,141 hold the separate bestKey best-wave record and src/orchard/main.js:20,106 the "orchard-settings" key. Verify those lines yourself at this base and cite them. Cite HF-06b, HF-07a and HF-07b by their BACKLOG card titles. Do not copy retain_revision-at-replacement or read_initial_snapshot from HF-04b. Do not depend on equipment mount_id or on build, equipment or companion container rows (HF-07a review notes N2, N3). S0-08 is done, so the DoD 2 re-verify trigger has already fired: reconcile by source review of docs/tech/proofs/S0-08-save-evidence.md and its retained receipts without executing anything. Admitting a second schema version fires the S0-07 trigger at docs/tech/proofs/S0-07-save-owner.md:116; record that reconciliation in your section. Your paper check should walk the four verification cases (a compatible migration, a rejected future version, a missing recipe, a repeated load) mechanically through the accept, migrate or reject table.

ACCEPTANCE: Every item in the exact card below, the required section headings, exact source identities, scenario receipts and limitations. Do not merely restate the DoD; produce the complete usable contract.

VERIFY: In the worktree: npm run check:scope -- 2db978b7e8220e8b414d808d2a7d782b72492b58 <candidate> --no-build; npm run check:docs; npm run check:project; plus the card-specific paper checks. Save an executable paper check under artifacts/local/tasks/HF-09/ (ignored) that accepts an explicit repository root and an --out directory for its receipts, so the coordinator can rerun it from a retained copy without rewriting retained files; never write into artifacts/foundation-sprint-2026-09/. The coordinator independently reruns and retains receipts.

TIMEBOX: Checkpoint within 15 active minutes and at handoff with actual paths, artifacts and blockers. Initial target 60 minutes for M; reassess from evidence; never claim elapsed time as progress.

FORBIDDEN: No edits to TRACKING.md, ORCHESTRATOR.md or BACKLOG.md; no builds, no native or browser execution, no dependency, asset or runtime changes, no publication, no invented product answers, no push, no rebase, no touching main. A registered non-blocking question keeps every candidate answer open: the contract must hold under each, and an engineering-half protocol may be submitted only as a proposal in your report, never written as an answer. If a source contradiction prevents the exact DoD, stop affected work and submit an amendment request in the form of docs/project/sprint-0/amendment-request.md under artifacts/local/tasks/HF-09/; do not silently weaken the contract.

REPORT: Commit only permitted output files on your branch and leave the tracked worktree clean. Report candidate SHA, base, changed paths, sha256 of each output, DoD coverage item by item, commands run with exit codes, receipt paths, CLAUDE_EFFORT value, proposed question protocols if any, deviations and follow-ups, and state explicitly that you have stopped.

## Exact card

### HF-09: Specify schema and gameplay-content migration

**Card revision:** 2 · **Owner:** Persistence · **Size:** M · **Lane:** foundation

**Source and inputs:**

- [adr/TADR-003-content-pipeline.md § Consequences](adr/TADR-003-content-pipeline.md#consequences)
- [adr/TADR-004-persistence.md § Decision](adr/TADR-004-persistence.md#decision) and [§ Consequences](adr/TADR-004-persistence.md#consequences) (browser storage preservation)
- [Q-E05](#q-e05)
- `src/campaign.js:115` and `src/progress-store.js:45`, the two browser storage records this card preserves
- `docs/tech/sections/HF-05-content-admission.md` from [HF-05](#hf-05) (content compatibility and missing IDs)
- `docs/tech/sections/HF-06b-persistence-projection.md` from [HF-06b](#hf-06b) (must be admitted before assignment)
- `docs/tech/sections/HF-07a-save-envelope.md` from [HF-07a](#hf-07a) and `docs/tech/sections/HF-07b-commit-boundaries.md` from [HF-07b](#hf-07b) (must be admitted before assignment)
- [BIBLE.md § 6. Core Systems](BIBLE.md#6-core-systems) (Product invariants; cite the specific relevant system pages in the output.)

**Dependencies:** [HF-06b](#hf-06b), [HF-07b](#hf-07b). **Blocking questions:** None. **Registered non-blocking questions:** [Q-E05](#q-e05). The contract must hold under every candidate answer; the card may submit a proposed protocol for the engineering half of a question as `proposed` in TRACKING, never as an answer.

**Files touched:** `docs/tech/sections/HF-09-schema-migration.md`; `artifacts/local/tasks/HF-09/`.

**Definition of done:**

1. (1a) A compatibility predicate over schema version, content revision and catalogue version with an accept, migrate or reject table.
2. (1b) Chaining as ordered single-step migrations, each validated before the next; the original stays untouched until the migrated generation commits through the HF-07b protocol. Re-verify when S0-08 lands.
3. Specify missing ID, incompatible content and newer-format handling without rerolling, losing discoveries or adding active effects. One tabletop case per negative appears in the output.
4. Name the browser records preserved by file and key (`src/campaign.js:115`, `src/progress-store.js:45`). State that HF-09 reads none of them. Q-E05 gates any import, and the contract holds under every candidate answer.

**Verification and evidence:**

- Walk one compatible migration, a rejected future version, a missing recipe and a repeated load through the proposed rules.
- Review that no migration implicitly imports or overwrites the named browser storage.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

