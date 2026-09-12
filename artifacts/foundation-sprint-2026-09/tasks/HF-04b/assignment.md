# HF-04b assignment A1

GOAL: Complete HF-04b revision 2 against the full exact card below: runtime patterns with linked admitted S0-04 sources, owners per HF-03a, and one unparsed typed scene-lifecycle sketch.

SCOPE: /home/andrew/Projects/scrapkeep-wt-HF-04b, branch wt/HF-04b, verified base d98803c555bedcd3d68e5d82efafb1a2d0bcf31b, exclusive lease HF-04b-L1, attempt HF-04b-A1. Writer scrapkeep-writer (claude-fable-5-1 high). Permitted files: docs/tech/sections/HF-04b-runtime-patterns.md; artifacts/local/tasks/HF-04b/.

CONTEXT: Full foundation authorization TRACKING EV-0078 (documentation-only, no approval pauses) applies. Read AGENTS.md, docs/project/README.md, CONTRIBUTING.md, ORCHESTRATOR.md (Handoff and review), both project task/verify skills under .agents/skills, and every exact card source below. Current source claims come from inspection. All dependency sections are the admitted bytes at this base; cite them by path and line. Already admitted S0 proofs and retained receipts are historical evidence, never new execution. Required section headings come from docs/tech/sections/README.md (Sources, Contract, Scenarios, Unresolved questions, Re-verification triggers, Procedure performed, Evidence limits). Known gotchas: HF-05 section line 8 cites TADR-004 where TADR-003:41 is correct, do not propagate it; scripts/check-docs.mjs scans only .md files and resolves relative links against the containing file.

ACCEPTANCE: Every item in the exact card below, the required section headings, exact source identities, scenario receipts and limitations. Do not merely restate the DoD; produce the complete usable contract.

VERIFY: In the worktree: npm run check:scope -- d98803c555bedcd3d68e5d82efafb1a2d0bcf31b <candidate> --no-build; npm run check:docs; npm run check:project; plus the card-specific paper checks. Save executable paper checks under artifacts/local/tasks/HF-04b/ (ignored) that accept an explicit repository root and write receipts next to themselves; never write into artifacts/foundation-sprint-2026-09/. The coordinator independently reruns and retains receipts.

TIMEBOX: Checkpoint within 15 active minutes and at handoff with actual paths, artifacts and blockers. Initial target 60 minutes for M, 30 for S; reassess from evidence; never claim elapsed time as progress.

FORBIDDEN: No edits to TRACKING.md, ORCHESTRATOR.md or BACKLOG.md unless listed in permitted files; no builds, no native or browser execution, no dependency, asset or runtime changes, no publication, no invented product answers, no push, no rebase, no touching main. If a source contradiction prevents the exact DoD, stop affected work and submit an amendment request in the form of docs/project/sprint-0/amendment-request.md under artifacts/local/tasks/HF-04b/; do not silently weaken the contract.

REPORT: Commit only permitted output files on your branch and leave the tracked worktree clean. Report candidate SHA, base, changed paths, sha256 of each output, DoD coverage item by item, commands run with exit codes, receipt paths, CLAUDE_EFFORT value, deviations and follow-ups, and state explicitly that you have stopped.

Card-specific notes: HF-04a section bytes at this base are binding (sha256 7eb7ad2c909b715e62051d2d73e353f445b96270f3140b38c1c38c4c3fc171fb); HF-03a likewise (95fbd03d067fd0da2d122130ae3c54284116adc92f40c7f69c91946fd941e4cc). Coordinator-resolved Godot 4.7 static typing documentation, fetched 2026-09-12 via Context7 library /websites/godotengine_en_4_7: https://docs.godotengine.org/en/4.7/tutorials/scripting/gdscript/static_typing.html , https://docs.godotengine.org/en/4.7/tutorials/scripting/gdscript/gdscript_basics.html , https://docs.godotengine.org/en/4.7/tutorials/scripting/gdscript/gdscript_styleguide.html ; the receipt is at artifacts/local/tasks/HF-04b/ctx7-godot-static-typing.txt in the main checkout (read-only for you; copy it if you cite it). Pin each linked native/proofs/tadr-002/ script to its admitted source commit with git log; the S0-04 evidence files are artifacts/prepare-stage-2026-09-06/tasks/S0-04/S0-04-int-proof-run.txt and S0-04-int-proof-fault.txt. Do not execute any proof or open an editor; presence and typed form only.

## Exact card

### HF-04b: Specify runtime patterns and typed sketches

**Card revision:** 2 · **Owner:** Runtime · **Size:** M · **Lane:** foundation

**Source and inputs:**

- [adr/TADR-002-runtime-model.md § Decision](adr/TADR-002-runtime-model.md#decision)
- [adr/TADR-001-engine-language-platforms.md § Decision](adr/TADR-001-engine-language-platforms.md#decision) (typed GDScript)
- Godot 4.7 static-typing documentation, resolved by the coordinator and supplied in the packet.
- `docs/tech/sections/HF-04a-runtime-lifecycle.md` from [HF-04a](#hf-04a) (must be admitted before assignment)
- `docs/tech/sections/HF-03a-module-map.md` from [HF-03a](#hf-03a) (owner map, admitted before assignment)
- [docs/tech/proofs/S0-04-runtime-ownership.md](docs/tech/proofs/S0-04-runtime-ownership.md), particularly Contract, Scenarios, Unresolved questions and Evidence limits
- The seven source scripts under `native/proofs/tadr-002/`, pinned to their admitted source identity
- `artifacts/prepare-stage-2026-09-06/tasks/S0-04/S0-04-int-proof-run.txt` and `S0-04-int-proof-fault.txt`

**Dependencies:** [HF-04a](#hf-04a). **Blocking questions:** None.

**Files touched:** `docs/tech/sections/HF-04b-runtime-patterns.md`; `artifacts/local/tasks/HF-04b/`.

**Definition of done:**

1. Name the game-loop, state-machine, scoped signal/message and scene-lifecycle patterns and when not to use each. Document time/tick ownership and event ordering under HF-04a.
2. For the game-loop, state-machine and scoped signal/message patterns, replace inline sketches with links to the applicable admitted S0-04 source. Link `native/proofs/tadr-002/encounter_coordinator.gd` for the single physics-callback owner, queued command admission and minimal prepared/cast transitions; `session_owner.gd`, `input_adapter.gd` and `menu_probe.gd` for input release, prepared-action cancellation, pause and resume; and `intruder.gd` with `proof_runner.gd` phase B for rejection of a second mutation source. Each example identifies its source commit, the assertion or phase that exercised it, the retained normal and fault-run evidence, and the behavior those assertions establish. State explicitly that these examples do not prove a complete production state machine, positive committed-result signal delivery or scoped connection teardown. Retain a minimal typed scene-lifecycle sketch marked "unparsed: no editor run in this card; scene replacement and scoped teardown await a later authorized proof". Reconcile every example and remaining paper contract against the admitted HF-04a lifecycle contract. Record the S0-04 trigger as satisfied by source and retained-evidence review; no native execution occurs in this card.
3. State for each pattern which HF-03a module may own it.

**Verification and evidence:**

- Confirm each linked source file and retained receipt exists; identify the exact assertion supporting each claimed behavior; inspect proof discovery and the pinned typing configuration without executing them. Check that every remaining inline sketch carries the unparsed marker, every pattern names its HF-03a owner, and no example substitutes a proof default or untested behavior for the admitted HF-04a contract.
- The reviewer confirms presence and typed form only; no sketch is executed under this card.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

