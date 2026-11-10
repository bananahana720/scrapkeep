# Threads and sessions (checked 8 Nov 2026, project coordinator; three roles added 10 Nov)

Coordination runs from the claude.ai project "Scrapkeep". The coordinator talks to Andrew in the project chat and starts one thread per lane or unit; Remote Control sessions on his PC run GPU work. Thread ids change as lanes open and close, so the coordinator's project memory holds the current ids; this file names the standing roles. The 22 Oct PC-coordinator lane table is in git history.

| Role | Where | What it does |
| --- | --- | --- |
| Coordinator | project chat | Talks to Andrew, starts threads, admits and merges gate-passed PRs, promotes stages, writes the register |
| Gate | cloud thread | Cuts each `stage/alpha-w<N>`, opens the wave board, stacks green PRs, runs the full gate once per promotion. Doesn't write fixes |
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
