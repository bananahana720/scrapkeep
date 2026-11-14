---
name: flag-project-model-pins-before-spending
description: Andrew wants a project's stricter model pins surfaced against his pstack tier map before delegates are spawned, not followed silently.
metadata:
  type: feedback
---

On 2026-09-12 Andrew stopped a Scrapkeep sprint run mid-way because every delegate had run on Fable high: the project's `.claude/agents/scrapkeep-*` definitions and ORCHESTRATOR pinned Fable, and the runtime contract says to honor project pins, so I followed them without saying so. He called that use "off" and approved a remap to the three-tier map (Opus 5 high writers, Sonnet 5 lookups, Fable medium consequential review).

**Why:** The pins predated his 2026-09-12 routing change and nobody had reconciled them. Silent compliance cost roughly three times the intended spend across eleven spawns before he noticed.

**How to apply:** At the first spawn in any project, compare the project's pinned model and effort against `/home/andrew/.config/pstack/models/claude.md`. If they differ, say so in one line with the proposed remap and ask before the first delegate runs. Treat "honor project pins" as "surface the conflict", not "hide it". Related: [[scrapkeep-coordination]].
