# Contraption material reuse VD-03-A1

> **Historical single-unit receipt:** Contraption material reuse (`cf2363e`); live contract ownership is in [CONTRACTS.md](CONTRACTS.md).

Contraptions now allocate seven solid materials per owner: sand, charcoal, rust, copper, and amber emitting at 0.6, 0.8 and 1.2. Existing gauge and needle materials supply sand and charcoal. Matching static prop surfaces reuse these resources. The resources are treated as immutable after setup; each owner receives its own set. The existing striped and unshaded materials remain unchanged.

Palette.solid still returns a new resource. Enemy flashes, surge gates, boss magnets, fabricator readiness and melting ice retain their independent mutable resources. No global cache, arbitrary-color registry or lifetime policy is introduced.

The production diff only adds material fields/setup allocations and replaces matching Palette.solid expressions with their corresponding fields. No geometry, collision, transforms, animation, timers, colors or emission values change.

## Focused verification

Run `tests/contraptions_materials_test.gd` headless under the core-loop project. It checks matching material identity, seven distinct variants, owner isolation, fresh mutable material isolation, authored material attributes and stage/arena lifecycle. Two owners follow the same 4.5-second sequence exercising barges, lifts, gauges and a valve opening, then reset. Mesh and collision geometry, transforms, masks, visibility and material attributes are compared.

For a baseline comparison, extract the original contraptions.gd from commit cf2363e31ffe9864262297d1c6d98711d70ff9cd to an evidence path and pass `-- --reference=/absolute/path/contraptions-baseline.gd`. The reference owner then runs the original allocation implementation while the candidate owner runs the changed script. Without that argument both owners run the candidate. No physics-contact solver or human-feel claim follows from these structural and scripted-state checks.

Native before/after measurements and visual acceptance remain parent-owned. Fewer material resources alone does not establish fewer draw calls or faster frames.
