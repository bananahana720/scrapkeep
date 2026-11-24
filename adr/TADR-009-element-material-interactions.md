# TADR-009. Element and material interactions

Status: **Accepted engineering direction.** Andrew authorized the direction foundation on 26 September 2026 ([TRACKING](../TRACKING.md) EV-0579) and left its technical choices to the coordinator. This records decision D4. It is not authorization to build.

Date: 26 September 2026. Depends on [TADR-002](TADR-002-runtime-model.md), [TADR-003](TADR-003-content-pipeline.md) and [TADR-008](TADR-008-ability-contract.md). Line numbers cite files at commit `433a3f4`.

## Context

In playtest entry 4 (`../docs/playtests/PLAYTEST-LOG.md`) Andrew made the basin flood a core stage mechanic and asked for the player to turn events to advantage: "if there's water, then a person can freeze it" and "if there's I don't know lava then you could use water to to to make platforms for yourself if you had a character or the ability or an item to do that". The entry's next action is an ability-meets-material interaction on the flood as the first test.

The Bible has no element and material layer; the harmonization review (`../artifacts/bible-harmonization-2026-09-26/REVIEW.md`) marks it silent. It has the pieces. Fuse's emitter has "swappable working chambers" that "visibly support multiple elements and effects" ([BIBLE.md](../BIBLE.md#44-fuse-squirrel-itinerant-apprentice) line 354), and a Fuse mishap "might scorch an escape line or frost a mechanism" (line 350). No final element pool is selected (line 359). Water is Spillway Works' terrain, with basins whose level changes and currents whose "effect on handling remains undecided" ([Spillway Works](../BIBLE.md#spillway-works) lines 207 and 209). Lava appears nowhere in the Bible.

The Bible supplies the rule to extend. "Simulation resolves attack geometry once. Collision, previews, effects and damage use that result" ([BIBLE.md](../BIBLE.md#a-committed-attack-means-what-it-shows) line 493). The review's second "keep" item names this rule as the basis for the element layer. A change in water level "must announce the new ground and reachable exits before it becomes dangerous" (line 209). Broad ordinary routes stay usable, and "a required exit cannot depend on a rare drop" (line 177). Line 261 leaves traction penalties and weather-driven route changes unchosen. Line 481 refuses mandatory handling penalties.

The admitted contracts fix where a world change may happen. Only two things change the collision world. CollisionQueries drives body updates on the encounter's ordered request at P3, and the world is bound or released at the lifecycle boundaries (TH-15 (`../docs/tech/sections/TH-15-physics-query-contract.md`) line 78). P5 applies outcomes with no geometry change (line 63). A committed attack's descriptor feeds damage and presentation alike (TH-03 (`../docs/tech/sections/TH-03-a-committed-attack-means-what-it-shows.md`) line 136). An effect window lives in `EncounterState` in ticks, and none is durable (TH-04 (`../docs/tech/sections/TH-04-abilities-ultimates-and-combat-rhythm.md`) lines 111 to 118). Q-P24 owns which terrain-changing interactions enter production for a region, and Q-P13 owns the element pool ([BACKLOG](../BACKLOG.md#q-p24)).

## Options

| Option | Disposition | Reason |
| --- | --- | --- |
| One element × material table as a typed Resource, consulted by abilities and stage events, resolved once in the encounter tick; a created surface is shared geometry. | **Recommended** | One rule for every source, one place to read an interaction, and the Bible's resolve-once rule applied to materials. |
| Interactions written into each ability's code, for example a frost ability that checks for water. | **Rejected for this baseline** | Quick for a first test. It scatters one rule across every ability, gives stage events no way to share it, and is the content-in-actor-code option TADR-003 line 19 rejects. |
| Material-owned reactions: each water or lava body reacts to element signals with its own script and spawns its result. | **Rejected for this baseline** | Feels natural in a scene tree. It builds the hidden chain of gameplay mutations through signals that TADR-002 line 32 refuses, and a surface spawned by a callback can exist for rendering before collision, or the reverse. |
| A systemic simulation: temperature and heat fields, fluid flow, and reactions that propagate cell to cell. | **Rejected for this baseline** | Rich emergent play. It is unbounded before any pair is chosen, harder to read in a crowded fight (BIBLE line 54), and harder to qualify on rigid physics judged by rates (EV-0578, decision D1). The table can feed such rules later if measured need appears. |
| Presentation-only reactions: frost or rock effects drawn on the material with no collision. | **Rejected for this baseline** | Cheap. Andrew asked for platforms, and line 493 forbids decoration that grants what the resolved geometry does not support. |

## Decision

Adopt **one element × material interaction table**, authored as a typed Resource with a stable domain ID under TADR-003. Elements and materials are definitions with stable IDs. A row's key is one element ID and one material ID. Its value names a reviewed interaction behaviour and, where the interaction creates a surface, the surface definition it creates. A pair with no row does nothing; interactions are default-deny, as compatibility is (TH-10 line 92). Admission rejects a row that names a missing element, material or surface, and a duplicated key. This ADR fixes the table and its key. The interaction behaviours are proposed for the content coverage matrix TADR-003 line 45 requires, for example creating a surface or changing a material. No row is admitted by this ADR.

**Abilities and stage events consult the same table.** An ability carries an element by its definition (TADR-008). A stage event that brings an element or a material, such as a flood raising water or a weather event if content adds one, carries it by its definition too. Both commit through the encounter. Neither source has a private rule, and the event director that schedules stage events is DF-03's concurrent card.

**An interaction resolves once, in the simulation.** The material an element meets is the material the committed geometry touched. That is the same descriptor damage and presentation read (TH-03 line 136). The table lookup happens inside that single P4 resolution. It happens nowhere in presentation, in a callback or in a second pass. P5 records the result once in `EncounterState`, and P6 publishes it. The lookup itself is deterministic. If a future row ever needs chance, it uses the commitment's single draw (TH-03 line 138).

**A created surface is shared geometry.** Ice from water and rock from lava enter the collision world only through CollisionQueries at the next P3, on the encounter's ordered request (TH-15 lines 61 and 78). Collision, rendering and damage then read that one surface. Rendering draws the published surface and never creates one. A surface that goes away is removed the same way. Its lifetime is an effect window in ticks under TH-04 (lines 112 and 113). Like every window, it ends with the encounter (line 118). The run saves at a level entrance (BIBLE line 465), so no created surface is durable. This ordering, resolve at P4, record at P5, enter the world at the next P3, is this ADR's reading of TH-15 lines 61 to 64. It adds no phase.

**A created surface obeys the route rules.** A surface that changes the ground is announced before it becomes dangerous, as line 209 requires of a changing water level. This extends that rule to created surfaces by inference. A required exit never depends on an interaction the build may lack, per line 177. A surface created by an event rather than by the player cannot impose a handling change the player did not choose (line 481).

The table below shows example entries. They are candidates, not content.

| Element (candidate) | Material (candidate) | Result (candidate) | Source |
| --- | --- | --- | --- |
| Cold or frost | Water | An ice surface the ball can stand on | Entry 4 ("freeze it"); BIBLE line 350 ("frost a mechanism") |
| Water | Lava | A rock platform | Entry 4 ("make platforms"); lava is absent from the Bible |

The first test is the Spillway flood, as entry 4 names. One element-carrying ability freezes flood water into a surface, and collision, rendering and damage agree on it.

## Consequences

Level authoring gains a duty. Every surface and volume an element can meet carries a material ID. A world without material IDs has no interactions, which is a safe default and an authoring cost.

Created surfaces add dynamic bodies to the rigid world. A surface can form under or around the ball, so overlap at creation needs a rule before content ships. The cost of a surface's body under Jolt is unmeasured.

The same table serves the player and the stage. A flood that meets a frozen surface, or a weather event that freezes water if content adds one, would use the rows an ability uses. Enemies as element sources would use them too, if content ever adds them.

Adding a pair is a definition edit. Adding a new kind of result is a reviewed behaviour and a code change. The table is small and inspectable; interactions do not cascade unless a row's result triggers another committed event, which no candidate does.

## Later qualification and reconsideration

Qualify admission first. A malformed table is rejected whole. A row naming a missing ID, and a duplicated key, are each rejected with a diagnostic, and the existing catalogue is retained (TADR-003 lines 31 and 33).

Qualify the flood test in a controlled world. An element hits water once and creates one surface. The surface enters collision at the next P3. The ball can stand on it, rendering draws it from the published result, and damage reads the same body. The surface leaves at its window's end the same way. Test a surface created where the ball already is. Test an ability and a stage event that meet the same water in one tick; they resolve in the frozen command and entity order. Rigid outcomes are judged as rates over at least 20 trials with a stated floor, per D1. Whether the interaction is fun is Andrew's verdict in the playtest log.

Open in the Bible and not decided here:

- The element pool, and which abilities and items carry an element. Q-P13 owns the pool (line 359 selects none); Q-P11 and Q-P14 own kits and items.
- Which materials exist in which regions, and which pairs enter production. Q-P24 owns terrain-changing interactions per region.
- Lava as a material and any region that holds it. The Bible never mentions lava.
- How ice or any created surface handles. Line 261 leaves traction penalties unchosen, and line 207 leaves currents' effect on handling undecided.
- Every surface lifetime, size and count, and whether a created surface can hurt or be destroyed.
- Whether enemies carry elements or trigger interactions. Q-P25 owns the roster.
- Audio for an interaction. The Bible has no event or interaction stinger, as the review's music row notes.

Revisit this ADR if play asks for interactions that chain or spread, which a single lookup cannot express, or if dynamic surfaces cost more than the physics budget allows once one is measured.
