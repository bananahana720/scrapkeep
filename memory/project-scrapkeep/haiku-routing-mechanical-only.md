---
name: haiku-routing-mechanical-only
description: "Andrew's 2026-10-13 ruling after the 19-unit Haiku swarm trial — Haiku writes only mechanical units; cross-file work goes to Sonnet writers since Codex retired"
metadata:
  node_type: memory
  type: feedback
  originSessionId: cabb58e4-73c1-4c8c-adc7-200746caa4da
  modified: 2026-10-13T23:17:50.388Z
---

Haiku writer + verifier + Opus gate pipeline only for mechanical units: record tables, single-file fixes, units whose files and pattern the block names. Cross-file or design units go to Sonnet 5.5 writers per AGENTS.md (Codex retired 2026-10-17; this line originally said Codex Sol). Haiku scouts stay for readiness triage, but the coordinator spot-checks their "mechanical" calls (a scout misfiled SQ8, a 200-bot-run tuning unit). Opus gate unchanged.

**Why:** the trial (docs/project/haiku-swarm-trial-2026-10-12.md) admitted 6 of 19 Haiku units inside the pipeline, under its 35% line; every win was a record table or one-file fix. Failures were cross-file seams, tests that pass by construction, reports filed before the smoke finished, and uncommitted fix rounds. Andrew chose this routing in task #7.

**How to apply:** when dispatching wave units, classify first; mechanical → `w13-haiku-wave.js` workflow, everything else → a Sonnet `scrapkeep-writer` (the Codex lane retired 2026-10-17). Reverse only if five consecutive cross-file Haiku units admit with a clean merge check. Related: [[codex-image-boards]], AGENTS.md model pins.
