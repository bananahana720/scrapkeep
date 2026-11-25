---
trigger: glob
globs: "**/src/**/*.js, **/index.html, **/orchard.html, **/server/**/*.js, **/project-guide/handoff/sitting-kit/*, **/project-guide/handoff/sitting-kit/**/*"
description: "Rules for editing preserved browser proofs and the Sitting Kit page."
---

# Browser Proofs & Sitting Kit Rules

- **Separation from Godot**: `/` and `/orchard.html` are preserved browser proofs, not the current Godot direction. Keep them separate until consolidation is approved; their checks never qualify `sketches/core-loop/`.
- **Orchard layering**: Keep combat state in `src/orchard/simulation.js`, rendering in `src/orchard/scene.js`, procedural geometry in `src/orchard/models.js`, and input/UI in `src/orchard/main.js`. Damage and telegraphs must consume the same committed geometry.
- **Modern web practices**: Activate the `modern-web-guidance` skill before non-trivial HTML, CSS, or client-side DOM work.
- **Verification**: Run `npm run verify` and the browser checks in [CONTRIBUTING.md](../../CONTRIBUTING.md), plus `scrapkeep-verify-web` (Playwright + isolated ports + scratch verdicts file) to verify rendered UI behaviour.
