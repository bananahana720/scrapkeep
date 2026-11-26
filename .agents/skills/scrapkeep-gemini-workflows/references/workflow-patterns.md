# Dynamic Workflow Patterns (`run_workflow`)

Use `run_workflow` when orchestration logic is code: fanning out across files or cards, running multi-stage checks before review, or aggregating structured JSON verdicts. Use `invoke_subagent` directly for a single delegated task.

## Primitives Checklist

- `phase(name)`: Group logs and agent cards in the Antigravity UI (`"Scope and diff"`, `"Scoped verification checks"`, `"Independent review"`).
- `subprocess.run(...)`: Run deterministic repo scripts (`node scripts/check-scope.mjs`, `npm run check:agents`, `node scripts/card-runner.mjs --json`, `git diff`) directly in Python without burning LLM turns or assuming host-specific `call_tool` injection.
- `agent(prompt, schema=..., role=..., type_name=..., workspace=..., model=...)`: Always provide a strict JSON `schema` so the child terminates by calling `finish` with structured data.
- `parallel(items, fn)` / `pipeline(items, fn)`: Fan out independent read-only inspections or serialize `workspace="share"` writers (<= 3 active writers per `ORCHESTRATOR.md`).

## Included Scripts

1. `.agents/skills/scrapkeep-gemini-workflows/scripts/pr_gate_review.py`:
   - `Args`: `{"base": "<optional>", "candidate": "HEAD", "consequential": false, "reviewer_model": "inherit", "acceptance": ""}` (`base` defaults to `origin` `main`, or the `Open stage` branch if `project-guide/handoff/STATE.md` names one).
   - Runs `node scripts/check-scope.mjs`, executes `npm run check:agents`, `npm run check:skills`, and `check:scope`-selected npm commands via `subprocess.run`, captures `git diff`, and dispatches `scrapkeep-reviewer-medium` (or `scrapkeep-reviewer` when `consequential` is true) with `model="inherit"` by default (so a Gemini 4 Neon high session satisfies `AGENTS.md` Rules 4 & 11; fallback `pro` is advisory only) and structured `{verdict, findings, evidence_level, summary}`.
2. `.agents/skills/scrapkeep-gemini-workflows/scripts/card_batch.py`:
   - `Args`: `{"cards": ["<ID>"], "section": "", "limit": 2, "dry_run": true, "reviewer_model": "inherit"}`.
   - Calls `node scripts/card-runner.mjs --json` to enforce `BACKLOG.md` refusal rules, then optionally runs an isolated `workspace="share"` `scrapkeep-writer`, captures coordinator `git diff` + `npm run sketch:fast` receipts via `subprocess.run`, and passes only card + diff + receipts to `scrapkeep-reviewer-medium` (`model="inherit"` by default per Rule 11) without pushing or stacking.

## Validation

Because `run_workflow` scripts allow top-level `await`, validate syntax with `npm run check:agents` (which compiles all workflow `.py` files with `ast.PyCF_ALLOW_TOP_LEVEL_AWAIT`), rather than `py_compile`.
