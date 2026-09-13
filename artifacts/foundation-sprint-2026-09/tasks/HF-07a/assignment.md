# HF-07a assignment A1

GOAL: Complete HF-07a revision 1 against the full exact card below: a field table for the save envelope, profile, checkpoint, lifecycle facts and the separate preferences record, each field with type, HF-03a owner and source or question ID, with stable anchors per group and a CSV copy.

SCOPE: /home/andrew/Projects/scrapkeep-wt-HF-07a, branch wt/HF-07a, verified base 5f459b0407dce4fbb060a1a8421a00fb8bb5e0c1, exclusive lease HF-07a-L1, attempt HF-07a-A1. Writer scrapkeep-writer-medium (claude-fable-5-1, effort pinned by the agent definition; report the runtime CLAUDE_EFFORT value). Permitted files: docs/tech/sections/HF-07a-save-envelope.md; docs/tech/sections/HF-07a-save-envelope.csv; artifacts/local/tasks/HF-07a/.

CONTEXT: Full foundation authorization TRACKING EV-0078 (documentation-only, no approval pauses) applies. Read AGENTS.md, docs/project/README.md, CONTRIBUTING.md, ORCHESTRATOR.md (Handoff and review), both project task/verify skills under .agents/skills, and every exact card source below. Current source claims come from inspection. All dependency sections are the admitted bytes at this base; cite them by path and line. Already admitted S0 proofs and retained receipts are historical evidence, never new execution. Required section headings come from docs/tech/sections/README.md (Sources, Contract, Scenarios, Unresolved questions, Re-verification triggers, Procedure performed, Evidence limits). Known gotchas: HF-05 section line 8 cites TADR-004 where TADR-003:41 is correct, do not propagate it; scripts/check-docs.mjs scans only .md files and resolves relative links against the containing file, so a CSV output gets no automated link or parity check and you must supply one in your paper check.

Card-specific notes. Dependency bytes at this base: HF-06b section sha256 63cb58810eac36da3c70855868873c60ffb25f1c32c0c8e1b73e7adcceefd7f2 and CSV 8ba1476b42ad206eea09bc6ea411a5f297afdcb1f4d596cdf686b4afdf8cec15 (67 rows; the 14 json-projection rows and the projection-group vocabulary at its lines 55-71 are the fields you must place in the envelope, profile, checkpoint and lifecycle groups); HF-03a section sha256 95fbd03d067fd0da2d122130ae3c54284116adc92f40c7f69c91946fd941e4cc (owning modules at lines 29-51). TADR-004 § Context is adr/TADR-004-persistence.md:7-21 and § Decision :22-34. DECISION-REGISTER rows D26 and D27 are docs/project/DECISION-REGISTER.md:49-50. Registered non-blocking questions: Q-E09 (BACKLOG.md:2726) and Q-P16 (:3006); engineering-half protocols for Q-E09 are recorded as proposed, not answered, at TRACKING EV-0144 and EV-0151, and HF-06b reserved a possibly-empty checkpoint.device-carry-over group for Q-P15 (its line 53) that you may shape or leave empty but must not fill with a product answer. The downstream consumers that will reference your field names are HF-07b, HF-08, HF-09, TH-11 (BACKLOG.md:1475) and TH-21 (:1782); give every field group a stable anchor. HF-06b rule 4 (every projected ID is a JSON string, its line 34) is an accepted input; decide and state the numeric typing of generation, schema version and transaction fields yourself under TADR-004. Cite HF-06b and HF-07b by their BACKLOG card titles. Do not copy retain_revision-at-replacement or read_initial_snapshot from HF-04b. The CSV must carry exactly the Markdown field rows with the same names, types, owners and sources; provide the md/csv parity check in your paper check because check:docs does not read CSV. S0-07 is done, so the DoD 1 re-verify trigger has already fired: reconcile by source review of docs/tech/proofs/S0-07-save-owner.md and its retained receipts without executing anything.

ACCEPTANCE: Every item in the exact card below, the required section headings, exact source identities, scenario receipts and limitations. Do not merely restate the DoD; produce the complete usable contract.

VERIFY: In the worktree: npm run check:scope -- 5f459b0407dce4fbb060a1a8421a00fb8bb5e0c1 <candidate> --no-build; npm run check:docs; npm run check:project; plus the card-specific paper checks. Save an executable paper check under artifacts/local/tasks/HF-07a/ (ignored) that accepts an explicit repository root and an --out directory for its receipts, so the coordinator can rerun it from a retained copy without rewriting retained files; never write into artifacts/foundation-sprint-2026-09/. The coordinator independently reruns and retains receipts.

TIMEBOX: Checkpoint within 15 active minutes and at handoff with actual paths, artifacts and blockers. Initial target 30 minutes for S; reassess from evidence; never claim elapsed time as progress.

FORBIDDEN: No edits to TRACKING.md, ORCHESTRATOR.md or BACKLOG.md; no builds, no native or browser execution, no dependency, asset or runtime changes, no publication, no invented product answers, no push, no rebase, no touching main. A registered non-blocking question keeps every candidate answer open: the contract must hold under each, and an engineering-half protocol may be submitted only as a proposal in your report, never written as an answer. If a source contradiction prevents the exact DoD, stop affected work and submit an amendment request in the form of docs/project/sprint-0/amendment-request.md under artifacts/local/tasks/HF-07a/; do not silently weaken the contract.

REPORT: Commit only permitted output files on your branch and leave the tracked worktree clean. Report candidate SHA, base, changed paths, sha256 of each output, DoD coverage item by item, commands run with exit codes, receipt paths, CLAUDE_EFFORT value, proposed question protocols if any, deviations and follow-ups, and state explicitly that you have stopped.

## Exact card

### HF-07a: Specify the save envelope and preferences record

**Card revision:** 1 · **Owner:** Persistence · **Size:** S · **Lane:** foundation

**Source and inputs:**

- [adr/TADR-004-persistence.md § Context](adr/TADR-004-persistence.md#context) and [§ Decision](adr/TADR-004-persistence.md#decision)
- [BIBLE.md § Runs, regions, exits and saves](BIBLE.md#runs-regions-exits-and-saves) and [BIBLE.md § HUD, dashboard and settings](BIBLE.md#hud-dashboard-and-settings) (preferences)
- [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) rows D26 and D27
- `docs/tech/sections/HF-03a-module-map.md` from [HF-03a](#hf-03a) (owning modules)
- `docs/tech/sections/HF-06b-persistence-projection.md` from [HF-06b](#hf-06b) (must be admitted before assignment)

**Dependencies:** [HF-06b](#hf-06b). **Blocking questions:** None. **Registered non-blocking questions:** [Q-E09](#q-e09), [Q-P16](#q-p16). The contract must hold under every candidate answer; the card may submit a proposed protocol for the engineering half of a question as `proposed` in TRACKING, never as an answer.

**Files touched:** `docs/tech/sections/HF-07a-save-envelope.md`; `docs/tech/sections/HF-07a-save-envelope.csv`; `artifacts/local/tasks/HF-07a/`.

**Definition of done:**

1. A field table for the envelope (schema version, content revision, generation, transaction), profile, checkpoint, lifecycle facts and the separate preferences record. Each field has a type, an owning module from HF-03a and a source or question ID. Re-verify when S0-07 lands.
2. A stable anchor per field group and a machine-readable copy. HF-07b, HF-08, HF-09, TH-11 and TH-21 reference fields by these names.
3. Fields shaped by Q-E09 or Q-P16 carry the question ID and a shape that holds under every candidate answer.

**Verification and evidence:**

- Check every field carries all three attributes.
- Check the envelope identifies generation, content and transaction without a field that only one candidate policy needs.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

