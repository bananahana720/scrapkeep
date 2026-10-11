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
| Landmark | the sinkhole, 250 m across and 120 m deep at (0, 350), open to the sky, with a Cherenkov-blue light column 140 m tall (PARK.md:377) |
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

**The sinkhole.** A round collapse 250 m across that opens the plateau to the sky. Its walls are layered basalt over pale limestone, streaked with mineral stain, with the miners' timber gallery ring at the 100 m mark and the caisson's flooded pool in the middle. From the plateau you cannot see into it, so the landmark is its light column: a Cherenkov-blue beam 4 m wide (start) rising from the nest to `sight_top` [0, 140, 388], 140 m above the plain. The column is the brood's light, not daylight, so it reads as "the Warden is there" and never as a floor telegraph (section 8).

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
| BOUNTY | the hauler bounty in the great room, waymark 3, 6 m off the room's centre | (6, -20) |
| HIVE | landmark warden anchor; the light column rises here | (0, 388), y -99 |
| GATE, BAY | gate slot, bay dock | (0, 305), (0, 320) |
| Homes | cinder burrowers in the channel; lamps in the flooded west gallery; drill crews in the east drift; hive cells on the gallery ring; the barge's bore crew (dormant) | channel (-215, -555); gallery (-90, -330); drift (165, -200); ring (0, 350); apron (240, 150) |
| Contraptions | fumarole (-150, -480); cone thermal (-320, -705); cave breath (220, -200); great room lift (20, -10); drift valve (170, -200); sealed crosscut (-75, 110); cenote raft (-330, -200) to (-270, -160); rim zip (-110, 260) to (-48, 350) |
| Activities | hauler bounty `bounty_great_room`; enemy camp `cenote_camp`; cracked cache `trench_cache` | (6, -20); (-300, -170); (-520, -120) |
| Event sites | west roof cave-in (-110, 200); machine vault (-230, -120); bore apron (240, 150); west cenote (-300, -180); pump gallery (50, 350) |

The bounty sits on every line, in the one room every tube passes through. The camp's lamps glow at the cenote's edge, seen from the west gallery. The cache sits in the west trench under the granaries, the reward for a roaming loop.

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

## 5. `event_rows` draft

Five rows, all four families. Tier 1 at 45 s and tier 2 at 90 s (`src/world/director.gd:83-85`, as cited in PARK.md section 5); tier 3 needs veto item 16 (`MAX_TIME_TIERS` raised to 4).

| Id | Kind, family | Site | Trigger | Telegraph | Effect | Route change | Music |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `west_roof_cave_in` | cave_in, natural | `west_tube_roof` | clock tier 1 | 6 s, `crust_crack` (new form), on bar | the west tube's roof falls in over a 70 by 40 m patch; the tube becomes an open trench 12 m deep | opens `plateau_drop`, a way in from the plateau | `riser_natural` / `drop_cave_in` |
| `junction_machine_wakes` | machine_eruption, ancient | `machine_vault` | clock tier 2 | 8 s, `ancient_stirring`, on bar | a swarm remnant miniboss breaks out of the sealed vault; the vault's lip becomes a kicker into the great room | closes `cannon_tube`, opens `eruption_lip` | `riser_ancient` / `drop_ancient` |
| `bore_barge` | fleet_landing, fleet | `bore_apron` | clock tier 2 | 10 s, `fleet_inbound`, on bar | drill barge lands, footprint 40 by 18 m, bores a shaft about 70 m down to the east haulage and wakes `barge_bore_crew` | opens `bore_shaft` | `riser_fleet` / `drop_fleet` |
| `cenote_drain` | drain, natural | `west_cenote` | clock tier 3 | 5 s, `drain_gurgle` (new form), on bar | the cenote drains from 1.2 m to dry over 12 s for 60 s; the camp's floor opens | opens `cenote_floor` | `riser_natural` / `drop_drain` |
| `pump_boiler` | boiler_burst, industrial | `pump_gallery` | Warden phase `chunk_2` | 5 s, `boiler_pressure`, on bar | steam cone 24 by 10 m, 6 damage, 8 s; the pump gallery's fallen boiler becomes a ramp from the pool to the ring | opens `pump_ramp` | `riser_industrial` / `drop_industrial` |

**Why these.** A direct run (about 65 s) sees the cave-in from below at about 51 s and the boiler during the fight; the eruption, the barge and the drain reward roaming. Checks against the momentum rules (PARK.md:308):

- The cave-in's site sits on the Tarn line, which passes under it at about 53 s. Its `hold_clear_m` of 20 holds the fall while a ball is within 20 m (`src/world/terrain_event.gd:7-11`), and no route closes.
- The eruption closes the cannon tube, which is the Cannon's line. Tier 2 fires at 90 s and every measured line leaves the upper tubes by 58 s (Kest is last, section 9). A Cannon still roaming there at 98 s gets an 8 s telegraph and three other tubes, and the same row opens `eruption_lip`. The vault's edge sits 22 m from the line, outside the 8 m corridor.
- The barge footprint sits on the plateau 55 m in plan from the east haulage line and about 70 m above it.
- The drain lowers water and never raises ground.
- The boiler sits 63 m from the nest, outside the 45 m engage ring, so its steam never lands in the fight.

## 6. `home_rows` draft

| Id | Enemy | Site (landform) | Advantage | Counter | Reinforce | Break | Stops kind |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `cinder_burrowers` | burrower | `lava_channel_1` (lava_tube) | loose black cinder fills the channel floor, so the burrow bulge hides in the grain, and every line rides this channel in its first 30 s | the channel is a half-pipe: ride the wall above the committed 2.2 m lane (`src/combat/burrower.gd:10`), or slam the marker | tier 0, every 24 s, max 3, `deep_bore` | slam, 60 hp, 12 scrap | yes |
| `gallery_lamps` | lamp_swarm | `west_gallery_1` (cenote_pool) | the flooded gallery is the darkest place in the park, so the 9 m lure bloom (`src/combat/lamp_swarm.gd:17`) is the only light and bends a slow ball toward the pool edge | the Rivet line sprints the gallery at cruise or faster, which the lure never touches (`lamp_swarm.gd:7-9`); a cruise ram scatters the lamps | tier 1, every 22 s, max 3, `deep_lamps` | ram, 50 hp, 10 scrap | yes |
| `drift_drill_crews` | drill_crew | `east_drift_2` (adit) | the drift is 8 m wide and straight, so a rig leading the ball by 0.8 s (`src/combat/drill_crew.gd:11`) puts its 3 m ring on the line | the timber sets every 6 m are claw and harpoon anchors: swing over the ring, or smash the rig mid-bore | tier 1, every 26 s, max 2, `deep_crew` | smash, 80 hp, 14 scrap | no (the barge also brings them) |
| `hive_cells` | swarm_remnant | `gallery_ring` (sinkhole) | the brood's outer cells line the gallery ring above the pool, so drone racks dive from the ring onto a ball pumping the pool below | bowl through a forming rack at cruise or faster and the drones follow you; lead them into the lamp guard as pins (the `awaiting_operator` codex entry, `src/combat/codex_entries.gd:162`) | tier 1, every 30 s, max 6, `swarm_remnant` (the director's ancient pack, `src/world/director.gd:404-407`) | smash, 90 hp, 16 scrap | yes |
| `barge_bore_crew` | drill_crew | `bore_apron` (lava_tube) | the barge bores straight down into the east haulage, so its crew arrives under the plateau ahead of a ball already in the tubes | ride the 70 m bore shaft down past the crew, or shoot the mast from the rim | tier 2, every 30 s, max 2, `deep_crew` | damage, 150 hp, 20 scrap | yes; dormant until the barge lands |

Every pack is the stage's own (`alpha_defs.gd:96-99`) or the director's ancient pack for the stage's ancient, `swarm_remnant` (`alpha_defs.gd:92`). The hive cells home is PARK.md's "swarm remnants in the sinkhole cells" (PARK.md:385).

## 7. `contraption_rows` draft

Spec keys are today's (`src/world/contraptions.gd:86-101`).

| Id | Kind, recipe | Site | Spec (start) | What it is for |
| --- | --- | --- | --- | --- |
| `fumarole` | launcher (geyser), `geyser_vent` | `lava_channel_2` | at (-150, -480), target (0, -5.2, -360), floor 16, min flight 2.2 s, charge 3.0 s | a steam vent in the channel floor that throws you into the tube mouth |
| `cone_thermal` | thermal, `""` | `cinder_cone` | at (-320, -705), radius 6, height 70 | warm air rising out of the crater: Kest's first height |
| `cave_breath` | thermal, `""` | `skylight_2` | at (220, -200), radius 5, height 40 | the tubes breathe out through skylight 2 in the afternoon heat |
| `great_room_lift` | lift, `lift_platform` | `great_room` | at (20, -10), radius 4.5, rise 50, charge 3.2 s | the miners' cage lift back up to the main tube's roof shelf |
| `drift_valve` | valve, `gauge` | `east_drift_2` | at (170, -200), door at (150, -200), 10 by 5 by 1 m, turn 1.57 | opens a side door from the drift into skylight 2's chamber |
| `sealed_crosscut` | cracked_wall, `""` | `west_breakthrough_1` | at (-75, 110), 10 by 6 by 1.4 m | smash it to cut from the west tube to the main lower tube |
| `cenote_raft` | barge, `barge` | `west_cenote` | a (-330, -30.6, -200) to b (-270, -30.6, -160), 14 m deck, travel 6 s, dwell 2 s | a miners' raft across the cenote to the camp |
| `rim_zip` | cable, `""` | `sinkhole_walls` | from (-110, 3.2, 260) to (-48, -97.6, 350), radius 3.4, floor 18 | a 100 m drop line from the west rim to the gallery ring, after the cave-in opens the plateau |

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
- The only coloured light on a floor is a telegraph, a lamp swarm's lure bloom (an enemy's own read) or the brood's blue.
- The light column is vertical, 4 m wide, centred on the nest and the Warden's colour. It lights no floor patch along a line.

## 9. Traversal lines

Every line passes the waymarks `drop_in`, `tube_mouth`, `bounty_great_room`, `landmark` in order. Lengths are measured on the waypoints below. Times assume the same mean planar speeds as stage 3 (Sable 27, Rivet 30, Kest 24, Tarn 25, Tally 27, the Cannon 26, the floor line 20 m/s), which is my estimate, not a measurement; the bot measures in KD4. Straight distance from the drop-in to the nest is 1,158 m.

| Line | Length | Ratio | Est. time | Segments (s) | Route |
| --- | --- | --- | --- | --- | --- |
| Sable | 1,686 m | 1.46 | 62.5 s | 19.8 / 23.7 / 18.9 | main tube upper, great room, main tube lower |
| Rivet | 1,866 m | 1.61 | 62.2 s | 17.8 / 23.7 / 20.7 | flooded west gallery, great room, east haulage |
| Kest | 1,898 m | 1.64 | 79.1 s | 24.6 / 33.2 / 21.3 | cone thermal, skylight chain, main tube upper and lower |
| Tarn | 1,572 m | 1.36 | 62.9 s | 21.4 / 21.7 / 19.7 | east drift, great room, west breakthrough |
| Tally | 1,796 m | 1.55 | 66.5 s | 19.8 / 23.7 / 23.0 | main tube upper, great room, east haulage |
| The Cannon | 1,832 m | 1.58 | 70.5 s | 20.6 / 30.2 / 19.7 | cannon tube, main tube upper's tail, main tube lower |
| Floor line | 1,686 m | 1.46 | 84.3 s | 26.7 / 32.0 / 25.6 | main tubes, no harpoon, no contraption |

**The flow line a skater takes.** Roll off the cone's north rim and carve the crater bowl, down and round to the breach on its south-east. Shoot the breach into the lava channel, a half-pipe of black cinder, and either drop into the tube mouth at the channel's end or let the fumarole throw you there. Under the roof the ride becomes a dark slalom: S-bends between basalt pillars, skylights flashing overhead, a fall of 43 m to the great room. Bank round the great room's cavern bowl past the hauler, take a lower tube another 45 m down, and burst out onto the gallery ring with the sky open 100 m above, the pool below and the brood glowing blue on the far wall.

**Tricks it offers each pilot (verbs from the brief).**

| Pilot | Tricks on this stage |
| --- | --- |
| Sable (vault, slingshot) | slingshot round the basalt pillars at the main tube's S-bends, (40, -250), (-60, -190) and (60, -90); vault from the great room's lip into the lower tube; vault off the gallery ring over the pool onto the nest |
| Rivet (sprint) | sprint the flooded west gallery at cruise, where the lamps' lure never bends you (`lamp_swarm.gd:7-9`); sprint the east haulage's 8 m drift on its rails |
| Kest (glide, rocket jump) | circle the cone thermal for 70 m of height and glide off the cone; on the skylight chain, rocket-jump out of skylight 1, glide over the surface, drop into skylight 2, ride the cave breath up, and glide to skylight 3 |
| Tarn (claw pull) | claw-pull along the east drift's timber sets every 6 m; claw round the west breakthrough's tight bends to the ring |
| Tally (surge) | surge the main tube's banked S-bends; surge the east haulage straight to the ring |
| The Cannon (recoil) | recoil down the cannon tube's straight bores to stretch each drop; recoil-turn in the great room's bowl to line up the lower tube |

**Against PARK.md's bands (estimates).** Time to Warden: 62.2 to 79.1 s (band 60 to 120 s); Rivet and Sable sit closest to the floor. Segments: 17.8 to 33.2 s (band 12 to 45 s). Ratio: 1.36 to 1.64 (band 1.3 to 2.0). Floor line: 84.3 s, 1.30 times the pilot median of 64.7 s, inside 2.0. Distinct verbs: every line rides `ride_bowl` (cone, great room, pool), `ride_drop` (breach, tube mouth) and `ride_chute` (channel, tubes); Kest adds `ride_hop` and `thermal_ride`, Rivet and Tally add `ride_grapple_line` on the haulage rails. Peak speed: the cone's 90 m and the 100 m fall from the channel to the ring give more height than stage 3; the blazing tier (26.6 m/s) comes in the crater bowl. Distinct lines: from the tube mouth to the great room five lines split across five different tubes, so at least three lines are distinct by more than 8 m for more than 40% of their length.

**Roof share.** Every line's segment 1 runs on the surface and segments 2 and 3 run under a roof, except Kest's skylight hops (about 120 m of surface) and the last 20 m onto the gallery ring. That puts each line at 50% or more under a roof, above PARK.md's 40% (PARK.md:583). The bake's roofed-cell mask confirms it in KD4.

**Draft for `tools/park_lines/park_sinkhole.json`** (`BAR` is PARK.md section 8's band object):

```
{"map": "park_sinkhole", "stage": 4, "pilots": {
  "sable": {"waypoints": ["drop_in", [-310, -700], [-300, -640], [-250, -590], [-180, -520], [-100, -440], "tube_mouth", [-70, -300], [40, -250], [-60, -190], [-50, -120], [60, -90], [-20, -50], "bounty_great_room", [-60, 40], [40, 90], [-30, 150], [20, 200], [0, 295], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}},
  "rivet": {"waypoints": ["drop_in", [-310, -700], [-300, -640], [-250, -590], [-180, -520], [-100, -440], "tube_mouth", [-180, -300], [-300, -180], [-200, -80], "bounty_great_room", [150, 80], [210, 220], [170, 330], [55, 350], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}},
  "kest": {"waypoints": ["drop_in", [-310, -700], [-340, -650], [-320, -600], [-260, -600], [-250, -590], [-180, -520], [-100, -440], "tube_mouth", [120, -300], [220, -200], [60, -150], [-50, -120], [60, -90], [-20, -50], "bounty_great_room", [-60, 40], [40, 90], [-30, 150], [20, 200], [0, 295], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}},
  "tarn": {"waypoints": ["drop_in", [-310, -700], [-300, -640], [-250, -590], [-180, -520], [-100, -440], "tube_mouth", [150, -280], [180, -120], [80, -40], "bounty_great_room", [-60, 60], [-110, 200], [-128, 300], [-55, 350], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}},
  "tally": {"waypoints": ["drop_in", [-310, -700], [-300, -640], [-250, -590], [-180, -520], [-100, -440], "tube_mouth", [-70, -300], [40, -250], [-60, -190], [-50, -120], [60, -90], [-20, -50], "bounty_great_room", [150, 80], [210, 220], [170, 330], [55, 350], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}},
  "cannon": {"waypoints": ["drop_in", [-310, -700], [-300, -640], [-250, -590], [-180, -520], [-100, -440], "tube_mouth", [-150, -330], [-250, -250], [-200, -150], [-50, -120], [60, -90], [-20, -50], "bounty_great_room", [-60, 40], [40, 90], [-30, 150], [20, 200], [0, 295], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}}},
 "floor": {"waypoints": ["drop_in", [-310, -700], [-300, -640], [-250, -590], [-180, -520], [-100, -440], "tube_mouth", [-70, -300], [40, -250], [-60, -190], [-50, -120], [60, -90], [-20, -50], "bounty_great_room", [-60, 40], [40, 90], [-30, 150], [20, 200], [0, 295], "landmark"]}}
```

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
| `ancient_buried_lens` | `machine_vault` | Vault seam: blue, steady, warm to the glove. The seam is a lid. |
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
| Camp kinds and pay `pylon_capacitor` | `map_dig_deep.gd:52-53` | kept on `cenote_camp` |
| Breach plates as a slam verb | `map_dig_deep.gd:17-18`, `60` | become two caps |
| Vault and relic spot | `map_dig_deep.gd:39`, `59` | need the schema keys the stage 3 page proposes |

The ambush altar (`map_dig_deep.gd:54`) gives way to the hauler bounty, so the world's two stages offer different activity sets (stage 3: cache, camp, altar; stage 4: bounty, camp, cache).

**Warden band timings.** Today's stage 4 Warden breaks at a median of 39.66 s over eight seeds (`tools/posture_sweep.md:246`), inside the world 2 band of 24.5 to 128 s (`tests/alpha_posture_bands_w23_test.gd:27`). The rising pool makes each later chunk quicker, but the first stagger must now come from the pool floor 21 m below the nest, so the kind sheet predicts 45 to 70 s. KF3 re-measures and re-pins stage 4 with a dated header.

**Tests to re-pin (by name in `tests/`; the KD4 unit greps each for `dig_deep`, `brood` and the stage number first):** `dig_deep_zone_test.gd`, `dig_scenery_test.gd`, `warden_variants_test.gd`, `alpha_posture_bands_w23_test.gd`, `world_sites_test.gd`, `relics_per_world_test.gd`, `scatter_rows_test.gd`, `terrain_lazy_world_test.gd`, `world_table_test.gd`, `alpha_table_test.gd`. The music tests (`ace_tracks_test.gd`, `music_rows_test.gd`, `audio_music_rows_test.gd`) re-pin only if the map id becomes a music key.

## 13. Storyboard frames

Board id `park-4-park_sinkhole`. PARK.md section 6.1 panels in brackets. The pilot ball, where shown, is the expanded Hoberman-sphere mecha (`docs/decisions.tsv:417`).

1. **Drop-in vista [p2_drop_in].** Behind the ball on the cinder cone's north rim in afternoon light, looking south. The crater bowl falls away in red-black cinder, breached on the far side. Beyond, a flat black basalt plateau runs to the horizon, pocked with a line of skylights. Far south, a thin Cherenkov-blue column rises out of the plateau where the sinkhole is. A monsoon cell builds in the south-west sky.
2. **First flow line [p3_line].** Chase camera low in the lava channel, a half-pipe of black cinder with glassy walls, the ball high on the left wall. Ahead, the fumarole vents white steam and the tube mouth gapes, a collapsed skylight with the tube's dark throat beyond.
3. **An enemy home [p4_home].** The flooded west gallery: a dark lava tube half full of clear still water, three lamp-swarm lures hanging over the surface as the only light, their reflections below. The Rivet ball cuts a straight wake through the middle at speed, the lures swinging toward where it was.
4. **An event firing [p5_event].** Inside the west tube, looking up. The roof's crust cracks in a glowing ring (the `crust_crack` telegraph) and dust sifts down. Second beat: the roof has fallen away into a sky-lit trench, rubble banked into ramps along the walls, and a ball rides the bank past it.
5. **The landmark approach [p3_line, second].** From inside the main lower tube, the round mouth ahead blazes with daylight. Through it, the sinkhole's far wall in banded basalt and limestone, the timber gallery ring, and the brood's blue nest. The ball is a silhouette against the light.
6. **The Warden fight [p6_warden].** Wide shot from the gallery ring. The brood nest, a lumpy honeycomb of hexagonal cells, clings to the south wall over a round pool. The lamp guard circles over the water. A ball is mid-ram across the pool floor. Waterfall threads from the monsoon fall down the walls; the light column rises from the nest to the sky.
7. **The drop finisher [p6_warden, second].** Stagger, the pool raised two steps: the nest's shutters are blown open and the queen cell swells blue. The ball falls from a harpoon swing straight onto it, the rope trailing.
8. **The exit.** The pool flooded to the gallery ring, flat and bright, the nest dark and dripping. The bay's hover barge docks over the water by the gate, and the launch arc rises up the sinkhole's open throat toward the sky and the next world.

## 14. Calls, veto list and open questions

**Calls made under the creative charge (veto list).**

1. The great room is the one junction every line passes, and it hosts the hauler bounty as waymark 3.
2. Five upper routes (main tube, skylight chain, flooded gallery, east drift, cannon tube) give each pilot family its own way; the floor line takes the main tubes.
3. The pool rises 5 m a step from -120 to -105, and the break floods it to the gallery ring at -100.
4. The light column is 4 m wide and blue. It is the stage's sight line, because the sinkhole cannot be seen from the plateau.
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

## Appendix: draft park file

Generated from the tables above and checked for enums, id references, home landforms, pack membership, lead floors and the real-culture rule (no failures on this stage). It is the schema-exact form for `src/world/park/park_sinkhole.json`.

```json
{
 "schema": "scrapkeep-park/1",
 "map": "park_sinkhole",
 "size_m": 1600,
 "time_of_day": "afternoon",
 "spawn": {"at": [-330, -760], "heading_deg": 17},
 "play_rect": [-760, -790, 1520, 1580],
 "landmark": {"id": "sinkhole", "kind": "sinkhole", "at": [0, 350], "size": [250, 120, 250], "yaw_deg": 0, "recipe": "landmark_sinkhole", "budget": "hero_landmark", "sight_top": [0, 140, 388], "sight_share": 0.85, "beacon": [0, 350], "reach_m": 45, "warden": {"mounting": "sinkhole", "anchor": [0, -99, 388], "path": [], "hardpoints": 3}, "bay_dock": {"at": [0, 320], "facing_deg": 0}, "gate_slots": [{"at": [0, 305], "facing_deg": 180}], "light": "ancient_beam", "music": "landmark_hum", "fragment": "ancient_brood_count"},
 "waymarks": ["drop_in", "tube_mouth", "bounty_great_room", "landmark"],
 "routes": [
  {"id": "main", "from": "drop_in", "to": "landmark", "via": ["cinder_cone", "crater_breach", "lava_channel_1", "lava_channel_2", "tube_mouth", "main_tube_upper_1", "main_tube_upper_2", "main_tube_upper_3", "main_tube_upper_4", "main_tube_upper_5", "main_tube_upper_6", "main_tube_upper_7", "great_room", "main_tube_lower_1", "main_tube_lower_2", "main_tube_lower_3", "main_tube_lower_4", "main_tube_lower_5", "gallery_ring", "caisson_bowl"]},
  {"id": "west_gallery", "from": "tube_mouth", "to": "great_room", "via": ["west_gallery_1", "west_gallery_2", "west_gallery_3", "west_gallery_4", "west_cenote"]},
  {"id": "east_drift", "from": "tube_mouth", "to": "great_room", "via": ["east_drift_1", "east_drift_2", "east_drift_3", "east_drift_4"]},
  {"id": "skylight_chain", "from": "tube_mouth", "to": "great_room", "via": ["skylight_chain_1", "skylight_chain_2", "skylight_chain_3", "skylight_chain_4", "skylight_1", "skylight_2", "skylight_3"]},
  {"id": "cannon_tube", "from": "tube_mouth", "to": "great_room", "via": ["cannon_tube_1", "cannon_tube_2", "cannon_tube_3", "cannon_tube_4"]},
  {"id": "east_haulage", "from": "great_room", "to": "landmark", "via": ["east_haulage_1", "east_haulage_2", "east_haulage_3", "east_haulage_4", "gallery_ring"]},
  {"id": "west_breakthrough", "from": "great_room", "to": "landmark", "via": ["west_breakthrough_1", "west_breakthrough_2", "west_breakthrough_3", "west_breakthrough_4", "gallery_ring"]},
  {"id": "breach_caps", "from": "great_room", "to": "landmark", "via": ["great_room_cap", "upper_tube_cap"]},
  {"id": "cenote_floor", "from": "west_cenote", "to": "great_room", "via": ["west_cenote"]},
  {"id": "eruption_lip", "from": "machine_vault", "to": "great_room", "via": ["machine_vault"]},
  {"id": "plateau_drop", "from": "west_tube_roof", "to": "landmark", "via": ["west_tube_roof", "west_breakthrough_3"]},
  {"id": "bore_shaft", "from": "bore_apron", "to": "landmark", "via": ["bore_apron", "east_haulage_2"]},
  {"id": "rim_line", "from": "sinkhole_walls", "to": "landmark", "via": ["sinkhole_walls", "gallery_ring"]},
  {"id": "pump_ramp", "from": "pump_gallery", "to": "landmark", "via": ["pump_gallery", "caisson_bowl"]},
  {"id": "west_loop", "from": "west_trench", "to": "west_gallery_2", "via": ["west_trench", "trench_granaries"]},
  {"id": "east_loop", "from": "spatter_field", "to": "east_mesa", "via": ["spatter_field", "east_mesa"]},
  {"id": "south_loop", "from": "south_flats", "to": "sinkhole_walls", "via": ["south_flats"]}
 ],
 "park_rows": [
  {"id": "cinder_cone", "element": "bowl", "landform": "butte", "society": "none", "at": [-320, -705], "y": null, "size": [460, 90, 460], "yaw_deg": 0, "verb": "pump", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "crater", "hole": false, "budget": "landform", "routes": ["main"], "fragment": "lava_cone_note"},
  {"id": "crater_breach", "element": "drop", "landform": "lava_tube", "society": "none", "at": [-275, -615], "y": null, "size": [70, 10, 30], "yaw_deg": 45, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:drop", "stamp": "ramp", "hole": false, "budget": "landform", "routes": ["main"], "fragment": ""},
  {"id": "lava_channel_1", "element": "half_pipe", "landform": "lava_tube", "society": "none", "at": [-215, -555], "y": null, "size": [99, 8, 30], "yaw_deg": 45, "verb": "pump", "ride_fact": "ride_chute", "home": "cinder_burrowers", "recipe": "", "stamp": "channel", "hole": false, "budget": "landform", "routes": ["main"], "fragment": ""},
  {"id": "lava_channel_2", "element": "half_pipe", "landform": "lava_tube", "society": "none", "at": [-140, -480], "y": null, "size": [113, 8, 30], "yaw_deg": 45, "verb": "pump", "ride_fact": "ride_chute", "home": "", "recipe": "", "stamp": "channel", "hole": false, "budget": "landform", "routes": ["main"], "fragment": ""},
  {"id": "tube_mouth", "element": "drop", "landform": "lava_tube", "society": "none", "at": [0, -360], "y": null, "size": [60, 12, 40], "yaw_deg": 51, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "lava_tube_run", "stamp": "sinkhole", "hole": true, "budget": "park_large", "routes": ["main", "west_gallery", "east_drift", "skylight_chain", "cannon_tube"], "fragment": "lava_tube_flow"},
  {"id": "main_tube_upper_1", "element": "tunnel", "landform": "lava_tube", "society": "none", "at": [-35, -330], "y": -15.1, "size": [92, 14, 24], "yaw_deg": -49, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "lava_tube_run", "stamp": "", "hole": false, "budget": "park_large", "routes": ["main"], "fragment": ""},
  {"id": "main_tube_upper_2", "element": "tunnel", "landform": "lava_tube", "society": "none", "at": [-15, -275], "y": -22.3, "size": [121, 14, 24], "yaw_deg": 66, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "lava_tube_run", "stamp": "", "hole": false, "budget": "park_large", "routes": ["main"], "fragment": ""},
  {"id": "main_tube_upper_3", "element": "tunnel", "landform": "lava_tube", "society": "none", "at": [-10, -220], "y": -30.2, "size": [117, 14, 24], "yaw_deg": -59, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "lava_tube_run", "stamp": "", "hole": false, "budget": "park_large", "routes": ["main"], "fragment": ""},
  {"id": "main_tube_upper_4", "element": "tunnel", "landform": "lava_tube", "society": "none", "at": [-55, -155], "y": -36.5, "size": [71, 14, 24], "yaw_deg": 8, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "lava_tube_run", "stamp": "", "hole": false, "budget": "park_large", "routes": ["main"], "fragment": ""},
  {"id": "main_tube_upper_5", "element": "tunnel", "landform": "lava_tube", "society": "none", "at": [5, -105], "y": -42.7, "size": [114, 14, 24], "yaw_deg": 75, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "lava_tube_run", "stamp": "", "hole": false, "budget": "park_large", "routes": ["main"], "fragment": ""},
  {"id": "main_tube_upper_6", "element": "tunnel", "landform": "lava_tube", "society": "none", "at": [20, -70], "y": -49.6, "size": [89, 14, 24], "yaw_deg": -63, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "lava_tube_run", "stamp": "", "hole": false, "budget": "park_large", "routes": ["main"], "fragment": ""},
  {"id": "main_tube_upper_7", "element": "tunnel", "landform": "lava_tube", "society": "none", "at": [-10, -35], "y": -53.8, "size": [36, 14, 24], "yaw_deg": 34, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "lava_tube_run", "stamp": "", "hole": false, "budget": "park_large", "routes": ["main"], "fragment": ""},
  {"id": "skylight_chain_1", "element": "tunnel", "landform": "lava_tube", "society": "none", "at": [60, -330], "y": -15.4, "size": [134, 10, 20], "yaw_deg": 63, "verb": "launch", "ride_fact": "ride_hop", "home": "", "recipe": "lava_tube_run", "stamp": "", "hole": false, "budget": "park_large", "routes": ["skylight_chain"], "fragment": ""},
  {"id": "skylight_chain_2", "element": "tunnel", "landform": "lava_tube", "society": "none", "at": [170, -250], "y": -22.3, "size": [141, 10, 20], "yaw_deg": 45, "verb": "launch", "ride_fact": "ride_hop", "home": "", "recipe": "lava_tube_run", "stamp": "", "hole": false, "budget": "park_large", "routes": ["skylight_chain"], "fragment": ""},
  {"id": "skylight_chain_3", "element": "tunnel", "landform": "lava_tube", "society": "none", "at": [140, -175], "y": -30.1, "size": [168, 10, 20], "yaw_deg": -73, "verb": "launch", "ride_fact": "ride_hop", "home": "", "recipe": "lava_tube_run", "stamp": "", "hole": false, "budget": "park_large", "routes": ["skylight_chain"], "fragment": ""},
  {"id": "skylight_chain_4", "element": "tunnel", "landform": "lava_tube", "society": "none", "at": [5, -135], "y": -37.1, "size": [114, 10, 20], "yaw_deg": -75, "verb": "launch", "ride_fact": "ride_hop", "home": "", "recipe": "lava_tube_run", "stamp": "", "hole": false, "budget": "park_large", "routes": ["skylight_chain"], "fragment": ""},
  {"id": "skylight_1", "element": "drop", "landform": "lava_tube", "society": "none", "at": [120, -300], "y": null, "size": [24, 10, 18], "yaw_deg": 59, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:drop", "stamp": "sinkhole", "hole": true, "budget": "park_large", "routes": ["skylight_chain"], "fragment": ""},
  {"id": "skylight_2", "element": "drop", "landform": "lava_tube", "society": "none", "at": [220, -200], "y": null, "size": [24, 10, 18], "yaw_deg": 45, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:drop", "stamp": "sinkhole", "hole": true, "budget": "park_large", "routes": ["skylight_chain"], "fragment": ""},
  {"id": "skylight_3", "element": "drop", "landform": "lava_tube", "society": "none", "at": [60, -150], "y": null, "size": [24, 10, 18], "yaw_deg": -107, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:drop", "stamp": "sinkhole", "hole": true, "budget": "park_large", "routes": ["skylight_chain"], "fragment": ""},
  {"id": "west_gallery_1", "element": "flooded_cavern", "landform": "cenote_pool", "society": "none", "at": [-90, -330], "y": -16.0, "size": [190, 16, 30], "yaw_deg": -72, "verb": "swing", "ride_fact": "ride_drop", "home": "gallery_lamps", "recipe": "cavern_shell", "stamp": "", "hole": false, "budget": "park_large", "routes": ["west_gallery"], "fragment": "lava_cenote_note"},
  {"id": "west_gallery_2", "element": "flooded_cavern", "landform": "cenote_pool", "society": "none", "at": [-240, -240], "y": -27.4, "size": [170, 16, 30], "yaw_deg": -45, "verb": "swing", "ride_fact": "ride_drop", "home": "", "recipe": "cavern_shell", "stamp": "", "hole": false, "budget": "park_large", "routes": ["west_gallery"], "fragment": ""},
  {"id": "west_gallery_3", "element": "flooded_cavern", "landform": "cenote_pool", "society": "none", "at": [-250, -130], "y": -37.3, "size": [141, 16, 30], "yaw_deg": 45, "verb": "swing", "ride_fact": "ride_drop", "home": "", "recipe": "cavern_shell", "stamp": "", "hole": false, "budget": "park_large", "routes": ["west_gallery"], "fragment": ""},
  {"id": "west_gallery_4", "element": "flooded_cavern", "landform": "cenote_pool", "society": "none", "at": [-100, -50], "y": -48.4, "size": [209, 16, 30], "yaw_deg": 73, "verb": "swing", "ride_fact": "ride_drop", "home": "", "recipe": "cavern_shell", "stamp": "", "hole": false, "budget": "park_large", "routes": ["west_gallery"], "fragment": ""},
  {"id": "west_cenote", "element": "flooded_cavern", "landform": "cenote_pool", "society": "none", "at": [-300, -180], "y": -30, "size": [70, 20, 60], "yaw_deg": 0, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "cenote_pool", "stamp": "", "hole": true, "budget": "park_large", "routes": ["west_gallery", "cenote_floor"], "fragment": ""},
  {"id": "east_drift_1", "element": "tunnel", "landform": "adit", "society": "mining", "at": [75, -320], "y": -17.0, "size": [170, 7, 8], "yaw_deg": 62, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "greybox:tunnel", "stamp": "", "hole": false, "budget": "park_large", "routes": ["east_drift"], "fragment": "mining_drift_tally"},
  {"id": "east_drift_2", "element": "tunnel", "landform": "adit", "society": "mining", "at": [165, -200], "y": -30.8, "size": [163, 7, 8], "yaw_deg": 11, "verb": "roll", "ride_fact": "ride_chute", "home": "drift_drill_crews", "recipe": "greybox:tunnel", "stamp": "", "hole": false, "budget": "park_large", "routes": ["east_drift"], "fragment": ""},
  {"id": "east_drift_3", "element": "tunnel", "landform": "adit", "society": "mining", "at": [130, -80], "y": -42.9, "size": [128, 7, 8], "yaw_deg": -51, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "greybox:tunnel", "stamp": "", "hole": false, "budget": "park_large", "routes": ["east_drift"], "fragment": ""},
  {"id": "east_drift_4", "element": "tunnel", "landform": "adit", "society": "mining", "at": [40, -30], "y": -51.6, "size": [82, 7, 8], "yaw_deg": -76, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "greybox:tunnel", "stamp": "", "hole": false, "budget": "park_large", "routes": ["east_drift"], "fragment": ""},
  {"id": "cannon_tube_1", "element": "tunnel", "landform": "lava_tube", "society": "none", "at": [-75, -345], "y": -15.9, "size": [153, 12, 20], "yaw_deg": -79, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "lava_tube_run", "stamp": "", "hole": false, "budget": "park_large", "routes": ["cannon_tube"], "fragment": ""},
  {"id": "cannon_tube_2", "element": "tunnel", "landform": "lava_tube", "society": "none", "at": [-200, -290], "y": -23.1, "size": [128, 12, 20], "yaw_deg": -51, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "lava_tube_run", "stamp": "", "hole": false, "budget": "park_large", "routes": ["cannon_tube"], "fragment": ""},
  {"id": "cannon_tube_3", "element": "tunnel", "landform": "lava_tube", "society": "none", "at": [-225, -200], "y": -29.3, "size": [112, 12, 20], "yaw_deg": 27, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "lava_tube_run", "stamp": "", "hole": false, "budget": "park_large", "routes": ["cannon_tube"], "fragment": ""},
  {"id": "cannon_tube_4", "element": "tunnel", "landform": "lava_tube", "society": "none", "at": [-125, -135], "y": -36.1, "size": [153, 12, 20], "yaw_deg": 79, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "lava_tube_run", "stamp": "", "hole": false, "budget": "park_large", "routes": ["cannon_tube"], "fragment": ""},
  {"id": "machine_vault", "element": "bowl", "landform": "lava_tube", "society": "ancient", "at": [-230, -120], "y": -35, "size": [40, 15, 40], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:bowl", "stamp": "", "hole": false, "budget": "park_large", "routes": ["eruption_lip"], "fragment": "ancient_buried_lens"},
  {"id": "great_room", "element": "bowl", "landform": "lava_tube", "society": "none", "at": [0, -20], "y": -55, "size": [90, 28, 90], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "cavern_shell", "stamp": "", "hole": false, "budget": "park_large", "routes": ["main", "west_gallery", "east_drift", "skylight_chain", "cannon_tube", "east_haulage", "west_breakthrough"], "fragment": ""},
  {"id": "great_room_cap", "element": "drop", "landform": "shaft", "society": "mining", "at": [30, -10], "y": -55, "size": [12, 15, 12], "yaw_deg": 0, "verb": "slam", "ride_fact": "ride_drop", "home": "", "recipe": "shaft_drop", "stamp": "", "hole": true, "budget": "park_large", "routes": ["breach_caps"], "fragment": "mining_cap_stencil"},
  {"id": "upper_tube_cap", "element": "drop", "landform": "shaft", "society": "mining", "at": [-55, -150], "y": -38, "size": [12, 12, 12], "yaw_deg": 0, "verb": "slam", "ride_fact": "ride_drop", "home": "", "recipe": "shaft_drop", "stamp": "", "hole": true, "budget": "park_large", "routes": ["breach_caps"], "fragment": ""},
  {"id": "main_tube_lower_1", "element": "tunnel", "landform": "lava_tube", "society": "none", "at": [-30, 10], "y": -59.2, "size": [85, 14, 24], "yaw_deg": -45, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "lava_tube_run", "stamp": "", "hole": false, "budget": "park_large", "routes": ["main"], "fragment": ""},
  {"id": "main_tube_lower_2", "element": "tunnel", "landform": "lava_tube", "society": "none", "at": [-10, 65], "y": -68.9, "size": [112, 14, 24], "yaw_deg": 63, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "lava_tube_run", "stamp": "", "hole": false, "budget": "park_large", "routes": ["main"], "fragment": ""},
  {"id": "main_tube_lower_3", "element": "tunnel", "landform": "lava_tube", "society": "none", "at": [5, 120], "y": -78.9, "size": [92, 14, 24], "yaw_deg": -49, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "lava_tube_run", "stamp": "", "hole": false, "budget": "park_large", "routes": ["main"], "fragment": ""},
  {"id": "main_tube_lower_4", "element": "tunnel", "landform": "lava_tube", "society": "none", "at": [-5, 175], "y": -86.9, "size": [71, 14, 24], "yaw_deg": 45, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "lava_tube_run", "stamp": "", "hole": false, "budget": "park_large", "routes": ["main"], "fragment": ""},
  {"id": "main_tube_lower_5", "element": "tunnel", "landform": "lava_tube", "society": "none", "at": [10, 248], "y": -95.2, "size": [97, 14, 24], "yaw_deg": -12, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "lava_tube_run", "stamp": "", "hole": false, "budget": "park_large", "routes": ["main"], "fragment": ""},
  {"id": "east_haulage_1", "element": "tunnel", "landform": "adit", "society": "mining", "at": [75, 30], "y": -62.2, "size": [180, 7, 8], "yaw_deg": 56, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:tunnel", "stamp": "", "hole": false, "budget": "park_large", "routes": ["east_haulage"], "fragment": "mining_haulage_rails"},
  {"id": "east_haulage_2", "element": "tunnel", "landform": "adit", "society": "mining", "at": [180, 150], "y": -75.4, "size": [152, 7, 8], "yaw_deg": 23, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:tunnel", "stamp": "", "hole": false, "budget": "park_large", "routes": ["east_haulage"], "fragment": ""},
  {"id": "east_haulage_3", "element": "tunnel", "landform": "adit", "society": "mining", "at": [190, 275], "y": -86.1, "size": [117, 7, 8], "yaw_deg": -20, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:tunnel", "stamp": "", "hole": false, "budget": "park_large", "routes": ["east_haulage"], "fragment": ""},
  {"id": "east_haulage_4", "element": "tunnel", "landform": "adit", "society": "mining", "at": [112, 340], "y": -95.4, "size": [117, 7, 8], "yaw_deg": -80, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:tunnel", "stamp": "", "hole": false, "budget": "park_large", "routes": ["east_haulage"], "fragment": ""},
  {"id": "west_breakthrough_1", "element": "tunnel", "landform": "lava_tube", "society": "none", "at": [-30, 20], "y": -60.1, "size": [100, 12, 20], "yaw_deg": -37, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "lava_tube_run", "stamp": "", "hole": false, "budget": "park_large", "routes": ["west_breakthrough"], "fragment": ""},
  {"id": "west_breakthrough_2", "element": "tunnel", "landform": "lava_tube", "society": "none", "at": [-85, 130], "y": -72.9, "size": [149, 12, 20], "yaw_deg": -20, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "lava_tube_run", "stamp": "", "hole": false, "budget": "park_large", "routes": ["west_breakthrough"], "fragment": ""},
  {"id": "west_breakthrough_3", "element": "tunnel", "landform": "lava_tube", "society": "none", "at": [-119, 250], "y": -85.7, "size": [102, 12, 20], "yaw_deg": -10, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "lava_tube_run", "stamp": "", "hole": false, "budget": "park_large", "routes": ["west_breakthrough"], "fragment": ""},
  {"id": "west_breakthrough_4", "element": "tunnel", "landform": "lava_tube", "society": "none", "at": [-92, 325], "y": -95.5, "size": [88, 12, 20], "yaw_deg": 56, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "lava_tube_run", "stamp": "", "hole": false, "budget": "park_large", "routes": ["west_breakthrough"], "fragment": ""},
  {"id": "west_tube_roof", "element": "ground", "landform": "lava_tube", "society": "none", "at": [-110, 200], "y": null, "size": [70, 0, 40], "yaw_deg": -20, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "", "hole": false, "budget": "landform", "routes": ["plateau_drop"], "fragment": ""},
  {"id": "sinkhole_walls", "element": "drop", "landform": "sinkhole", "society": "none", "at": [0, 350], "y": null, "size": [250, 100, 250], "yaw_deg": 0, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "", "stamp": "sinkhole", "hole": false, "budget": "landform", "routes": ["main", "east_haulage", "west_breakthrough", "rim_line"], "fragment": ""},
  {"id": "gallery_ring", "element": "ledge", "landform": "sinkhole", "society": "mining", "at": [0, 350], "y": -100, "size": [110, 4, 110], "yaw_deg": 0, "verb": "roll", "ride_fact": "ride_ledge", "home": "hive_cells", "recipe": "greybox:ledge", "stamp": "", "hole": false, "budget": "landform", "routes": ["main", "east_haulage", "west_breakthrough", "rim_line", "pump_ramp"], "fragment": "mining_gallery_timber"},
  {"id": "caisson_bowl", "element": "bowl", "landform": "flooded_shaft", "society": "mining", "at": [0, 350], "y": -120, "size": [80, 10, 80], "yaw_deg": 0, "verb": "pump", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:bowl", "stamp": "", "hole": true, "budget": "park_large", "routes": ["main"], "fragment": "mining_pump_caisson"},
  {"id": "pump_gallery", "element": "ledge", "landform": "flooded_shaft", "society": "mining", "at": [50, 350], "y": -100, "size": [20, 10, 30], "yaw_deg": -90, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "greybox:ledge", "stamp": "", "hole": false, "budget": "landform", "routes": ["pump_ramp"], "fragment": "mining_pump_ticket"},
  {"id": "bore_apron", "element": "ground", "landform": "lava_tube", "society": "fleet", "at": [240, 150], "y": null, "size": [60, 0, 40], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "", "hole": false, "budget": "landform", "routes": ["bore_shaft"], "fragment": ""},
  {"id": "west_trench", "element": "half_pipe", "landform": "lava_tube", "society": "none", "at": [-520, -60], "y": null, "size": [320, 14, 40], "yaw_deg": 0, "verb": "pump", "ride_fact": "ride_chute", "home": "", "recipe": "", "stamp": "channel", "hole": false, "budget": "landform", "routes": ["west_loop"], "fragment": ""},
  {"id": "trench_granaries", "element": "elevated_line", "landform": "cliff_dwelling", "society": "ancestral_puebloan", "at": [-545, -60], "y": -8, "size": [180, 6, 10], "yaw_deg": 0, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "cliff_dwelling_row", "stamp": "", "hole": false, "budget": "landform", "routes": ["west_loop"], "fragment": "ref_granary_ledge"},
  {"id": "spatter_field", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [420, -600], "y": null, "size": [300, 18, 260], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "landform", "routes": ["east_loop"], "fragment": ""},
  {"id": "east_mesa", "element": "ledge", "landform": "mesa_rim", "society": "none", "at": [560, 40], "y": null, "size": [360, 40, 280], "yaw_deg": 0, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "mesa_rim_ledge", "stamp": "mesa", "hole": false, "budget": "landform", "routes": ["east_loop"], "fragment": ""},
  {"id": "south_flats", "element": "half_pipe", "landform": "dry_wash", "society": "none", "at": [0, 680], "y": null, "size": [800, 8, 40], "yaw_deg": 90, "verb": "pump", "ride_fact": "ride_chute", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": ["south_loop"], "fragment": ""}
 ],
 "event_rows": [
  {"id": "west_roof_cave_in", "kind": "cave_in", "family": "natural", "site": "west_tube_roof", "trigger": {"on": "clock_tier", "value": 1}, "weight": 1.0, "telegraph": {"lead_s": 6.0, "form": "crust_crack", "on_bar": true}, "live_s": 0.0, "effect": {"depth_m": 12.0, "fill_s": 3.0, "material": "basalt", "swap": "west_collapse_trench"}, "route_change": {"closes": [], "opens": ["plateau_drop"]}, "hold_clear_m": 20.0, "cooldown_s": 0.0, "once": true, "music_cue": {"telegraph": "riser_natural", "land": "drop_cave_in"}},
  {"id": "junction_machine_wakes", "kind": "machine_eruption", "family": "ancient", "site": "machine_vault", "trigger": {"on": "clock_tier", "value": 2}, "weight": 1.0, "telegraph": {"lead_s": 8.0, "form": "ancient_stirring", "on_bar": true}, "live_s": 0.0, "effect": {"miniboss": "swarm_remnant", "swap": "eruption_lip"}, "route_change": {"closes": ["cannon_tube"], "opens": ["eruption_lip"]}, "hold_clear_m": 15.0, "cooldown_s": 0.0, "once": true, "music_cue": {"telegraph": "riser_ancient", "land": "drop_ancient"}},
  {"id": "bore_barge", "kind": "fleet_landing", "family": "fleet", "site": "bore_apron", "trigger": {"on": "clock_tier", "value": 2}, "weight": 1.0, "telegraph": {"lead_s": 10.0, "form": "fleet_inbound", "on_bar": true}, "live_s": 0.0, "effect": {"vessel": "drill_barge", "home": "barge_bore_crew", "footprint_m": [40, 18]}, "route_change": {"closes": [], "opens": ["bore_shaft"]}, "hold_clear_m": 25.0, "cooldown_s": 0.0, "once": true, "music_cue": {"telegraph": "riser_fleet", "land": "drop_fleet"}},
  {"id": "cenote_drain", "kind": "drain", "family": "natural", "site": "west_cenote", "trigger": {"on": "clock_tier", "value": 3}, "weight": 1.0, "telegraph": {"lead_s": 5.0, "form": "drain_gurgle", "on_bar": true}, "live_s": 60.0, "effect": {"depth_m": 1.2, "fill_s": 12.0, "material": "water"}, "route_change": {"closes": [], "opens": ["cenote_floor"]}, "hold_clear_m": 12.0, "cooldown_s": 120.0, "once": false, "music_cue": {"telegraph": "riser_natural", "land": "drop_drain"}},
  {"id": "pump_boiler", "kind": "boiler_burst", "family": "industrial", "site": "pump_gallery", "trigger": {"on": "warden_phase", "value": "chunk_2"}, "weight": 1.0, "telegraph": {"lead_s": 5.0, "form": "boiler_pressure", "on_bar": true}, "live_s": 8.0, "effect": {"hazard": "steam_cone", "hazard_m": [24, 10], "damage": 6.0, "swap": "pump_gallery_ramp"}, "route_change": {"closes": [], "opens": ["pump_ramp"]}, "hold_clear_m": 14.0, "cooldown_s": 0.0, "once": true, "music_cue": {"telegraph": "riser_industrial", "land": "drop_industrial"}}
 ],
 "home_rows": [
  {"id": "cinder_burrowers", "enemy": "burrower", "site": "lava_channel_1", "landform": "lava_tube", "advantage": "Loose black cinder fills the channel floor, so the burrow bulge hides in the grain and every line rides this channel in the first 30 s.", "counter": "The channel is a half-pipe: ride the wall above the committed 2.2 m lane (burrower.gd:10), or slam the marker; the codex burrow_lane pays for the side roll.", "reinforce": {"from_tier": 0, "every_s": 24.0, "max_alive": 3, "pack": "deep_bore"}, "break": {"by": "slam", "hp": 60, "scrap": 12}, "stops_kind": true, "dormant": false},
  {"id": "gallery_lamps", "enemy": "lamp_swarm", "site": "west_gallery_1", "landform": "cenote_pool", "advantage": "The flooded gallery is the darkest place in the park, so the lure bloom is the only light and it bends a slow ball toward the pool edge.", "counter": "Rivet's line sprints the gallery at cruise or faster, which the lure never touches (lamp_swarm.gd:7-9); a cruise ram scatters the lamps.", "reinforce": {"from_tier": 1, "every_s": 22.0, "max_alive": 3, "pack": "deep_lamps"}, "break": {"by": "ram", "hp": 50, "scrap": 10}, "stops_kind": true, "dormant": false},
  {"id": "drift_drill_crews", "enemy": "drill_crew", "site": "east_drift_2", "landform": "adit", "advantage": "The drift is 8 m wide and straight, so a rig leading the ball by 0.8 s (drill_crew.gd:11) puts its 3 m ring dead on the line.", "counter": "The timber sets every 6 m are claw and harpoon anchors: swing over the ring, or smash the rig mid-bore.", "reinforce": {"from_tier": 1, "every_s": 26.0, "max_alive": 2, "pack": "deep_crew"}, "break": {"by": "smash", "hp": 80, "scrap": 14}, "stops_kind": false, "dormant": false},
  {"id": "hive_cells", "enemy": "swarm_remnant", "site": "gallery_ring", "landform": "sinkhole", "advantage": "The brood's outer cells line the gallery ring above the caisson, so drones dive from the ring onto a ball pumping the bowl below.", "counter": "Bowl through a forming rack at speed and the drones follow you; lead them into the lamp guard as pins (codex awaiting_operator).", "reinforce": {"from_tier": 1, "every_s": 30.0, "max_alive": 6, "pack": "swarm_remnant"}, "break": {"by": "smash", "hp": 90, "scrap": 16}, "stops_kind": true, "dormant": false},
  {"id": "barge_bore_crew", "enemy": "drill_crew", "site": "bore_apron", "landform": "lava_tube", "advantage": "The barge bores straight down into the east haulage, so its crew arrives under the plateau ahead of a ball already in the tubes.", "counter": "The bore shaft it opens is a 70 m drop onto the haulage rails; ride it down past the crew, or shoot the mast from the rim.", "reinforce": {"from_tier": 2, "every_s": 30.0, "max_alive": 2, "pack": "deep_crew"}, "break": {"by": "damage", "hp": 150, "scrap": 20}, "stops_kind": true, "dormant": true}
 ],
 "contraption_rows": [
  {"id": "fumarole", "kind": "launcher", "site": "lava_channel_2", "recipe": "geyser_vent", "style": "geyser", "at": [-150, -480], "radius": 3.5, "target": [0, -5.2, -360], "floor": 16.0, "min_flight": 2.2, "charge": 3.0},
  {"id": "cone_thermal", "kind": "thermal", "site": "cinder_cone", "recipe": "", "at": [-320, -705], "radius": 6.0, "height": 70.0},
  {"id": "cave_breath", "kind": "thermal", "site": "skylight_2", "recipe": "", "at": [220, -200], "radius": 5.0, "height": 40.0},
  {"id": "great_room_lift", "kind": "lift", "site": "great_room", "recipe": "lift_platform", "at": [20, -10], "radius": 4.5, "rise": 50.0, "charge": 3.2, "offset": 0.0},
  {"id": "drift_valve", "kind": "valve", "site": "east_drift_2", "recipe": "gauge", "at": [170, -200], "door": {"at": [150, -200], "size": [10, 5, 1], "turn": 1.57}, "vent": null},
  {"id": "sealed_crosscut", "kind": "cracked_wall", "site": "west_breakthrough_1", "recipe": "", "at": [-75, 110], "size": [10, 6, 1.4], "turn": 0.0},
  {"id": "cenote_raft", "kind": "barge", "site": "west_cenote", "recipe": "barge", "a": [-330, -30.6, -200], "b": [-270, -30.6, -160], "size": [14, 1.2, 14], "travel": 6.0, "dwell": 2.0, "offset": 0.0},
  {"id": "rim_zip", "kind": "cable", "site": "sinkhole_walls", "recipe": "", "from": [-110, 3.2, 260], "to": [-48, -97.6, 350], "radius": 3.4, "floor": 18.0}
 ],
 "weather_rows": [
  {"id": "tube_mist", "kind": "cave_mist", "trigger": {"on": "always"}, "lead_s": 0.0, "live_s": 0.0, "gap_s": 0.0, "fog": {"density": 0.004, "color": "#9fb3b8"}, "sky": "clear", "sound": "cave_drip", "music_layer": "drip_keys", "event_odds": {}, "handling": "none"},
  {"id": "afternoon_monsoon", "kind": "monsoon", "trigger": {"on": "clock_tier", "value": 2}, "lead_s": 8.0, "live_s": 45.0, "gap_s": 120.0, "fog": {"density": 0.008, "color": "#6f7d86"}, "sky": "storm_build", "sound": "monsoon_rain", "music_layer": "rain_toms", "event_odds": {"cenote_drain": 0.5}, "handling": "none"}
 ],
 "activity_rows": [
  {"id": "bounty_great_room", "activity": "hauler_bounty", "site": "great_room", "at": [6, -20], "pack": [], "pay": {}},
  {"id": "cenote_camp", "activity": "enemy_camp", "site": "west_cenote", "at": [-300, -170], "pack": ["burrower", "drill_crew", "lamp_swarm"], "pay": {"named": "pylon_capacitor"}},
  {"id": "trench_cache", "activity": "cracked_cache", "site": "west_trench", "at": [-520, -120], "pack": [], "pay": {}}
 ]
}
```
