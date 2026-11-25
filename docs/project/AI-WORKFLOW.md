# Scrapkeep in Antigravity and Claude Code

Scrapkeep supports **Google Antigravity (Gemini)** and **Claude Code** as first-class hosts (Codex retired on 17 October 2026). Antigravity loads [GEMINI.md](../../GEMINI.md) with [AGENTS.md](../../AGENTS.md), scoped rules in `.agents/rules/`, subagents in `.agents/agents/`, `PreToolUse` hooks in `.agents/hooks.json`, and skills in `.agents/skills/`. Claude Code loads `CLAUDE.md` (which imports `AGENTS.md`), `.claude/agents/`, and `.claude/skills/` symlinks to `.agents/skills/`.

## Use it

| Request | Workflow |
| --- | --- |
| "Plan the next Scrapkeep session" | `plan-session` reads the board and discusses unresolved choices without starting a sprint. |
| "Implement approved card <ID>" | `scrapkeep-task` checks authorization and prerequisites before assigning isolated work. |
| "Verify this Scrapkeep change" | `scrapkeep-verify` selects checks for the artifact and reports evidence limits. |
| "Block out this pocket in mojulo" | `scrapkeep-blockout` builds mojulo recipes, exports lit glb, and proves them with the ball. |
| "Show this working in the running game" | `scrapkeep-verify-game` drives `sketches/core-loop` with real keys/clicks and keeps pictures, rows, and saves. |
| "Check the build Andrew will install" | `scrapkeep-verify-build` checks and drives the packed Linux build (`core-loop.x86_64`). |
| "Check the Sitting Kit page" or a preserved browser proof | `scrapkeep-verify-web` serves the Sitting Kit, yard, and Iron Orchard in headless Chromium. |
| "Model-check the run flow" or a change to `flow.gd` | `scrapkeep-verify-formal` model-checks `RunFlow.tla` against death, retry, new run, quit, and Continue. |
| "Design or evaluate a model decision inside the game loop" | `reactive-model-loop` covers controls, blind corpora, pre-registration, caching, and cost fields. |
| "Run parallel PR review, `run_workflow` pipelines, or card batches" | `scrapkeep-gemini-workflows` runs `pr_gate_review.py` and `card_batch.py` with Gemini tier routing. |
| "Audit screenshots, UI legibility, `eye.mjs` films, or Gemini refsheets" | `scrapkeep-visual-review` runs multimodal `read_file` checks, `eye_read_workflow.py`, `image-generator`, and MCP inspection. |

Slash commands match the 11 skill names above; see [the skills README](../../.agents/skills/README.md) when adding one. `BIBLE.md`, `adr/`, `BACKLOG.md`, `TRACKING.md`, and `ORCHESTRATOR.md` remain the canonical heavy-lane authorities.

## Host behavior & safety gates

- **Tier routing & isolation**: [GEMINI.md](../../GEMINI.md) owns the Antigravity Gemini tier map (`flash`, `pro`, `inherit`), MCP servers, and built-in tools; `.claude/agents/` owns Claude pins (`sonnet`, `opus`, `fable`). Explorers and reviewers exclude shell and edits and never read the writer's brief.
- **Worktrees**: Coordinators create isolated checkouts via `workspace: "share"` (Antigravity) or `scripts/new-worktree.sh <task-id> <base-sha>`.
- **Mechanical gates**: Antigravity enforces approval boundaries in `.agents/hooks.json` via `.agents/hooks/safety-gate.mjs`; Claude Code enforces them in `.claude/settings.json` (`permissions.deny` / `ask`).

## Check the installation

```sh
npm run check:agents
npm run check:skills
npm run check:project
npm run check:docs
npm run check:scope -- <base> <candidate> [--no-build]
node --test tests/antigravity-hooks.test.js
```

Tracked audit and decision trails live under `artifacts/ai-first-audit-2026-11-25/`.

## Sprint handback

When a heavy-lane sprint exhausts its work, follow [ORCHESTRATOR.md](../../ORCHESTRATOR.md#sprint-closure).
