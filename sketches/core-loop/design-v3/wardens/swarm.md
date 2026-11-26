# Warden kind sheet: `swarm`, the swarm remnant

The Warden kind for world 2, The Dig. Unit K-W2, wave 13, 10 October 2026. Status: **draft for Andrew's click approval** of board `warden-swarm`. Every number is a starting value to tune in play unless it cites code. Paths are under `sketches/core-loop/` unless they start with `adr/`, `docs/` or `BIBLE.md`.

Read with [PARK.md](../PARK.md) section 7 (the kinds and mountings), [TADR-011](../../../../adr/TADR-011-park-terrain-and-warden-kinds.md), the reactor sheet [reactor.md](reactor.md) for the shared layout, and the two stage pages, [3-park_pit.md](../park/stages/3-park_pit.md) and [4-park_sinkhole.md](../park/stages/4-park_sinkhole.md).

| Mounting | Stage | Where | Mechanism | Variant |
| --- | --- | --- | --- | --- |
| `headframe` | 3, `park_pit` | on the hoist rope inside the 120 m headframe on the pit floor | it rides the hoist: 12 s up and down, low for contact, high for the line | `""` |
| `sinkhole` | 4, `park_sinkhole` | a nest on the sinkhole's south wall over the caisson pool | the pool rises one step per chunk lost, lifting the floor toward the nest | `brood` |

Both rows match PARK.md:426-427.

## 1. What it is, and how it reads at a glance

A swarm remnant is a pre-collapse machine that is many machines: a hive of identical drones round a queen cell, still running the last job it was given. The fiction's rule for the kind is "it counts and it carries". The deep-works crews log it counting every bolt (`src/core/lore_rows.gd:215`, `224`), and in the pit it works the hoist the miners left. Both mountings put it where the miners moved things vertically, and its mechanism on each moves the fight floor or the fight itself up and down.

**Today.** Every Warden is the shared Fleet-built clamp (`src/combat/warden_look.gd:9-12`, `34-43`) with a family kit on top. The swarm kit is a crown of hexagonal hive cells round a queen cell, dark behind its shutters until the guard scatters, then lit and swollen in a stagger (`src/combat/warden_kit.gd:13-14`, `81-95`). The drones it makes are small flat cast triangles, the only identical things in the game on purpose (`src/combat/swarm_remnant.gd:6-7`).

**At a glance against the other two kinds** (same table as `reactor.md` section 1, swarm column expanded):

| Layer | Reactor relic | Swarm remnant | The Mind's hand |
| --- | --- | --- | --- |
| Silhouette | A squat drum with three upright stacks: a pile | A lumpy dome of many small hexagonal cells round a queen cell (`warden_kit.gd:13-14`): a hive | An open hand with a lens on a stalk: a hand |
| Where it lives | On the water: the dam face, the flume head house | In the earth: on the hoist in the headframe, on the sinkhole wall | In the air; the only kind that never touches the ground |
| Motion | Vertical: stacks lift on the pulse, water and slag fall | Crawling and rippling: drones walk over it, shutters open in waves, the guard scatters and reforms | Tracking and travelling: the lens follows you and the whole body moves (the tilt, the flight) |
| Light | One steady green that breathes with the charge | Many green pinpricks in the cell seams, rippling base to crown | One big point that turns toward you; five small lenses blink the quote's rhythm |
| Sound | The Ab tritone pedal and a Geiger tick (SOUND-STORY.md:59) | A thin G5 buzz that locks into a quartal chord (SOUND-STORY.md:60) | Your own class motif, inverted and wrong (SOUND-STORY.md:61) |
| Colours the band | Yes, the only one (SOUND-STORY.md:69, 74) | No (SOUND-STORY.md:69) | No, never (SOUND-STORY.md:280) |
| What you play around | It never moves. Its mounting turns the pulse into terrain: a road up to the core (the sheet) or lanes to dodge (the slag) | A guard stands between you and it, and its reach changes on a vertical rhythm (the hoist, the rising pool) | It moves you. A latched ball is thrown by the tilt or carried by the flight, so the rope is the fight |

The read rule: **many small identical things** means swarm. A player who sees one cell or one drone knows the whole kind.

### 1.1 The body

K-F gives the kind its own body (unit KF6, section 11) on the same clamp base, so the colliders and posture reads stay (`warden_look.gd:31-32`).

- **The hive dome.** About 10 m across and 8 m tall (start): 19 hexagonal cells in three rings (the queen, 6 round it, 12 outside), stacked into an uneven dome, not a smooth one. Each outer cell is about 1.6 m across with a three-plate iris shutter. Enamel stays dull petrol like the reactor's (`warden_kit.gd:6-9`), so the two ancients share a maker.
- **The queen cell.** In the middle and on top, 1.6 m across and taller than the rest, with its own heavier shutter. It is the family weak point, `queen` (`src/combat/warden.gd:51`), open only in a stagger (`warden.gd:183-184`).
- **Drones on the body.** Six to ten flat cast triangles crawl over the dome at all times (start), the same mesh as the enemy drone (`swarm_remnant.gd:263`). They are dressing, not enemies: the rule and the guard live in `swarm.gd`.
- **Hardpoints.** Three grip cells, each a cell with a thick green rim, for the harpoon (section 4).
- **Mounting dress.** On the headframe the clamp's jaws close round the hoist cage's guide rails, so the hive hangs in the cage and the rope runs from its crown to the sheaves. In the sinkhole the jaws bite the gallery ring's inner timbers, and the dome hangs out over the pool on the wall, with brood comb spreading 10 m across the rock round it.

### 1.2 Light

- uranium-glass green (#9dff3c) only, the ancients' colour (`Roster.ANCIENT_LIGHT`, cited in `warden_kit.gd:33`). It lives in the cell seams as many small points, never one big glow.
- The seams use the kit's existing levels: dim at rest, brightening across the charge, blazing while the queen stands open (`warden_kit.gd:19-20`).
- Stage 4's light column rises from the nest, 4 m wide. It dims when the guard is down and dies on the break.
- No warm light on the body or the mounting. The wave 11 lamp veto (VX8, `364e1e6`) holds on both Dig stages: no light pools, no daylight shafts, no amber.

## 2. The shared posture grammar it keeps

Every number here is today's, so the fight reads like every other Warden.

- **Telegraph and pulse.** Inside the reach ring the Warden charges for 2 s every 6 s (`PULSE_TELEGRAPH`, `PULSE_CYCLE`, `warden.gd:40-41`). The pulse gives a ball in the reach ring 10 m/s straight up for one tick, planar speed untouched, and a ball in the 6 m core ring also takes 10 damage (`warden.gd:18-23`, `42-44`).
- **Posture.** A ram, stomp or slam adds 30 times a heft multiplier between 0.2 and 1.5; a smash adds 45; anything else 1.5, or 3 while the Warden charges (`src/combat/boss_posture.gd:9-14`). Posture drains at 12 a second after 3 s without gain (`boss_posture.gd:15-16`).
- **Stagger and break.** At 100 the Warden staggers for 4 s and the queen opens (`boss_posture.gd:17`, `warden.gd:526-542`); the pulse pauses (`warden.gd:360-361`). Four chunks, at most one lost per stagger, shattered at speed tier 2 or better (`boss_posture.gd:18-19`). A stomp or slam within 3.2 m in plan of the Warden hits the open queen (`warden.gd:50`, `52`, `231-235`).
- **The guard.** The swarm keeps a guard near its body, respawned 10 s after it falls (`GUARD_RESPAWN`, `warden.gd:46`, `206-222`). The cruise-or-faster ram that scatters a drone rack pays 25 posture once (`GUARD_RACK_POSTURE`, `warden.gd:24-27`, `48`, `194-203`). That is the swarm's own way to build posture, and the stage 4 hint already teaches it: "Bowl through its guard rack, then smash the core." (`src/core/alpha_defs.gd:94`).
- **The brood guard.** On the `brood` variant the guard is a lamp swarm (`warden.gd:225-228`), and the first tick it is down fires the `brood_dark` discovery (`warden.gd:211-213`). KF3 must check whether a lamp guard's scatter pays the 25 posture: `_on_guard_struck` reads `enemy.get("swarm")` and `guard.following()` (`warden.gd:197`), which `lamp_swarm.gd` may not provide. If it does not, KF3 pays the same 25 for the ram that kills the last lamp, so both mountings share one posture rule.
- **The drop finisher.** At the Warden the harpoon is a drop finisher, never a bowl hammer (PARK.md:410): release above the open queen, then haul.

The kind adds no new posture numbers. Each mounting changes where the fight happens, not how posture fills.

## 3. The mechanism each mounting gives it

One mechanism per mounting (PARK.md:420-427). Both are vertical: the swarm carries.

### 3.1 `headframe` (stage 3): it rides the hoist

The hive hangs on the hoist rope inside the headframe over the main shaft at `(0, 255)` (live `park_pit.json` anchor `[0, -108, 255]` rising to `[0, -78, 255]`; originally drafted at `y -96` to `y -66`). It runs a 12 s cycle (`DWELL 4.0`, `MOVE 2.0`, `RISE 30.0`, `BRAKE_DROP := 0.9 s` in `src/combat/warden_swarm.gd`):

| Phase | Seconds | Hive centre (drafted / live `park_pit.json`) | What it means for the ball |
| --- | --- | --- | --- |
| Low dwell | 0 to 4 | `y -96` drafted (`y -108` in `park_pit.json`), at the collar on the pit floor | rams, stomps and slams reach it; the guard rack forms on the floor between it and the ball; the charge runs in the last 2 s and the pulse fires at 4 s |
| Rise | 4 to 6 | 30 m up at 15 m/s | a latched ball is dragged up with it |
| High dwell | 6 to 10 | `y -66` drafted (`y -78` in `park_pit.json`), under the tipple deck | out of ram reach; the latch window; the charge runs in the last 2 s and the pulse fires at 10 s |
| Fall | 10 to 12 | back to the collar | a latched ball's line goes slack; the hive lands for the next low dwell |

- **Stagger.** The hoist brakes and the hive drops to the collar in `BRAKE_DROP := 0.9 s` (`warden_swarm.gd`; drafted `1.0 s`) with the queen open for the 4 s stagger. The queen is at floor level, so a slam on the floor finishes, and so does a drop from the tipple deck 40 m up (about 2.9 s of fall, inside the 4 s window if the ball leaves the deck within 1 s).
- **Throw.** A ball latched through the rise keeps 15 m/s upward when the hive stops at the high dwell. That lifts it about 11 m, over the tipple deck's rail 6 m above (estimate at 9.8 m/s squared; the game's gravity may differ). The hoist throws you onto the finisher's platform.
- **Engage ring.** The hive moves 30 m vertically and 0 m in plan, so the landmark's `reach_m` of 42 already exceeds its path (PARK.md:431). The pulse ring stays 30 m (`DEFAULT_REACH`, `warden.gd:39`) and follows the hive, drawn on the floor under it. At the low dwell the pulse pops floor balls; at the high dwell it pops a ball hanging on the line.
- **Why.** PARK.md:426 asked for the cage rising and falling with a 4 s exposure. This makes the two dwells two different jobs: the ground fight and the line fight alternate every 6 s, which is the pulse cycle you already read.
- **Deviation from PARK.md:426.** The finisher drop comes from the tipple deck, not the sheave wheel. The sheaves sit at y +20, 86 m above the high dwell and outside the 45 m rope (`src/movement/tuning.gd:18`, via PARK.md:414). It is item 1 on the veto list.

### 3.2 `sinkhole` (stage 4): the pool rises

The brood nests on the sinkhole's south wall at (0, 388), centre y -99, over the caisson pool's south edge. It does not move. A lamp swarm guards it (the `brood` variant, `warden.gd:31-32`, `225-228`). The fight floor is the pool: water 1.2 m deep at most over a floor at y -120 (PARK.md:294), 21 m below the nest.

- **One step per chunk.** Each chunk lost sheds a ring of outer cells into the pool, and the floor rises 5 m as they settle: -120, then -115, -110, -105 (start). The break floods the pool to the gallery ring at y -100. The water stays at most 1.2 m deep over the new floor, so a ball always rolls through.
- **Telegraph.** A 2 s swell (`pool_swell`, a new form) bulges the water on the downbeat after the chunk shatters, then the floor rises over 3 s.
- **Never under the ball.** The rise waits while a ball is grounded on the pool floor, using the hold rule (`src/world/terrain_event.gd:7-11`, PARK.md:308). It goes while the ball is on the ring, airborne or on the line. If the ball stays on the floor, the step goes on the next pulse, which already lifts a floor ball 10 m/s straight up with planar speed untouched (`warden.gd:18-23`); the floor rises beneath the airborne ball, so nothing ever lifts a grounded ball.
- **Why.** It is PARK.md:427's mechanism. It makes progress physical: each chunk you break brings the queen 5 m closer, so the fight gets easier as you win it, which keeps momentum with the player. It mirrors the stage's lore: "Level rises when something breaks." (`mining_pump_caisson`, stage 4 page section 11).
- **The reach.** The nest sits 21 m above the first floor, so early staggers come from the line and the pulse. After two steps the floor is 11 m below the nest, and the pulse's 10 m/s pop carries a floor ball most of the way. The guard circles over the water inside the 30 m pulse ring.

### 3.3 The guard, per mounting

| Mounting | Guard | Where it forms | How to beat it |
| --- | --- | --- | --- |
| `headframe` | the drone rack (`warden.gd:228`) | on the pit floor at a drop point near the hive (`warden.gd:220`), 9 m out (`GUARD_OFFSET`, `warden.gd:47`), between the hive and the ball | ram the forming rack at cruise or faster for 25 posture; the scattered drones follow you and become pins on other enemies (`swarm_remnant.gd:9-11`) |
| `sinkhole` | a lamp swarm (`warden.gd:226-227`) | over the pool, inside the pulse ring | bowl the pool at cruise through the lamps, where the lure never bends you (`src/combat/lamp_swarm.gd:7-9`); the nest goes dark when the guard is down (`brood_dark`) |

The stage 4 `hive_cells` home adds drone racks from the gallery ring (stage 4 page section 6). Lead them into the lamp guard as pins, which is the `awaiting_operator` codex lesson (`src/combat/codex_entries.gd:162`).

## 4. The harpoon anchor

Every Warden is a harpoon anchor (PARK.md:412-418). The framework is unit KF1; this is the swarm's placement of it.

| Behaviour | Rule (PARK.md:414-418) | On the headframe | In the sinkhole |
| --- | --- | --- | --- |
| Latch | 3 hardpoints rimmed in green, bitten from rope range (45 m) | three grip cells on the hive's crown; they move with it | two gallery-ring posts 20 m either side of the nest (y -96) and one grip cell on the nest's crown |
| Ride | swing as on a world line; the winch shortens it; no drop inside the minimum rope | hang under the hive and ride its rise and fall | a pendulum over the pool from a ring post, or an orbit round the nest |
| Fire from the line | the weapon slot fires while hanging; each bolt adds 1.5 posture, 3 during the charge (`boss_posture.gd:11-12`) | at the high dwell, hang below the hive and shoot it while the floor rack reforms | hang over the pool and shoot the nest while the lamp guard circles below |
| Drag | when the mounting moves, the anchor moves | yes: 15 m/s up for 2 s, then slack on the fall | none: the nest never moves; the pool rises under you instead |
| Resist | once per pulse cycle a lined hardpoint flares for the 2 s charge, then drops the line on the pulse; the ball keeps its velocity plus the lift | the snip (below) | the snip (below) |

**The snip: how it resists.** The swarm shows PARK.md's shrug with drones. During the 2 s charge, a file of three drones runs up the lined rope from the hardpoint toward the ball. The rope's green flickers and the buzz rises along it. On the pulse they cut the line, and the ball keeps its velocity plus the pulse's 10 m/s lift if it is inside the reach ring. You see the cut coming from 2 s away, you can let go early, and the cut never stops the ball (PARK.md:308).

**How it throws you.** On the headframe the throw is the hoist stop (section 3.1): ride the rise and the stop throws you onto the tipple deck. In the sinkhole the throw is the snip plus the pulse: a ball swinging from a ring post when the line is cut flies up the sinkhole wall, back onto the gallery ring.

**During a stagger** every hardpoint holds and no snip runs. On the headframe, a ball latched at the high dwell rides the `BRAKE_DROP := 0.9 s` brake-drop (`warden_swarm.gd`) down with the hive and arrives on the open queen, the hoist doing the drop for you. In the sinkhole, swing up over the nest from a ring post, release above the open queen and haul.

## 5. Clips

The GLB carries these clips (KF6). Lengths are starts.

| Clip | Length, blend (s) | When | What moves |
| --- | --- | --- | --- |
| `idle` | 4.0, 1.0 | default loop | Cells breathe 2%, drones crawl, shutters closed, seams at the dim level: alive and closed from range |
| `pulse` | 2.0 then 0.4, 0.1 | the charge and the pulse (`warden.gd:375-386`) | Shutters ripple open base to crown over the charge and the seams brighten with them; on the pulse every shutter slams shut and the crawling drones burst 3 m out and settle, on the music's lock (section 6) |
| `active` | loop, 0.5 | while the guard is out | Half the shutters cracked, drones circling the dome: the guard is up |
| `hoist_ride` (headframe) | 2.0, 0.3 | the rise and the fall | The hive braces on the rope, drones cling flat |
| `snip` | 2.0, 0.2 | the resist on a lined hardpoint | Three drones walk the lined rope toward the ball |
| `stagger_open` | 4.0, 0.5 | stagger open (`warden.gd:526`) | Shutters blown open, the queen swollen and blazing (`warden_kit.gd:13-14`): the finisher window |
| `chunk_shed` | 1.0, 0.8 | a chunk shatters | One ring of outer cells breaks away and falls, into the shaft on the headframe and into the pool in the sinkhole, where it is the visible cause of the pool's rise |
| `brood_dark` (sinkhole) | 1.0 then hold, 0.5 | the guard is down | Seams dim to near off and stay dim until the guard respawns: push now |
| `break` | 3.0, 2.0 | broken | The dome splits along its seams into single cells that fall; the drones drop as dead triangles; the seams go dark |

## 6. Audio motif

The swarm's sound already exists in the sound story, and the Warden uses it unchanged (`SOUND-STORY.md:60`):

- **Unison.** One high pitch, G5 (MIDI 79), buzzed in unison by many voices: a thin sawtooth pulsed in sixteenths, with no low end.
- **Lock.** When the formation locks, the unison becomes a quartal chord, D5 G5 C6 F6 (74 79 84 89): stacked fourths, many identical things in tune.
- **Scatter.** Scattering breaks the chord into single detuned notes.

The Warden's use:

| Moment | Sound |
| --- | --- |
| Idle | the G5 unison, quiet, voices drifting about 15 cents apart (start) |
| Charge (2 s) | the voices glide out of the unison toward the four chord tones, arriving on the pulse downbeat |
| Pulse | the chord locks, short and hard, then falls back to the unison |
| Rack scattered | single detuned notes, the formation's own scatter sound |
| Snip | a rising buzz along the rope, the G5 bending up a fourth to C6 as the drones reach the ball |
| Stagger | the chord holds with a tremolo for the 4 s window |
| Chunk lost | the chord loses its top voice: four chunks, four voices (F6, then C6, then G5, then D5) |
| Break | the last voices detune and stop; the stage band's next downbeat is the drop |

Two rules from the sound story hold. The swarm never enters the band; its chord is its own sound (`SOUND-STORY.md:69`, `280`). The band keeps playing under it. Per mounting: the hoist's winch whine is tuned to G, so the machine sings the swarm's note on the headframe; in the sinkhole the cave's `drip_keys` layer plays chord tones, and each pool step is a pitchless low water swell, so the swarm stays thin.

## 7. Posture bands

| Arm | Headframe (stage 3 numbers: plating 130, hp 950, `alpha_defs.gd:84`) | Sinkhole, brood (plating 150, hp 1,100, `alpha_defs.gd:94`) |
| --- | --- | --- |
| grown median | 25 to 45 s | 25 to 45 s |
| small median | at least 2 times grown | at least 2 times grown |
| camper | never breaks it | never breaks it |
| world 2 pilots (`alpha_posture_bands_w23_test.gd`) | 24.5 to 128 s, re-measured on the park after KD3, dated header | the same after KD4 |

The evidence behind the world 2 row. PARK.md:548 has `tests/posture_bands_test.gd` gain a band per kind. Today's world 2 Wardens are pinned in `tests/alpha_posture_bands_w23_test.gd`:

| Number | Value | Source |
| --- | --- | --- |
| World 2 Warden band | 24.5 to 128 s (0.7 x 35 and 1.6 x 80) | `alpha_posture_bands_w23_test.gd:27`, `alpha_posture_bands_test.gd:32` |
| Stage 3 median today (reactor, `meltdown`) | 62.67 s | `tools/posture_sweep.md:246` |
| Stage 4 median today (swarm, `brood`) | 39.66 s | `tools/posture_sweep.md:246` |
| Predicted, `headframe` | 60 to 85 s (the hive is out of ram reach 8 s in every 12) | this sheet |
| Predicted, `sinkhole` | 45 to 70 s (the first stagger is from 21 m below) | this sheet |

**The band for the swarm kind:** grown median 25 to 45 s and small at least twice grown on each mounting, measured with the latch arm on (the table above); the 24.5 to 128 s world band applies to the pilots row only (historical coordinator ruling at KF3 merge, 2026-10-11; `KNOWN-FAILING.tsv` is the sole live red ledger while `tests/QUARANTINE.tsv` is an empty header-only stub). Two mechanism checks ride with it, so a win that skips the mechanism fails the test instead of passing quietly:

- `headframe`: at least half the seeds land a stagger during a low dwell and at least one finish from a latch.
- `sinkhole`: the pool rises one step per chunk lost in every seed, and no step rises under a grounded ball.

KF3 measures, then pins with a dated header.

## 8. K-F implementation units

Each unit writes in its own worktree, gets a verifier and one fix round, with red-then-green tests, the sketch lint and a fence check against SCOPE (PARK.md:496).

**KF0 Reconciliation (coordinator, serial; shared with the reactor sheet).** The swarm part: the stage 3 row changes `warden_family` from `reactor` to `swarm`, the ancient from `reactor_relic` to `swarm_remnant`, and the variant from `meltdown` to `""` (PARK.md:439). Stage 4 is unchanged (PARK.md:440). ACCEPTANCE adds: `Roster.warden_family(3)` returns `swarm`; stage 3 mounts no mantle (`src/presentation/hero_assets.gd:11-12`); stage 3's band is re-measured.

**KF3 Swarm mechanisms.** SCOPE: `src/combat/warden_swarm.gd` (the hoist cycle and its brake-drop for `headframe`; the pool step for `sinkhole`, read from the stage's `landmark.warden.mounting`; the snip as the swarm's shrug), `src/core/event_kinds.gd` (`pool_swell` form and `hoist_ride` fact, after KC0), `tests/warden_swarm_test.gd`, `tests/posture_bands_test.gd` (the swarm band). ACCEPTANCE:

- In a stepped headless run the hive dwells 4 s low and 4 s high and moves 30 m in 2 s each way.
- The pulse fires at the end of each dwell.
- A stagger drops the hive to the collar within `BRAKE_DROP := 0.9 s` (`warden_swarm.gd`; drafted `1.0 s`).
- A ball latched through the rise leaves the high-dwell stop with upward carry (`THROW_SPEED` in `warden_swarm.gd`).
- In the sinkhole each chunk lost raises the pool floor 5 m. No step rises while a ball is grounded on it, except the 6 s lift fallback, and that lift leaves planar speed within 1%.
- A lamp guard's last kill pays 25 posture, as a rack scatter does.
- The snip never changes the ball's velocity except the pulse lift.
- `brood_dark` still fires.
- The swarm band in section 10 passes on the sweep.
- No change touches `boss_posture.gd`.

Order: after KF1.

**KF6 Swarm body.** SCOPE: `tools/blender/warden_swarm.py`, `assets/models/warden_swarm.glb` with the section 5 clips, the `hero_assets.gd` row, a look subject. ACCEPTANCE:

- `npm run asset:inspect` passes the `warden_base` class (5,000 triangles, 32 draws) for the dome and `warden_kit` (1,500, 18) for the drone dressing (`assets/asset_budgets.json`).
- Below 2 m nothing passes the 2.8 m collider radius (`warden.gd:38`, `warden_look.gd:31-32`).
- Every clip in section 7 exists with its length.
- The queen sits at the kit's point offset so `family_point_at()` lands on it (`warden.gd:176-180`).
- Blind pairs read "hive", not "pile" or "hand", at 20, 60 and 150 m.

Order: after this sheet is approved.

**KF8 Mountings and wiring (shared).** The swarm part: `landmark.warden` in `src/world/park/park_pit.json` and `park_sinkhole.json` only. ACCEPTANCE:

- Live `park_pit.json` anchors the headframe hive at `[0, -108, 255]` with path `[[0, -108, 255], [0, -78, 255]]` (originally drafted at `y -96` / `-66`).
- The sinkhole nest sits at [0, -99, 388] with an empty path.
- Three hardpoints per mounting where section 5 puts them.
- KF1's bot latches, rides 3 s, fires from the line, survives a snip with its velocity, and finishes with a drop on both stages.

Order: after KD3, KD4 and KF6.

## 9. Storyboard

Board `warden-swarm`, five panels (PARK.md:406):

| Panel | Frame |
| --- | --- |
| `w1_body` | The hive alone on a plain ground: a lumpy honeycomb dome of hexagonal cells in dull petrol enamel, green pinpricks in the seams, the queen cell taller on top, flat triangle drones crawling over it. |
| `w2_mount_a` | The headframe: the hive hanging in the hoist cage at its high dwell under the tipple deck, the black steel frame and sheave wheels above, the pit's benches behind in noon light. |
| `w3_mount_b` | The sinkhole: the nest on the banded south wall over a round pool, the timber gallery ring, the lamp guard circling over the water, the green column rising to an afternoon sky. |
| `w4_anchor` | A harpoon line from a grip cell to a ball hanging in the air, three drones walking the rope toward it. |
| `w5_break` | The dome splitting along its seams into falling cells over the pool, drones dropping as dead triangles, seams going dark. |

The concept board `artifacts/local/alpha/push/w13/concepts/boards/park-w2.json` carries four `swarm_warden` subjects for a first look.

## 10. Calls, veto list and open questions

**Calls made under the creative charge (veto list).**

1. On the headframe the finisher drop comes from the tipple deck at 40 m, not the sheave wheel (outside the 45 m rope).
2. The hoist cycle is 12 s: two dwells of 4 s and two moves of 2 s, so it locks to the 6 s pulse cycle.
3. The swarm's shrug is the snip: drones walk the line for the 2 s charge and cut it on the pulse.
4. In the sinkhole the pool rises because shed cells fill it, so the chunk clip causes the rise you see.
5. A lamp guard's last kill pays the same 25 posture as a rack scatter.
6. The body is 19 cells in three rings, about 10 m across, uneven on purpose.
7. The hoist winch is tuned to G5 so the machine sings the swarm's note.

**Open questions for KF1, KF3 and the coordinator.**

1. Does the pulse ring follow a moving Warden in `warden.gd`, or stay where the body spawned? This sheet wants it to follow (section 3.1).
2. Gravity: the throw and finisher timings assume 9.8 m/s squared. KF3 recomputes them with the game's value.
3. The pool's rising floor needs a terrain change the bake supports: a recipe height that moves at run time (KE1's event engine or a moving collider). PARK.md section 5 has events that change ground; this one is driven by the Warden phase instead of a row, so KE1 and KF3 agree on who owns it.
