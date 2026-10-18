# Live threads at the move (18 Oct 2026, 05:15Z)

Threads and their sessions stay in the old project and don't move. In the new project, restart only the roles you still need. Each row says what the thread owns and what it is waiting on. Its PR, branch and files are what a new thread picks up.

## Standing roles (restart these first)

| Role (old thread title) | Owns | Waiting on |
| --- | --- | --- |
| Coordinator (project chat) | Triage, cards, standing merge authority, Design hub tab, memory | - |
| Project library and lessons learned | Decisions register and lessons (both copies), Library page, sitting watch list. Verifies every tap in the timeline before recording | Nothing. The register is current to 04:42Z |
| Cloud gate for draft PRs | Gate of record except GPU. Receipts on each PR; shards bot tiers to the bot shard threads | Its wave 17 queue (STATE.md) |
| Cloud staging candidate | `stage/alpha-w<N>`: stacks gate passes, merges the stage to main on GitHub, cuts the next stage branch, row-pin re-records | Wave 17 gate results |
| Faster test and red team loops | The tiered gate (#106), flaky tests made deterministic, never skipped | Review of #106 |
| Set up the per-wave red team | Red team per stage head (one persona) and the five-persona close sweep; crash harvest; intent-check scorecard re-run | The next stage head |
| Bot shard 6, Bot shard 7 | Bot-tier test shards for the gate (the brief is in `gate/BOT-SHARDS.md` in the shared folder) | Gate jobs |
| PC machine session (Remote Control) | GPU checks, admissions, the 4080 benches | #129 rerun, the #73 slope bench |
| PC music session (Remote Control) | ACE-Step renders, radio takes, camp music | The last 9 radio takes, the camp split |

## Work threads still open

| Thread | Work | State |
| --- | --- | --- |
| Smoother, more detailed models | Polish toolkit #107 (frozen), pilots #115/#122/#133, the Mind #120 | In gate as one set |
| Polish world 1 enemies | #121 | Review-ready |
| Polish world 2 and 3 enemies | #119 | Done, in gate |
| Polish bosses and Wardens | #128 | Done, in gate |
| Polish props and landmarks | #124 | Review-ready |
| Smoother animation blends | #109, #117, #123, #130, #131 | Working |
| Effects and shader polish | #108 (also owns baked shading lost where enemy scripts swap materials) | Done, in gate |
| Stage entry freeze | #129: in-stage freezes and the 12 s menu-ready | Awaiting the 4080 rerun |
| Runner Gunner ultimate freeze (Rivet) | #73: Spread every Breach, Smooth 0.11 s on slopes | Building the slope timing |
| Swarm hive stall on main | Base red: runner_gunner never latches the hive | Review-ready |
| Reward overpowered builds | #104: Lift the ceiling, Per Warden, overkill pays | In gate |
| Wall grip and carving | #61 Speed holds | In gate |
| World 2 and 3 enemy identity | #69; owns the attack id registry `alpha-status/attack-ids.md` (new claims E34+) | Review-ready |
| Crown park authored pass | #78 | Working |
| Flume park authored pass | #126, Keep the carry | Working |
| First-win secrets | #127 | Review-ready |
| Meteor Crater ending | #125 | Review-ready |
| Build the camp hub model | #111 walkable camp | Review-ready |
| Silo Battery, Quake Knock, Glass Lance actives; Active offers | #84-#91 | Working |
| Lift Pulse active; Maker set bonuses | #89, #99 | Review-ready |
| Measure how mighty a grown pilot feels | Power read tool | Review-ready |
| Stage 6 exit gate stall | Bot stall at the stage 6 exit | Working |
| Wire picked themes into stages | #105 | Done, in gate |
| Every-park intentionality check | Owns `alpha-status/intent-check/METHOD.md` | Weighing the flume's route-membership weighting |

The PR heads are in STATE.md. Everything else was resolved before the move.
