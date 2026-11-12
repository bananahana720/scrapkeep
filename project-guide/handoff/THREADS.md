# Threads and sessions (local coordinator from 10 Nov 2026; project roles checked 8 Nov)

Since 10 Nov 2026 coordination runs from one local Claude Code session on Andrew's PC (ruling cs). The first table is who does what now. The second is the claude.ai project's roles as they stood at the handoff, kept as the map of who owned what and for a session that works there again.

| Role | Where | What it does |
| --- | --- | --- |
| Coordinator and Gate | the local session on the PC | Talks to Andrew, cuts each `stage/alpha-w<N>`, opens the wave board, stacks reviewed PRs, runs the wave gate per promotion and the release gate once per sprint on the PC (ruling cy; shards as background scripts, receipts under `~/scratch/gate/` and published on `scratch/gate-receipts-*` branches), promotes, writes the register. Writes sequential and shared-file changes itself |
| Writers | project writer agents, each in its own worktree | One disjoint unit each, from a brief; a draft PR on the open stage with a focused test and the fast-lane receipt. Never review their own work |
| Reviewers | read-only agents | One independent review per finished diff, naming the head it read |
| Cloud sessions | Claude Code cloud sessions, when Andrew or the coordinator starts one | One unit or lane each, built from the open stage. A cloud session sees the repository, the pull requests and the wave board only, so it claims on the board, ends each unit as a draft pull request with a receipt, and raises a hand on the board ([COMMS.md](COMMS.md), ruling cz; [the lane brief](../coord/LANE-BRIEF.md)) |
| PC timing and renders | the same session, queued | 4080 frame rows and films on an idle card, 3060 stills and music renders. Never while gate shards run |

## Project roles at the handoff (10 Nov)

Thread ids lived in the project coordinator's memory. The 22 Oct PC-coordinator lane table is in git history.

| Role | Where | What it does |
| --- | --- | --- |
| Coordinator | project chat | Talks to Andrew, starts threads, admits and merges gate-passed PRs, promotes stages, writes the register |
| Gate | cloud thread | Cuts each `stage/alpha-w<N>`, opens the wave board, stacks green PRs, runs the wave gate per promotion and the full release gate once per sprint (ruling cy). Doesn't write fixes |
| Unit and lane threads | cloud threads | One unit or lane each; branch from the current stage, open a draft PR, post a claim and receipts on the wave board |
| Pass lanes | cloud threads | The pre-sitting improvement pass (ruling bo): design, look and feel, technicals and performance, workflows, testing. Workflows owns the runner files and the gate recipe; testing owns the tests, the bots, the end-to-end checks and the play findings list (ruling cn) |
| Domain threads | cloud threads | Systems, sight and sound (Andrew, 9 Nov): each owns its domain's direction and how its work is checked. Sound owns the sound bible and systems the level conductor; the two share one contract, `sketches/core-loop/design-v3/sound/INTEGRATION.md` |
| Bands | cloud threads | Band reads A to C per promotion, run as Gate shards |
| Deep-modules sweep | cloud thread | After each promotion: `node scripts/deep-sweep.mjs` on main, behaviour-preserving refactors on the next stage ([DEEP-SWEEP.md](DEEP-SWEEP.md)) |
| PC work | Remote Control session on Andrew's PC | 4080 frame timing, 3060 renders, music, export proofs. Only the coordinator's `message_thread` reaches it |
| Sitting prep | cloud thread | The sitting sheet (/mnt/project-files/world1/sitting-sheet.html) and the gap list |
| Nightly housekeeping | cloud thread, a routine at 2:00 America/Phoenix | Keeps the library: registers new pages and files in `/mnt/project-files/INDEX.md` and on the Library page, refreshes the shared-folder copies of repo documents, and syncs the decisions register doc with [DECISIONS.md](DECISIONS.md). Deletes nothing; candidates go in `/mnt/project-files/housekeeping/pending-deletes.md`, and its log is `housekeeping/LOG.md` beside it. At most one small docs pull request a night, never merged by the run |
| Blender | cloud thread | Props on the Blender kit; code-side and Blender-side work stay in separate threads |

**Threads are one-way for rulings.** A thread reads the board only when it pages it, so restate the head SHA in every message that carries a ruling. Threads stopped by usage limits don't resume on their own; the coordinator re-messages each with its head SHA.

**Gate shards.** A full gate runs about 13 shard threads from one project post (tests in three blocks, bots in blocks of five, bands A to C, one red team persona); the recipe is [GATE.md](GATE.md), with the shard scripts under `scripts/gate/`. Before relaunching a "missing" shard, check the thread list and the board.
