# Artifacts

Disposable evidence and scratch outputs live under `artifacts/local/` (gitignored).

- `artifacts/local/` holds disposable receipts, stills, test logs and builds from local commands (`npm run check:docs`, `npm run verify`, `scrapkeep-verify-game`, `scrapkeep-verify-build`, `scrapkeep-verify-web`). Do not commit files under `artifacts/local/`.
- `artifacts/mojulo-lab/` holds live mojulo blockout helpers (`inputs/ball_proof.gd`, `inputs/geomhash.py`, `local/C/hero_stills.py`) cited by `.agents/skills/scrapkeep-blockout/SKILL.md`.
- `artifacts/orchard-first-build/`, `artifacts/lightning-playtest/`, `artifacts/visual-iterations/` and root browser-proof files are preserved until Phase 2 browser-proof retirement; [First-build verification](../docs/FIRST-BUILD-VERIFICATION.md) owns the historical orchard proof record.
- Older September/October historical artifact bundles remain permanently in git history.
