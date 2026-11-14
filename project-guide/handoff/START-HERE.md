# Start here

The claude.ai project "Scrapkeep" coordinates the alpha (ruling dh). Its coordinator talks to Andrew in the project chat and starts one thread per unit of work. One thread, "Drive the wave <N> board", is the Gate: it alone stacks onto the open stage, runs the wave gate, promotes, and drives Andrew's PC through a Remote Control session for GPU work. [THREADS.md](THREADS.md) lists the roles.

The rules every thread follows are in [AGENTS.md](../../AGENTS.md), most important first: finish every to-do, one thread one writer, only the board thread stacks, and what needs Andrew's go-ahead.

**A cloud session cannot read the PC's disk.** It sees the repository, the pull requests, the wave board and, in a project thread, the shared folder `/mnt/project-files`. Gate receipts from the PC are on `scratch/gate-receipts-w<N>-<head>` branches.

## Read in this order

1. [AGENTS.md](../../AGENTS.md): the rules, and the steps that need no approval.
2. [STATE.md](STATE.md): where the wave stands. Its Wave facts table is the one place that names the open stage and the live board.
3. The board issue (it holds the open pull requests' file fences) and your brief. Post a claim before you build.
4. The rows of [DECISIONS.md](DECISIONS.md) your brief cites. Newest wins; do not re-ask one. Search it before you ask Andrew anything.

Everything else is read when the work calls for it; the table below says which page. A fresh coordinator also reads [ROADMAP.md](ROADMAP.md) (phone copy: https://claude.ai/artifact/55bppMdvsEXW52ZVFyhNna), the shared folder map `/mnt/project-files/INDEX.md` and the phone start page https://claude.ai/artifact/LQF6h696vYdtJee3soD2Pi. The log, briefs and scripts of the local PC session that coordinated on 10 and 11 November are on branch `scratch/coordinator-notes-2026-11-11`.

## Where to go when

One home for every fact (ruling bz, Andrew, 9 Nov): update the page, doc or record that exists before making a new one, link instead of repeating, and add anything new to the library in the same turn.

| When you are | Read | Write |
| --- | --- | --- |
| Starting | The list above, in order | Nothing yet |
| Claiming a unit | The board issue named in [STATE.md](STATE.md) and its file fences, the stage log, the open pull requests | One CLAIM comment on the board: the unit, your branch, the base and the files you will touch |
| Building | The unit's own sources; [DEEP-SWEEP.md](DEEP-SWEEP.md) for how to build; [the tone bible](shared/tone/TONE-BIBLE.md) before creative work; [LEGIBILITY.md](../../sketches/core-loop/design-v3/LEGIBILITY.md) section 13 before anything a player reads or navigates (ruling cx: no slop, marks before words); [ART-MISTAKES.md](ART-MISTAKES.md) before art | Your own branch. You write it yourself (ruling by); sub-agents only search, research, run noisy jobs and review. Scratch goes under `artifacts/local/` |
| Checking | The tiered gate in [ORCHESTRATOR.md](../../ORCHESTRATOR.md), then [CONTRIBUTING.md](../../CONTRIBUTING.md) for the commands | The fast-lane receipt and one independent review of the finished diff, both posted on the pull request |
| Wanting a method, an independent review or a best-practice check | Andrew's A stack plugin, `astack` (Andrew, 12 Nov: use it for verification and best practice in game development). It is synced into every claude.ai session (`~/.claude/plugins/synced/*/astack/`) and its skills are listed as `astack:*`; its agents are `astack:reviewer` (top tier), `astack:verifier` (mid tier) and `astack:scout` (fast lookup) | Nothing new. The project's own rules still win: one writer per thread, pinned tiers, the gate in ORCHESTRATOR |
| Wanting to show a feature working in the running game, the packed build or a browser page | The skills `scrapkeep-verify-game`, `scrapkeep-verify-build` and `scrapkeep-verify-web`. To watch the game while you build, the Godot MCP in `.mcp.json` ([tools/godot-mcp/run.sh](../../tools/godot-mcp/run.sh)): set `projectPath` to `sketches/core-loop`, use `run_project` (`background: true`), `take_screenshot`, `simulate_input`, `get_ui_elements` and `run_script`, and call `stop_project` before you commit, because a running game leaves an `McpBridge` autoload in `project.godot`. A cloud box renders slowly, so the 4080 still owns frame times | The proof goes in the pull request's receipt. Saves go to `artifacts/local/`, never Andrew's |
| Running backlog cards unattended | [scripts/card-runner.mjs](../../scripts/card-runner.mjs): it takes only S and M cards whose proof names a test, and only ones no PR or board claim names. Pass `--taken` with the open PRs and board comments. Each card gets a writer under a time and dollar cap, the fast lane and an independent review, and it is pushed only when both pass. Without `--run`, it prints the plan | One CLAIM per card before the run. A draft PR and a READY comment for each card that is pushed; a RELEASED comment for each that is not |
| Writing anything another reader acts on (a board post, a receipt, a brief, a report, a hand-off, a message to Andrew) | [COMMS.md](COMMS.md) (ruling cz) | The message, standing on its own for a reader with no context |
| Handing over | Nothing new | A draft pull request on the open stage, then one READY comment on the board with the receipts |
| Running a gate shard | [GATE.md](GATE.md), [KNOWN-FAILING.tsv](KNOWN-FAILING.tsv) | The receipt on a `scratch/gate-receipts-w<N>-<head>` branch, the verdict on the board |
| Needing Andrew | [DECISIONS.md](DECISIONS.md) first: a ruled question is not asked again | One decision card (question, options, a recommended default), asked once. Keep building on the recommendation while he decides |
| Holding a new ruling | The row it replaces, and the last letter taken | [DECISIONS.md](DECISIONS.md) on a docs pull request against the open stage. `npm run check:docs` fails a letter used twice |
| Holding a lesson | The section of [LESSONS.md](LESSONS.md) for your kind of work, to see it is new | One numbered line in LESSONS.md; an art mistake goes in ART-MISTAKES.md |
| Auditing the UI, or holding a UI finding | [The UI audit loop](../../sketches/core-loop/design-v3/ui-audit/README.md): the principles, each with its checks, and `npm run sketch:ui-audit` | One row in [UI-FINDINGS.tsv](UI-FINDINGS.tsv) with a class; a class seen twice also gets a guard in the same pull request (LESSONS 70) |
| Holding a play finding | [PLAY-FINDINGS.tsv](PLAY-FINDINGS.tsv), to see it is new | One row there with a grade, an owner and a review date (ruling cn); it never holds a promotion |
| Showing Andrew something | The library (`/mnt/project-files/INDEX.md`), to find the page that already covers it | That page, updated. A new page gets a line in INDEX.md and on the Library page in the same turn |
| Keeping evidence | `/mnt/project-files/INDEX.md`, for the folder that owns the area | The area's folder under `/mnt/project-files/`. Disposable output stays in `artifacts/local/` |
| Learning a fact the next thread would ask again | The project memory index | One memory file per subject, as a pointer to the home above, not a copy of it |
| Wanting something deleted or archived | `/mnt/project-files/housekeeping/pending-deletes.md`, to see it is not already listed | One row there with the reason; Andrew or the owner named decides. A thread deletes nothing itself, and merged branches go only through Andrew's prune script |
| Just after a promotion | "After each promotion" in [STATE.md](STATE.md) | The Wave facts table, the fast-lane timings, the deep sweep report |
| Changing a world 1 map, its difficulty or a hand-over between stages | The audit for it in [shared/world1/](shared/world1/): [the map audit](shared/world1/map-audit.md) (ruling ct), [the difficulty plan](shared/world1/difficulty-plan.md) (ruling cu), [the transitions audit](shared/world1/transitions-audit.md) (ruling cv), [the gameplay critique](shared/world1/gameplay-critique.md) (12 Nov), [the effects critique](shared/world1/effects-critique.md) for a hit, kill, warning, boss or world effect | The check the audit names for the point you touched, with its planted failing case; a new measurement goes back into the audit |
| Changing how a world 1 model, material, pickup, icon or HUD piece looks | [The visual assets critique](shared/world1/visual-assets-audit.md) and the sight persona, `sketches/core-loop/design-v3/SIGHT-PERSONA.md` | The primitive census for anything drawn in code, a PC still at play distance, and the row's own proof in BACKLOG.md |

What matters most right now: world 1 fully polished before Andrew plays it (ruling cs). [ROADMAP.md](ROADMAP.md) has the order of what is left. Worlds 2 and 3 start nothing new (ruling at). Model work with Tripo covers every world 1 prop, point of interest, set piece, enemy, creature and attack prop, behind `--models=tripo` (ruling do).
