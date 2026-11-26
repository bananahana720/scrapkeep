# Warden kind sheet: `reactor`, the reactor relic

World 1, Spillway Works. Mountings `dam_face` (stage 1, `park_dam`, variant `""`) and `flume` (stage 2, `park_flume`, variant `meltdown`). Board id `warden-reactor`. Status: draft for Andrew's approval (unit K-W1, 2026-10-10). Numbers without a file:line are starting values to tune in play.

The kind id is the existing family id `reactor` (`src/combat/roster.gd:31-33`, via PARK.md:420), so the posture rule, the kit switch (`warden_kit.gd:34-40`) and the asset key (`hero_assets.gd:7`) keep working. The stage pages are `design-v3/park/stages/1-park_dam.md` and `2-park_flume.md`.

| Mounting | Stage | Where | Mechanism | Variant |
| --- | --- | --- | --- | --- |
| `dam_face` | 1, `park_dam` | open air, on the dam's curved face 22 m above the toe apron | the spillway sheet: each pulse opens the gates and a 3 s water sheet is a road up the face to the core | `""` |
| `flume` | 2, `park_flume` | in the flume head house at the top of the penstock tower | it boils the flume: slag lanes run down the channel toward the ball, and the core window lasts 1.5 times longer | `meltdown` |

Both rows match PARK.md:424-425.

## 1. What it is, and how it reads at a glance

A reactor relic is one of the pre-collapse machines that woke under the dam works: a fission pile that never shut down, clamped onto the water that used to cool it. The fiction's rule for the kind is "it wants the water". Both mountings put it where the works' water runs, and its one mechanism on each turns that water against you, or into a ride.

**Body.** Today every Warden is the shared Fleet-built clamp (four jaw plates round the beacon mast, about 7 m tall and 8 m across, `warden_look.gd:9-12`, `34-43`; the cast base in `tools/blender/warden_clamp.py:1-13`) with a family kit on top. The reactor kit is three vent stacks round the deck and a core dome (`warden_kit.gd:11-12`, `58-78`). K-F gives the kind its own body, built on the same base so the colliders and the posture reads stay:

- **A squat drum, wider than tall.** About 9 m across and 6 m tall, ribbed like a cooling jacket, sitting in the clamp's jaws. The core dome sits on top inside a lattice cage, so the core is visible through the bars from any side.
- **Three control-rod stacks** rising 4 m from the drum's rim at 120 degrees, the existing vent stacks grown taller. On a pulse they lift 0.6 m and drop back: the kind's tell is vertical.
- **Enamel stays dull petrol; only the seams glow** (`warden_kit.gd:6-9`). The seams are uranium-glass green #9dff3c (`Roster.ANCIENT_LIGHT`, `warden_kit.gd:33`) and breathe with the pulse charge: dim at 0.8, brightening across the 2 s charge, blazing at 5.0 while the core stands open (`warden_kit.gd:19-20`).

**At a glance against the other two kinds.**

| Layer | Reactor relic | Swarm remnant | The Mind's hand |
| --- | --- | --- | --- |
| Silhouette | A squat drum with three upright stacks: a pile | A lumpy dome of many small hexagonal cells round a queen cell (`warden_kit.gd:13-14`): a hive | An open hand with a lens on a stalk: a hand |
| Where it lives | On the water: the dam face, the flume head house | In the earth: on the hoist in the headframe, on the sinkhole wall | In the air; the only kind that never touches the ground |
| Motion | Vertical: stacks lift on the pulse, water and slag fall | Crawling and rippling: drones walk over it, shutters open in waves, the guard scatters and reforms | Tracking and travelling: the lens follows you and the whole body moves (the tilt, the flight) |
| Light | One steady green that breathes with the charge | Many green pinpricks in the cell seams, rippling base to crown | One big point that turns toward you; five small lenses blink the quote's rhythm |
| Sound | The Ab tritone pedal and a Geiger tick (SOUND-STORY.md:59) | A thin G5 buzz that locks into a quartal chord (SOUND-STORY.md:60) | Your own class motif, inverted and wrong (SOUND-STORY.md:61) |
| Colours the band | Yes, the only one (SOUND-STORY.md:69, 74) | No (SOUND-STORY.md:69) | No, never (SOUND-STORY.md:280) |
| What you play around | It never moves. Its mounting turns the pulse into terrain: a road up to the core (the sheet) or lanes to dodge (the slag) | A guard stands between you and it, and its reach changes on a vertical rhythm (the hoist, the rising pool) | It moves you. A latched ball is thrown by the tilt or carried by the flight, so the rope is the fight |

## 2. The shared posture grammar it keeps

Every number here is today's, so the fight reads the same as every other Warden.

- **Telegraph.** While the ball is inside the reach ring, the Warden charges for 2 s every 6 s (`PULSE_TELEGRAPH`, `PULSE_CYCLE`, `warden.gd:40-41`), showing the reach ring and a 6 m core ring (`warden.gd:44`, `375-383`). The reactor also emits `vent_charging` for the music and the vents (`warden.gd:382-383`).
- **The pulse.** A ball inside the reach ring gains 10 m/s straight up for one tick, planar speed untouched; inside the core ring it also takes 10 damage (`warden.gd:18-23`, `42-43`, `386-393`). The reactor emits `vent_erupted` (`warden.gd:395-397`).
- **Posture.** Hits fill 0 to 100: a ram, stomp or slam adds 30 times a heft multiplier between 0.2 and 1.5, a smash 45, anything else 1.5, or 3 while the Warden charges (`boss_posture.gd:9-14`, `20`). It drains at 12 a second after 3 s without gain (`boss_posture.gd:15-16`).
- **Stagger.** At 100 the Warden staggers for 4 s and the core opens (`boss_posture.gd:17`, `warden.gd:526-542`). The pulse pauses during a stagger (`warden.gd:360-361`).
- **Break.** Four chunks, at most one lost per stagger, shattered at speed tier 2 or better (`boss_posture.gd:18-19`); both stage rows set `ram_shatters` false (`alpha_defs.gd:73`, `79`).
- **The drop finisher.** At the Warden the harpoon is a drop finisher, never a bowl hammer (PARK.md:410): release above the open core, then haul.

## 3. The mechanism each mounting gives it

One mechanism per mounting (PARK.md:420-425). The Warden itself never moves on either mounting (`landmark.warden.path` is empty): the reactor moves the water instead.

### 3.1 `dam_face` (stage 1): the spillway sheet

The relic clamps to the centreline of the dam's curved face, anchor [0, 22, 590], 22 m above the toe apron. The face is a quarter pipe: flat at the toe, vertical about 30 m up.

1. On each pulse the two spillway gates over the relic open.
2. A water sheet 24 m wide runs down the face for 3 s, centred on the relic.
3. The sheet is a ride: a ball that enters it from the apron while moving toward the face rides up the face along the sheet and arrives at the relic's core height, about 22 m, with its planar speed kept. It publishes a new ride fact, `ride_sheet` (start).
4. A ball that misses the sheet loses nothing: the dry face is still a quarter pipe.

**The rhythm.** One 6 s cycle reads as: 2 s charge (gates glow, the Ab pedal under the band), the pulse (gates open, 10 m/s up), 3 s of sheet (your road to the core), 1 s dry. A grown ball rams the core on the sheet; a small ball rides the sheet to reach it at all. That keeps the posture bands' "small takes at least twice grown's time" shape (`tests/posture_bands_test.gd:82`).

**Other ways up the face** (stage 1 page, section 8): the plunge pool geyser lobs you onto the face 10 m above the relic; the spray thermal lifts you 60 m; the crest trebuchet puts you on the crest rail for a drop down the face. All are momentum tools; none is required.

### 3.2 `flume` (stage 2): it boils the flume

The relic clamps onto the flume's pour channel inside the head house; live `park_flume.json` places the anchor at `[230, -2, 470]` (originally drafted as `[230, 41, 470]` 12 m above the drum floor). This is the `meltdown` variant, placed:

- **Slag lanes.** Every pulse leaves a lane toward the ball, 14 m long and 4 m wide, that fills over 1 s and burns a grounded ball inside it for 6 s at 4 damage a second (`warden.gd:29-31`, `56-60`, `263-291`). In the head house each lane pours out of the flume's channel and runs down the drum floor, so the lanes always start from one readable place.
- **The counter is air.** A ball over a burning lane, no more than 8 m above it, is safe and earns `slag_hop` (`warden.gd:62`, `312-321`; `codex_entries.gd:131-135`).
- **A longer window.** The core stays open 1.5 times longer, 6 s instead of 4 (`warden.gd:55`, `112-114`).

## 4. The harpoon anchor

Every Warden is a harpoon anchor (PARK.md:412-418). The framework is unit KF1; this is the reactor's placement of it.

| Behaviour | Rule (PARK.md:414-418) | On the dam face | In the head house |
| --- | --- | --- | --- |
| Latch | 3 hardpoints rimmed in green, bitten from rope range (45 m, `tuning.gd:18` via PARK.md:414) | The two gate piers either side of the relic and the relic's crown | The pour channel's two cheeks and the relic's crown |
| Ride | Swing as on a world line; the winch shortens it; no drop inside the minimum rope | A pendulum over the toe apron, swinging across the sheet's foot | An orbit round the relic under the roof trusses |
| Fire from the line | The weapon slot fires while hanging; each gun bolt adds 1.5 posture | Hang from a pier and shoot the relic during the charge for 3 posture a hit (`boss_posture.gd:12`) | Hang over the drum and shoot while the slag lanes burn below |
| Drag | When the mounting moves, the anchor moves | None: the relic never moves | None |
| Resist | Once per pulse cycle, a lined hardpoint flares for the 2 s charge, then drops the line on the pulse; the ball keeps its velocity plus the 10 m/s lift | The pier's flare shares the gates' glow | The cheek's flare shares the channel's glow |

**How it throws you.** The reactor's throw is the shrug plus the pulse: a ball hanging from a hardpoint at the pulse is let go with 10 m/s upward and its swing velocity kept. On the dam that throw arcs you up the face; in the drum it lifts you over a fresh slag lane. Both are rides, so the resist never stops the ball (PARK.md:308).

**During a stagger** every hardpoint holds. Release above the open core and haul: the drop finisher.

## 5. Clips

The KF5 body exports these clips in the shape of the boss bodies' clip tables (`tools/blender/bosses/mind_body.py:54-62`: name, then length and blend in seconds). The fight drives them from `warden.gd`'s state; nothing in the clips changes a collider.

| Clip | Length, blend (s) | When | What moves |
| --- | --- | --- | --- |
| `idle` | 4.0, 1.0 | default loop | Seams breathe at 0.8; the stacks shimmer with heat |
| `pulse_warn` | 2.0, 0.5 | the charge (`warden.gd:375-383`) | Stacks rise 0.6 m; seams ramp to full; the core dome's cage glows |
| `pulse` | 0.3, 0.1 | the pulse (`warden.gd:386`) | Stacks drop; a ring of steam from the drum's foot |
| `active` | 0.5, 0.5 | stagger open (`warden.gd:526`) | The jaws lean open 14 degrees (`warden_look.gd:72`); the cage splits; the core blazes |
| `chunk_lost` | 1.0, 0.8 | a chunk shatters | One quarter of the drum's jacket falls away |
| `shrug` | 0.4, 0.2 | the resist on a lined hardpoint | The flared hardpoint kicks outward |
| `gates_open` (dam_face) | 0.6, 0.3 | each pulse on the dam | The two gates swing up; the sheet starts |
| `pour` (flume) | 1.0, 0.3 | each pulse in the head house | The pour channel tilts and the slag pours |
| `final_quiet` | 2.0, 2.0 | broken | Seams go dark one by one, the Ab pedal stops on the last |

## 6. Audio motif

**The pedal.** No tune. A pedal on the tritone, Ab (MIDI 44 and 56), under whatever the band plays, as a sub sine with a crackling tick like a Geiger counter (SOUND-STORY.md:59). It enters for the bars the vent charges and leaves when the vent blows: the sinister break's colour arriving early (SOUND-STORY.md:69; `harmony.gd` `TRITONE`, `SINISTER`). The tick rate follows the real charge and speeds toward the pulse; the pulse lands on the beat. Only the reactor colours the band (SOUND-STORY.md:74).

**Per mounting.**

- Dam face: the water sheet is a white-noise swell that rises under the 2 s charge and lands with the pulse.
- Flume: each slag lane's 1 s fill is a rising hiss; the burn crackles on the Geiger tick.

**Teaching it early.** Each reactor stage erupts one small `reactor_relic` miniboss before the Warden (the dam's toe vents, the flume's bend relic; stage pages section 6), so the player has heard the pedal once, small, before the fight.

## 7. Posture bands

**Today.** `tests/posture_bands_test.gd` holds the slice Warden's sweep cell (plating 110, curve 2.0, `ram_shatters` false, `posture_bands_test.gd:25`): grown breaks it in 25 to 45 s, small takes at least twice grown, the camper never breaks it, and live medians stay within 10 percent of 66.6 and 32.3 s (`posture_bands_test.gd:45-46`, `74-89`). The stage bands live in `tests/alpha_posture_bands_test.gd`: Spillway skipper 50 to 90 s, Reach skipper 35 to 80 s, Reach completionist at most 1.25 times the skipper (`alpha_posture_bands_test.gd:31-34`).

**The reactor band** that KF2 adds to `posture_bands_test.gd` (PARK.md:548):

| Arm | Dam face (`alpha_defs.gd`: plating `105.0`, hp `650.0`, drafted at 90) | Flume, meltdown (`alpha_defs.gd`: plating `110.0`, hp `800.0`) |
| --- | --- | --- |
| grown median | 25 to 45 s | 25 to 45 s |
| small median | at least 2 times grown | at least 2 times grown |
| camper | never breaks it | never breaks it |
| alpha skipper (`alpha_posture_bands_test.gd`) | 50 to 90 s, re-pinned with a dated header | 35 to 80 s, re-pinned after KF0 |

The sweep runs with the mechanism on. If the sheet makes the dam's grown arm faster than 25 s, the sheet's width or duration is the tuning dial, not the band.

## 8. K-F implementation units

Each unit writes in its own worktree, gets a verifier and one fix round; red-then-green tests, the sketch lint and a fence check against SCOPE (PARK.md:496).

**KF0 Reconciliation (coordinator, serial).** SCOPE: `src/core/alpha_defs.gd` stage 2 row (`swarm` to `reactor`, `swarm_remnant` to `reactor_relic`, `""` to `meltdown`, PARK.md:438), `src/combat/roster.gd` `warden_family` by world, `src/presentation/hero_assets.gd` `WARDEN_MANTLES` (the meltdown mantle moves from stage 3 to stage 2, `hero_assets.gd:11-12`), `tests/alpha_posture_bands_test.gd` re-pinned. ACCEPTANCE: `Roster.warden_family(2)` returns `reactor`; stage 2 mounts the meltdown mantle and stage 3 mounts none until the swarm sheet gives it one; the Reach band is re-measured and pinned with a dated header.

**KF2 Reactor mechanisms.** SCOPE: `src/combat/warden_reactor.gd` (the `dam_face` sheet and the `flume` placement of the slag lanes, read from the stage's `landmark.warden.mounting`), `src/core/event_kinds.gd` (`ride_sheet`, after KC0), `tests/warden_reactor_test.gd`, `tests/posture_bands_test.gd` (the reactor band). ACCEPTANCE: in a stepped headless run the gates open on every pulse and the sheet lives 3 s; a ball entering the sheet at cruise reaches core height with planar speed within 5 percent of its entry; a ball that misses the sheet loses no speed; slag lanes in the head house start at the pour channel; `slag_hop` still fires; the reactor band in section 7 passes on the sweep; no change touches the posture numbers in `boss_posture.gd`.

**KF5 Reactor body.** SCOPE: `tools/blender/warden_reactor.py`, `assets/models/warden_reactor.glb` with the section 5 clips, the `hero_assets.gd` row, a look subject. ACCEPTANCE: `npm run asset:inspect` passes the `warden_base` class (5,000 triangles, 32 draws) for the body and `warden_kit` (1,500, 18) for any kit part (`assets/asset_budgets.json`); below 2 m nothing passes the 2.8 m collider radius (`warden_look.gd:31-32`); every clip in section 5 exists with its length; blind pairs read "pile", not "hive" or "hand", at 20, 60 and 150 m. Order: after this sheet is approved.

**KF8 Mountings and wiring.** SCOPE: `src/combat/warden_look.gd`, `warden_kit.gd` (read the kind body), and the `landmark.warden` object in `src/world/park/park_dam.json` and `park_flume.json` only. ACCEPTANCE: the dam relic sits on the face at `[0, 22, 590]` and the flume relic on the pour channel (`park_flume.json` live anchor `[230, -2, 470]`; drafted `[230, 41, 470]`); three hardpoints per mounting where section 4 puts them; the bot (KF1's test) latches, rides 3 s, fires from the line, survives a shrug with its velocity, and finishes with a drop on both stages. Order: after KD1, KD2 and KF5.

## 9. Storyboard

Board `warden-reactor`, five panels (PARK.md:406). The concept board `artifacts/local/alpha/push/w13/concepts/boards/park-w1.json` carries four `reactor_warden` subjects for a first look.

| Panel | Frame |
| --- | --- |
| `w1_body` | The relic alone on a plain ground at three-quarter view: the ribbed drum in the clamp's jaws, three rod stacks, the caged core dome, green seams |
| `w2_mount_a` | On the dam face from the toe apron: the relic 22 m up the curved concrete, the gates over it open, the sheet pouring |
| `w3_mount_b` | Inside the head house: the relic on the flume's pour channel, two slag lanes running down the drum floor |
| `w4_anchor` | The ball hanging on a harpoon line from a gate pier, swinging across the sheet's foot, firing at the relic |
| `w5_break` | The stagger: jaws open, the core blazing, the ball dropping from above on a hauled line onto the open core |

## 10. Calls, veto list and open questions

**Calls made under the creative charge (veto list).**

1. The sheet is a ride with its own ride fact, `ride_sheet` (section 3.1); a ball that misses it loses nothing.
2. The relic never moves on either mounting, so it is the one kind with no drag (section 4): the reactor is the stationary kind and its mountings turn the pulse into terrain.

**Open questions for KF2 and the coordinator.**

1. The sheet needs a surface that carries a ball up a quarter pipe at kept planar speed. KF2 decides between a ride assist (as the chutes do) and a lossless slick surface, and the posture bands judge which.
