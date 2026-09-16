# Engineering handoff sections

## Sources

[Task definitions](../../../BACKLOG.md) own the section contracts. [TRACKING](../../../TRACKING.md) owns authorization and execution state.

## Contract

Coordinator-owned index. Section documents are admitted independently and do not constitute the assembled TECH_BIBLE.

- [HF-01: Production paths and contribution conventions](HF-01-production-conventions.md).
- [HF-02: Constraints and evidence register](HF-02-constraints-evidence.md).
- [HF-03a: Module ownership and owned records](HF-03a-module-map.md).
- [HF-03b: Dependency edges and interface walkthroughs](HF-03b-dependency-graph.md).
- [HF-04a: Fixed tick, pause and encounter lifecycle](HF-04a-runtime-lifecycle.md).
- [HF-04b: Runtime patterns and typed sketches](HF-04b-runtime-patterns.md).
- [HF-05: Stable content identity and admission](HF-05-content-admission.md).
- [HF-06a: Authored content inventory and treatment](HF-06a-schema-inventory.md) with its [CSV copy](HF-06a-schema-inventory.csv).
- [HF-06b: Matrix rows mapped to persistence projections](HF-06b-persistence-projection.md) with its [CSV copy](HF-06b-persistence-projection.csv).
- [HF-07a: Save envelope and preferences record](HF-07a-save-envelope.md) with its [CSV copy](HF-07a-save-envelope.csv).
- [HF-07b: Durable commit boundaries](HF-07b-commit-boundaries.md).
- [HF-08: Save failure and conservative recovery](HF-08-save-recovery.md).
- [HF-09: Schema and gameplay-content migration](HF-09-schema-migration.md).
- [TH-01: The complete run loop](TH-01-complete-loop.md).
- [TH-02: Movement, camera and active aim](TH-02-movement-camera-and-active-aim.md).
- [TH-03: A committed attack means what it shows](TH-03-a-committed-attack-means-what-it-shows.md).
- [TH-04: Abilities, ultimates and combat rhythm](TH-04-abilities-ultimates-and-combat-rhythm.md).
- [TH-05: Electromagnetic collection, recycling and growth](TH-05-electromagnetic-collection-recycling-and-growth.md).
- [TH-06: Encounters, waves and enemies](TH-06-encounters-waves-and-enemies.md).
- [TH-08: Inventory, equipment and transformations](TH-08-inventory-equipment-and-transformations.md).
- [TH-11: Runs, regions, exits and saves](TH-11-runs-regions-exits-and-saves.md).

## Scenarios

Use the exact card and admitted dependency sections before drafting a section. A missing section is not an implemented contract.

## Unresolved questions

See the [question register](../../../BACKLOG.md#q-e03).

## Re-verification triggers

Update this index when a section is admitted or its authoritative location changes.

## Procedure performed

Created the shared directory before the first pair of file-level writer leases.

## Evidence limits

This index establishes no runtime behavior, hardware qualification or gameplay approval.
