# Gemini Workflows Lessons Ledger

Each lesson captures an operational rule for running Scrapkeep workflows in Google Antigravity.

## Lessons

- **AGW-01** · status: provisional · since: 2026-11-25 · origin: Antigravity run_workflow skill alignment
  Use `run_workflow` only for multi-step pipelines or fan-outs across files, checks, or cards; use `invoke_subagent` for a single delegated task and act directly for 1–2 targeted operations.
  Evidence: `AGENTS.md:16` (subagents for wide search, noisy runs, and independent review); `docs/project/AI-WORKFLOW.md:1-45`.
  Overturned by: —

- **AGW-02** · status: provisional · since: 2026-11-25 · origin: ruling bp tier mapping
  Map Scrapkeep's fast/mid/top tiers to `flash`, `pro`, and `inherit` in `.agents/agents/scrapkeep-*.md`; never run an acceptance gate or independent review below its pinned tier.
  Evidence: `AGENTS.md:25` (ruling `bp` tier pinning); `.claude/agents/scrapkeep-reviewer.md:1-15`.
  Overturned by: —

- **AGW-03** · status: provisional · since: 2026-11-25 · origin: ruling by & ORCHESTRATOR review isolation
  Run static scope and doc checks deterministically in `subprocess.run` before spawning an independent read-only reviewer, and never pass the writer's brief to the reviewer.
  Evidence: `AGENTS.md:18` (Rule 4 checks + review); `.claude/agents/scrapkeep-reviewer-medium.md:9` and `.agents/agents/scrapkeep-reviewer-medium.md:11` ("Do not read the writer's brief").
  Overturned by: —

- **AGW-04** · status: provisional · since: 2026-11-25 · origin: card-runner refusal and Gate stacking boundary
  Reuse `scripts/card-runner.mjs` (`--json`) to filter `BACKLOG.md` cards before batch execution, default to `dry_run: true`, isolate writers in `workspace="share"`, and never push or stack onto a stage branch automatically.
  Evidence: `AGENTS.md:17` (ruling `ds`, only the Gate stacks); `scripts/card-runner.mjs:86-99` (unattended refusal rules).
  Overturned by: —

## Changelog

| Date | Change type | Ids touched | Evidence or commit | Reviewer |
| --- | --- | --- | --- | --- |
| 2026-11-25 | new lesson | AGW-01, AGW-02, AGW-03, AGW-04 | Initial Antigravity uplift (`scrapkeep-gemini-workflows`) | pending |
