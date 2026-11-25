---
trigger: model_decision
description: "Apply when creating, reviewing, or auditing Scrapkeep art, 3D assets, reference sheets, UI screens, player's-eye films, VFX, audio, or narrative tone."
---

# Creative, Visual & Tone Rules

- **Read story and tone first**: Open [STORY-MAP.md](../../sketches/core-loop/design-v3/STORY-MAP.md) and [TONE-BIBLE.md](../../project-guide/handoff/shared/tone/TONE-BIBLE.md) before authoring or judging design, art, writing, or sound.
- **Art and sight references**: Check [ART-MISTAKES.md](../../project-guide/handoff/ART-MISTAKES.md) and [SIGHT-PERSONA.md](../../sketches/core-loop/design-v3/SIGHT-PERSONA.md) before 3D modelling, asset review, or camera/readability judgements.
- **Visual inspection discipline**: Activate `scrapkeep-visual-review` for UI legibility audits (`LEGIBILITY.md` §13), blind player's-eye film reads (`scripts/redteam/eye.mjs`), and Gemini reference sheets (`image-generator` / `gemini-api-cli` with the 1.84 m scale ball in every orthographic panel). Always inspect rendered PNGs/JPGs directly via `read_file` before claiming a visual pass.
- **Blockout geometry**: Activate `scrapkeep-blockout` for mojulo recipes, glb exports, and ball proofs; use `blender_blender` MCP for viewport inspection and Cycles stills.
