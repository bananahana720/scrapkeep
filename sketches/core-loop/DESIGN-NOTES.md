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

1. **The scrap magnet reaches further the faster you roll.** Its reach is 7 m plus 0.3 m per m/s of speed, so about 16 m at 30 m/s. A piece it catches homes in faster than the ball can outrun it and stays caught. Serves momentum is sacred (1): you never slow down or turn back for scrap.
2. **Scrap sticks to the ball, and so do parts.** Held scrap shows as chunks on the ball's surface, growing with the square root of the total and capped at 36. Each part is a piece of hardware: its shape says its family (barrel, cross, coil, rod, vane, capacitor, gem) and its colour says its rarity. Pieces cap at 24 and stick out no more than 0.7 m. Spending at a fabricator takes chunks off and bolts a part on, so the purchase reads on the ball. Serves 1 ("building momentum and rolling and growing"), 4 (visual clarity) and form mirrors function.
3. **Fabricators are hoops you roll through.** They stand across the scrap lines, away from the beacon and the spawn: 2, 3 and 4 hoops in stages 1 to 3. There is no collider. Roll through with enough scrap and the hoop spends it and grants the part. Short of scrap, nothing happens, and the hoop reads "need N scrap (have M)". After a sale the hoop restocks with a new part 2.5 s later. The build test measured 19.34 m/s before a paid pass and 19.86 m/s after, and 18.79 then 18.54 m/s through an unpaid one. Serves 1 ("fabricators are drive-through").
4. **Price depends only on the part's tier and how many parts you hold.** It is 10 scrap times 1, 1.6 or 2.6 by tier, times 1.15 for each part held. A retry restores the part list, so it restores prices too. Serves quick restart (2) and fast without debt (7).
5. **A gate says what it gives while you approach.** It shows the part name large, its effect in one line, and "* completes Storm Lattice *" when taking it would complete a synergy. Rarity shows twice: in the arch's colour and in the topper's shape (a bar for common, a diamond for rare, a star for epic). The offer records carry `name`, `text`, `rarity`, `tier` and `synergy` for presentation. Serves form mirrors function and 1 ("reward choices are gates you roll through").
6. **Offers climb in tier across the run.** (Superseded by 23: tier now follows bonus cores, not the stage.) The test measured a mean offered tier of 1.25, 1.59 and 1.97 in stages 1 to 3. When the run is one part short of a synergy, half the time one offer slot shows that part. Serves 4 (Isaac-style "one more piece").
7. **The scaling curve runs from modest to absurd on purpose.** Tier 1 gives +10 to 15%, tier 2 +25% and tier 3 +50%. Copies multiply, and pattern levels add. The build sheet's output estimate puts one Hot Rivets at 1.12x a bare weapon and a ten-part late build at about 324x. With punch added in phase 1, the same builds measure 1.44x and about 1,444x. That number is a model for shaping the curve. What is actually drawn and how hard it hits is combat's (A), under the visual caps. Serves 4 ("the ability to scale insanely").
8. **Synergies are derived, never held.** (Superseded in part by 17 and 18: synergies are now tag pairs, and Storm Lattice lost its +25%.) Storm Lattice (Cross Split and Chain Arc) makes every split bolt chain, adds a chain level and +25% damage, and puts a gyroscope cage of arc rings on the ball. Thermal Shock (Frost Vane and Arc Coil) makes the slam's arc shatter nearby ice into a shard nova at double damage, then refreezes the water around you. It puts a frosted coil ring on the ball. A retry that drops a part drops its synergy. Serves 4 and form mirrors function.
9. **Frost on water makes real ground.** Ice is a StaticBody3D on the world layer, so the ball, the grapple and the camera all treat it as terrain. It has the same grip as the ground, so there is no handling penalty (BIBLE line 481). It lasts 9 s and blinks for its last 1.5 s, so losing the ground is never a surprise. The test rolled a ball over 3 m of water: with no ice it sank to the ground, and on ice it stayed at the surface and kept 12.4 m/s. Serves 1 ("nothing ... in a way they didn't see coming") and TADR-009.
10. **Ice never forms inside the ball.** Where the ball already sits below the new surface, the slab forms just under it. The test measured 0.000 m of displacement. Serves 1: creating a surface never pops or blocks the ball.
11. **Frost on ice does nothing.** The table has no frost x ice row, so slabs never stack and land about one radius apart in an overlapping road. Serves TADR-009 (default-deny).
12. **Electrified water hurts enemies only.** The arc is the player's own weapon, so it never costs the player HP or momentum. Serves 8 ("feel like a badass") and 1.
13. **Dash and slam elements resolve in build's own physics step.** The `dashed` and `slammed` handlers only queue them. The frost trail lasts 0.7 s after a Frost Vane dash, with a visible frost puff every third tick, even over dry ground, so the part always shows it is working. Serves TADR-008 (a signal applies nothing) and form mirrors function.
14. **A won event pays out in the same frame.** The milestone handler grants the part at once, so the milestone stinger and "New part" land as one beat. This is the one place build mutates inside a handler. Serves 3 ("win great rewards like key milestone rewards").
15. **Events award named milestone parts.** Surge Run awards Rime Heart: you rode the flood, now you freeze it. Hold the Relay awards Tempest Core. Any other event awards the first milestone part the run does not hold yet. Fabricators and vaults never offer milestone parts, and a gate offers them only when overcharged by two or more bonus cores (23). Class mods (Pylon Capacitor, Runner Overclock) are offered only to their class. Serves 3 and 5.
16. **Build owns the tuning mods.** Weapon numbers travel as tuning mods (`weapon_damage`, `weapon_rate`, `weapon_range`, `turret_damage`), so combat reads them with `tuning.mod(key)` and needs no spine change. Pattern levels, transformers and the element table are behind the build API; [src/build/SEAMS.md](src/build/SEAMS.md) lists every id. Serves 7.

17. **Tags make synergies legible.** Every part carries one or two of nine tags: frost, arc, kinetic, split, spiral, chain, anchor, speed and mass. A named synergy is a tag pair. It goes live when two different held parts carry its two tags, so "something that splits" is a clue a player can act on. Serves Andrew's synergy request ("coherent sense for the player to be willing to experiment") and 4.
18. **Eight named synergies, each a behaviour, never a bare number.**
    - Storm Lattice (chain + split): split bolts chain.
    - Thermal Shock (frost + arc): the slam's arc shatters ice at double damage, then refreezes.
    - Lightning Rod (arc + mass): each pickup sparks an arc at the nearest enemy.
    - Tesla Pylon (anchor + arc): arcs leap to two enemies while mounted or hooked.
    - Wrecking Ball (speed + kinetic): rams send out a shockwave.
    - Shrapnel Bloom (split + kinetic): kills burst into shrapnel.
    - Glacier Hull (mass + frost): hard landings crack out a frost ring.
    - Pinwheel (spiral + speed): at fast speed and above, a blade ring cuts the enemies you pass.

    Storm Lattice lost its +25% damage. Serves 4 ("a synergy changes behaviour, never just a percentage").
19. **Every synergy effect is capped.**
    - Shrapnel: 6 bursts a second, 3 targets each.
    - Lightning Rod: 6 zaps a second.
    - Tesla Pylon: 2 targets every 0.5 s.
    - Pinwheel: up to 4 targets, each cut at most once per 0.3 s.
    - Zap lines on screen: at most 12.
    - Rings: one per live synergy, 8 at most, each at its own tilt and in its first tag's colour.

    The behaviour test sent 20 kills in one tick and measured 6 shrapnel strikes. Serves 4 (visual clarity is the balance rule).
20. **Hint cards set goals.** An undiscovered card names one ingredient and gives a clue from the other's tag: "Chain Arc + something that splits." Offers carry a star line:
    - "* completes Storm Lattice *" when taking the part brings a synergy live;
    - "* ingredient: ??? *" when it is a card's named ingredient;
    - "* ingredient: Storm Lattice *" once that synergy is discovered.

    Serves Andrew's "goal setting and creating some excitement" and 1 (you choose by reading a gate at speed).
21. **A synergy is discovered once per run.** Its first activation is the discovery. A retry that drops it and a later reactivation do not repeat it. From phase 2 the lasting record and the scrap burst belong to the codex registry. Serves 2 and 3.
22. **Accidental finds come from the systems, unnamed.** Each element-table row and the spiral + chain tag rule has a plain description, logged the first time it fires in a run. Every slam carries kinetic, so slamming your own ice shatters it: the spec's "frost followed by kinetic". Serves Andrew's "accidental ones" and TADR-009.
23. **Rarity follows source.**
    - Gates: common or uncommon at 0 bonus cores, uncommon or rare at 1, rare or rare-plus at 2 or more. At 2 or more, a gate may offer a milestone part.
    - Fabricators: uncommon.
    - Vaults: rare.
    - Won events: rare-plus.

    Only common parts may be plain percentages, and every gate pair holds a part that raises punch or transforms a pattern. The measured mean offered tier is 1.43, 2.38 and 3.00 at 0, 1 and 2 cores. Serves the demo's one demand (punch against plating) and 4.
24. **Labels state the demand.** An offer reads "{name}: {verb}. Punch +{n}", so what a part does for the plating check is on the arch. Serves form mirrors function.
25. **The capped behaviours start full.** Their per-second budgets refill at each stage entry, so the first shrapnel burst of a stage is never swallowed; the behaviour test caught that bug. Serves 8 ("feel like a badass" from the first kill).

Open for integration: in live play, frost and arc find water only once world answers `ctx.terrain.material_at(point)` or registers a water provider (SEAMS.md). Until then the element table works in the tests, and in play the dash shows only its frost puffs.

## Audio and feel (writer C)

## Events and stages (writer D)
