# 0005: Caster input and solo dashboard lifecycle

Date: 5 September 2026. Status: accepted for increment 01; implementation verification pending.

## Context

Andrew's orchard playtest requested mouse-driven third-person aiming, targeted spells, jumping, denser waves and a readable management overlay. The old proof couples Space to burst, R to immediate restart, and primary fire to charge-release. Those bindings conflict with the approved caster kit.

## Decision

Input orchestration owns browser focus, pointer capture, physical key state and dashboard navigation. The simulation owns ability edges, cast preparation, release, cooldowns and cancellation. Rendering owns camera orientation and provides its center ray; the simulation resolves weapon-origin geometry from that ray.

Opening the dashboard pauses the solo simulation, cancels prepared attacks, clears held controls and releases pointer capture. Closing it restores the prior playing or intermission state. Actual play resumes only after valid mouse capture or a supported non-mouse control path. A denied capture has a visible retry action. The retry click never doubles as a shot.

The native modal dialog provides focus containment. Tab navigates controls within it; I toggles the dashboard and Escape cancels targeting or closes/pauses. Restart is an explicit menu action. Equipment inspection and settings are always available through pause; equipment mutation is allowed only between waves. There is no persistence of combat power.

## Consequences

Held-key clearing at the UI boundary and simulation cancellation solve different problems. Clearing browser state prevents a stale press on resume; cancellation prevents a prepared spell from casting when its key is released outside play. Neither is optional.

Screenshots and synthetic DOM events do not prove actual pointer capture. Verify normal start/resume using a real browser interaction and label synthetic QA separately. A gamepad mapping does not establish hardware usability.

## Revisit trigger

Co-op requires a new rule for menus because a local overlay cannot pause the shared encounter. A new targeting scheme or platform also requires review of input ownership and cancellation semantics.

Sources: [approved increment](../project/INCREMENT-01-lightning-playtest.md), [simulation boundary](0002-simulation-boundary.md), [geometry](0003-authoritative-attack-geometry.md).
