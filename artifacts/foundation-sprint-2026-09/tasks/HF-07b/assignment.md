# HF-07b assignment A1

GOAL: Complete HF-07b revision 1 against the full exact card below: durable commit boundaries as stage, validate, commit and acknowledge lists per transition, candidate revival and interruption policies with nonduplication invariants shown under each, and four tabletop cases as step tables.

SCOPE: /home/andrew/Projects/scrapkeep-wt-HF-07b, branch wt/HF-07b, verified base 79ed9c5790a896c85f769c5b4e4745aef6b4200d, exclusive lease HF-07b-L1, attempt HF-07b-A1. Writer scrapkeep-writer (model and effort pinned by its agent definition under .claude/agents after TRACKING EV-0149; report the runtime CLAUDE_EFFORT value and the self-described model name). Permitted files: docs/tech/sections/HF-07b-commit-boundaries.md; artifacts/local/tasks/HF-07b/.

CONTEXT: Full foundation authorization TRACKING EV-0078 (documentation-only, no approval pauses) applies. Read AGENTS.md, docs/project/README.md, CONTRIBUTING.md, ORCHESTRATOR.md (Handoff and review), both project task/verify skills under .agents/skills, and every exact card source below. Current source claims come from inspection. All dependency sections are the admitted bytes at this base; cite them by path and line. Already admitted S0 proofs and retained receipts are historical evidence, never new execution. Required section headings come from docs/tech/sections/README.md (Sources, Contract, Scenarios, Unresolved questions, Re-verification triggers, Procedure performed, Evidence limits). Known gotchas: HF-05 section line 8 cites TADR-004 where TADR-003:41 is correct, do not propagate it; scripts/check-docs.mjs scans only .md files and resolves relative links against the containing file, so a CSV output gets no automated link or parity check and you must supply one in your paper check.

Card-specific notes. Dependency bytes at this base: HF-07a section sha256 1d295df34c40e60b9d0e66a22de7691ce3fcf261ffb84a4a80fe49b2eb91ea0a and CSV df4b60f562cc5dce2db2e23a7cb6a932e9e3c472572ad2114045070f3704753a (60 fields in six anchored groups; reference fields by the exact names in its naming rule at its line 23, and use its envelope keys schema_version, content_revision, generation and transaction_id, its run.checkpoint.interruption and run.lifecycle.revival_spent fields, and its rejected-key table at lines 174-182); HF-04a section sha256 7eb7ad2c909b715e62051d2d73e353f445b96270f3140b38c1c38c4c3fc171fb (level completion seam and O1 to O4 ordering at its lines 87-90, scenario tables at 131-179). TADR-004 § Decision is adr/TADR-004-persistence.md:22-34; the hold-on-failed-write rule is at :32. DECISION-REGISTER rows D26 and D27 are docs/project/DECISION-REGISTER.md:49-50. Registered non-blocking questions: Q-E09 (BACKLOG.md:2726) and Q-P16 (:3006); their engineering-half protocols are recorded as proposed, not answered, at TRACKING EV-0144, EV-0151 and EV-0157, so your stage lists and the four tabletop cases must hold under every candidate policy and must not assume the proposals; you may submit a further Persistence-half Q-E09 protocol as a proposal in your report. The HF-07a review (artifacts/foundation-sprint-2026-09/tasks/HF-07a/review.md, notes N2 and N3) leaves open whether equipment mounts exist as named positions and gives build, equipment and companion containers no row; do not depend on either. Cite HF-07a, HF-08 and HF-09 by their BACKLOG card titles. Do not copy retain_revision-at-replacement or read_initial_snapshot from HF-04b. S0-08 is done, so the DoD 1 re-verify trigger has already fired: reconcile by source review of docs/tech/proofs/S0-08-save-evidence.md and its retained receipts without executing anything. Your paper check should reproduce every tabletop case against every candidate policy mechanically, so the reviewer reruns one command.

ACCEPTANCE: Every item in the exact card below, the required section headings, exact source identities, scenario receipts and limitations. Do not merely restate the DoD; produce the complete usable contract.

VERIFY: In the worktree: npm run check:scope -- 79ed9c5790a896c85f769c5b4e4745aef6b4200d <candidate> --no-build; npm run check:docs; npm run check:project; plus the card-specific paper checks. Save an executable paper check under artifacts/local/tasks/HF-07b/ (ignored) that accepts an explicit repository root and an --out directory for its receipts, so the coordinator can rerun it from a retained copy without rewriting retained files; never write into artifacts/foundation-sprint-2026-09/. The coordinator independently reruns and retains receipts.

TIMEBOX: Checkpoint within 15 active minutes and at handoff with actual paths, artifacts and blockers. Initial target 60 minutes for M; reassess from evidence; never claim elapsed time as progress.

FORBIDDEN: No edits to TRACKING.md, ORCHESTRATOR.md or BACKLOG.md; no builds, no native or browser execution, no dependency, asset or runtime changes, no publication, no invented product answers, no push, no rebase, no touching main. A registered non-blocking question keeps every candidate answer open: the contract must hold under each, and an engineering-half protocol may be submitted only as a proposal in your report, never written as an answer. If a source contradiction prevents the exact DoD, stop affected work and submit an amendment request in the form of docs/project/sprint-0/amendment-request.md under artifacts/local/tasks/HF-07b/; do not silently weaken the contract.

REPORT: Commit only permitted output files on your branch and leave the tracked worktree clean. Report candidate SHA, base, changed paths, sha256 of each output, DoD coverage item by item, commands run with exit codes, receipt paths, CLAUDE_EFFORT value, proposed question protocols if any, deviations and follow-ups, and state explicitly that you have stopped.

## Exact card

### HF-07b: Specify durable commit boundaries

**Card revision:** 1 · **Owner:** Persistence · **Size:** M · **Lane:** foundation

**Source and inputs:**

- [adr/TADR-004-persistence.md § Decision](adr/TADR-004-persistence.md#decision) (revival and interruption hold on a failed write)
- [Q-P16](#q-p16) and [Q-E09](#q-e09)
- [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) rows D26 and D27
- [BIBLE.md § Runs, regions, exits and saves](BIBLE.md#runs-regions-exits-and-saves)
- `docs/tech/sections/HF-04a-runtime-lifecycle.md` from [HF-04a](#hf-04a) (level completion seam)
- `docs/tech/sections/HF-07a-save-envelope.md` from [HF-07a](#hf-07a) (must be admitted before assignment)

**Dependencies:** [HF-04a](#hf-04a), [HF-07a](#hf-07a). **Blocking questions:** None. **Registered non-blocking questions:** [Q-E09](#q-e09), [Q-P16](#q-p16). The contract must hold under every candidate answer; the card may submit a proposed protocol for the engineering half of a question as `proposed` in TRACKING, never as an answer.

**Files touched:** `docs/tech/sections/HF-07b-commit-boundaries.md`; `artifacts/local/tasks/HF-07b/`.

**Definition of done:**

1. For each transition (level completion, reward/offer resolution, revival use, terminal settlement), a numbered stage list of stage, validate, commit and acknowledge that names the observable state before and after. Re-verify when S0-08 lands.
2. Enumerate the candidate revival/interruption policies, at minimum resume at the last completed level, resume mid-level from a checkpoint, and forfeit the level. Show the nonduplication invariants hold under each. Label the candidates pending Q-P16.
3. Keep unresolved revival/interruption product choices explicit. The Persistence half of Q-E09 (write-timing protocol) may be submitted as a proposed answer.
4. Four tabletop cases (duplicate completion, revival with an older spatial checkpoint, terminal defeat, stable offered-choice restore) appear in the output as step tables.

**Verification and evidence:**

- Review that only a validated committed generation can be acknowledged as durable.
- Check each tabletop case against the stage lists under every candidate policy.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

