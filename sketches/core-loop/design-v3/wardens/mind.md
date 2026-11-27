# Warden kind sheet: `mind`, the Mind's hand

> **Historical / Built spec (10 Oct 2026):** Live implementation owns tuned stats in `sketches/core-loop/src/combat/warden*.gd`, `src/core/park_defs.gd`, and `src/core/alpha_defs.gd` (ignore any retired `QUARANTINE.tsv` references; use `KNOWN-FAILING.tsv`).

World 3, The Highdraft. Mountings `under_island` (stage 5, `park_islands`, variant `""`) and `spires` (stage 6, `park_crown`, variant `choir`). Board id `warden-mind`. Status: draft for Andrew's approval (unit K-W3, 2026-10-10). Numbers without a file:line are starting values to tune in play.

The kind id is the existing family id `mind` (`src/combat/roster.gd:33`, via PARK.md:420), so the posture rule, the kit switch (`warden_kit.gd:39-40`) and the asset key (`hero_assets.gd:7`) keep working. The stage pages are `design-v3/park/stages/5-park_islands.md` and `6-park_crown.md`. The Mind boss (`src/boss/mind.gd`) and the ending (`src/ui/ending_sequence.gd`) stay authored; nothing on this sheet changes them.

| Mounting | Stage | Where | Mechanism | Variant |
| --- | --- | --- | --- | --- |
| `under_island` | 5, `park_islands` | beneath the Hanging Isle, palm up, holding it up | the pendulum tilt: the island tips 10 degrees toward the ball on each pulse and a latched ball is thrown with the swing | `""` |
| `spires` | 6, `park_crown` | flying between three perch spires | the choir flight: it moves to the next perch every 8 s and carries a latched ball along its flight | `choir` |

Both rows match PARK.md:428-429.

## 1. What it is, and how it reads at a glance

The Mind is the superintelligence that ran the old works (SOUND-STORY.md:61). Its hands are how it reaches into the world: tall, thin, many-jointed arms with a lens cluster that always follows the ball, "still, then exact" (`src/combat/mind_hand.gd:7-9`). A field hand on a stage is one arm on a cast foot. A Warden is a whole hand. The fiction's rule for the kind is "it holds things up, and it watches you". On the islands it holds the mountain in the air. On the Crown it perches like a bird and watches the storm. Its one mechanism on each mounting turns what it holds, or where it sits, into a ride.

**Body.** Today every Warden is the shared Fleet-built clamp (about 7 m tall and 8 m across, `warden_look.gd:9-12`) with a family kit on top. The mind kit is a 3 m jointed rod rising from the deck, a seam-lit joint, and a 0.9 m glass lens at 7.6 m that turns to face the ball every frame (`warden_kit.gd:98-115`, `137-141`). Stage 5 and 6 also mount presentation mantles, `warden_mantle_hand` and `warden_mantle_choir` (`hero_assets.gd:14-15`). K-F gives the kind its own body and drops the clamp, because neither mounting stands on the ground:

- **A hand, 16 m from wrist to fingertip.** A palm plate 7 m across, four long fingers of three segments each and an opposed thumb, in dull petrol enamel.
- **Four fingers, four chunks.** Each finger carries one uranium-glass green (#9dff3c) seam. When a chunk shatters, one finger goes dark and curls shut (`boss_posture.gd:18`: four chunks). You can count what is left from 150 m.
- **Three knuckle hardpoints** on the back of the hand, rimmed in the ancients' green (PARK.md:414).
- **A wrist stalk, 8 m, ending in the lens cluster.** One big lens 1.8 m across (today's glass, `warden_kit.gd:112-115`) ringed by five small lenses. The cluster always faces the ball, as today (`warden_kit.gd:137-141`).
- **Enamel stays dull; only the seams glow** (`warden_kit.gd:6-9`). The seams are uranium-glass green (`Roster.ANCIENT_LIGHT`, `warden_kit.gd:33`) and breathe from 0.8 to 5.0 when the lens stands open (`warden_kit.gd:19-20`, `134`).
- **Two poses, one rig.** Under the island the hand is palm up with the fingers laid along the island's flank inside the -1 to 4.2 m approach band, the wrist stalk hanging down with the lens 10 m below the palm (coordinator ruling at the KF7 merge, 2026-10-11 w13-wardens: a curl up the island's tip leaves the band, so the curl is a KF8 held hang-clip option for the segments the island mesh hides). On the spires it is palm down, gripping a perch top like a bird's foot, the wrist raised and the lens 6 m above the perch.

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

**Against the field hand.** The `mind_hand` enemy (`roster.gd:121`, `mind_hand.gd`) is a single jointed arm on a cast foot with one lens. The Warden is a whole hand, 16 m, with a five-lens cluster, and it is never on a foot. The field hand is the Warden's finger; the eruption events on both stages wake one so you meet the family small first (stage pages, section 6).

## 2. The shared posture grammar it keeps

Every number here is today's, so the fight reads the same as every other Warden.

- **Telegraph.** While the ball is inside reach, the Warden charges for 2 s every 6 s (`PULSE_TELEGRAPH`, `PULSE_CYCLE`, `warden.gd:40-41`), showing the reach ring and a 6 m core ring (`warden.gd:44`, `375-381`). The mind's core ring carries no faction voice (`warden.gd:381`); its voice is the quote (section 6).
- **The pulse.** A ball the reach ring contains gains 10 m/s straight up for one tick, planar speed untouched; inside the core ring it also takes 10 damage (`warden.gd:18-23`, `42-43`, `386-393`).
- **Posture.** Hits fill 0 to 100: a ram, stomp or slam adds 30 times a heft multiplier between 0.2 and 1.5, a smash 45, anything else 1.5, or 3 while the Warden charges (`boss_posture.gd:9-14`, `20`). It drains at 12 a second after 3 s without gain (`boss_posture.gd:15-16`).
- **Stagger.** At 100 the Warden staggers for 4 s and the lens opens (`boss_posture.gd:17`; `warden.gd:526-542`). The pulse pauses in a stagger (`warden.gd:360-361`). The open lens is the weak point (`FAMILY_POINTS`, `warden.gd:51`; `plating_for` returns 0 for it, `warden.gd:143-145`).
- **The choir brace (stage 6 only).** On a stagger the choir variant reads the ball's most-used habit and braces against it: hits of that kind meet 1.6 times the plating while the open lens still takes everything (`warden.gd:535-540`, `146-147`, `65`). Codex entry `choir_switch` (`codex_entries.gd:143-146`).
- **Break.** Four chunks, at most one lost per stagger, shattered at speed tier 2 or better (`boss_posture.gd:18-19`). Both stage rows set `ram_shatters` false (`alpha_defs.gd:105`, `115`).
- **The drop finisher.** At the Warden the harpoon is a drop finisher, never a bowl hammer (PARK.md:410): release above the open lens, then haul.

**Stage numbers, unchanged.** Stage 5: plating 170, health 1,250 (`alpha_defs.gd:104`). Stage 6: plating 190, health 1,400 (`alpha_defs.gd:114`).

**What a mounted Warden needs from KF1.** Today the Warden sits on the ground under its point (`warden.gd:126-127`), its pulse ring reaches 8 m up (`LIFT_REACH_UP`, `warden.gd:45`), and its body obeys the "below 2 m" rule (`warden_look.gd:31-32`). The hand hangs 28 m above its arena floor on the islands and perches 24 m above it on the Crown, so:

1. The Warden sits at `landmark.warden.anchor`, not on the ground.
2. The reach ring is drawn on the arena floor under the lens, radius 30 m (`DEFAULT_REACH`, `warden.gd:39`), and contains a ball from the floor up to 4 m above the palm.
3. The core ring becomes a 6 m sphere round the lens (`CORE_RADIUS`, `warden.gd:44`), so the 10 damage lands only on a ball right at the lens.
4. The engage ring is the landmark's `reach_m` (120 on both stages), larger than any path (PARK.md:431).

## 3. The mechanism each mounting gives it

One mechanism per mounting (PARK.md:428-429).

### 3.1 `under_island` (stage 5): the pendulum tilt

The hand cups the Hanging Isle's tip from beneath and holds the mountain up. Live `park_islands.json` places the anchor at `[0, 66, 520]` (PW1 adjusted from drafted `[0, 80, 520]` so ground lock reaches inside 45 m rope). At the original 80 m design datum, the palm sat at 82 m, the three knuckle hardpoints at 88 m, each 6 m off the axis toward one knuckle butte (west, east, north), and the lens at 72 m (`park_islands.json` places them relative to the `[0, 66, 520]` anchor). The arena is the net bowl: floor 44 m, three knuckle buttes 60 m from the axis with tops at 80 m. `landmark.warden.path` is empty: the hand moves with the island, not along a path.

1. **The charge (2 s).** The island creaks. The thin waterfall off its rim leans toward the ball. The lens narrows. The wrong note sounds (section 6).
2. **The pulse.** The normal lift lands. On the same frame the island pivots 10 degrees toward the ball (its top deck dips toward you, PARK.md:428).
3. **The swing.** The island pivots on its beam at 200 m, 118 m above the tip. The tip, the hand and its hardpoints swing 20.5 m away from the ball and rise 1.8 m over 1.2 s (ease out), then come back over 2.8 s (ease in and out). Peak anchor speed is about 27 m/s, mid swing.
4. **The reset.** The swing ends 4 s after the pulse, as the next charge begins.

**The rhythm.** One 6 s cycle reads as: 2 s charge (creak, lean, the wrong note), the pulse (lift and tip), 1.2 s swing out, 2.8 s swing back.

**Why it is a ride.** A ball latched to a knuckle hardpoint at the pulse is dragged across the bowl by the swing and thrown at its far end, toward the opposite knuckle's banked spiral (section 4, Resist). A camper parked under the lens finds it 20 m away after every pulse. A ball on the floor loses nothing: the swing never touches the net.

**The stagger.** The hand's grip falters: the island sinks 2 m and the waterfall breaks into spray (the stagger's world read). The wrist stalk unfolds straight down and the lens drops 10 m, from 72 m to 62 m, 18 m above the floor, for the 4 s window. From a knuckle line the drop finisher is a 26 m fall onto the open lens.

**Other ways up.** The knuckle buttes' banked spirals carry a rolling ball to 80 m; the `bowl_thermal` lifts 160 m beside the east knuckle; the net bowl's banks pump you up the sides (stage 5 page, sections 2 and 8). All are momentum tools; none is required.

**The island shed.** The Warden's first chunk lost makes the island shed a boulder onto the west wing mesa (`isle_shed`, an `impact` event on `chunk_1`, stage 5 page section 6). The crater is a new ride, never a block.

### 3.2 `spires` (stage 6): the choir flight

Three perch spires stand in the Crown's bowl, 45 m from the Crown's axis at [0, 470] and 78 m from each other: perches at [0, 515], [39, 447.5] and [-39, 447.5], tops at 12 m. The bowl's rim is at 0 m and its floor at -12 m. The hand grips a perch top palm down, lens at 18 m. Anchor [0, 18, 515]. `landmark.warden.path` lists the three perch anchors in flight order. This is today's `choir` variant, placed.

1. **Every 8 s it flies to the next perch** (`ADAPT_CYCLE`, `warden.gd:63`; the lens clock, `warden.gd:347-354`). The flight is a `FLIGHT_SECONDS := 3.0 s` arc with `ARC_RISE := 9.0 m` peak above the perches (`warden_mind.gd`; originally drafted as 15 m). The horizontal span is about 78 m, averaging ~26–28 m/s (blazing tier). Today the open lens seat steps round a 1.6 m circle (`CHOIR_RADIUS`, `warden.gd:64`, `176-180`). The mounting spreads the three seats to the three perches: the open seat is the current perch.
2. **It never charges in flight.** If the 8 s perch clock runs out during a charge, the hand waits for the pulse and takes off right after it. A pulse therefore always comes from a perch, and its ring is drawn round that perch's foot. The wait is at most 2 s.
3. **A stagger stops the flight clock** (`warden.gd:349`). A stagger on a perch leaves the hand on the perch. **A stagger in flight knocks the hand out of the air:** it falls to the bowl floor under its flight path over 1 s, lies there open for the stagger, then climbs back to the nearest perch over 2 s. Knocking it down is the stage's best moment, and it is earned: you need a line or a long jump to hit it in flight.
4. **The brace.** On every stagger the quote plays, the lens shows the habit's icon, and the hand braces against that habit (`warden.gd:535-540`; `fleet.mind_adapt`). Change the tune (`choir_switch`, `codex_entries.gd:143-146`).

**The rhythm.** Pulses run on 6 s and flights on 8 s, so the two drift against each other in a 3-against-4 feel that realigns about every 24 s. The music cues key off the real events (section 6), so every drop lands on a real takeoff or pulse.

**Why it is a ride.** Latch a knuckle hardpoint while the hand is perched. When it takes off, the line drags you along its 3 s arc at about 28 m/s and lets you go at the next perch with that speed (section 4). A camper loses the lens every 8 s.

**Other ways up.** The perch spires and the Crown are anchor fields; from the bowl floor beside a perch its top is 24 to 33 m away, inside the 45 m rope (`src/movement/tuning.gd:18`). The Fleet's lightning collector catwalk on the Crown's south face at 64 m is the high anchor for the drop finisher. The `crown_updraft` thermal lifts 120 m on the bowl's west side (stage 6 page, sections 2 and 8).

## 4. The harpoon anchor

Every Warden is a harpoon anchor (PARK.md:412-418). The framework is unit KF1; this is the mind's placement of it. The mind is the kind where the drag matters most: both mountings move.

| Behaviour | Rule (PARK.md:414-418) | Under the island | On the spires |
| --- | --- | --- | --- |
| Latch | 3 hardpoints rimmed in green, bitten from rope range (45 m, `tuning.gd:18`) | The three knuckles at 88 m. From a knuckle butte's top edge the nearest knuckle is about 37 m away; from the bowl floor under it, 44 m | The three knuckles on the back of the hand, 2 m above the perch top. From the bowl floor beside the perch, about 27 m |
| Ride | Swing as on a world line; the winch shortens it; no drop inside the minimum rope | A pendulum under the island, across the bowl. Winch a 16 m line and the ball hangs level with the lens: swing through it for a ram | An orbit round the perch spire, inside the perch ring |
| Fire from the line | The weapon slot fires while hanging; each gun bolt adds 1.5 posture | Hang from a knuckle and shoot the lens below you, 3 posture a hit during the charge (`boss_posture.gd:12`) | Hang from the hand and shoot it while it is perched |
| Drag | When the mounting moves, the anchor moves | The swing: 20.5 m in 1.2 s, peak about 27 m/s | The flight: about 85 m in 3 s, about 28 m/s |
| Resist | Once per pulse cycle a lined hardpoint flares for the 2 s charge, then drops the line on the pulse; the ball keeps its velocity plus the 10 m/s lift | The line holds through the swing and drops when the swing stops, 1.2 s after the pulse (call 1 below) | As the rule: the flare and the drop happen on a perch, because the hand never pulses in flight |

**How it throws you.** Under the island, the throw is the swing itself. The rope drags you with the swing to about 27 m/s, the line lets go as the swing stops, and you fly on with that speed plus the pulse's 10 m/s lift, out toward the opposite knuckle's banked spiral. On the spires the shrug is the reactor's: let go on the pulse with your swing velocity plus the lift. A dragged flight never ends in a shrug. Both throws are rides, so the resist never stops the ball (PARK.md:308).

**During a stagger** every hardpoint holds. Release above the open lens and haul: the drop finisher. Under the island that is a 26 m fall from a knuckle onto the dropped lens; on the spires, a fall from the collector catwalk (64 m) or from a perch line onto a hand that is perched or lying on the bowl floor.

## 5. Clips

The KF7 body exports these clips in the shape of the boss bodies' clip tables (`tools/blender/bosses/mind_body.py:54-62`: name, then length and blend in seconds). The fight drives them from `warden.gd`'s state and `warden_mind.gd`'s mechanism. Nothing in a clip moves a collider; the mechanism moves the anchor.

| Clip | Length, blend (s) | When | What moves |
| --- | --- | --- | --- |
| `idle` | 4.0, 1.0 | default loop | Fingers flex one at a time, slowly; seams breathe at 0.8; the lens cluster tracks the ball |
| `pulse_warn` | 2.0, 0.5 | the charge (`warden.gd:375-381`) | The lens narrows; the five small lenses blink; the fingers tighten |
| `pulse` | 0.3, 0.1 | the pulse (`warden.gd:386`) | Fingers snap open and closed once |
| `active` | 0.5, 0.5 | stagger open (`warden.gd:526`) | Fingers splay; the lens cluster opens wide (today's 1.3 scale, `warden_kit.gd:136`); the seams blaze |
| `chunk_lost` | 1.0, 0.8 | a chunk shatters | One finger goes dark and curls shut, little finger first, then ring, middle, index |
| `shrug` | 0.4, 0.2 | the resist on a lined hardpoint | The flared knuckle flicks outward |
| `quote` | 1.4, 0.2 | the quote plays (section 6) | The five small lenses blink the quote's rhythm, one lens per note |
| `grip_falter` (under_island) | 0.5, 0.5 | stagger, under the island | The wrist unfolds straight down; the lens drops 10 m |
| `takeoff` (spires) | 0.6, 0.3 | leaving a perch | The hand pushes off, fingers folding into a fist |
| `glide` (spires) | 3.0, 0.3 | the flight | Fingers spread like flight feathers; the lens trails the ball |
| `land` (spires) | 0.5, 0.2 | arriving at a perch | Fingers open, then clamp round the perch top |
| `knocked_down` (spires) | 1.0, 0.2 | a stagger in flight | The hand tumbles to the bowl floor, palm up, lens open |
| `final_quiet` | 2.0, 2.0 | broken | The thumb, the last lit seam, goes dark; the lens closes like an eye |

`quote` takes 1.4 s, the field hand's warn time (`mind_hand.gd:26`), so the two read as one family.

## 6. Audio motif

**The quote.** The Mind has no motif of its own. It plays your class motif back inverted, every interval flipped, with the last note a semitone flat, on a pure sine chime with a long tail and a slow 3-cent bend (SOUND-STORY.md:61, 267). Sable's rising D F A C E comes back as a falling D B G E B. It is the one sanctioned hostile use of a class motif and it doubles as the telegraph (SOUND-STORY.md:74). It never enters the band (SOUND-STORY.md:69, 280).

**When it plays.** Once per adaptation (SOUND-STORY.md:61, 294), so:

- **On engage, both stages:** the hand quotes you once as you cross the engage ring. That is its greeting, and it tells you which motif it took.
- **Each charge, both stages:** only the quote's last, wrong note, held on sine for the 2 s charge with the 3-cent bend, landing on the pulse. The pulse's telegraph is that one wrong note, so you hear the quote's sting every cycle without the whole motif wearing thin.
- **Each stagger on the Crown:** the full quote again, before the brace lands, naming the habit it read (`warden.gd:535-540`; the lens shows the icon, SOUND-STORY.md:142). The islands' hand has no variant and no brace (`warden.gd:535`), so it quotes only on engage.

**Per mounting.**

- Under the island: the island's creak is a low stone groan pitched to the wrong note; the swing is a wind roar panned with the hand; the grip falter is the waterfall cutting out for the 4 s window.
- On the spires: the occupied perch hums a low sine; the hum leaves with the hand and lands on the next perch. The flight is a 3 s sine glide between the two perches' hums. A knock-down is the one hard hit in the mind's palette: a dull stone thud, then silence while the lens lies open.

**Teaching it early.** Each Highdraft stage erupts one field `mind_hand` before the Warden (the Lens Rocks on stage 5, the lens spire on stage 6; stage pages section 6), and the Crown has a home of field hands. A field hand quotes you on every strike (`mind_hand.gd:12-15`), so you have heard your motif turned wrong, small, before the fight.

## 7. Posture bands

**Today.** `tests/posture_bands_test.gd` holds the slice Warden's sweep cell (plating 110, curve 2.0, `ram_shatters` false, `posture_bands_test.gd:25`): over the sweep, grown breaks it in 25 to 45 s and small takes at least twice grown's time; the camper never breaks it; live medians stay within 10 percent of 66.6 and 32.3 s (`posture_bands_test.gd:45-46`, `74-85`). The world 3 stages sit in `tests/alpha_posture_bands_w23_test.gd`: every pilot's Warden fight inside 0.7 times 35 s to 1.6 times 80 s, so 24.5 to 128 s (`alpha_posture_bands_w23_test.gd:25-27`).

**The mind band** that KF4 adds to `posture_bands_test.gd` (PARK.md:548):

| Arm | Under the island (plating 170, health 1,250, `alpha_defs.gd:104`) | Spires, choir (plating 190, health 1,400, `alpha_defs.gd:114`) |
| --- | --- | --- |
| grown median | 25 to 45 s | 25 to 45 s |
| small median | at least 2 times grown | at least 2 times grown |
| camper | never breaks it | never breaks it |
| world 3 pilots (`alpha_posture_bands_w23_test.gd`) | 24.5 to 128 s, re-measured on the park after KD5, dated header | the same after KD6 |

The sweep runs with the mechanism on. Historically at KF4 (2026-10-11), `posture_bands_mind_test` waited on anchor-latching; under ruling `eq` (26 Nov 2026), it graduated off [KNOWN-FAILING.tsv](../../../../project-guide/handoff/KNOWN-FAILING.tsv) at `29.6 s` grown / `2.25x` / `0` camper (`tests/QUARANTINE.tsv` is an empty header-only stub superseded by `KNOWN-FAILING.tsv`). The tuning dials are the mechanism's, not the band: under the island, the lens height and the tilt angle; on the spires, the flight time and the perch spacing. If the knock-down makes the Crown's grown arm faster than 25 s, the knock-down's 4 s on the floor shortens before anything else.

## 8. K-F implementation units

Each unit writes in its own worktree, gets a verifier and one fix round; red-then-green tests, the sketch lint and a fence check against SCOPE (PARK.md:496).

**KF0 Reconciliation (coordinator, serial), the mind's part.** SCOPE: `src/core/alpha_defs.gd` stage 5 row (`warden_variant` `choir` to `""`, PARK.md:441), `tests/warden_variants_test.gd` (stage 5 now has no variant), `tests/alpha_posture_bands_w23_test.gd` re-pinned. ACCEPTANCE: stage 5 builds a mind Warden with variant `""` and stage 6 a `choir` one; `choir_switch` still fires on stage 6; the world 3 band is re-measured and pinned with a dated header.

**KF1 Mounting and anchor framework, what the mind needs.** The shared unit (PARK.md:546) must cover: placement at `landmark.warden.anchor` off the ground; the floor-drawn reach ring and the 3D core sphere (section 2); hardpoint lines on an anchor that moves along `path` or by a procedural transform; the shrug's drop delayed until a named mechanism event (call 1). ACCEPTANCE for the mind: the KF1 bot latches a knuckle on a moving test anchor, is dragged, and keeps its velocity on release.

**KF4 Mind mechanisms.** SCOPE: `src/combat/warden_mind.gd` (the pendulum tilt for `under_island`; the perch flight, the no-charge-in-flight rule and the knock-down for `spires`; both read `landmark.warden.mounting` and `path`), `tests/warden_mind_test.gd`, `tests/posture_bands_test.gd` (the mind band). The Hanging Isle must be a landmark node, not baked ground, so it can tilt; only its tip below 120 m carries a collider (a note for KD5, which owns the bake). ACCEPTANCE:
- In a stepped headless run under the island, each pulse tilts the island 10 degrees toward the ball; the anchor moves 20 to 21 m away within 1.2 s and is back within 4 s of the pulse.
- A ball latched to a knuckle at the pulse leaves the line when the swing stops, with planar speed of at least 20 m/s.
- A stagger under the island drops the lens 10 m and raises it again when the stagger ends.
- On the spires the hand leaves its perch every 8 s, plus at most 2 s when a charge is in flight; the flight lasts 3 s; no charge starts in flight; the open seat is the current perch.
- A stagger in flight puts the hand on the bowl floor within 1 s and back on a perch 2 s after the stagger ends.
- The choir brace and `choir_switch` still fire on the spires.
- The mind band in section 7 passes on the sweep.
- No change touches the posture numbers in `boss_posture.gd`.

**KF7 Mind body.** SCOPE: `tools/blender/warden_mind.py`, `assets/models/warden_mind.glb` with the section 5 clips and both poses, the `hero_assets.gd` row (the stage 5 and 6 mantles, `hero_assets.gd:14-15`, retire once the body lands), a look subject. ACCEPTANCE:
- `npm run asset:inspect` passes the `warden_base` class (5,000 triangles, 32 draws) for the body and `warden_kit` (1,500, 18) for any kit part (`assets/asset_budgets.json:27-36`).
- No visible finger reaches more than 1 m past a collider, so the hand the ball sees is the hand it meets (the mounted form of `warden_look.gd:31-32`).
- Every clip in section 5 exists with its length; four finger seams can go dark one at a time.
- Blind pairs read "hand", not "pile" or "hive", at 20, 60 and 150 m, and "Warden", not "field hand", against the `mind_hand` model at 60 m.
- Order: after this sheet is approved.

**KF8 Mountings and wiring.** SCOPE: `src/combat/warden_look.gd`, `warden_kit.gd` (read the kind body), and the `landmark.warden` object in `src/world/park/park_islands.json` and `park_crown.json` only. ACCEPTANCE:
- Live `park_islands.json` places the island hand at `[0, 66, 520]` (PW1 adjustment from `[0, 80, 520]`) with knuckles offset toward the three knuckle buttes.
- The Crown hand starts on the perch at [0, 18, 515] and flies the three-perch path.
- The bot (KF1's test) latches, rides 3 s, fires from the line, is dragged by the swing on stage 5 and by a flight on stage 6, survives a shrug with its velocity, and finishes with a drop on both stages.
- Order: after KD5, KD6 and KF7.


## 9. Storyboard

Board `warden-mind`, five panels (PARK.md:406). The concept board `artifacts/local/alpha/push/w13/concepts/boards/park-w3.json` carries four `mind_warden` subjects for a first look.

| Panel | Frame |
| --- | --- |
| `w1_body` | The hand alone at three-quarter view on a plain ground: palm, four fingers and a thumb in dull petrol enamel, green seams along each finger, the wrist stalk and the five-lens cluster turned toward the camera |
| `w2_mount_a` | Under the Hanging Isle from the net bowl: the upside-down mountain filling the top of the frame, the hand cupping its tip palm up, the lens hanging below, the three knuckle buttes round the bowl |
| `w3_mount_b` | The Crown's bowl at dusk: the hand perched palm down on one of three short spires, a second perch empty, the 330 m Crown behind with its beam, lightning in the clouds |
| `w4_anchor` | Under the island: the ball on a harpoon line from a knuckle, dragged across the bowl as the island tips 10 degrees, firing at the lens |
| `w5_break` | The Crown: the hand knocked out of the air, lying palm up on the bowl floor with its lens open, the ball dropping onto it from the collector catwalk on a hauled line |

## 10. Calls, veto list and open questions

**Calls made under the creative charge (veto list).**

1. Under the island, the shrug's line drop waits for the swing to stop (1.2 s after the pulse) instead of landing on the pulse, so the drag is a throw. PARK.md:418 drops it on the pulse.
2. The hand never charges in flight; the perch clock waits up to 2 s for a pulse.
3. A stagger in flight knocks the hand down to the bowl floor.
4. Four fingers are the four chunks; the thumb is the last light.
5. The core ring becomes a 6 m sphere round the lens, and the reach ring is drawn on the arena floor.
6. The quote plays once on engage; each charge carries only its wrong last note; the full quote returns only with the choir's brace.
7. The island pivots at 200 m, so its tip swings 20.5 m.

**Open questions for KF1, KF4 and the coordinator.**

1. The tilt and the flight move the hardpoints; KF1's moving anchor must carry the rope's tension, which `augments.gd:697-702` does for enemies but not yet for a Warden body.
