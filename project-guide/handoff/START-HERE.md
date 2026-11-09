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

What matters most right now: world 1 first. Andrew has played the dam (30 Oct) and not yet marked any area. On 9 Nov he asked for a pre-sitting improvement pass first (ruling bo), so the build he plays is the promotion that carries that pass (STATE.md). Post-sitting work comes from his marks. Worlds 2 and 3 start nothing new (ruling at).

How to build (Andrew, 9 Nov): deepen the game's modules and keep the interfaces between the pieces as simple as possible. New behaviour goes inside the module that owns the state; callers get one small call, not a reach into private members. [DEEP-SWEEP.md](DEEP-SWEEP.md) has the method, and it applies to every unit, not only the sweep after a promotion.
