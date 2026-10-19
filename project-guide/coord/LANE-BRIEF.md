# Lane brief template

The local coordinator fills the bracketed fields and starts each cloud lane with this text. A lane is a sub-coordinator: it plans its units, fans out its own agents and workflows inside its sandbox, gates its work and opens PRs. Andrew's words on 18 Oct authorize this: "sessions that can also be their own coordinators within their sandboxes. And if they need to spin up their own agents and yeah, kind of divide and conquer."

## Read first

1. [GRAPH.md](GRAPH.md): ownership, your units, their dependencies and the test gates.
2. [DECISIONS.md](../handoff/DECISIONS.md): Andrew's rulings, newest wins. Never re-ask one.
3. [LESSONS.md](../handoff/LESSONS.md) and [NEW-INSTRUCTIONS.md](../handoff/NEW-INSTRUCTIONS.md): how this project works.
4. [AMBITION-BRIEF.md](AMBITION-BRIEF.md): Andrew's 19 Oct goals, reframed through [the ambition article](../handoff/shared/ways-of-working/rieseberg-ambition-article.md). It covers the outcome, the hard targets with their instruments and outside checks, and the practices (by verb) your units use. Name the verb and the practice in every PR body.
5. `AGENTS.md`, `ORCHESTRATOR.md`, `CONTRIBUTING.md` and the skill for your work (`scrapkeep-task`, `scrapkeep-verify`, `scrapkeep-lab`).

## Fields

- **Lane:** [Gate + staging | Systems | World | Perf | Dressing | Life | Challenge] (cloud), or a PC lane named in GRAPH.md
- **Wave and stage:** wave [N], base `stage/alpha-w[N]`
- **Goal:** [one sentence end state]
- **Units:** [from GRAPH.md, with depends-on]
- **Acceptance:** each unit's checks from GRAPH.md "Test gates", plus [unit criteria]

## Ownership

Write only your units' files. Shared fold files (`registry.json`, attack ids, row digests) are re-folded by the Gate lane; claim ids on the Wave board issue first. Never push to `main`, never rebase or force-push a shared branch, never edit another lane's units or the coordinator's records (DECISIONS, LESSONS, STATE, GRAPH, TRACKING); propose those on the Wave board.

## Model routing

Writers on Sonnet 5.5, gates on Opus 5.5, consequential review on Fable 5.1, through the project agent definitions in `.claude/agents/`. Nothing above high effort. No thread grades its own work.

## Receipts and the bus

You cannot message other sessions. GitHub is the bus.
- Each unit ends as a PR against `stage/alpha-w[N]` with a receipt comment: `VERDICT <PASS|PASS+NOTES|FAIL|BLOCKED> head <sha>`, the commands run, nonzero test counts, and the reviewer's verdict.
- The Gate lane stacks PRs whose receipt is on their current head.
- Raise a hand on Wave board issue #[issue]: `NEEDS: coordinator|gpu|andrew`, one line of context, options and your recommendation. Keep building on the recommendation; the coordinator answers there at least every 30 minutes.
- GPU proofs (frame times, menu-ready, Vulkan, the real export) are requests on the Wave board tagged `NEEDS: gpu`; cloud perf numbers never count.

## Cloud box limits

4 vCPU, 15 GB, no GPU, about 2 h per background task. At most 6 Godot lanes; band sweeps can OOM, so rerun a 300 s or timeout row alone before calling it red. Copy evidence you want kept into the PR or a pushed branch before going quiet; the container is reclaimed when idle.

## Done

Every unit in your list has a PR with a receipt, or a Wave board note saying why not. Then post a lane summary on the Wave board and stop.
