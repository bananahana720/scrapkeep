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

The contract other modules read is [src/combat/README.md](src/combat/README.md). The numbers below come from the `tests/combat_*.gd` runs on this branch.

1. **Weapons fire bolts, and one aim query sends them.** The reticle's centre ray finds the point, and the centre bolt of every volley flies straight at it and never corkscrews. The ray starts level with the ball, so nothing behind the shooter catches the aim. There is no aim magnetism anywhere. Serves TADR-008 (the reticle shows what the shot hits) and 5.
2. **The runner-gunner is laser-true.** It fires 12 bolts a second at 7 damage, with a thin 0.25 m field and no spread. A chaser 16 m out died 0.66 s into held fire. Serves 5 ("rapid tight laser shots").
3. **Overdrive is the runner's escape hatch.** F blasts a 12 m ring for 30 damage with a heavy shove, then gives 3 s of 1.6 times the fire rate, on a 6 s cooldown. It clears space when you are surrounded, so you keep rolling instead of braking. Serves 5 (the area alternative) and 1.
4. **The arc caster forgives with a wide field and a chain, not a magnet.** It fires 5 bolts a second at 12 damage, with a 0.55 m field and one chain jump within 9 m. In the test the chain reached the chaser beside the target 4 times. Serves 5 and TADR-008, since a homing bolt would make the reticle lie.
5. **The pylon turret is the caster, planted.** While mounted, held fire fires 9 volleys a second, chains two jumps within 16 m, and reaches 95 m. The test measured 10 turret volleys in 1 s. Serves 5 and 8.
6. **The engineer's special is one discharge with two triggers.** Every plant fires it free, powered by the banked speed: that is the opening burst. F fires it any time, powered by your current speed, or by the bank while mounted, on a 5 s cooldown. Speed buys arcs, reach and damage. A plant at 5.0 m/s arced 2 enemies for 20.9 each within 14.2 m. A plant at 25.8 m/s arced 7 for 50.1 each within 23.6 m. Serves 8 ("a faster mount gives a stronger opening burst") and 1, since speed becomes power rather than something the wall takes away.
7. **The shoulder view follows the mount state every tick,** not only the mount and dismount signals. A retry, a death or an E drop can never leave the camera stuck at the shoulder. In the test the blend reached 1.00, and 10 of 10 turret shots sat on the shoulder reticle's ray and struck the chaser under it. Serves entry 6 ("snap to a more shoulder view") and 5.
8. **Patterns are data, and transformers are rows.** A row adds, then multiplies, then floors pattern fields, once per stack. Cross split adds three arms around the aim line, making a cross and then a seven-point star. Spiral wave turns the pattern 23 degrees per volley and corkscrews the off-centre bolts. Parts reach these through `register_part(part_id, ids)` or by using a transformer id as the part id. Combat recomputes from `run.parts`, so a retry restores the build. Serves 4 (Isaac and Gunfire Reborn synergies) and 7.
9. **Stacking can multiply damage without limit, but never what is on screen.** A volley has at most 16 bolts and 8 arms, fire rate stops at 20 a second, and at most 64 player bolts are live. Past the cap a new bolt retires the oldest, so the trigger never stalls and only the far end of the stream thins. Bolts fade from 0.9 to 0.4 alpha as the count climbs. A spiral plus two crosses plus every rate and range tier would put about 103 bolts up; the test peaked at 64 and kept 20 volleys a second. Serves 4 ("cap projectile counts") and 1.
10. **Enemy telegraphs always draw on top.** They use `HAZARD`, with no depth test, at render priority 40. Player bolts draw at 0 and combat effects at 1, and no player weapon uses `HAZARD`. Serves 4 ("never let our own effects hide an enemy").
11. **An enemy hurts you only through the geometry it showed you.** Each attack commits a ring or a lane once, and the damage asks that same node whether the ball is inside. Touching an enemy that is not attacking costs nothing but the bump. Rings and lanes reach 3.5 to 4 m above the ground, so a jump or a glide clears them. In the test a charge lane committed on the ball missed once the ball was moved 12.6 m off it. Serves 1 (nothing stops you unforeseen) and AGENTS.md (damage and telegraphs consume the same committed geometry).
12. **The chaser lunges down a lane; the lobber shells a ring.** The chaser lays an 11 m lane with a 0.6 s wind-up. A knock of 10 m/s or more during the wind-up breaks the lunge, so a ram or overdrive can interrupt it. The lobber commits its landing ring the moment it fires, leading a moving ball by half its travel, and shows the ring for the whole 1.9 s flight. A shell already in the air still lands if its lobber dies, because what was shown is what happens. Serves 1 and TADR-008.
13. **A hit taken shoves the ball** by 5 to 10 m/s along the attack. Serves 1: collisions have weight, and a hit taken is the player's own performance. It uses `add_external_accel`, the hook the flood uses; see the shared-file request in the handoff.
14. **Weight divides every knock.** A chaser weighs 1, a lobber 3 and the miniboss 5. The lobber used to be immovable and now slides when rammed. Serves 1 ("collisions have weight").
15. **The miniboss fights in a readable rhythm.** It alternates a leap slam (a 7 m ring) and a charge (a 30 m lane, 1 s brace). After each attack comes a 2.4 s weak window, and the window reads three ways: the armour plates swing open, the core swells and glows, and a halo spins overhead. Hits land at 2.2 times in the window and 0.35 times through the armour. It has 900 health times stage threat. The base laser killed it 7.5 s into held fire at stage 1, starting at its second window. Serves 3 (the boss half of an event), 8 ("feel like a badass": read, dodge, punish) and 4 (readable threats).
16. **An enemy that falls through the map is put back on the ground, not killed,** so nobody gets scrap they did not earn. Serves 7.

Open questions for Andrew:

- F on the engineer fires the pylon discharge from your speed. Would you rather F did something with the pylon itself, such as planting one without a wall?
- A hit taken shoves you 5 to 10 m/s. Is that weight, or does it read as the game taking your line?

## Build and growth (writer B)

## Audio and feel (writer C)

## Events and stages (writer D)
