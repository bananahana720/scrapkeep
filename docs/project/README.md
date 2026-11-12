# Project desk

**Current state.** The game is a Godot sketch at `sketches/core-loop`: three worlds of two stages each, with world 1 (the Spillway) first. The claude.ai project "Scrapkeep" coordinates the alpha, one thread per unit; [START-HERE.md](../../project-guide/handoff/START-HERE.md) says who owns what. The live board is the current wave's GitHub issue, named in [STATE.md](../../project-guide/handoff/STATE.md); the order of what is left is in [ROADMAP.md](../../project-guide/handoff/ROADMAP.md) and the rulings are in [DECISIONS.md](../../project-guide/handoff/DECISIONS.md). Alpha work stacks on `stage/alpha-w<N>`; Andrew plays a world 1 sitting, then one full-alpha sitting. Claude project agents under `.claude/agents` are the only workers; see [the AI workflow guide](AI-WORKFLOW.md).

**Start at the [Bible contents](../../BIBLE.md#contents) and read the section your task names before any game work.** The Bible is the approved product reference; a card cites the exact sections it needs. The [accepted engineering ADRs](../../adr/README.md) settle the production direction. [BACKLOG.md](../../BACKLOG.md) holds atomic task definitions, [SOURCE-DISPOSITIONS.md](SOURCE-DISPOSITIONS.md) holds the historical source dispositions, [ORCHESTRATOR.md](../../ORCHESTRATOR.md) governs the swarm, and [TRACKING.md](../../TRACKING.md) is the board for heavy-lane work. Explicitly missing product details remain questions; do not reopen settled choices.

**History.** The foundation and handoff sprints (September 2026), the Operational Sprint 0 and the prepare stage are closed. Their receipts are in `docs/project/*/closure.json`, the events are in [the event archives](tracking/EVENTS-0001-0057.md), and [TRACKING.md](../../TRACKING.md) points to the rest. The long sprint narrative that lived on this page is in the repository history.

**Preserved proofs.** The Iron Orchard (`/orchard.html`) and the original yard (`/`) are preserved browser proofs, not the current direction. The [approved increment](INCREMENT-01-lightning-playtest.md) owns the orchard's scope and integration contract, and the [verification record](../LIGHTNING-VERIFICATION.md) retains its checks and limits. The [T13 playtesting record](AGENT-PLAYTEST-ENGINEERING.md) preserves operational Linux controls and the [maintained native player](../../tools/agent-player/README.md); its [carry-forward map](AGENT-PLAYTEST-ENGINEERING.md#carry-forward-map) identifies tools and evidence. None of this replaces Andrew's play feedback.

## Start the next session

Read [AGENTS.md](../../AGENTS.md), then [START-HERE.md](../../project-guide/handoff/START-HERE.md), the wave board and your brief, and the DECISIONS rows it cites. For heavy-lane cards, read the board's authorization and checkpoint, then follow ORCHESTRATOR. Inspect actual workspace changes and preserve owner work. Dispatch only a complete, input-ready card inside an approved scope. Do not run a build preflight for a documentation-only task. The [earlier planning protocol](PLANNING.md) remains historical evidence, not a second dispatch system.

## Sources of truth

| Concern                                                                | Owner                                                                                 |
| ---------------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| Approved product reference (game, world, art, audio)                   | [Art & Game Bible](../../BIBLE.md)                                                    |
| Setup, code conventions and local checks                               | [CONTRIBUTING](../../CONTRIBUTING.md)                                                 |
| Scope and requirement status                                           | [Requirements](REQUIREMENTS.md)                                                       |
| Atomic work definitions and open questions                             | [Root backlog](../../BACKLOG.md)                                                      |
| Historical identifier dispositions and source inventory                | [Source dispositions](SOURCE-DISPOSITIONS.md)                                         |
| Alpha roadmap, wave state and rulings                                  | [ROADMAP.md](../../project-guide/handoff/ROADMAP.md), [STATE.md](../../project-guide/handoff/STATE.md), [DECISIONS.md](../../project-guide/handoff/DECISIONS.md) |
| Heavy-lane execution and question states                              | [Tracking board](../../TRACKING.md)                                                   |
| Assignment, isolation, review and checkpoint rules                     | [Orchestrator](../../ORCHESTRATOR.md)                                                 |
| Accepted publisher preferences and unresolved choices                  | [Discovery](../DISCOVERY.md)                                                          |
| Accepted production architecture and earlier boundary sketch           | [Production TADRs](../../adr/README.md), [runtime blueprint](../RUNTIME-BLUEPRINT.md)    |
| Orchard module, geometry and input contract (preserved proof)          | [Lightning increment](INCREMENT-01-lightning-playtest.md)                             |
| Orchard controls and executed lightning evidence (preserved proof)     | [Play guide](../LIGHTNING-PLAYGUIDE.md), [lightning verification](../LIGHTNING-VERIFICATION.md) |
| Historical first-proof module and geometry contract                    | [Build contract](../FIRST-BUILD-CONTRACT.md)                                          |
| Durable browser-proof implementation decisions                         | [Browser-proof ADRs](../adr/README.md)                                                |
| Executed first-build evidence and limits                               | [First-build verification](../FIRST-BUILD-VERIFICATION.md)                            |
| Art, competition and enemy-family research navigation                  | [Design desk](../DESIGN-INDEX.md)                                                     |
| Original yard controls and behavior (preserved baseline)               | [Baseline guide](../BASELINE-GUIDE.md)                                                |
| Asset provenance and output retention                                  | [Assets](ASSETS.md), [artifacts](../../artifacts/README.md)                           |
| The closeout housekeeping result                                       | [Closeout](HOUSEKEEPING.md)                                                           |
| The planning-prep swarm and ground-truth check                         | [Team record](../PLANNING-PREP-SWARM.md)                                              |

The coordinator owns integration and technical records. Andrew owns publisher preference and next-scope decisions. Agent assignments in historical swarm notes are completed task records, not a permanent staffed team or a promise of background work.

This page creates no session goal, sprint or deadline.
