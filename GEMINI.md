# Scrapkeep in Google Antigravity & Gemini

[AGENTS.md](AGENTS.md) is canonical. Read order: [START-HERE.md](project-guide/handoff/START-HERE.md) -> [STATE.md](project-guide/handoff/STATE.md) -> your brief and cited rows of [DECISIONS.md](project-guide/handoff/DECISIONS.md). See [AI-WORKFLOW.md](docs/project/AI-WORKFLOW.md) for cross-host workflow details.

## Worker Routing & Fallback Tier Map (Rule 11 / Ruling ej)

`AGENTS.md` Rule 11 (ruling `ej`) owns active worker routing: Claude Fable 5.2 leads design/planning, Claude Opus 5.5 takes 3D units, and Gemini 4 Neon at high effort handles code, tests, formal models, gate runs, and every independent review (Rule 4). Native subagents in `.agents/agents/scrapkeep-*.md` keep the older `ruling bp` tier pins as Rule 11's fallback when a named worker cannot run:

| Tier | Model | Subagents | Scope Notes |
| --- | --- | --- | --- |
| Fast | `flash` | `scrapkeep-explorer`, `scrapkeep-writer-low`, `scrapkeep-writer`, built-in `research` / `browser` | Read-only lookup and bounded writer units (fallback pin) |
| Mid | `pro` | `scrapkeep-verifier`, `scrapkeep-reviewer-medium` | Independent test receipts and fallback mechanical review (Rule 4/11 admission requires Gemini 4 Neon at high) |
| Top | `inherit` | `scrapkeep-reviewer` | Consequential Bible, ADR, or contract judgement (inherits Neon high) |

Report active Gemini model and tier from runtime metadata if exposed, otherwise state unavailable.

## Skills, Rules, Hooks & MCP Servers

- **Project skills (11)**: listed in [.agents/skills/README.md](.agents/skills/README.md); includes `scrapkeep-gemini-workflows` (`run_workflow` PR gate & card batching) and `scrapkeep-visual-review` (multimodal UI/film/art QA).
- **Antigravity built-ins**: `run-workflow`, `gemini-api-dev`, `gemini-api-cli`, `gemini-live-api-dev`, `modern-web-guidance`, `context7-mcp`, `ai-firstify`, `agy-customizations`, plus `research`, `browser`, and `image-generator`.
- **MCP servers**: `godot_godot` (`projectPath: "sketches/core-loop"`, saves in `artifacts/local/`, always call `stop_project` before committing), `blender_blender`, `gemini-api_gemini-api-docs`, `context7_context7`.
- **Scoped rules & safety gates**: `.agents/rules/` auto-loads `godot-core-loop.md`, `browser-proofs.md`, and `creative-and-visual.md`; `.agents/hooks.json` invokes `.agents/hooks/safety-gate.mjs` on `PreToolUse` to enforce `AGENTS.md` approval and `McpBridge` boundaries mechanically.
