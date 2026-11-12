# Lane brief template

The local coordinator fills the bracketed fields and starts each cloud lane with this text. A lane is a sub-coordinator: it plans its units, fans out its own agents and workflows inside its sandbox, gates its work and opens PRs. Andrew's words on 18 Oct authorize this: "sessions that can also be their own coordinators within their sandboxes. And if they need to spin up their own agents and yeah, kind of divide and conquer."

## Read first

1. [START-HERE.md](../handoff/START-HERE.md), then the wave board that [STATE.md](../handoff/STATE.md) names: ownership, your units and their dependencies. [GRAPH.md](GRAPH.md) is the wave 18 board, kept as history.
2. [DECISIONS.md](../handoff/DECISIONS.md): Andrew's rulings, newest wins. Don't re-ask one without new information.
3. [LESSONS.md](../handoff/LESSONS.md): how this project works.
4. [AMBITION-BRIEF.md](AMBITION-BRIEF.md): Andrew's 19 Oct goals, reframed through [the ambition article](../handoff/shared/ways-of-working/rieseberg-ambition-article.md). It covers the outcome, the hard targets with their instruments and outside checks, and the practices (by verb) your units use. Name the verb and the practice in every PR body.
5. `AGENTS.md`, `ORCHESTRATOR.md`, `CONTRIBUTING.md` and the skill for your work (`scrapkeep-task`, `scrapkeep-verify`, `scrapkeep-lab`).

## Fields

- **Lane:** [a cloud lane or a PC lane named on the wave board and in THREADS.md]
- **Wave and stage:** wave [N], base `stage/alpha-w[N]`
- **Goal:** [one sentence end state]
- **Units:** [from the wave board, with depends-on]
- **Acceptance:** each unit's checks (focused tests on the feature plus `npm run sketch:fast`; the wave gate runs per promotion and the release gate once per sprint, ruling cy), plus [unit criteria]

## Ownership

Write only your units' files. Shared fold files (`registry.json`, attack ids, row digests) are re-folded by the Gate lane; claim ids on the Wave board issue first. Push your own branch freely. Main moves only through the Gate's promotion under the standing merge authority, and a rebase or force-push of a shared branch needs Andrew's go-ahead first, because other lanes build on it. Propose edits to another lane's units or the coordinator's records (DECISIONS, LESSONS, STATE, GRAPH, TRACKING) on the Wave board, because their owners admit them.

## Model routing

By tier, through the project agent definitions in `.claude/agents/` (ruling bp, in AGENTS.md): the fast tier for search and well-specified mechanical writing, the mid tier for routine review and the acceptance gate, the top tier at high for judgement and consequential review. Nothing above high effort. No thread grades its own work.

## Receipts and the bus

You cannot message other sessions. GitHub is the bus. The reader of every post has seen none of your work and cannot see your disk, so write each one to stand on its own, as [COMMS.md](../handoff/COMMS.md) sets out (ruling cz).
- Each unit ends as a PR against `stage/alpha-w[N]` with a receipt comment: `VERDICT <PASS|PASS+NOTES|FAIL|BLOCKED> head <sha>`, one sentence on what a player or the next engineer now gets, the commands run, nonzero test counts, what was not checked, and the reviewer's verdict.
- The Gate lane stacks PRs whose receipt is on their current head.
- Raise a hand on Wave board issue #[issue]: `NEEDS: coordinator|gpu|andrew`, one line of context, options and your recommendation. Keep building on the recommendation; the coordinator answers there at least every 30 minutes.
- GPU proofs (frame times, menu-ready, Vulkan, the real export) are requests on the Wave board tagged `NEEDS: gpu`; cloud perf numbers never count.

## Cloud box limits

4 vCPU, 15 GB, no GPU, about 2 h per background task. CPU-only work runs here by default. At most 6 Godot lanes; band sweeps can OOM, so rerun a 300 s or timeout row alone before calling it red. Copy evidence you want kept into the PR or a pushed branch before going quiet; the container is reclaimed when idle.

## Done

Every unit in your list has a PR with a receipt, or a Wave board note saying why not. Then post a lane summary on the Wave board and stop.
