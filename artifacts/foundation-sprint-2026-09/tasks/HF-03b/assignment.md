# HF-03b assignment A1

GOAL: Complete HF-03b revision 1 against the full exact card below: the dependency adjacency list over HF-03a modules with a reproducible cycle check and three interface walkthroughs.

SCOPE: /home/andrew/Projects/scrapkeep-wt-HF-03b, branch wt/HF-03b, verified base d98803c555bedcd3d68e5d82efafb1a2d0bcf31b, exclusive lease HF-03b-L1, attempt HF-03b-A1. Writer scrapkeep-writer (claude-fable-5-1 high). Permitted files: docs/tech/sections/HF-03b-dependency-graph.md; artifacts/local/tasks/HF-03b/.

CONTEXT: Full foundation authorization TRACKING EV-0078 (documentation-only, no approval pauses) applies. Read AGENTS.md, docs/project/README.md, CONTRIBUTING.md, ORCHESTRATOR.md (Handoff and review), both project task/verify skills under .agents/skills, and every exact card source below. Current source claims come from inspection. All dependency sections are the admitted bytes at this base; cite them by path and line. Already admitted S0 proofs and retained receipts are historical evidence, never new execution. Required section headings come from docs/tech/sections/README.md (Sources, Contract, Scenarios, Unresolved questions, Re-verification triggers, Procedure performed, Evidence limits). Known gotchas: HF-05 section line 8 cites TADR-004 where TADR-003:41 is correct, do not propagate it; scripts/check-docs.mjs scans only .md files and resolves relative links against the containing file.

ACCEPTANCE: Every item in the exact card below, the required section headings, exact source identities, scenario receipts and limitations. Do not merely restate the DoD; produce the complete usable contract.

VERIFY: In the worktree: npm run check:scope -- d98803c555bedcd3d68e5d82efafb1a2d0bcf31b <candidate> --no-build; npm run check:docs; npm run check:project; plus the card-specific paper checks. Save executable paper checks under artifacts/local/tasks/HF-03b/ (ignored) that accept an explicit repository root and write receipts next to themselves; never write into artifacts/foundation-sprint-2026-09/. The coordinator independently reruns and retains receipts.

TIMEBOX: Checkpoint within 15 active minutes and at handoff with actual paths, artifacts and blockers. Initial target 60 minutes for M, 30 for S; reassess from evidence; never claim elapsed time as progress.

FORBIDDEN: No edits to TRACKING.md, ORCHESTRATOR.md or BACKLOG.md unless listed in permitted files; no builds, no native or browser execution, no dependency, asset or runtime changes, no publication, no invented product answers, no push, no rebase, no touching main. If a source contradiction prevents the exact DoD, stop affected work and submit an amendment request in the form of docs/project/sprint-0/amendment-request.md under artifacts/local/tasks/HF-03b/; do not silently weaken the contract.

REPORT: Commit only permitted output files on your branch and leave the tracked worktree clean. Report candidate SHA, base, changed paths, sha256 of each output, DoD coverage item by item, commands run with exit codes, receipt paths, CLAUDE_EFFORT value, deviations and follow-ups, and state explicitly that you have stopped.

Card-specific notes: HF-03a was admitted at 3f56a82ea7b74ebd6769b5ea50653d9d2452453a; its section bytes at this base are binding (sha256 95fbd03d067fd0da2d122130ae3c54284116adc92f40c7f69c91946fd941e4cc). S0-04 is done, so the card's re-verify trigger is already fired: reconcile the edge list against docs/tech/proofs/S0-04-runtime-ownership.md and the seven scripts under native/proofs/tadr-002/ by source review only. Make the cycle check an executable script under artifacts/local/tasks/HF-03b/ that reads the adjacency list from the section file, so a reviewer reproduces it with one command. A walkthrough step that needs an unlisted edge is reported as a defect in the section, not added silently.

## Exact card

### HF-03b: Specify dependency edges and interface walkthroughs

**Card revision:** 1 · **Owner:** Runtime · **Size:** M · **Lane:** foundation

**Source and inputs:**

- [adr/TADR-002-runtime-model.md § Decision](adr/TADR-002-runtime-model.md#decision)
- [docs/adr/0003-authoritative-attack-geometry.md](docs/adr/0003-authoritative-attack-geometry.md) (attack walkthrough precedent)
- [BIBLE.md § A committed attack means what it shows](BIBLE.md#a-committed-attack-means-what-it-shows), [BIBLE.md § Inventory, equipment and transformations](BIBLE.md#inventory-equipment-and-transformations) and [BIBLE.md § Encounters, waves and enemies](BIBLE.md#encounters-waves-and-enemies)
- `docs/tech/sections/HF-03a-module-map.md` from [HF-03a](#hf-03a) (must be admitted before assignment)

**Dependencies:** [HF-03a](#hf-03a). **Blocking questions:** None.

**Files touched:** `docs/tech/sections/HF-03b-dependency-graph.md`; `artifacts/local/tasks/HF-03b/`.

**Definition of done:**

1. An adjacency list of allowed dependency edges between HF-03a modules, from which a reviewer's cycle check reproduces. Forbid hidden gameplay mutation through signals or rendering. Re-verify when S0-04 lands.
2. Three walkthroughs (an attack, an equipment change, an encounter replacement) appear in the output as step tables naming the interface used at each step.
3. Every walkthrough step uses a listed edge. A step that needs an unlisted edge is a defect to report, not an edge to add silently.

**Verification and evidence:**

- Reproduce the cycle check from the adjacency list and record the result.
- Check each walkthrough step against the edge list and the HF-03a owner table.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

