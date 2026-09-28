# Warden design: the three family Wardens

The boss design pass for core-loop v2. It sits beside `DESIGN-V2.md` (§10, §11, §15), `VISUAL-LANGUAGE.md` (§2 to §4, §8, §9, §11), `SOUND-STORY.md` (§2, §3) and `STORY-THREADS.md`. It reads W7's built mechanics as the source of truth for every form; where the fight itself is the weak part, §9 says so and proposes the fix instead of dressing it.

Andrew's brief (2026-09-27, verbatim): the first Warden model "doesn't really look like a boss ... I would want it to be something that's a little bit more menacing ... epic ... not in terms of scale but in terms of design ... intimidating ... part of its design has to encompass its main set of boss mechanics". And the same day: "a hero's journey as they progress through the map ... being versus God type of feeling ... insurmountable odds ... a way to instill the player to take on the challenge."

Concept renders are under `artifacts/local/boss-concepts/` (git ignores them); `board/BOSS-BOARD.md` pairs each with its pitch. The renders are references for shape and mood, never for surface, and never admission evidence.

## 1. What the first pass got wrong, and the rules that fix it

The rejected model (`core-loop-v2-look/artifacts/local/v3/warden/`) is a stack of smooth petrol rings around a pole with the family kit as a small ornament on top. Read from the gameplay camera it is a fountain or a pump. The failures, each with the rule this document builds on:

| Failure | Rule |
| --- | --- |
| No face. Nothing on it looks at you, so nothing threatens you. | Every Warden has one focal point that tracks the ball, and that point is its weak point. Where it looks is where you hit it. |
| No posture. Rings are radially symmetric, so it has no front, no lean, no intent. | Every Warden leans toward the player and is asymmetric front to back and left to right (a scar side and a whole side). |
| The kit is a detail on the base. The base is 80% of the mass and says nothing. | The proportion inverts: the base is the lower third and the family body is the upper two thirds and the silhouette (§7, a proportion proposal, not a rule change). |
| The mechanic is invisible. Vent stacks that never swell, a queen cell that never opens, a lens the size of a bolt. | Every attack and state in `warden.gd` maps to a named part that visibly winds up, and the part is big enough to read at 150 m (§2, the tables). |
| Threat with no reason. Blue seams as decoration. | Light leaks only from wounds and weak points (VISUAL-LANGUAGE §11: seams are the mechanism). A Warden gets brighter as it gets more broken. |

## 2. What W7 built (the mechanics every form must carry)

Read from `core-loop-v2-enemies` at `4106317`: `src/combat/warden.gd`, `warden_kit.gd`, `warden_look.gd`, `swarm.gd`, `swarm_remnant.gd`, `mind_hand.gd`, `reactor_relic.gd`, `habits.gd`, `fleet.gd`, and `DESIGN-NOTES.md` "v2 W7 enemies" items 8 to 14.

**Shared, all three (the clamp):**

- Immobile at the beacon mast's base; collider cylinder radius 2.8 m, height 3.2 m (`warden.gd:43-44,432-438`). The look is about 7 m tall and 8 m across (`warden_look.gd:8-9`). Four jaw plates turn as one so a gap faces the ball (`warden_look.gd:149-166,290-296`); they carry the plating tint and the shred seams (amber cracks past 25% stripped, `warden_look.gd:52,355-362`).
- **The pulse.** While the ball is inside reach (30 m), every 6 s it charges for 2 s (INSTANT ring at reach radius in sand, plus a 6 m core ring), then lifts a ball inside the reach ring 10 m/s straight up and deals 10 to a ball inside the core ring (`warden.gd:45-50,338-383`). The core glow brightens with the charge (`warden_look.gd:299-304`).
- **Plating** 45 / 80 / 140 and HP 800 / 2200 / 7500 by stage (CONTRACTS.md:83). A punch below plating chips 20%; landed hits shred plating for a while (DESIGN-NOTES combat item 36).
- **The lesson**, one per stage as data (`warden.gd:19-27`): stage 1 `plate` (nothing more); stage 2 `caps` (three vent caps on the deck, a stomp or slam on one meets plating 0 at x1.5); stage 3 `magnet` (every 8 s an arm swings toward the ball 3.6 m up, a 35° LANE wedge for 1.5 s, then a 1.5 s tug at 3.5 m/s²; a weapon hit on the arm during the tug drops plating to 0 for 3 s).
- **The badge**: a camera-facing integrity ring 12 m up that fills with the share broken (`warden_look.gd:196-224`).
- **Music**: the club transition on `warden_engaged`, a key lift at 50% broken (`music_engine.gd:101` `WARDEN_LIFT_AT := 0.5`), the sinister build from 75% (`music_engine.gd:102` `WARDEN_BUILD_FROM := 0.75`), the drop on `beacon_unsealed` (DESIGN-NOTES audio items 25, 34).

**The family kit** (`warden.gd:29-41,194-285`, `warden_kit.gd`): one weak point at plating 0 (radius 1.3 m) that opens only when the family's own mechanic is answered.

| Stage | Family | Opens the weak point | Window | Point, height | Reachable by |
| --- | --- | --- | --- | --- | --- |
| 1 | Reactor | Every pulse (the reactor venting) | 2.5 s | `core`, 5.2 m | Weapons; a stomp or slam within 3.2 m flat (`contact_part`) |
| 2 | Swarm hive | Bowling through the ten-drone guard rack (a rack scatters at 10 m/s or on a hard knock) | 4 s; the guard respawns 10 s after it dies out | `queen`, 5.1 m | Weapons; a stomp or slam within 3.2 m |
| 3 | The Mind | Every 10 s in reach it reads your most-used habit, shows its trigger icon for 1.2 s, then braces 5 s: that verb meets 1.4x plating and the lens stands open | 5 s | `lens`, 7.6 m | Weapons only (`contact_part` excludes the Mind) |

The guard rack is a real swarm (`swarm.gd`): it forms between hive and ball at 9 m, locks, commits a LANE and dives at 20 m/s, stings 8 once per dive, then re-forms. Scattered drones follow the ball for 2 s with their seams dark (C11).

## 3. The shared base: the Housing

DESIGN-V2 §11 and VISUAL-LANGUAGE §9 keep one shared clamp base with a family kit per stage. This document keeps the rule. The base earns its share when it says one thing every stage: **this is the standard human casing the Fleet digs up, and each family is what climbed out of it.** Brindle counts these housings as inventory (STORY-THREADS T4, fragment 9); the clamp is the inventory tag made physical.

**Form.** A half-buried cast footing (the collider) with the sand line of the dig cut across it, four jaw plates rising from it around the mast, and a pivot deck between them where the family body stands. The jaws are the ball-culture tell: each plate is a C-section sized to close on a 2 m sphere. A player who has rolled through a mag pit and a catch trap reads the clamp at once as the biggest cup in the game, and the beacon mast as what it caught instead of them. The jaws turn to face the ball (code) so the gap, and the family's face behind it, always look at you.

**What the base owns, every stage:**

| Mechanic | Base part | Telegraph and read |
| --- | --- | --- |
| Plating tint, "breaks now" rim, crack glyph | `Jaws/Jaw_0..3` outer faces | The four biggest flat faces in the fight carry the dress (primer ruling 6), readable from the drop. |
| Shred seams | `Jaws/Jaw_N/Seams_0..2` | Amber cracks across the plate, three levels (code). Form: the cast shell splitting, light behind it. |
| The pulse (INSTANT) | `Skirt/Vent_0..7` under the jaw line, plus the family's own tell (§4 to §6) | Over the 2 s the skirt vents open downward, one every 0.25 s round the ring (a ratchet you can see, matching the ratchet you hear); at the pulse they all blast down at once and the jaws clench inward one frame. A lift is a downward blast: form mirrors function. |
| Unplated by magnet (stage 3) | `Skirt` seams, `PulseCore` | Seams flicker off and on (code flickers the core); the jaws sag open 15° for the 3 s. |
| Integrity | `Badge` (code, no model) and the break stages (§4 to §6) | |

**Named base nodes** (for the rig and for `warden_look.gd`): `Footing`, `Skirt` (with `Vent_0..7`), `Jaws` (pivot, yaw driven), `Jaws/Jaw_0..3` (each with `Lip`, `Seams_0..2`), `Deck`, `PulseCore`, `Mast_Socket` (where the world's mast passes through; the mast itself is world geometry).

**Two C-jaws or four plates.** VISUAL-LANGUAGE §9 says "two massive cast C-jaws"; `warden_look.gd` builds four plates. Both hold if each C-jaw is cast in two plates with a seam between: two jaws, four plates, and the code's four pivots drive them. The Blender brief below uses that.

## 4. Stage 1: the Reactor Warden, "the Pile"

**Pitch.** A wounded titan. A pre-collapse reactor vessel that was a war machine's heart, fused onto the beacon mast by its own meltdown and still burning. Its wound is its face. The first god you meet is already dying, and that is how you learn gods can die.

**Silhouette.** Slumped and hunched over the mast like a beast hugging a post. Two massive shoulders above the jaws: the left cast clean, the right melted into frozen drips of slag that run down over Jaw_1 and Jaw_2 (the scar side). On its back three thick vent stacks, a frill against the sky. Its head is the containment dome, tilted 20° down toward the player, split front to back by one jagged crack. Nothing else on it glows; the crack does.

**The face.** The crack. Cherenkov light leaks from it in a thin line while the dome is shut, widens into an eye as the dome halves part, and floods white-blue while the core stands open. The dome yaws with the jaws (child of `Jaws`), so the crack always faces you.

**Mechanics to form.**

| Mechanic (code) | Part | Wind-up (telegraph) | Fire | Grammar |
| --- | --- | --- | --- | --- |
| Pulse charge, 2 s (`_step_pulse`, `vent_charging`) | `Stacks/Stack_0..2` | Each stack swells 20% wide and 50% tall, linearly over the 2 s (`reactor_relic.gd:117-120` already does this for the relic; the Warden does not yet, §8). The crowns go from dim blue to white. The skirt vents open in sequence. | | INSTANT: ring fills edge-in in HAZARD stripes; sand reach ring; Geiger tick accelerating; Ab pedal under the band (SOUND-STORY §2). |
| Pulse (`_pulse`, `vent_erupted`) | `Stacks`, `Skirt`, `Dome` | | Stacks blast a heat column 6 m up, skirt blasts down, jaws clench, dome halves kick apart 25°. | Ratchet clang; the eruption on the beat. |
| Core window, 2.5 s (`_open(CORE_WINDOW)`) | `Dome/Half_L`, `Dome/Half_R`, `Core` | | Dome halves hinge open like petals (yaw hinges at the back of the dome), the core sphere (radius 1.3, the weak point) rises 0.4 m and blazes (code `SEAM_OPEN`, scale 1.3). The dome opens upward and forward so a stomp from the drop lands on it: `contact_part` counts a stomp or slam within 3.2 m. | `weak_point_opened`: the crack becomes an eye. Class-colour rim on the core (breaks now, plating 0). |
| Core closes | `Dome` | | Halves close over 0.4 s, ease in (departure). The crack line stays lit dimmer than before each cycle: it never fully heals. | |
| Plating 45 / shred | `Jaws` | | Slag crust flakes off the scar-side jaws first (the shred seams are cut through slag, not enamel, on Jaw_1 and Jaw_2). | Amber seams (code). |
| Lesson `plate` | none | | Nothing more. The Pile is the simplest fight on purpose (§10). | |

**Menace language.**

- Posture: hunched, weight forward over the mast, shoulders higher than the dome. It reads as something that fell onto the mast and never got up.
- Reaction to the ball: the dome yaws with the jaws (code turn rate 3.0). When the ball enters reach the heat shimmer over the stacks doubles and the crack's light pulses once per second (idle) instead of once per four (out of reach).
- Scars: the slag shoulder, a sheared stack crown on Stack_2, sand filling the crack's lower third (it was buried; the Fleet dug it out; the dig line runs across the footing at 1.2 m).
- The hostage: the slag has run down the mast and set. The mast is welded into the Pile's chest. Breaking the Warden is breaking that weld: at the unseal the slag collar shears and the mast stands free.
- Ball culture: a lift is the one thing that beats a ball outright (a ball in the air steers nothing). The Pile's pulse is a reactor SCRAM turned outward, and every Warden inherits it because the base is the same casing: the anti-ball counter humans built last is the one the Fleet dug up first.

**Break states** (read from `integrity()`, look only, synced to the music thresholds):

| Integrity | Body | Light | Music |
| --- | --- | --- | --- |
| 100 to 50% | Whole. Crack lit thin. | Seams dim (0.8). | Club at 129. |
| 50% (`WARDEN_LIFT_AT`) | The slag shoulder shears off and drops beside Jaw_2 as a slab (a prop, visual only, outside the collider). Stack_2's crown falls. | The shoulder wound leaks Cherenkov; crack lit wide. | Key lift, lead up an octave. |
| 75% (`WARDEN_BUILD_FROM`) | The dome no longer closes fully: a 10° gap stays, and the core shutter (`Core/Shutter`, a second inner iris) is what closes between windows, so the weak point is still gated by the pulse. All three stacks vent continuously. The ground ring inside 6 m blackens (decal). | Every seam at open brightness. The crack is a permanent eye. | Sinister build. |
| Unseal | The slag collar shears, the jaws release and sag outward, the dome halves fall inward, the stacks go dark one by one. | The core flares white once, then dark. One last blue flicker in the crack 2 s later (STORY-THREADS §4: never resolved). | The drop. |

**Animation beats** (rig-ready; every timing is code's):

- Idle out of reach: 4 s breath (dome rises 0.05 m and settles); crack glow 0.25 Hz.
- Idle in reach: 1 s crack pulse; stacks shimmer; jaws track.
- Pulse charge (2 s, linear): stacks swell; skirt vents open in sequence; crowns blue to white.
- Pulse (1 frame plus 0.3 s recoil): stacks blast; skirt blast; jaw clench; dome halves kick.
- Core open (hold 2.5 s): halves at 25° (75%: 35°), core risen and blazing.
- Core close (0.4 s, ease in).
- Struck on the core (per hit): dome halves shudder 0.1 s; core dims one frame.
- Break 50% (0.8 s): shoulder shear, slab drop, dust outside the footprint (RR-05).
- Break 75% (0.6 s): dome gap set; stacks vent on.
- Unseal (2.5 s): collar shear, jaw release, dome collapse, core flare, dark; 70 ms hit-stop is code.

## 5. Stage 2: the Hive Warden, "the Choir"

**Pitch.** A legion with one will. A drone carrier grown around the mast like a hornet nest around a branch: its true face is the ten-drone rack hovering in front of it, pointed at you, and its own eye stays shuttered until you bowl its army down. You cannot hit what you came for; you have to go through everything it owns first.

**Silhouette.** Tall and leaning, the opposite of the Pile: a comb tower of hexagonal cast cells rising off the deck and wrapping the mast, tilted 12° toward the player. At its top the queen cell, a hexagonal iris shutter 2.2 m across, facing 45° up and forward (so it is a stomp target from the drop and a weapon target from the ground). Two wide louvre wings fold at its sides. The rack of ten drones hangs in the air 9 m in front (code `GUARD_OFFSET`), apex toward you, a spearhead. Three brood caps bulge on the deck.

**The face.** Two faces, by design. Before the scatter: the rack, ten identical seams in a spearhead, the unison buzz. After the scatter: the iris, opening like an aperture on the queen cell, swollen and lit. The shift from the first face to the second is the fight's lesson, read by eye.

**Mechanics to form.**

| Mechanic (code) | Part | Wind-up (telegraph) | Fire | Grammar |
| --- | --- | --- | --- | --- |
| Pulse charge, 2 s | `Wings/Wing_L`, `Wings/Wing_R` (louvres), `Skirt` | The louvre wings fan open linearly over the 2 s (a wingbeat winding up); every occupied comb cell brightens in sequence, bottom to top. | | INSTANT ring; the ratchet in the swarm's buzz timbre (`owner_voice = swarm_buzz`, code). |
| Pulse | `Wings`, `Skirt` | | Wings snap shut (0.1 s), skirt blasts down; the rack in front jolts 1 m up with the ball (visual only, drones are separate bodies; a rig hook in `swarm.gd` is a proposal, §8). | A downdraft that lifts you: the wingbeat. |
| Guard rack alive (`_step_guard`, `spawn_guard`) | `Comb/Cell_0..9` (the front face) | | Ten cells lit while their drone lives; a cell goes dark when its drone dies. Respawn after 10 s: the cell blazes and its drone launches from it (spawn at the cell, proposal §8; today it spawns at 9 m). | The chord (SOUND-STORY §2) is the rack's state. |
| Rack locks and dives (`swarm.gd` LOCKED, DIVING) | the drones | The rack's LANE (code, 1.2 s) from the rack to the ball. | The rack dives down its lane at 20 m/s, stings once, peels off. | LANE fill, unison buzz snapping to the quartal chord. |
| Scatter (`on_guard_scattered`) | `Iris/Blade_0..5`, `Queen` | | The six iris blades open over 0.3 s (arrival ease-out); the queen cell (weak point, radius 1.3 at 5.1 m) swells 1.3x and blazes (code). Open 4 s. Scattered drones lose their seams and follow the ball (C11). | `weak_point_opened`; the chord breaks into single notes. Class rim on the queen. |
| Queen closes | `Iris` | | Blades close 0.4 s ease-in. | |
| Lesson `caps` (three caps, stomp or slam at plating 0, x1.5) | `Deck/BroodCap_0..2` | | Hexagonal bulges with a soft membrane top, amber-lit (code cap material), heat plumes above the jaw line (code). Struck: the membrane flashes (code energy 5.0) and a puff of dead drone shells spills out. The caps are brood cells, so the reactor's vent-cap language does not leak onto a hive. | Cap contact: the existing cap rule. |
| Plating 80 / shred | `Jaws`, `Comb` | | Comb cells crack in amber seams above the jaw seams; broken cells fall. | |

**Menace language.**

- Posture: leaning in, the comb's cells all facing the player like a wall of eyes with the lids down. The rack moves as one; the tower is still.
- Reaction: the rack re-posts between hive and ball as the ball circles (code `_post`); the louvres twitch when the ball passes 10 m; the iris blades tighten one notch when the rack scatters and then open (a flinch before the reveal).
- Scars: the comb's left face is cracked open and empty (cells whose drones never came back, STORY-THREADS fragment 5 "awaiting operator"); the right face is sealed and whole. One louvre is missing two slats.
- The hostage: the comb has grown up the mast; cells encase the lower 6 m of it. At the unseal the comb splits and slides down the mast.
- Ball culture: the rack is a bowling rack (DESIGN-NOTES W7 item 10): the swarm formed up to take a ram, because a ram is what a ball does. The hive learned bowling. The player learns that the rack is a formation to break, not a wall to avoid.

**Break states.**

| Integrity | Body | Light | Music |
| --- | --- | --- | --- |
| 100 to 50% | Whole. Rack of ten. | Occupied cells lit dim. | Club. |
| 50% | The cracked left comb face shears off and falls as a sheet, exposing the inner lattice and the mast inside it; three dead cells spill. Wing_L hangs by one hinge. | The lattice glows Cherenkov where the comb was. | Lift. |
| 75% | The iris jams: it never closes past 30%, so a sliver of the queen's light shows always (the weak point still gates on the scatter, code). Every occupied cell flickers in time with the buzz. | Queen light constant, dim; open blazes. | Sinister build. |
| Unseal | The iris blows out (blades fly), the queen goes dark, the comb splits and slides down the mast, the wings fold. The last guards lose their seams and drift down (C11's follow language: they were awaiting an operator and it is gone). | One blue flicker in one cell 2 s later. | Drop. |

**Animation beats.**

- Idle: cells breathe in a slow ripple bottom to top (4 s); louvres closed; iris shut.
- In reach: ripple 1 s; louvres half-open twitch on ball pass.
- Pulse charge (2 s): louvres fan open; cell ripple runs with the fill.
- Pulse: louvres snap; skirt blast.
- Guard cell respawn (0.3 s): cell blaze, launch puff.
- Scatter and open (0.3 s): iris flinch then open; queen swell.
- Queen close (0.4 s).
- Cap struck (0.2 s): membrane flash, shell spill.
- Break 50% (0.8 s): comb sheet shear and fall.
- Break 75% (0.4 s): iris jam.
- Unseal (2.5 s): iris blow-out, queen dark, comb slide, wing fold.

## 6. Stage 3: the Mind's Hand Warden, "the Regard"

**Pitch.** The nearest thing this world has to a god, and it is only a hand. Two long thin arms rise from the housing; one holds the beacon's light in its fingers, the other reaches for you. Between them a stalk carries one great eye that never blinks and never looks anywhere but at you, and when it has read you it shows you your own habit and closes its hand on the answer.

**Silhouette.** Tall and thin, the tallest of the three (lens at 7.6 m, code; fingers at the mast's ring above that). No torso, no head: a clamp, two arms, a stalk. `Arm_Hold` rises straight up and closes its fingers around the beacon ring at the mast's top. `Arm_Reach` (the magnet, code `MAGNET_ARM`, `MAGNET_RISE`) folds like a mantis forelimb, hand open toward you, palm sand-lit. The `Stalk` arcs forward over the mast from the back of the deck and ends in the `LensCluster`: one primary iris 1.6 m across ringed by five small lenses, one of them dead (the scar). The cluster is the weak point (radius 1.3), so the eye is literally the target.

**The face.** The eye. It is the only thing in the fight that is smooth and perfect, and it is the thing you shoot. Its iris contracts and dilates with the mechanics (below), and the trigger icon it shows you is drawn on the iris itself in HAZARD (code shows a billboard icon above the lens; drawing it on the glass is a look proposal, §8).

**Mechanics to form.**

| Mechanic (code) | Part | Wind-up (telegraph) | Fire | Grammar |
| --- | --- | --- | --- | --- |
| Pulse charge, 2 s | `LensCluster/Iris`, `Stalk` | The iris contracts linearly from wide to a pinpoint over the 2 s (a countdown you can read in the eye); the stalk lowers 0.3 m, leaning in. Skirt vents open. | | INSTANT ring; no owner voice (code: the Mind's rings carry no voice; the pulse is the base's). |
| Pulse | `Iris`, `Stalk`, `Skirt` | | The iris snaps wide in one frame and the stalk recoils up 0.5 m; skirt blast. A blink that throws you. | |
| Magnet telegraph, 1.5 s (`Magnet.TELEGRAPH`, `magnet_out` 0 to 1) | `Arm_Reach` (shoulder, elbow, wrist, `Hand/Finger_0..3`) | The arm unfolds toward the ball, rising to 3.6 m and 3.2 m out (code drives the head position; the rig solves the joints). Fingers splay. Palm sand, brightening with `magnet_out` (code). | | LANE wedge 35°, dashed rim, chevrons pointing home (code). Charge hum on Ab. |
| Magnet tug, 1.5 s (`Magnet.TUG`) | `Hand` | | Fingers curl; the palm burns amber (code); a Cherenkov thread runs from the palm to the ball (a beam, visual only). Weapon hits on the palm count now. | Tearing buzz. Amber palm is the one moment a shot on it counts (code comment). |
| Unplated by magnet, 3 s (`on_struck`, `_unplated`) | `Arm_Reach`, `Skirt`, `Jaws` | | The arm snaps back and hangs; every seam flickers (code flickers the core); jaws sag open 15°. Plating 0 on the body: the whole thing is soft for 3 s. | Class rim on the jaws (breaks now). |
| Adapt warn, 1.2 s (`ADAPT_WARN`, `mind_adapted`, `show_icon`) | `LensCluster`, `Stalk` | The five small lenses all rotate to point at the primary (a focusing); the stalk leans in 0.5 m; the trigger icon appears in HAZARD. | | The inverted class motif, once (C6). The icon is the telegraph. |
| Brace, 5 s (`_brace_left`, braced verb at 1.4x plating, lens open) | `Arm_Hold`, `Arm_Reach`, `Iris` | | The arms take the brace pose for the verb (below); the iris opens wide and blazes (code `SEAM_OPEN`, scale 1.3). The lens is the weak point for 5 s, plating 0, weapon-only (`contact_part` excludes the Mind). | `weak_point_opened("lens")`. Class rim on the eye. |
| Brace ends | `Arms`, `Iris` | | Arms return (0.5 s ease-in), iris to rest, icon off (code). | |
| Plating 140 / shred | `Jaws`, `Arm` segments | | Cracks along the arm segments' seams, amber. | |

**The brace poses** (from `habits.gd` `BRACES`, the kinds each hardens): BAR for `ram` (both arms low across the front of the deck, a bar at ball height); ROOF for `stomp` and `vault` (both arms up, forearms flat over the deck); CROSS for `rebound` (one low, one up); SHUTTER for `weapon` and `special` (the small lenses swing in front of the primary like a shutter, and the arms do not move; the primary stays open through the gap, so the weak point still reads); for `smash`, ROOF. Four poses, each readable at a glance as "that verb is answered", and each leaves the eye visible.

**Menace language.**

- Posture: still. It moves only when something in code changes, and then exactly (VISUAL-LANGUAGE §11 "still, then exact"). Idle has no breath; the only idle motion is the eye tracking.
- Reaction: the lens tracks the ball every frame (code `_lens.basis`). Proposal: past 75% the tracking snaps instead of lerps (§8). When the ball enters reach the iris dilates one step. When the ball is airborne the stalk rises to keep the eye above it.
- Scars: the dead small lens (top right); Arm_Hold's forearm has a mended seam where it was broken and re-cast (the Mind repairs itself: the only ancient that heals, told by a scar); a Fleet brass requisition tag still bolted to the footing, half torn off (STORY-THREADS T4: inventory that woke).
- The hostage: the hand holds the light. The beacon ring sits in Arm_Hold's fingers. The player breaks the Warden to make it let go; at the unseal the fingers open and the ring lights mint.
- Ball culture: the Mind's counter is the ultimate anti-ball counter: it does not fight the ball, it learns the roll. It reaches for you (the magnet, a hand-sized grab for a ball-sized thing) and it shows you what it learned. The other two families evolved a counter each; this one evolves in the fight.

**Break states.**

| Integrity | Body | Light | Music |
| --- | --- | --- | --- |
| 100 to 50% | Whole. Eye half-lidded at rest. | Eye lit dim. | Club. |
| 50% | Arm_Hold's forearm shears at the elbow and hangs by Cherenkov seam-cables, but the hand keeps its grip on the ring (the hand is cabled to the ring, so the hostage holds). The dead lens cracks and leaks light. | Cables and cracked lens glow. | Lift. |
| 75% | The cluster's shell splits so the primary iris is bare and always fully visible; the stalk kinks; tracking snaps. | Eye at open brightness always; the brace blazes white. | Sinister build. |
| Unseal | The eye goes white, then dark. The fingers open and the ring lights mint. The stalk folds down over the jaws like a dead lamp. Arm_Reach curls in. | One blue flicker in the dead lens 2 s later. | Drop. |

**Animation beats.**

- Idle: no motion but the eye. Iris at 60%.
- In reach: iris to 75%; small lenses drift.
- Pulse charge (2 s): iris to pinpoint; stalk lowers.
- Pulse: iris snap wide; stalk recoil.
- Reach out (1.5 s): arm unfold, fingers splay, palm brightening.
- Tug (1.5 s): fingers curl, palm amber, thread.
- Stunned (3 s): arm snap back and hang; seams flicker; jaws sag.
- Adapt (1.2 s): lenses focus, stalk lean, icon on.
- Brace (hold 5 s): BAR / ROOF / CROSS / SHUTTER; iris wide.
- Brace off (0.5 s).
- Break 50% (0.8 s): forearm shear, cables.
- Break 75% (0.4 s): shell split, kink.
- Unseal (2.5 s): white, dark, fingers open, ring lights, stalk fold.

## 7. The proportion proposal (for the coordinator)

The shared-base rule stands. What changes is the split of mass and tris between base and kit, which VISUAL-LANGUAGE §9 sets at 4,000 to 6,000 for the base and 800 to 1,500 per kit. At that split the kit cannot be the silhouette, and the first pass shows the result. Proposal:

- Base 3,000 to 4,000 tris (footing, skirt, four jaw plates, deck, core). Its height stays at the jaw line, about 4.5 m.
- Kit 3,000 to 5,000 tris, rising 3 to 5 m above the jaw line, and owning the silhouette above it. Three kits, so the total across a run is the same order as before.
- The jaws keep the plating dress and the shred seams; they are the "not yet / now" surface (code). The kit owns the face and the weak point.

This is a proportion change inside the existing rule, not a new base per stage; every part below the deck is shared geometry and shared materials. VISUAL-LANGUAGE §9's table row for the clamp needs its tri bands updated if the coordinator accepts it.

## 8. What W7's code would need to drive these forms (spec proposals, no silent changes)

All look-only unless marked. Owner W7 unless marked.

1. `warden_look.gd` reads `integrity()` for the break stages (50%, 75%) and swaps or animates the named nodes above; today only the badge reads it (`_update_badge`). The same thresholds as `music_engine.gd`, so the body and the band turn on the same frame.
2. `warden_kit.gd` gets per-family animation hooks driven by existing state: `charge_fraction()` for the stack swell, the louvre fan and the iris contraction; `magnet_out()` and `magnet_point()` for the arm rig (code already publishes them); `family_open()` for the dome halves, iris blades and brace pose; `adapting()` for the focusing; `braced_kinds` for the brace pose choice.
3. Guard drones spawn from the hive's cells (`fleet.spawn_guard` at the cell's world position instead of 9 m out), and a cell's light follows its drone's life. Gameplay-adjacent (spawn point moves 9 m), so W7 decides; the rack still posts at 9 m.
4. The Mind's icon draws on the iris glass instead of a billboard above it (`WardenKit._icon`), keeping HAZARD and the 24 px readability rule.
5. Past 75% the Mind's lens tracking snaps (a step every 0.2 s) instead of lerping. Look only.
6. A `warden_broke(stage, fraction)` fact on the bus at 50% and 75% would let presentation, audio and the look read one source (VISUAL-LANGUAGE §10 item 1). Today audio reads `integrity` itself.
7. The unseal sequence needs 2.5 s of body animation after `enemy_killed`; `combat.gd` frees the Warden on death today (not read in this pass; ASSERTED). A corpse node that plays the unseal and the flicker, then frees, is the smallest change.

## 9. Where the fight itself is weak, and the better alternative

The form can only be as good as the fight. Read plainly:

1. **The Warden never attacks you.** By spec it is "a lock, not a fight you can lose to" (DESIGN-NOTES combat item 18): it never moves, the pulse only lifts, and the 10 damage reaches a ball inside 6 m. The threat during the fight is the packs the director sends (W7 items 15 to 17), not the Warden. That is right for momentum, and wrong for "being versus god": a god that cannot hurt you is furniture. The fix is not damage. It is **consequence in the family's own currency**, telegraphed and dodgeable: the Pile's pulse leaves a fallout crater (the relic's 5 s burning ring, `reactor_relic.gd` `CRATER`) under the core ring, so the arena floor fills with hazard as the fight runs and the 75% stage is a floor you have to route; the Choir's rack dives (it already does); the Regard's brace is answered by a strike (below). Gameplay change; proposed to W7 and the coordinator.
2. **The stage 3 Warden, the god, is the most passive of the three.** The Mind's Hand (the counter unit, `mind_hand.gd`) commits a strike lane and hits for 10 with a shove; the Mind's Warden only reads, shows and braces. The god does nothing but harden. Alternative: the Warden answers with your own verb. On the adapt, after the 1.2 s warn, `Arm_Reach` commits a LANE strike down the line the ball last used for that habit (ram: along your approach line; stomp: a ring under you; weapon: a beam back along your firing line), the same 1.4 s warn and 10 damage as the hand, then the 5 s brace. "It quotes your motif wrong" becomes "it quotes your move wrong". One lane per 10 s, so the fight's rhythm is unchanged. This is the change that most earns "part of its design has to encompass its main set of boss mechanics".
3. **The pulse is the base's, not the reactor's.** All three families pulse identically, so the reactor kit's claim that "the pulse is the reactor venting" (`warden.gd:33`) adds only a 2.5 s window. Item 1's crater fixes it: only the reactor's pulse scars the ground.
4. **Nothing changes at 50% and 75% but the music.** The thresholds are felt in the ears and not the hands. Smallest gameplay change: at 75% the family cycle shortens (pulse 6 to 4.5 s, adapt 10 to 8 s, guard respawn 10 to 7 s). Angrier and more exposed, since every cycle also opens the weak point more often.
5. **The magnet lesson and the Mind kit are the same limb, and the caps lesson on the hive is reactor language.** Both are form fixes made above (the magnet is Arm_Reach; the caps are brood cells). No code change; the lesson data stays per stage.
6. **The Warden is not where the danger is, but it is where the camera looks.** The reveal framing in §10 uses that: the packs arrive while you are looking at the god.

## 10. The journey

Andrew's frame: a hero's journey up the map, mortal against god, insurmountable at first sight and fair in the hands. Three rungs, then the man who woke them.

| Stage | Rung | What the player is | What the Warden is | The gap, and how it narrows |
| --- | --- | --- | --- | --- |
| 1 | The call. A wounded titan. | A light ball with one pick. | The Pile: huge, burning, already dying. | The first sight says impossible; the first crack (shred seams on the jaws) says otherwise. Its wound is the lesson: the dome opens on its own pulse. You learn gods have weak points. |
| 2 | The threshold. A legion with one will. | Heavier, two picks, a habit forming. | The Choir: you cannot hit what you came for. | The gap is numbers. Bowling through ten bodies to reach one is the ball's whole argument. The lesson is that the army is the door. |
| 3 | The ordeal. The eye. | Heavy, three picks, a build with a name. | The Regard: it knows what you do and shows you. | The gap is knowledge. It shows you your own icon and hardens against it; the answer is to do the other thing. The build you grew is the thing it reads, so growth is what it fights. Never even: it is still taller, still calmer, and it still holds the light. |
| Arena | The return. | The player who broke three gods. | Brindle, a mortal who thinks he owns them, in the Requisition running on a dug-up core (C10). | The three stages quoted in reverse (C2). The final Cherenkov flicker across the housings on the summary says the gods are not dead (DESIGN-V2 §15, primer ruling 8). |

**The moments that carry mortal versus god, per stage.**

- **First sight.** From the 14 m entry drop, 150 m out (`warden_look.gd:8`): the badge and the kit's crown against the sky. Stage 1: the frill of stacks and the crack's line. Stage 2: the spearhead of ten seams hanging in the air, then the comb behind it. Stage 3: the eye catches the light and it is already looking at you. Camera: the gameplay camera, no cut; the reveal is the drop itself, so momentum is untouched. Sound: `pack_arrived` for the family plus the Warden's timbre on the first ring entry; the club pivot on `warden_engaged` (audio item 34).
- **First crack.** The first shred seam on a jaw (25% stripped) with the class-colour rim: "not yet" turns to "now" on the biggest face in the fight. It answers "impossible" within the first ten seconds of contact.
- **50%.** The key lift and the shear: something falls off the god. The player did that.
- **75%.** The sinister build and the permanent wound: the god is angrier and more open. If §9 item 4 lands, faster too.
- **Unseal.** The drop on the beat, 70 ms hit-stop, the FOV punch and the star over the beacon (audio item 25), the jaws letting go of the mast, and the mast's ring lighting mint: the light is yours. Then the flicker nobody is meant to notice the first time.

**Scale by presence, not size.** The Warden stays 7 to 9 m tall so the gameplay camera stays honest. What makes it huge: the reveal from above (it fills the basin floor from the drop); the lean (every Warden tilts toward you); the light (its family light is the only glow in the arena, and the arena is lit by it); the sound (the only tonal sounds in the game, sitting still while the band moves); and the arena bending around it (the Pile's craters, the Choir's orbiting rack, the Regard's eye and every Mind's hand in the arena turning to face you together).

**A friendly ancient.** The hero pass (`design-v2/HERO-SPHERE.md`, in parallel) may add a friendly ancient AI pilot who chose the living. If it exists, the three Wardens are its fallen kin, and the flicker at each unseal is addressed to it. One line in the codex world page per Warden ("It knew me") is enough; the fights need no change, and the thread stays unresolved (STORY-THREADS §4).

## 11. Modelling briefs (for the Blender writer)

Style per VISUAL-LANGUAGE §9: chunky low-poly, flat colour per slot, nothing below gameplay-distance detail. Material slots as named there: `ancient_enamel` (petrol, value and saturation capped at 45%, never emissive, sand dust on top faces), `ancient_light` (Cherenkov, emissive, in charcoal grooves twice the seam width), `bare_metal` (rubbed jaw edges), plus `hazard_glass` proposed for the Mind's iris (a glass slot that takes the HAZARD icon). No bolts, welds or brass on any ancient part; the one brass tag on the Regard's footing is `requisition_tag`, torn.

Every animated or telegraphing part is its own object with the node name below and its pivot placed at the hinge. Pose set per Warden: `idle`, `idle_reach`, one pose per telegraph, one per fire, one per weak-point open, `break_50`, `break_75`, `unseal`. Deliver the base once and each kit as a separate file that parents to `Deck`.

**Base (shared): "the Housing"**

- Silhouette callouts: half-buried footing with a dig line; eight skirt vents under the jaw line; two C-jaws each cast in two plates (four plates, four yaw pivots); a heavy inward lip on each plate; the deck between; the core in the mouth; a mast socket.
- Tris: 3,000 to 4,000. Slots: `ancient_enamel`, `ancient_light` (skirt seams, core), `bare_metal` (lips, plate edges).
- Nodes: `Footing`, `Skirt`, `Skirt/Vent_0..7`, `Jaws`, `Jaws/Jaw_0..3`, `Jaws/Jaw_N/Lip`, `Jaws/Jaw_N/Seams_0..2` (thin strips proud of the outer face, hidden by default), `Deck`, `PulseCore`, `Mast_Socket`.
- Poses: `idle`, `pulse_charge` (vents open in sequence; store as a 0 to 1 blend), `pulse` (vents blasted, jaws clenched), `sag` (jaws 15° open, for the stun), `unseal` (jaws released outward).

**Kit 1: the Pile (reactor)**

- Callouts: two shoulders, left clean and right slag (the slag runs over Jaw_1 and Jaw_2); three vent stacks on the back with crowns, Stack_2's crown sheared; the containment dome, tilted 20° down, split by one crack front to back; the slag collar on the mast. Scale: shoulders to 6 m, stacks to 7.5 m, dome top 6.5 m.
- Tris: 3,500 to 5,000. Slots: `ancient_enamel`, `ancient_light` (crack, stack crowns, shoulder wound after 50%), `slag` proposed (charcoal, matte, dripped; else `rubber`).
- Nodes: `Shoulder_L`, `Shoulder_R` (detaches at 50%; ships with its slab as `Shoulder_R_Slab`), `Stacks/Stack_0..2` (scale pivots at their base), `Stacks/Stack_N/Crown`, `Dome` (yaw with jaws), `Dome/Half_L`, `Dome/Half_R` (hinges at the back), `Dome/Crack` (light strip), `Core`, `Core/Shutter`, `Collar`.
- Poses: `idle`, `pulse_charge` (stacks swollen 1.2 x 1.5), `pulse` (blast), `core_open` (halves 25°, core risen), `core_open_75` (35°), `break_50` (Shoulder_R gone, Crown_2 gone), `break_75` (halves gapped 10°, shutter closed), `unseal` (halves fallen in, collar sheared).

**Kit 2: the Choir (swarm hive)**

- Callouts: a hexagonal comb tower leaning 12°, wrapping the mast, its left face cracked and empty and its right face sealed; the ten guard cells on the front face; the queen iris (six blades, 2.2 m) facing 45° up and forward; two louvre wings; three brood caps on the deck. Scale: comb top 6.5 m, iris centre 5.1 m, wings 3 m span each.
- Tris: 3,500 to 5,000 (instance the cells). Slots: `ancient_enamel`, `ancient_light` (cells, iris rim, queen), `membrane` proposed for the brood caps (amber, translucent; else `ancient_light` tinted at runtime by the cap material code already owns).
- Nodes: `Comb`, `Comb/Face_L` (detaches at 50%, ships with `Face_L_Sheet`), `Comb/Face_R`, `Comb/Cell_0..9` (each with a light strip), `Iris`, `Iris/Blade_0..5` (pivots on the rim), `Queen`, `Wings/Wing_L`, `Wings/Wing_R` (hinges at the comb), `Deck/BroodCap_0..2` (at the code's cap points: ring 1.6 m, three at 120°), `Lattice` (inner, visible after 50%).
- Poses: `idle`, `pulse_charge` (wings fanned), `pulse` (wings shut), `queen_open` (blades open, queen 1.3x), `queen_jammed` (blades at 30%), `break_50` (Face_L gone, Wing_L hanging), `break_75` (jammed), `unseal` (blades gone, comb split, wings folded).

**Kit 3: the Regard (the Mind's hand)**

- Callouts: two long thin arms of three segments each, joints as cast balls in seam rings; `Arm_Hold` straight up with its fingers around the mast's ring; `Arm_Reach` folded, hand open, four fingers; the stalk arcing forward over the mast to the lens cluster (primary iris 1.6 m, five small lenses, top-right dead); a mended seam on Arm_Hold's forearm; a torn brass tag on the footing. Scale: lens 7.6 m (code), fingers at the ring height the world sets, reach hand at 3.6 m and 3.2 m out when extended (code).
- Tris: 4,000 to 5,000. Slots: `ancient_enamel`, `ancient_light` (joint rings, cables after 50%), `glass` for the lenses, `hazard_glass` proposed for the primary iris, `bare_metal` (finger tips, palm), `requisition_tag`.
- Nodes: `Arm_Hold/Shoulder`, `/Elbow`, `/Wrist`, `/Hand`, `/Hand/Finger_0..3`, `Arm_Hold/Cables` (hidden until 50%), `Arm_Reach/Shoulder`, `/Elbow`, `/Wrist`, `/Hand`, `/Hand/Finger_0..3`, `/Hand/Palm` (takes the magnet material), `Stalk/Seg_0..2`, `LensCluster`, `LensCluster/Iris` (blend shape or blade set, 0 pinpoint to 1 wide), `LensCluster/Small_0..4` (Small_4 dead), `LensCluster/Shell` (splits at 75%).
- Poses: `idle` (iris 60%), `pulse_charge` (iris pinpoint, stalk down), `pulse` (iris wide, stalk up), `reach` (arm extended per code's point), `tug` (fingers curled), `stunned` (arm hanging), `adapt` (small lenses focused, stalk in), `brace_bar`, `brace_roof`, `brace_cross`, `brace_shutter`, `break_50` (forearm sheared, cables), `break_75` (shell split, stalk kinked), `unseal` (fingers open, stalk folded).

## 12. Open identity questions for Andrew

At most three, each with the default this document uses.

1. **Should the stage 3 Warden strike back (§9 item 2)?** Default: yes, one LANE strike in your own verb per adapt, same numbers as the Mind's hand. The alternative keeps it as a pure reader, which is safer for momentum and weaker as a god.
2. **Names on the codex page.** Default: the Pile, the Choir, the Regard, as codex enemy entries only, never on the HUD. The alternative is family names only (Reactor Warden, Hive Warden, Mind Warden).
3. **Does the god hold the light?** Default: the Regard's hand grips the beacon ring itself, and the unseal is it letting go. The alternative keeps the ring free and the jaws as the only grip, which is cleaner for W6's mast geometry but loses the fight's best image.
