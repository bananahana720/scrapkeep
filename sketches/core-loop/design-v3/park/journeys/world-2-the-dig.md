# World 2, The Dig: the journey to the swarm remnant

Journey board for world 2, wave 13, 10 October 2026 (World 2 is now unparked and shipped flat on `main` under rulings `ep`/`eq` with `Worlds.FULL_ALPHA := true`). It joins the two stage pages and the Warden kind sheet into one ride, beat by beat, from the drop onto the spoil dump to the launch out of the sinkhole. It adds no mechanic. Historical `artifacts/local/alpha/push/w13/concepts/...` paths refer to the wave-13 candidate worktree. Every fact carries a `(file:line)` cite. A cite with no number is an inference, and it says so.

Cite keys. `3-park_pit.md` and `4-park_sinkhole.md` are `design-v3/park/stages/`. `swarm.md` is `design-v3/wardens/swarm.md`. `PARK.md`, `DESIGN-V3.md` and `ALPHA-PLAN.md` are in `design-v3/`. `BIBLE.md` and `docs/decisions.tsv` are at the repository root. `.gd` files are under `sketches/core-loop/src/`. Picture paths are under the repository root and are gitignored, so they resolve in the candidate worktree `scrapkeep-wt-cand-alpha-w13`. Cites into `.gd` files, `DESIGN-V3.md`, `ALPHA-PLAN.md` and `docs/decisions.tsv` lie outside the review's sources (the two stage pages, the kind sheet and PARK.md); they await the coordinator's check against those files.

## The journey in one paragraph

You land on a spoil dump at noon on the north-west corner of a copper pit, and the black headframe already stands over the far rim 1,168 m away (3-park_pit.md:76, :43, :189). You drop the dump's 55 m face, carve an arroyo, grind the old canal and crest the rim, where the whole pit opens below you (3-park_pit.md:201). You take a way down the benches to the floor and fight the swarm remnant's hive as it rides the hoist rope, and the hoist teaches you every rope trick the world will ask for (swarm.md:74-80, :110-120). Moss's bay docks over the reward gates, you take a part, and a gate fires you into the afternoon (bay.gd:11-28, launch.gd:6-10). On a cinder cone's rim a thin green column on the far skyline marks the nest of the same kind, the swarm's brood (4-park_sinkhole.md:44, :326, swarm.md:7-10). You drop under the basalt, ride the dark tubes, burst onto the sinkhole's gallery ring under open sky, and break the brood while the pool rises toward it one chunk at a time (4-park_sinkhole.md:232, swarm.md:89). The pool floods to the ring, the bay docks over the water, and the launch arc carries you up the sinkhole's throat to the Waking and then to world 3 (4-park_sinkhole.md:333, field_notes.gd:25).

## The world arc

The Warden is the end of every act: the headframe from the dump top, the green column from the cone rim (3-park_pit.md:290, 4-park_sinkhole.md:326). Times are the pages' estimates from assumed mean speeds, not measurements (3-park_pit.md:189, 4-park_sinkhole.md:220).

| Act | Where | What you want | What the world does | Time (s) | Music layer |
| --- | --- | --- | --- | --- | --- |
| 1. Drop into the Dig | Stage 3, dump top to the rim crest at the cache | Speed, and the headframe | The dump face, the arroyo and the canal hand you about 33 m/s; the pit opens at the crest (3-park_pit.md:214, :201) | 24.5 to 30.7 elapsed at the cache; floor line 36.8 (sums of 3-park_pit.md:193-199) | Bed and two knocks, then the groove, one held note on the canal, a 2-bar riser to the reveal (3-park_pit.md:235-238) |
| 2. The benches | Stage 3, rim to pit floor | A way down, and Kest's cage | The tailings face slumps at 45 s; homes sit on benches; Kest waits on bench 4 west (3-park_pit.md:138, :82, :85) | 34.8 to 44.1 on the segment; at the Warden 62.1 to 69.3, floor line 81.3 (3-park_pit.md:193-199) | A fill on each kicker; bass forward on the floor; `landmark_hum` fades in (3-park_pit.md:239-240) |
| 3. The headframe Warden | Stage 3, the collar and the tipple deck | Break the hive | The hoist runs a 12 s cycle; the snip cuts your rope; the boiler blows at chunk 2 (swarm.md:72-77, :116, 3-park_pit.md:142) | 60 to 85, predicted (swarm.md:177) | The swarm's G5 buzz over the band, a chord that loses a voice per chunk (3-park_pit.md:241-243) |
| 4. The bay and the gates | Stage 3 floor, bay dock (60, 300), gate (60, 280) | A part, a breather, the companion | No new event for 20 s; the bay is opt-in; a gate is a cannon shot (PARK.md:313, bay.gd:11-28, launch.gd:6-10) | Not given; opt-in | The band's drop lands on the break (3-park_pit.md:243); the bay's jukebox flips the lounge (bay.gd:25-27) |
| 5. The cone and the channel | Stage 4 surface, cone rim to the tube mouth | The green column | The crater bowl gives the blazing tier; burrowers hide in the channel cinder; the fumarole throws you (4-park_sinkhole.md:245, :176, :190) | 17.8 to 24.6; floor line 26.7 (4-park_sinkhole.md:224-230) | Wind and bed for 3 s, the groove on the first landing, a fill on the breach (4-park_sinkhole.md:268-270) |
| 6. Under the roof | Stage 4, five tubes to the great room | The way down in the dark | Skylights flash; five routes rejoin at the hauler bounty (4-park_sinkhole.md:232, :94) | 21.7 to 33.2; floor line 32.0 (4-park_sinkhole.md:224-230) | Low-pass filter; it opens one beat per skylight; reverb widens in the great room (4-park_sinkhole.md:271-273) |
| 7. The ring and the brood | Stage 4, lower tubes to the caisson pool | Sky again, then the queen | The roof caves in at 45 s; the pool rises 5 m per chunk lost (4-park_sinkhole.md:158, swarm.md:89) | Approach 18.9 to 23.0, at the Warden 62.2 to 79.1, floor line 84.3; fight 45 to 70, predicted (4-park_sinkhole.md:224-230, swarm.md:178) | The filter opens fully on the ring; the chord loses a voice and the water swells per chunk (4-park_sinkhole.md:275-277) |
| 8. The exit | Pool flooded to the ring, bay dock (0, 320), launch up the throat | Out, carrying the run | The break floods the pool; the gate fires you to the Waking, then to the Highdraft at golden hour (swarm.md:89, field_notes.gd:25, PARK.md:606) | Not given | The chord detunes and stops; the band's next downbeat is the drop (4-park_sinkhole.md:278) |

The whole world runs about 229 to 303 s of riding and fighting before the bay and the Waking (inference: the sums of the pilot arrival times and the predicted fight bands above).

## Stage 3: The Dig, the open pit, the line

Fixed noon, heat shimmer always, short straight shadows so the benches read as steps (3-park_pit.md:176-180). The headframe stands on the pit floor at (0, 255), 120 m tall, its top at y +20 so it shows over the rim from every plateau cell (3-park_pit.md:43).

**Beat 1. The dump top: the view**
- Where: `spoil_dump`, a 55 m tipping face, spawn (-560, -770) at y +55, heading 15 degrees (3-park_pit.md:76, :95, :333).
- You: you land facing south-south-east and read the whole pit before you roll.
- You see: the headframe's black legs and sheave wheels standing out of the pit on the far side, 1,168 m off; the canal across the left foreground; two dust devils over the pale tailings on the right; the camp's smoke on the north-east bench and the altar's lit ring on bench 4 (3-park_pit.md:290, :87, :189).
- Pull: the tipping face directly ahead, and the headframe on the heading.
- Pressure: none.
- Seconds: inside the first segment, 12.6 to 15.8 s; floor line 18.9 s (3-park_pit.md:193-199).
- Music: bed only and a two-knock figure with a gap; the second knock is the downbeat of the drop (3-park_pit.md:235).
- Panel: `artifacts/local/alpha/push/w13/concepts/codex/park/park-pit/vista-1.png` (observed: ball on the dump rocks, canal and saguaros left, headframe centred over five benches, dust devils and pale pond right).

**Beat 2. The tipping face drop**
- Where: `spoil_dump` into `dump_wash_1`, the arroyo half-pipe (3-park_pit.md:95-96).
- You: you go off the 55 m face and land in the arroyo on the downbeat with about 33 m/s before losses (3-park_pit.md:214).
- You see: cinder-red banks and saguaros on the lip; the canal lip catching light ahead (3-park_pit.md:291). The headframe drops out of view in the cut (inference: the arroyo is 10 m deep, 3-park_pit.md:96, and the headframe top clears the plain by 20 m, :43, so it may show over the bank).
- Pull: a drop, gravity down the face and the half-pipe walls funnelling you on.
- Pressure: none. The optional `west_swing` detour through `saguaro_stand` swings you on grapple anchors (3-park_pit.md:97, :339).
- Seconds: inside the 12.6 to 15.8 s first segment (3-park_pit.md:193-198).
- Music: the groove enters on the first landing downbeat (3-park_pit.md:236).
- Panel: NEW `S3-A`, shared with beats 3 and 4.

**Beat 3. The arroyo carve**
- Where: `dump_wash_1..2`, 36 m wide and 10 m deep (3-park_pit.md:96, :124, :360-361).
- You: you pump the walls down to the canal; lines on opposite walls stay more than 8 m apart (3-park_pit.md:214).
- You see: the arroyo bending east toward the canal's straight line.
- Pull: the walls funnel the line downhill into the canal.
- Pressure: none.
- Seconds: the end of the first segment, 12.6 to 15.8 s elapsed (3-park_pit.md:193-198).
- Music: full groove (3-park_pit.md:237).
- Panel: shares `S3-A`.

**Beat 4. The canal lip grind (rope lesson 1 offered: latch)**
- Where: `canal_lip`, a 380 m grind line at y +3, waymark 2, society `hohokam` (3-park_pit.md:98, :363, :34).
- You: you bite the lip with the harpoon and grind it east, or roll its channel (3-park_pit.md:201). This is the first bite on the main line: the canal lip is a `ride_grapple_line` row on route `main`, and the earlier `saguaro_stand` sits only on the optional `west_swing` (3-park_pit.md:98, :338-339, :362). Rolling the channel skips the bite.
- You see: the haul road bending around the canal, and the headframe's top over the rim ahead, because it shows from every plateau cell (3-park_pit.md:39, :43). This is the Warden's second sighting.
- Pull: the line sweeps off the canal onto the rim haul ramp at (-300, -330) (3-park_pit.md:78).
- Pressure: none; no home and no ground-changing event may sit on this row (3-park_pit.md:34).
- Seconds: second segment, 11.9 to 14.9 s; floor line 17.9 s (3-park_pit.md:193-199).
- Music: the grind adds one held lead note (3-park_pit.md:237).
- Panel: shares `S3-A`.

> **NEW `S3-A`, the arroyo to the canal.** 1536x1024. Low chase camera at ball height in a dry arroyo half-pipe, 36 m wide, cinder-red banks, saguaros on the lip, at noon with short shadows. The arroyo bends left into a long straight stone-lined canal running level across the plateau, its lip catching hard light; a dirt haul road visibly detours around the canal. Far ahead, just over the pit's rim, the top of a black steel headframe and its two sheave wheels. Heat shimmer. No ball, no figures. References for continuity: park-pit vista-1 (palette, canal, saguaros), park-pit vista-2 (headframe). No text. Green ancient light only, none here. Copper and rust tones, never brass.

**Beat 5. The rim haul ramp: the reveal**
- Where: `rim_haul_ramp`, 197 m from (-300, -330) to (-140, -215) (3-park_pit.md:78, :364).
- You: you roll up the ramp and crest the rim.
- You see: the rim coming up, then the whole pit below you at the crest, five pale treads and dark face bands down to the floor and the headframe across it. This is the Warden's third sighting (3-park_pit.md:201, :238).
- Pull: a sight line, the pit opening under the crest.
- Pressure: none.
- Seconds: inside the 11.9 to 14.9 s second segment (3-park_pit.md:193-198).
- Music: a 2-bar riser while the rim comes up; the pit reveal is the stage's big drop, on the crest (3-park_pit.md:238).
- Panel: `artifacts/local/alpha/push/w13/concepts/codex/park/park-pit/vista-2.png`, shared with beat 6 (observed: bench treads with trolley poles, the haul road, the headframe and hoist house on the floor, the conveyor gallery on the right wall).

**Beat 6. The cache and the fork**
- Where: `pit` at the bench 1 lip; the cracked cache `cache_lip` at (-134, -215), waymark 3, 6 m off the line (3-park_pit.md:79, :421).
- You: you smash the cache on the way past at cruise, then pick your way down (DESIGN-V3.md:130). Every pilot line splits here (3-park_pit.md:201).
- You see: the north dive kicker at (-80, -177), the haul road starting at (-140, -215), and the rim zip's cable from (60, -280) down to bench 3 (3-park_pit.md:371, :124, :166). The headframe stays on the far side as the target.
- Pull: the choice. Bench lips and kickers for the drop lines; the haul road for the floor line; the rim zip for a rope line.
- Pressure: contraptions `rim_zip` (a 240 m downhill grapple line, rope lesson 2 offered: ride) and `incline_skip` (a 9 s ride down the north wall) (3-park_pit.md:166, :163).
- Seconds: 24.5 to 30.7 s elapsed; floor line 36.8 s (sums of 3-park_pit.md:193-199).
- Music: from here, a fill on each kicker launch (3-park_pit.md:239).
- Panel: shares `park-pit/vista-2.png`.

**Beat 7. The bench descent and the slump**
- Where: `pit` benches 1 to 3, `north_dive`, `east_dive`, `bench2_east_bank`, `tailings_bench_east`, `haul_road_west_1..2` (3-park_pit.md:100-105).
- You: you dive a bench per two bars and land on the downbeat, because treads are about 75 m wide at 27 m/s (3-park_pit.md:27). Sable takes the east dive kicker, Rivet sprints the bench 1 contour across the tailings pond, Kest glides from the bench 2 west lip, Tarn takes the north dive, Tally surges the bench 2 bank, the Cannon dives to bench 3 east (3-park_pit.md:193-198).
- You see: turquoise copper stain on the faces, dark burrow markers on the pale pond, the headframe growing on every dive (3-park_pit.md:292, :150).
- Pull: the next bench lip below, a drop every two bars; every way down ends on the floor bowl at the headframe's foot (3-park_pit.md:201). Beat 7 leads straight to Beat 8, the floor approach. The roaming loop 7a below is a side loop off the bench lips, not a link in the chain.
- Pressure: event `tailings_slump` at clock tier 1 (45 s): a 6 s `ground_slump` telegraph, then the bench 1 to 2 face slumps into a slide ramp over 4 s and opens `tailings_slide` (3-park_pit.md:138). Home `tailings_burrowers` on the pond: slam the 1.6 m marker, which reads from 40 m (3-park_pit.md:150).
- Seconds: inside the 34.8 to 44.1 s third segment; a direct run meets the slump mid-pit at 45 s (3-park_pit.md:193-198, :144).
- Music: a fill on each kicker; the slump is a low sub riser into a dust hit (3-park_pit.md:239, :244).
- Panel: NEW `S3-B`.

> **NEW `S3-B`, the tailings slump.** 1536x1024, two halves split vertically, same camera. Camera on bench 1 of a desert copper pit at noon, at the inner edge of a pale flat tailings pond with dark burrow markers, looking down-slope south-west along the curving 20 m bench 1 to 2 face, streaked turquoise and rust. Left half: a dust curtain lifting along the face and a crawling crack along its foot, the telegraph. Right half, one bar later: the face sheared into one smooth slide ramp down to bench 2, treads intact. The black headframe stands on the far pit floor at frame centre-left. References: park-pit vista-1, park-pit vista-2. No ball, no text. Green ancient light only, none here. Copper never brass.

**Side loop 7a. Mid-pit homes, winzes and Kest's cage (off the chain)**
- Where: `winze_west`, `winze_north`, `winze_east`, `adit_east`, `conveyor_gallery`, `deep_adit`, `switchback_camp` (3-park_pit.md:106-112, :116).
- You: off the measured lines, you slam a winze cap to drop one bench, clear a home, ride the conveyor gallery, or free Kest from the cage on bench 4 west (3-park_pit.md:126, :85). The rescue unlocks Kest (ALPHA-PLAN.md:194).
- You see: white unpooled lamp lenses on the faces and a bright lure bloom in a winze collar's noon shadow (3-park_pit.md:185, :152). Kest's cage at (-144, 110) sits about 56 m from the altar's lit ring at (-170, 60), so the altar signposts the cage (inference from 3-park_pit.md:84-85).
- Pull in, from the bench lips of Beat 7: the altar's lit ring on bench 4, seen across the pit (3-park_pit.md:87), and the bright lure bloom in the `winze_west` collar's noon shadow (3-park_pit.md:152). Homes to clear on the way: `winze_lamps` (-200, 40) and `adit_drill_crews` (215, 30) (3-park_pit.md:82).
- Pull out, back to Beat 8: every way down ends on the floor bowl at the headframe's foot, and each winze cap drops you one bench closer to it (3-park_pit.md:201, :126). The headframe stays in view over the floor (inference: it stands 120 m tall on the floor, 3-park_pit.md:43).
- Pressure: `winze_lamps`, ram at tier 2, 50 hp; `adit_drill_crews`, smash 80 hp, drop on the rig from bench 2 (3-park_pit.md:151-152). At clock tier 2 (90 s): `bench3_drill_barge` with a 10 s telegraph opens `barge_ramp`, and `sump_flood` with a 6 s telegraph closes `sump_floor` (3-park_pit.md:139-140). Tier 3 `deep_adit_wakes` needs veto item 16 (3-park_pit.md:134, :141).
- Seconds: not on a measured line; no number given.
- Music: barge, Brindle's anvil and brass; flood, a rising filtered pad (3-park_pit.md:244).
- Panel: shares `S3-B` (bench faces) and `park-pit/vista-2.png` (conveyor gallery); no new panel.

**Beat 8. The floor approach**
- Where: `pit` floor dish, 260 m across; `haul_road_west_3..5`, `floor_sump`, `hoist_house` (3-park_pit.md:27, :101, :113-114).
- You: you land on the floor bowl and pump it for speed toward the collar. Kest rides `dust_devil_floor` for height, the Cannon recoil-turns to line up a ram (3-park_pit.md:209, :212).
- You see: the headframe filling the frame, the hive low at the collar with its green seams lit, a drone rack forming on the floor (3-park_pit.md:294). Fourth sighting. The edge marker points at the Warden whenever it is off screen (edge_markers.gd:8-12).
- Pull: the 42 m engage ring and the hive's low dwell (3-park_pit.md:45).
- Pressure: contraptions `sump_geyser` (-70, 128) and `tipple_lift` (20, 262), both of which put you on the tipple deck (3-park_pit.md:164-165).
- Seconds: at the Warden at 62.1 to 69.3 s; floor line 81.3 s (3-park_pit.md:193-199).
- Music: bass forward; `landmark_hum` fades in under the band (3-park_pit.md:240).
- Panel: NEW `S3-C`.

> **NEW `S3-C`, the landmark approach.** 1536x1024. Camera in the air just off a bench 2 lip kicker of a desert copper pit at noon, looking down and south across bench 3 to the round dusty floor. A 120 m black riveted steel A-frame headframe fills the right half of frame, two sheave wheels at top, a tipple deck 40 m up, a brick hoist house on its left. Inside the frame a hive of hexagonal cells in dull petrol enamel hangs low at the shaft collar, green pinpricks in its seams; a loose rack of small flat triangle drones forms on the floor before it. References: park-pit vista-3, warden-swarm warden-2, warden-swarm warden-1. No ball, no text. Green ancient light only. Copper never brass.

**Beat 9. The headframe Warden: ride the hoist (rope lessons 3 to 5 offered: fire, drag, shrug)**
- Where: the floor dish round the collar; the hive on the hoist rope, anchor [0, -96, 255] to [0, -66, 255] (3-park_pit.md:335).
- You: in the 4 s low dwell you ram the hive or scatter its drone rack at cruise for 25 posture (swarm.md:74, :99). In the 4 s high dwell you latch a green-rimmed grip cell on its crown, hang under it and fire (swarm.md:76, :110-112). Ride the 2 s rise and the hoist drags you up at 15 m/s and throws you over the tipple deck rail (swarm.md:75, :80). Once a cycle three drones walk your rope and cut it on the pulse; you keep your speed plus the 10 m/s lift (swarm.md:116).
- You see: the hive going up and down inside the frame; the snip as three drones on your rope, the rope's green flickering (swarm.md:116, :132).
- Pull: the 12 s cycle itself, two pulses per cycle at the end of each dwell (swarm.md:72).
- Pressure: the pulse, 10 m/s straight up inside the 30 m ring and 10 damage inside the 6 m core ring (swarm.md:55, :81). Event `hoist_boiler` at Warden phase `chunk_2`: 5 s `boiler_pressure` telegraph, steam cone 24 by 10 m, 6 damage for 8 s, the hoist house roof becomes a ramp aimed at the tipple deck (3-park_pit.md:142). It sits 75 m from the collar, outside the ring (3-park_pit.md:144).
- Seconds: fight 60 to 85 s predicted, because the hive is out of ram reach 8 s in every 12 (swarm.md:177).
- Music: the swarm's G5 buzz over the band, locking into D5 G5 C6 F6 on each pulse; the snip bends G5 up to C6; the winch whine is tuned to G (3-park_pit.md:241, swarm.md:154, :159).
- Panel: `artifacts/local/alpha/push/w13/concepts/codex/park/warden-swarm/warden-2.png` (observed: the hive hanging under the deck in the frame, drones over the floor) with `artifacts/local/alpha/push/w13/concepts/codex/park/park-pit/vista-3.png` for scale (observed: the hive low at the collar, a green ring in the shaft, the hoist house left). The rope-and-snip moment has no picture; it is the climax panel `C-A` below.

**Beat 10. The stagger and the drop from the tipple deck**
- Where: `tipple_deck` at y -60, 40 m above the collar (3-park_pit.md:43, :384).
- You: at 100 posture the hoist brakes and the hive falls to the collar in 1.0 s with its queen open for 4 s (swarm.md:79). Leave the deck within 1 s and the 2.9 s fall lands you on the open queen; or stay latched from the high dwell and ride the brake-drop down; or slam the queen from the floor (swarm.md:79, :120, 3-park_pit.md:47). One chunk per stagger, four chunks (swarm.md:57).
- You see: shutters blown open and the queen swollen and blazing green; each lost chunk is a ring of cells falling into the shaft (swarm.md:133-134).
- Pull: the drop, straight down onto the green.
- Pressure: none in the window: the pulse pauses and no snip runs during a stagger (swarm.md:57, :120).
- Seconds: the 4 s stagger, inside the 60 to 85 s fight (swarm.md:57, :177).
- Music: the chord holds with a tremolo for 4 s; each chunk lost drops its top voice; the boiler whistle rises into a hit on chunk 2 (swarm.md:155-156, 3-park_pit.md:242).
- Panel: NEW `S3-D`.

> **NEW `S3-D`, the drop from the tipple deck.** 1536x1024. Point-of-view shot from the edge of a riveted steel tipple deck 40 m up inside a black A-frame headframe, looking straight down at noon. Far below, at the square shaft collar on a dusty pit floor, a hive of hexagonal petrol-enamel cells has dropped and stopped, every iris shutter blown open, the tall queen cell in the middle swollen and blazing green. The hoist rope runs slack from above into the frame. Stepped bench walls ring the floor; short hard shadows. References: park-pit vista-3, warden-swarm warden-4 (the open cells), warden-swarm warden-1. No ball, no text. Green ancient light only. Copper never brass.

**Beat 11. The break, the bay and the gates**
- Where: gate slot (60, 280) facing +z; bay dock (60, 300), behind and above the gate inside the gates' 110 m hold (3-park_pit.md:49, reward_gates.gd:36).
- You: the hive splits into falling cells and the plate says "Roll through a gate" (swarm.md:136, DESIGN-V3.md:138). Ride the steam cradle up to Moss's bay if you want the practice yard, the lap or a companion change, or roll straight on (bay.gd:11-28, DESIGN-V3.md:248). Roll through one of two arches to take its part; the gate fires you up a rail of rings (reward_gates.gd:11-14, launch.gd:6-10).
- You see: the bay's hover barge over the gates, the headframe dark behind it, the launch arc rising toward the south-west (3-park_pit.md:297).
- Pull: the gate arches, which say what they give while you approach (reward_gates.gd:16-17).
- Pressure: none; no new event starts within 20 s of a Warden break (PARK.md:313).
- Seconds: not given; the bay is opt-in (bay.gd:12-13).
- Music: the chord breaks into detuned notes and stops; the band's next downbeat is the drop (3-park_pit.md:243).
- Panel: NEW `S3-E`.

> **NEW `S3-E`, the bay over the gates.** 1536x1024. Wide shot from the south edge of a desert copper pit's floor at noon, looking north: two roll-through reward arches in the foreground, and a hover barge, a small floating workshop with a banked rim track and a steam cradle, docked just above them. Behind the barge a dark, still black steel headframe whose hive is gone. A rail of hoops arcs up out of frame left toward the south-west. Stepped benches ring the floor. References: park-pit vista-3, park-pit vista-2. No ball, no figures, no text. Green ancient light only, none lit here. Copper never brass.

## Stage 4: The Dig, the sinkhole, the line

Fixed afternoon with the sun in the south-west; underground, light comes in only through skylights and the sinkhole (4-park_sinkhole.md:201-203). The landmark is a uranium-glass green column 4 m wide rising from the nest to `sight_top` [0, 140, 388], because the sinkhole cannot be seen into from the plateau (4-park_sinkhole.md:44).

**Beat 1. The cone rim drop-in**
- Where: `cinder_cone`, north rim, spawn (-330, -760) at y +90, heading 17 degrees; the gate's launch rail lands here (4-park_sinkhole.md:84, :367, launch.gd:9-10).
- You: you roll off the rim into the crater bowl. Kest circles the `cone_thermal` for 70 m of height and glides off (4-park_sinkhole.md:240, :191).
- You see: the crater bowl breached on the far side, black plateau to the horizon with a line of skylights, and far south a thin green column on the skyline, 1,158 m away (4-park_sinkhole.md:326, :220). That column is the Warden. A monsoon cell builds in the south-west.
- Pull: the column on the heading, and the bowl's slope.
- Pressure: none.
- Seconds: inside the first segment, 17.8 to 24.6 s; floor line 26.7 s (4-park_sinkhole.md:224-230).
- Music: wind and the bed only for 3 s; the first downbeat is the first landing in the crater (4-park_sinkhole.md:268).
- Panel: `artifacts/local/alpha/push/w13/concepts/codex/park/park-sinkhole/vista-1.png` (observed: ball on the cone rim, the crater bowl, a channel winding right, three round pits in a line, the green column on the skyline, a thunderhead upper right; the ground reads red sandstone where the page says black basalt).

**Beat 2. The crater bowl and the breach**
- Where: `cinder_cone` into `crater_breach`, a 10 m drop on the south-east (4-park_sinkhole.md:102-103, :392).
- You: you carve the bowl round to the breach and shoot it into the channel. The blazing tier (26.6 m/s) comes in this bowl (4-park_sinkhole.md:245).
- You see: the breach as a gap in the bowl's rim; the column over the far rim (inference: the bowl's rim is 90 m above the plain at most and the column tops at 140 m, 4-park_sinkhole.md:28, :44).
- Pull: a drop, the breach.
- Pressure: none.
- Seconds: inside the 17.8 to 24.6 s first segment.
- Music: the groove enters on the landing; a fill on the breach jump (4-park_sinkhole.md:269).
- Panel: shares `park-sinkhole/vista-1.png`.

**Beat 3. The lava channel**
- Where: `lava_channel_1..2`, a half-pipe of black cinder 30 m wide and 8 m deep (4-park_sinkhole.md:28, :104).
- You: you pump the walls and ride high over the burrower lane, or slam its marker; take the fumarole or drop into the tube mouth at the end (4-park_sinkhole.md:176, :190).
- You see: the fumarole's white steam ahead and the tube mouth's dark throat (4-park_sinkhole.md:327). The column still stands on the skyline from the channel (inference: surface cell, `sight_share` 0.85, 4-park_sinkhole.md:369). This is the Warden's second sighting.
- Pull: the steam plume and the dark throat.
- Pressure: home `cinder_burrowers`, tier 0, every 24 s, max 3, slam 60 hp; every line rides this channel in its first 30 s (4-park_sinkhole.md:176). Contraption `fumarole`, 3.0 s charge, throws you to the tube mouth (4-park_sinkhole.md:190).
- Seconds: inside the 17.8 to 24.6 s first segment.
- Music: full groove; the fumarole launch is a 1-bar riser (4-park_sinkhole.md:270).
- Panel: NEW `S4-A`.

> **NEW `S4-A`, the lava channel.** 1536x1024. Low chase camera in a lava channel half-pipe of loose black cinder with glassy walls, 30 m wide, afternoon sun from the right raking long shadows. Ahead a fumarole vents a tall white steam plume from the channel floor, and beyond it the ground has collapsed into a round skylight, the lava tube's dark throat opening below. On the far skyline, above the black basalt plateau, a thin uranium-glass green light column rises. A monsoon cell builds at upper right. References: park-sinkhole vista-1 (palette, column), park-sinkhole vista-2 (black basalt plateau, cone). No ball, no text. Green ancient light only. Copper never brass.

**Beat 4. The tube mouth: the roof closes**
- Where: `tube_mouth`, a skylight drop 12 m deep at (0, -360), waymark 2 (4-park_sinkhole.md:85, :395).
- You: you drop into the throat and the surface is behind you.
- You see: daylight behind, five tube mouths forking ahead (4-park_sinkhole.md:372-376). The column is gone; from here the edge marker carries the Warden's direction (edge_markers.gd:8-12).
- Pull: a drop, then the forks, one per pilot family (4-park_sinkhole.md:224-229).
- Pressure: none.
- Seconds: the end of the first segment.
- Music: the band drops under a low-pass filter (start 1.2 kHz) as the roof closes (4-park_sinkhole.md:271).
- Panel: shares `S4-A`.

**Beat 5. The upper tubes**
- Where: `main_tube_upper_1..7`, `skylight_chain_1..4`, `skylight_1..3`, `west_gallery_1..4`, `east_drift_1..4`, `cannon_tube_1..4` (4-park_sinkhole.md:106-112).
- You: you slalom S-bends between basalt pillars and fall 43 m to the great room (4-park_sinkhole.md:232). Sable and Tally slingshot pillars, Rivet sprints the flooded west gallery, Kest hops the skylight chain, Tarn claw-pulls the east drift's timber sets, the Cannon recoils down its tube (4-park_sinkhole.md:238-243).
- You see: skylights flashing overhead as bright holes with no light shaft (4-park_sinkhole.md:212); in the west gallery three lamp lures over still water as the only light (4-park_sinkhole.md:328).
- Pull: the tube always falls, and each skylight opens the music for a beat.
- Pressure: home `gallery_lamps`, tier 1, ram 50 hp; at cruise the lure never bends you (4-park_sinkhole.md:177). Home `drift_drill_crews`, tier 1, smash 80 hp; the timber sets every 6 m are harpoon anchors (rope lesson refresher: latch and ride) (4-park_sinkhole.md:178). Contraptions `cave_breath`, `drift_valve`, `cenote_raft` (4-park_sinkhole.md:192, :194, :196). At clock tier 2 (90 s), `junction_machine_wakes` with an 8 s telegraph closes `cannon_tube` (4-park_sinkhole.md:159); every measured line has left the upper tubes by 58 s (4-park_sinkhole.md:167).
- Seconds: inside the second segment, 21.7 to 33.2 s; floor line 32.0 s (4-park_sinkhole.md:224-230).
- Music: the filter opens for one beat under each skylight; `drip_keys` plays sparse notes (4-park_sinkhole.md:272).
- Panel: `artifacts/local/alpha/push/w13/concepts/codex/park/park-sinkhole/vista-2.png` as the overview, shared with beat 6 (observed: a cutaway of flooded tubes with timber walkways, three skylights, the cone behind, the nest and pool at the bottom, the column through the middle; it shows no five-way fork).

**Beat 6. The great room and the hauler bounty**
- Where: `great_room`, a cavern bowl 90 m across at (0, -20), floor y -55; the bounty `bounty_great_room` at (6, -20), waymark 3 (4-park_sinkhole.md:28, :86, :481).
- You: you bank round the bowl and break the hauler on the way through; Sable vaults the lip into the lower tube, the Cannon recoil-turns to line it up (4-park_sinkhole.md:238, :243).
- You see: the one room every tube passes through, and three lower tube mouths falling south (4-park_sinkhole.md:94, :117).
- Pull: the lower tube mouths; `great_room_cap` is a 15 m slam drop onto the main lower tube (4-park_sinkhole.md:146).
- Pressure: contraption `great_room_lift`, rise 50, back up to the main tube's roof shelf (4-park_sinkhole.md:193).
- Seconds: the end of the second segment.
- Music: the filter half-opens and the reverb widens (4-park_sinkhole.md:273).
- Panel: NEW `S4-B`.

> **NEW `S4-B`, the great room junction.** 1536x1024. Wide shot inside a lava-tube cavern 90 m across, a smooth banked basalt bowl under a dark ribbed roof, lit only by the dim sky colour from two small roof skylights and white unpooled miners' lamps. Three tube mouths open high round the upper wall: the main tube, a flooded gallery and a timbered drift; three lower tube mouths fall away on the far side. A rusted ore hauler machine sits near the bowl's centre. A miners' cage lift and a capped shaft in the floor. Cool cave mist. References: park-sinkhole vista-2 (tube shapes, timber), park-sinkhole vista-1 (palette). No ball, no text, no light shafts or pools. Green ancient light only, none here. Copper never brass.

**Beat 7. The lower tubes and the cave-in**
- Where: `main_tube_lower_1..5`, `east_haulage_1..4`, `west_breakthrough_1..4`, `west_tube_roof` (4-park_sinkhole.md:117-120).
- You: you fall another 45 m toward the ring. Rivet and Tally grind the haulage rails; Tarn claws the west breakthrough; Sable and Kest take the main lower tube (4-park_sinkhole.md:118, :239-242).
- You see: the tube's end brightening toward daylight.
- Pull: the brightening tube end.
- Pressure: event `west_roof_cave_in` at clock tier 1 (45 s): a 6 s `crust_crack` telegraph, then a 70 by 40 m roof patch falls into an open trench and opens `plateau_drop`; `hold_clear_m` 20 keeps the fall off the ball (4-park_sinkhole.md:158, :166). A direct run sees it from below at about 51 s (4-park_sinkhole.md:164). The crosscut `sealed_crosscut` can be smashed from west to main (4-park_sinkhole.md:195).
- Seconds: inside the third segment, 18.9 to 23.0 s; floor line 25.6 s (4-park_sinkhole.md:224-230).
- Music: a 2-bar riser as the tube's end brightens; the cave-in is a low sub riser into a rock hit (4-park_sinkhole.md:274, :279).
- Panel: NEW `S4-C`.

> **NEW `S4-C`, the cave-in.** 1536x1024, two halves split vertically, same camera. Inside a black basalt lava tube looking up at its roof. Left half: the roof crust cracks in a glowing ring and dust sifts down, the telegraph. Right half: the roof has fallen away into a 12 m deep trench open to an afternoon sky, rubble banked into smooth ramps along both walls, the tube floor still clear. Far down the tube, its end blazes with daylight. References: park-sinkhole vista-2 (tube interiors), park-sinkhole vista-1 (sky, palette). No ball, no text. Green ancient light only, none here. Copper never brass.

**Beat 8. The burst onto the gallery ring**
- Where: `sinkhole_walls`, `gallery_ring` (y -100, 15 m wide), `caisson_bowl` (4-park_sinkhole.md:48, :441-443).
- You: you burst out of the tube mouth onto the timber ring with the sky open 100 m above (4-park_sinkhole.md:232). After the cave-in, `rim_zip` is a 100 m drop line from the west rim to the ring (4-park_sinkhole.md:197).
- You see: banded basalt and limestone walls, the ring, the pool below and the brood glowing green on the far wall, with the column rising from it (4-park_sinkhole.md:330). Third sighting.
- Pull: the nest itself, inside the 45 m engage ring (4-park_sinkhole.md:369).
- Pressure: home `hive_cells` on the ring, tier 1, every 30 s, max 6, smash 90 hp; its drone racks dive onto a ball in the pool (4-park_sinkhole.md:179).
- Seconds: at the Warden at 62.2 to 79.1 s; floor line 84.3 s (4-park_sinkhole.md:224-230).
- Music: the filter opens fully on the downbeat you hit the ring; `landmark_hum` under the band (4-park_sinkhole.md:275).
- Panel: NEW `S4-D`.

> **NEW `S4-D`, the tube mouth onto the ring.** 1536x1024. From inside a dark lava tube, a round tube mouth ahead blazes with afternoon daylight. Through it, across a sinkhole 250 m wide, the far wall in banded black basalt over pale limestone, a timber gallery ring on posts circling 100 m down, a still turquoise pool below, and on the south wall a honeycomb nest of hexagonal petrol-enamel cells with green pinpricks, a thin green light column rising from it to the sky. References: park-sinkhole vista-3, warden-swarm warden-3. No ball, no text. Green ancient light only. Copper never brass.

## The Warden: The swarm remnant, the climax

**The approach.** The world's last Warden is the brood on stage 4's sinkhole mounting (4-park_sinkhole.md:46). You first read it from the cone rim as the green column, then from the channel, then through the lower tube's mouth as the nest on the far wall (beats 1, 3 and 8 above). Its harpoon hardpoints are two gallery-ring posts 20 m either side of the nest at y -96 and one grip cell on the nest's crown, each with a thick green rim (swarm.md:41, :110).

**Where the rope was offered.** Every lesson below is offered, none is required: the canal lip can be rolled instead of bitten, the rim zip and the saguaro stand are optional detours, and the floor line wins the headframe with no harpoon (3-park_pit.md:201, :166, :339, :47, :199). Latch, offered on the canal lip (stage 3 beat 4). Ride, offered on the rim zip and the saguaro stand (stage 3 beats 2 and 6). Fire from the line, drag and shrug, offered on the headframe's high dwell, rise and snip (stage 3 beat 9). Refresher, offered on the east drift's timber sets (stage 4 beat 5). Drag does not return here: the nest never moves and the pool rises under you instead (swarm.md:113). The first latch the world requires is here, at the brood's first stagger (gaps item 12).

**Beat C1. Engage on the ring**
- Where: `gallery_ring` and `caisson_bowl`; nest anchor [0, -99, 388], 21 m above the pool floor at y -120 (4-park_sinkhole.md:46, :369).
- You: you carve the ring as a wall ride and enter the 45 m engage ring (4-park_sinkhole.md:48).
- You see: the nest static on the south wall, the lamp guard circling over the water, the plate saying "Break its guard" (swarm.md:100, DESIGN-V3.md:136).
- Pull: the lamp guard over the pool, the thing between you and the nest.
- Pressure: the pulse, a 2 s charge every 6 s, 10 m/s straight up inside the 30 m ring (swarm.md:55). `hive_cells` drone racks dive from the ring (4-park_sinkhole.md:179).
- Seconds: the fight runs 45 to 70 s, predicted (swarm.md:178).
- Music: the lamp guard's own sound, then the swarm's G5 buzz locking into D5 G5 C6 F6 on each pulse; the swarm never enters the band (4-park_sinkhole.md:276).
- Panel: `artifacts/local/alpha/push/w13/concepts/codex/park/park-sinkhole/vista-3.png` (observed: the nest on the wall over the round pool, the ring's timber posts in the foreground, waterfalls, the column; no lamp guard).

**Beat C2. Bowl the guard: the nest goes dark**
- Where: the pool floor, water 1.2 m deep at most, so the ball rolls through (4-park_sinkhole.md:48).
- You: you drop off the ring's inner edge and bowl through the lamps at cruise, where the lure never bends you (swarm.md:100). Lead `hive_cells` drones into the lamps as pins (4-park_sinkhole.md:179).
- You see: with the guard down the seams dim to near off and the column dims: push now (swarm.md:135, :48).
- Pull: the dark nest, a 10 s window before the guard respawns (swarm.md:58).
- Pressure: the pulse pops a floor ball 10 m/s up, planar speed untouched (swarm.md:55).
- Seconds: up to 10 s per guard cycle (swarm.md:58).
- Music: the scatter breaks the chord into single detuned notes (swarm.md:153).
- Panel: `artifacts/local/alpha/push/w13/concepts/codex/park/warden-swarm/warden-3.png` (observed: the nest with comb spreading on the wall, timber walkways either side, five green lure lamps hanging over a clear pool with reflections).

**Beat C3. Latch a ring post**
- Where: a ring post 20 m beside the nest at y -96, or the crown cell (swarm.md:110).
- You: from the ring you bite a green-rimmed post from up to 45 m (swarm.md:110, PARK.md:418).
- You see: the rim's green on the post, the line's green flicker (swarm.md:41).
- Pull: the swing out over the pool.
- Pressure: none at the latch.
- Seconds: one 6 s pulse cycle (swarm.md:55).
- Music: the idle G5 unison under the band (swarm.md:150).
- Panel: NEW `C-A`, shared with C4 and C5.

**Beat C4. Ride and fire from the line**
- Where: on the rope over the pool.
- You: you pendulum over the pool or orbit the nest; the winch shortens the line and you do not drop inside the minimum rope; you fire the weapon slot, 1.5 posture a bolt, 3 during the charge (swarm.md:111-112).
- You see: the shutters rippling open base to crown over the charge (swarm.md:129).
- Pull: the charge, when each bolt counts double.
- Pressure: the lamp guard reforming below; drone racks from the ring.
- Seconds: the 2 s charge in each 6 s cycle (swarm.md:55).
- Music: the voices glide from unison toward the chord tones over the charge (swarm.md:151).
- Panel: shares `C-A`.

**Beat C5. The snip and the throw**
- Where: on the rope, 2 s before the pulse.
- You: three drones walk your line from the post; on the pulse they cut it and the cut throws you up the sinkhole wall back onto the ring with your speed plus the 10 m/s lift (swarm.md:116, :118). You can let go early (swarm.md:116).
- You see: three drones walking the rope, the rope's green flickering (swarm.md:116, :132).
- Pull: the throw back to the ring, ready for the next carve.
- Pressure: the snip never stops the ball (swarm.md:116).
- Seconds: 2 s of warning (swarm.md:116).
- Music: a rising buzz, G5 bending up a fourth to C6 as the drones reach you (swarm.md:154).
- Panel: shares `C-A`.

> **NEW `C-A`, the line and the snip.** 1536x1024. Wide shot across a sinkhole's caisson pool in afternoon light. On the banded south wall a honeycomb nest of hexagonal petrol-enamel cells; a timber gallery ring circles the pool on posts, and the post 20 m left of the nest has a thick green rim. A taut harpoon line runs from that post out over the turquoise water to empty air at frame right. Three flat triangle drones walk along the rope toward the free end; the rope flickers green. Small green lure lamps circle low over the pool. References: park-sinkhole vista-3, warden-swarm warden-3, warden-swarm warden-1. No ball, no text. Green ancient light only. Copper never brass.

**Beat C6. The first stagger**
- Where: over the nest, from the line or the pulse lift.
- You: at 100 posture the nest staggers for 4 s, the pulse pauses and every hardpoint holds; swing up over the nest from a post, release above the open queen and haul, or stomp within 3.2 m in plan (swarm.md:57, :120). The first stagger comes from the line, because the floor is 21 m below the nest (swarm.md:93).
- You see: every shutter blown open, the queen swollen and blazing (swarm.md:133).
- Pull: the open queen, the drop finisher's target (PARK.md:414).
- Pressure: none in the window.
- Seconds: the 4 s stagger (swarm.md:57).
- Music: the chord holds with a tremolo for 4 s (swarm.md:155).
- Panel: `artifacts/local/alpha/push/w13/concepts/codex/park/warden-swarm/warden-4.png`, shared with C9 (observed: every cell open and blazing green, the queen brightest, a ring of lower cells breaking off toward the pool, dark drones tumbling, a tan rope at top right).

**Beat C7. A chunk lost: the pool rises**
- Where: `caisson_bowl`, the floor stepping from y -120 to -115, -110, -105 (swarm.md:89).
- You: the lost chunk sheds a ring of cells into the pool, the water bulges for 2 s and the floor rises 5 m over 3 s; it waits while you are grounded on it (swarm.md:89-91). Each step brings the queen 5 m closer, so the fight gets easier as you win (swarm.md:92).
- You see: falling cells, then the swell, then the water higher on the ring's piles.
- Pull: the shorter reach to the nest after each step.
- Pressure: event `pump_boiler` at chunk 2: a 5 s `boiler_pressure` telegraph, a 24 by 10 m steam cone, 6 damage for 8 s, then the fallen boiler is a ramp from the pool to the ring; it sits 63 m from the nest, outside the ring (4-park_sinkhole.md:162, :170). At clock tier 2 (90 s), the monsoon arrives with an 8 s lead and threads of waterfall down the walls, and the handling stays the same (4-park_sinkhole.md:206-208).
- Seconds: 2 s swell and 3 s rise per step (swarm.md:90).
- Music: a low water swell, and the chord loses its top voice, F6 then C6 then G5 then D5 (4-park_sinkhole.md:277, swarm.md:156).
- Panel: NEW `C-B`.

> **NEW `C-B`, the pool step.** 1536x1024. View from the timber gallery ring across a sinkhole's caisson pool in afternoon light. On the banded south wall a honeycomb nest of hexagonal petrol-enamel cells; one outer ring of its cells is breaking away and falling into the turquoise water. The pool surface bulges in a broad swell where they land, and the water line stands visibly higher on the ring's timber piles than a dark tide mark below it. Thin monsoon waterfall threads run down the walls; a green light column rises from the nest. References: park-sinkhole vista-3, warden-swarm warden-4, warden-swarm warden-3. No ball, no text. Green ancient light only. Copper never brass.

**Beat C8. The last stagger: the drop finisher**
- Where: above the nest, the floor now at y -105, 6 m under the nest's centre (inference from swarm.md:89 and 4-park_sinkhole.md:46).
- You: swing up over the nest from a ring post, release above the open queen and haul; the harpoon is a drop finisher, never a bowl hammer (swarm.md:120, PARK.md:414). With the floor this close, a stomp after the pulse's lift also reaches (inference from swarm.md:93).
- You see: the queen blazing green straight below you.
- Pull: gravity, straight down onto the green.
- Pressure: none in the window.
- Seconds: the 4 s stagger.
- Music: the held chord under tremolo, then the break cadence (swarm.md:155, :157).
- Panel: NEW `C-C`.

> **NEW `C-C`, the drop finisher.** 1536x1024. Point-of-view shot from the top of a harpoon swing above a sinkhole's south wall, looking straight down in afternoon light. Below, a honeycomb nest of hexagonal petrol-enamel cells clings to banded limestone over a turquoise pool raised close beneath it; every iris shutter is blown open and the tall queen cell in the middle swells and blazes green. A taut rope runs from a green-rimmed timber post on the gallery ring up out of frame. References: warden-swarm warden-4, park-sinkhole vista-3, warden-swarm warden-1. No ball, no text. Green ancient light only. Copper never brass.

**Beat C9. The break and the exit**
- Where: the pool flooded to the ring at y -100; gate (0, 305) facing the arriving ball; bay dock (0, 320) (swarm.md:89, 4-park_sinkhole.md:50, :369).
- You: the dome splits along its seams and the drones drop as dead triangles (swarm.md:136). The plate says "Roll through a gate" (DESIGN-V3.md:138). You take a part and the gate fires you up a rail of rings out of the sinkhole's throat (reward_gates.gd:11-14, launch.gd:6-10, 4-park_sinkhole.md:333). Each world's last stage launches you into its boss arena: the Waking, then world 3 (field_notes.gd:25). The brood is world 2's climax; the Waking is an interlude after it, not part of that climax (veto call 8; PARK.md:383 names the Waking only as a boss arena). You carry the parts you took, the scrap you grew and the Cogs you earned; Kest is unlocked if you freed the cage (ALPHA-PLAN.md:192, :194).
- You see: flat bright water, the nest dark and dripping, the column dead, the bay's barge docked over the water (4-park_sinkhole.md:333, swarm.md:48).
- Pull: the gate arches, then the arc up the open throat.
- Pressure: none for 20 s (PARK.md:313).
- Seconds: not given.
- Music: the chord breaks into single detuned notes and stops; the band's next downbeat is the drop (4-park_sinkhole.md:278).
- Panel: NEW `C-D`, with `warden-4.png` for the break itself.

> **NEW `C-D`, the exit.** 1536x1024. Wide shot from the gallery ring of a sinkhole in late afternoon light. The caisson pool has flooded level with the timber ring, flat and bright. On the banded south wall the honeycomb nest hangs dark and dripping, seams unlit, no light column. A small hover barge workshop docks over the water beside two roll-through reward arches on the ring. A rail of hoops arcs up the sinkhole's open throat toward a warm sky. References: park-sinkhole vista-3, warden-swarm warden-3, park-pit vista-3 for the barge's world. No ball, no figures, no text. Green ancient light only, none lit here. Copper never brass.

## Overhead route

The plot tool draws each route from the appendix's `routes[].via` row ids, at each row's `at` [x, z] in metres with `y` (null on the surface), `size` [length, height, width] and `yaw_deg`; the landmark row carries `at`, `sight_top` [x, y, z], `warden.anchor` [x, y, z], `bay_dock.at` and `gate_slots[].at` (3-park_pit.md:91, :335, 4-park_sinkhole.md:369, PARK.md:117-118).

**Stage 3, `park_pit`** (3-park_pit.md:338, :340-342).
1. Start: spawn (-560, -770), heading 15 degrees.
2. `main`: `spoil_dump`, `dump_wash_1`, `dump_wash_2`, `canal_lip`, `rim_haul_ramp`, `pit`, `haul_road_west_1`, `haul_road_west_2`, `haul_road_west_3`, `haul_road_west_4`, `haul_road_west_5`.
3. Branches from `rim_haul_ramp`: `bench_dive` (`pit`, `east_dive`), `north_dive` (`pit`, `north_dive`, `adit_east`), `east_benches` (`pit`, `switchback_camp`, `tailings_bench_east`, `bench2_east_bank`).
4. Warden site: headframe at (0, 255), hive anchor [0, -96, 255], path to [0, -66, 255]; finisher platform `tipple_deck` at (0, 240), y -60 (3-park_pit.md:335, :384).
5. Gate (60, 280); bay dock (60, 300).

**Stage 4, `park_sinkhole`** (4-park_sinkhole.md:372-378).
1. Start: spawn (-330, -760), heading 17 degrees.
2. `main`: `cinder_cone`, `crater_breach`, `lava_channel_1`, `lava_channel_2`, `tube_mouth`, `main_tube_upper_1` to `main_tube_upper_7`, `great_room`, `main_tube_lower_1` to `main_tube_lower_5`, `gallery_ring`, `caisson_bowl`.
3. Upper branches from `tube_mouth` to `great_room`: `west_gallery`, `east_drift`, `skylight_chain`, `cannon_tube`. Lower branches from `great_room`: `east_haulage`, `west_breakthrough`, each ending on `gallery_ring`.
4. Warden site: sinkhole at (0, 350), nest anchor [0, -99, 388], empty path; light column to `sight_top` [0, 140, 388] (4-park_sinkhole.md:369).
5. Gate (0, 305); bay dock (0, 320).

## Connecting material

**This way, and the Warden is that way.**
- Green (#9dff3c) means the ancients and nothing else: the hive's seams, the hardpoints' rims, the stage 4 column (swarm.md:41, :46-48). Green on the skyline is always the Warden.
- The headframe's silhouette shows over the rim from every plateau cell; the column clears the plateau by 140 m (3-park_pit.md:43, 4-park_sinkhole.md:44).
- Under a roof or behind a wall, the edge-of-screen chevron points at the Warden with the plate's glyph (edge_markers.gd:8-12).
- Gravity is the stage 4 signpost: every tube descends from the mouth at y -12 to the ring at y -100 (4-park_sinkhole.md:98).
- Amber means an offer: the activity markers (DESIGN-V3.md:140, :143). White unpooled lamps are mining dressing and never point anywhere (3-park_pit.md:185, 4-park_sinkhole.md:213).
- Sound: `landmark_hum` fades in when the Warden is near (3-park_pit.md:240, 4-park_sinkhole.md:275); the filter opens as the roof opens (4-park_sinkhole.md:271-275).

**Activities, and where the line first shows them.**

| Stage | Activity | Where | First seen from the line |
| --- | --- | --- | --- |
| 3 | Cracked cache `cache_lip` | (-134, -215), on the line | Beat 6, at the crest, 6 m off the line (3-park_pit.md:79) |
| 3 | Enemy camp `switchback_camp_site` | (180, -150), pays `rivet_plating` | Beat 1, its smoke from the dump top (3-park_pit.md:87, :422) |
| 3 | Ambush altar `bench4_altar` | (-170, 60) | Beat 1, a lit ring on bench 4 across the pit (3-park_pit.md:87) |
| 3 | Rescue, Kest's cage (`rescue_rows`, not an activity row) | (-144, 110) | Beat 5 at the crest, beside the altar's ring (inference from 3-park_pit.md:84-85) |
| 4 | Hauler bounty `bounty_great_room` | (6, -20), on every line | Beat 6, in the great room (4-park_sinkhole.md:94) |
| 4 | Enemy camp `cenote_camp` | (-300, -170), pays `pylon_capacitor` | Beat 5, its lamps from the west gallery (4-park_sinkhole.md:94, :482) |
| 4 | Cracked cache `trench_cache` | (-520, -120) | Off every measured line; a roaming loop under the granaries (4-park_sinkhole.md:94) |

**The music across the world.** Both stages ride synth theme 1, `dig_upper` then `dig_deep` (3-park_pit.md:231, 4-park_sinkhole.md:264). Each stage opens thin and lets the groove in on the first landing, so the drop-in is the music drop (3-park_pit.md:235-236, 4-park_sinkhole.md:268-269). Stage 3 builds to its reveal at the rim; stage 4 muffles under the roof and opens fully on the ring (3-park_pit.md:238, 4-park_sinkhole.md:271-275). The swarm's chord is the same object in both fights: G5 unison, the D5 G5 C6 F6 lock on each pulse, one voice lost per chunk, the drop on the break (swarm.md:150-157). The headframe fight teaches the chord's countdown; the brood fight pays it off with the water swell under each lost voice (swarm.md:159).

## Gaps and calls

**Calls made under the creative charge (veto list).**
1. The rope is offered across stage 3, never required there: latch on the canal lip, ride on the rim zip and saguaros, fire, drag and shrug on the headframe. Stage 4's east drift timber sets are the refresher. The first required latch is the brood's first stagger (gaps item 12).
2. Under the stage 4 roof, the edge-marker chevron is the Warden's signpost (edge_markers.gd:8-12). No new light: the lamp veto holds (4-park_sinkhole.md:210-216).
3. Kest's cage is signposted by the altar's lit ring 54 m away; no new marker (3-park_pit.md:84-85, :87).
4. Stage 4 keeps no rescue: Kest is the Dig's one rescue (ALPHA-PLAN.md:194). This answers 4-park_sinkhole.md:351 for this board.
5. The bay is the world's breather: opt-in, no event for 20 s, companion changes at the intermission (bay.gd:12-13, PARK.md:313, DESIGN-V3.md:248).
6. Tier 2 events and weather may fire during either fight, because direct runs arrive at 62 to 79 s and tier 2 starts at 90 s. They stay as written: every site is outside the engage ring (3-park_pit.md:144, 4-park_sinkhole.md:164-170).
7. The stage 4 exit goes to the Waking's arena, then to world 3 (field_notes.gd:25). The park pages do not place it (PARK.md:383).
8. The brood is world 2's climax and endpoint; the Waking is an interlude after it, not part of world 2's climax. The pages name the Waking only as one of the boss arenas (PARK.md:383), so this is a call for Andrew to confirm or veto.

**What the pages did not settle.**
1. Per-beat seconds. The pages give three segment times per line, so beats inside one segment share a time (3-park_pit.md:193-199, 4-park_sinkhole.md:224-230). KD3 and KD4's bots should log a time at each beat's row.
2. The stage 3 fork at the cache has no stated pull toward one route for a non-Sable player (3-park_pit.md:201). The board uses the visible kickers and the haul road. Back to the stage page: name the read for each route.
3. The floor line's last 88 m, from the haul road's end at (-60, 320) to the collar, has no row or pull (3-park_pit.md:124). Back to the stage page.
4. Fire from the line is a Warden-anchor rule; no page says it works on world lines like the rim zip (PARK.md:420, swarm.md:112). The board teaches it at the headframe.
5. The `sump_flood` at 90 s can flood the sump round `sump_geyser` mid-fight; the page does not say whether the geyser still fires under 1.2 m of water (3-park_pit.md:140, :165). Back to the stage page.
6. Event risers can play over the swarm chord during a fight. The pages give no priority rule (3-park_pit.md:244, 4-park_sinkhole.md:279). For KE8.
7. Stage 3's exit beat has no panel name, and the bay is a landmark field, not a park row (3-park_pit.md:297, PARK.md:117). The journey board needs a panel key for the exit, for example `p7_exit`. Back to PARK.md section 6.1.
8. Stage 4's breach row centre (-275, -615) sits off the drafted line waypoints, so the breach is not a sure pull (4-park_sinkhole.md:392, :253). Back to the stage page.
9. Picture mismatches. Stage 4 vista-1 shows red sandstone where the page says black basalt (4-park_sinkhole.md:326). Stage 3 vista-1 shows the headframe standing in the pit centre, not over the far rim (3-park_pit.md:290). Swarm.md's veto item 1 moves the finisher to the tipple deck while PARK.md:430 still says the sheave wheel (swarm.md:83).
10. The rescue has no schema home (3-park_pit.md:315). Tier 3 events need veto item 16 and never fire without it (3-park_pit.md:134, 4-park_sinkhole.md:161).
11. The bay and the launch have no music cue of their own beyond the break's drop (3-park_pit.md:243). The board leaves the band running and gives the bay its jukebox (bay.gd:25-27).
12. No rope lesson is required before the brood. The canal lip can be rolled, the rim zip and the saguaro stand are detours, and the floor line wins the headframe without a harpoon (3-park_pit.md:201, :166, :339, :47, :199). The first required latch is the brood's first stagger from the line: the nest sits 21 m above the first pool floor, so early staggers come from the line and the pulse (swarm.md:87, :93). A player can meet that latch cold. Back to the stage page: decide whether one stage 3 rope moment becomes required, or whether the brood's ring posts teach it on the spot.
13. Several load-bearing cites point outside the stage pages, the kind sheet and PARK.md: `edge_markers.gd` (the only Warden signpost under the stage 4 roof, call 2), `field_notes.gd` (the Waking), `ALPHA-PLAN.md` (Kest, the Cogs), `bay.gd`, `launch.gd`, `reward_gates.gd` and `DESIGN-V3.md`. The coordinator should confirm each against its source file before Andrew reads the board.
