# 0003: Share committed attack geometry

Date: 2026-09-05. Status: accepted, recorded retrospectively.

## Context and decision

Players need the announced path and the damaging tool to agree. Attack preparation locks aim and position. The simulation provides world-space capsules for the damaging stroke and sampled preview capsules for its complete motion. The renderer displays these values, and articulated models follow the same tool dimensions and phase.

## Consequences and revisit trigger

An art change to blade reach or foot placement can change combat. Verify geometry and gameplay together. A larger enemy can repeat learned mechanics because its tool family retains the same visual logic. The current representation is intentionally simple; new tools may need another shape. Preserve one authoritative geometry definition when extending it.

Evidence: [tool paths and transitions](../../src/orchard/simulation.js), [hazard renderer](../../src/orchard/scene.js), [model checks](../../tests/orchard-models.mjs), [renderer regressions](../../tests/orchard-renderer.test.js).
