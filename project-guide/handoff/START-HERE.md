# Start here

Coordination runs from the claude.ai project "Scrapkeep" on Andrew's main account (since 23 Oct 2026). The project coordinator talks to Andrew in the project chat; cloud threads are the lanes; Remote Control sessions on his PC run GPU work. A fresh coordinator or thread reads these in order:

1. The project instructions (in the project settings): goal, mission statement, direction principles 1-22, how work flows, standing approval.
2. [DECISIONS.md](DECISIONS.md): Andrew's rulings. Newest wins. Don't re-ask one. His readable copy is the Claude Doc https://claude.ai/code/artifact/e209a132-0f39-416d-a116-3be4e9df8de9; threads also read /mnt/project-files/project-guide/DECISIONS.md. All three change together.
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
| Building | The unit's own sources; [DEEP-SWEEP.md](DEEP-SWEEP.md) for how to build; `/mnt/project-files/tone/TONE-BIBLE.md` before creative work; [ART-MISTAKES.md](ART-MISTAKES.md) before art | Your own branch. You write it yourself (ruling by); sub-agents only search, research, run noisy jobs and review. Scratch goes under `artifacts/local/` |
| Checking | The tiered gate in [ORCHESTRATOR.md](../../ORCHESTRATOR.md), then [CONTRIBUTING.md](../../CONTRIBUTING.md) for the commands | The fast-lane receipt (`artifacts/local/receipts/`) and one independent review of the finished diff |
| Handing over | Nothing new | A draft pull request on the open stage, then one READY comment on the board with the receipts |
| Running a gate shard | [GATE.md](GATE.md), [KNOWN-FAILING.tsv](KNOWN-FAILING.tsv), the gate plan under `/mnt/project-files/gate/` | The receipt under `/mnt/project-files/gate/w<N>-<head>/`, the verdict on the board, a reply to the Gate thread |
| Needing Andrew | [DECISIONS.md](DECISIONS.md) first: a ruled question is not asked again | A card to the coordinator (question, options, a recommendation); never a question inside a thread |
| Holding a new ruling | The row it replaces | [DECISIONS.md](DECISIONS.md) on the open stage, then its two copies in the same turn (step 2 above) |
| Holding a lesson | [LESSONS.md](LESSONS.md), to see it is new | One numbered line in LESSONS.md; an art mistake goes in ART-MISTAKES.md |
| Showing Andrew something | The library (`/mnt/project-files/INDEX.md`), to find the page that already covers it | That page, updated. A new page gets a line in INDEX.md and on the Library page in the same turn |
| Keeping evidence | `/mnt/project-files/INDEX.md`, for the folder that owns the area | The area's folder under `/mnt/project-files/`. Disposable output stays in `artifacts/local/` |
| Learning a fact the next thread would ask again | The project memory index | One memory file per subject, as a pointer to the home above, not a copy of it |
| Just after a promotion | "After each promotion" in [STATE.md](STATE.md) | The Wave facts table, the fast-lane timings, the deep sweep report |

What matters most right now: world 1 first. Andrew has played the dam (30 Oct) and not yet marked any area. On 9 Nov he asked for a pre-sitting improvement pass first (ruling bo), so the build he plays is the promotion that carries that pass (STATE.md). Post-sitting work comes from his marks. Worlds 2 and 3 start nothing new (ruling at).

How to build (Andrew, 9 Nov): deepen the game's modules and keep the interfaces between the pieces as simple as possible. New behaviour goes inside the module that owns the state; callers get one small call, not a reach into private members. [DEEP-SWEEP.md](DEEP-SWEEP.md) has the method, and it applies to every unit, not only the sweep after a promotion.
