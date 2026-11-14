# Threads and who owns what (14 Nov 2026)

The claude.ai project "Scrapkeep" coordinates the alpha. Each role below is a thread in that project unless it says otherwise. Earlier set-ups (the PC-coordinator lanes of 22 Oct, the project roles at the 10 Nov hand-off, the local PC coordinator of 10 to 11 Nov) are in git history.

| Role | Where | What it does |
| --- | --- | --- |
| Coordinator | project chat | Talks to Andrew, starts and messages threads, writes the register and memory. Andrew reads the project chat on his phone, not threads. A fresh coordinator also reads [ROADMAP.md](ROADMAP.md), the library map `/mnt/project-files/INDEX.md` and the phone start page https://claude.ai/artifact/LQF6h696vYdtJee3soD2Pi |
| Gate | thread "Drive the wave <N> board" | The only thread that stacks onto the open stage. Cuts each `stage/alpha-w<N>`, opens the wave board, stacks reviewed pull requests, runs the wave gate per promotion and the release gate once per sprint (ruling cy), promotes. Owns the shared flow, launch, arena, boss and world files, and the PC Remote Control session for GPU work ([DEVICES.md](DEVICES.md)) |
| Unit threads | cloud threads | One unit each, built from the open stage: claim on the board with a file fence, build, run focused tests and `sketch:fast`, one independent review, a draft pull request with its receipt, a "ready" comment on the board ([COMMS.md](COMMS.md)) |
| Systems audit | thread "Audit and improve game systems" | The systems audit passes A to F (`docs/systems-audit/`), cards SA-A to SA-F in [BACKLOG.md](../../BACKLOG.md). Brings Andrew only a cut or merge of a feature, a pillar conflict, or a balance fix that needs a design change |
| Full-game audit | thread "Audit the whole game" | Audits the whole game on the open stage, started 14 Nov; its UI part runs on [the UI audit loop](../../sketches/core-loop/design-v3/ui-audit/README.md) |
| Tripo models | thread "Upgrade game models with Tripo" | Generated models for every world 1 prop, point of interest, set piece, enemy, creature and attack prop, behind `--models=tripo` (ruling do). Its permission check wants Andrew's approvals typed in its own thread |
| Nightly housekeeping | routine at 2:00 America/Phoenix | Keeps the library: new pages in `/mnt/project-files/INDEX.md` and on the Library page, the shared-folder copies of repo documents, and the decisions register doc in step with [DECISIONS.md](DECISIONS.md). Deletes nothing; candidates go in `/mnt/project-files/housekeeping/pending-deletes.md`, its log is `housekeeping/LOG.md`. At most one small docs pull request a night, never merged by the run |
| Reviewers | read-only agents a thread starts | One independent review per finished diff, naming the head it read. A thread never reviews its own work (ruling by) |

**Every thread finishes every to-do before it goes idle** (ruling dn, [AGENTS.md](../../AGENTS.md) rule 1). Every brief says so, and the coordinator checks a "done" task by task and nudges a thread that stopped partway.

**Restate the head in every message that carries a ruling.** A thread reads the board only when it pages it, and a thread stopped by usage limits does not resume by itself; the coordinator re-messages it with its head SHA.

**Gate steps.** The recipe is [GATE.md](GATE.md), with the step scripts under `scripts/gate/`. Before relaunching a "missing" step, check the board and the thread list.
