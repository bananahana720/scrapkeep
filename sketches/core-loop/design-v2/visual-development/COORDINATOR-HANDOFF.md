# Visual-development handoff to the core-loop v2 coordinator

The isolated presentation candidate is on `codex/visual-development` in `/home/andrew/Projects/scrapkeep/artifacts/local/visual-development/workspace`. Final gameplay/presentation code is `ba7da85b5df564e1f84cc050f0782a07eebd7ac0` on your supplied base `6a6ef840a14b286a8cdb3e6f70ef3804003dd0ab`. Later evidence-only commits do not change this code identity. No sibling branch or W8 update was merged.

## Alignment findings addressed

- `hero_assets.gd` attaches the existing Warden clamp and Reactor/Hive/Mind kits. Fixed weak points, collision and gameplay state remain authoritative. The hook retains dynamic cues, fits warning ribbons to jaw surfaces, prewarms their immutable geometry, and restores placeholders on teardown.
- Stage-2 lesson caps in `src/combat/warden_look.gd` are shallow hexagonal brood membranes with enamel rims and elevated open hex markers. The domes and heat plumes are gone; cap hit positions, multipliers and flash behavior remain unchanged.
- Native review found the beacon mast inside the fixed family targets. The hero hook reversibly replaces only the intersecting visual band with open supports while the real Warden lives; it restores the original mast afterward. No `beacon.gd` or world-source edit was needed.
- The Hive GLB's rubber front hatch now hinges open with the existing queen window. It no longer hides the glowing target while damage is allowed.
- `Palette.ANCIENT` is defined as `Color("3d8bff")`; hero materials use it. Please replace your remaining five literals: roster, map_gorge, contraptions, and event_kinds twice. The top speed tier is warm white; aim reach is bone and magnetic assist is mint, preserving shared meaning across classes.

## File seams

Runtime changes relative to the supplied base are `src/core/palette.gd`, `src/game.gd`, `src/movement/{aim_style,speed_tier}.gd`, `src/presentation/{hero_assets,spillway_scenery}.gd`, `src/world/{terrain,contraptions}.gd`, and the newly authorized `src/combat/warden_look.gd`. The candidate also carries shell GLBs/builders, focused tests, capture tooling and isolated visual-development notes.

Terrain text before `_build_sky` is byte-identical to your refreshed base. The scenery hook follows world-module creation in `_ready`; preserve W8's workshop-ready and menu-held input hooks. Contraptions changes share seven immutable material variants per owner; dynamic callers still receive fresh `Palette.solid` resources. Canonical design records, contracts, tracking and playtest log remain yours. Please fold the brood-cell appearance correction into the old plume description when integrating.

## Evidence and limits

The pre-Warden baseline passed all 165 sketch-smoke checks. Later affected hero, Warden-family and combat-lesson tests passed; the final hatch revision reran both affected hero tests. Final code has not rerun the entire suite. Headless results establish behavior, not native feel.

Native inspection covers all three kits at four angles, plus final open/closed Hive states, actual 1920×1080 on RTX 4080. The open support clears the 1.3 m hit sphere by at least 0.14 m. These short captures are ineligible for FPS qualification.

The gorge material count falls from 227 to 173 with 374 meshes and 57 colliders unchanged. The earlier 120-second grown dense run passed 14.223 ms p99; the after-change run was interrupted, and another session continued occupying 100% GPU. No final performance gain or target pass is claimed. The remaining native gate is 120-second traversal, grown dense combat and boss coverage on the final code under a controlled load.

This candidate is ready for coordinator review of these bounded fixes and Andrew's playtest. It is not a declaration that the complete visual plan or Style A fidelity is finished. See [integrated evidence](INTEGRATED-VERIFICATION.md) and [remaining fidelity work](FIDELITY-GAPS.md).
