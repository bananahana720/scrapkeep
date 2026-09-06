# Cohesion review contract

Review this edition as one creative reference. The user requires an independent reviewer to check every image against Art Direction, identify the violated rule, request one regeneration where needed, and list persistent outliers. The same review checks every section against the three pillars and the other sections. Do not replace the user's design with a new one.

## Inputs

- `BIBLE.md`, reading its body before Appendix A to avoid repeated prompt text.
- `docs/bible/ART-DIRECTION-LOCK.md`, the approved style text.
- `docs/bible/production/assets.json`, the image and prompt inventory.
- `docs/bible/production/section-*-decisions.md`, the workers' unresolved choices.
- Current accepted source docs only when a specific claimed rule needs confirmation.

## Image coverage

Inspect every actual full image with the image viewer. Do not substitute filenames, captions or worker self-reviews for looking. For each image record its ID, inspected path, verdict, any violated AD rule, precise observation and required correction. Label minor rendering limits separately from contradictions. Typography that prevents the requested A/B/C, map or HUD comparison is actionable. Do/don't negative panels are intentional exceptions only to their named rule; check labeling and positive panels carefully.

A key-art or establishing image can use an appropriate conceptual viewpoint. Gameplay mockups must communicate the approved close third-person view, readable danger and cockpit/mech identity. Do not require every distant panorama to reveal internal fabrication or a pilot face. Apply scene-relevant rules rather than demanding every image illustrate all systems.

Ask for one targeted regeneration only when a visible issue violates a rule or misses the requested deliverable. Ordinary taste differences and unresolved character A/B/C selection are not violations. Do not regenerate yourself. The coordinator issues exactly one correction attempt for each flagged image and returns it for reinspection. Reinspection records corrected or persistent issues; no third generation.

## Text coverage

Record coverage for all nine sections. Test the three named pillars: Joyful physical mastery; Scrap becomes your build; A world worth crossing. Check names, species and civilizations across sections; four-world runs versus the candidate catalogue; weapon plus three skills; eight endpoints per slot; milestone access; respec versus item reconfiguration; optional transformations and earned dominance; one main companion; standard revival and completed-level saves; permanent options versus rebuilt combat power; and conditional animal roster status.

Do not ask the coordinator to invent final prices, recipes, production-engine selection, a fixed route order or a final boss. These are explicitly open where prior planning did not settle them. Find contradictions, accidental approvals and material omissions. State uncertainty plainly. Flag a source gap as a gap, not as an implementation bug.

## Report

Return a compact image-review table covering all 25 initial images and a section-review table covering all nine sections. Each actionable issue needs an exact image ID or text section/line and the specific violated rule or pillar. Separate text corrections the coordinator can make from choices that belong to Andrew. The coordinator owns the final `COHESION_REPORT.md` and `BIBLE_DECISIONS.md`.

The evidence is concept inspection and document/source review. Do not claim tested fun, balance, controller handling, physics, real geometry, audio, runtime performance or shipped content.
