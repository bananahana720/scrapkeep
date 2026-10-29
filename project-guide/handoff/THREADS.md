# Threads and sessions (29 Oct 2026, project coordinator)

Coordination runs from the claude.ai project "Scrapkeep". The coordinator talks to Andrew in the project chat and starts one thread per lane or unit; Remote Control sessions on his PC run GPU work. Thread ids change as lanes open and close, so the coordinator's project memory holds the current ids; this file names the standing roles. The 22 Oct PC-coordinator lane table is in git history.

| Role | Where | What it does |
| --- | --- | --- |
| Coordinator | project chat | Talks to Andrew, starts threads, admits and merges gate-passed PRs, promotes stages, writes the register |
| Gate | cloud thread | Cuts each `stage/alpha-w<N>`, opens the wave board, stacks green PRs, runs the full gate once per promotion. Doesn't write fixes |
| Unit and lane threads | cloud threads | One unit or lane each; branch from the current stage, open a draft PR, post a claim and receipts on the wave board |
| Bands | cloud thread | Difficulty band reads per promotion |
| PC work | Remote Control session on Andrew's PC | 4080 frame timing, 3060 renders, music, export proofs. Only the coordinator's `message_thread` reaches it |
| Sitting prep | cloud thread | The sitting sheet (/mnt/project-files/world1/sitting-sheet.html) and the gap list |
| Blender | cloud thread | Props on the Blender kit; code-side and Blender-side work stay in separate threads |

**Threads are one-way for rulings.** A thread reads the board only when it pages it, so restate the head SHA in every message that carries a ruling. Threads stopped by usage limits don't resume on their own; the coordinator re-messages each with its head SHA.

**Gate shards.** A full gate runs about 13 shard threads from one project post (tests in three blocks, bots in blocks of five, bands A to C, one red team persona); the recipe is in the Gate thread's memory and /mnt/project-files/gate/BOT-SHARDS.md. Before relaunching a "missing" shard, check the thread list and the board.
