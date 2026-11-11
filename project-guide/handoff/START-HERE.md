# Start here

Coordination runs from one local Claude Code session on Andrew's PC (since 10 Nov 2026, ruling cs). That session is the coordinator and the Gate: it talks to Andrew, stacks and promotes, runs the full gate on the PC, writes sequential changes itself and gives disjoint units to writer agents in their own worktrees. The claude.ai project "Scrapkeep" coordinated from 23 Oct to 10 Nov, and its threads stopped at the handoff posted on the wave 34 board (10 Nov, 16:33Z).

**On the PC there is no `/mnt/project-files`.** Where a page names a path under it, use the PC stand-in: gate plans and receipts are under `~/scratch/gate/`, the coordinator's briefs and notes under `~/scratch/world1/`, and the repo copies under [shared/](shared/) (the tone bible, the sitting watch list). The repo file is the register. The Claude Doc and shared-folder copies of DECISIONS.md are Andrew's reading copies: the nightly housekeeping routine brings them in step with the repo file (through ruling cz on 11 Nov), so they can be up to a day behind. A row below that says "project thread" describes how the project ran, kept for a session that works there again.

**A session that is not on the PC cannot read the PC's disk.** A cloud session sees the repository, the pull requests and the wave board. The PC coordinator's log, briefs and helper scripts, and the gate receipts, are published on `scratch/` branches; the "Now" paragraph of [STATE.md](STATE.md) names the current ones. Built units wait as draft pull requests on the open stage, each with a receipt. [COMMS.md](COMMS.md) says how to write so the next reader needs nothing else.

A fresh coordinator or session reads these in order:

1. The project instructions (in the project settings, for project threads): goal, mission statement, how work flows, standing approval. The direction principles are DECISIONS.md's Direction table. What needs no approval, and what needs Andrew's go-ahead first, is the last section of [AGENTS.md](../../AGENTS.md).
2. [DECISIONS.md](DECISIONS.md): Andrew's rulings. Newest wins. Don't re-ask one. The repo file is the register; the Claude Doc https://claude.ai/code/artifact/e209a132-0f39-416d-a116-3be4e9df8de9 and /mnt/project-files/project-guide/DECISIONS.md are reading copies that the nightly housekeeping routine keeps in step with it, up to a day behind.
3. [LESSONS.md](LESSONS.md): how this project works (numbered lessons; numbers stay fixed).
4. [ROADMAP.md](ROADMAP.md): what is left, in order. Phone copy: https://claude.ai/artifact/55bppMdvsEXW52ZVFyhNna
5. [STATE.md](STATE.md): where the wave stands and what holds it. Its Wave facts table is the one place that names the live board.
6. [GATE.md](GATE.md), for a thread that runs or judges a gate shard: the recipe and the known-failing ledger.
7. The shared folder map /mnt/project-files/INDEX.md and the phone start page https://claude.ai/artifact/LQF6h696vYdtJee3soD2Pi (every page marked Current, Reference or Out of date).
8. A lane then reads the wave's board issue (named in STATE.md's Wave facts table, nowhere else), the stack queue `/mnt/project-files/gate/w<N>-stack-queue.md` and its own brief, and posts a claim before building. [GRAPH.md](../coord/GRAPH.md) is the wave 18 board, kept as history.

## Where to go when

One home for every fact (ruling bz, Andrew, 9 Nov): update the page, doc or record that exists before making a new one, link instead of repeating, and add anything new to the library in the same turn.

| When you are | Read | Write |
| --- | --- | --- |
| Starting | The list above, in order | Nothing yet |
| Claiming a unit | The board issue named in [STATE.md](STATE.md), the stage log (`git log origin/stage/alpha-w<N>`), the open pull requests, `/mnt/project-files/gate/w<N>-stack-queue.md` | One CLAIM comment on the board: the unit, your branch, the base and the files you will touch |
| Building | The unit's own sources; [DEEP-SWEEP.md](DEEP-SWEEP.md) for how to build; [the tone bible](shared/tone/TONE-BIBLE.md) before creative work; [LEGIBILITY.md](../../sketches/core-loop/design-v3/LEGIBILITY.md) section 13 before anything a player reads or navigates (ruling cx: no slop, marks before words); [ART-MISTAKES.md](ART-MISTAKES.md) before art | Your own branch. You write it yourself (ruling by); sub-agents only search, research, run noisy jobs and review. Scratch goes under `artifacts/local/` |
| Checking | The tiered gate in [ORCHESTRATOR.md](../../ORCHESTRATOR.md), then [CONTRIBUTING.md](../../CONTRIBUTING.md) for the commands | The fast-lane receipt (`artifacts/local/receipts/`) and one independent review of the finished diff |
| Writing anything another reader acts on (a board post, a receipt, a brief, a report, a hand-off, a message to Andrew) | [COMMS.md](COMMS.md) (ruling cz) | The message, standing on its own for a reader with no context |
| Handing over | Nothing new | A draft pull request on the open stage, then one READY comment on the board with the receipts |
| Running a gate shard | [GATE.md](GATE.md), [KNOWN-FAILING.tsv](KNOWN-FAILING.tsv), the gate plan under `/mnt/project-files/gate/` | The receipt under `/mnt/project-files/gate/w<N>-<head>/`, the verdict on the board, a reply to the Gate thread |
| Needing Andrew | [DECISIONS.md](DECISIONS.md) first: a ruled question is not asked again | In a project thread, a card to the coordinator (question, options, a recommendation), because Andrew reads the project chat on his phone, not threads. In a local session at his computer, ask him directly, once, with a recommended default |
| Holding a new ruling | The row it replaces, and the last letter taken | [DECISIONS.md](DECISIONS.md) on the open stage (its two project copies are frozen, step 2 above). `npm run check:docs` fails a letter used twice |
| Holding a lesson | [LESSONS.md](LESSONS.md), to see it is new | One numbered line in LESSONS.md; an art mistake goes in ART-MISTAKES.md |
| Holding a play finding | [PLAY-FINDINGS.tsv](PLAY-FINDINGS.tsv), to see it is new | One row there with a grade, an owner and a review date (ruling cn); it never holds a promotion |
| Showing Andrew something | The library (`/mnt/project-files/INDEX.md`), to find the page that already covers it | That page, updated. A new page gets a line in INDEX.md and on the Library page in the same turn |
| Keeping evidence | `/mnt/project-files/INDEX.md`, for the folder that owns the area | The area's folder under `/mnt/project-files/`. Disposable output stays in `artifacts/local/` |
| Learning a fact the next thread would ask again | The project memory index | One memory file per subject, as a pointer to the home above, not a copy of it |
| Wanting something deleted or archived | `/mnt/project-files/housekeeping/pending-deletes.md`, to see it is not already listed | One row there with the reason; Andrew or the owner named decides. A thread deletes nothing itself, and merged branches go only through Andrew's prune script |
| Just after a promotion | "After each promotion" in [STATE.md](STATE.md) | The Wave facts table, the fast-lane timings, the deep sweep report |
| Changing a world 1 map, its difficulty or a hand-over between stages | The audit for it in [shared/world1/](shared/world1/): [the map audit](shared/world1/map-audit.md) (ruling ct), [the difficulty plan](shared/world1/difficulty-plan.md) (ruling cu), [the transitions audit](shared/world1/transitions-audit.md) (ruling cv) | The check the audit names for the point you touched, with its planted failing case; a new measurement goes back into the audit |

What matters most right now: world 1 first, and world 1 fully polished before he plays (ruling cs, 10 Nov). Andrew has played the dam (30 Oct) and not yet marked any area. The pre-sitting improvement pass (ruling bo) is on `main` as wave 33. The open world 1 list is now worked wave by wave (STATE.md), and the build he plays is the promotion that closes it, handed over as "ready for your verdict". Worlds 2 and 3 start nothing new (ruling at).

How to build (Andrew, 9 Nov): deepen the game's modules and keep the interfaces between the pieces as simple as possible. New behaviour goes inside the module that owns the state; callers get one small call, not a reach into private members. [DEEP-SWEEP.md](DEEP-SWEEP.md) has the method, and it applies to every unit, not only the sweep after a promotion.
