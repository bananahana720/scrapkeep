# The hero sphere

A design-and-concept pass for the core-loop v2 look, written 2026-09-27 after Andrew liked the V3 shells and asked for two things: idle and active animation with attention to detail, and the player as "an actual sphere" with "the character inside the ball ... like a Super Mario Ball sort of type of look ... way more epic", with "gyroscopic rings that can go around the sphere and move around", where the pilot's race "ties in with its machinery". No game code changes here. The V3 shells, their recipes and `hero_assets.gd` are the baseline this evolves; the images under `artifacts/local/hero-concepts/` are the evidence, and `board/HERO-BOARD.md` is the one-page pitch.

Canon this obeys: `DESIGN-V2.md` §2 (kits, colours, shapes, sounds), §10 (the ancients are us; animals reign), §15 (the ball is the culture); `VISUAL-LANGUAGE.md` §2 (palette roles, class colour means "yours", ANCIENT never the player), §3 (shape grammar, class tick marks on the rim), §6, §8, §9 (slots, tri bands); `SOUND-STORY.md` §2 (leitmotifs); `STORY-THREADS.md` T2, T6, T7. Gameplay is fixed: the collider is a 1.0 m sphere (`src/movement/tuning.gd` `RADIUS`), rigid physics, the kits and trees stay.

## 1. The sphere mech

**One silhouette, three interiors.** The hull is a true 1.0 m clear sphere, the same for every class, so the player's shape on screen is the one thing in the world that is perfectly round (Wardens are cast and heavy, Fleet gear is bolted and boxy, terrain is banked stone). The pilot sits inside it, upright and visible from every angle (Monkey Ball clarity, AD-01/AC-01), on a **cradle**: two nested gimbal rings that keep the seat level while the glass rolls around it. Under the seat sits the **heart**: a salvaged ancient gyro flywheel, ringed by the mint intake (the shared collection field of VISUAL-LANGUAGE §2: scrap flies into it) with the class light at its centre. Outside the glass, **orbit rings** float on the heart's field at a lean, and they are where the class shape, the speed, the growth and the ability state all show.

The culture's word for the whole machine is a **gyre** (DESIGN-V2 §15 asked why balls; §6 below answers with the gyro). The three parts:

| Part | What it is | Moves with | Reads at 8 m |
| --- | --- | --- | --- |
| Hull | Clear ancient pressure-glass, with three great-circle seams and a handful of salvaged hex tiles bolted on | Rolls with the collider | The roll itself (the seams turn like a basketball's lines); the sphere's edge |
| Cradle | Two gimbal rings, a seat or perch, the heart, the class kit, the pilot | Stays upright, yaws to the heading (today's Pod) | The pilot's head and ears, the heart's glow, the kit's one working device |
| Rig | One to three orbit rings with rim marks, plates and hung devices | Neither: steered by velocity and state | Speed (spin), heading (lean), heft (count), class (rim marks), ability state (glow) |

The hull rolls but is glass, so without the seams the roll would be invisible; the seams make the rolling read, and the rings make the *momentum* read. The two are different facts and get different parts.

## 2. The ring language

The orbit rings are a language, and each fact has one carrier. Every carrier reads from the class row or the run state in code, never from a second copy (Andrew's one-source rule, preferences 2026-09-24).

| Fact | Carrier | How it reads | Source |
| --- | --- | --- | --- |
| Speed | Ring spin about its own axis, plus the rim marks | Marks streak into a blur at cruise; at rest the rings drift one turn per 6 s | `state.velocity` length |
| Heading and turning | Ring lean: all rings bank into the velocity, nose-down, 25° at cruise and 40° when boosting; the lean lags the turn by 0.15 s so a hard turn reads as the rings catching up | `state.velocity`, its change |
| Airborne | The rings level out (the gyro finds level) and spread 5 cm | grounded flag |
| Heft class I to V | Ring count 1, 1, 2, 2, 3; armour plates on each track 0, 3, 3, 5, 5; gimbal width 5 to 9 cm; heart radius 16 to 28 cm; a petrol armour band on ring 0 from class IV and on ring 1 at V | heft class, `run.mass` |
| Class shape | Rim marks: Sable's ring carries 12 mint pips; Rivet's carries 14 copper chevron teeth raked backward, so spin says direction; Kest's carries 8 spikes with amber fuse tips (VISUAL-LANGUAGE §3 "ring pips, chevrons or starburst spikes") | class row |
| Ability ready or cooling | The glow band on ring 0's inner face is the class colour when ready; while cooling it is a dark wedge that sweeps back to full, linearly (§8 easing), so the ring is the cooldown dial in world space; the HUD wedge stays the primary read | kit cooldown |
| Charges | Rim marks are lit per charge: Rivet's teeth in groups per sprint charge; Kest's spikes go dark one per live sticky and relight on detonation; Sable's pips pulse while a vault is available | kit charges |
| Hold gauge | The rings spread outward with the gauge (up to +12 cm) and the heart brightens; release snaps them back with the 1.2 overshoot (player-owned success, §8) | gauge |
| Hit | One ring is knocked 30° off its lean, its glow band flashes iron oxide for 0.25 s (harm to you, §2), and re-seats over 0.4 s; the pilot braces | damage event |
| Crowd control and gyro jam | The *inner* gimbals tumble and the seat wobbles (screen-stable, the camera never follows); the orbit rings drift level and dim. Break-free and tenacity: rings snap rigid with the broken-bracket flicker in the class colour (§11) | cc state, tenacity |
| Synergies | Lit 45° segments on the inner gimbal in the tag colour, up to eight, inside the glass so the silhouette never grows | synergies |
| Cloak (Kest) | Rings and glow go dotted, as the outline already does | cloak state |

**Why outside rings do not clip the ground.** Ring radii are 1.10, 1.21 and 1.32 m and the lean is capped at 0.70 rad: 1.44 m (the widest ring at full gauge spread) times sin 0.70 is 0.93 m, under the 1.0 m collider, so no ring ever reaches the ground plane. The blockout script asserts the cap (`MAX_TILT`). The rings are field-held, not mechanical, which is also why they can lean and spin free of the hull.

## 3. How it behaves, state by state

| State | Hull | Cradle and pilot | Rings | Sound cue that already exists |
| --- | --- | --- | --- | --- |
| Rest | Still | Pilot upright; slow breathing; fidgets (§7) | Slow drift, mixed leans, no spin | idle band |
| Rolling | Seams turn | Pilot leans into the heading, head ahead | Bank 25° into travel, spin with speed | the class's tick sounds |
| Airborne | Free | Pilot braces, both hands on the grips | Level out, 5 cm spread | none |
| Boost or sprint | Seams blur | Rivet's visor glows copper (the one pilot-shared effect, §6) | Bank 40°, spread, glow full | hi-hat roll, arpeggio, thumps |
| Smash (Ctrl) | Dips | Pilot ducks | Rings slam flat then bounce 1.2 on landing | the class's smash cue |
| Grapple and winch (Sable) | Free | Head tracks the anchor | Ring 0 rotates so its rope fairlead faces the anchor: the reticle made physical | two-note pickup |
| Glide (Kest) | Free | Bird stands tall on the perch | Ring 0's halves fold out as vanes (today's VaneL/VaneR) | the vane unfold |
| Hit | Free | Pilot flinches, eyes shut a frame | One ring knocked, oxide flash, re-seat | hit |
| Growing | Free | Heart brightens | A pickup's plate flies into the intake; on a heft class step a new ring forges out of the heart through the glass as a light ring and solidifies outside with a clunk | the A-D-A climb, the class clunk |

## 4. Growth without lumps

Scrap accretion on the surface goes. The fantasy of getting heavy stays, carried by the heft table above: more rings, plates locking onto ring tracks, a thicker gyro cage, a brighter heart, armour bands. Mass goes *into* the heart (a heavier flywheel is more gyroscopic momentum, which is what heft means in play: fodder that bounced you rolls up at 0.95 speed, hook tethers snap above your heft rating). The collider stays 1.0 m and the hull never scales; `accretion.gd`'s `shell_scale` step (7% per class) retires, because the rings extend the silhouette instead.

**Run start against late run.** Heft I is one thin bare ring, a slim cage, a small heart and a small pilot in a lot of glass. Heft V is three plated rings at three leans, a heavy cage, a heart lighting the pilot from below, and the same-sized pilot. The blockout lineups (`lineup_h1_rest`, `lineup_h5_boost`) show both at the game camera.

**What happens to the code path (proposal for the coordinator, no edits here).**

- `src/build/accretion.gd` keeps its job and its public API (`show_build(mass, parts, synergies, heft_class)`, `fling`, `chunk_count`, `piece_count`, `halo_visible`, `shell_class`), so its tests and the run-state contract hold. Its drawing target changes: `chunks_for(mass)` becomes plates on ring tracks (`MAX_CHUNKS` 36 becomes 15 plate slots at V, 5 per ring); the golden-spiral `_slot` becomes a track slot (ring, angle); `fling` sends plates off the tracks toward the thief; `_rebuild_pieces` docks the same part shapes on the tracks and the cradle instead of the surface; `_build_halo`'s tori retire and synergies become gimbal segments; `shell_scale` retires. The node moves from under `roll_node()` to under the rig, because plates ride rings, not the hull.
- `src/presentation/hero_assets.gd` splits the shell three ways instead of two: Hull under the rolling mesh, Cradle under the juice node (today's Pod path, unchanged), and a Rig under the juice node with its own `_steer_rig()` that sets spin, lean, spread and glow per §2 from `state.velocity`, the kit and the run. `CHUNK_BANDS`, `dress_chunk` and `_tuck_chunks` retire. Ring count by heft shows or hides `Ring1` and `Ring2`, which are all baked in one glb.
- The V3 animation writer's rule stands: everything drives named nodes (§8), so its idle and active work carries over.

## 5. Who pilots, and how race shapes the machine

Andrew opened the roster ("it could be literally whatever", friendly ancient machine beings, a friendly AI) and liked the fox, mole and bird. Canon says animals are the reigning species (DESIGN-V2 §10, T6), the ancients are hostile machines the Fleet dug up, and ANCIENT light never belongs to the player (VISUAL-LANGUAGE §2). The recommendation keeps the three animals as the demo's three classes, because the kits are theirs and Andrew likes them, and adds a fourth pilot as a story presence now and a class after v2 play.

**Race shapes the machine.** Species is a culture, never a temperament (Bible §2, T6), so each pilot's *body* shapes the cradle and each *culture* shapes the rings.

| | Sable, fox, Switchback Enclaves | Rivet, mole, Redjaw Workshops | Kest, bird, Highdraft Roosts | Tally, a friendly ancient (proposed) |
| --- | --- | --- | --- | --- |
| How the body sits | Curled into a felt-lined seat, tail wrapped round it; a fox rests low and springs | Low in a rear half-bucket cowl, claws on the grips; a burrower wants a wall at its back | Standing on a perch bar, feet gripping, shoulders still, head making small corrections; a flier wants air on every side | No body. The housing is the pilot: a barrel-sized seamless enamel core with one bone lens, bolted-on salvaged arms holding the grips |
| Hull | The clearest: Enclaves build quiet, so it rattles least | The same clear sphere; the cowl sits inside it, below shoulder height, so the visor stays findable | The same clear sphere; the most open interior | A tribe-built sphere, with one dead ancient groove on the glass where a light once ran |
| Heart | A lantern coil: the arpeggio is a winch reeling | A bearing race: the loudest heart, a hi-hat roll when it spins | A lift turbine: the thumps are its downdraft | Its own heart, lit worn bone: an unclaimed light |
| Rings | Clean circles with mint pips; ring 0 carries the rope fairlead and turns to aim the grapple | Heavy, chevron-toothed, plated first; the rail runs along the cradle to the glass | Spiked with fuse tips; satchels hang from the track; ring 0 folds into vanes | A single smooth ring with a charcoal groove and no marks: it has no class shape yet |
| What the class shape says | Ring: area around a point | Chevron: direction | Starburst: release | None until it has a kit |

**Tally, the friendly ancient, and the tension with canon.** A friendly ancient is the strongest thread Andrew opened, and canon already has its seed: the Caretaker Node plaque (T2) and the open question of whether the animals were uplifted by something humans left behind. The tension is visual and factional: Cherenkov blue and seamless enamel mean "hostile ancient", and the Fleet digs ancients up as inventory that wakes. Tally resolves it by being an ancient that *chose the living*: a caretaker drone core that woke in a tribe's salvage pile, and whose own light seams went dark when it did. Its enamel keeps the cap of `ancient_enamel` (value and saturation 45%, never emissive), its groove is unlit charcoal, and its only light is worn bone, so it never wears the Warden's colour and the palette rule holds. The question it carries stays unresolved on purpose (STORY-THREADS §4): a Warden's lost sibling, or the Mind's first hand, or an echo running on its own. One beat: on the summary's Cherenkov flicker across the dug-up housings, Tally's groove flickers once too, and never again. For the demo it is a presence: a dormant housing on Moss's shelf, one codex fragment, and the concept `h05`. A fourth class needs its own kit and tree (the no-reskins rule holds for heroes too), so that is post-v2 work.

## 6. Why spheres: the gyre

Sharpening DESIGN-V2 §15 for a true sphere with rings. The codex tells it; nothing states it.

- **You build a sphere around a gyro, not a gyro into a ball.** The first thing a tribe owns is a heart: a gyro salvaged from an ancient machine (reactor gyros, drone cores). The heart keeps a seat level over any ground, and the ground after the collapse is the enemy: fallout pockets, swarm ruins, the Mind's traps. So the tribes wrapped the heart in the one shape that rolls over anything, and the tech that ended humanity keeps the animals alive.
- **The glass is human glass.** Ancient pressure-glass (reactor viewports, drone canopies) is the one material the tribes cannot make and must dig for, so a whole sphere is wealth, and a cracked one is a family's loss. That is why the hull is clear and why every pilot is visible: nobody hides the glass they dug for.
- **Rings are the visible ledger.** A ring is forged by hand and floated on the heart's field; a family adds one when the heart can carry it. "A three-ring" is a respected gyre and heft class V. Count the rings and you know the elder. Ring marks are the culture's mark: the Enclaves pip, the Workshops tooth, the Roosts spike.
- **Nomads live in the gyre.** It is tent, cart and armour; camps go up as marble runs and come down the same day; cannons and trebuchets are public transport (§15). Moss's bay is the pit stop where a ring gets re-forged.
- **The enemies learned the sphere.** Gyro jammers make the gimbals tumble, swatters bat the ring, catch-traps cup the glass (§15). Every counter aims at one of the three parts, so a player who reads the machine reads the threat.

## 7. Animation and soul beats

Andrew: "attention to detail in the way they kind of like pulse or have idle or active animations". The pilot is the soul and the rings are the body language. Shared rules: the gyro keeps the pilot upright always; at speed the pilot braces (leans into travel, grips tighten); the head looks at the nearest live telegraph within 15 m, and at the lens cluster when the Mind's hand tracks the ball (a mutual-gaze beat for W7 and the boss designer). Reduced motion (RR-11) keeps the lean and spin (they measure state) and drops the fidgets.

| Beat | Sable | Rivet | Kest | Rings |
| --- | --- | --- | --- | --- |
| Idle | Ears swivel to sounds; tail tip flicks | Claws flex on the grips; visor dims and brightens like breathing | Head tilts in sharp small steps; crest settles | Drift one turn per 6 s; ring 0 pulses with the ready state |
| Fidget (every 6 to 12 s, one at a time) | Winds the spool a click; checks the rope | Taps the rail lens with a claw, wipes it | Re-hangs a satchel; goggles up, goggles down | One ring hiccups a quarter turn and settles |
| Active | Leans hard into the exit; head snaps to the vault face | Hunches; visor glows copper on sprint; exhaust puffs | Stands tall on glide; one wing-arm out for balance | Bank, spin, spread per §2 |
| Hit | Flinch, ears back, eyes shut a frame | Grips locked, shoulders up | Feathers puff, then flatten | One ring knocked, oxide flash |
| Triumph (Warden break, milestone) | Sits up, ears high, one paw off the grip | Slaps the bucket rim twice | Wings up, a hop on the perch | All rings snap to one lean and flash the class colour on the motif's last note |

Each beat has one sound and it is the class instrument (SOUND-STORY §2); fidgets are silent.

## 8. The hero's-journey read

Run start: heft I, one bare ring, a dim heart, a small pilot in a lot of glass, alone on a mesa edge. Stage 3: heft V, three plated rings spinning, a heart lighting the pilot from below, and the pilot exactly the same size, still visible, still soft. Against the Mind's hand the sphere is never big; it is bright and fast and handmade, and it can be seen into. That is the mortal read, and the contrast the boss designer should build against:

| Hero | Warden, the god's rungs (WARDEN-DESIGN.md) |
| --- | --- |
| Clear: the pilot and the heart are always visible | Opaque: cast shells, an operator nowhere ("awaiting operator") |
| Warm class light (mint, copper, amber) | Cold Cherenkov seams in charcoal grooves |
| Handmade: forged rings, bolts, plates, felt | Seamless, no bolts, no welds |
| 2 m across; grows by rings, never by size | Tens of metres; grows by rungs |
| Shows its heart all the time | Shows its core only where a shell has cracked (the weak point) |
| Rings spin with the player's momentum | Proposal for the boss side: the Mind's hand's arms carry rings that counter-spin, the ring language inverted like the motif is (C6) |

Things the boss side must know: the hero's rings reach 1.44 m from centre, so swatter paddles and catch-traps should be sized to the ring, not the glass; the pilot's head tracks the lens cluster, so a tracking lens gets a look back; the hero never uses hazard stripes, Cherenkov or brass, and never grows past its rings.

## 9. Modelling brief for the Blender writer

Style, slots and tri bands follow VISUAL-LANGUAGE §9; the blockouts in `tools/blender/concepts/hero_sphere.py` are the geometric reference (radii, leans, part placement), not the surfaces.

**Nodes, exactly (read by `hero_assets.gd` and the animation layer):**

```
Shell<Class>          root
  Hull                rolls: glass sphere, seams, hex tiles
  Cradle              upright, yaws: GimbalOuter, GimbalInner, Seat, Core (the heart), Pilot, class kit
    Pilot             the bust; Head under it, so the look-at drives one node
    Spool + RopeExit  Sable    |  Rail, Stacks, Cowl  Rivet    |  Mortar, Perch  Kest
  Rig                 steered: Ring0, Ring1, Ring2; each with Glow, Marks, Plate0..4, Band
    VaneL, VaneR      Kest, on Ring0
```

**Slots:** `glass` (hull), `bare_metal` (rings, gimbals, seams), `rubber` (pivots, grooves), `paint` (plates, seat, cowl, tiles; vertex-coloured from the paint set), `class_accent` (rim marks, glow bands, kit tips, the heart's centre; emissive only at the working device), `field` (the intake ring; mint, shared), `pilot`, and for Tally `ancient_enamel` capped and never emissive. No new slot.

**Tri bands (sketch targets):** hull 900 to 1,400; cradle with gimbals and kit 1,500 to 2,200; pilot 400 to 800; each orbit ring with marks 350 to 700; each plate 60 to 120. Heft V total 4,500 to 6,500, so the budget grows with heft and a heft I sphere is under 3,500.

**What code drives:** `Ring*` rotation (spin about local Z, lean about X and Y), `Ring*/Glow` material emission and wedge, `Ring*/Marks` per-mark visibility, `Ring*/Plate*` visibility, `Core` emission energy and scale, `GimbalOuter` and `GimbalInner` tumble, `Pilot/Head` look-at and brace pose, `VaneL/R` fold. The V3 shells' Core and Pod names stay valid until the swap (the new Cradle is the old Pod).

## 10. What the gameplay would need (proposals only)

Nothing in this document requires a gameplay change; the collider, physics and kits stay. Optional hooks, each a proposal for the coordinator: a `heft_class_changed` signal so the ring forge beat has one trigger; the gyro-jam counter (§15) exposing a `jammed` state so the gimbals can tumble; and hit and tenacity events already exist. The rings are cosmetic and never collide.

## 11. Questions for Andrew

1. **Tally. Answered 2026-09-27: an unlockable fourth pilot.** Andrew's words: "an unlock of a character ... a friendly version or a quirky glitchy ... comic relief type of character ... a robot that ... could kind of like transmog and ... shift based on ... his abilities and or technology". So Tally is playable once unlocked, not a starting pick, and is comic relief. The comedy lands through timing and animation (stutters, error faces, reboots at bad moments), not words. The mechanic is transmog: its sphere, rings and kit reshape to match the parts and tree picks it holds. It must reuse the existing slot and dispatch tables in `src/core/ability_state.gd` and the tree data, with no special-case paths, and the ring language shows its current form. The unlock rides a story beat and applies from the next run (PROGRESSION account horizon). The demo keeps the presence default above (the shelf housing, one fragment, the flicker). The playable class, its transmog rule and its unlock are post-alpha design work, and the gameplay rule needs its own design pass before any build.
2. **How opaque may a race make its sphere?** Rivet wants a wall at his back. Default: the rear bucket below shoulder height only; the glass stays a full clear sphere for all three, one silhouette and three interiors.
3. **Ring count as a public status marker.** If a three-ring is an elder, NPC and ambient gyres in Moss's bay and later settlements would show their rings too. Default: yes for ambient gyres after the demo, none in the demo.

## 12. Evidence

- Blockouts: `artifacts/local/hero-concepts/blockouts/<class>_h<heft>_<state>_sheet.png` (four yaws at the game camera, four close), plus `lineup_h1_rest` and `lineup_h5_boost`; `batch.log` carries the TRIS and RING rows. Script: `tools/blender/concepts/hero_sphere.py`.
- Paintovers: `artifacts/local/hero-concepts/paintovers/h01..h06_try*.png` with `renders.jsonl` (seed, seconds, peak VRAM). Script: `tools/concept/render_hero.py`. Concept references only, never runtime assets.
- Contact sheet: `artifacts/local/hero-concepts/contact_sheet.jpg`; pitches in `board/HERO-BOARD.md`.
