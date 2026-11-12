# Start here

The claude.ai project "Scrapkeep" coordinates the alpha. Its coordinator talks to Andrew in the project chat and starts one thread per unit of work. One thread, "Drive the wave <N> board", is the Gate: it alone stacks onto the open stage, runs the wave gate and promotes, and it drives Andrew's PC through a Remote Control session for GPU work (frame timing, films, renders). History: the project coordinated from 23 Oct to 10 Nov, a local Claude Code session on the PC coordinated from 10 to 11 Nov (ruling cs), and the project took coordination back on 11 Nov. That local session's log, briefs and scripts are on branch `scratch/coordinator-notes-2026-11-11`.

**A cloud session cannot read the PC's disk.** It sees the repository, the pull requests, the wave board and, in a project thread, the shared folder `/mnt/project-files`. Gate receipts from the PC are published on `scratch/gate-receipts-w<N>-<head>` branches. Built units wait as draft pull requests on the open stage, each with a receipt. [COMMS.md](COMMS.md) says how to write so the next reader needs nothing else.

A fresh coordinator or session reads these in order:

1. The project instructions (in the project settings, for project threads): goal, mission statement, how work flows, standing approval. The direction principles are DECISIONS.md's Direction table. What needs no approval, and what needs Andrew's go-ahead first, is the last section of [AGENTS.md](../../AGENTS.md).
2. [DECISIONS.md](DECISIONS.md): Andrew's rulings. Newest wins. Don't re-ask one. The repo file is the register; its two reading copies (a Claude Doc and the shared folder) are synced nightly and can be a day behind.
3. [LESSONS.md](LESSONS.md): how this project works (numbered lessons; numbers stay fixed).
4. [ROADMAP.md](ROADMAP.md): what is left, in order. Phone copy: https://claude.ai/artifact/55bppMdvsEXW52ZVFyhNna
5. [STATE.md](STATE.md): where the wave stands and what holds it. Its Wave facts table is the one place that names the live board.
6. [GATE.md](GATE.md), for a thread that runs or judges a gate shard: the recipe and the known-failing ledger.
7. The shared folder map /mnt/project-files/INDEX.md and the phone start page https://claude.ai/artifact/LQF6h696vYdtJee3soD2Pi (every page marked Current, Reference or Out of date).
8. A lane then reads the wave's board issue (named in STATE.md's Wave facts table, nowhere else; it also holds the open pull requests' file fences) and its own brief, and posts a claim before building. The stage log (`git log --first-parent origin/stage/alpha-w<N>`) is the stack queue.

## Where to go when

One home for every fact (ruling bz, Andrew, 9 Nov): update the page, doc or record that exists before making a new one, link instead of repeating, and add anything new to the library in the same turn.

| When you are | Read | Write |
| --- | --- | --- |
| Starting | The list above, in order | Nothing yet |
| Claiming a unit | The board issue named in [STATE.md](STATE.md) and its file fences, the stage log, the open pull requests | One CLAIM comment on the board: the unit, your branch, the base and the files you will touch |
| Building | The unit's own sources; [DEEP-SWEEP.md](DEEP-SWEEP.md) for how to build; [the tone bible](shared/tone/TONE-BIBLE.md) before creative work; [LEGIBILITY.md](../../sketches/core-loop/design-v3/LEGIBILITY.md) section 13 before anything a player reads or navigates (ruling cx: no slop, marks before words); [ART-MISTAKES.md](ART-MISTAKES.md) before art | Your own branch. You write it yourself (ruling by); sub-agents only search, research, run noisy jobs and review. Scratch goes under `artifacts/local/` |
| Checking | The tiered gate in [ORCHESTRATOR.md](../../ORCHESTRATOR.md), then [CONTRIBUTING.md](../../CONTRIBUTING.md) for the commands | The fast-lane receipt and one independent review of the finished diff, both posted on the pull request |
| Writing anything another reader acts on (a board post, a receipt, a brief, a report, a hand-off, a message to Andrew) | [COMMS.md](COMMS.md) (ruling cz) | The message, standing on its own for a reader with no context |
| Handing over | Nothing new | A draft pull request on the open stage, then one READY comment on the board with the receipts |
| Running a gate shard | [GATE.md](GATE.md), [KNOWN-FAILING.tsv](KNOWN-FAILING.tsv) | The receipt on a `scratch/gate-receipts-w<N>-<head>` branch, the verdict on the board |
| Needing Andrew | [DECISIONS.md](DECISIONS.md) first: a ruled question is not asked again | One decision card (question, options, a recommended default), asked once. Keep building on the recommendation while he decides |
| Holding a new ruling | The row it replaces, and the last letter taken | [DECISIONS.md](DECISIONS.md) on a docs pull request against the open stage. `npm run check:docs` fails a letter used twice |
| Holding a lesson | [LESSONS.md](LESSONS.md), to see it is new | One numbered line in LESSONS.md; an art mistake goes in ART-MISTAKES.md |
| Holding a play finding | [PLAY-FINDINGS.tsv](PLAY-FINDINGS.tsv), to see it is new | One row there with a grade, an owner and a review date (ruling cn); it never holds a promotion |
| Showing Andrew something | The library (`/mnt/project-files/INDEX.md`), to find the page that already covers it | That page, updated. A new page gets a line in INDEX.md and on the Library page in the same turn |
| Keeping evidence | `/mnt/project-files/INDEX.md`, for the folder that owns the area | The area's folder under `/mnt/project-files/`. Disposable output stays in `artifacts/local/` |
| Learning a fact the next thread would ask again | The project memory index | One memory file per subject, as a pointer to the home above, not a copy of it |
| Wanting something deleted or archived | `/mnt/project-files/housekeeping/pending-deletes.md`, to see it is not already listed | One row there with the reason; Andrew or the owner named decides. A thread deletes nothing itself, and merged branches go only through Andrew's prune script |
| Just after a promotion | "After each promotion" in [STATE.md](STATE.md) | The Wave facts table, the fast-lane timings, the deep sweep report |
| Changing a world 1 map, its difficulty or a hand-over between stages | The audit for it in [shared/world1/](shared/world1/): [the map audit](shared/world1/map-audit.md) (ruling ct), [the difficulty plan](shared/world1/difficulty-plan.md) (ruling cu), [the transitions audit](shared/world1/transitions-audit.md) (ruling cv) | The check the audit names for the point you touched, with its planted failing case; a new measurement goes back into the audit |

What matters most right now: world 1 fully polished before Andrew plays it (ruling cs). [ROADMAP.md](ROADMAP.md) has the order of what is left and [STATE.md](STATE.md) where the open wave stands. Worlds 2 and 3 start nothing new (ruling at).

How to build (Andrew, 9 Nov): deepen the game's modules and keep the interfaces between the pieces as simple as possible. New behaviour goes inside the module that owns the state; callers get one small call, not a reach into private members. [DEEP-SWEEP.md](DEEP-SWEEP.md) has the method, and it applies to every unit, not only the sweep after a promotion.
