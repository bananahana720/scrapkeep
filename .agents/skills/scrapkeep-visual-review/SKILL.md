---
name: scrapkeep-visual-review
description: "Review Scrapkeep screenshots, UI audits, player's-eye films, 3D renders, and art reference turnarounds with Gemini multimodal vision, Antigravity image generation, and Blender or Godot MCP tools. Use for visual QA, LEGIBILITY section 13 UI audits, blind player's-eye film reads, and generating Gemini art reference sheets; driving the game from step files stays in scrapkeep-verify-game, mojulo geometry recipes stay in scrapkeep-blockout, and check selection stays in scrapkeep-verify."
---

# Review Scrapkeep Visuals with Gemini & MCP

Resolve this skill directory through symlinks, then run `git -C <resolved-skill-directory> rev-parse --show-toplevel` to identify the repository root. Read `AGENTS.md`, `GEMINI.md`, and `project-guide/handoff/START-HERE.md`. Use root-relative source paths below. The linked Claude skill resolves to this same body.

This skill owns Gemini multimodal inspection of Scrapkeep screenshots, UI legibility audits, blind player's-eye red-team film reads, Blender/Godot render checks, and Gemini art reference sheet generation. Driving gameplay step files stays in `scrapkeep-verify-game`, mojulo blockouts stay in `scrapkeep-blockout`, and check selection stays in `scrapkeep-verify`.

## Procedure

1. Classify the task (UI legibility audit, player's-eye film read, live 3D/scene check, or art reference turnaround) and read `sketches/core-loop/design-v3/STORY-MAP.md` plus `sketches/core-loop/design-v3/TONE-BIBLE.md` before any creative judgement. (design choice)
2. Open every captured PNG or JPG directly with `read_file` for Gemini multimodal inspection; never infer a visual pass from step logs or exit codes alone. (SVR-01)
3. For HUD, cards, tips, menus, or prompts, run `npm run sketch:ui-audit` (when Godot is present) and audit against `sketches/core-loop/design-v3/LEGIBILITY.md` section 13 (ruling `cx`), `sketches/core-loop/design-v3/SIGHT-PERSONA.md`, and `project-guide/handoff/ART-MISTAKES.md`; log new defects in `project-guide/handoff/UI-FINDINGS.tsv` and add a mechanical guard in the same PR if a defect class appears twice. (SVR-02)
4. For player's-eye films from `scripts/redteam/eye.mjs`, run `scripts/eye_read_workflow.py` via `run_workflow` so the cold Reader inspects only `<eye_dir>/reader/` frames and `<eye_dir>/reader/BRIEF.md` (blind to `film.ndjson` and `<eye_dir>/judge/`), then a separate Judge compares against `<eye_dir>/judge/SHEET.md`. (SVR-03)
5. For multi-angle art reference turnarounds, follow [references/refsheets-gemini.md](references/refsheets-gemini.md) using `tools/refsheets/split.py` and Antigravity's `image-generator` subagent or `gemini-api-cli`, keeping the 1.84 m scale ball in every orthographic panel. (SVR-04)
6. For live scene inspection, call `blender_blender` (`render_viewport_to_path`, `get_objects_summary`) or `godot_godot` (`take_screenshot`, `get_ui_elements`, and always `stop_project` before committing). (design choice)

## Lessons and updates

[references/lessons.md](references/lessons.md) holds SVR-01 onward. Status is `established`, `provisional` or `retracted`. When a result overturns a lesson, retract it, fill `Overturned by`, change the rule line above in the same commit, and add a changelog row.

## Host adapter

- Antigravity: `/scrapkeep-visual-review`. Uses Gemini multimodal `read_file`, `run_workflow`, `image-generator`, `blender_blender`, and `godot_godot`.
- Claude Code: `/scrapkeep-visual-review`. Open images via `Read` and run `scripts/redteam/eye.mjs` manually.
