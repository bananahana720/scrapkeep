# 0002: Separate simulation from presentation

Date: 2026-09-05. Status: accepted, recorded retrospectively.

## Context and decision

Combat must be testable without a browser. Keep orchard state, movement, combat, pickups and event production in the deterministic simulation. Input/UI orchestration translates controls into simulation inputs; the scene and models consume state and drained events.

The orchard simulation runs at 120 Hz with bounded elapsed-time handling. The baseline's 60 Hz loop is a separate implementation. Its timing is not an orchard convention.

## Consequences and revisit trigger

Increment 01 extends this boundary with vertical player state, wave/intermission state, equipment and simulation-owned attack descriptors. Camera rays enter as plain vectors; Three.js objects and DOM events remain outside the simulation. The [current contract](../project/INCREMENT-01-lightning-playtest.md) defines the interface.

State and event contracts must remain explicit. Avoid DOM, rendering and audio dependencies in the simulation. Renderer state does not decide damage. A richer physics/terrain model may require another boundary, but any change must retain deterministic gameplay checks and explain how presentation reads authoritative state.

Evidence: [simulation](../../src/orchard/simulation.js), [orchestration](../../src/orchard/main.js), [contract](../FIRST-BUILD-CONTRACT.md), [simulation tests](../../tests/orchard.test.js).
