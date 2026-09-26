# Core-loop design notes

These are the design calls agents made while building this prototype, each with the principle it serves. The principles are Andrew's, from [playtest entry 6](../../docs/playtests/PLAYTEST-LOG.md#6-mobility-kit-v2-first-human-play-and-design-principles). The coordinator brings these to Andrew and asks him only when a call would change the direction of the deliverable.

Each writer appends only inside its own section, so the four module branches merge cleanly.

## Spine (wave 1)

1. **The beacon charges as you roll into its ring.** No key starts it, and you never have to stop. Circling inside the ring charges it. Leaving pauses the charge and keeps what you have. Serves momentum is sacred (1).
2. **Reward gates are arches with no collider.** They stand 38 m ahead on the ball's line of travel, 18 m apart. Rolling through one takes its part. If you roll past both, the stub puts them ahead of you again instead of waiting behind you. Serves 1 ("reward choices are gates you roll through, not a menu"). The run test measures speed through a gate: 20.93 m/s in, 21.11 m/s after.
3. **The launch keeps horizontal speed exactly.** Flow turns that speed onto the next stage's entry heading and keeps the vertical part. The world stub adds 20 m/s of lift and never launches slower than cruise, because raising a slow ball is a gift, not a cost. Serves 1 ("the stage exit is a launch into the next stage"). The run test measured 20.99 m/s before the launch and 20.98 m/s after.
4. **The next stage is entered from 14 m above its spawn,** so a launch lands rather than pops in. Serves 1 and the snappy, fluid half of 8.
5. **Stage 1 drops you in already rolling,** at 80% of cruise down the entry heading. Serves quick to start (2) and 1.
6. **A retry restores the entry velocity as well as the stage-start state:** scrap, HP, parts, kills and position. You re-enter the stage the way the launch delivered you. It is one synchronous call, measured at about 1 ms. Serves 2 and 1.
7. **The death screen takes one key.** R retries the stage from its start. N starts a new run as the same class. C goes to class select. In play, holding R for 0.5 s retries the stage. The hold stops a stray tap from throwing away a good run. Serves 2.
8. **Falling through the geometry costs nothing.** The rescue puts you back on the ground with your full horizontal speed and no damage, because the map failed, not the player. Serves 1 ("only the player's own performance costs momentum").
9. **The pylon banks the speed you plant with.** Space slingshots you off along the face toward where you look. The eject speed is the banked speed times 0.85, plus 6 m/s, and never less than a plain jump. E drops off in place, a stop the player chose. Both numbers are F1 sliders (`Slingshot keep`, `Slingshot boost`). Serves 8 ("the pylon keeps momentum"). The movement test measured a plant at 11.89 m/s and an eject at 16.10 m/s, against a 13 m/s jump.
10. **The camera moves to the shoulder while mounted.** The arm shortens to 4.2 m and the ball shifts left of the crosshair. The camera owns the hook, and combat decides when to use it. Serves entry 6 ("snap to a more shoulder view") and 5.
11. **Both classes can fire while rolling.** v2 allowed the zap only while mounted. The runner-gunner runs and guns, so the stub weapon fires any time for both classes. Serves 5.
12. **Collisions have weight on both sides of the seam.** The ball applies knockback itself, so a ram always shoves. Combat turns the same contact into damage once, through `strike`. Serves 1 ("collisions have weight") and TADR-008 (resolve once, publish the result).
13. **Run state changes only through mutators, and each mutator publishes its own fact.** The HUD, the summary and audio cannot disagree with the numbers. Serves fast without debt (7) and TADR-008.
14. **Every fact has a shape as well as a colour** in `event_kinds.gd`, so colour never carries meaning alone. The objective line, the HUD toasts and the field-notes legend all read their wording from the same row. Serves form mirrors function.
15. **Hit-stop is a spine API.** It is capped at 60 ms, never stacks, and runs only in play, so juice cannot become an obstruction. Serves 8 ("as weight and not as obstruction") and 1.
16. **Parts change tuning through multipliers, not by moving the sliders.** The recompute from the part list is idempotent, so a retry restores the build exactly, and F1 still shows the base values. Serves 7.
17. **Rigid physics only.** The kinematic body and the F2 toggle are gone. Serves entry 6 and TADR-006.
18. **The terrain belongs to world (D) behind a frozen API.** For now all three stages share the Spillway map, read three ways: stage 1 runs the top shelf and its chute to a mid-shelf beacon, stage 2 drops into the basin the flood fills, and stage 3 takes the bypass deck to the basin floor. Serves 3 (the flood is a layer on stage 2's beacon), and D can replace the stages.
19. **The flood is announced before it rises.** Its klaxon runs for 5 s before the water moves (`event_announced`, then `event_started`). Serves 1 ("nothing the game does may stop or inhibit the player in a way they didn't see coming") and TADR-010.

Open question for review: the flood's drag in the basin slows a ball that stays in the water. The flood is announced and visible and the ball can leave it, but the reviewer should decide whether drag near a beacon counts as an unforeseen momentum blocker.

## Combat and classes (writer A)

## Build and growth (writer B)

## Audio and feel (writer C)

## Events and stages (writer D)
