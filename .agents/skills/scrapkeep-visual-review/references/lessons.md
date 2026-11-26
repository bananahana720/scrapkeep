# Visual Review Lessons Ledger

Each lesson captures a visual verification or Gemini multimodal workflow rule for Scrapkeep.

## Lessons

- **SVR-01** · status: provisional · since: 2026-11-25 · origin: verify-game & verify-build multimodal proof standard
  Always inspect rendered screenshots directly with `read_file` before claiming a visual pass; step exit codes and log lines prove execution, not what the player actually sees.
  Evidence: `.agents/skills/scrapkeep-verify-game/SKILL.md`; `.agents/skills/scrapkeep-verify-build/SKILL.md`.
  Overturned by: —

- **SVR-02** · status: provisional · since: 2026-11-25 · origin: ruling cx & UI audit workflow
  Audit every player-facing UI or text change against `sketches/core-loop/design-v3/LEGIBILITY.md` section 13 pattern codes and record new defects in `project-guide/handoff/UI-FINDINGS.tsv`.
  Evidence: `AGENTS.md` Rule 8 (`ruling cx`); `project-guide/handoff/START-HERE.md`.
  Overturned by: —

- **SVR-03** · status: provisional · since: 2026-11-25 · origin: red-team player's-eye blindness boundary
  Enforce strict context isolation in `.agents/skills/scrapkeep-visual-review/scripts/eye_read_workflow.py`: the cold Reader reads only `<eye_dir>/reader/BRIEF.md` and the reader frames, never `film.ndjson` or `<eye_dir>/judge/SHEET.md`.
  Evidence: `scripts/redteam/eye.mjs` (`<out>/film/`, `<out>/reader/`, `<out>/judge/` separation); `scripts/redteam/README.md`.
  Overturned by: —

- **SVR-04** · status: provisional · since: 2026-11-25 · origin: multi-angle reference sheet scale drift
  Keep the 1.84 m Hoberman-lattice player ball in every orthographic panel and use plain machine-part nouns when generating reference sheets with Gemini or `image-generator`.
  Evidence: `tools/refsheets/README.md` (16-unit batch scale drift fix and word filter rule).
  Overturned by: —

## Changelog

| Date | Change type | Ids touched | Evidence or commit | Reviewer |
| --- | --- | --- | --- | --- |
| 2026-11-25 | new lesson | SVR-01, SVR-02, SVR-03, SVR-04 | Initial Antigravity uplift (`scrapkeep-visual-review`) | pending |
