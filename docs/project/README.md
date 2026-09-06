# Project desk

Updated 5 September 2026. **The Iron Orchard first proof is complete and ready for Andrew's playtest.** The next build has not been scoped. The repository is a real Git checkout on `main`; the design audit and deep-research pass are indexed, and their open decisions sit in one register. The original yard remains a separate playable baseline.

## Start the next session

Run the [planning protocol](PLANNING.md). In Claude Code the `plan-session` project skill invokes it. Its phases are:

1. Preflight alone: clean `git status`, green `npm run verify`, read this desk and the [backlog](BACKLOG.md), load the [decision register](DECISION-REGISTER.md).
2. Decide with Andrew: the register's Tier A entries, one at a time, recommendation first, "park it" always allowed. Each ruling becomes a `decisions.tsv` row.
3. Scope one bounded increment with observable acceptance criteria as `INCREMENT-<nn>-<slug>.md`, then ask for go/no-go.
4. Only after a recorded go, hand lanes to isolated writers, admit serially behind the gate, and review independently.
5. Close out: requirements/ADR, backlog, decision trail, this status line, one next action.

The immediate product question is whether rolling out of a committed attack and returning for a strong hit is satisfying. The precise script's damage-free 37-second clear also makes ranged pressure a concrete tuning question. Neither result calls for a full class-system implementation before feedback.

## Sources of truth

| Concern | Owner |
| --- | --- |
| Setup, code conventions and local checks | [CONTRIBUTING](../../CONTRIBUTING.md) |
| Current scope and requirement status | [Requirements](REQUIREMENTS.md) |
| Ordered open work and closure criteria | [Backlog](BACKLOG.md) |
| Open decisions awaiting Andrew, tiered and ordered | [Decision register](DECISION-REGISTER.md) |
| How a planning session runs, from decisions to swarm | [Planning protocol](PLANNING.md) |
| Accepted publisher preferences and unresolved choices | [Discovery](../DISCOVERY.md) |
| Detailed first-proof module and geometry contract | [Build contract](../FIRST-BUILD-CONTRACT.md) |
| Durable implementation decisions | [ADRs](../adr/README.md) |
| Executed first-build evidence and limits | [Verification](../FIRST-BUILD-VERIFICATION.md) |
| Art, competition and enemy-family research navigation | [Design desk](../DESIGN-INDEX.md) |
| Original yard controls and behavior | [Baseline guide](../BASELINE-GUIDE.md) |
| Asset provenance and output retention | [Assets](ASSETS.md), [artifacts](../../artifacts/README.md) |
| The closeout housekeeping result | [Closeout](HOUSEKEEPING.md) |
| The planning-prep swarm and ground-truth check | [Team record](../PLANNING-PREP-SWARM.md) |

The coordinator owns integration and technical records. Andrew owns publisher preference and next-scope decisions. Agent assignments in historical swarm notes are completed task records, not a permanent staffed team or a promise of background work.

No active session goal or next sprint is created by this page. No deadlines are assigned.
