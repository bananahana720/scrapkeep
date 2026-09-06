# 0004: Keep prototype models separate from concept art

Date: 2026-09-05. Status: accepted for the first proof, recorded retrospectively.

## Context and decision

The first build must demonstrate an enclosed animal, rolling scrap and believable tool motion. Author lightweight models and articulation in Three.js source. Use locally packaged fonts and synthesized sound. Generated raster concepts guide direction but are not meshes, rigs, animation clips or gameplay screenshots.

## Consequences and revisit trigger

Procedural models make geometry and motion directly inspectable but require manual maintenance. They do not establish production art quality or device performance. Revisit when an imported-asset increment is approved. Record source, license/provenance, units, axes, collision scale, material/animation expectations and measured cost for each admitted asset.

Evidence: [models](../../src/orchard/models.js), [concept study](../CONCEPT-STUDY-03.md), [asset inventory](../project/ASSETS.md), [first-build visual evidence](../FIRST-BUILD-VERIFICATION.md).
