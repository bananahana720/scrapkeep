---
name: jev-lab-close-and-game-dev-start
description: Jev Lab program closed 2026-09-26; game dev has since started on sketches/core-loop, and this keeps the lab's still-open loose ends (EV-0573, EV-0575, the Cable Bench tunneling finding)
metadata:
  node_type: memory
  type: project
  originSessionId: f878c283-77eb-4b3b-935e-06b499d5e735
  modified: 2026-09-26T01:42:19.103Z
---

**Update 2026-09-28:** game dev started on 2026-09-26 in the Godot sketch `sketches/core-loop` (core-loop v2, then the v3 loop redesign; see [[fun-gate-before-alpha]] and [[scrapkeep-design-principles]]). The start points below are no longer the plan. What stays open is the lab's loose ends: EV-0573, EV-0575, and the Cable Bench tunneling finding, which may or may not apply to the core-loop sketch.

The Jev Lab program closed on 2026-09-26 (TRACKING EV-0576 onward; retro at `artifacts/jev-lab-2026-09-25/RETRO.md`). Andrew asked that the next session move to actual game-dev items, using the lab harness as the test environment.

Start points for game dev:
- `artifacts/jev-lab-2026-09-25/experiments/arms/FINDINGS.md`: 21 gameplay findings across ball-lab, Cable Bench and Spillway, each with a Try line. The top one is a real bug: on Cable Bench rigid, the ball tunnels through the ground near x −34 and the stage still credits a clear.
- Parked idea, EV-0573: an endless or goal mode for the watch view, per-event sounds, and a decision-tree view (branch = replay the kinematic prefix, then force option i). Cards are needed before any work.
- Post-close tooling follow-ups, EV-0575: `program.mjs` stops counting at JL-20; `coverage-gap.mjs` calls Jev by default with no dry-run; some evidence was never retained; `jev:score` still defaults to q1.

**Why:** Andrew wants game-dev work next, and recording is his stated failure point, so the next session should not have to rediscover these.
**How to apply:** At a Scrapkeep game-dev start, read FINDINGS.md "Try first" and EV-0573 before proposing work. State at close: main d0bea4d, pushed to origin 2026-09-26; all wt/JL-* worktrees removed and merged branches deleted; wt/JL-30x (unmerged pillar-sprint skill-exercise scenario) kept as a possible game-dev start; JL-28 run records moved to the main checkout at artifacts/local/tasks/JL-28/. The push and the cleanup are not on the board (no event after EV-0577). Related: [[flag-project-model-pins-before-spending]].
