---
name: harness-hooks-and-corpora
description: Where Andrew's Claude Code guard hooks, their corpora and the change record live, and what each gate enforces.
metadata:
  type: reference
---

Four hooks under `~/.claude/hooks/` registered in `~/.claude/settings.json` since 2026-09-12: `agent-type-guard.sh` (PreToolUse on Agent, denies unregistered subagent types), `delegate-report-gate.sh` (SubagentStop on pstack-, scrapkeep- and poteto agents, blocks a final report once if it lacks verdict, evidence level, receipt or head SHA), `session-state.sh` (Stop, writes a resume note under `~/.claude/projects/<slug>/`), `model-pin-audit.sh` (SessionStart, flags project agent pins off the pstack map). `sudo-guard.sh` predates them. Run every corpus with `bash ~/.claude/hooks/tests/run-all.sh` after touching any of them. Change record: `~/.config/pstack/audit/harness-2026-09-12.md`. Related: [[flag-project-model-pins-before-spending]].
