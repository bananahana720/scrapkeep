# Start here

One local session on the Mac Studio coordinates the alpha and is the Gate (rulings eb, ep, eq). It talks to Andrew in its own chat, integrates reviewed pull requests onto `main` (and historically stacked `stage/alpha-w<N>`), runs the gate, promotes, and dispatches isolated worker units. [THREADS.md](THREADS.md) lists the roles. Where an older page says "the board thread" or "a thread", read "the local session" and "a worker agent".

The rules every session follows are in [AGENTS.md](../../AGENTS.md), most important first: finish every to-do, one thread one writer, only the Gate integrates, and what needs Andrew's go-ahead.

**A cloud or worker session sees only the repository and pull requests.** Do not rely on paths private to one machine (`~/scratch/...` or local notes). Gate receipts live on `scratch/gate-receipts-*` branches.

## Read first

The read order is in [AGENTS.md](../../AGENTS.md) ("Read first, in this order"): this page, then [STATE.md](STATE.md), then your brief or unit packet, then the [DECISIONS.md](DECISIONS.md) rows it cites.

Everything else is read when the work calls for it; the table below says which page. Historical notes from earlier local sessions are preserved in git history (`scratch/coordinator-notes-2026-11-11`).

## Where to go when

One home for every fact (ruling bz, Andrew, 9 Nov): update the page, doc or record that exists before making a new one, link instead of repeating, and add anything new in the same turn.

| When you are | Read | Write |
| --- | --- | --- |
| Starting | The list above, in order | Nothing yet |
| Starting a unit | Your brief, [STATE.md](STATE.md), the open pull requests, and `AGENTS.md` file fences | Your own isolated branch/worktree |
| Building | The unit's own sources; [DEEP-SWEEP.md](DEEP-SWEEP.md) for module boundaries; [the tone bible](../../sketches/core-loop/design-v3/TONE-BIBLE.md) before creative work; [LEGIBILITY.md](../../sketches/core-loop/design-v3/LEGIBILITY.md) section 13 before anything a player reads or navigates (ruling cx); [ART-MISTAKES.md](ART-MISTAKES.md) before art | Your own branch (ruling by); sub-agents only search, research, run noisy jobs and review. Scratch goes under `artifacts/local/` |
| Checking | The tiered gate in [ORCHESTRATOR.md](../../ORCHESTRATOR.md), then [CONTRIBUTING.md](../../CONTRIBUTING.md) for the commands | The fast-lane receipt and one independent Gemini 4 Neon High review (rule 4/11), both posted on the pull request |
| Wanting a method, an independent review or a best-practice check | `pstack` (`pstack@cursor-plugins`, ruling er: `/pstack:poteto-mode`, `/pstack:maintain-verification-skill`, `/pstack:statechart`, [DEVICES.md](DEVICES.md)) plus [GEMINI.md](../../GEMINI.md) and `.agents/skills/` (`.claude/skills/` in Claude Code) | Nothing new. Project rules (`AGENTS.md`, `ORCHESTRATOR.md`, rule 11) still win where they differ |
| Wanting to show a feature working in the running game, the packed build or a browser page | `scrapkeep-verify-game`, `scrapkeep-verify-build`, `scrapkeep-verify-web`, and `scrapkeep-verify-formal`. Headless Mac captures use `display-run.mjs --offscreen` or `--embedded --rendering-driver metal`; live MCP runs (`projectPath: sketches/core-loop`) must call `stop_project` before committing (`McpBridge` in `project.godot`) | Proof in the pull request receipt; saves in `artifacts/local/` |
| Taking a world 1 promise card (W1-131 to W1-144; Codex Astra may assist, ruling ec) | [docs/promises/README.md](../../docs/promises/README.md), your card, and [picture-proof.md](../../.agents/skills/scrapkeep-verify/references/picture-proof.md) | Draft pull request with round record, before/after stills, Sol QA verdict (`ruling ee`), and Gemini 4 Neon High review |
| Running backlog cards unattended | [scripts/card-runner.mjs](../../scripts/card-runner.mjs) (note: currently expects legacy `stage/alpha-w<N>` / board values in `STATE.md`, see `scripts/card-runner.mjs:85-93`) | Draft PRs and receipts |
| Writing anything another reader acts on | [COMMS.md](COMMS.md) (ruling cz) | Self-contained plain-English report |
| Handing over | Nothing new | Draft pull request against `main` with receipts |
| Running a gate shard | [GATE.md](GATE.md), [KNOWN-FAILING.tsv](KNOWN-FAILING.tsv) | Receipt on `scratch/gate-receipts-*` |
| Needing Andrew | [DECISIONS.md](DECISIONS.md) first: a ruled question is not asked again | One concise question with options and default |
| Holding a new ruling | The row it replaces, and the last letter taken (`er`) | [DECISIONS.md](DECISIONS.md) on `main`; `npm run check:docs` enforces unique letters |
| Holding a lesson | The section of [LESSONS.md](LESSONS.md) for your kind of work, to see it is new | One numbered line in `LESSONS.md`; art mistakes in `ART-MISTAKES.md` |
| Auditing the UI, or holding a UI finding | [The UI audit loop](../../sketches/core-loop/design-v3/ui-audit/README.md) and `npm run sketch:ui-audit` | One row in [UI-FINDINGS.tsv](UI-FINDINGS.tsv) with a class and guard if seen twice (LESSONS 70) |
| Holding a play finding | [PLAY-FINDINGS.tsv](PLAY-FINDINGS.tsv) (ruling cn) | One row with grade, owner and review date |
| Keeping evidence or records | Repository doc folders (`project-guide/handoff/`, `docs/`); disposable artifacts under `artifacts/local/` | Updated existing page before making a new one |
| Learning a fact the next session would ask again | This table, for the page that owns the subject | That page ([AGENTS.md](../../AGENTS.md) for repo rules, [DEVICES.md](DEVICES.md) for machine facts; private memory cleared 21 Nov 2026) |
| Wanting something deleted or archived | List candidates cleanly; never `git rm` without Andrew's go-ahead (`AGENTS.md`) | Whole-file deletion candidate table for Andrew's go-ahead |
| After integrating on `main` | [STATE.md](STATE.md) and [DEEP-SWEEP.md](DEEP-SWEEP.md) | Updated `Wave facts` (if applicable) and fast-lane timings |
| Changing a world 1 map, difficulty or hand-over | [shared/world1/](shared/world1/): [map-audit.md](shared/world1/map-audit.md) (`ct`), [difficulty-plan.md](shared/world1/difficulty-plan.md) (`cu`), [transitions-audit.md](shared/world1/transitions-audit.md) (`cv`), [gameplay-critique.md](shared/world1/gameplay-critique.md), [effects-critique.md](shared/world1/effects-critique.md) | The audit check plus planted failing case |
| Changing a model, material, pickup, icon or HUD piece | [visual-assets-audit.md](shared/world1/visual-assets-audit.md) and [SIGHT-PERSONA.md](../../sketches/core-loop/design-v3/SIGHT-PERSONA.md) | Primitive census and still at play distance |

What matters most right now: under rulings `ep` and `eq`, Worlds 1–3 are unparked and the Full-Alpha milestone (`ba4b8bef`) is landed flat on `main` ahead of Andrew's human sitting (`Sitting Kit`). [ROADMAP.md](ROADMAP.md) holds post-sitting and remaining polish order.
