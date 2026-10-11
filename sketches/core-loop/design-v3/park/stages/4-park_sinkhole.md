# The Dig: the sinkhole (`park_sinkhole`, stage 4)

Storyboard and table draft for stage 4, the second zone of world 2. Unit K-W2, wave 13, 10 October 2026. Status: **draft for Andrew's click approval** of board `park-4-park_sinkhole`. Nothing here is built. Every number is a starting value to tune in play unless it cites code.

Read with [PARK.md](../../PARK.md) (the tables and bands), [TADR-011](../../../../../adr/TADR-011-park-terrain-and-warden-kinds.md) (the decision), the Warden kind sheet [wardens/swarm.md](../../wardens/swarm.md) and the stage 3 page [3-park_pit.md](3-park_pit.md), which defines bench, winze, collar and waymark. Paths are under `sketches/core-loop/` unless they start with `adr/`, `docs/` or `BIBLE.md`.

Terms used once and kept: a **lava tube** is a cave a lava river left when its crust cooled and the lava drained; a **skylight** is a hole where a tube's roof fell in; a **drift** is a level mine tunnel; a **crosscut** is a drift that joins two others; a **caisson** is a lined pump shaft, here flooded; the **gallery ring** is the timber walkway the miners built round the sinkhole at the 100 m mark.

## 0. At a glance

| Field | Value |
| --- | --- |
| Stage, world | 4, The Dig (world 2) |
| Map id, display name | `park_sinkhole`, "The Dig: the sinkhole" (today `dig_deep`, "Dig: the deep works", `src/core/alpha_defs.gd:91`) |
| Warden | kind `swarm` (the swarm remnant), mounting `sinkhole`, variant `brood` (both today's, `alpha_defs.gd:91`, `:100`) |
| Time of day | `afternoon` (fixed) |
| Weather | cave mist always; a monsoon cell from clock tier 2 |
| Landmark | the sinkhole, 250 m across and 120 m deep at (0, 350), open to the sky, with a uranium-glass green (#9dff3c) light column 140 m tall (PARK.md:377) |
| Park | 1.6 km square; a basalt plateau with a cinder cone in the north, cut by lava tubes, mine drifts and flooded caverns |
| Lines | six pilot lines of 1,572 to 1,898 m, estimated 62 to 79 s; floor line 1,686 m, about 84 s (section 9) |
| Roof share | 50% or more of every measured line runs under a roof (PARK.md:583 asks for 40%) |
| Draft size | 29 row families that expand to 60 park rows, 5 events, 5 homes, 8 contraptions, 2 weather rows, 3 activities, 17 routes |

## 1. Landform and society layer

**The Arizona landform.** The San Francisco and Uinkaret volcanic fields: black basalt flats, a cinder cone with a breached crater, and lava tubes under the plateau like the Lava River Cave near Flagstaff, 1 km of tube you can walk. Here the tubes ran south and drained into a karst sinkhole that later flooded, the way cenotes and collapse sinks form where rock dissolves under a cap. Miners found copper in the tube walls and drove drifts between the tubes; they sank a pump caisson in the sinkhole floor to keep the workings dry. The plateau's top is the stage's ceiling, so a run is mostly a ride through the dark between skylights.

**The park, in numbers (start).** Cinder cone centre (-320, -705), 460 m across, 90 m tall, its crater breached on the south-east. Lava channel 30 m wide and 8 m deep from the breach to the tube mouth at (0, -360). Five tubes and drifts from the tube mouth (y -12) fall to the great room, a cavern 90 m across at (0, -20), floor y -55. Three lower tubes fall from the great room to the sinkhole's gallery ring (y -100). Sinkhole rim radius 125 m at y 0; walls drop 100 m to the gallery ring (radius 40 to 55 m); the caisson pool sits inside it, radius 40 m, coping y -110, floor y -120.

**Who shaped it.**

| Society | What they left | Rows | Rule |
| --- | --- | --- | --- |
| `none` | the cone, the lava channel, the tubes, the skylights, the great room, the sinkhole walls, the cenote, the west trench, the spatter field, the east mesa, the south flats | most rows | water, fire and time |
| `mining` | the east drift, the east haulage drift, the breach caps, the gallery ring, the caisson, the pump gallery | 6 families | carries homes and events freely |
| `ancestral_puebloan` | a row of small stone granaries in the west trench wall | `trench_granaries` | no home, no ground-changing event, `ref_` fragment only (PARK.md section 4) |
| `ancient` | a sealed vault off the cannon tube, where a buried machine woke | `machine_vault` | the ancient eruption's site |
| `fleet` | nothing at start; a drill barge lands on the east plateau at clock tier 2 and bores down | `bore_apron` | brings a dormant drill crew home |

The granaries sit in the trench wall off every measured line, a quiet side loop for a player who roams west. They are the stage's reference to people who stored seed against a dry year in this country, and nothing hostile lives in them.

## 2. The hero landmark and the Warden's mounting

**The sinkhole.** A round collapse 250 m across that opens the plateau to the sky. Its walls are layered basalt over pale limestone, streaked with mineral stain, with the miners' timber gallery ring at the 100 m mark and the caisson's flooded pool in the middle. From the plateau you cannot see into it, so the landmark is its light column: a uranium-glass green beam 4 m wide (start) rising from the nest to `sight_top` [0, 140, 388], 140 m above the plain. The column is the brood's light, not daylight, so it reads as "the Warden is there" and never as a floor telegraph (section 8).

**The mounting (`sinkhole`).** The brood nests on the sinkhole's south wall at [0, -99, 388], over the pool's south edge, 21 m above the pool floor. It does not move (`warden.path` is empty). Its guard is a lamp swarm, as today's `brood` variant already makes it (`src/combat/warden.gd:31-32`, `225-228`). The mounting's one mechanism is PARK.md's (PARK.md:427): **the pool rises one step per chunk lost**, 5 m a step (start), lifting the fight floor toward the nest: floor y -120, then -115, -110, -105. The break floods the pool to the gallery ring (y -100), and the bay docks over the water. The kind sheet ([swarm.md](../../wardens/swarm.md) section 3.2) holds the full rule, including the hold that keeps a step from rising under the ball.

**Fight floor.** The pool's floor is a shallow bowl under 1.2 m of water at most, so a ball rolls through and keeps planar speed (PARK.md:294). The gallery ring is a 15 m wide timber shelf all the way round, a wall ride that circles the pool. A ball carves the ring, drops off its inner edge onto the pool floor for a ram or a slam, and climbs back out by the pump-gallery ramp (after the boiler blows), the rim zip's end, a harpoon swing, or the pulse's 10 m/s lift (`warden.gd:42`).

**Bay and gates.** Gate slot (0, 305) on the gallery ring's north side, facing -z toward the arriving ball. The bay docks at (0, 320), 15 m from the gate and inside the gates' 110 m hold (`src/world/bay.gd:21-23`).

## 3. Region sketch

The 1.6 km square in 200 m cells, north (-z, the drop-in side) at the top. UPPERCASE is the surface; `[brackets]` is underground.

```
          A           B           C            D            E            F            G           H
x:      -800        -600        -400         -200           0          200          400         600
1 z-800 .           CONE        CONE * rim   CONE         .            SPATTER      SPATTER     .
                                breach                                  field        field
2 z-600 .           cone        CHANNEL      CHANNEL      .            SPATTER      SPATTER     .
                                             fumarole
3 z-400 .           .           [cannon]     [cannon]     TUBE MOUTH   SKYLIGHT 2   .           .
                                             [gallery]    [main] [sky1] cave breath
                                                          [east drift]
4 z-200 .           W TRENCH    [CENOTE]     [main]       [GREAT ROOM] [east drift] EAST MESA   EAST MESA
                    granaries   CAMP raft    cap          BOUNTY lift  valve
                    CACHE       [VAULT]                   cap [sky3]
5 z   0 .           .           .            [main low]   [main low]   BORE APRON   EAST MESA   EAST MESA
                                             [west brk]   [haulage]    barge lands
                                             crosscut
6 z 200 .           .           .            WEST ROOF    SINKHOLE     [haulage]    .           .
                                             [west brk]   ring, pool
                                             zip start    HIVE GATE BAY
                                                          pump gallery
7 z 400 .           .           .            sinkhole rim sinkhole rim .            .           .
8 z 600 .           .           SOUTH FLATS  SOUTH FLATS  SOUTH FLATS  SOUTH FLATS  .           .
```

Legend, exact positions (x, z in metres):

| Mark | What | Where |
| --- | --- | --- |
| `*` | drop-in, on the cone's north rim, y +90, heading 17 degrees | (-330, -760) |
| TUBE MOUTH | `tube_mouth`, a skylight 12 m deep, waymark 2 | (0, -360) |
| GREAT ROOM | the cavern junction, waymark 3, with the on-line camp `great_room_camp` | (0, -20) |
| HIVE | landmark warden anchor; the light column rises here | (0, 388), y -99 |
| GATE, BAY | gate slot, bay dock | (0, 305), (0, 320) |
| Homes | cinder burrowers in the channel; lamps in the flooded west gallery; drill crews in the east drift; hive cells on the gallery ring; the barge's bore crew (dormant) | channel (-215, -555); gallery (-90, -330); drift (165, -200); ring (0, 350); apron (240, 150) |
| Contraptions | fumarole (-150, -480); cone thermal (-320, -705); cave breath (220, -200); great room lift (20, -10); drift valve (170, -200); sealed crosscut (-75, 110); cenote raft (-330, -200) to (-270, -160); rim zip (-110, 260) to (-48, 350) |
| Activities | enemy camp `great_room_camp` on waymark 3; hauler bounty `east_chamber_bounty` in the east side chamber; cracked cache `west_chamber_cache` in the west side chamber | (0, -20); (172, 40); (-226, -18) |
| Event sites | west roof cave-in (-110, 200); machine vault (-230, -120); bore apron (240, 150); west cenote (-300, -180); pump gallery (50, 350) |

The camp sits on every line, in the one room every tube passes through (R2). The hauler bounty waits in a side chamber off the room's east wall, its door 196 m of path from the line; the cracked cache in the west chamber, 209 m off, is the reward (PARK.md 2.12, R1, R7).

## 4. `park_rows` draft

29 families, 60 rows once the polyline families expand (same convention as the stage 3 page: one straight row per segment, `at` the midpoint, `yaw_deg` the heading). Tube rows carry `y` from the tube mouth's -12 m down to the gallery ring's -100 m along their length. The appendix holds every row in K1's schema, checked.

| Row | Element | Landform | Society | Verb / ride fact | Home | Recipe | Stamp | Hole | Budget | Fragment |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `cinder_cone` | bowl | butte | none | pump / `ride_bowl` | - | `-` | crater | - | landform | lava_cone_note |
| `crater_breach` | drop | lava_tube | none | drop / `ride_drop` | - | `greybox:drop` | ramp | - | landform | - |
| `lava_channel_1..2` | half_pipe | lava_tube | none | pump / `ride_chute` | cinder_burrowers | `-` | channel | - | landform | - |
| `tube_mouth` | drop | lava_tube | none | drop / `ride_drop` | - | `lava_tube_run` | sinkhole | yes | park_large | lava_tube_flow |
| `main_tube_upper_1..7` | tunnel | lava_tube | none | roll / `ride_chute` | - | `lava_tube_run` | - | - | park_large | - |
| `skylight_chain_1..4` | tunnel | lava_tube | none | launch / `ride_hop` | - | `lava_tube_run` | - | - | park_large | - |
| `skylight_1..3` | drop | lava_tube | none | drop / `ride_drop` | - | `greybox:drop` | sinkhole | yes | park_large | - |
| `west_gallery_1..4` | flooded_cavern | cenote_pool | none | swing / `ride_drop` | gallery_lamps | `cavern_shell` | - | - | park_large | lava_cenote_note |
| `west_cenote` | flooded_cavern | cenote_pool | none | drop / `ride_drop` | - | `cenote_pool` | - | yes | park_large | - |
| `east_drift_1..4` | tunnel | adit | mining | roll / `ride_chute` | drift_drill_crews | `greybox:tunnel` | - | - | park_large | mining_drift_tally |
| `cannon_tube_1..4` | tunnel | lava_tube | none | roll / `ride_chute` | - | `lava_tube_run` | - | - | park_large | - |
| `machine_vault` | bowl | lava_tube | ancient | bank / `ride_bowl` | - | `greybox:bowl` | - | - | park_large | ancient_buried_lens |
| `great_room` | bowl | lava_tube | none | bank / `ride_bowl` | - | `cavern_shell` | - | - | park_large | - |
| `great_room_cap` | drop | shaft | mining | slam / `ride_drop` | - | `shaft_drop` | - | yes | park_large | mining_cap_stencil |
| `upper_tube_cap` | drop | shaft | mining | slam / `ride_drop` | - | `shaft_drop` | - | yes | park_large | - |
| `main_tube_lower_1..5` | tunnel | lava_tube | none | roll / `ride_chute` | - | `lava_tube_run` | - | - | park_large | - |
| `east_haulage_1..4` | tunnel | adit | mining | grind / `ride_grapple_line` | - | `greybox:tunnel` | - | - | park_large | mining_haulage_rails |
| `west_breakthrough_1..4` | tunnel | lava_tube | none | roll / `ride_chute` | - | `lava_tube_run` | - | - | park_large | - |
| `west_tube_roof` | ground | lava_tube | none | roll / `-` | - | `-` | - | - | landform | - |
| `sinkhole_walls` | drop | sinkhole | none | drop / `ride_drop` | - | `-` | sinkhole | - | landform | - |
| `gallery_ring` | ledge | sinkhole | mining | roll / `ride_ledge` | hive_cells | `greybox:ledge` | - | - | landform | mining_gallery_timber |
| `caisson_bowl` | bowl | flooded_shaft | mining | pump / `ride_bowl` | - | `greybox:bowl` | - | yes | park_large | mining_pump_caisson |
| `pump_gallery` | ledge | flooded_shaft | mining | roll / `ride_ledge` | - | `greybox:ledge` | - | - | landform | mining_pump_ticket |
| `bore_apron` | ground | lava_tube | fleet | roll / `-` | - | `-` | - | - | landform | - |
| `west_trench` | half_pipe | lava_tube | none | pump / `ride_chute` | - | `-` | channel | - | landform | - |
| `trench_granaries` | elevated_line | cliff_dwelling | ancestral_puebloan | roll / `ride_ledge` | - | `cliff_dwelling_row` | - | - | landform | ref_granary_ledge |
| `spatter_field` | anchor_field | hoodoo_field | none | swing / `ride_grapple_line` | - | `greybox:anchor_field` | - | - | landform | - |
| `east_mesa` | ledge | mesa_rim | none | roll / `ride_ledge` | - | `mesa_rim_ledge` | mesa | - | landform | - |
| `south_flats` | half_pipe | dry_wash | none | pump / `ride_chute` | - | `-` | wash | - | landform | - |

Polylines (x, z), all starting at the tube mouth (0, -360) or the great room (0, -20):

| Family | Waypoints | Width, height |
| --- | --- | --- |
| `lava_channel` | (-250, -590), (-180, -520), (-100, -440) | 30 m, 8 m |
| `main_tube_upper` | (0, -360), (-70, -300), (40, -250), (-60, -190), (-50, -120), (60, -90), (-20, -50), (0, -20) | 24 m, 14 m |
| `skylight_chain` | (0, -360), (120, -300), (220, -200), (60, -150), (-50, -120) | 20 m, 10 m |
| `west_gallery` | (0, -360), (-180, -300), (-300, -180), (-200, -80), (0, -20) | 30 m, 16 m |
| `east_drift` | (0, -360), (150, -280), (180, -120), (80, -40), (0, -20) | 8 m, 7 m |
| `cannon_tube` | (0, -360), (-150, -330), (-250, -250), (-200, -150), (-50, -120) | 20 m, 12 m |
| `main_tube_lower` | (0, -20), (-60, 40), (40, 90), (-30, 150), (20, 200), (0, 295) | 24 m, 14 m |
| `east_haulage` | (0, -20), (150, 80), (210, 220), (170, 330), (55, 350) | 8 m, 7 m |
| `west_breakthrough` | (0, -20), (-60, 60), (-110, 200), (-128, 300), (-55, 350) | 20 m, 12 m |

**Breach plates become caps.** Today's deep works carries five breach plates (`src/world/map_dig_deep.gd:17-18`, `60`). Here two mining caps keep the slam verb: `upper_tube_cap` on the main tube drops 17 m into the cannon tube's tail, and `great_room_cap` drops 15 m from the great room onto the main lower tube. The cap and its `drop_to` need the schema key the stage 3 page proposes (its section 14, question 1).

**Anchors for the 40 m gap rule.** Tube recipes carry basalt pillars or lava stalactites every 30 m (start); drifts carry timber sets every 6 m; the gallery ring carries its posts every 12 m. The spatter field's hoodoos and the cone's lip blocks cover the surface lines.

**Density gaps for KD4.** Column A and the far east (G3, H6 to H8) sit more than 80 m from any footprint. KD4 fills them with `ground` rows or widens `west_trench`, `east_mesa` and `south_flats`.

## 5. `event_rows` (shipped)

Five rows, all four families, as shipped in `src/world/park/park_sinkhole.json` (KD4 greybox, 2026-10-11). Tier 1 at 45 s and tier 2 at 90 s (`src/world/director.gd:83-85`, as cited in PARK.md section 5); `cenote_drain` waits for tier 3 (veto item 16, `MAX_TIME_TIERS` raised to 4).

| Id | Kind, family | Site (at) | Trigger | Telegraph | Effect | Route change | Hold clear |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `west_roof_cave_in` | cave_in, natural | `west_tube_roof` (-205, 250) | clock tier 1 | 6 s, `crust_crack`, on bar | the roof crust falls into a 12 m trench of basalt over 3 s, swapping in `west_collapse_trench` | opens `plateau_drop` | 20 m |
| `junction_machine_wakes` | machine_eruption, ancient | `machine_vault` (-182, -160) | clock tier 2 | 8 s, `ancient_stirring`, on bar | a swarm remnant miniboss breaks out; the vault's lip becomes `eruption_lip` | closes `cannon_tube`, opens `eruption_lip` | 15 m |
| `bore_barge` | fleet_landing, fleet | `bore_apron` (240, 150) | clock tier 2 | 10 s, `fleet_inbound`, on bar | a drill barge lands, footprint 40 by 18 m, and wakes `barge_bore_crew` | opens `bore_shaft` | 25 m |
| `cenote_drain` | drain, natural | `west_cenote` (-318, -205) | clock tier 3 | 5 s, `drain_gurgle`, on bar | the cenote drains 1.2 m over 12 s for 60 s | opens `cenote_floor` | 12 m |
| `pump_boiler` | boiler_burst, industrial | `pump_gallery` (60, 350) | Warden phase `chunk_2` | 5 s, `boiler_pressure`, on bar | steam cone 24 by 10 m, 6 damage, 8 s; swaps in `pump_gallery_ramp` | opens `pump_ramp` | 14 m |

**Why these, measured.** Every pilot line reaches the great room between about 47 s and 75 s (section 9), so the tier 1 cave-in fires while a direct run is in the upper tubes, and is heard rather than seen; it opens `plateau_drop` for a second lap or a roaming player. Checks against the momentum rules (PARK.md:308):

- The cave-in's site sits 70 to 90 m west of the west breakthrough (Tarn's lower tube), off every measured line; `hold_clear_m` 20 holds the fall while a ball is within 20 m (`src/world/terrain_event.gd:7-11`), and no route closes.
- The eruption closes the cannon tube at 90 s plus an 8 s telegraph. Every measured line leaves the upper tubes by about 75 s (section 9), so it closes nothing a direct run is on; the vault sits about 50 m west of the Cannon line.
- The barge footprint sits on the plateau east of the haulage, off every line.
- The drain lowers water and never raises ground. `great_room_camp` no longer stands on this site (R3): the on-line camp moved to the great room (section 14).
- The boiler sits 63 m from the nest, outside the 45 m engage ring.

## 6. `home_rows` (shipped)

| Id | Enemy | Site (landform, at) | Reinforce | Break | Stops kind |
| --- | --- | --- | --- | --- | --- |
| `cinder_burrowers` | burrower | `lava_channel_1` (lava_tube, (-645.2, -723.2)) | tier 0, every 24 s, max 3, `deep_bore` | slam, 60 hp, 12 scrap | yes |
| `gallery_lamps` | lamp_swarm | `west_gallery_1` (cenote_pool, (-55, -344.5)) | tier 1, every 22 s, max 3, `deep_lamps` | ram, 50 hp, 10 scrap | yes |
| `drift_drill_crews` | drill_crew | `east_drift_3` (adit, (141.8, -325.1)) | tier 1, every 26 s, max 2, `deep_crew` | smash, 80 hp, 14 scrap | no |
| `hive_cells` | swarm_remnant | `gallery_ring` (sinkhole, (0, 300)) | tier 1, every 30 s, max 6, `swarm_remnant` | smash, 90 hp, 16 scrap | yes |
| `barge_bore_crew` | drill_crew | `bore_apron` (lava_tube, (240, 150)) | tier 2, every 30 s, max 2, `deep_crew` | damage, 150 hp, 20 scrap | yes; dormant until the barge lands |

Advantage and counter text is in each row of the park file. `drift_drill_crews` moved from `east_drift_2` to `east_drift_3`, the drift's straight stretch on the shipped polyline. Every pack is the stage's own (`alpha_defs.gd:96-99`) or the director's ancient pack for the stage's ancient, `swarm_remnant` (`alpha_defs.gd:92`).

## 7. `contraption_rows` (shipped)

Spec keys are today's (`src/world/contraptions.gd:86-101`). 32 rows.

| Id | Kind, recipe | Site | Spec | What it is for |
| --- | --- | --- | --- | --- |
| `tube_rope_1` | cable, `""` | `lava_channel_14` | from [-194.8, -79.3, -545.2] to [-197.0, -79.8, -505.6], radius 3.4, floor 18 | the rope fan across the lava channel: four parallel lines, so every line latches one whatever its lane |
| `tube_rope_2` | cable, `""` | `lava_channel_14` | from [-188.9, -79.9, -546.3] to [-191.5, -80.5, -503.3], radius 3.4, floor 18 | the rope fan across the lava channel: four parallel lines, so every line latches one whatever its lane |
| `tube_rope_3` | cable, `""` | `lava_channel_14` | from [-183.0, -79.9, -547.3] to [-186.0, -80.6, -500.9], radius 3.4, floor 18 | the rope fan across the lava channel: four parallel lines, so every line latches one whatever its lane |
| `tube_rope_4` | cable, `""` | `lava_channel_14` | from [-177.1, -79.2, -548.4] to [-180.5, -80.0, -498.6], radius 3.4, floor 18 | the rope fan across the lava channel: four parallel lines, so every line latches one whatever its lane |
| `main_tube_lower_rope_1` | cable, `""` | `main_tube_lower_4` | from [-75.7, -97.2, 121.9] to [-50.3, -97.2, 144.3], radius 3.4, floor 18 | four ropes across each lower tube past its vent's landing, so every line meets a grapple line after the great room |
| `main_tube_lower_rope_2` | cable, `""` | `main_tube_lower_4` | from [-70.7, -98.1, 118.7] to [-47.8, -98.0, 138.9], radius 3.4, floor 18 | four ropes across each lower tube past its vent's landing, so every line meets a grapple line after the great room |
| `main_tube_lower_rope_3` | cable, `""` | `main_tube_lower_4` | from [-65.6, -98.0, 115.5] to [-45.3, -97.9, 133.4], radius 3.4, floor 18 | four ropes across each lower tube past its vent's landing, so every line meets a grapple line after the great room |
| `main_tube_lower_rope_4` | cable, `""` | `main_tube_lower_4` | from [-60.5, -96.9, 112.3] to [-42.8, -96.7, 128.0], radius 3.4, floor 18 | four ropes across each lower tube past its vent's landing, so every line meets a grapple line after the great room |
| `east_haulage_rope_1` | cable, `""` | `east_haulage_4` | from [147.2, -95.9, 89.3] to [163.2, -95.8, 110.4], radius 3.4, floor 18 | four ropes across each lower tube past its vent's landing, so every line meets a grapple line after the great room |
| `east_haulage_rope_2` | cable, `""` | `east_haulage_4` | from [151.5, -97.1, 85.2] to [168.7, -97.2, 108.0], radius 3.4, floor 18 | four ropes across each lower tube past its vent's landing, so every line meets a grapple line after the great room |
| `east_haulage_rope_3` | cable, `""` | `east_haulage_4` | from [155.9, -97.0, 81.0] to [174.2, -97.1, 105.5], radius 3.4, floor 18 | four ropes across each lower tube past its vent's landing, so every line meets a grapple line after the great room |
| `east_haulage_rope_4` | cable, `""` | `east_haulage_4` | from [160.2, -95.5, 76.9] to [179.7, -95.7, 103.1], radius 3.4, floor 18 | four ropes across each lower tube past its vent's landing, so every line meets a grapple line after the great room |
| `west_breakthrough_rope_1` | cable, `""` | `west_breakthrough_6` | from [-166.8, -98.7, 176.7] to [-155.9, -98.5, 208.5], radius 3.4, floor 18 | four ropes across each lower tube past its vent's landing, so every line meets a grapple line after the great room |
| `west_breakthrough_rope_2` | cable, `""` | `west_breakthrough_6` | from [-161.0, -99.6, 175.3] to [-151.2, -99.6, 204.6], radius 3.4, floor 18 | four ropes across each lower tube past its vent's landing, so every line meets a grapple line after the great room |
| `west_breakthrough_rope_3` | cable, `""` | `west_breakthrough_6` | from [-155.2, -99.6, 173.9] to [-146.6, -100.2, 200.8], radius 3.4, floor 18 | four ropes across each lower tube past its vent's landing, so every line meets a grapple line after the great room |
| `west_breakthrough_rope_4` | cable, `""` | `west_breakthrough_6` | from [-149.3, -98.6, 172.5] to [-142.0, -99.2, 197.0], radius 3.4, floor 18 | four ropes across each lower tube past its vent's landing, so every line meets a grapple line after the great room |
| `main_tube_upper_vent` | launcher, `geyser_vent` | `main_tube_upper_4` | at (88.3, -229.4), radius 5, target [58.8, -87.6, -191.9], floor 16, min flight 2.2 s, charge 3 s | a lava vent on the tube's straightest stretch: it throws a passing ball 50 m down the tube on an arc of at least 2.2 s |
| `skylight_chain_vent` | launcher, `geyser_vent` | `skylight_chain_8` | at (127.5, -126), radius 5, target [89.8, -90.3, -93.2], floor 16, min flight 2.2 s, charge 3 s | a lava vent on the tube's straightest stretch: it throws a passing ball 50 m down the tube on an arc of at least 2.2 s |
| `east_drift_vent` | launcher, `geyser_vent` | `east_drift_9` | at (189.5, -108.8), radius 5, target [152.8, -90.8, -75.1], floor 16, min flight 2.2 s, charge 3 s | a lava vent on the tube's straightest stretch: it throws a passing ball 50 m down the tube on an arc of at least 2.2 s |
| `west_gallery_vent` | launcher, `geyser_vent` | `west_gallery_9` | at (-150.1, -93.9), radius 5, target [-110.2, -91.1, -63.9], floor 16, min flight 2.2 s, charge 3 s | a lava vent on the tube's straightest stretch: it throws a passing ball 50 m down the tube on an arc of at least 2.2 s |
| `cannon_tube_vent` | launcher, `geyser_vent` | `cannon_tube_2` | at (-45.7, -314.1), radius 5, target [-79.4, -85.3, -277.2], floor 16, min flight 2.2 s, charge 3 s | a lava vent on the tube's straightest stretch: it throws a passing ball 50 m down the tube on an arc of at least 2.2 s |
| `main_tube_lower_vent` | launcher, `geyser_vent` | `main_tube_lower_2` | at (-41.3, 25.5), radius 5, target [-73.1, -94.5, 62.7], floor 16, min flight 2.2 s, charge 3 s | a lava vent on the tube's straightest stretch: it throws a passing ball 50 m down the tube on an arc of at least 2.2 s |
| `east_haulage_vent` | launcher, `geyser_vent` | `east_haulage_2` | at (65.7, 18.1), radius 5, target [108.5, -94.0, 43.9], floor 16, min flight 2.2 s, charge 3 s | a lava vent on the tube's straightest stretch: it throws a passing ball 50 m down the tube on an arc of at least 2.2 s |
| `west_breakthrough_vent` | launcher, `geyser_vent` | `west_breakthrough_8` | at (-123.3, 233.4), radius 5, target [-83.3, -100.0, 263.3], floor 16, min flight 2.2 s, charge 3 s | a lava vent on the tube's straightest stretch: it throws a passing ball 50 m down the tube on an arc of at least 2.2 s |
| `sealed_crosscut` | cracked_wall, `""` | `crosscut_drift` | at (-84, 150), 10 by 6 by 1.4 m | the hidden pocket: smash it to cut from the west breakthrough to the main lower tube |
| `fumarole` | launcher, `geyser_vent` | `lava_channel_5` | at (-267, -636.8), radius 3.5, target [0, -79.0, -362], floor 16, min flight 2.2 s, charge 3 s | a steam vent 24 m off the channel line that throws a ball that seeks it to the tube mouth |
| `cone_thermal` | thermal, `""` | `cinder_cone` | at (-690, -700), radius 6, height 70 | warm air rising off the cone: a glider's first height |
| `cave_breath` | thermal, `""` | `skylight_2` | at (175.3, -202), radius 5, height 40 | the tubes breathe out through skylight 2 |
| `great_room_lift` | lift, `lift_platform` | `great_room` | at (48, -4), radius 4.5, rise 50, charge 3.2 s | the miners' cage lift back up to the great room's rim |
| `drift_valve` | valve, `gauge` | `east_drift_3` | at (195.4, -272.1), door at (207.2, -277.5), 10 by 5 by 1 m | opens a side door from the drift into skylight 2's chamber |
| `cenote_raft` | barge, `barge` | `west_cenote` | a [-335, -84.8, -215] to b [-300, -85.3, -195], travel 6 s, dwell 2 s | a miners' raft across the cenote |
| `rim_zip` | cable, `""` | `sinkhole_walls` | from [-160, 4.4, 255] to [-60, -97.6, 330], radius 3.4, floor 18 | a drop line from the west rim to the gallery ring, after the cave-in opens the plateau |

Against the draft: the rope fan (`tube_rope_1` to `_4`), the eight tube vents and the twelve lower-tube ropes are new in KD4, because on this head a park row's ride sensor is never built (`ParkRecipes.place` has no caller), so contraptions and kicker rows are the only ride facts a line can earn (section 9). `sealed_crosscut` stands on its own `crosscut_drift` site row at (-84, 150) (R3, the cave-in ring); the fumarole, lift, valve and raft moved to the shipped polylines.

## 8. Weather and time of day

**Time: `afternoon`, fixed.** The sun stands in the south-west. On the surface it rakes the cone and the spatter field with long shadows. Underground it enters only through the skylights and the sinkhole, so the tubes read as dark with bright holes. The `world_look.gd` `TIME_ROWS` afternoon row owns sun height and colour (unit KE7).

| Id | Kind | Trigger | Live | Fog | Sky, sound, layer | Event odds |
| --- | --- | --- | --- | --- | --- | --- |
| `tube_mist` | cave_mist | always | always | density 0.004, `#9fb3b8` | clear; `cave_drip`; `drip_keys` | none |
| `afternoon_monsoon` | monsoon | clock tier 2, lead 8 s | 45 s, gap 120 s | density 0.008, `#6f7d86` | `storm_build`; `monsoon_rain`; `rain_toms` | `cenote_drain` x0.5 (rain refills the cenote) |

Both rows carry `handling: "none"`. The monsoon changes the view and the sound: rain curtains through the skylights and thin waterfalls down the sinkhole walls. It never changes the handling.

**The Dig lamps veto, kept.** VX8 (`364e1e6`, on Andrew's wave 11 veto list, `design-v3/HANDOFF.md:17`) removed the amber lamp pools and the breach-plate daylight shaft because they read as false telegraphs. This stage keeps that rule underground, where it matters most:

- Skylights get no volumetric light shaft and no light pool. They show the sky colour through the hole and raise the ambient level in a 20 m radius (start), nothing more.
- No warm OmniLight3D anywhere; drift lamps keep white, unpooled lenses (`src/presentation/dig_scenery.gd:404-405`).
- Breach caps carry no light under them.
- The only coloured light on a floor is a telegraph, a lamp swarm's lure bloom (an enemy's own read) or the brood's green.
- The light column is vertical, 4 m wide, centred on the nest and the Warden's colour. It lights no floor patch along a line.

## 9. Traversal lines (measured)

Every line passes the waymarks `drop_in`, `tube_mouth`, `great_room`, `landmark` in order; the waypoints are in `tools/park_lines/park_sinkhole.json`, cut from the shipped tube polylines (one waypoint per resampled polyline point). Measured with `tools/traversal_line.gd` (KB7) on the park table, stage 4, 8 seeds a line, `--fixed-fps 90`, on this branch's committed bake and graph (KD4 greybox, 2026-10-11). Medians of 8 seeds; the full 13-band table per line is in `design-v3/park/traversal/park_sinkhole.md`.

| Line | Class | Path (median) | Ratio | To the Warden | Segments (s) | Route |
| --- | --- | --- | --- | --- | --- | --- |
| Sable | pylon_engineer | 2178 m | 1.67 | 68.6 s (worst 218.5) | 30.4 / 16.8 / 20.8 | lava channel, main tube upper, great room, main tube lower |
| Rivet | runner_gunner | 2149 m | 1.65 | 102.6 s (worst 103.2) | 42.2 / 31.0 / 29.0 | lava channel, flooded west gallery, great room, east haulage |
| Kest | demolitions_caster | 2071 m | 1.58 | 94.4 s (worst 98.4) | 40.8 / 26.6 / 26.8 | lava channel, skylight chain, great room, main tube lower |
| Tarn | tarn | 2137 m | 1.64 | 93.2 s (worst 94.0) | 41.0 / 29.2 / 23.1 | lava channel, east drift, great room, west breakthrough |
| Tally | tally | 2049 m | 1.57 | 95.6 s (worst 101.8) | 41.9 / 25.5 / 28.3 | lava channel, main tube upper, great room, east haulage |
| The Cannon | remembered_cannon | 1975 m | 1.51 | 90.8 s (worst 91.5) | 42.5 / 21.5 / 26.6 | lava channel, cannon tube, great room, main tube lower |
| Floor line | runner_gunner | 2028 m | 1.55 | 100.1 s (worst 102.2) | 43.3 / 27.3 / 29.1 | the main tubes, no harpoon, no contraption it must seek |

**The flow line a skater takes.** Drop off the cinder cone's north-west flank, now 45 m tall so even a pilot that cannot boost reaches the blazing tier on the way down. Carve into the lava channel, a half-pipe of black cinder: take the cinder kicker, latch one of the four ropes slung across the channel, take the crust kicker on the last straight and drop into the tube mouth. Under the roof each tube has a lava vent on its straightest stretch that throws the ball 50 m on an arc of at least 2.2 s, and a kicker halfway down. Bank through the great room past the camp, take a lower tube, latch its rope fan past the vent's landing, and burst out onto the gallery ring with the sky open above and the brood glowing green on the far wall.

**Ride facts on this head.** A park row's ride sensor (`ride_chute`, `ride_bowl`, `ride_drop`, `ride_ledge`) is built by `ParkRecipes.place`, which nothing on this head calls, so the only ride facts a line can earn are the kickers' `kicker_launch`, the ropes' `ride_grapple_line`, a glider's `thermal_ride` and the lift's `lift_fired` (the lift's own cycle, heard on every line). Every line's distinct-verbs pass rests on those three or four; under KB7b's narrowed set (`lift_fired` out) a non-gliding line has two, a miss that needs the runtime ride sensors (follow-up).

**Against the draft.** The draft's estimates (62 to 79 s from mean speeds) were optimistic for every pilot but Sable: the plateau slab tilts only 30 m over 1,100 m, so a pilot that cannot boost settles near 23 m/s on the flat and runs 90 to 105 s. The bands are met by reworking rows (the 45 m cone, vents, kickers, rope fans, post walls), never by moving a band.

## 10. Music arc

The stage keeps its band: synth theme 1 and the ACE track `dig_deep` (`alpha_defs.gd:91`, `src/presentation/music_rows.gd:11`).

| Where or when | What the music does | Why |
| --- | --- | --- |
| Cone rim, the first 3 s | wind and the bed only | the first downbeat is the first landing in the crater |
| Crater and breach | the groove enters on the landing; a fill on the breach jump | drop-in equals music drop |
| Lava channel | full groove; the fumarole launch is a 1-bar riser | the vent is a held breath |
| Tube mouth | the band drops under a low-pass filter (start: 1.2 kHz cut) as the roof closes over you | form mirrors function: under a roof the music is muffled too |
| Tubes | the filter opens for one beat under each skylight; `drip_keys` plays sparse notes in the dark | the light and the sound open together |
| Great room | the filter half-opens and the reverb widens to the cavern | a big room sounds big |
| Lower tubes | a 2-bar riser as the tube's end brightens | the sinkhole is the stage's big drop |
| Gallery ring | the filter opens fully on the downbeat you burst onto the ring; the light column's `landmark_hum` sits under the band | sky, sound and landmark arrive together |
| Warden engaged | the lamp guard's own sound, then the swarm's G5 buzz locking into D5 G5 C6 F6 on each pulse (`SOUND-STORY.md:60`); the swarm never enters the band (`SOUND-STORY.md:69`, `280`) | the enemy's music is its own sound |
| Each chunk lost | the pool rises one step with a low water swell, and the locked chord loses its top voice | progress you can hear and see |
| Break | the pool floods to the ring; the chord breaks into single detuned notes and stops; the band's next downbeat is the drop | the drop lands on the break |
| Events | cave-in: low sub riser into a rock hit; barge: Brindle's anvil and brass (PARK.md section 5 rule 4); eruption: the swarm buzz rising; drain: a falling gurgle; boiler: the steam whistle into a percussion hit | one family, one sound |
| Weather layers | `drip_keys` always; `rain_toms` while the monsoon lives | weather changes the view and the sound, never the handling |

## 11. Codex fragments

Short field notes in the deep works' existing voice (`src/core/lore_rows.gd:195-224`). Ids are new; the KD4 unit adds them.

| Id | Found at | Text (draft) |
| --- | --- | --- |
| `ref_granary_ledge` | `trench_granaries` | Small stone rooms set high in the trench wall, doors no wider than a shoulder. Built to keep seed dry through a bad year. |
| `lava_cone_note` | `cinder_cone` | Cone survey: crater cold. Rock under the crater, not cold. |
| `lava_tube_flow` | `tube_mouth` | The tubes ran lava downhill, then nothing for a long time. The floors are polished anyway. |
| `lava_cenote_note` | `west_gallery_1` | Flooded gallery: water clear to the bottom. The lights are not on the bottom. |
| `mining_drift_tally` | `east_drift_1` | Drift tally: timber sets every six metres. One more set going in than coming out. |
| `ancient_buried_lens` | `machine_vault` | Vault seam: green, steady, warm to the glove. The seam is a lid. |
| `mining_cap_stencil` | `great_room_cap` | Cap stencil: DO NOT SLAM. Bolts already loosened. From underneath. |
| `mining_haulage_rails` | `east_haulage_1` | Haulage rails: ore cars ran to the pump shaft. Rails polished. No cars. |
| `mining_gallery_timber` | `gallery_ring` | Gallery ring set at the hundred-metre mark. The brood has built a second ring inside it. |
| `mining_pump_caisson` | `caisson_bowl` | Caisson log: pumped dry at shift change. Water back by noon. Level rises when something breaks. |
| `mining_pump_ticket` | `pump_gallery` | Pump ticket: boiler rated for the caisson. Caisson rated for water. |
| `ancient_brood_count` | landmark | Brood count: every bolt in the deep works, sorted by size. The count is still going. |

The `ref_` fragment describes the work and speaks for no living people (PARK.md section 4). `mining_pump_caisson` foreshadows the Warden's mechanism, and `ancient_brood_count` picks up the deep works' existing brood lines (`lore_rows.gd:215`, `224`). The existing codex entries this stage teaches stay: `lure_bloom`, `bore_breach`, `burrow_lane`, `awaiting_operator` and the variant's `brood_dark` (PARK.md:431).

## 12. What stays from today's stage

| Kept | Where it lives | Note |
| --- | --- | --- |
| Packs `deep_bore`, `deep_lamps`, `deep_crew`; the elite; the ancient `swarm_remnant` from unlock base 4 | `alpha_defs.gd:92`, `:96-100` | homes reinforce from these packs only |
| Pressure row and threat 1.2 | `alpha_defs.gd:91`, `:94` | unchanged |
| Warden plating 150, health 1100, posture curve, `ram_shatters` false, beacon 25 s and 30 m, the hint "Bowl through its guard rack, then smash the core." | `alpha_defs.gd:93-94` | the kind and variant stay, so the numbers carry over until KF3 re-measures |
| Variant `brood`: the lamp guard and the `brood_dark` discovery | `alpha_defs.gd:100`, `warden.gd:211-213`, `225-228` | the sinkhole mounting is the brood's home |
| Music theme 1, ACE `dig_deep` | `alpha_defs.gd:91`, `music_rows.gd:11` | the arc in section 10 rides it |
| Camp kinds and pay `pylon_capacitor` | `map_dig_deep.gd:52-53` | kept on `great_room_camp` |
| Breach plates as a slam verb | `map_dig_deep.gd:17-18`, `60` | become two caps |
| Vault and relic spot | `map_dig_deep.gd:39`, `59` | need the schema keys the stage 3 page proposes |

The ambush altar (`map_dig_deep.gd:54`) gives way to the hauler bounty, so the world's two stages offer different activity sets (stage 3: cache, camp, altar; stage 4: bounty, camp, cache).

**Warden band timings.** Today's stage 4 Warden breaks at a median of 39.66 s over eight seeds (`tools/posture_sweep.md:246`), inside the world 2 band of 24.5 to 128 s (`tests/alpha_posture_bands_w23_test.gd:27`). The rising pool makes each later chunk quicker, but the first stagger must now come from the pool floor 21 m below the nest, so the kind sheet predicts 45 to 70 s. KF3 re-measures and re-pins stage 4 with a dated header.

**Tests to re-pin (by name in `tests/`; the KD4 unit greps each for `dig_deep`, `brood` and the stage number first):** `dig_deep_zone_test.gd`, `dig_scenery_test.gd`, `warden_variants_test.gd`, `alpha_posture_bands_w23_test.gd`, `world_sites_test.gd`, `relics_per_world_test.gd`, `scatter_rows_test.gd`, `terrain_lazy_world_test.gd`, `world_table_test.gd`, `alpha_table_test.gd`. The music tests (`ace_tracks_test.gd`, `music_rows_test.gd`, `audio_music_rows_test.gd`) re-pin only if the map id becomes a music key.

## 13. Storyboard frames

Board id `park-4-park_sinkhole`. PARK.md section 6.1 panels in brackets. The pilot ball, where shown, is the expanded Hoberman-sphere mecha (`docs/decisions.tsv:417`). Frames match the shipped greybox (KD4, 2026-10-11): the drop-in is on the cinder cone's north-west flank at (-690, -760), the cone stands 45 m, and the great room hosts the on-line camp.

1. **Drop-in vista [p2_drop_in].** Behind the ball high on the cinder cone's north-west flank in afternoon light, looking south-east. The lava channel's black half-pipe leaves the cone and curls across the basalt plateau. Beyond, a line of skylights pocks the plateau, and far south-east a thin uranium-glass green column rises out of it where the sinkhole is. A monsoon cell builds in the south-west sky.
2. **First flow line [p3_line].** Chase camera low in the lava channel, a half-pipe of black cinder, the ball high on the left wall. Ahead, the cinder kicker's lip and, past it, four ropes slung across the channel; the fumarole steams on the bank, and the tube mouth gapes at the channel's end.
3. **An enemy home [p4_home].** The flooded west gallery: a dark lava tube with still water along its floor, three lamp-swarm lures hanging over it as the only light. The Rivet ball cuts a straight wake through the middle at speed, the lures swinging toward where it was.
4. **The great room camp [p5_event, swapped].** The cavern junction where every tube meets: basalt pillars ringing the room, the camp's burrowers, drill crew and lamps round the floor, the ball banking through them toward a lower tube mouth while a vent behind it throws the next ball into the air.
5. **The landmark approach [p3_line, second].** From inside a lower tube, the round mouth ahead blazes with daylight. Through it, the sinkhole's far wall in banded basalt and limestone, the timber gallery ring, and the brood's green nest. The ball is a silhouette against the light.
6. **The Warden fight [p6_warden].** Wide shot from the gallery ring. The brood nest, a lumpy honeycomb of hexagonal cells, clings to the south wall over a round pool. The lamp guard circles over the water. A ball is mid-ram across the pool floor. Waterfall threads from the monsoon fall down the walls; the light column rises from the nest to the sky.
7. **The drop finisher [p6_warden, second].** Stagger, the pool raised two steps: the nest's shutters are blown open and the queen cell swells green. The ball falls from a harpoon swing straight onto it, the rope trailing.
8. **The exit.** The pool flooded to the gallery ring, flat and bright, the nest dark and dripping. The bay's hover barge docks over the water by the gate, and the launch arc rises up the sinkhole's open throat toward the sky and the next world.

The west roof cave-in, frame 4 of the draft, fires at 45 s off every measured line; it stays a roaming player's event and a codex frame, not a line frame.

## 14. Calls, veto list and open questions

**Calls made under the creative charge (veto list).**

1. The great room is the one junction every line passes, and it hosts the hauler bounty as waymark 3.
2. Five upper routes (main tube, skylight chain, flooded gallery, east drift, cannon tube) give each pilot family its own way; the floor line takes the main tubes.
3. The pool rises 5 m a step from -120 to -105, and the break floods it to the gallery ring at -100.
4. The light column is 4 m wide and green. It is the stage's sight line, because the sinkhole cannot be seen from the plateau.
5. Skylights get no light shaft or pool, following the wave 11 lamp veto.
6. The ambush altar gives way to a hauler bounty in the great room.
7. The Ancestral Puebloan granaries sit off every measured line, on the west loop, and host nothing hostile.
8. The music filter follows the roof: muffled under a roof, open under sky.
9. The hive cells home reinforces from the director's ancient pack, so no new pack id is needed.

**Open questions for K1, KD4 and the coordinator.**

1. Same schema gaps as stage 3: rescue rows, vault, relic spot and breach caps (stage 3 page, section 14, question 1). `map_dig_deep.gd:58` places today's relic spot south of Kest's cage; KD4 confirms whether stage 4 keeps a rescue at all.
2. Tube rows need a `y` profile along their length (mouth -12 m to ring -100 m). This draft uses one `y` per segment; the bake may want `y0` and `y1`.
3. Roofed cells: the sight test excludes them (PARK.md:474), but the schema has no roof flag; `tunnel` and `flooded_cavern` rows could imply it.
4. New telegraph forms for KE1: `crust_crack`, `drain_gurgle`. New music cues for KE8: `drop_cave_in`, `drop_drain`.
5. Whether a lamp-swarm guard's scatter pays `GUARD_RACK_POSTURE` (`warden.gd:194-203` checks `enemy.get("swarm")` and `guard.following()`, which a lamp guard may not expose) is unverified; the kind sheet's section 3 asks KF3 to check it.

**KD4 greybox calls (2026-10-11), on the veto list.**

1. Waymark 3 is the landform row `great_room`, and the on-line camp `great_room_camp` (was `great_room_camp`) sits on it (R2, R3: the camp stood inside the `cenote_drain` site). Call 1 and call 6 above now read: the great room hosts the camp; the hauler bounty moved to a side chamber.
2. The hauler bounty is `east_chamber_bounty` (was `great_room`), in a side chamber off the great room's east wall, door 196 m of path from the line (the risk pocket); the cracked cache is `west_chamber_cache` (was `west_chamber_cache`) in the west side chamber, 209 m off (the reward pocket). PARK.md 2.12 wins over the journey beat (R7).
3. `sealed_crosscut` stands on its own `crosscut_drift` site, door at (-80, 152), clear of the `west_tube_roof` cave-in ring; its door is 43 m of path off the line and 238 m from the nearest door (R3).
4. The cinder cone stands 45 m (draft 15 m) and every tube carries a kicker, a lava vent on its straightest stretch and, in the lower tubes, a four-rope fan. Without them a pilot that cannot boost settled near 23 m/s on the 30 m tilt and missed the peak-speed, blazing-time and airborne bands.
5. Every tube is lined with basalt pillars and walls standing 16 to 20 m over the floor (posts, fillers and lip pillars) so the anchor probe never runs 40 m dry, even at a vent's apex.
6. Cross-stage fact 2 (one gate slot in world 2 against two arches) is reported, not changed.

## Appendix: the shipped park file

The draft park file that stood here is superseded. The shipped file is `sketches/core-loop/src/world/park/park_sinkhole.json` (KD4 greybox, 2026-10-11); its bake and graph are in `sketches/core-loop/assets/park/park_sinkhole/`, its pilot lines in `sketches/core-loop/tools/park_lines/park_sinkhole.json`, and its measured bands in `sketches/core-loop/design-v3/park/traversal/park_sinkhole.md`.
