---
trigger: glob
globs: "**/sketches/core-loop/**/*.gd, **/sketches/core-loop/**/*.tscn, **/sketches/core-loop/**/*.tres, **/sketches/core-loop/project.godot"
description: "Rules for editing the Godot 4.7.2 alpha game under sketches/core-loop/."
---

# Godot Core-Loop Rules

- **Architecture & modularity**: Follow [DEEP-SWEEP.md](../../project-guide/handoff/DEEP-SWEEP.md) — keep new behaviour inside the state-owning module behind a small caller interface.
- **Player-facing text & UI**: Check [LEGIBILITY.md](../../sketches/core-loop/design-v3/LEGIBILITY.md) section 13 before adding or changing player-facing words, prompts, or navigation (ruling `cx`: position, shape, colour, icon, motion, or sound before text).
- **World 1 maps, difficulty & handovers**: Read the matching audit under `project-guide/handoff/shared/world1/` first (rulings `ct`, `cu`, `cv`). Tune difficulty harder only on slowed/stopped balls; never stop a rolling/turning ball.
- **Verification**: Qualify changes with focused Godot tests and `npm run sketch:fast -- --base <stage>` (never substitute browser tests), after `node scripts/import-stamp.mjs import` for lab/band reads. Isolate saves under `artifacts/local/` (`XDG_DATA_HOME` on Linux, `HOME` on macOS per [DEVICES.md](../../project-guide/handoff/DEVICES.md); live saves and `McpBridge` commit guards are enforced by `.agents/hooks/safety-gate.mjs`).
