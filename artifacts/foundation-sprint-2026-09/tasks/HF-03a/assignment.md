# HF-03a assignment A1

GOAL: Complete HF-03a revision 1 against the full exact card below.

SCOPE: /home/andrew/Projects/scrapkeep-wt-HF-03a, branch wt/HF-03a, verified base 9cb8f51f901a6944428a7dcbea964ac0d4fc7634, exclusive lease HF-03a-L1, attempt HF-03a-A1. Writer foundation_hf03a, requested gpt-6-astra high (report actual model/effort). Permitted files: `docs/tech/sections/HF-03a-module-map.md`; `artifacts/local/tasks/HF-03a/`.

CONTEXT: Full foundation authorization TRACKING EV-0078 applies even if this worktree predates the assignment. Read AGENTS, project desk, CONTRIBUTING, ORCHESTRATOR, both project task/verify skills and every exact card source. Current source claims come from inspection. All dependencies must use admitted section bytes in this base. The already admitted S0 proofs are historical source evidence, never new execution. Reconcile each named trigger now; separate proof-covered rules from unqualified broader claims.

Coordinator resolved official Godot4.7 autoload and GDScript class_name/preload references on 2026-09-06: https://docs.godotengine.org/en/4.7/tutorials/scripting/singletons_autoload.html and https://docs.godotengine.org/en/4.7/tutorials/scripting/gdscript/gdscript_basics.html . Autoload provides persistent nodes but does not enforce unique authority; use TADR-002 ownership. S0-01 and tadr-002 proof source must be reconciled without rerunning them.

ACCEPTANCE: Every item in the exact card below, required section headings from docs/tech/sections/README.md, exact source identities, scenario receipts and limitations. Do not merely restate the DoD; produce the complete usable contract.

VERIFY: npm run check:scope -- 9cb8f51f901a6944428a7dcbea964ac0d4fc7634 <candidate> --no-build; npm run check:docs; npm run check:project; exact card-specific source/scenario checks. Save executable paper checks when useful under artifacts/local/tasks/HF-03a/ and record invocation; keep receipt references portable to their retained directory. Coordinator will independently execute and retain receipts.

TIMEBOX: Checkpoint within15 active minutes and at handoff, with actual paths/artifacts and blockers. Initial target60minutes for M or30 for S, reassess from evidence, never claim elapsed time as progress.

FORBIDDEN: No shared-record/index edits, no builds, no native/browser execution, no dependencies/assets/runtime changes, no publication, no invented product answers. Read-only reviewers do not edit the candidate. If a source contradiction prevents the exact DoD, stop affected work and submit a factual amendment request; do not silently weaken it.

REPORT: Commit only permitted output files, leave tracked worktree clean, report candidate SHA, base, changed paths, output hashes, DoD coverage, actual checks and failures, receipt paths, model/effort and explicitly stopped writer. Leave ignored receipts accessible for coordinator retention; do not edit the board or canonical retained evidence directory.

## Exact card

### HF-03a: Specify module ownership and owned records

**Card revision:** 1 · **Owner:** Runtime · **Size:** M · **Lane:** foundation

**Source and inputs:**

- [adr/TADR-002-runtime-model.md § Decision](adr/TADR-002-runtime-model.md#decision)
- [adr/TADR-003-content-pipeline.md § Decision](adr/TADR-003-content-pipeline.md#decision) (content-admission owner)
- [adr/TADR-004-persistence.md § Decision](adr/TADR-004-persistence.md#decision) (persistence owner)
- [BIBLE.md § Architecture and implementation handoff](BIBLE.md#architecture-and-implementation-handoff)
- `docs/tech/sections/HF-01-production-conventions.md` from [HF-01](#hf-01) (must be admitted before assignment)
- Godot 4.7 documentation for autoload, `class_name` and `preload`, resolved by the coordinator and supplied in the packet.

**Dependencies:** [HF-01](#hf-01). **Blocking questions:** None.

**Files touched:** `docs/tech/sections/HF-03a-module-map.md`; `artifacts/local/tasks/HF-03a/`.

**Definition of done:**

1. One module table with the columns module, owned mutable records, allowed imports, exposed commands and published results, under one session authority. Re-verify when S0-01 lands, because allowed imports drift from observed autoload, `class_name` and `preload` behavior.
2. Assign collision queries, encounter timing, run/profile mutation, persistence, content admission and presentation to explicit owners. Each owner row cites its TADR line.
3. Name every record that exactly one module may mutate. A record with two owners is a defect in the output, not a note.

**Verification and evidence:**

- Inspect the table for a module with no owned record and for a record with two owners.
- Check each owner assignment against the cited TADR lines.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.
