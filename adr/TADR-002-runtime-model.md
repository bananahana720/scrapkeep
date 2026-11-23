# TADR-002. Runtime ownership and composition

Status: **Accepted engineering direction.** Andrew treated the architecture as settled and approved execution preparation on 6 September 2026. This is not authorization to build.

Date: 6 September 2026. Depends on [TADR-001](TADR-001-engine-language-platforms.md).

## Context

[A committed attack means what it shows](../BIBLE.md#a-committed-attack-means-what-it-shows) requires damage and presentation to consume authoritative geometry. Chaos outcomes resolve once. [The implementation handoff](../BIBLE.md#architecture-and-implementation-handoff) distinguishes encounter simulation, run state, permanent progression and rendering. [Equipment and transformations](../BIBLE.md#inventory-equipment-and-transformations) requires removing old effects when selections change.

The current simulation boundary (`../docs/adr/0002-simulation-boundary.md`) and attack geometry ADR (`../docs/adr/0003-authoritative-attack-geometry.md`) already establish useful ownership. Source inspection found frame accumulation in both `main.js` and `simulation.js`; it did not demonstrate a runtime failure. Production must choose one timing owner instead of inheriting both layers.

## Options

| Option | Disposition | Reason |
| --- | --- | --- |
| Hybrid of engine scene composition and explicitly owned typed gameplay records/controllers | **Recommended** | Uses Godot's physical world while keeping run lifetime, mutation and ordering explicit. |
| General ECS framework for all gameplay and presentation | **Rejected for this baseline** | Adds entity storage, scheduling and authoring conventions before measured scale requires them. Local data-oriented collections remain available if profiling later justifies them. |
| Object hierarchy with autonomous actor callbacks and inherited gameplay behavior | **Rejected for this baseline** | Spreads mutation and update authority across scene lifetimes, animation and signal order. The scene hierarchy may organize composition without becoming the gameplay ownership model. |
| Engine-independent C# simulation driving thin Godot adapters | **Rejected for this baseline** | Provides a portable test boundary at the cost of another toolchain and physical-world translation. TADR-001 accepts an engine-hosted runtime. |

## Decision

Recommend a **hybrid within Godot**. Typed GDScript objects hold explicit encounter/run/profile records. Small composed controllers operate on owned records. Godot nodes provide scene lifetime, physical bodies, views and interaction surfaces. Do not introduce a general ECS, global gameplay event bus or deep class-specific inheritance hierarchy at the outset.

One application/session owner holds run continuity and the permanent profile and supplies services explicitly. An encounter is replaceable; unloading its scene cannot discard the run. One encounter coordinator advances authoritative gameplay in a fixed physics callback. Actor callbacks cannot independently advance combat. Rendering interpolates published results and never advances gameplay. Tick rate, detailed update order and overload policy belong to later Runtime Patterns and Constraints work. Godot provides a [physics-synchronized main loop](https://docs.godotengine.org/en/4.7/tutorials/scripting/scene_tree.html); this ADR supplies the project's ownership rule.

Gameplay may use engine math and physics types. One collision-query owner controls movement resolution, queries and contact interpretation. The encounter commits resolved state and outcomes. Query ordering and the collision world's synchronized state must be explicit so that visual interpolation cannot become another authority. This is an engine-native simulation, not an engine-free library or a custom physics engine.

Aim previews are provisional. At commitment, the encounter revalidates the current state and resolves the attack once. The resulting geometry, targets and random outcome drive damage and emitted presentation data. Committed enemy windups preserve their declared geometry contract. Cosmetic scrap, animations and effects cannot choose targets, advance progression or reroll loot, offers or miscasts.

Signals may report committed results through scoped connections. They cannot form hidden chains of gameplay mutations. The session permits equipment changes between fights and tree respec only at an authorized opportunity, then rebuilds effective effects from selections.

Input release, prepared-action cancellation and solo pause are distinct operations. Focus loss or a modal transition clears held physical input and explicitly cancels uncommitted prepared actions through the simulation boundary. Resume cannot manufacture a cast. This preserves the current input/dashboard contract (`../docs/adr/0005-caster-input-and-dashboard.md`).

## Consequences

Rules can be exercised without rendered scenes, but their test host remains Godot. Physics scenarios need controlled engine worlds. The engine's [headless command-line facilities](https://docs.godotengine.org/en/4.7/tutorials/editor/command_line_tutorial.html) provide a possible test host, not proof of project correctness. Actual graphics and controller feel require separate evidence.

Explicit commands and seeded randomness help diagnosis but do not establish cross-platform determinism or future network compatibility. [TADR-005](TADR-005-networking-scope.md) accepts that limitation. Authored definitions follow [TADR-003](TADR-003-content-pipeline.md); durable projections follow [TADR-004](TADR-004-persistence.md).

Engine binding is deliberate. Explicit ownership makes behavior traceable but does not make a future engine replacement cheap. Keep shared definition Resources unchanged and mutable session state separate.

## Later qualification and reconsideration

Qualify a single owned tick, pause/resume, scene replacement without lost run state, effect removal, one obstructed attack and one harmful miscast resolved once. Test collision-query ordering, coordinate conversion and contact interpretation against real controlled engine worlds. Measure entity/geometry scale before adopting ECS storage or parallel gameplay scheduling. A change in mutation or timing authority requires revisiting this ADR.
