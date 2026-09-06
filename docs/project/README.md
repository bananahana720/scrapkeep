# Project desk

Updated 5 September 2026. **Increment 01, the lightning caster playtest, is implemented and ready for Andrew's next playtest.** Andrew's first orchard playtest requested automatic mouse look, accurate spell previews, jumping and rebounds, dense waves, and a readable interface. The [approved increment](INCREMENT-01-lightning-playtest.md) owns scope, lane boundaries and the current integration contract. The original yard remains a separate playable baseline. The [verification record](../LIGHTNING-VERIFICATION.md) records passed checks and the remaining physical capture and human playtest limits.

Andrew's 6 September tooling priority is [T13, agent playtesting engineering](AGENT-PLAYTEST-ENGINEERING.md). Independent Linux controls and the [maintained native player](../../tools/agent-player/README.md) are operational. [Target continuity and bounded recovery](../../artifacts/agent-recovery-2026-09-06/README.md) passed three consecutive terminal trials: two wins and one defeat, with pause/resume and no stall timeout. The [carry-forward map and resume steps](AGENT-PLAYTEST-ENGINEERING.md#carry-forward-map) identify the preserved tools, source snapshot and reusable patterns. Measured profiles and regression comparisons remain next. This supports P10 and does not replace Andrew's play feedback or authorize another gameplay increment.

## Start the next session

Run the [planning protocol](PLANNING.md). In Claude Code the `plan-session` project skill invokes it. Its phases are:

1. Preflight alone: clean `git status`, green `npm run verify`, read this desk and the [backlog](BACKLOG.md), load the [decision register](DECISION-REGISTER.md).
2. Decide with Andrew: the register's Tier A entries, one at a time, recommendation first, "park it" always allowed. Each ruling becomes a `decisions.tsv` row.
3. Scope one bounded increment with observable acceptance criteria as `INCREMENT-<nn>-<slug>.md`, then ask for go/no-go.
4. Only after a recorded go, hand lanes to isolated writers, admit serially behind the gate, and review independently.
5. Close out: requirements/ADR, backlog, decision trail, this status line, one next action.

The immediate product question is whether the new caster controls, double jump, denser waves and readable HUD satisfy Andrew's playtest feedback. The earlier 37-second scripted clear remains historical first-proof evidence.

## Sources of truth

| Concern | Owner |
| --- | --- |
| Setup, code conventions and local checks | [CONTRIBUTING](../../CONTRIBUTING.md) |
| Current scope and requirement status | [Requirements](REQUIREMENTS.md) |
| Ordered open work and closure criteria | [Backlog](BACKLOG.md) |
| Open decisions awaiting Andrew, tiered and ordered | [Decision register](DECISION-REGISTER.md) |
| How a planning session runs, from decisions to swarm | [Planning protocol](PLANNING.md) |
| Accepted publisher preferences and unresolved choices | [Discovery](../DISCOVERY.md) |
| Current module, geometry and input contract | [Lightning increment](INCREMENT-01-lightning-playtest.md) |
| Current controls and executed evidence | [Play guide](../LIGHTNING-PLAYGUIDE.md), [verification](../LIGHTNING-VERIFICATION.md) |
| Historical first-proof module and geometry contract | [Build contract](../FIRST-BUILD-CONTRACT.md) |
| Durable implementation decisions | [ADRs](../adr/README.md) |
| Executed first-build evidence and limits | [Verification](../FIRST-BUILD-VERIFICATION.md) |
| Art, competition and enemy-family research navigation | [Design desk](../DESIGN-INDEX.md) |
| Original yard controls and behavior | [Baseline guide](../BASELINE-GUIDE.md) |
| Asset provenance and output retention | [Assets](ASSETS.md), [artifacts](../../artifacts/README.md) |
| The closeout housekeeping result | [Closeout](HOUSEKEEPING.md) |
| The planning-prep swarm and ground-truth check | [Team record](../PLANNING-PREP-SWARM.md) |

The coordinator owns integration and technical records. Andrew owns publisher preference and next-scope decisions. Agent assignments in historical swarm notes are completed task records, not a permanent staffed team or a promise of background work.

No active session goal or next sprint is created by this page. No deadlines are assigned.
