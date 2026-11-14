---
name: workflow-agents-pin-model
description: "Every agent() call in a Workflow script must carry an explicit model; an unpinned agent inherits the main session's model, and after Andrew switched the main to Fable the doc agents all ran on Fable (2026-10-10)"
metadata:
  node_type: memory
  type: feedback
  originSessionId: f5d7ec2a-9e8b-47a6-95bf-2efe48b91870
  modified: 2026-10-11T00:30:49.580Z
---

Pin `model` on every `agent()` in a Workflow script (and `agentType` where a project definition fits). An `agent()` with neither inherits the main session's model. On 2026-10-10 the harmonize and round-2 brief workflows were written while the main ran on Opus; after the reboot the main came back on Fable 5.1, the resumed workflows' unpinned agents ran on Fable, and Andrew stopped it: "whoa whoa thats all fable agents!"

**Why:** Fable is the scarce tier (conductor budget, `models/claude.md`). Prose rewrites and brief checks are Sonnet work; critics and gates are Opus. A resume after a model switch silently re-tiers every unpinned agent.

**How to apply:** In every Workflow script, `model: 'sonnet'` for writers and mechanical edits, `model: 'opus'` for critics, verifiers and gates, `agentType: 'scrapkeep-reviewer'` only where Fable review is intended. Before resuming a workflow after the main's model changed, grep the script for `agent(` calls without `model`. Check actual models with `grep -o '"model":"[^"]*"' <workflows dir>/<run>/agent-*.jsonl | sort | uniq -c`. See [[worktree-isolated-session-writers]] for the other resume gotcha and [[flag-project-model-pins-before-spending]].
