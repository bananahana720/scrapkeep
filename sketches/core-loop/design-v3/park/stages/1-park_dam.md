# Stage 1, `park_dam`: Spillway: the dam

World 1, Spillway Works. Warden kind `reactor` on the `dam_face` mounting, variant `""`. Time of day `dawn`. Storyboard board id `park-1-park_dam`. Status: draft for Andrew's approval (unit K-W1, 2026-10-10). Every number is a starting value to tune in play unless a file:line backs it.

This page follows the park schema in `design-v3/PARK.md` section 2 and `adr/TADR-011-park-terrain-and-warden-kinds.md`. The draft park file in section 13 passed a scratch copy of the 2.10 checks, the route test over every allowed event overlap, and the line estimates in section 9. Nothing here touches `src/`.

## 1. The stage in one paragraph

You drop in at dawn onto a survey deck on the top shelf, 1.3 km north of the dam. The dam's crest and its green beam sit on the skyline the whole way down. The shelf rolls over slickrock domes to a lip, the lip throws you into one of three runs cut 25 m into the plateau (two slot canyons and a concrete-lined wash), and all three meet at the Eye, a hole worn through a sandstone fin. From the Eye you choose how to fall 100 m into the river canyon: down the spillway tunnel, along the cliff-room ledges, straight down the construction incline, or across the pipeline bridge and down the east haul road. Every way lands on the toe apron, under a 120 m concrete face with a reactor relic clamped to it 22 m up. The face is the biggest quarter pipe in the game.

## 2. Arizona landform and society layer

**Landforms** (PARK.md:73). Slickrock domes and a ramped top shelf; two slot canyons and a lined arroyo cut into a 100 m plateau; a river canyon and an east side gorge (`river_canyon`, a landform this pass adds to PARK.md 2.2 so the horseshoe bend stays stage 2's); a mesa-rim west wall; the dam face and its plunge pool (`dam_face`); a spillway tunnel through the west abutment. The canyon floor sits near y 0, the plateau at y 100, the top shelf at y 150 on its north edge. A `ramp` or `drop` stamp falls by its height from its start to its end along its yaw (a convention this draft proposes for the bake, PARK.md:236 leaves it open).

**Society layers** (PARK.md:74, 301).

| Society | Where | What it left |
| --- | --- | --- |
| `none` (water and time) | the domes, the slots, the canyon, the gorges | the ground itself |
| `dam_era` | the survey deck, the wash liner, the overflow channel and spillway tunnel, the service ledge, the incline, the pipeline bridge, the haul road, the powerhouse, the dam | concrete, stencils, gauges, the crews' humour |
| `ancestral_puebloan` (reference) | the cliff rooms in the west wall and their viga beams | rooms and roof beams, ridden as ledges and swing pivots only |
| `dam_era` (headworks) | the canal lips on the east bench | the crews' concrete canal headworks, ridden as a grind line; the Hohokam canal layer belongs to stage 2 and the pit |
| `ancient` | the Eye's carved marks, the vent pits at the dam's east toe, the relic itself | uranium-glass green (#9dff3c) seams; the thing that woke |
| `fleet` | nothing at start; a dropship lands on the east bench at tier 1 | a crew home |

The guardrail holds: the cliff rooms house no home, are no event's site, and carry only `ref_` fragments. The canal lips are dam-era concrete, so world 1 shows each real culture once: the cliff builders here, the canal builders on stage 2. The lobbers live on the dam-era service ledge, not in the rooms (PARK.md:589).

## 3. The hero landmark and the Warden's mounting

**The spillway dam** (`landmark_dam`, `hero_landmark` budget, PARK.md:490). A curved concrete arch 320 m along the crest and 120 m tall, centred at [0, 620], facing -z (yaw 180) toward the whole park. Its crest sits at y 121, above the plateau's y 100, so the crest line and its two gate towers break the skyline from every open cell on the plateau. `sight_top` is [0, 141, 640], the gate tower tops. `light` is `ancient_beam`: a uranium-glass green column rises from the relic past the crest, so the dam reads through the monsoon haze at tier 2.

**The mounting, `dam_face`** (PARK.md:424). The relic clamps to the face's centreline, anchor [0, 22, 590], 22 m above the toe apron. The face is a quarter pipe: it curves from flat at the toe (z 560) to vertical at about 30 m up. The engage ring is centred on the toe apron at [0, 575] with `reach_m` 30, the same radius as today's `beacon_radius` (`alpha_defs.gd:71`), so the pulse ring and the posture bands keep today's geometry.

**What the mounting adds.** On every pulse the two spillway gates over the relic open and a 24 m wide water sheet runs down the face for 3 s. The sheet is a ride, not a push: a ball that enters it from the apron rides up the face along the sheet to the relic's core height, keeping its planar speed. Missing the sheet costs nothing, because the dry face is still a quarter pipe. The full rule lives in `design-v3/wardens/reactor.md`.

**The exit.** The three reward gates stand on the toe apron at z 528, facing +z, toward the face. Moss's bay docks 61 m behind them and 46 m up, as `bay.gd` already places it (`bay.gd:37-41`, `143-153`), so `bay_dock.at` is [0, 467]: the slot and the search agree. The launch throws you up the face and over the crest, into the reservoir country that feeds stage 2's weir.

## 4. Region sketch

Top-down, 80 m cells. `~` marks the six planned pilot lines; letters are regions; capitals are placed things (a capital hides the cell's region letter). Generated from the draft park file by the scratch builder, so it matches section 13.

```
x from -800 (left) to 800 m (right); z from -800 (top) to 800 m (bottom); one cell = 80 m
  -800 t t t t t t t t t t t t t t t t t t t t
  -720 t t t t t t t t D t t t t t t t t t t t
  -640 t t t t t t t t ~ ~ t t t t t t t t t t
  -560 t t t t t t t ~ E t t t t t t t t t t t
  -480 t t t t t t t t ~ t C t t t t t t t t t
  -400 t t t t t t t t t A t t t t t t t t t t
  -320 w w w w w w w ~ ~ ~ ~ s e e e e e e e e
  -240 w w w w w w w ~ ~ ~ ~ ~ e e e e e e e e
  -160 w w w w w w w ~ ~ ~ C s e e e e e e e e
   -80 w w w w w w w E ~ ~ s ~ e e e e e e e e
     0 w w w w w w w w ~ ~ ~ s e e e e e e e e
    80 w w w w w w w w ~ ~ ~ s e e e e e e e e
   160 r r r r r r r A ~ ~ ~ ~ g g g g g g g g
   240 r r r r r r ~ ~ ~ ~ c ~ ~ b b b b b b b
   320 r r r r r r r H ~ ~ c c ~ E b b b b b b
   400 r r r r r r r C C ~ B E C ~ A b b b b b
   480 r r r r r r r r E C G E ~ b b b b b b b
   560 r r r r r r r r d ~ W ~ C b b b b b b b
   640 r r r r r r r r d d ~ d b b b b b b b b
   720 r r r r r r r r d d d d b b b b b b b b
```

| Code | Region | What happens there |
| --- | --- | --- |
| t | The top shelf | Drop-in deck, slickrock domes, the domes camp (first waymark), the domes cannon |
| w | West slickrock | The west wash, a concrete-lined arroyo half-pipe with the chasers' culverts |
| s | The slots | The upper slot and the corkscrew slot, both 22 to 26 m deep; the bulkhead |
| e | East slickrock | Open slickrock; space KD1 fills with hoodoo and saguaro rows |
| r | West rim and cliff rooms | The overflow channel, the spillway tunnel, the cliff rooms, the service ledge, the rim cache |
| c | The river canyon | The incline's foot, the tailwater bar, the plunge pool's north side |
| g | The east gorge | A 70 m wide side gorge the pipeline bridge crosses at plateau height |
| b | East bench and canal | Bench flats, the canal lips, the haul road, the dropship landing, the altar |
| d | The dam and its toe | The toe apron, plunge pool, powerhouse, vent pits, the face and crest |

Placed things:

```
H culvert_chasers [-165, -65]
H ledge_lobbers [-125, 490]
H powerhouse_trappers [120, 505]
H outlet_brutes [-195, 375]
H dropship_winches [300, 380]
C rim_zip [230, 470]
C crest_trebuchet [170, 560]
C pool_geyser [-110, 540]
C spray_thermal [-40, 520]
C gallery_valve [-170, 455]
C slot_bulkhead [70, -90]
C domes_cannon [60, -450]
C service_lift [-125, 470]
A domes_camp [-51, -396]
A rim_cache [-200, 215]
A bench_altar [330, 420]
E plunge_pool_flood [-85, 515]
E west_wash_flash_flood [-165, -65]
E dome_lightning [-110, -520]
E east_bench_dropship [300, 380]
E toe_vents_wake [140, 440]
E powerhouse_boiler [120, 505]
B bay dock [0, 467]
G gate row [0, 528]
L spillway_dam (landmark) [0, 620]
W Warden engage ring centre [0, 575]
D drop-in [-150, -690]
```

The three activities, signposted from the drop-in: the domes camp (`enemy_camp`, today's chaser pack and the named `hot_rivets` pay, `map_spillway.gd:98`), the rim cache (`cracked_cache`) and the bench altar (`ambush_altar`). Rules from `activities.gd:29-47`. The camp is also the first waymark: lines pass its point within 12 m, and its ring starts only inside 8 m (`activities.gd:31`), so the fight is a choice made at speed.

## 5. `park_rows` draft (29 rows)

The spine of the park. KD1 grows it to the 40 to 70 rows PARK.md:67 asks for, mostly height-only filler rows (hoodoo fields, saguaro stands, dry washes) in the empty east slickrock and west plateau, so the density test (no open cell more than 80 m from a non-ground row, PARK.md:474) passes. The full rows are in section 13.

| Row | Element / landform / society | Verb, ride fact | Note |
| --- | --- | --- | --- |
| `canyon_country`, `shelf_rise` | ground / slickrock / none | roll | the 100 m plateau and the 50 m shelf ramp |
| `top_shelf_deck` | drop / slickrock / dam_era | drop, `ride_drop` | the drop-in deck, 10 m |
| `slickrock_domes` | bank / slickrock / none | bank, `ride_hop` | rollers that keep the shelf from going quiet |
| `shelf_lip` | kicker | launch, `kicker_launch` | throws you into the slots |
| `west_wash` | half_pipe / arroyo / dam_era | pump, `ride_chute` | home `culvert_chasers` |
| `upper_slot`, `corkscrew_slot` | flow_line / slot_canyon / none | roll, `ride_chute` | 120 m and 90 m wide meander bands |
| `the_eye` | tunnel / slickrock / none | roll, `ride_chute` | waymark; hole; ancient marks |
| `west_rim_bench` | bank / mesa_rim / dam_era | bank, `ride_bowl` | the overflow channel on the rim |
| `spillway_tunnel` | tunnel / spillway_tunnel / dam_era | drop, `ride_drop` | 100 m inclined drop; home `outlet_brutes` |
| `outlet_bucket` | kicker | launch | the flip bucket |
| `cliff_rooms_west`, `viga_span` | elevated_line, anchor_field / cliff_dwelling / ancestral_puebloan | roll, swing | `ref_` only |
| `service_ledge` | ledge / mesa_rim / dam_era | roll, `ride_ledge` | home `ledge_lobbers` |
| `construction_incline` | drop / mesa_rim / dam_era | drop, `ride_drop` | the floor line's 94 m drop |
| `river_canyon`, `east_gorge` | ground / river_canyon / none | | channel stamps |
| `tailwater_bar` | flow_line / dry_wash / none | roll | gravel bar to the toe |
| `pipeline_bridge` | grind_line / pipeline / dam_era | grind | y 100 across the canyon mouth |
| `east_bench_flats` | ground / slickrock / none | | dormant home `dropship_winches` |
| `canal_lips` | grind_line / canal / dam_era | grind | `dam_era_canal_headworks` |
| `east_haul_road` | drop / mesa_rim / dam_era | drop | 100 m switchback road |
| `east_abutment` | ledge / dam_face / dam_era | roll | the trebuchet's shoulder |
| `plunge_pool`, `toe_apron`, `toe_vent_pits` | bowl, bank / dam_face | bank, `ride_bowl` | the fight floor and its neighbours |
| `powerhouse` | ledge / dam_face / dam_era | roll | home `powerhouse_trappers` |
| `crest_rail` | rail / dam_face / dam_era | grind | y 121 along the crest |

## 6. `event_rows` draft (6 rows)

| Row | Family, kind | Site | Trigger | Telegraph | What changes | Route change |
| --- | --- | --- | --- | --- | --- | --- |
| `plunge_pool_flood` | natural, `flood_fill` | plunge pool | tier 1 (45 s) | 6 s `flood_rising` | 3 m of water for 35 s | closes `pool_floor`, opens `pool_rim` (PARK.md:327-333, kept as written) |
| `west_wash_flash_flood` | natural, `flash_flood` | west wash | tier 2 (90 s) | 6 s | 1.6 m for 30 s, deeper than the 1.2 m roll-out depth (PARK.md:294) | closes `west_wash_run` |
| `dome_lightning` | natural, `lightning` | slickrock domes | tier 3 (135 s) | 3 s `lightning_charge` | 6 m strikes, 8 damage, no ground change | none |
| `east_bench_dropship` | fleet, `fleet_landing` | east bench flats | tier 1 | 10 s `fleet_inbound` | a dropship lands and wakes `dropship_winches` | opens `dropship_ramp` |
| `toe_vents_wake` | ancient, `machine_eruption` | toe vent pits | tier 2 | 8 s `ancient_stirring` | a `reactor_relic` miniboss erupts at the east toe | none |
| `powerhouse_boiler` | industrial, `boiler_burst` | powerhouse | Warden `chunk_2` | 5 s `boiler_pressure` | steam cone 24 by 10 m, 6 damage, 8 s; the roof becomes a ramp | closes `powerhouse_floor`, opens `roof_ramp_line` (PARK.md:357-363, kept) |

Why these. The flood and the boiler are PARK.md's signature events for this stage (PARK.md:383). The vent pits teach the reactor's tell before the fight: the first relic erupts on the canyon floor at about the time most lines arrive (tier 2 is 90 s; the lines' estimates are 84 to 98 s), so the player hears the Ab pedal and sees a vent blow once, small, before the Warden. Tier 3 exists only with veto item 16 (`MAX_TIME_TIERS` from 2 to 4, PARK.md:588); without it the lightning row never fires. The relic comes as an event, not a home, because a home's pack must be one of the stage's packs (PARK.md:154, 225) and no pack holds `reactor_relic` (`alpha_defs.gd:42-47`).

The route test passed in scratch: with every allowed overlap (at most two ground changers, one Fleet, one ancient, PARK.md:311), `drop_in` still reaches `landmark`. The `face` route never closes.

## 7. `home_rows` (5 homes, one per kind)

| Home | Kind | Site, landform | Advantage | Counter | Reinforce | Break |
| --- | --- | --- | --- | --- | --- | --- |
| `culvert_chasers` | chaser | west wash, arroyo | The lunge lane is a straight 11 m strip (`chaser.gd:14`), and the wash floor is the shelf's longest straight | Pump the wash wall: the lane lies on the floor (`chaser.gd:3-8`) | tier 1, every 25 s, 5 alive, `run_down` | ram, 60 hp, 12 scrap |
| `ledge_lobbers` | lobber | service ledge, mesa_rim | 24 m up the west wall, inside 75 m of the plunge pool and the west toe (`lobber.gd:12`) | Change line under the shell (`lobber.gd:3-7`), or ride the ledge and slam them | tier 1, 30 s, 4, `grounded` | slam, 80, 14 |
| `powerhouse_trappers` | mag_trapper | powerhouse, dam_face | A ball off a drop arrives light on the flat apron; the pit bends a light line | Grow past the rating, or jump the disc (`mag_trapper.gd:6-9`) | tier 2, 35 s, 3, `grounded` | smash, 90, 16 |
| `outlet_brutes` | plated_brute | spillway tunnel | The tunnel puts every ball on one landing spot inside a 6 m slam ring (`plated_brute.gd:12`) | Take the flip bucket over the ring and land on the brute | tier 2, 45 s, 2, `elite` | damage, 140, 20 |
| `dropship_winches` (dormant) | winch_drone | east bench, slickrock | Drones hover 5.5 m over bare rock (`winch_drone.gd:13`) and reel a crossing ball toward the crew | Hold 19 m/s across the bench or jump: the cable snaps (`winch_drone.gd:20`) | tier 1, 30 s, 3, `elite` | damage, 70, 14 |

All five set `stops_kind` true. Reinforcement numbers are starts for KE6, which spawns arrivals from live homes 60 to 250 m ahead (PARK.md:536).

## 8. `contraption_rows` (8 rows), weather and time of day

| Row | Kind, skin | Where | What it does for the line |
| --- | --- | --- | --- |
| `domes_cannon` | launcher, `cannon` | top shelf | Fires you 117 m over the shelf lip into the corkscrew's head |
| `slot_bulkhead` | cracked_wall | corkscrew slot | Breaks at cruise (`break_at_cruise`, as `map_reach.gd:225`) into a cut-through |
| `service_lift` | lift, `lift_platform` | service ledge | Lifts 24 m from the canyon floor to the ledge |
| `gallery_valve` | valve, `gauge` | service ledge | Opens a cache pocket in the gallery; new codex row `spillway_gallery_cache` |
| `rim_zip` | cable | east haul road | A 175 m zip from the plateau edge to the toe |
| `crest_trebuchet` | launcher, `trebuchet` | east abutment | Throws you onto the crest rail; the crest line drops down the face onto the relic |
| `pool_geyser` | launcher, `geyser_vent` | plunge pool | Lobs you onto the face 10 m above the relic: a drop-finisher setup during a stagger |
| `spray_thermal` | thermal | toe apron | The spillway's spray column, 60 m: another way above the relic |

Keys are exactly today's spec keys (`map_gorge.gd:345-369`, `map_reach.gd:226-236`).

**Time of day: `dawn`** (PARK.md:374, 387). Low sun from the east puts the dam face in shade and its green seams bright; the canyon floor is in shadow until the drop. A `TIME_ROWS` row for KE7.

**Weather.** `dawn_still` (clear, always) and `monsoon_buildup` from tier 2: 20 s warning, 90 s live, 60 s gap, grey fog at 0.0014, a `storm_build` sky, far thunder, a `monsoon_pad` music layer, and event odds 2.5 times for the wash flash flood, 3 times for the dome lightning, 1.5 times for the pool flood. `handling` is `"none"`.

## 9. Traversal lines

Four waymarks: `drop_in`, `domes_camp`, `the_eye`, `landmark`. The bands are PARK.md:452-468. The estimates below assume a 20 m/s mean (start; cruise is 14 m/s and the blazing tier 26.6 m/s, PARK.md:462); the bot's runs replace them.

**The flow line a skater would take** (Rivet's and the floor line): drop off the deck, carve the domes left, right, left, catch the shelf lip, pump the upper slot's meanders, shoot the Eye, take the incline's 94 m drop straight down the canyon wall, roll the tailwater bar and arrive on the toe apron carrying the descent's speed. No harpoon, no contraption.

| Line | Path (m) | Length ratio (band 1.3 to 2.0) | Segments (m) | Est. segment s (band 12 to 45) | Est. drop-in to Warden s (band 60 to 120) |
| --- | --- | --- | --- | --- | --- |
| Sable | 1877 | 1.47 | 440, 736, 701 | 22, 37, 35 | 94 |
| Rivet | 1672 | 1.31 | 440, 767, 465 | 22, 38, 23 | 84 |
| Kest | 1867 | 1.47 | 440, 739, 688 | 22, 37, 34 | 93 |
| Tarn | 1807 | 1.42 | 440, 767, 601 | 22, 38, 30 | 90 |
| Tally | 1697 | 1.33 | 440, 736, 522 | 22, 37, 26 | 85 |
| Cannon | 1950 | 1.53 | 440, 739, 771 | 22, 37, 39 | 98 |
| Floor line | 1672 | 1.31 | 440, 767, 465 | 22, 38, 23 | 84 |

Straight distance drop-in to engage centre: 1274 m. The floor line rides Rivet's waypoints with no harpoon and no contraption; its band is at most 2.0 times the pilot line's median time (PARK.md:467). Flow share, airborne share, peak speed, quiet stretch, anchor gap and distinct verbs need the bot on the baked greybox (KB7, KD); the line JSON carries today's bar keys at the band floors.

Distinct lines: 11 of 15 pilot pairs share fewer than half their samples within 8 m, above the band's three (PARK.md:468).

**Tricks each line offers** (kits from `class_def.gd:87-122`):

- **Sable** (grapple, vault off steep faces): the west wash's walls are vault faces every 60 m; at the rim, a slingshot off the overflow channel's gate posts into the tunnel mouth; out of the flip bucket, a vault kick off the plunge pool's coping onto the apron.
- **Rivet** (overdrive sprint): the upper slot's straights are sprint lanes; the incline is the longest sprint drop in world 1; the sprint holds 19 m/s across the east bench, which snaps a winch drone's cable (`winch_drone.gd:20`).
- **Kest** (rocket jump and glide; the glide rides the fin vents on Kest's ball, the per-pilot machinery call): rocket-jump the corkscrew's walls to cut its bends; off the pipeline bridge, glide the east gorge; the rim zip ends in a rocket jump over the haul road's last switchback.
- **Tarn** (claw pull): claw-pull from the overflow channel down onto the cliff-room ledges, swing the viga span, pull onto the service ledge and slam the lobbers off it.
- **Tally** (flywheel surge, refilled by rolling): surge down the west wash, refill on the incline, then pump the plunge pool's bowl twice and surge out onto the apron.
- **The Cannon** (recoil): recoil-hop the corkscrew, take the trebuchet onto the crest, grind the crest rail, then recoil off the crest and drop down the face onto the relic. It is the stage's showcase line and the only one that meets the Warden from above.

## 10. Music arc

The stage keeps its row: theme 0, `spillway` (`alpha_defs.gd:69`; `harmony.gd:117`), the 172 BPM D Dorian band (MUSIC-GEMS.md:11). Cue ids are proposals for the `CUES` table KE8 adds (PARK.md:540).

| Where or when | What the music does |
| --- | --- |
| Drop-in, dawn on the shelf | The band's calm layer: keys and pad, no drums. The reese bass (MUSIC-GEMS.md:18) enters on the first ride fact |
| The shelf lip | First launch: the full drum-and-bass groove lands on the landing downbeat (cue `first_drop`) |
| The slots and the wash | The full band; combat lifts layers through the existing `escalate` arc (MUSIC-GEMS.md:21) |
| The Eye | A one-bar low-pass dip inside the tunnel, opening on the far side (cue `eye_filter`) |
| The canyon floor, first touch | The B section lands as the ball first reaches y 10 or lower (cue `canyon_floor`) |
| Flood, flash flood | Stage-band riser over the lead, `drop_flood` on the landing (PARK.md:310) |
| Lightning | A stinger on the beat |
| Dropship | Brindle's anvil and brass, one layer (SOUND-STORY.md:74) |
| Vent pits wake | The reactor's Ab pedal under the band while the vent charges, the Geiger tick speeding toward the eruption (SOUND-STORY.md:59, 140). The first time the player hears the Warden's colour |
| Powerhouse boiler | Steam whistle rising into a percussion hit |
| Monsoon | `monsoon_pad` layer while live |
| Warden engage | The Spillway pivot: half-note triplets, then four on the floor at 129 (MUSIC-GEMS.md:13) |
| Each pulse charge | The Ab pedal for the 2 s charge (SOUND-STORY.md:69); the water sheet's rush lands with the pulse |
| Half broken, three quarters | The half-step lift, then the sinister break (MUSIC-GEMS.md:17) |
| Break | The unseal drop, the cadence home; the launch over the crest rides the cadence |

## 11. Codex fragments from the society layer

Draft text for the lore pass, in the tone of `SOUND-STORY.md:212`. Fragment ids are new; KD1 adds them through whatever fragment table the codex unit picks. The `ref_` texts describe technique only and need a fact check before they ship (PARK.md:301).

| Id | Found at | Draft text |
| --- | --- | --- |
| `dam_era_survey_deck` | drop-in deck | Survey mark. Deck 151.0. Crest 121.0. Somebody scratched: "downhill from here, all of it." |
| `dam_era_wash_liner` | west wash | Liner pour 14. The wash will flood. The wash always floods. Pour it anyway. |
| `dam_era_overflow_channel` | west rim bench | Overflow channel, gate 2. Opens itself. Do not stand in it to find out. |
| `dam_era_tunnel_gauge` | spillway tunnel | Gauge reads in metres of water. It has read 0 for a long time. |
| `dam_era_ledge_stencil` | service ledge | NO CLIMBING ON THE ROOMS. USE THE LEDGE. THE LEDGE IS FOR YOU. |
| `dam_era_incline_tally` | construction incline | Tally marks for every bucket of concrete the incline carried. The marks stop mid-row. |
| `dam_era_bridge_plate` | pipeline bridge | Pipeline 3. Rated for water. Not rated for whatever you are. |
| `dam_era_haul_sign` | east haul road | Haul road. Speed limit 25. Nobody has checked since. |
| `dam_era_powerhouse_log` | powerhouse | Shift log: boiler 2 hot again. Relic on the face hums at night. Filed under not my problem. |
| `dam_dedication_plaque` | the dam | Dedicated to the crews who poured the face. The bottom line is scratched out and rewritten in blue. |
| `ancient_eye_marks` | the Eye | Marks cut round the Eye's rim, older than the wash. They glow faintly the same blue as the face. |
| `ancient_vent_plate` | toe vent pits | A cast plate over a vent: no bolts, no seams. Warm. |
| `ref_cliff_rooms` | cliff rooms | Rooms built into an alcove of the canyon wall, stone laid in mud mortar, sheltered from sun and flood by the overhang above. |
| `ref_viga_beams` | viga span | Roof beams carried from far uplands, their ends left long past the wall. |
| `dam_era_canal_headworks` | canal lips | Headworks 2. The canal feeds fields nobody plants now. Gate oiled weekly anyway. |

## 12. What stays from today's stage, and what has no table yet

**Stays on the stage row** (`alpha_defs.gd:69-74`): stage 1, world 1, `warden_family` `reactor`, `ancient` `reactor_relic`, plating 90, hp 650, `beacon_seconds` 25, posture curve 2.0 with `ram_shatters` false, `PRESSURE[0]`, `PACKS` and `ELITE` (`alpha_defs.gd:42-47`, `60`). The display name changes to "Spillway: the dam" and the map id to `park_dam` at KD7 (PARK.md:524, 528, 573). Music stays theme 0, `spillway`.

**Warden band timing.** `SPILLWAY_SKIPPER_S` is 50 to 90 s (`tests/alpha_posture_bands_test.gd:31`), measured as stage clock at the break less the bot's turn to the Warden (`alpha_posture_bands_test.gd:12-13`). The face mounting changes how the ball reaches the core, so KF2 re-measures it on `--table=park` and re-pins with a dated header; the window stays unless the median leaves it. The slice cell in `tests/posture_bands_test.gd:25` and `45-46` is untouched by this stage.

**Tests to re-pin** (names from the `tests/` listing; KD1 confirms which pin stage 1 values): `alpha_posture_bands_test.gd`, `world_one_wardens_test.gd`, `world_warden_flow_test.gd`, `stage_bay_test.gd`, `warden_ring_test.gd`, `hero_warden_assets_test.gd`, and the win proof on `--table=park`.

**Fields today's map carries that the park file has no table for** (park_map fills only the list at PARK.md:216):

| Field | Today | Proposal |
| --- | --- | --- |
| `rescue_sites` | Rivet's cage at (60, -150), `map_spillway.gd:99-100`; Rivet unlocks by it (`class_def.gd:48`) | Must stay. Put the cage at [60, -600] on the top shelf, flat, 120 m east of every line. Needs a park key or a derived field (open question) |
| `vault` | (-5, -130), `map_spillway.gd:67` | A plinth at [-260, -520] on the shelf's west side, off the fall line with a downhill way back (`stage_map.gd:26-27`) |
| `unique_events` | `scrap_stampede`, `hold_the_relay`, `map_spillway.gd:86-97` | Retire into this page's event rows and the activities; the stampede's hauler becomes stage 2's `hauler_bounty` |
| `scrap_lines` | four short lines, `map_spillway.gd:80-85` | Derive from the pilot lines in `tools/park_lines/park_dam.json` |
| `basin` | the flood bowl, `map_spillway.gd:77-78` | Replaced by `plunge_pool_flood` |
| `beacon_floor` | 15 m, `map_spillway.gd:66` | The toe apron's height, read from the bake |

## 13. The draft park file

KD1 copies this to `src/world/park/park_dam.json`. Each row's `routes` list is filled from the route table.

```json
{
 "schema": "scrapkeep-park/1",
 "map": "park_dam",
 "size_m": 1600,
 "time_of_day": "dawn",
 "spawn": {"at": [-150, -690], "heading_deg": 30},
 "play_rect": [-760, -780, 1520, 1480],
 "landmark": {"id": "spillway_dam", "kind": "dam", "at": [0, 620], "size": [120, 120, 320], "yaw_deg": 180, "recipe": "landmark_dam", "budget": "hero_landmark", "sight_top": [0, 141, 640], "sight_share": 0.85, "beacon": [0, 575], "reach_m": 30, "warden": {"mounting": "dam_face", "anchor": [0, 22, 590], "path": [], "hardpoints": 3}, "bay_dock": {"at": [0, 467], "facing_deg": 0}, "gate_slots": [{"at": [-16, 528], "facing_deg": 0}, {"at": [0, 528], "facing_deg": 0}, {"at": [16, 528], "facing_deg": 0}], "light": "ancient_beam", "music": "landmark_hum", "fragment": "dam_dedication_plaque"},
 "waymarks": ["drop_in", "domes_camp", "the_eye", "landmark"],
 "routes": [
  {"id": "shelf", "from": "drop_in", "to": "shelf_lip", "via": ["top_shelf_deck", "slickrock_domes"]},
  {"id": "west_wash_run", "from": "shelf_lip", "to": "the_eye", "via": ["west_wash"]},
  {"id": "upper_slot_run", "from": "shelf_lip", "to": "the_eye", "via": ["upper_slot"]},
  {"id": "corkscrew_run", "from": "shelf_lip", "to": "the_eye", "via": ["corkscrew_slot"]},
  {"id": "west_rim_run", "from": "the_eye", "to": "west_rim_bench", "via": ["the_eye", "west_rim_bench"]},
  {"id": "tunnel_line", "from": "west_rim_bench", "to": "outlet_bucket", "via": ["spillway_tunnel"]},
  {"id": "bucket_flight", "from": "outlet_bucket", "to": "toe_apron", "via": ["outlet_bucket"]},
  {"id": "pool_floor", "from": "outlet_bucket", "to": "toe_apron", "via": ["plunge_pool"]},
  {"id": "pool_rim", "from": "outlet_bucket", "to": "toe_apron", "via": ["plunge_pool"]},
  {"id": "ledge_line", "from": "west_rim_bench", "to": "toe_apron", "via": ["cliff_rooms_west", "viga_span", "service_ledge"]},
  {"id": "incline_line", "from": "the_eye", "to": "tailwater_bar", "via": ["the_eye", "construction_incline"]},
  {"id": "tailwater_run", "from": "tailwater_bar", "to": "toe_apron", "via": ["tailwater_bar"]},
  {"id": "bridge_line", "from": "the_eye", "to": "east_bench_flats", "via": ["the_eye", "pipeline_bridge"]},
  {"id": "canal_run", "from": "east_bench_flats", "to": "toe_apron", "via": ["canal_lips", "east_haul_road"]},
  {"id": "dropship_ramp", "from": "east_bench_flats", "to": "toe_apron", "via": ["east_bench_flats"]},
  {"id": "crest_line", "from": "east_bench_flats", "to": "landmark", "via": ["east_abutment", "crest_rail"]},
  {"id": "face", "from": "toe_apron", "to": "landmark", "via": ["toe_apron"]},
  {"id": "powerhouse_floor", "from": "toe_apron", "to": "landmark", "via": ["powerhouse"]},
  {"id": "roof_ramp_line", "from": "toe_apron", "to": "landmark", "via": ["powerhouse"]}
 ],
 "park_rows": [
  {"id": "canyon_country", "element": "ground", "landform": "slickrock", "society": "none", "at": [0, 0], "y": null, "size": [1600, 100, 1600], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "shelf_rise", "element": "ground", "landform": "slickrock", "society": "none", "at": [0, -500], "y": null, "size": [600, 50, 1600], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "ramp", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "top_shelf_deck", "element": "drop", "landform": "slickrock", "society": "dam_era", "at": [-150, -690], "y": null, "size": [44, 10, 30], "yaw_deg": 30, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:drop", "stamp": "mesa", "hole": false, "budget": "landform", "routes": ["shelf"], "fragment": "dam_era_survey_deck"},
  {"id": "slickrock_domes", "element": "bank", "landform": "slickrock", "society": "none", "at": [-110, -520], "y": null, "size": [260, 24, 240], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_hop", "home": "", "recipe": "", "stamp": "ridge", "hole": false, "budget": "landform", "routes": ["shelf"], "fragment": ""},
  {"id": "shelf_lip", "element": "kicker", "landform": "slickrock", "society": "none", "at": [-90, -300], "y": null, "size": [20, 4, 30], "yaw_deg": 0, "verb": "launch", "ride_fact": "kicker_launch", "home": "", "recipe": "greybox:kicker", "stamp": "ramp", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "west_wash", "element": "half_pipe", "landform": "arroyo", "society": "dam_era", "at": [-165, -65], "y": null, "size": [362, 12, 80], "yaw_deg": 24, "verb": "pump", "ride_fact": "ride_chute", "home": "culvert_chasers", "recipe": "half_pipe_concrete", "stamp": "wash", "hole": false, "budget": "landform", "routes": ["west_wash_run"], "fragment": "dam_era_wash_liner"},
  {"id": "upper_slot", "element": "flow_line", "landform": "slot_canyon", "society": "none", "at": [-70, -65], "y": null, "size": [359, 26, 120], "yaw_deg": 13, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "slot_canyon_flow", "stamp": "channel", "hole": false, "budget": "landform", "routes": ["upper_slot_run"], "fragment": ""},
  {"id": "corkscrew_slot", "element": "flow_line", "landform": "slot_canyon", "society": "none", "at": [60, -90], "y": null, "size": [306, 22, 90], "yaw_deg": -11, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "slot_canyon_flow", "stamp": "channel", "hole": false, "budget": "landform", "routes": ["corkscrew_run"], "fragment": ""},
  {"id": "the_eye", "element": "tunnel", "landform": "slickrock", "society": "none", "at": [0, 150], "y": null, "size": [30, 28, 40], "yaw_deg": 0, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "greybox:tunnel", "stamp": "", "hole": true, "budget": "park_large", "routes": ["west_rim_run", "incline_line", "bridge_line"], "fragment": "ancient_eye_marks"},
  {"id": "west_rim_bench", "element": "bank", "landform": "mesa_rim", "society": "dam_era", "at": [-125, 200], "y": null, "size": [269, 4, 60], "yaw_deg": -68, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:bank", "stamp": "terrace", "hole": false, "budget": "landform", "routes": ["west_rim_run"], "fragment": "dam_era_overflow_channel"},
  {"id": "spillway_tunnel", "element": "tunnel", "landform": "spillway_tunnel", "society": "dam_era", "at": [-195, 375], "y": null, "size": [273, 100, 14], "yaw_deg": 24, "verb": "drop", "ride_fact": "ride_drop", "home": "outlet_brutes", "recipe": "spillway_tunnel", "stamp": "", "hole": true, "budget": "park_large", "routes": ["tunnel_line"], "fragment": "dam_era_tunnel_gauge"},
  {"id": "outlet_bucket", "element": "kicker", "landform": "spillway_tunnel", "society": "dam_era", "at": [-135, 505], "y": null, "size": [16, 4, 18], "yaw_deg": 24, "verb": "launch", "ride_fact": "kicker_launch", "home": "", "recipe": "greybox:kicker", "stamp": "ramp", "hole": false, "budget": "detail", "routes": ["bucket_flight"], "fragment": ""},
  {"id": "cliff_rooms_west", "element": "elevated_line", "landform": "cliff_dwelling", "society": "ancestral_puebloan", "at": [-145, 340], "y": 60, "size": [160, 8, 10], "yaw_deg": 4, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "cliff_dwelling_row", "stamp": "", "hole": false, "budget": "landform", "routes": ["ledge_line"], "fragment": "ref_cliff_rooms"},
  {"id": "viga_span", "element": "anchor_field", "landform": "cliff_dwelling", "society": "ancestral_puebloan", "at": [-135, 430], "y": 50, "size": [60, 4, 4], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "viga_pivot", "stamp": "", "hole": false, "budget": "detail", "routes": ["ledge_line"], "fragment": "ref_viga_beams"},
  {"id": "service_ledge", "element": "ledge", "landform": "mesa_rim", "society": "dam_era", "at": [-125, 490], "y": 24, "size": [104, 24, 9], "yaw_deg": 17, "verb": "roll", "ride_fact": "ride_ledge", "home": "ledge_lobbers", "recipe": "mesa_rim_ledge", "stamp": "", "hole": false, "budget": "landform", "routes": ["ledge_line"], "fragment": "dam_era_ledge_stencil"},
  {"id": "construction_incline", "element": "drop", "landform": "mesa_rim", "society": "dam_era", "at": [-45, 295], "y": null, "size": [212, 94, 16], "yaw_deg": -8, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:drop", "stamp": "ramp", "hole": false, "budget": "landform", "routes": ["incline_line"], "fragment": "dam_era_incline_tally"},
  {"id": "river_canyon", "element": "ground", "landform": "river_canyon", "society": "none", "at": [0, 380], "y": null, "size": [360, 100, 300], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "channel", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "tailwater_bar", "element": "flow_line", "landform": "dry_wash", "society": "none", "at": [-40, 465], "y": null, "size": [136, 3, 30], "yaw_deg": 17, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "greybox:flow_line", "stamp": "wash", "hole": false, "budget": "landform", "routes": ["tailwater_run"], "fragment": ""},
  {"id": "east_gorge", "element": "ground", "landform": "river_canyon", "society": "none", "at": [455, 235], "y": null, "size": [690, 100, 70], "yaw_deg": 90, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "channel", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "pipeline_bridge", "element": "grind_line", "landform": "pipeline", "society": "dam_era", "at": [105, 240], "y": 100, "size": [177, 3, 3], "yaw_deg": 47, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "pipeline_rail", "stamp": "", "hole": false, "budget": "landform", "routes": ["bridge_line"], "fragment": "dam_era_bridge_plate"},
  {"id": "east_bench_flats", "element": "ground", "landform": "slickrock", "society": "none", "at": [300, 380], "y": null, "size": [160, 6, 200], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "dropship_winches", "recipe": "", "stamp": "plateau", "hole": false, "budget": "landform", "routes": ["dropship_ramp"], "fragment": ""},
  {"id": "canal_lips", "element": "grind_line", "landform": "canal", "society": "dam_era", "at": [260, 420], "y": null, "size": [244, 3, 8], "yaw_deg": 35, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "canal_lip", "stamp": "channel", "hole": false, "budget": "landform", "routes": ["canal_run"], "fragment": "dam_era_canal_headworks"},
  {"id": "east_haul_road", "element": "drop", "landform": "mesa_rim", "society": "dam_era", "at": [200, 508], "y": null, "size": [214, 100, 14], "yaw_deg": -69, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:drop", "stamp": "ramp", "hole": false, "budget": "landform", "routes": ["canal_run"], "fragment": "dam_era_haul_sign"},
  {"id": "east_abutment", "element": "ledge", "landform": "dam_face", "society": "dam_era", "at": [175, 575], "y": null, "size": [80, 16, 60], "yaw_deg": 0, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "greybox:ledge", "stamp": "plateau", "hole": false, "budget": "landform", "routes": ["crest_line"], "fragment": ""},
  {"id": "plunge_pool", "element": "bowl", "landform": "dam_face", "society": "dam_era", "at": [-85, 515], "y": null, "size": [110, 8, 110], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "bench_coping", "stamp": "bowl", "hole": false, "budget": "landform", "routes": ["pool_floor", "pool_rim"], "fragment": ""},
  {"id": "toe_apron", "element": "bank", "landform": "dam_face", "society": "dam_era", "at": [0, 545], "y": null, "size": [40, 2, 300], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:bank", "stamp": "plateau", "hole": false, "budget": "landform", "routes": ["face"], "fragment": ""},
  {"id": "powerhouse", "element": "ledge", "landform": "dam_face", "society": "dam_era", "at": [120, 505], "y": null, "size": [40, 24, 70], "yaw_deg": 0, "verb": "roll", "ride_fact": "ride_ledge", "home": "powerhouse_trappers", "recipe": "greybox:ledge", "stamp": "", "hole": false, "budget": "landform", "routes": ["powerhouse_floor", "roof_ramp_line"], "fragment": "dam_era_powerhouse_log"},
  {"id": "toe_vent_pits", "element": "bowl", "landform": "dam_face", "society": "ancient", "at": [140, 440], "y": null, "size": [50, 3, 70], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:bowl", "stamp": "bowl", "hole": false, "budget": "detail", "routes": [], "fragment": "ancient_vent_plate"},
  {"id": "crest_rail", "element": "rail", "landform": "dam_face", "society": "dam_era", "at": [0, 650], "y": 121, "size": [300, 1, 1], "yaw_deg": 90, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "pipeline_rail", "stamp": "", "hole": false, "budget": "detail", "routes": ["crest_line"], "fragment": ""}
 ],
 "event_rows": [
  {"id": "plunge_pool_flood", "kind": "flood_fill", "family": "natural", "site": "plunge_pool", "trigger": {"on": "clock_tier", "value": 1}, "weight": 1.0, "telegraph": {"lead_s": 6.0, "form": "flood_rising", "on_bar": true}, "live_s": 35.0, "effect": {"depth_m": 1.2, "fill_s": 10.0, "material": "water"}, "route_change": {"closes": ["pool_floor"], "opens": ["pool_rim"]}, "hold_clear_m": 12.0, "cooldown_s": 90.0, "once": false, "music_cue": {"telegraph": "riser_natural", "land": "drop_flood"}},
  {"id": "west_wash_flash_flood", "kind": "flash_flood", "family": "natural", "site": "west_wash", "trigger": {"on": "clock_tier", "value": 2}, "weight": 0.6, "telegraph": {"lead_s": 6.0, "form": "flood_rising", "on_bar": true}, "live_s": 30.0, "effect": {"depth_m": 1.2, "fill_s": 4.0, "material": "water"}, "route_change": {"closes": ["west_wash_run"], "opens": []}, "hold_clear_m": 15.0, "cooldown_s": 120.0, "once": false, "music_cue": {"telegraph": "riser_natural", "land": "drop_flash_flood"}},
  {"id": "dome_lightning", "kind": "lightning", "family": "natural", "site": "slickrock_domes", "trigger": {"on": "clock_tier", "value": 3}, "weight": 0.4, "telegraph": {"lead_s": 3.0, "form": "lightning_charge", "on_bar": true}, "live_s": 20.0, "effect": {"strike_m": 6.0, "damage": 8.0}, "route_change": {"closes": [], "opens": []}, "hold_clear_m": 0.0, "cooldown_s": 60.0, "once": false, "music_cue": {"telegraph": "riser_natural", "land": "stinger_lightning"}},
  {"id": "east_bench_dropship", "kind": "fleet_landing", "family": "fleet", "site": "east_bench_flats", "trigger": {"on": "clock_tier", "value": 1}, "weight": 1.0, "telegraph": {"lead_s": 10.0, "form": "fleet_inbound", "on_bar": true}, "live_s": 0.0, "effect": {"vessel": "dropship", "home": "dropship_winches", "footprint_m": [36, 16]}, "route_change": {"closes": [], "opens": ["dropship_ramp"]}, "hold_clear_m": 25.0, "cooldown_s": 0.0, "once": true, "music_cue": {"telegraph": "riser_fleet", "land": "drop_fleet"}},
  {"id": "toe_vents_wake", "kind": "machine_eruption", "family": "ancient", "site": "toe_vent_pits", "trigger": {"on": "clock_tier", "value": 2}, "weight": 1.0, "telegraph": {"lead_s": 8.0, "form": "ancient_stirring", "on_bar": true}, "live_s": 0.0, "effect": {"miniboss": "reactor_relic", "swap": "vent_pit_lip"}, "route_change": {"closes": [], "opens": []}, "hold_clear_m": 15.0, "cooldown_s": 0.0, "once": true, "music_cue": {"telegraph": "riser_ancient", "land": "drop_ancient"}},
  {"id": "powerhouse_boiler", "kind": "boiler_burst", "family": "industrial", "site": "powerhouse", "trigger": {"on": "warden_phase", "value": "chunk_2"}, "weight": 1.0, "telegraph": {"lead_s": 5.0, "form": "boiler_pressure", "on_bar": true}, "live_s": 8.0, "effect": {"hazard": "steam_cone", "hazard_m": [24, 10], "damage": 6.0, "swap": "powerhouse_roof_ramp"}, "route_change": {"closes": ["powerhouse_floor"], "opens": ["roof_ramp_line"]}, "hold_clear_m": 14.0, "cooldown_s": 0.0, "once": true, "music_cue": {"telegraph": "riser_industrial", "land": "drop_industrial"}}
 ],
 "home_rows": [
  {"id": "culvert_chasers", "enemy": "chaser", "site": "west_wash", "landform": "arroyo", "advantage": "A chaser's lunge lane is a straight 11 m strip (chaser.gd:14), and the wash floor is the shelf's longest straight.", "counter": "Pump the wash wall: the lane lies on the floor, and dropping back off the wall lands a ram on the wind-up.", "reinforce": {"from_tier": 1, "every_s": 25.0, "max_alive": 5, "pack": "run_down"}, "break": {"by": "ram", "hp": 60.0, "scrap": 12}, "stops_kind": true, "dormant": false},
  {"id": "ledge_lobbers", "enemy": "lobber", "site": "service_ledge", "landform": "mesa_rim", "advantage": "From 24 m up the west wall, a lobber leads every held line across the plunge pool and the west toe (75 m range, lobber.gd:12).", "counter": "Change line under the shell, or ride the ledge itself and slam them off it.", "reinforce": {"from_tier": 1, "every_s": 30.0, "max_alive": 4, "pack": "grounded"}, "break": {"by": "slam", "hp": 80.0, "scrap": 14}, "stops_kind": true, "dormant": false},
  {"id": "powerhouse_trappers", "enemy": "mag_trapper", "site": "powerhouse", "landform": "dam_face", "advantage": "The toe apron is flat and a ball off a drop arrives light; a pit there bends a light line toward the plunge pool.", "counter": "Grow past the pit's rating and roll straight through, or jump the disc and shatter it (mag_trapper.gd:6-9).", "reinforce": {"from_tier": 2, "every_s": 35.0, "max_alive": 3, "pack": "grounded"}, "break": {"by": "smash", "hp": 90.0, "scrap": 16}, "stops_kind": true, "dormant": false},
  {"id": "outlet_brutes", "enemy": "plated_brute", "site": "spillway_tunnel", "landform": "spillway_tunnel", "advantage": "The tunnel puts every ball on one landing spot, and a brute's 6 m slam ring (plated_brute.gd:12) covers it.", "counter": "Take the flip bucket's launch over the ring and come down on the brute from above.", "reinforce": {"from_tier": 2, "every_s": 45.0, "max_alive": 2, "pack": "elite"}, "break": {"by": "damage", "hp": 140.0, "scrap": 20}, "stops_kind": true, "dormant": false},
  {"id": "dropship_winches", "enemy": "winch_drone", "site": "east_bench_flats", "landform": "slickrock", "advantage": "The dropship's drones hover 5.5 m over bare bench rock (winch_drone.gd:13), out of ram reach, and winch a ball crossing to the canal lips toward the crew.", "counter": "Hold 19 m/s across the bench and the cable snaps (winch_drone.gd:20); the canal lips' grind carries that speed, and a jump snaps it too.", "reinforce": {"from_tier": 1, "every_s": 30.0, "max_alive": 3, "pack": "elite"}, "break": {"by": "damage", "hp": 70.0, "scrap": 14}, "stops_kind": true, "dormant": true}
 ],
 "contraption_rows": [
  {"id": "rim_zip", "kind": "cable", "site": "east_haul_road", "recipe": "", "from": [230, 103, 470], "to": [70, 4.4, 545], "radius": 4.0, "floor": 18.0},
  {"id": "crest_trebuchet", "kind": "launcher", "site": "east_abutment", "recipe": "trebuchet", "style": "trebuchet", "at": [170, 560], "radius": 3.5, "target": [60, 123, 648], "floor": 30.0, "min_flight": 3.2, "charge": 4.0},
  {"id": "pool_geyser", "kind": "launcher", "site": "plunge_pool", "recipe": "geyser_vent", "style": "geyser", "at": [-110, 540], "radius": 3.5, "target": [-30, 32, 584], "floor": 16.0, "min_flight": 2.2, "charge": 3.0},
  {"id": "spray_thermal", "kind": "thermal", "site": "toe_apron", "recipe": "", "at": [-40, 520], "radius": 6.0, "height": 60.0},
  {"id": "gallery_valve", "kind": "valve", "site": "service_ledge", "recipe": "gauge", "at": [-170, 455], "door": {"at": [-165, 470], "size": [12, 6, 1], "turn": 0.6}, "cache": {"at": [-162, 482]}, "codex": "spillway_gallery_cache"},
  {"id": "slot_bulkhead", "kind": "cracked_wall", "site": "corkscrew_slot", "recipe": "", "at": [70, -90], "size": [10, 6, 1.4], "turn": 0.25, "break_at_cruise": true},
  {"id": "domes_cannon", "kind": "launcher", "site": "slickrock_domes", "recipe": "cannon", "style": "cannon", "at": [60, -450], "radius": 4.0, "target": [100, 108, -340], "floor": 34.0, "min_flight": 2.6, "charge": 2.5},
  {"id": "service_lift", "kind": "lift", "site": "service_ledge", "recipe": "lift_platform", "at": [-125, 470], "radius": 4.5, "rise": 24.0, "charge": 3.2, "offset": 0.0}
 ],
 "weather_rows": [
  {"id": "dawn_still", "kind": "clear", "trigger": {"on": "always"}, "lead_s": 0.0, "live_s": 0.0, "gap_s": 0.0, "fog": {"density": 0.0006, "color": "#a3bdd0"}, "sky": "clear", "sound": "canyon_dawn_bed", "music_layer": "", "event_odds": {}, "handling": "none"},
  {"id": "monsoon_buildup", "kind": "monsoon", "trigger": {"on": "clock_tier", "value": 2}, "lead_s": 20.0, "live_s": 90.0, "gap_s": 60.0, "fog": {"density": 0.0014, "color": "#7d8b99"}, "sky": "storm_build", "sound": "monsoon_far_thunder", "music_layer": "monsoon_pad", "event_odds": {"west_wash_flash_flood": 2.5, "dome_lightning": 3.0, "plunge_pool_flood": 1.5}, "handling": "none"}
 ],
 "activity_rows": [
  {"id": "domes_camp", "activity": "enemy_camp", "site": "slickrock_domes", "at": [-51, -396], "pack": ["chaser", "chaser", "chaser"], "pay": {"named": "hot_rivets"}},
  {"id": "rim_cache", "activity": "cracked_cache", "site": "west_rim_bench", "at": [-200, 215], "pack": [], "pay": {}},
  {"id": "bench_altar", "activity": "ambush_altar", "site": "east_bench_flats", "at": [330, 420], "pack": [], "pay": {}}
 ]
}
```

The draft pilot lines for `tools/park_lines/park_dam.json`, with today's bar keys set to PARK.md section 8's floors:

```json
{
 "map": "park_dam",
 "stage": 1,
 "pilots": {
  "sable": {"waypoints": ["drop_in", [-60, -600], [-180, -500], [-60, -400], "domes_camp", [-90, -300], [-240, -230], [-170, -60], [-90, 100], [0, 150], "the_eye", [-130, 200], [-250, 250], [-195, 375], [-140, 500], [-60, 545], [0, 575], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}},
  "rivet": {"waypoints": ["drop_in", [-60, -600], [-180, -500], [-60, -400], "domes_camp", [-90, -300], [-110, -240], [-20, -170], [-120, -90], [-10, -20], [-80, 50], [-30, 110], [0, 150], "the_eye", [-30, 190], [-90, 300], [-60, 400], [-40, 470], [-20, 530], [0, 575], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}},
  "kest": {"waypoints": ["drop_in", [-60, -600], [-180, -500], [-60, -400], "domes_camp", [-90, -300], [90, -240], [40, -140], [100, -40], [30, 60], [0, 150], "the_eye", [40, 180], [170, 300], [260, 420], [230, 470], [70, 545], [0, 575], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}},
  "tarn": {"waypoints": ["drop_in", [-60, -600], [-180, -500], [-60, -400], "domes_camp", [-90, -300], [-110, -240], [-20, -170], [-120, -90], [-10, -20], [-80, 50], [-30, 110], [0, 150], "the_eye", [-130, 200], [-170, 260], [-150, 330], [-140, 430], [-120, 500], [-60, 550], [0, 575], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}},
  "tally": {"waypoints": ["drop_in", [-60, -600], [-180, -500], [-60, -400], "domes_camp", [-90, -300], [-240, -230], [-170, -60], [-90, 100], [0, 150], "the_eye", [-30, 190], [-90, 300], [-60, 400], [-110, 480], [-60, 540], [0, 575], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}},
  "cannon": {"waypoints": ["drop_in", [-60, -600], [-180, -500], [-60, -400], "domes_camp", [-90, -300], [90, -240], [40, -140], [100, -40], [30, 60], [0, 150], "the_eye", [40, 180], [170, 300], [230, 420], [170, 560], [60, 648], [20, 648], [0, 600], [0, 575], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}}
 },
 "floor": {"waypoints": ["drop_in", [-60, -600], [-180, -500], [-60, -400], "domes_camp", [-90, -300], [-110, -240], [-20, -170], [-120, -90], [-10, -20], [-80, 50], [-30, 110], [0, 150], "the_eye", [-30, 190], [-90, 300], [-60, 400], [-40, 470], [-20, 530], [0, 575], "landmark"]}
}
```

## 14. Storyboard

Board `park-1-park_dam`, panels per PARK.md:406. `p1_overhead` is plotted from section 13 by `tools/park_plot.py`; the rest are generated. The concept board `artifacts/local/alpha/push/w13/concepts/boards/park-w1.json` carries three vista subjects for this stage.

| Panel | Frame |
| --- | --- |
| `p1_overhead` | Frame 0 below, plotted |
| `p2_drop_in` | Frame 1 |
| `p3_line` | Frame 2 |
| `p4_home` | Frame 3 |
| `p5_event` | Frame 4 |
| `p6_warden` | Frame 6 |

**Frame 0, the plan.** The section 4 grid drawn to scale: the shelf at the top, the slots converging on the Eye, the canyon, the dam across the bottom with its toe apron, every line in its pilot's colour.

**Frame 1, the drop-in vista.** From the survey deck at dawn, 2 m above the ball, looking south. Slickrock domes roll away in pink and cream; two dark slot mouths and the pale lined wash cut the plateau beyond the lip; 1.3 km away the dam's crest is a pale bar across the canyon with a thin green beam rising from its middle, and the monsoon clouds are only a grey line on the horizon.

**Frame 2, the first flow line.** Chase camera low behind the ball in the upper slot, walls 25 m high and close enough to touch, a stripe of sky overhead, the ball banked high on the outside of a meander. Ahead, the slot opens into the Eye's arch with daylight and the far canyon framed in it.

**Frame 3, an enemy home.** The west wash from its rim: a concrete-lined arroyo half-pipe, a culvert mouth in its wall with chaser crews spilling out, one chaser's lunge lane painted on the floor, and the ball high on the opposite wall, above the lane, about to drop on it.

**Frame 4, an event firing.** The plunge pool from the toe apron. Left half: the telegraph, the pool's coping lit in the flood colour and water already sheeting off the spillway tunnel's outlet. Right half: three seconds later, the pool brimming and the ball riding its rim line where the floor line was.

**Frame 5, the landmark approach.** Off the construction incline, the camera falling with the ball down the canyon wall toward the toe; the dam fills the frame, 120 m of curved concrete, the relic a squat blue-seamed drum clamped to its centre 22 m up, the powerhouse steaming to the right.

**Frame 6, the Warden fight.** From the toe apron looking up the face: the gates over the relic open, a white water sheet pouring down the face, and the ball riding up the sheet toward the relic's open core, a harpoon line taut from a gate pier to the ball.

**Frame 7, the exit.** After the break: the three gates on the apron, Moss's bay hovering behind them, and the ball arcing up the face and over the crest, the reservoir and a far mesa with a weir on it in the morning haze.
