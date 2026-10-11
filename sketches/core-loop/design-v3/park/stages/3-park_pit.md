# The Dig: the open pit (`park_pit`, stage 3)

Storyboard and table draft for stage 3, the first zone of world 2. Unit K-W2, wave 13, 10 October 2026. Status: **draft for Andrew's click approval** of board `park-3-park_pit`. Nothing here is built. Every number is a starting value to tune in play unless it cites code.

Read with [PARK.md](../../PARK.md) (the tables and bands), [TADR-011](../../../../../adr/TADR-011-park-terrain-and-warden-kinds.md) (the decision) and the Warden kind sheet [wardens/swarm.md](../../wardens/swarm.md). Paths are under `sketches/core-loop/` unless they start with `adr/`, `docs/` or `BIBLE.md`.

Terms used once and kept: a **bench** is one step of the pit (a flat **tread** you roll on and a **face** you drop down); a **winze** is a shaft sunk from one bench to the one below; the **collar** is the mouth of the main shaft on the pit floor; the **tipple** is the headframe platform where the ore cage tips its load; a **waymark** is a point every measured line must pass within 12 m (PARK.md section 8).

## 0. At a glance

| Field | Value |
| --- | --- |
| Stage, world | 3, The Dig (world 2) |
| Map id, display name | `park_pit`, "The Dig: the open pit" (today `dig`, "Dig: the upper bench", `src/core/alpha_defs.gd:81`) |
| Warden | kind `swarm` (the swarm remnant), mounting `headframe`, variant `""` (today reactor with `meltdown`, `alpha_defs.gd:81`, `:90`; KF0 changes it, PARK.md section 7) |
| Time of day | `noon` (fixed) |
| Weather | heat shimmer always; dust devils from clock tier 2 |
| Landmark | the headframe, 120 m tall, on the pit floor at (0, 255) |
| Park | 1.6 km square; an open-pit copper mine 900 m across and 100 m deep in its middle |
| Lines | six pilot lines of 1,571 to 2,059 m, estimated 62 to 69 s; floor line 1,627 m, about 81 s (section 9) |
| Draft size | 28 row families that expand to 33 park rows, 5 events, 4 homes, 8 contraptions, 2 weather rows, 3 activities, 19 routes |

## 1. Landform and society layer

**The Arizona landform.** A copper porphyry open pit, the kind cut at Ray, Morenci and Bisbee: concentric benches stepped into a bowl, a haul road spiralling down the wall, waste-rock dumps and leach-pad terraces on the plateau, and tailings ponds the colour of wet flour. The rock reads in bands: ochre and rust oxides, grey-green host rock, and turquoise streaks of copper carbonate on the faces. Saguaros stand on the west plateau and a slickrock field breaks the south-west corner. That is the "uncanny jungle gym" here: a mine is already a skate park built by machines, so the disguise is honest.

**The pit, in numbers (start).** Centre (0, 175). Five faces at radius 450, 360, 280, 200 and 130 m, each 20 m high, so the treads sit at y 0 (rim), -20, -40, -60, -80 and the floor at -100. Treads are 70 to 90 m wide. That width is two bars of the stage band at a flowing 27 m/s (2 x 1.395 s x 27 = 75 m), so a ball that dives one bench per two bars lands on the downbeat. The floor is 260 m across and the headframe stands near its south edge, so the long north wall is the descent and the short south wall is the backdrop behind the Warden.

**Who shaped it.**

| Society | What they left | Rows | Rule |
| --- | --- | --- | --- |
| `mining` | the pit, the haul road, benches, winzes, adits, the conveyor gallery, tailings, leach pads, the headframe and hoist house | most rows | carries homes and events freely |
| `hohokam` | one canal on the plateau, older than the pit; the haul road bends around it | `canal_lip` | no home, no ground-changing event, `ref_` fragment only (PARK.md section 4) |
| `ancient` | a sealed adit where the miners struck a buried machine | `deep_adit` | the ancient eruption's site |
| `fleet` | nothing at start; a drill barge lands on bench 3 at clock tier 2 | event `bench3_drill_barge` | brings a dormant drill crew home |
| `none` | the arroyo, the saguaro stand, the slickrock, the south wash, the north-east mesa | plateau rows | water and time |

The canal is the one smooth, level line in a park of steps. It is a grind line that every pilot passes, and it is the stage's quiet reference to people who moved water across this desert long before the mine. The haul road visibly detours around it.

## 2. The hero landmark and the Warden's mounting

**The headframe.** A black steel A-frame headframe 120 m tall over the main shaft at (0, 255), with two 14 m sheave wheels at the top, a tipple deck 40 m up (y -60), and a hoist house beside it at (-75, 215). Its top sits at y +20, 20 m above the plain, so it shows over the rim from every plateau cell (`sight_top` [0, 20, 255]). PARK.md's start was 70 m over a 150 m deep pit, which puts the top 80 m below the plain and fails the 85% sight test on every cell outside the pit (about 75% of the park). This draft keeps the pit at 100 m and raises the headframe to 120 m. No ancient beam on this stage: the noon sky is bright and the silhouette carries it.

**The mounting (`headframe`).** The swarm remnant's hive hangs on the hoist rope inside the frame. It rides a 12 s cycle (start): 4 s parked at the collar (low, centre y -96, rammable from the floor), 2 s rising 30 m, 4 s parked high just under the tipple deck (centre y -66), 2 s falling. The two pulses of each cycle land at the end of each dwell. A stagger brakes the hoist and drops the hive to the collar in 1.0 s with its queen cell open for 4 s. The kind sheet ([swarm.md](../../wardens/swarm.md) section 3) holds the full mechanism. The landmark row's `warden.path` is the two dwell points; `reach_m` is 42 so the engage ring is larger than the hive's path.

**Fight floor.** The floor around the collar is a shallow dish 10 m deep (part of the pit row) that a ball pumps for speed between rams. The tipple deck (`tipple_deck`) is the drop-finisher platform; a ball reaches it by riding the hive up, by the sump geyser (`sump_geyser`), by the tipple lift (`tipple_lift`), along the conveyor gallery, or from the hoist house roof after the boiler blows. Without harpoon or contraption, a slam or stomp on the open queen at the collar still finishes (`src/combat/warden.gd:231-235`), so the floor line can win.

**Bay and gates.** Gate slot (60, 280) on the floor, facing +z as today's gates do (`src/world/map_dig.gd:75`). The bay docks at (60, 300), behind and above the gate within the gates' 110 m hold (`src/world/bay.gd:21-23`).

## 3. Region sketch

The 1.6 km square in 200 m cells. North (-z, the drop-in side) is at the top; x runs west to east. `b1` to `b4` are bench treads; `floor` is the pit floor.

```
          A           B           C            D            E            F            G           H
x:      -800        -600        -400         -200           0          200          400         600
1 z-800 dump        DUMP *      .            .            LEACH        LEACH        .           NE MESA
2 z-600 SAGUARO     wash        CANAL        .            leach        leach        launder     .
3 z-400 SAGUARO     canal       canal>RAMP   CACHE b1     zip / rim    rim          launder     .
4 z-200 .           .           haul b1-b2   dive  winzeN skip  b2     CAMP b1      TAILINGS b1 .
5 z   0 .           .           haul b2      winzeW b3    floor        ADIT b3      b2 bank     DAM
                                             ALTAR b3     devil        winzeE       devil
                                             KEST b4      sump/geyser  east dive
6 z 200 SLICKROCK   SLICKROCK   BARGE b3     HOIST floor  HEADFRAME    DEEP ADIT b4 b2          DAM
                                haul b2      haul b3-b4   tipple GATE  b3
                                                          BAY lift
7 z 400 SLICKROCK   .           b1           b2           b2           b1           rim         .
8 z 600 .           .           S WASH       S WASH       S WASH       S WASH       .           .
```

Legend, exact positions (x, z in metres):

| Mark | What | Where |
| --- | --- | --- |
| `*` | drop-in, on the spoil dump top, y +55, heading 15 degrees | (-560, -770) |
| CANAL | `canal_lip`, waymark 2 | (-380, -470) on the canal line |
| RAMP | `rim_haul_ramp`, plateau to bench 1 over the rim | (-300, -330) to (-140, -215) |
| CACHE | `cache_lip`, the cracked cache, waymark 3, 6 m off the line | (-134, -215) |
| HEADFRAME | landmark and Warden, beacon | (0, 255) |
| GATE, BAY | gate slot, bay dock | (60, 280), (60, 300) |
| Homes | tailings burrowers; adit drill crews; winze lamp swarms; barge drill crew (dormant) | (380, -20); (215, 30); (-200, 40); (-230, 200) |
| Contraptions | incline skip (0, -225) to (0, 10); tipple lift (20, 262); sump geyser (-70, 128); rim zip (60, -280) to (150, -60); adit valve (235, 0); sealed portal (185, 240); dust devils (400, -60) and (80, 60) |
| Activities | cracked cache `cache_lip`; enemy camp `switchback_camp_site`; ambush altar `bench4_altar` | (-134, -215); (180, -150); (-170, 60) |
| Rescue | Kest's cage (needs a schema key, section 14) | (-150, 110), bench 4 west, facing +x |

The three activities are signposted from the drop-in: the cache sits on the main line, the camp's smoke rises on the north-east bench in view of the dump top, and the altar is a lit ring on bench 4 seen across the pit (altar lighting follows VX8: no hazard stripes on it, `git show 364e1e6`).

## 4. `park_rows` draft

28 families, 33 rows once the polyline families expand. A family named `x_1..n` is one straight row per segment between the listed points: `at` is the segment midpoint, `size[0]` its length, `yaw_deg` its heading (`atan2(dx, dz)`), and `y` stays null unless given. Recipes are the target ids from PARK.md section 4; during greybox every row carries `greybox:<element>` instead. The appendix holds every row exactly in K1's schema, checked for enums, references and the real-culture rule.

| Row | Element | Landform | Society | Verb / ride fact | Home | Recipe | Stamp | Hole | Budget | Fragment |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `spoil_dump` | drop | tailings_bench | mining | drop / `ride_drop` | - | `tailings_lip` | mesa | - | landform | mining_dump_tally |
| `dump_wash_1..2` | half_pipe | arroyo | none | pump / `ride_chute` | - | `-` | wash | - | landform | - |
| `saguaro_stand` | anchor_field | saguaro_stand | none | swing / `ride_grapple_line` | - | `greybox:anchor_field` | - | - | landform | - |
| `canal_lip` | grind_line | canal | hohokam | grind / `ride_grapple_line` | - | `canal_lip` | channel | - | landform | ref_canal_gradient |
| `rim_haul_ramp` | flow_line | open_pit | mining | roll / `ride_chute` | - | `pit_haul_ramp` | ramp | - | landform | mining_haul_grade |
| `pit` | bowl | open_pit | mining | bank / `ride_bowl` | - | `bench_coping` | terrace | - | landform | mining_bench_survey |
| `haul_road_west_1..5` | flow_line | open_pit | mining | roll / `ride_chute` | - | `pit_haul_ramp` | ramp | - | landform | - |
| `north_dive` | kicker | open_pit | mining | launch / `kicker_launch` | - | `mesa_lip_kicker` | - | - | detail | - |
| `east_dive` | kicker | open_pit | mining | launch / `kicker_launch` | - | `mesa_lip_kicker` | - | - | detail | - |
| `tailings_bench_east` | terrace | tailings_bench | mining | roll / `ride_bowl` | tailings_burrowers | `tailings_lip` | plateau | - | landform | mining_tailings_pond |
| `bench2_east_bank` | bank | open_pit | mining | bank / `ride_bowl` | - | `bench_coping` | - | - | landform | - |
| `adit_east` | tunnel | adit | mining | roll / `ride_chute` | adit_drill_crews | `adit_mouth` | - | yes | park_large | mining_adit_docket |
| `winze_west` | drop | shaft | mining | slam / `ride_drop` | winze_lamps | `shaft_drop` | - | yes | park_large | mining_winze_stencil |
| `winze_north` | drop | shaft | mining | slam / `ride_drop` | - | `shaft_drop` | - | yes | park_large | - |
| `winze_east` | drop | shaft | mining | slam / `ride_drop` | - | `shaft_drop` | - | yes | park_large | - |
| `conveyor_gallery` | rail | pipeline | mining | grind / `ride_grapple_line` | - | `pipeline_rail` | - | - | landform | mining_conveyor_tag |
| `barge_apron` | ground | open_pit | mining | roll / `-` | - | `-` | - | - | landform | - |
| `deep_adit` | tunnel | adit | ancient | roll / `ride_chute` | - | `adit_mouth` | - | yes | park_large | ancient_adit_seal |
| `floor_sump` | bowl | open_pit | mining | pump / `ride_bowl` | - | `-` | bowl | - | landform | mining_sump_gauge |
| `hoist_house` | ledge | headframe | mining | roll / `ride_ledge` | - | `greybox:ledge` | - | - | landform | mining_hoist_boiler |
| `tipple_deck` | ledge | headframe | mining | drop / `ride_drop` | - | `greybox:ledge` | - | - | detail | - |
| `switchback_camp` | ground | open_pit | mining | roll / `-` | - | `-` | - | - | landform | - |
| `leach_pads` | terrace | tailings_bench | mining | pump / `ride_bowl` | - | `tailings_lip` | terrace | - | landform | mining_leach_ticket |
| `mill_launder` | grind_line | flume | mining | grind / `ride_grapple_line` | - | `flume_span` | - | - | landform | mining_launder_note |
| `ne_mesa` | ledge | mesa_rim | none | roll / `ride_ledge` | - | `mesa_rim_ledge` | mesa | - | landform | - |
| `tailings_dam` | bank | tailings_bench | mining | bank / `ride_bowl` | - | `tailings_lip` | mesa | - | landform | - |
| `south_wash` | half_pipe | dry_wash | none | pump / `ride_chute` | - | `-` | wash | - | landform | - |
| `west_slickrock` | bank | slickrock | none | bank / `ride_bowl` | - | `-` | ridge | - | landform | - |

Polylines (x, z): `dump_wash` (-540, -640) to (-500, -540) to (-380, -470); `haul_road_west` (-140, -215), (-260, -110), (-330, 60), (-300, 260), (-150, 330), (-60, 320); `mill_launder` (600, -560) to (470, -310).

**Breach plates become winze caps.** Today's three Dig plates (`map_dig.gd:28-32`) are slam-to-break covers over pits. Here each winze is a capped shaft on a bench tread; a slam breaks the cap and drops the ball 20 m to the bench below through a short adit. That keeps the slam verb and the existing breach tests' meaning. The cap and its `drop_to` need a schema home (section 14).

**Anchors for the 40 m gap rule.** Trolley poles every 35 m along the haul road and the bench 1 and 2 lips are part of the `pit_haul_ramp` and `bench_coping` recipes (start). Saguaros, the canal lip, the conveyor trestles and the headframe legs cover the rest.

**Density gaps for KD3.** The rows above leave the far corners (A1, A8, H3, H7, H8) more than 80 m from any footprint, which `park_density_test.gd` would flag (PARK.md section 8). KD3 fills them with `ground` rows or widens `ne_mesa`, `west_slickrock` and `south_wash`.

## 5. `event_rows` draft

Five rows, all four families. Trigger tiers: tier 1 at 45 s, tier 2 at 90 s (`src/world/director.gd:83-85`, as cited in PARK.md section 5); tiers 3 and 4 need veto item 16 (`MAX_TIME_TIERS` raised to 4).

| Id | Kind, family | Site | Trigger | Telegraph | Effect | Route change | Music |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `tailings_slump` | collapse, natural | `tailings_bench_east` | clock tier 1 | 6 s, `ground_slump` (new form), on bar | the bench 1 to 2 face slumps 20 m into a slide ramp over 4 s; treads stay | opens `tailings_slide` | `riser_natural` / `drop_collapse` |
| `bench3_drill_barge` | fleet_landing, fleet | `barge_apron` | clock tier 2 | 10 s, `fleet_inbound`, on bar | drill barge lands, footprint 40 by 18 m, wakes `barge_drill_crew` | opens `barge_ramp` (its stern ramp is a kicker) | `riser_fleet` / `drop_fleet` |
| `sump_flood` | flood_fill, natural | `floor_sump` | clock tier 2, weight 0.8 | 6 s, `flood_rising`, on bar | sump fills to 1.2 m in 10 s for 40 s | closes `sump_floor` | `riser_natural` / `drop_flood` |
| `deep_adit_wakes` | machine_eruption, ancient | `deep_adit` | clock tier 3 | 8 s, `ancient_stirring`, on bar | a swarm remnant miniboss bursts from the sealed adit; the portal becomes a lip | closes `deep_adit_floor`, opens `eruption_lip` | `riser_ancient` / `drop_ancient` |
| `hoist_boiler` | boiler_burst, industrial | `hoist_house` | Warden phase `chunk_2` | 5 s, `boiler_pressure`, on bar | steam cone 24 by 10 m, 6 damage, 8 s; the roof becomes a ramp aimed at the tipple deck | closes `hoist_yard`, opens `hoist_roof_line` | `riser_industrial` / `drop_industrial` |

**Why these.** A direct run (about 65 s) sees the slump mid-pit at 45 s and the boiler during the fight; the barge, flood and eruption reward roaming. No event footprint touches a measured line: the slump keeps both treads, the barge apron sits 85 m off the floor line, the sump sits 40 m or more from every line, and the deep adit sits 63 m or more from every line (measured from the section 9 waypoints). The boiler is outside the 42 m engage ring (75 m from the collar), so its steam never lands in the fight.

## 6. `home_rows` draft

| Id | Enemy | Site (landform) | Advantage | Counter | Reinforce | Break | Stops kind |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `tailings_burrowers` | burrower | `tailings_bench_east` (tailings_bench) | soft wet tailings swallow the burrow mound, and Rivet's and Tally's lines cross the pond at speed | the pond is flat and pale, so the dark 1.6 m marker (`src/combat/burrower.gd:11`) reads from 40 m; slam it while hidden (`burrower.gd:5-6`) | tier 1, every 20 s, max 4, `dig_shallow` | slam, 60 hp, 12 scrap | yes |
| `adit_drill_crews` | drill_crew | `adit_east` (adit) | the adit opens onto the bench 3 tread the Tarn and Cannon lines dive onto, so the rig's 0.8 s lead ring (`src/combat/drill_crew.gd:11-12`) lands where the ball lands | the adit roof is the bench 2 tread: drop on the rig mid-bore (`src/combat/codex_entries.gd:75-78`) | tier 1, every 25 s, max 2, `dig_bore` | smash, 80 hp, 14 scrap | no (the barge also brings them) |
| `winze_lamps` | lamp_swarm | `winze_west` (shaft) | the winze collar sits in the bench face's noon shadow, so the 9 m lure bloom (`src/combat/lamp_swarm.gd:17`) reads bright and bends a slow ball toward the cap | boost straight through at cruise (`lamp_swarm.gd:7-9`), or slam the cap and drop a bench out of the bloom | tier 0, every 22 s, max 3, `dig_lamps` | ram at tier 2, 50 hp, 10 scrap | yes |
| `barge_drill_crew` | drill_crew | `barge_apron` (open_pit) | the barge deck stands 6 m over bench 3 and its mast bores the haul road below, out of a ram's reach | the stern ramp is a kicker aimed at the mast; ram at tier 2 or shoot the mast | tier 2, every 30 s, max 2, `dig_bore` | damage, 150 hp, 20 scrap | yes; dormant until the barge lands |

Every pack is one of the stage's own (`alpha_defs.gd:86-89`). The elite pack still arrives as the third arrival (`alpha_defs.gd:47-49`).

## 7. `contraption_rows` draft

Spec keys are today's (`src/world/contraptions.gd:86-101`; shapes as in `src/world/map_gorge.gd:345-372`).

| Id | Kind, recipe | Site | Spec (start) | What it is for |
| --- | --- | --- | --- | --- |
| `incline_skip` | barge, `barge` | `pit` | a (0, -20.6, -225) to b (0, -80.6, 10), 14 m deck, travel 9 s, dwell 3 s | the old ore skip down the north wall: a 60 m descent you can ride instead of diving |
| `tipple_lift` | lift, `lift_platform` | `tipple_deck` | at (20, 262), radius 4.5, rise 40, charge 3.2 s | pops a ball onto the tipple deck for the drop finisher |
| `sump_geyser` | launcher (geyser), `geyser_vent` | `floor_sump` | at (-70, 128), target (0, -59.2, 240), floor 16, min flight 2.2 s, charge 3.0 s | a burst dewatering standpipe that throws you onto the tipple deck |
| `rim_zip` | cable, `""` | `pit` | from (60, 3.2, -280) to (150, -57.6, -60), radius 3.4, floor 18 | a 240 m downhill grapple line from the north rim to bench 3 |
| `adit_valve` | valve, `gauge` | `adit_east` | at (235, 0), door at (228, 18), 10 by 5 by 1 m, turn 2.16 | opens the adit's back door: a shortcut from bench 2 to bench 3 |
| `sealed_portal` | cracked_wall, `""` | `deep_adit` | at (185, 240), 12 by 7 by 1.4 m, turn 1.24 | smash the seal before the eruption to see the green seam early |
| `dust_devil_east` | thermal, `""` | `tailings_bench_east` | at (400, -60), radius 5, height 62 | a visible dust devil over hot tailings: a lift lane, never a push |
| `dust_devil_floor` | thermal, `""` | `pit` | at (80, 60), radius 5, height 60 | Kest's lift over the floor bowl |

The dust devils are the weather's dust devils made into marked lanes, as PARK.md section 2.7 asks: wind that moves the ball is always a thermal row, never weather.

## 8. Weather and time of day

**Time: `noon`, fixed.** The sun stands near the top of the sky, so shadows fall short and straight down the bench faces. Each face shows a thin dark band at its foot and the treads stay bright, which makes the steps read as steps from the drop-in. The `world_look.gd` `TIME_ROWS` noon row owns sun height and colour (unit KE7).

| Id | Kind | Trigger | Live | Fog | Sky, sound, layer | Event odds |
| --- | --- | --- | --- | --- | --- | --- |
| `noon_shimmer` | heat_shimmer | always | always | density 0.0015, `#e8d7b0` | clear; `heat_tick` (ticking metal, cicadas); `shimmer_pad` | none |
| `dust_devils` | dust_squall | clock tier 2, lead 6 s | 30 s, gap 90 s | density 0.006, `#c9a36b` | dust; `dust_hiss`; `dust_grit` | `bench3_drill_barge` x1.5 (the Fleet lands under cover of dust) |

Both rows carry `handling: "none"`.

**The Dig lamps veto, kept.** VX8 (`364e1e6`, on Andrew's wave 11 veto list, `design-v3/HANDOFF.md:17`) removed the amber lamp pools and the breach-plate daylight shaft because they read as false telegraphs. This stage adds no light pool, no light shaft and no warm OmniLight3D. Lamp lines on the bench faces keep white, unpooled lenses (`src/presentation/dig_scenery.gd:404-405`). Winze caps carry no light under them. The only coloured light on the floor is a telegraph or the hive's green seams.

## 9. Traversal lines

Every line passes the waymarks `drop_in`, `canal_lip`, `cache_lip`, `landmark` in order. Lengths are measured on the waypoints below. Times assume a mean planar speed per pilot (Sable 27, Rivet 30, Kest 24, Tarn 25, Tally 27, the Cannon 26, the floor line 20 m/s), which is my estimate, not a measurement; the bot measures in KD3. Straight distance from the drop-in to the headframe is 1,168 m. Every line descends or holds level after the rim: a check of each waypoint's bench level found no climb.

| Line | Length | Ratio | Est. time | Segments (s) | Route after the cache |
| --- | --- | --- | --- | --- | --- |
| Sable | 1,677 m | 1.44 | 62.1 s | 14.0 / 13.3 / 34.8 | bench 2 east, east dive kicker, floor |
| Rivet | 2,059 m | 1.76 | 68.6 s | 12.6 / 11.9 / 44.1 | the whole bench 1 contour round the east, through the tailings pond, down the south wall |
| Kest | 1,571 m | 1.35 | 65.5 s | 15.8 / 14.9 / 34.8 | glide from bench 2 west over bench 3, carve the floor bowl |
| Tarn | 1,732 m | 1.48 | 69.3 s | 15.1 / 14.3 / 39.8 | north dive kicker to bench 3, claw round the floor's west |
| Tally | 1,821 m | 1.56 | 67.5 s | 14.0 / 13.3 / 40.2 | surge the bench 2 east contour, down the south-east |
| The Cannon | 1,709 m | 1.46 | 65.7 s | 14.5 / 13.8 / 37.4 | dive to bench 3 east, recoil-carve the floor |
| Floor line | 1,627 m | 1.39 | 81.3 s | 18.9 / 17.9 / 44.5 | the west haul road, no harpoon, no contraption |

**The flow line a skater takes.** Drop off the dump top's 55 m tipping face into the arroyo half-pipe and carve its 36 m walls down to the canal. Ride the canal lip east (bite and grind, or roll its channel), sweep off it onto the rim haul ramp, and crest the rim at the cache with the whole pit opening below. From there each pilot takes a different way down: around the benches, off the bench lips, or down the haul road, and every way ends on the floor bowl at the headframe's foot.

**Tricks it offers each pilot (verbs from the brief).**

| Pilot | Tricks on this stage |
| --- | --- |
| Sable (vault, slingshot) | vault the canal lip's end onto the rim ramp; slingshot round winze east's collar frame onto the east dive kicker; vault the bench 3 tread from the kicker straight to bench 4 |
| Rivet (sprint) | sprint the 440 m near-level bench 1 contour from the switchback camp to the south-east, across the tailings pond, ramming burrowers at tier 2 |
| Kest (glide, rocket jump) | glide from the bench 2 west lip at (-220, -40) over bench 3 (a 40 m drop); rocket-jump off the floor-bowl rim into `dust_devil_floor` for height before the hive |
| Tarn (claw pull) | claw-pull along the adit portal timbers and the conveyor trestles, round the floor's west side, into the hive's low dwell |
| Tally (surge) | surge the bench 2 east bank, a 190 m banked contour; surge down the south-east benches |
| The Cannon (recoil) | recoil off the bench 3 lip to stretch the dive; recoil-turn in the floor bowl to line up a ram at the collar |

**Against PARK.md's bands (estimates).** Time to Warden: every line 62 to 69 s (band 60 to 120 s); Sable and Rivet sit closest to the 60 s floor. Segments: 11.9 to 44.1 s (band 12 to 45 s); Rivet's middle segment (11.9 s) and last segment (44.1 s) are the edge cases. Ratio: 1.35 to 1.76 (band 1.3 to 2.0). Floor line: 81.3 s, 1.23 times the pilot median, inside 2.0. Distinct verbs: every line rides `ride_drop` (dump), `ride_chute` (arroyo, ramp), `ride_bowl` (pit); bite lines add `ride_grapple_line`, dive lines add `kicker_launch`. Peak speed: the 55 m dump drop alone gives about 33 m/s before losses, so the 26.6 m/s blazing tier is reachable in the first 10 s. Airborne share: about 0.15 to 0.25 from the dump face, the kickers and the dives (estimate). Distinct lines: the shared head is 736 m, 36 to 47% of each line, and the arroyo is 36 m wide, so lines that carve opposite walls stay more than 8 m apart; Kest (west), Sable (east bench dive) and Rivet (far east contour) are three mutually distinct lines.

**Draft for `tools/park_lines/park_pit.json`** (every `bar` is the canonical object: the section 8 bands, with this stage's airborne band):

```
{"map": "park_pit", "stage": 3, "pilots": {
  "sable": {"waypoints": ["drop_in", [-540, -640], [-500, -540], "canal_lip", [-300, -330], "cache_lip", [60, -150], [230, -80], [300, -20], [290, 90], [150, 130], [45, 235], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}},
  "rivet": {"waypoints": ["drop_in", [-540, -640], [-500, -540], "canal_lip", [-300, -330], "cache_lip", [100, -215], [300, -140], [420, 20], [390, 210], [230, 350], [70, 330], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}},
  "kest": {"waypoints": ["drop_in", [-540, -640], [-500, -540], "canal_lip", [-300, -330], "cache_lip", [-220, -40], [-150, 90], [0, 40], [110, 110], [120, 165], [40, 230], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}},
  "tarn": {"waypoints": ["drop_in", [-540, -640], [-500, -540], "canal_lip", [-300, -330], "cache_lip", [40, -100], [180, 20], [150, 170], [-120, 150], [-20, 200], [0, 225], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}},
  "tally": {"waypoints": ["drop_in", [-540, -640], [-500, -540], "canal_lip", [-300, -330], "cache_lip", [120, -140], [270, -30], [330, 40], [340, 150], [230, 300], [60, 290], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}},
  "cannon": {"waypoints": ["drop_in", [-540, -640], [-500, -540], "canal_lip", [-300, -330], "cache_lip", [100, -80], [200, 60], [60, 150], [-60, 60], [0, 185], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}}},
 "floor": {"waypoints": ["drop_in", [-540, -640], [-500, -540], "canal_lip", [-300, -330], "cache_lip", [-260, -110], [-330, 60], [-300, 260], [-150, 330], [-60, 320], "landmark"]}}
```

## 10. Music arc

The stage keeps its band: synth theme 1 and the ACE track `dig_upper` (`alpha_defs.gd:81`, `src/presentation/music_rows.gd:10`). Cue ids are the `CUES` table unit KE8 adds; the new ones are named in section 14.

| Where or when | What the music does | Why |
| --- | --- | --- |
| Dump top, the first 3 s | bed only, and a two-knock rim figure with a gap | the Dig crew's rule "knock twice before drilling" (`src/core/lore_rows.gd:140`); the second knock is the downbeat of the drop |
| Dump face | the groove enters on the first landing downbeat | drop-in equals music drop |
| Arroyo and canal | full groove; the canal grind adds one held lead note | the one smooth line gets the one held note |
| Rim haul ramp | a 2-bar riser while you climb nothing and see the rim come up | the pit reveal is the stage's big drop, on the crest |
| Benches | a fill on each kicker launch; landings fall on downbeats (treads are two bars long) | form mirrors function: bench width is tempo |
| Floor | bass forward; the headframe's `landmark_hum` fades in under the band | the landmark has a voice before the fight |
| Warden engaged | the swarm's own G5 buzz plays over the band and locks into the quartal chord D5 G5 C6 F6 on each pulse (`SOUND-STORY.md:60`; kind sheet section 9) | the swarm never enters the band: its chord is its own sound (`SOUND-STORY.md:69`, `280`) |
| Each chunk lost | the locked chord loses its top voice (four chunks, four voices); the boiler's whistle rises into a hit on chunk 2 | progress you can hear |
| Break | the chord breaks into single detuned notes and stops; the band's next downbeat is the drop | the drop lands on the break |
| Events | slump: low sub riser into a dust hit; barge: Brindle's anvil and brass (PARK.md section 5 rule 4); eruption: the buzz rising; flood: a rising filtered pad | one family, one sound |
| Weather layers | `shimmer_pad` always; `dust_grit` while the dust devils live | weather changes the view and the sound, never the handling |

## 11. Codex fragments

Short field notes in the Dig's existing voice (`src/core/lore_rows.gd:114-170`). Ids are new; unit B6 or the KD3 unit adds them to the codex tables.

| Id | Found at | Text (draft) |
| --- | --- | --- |
| `ref_canal_gradient` | `canal_lip` | The canal falls a hand's width every few hundred paces. Water here was taught to arrive slowly. |
| `mining_dump_tally` | `spoil_dump` | Dump tally: forty years of waste rock, one hill. The hill is still settling. Toward the pit. |
| `mining_haul_grade` | `rim_haul_ramp` | Haul road grade: eight in a hundred. Trucks climbed it loaded. Nothing has climbed it since. |
| `mining_bench_survey` | `pit` | Bench survey: five benches, twenty metres each. The sixth was never dug. Chalk marks say otherwise. |
| `mining_tailings_pond` | `tailings_bench_east` | Tailings log: fine grind, wet. Tracks lead onto the pond. None lead off. Burrow count pending. |
| `mining_adit_docket` | `adit_east` | Adit docket: drill crew sent in. Drill crew sent back out. Different crew. |
| `mining_winze_stencil` | `winze_west` | Winze cap stencil: DO NOT SLAM. Someone has scratched out the DO NOT. |
| `mining_conveyor_tag` | `conveyor_gallery` | Belt tag: conveyor stopped, rollers turning. Grease fresh. Nobody on shift. |
| `ancient_adit_seal` | `deep_adit` | Adit 4 sealed at the old lens. The seal is warm. The seam is blue. |
| `mining_sump_gauge` | `floor_sump` | Sump gauge: dry at noon, full by two. No rain logged. |
| `mining_hoist_boiler` | `hoist_house` | Boiler ticket: pressure steady. No fire lit. |
| `mining_leach_ticket` | `leach_pads` | Leach pad ticket: copper drawn off, solution returned. Return volume exceeds issue. |
| `mining_launder_note` | `mill_launder` | Launder note: tailings run downhill to the dam. Some run back. |
| `mining_headframe_cage` | landmark | Hoist log: cage called to the collar 412 times on the night shift. There was no night shift. |

The `ref_` fragment describes the work and the water it managed and speaks for no living people (PARK.md section 4). The existing codex entries this stage teaches stay: `burrow_lane`, `bore_breach`, `lure_bloom` and `awaiting_operator` (`src/combat/codex_entries.gd:59-60`, `69-84`, `162-166`).

## 12. What stays from today's stage

| Kept | Where it lives | Note |
| --- | --- | --- |
| Packs `dig_shallow`, `dig_bore`, `dig_lamps`; elite plated brute and winch drone as the third arrival | `alpha_defs.gd:86-90`, `:47-49` | homes reinforce from these packs only |
| Pressure row 3 (pack 1.20, interval 0.90, elite 1.00, posture 1.05, boss 1.15) | `alpha_defs.gd:59-66` | unchanged |
| Warden plating 130, health 950, posture curve 2.0 x 1.05, `ram_shatters` false, beacon 25 s | `alpha_defs.gd:81-85` | the kind changes, the numbers stay until KF3 re-measures |
| Music theme 1, ACE `dig_upper` | `alpha_defs.gd:81`, `music_rows.gd:10` | the arc in section 10 rides it |
| Kest's rescue on this stage, quest `dig` | `map_dig.gd:84` | moves to (-150, 110); needs a schema key |
| Breach plates as a slam verb | `map_dig.gd:28-32` | become winze caps |
| Camp pay `rivet_plating`, cache, altar | `map_dig.gd:78-82` | the camp pack becomes Dig kinds (veto item 6) |

**Warden band timings.** Today's stage 3 Warden (reactor, meltdown) breaks at a median of 62.67 s over eight seeds (`tools/posture_sweep.md:246`), inside the world 2 band of 24.5 to 128 s (`tests/alpha_posture_bands_w23_test.gd:27`, from `tests/alpha_posture_bands_test.gd:32`). The swarm on the headframe will fight differently, so KF0 re-measures and re-pins stage 3 with a dated header. The kind sheet predicts 60 to 85 s, because the hive spends 8 of every 12 s out of ram reach.

**Tests to re-pin (by name in `tests/`; the KD3 unit greps each for `dig`, the stage number and the plate ids first):** `dig_zone_test.gd`, `dig_rescue_test.gd`, `dig_scenery_test.gd`, `dig_fx_test.gd`, `breach_plate_test.gd`, `breach_attack_test.gd`, `bot_dig_breach_test.gd`, `probe_dig_floor_drop_test.gd`, `alpha_posture_bands_w23_test.gd`, `warden_variants_test.gd`, `warden_meltdown_slag_test.gd`, `run_log_posture_stages_test.gd`. `src/presentation/hero_assets.gd:11-12` mounts the meltdown mantle on stage 3 by stage number and mounts nothing on a family mismatch, so after KF0 the mantle silently disappears; KF8 removes or re-keys the row.

## 13. Storyboard frames

Board id `park-3-park_pit`. PARK.md section 6.1 panels in brackets. The pilot ball, where shown, is the expanded Hoberman-sphere mecha (`docs/decisions.tsv:417`), never an open cage.

1. **Drop-in vista [p2_drop_in].** Behind the ball on the dump top at noon, looking south-south-east. The pit fills the lower two thirds of the frame: five pale treads and dark face bands spiralling down, the haul road a thin ramp on the west wall. On the floor the black headframe rises above the far rim, sheave wheels glinting. Left foreground, the canal's straight line runs across the plateau; right, two dust devils over the pale tailings. Heat shimmer softens the far wall.
2. **First flow line [p3_line].** Low chase camera as the ball drops off the dump's tipping face into the arroyo, then carves high on the left wall. Cinder-red banks, a few saguaros on the lip, the canal lip ahead catching light. The ball is airborne for the first beat, wheels of dust behind it.
3. **An enemy home [p4_home].** Rivet's line across the tailings pond on bench 1 east. Three dark burrow markers on the flat pale surface, one bulging lane committed toward the ball. The bench face behind is streaked with turquoise copper stain; a dust devil stands at the pond's edge.
4. **An event firing [p5_event].** The tailings slump. Panel left: the telegraph, a dust curtain lifting along the bench 1 face and the `ground_slump` form crawling along its foot. Panel right, one bar later: the face has sheared into a smooth slide down to bench 2, and a ball is riding it.
5. **The landmark approach [p3_line, second].** From the east dive kicker on the bench 2 lip, the ball in the air over bench 3 with the headframe filling the right half of frame. Inside the frame the hive hangs low at the collar, green seams lit, a rack of drones forming on the floor between it and the ball.
6. **The Warden fight [p6_warden].** The hive at its high dwell just under the tipple deck. A harpoon line runs from a ringed grip cell down to the ball hanging 25 m above the floor. A file of drones climbs the rope toward the ball: the snip telegraph. Below, the hoist house and the floor dish.
7. **The drop finisher [p6_warden, second].** Stagger. The hive has dropped to the collar, shutters blown open, the queen cell swollen and blazing blue. The ball falls from the tipple deck straight onto it.
8. **The exit.** The bay's hover barge docked over the gate on the pit floor, the headframe dark and still behind it, and the stage launch arc rising out of the pit toward the south-west and the next zone.

## 14. Calls, veto list and open questions

**Calls made under the creative charge (veto list).**

1. The headframe is 120 m and the pit 100 m deep (PARK.md start: 70 m and 150 m), so the landmark's top clears the plain for the 85% sight test.
2. The pit centre sits at (0, 175) with the floor at the south side; the long north wall is the descent.
3. The hoist's low dwell is the contact window and its high dwell is the latch window; the drop finisher comes from the tipple deck at 40 m, because the sheave wheels at 120 m are outside the 45 m rope.
4. Today's breach plates become winze caps: slam to drop one bench.
5. Kest's cage moves to bench 4 west at (-150, 110).
6. The enemy camp fields Dig kinds (burrower, burrower, drill crew), not today's world 1 kinds (`map_dig.gd:79`); the pay stays `rivet_plating`.
7. The Hohokam canal is a grind line the haul road bends around; it hosts nothing hostile and nothing breaks it.
8. No ancient beam on this stage.
9. Bench treads are about two bars wide at flowing speed, so dives land on the downbeat.

**Open questions for K1, KD3 and the coordinator.**

1. The park schema has no field for rescue sites, the vault, the relic spot or breach covers, all of which today's map carries (`map_dig.gd:35-45`, `57`, `84`). Proposal: top-level `rescue_rows` (`{id, quest, prompt, at, face}`), `vault` and `relic_spot` (`[x, z]`), and a `breach` object on `drop` rows (`{drop_to}`).
2. The `terrace` stamp needs a bench schedule: this pit wants faces at radius 450, 360, 280, 200, 130 m, each 20 m. Either a `steps` field on the row or a rule that derives steps from `size[1]` / 20 m.
3. Routes named in an event's `opens` must start closed, or "opens" means nothing. Proposal: `park_map.gd` derives that from the event table.
4. The overlap cap (two ground-changing events live at once) should count only events in their telegraph or landing window; otherwise a permanent change (`live_s` 0) blocks every later one.
5. New telegraph form for KE1: `ground_slump`. New music cue for KE8: `drop_collapse`.
6. `src/combat/miniboss.gd` must run a `swarm_remnant` eruption miniboss; unverified here.
7. Page path: this page lives at `design-v3/park/stages/3-park_pit.md` (PARK.md section 6.1 and the world 1 pages), not at the brief's `design-v3/park/park_pit.md`.

## Appendix: draft park file

Generated from the tables above and checked for enums, id references, home landforms, pack membership, lead floors and the real-culture rule (no failures on this stage). It is the schema-exact form for `src/world/park/park_pit.json`; KD3 replaces target recipes with `greybox:<element>` for the greybox pass.

```json
{
 "schema": "scrapkeep-park/1",
 "map": "park_pit",
 "size_m": 1600,
 "time_of_day": "noon",
 "spawn": {"at": [-560, -770], "heading_deg": 15},
 "play_rect": [-760, -790, 1520, 1580],
 "landmark": {"id": "headframe", "kind": "headframe", "at": [0, 255], "size": [40, 120, 30], "yaw_deg": 180, "recipe": "landmark_headframe", "budget": "hero_landmark", "sight_top": [0, 20, 255], "sight_share": 0.85, "beacon": [0, 255], "reach_m": 42, "warden": {"mounting": "headframe", "anchor": [0, -96, 255], "path": [[0, -96, 255], [0, -66, 255]], "hardpoints": 3}, "bay_dock": {"at": [60, 300], "facing_deg": 0}, "gate_slots": [{"at": [60, 280], "facing_deg": 0}], "light": "", "music": "landmark_hum", "fragment": "mining_headframe_cage"},
 "waymarks": ["drop_in", "canal_lip", "cache_lip", "landmark"],
 "routes": [
  {"id": "main", "from": "drop_in", "to": "landmark", "via": ["spoil_dump", "dump_wash_1", "dump_wash_2", "canal_lip", "rim_haul_ramp", "pit", "haul_road_west_1", "haul_road_west_2", "haul_road_west_3", "haul_road_west_4", "haul_road_west_5"]},
  {"id": "west_swing", "from": "drop_in", "to": "canal_lip", "via": ["saguaro_stand"]},
  {"id": "north_dive", "from": "rim_haul_ramp", "to": "landmark", "via": ["pit", "north_dive", "adit_east"]},
  {"id": "east_benches", "from": "rim_haul_ramp", "to": "landmark", "via": ["pit", "switchback_camp", "tailings_bench_east", "bench2_east_bank"]},
  {"id": "bench_dive", "from": "rim_haul_ramp", "to": "landmark", "via": ["pit", "east_dive"]},
  {"id": "floor_bowl", "from": "pit", "to": "landmark", "via": ["pit", "floor_sump"]},
  {"id": "conveyor_line", "from": "rim_haul_ramp", "to": "landmark", "via": ["conveyor_gallery", "tipple_deck"]},
  {"id": "winze_drops", "from": "pit", "to": "landmark", "via": ["winze_north", "winze_west", "winze_east"]},
  {"id": "sump_floor", "from": "pit", "to": "landmark", "via": ["floor_sump"]},
  {"id": "tailings_slide", "from": "tailings_bench_east", "to": "landmark", "via": ["tailings_bench_east", "pit"]},
  {"id": "barge_ramp", "from": "barge_apron", "to": "landmark", "via": ["barge_apron"]},
  {"id": "deep_adit_floor", "from": "deep_adit", "to": "landmark", "via": ["deep_adit"]},
  {"id": "eruption_lip", "from": "deep_adit", "to": "landmark", "via": ["deep_adit"]},
  {"id": "hoist_yard", "from": "hoist_house", "to": "landmark", "via": ["hoist_house"]},
  {"id": "hoist_roof_line", "from": "hoist_house", "to": "landmark", "via": ["hoist_house", "tipple_deck"]},
  {"id": "north_plateau", "from": "drop_in", "to": "rim_haul_ramp", "via": ["leach_pads", "mill_launder_1", "ne_mesa"]},
  {"id": "east_loop", "from": "tailings_dam", "to": "pit", "via": ["tailings_dam"]},
  {"id": "south_loop", "from": "south_wash", "to": "pit", "via": ["south_wash"]},
  {"id": "west_loop", "from": "west_slickrock", "to": "pit", "via": ["west_slickrock"]}
 ],
 "park_rows": [
  {"id": "spoil_dump", "element": "drop", "landform": "tailings_bench", "society": "mining", "at": [-550, -700], "y": null, "size": [160, 55, 200], "yaw_deg": 9, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "tailings_lip", "stamp": "mesa", "hole": false, "budget": "landform", "routes": ["main"], "fragment": "mining_dump_tally"},
  {"id": "dump_wash_1", "element": "half_pipe", "landform": "arroyo", "society": "none", "at": [-520, -590], "y": null, "size": [108, 10, 36], "yaw_deg": 22, "verb": "pump", "ride_fact": "ride_chute", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": ["main"], "fragment": ""},
  {"id": "dump_wash_2", "element": "half_pipe", "landform": "arroyo", "society": "none", "at": [-440, -505], "y": null, "size": [139, 10, 36], "yaw_deg": 60, "verb": "pump", "ride_fact": "ride_chute", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": ["main"], "fragment": ""},
  {"id": "saguaro_stand", "element": "anchor_field", "landform": "saguaro_stand", "society": "none", "at": [-690, -430], "y": null, "size": [260, 14, 220], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "landform", "routes": ["west_swing"], "fragment": ""},
  {"id": "canal_lip", "element": "grind_line", "landform": "canal", "society": "hohokam", "at": [-360, -430], "y": null, "size": [380, 3, 8], "yaw_deg": 30, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "canal_lip", "stamp": "channel", "hole": false, "budget": "landform", "routes": ["main", "west_swing"], "fragment": "ref_canal_gradient"},
  {"id": "rim_haul_ramp", "element": "flow_line", "landform": "open_pit", "society": "mining", "at": [-220, -272], "y": null, "size": [197, 23, 30], "yaw_deg": 54, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "pit_haul_ramp", "stamp": "ramp", "hole": false, "budget": "landform", "routes": ["main"], "fragment": "mining_haul_grade"},
  {"id": "pit", "element": "bowl", "landform": "open_pit", "society": "mining", "at": [0, 175], "y": null, "size": [900, 100, 900], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "bench_coping", "stamp": "terrace", "hole": false, "budget": "landform", "routes": ["main", "east_benches", "bench_dive", "north_dive", "floor_bowl", "tailings_slide", "sump_floor", "conveyor_line"], "fragment": "mining_bench_survey"},
  {"id": "haul_road_west_1", "element": "flow_line", "landform": "open_pit", "society": "mining", "at": [-200, -162], "y": null, "size": [159, 6, 30], "yaw_deg": -49, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "pit_haul_ramp", "stamp": "ramp", "hole": false, "budget": "landform", "routes": ["main"], "fragment": ""},
  {"id": "haul_road_west_2", "element": "flow_line", "landform": "open_pit", "society": "mining", "at": [-295, -25], "y": null, "size": [184, 6, 30], "yaw_deg": -22, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "pit_haul_ramp", "stamp": "ramp", "hole": false, "budget": "landform", "routes": ["main"], "fragment": ""},
  {"id": "haul_road_west_3", "element": "flow_line", "landform": "open_pit", "society": "mining", "at": [-315, 160], "y": null, "size": [202, 6, 30], "yaw_deg": 9, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "pit_haul_ramp", "stamp": "ramp", "hole": false, "budget": "landform", "routes": ["main"], "fragment": ""},
  {"id": "haul_road_west_4", "element": "flow_line", "landform": "open_pit", "society": "mining", "at": [-225, 295], "y": null, "size": [166, 6, 30], "yaw_deg": 65, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "pit_haul_ramp", "stamp": "ramp", "hole": false, "budget": "landform", "routes": ["main"], "fragment": ""},
  {"id": "haul_road_west_5", "element": "flow_line", "landform": "open_pit", "society": "mining", "at": [-105, 325], "y": null, "size": [91, 6, 30], "yaw_deg": 96, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "pit_haul_ramp", "stamp": "ramp", "hole": false, "budget": "landform", "routes": ["main"], "fragment": ""},
  {"id": "north_dive", "element": "kicker", "landform": "open_pit", "society": "mining", "at": [-80, -177], "y": null, "size": [12, 2.5, 14], "yaw_deg": 57, "verb": "launch", "ride_fact": "kicker_launch", "home": "", "recipe": "mesa_lip_kicker", "stamp": "", "hole": false, "budget": "detail", "routes": ["north_dive"], "fragment": ""},
  {"id": "east_dive", "element": "kicker", "landform": "open_pit", "society": "mining", "at": [269, 96], "y": null, "size": [12, 2.5, 14], "yaw_deg": -74, "verb": "launch", "ride_fact": "kicker_launch", "home": "", "recipe": "mesa_lip_kicker", "stamp": "", "hole": false, "budget": "detail", "routes": ["bench_dive"], "fragment": ""},
  {"id": "tailings_bench_east", "element": "terrace", "landform": "tailings_bench", "society": "mining", "at": [380, -20], "y": null, "size": [200, 4, 120], "yaw_deg": 20, "verb": "roll", "ride_fact": "ride_bowl", "home": "tailings_burrowers", "recipe": "tailings_lip", "stamp": "plateau", "hole": false, "budget": "landform", "routes": ["east_benches", "tailings_slide"], "fragment": "mining_tailings_pond"},
  {"id": "bench2_east_bank", "element": "bank", "landform": "open_pit", "society": "mining", "at": [320, 60], "y": null, "size": [190, 20, 60], "yaw_deg": 21, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "bench_coping", "stamp": "", "hole": false, "budget": "landform", "routes": ["east_benches"], "fragment": ""},
  {"id": "adit_east", "element": "tunnel", "landform": "adit", "society": "mining", "at": [215, 30], "y": -60, "size": [70, 8, 12], "yaw_deg": 124, "verb": "roll", "ride_fact": "ride_chute", "home": "adit_drill_crews", "recipe": "adit_mouth", "stamp": "", "hole": true, "budget": "park_large", "routes": ["north_dive"], "fragment": "mining_adit_docket"},
  {"id": "winze_west", "element": "drop", "landform": "shaft", "society": "mining", "at": [-200, 40], "y": -60, "size": [12, 20, 12], "yaw_deg": 0, "verb": "slam", "ride_fact": "ride_drop", "home": "winze_lamps", "recipe": "shaft_drop", "stamp": "", "hole": true, "budget": "park_large", "routes": ["winze_drops"], "fragment": "mining_winze_stencil"},
  {"id": "winze_north", "element": "drop", "landform": "shaft", "society": "mining", "at": [-40, -120], "y": -40, "size": [12, 20, 12], "yaw_deg": 0, "verb": "slam", "ride_fact": "ride_drop", "home": "", "recipe": "shaft_drop", "stamp": "", "hole": true, "budget": "park_large", "routes": ["winze_drops"], "fragment": ""},
  {"id": "winze_east", "element": "drop", "landform": "shaft", "society": "mining", "at": [250, 0], "y": -40, "size": [12, 20, 12], "yaw_deg": 0, "verb": "slam", "ride_fact": "ride_drop", "home": "", "recipe": "shaft_drop", "stamp": "", "hole": true, "budget": "park_large", "routes": ["winze_drops"], "fragment": ""},
  {"id": "conveyor_gallery", "element": "rail", "landform": "pipeline", "society": "mining", "at": [-165, 49], "y": -30, "size": [517, 60, 6], "yaw_deg": 40, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "pipeline_rail", "stamp": "", "hole": false, "budget": "landform", "routes": ["conveyor_line"], "fragment": "mining_conveyor_tag"},
  {"id": "barge_apron", "element": "ground", "landform": "open_pit", "society": "mining", "at": [-230, 200], "y": null, "size": [60, 0, 40], "yaw_deg": 90, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "", "hole": false, "budget": "landform", "routes": ["barge_ramp"], "fragment": ""},
  {"id": "deep_adit", "element": "tunnel", "landform": "adit", "society": "ancient", "at": [185, 240], "y": -80, "size": [50, 10, 14], "yaw_deg": 71, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "adit_mouth", "stamp": "", "hole": true, "budget": "park_large", "routes": ["deep_adit_floor", "eruption_lip"], "fragment": "ancient_adit_seal"},
  {"id": "floor_sump", "element": "bowl", "landform": "open_pit", "society": "mining", "at": [-90, 120], "y": null, "size": [40, 5, 40], "yaw_deg": 0, "verb": "pump", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "bowl", "hole": false, "budget": "landform", "routes": ["sump_floor", "floor_bowl"], "fragment": "mining_sump_gauge"},
  {"id": "hoist_house", "element": "ledge", "landform": "headframe", "society": "mining", "at": [-75, 215], "y": null, "size": [44, 16, 26], "yaw_deg": -63, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "greybox:ledge", "stamp": "", "hole": false, "budget": "landform", "routes": ["hoist_yard", "hoist_roof_line"], "fragment": "mining_hoist_boiler"},
  {"id": "tipple_deck", "element": "ledge", "landform": "headframe", "society": "mining", "at": [0, 240], "y": -60, "size": [24, 2, 16], "yaw_deg": 180, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:ledge", "stamp": "", "hole": false, "budget": "detail", "routes": ["conveyor_line", "hoist_roof_line"], "fragment": ""},
  {"id": "switchback_camp", "element": "ground", "landform": "open_pit", "society": "mining", "at": [180, -150], "y": null, "size": [60, 0, 50], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "", "hole": false, "budget": "landform", "routes": ["east_benches"], "fragment": ""},
  {"id": "leach_pads", "element": "terrace", "landform": "tailings_bench", "society": "mining", "at": [180, -640], "y": null, "size": [420, 24, 260], "yaw_deg": 90, "verb": "pump", "ride_fact": "ride_bowl", "home": "", "recipe": "tailings_lip", "stamp": "terrace", "hole": false, "budget": "landform", "routes": ["north_plateau"], "fragment": "mining_leach_ticket"},
  {"id": "mill_launder_1", "element": "grind_line", "landform": "flume", "society": "mining", "at": [535, -435], "y": null, "size": [282, 4, 6], "yaw_deg": -27, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "flume_span", "stamp": "", "hole": false, "budget": "landform", "routes": ["north_plateau"], "fragment": "mining_launder_note"},
  {"id": "ne_mesa", "element": "ledge", "landform": "mesa_rim", "society": "none", "at": [650, -700], "y": null, "size": [240, 30, 240], "yaw_deg": 0, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "mesa_rim_ledge", "stamp": "mesa", "hole": false, "budget": "landform", "routes": ["north_plateau"], "fragment": ""},
  {"id": "tailings_dam", "element": "bank", "landform": "tailings_bench", "society": "mining", "at": [640, 150], "y": null, "size": [300, 35, 160], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "tailings_lip", "stamp": "mesa", "hole": false, "budget": "landform", "routes": ["east_loop"], "fragment": ""},
  {"id": "south_wash", "element": "half_pipe", "landform": "dry_wash", "society": "none", "at": [0, 720], "y": null, "size": [700, 8, 40], "yaw_deg": 90, "verb": "pump", "ride_fact": "ride_chute", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": ["south_loop"], "fragment": ""},
  {"id": "west_slickrock", "element": "bank", "landform": "slickrock", "society": "none", "at": [-600, 450], "y": null, "size": [360, 18, 300], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "ridge", "hole": false, "budget": "landform", "routes": ["west_loop"], "fragment": ""}
 ],
 "event_rows": [
  {"id": "tailings_slump", "kind": "collapse", "family": "natural", "site": "tailings_bench_east", "trigger": {"on": "clock_tier", "value": 1}, "weight": 1.0, "telegraph": {"lead_s": 6.0, "form": "ground_slump", "on_bar": true}, "live_s": 0.0, "effect": {"depth_m": 20.0, "fill_s": 4.0, "material": "tailings", "swap": "tailings_slide_ramp"}, "route_change": {"closes": [], "opens": ["tailings_slide"]}, "hold_clear_m": 25.0, "cooldown_s": 0.0, "once": true, "music_cue": {"telegraph": "riser_natural", "land": "drop_collapse"}},
  {"id": "bench3_drill_barge", "kind": "fleet_landing", "family": "fleet", "site": "barge_apron", "trigger": {"on": "clock_tier", "value": 2}, "weight": 1.0, "telegraph": {"lead_s": 10.0, "form": "fleet_inbound", "on_bar": true}, "live_s": 0.0, "effect": {"vessel": "drill_barge", "home": "barge_drill_crew", "footprint_m": [40, 18]}, "route_change": {"closes": [], "opens": ["barge_ramp"]}, "hold_clear_m": 25.0, "cooldown_s": 0.0, "once": true, "music_cue": {"telegraph": "riser_fleet", "land": "drop_fleet"}},
  {"id": "sump_flood", "kind": "flood_fill", "family": "natural", "site": "floor_sump", "trigger": {"on": "clock_tier", "value": 2}, "weight": 0.8, "telegraph": {"lead_s": 6.0, "form": "flood_rising", "on_bar": true}, "live_s": 40.0, "effect": {"depth_m": 1.2, "fill_s": 10.0, "material": "water"}, "route_change": {"closes": ["sump_floor"], "opens": []}, "hold_clear_m": 15.0, "cooldown_s": 90.0, "once": false, "music_cue": {"telegraph": "riser_natural", "land": "drop_flood"}},
  {"id": "deep_adit_wakes", "kind": "machine_eruption", "family": "ancient", "site": "deep_adit", "trigger": {"on": "clock_tier", "value": 3}, "weight": 1.0, "telegraph": {"lead_s": 8.0, "form": "ancient_stirring", "on_bar": true}, "live_s": 0.0, "effect": {"miniboss": "swarm_remnant", "swap": "eruption_lip"}, "route_change": {"closes": ["deep_adit_floor"], "opens": ["eruption_lip"]}, "hold_clear_m": 15.0, "cooldown_s": 0.0, "once": true, "music_cue": {"telegraph": "riser_ancient", "land": "drop_ancient"}},
  {"id": "hoist_boiler", "kind": "boiler_burst", "family": "industrial", "site": "hoist_house", "trigger": {"on": "warden_phase", "value": "chunk_2"}, "weight": 1.0, "telegraph": {"lead_s": 5.0, "form": "boiler_pressure", "on_bar": true}, "live_s": 8.0, "effect": {"hazard": "steam_cone", "hazard_m": [24, 10], "damage": 6.0, "swap": "hoist_house_roof_ramp"}, "route_change": {"closes": ["hoist_yard"], "opens": ["hoist_roof_line"]}, "hold_clear_m": 14.0, "cooldown_s": 0.0, "once": true, "music_cue": {"telegraph": "riser_industrial", "land": "drop_industrial"}}
 ],
 "home_rows": [
  {"id": "tailings_burrowers", "enemy": "burrower", "site": "tailings_bench_east", "landform": "tailings_bench", "advantage": "Soft wet tailings swallow the burrow mound, so only the flat surface marker shows, and Rivet's and Tally's lines cross the pond at speed.", "counter": "The pond is dead flat and pale, so the dark 1.6 m marker reads from 40 m; slam it while hidden (burrower.gd:5-6) or roll off the bulging lane.", "reinforce": {"from_tier": 1, "every_s": 20.0, "max_alive": 4, "pack": "dig_shallow"}, "break": {"by": "slam", "hp": 60, "scrap": 12}, "stops_kind": true, "dormant": false},
  {"id": "adit_drill_crews", "enemy": "drill_crew", "site": "adit_east", "landform": "adit", "advantage": "The adit opens onto the bench 3 tread that the Tarn and Cannon lines dive onto, so a rig bores where a ball coming down the face will land.", "counter": "The adit roof is the bench 2 tread above: drop onto the rig mid-bore and the bore stops (codex bore_breach, codex_entries.gd:75-78).", "reinforce": {"from_tier": 1, "every_s": 25.0, "max_alive": 2, "pack": "dig_bore"}, "break": {"by": "smash", "hp": 80, "scrap": 14}, "stops_kind": false, "dormant": false},
  {"id": "winze_lamps", "enemy": "lamp_swarm", "site": "winze_west", "landform": "shaft", "advantage": "The winze collar sits in the bench face's noon shadow, so the lure bloom reads bright and bends a slow ball toward the capped shaft.", "counter": "Boost straight through at cruise or faster (lamp_swarm.gd:7-9), or slam the cap under them and drop a bench out of the bloom.", "reinforce": {"from_tier": 0, "every_s": 22.0, "max_alive": 3, "pack": "dig_lamps"}, "break": {"by": "ram", "hp": 50, "scrap": 10}, "stops_kind": true, "dormant": false},
  {"id": "barge_drill_crew", "enemy": "drill_crew", "site": "barge_apron", "landform": "open_pit", "advantage": "The barge deck stands 6 m over bench 3 and its drill mast bores the haul road below, out of a ram's reach from the road.", "counter": "The stern ramp the landing drops is a kicker aimed at the mast: ram it at speed tier 2, or shoot the mast.", "reinforce": {"from_tier": 2, "every_s": 30.0, "max_alive": 2, "pack": "dig_bore"}, "break": {"by": "damage", "hp": 150, "scrap": 20}, "stops_kind": true, "dormant": true}
 ],
 "contraption_rows": [
  {"id": "incline_skip", "kind": "barge", "site": "pit", "recipe": "barge", "a": [0, -20.6, -225], "b": [0, -80.6, 10], "size": [14, 1.2, 14], "travel": 9.0, "dwell": 3.0, "offset": 0.0},
  {"id": "tipple_lift", "kind": "lift", "site": "tipple_deck", "recipe": "lift_platform", "at": [20, 262], "radius": 4.5, "rise": 40.0, "charge": 3.2, "offset": 0.0},
  {"id": "sump_geyser", "kind": "launcher", "site": "floor_sump", "recipe": "geyser_vent", "style": "geyser", "at": [-70, 128], "radius": 3.5, "target": [0, -59.2, 240], "floor": 16.0, "min_flight": 2.2, "charge": 3.0},
  {"id": "rim_zip", "kind": "cable", "site": "pit", "recipe": "", "from": [60, 3.2, -280], "to": [150, -57.6, -60], "radius": 3.4, "floor": 18.0},
  {"id": "adit_valve", "kind": "valve", "site": "adit_east", "recipe": "gauge", "at": [235, 0], "door": {"at": [228, 18], "size": [10, 5, 1], "turn": 2.16}, "vent": null},
  {"id": "sealed_portal", "kind": "cracked_wall", "site": "deep_adit", "recipe": "", "at": [185, 240], "size": [12, 7, 1.4], "turn": 1.24},
  {"id": "dust_devil_east", "kind": "thermal", "site": "tailings_bench_east", "recipe": "", "at": [400, -60], "radius": 5.0, "height": 62.0},
  {"id": "dust_devil_floor", "kind": "thermal", "site": "pit", "recipe": "", "at": [80, 60], "radius": 5.0, "height": 60.0}
 ],
 "weather_rows": [
  {"id": "noon_shimmer", "kind": "heat_shimmer", "trigger": {"on": "always"}, "lead_s": 0.0, "live_s": 0.0, "gap_s": 0.0, "fog": {"density": 0.0015, "color": "#e8d7b0"}, "sky": "clear", "sound": "heat_tick", "music_layer": "shimmer_pad", "event_odds": {}, "handling": "none"},
  {"id": "dust_devils", "kind": "dust_squall", "trigger": {"on": "clock_tier", "value": 2}, "lead_s": 6.0, "live_s": 30.0, "gap_s": 90.0, "fog": {"density": 0.006, "color": "#c9a36b"}, "sky": "dust", "sound": "dust_hiss", "music_layer": "dust_grit", "event_odds": {"bench3_drill_barge": 1.5}, "handling": "none"}
 ],
 "activity_rows": [
  {"id": "cache_lip", "activity": "cracked_cache", "site": "pit", "at": [-134, -215], "pack": [], "pay": {}},
  {"id": "switchback_camp_site", "activity": "enemy_camp", "site": "switchback_camp", "at": [180, -150], "pack": ["burrower", "burrower", "drill_crew"], "pay": {"named": "rivet_plating"}},
  {"id": "bench4_altar", "activity": "ambush_altar", "site": "pit", "at": [-170, 60], "pack": [], "pay": {}}
 ]
}
```
