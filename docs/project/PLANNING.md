# Planning mode

> **Historical single-increment protocol.** [ORCHESTRATOR.md](../../ORCHESTRATOR.md) now owns worker assignment, tracking, review and checkpoint rules. Read the root [backlog](../../BACKLOG.md) and [board](../../TRACKING.md) for current scope. The old P10 priority, clean-checkout stop and automatic build preflight below do not override the current documentation-only authorization. Retain this file as the source for previous increments.

Updated 22 October 2026. This protocol runs one planning session for Scrapkeep. It settles Andrew's key decisions in conversation, scopes one bounded increment, and only then hands implementation to an agent swarm with verification gates. Claude Code invokes it through the `plan-session` project skill.

**The one rule.** No implementation starts until Phase 2 has recorded a scoped increment document and Andrew has said go. A proposal, an audit, a research desk, or a backlog row is not approval to build.

The notebook interview has already settled the direction recorded in D07/D24 and D49–D57. Apply those rulings without re-interviewing Andrew. P10 remains the current product task; P11–P14 hold future design. The mass/deflect-first agenda and the audit's fixed increment sequence are superseded. An explicitly requested documentation synchronization records existing direction and does not authorize dependent gameplay scope.

## Roles

| Who                                           | Decides                                                                   |
| --------------------------------------------- | ------------------------------------------------------------------------- |
| Andrew                                        | Publisher preference, scope, priority, and the go/no-go on each increment |
| Coordinator (the agent running this protocol) | Integration, technical records, lane partition, admission, and closeout   |
| Writers                                       | Only the files their lane owns, inside their own worktree                 |
| Reviewer                                      | Nothing. It reports observations. The coordinator applies changes         |

## Phases at a glance

| Phase       | Entry condition                        | Exit artifact                                                  | Who decides exit             |
| ----------- | -------------------------------------- | -------------------------------------------------------------- | ---------------------------- |
| 0 Preflight | Session starts                         | Situation brief in chat                                        | Coordinator                  |
| 1 Decide    | Brief delivered                        | New rows in `docs/decisions.tsv` and updated register statuses | Andrew, one ruling at a time |
| 2 Scope     | Tier A blockers ruled or parked        | `docs/project/INCREMENT-<nn>-<slug>.md` plus a go row          | Andrew                       |
| 3 Swarm     | Go row recorded                        | Admitted changes on `main`, gate green, reviewer verdict       | Coordinator                  |
| 4 Closeout  | Reviewer verdict is PASS or PASS+NOTES | Updated canonical docs and one next action                     | Coordinator                  |

## Phase 0. Preflight

The agent runs this alone and asks no questions.

1. `git status --short` is clean. If not, stop and report the dirty paths.
2. `npm run verify` is green. If not, the session's first candidate increment is the fix.
3. Read the [project desk](README.md), the [backlog](BACKLOG.md), and the [requirements](REQUIREMENTS.md).
4. Load the [decision register](DECISION-REGISTER.md). List unresolved decisions that the candidate work actually depends on; skip ruled and superseded entries.
5. Write a one-paragraph situation brief. Name the current increment, gate result, relevant open dependencies and top backlog item.

Exit. The brief is in chat. Andrew has not been asked anything yet.

## Phase 1. Decide with Andrew

Present only unresolved decisions relevant to the candidate work, one at a time. At most seven per session. Order by backlog dependency; historic tier labels do not override current rulings.

Each decision uses the AskUserQuestion tool. Each question carries these parts.

- The recommendation first, with its evidence type. Fixture, paper, or playtest.
- Two to four options.
- "Park it" as an option every time. Parked is a valid ruling.

After each ruling the coordinator does three things before asking the next question.

1. Append one row to the [decision trail](../decisions.tsv). The columns are `ts`, `phase`, `decision`, `why`, `evidence`, `result`. Phase is `planning`. Result holds the ruling, including "parked" or "blocked on evidence".
2. Set the register row's Status.
3. Name which owning document must propagate the ruled name or number. Put that propagation in the increment's closeout list or in the backlog.

Stop rules.

- Andrew revisits a settled decision with no new information. Say so, restate the recorded ruling with its decisions.tsv timestamp, and move on.
- A decision needs evidence that does not exist yet, for example P01 playtest feedback. Record "blocked on evidence" and move on. Do not invent the evidence and do not ask Andrew to guess.
- Seven rulings reached, or Andrew says stop. Move to Phase 2 with what is settled.

Exit. Every presented decision has a decisions.tsv row and a register Status. Andrew decided each one.

## Phase 2. Scope one increment

Entry. Every Tier A decision the candidate increment depends on is ruled or parked. A parked blocker means that increment is not a candidate this session.

Write `docs/project/INCREMENT-<nn>-<slug>.md`, modeled on the [first-build contract](../FIRST-BUILD-CONTRACT.md). `<nn>` is two digits, starting at 01. The document has these sections in this order.

| Section      | Content                                                                                                            |
| ------------ | ------------------------------------------------------------------------------------------------------------------ |
| Goal         | One sentence. What a player or contributor can observe when it lands                                               |
| Requirements | Requirement IDs touched, per [REQUIREMENTS.md](REQUIREMENTS.md)                                                    |
| Exclusions   | What this increment explicitly does not do, named item by item                                                     |
| Ownership    | One row per lane. The files each lane may write. Files outside the table belong to the coordinator                 |
| Acceptance   | Numbered criteria. Each names its evidence type. Fixture, Node test, browser check, or playtest                    |
| Gate         | `npm run verify` plus the named browser checks from [CONTRIBUTING](../../CONTRIBUTING.md) that the changes require |
| Closeout     | ADR to add or amend, backlog rows to close or add, decisions.tsv rows, README status line                          |

Use the current backlog and accepted requirements to choose the candidate. The [design audit](../DESIGN-AUDIT.md) is historical research, not an approved implementation sequence.

Ask Andrew one go/no-go question with the document written. The options are go, revise, or park. Record a go as a decisions.tsv row with the increment path in `evidence`.

Exit. The increment document exists and the go row is appended. Without a go, the session ends here with the document parked. That is a complete session.

## Phase 3. Swarm implementation

Entry. The go row exists. Models come from the host's pstack model file, not from this document.

1. Partition lanes from the increment's ownership table. One writer per lane. Two lanes never share a file.
2. Give each writer its own worktree. Use the host's isolation parameter when it exists. Otherwise create it with `git worktree add -b <branch> <path> main`. A separate agent name is not isolation.
3. Write each brief with the poteto template verbatim. GOAL, SCOPE, CONTEXT, ACCEPTANCE, VERIFY, TIMEBOX, FORBIDDEN, REPORT. SCOPE lists the lane's files from the ownership table. CONTEXT names the increment document path and the decisions.tsv rows the lane depends on.
4. Writers report on the shared verdict scale. PASS, PASS+NOTES, FAIL, BLOCKED, INCONCLUSIVE, each with its evidence level.
5. The coordinator admits changes serially. One lane's branch merges, then `npm run verify` runs, then the next lane. A red gate stops admission until the failure is fixed or the lane is reverted.
6. Before closeout, spawn one fresh read-only reviewer against the admitted result. Its prompt carries the poteto panel paragraph verbatim plus the read-only line. One reviewer is one opinion. The coordinator reads the diff and writes its own summary. A FAIL sends each named finding back to the owning lane, or to the coordinator for files outside every lane, and the gate and a fresh reviewer run again before closeout.
7. Failure policy follows poteto. A dropout means proceed with N-1 and record it. BLOCKED gets a respawn after the environment heals. Garbage output gets a fresh respawn with consolidated scope, two retries, then the lane is abandoned and recorded.

Exit. Every lane is admitted or recorded as abandoned. The gate is green on the integrated result. The reviewer verdict is PASS or PASS+NOTES.

## Phase 4. Closeout

1. Update the canonical documents named in the increment's closeout list. Add or amend the [ADR](../adr/README.md). Keep one record per concern.
2. Append decisions.tsv rows for the integration choices and the review outcome.
3. Update the [backlog](BACKLOG.md). Close items with their closure evidence. Add new items only with a checkable closure condition.
4. Record the actual commit SHA of the admitted result in the increment document.
5. Leave one concrete next action in the [project desk](README.md).
6. No push, release, or remote publication without Andrew's explicit authorization in chat.

Exit. The project desk names the next action. The decision register and backlog agree with the increment document.

## What this protocol does not do

- It does not accept new scope from a swarm. A writer that finds adjacent work reports it. The coordinator adds a backlog row.
- It does not migrate the engine or upgrade a dependency.
- It does not deploy or publish.
- It does not create persistent memory, a task, or a reminder. A note in this repository is a record, not a schedule.
- It does not run more than one increment at a time.
