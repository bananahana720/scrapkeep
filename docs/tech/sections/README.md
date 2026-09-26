# Engineering handoff sections

## Sources

[Task definitions](../../../BACKLOG.md) own the section contracts. [TRACKING](../../../TRACKING.md) owns authorization and execution state.

## Contract

Coordinator-owned index. Section documents are admitted independently and do not constitute the assembled TECH_BIBLE.

Square-one review status (TRACKING EV-0480). Andrew's direction moved from compact levels to open momentum stages. The process lens classified each section against that direction. **Changes:** TH-01, TH-02, TH-05, TH-09, TH-10, TH-11, TH-15, HF-06a, HF-06b and HF-07b assume compact levels, waves, arena-seeded pickups or secret rooms. **Parked:** TH-06 and TH-14 encode the level shape that Q-P23 has not decided. Every other section survives unchanged. These are review labels, not amendments; each section stays admitted as written until a heavy-lane card changes it.

Superseded direction (DF-03). [TADR-010](../../../adr/TADR-010-open-stages-and-event-director.md) makes the open stage the run's level unit and replaces the wave grammar with an event director. It decides the level shape that parked TH-06 and TH-14; the generation technique stays with [Q-P23](../../../BACKLOG.md#q-p23). The section bodies are not edited and their stated hashes stay valid. Where a section says "level" or "compact encounter level", read "stage". Line numbers are at each section's current bytes.

- **TH-06.** Superseded: the Level row of [the four scales](TH-06-encounters-waves-and-enemies.md#four-scales-and-what-each-owns) (line 41) and the Wave row's standing as the level's grammar (line 40), because a wave is now one spawn event the director composes; [schedule positions](TH-06-encounters-waves-and-enemies.md#encounter-schedule-positions) EW-1 to EW-4 (lines 165 to 168), which model a stage as a cycle of waves; ET-01 (line 313), which TADR-010's three kinds of stage content replace; and UN-04 (line 118) and ET-04 (line 316), where a miniboss may now arrive at a varied location and wave counts become event counts, both still unset. Remains: the objective rules OB-01 to OB-09 (lines 60 to 68), including completion read from objective state; arrival rules AV-01 to AV-06 (lines 76 to 81), which now apply to every director spawn; attack admission AM-01 to AM-07 (lines 89 to 95) under [Q-E10](../../../BACKLOG.md#q-e10); recovery RC-01 to RC-05; inputs UN-01 to UN-03, UN-05 and UN-06; the prototype evidence table (lines 128 to 137); the Q-E10 and Q-P38 separation (lines 143 to 154); positions EW-0, EW-5 and EW-6; the carried state, interfaces, ordering rules EO-01 to EO-16 (EO-07's "stages nothing" now covers every event boundary, and EO-15 is TADR-010's no-clock rule), edge cases (EE-04, a stage with no wave, becomes the ordinary case), failure modes and every other tunable row. Director state enters `EncounterState` by a later revision.
- **TH-11.** Superseded: only the reading of "level" as a compact encounter level, in [level and world identities](TH-11-runs-regions-exits-and-saves.md#level-and-world-identities) ID-05 (line 42), RX-01 (line 55) and [run positions](TH-11-runs-regions-exits-and-saves.md#run-positions) RN-2 and RN-3 (lines 117 and 118). RN-2 is left when the stage's exit is taken, and what the exit requires stays with [Q-P38](../../../BACKLOG.md#q-p38). RP-22 (line 281) reads secrets as director discoveries or authored stage content, still unset, and line 143's level-interior state now includes director and event state, still with no durable projection. Remains: everything else, including the identities, the exit and world-choice split RX-01 to RX-09, offer stability RS-01 to RS-05, the route policy RT-01 to RT-04, the save lifecycle, RO-01 to RO-14, RE-01 to RE-14, RF-01 to RF-10, and RP-09 (line 267) and RP-21 (line 280) as open stages-per-world and technique rows.
- **TH-14.** Superseded: the claim that [four random responsibilities](TH-14-randomness-generation.md#four-independent-random-responsibilities) are the complete set, at GR-01 to GR-04 (lines 48 to 51), GI-09 (line 65), GP-01 and GP-02 (lines 254 and 255) and GP-04 (line 257). TADR-010 adds a fifth, the event director, on its own encounter-scoped, non-durable stream in `EncounterRandomState`; GI-01 (line 57) makes that a later revision of the table. Remains: every other rule. The durable streams stay route and layout (GS-04 and GP-03, lines 75 and 256), and [the level-generation request](TH-14-randomness-generation.md#the-level-generation-request) (lines 86 to 104) reads as the stage-generation request, still issued before the stage is entered, with the technique still open (GG-06, GP-09).

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
- [TH-07: Four slots and milestone progression](TH-07-four-slots-and-milestone-progression.md).
- [TH-08: Inventory, equipment and transformations](TH-08-inventory-equipment-and-transformations.md).
- [TH-09: Themed loot, attunement and fixed secrets](TH-09-themed-loot-attunement-and-fixed-secrets.md).
- [TH-10: Devices and one main companion](TH-10-devices-and-one-main-companion.md).
- [TH-11: Runs, regions, exits and saves](TH-11-runs-regions-exits-and-saves.md).
- [TH-12: HUD, dashboard and settings](TH-12-hud-dashboard-and-settings.md).
- [TH-13: Chaos outcome commitment](TH-13-chaos-outcomes.md).
- [TH-14: Randomness and generated-level interfaces](TH-14-randomness-generation.md).
- [TH-15: Collision queries and physical-world qualification](TH-15-physics-query-contract.md).
- [TH-16: Rendering and effect integration](TH-16-rendering-integration.md).
- [TH-18: Input-device and focus integration](TH-18-input-integration.md).
- [TH-19: Source-asset import and export admission](TH-19-asset-import-export.md).

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
