# The Dig: the open pit (`park_pit`, stage 3)

Stage 3, the first zone of world 2. Unit KD3, wave 13. The greybox is built from `src/world/park/park_pit.json`; measurements and acceptance limits are recorded below and in `traversal/park_pit.md`. The storyboard remains a reference for the coordinator's stills and Andrew's visual verdict. Values described as starts or predictions remain unmeasured.

**Status, 2026-10-12:** the merged greybox remains the carried geometry. The dressed candidate `36e3164` failed traversal after two reworks of the arroyo site and is retained in Git history. Sable reached the Warden on 2 of 8 seeds, with 126 dead stops on the worst seed. Other dressed lines and the dressed win proof were not run. This stage is not qualified as dressed. **2026-10-19:** the six remaining greybox rows are now decoration-only liners (section 15). Sable, Rivet and Cannon reach the Warden on 8 of 8 seeds each, but Sable still misses the dead_stops band (an intermittent stop at (-412.3, -536.4), also on the greybox base) and its time_to_warden median sits 0.5 s under the band floor. The stage is not traversal-qualified as dressed.

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
| Lines | Six pilot lines, median paths 1583 to 2034 m and median times 61.78 to 100.94 s; floor line 90.41 s (section 9) |
| Greybox size | 109 park rows, 5 events, 4 homes, 12 contraptions, 2 weather rows, 3 activities, 21 routes |
| After the authored pass (section 15) | 117 park rows (four drifts and four adit portals added), 7 homes (three cut homes added); the rest unchanged |

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
| CANAL | `canal_lip`, waymark 2 | (-356, -501) on the canal line |
| RAMP | `rim_haul_ramp`, plateau to bench 1 over the rim | (-300, -330) to (-140, -215) |
| CACHE | `cache_lip`, the cracked cache, the reward pocket (KD3 fix round: on the north-east rim at the foot of spoil heap 14, off every pilot line; waymark 3 is `switchback_camp`) | (296, -320) |
| HEADFRAME | landmark and Warden, beacon | (0, 255) |
| GATE, BAY | gate slot, bay dock | (60, 280), (60, 300) |
| Homes | tailings burrowers; adit drill crews; winze lamp swarms; barge drill crew (dormant) | (337.5, 110); (292.5, 120); (-337.5, -20); (-337.5, 250) |
| Contraptions | incline skip (0, -225) to (0, 10); tipple lift (20, 262); sump geyser (-70, 128); rim zip (60, -298) to (150, -178); adit valve (94, -374); sealed portal (262.5, 400); dust devils (400, -60) and (-30, 160) |
| Activities | cracked cache `cache_lip`; enemy camp `switchback_camp_site`; ambush altar `bench3_altar` (KD3, was `bench4_altar`) | (296, -320); (180, -160); (-110, -84) |
| Rescue | Kest's cage, `rescue_rows` kest_cage | (-144, 110) on the sump floor at the foot of bench 4 west, facing +x; moved 6 m off the bench wall from the first pick (-150, 110) so the roll-in is flat (park_rescue_test) |

The three activities are signposted from the drop-in: the cache sits on the north-east rim at the foot of a spoil heap, with a clear sight line from the stage line (`park_graph.gd` sight_ok), the camp's smoke rises on the north-east bench in view of the dump top, and the altar is a lit ring on bench 3 north seen across the pit (altar lighting follows VX8: no hazard stripes on it, `git show 364e1e6`).

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
| `haul_road_west_1..4` | flow_line | open_pit | mining | cast / `ride_chute` | cuts 2-4: section 15 | `pit_haul_ramp` | ramp | - | landform | section 15 |
| `haul_road_west_5` | flow_line | open_pit | mining | roll / `ride_chute` | - | `pit_haul_ramp` | ramp | - | landform | - |
| `west_drift_1..4` (section 15) | ground | open_pit | mining | cast / - | - | - | plateau | - | landform | drift 1: mining_drift_chalk |
| `west_adit_1..4` (section 15) | ledge | adit | mining | roll / `ride_ledge` | - | `timber_portal` | - | - | detail | - |
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
| `bench1_haul_lane`, `rim_road_lane_1..2`, `bench2_north_lane`, `bench2_camp_lane` (KD3 fix round) | flow_line | open_pit | mining | roll / `ride_chute` | - | `greybox:flow_line` | - | - | landform | - |

**The haul lanes (KD3 fix round).** Five flat haul lanes, 0.1 m greybox strips 20 to 24 m wide, mark the long tread runs: bench 1 at (-20, -241), the rim road at (-152.5, -316) and (-30, -300), bench 2 north at (0, -168) and bench 2 by the camp at (250, -152). Each fires `ride_chute` on entry. They exist because, once KB9 placed rows at runtime, the KB7b tool's quiet clock ran 21.8 to 29.5 s on the bench 1 run, the rim road and the bench 2 run east, past the 20 s band. The same pass dropped `haul_road_west_5`, `tailings_bench_east` and `bench2_east_bank` from 0.4 m to 0.1 m: the 0.4 m greybox box edge of `bench2_east_bank` stopped the Rivet and Cannon lines dead at (317, -139). In the dressed pass the lanes become the `pit_haul_ramp` haul road surface.

**The canal strip and its saguaros (KD3 fix round).** The `canal_lip` greybox box dropped from 3 m to 0.1 m: as a 3 m slab in the channel it left a step of about 4 m where the second arroyo wash meets the canal, and a Sable seed lost half its speed against it at (-386, -522) (1 of 8 seeds; a 2 m and a 9 m ramp at the junction were tried and made it worse). The slab was also the canal's only harpoon anchor, so a new `canal_saguaros` anchor field (300 by 70 m along the canal, yaw 45, 10 m posts, society none) lines the canal with saguaro posts outside the route lanes, as the S3-A panel already shows saguaros on the lip. The canal row itself keeps `hohokam` and its `ref_` fragment; the posts are a separate row.

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

**Why these.** A direct pilot run (61.78 to 100.94 s measured, section 9) sees the slump mid-pit at 45 s and the boiler during the fight; the barge, flood and eruption reward roaming. Against the shipped lines (KD3 greybox, 2026-10-11): the east-branch lines (Sable, Rivet, the Cannon) ride the `tailings_conveyor` cable straight over `tailings_bench_east`, so the slump fires under them and keeps both treads; the barge apron sits 190 m or more off every line; the Kest line passes 12 m from the `floor_sump` footprint's edge at about 90 s, so `sump_flood` (clock tier 2) can be live as it passes (the 1.2 m pool keeps planar speed, PARK.md section 4); the deep adit sits 150 m or more from every line. `deep_adit_wakes` waits for clock tier 3, which needs veto item 16 (`MAX_TIME_TIERS` 4); on this head it does not fire inside a measured run. The boiler is outside the 42 m engage ring (75 m from the collar), so its steam never lands in the fight.

## 6. `home_rows` draft

| Id | Enemy | Site (landform) | Advantage | Counter | Reinforce | Break | Stops kind |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `tailings_burrowers` | burrower | `tailings_bench_east` (tailings_bench) | soft wet tailings swallow the burrow mound, and Rivet's and Tally's lines cross the pond at speed | the pond is flat and pale, so the dark 1.6 m marker (`src/combat/burrower.gd:11`) reads from 40 m; slam it while hidden (`burrower.gd:5-6`) | tier 1, every 20 s, max 4, `dig_shallow` | slam, 60 hp, 12 scrap | yes |
| `adit_drill_crews` | drill_crew | `adit_east` (adit) | the adit opens onto the bench 3 tread the Tarn and Cannon lines dive onto, so the rig's 0.8 s lead ring (`src/combat/drill_crew.gd:11-12`) lands where the ball lands | the adit roof is the bench 2 tread: drop on the rig mid-bore (`src/combat/codex_entries.gd:75-78`) | tier 1, every 25 s, max 2, `dig_bore` | smash, 80 hp, 14 scrap | no (the barge also brings them) |
| `winze_lamps` | lamp_swarm | `winze_west` (shaft) | the winze collar sits in the bench face's noon shadow, so the 9 m lure bloom (`src/combat/lamp_swarm.gd:17`) reads bright and bends a slow ball toward the cap | boost straight through at cruise (`lamp_swarm.gd:7-9`), or slam the cap and drop a bench out of the bloom | tier 0, every 22 s, max 3, `dig_lamps` | ram at tier 2, 50 hp, 10 scrap | yes |
| `barge_drill_crew` | drill_crew | `barge_apron` (open_pit) | the barge deck stands 6 m over bench 3 and its mast bores the haul road below, out of a ram's reach | the stern ramp is a kicker aimed at the mast; ram at tier 2 or shoot the mast | tier 2, every 30 s, max 2, `dig_bore` | damage, 150 hp, 20 scrap | yes; dormant until the barge lands |

The authored pass (section 15) adds three cut homes, `powder_cut_lamps` (lamp_swarm, `dig_lamps`), `barge_cut_burrowers` (burrower, `dig_shallow`) and `collar_cut_rigs` (drill_crew, `dig_bore`); their advantage and counter text is in `park_pit.json`. Every pack is one of the stage's own (`alpha_defs.gd:86-89`). The elite pack still arrives as the third arrival (`alpha_defs.gd:47-49`).

## 7. `contraption_rows` draft

Spec keys are today's (`src/world/contraptions.gd:86-101`; shapes as in `src/world/map_gorge.gd:345-372`).

| Id | Kind, recipe | Site | Spec (start) | What it is for |
| --- | --- | --- | --- | --- |
| `incline_skip` | barge, `barge` | `pit` | a (0, -19.4, -225) to b (0, -99.4, 100), 14 m deck, travel 9 s, dwell 3 s | the old ore skip down the north wall: an 80 m descent you can ride instead of diving |
| `tipple_lift` | lift, `lift_platform` | `tipple_deck` | at (20, 262), radius 4.5, rise 40, charge 3.2 s | pops a ball onto the tipple deck for the drop finisher |
| `sump_geyser` | launcher (geyser), `geyser_vent` | `floor_sump` | at (-70, 128), target (0, -59.2, 240), floor 16, min flight 2.2 s, charge 3.0 s | a burst dewatering standpipe that throws you onto the tipple deck |
| `rim_zip` | cable, `""` | `pit` | from (60, 1.5, -298) to (150, -37.5, -178), radius 6, floor 22 | the rim road's downhill grapple line over bench 1 to the camp on bench 2 (the Rivet and Tally lines) |
| `tailings_conveyor` | cable, `""` | `tailings_bench_east` | from (337, -38.5, -40) to (337, -37.5, 110), radius 6, floor 22 | the bench 2 east conveyor: a 150 m grapple line over the tailings pond, near level (its landing end sits 1 m above its start, for the 2.35 m end clearance) (the east branch) |
| `bench2_haul_cable` | cable, `""` | `pit` | from (60, -38.5, -150) to (-90, -37.5, -150), radius 6, floor 22 | the bench 2 north haul cable west from the camp (the Kest line) |
| `skip_cable` | cable, `""` | `pit` | from (175, -38.5, -125) to (120, -77.5, 25), radius 6, floor 22 | a skip cable from the camp down over bench 3 to bench 4 (the Tarn and Tally lines) |
| `west_winze_cable` | cable, `""` | `pit` | from (-150, -58.5, -25) to (-100, -97.5, 170), radius 6, floor 22 | the Kest line's second west cable, over bench 4 to the floor |
| `adit_valve` | valve, `gauge` | `adit_back_door` | at (94, -374), door at (88, -368), 10 by 5 by 1 m, turn 2.16 | the hidden pocket: opens the adit's back door on the north rim; its tell is the `back_door_portal` row, an 8 by 6 m timbered portal 18 m behind the gauge |
| `sealed_portal` | cracked_wall, `""` | `deep_adit` | at (262.5, 400), 12 by 7 by 1.4 m, turn 1.24 | decorative: smash the seal before the eruption to see the green seam early; 70 m off the eruption site (R3) |
| `dust_devil_east` | thermal, `""` | `tailings_bench_east` | at (400, -60), radius 5, height 62 | a visible dust devil over hot tailings: a lift lane, never a push |
| `dust_devil_floor` | thermal, `""` | `pit` | at (-30, 160), radius 12, height 60 | Kest's lift on the floor, on his line from the west winze cable to the collar (only a gliding ball rides a thermal, `contraptions.gd:251-253`; at radius 5 a ball at cruise left the column before the glide engaged and no `thermal_ride` fired, so the fix round widened it to 12) |

**Why five cables (KD3).** The greybox pass was cut on a head where the runtime placed no recipe row, so each pilot line rides at least one cable and drops a bench by a kicker lip. Since KB9 (in the fix-round base) a park stage places every row that names a recipe at runtime, and its ride sensor fires on entry (`park_recipes.gd` `_sensor`): the fix-round runs show `ride_chute` (the washes, the haul road), `ride_bowl` (the east bank, the tailings terrace, the collar dish) and `thermal_ride` (Kest) besides the cables and kickers. A row without a recipe is a terrain stamp only and fires nothing. Every bench drop a line takes has a kicker row whose lip sits on the crest, and 60 m crest windrows (3 m safety berms, a real haul-road feature) either side of a 50 m gap, so the harpoon always has a face within its 45 m reach.

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

Measured, KD3 greybox on the merged candidate (2026-10-12), `tools/traversal_line.gd --table=park --stage=3`, 8 seeds per line; the full 13-band table is `design-v3/park/traversal/park_pit.md`. Every line passes the waymarks `drop_in`, `canal_lip`, `switchback_camp`, `landmark` in order. Waymark 3 is the enemy camp's ground row (`switchback_camp`, R2), not the cache: the cache moved off the line to keep its PARK.md 2.12 reward detour (section 14). Straight distance from the drop-in to the engage centre is about 1,170 m.

The lines are three heads and three tails. The shared start is the dump face, the two arroyo washes and the canal. The heads:

- **A, bench 1.** Down the rim haul ramp onto bench 1 and east along it, 30 to 40 m below the rim face, then from (95, -228) the `camp_dive` kicker lip, yawed 51 degrees, onto bench 2 at the camp heading east-north-east along the tread.
- **B, the rim road.** East along the rim road behind its crest berm, then the `rim_zip` cable over bench 1 down to the camp.
- **C, the north dive.** Down the ramp, the `north_dive` kicker lip onto bench 2 west, then east along bench 2 to the camp.

The tails:

- **E, the east benches.** East along bench 2, the `tailings_conveyor` cable down bench 2 east over the tailings pond, then the `east_dive`, `east_dive_2` and `east_dive_3` kicker lips to the floor.
- **S, the skip.** The `skip_cable` from the camp over bench 3 to bench 4, then the `floor_dive` lip to the floor.
- **W, the west winze.** The `bench2_haul_cable` west along bench 2, the `west_dive` lip to bench 3, then the `west_winze_cable` over bench 4 to the floor's west side, and across the floor through `dust_devil_floor` at (-30, 160), which lifts a gliding ball, to the collar. The line's last waypoint before the fix round, (-60, 205), ran into the `hoist_house` box once KB9 placed it (three dead stops at (-39, 181) on the first fix-round run, against an ore pile beside the thermal's first place); the line now passes (-45, 163) and (-15, 157), straight through the thermal's centre.

Greybox measured on the merged candidate, 2026-10-12, before the failed dressing attempt. Eight seeds per completed line; floor flow share is reported only under kd-common-r.md item 4. Full band and worst-seed values are in `traversal/park_pit.md`.

| Line | Head + tail | Time to Warden, median (s) | Segments, medians (s) | Ratio | Ride facts, KB7b set |
| --- | --- | --- | --- | --- | --- |
| Sable | A + E | 61.78 | 13.81 / 20.96 / 27.23 | 1.740 | 4 |
| Rivet | B + E | 100.94 | 18.80 / 38.20 / 43.97 | 1.640 | 4 |
| Kest | A + W | 96.75 | 18.45 / 36.44 / 42.06 | 1.720 | 5 |
| Tarn | C + S | 74.95 | 17.46 / 35.50 / 21.94 | 1.440 | 4 |
| Tally | B + S | 79.72 | 19.45 / 36.72 / 23.75 | 1.355 | 4 |
| The Cannon | C + E | 97.64 | 18.12 / 39.06 / 40.59 | 1.710 | 4 |
| Floor line | A + the S dives, no cable | 90.41 | 19.53 / 39.41 / 31.59 | 1.450 | 4 |

**Greybox distinct lines.** Rivet, Kest and Tarn are pairwise distinct on all eight current traces: every directed share of ticks within 8 m of any point in the other 3D trace is below 0.50. The largest share is 0.4742, Tarn against Kest on seed 6. The comparison uses exact spatial bins, with all neighboring bins searched; the full 24-row receipt is in `traversal/park_pit.md`. This establishes the required three distinct lines across the six pilots.

**Why the berms, windrows and ore piles.** They were cut when the runtime placed no recipe row, so the harpoon's anchors were stamped steep faces only (section 7); they stay, because the stamped rows (no recipe) are still terrain only. The rows that keep every line inside the 40 m anchor band are these:

- `dump_berm_east` and `dump_berm_west`, the haul-road safety berms beside the dump.
- `wash_berm`, `rim_road_berm` and `haul_ramp_berm`.
- The crest windrows either side of each kicker gap.
- `bench3_west_berm` and `bench4_ore_bin`.
- `camp_ore_bin` (fix round), a 10 m greybox ore bin 14 m tall on bench 1 at (160, -218), beside the camp dive. Sable's flight off the dive runs about 45 m at bench 1 height with no face in reach (anchor gap 40.7 to 46.7 m on three seeds before it, 23 to 30 m after).
- Six ore piles on the floor: `ore_pile_east`, `_mid`, `_north`, `_west`, `_sw` and `_nw`.

Look versus function: the ground's concrete tint skips the footprints of the six berm rows (`dump_berm_east`, `dump_berm_west`, `rim_road_berm`, `haul_ramp_berm`, `wash_berm` and `bench3_west_berm`, each padded 2 m; `PylonBite.BERM_ROWS`), so they keep their landform colour, yet a ball at their foot still bites their flanks (101 of 108 flank and foot samples in the probe posted on #241 6345448625). The tint under-reports them by design, and the padded footprints also untint 51 vertices on the pit rim's top edge where `dump_berm_east`'s end and `haul_ramp_berm` meet it (coordinator 6342820238 item 3, 6345347272 item 4, NEEDS 6350588099).

Two pieces of geometry were moved to clear dead stops. The canal channel is 16 m wide, so the arroyo's 40 degree turn into it does not stop a ball against the far wall. The camp dive's east windrow starts 60 m east of the lip, clear of Sable's overshoot. The fix round moved four more pieces for the same reason, once KB9 made kickers solid wedges: the camp dive (section 14 call 8) and the three east dives, now 30 to 40 m wide.

**Tricks it offers each pilot.** Unchanged in intent from the draft. Sable vaults the camp dive lip at 45 m/s and lands on bench 2 beside the camp. Rivet sprints the rim road to the zip. Kest rides two cables in a row down the west side, then glides up `dust_devil_floor` on the floor for height before the collar. Tarn and Tally take the skip cable down two benches at once. The Cannon recoils off the east dives.

**Draft for `assets/park/park_pit/lines.json`.** This block is the shipped file; every `bar` is the canonical object, PARK.md section 8 with this stage's airborne band of 0.12 to 0.45.

```
{"map": "park_pit", "stage": 3, "pilots": {
  "sable": {"waypoints": ["drop_in", [-498, -540], [-433, -522], "canal_lip", [-235, -380], [-240, -330], [-232, -262], [-150, -242], [40, -240], [95, -228], "switchback_camp", [300, -150], [345, -125], [337, -40], [337, 110], [322, 130], [290, 135], [240, 148], [210, 155], [165, 168], [135, 175], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}},
  "rivet": {"waypoints": ["drop_in", [-498, -540], [-433, -522], "canal_lip", [-235, -380], [-195, -372], [-175, -330], [-130, -302], [-20, -300], [60, -298], [150, -178], "switchback_camp", [300, -150], [345, -125], [337, -40], [337, 110], [322, 130], [290, 135], [240, 148], [210, 155], [165, 168], [135, 175], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}},
  "kest": {"waypoints": ["drop_in", [-498, -540], [-433, -522], "canal_lip", [-235, -380], [-240, -330], [-232, -262], [-150, -242], [40, -240], [95, -228], "switchback_camp", [100, -150], [60, -150], [-90, -150], [-140, -140], [-158, -125], [-160, -90], [-155, -55], [-150, -25], [-100, 170], [-45, 163], [-15, 157], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}},
  "tarn": {"waypoints": ["drop_in", [-498, -540], [-433, -522], "canal_lip", [-235, -380], [-240, -330], [-232, -262], [-160, -232], [-150, -210], [-150, -176], [-100, -168], [100, -168], "switchback_camp", [175, -125], [120, 25], [85, 45], [70, 55], [70, 80], [35, 167], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}},
  "tally": {"waypoints": ["drop_in", [-498, -540], [-433, -522], "canal_lip", [-235, -380], [-195, -372], [-175, -330], [-130, -302], [-20, -300], [60, -298], [150, -178], "switchback_camp", [175, -125], [120, 25], [85, 45], [70, 55], [70, 80], [35, 167], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}},
  "cannon": {"waypoints": ["drop_in", [-498, -540], [-433, -522], "canal_lip", [-235, -380], [-240, -330], [-232, -262], [-160, -232], [-150, -210], [-150, -176], [-100, -168], [100, -168], "switchback_camp", [300, -150], [345, -125], [337, -40], [337, 110], [322, 130], [290, 135], [240, 148], [210, 155], [165, 168], [135, 175], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}}
 },
 "floor": {"waypoints": ["drop_in", [-498, -540], [-433, -522], "canal_lip", [-235, -380], [-240, -330], [-232, -262], [-150, -242], [40, -240], [95, -228], "switchback_camp", [195, -130], [205, -118], [205, -90], [115, -35], [110, -28], [110, -5], [75, 45], [70, 55], [70, 80], [35, 167], "landmark"]}}
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
| `ancient_adit_seal` | `deep_adit` | Adit 4 sealed at the old lens. The seal is warm. The seam is green. |
| `mining_sump_gauge` | `floor_sump` | Sump gauge: dry at noon, full by two. No rain logged. |
| `mining_hoist_boiler` | `hoist_house` | Boiler ticket: pressure steady. No fire lit. |
| `mining_leach_ticket` | `leach_pads` | Leach pad ticket: copper drawn off, solution returned. Return volume exceeds issue. |
| `mining_launder_note` | `mill_launder` | Launder note: tailings run downhill to the dam. Some run back. |
| `mining_headframe_cage` | landmark | Hoist log: cage called to the collar 412 times on the night shift. There was no night shift. |
| `mining_top_cut` | `haul_road_west_1` | Top cut: forty wide, twenty deep. Trucks passed two abreast. Mirrors bolted to both walls. The mirrors face the wall. |
| `mining_powder_cut` | `haul_road_west_2` | Powder cut: charges kept in the west adit, lamps kept well clear of it. The lamps have moved closer. |
| `mining_barge_cut` | `haul_road_west_3` | Barge cut: spoil tipped off the barge straight into the cut. Floor stays soft for weeks. Something keeps it soft. |
| `mining_collar_cut` | `haul_road_west_4` | Collar cut: last grade to the floor. Rigs parked nose to the wall at shift end. By morning they face the road. |
| `mining_drift_chalk` | `west_drift_1` | Drift chalk: one drift holed through per cut, four in all. Count them on the way down. Five on the way up. |

The `ref_` fragment describes the work and the water it managed and speaks for no living people (PARK.md section 4). The existing codex entries this stage teaches stay: `burrow_lane`, `bore_breach`, `lure_bloom` and `awaiting_operator` (`src/combat/codex_entries.gd:59-60`, `69-84`, `162-166`).

## 12. What stays from today's stage

| Kept | Where it lives | Note |
| --- | --- | --- |
| Packs `dig_shallow`, `dig_bore`, `dig_lamps`; elite plated brute and winch drone as the third arrival | `alpha_defs.gd:86-90`, `:47-49` | homes reinforce from these packs only |
| Pressure row 3 (pack 1.20, interval 0.90, elite 1.00, posture 1.05, boss 1.15) | `alpha_defs.gd:59-66` | unchanged |
| Warden plating 130, health 950, posture curve 2.0 x 1.05, `ram_shatters` false, beacon 25 s | `alpha_defs.gd:81-85` | the kind changes, the numbers stay until KF3 re-measures |
| Music theme 1, ACE `dig_upper` | `alpha_defs.gd:81`, `music_rows.gd:10` | the arc in section 10 rides it |
| Kest's rescue on this stage, quest `dig` | `map_dig.gd:84` | moves to (-144, 110) as `rescue_rows` kest_cage |
| Breach plates as a slam verb | `map_dig.gd:28-32` | become winze caps |
| Camp pay `rivet_plating`, cache, altar | `map_dig.gd:78-82` | the camp pack becomes Dig kinds (veto item 6) |

**Warden band timings.** Today's stage 3 Warden (reactor, meltdown) breaks at a median of 62.67 s over eight seeds (`tools/posture_sweep.md:246`), inside the world 2 band of 24.5 to 128 s (`tests/alpha_posture_bands_w23_test.gd:27`, from `tests/alpha_posture_bands_test.gd:32`). The swarm on the headframe will fight differently, so KF0 re-measures and re-pins stage 3 with a dated header. The kind sheet predicts 60 to 85 s, because the hive spends 8 of every 12 s out of ram reach.

**Tests to re-pin (by name in `tests/`; the KD3 unit greps each for `dig`, the stage number and the plate ids first):** `dig_zone_test.gd`, `dig_rescue_test.gd`, `dig_scenery_test.gd`, `dig_fx_test.gd`, `breach_plate_test.gd`, `breach_attack_test.gd`, `bot_dig_breach_test.gd`, `probe_dig_floor_drop_test.gd`, `alpha_posture_bands_w23_test.gd`, `warden_variants_test.gd`, `warden_meltdown_slag_test.gd`, `run_log_posture_stages_test.gd`. `src/presentation/hero_assets.gd:11-12` mounts the meltdown mantle on stage 3 by stage number and mounts nothing on a family mismatch, so after KF0 the mantle silently disappears; KF8 removes or re-keys the row.

## 13. Storyboard frames

Board id `park-3-park_pit`. PARK.md section 6.1 panels in brackets. The pilot ball, where shown, is the expanded Hoberman-sphere mecha (`docs/decisions.tsv:417`), never an open cage.

1. **Drop-in vista [p2_drop_in].** Behind the ball on the dump top at noon, looking south-south-east. The pit fills the lower two thirds of the frame: five pale treads and dark face bands spiralling down, the haul road a thin ramp on the west wall. On the floor the black headframe rises above the far rim, sheave wheels glinting. Left foreground, the canal's straight line runs across the plateau; right, two dust devils over the pale tailings. Heat shimmer softens the far wall.
2. **First flow line [p3_line].** Low chase camera as the ball drops off the dump's tipping face into the arroyo, then carves high on the left wall. Cinder-red banks, a few saguaros on the lip, the canal lip ahead catching light. The ball is airborne for the first beat, wheels of dust behind it.
3. **An enemy home [p4_home].** Rivet's line on the `tailings_conveyor` cable across the tailings pond on bench 2 east. Three dark burrow markers on the flat pale surface, one bulging lane committed toward the ball. The bench face behind is streaked with turquoise copper stain; a dust devil stands at the pond's edge.
4. **An event firing [p5_event].** The tailings slump. Panel left: the telegraph, a dust curtain lifting along the bench 1 face and the `ground_slump` form crawling along its foot. Panel right, one bar later: the face has sheared into a smooth slide down to bench 2, and a ball is riding it.
5. **The landmark approach [p3_line, second].** From the `east_dive` kicker on the bench 2 east lip at (307, 130), between its two crest windrows, the ball in the air over bench 3 with the headframe filling the right half of frame. Inside the frame the hive hangs low at the collar, green seams lit, a rack of drones forming on the floor between it and the ball.
6. **The Warden fight [p6_warden].** The hive at its high dwell just under the tipple deck. A harpoon line runs from a ringed grip cell down to the ball hanging 25 m above the floor. A file of drones climbs the rope toward the ball: the snip telegraph. Below, the hoist house and the floor dish.
7. **The drop finisher [p6_warden, second].** Stagger. The hive has dropped to the collar, shutters blown open, the queen cell swollen and blazing green. The ball falls from the tipple deck straight onto it.
8. **The exit.** The bay's hover barge docked over the gate on the pit floor, the headframe dark and still behind it, and the stage launch arc rising out of the pit toward the south-west and the next zone.

## Dressed attempt, 2026-10-12

The native-family attempt replaced 38 greybox or empty recipes and added a second flume tile. It used piece bounds, separate macro terrain stamps, an aligned canal exit, open shaft mouths and a camp-flight silo. The eight-file smoke passed on `36e3164`. Traversal failed at the first arroyo liner and canal entrance, so the branch carries the original passing greybox geometry. The attempted source, bake, graph and lines remain at `36e3164`; these failed measurements are not measurements of the carried file.

| Pilot | Seeds | Reached Warden | Dead stops, median / worst | Time to engage, median | Status |
| --- | --- | --- | --- | --- | --- |
| Sable | 8 | 2 / 8 | 117.5 / 126 | 65.565 s among completed seeds | MISS |
| Rivet | Not run | Not measured | Not measured | Not measured | NOT QUALIFIED |
| Kest | Not run | Not measured | Not measured | Not measured | NOT QUALIFIED |
| Tarn | Not run | Not measured | Not measured | Not measured | NOT QUALIFIED |
| Tally | Not run | Not measured | Not measured | Not measured | NOT QUALIFIED |
| The Cannon | Not run | Not measured | Not measured | Not measured | NOT QUALIFIED |
| Floor line | Not run | Not measured | Not measured | Not measured | NOT QUALIFIED |

The first absolute-y seating cleared the incoming flight but disconnected the graph. The second, a 3.5 m bed cut, reconnected the graph but restored the wall collisions. The first liner stops the ball near (-492, -527); the canal stops it near (-384, -508). The complete band table is the second section of `traversal/park_pit.md`.

The attempted heaviest-view inventory counted 108 explicit mesh surfaces and 116,744 triangles. These are headless proxies, excluding Terrain3D clipmaps, renderer-generated geometry and occlusion. They are not rendered draw calls, rendered triangles or p99 performance. The three stills remain a coordinator capture plan. No visual or human-feel verdict is claimed.

## 14. Calls, veto list and open questions

**KD3 greybox calls (2026-10-11), measured on the bake and graph (`assets/park/park_pit/graph.json`).**

1. **Waymark 3 is `switchback_camp`.** It is the camp's ground row; R2 lets the on-line camp sit on a waymark.
2. **The cache moved off the line, then off every pilot line (fix round).** `cache_lip` is at (296, -320) on the north-east rim at the foot of spoil heap 14 (site `spoil_heap_14`), a rare-only reward with a graph detour of 241 m (door_m 241, sight_ok yes, d_spawn 1,063 m, d_landmark 716 m, 228 m from the valve door). Its first place, (312, -16) on bench 2 east, sat 25 m from the east branch's conveyor cable, so half the pilot lines passed it for nothing; now the nearest pilot-line point is 225 m away by graph path (a probe that seeds a graph search from every pilot and floor waypoint segment) and about 170 m in a straight line (Sable's (300, -150)). Reaching it is a choice: leave the rim road or the camp east along the rim. Beat 6's "smash the cache on the way past" no longer holds (journey amendment).
3. **The altar moved and was renamed.** `bench4_altar` became `bench3_altar` at (-110, -84) on bench 3 north, a risk with a detour of 216 m, inside PARK.md 2.12 and smaller than the reward's.
4. **The valve moved to the north rim.** `adit_valve` sits on `adit_back_door` at (88, -368), the hidden pocket. Its tell is the `back_door_portal` row, plus the gauge.
5. **`sealed_portal` moved off the eruption site.** It is at (262.5, 400), decorative (R3).
6. **`eruption_lip` has its own kicker row (R6).**
7. **`deep_adit_wakes` waits for clock tier 3.** That needs veto item 16.
8. **Fix round (2026-10-11, on the KB9 and KB7b head).** Five 0.1 m haul lanes added and three 0.4 m greybox strips lowered to 0.1 m (section 4); `dust_devil_floor` moved from (80, 100) to (-30, 160) onto the Kest line and widened to radius 12 (section 7); the Kest line re-cut through it and clear of `hoist_house`; `cache_lip` moved to (296, -320) on `spoil_heap_14` (call 2). With the kickers now physical wedges, two more geometry calls: `camp_dive` moved from (163.5, -196.4) at yaw 24.8 to (134, -197) at yaw 51, with `camp_dive_windrow_2` shifted west to (85, -197.4) and a new 30 m `camp_dive_windrow_3` at (175, -198) and the `camp_ore_bin` box at (160, -218) for the harpoon (section 9). Head A now reaches it from (95, -228). The old north-north-east launch threw Sable at 45 m/s across the whole bench 2 tread and off the `bench3_dive` lip to bench 3, where 2 of 8 seeds stalled under the camp. And `east_dive`, `east_dive_3` (30 m wide) and `east_dive_2` (40 m wide, centred at (232, 133), with `east_dive_2_windrow_2` shifted to (233, 83) to meet it) were widened from 14 m, because a ball landing off `east_dive` clipped the side of the 14 m wedge at (232, 142), and later the 40 m wedge's edge at (236, 125), and lost half its speed. And the `canal_lip` slab went to 0.1 m with a `canal_saguaros` anchor field beside it (section 4). The bake and graph were rebuilt; `park_graph.gd` reports no breach.
9. **`beacon_ok` is NO on this head (reported, not gated by any test in the stage list).** The SR15 objective-fit check (`tools/park_graph.gd` `beacon_check`, from KB8 round two) wants every node of a 42 m disc round the beacon open and within 2.5 m of its height. The collar dish (a 10 m bowl stamp, 70 m across) and the `tipple_deck` ledge sit inside that disc by design: the dish is the swarm's floor and the deck is the drop finisher. Clearing it is a mounting and fight-floor change, which is the coordinator's and KF8's call, so it is listed as a follow-up, not changed here. **Settled 2026-10-17 (authored pass):** `beacon_check` now reads a headframe mounting's own floor. When the Warden mounts on the headframe, the rows the landmark GLB dresses (`collar_dish`, `tipple_deck`, `hoist_house`, recipe `landmark`) are the fight floor: their nodes are exempt from the 2.5 m rise (the dish is a bowl by design), nodes under the deck and the hoist house roof are not counted as closed, and their tops are not counted as decks. Every other disc node is still checked. The headframe GLB now carries the tipple deck plate and the hoist house (`tools/blender/park/landmarks.py`), so those two rows stopped drawing grey boxes. Result: `beacon_ok` yes, 89 disc nodes, 0 closed. A planted park with greybox deck and hoist rows fails the check (`tests/park_park_pit_test.gd`). The tool hash changed, so every park's `graph.json` must be regenerated after its bake.

The anchor and ride-fact rows of sections 7 and 9 are new. These draft gaps stay open, because no row or line change closes them:

- the cage's schema home (Kest's rescue);
- the terrace schedule;
- the lure bloom's measured pull;
- the gate arches panel;
- tier 3 firing (veto item 16);
- `sump_flood` against `sump_geyser` (both on `floor_sump`; the geyser is not on a measured line).

`rim_zip`'s landing is now the camp on bench 2, so it needs no landing row. Density is closed: `park_density_test` is green on this file.

**Calls made under the creative charge (veto list).**

1. The headframe is 120 m and the pit 100 m deep (PARK.md start: 70 m and 150 m), so the landmark's top clears the plain for the 85% sight test.
2. The pit centre sits at (0, 175) with the floor at the south side; the long north wall is the descent.
3. The hoist's low dwell is the contact window and its high dwell is the latch window; the drop finisher comes from the tipple deck at 40 m, because the sheave wheels at 120 m are outside the 45 m rope.
4. Today's breach plates become winze caps: slam to drop one bench.
5. Kest's cage moves to the sump floor at the foot of bench 4 west, (-144, 110).
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

## 15. Authored pass, 2026-10-17: the West Workings

**The skill.** Andrew's ruling (one skill per park, relayed 22:15Z 17 Oct): the pit tests **abilities in close quarters**. The landforms stay. Enemy placement and the jungle-gym lines change so the pit reads as that test. The Dig's world theme is Plate: armour shrugs hits and is weak to abilities. The drill crew's plate takes the first breaking hit whole (`drill_crew.gd:5-6`).

**What was wrong.** The west haul road (`haul_road_west_1` to `_4`) was four dead-end slots. Each ramp cut 40 m wide into its bench tread and fell 20 m. But its foot sat 17.5 m short of the next bench's edge, so a ball reached the bottom of a 20 m pit with walls on three sides (measured on the bake: the foot cell at -40, -60, -80 or -100, the strip beyond it still at the bench above). The `main` and `west_swing` routes named a road no ball could use, and no pilot line went there. The quiet west side was a third of the pit with nothing to do.

**What it is now.** The four slots are the pit's ability gauntlet, rim to floor:

| Cut | Bench | Drift (row, centre, cut 20 m) | Who waits there | Why a cast beats a ram |
| --- | --- | --- | --- | --- |
| Top cut, `haul_road_west_1` | 1 to 2 | `west_drift_1`, (-384, -24) | nobody: the first cut teaches the slot. The winze lamps bloom at its exit (`winze_lamps`) | the slot is 40 m wide with 20 m walls, so a ball cannot swing wide |
| Powder cut, `haul_road_west_2` | 2 to 3 | `west_drift_2`, (-309, 136) | `powder_cut_lamps`: two lamp swarms and a plated drill crew (`dig_lamps`) | the walls hold the lure bloom in a box, and there is no run-up to reach the cruise that boosts through |
| Barge cut, `haul_road_west_3` | 3 to 4 | `west_drift_3`, (-234, 292) | `barge_cut_burrowers` (`dig_shallow`) | there is one line down the slot, and the mound is on it |
| Collar cut, `haul_road_west_4` | 4 to floor | `west_drift_4`, (-159, 184) | `collar_cut_rigs`: a plated drill crew with a burrower and a prop crew (`dig_bore`) | the plate shrugs the ram a 40 m run can build. Pop it with a cast first |

Each drift is a `ground` row with a `plateau` stamp of -20 over the bench strip between the cut's foot and the next bench. It opens the foot flush onto the lower bench: on the bake the drift cells sit at the lower bench height with no lip. The drift runs 46 m along the cut (50 m at the barge cut). It opens the bottom 38 to 42 m of the cut's side, where the cut floor stands up to 6 m over the drift as a step down, and runs 6 m past the cut's end wall as run-out. So a ball can leave the slot sideways before the end wall. The slot keeps its other wall and its upper two thirds. The first skill-line ride, with 16 m drifts at the very foot, dead-stopped Sable against all four end walls. 30 m drifts still caught Sable and Tarn on the corner where the drift met the cut wall. Each cut has an old adit in its west wall (`west_adit_1` to `_4`, `timber_portal` GLB, the mouth on the cut floor and the headwall flush with the wall). That is where the cut's crew comes from. The cuts and drifts carry the new park verb `cast` (PARK.md 2.2: a place the skill bar clears, not the ball).

**Enemy placement elsewhere.** The risk pocket stays `bench3_altar`, because PARK.md 2.12 wants it within the reward's 241 m detour of a pilot line and every west cut is 360 m or more from one (measured: a hauler bounty at the head of the top cut had a 367 m detour). Its ambush now draws Dig plate, two drill crews and a lamp swarm, instead of the rule's default chasers. The row's `pack` reaches the altar because `activities.gd` now applies an authored pack to `ambush_altar` the way it does for the relay (`tests/activities_pay_test.gd` pins it, with the empty-pack default). No other park authors an altar pack. The camp keeps its burrowers and a drill crew. Kest's cage on the floor (`kest_cage`, (-144, 110)) sits 70 m from the collar cut's drift: the demolitions caster is rescued at the foot of the ability gauntlet.

**The skill line.** `assets/park/park_pit/skill_line.json` holds one line for all six pilots: drop_in, the canal, the rim haul ramp, west along bench 1, then down all four cuts and through all four drifts to the floor, joining Kest's final approach to the landmark. It skips `switchback_camp`, because the camp is the east side's on-line pocket. Ride it with `tools/traversal_line.gd -- --table=park --stage=3 --pilot=<p> --lines=res://assets/park/park_pit/skill_line.json`. `tests/park_park_pit_test.gd` pins that it resolves, and that every cut and drift holds one of its waypoints. It is a separate file, so `lines.json`, the graph's line nodes and every pocket distance stay as they were. So the six measured pilot lines still ride the east side and none enters a cut: the gauntlet is the west route a player chooses, and the skill line is its proof.

**What the skill line does and does not pass.** Every pilot reaches the Warden on every seed (merged-tree receipts in `artifacts/local/pitpass/skillm/`). It is an end-to-end ride, not a stage-band line: on all six pilots the longest gap between anchors is about 60 m against the band's 40 m, it rides two ride facts against three, and one segment runs 50 to 68 s against 45 s. Those are the cost of four slots in a row with nothing to swing from inside them, which is the test. Sable still dead-stops once on half its seeds at (-322, 149), the south end-wall corner of the powder cut beside `west_drift_2`. Seeds come in identical pairs on this line, so four seeds are two distinct traces.

**Berms and windrows.** The 25 low plateau berms and crest windrows (3 to 4 m tall) carry the verb `swing`. Their recorded job is the harpoon's anchor faces (section 7 and the berm list in section 9), not banking. The 22 rim domes (`slickrock_N`, `spoil_heap_N`) stay as density fill (the KD3 density gaps, section 4). The brief keeps the landforms.

**Art swapped in this pass (placeholder unit D).** The `pit_haul_lane` GLB (a level 40 m haul-road tile, `tools/blender/park/bowls.py`) replaced four greybox haul lanes: seat fit on the 53 m and 60 m rim lanes (`rim_road_lane_1`, `_2`), tile fit on `bench1_haul_lane` and `bench2_north_lane`. The tile has a 1.4 m windrow on one side and a 3.8 m cut bank on the other, so it only fits where lines run along it: on `bench2_camp_lane` and `bench2_east_bank` the Sable, Rivet and Cannon lines cross its edge and dead-stopped there (9 of their 12 seeds), so those two stay 0.1 m greybox until a curbless lane exists. `haul_road_west_5` stays greybox too: tiled across the floor, its cut bank ran into the hoist house and stopped every skill-line pilot there. The nine kickers now seat the PR #95 plate kickers (`plate_kicker_12x2p5x14`, `_x30` on `east_dive` and `east_dive_3`, `_x40` on `east_dive_2`). `camp_ore_bin` now uses `ore_bin`, and `back_door_portal` uses `timber_portal` (`tools/blender/park/workings.py`). `mill_launder` and `conveyor_gallery` are each split in two and seat `flume_span` and `pipeline_rail`. `floor_sump` and `tailings_bench_east` are dressed by the scatter, `collar_dish`, `tipple_deck` and `hoist_house` by the landmark. Still greybox: `bench2_camp_lane`, `bench2_east_bank`, `haul_road_west_5`, `dump_wash_1` and `_2`, and `canal_lip`. The dressed attempt of 2026-10-12 failed traversal at those last three, so they stay greybox here.

**Last six rows dressed (wave 18, dress unit).** `dump_wash_1` and `_2`, `canal_lip`, `haul_road_west_5`, `bench2_camp_lane` and `bench2_east_bank` now draw bake-conformed liners (`liner_<row id>`, `tools/blender/park/flume_works.py --pit`, the flume's liner method over `assets/park/park_pit/ground.bin`): decoration only, no `-col`, the stamped terrain stays the only collider, so no collider edge or slab stands in these lanes, which is what failed the 2026-10-12 attempt. For the three unstamped rows (`haul_road_west_5`, `bench2_camp_lane`, `bench2_east_bank`) the physical ground did change: they used to place a 0.1 m box collider over the footprint (`place_greybox`), and those slabs are gone. The Sable, Rivet and Cannon lines that cross them were re-measured (`design-v3/park/traversal/park_pit.md`, 2026-10-19). No `fit`: each is placed rigidly at the row's `at` and yaw, so a moved row needs a liner rebuild. The washes wear banded sandstone over the baked half-pipe; the haul rows a graded gravel surface with two rut bands and soft cobble verges (at most 0.10 m); the canal an earthen lip and silt floor, left out where the second arroyo wash cuts it and where the mound at its west end rises (0.35 m off the canal's level), so no lining bridges a cut. Pit greybox rows: 0.

## Appendix: draft park file

Generated from the tables above and checked for enums, id references, home landforms, pack membership, lead floors and the real-culture rule (no failures on this stage). It is the schema-exact form for `src/world/park/park_pit.json`; KD3 replaces target recipes with `greybox:<element>` for the greybox pass. **Shipped (KD3 greybox, 2026-10-11; re-synced in the fix round):** the block below was the shipped `src/world/park/park_pit.json`, so the page's park file and its section 9 lines agree; the original draft is in git history (`5f2139b`). Since the authored pass (section 15) `src/world/park/park_pit.json` is the source of truth and this block is the fix-round snapshot.

```json
{
 "schema": "scrapkeep-park/1",
 "map": "park_pit",
 "size_m": 1600,
 "time_of_day": "noon",
 "spawn": {"at": [-560, -770], "heading_deg": 15.0},
 "play_rect": [-780, -790, 1560, 1580],
 "landmark": {"id": "headframe", "kind": "headframe", "at": [0, 255], "size": [40, 120, 30], "yaw_deg": 180, "recipe": "landmark_headframe", "budget": "hero_landmark", "sight_top": [0, 20, 255], "sight_share": 0.85, "beacon": [0, 255], "reach_m": 42, "warden": {"mounting": "headframe", "anchor": [0, -96, 255], "path": [[0, -96, 255], [0, -66, 255]], "hardpoints": 3, "family": "swarm", "harpoon_anchor": true}, "bay_dock": {"at": [60, 300], "facing_deg": 0}, "gate_slots": [{"at": [60, 280], "facing_deg": 0}], "light": "", "music": "landmark_hum", "fragment": "mining_headframe_cage"},
 "waymarks": ["drop_in", "canal_lip", "switchback_camp", "landmark"],
 "routes": [
  {"id": "main", "from": "drop_in", "to": "landmark", "via": ["spoil_dump", "dump_wash_1", "dump_wash_2", "canal_lip", "rim_haul_ramp", "pit", "haul_road_west_1", "haul_road_west_2", "haul_road_west_3", "haul_road_west_4", "haul_road_west_5", "collar_dish", "gate_apron"]},
  {"id": "west_swing", "from": "drop_in", "to": "landmark", "via": ["spoil_dump", "saguaro_stand", "canal_lip", "rim_haul_ramp", "pit", "haul_road_west_1", "haul_road_west_2", "haul_road_west_3", "haul_road_west_4", "haul_road_west_5", "collar_dish", "gate_apron"]},
  {"id": "north_dive", "from": "rim_haul_ramp", "to": "landmark", "via": ["pit", "north_dive", "winze_north", "switchback_camp", "bench4_dive", "collar_dish"]},
  {"id": "east_benches", "from": "rim_haul_ramp", "to": "landmark", "via": ["adit_back_door", "pit", "switchback_camp", "tailings_bench_east", "east_dive", "collar_dish"]},
  {"id": "bench_dive", "from": "rim_haul_ramp", "to": "landmark", "via": ["adit_back_door", "pit", "winze_east", "bench2_east_bank", "adit_east", "collar_dish"]},
  {"id": "rim_zip_line", "from": "rim_haul_ramp", "to": "landmark", "via": ["adit_back_door", "pit", "collar_dish"]},
  {"id": "conveyor_line", "from": "rim_haul_ramp", "to": "landmark", "via": ["pit", "conveyor_gallery", "collar_dish", "tipple_deck"]},
  {"id": "floor_bowl", "from": "rim_haul_ramp", "to": "landmark", "via": ["pit", "floor_sump", "collar_dish"]},
  {"id": "side_7a_winze", "from": "pit", "to": "collar_dish", "via": ["winze_north", "winze_west", "barge_apron"]},
  {"id": "side_7a_east", "from": "pit", "to": "collar_dish", "via": ["winze_east", "adit_east", "deep_adit"]},
  {"id": "sump_floor", "from": "pit", "to": "landmark", "via": ["floor_sump"]},
  {"id": "tailings_slide", "from": "tailings_bench_east", "to": "landmark", "via": ["tailings_bench_east", "pit"]},
  {"id": "barge_ramp", "from": "barge_apron", "to": "landmark", "via": ["barge_apron"]},
  {"id": "deep_adit_floor", "from": "deep_adit", "to": "landmark", "via": ["deep_adit"]},
  {"id": "eruption_lip", "from": "deep_adit", "to": "landmark", "via": ["deep_adit", "eruption_lip", "collar_dish"]},
  {"id": "hoist_yard", "from": "hoist_house", "to": "landmark", "via": ["hoist_house"]},
  {"id": "hoist_roof_line", "from": "hoist_house", "to": "landmark", "via": ["hoist_house", "tipple_deck"]},
  {"id": "north_plateau", "from": "drop_in", "to": "rim_haul_ramp", "via": ["leach_pads", "mill_launder_1", "ne_mesa"]},
  {"id": "east_loop", "from": "tailings_dam", "to": "pit", "via": ["tailings_dam"]},
  {"id": "south_loop", "from": "south_wash", "to": "pit", "via": ["south_wash"]},
  {"id": "west_loop", "from": "west_slickrock", "to": "pit", "via": ["west_slickrock"]}
 ],
 "park_rows": [
  {"id": "spoil_dump", "element": "drop", "landform": "tailings_bench", "society": "mining", "at": [-532.0, -665.7], "y": null, "size": [260.0, 55, 120], "yaw_deg": 15.0, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "", "stamp": "ramp", "hole": false, "budget": "landform", "routes": ["main", "west_swing"], "fragment": "mining_dump_tally"},
  {"id": "dump_wash_1", "element": "half_pipe", "landform": "arroyo", "society": "none", "at": [-465.7, -531.2], "y": null, "size": [67.8, 10, 36], "yaw_deg": 74.8, "verb": "pump", "ride_fact": "ride_chute", "home": "", "recipe": "greybox:half_pipe", "stamp": "wash", "hole": false, "budget": "landform", "routes": ["main"], "fragment": ""},
  {"id": "dump_wash_2", "element": "half_pipe", "landform": "arroyo", "society": "none", "at": [-402.3, -519.4], "y": null, "size": [61.7, 10, 36], "yaw_deg": 84.6, "verb": "pump", "ride_fact": "ride_chute", "home": "", "recipe": "greybox:half_pipe", "stamp": "wash", "hole": false, "budget": "landform", "routes": ["main"], "fragment": ""},
  {"id": "saguaro_stand", "element": "anchor_field", "landform": "saguaro_stand", "society": "none", "at": [-600, -400], "y": null, "size": [200, 2, 160], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "landform", "routes": ["west_swing"], "fragment": ""},
  {"id": "canal_lip", "element": "grind_line", "landform": "canal", "society": "hohokam", "at": [-356, -501], "y": null, "size": [300.0, 0.1, 16], "yaw_deg": 45.0, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "channel", "hole": false, "budget": "landform", "routes": ["main", "west_swing"], "fragment": "ref_canal_gradient"},
  {"id": "rim_haul_ramp", "element": "flow_line", "landform": "open_pit", "society": "mining", "at": [-240, -330], "y": null, "size": [110, -20, 30], "yaw_deg": 180, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "", "stamp": "ramp", "hole": false, "budget": "landform", "routes": ["main", "west_swing", "north_dive", "east_benches", "bench_dive", "rim_zip_line", "conveyor_line", "floor_bowl", "north_plateau"], "fragment": "mining_haul_grade"},
  {"id": "pit", "element": "bowl", "landform": "open_pit", "society": "mining", "at": [0, 175], "y": null, "size": [900, 20, 900], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "terrace", "hole": false, "budget": "landform", "routes": ["main", "west_swing", "north_dive", "east_benches", "bench_dive", "rim_zip_line", "conveyor_line", "floor_bowl", "side_7a_winze", "side_7a_east", "sump_floor", "tailings_slide", "east_loop", "south_loop", "west_loop"], "fragment": "mining_bench_survey"},
  {"id": "pit_bench_2", "element": "terrace", "landform": "open_pit", "society": "mining", "at": [0, 185], "y": null, "size": [750, -20, 750], "yaw_deg": 0, "verb": "roll", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "pit_bench_3", "element": "terrace", "landform": "open_pit", "society": "mining", "at": [0, 195], "y": null, "size": [600, -20, 600], "yaw_deg": 0, "verb": "roll", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "pit_bench_4", "element": "terrace", "landform": "open_pit", "society": "mining", "at": [0, 205], "y": null, "size": [450, -20, 450], "yaw_deg": 0, "verb": "roll", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "pit_floor", "element": "terrace", "landform": "open_pit", "society": "mining", "at": [0, 215], "y": null, "size": [300, -20, 300], "yaw_deg": 0, "verb": "roll", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "haul_road_west_1", "element": "flow_line", "landform": "open_pit", "society": "mining", "at": [-412.5, -80.0], "y": null, "size": [140, -20, 40], "yaw_deg": 180, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "", "stamp": "ramp", "hole": false, "budget": "landform", "routes": ["main", "west_swing"], "fragment": ""},
  {"id": "haul_road_west_2", "element": "flow_line", "landform": "open_pit", "society": "mining", "at": [-337.5, 80.0], "y": null, "size": [140, -20, 40], "yaw_deg": 180, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "", "stamp": "ramp", "hole": false, "budget": "landform", "routes": ["main", "west_swing"], "fragment": ""},
  {"id": "haul_road_west_3", "element": "flow_line", "landform": "open_pit", "society": "mining", "at": [-262.5, 240.0], "y": null, "size": [140, -20, 40], "yaw_deg": 180, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "", "stamp": "ramp", "hole": false, "budget": "landform", "routes": ["main", "west_swing"], "fragment": ""},
  {"id": "haul_road_west_4", "element": "flow_line", "landform": "open_pit", "society": "mining", "at": [-187.5, 240.0], "y": null, "size": [140, -20, 40], "yaw_deg": 0, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "", "stamp": "ramp", "hole": false, "budget": "landform", "routes": ["main", "west_swing"], "fragment": ""},
  {"id": "haul_road_west_5", "element": "flow_line", "landform": "open_pit", "society": "mining", "at": [-95.0, 200.0], "y": null, "size": [103.0, 0.1, 24], "yaw_deg": 60.9, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "greybox:flow_line", "stamp": "", "hole": false, "budget": "landform", "routes": ["main", "west_swing"], "fragment": ""},
  {"id": "tailings_bench_east", "element": "terrace", "landform": "tailings_bench", "society": "mining", "at": [337.5, 110], "y": null, "size": [140, 0.1, 40], "yaw_deg": 0, "verb": "roll", "ride_fact": "ride_bowl", "home": "tailings_burrowers", "recipe": "greybox:terrace", "stamp": "", "hole": false, "budget": "landform", "routes": ["east_benches", "tailings_slide"], "fragment": "mining_tailings_pond"},
  {"id": "bench2_east_bank", "element": "bank", "landform": "open_pit", "society": "mining", "at": [337.5, -60], "y": null, "size": [190, 0.1, 40], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:bank", "stamp": "", "hole": false, "budget": "landform", "routes": ["bench_dive"], "fragment": ""},
  {"id": "adit_east", "element": "tunnel", "landform": "adit", "society": "mining", "at": [292.5, 120], "y": null, "size": [60, 8, 14], "yaw_deg": 0, "verb": "roll", "ride_fact": "ride_chute", "home": "adit_drill_crews", "recipe": "", "stamp": "", "hole": false, "budget": "park_large", "routes": ["bench_dive", "side_7a_east"], "fragment": "mining_adit_docket"},
  {"id": "adit_back_door", "element": "ground", "landform": "adit", "society": "mining", "at": [88, -368], "y": null, "size": [40, 0, 30], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "", "hole": false, "budget": "landform", "routes": ["east_benches", "bench_dive", "rim_zip_line"], "fragment": ""},
  {"id": "back_door_portal", "element": "ledge", "landform": "adit", "society": "mining", "at": [100, -386], "y": null, "size": [8, 6, 3], "yaw_deg": 0, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "greybox:ledge", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "winze_west", "element": "drop", "landform": "shaft", "society": "mining", "at": [-337.5, -20], "y": null, "size": [12, 20, 12], "yaw_deg": 0, "verb": "slam", "ride_fact": "ride_drop", "home": "winze_lamps", "recipe": "", "stamp": "", "hole": false, "budget": "park_large", "routes": ["side_7a_winze"], "fragment": "mining_winze_stencil"},
  {"id": "winze_north", "element": "drop", "landform": "shaft", "society": "mining", "at": [-60, -162.5], "y": null, "size": [12, 20, 12], "yaw_deg": 0, "verb": "slam", "ride_fact": "ride_drop", "home": "", "recipe": "", "stamp": "", "hole": false, "budget": "park_large", "routes": ["north_dive", "side_7a_winze"], "fragment": ""},
  {"id": "winze_east", "element": "drop", "landform": "shaft", "society": "mining", "at": [382.5, 120], "y": null, "size": [12, 20, 12], "yaw_deg": 0, "verb": "slam", "ride_fact": "ride_drop", "home": "", "recipe": "", "stamp": "", "hole": false, "budget": "park_large", "routes": ["bench_dive", "side_7a_east"], "fragment": ""},
  {"id": "conveyor_gallery", "element": "rail", "landform": "pipeline", "society": "mining", "at": [-262.5, 40.0], "y": null, "size": [200.0, 0.4, 6], "yaw_deg": 0.0, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:rail", "stamp": "", "hole": false, "budget": "landform", "routes": ["conveyor_line"], "fragment": "mining_conveyor_tag"},
  {"id": "barge_apron", "element": "ground", "landform": "open_pit", "society": "mining", "at": [-337.5, 250], "y": null, "size": [60, 0, 40], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "", "hole": false, "budget": "landform", "routes": ["side_7a_winze", "barge_ramp"], "fragment": ""},
  {"id": "deep_adit", "element": "tunnel", "landform": "adit", "society": "ancient", "at": [262.5, 330], "y": null, "size": [50, 10, 14], "yaw_deg": 0, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "", "stamp": "", "hole": false, "budget": "park_large", "routes": ["side_7a_east", "deep_adit_floor", "eruption_lip"], "fragment": "ancient_adit_seal"},
  {"id": "eruption_lip", "element": "kicker", "landform": "adit", "society": "ancient", "at": [215, 330], "y": null, "size": [12, 2.5, 14], "yaw_deg": -90, "verb": "launch", "ride_fact": "kicker_launch", "home": "", "recipe": "", "stamp": "", "hole": false, "budget": "detail", "routes": ["eruption_lip"], "fragment": ""},
  {"id": "floor_sump", "element": "bowl", "landform": "open_pit", "society": "mining", "at": [-90, 120], "y": null, "size": [40, 5, 40], "yaw_deg": 0, "verb": "pump", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:bowl", "stamp": "bowl", "hole": false, "budget": "landform", "routes": ["floor_bowl", "sump_floor"], "fragment": "mining_sump_gauge"},
  {"id": "collar_dish", "element": "bowl", "landform": "open_pit", "society": "mining", "at": [0, 255], "y": null, "size": [70, 10, 70], "yaw_deg": 0, "verb": "pump", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:bowl", "stamp": "bowl", "hole": false, "budget": "landform", "routes": ["main", "west_swing", "north_dive", "east_benches", "bench_dive", "rim_zip_line", "conveyor_line", "floor_bowl", "side_7a_winze", "side_7a_east", "eruption_lip"], "fragment": ""},
  {"id": "hoist_house", "element": "ledge", "landform": "headframe", "society": "mining", "at": [-75, 215], "y": null, "size": [44, 16, 26], "yaw_deg": -63, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "greybox:ledge", "stamp": "", "hole": false, "budget": "landform", "routes": ["hoist_yard", "hoist_roof_line"], "fragment": "mining_hoist_boiler"},
  {"id": "tipple_deck", "element": "ledge", "landform": "headframe", "society": "mining", "at": [0, 240], "y": -60, "size": [24, 2, 16], "yaw_deg": 180, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:ledge", "stamp": "", "hole": false, "budget": "detail", "routes": ["conveyor_line", "hoist_roof_line"], "fragment": ""},
  {"id": "gate_apron", "element": "ground", "landform": "open_pit", "society": "mining", "at": [60, 292], "y": null, "size": [70, 0, 50], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "", "hole": false, "budget": "landform", "routes": ["main", "west_swing"], "fragment": ""},
  {"id": "switchback_camp", "element": "ground", "landform": "open_pit", "society": "mining", "at": [180, -160], "y": null, "size": [16, 0, 16], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "", "hole": false, "budget": "landform", "routes": ["north_dive", "east_benches"], "fragment": ""},
  {"id": "bench1_haul_lane", "element": "flow_line", "landform": "open_pit", "society": "mining", "at": [-20.0, -241.0], "y": null, "size": [80.0, 0.1, 24], "yaw_deg": 90.0, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "greybox:flow_line", "stamp": "", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "rim_road_lane_1", "element": "flow_line", "landform": "open_pit", "society": "mining", "at": [-152.5, -316.0], "y": null, "size": [53.0, 0.1, 20], "yaw_deg": 58.1, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "greybox:flow_line", "stamp": "", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "rim_road_lane_2", "element": "flow_line", "landform": "open_pit", "society": "mining", "at": [-30.0, -300.0], "y": null, "size": [60.0, 0.1, 20], "yaw_deg": 90.0, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "greybox:flow_line", "stamp": "", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "bench2_north_lane", "element": "flow_line", "landform": "open_pit", "society": "mining", "at": [0.0, -168.0], "y": null, "size": [80.0, 0.1, 20], "yaw_deg": 90.0, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "greybox:flow_line", "stamp": "", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "bench2_camp_lane", "element": "flow_line", "landform": "open_pit", "society": "mining", "at": [250.0, -152.0], "y": null, "size": [70.0, 0.1, 20], "yaw_deg": 90.0, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "greybox:flow_line", "stamp": "", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "leach_pads", "element": "terrace", "landform": "tailings_bench", "society": "mining", "at": [180, -640], "y": null, "size": [420, 3, 260], "yaw_deg": 90, "verb": "pump", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "mesa", "hole": false, "budget": "landform", "routes": ["north_plateau"], "fragment": "mining_leach_ticket"},
  {"id": "mill_launder_1", "element": "grind_line", "landform": "flume", "society": "mining", "at": [535, -435], "y": null, "size": [282, 1.5, 6], "yaw_deg": -27, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "landform", "routes": ["north_plateau"], "fragment": "mining_launder_note"},
  {"id": "ne_mesa", "element": "ledge", "landform": "mesa_rim", "society": "none", "at": [650, -700], "y": null, "size": [240, 20, 240], "yaw_deg": 0, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "", "stamp": "ridge", "hole": false, "budget": "landform", "routes": ["north_plateau"], "fragment": ""},
  {"id": "tailings_dam", "element": "bank", "landform": "tailings_bench", "society": "mining", "at": [640, 150], "y": null, "size": [300, 35, 220], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "mesa", "hole": false, "budget": "landform", "routes": ["east_loop"], "fragment": ""},
  {"id": "south_wash", "element": "half_pipe", "landform": "dry_wash", "society": "none", "at": [0, 720], "y": null, "size": [700, 8, 40], "yaw_deg": 90, "verb": "pump", "ride_fact": "ride_chute", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": ["south_loop"], "fragment": ""},
  {"id": "west_slickrock", "element": "bank", "landform": "slickrock", "society": "none", "at": [-600, 450], "y": null, "size": [360, 18, 300], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "ridge", "hole": false, "budget": "landform", "routes": ["west_loop"], "fragment": ""},
  {"id": "dump_berm_east", "element": "bank", "landform": "open_pit", "society": "mining", "at": [-510.9, -664.1], "y": null, "size": [250.0, 4.0, 4.0], "yaw_deg": 15.0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "dump_berm_west", "element": "bank", "landform": "open_pit", "society": "mining", "at": [-549.6, -653.7], "y": null, "size": [250.0, 4.0, 4.0], "yaw_deg": 15.0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "rim_road_berm", "element": "bank", "landform": "open_pit", "society": "mining", "at": [-87.5, -283.0], "y": null, "size": [255.0, 3.0, 4.0], "yaw_deg": 90.0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "haul_ramp_berm", "element": "bank", "landform": "open_pit", "society": "mining", "at": [-219.0, -324.0], "y": null, "size": [68.0, 3.0, 4.0], "yaw_deg": 0.0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "wash_berm", "element": "bank", "landform": "open_pit", "society": "mining", "at": [-462.5, -500.0], "y": null, "size": [75.2, 3.0, 4.0], "yaw_deg": 85.4, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "bench3_dive_windrow_1", "element": "bank", "landform": "open_pit", "society": "mining", "at": [247.0, -113.0], "y": null, "size": [30.0, 3.0, 4.0], "yaw_deg": 90.0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "bench4_ore_bin", "element": "bank", "landform": "open_pit", "society": "mining", "at": [-168.0, 32.5], "y": null, "size": [45.0, 14.0, 8.0], "yaw_deg": 0.0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "bench3_west_berm", "element": "bank", "landform": "open_pit", "society": "mining", "at": [-185.0, -52.5], "y": null, "size": [45.0, 3.0, 4.0], "yaw_deg": 0.0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "camp_dive", "element": "kicker", "landform": "open_pit", "society": "mining", "at": [134.0, -197.0], "y": null, "size": [12, 2.5, 14], "yaw_deg": 51.0, "verb": "launch", "ride_fact": "kicker_launch", "home": "", "recipe": "greybox:kicker", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "camp_dive_windrow_2", "element": "bank", "landform": "open_pit", "society": "mining", "at": [85.0, -197.4], "y": null, "size": [60.0, 3.0, 4.0], "yaw_deg": 90.0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "camp_dive_windrow_1", "element": "bank", "landform": "open_pit", "society": "mining", "at": [248.0, -198.0], "y": null, "size": [40.0, 3.0, 4.0], "yaw_deg": 90.0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "canal_saguaros", "element": "anchor_field", "landform": "saguaro_stand", "society": "none", "at": [-356, -501], "y": null, "size": [300.0, 10, 70], "yaw_deg": 45.0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "camp_ore_bin", "element": "ledge", "landform": "open_pit", "society": "mining", "at": [160.0, -218.0], "y": null, "size": [10.0, 14, 10.0], "yaw_deg": 0.0, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "greybox:ledge", "stamp": "", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "camp_dive_windrow_3","element": "bank", "landform": "open_pit", "society": "mining", "at": [175.0, -198.0], "y": null, "size": [30.0, 3.0, 4.0], "yaw_deg": 90.0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "north_dive", "element": "kicker", "landform": "open_pit", "society": "mining", "at": [-150, -197], "y": null, "size": [12, 2.5, 14], "yaw_deg": 0.0, "verb": "launch", "ride_fact": "kicker_launch", "home": "", "recipe": "greybox:kicker", "stamp": "", "hole": false, "budget": "detail", "routes": ["north_dive"], "fragment": ""},
  {"id": "north_dive_windrow_1", "element": "bank", "landform": "open_pit", "society": "mining", "at": [-95.0, -198.0], "y": null, "size": [60.0, 3.0, 4.0], "yaw_deg": 90.0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "north_dive_windrow_2", "element": "bank", "landform": "open_pit", "society": "mining", "at": [-205.0, -198.0], "y": null, "size": [60.0, 3.0, 4.0], "yaw_deg": 90.0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "bench3_dive", "element": "kicker", "landform": "open_pit", "society": "mining", "at": [205, -112], "y": null, "size": [12, 2.5, 14], "yaw_deg": 0.0, "verb": "launch", "ride_fact": "kicker_launch", "home": "", "recipe": "greybox:kicker", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bench3_dive_windrow_2", "element": "bank", "landform": "open_pit", "society": "mining", "at": [150.0, -113.0], "y": null, "size": [60.0, 3.0, 4.0], "yaw_deg": 90.0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "bench4_dive", "element": "kicker", "landform": "open_pit", "society": "mining", "at": [110, -27], "y": null, "size": [12, 2.5, 14], "yaw_deg": 0.0, "verb": "launch", "ride_fact": "kicker_launch", "home": "", "recipe": "greybox:kicker", "stamp": "", "hole": false, "budget": "detail", "routes": ["north_dive"], "fragment": ""},
  {"id": "bench4_dive_windrow_1", "element": "bank", "landform": "open_pit", "society": "mining", "at": [165.0, -28.0], "y": null, "size": [60.0, 3.0, 4.0], "yaw_deg": 90.0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "bench4_dive_windrow_2", "element": "bank", "landform": "open_pit", "society": "mining", "at": [55.0, -28.0], "y": null, "size": [60.0, 3.0, 4.0], "yaw_deg": 90.0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "floor_dive", "element": "kicker", "landform": "open_pit", "society": "mining", "at": [70, 58], "y": null, "size": [12, 2.5, 14], "yaw_deg": 0.0, "verb": "launch", "ride_fact": "kicker_launch", "home": "", "recipe": "greybox:kicker", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "floor_dive_windrow_1", "element": "bank", "landform": "open_pit", "society": "mining", "at": [125.0, 57.0], "y": null, "size": [60.0, 3.0, 4.0], "yaw_deg": 90.0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "floor_dive_windrow_2", "element": "bank", "landform": "open_pit", "society": "mining", "at": [15.0, 57.0], "y": null, "size": [60.0, 3.0, 4.0], "yaw_deg": 90.0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "east_dive", "element": "kicker", "landform": "open_pit", "society": "mining", "at": [307, 130], "y": null, "size": [12, 2.5, 30], "yaw_deg": -90.0, "verb": "launch", "ride_fact": "kicker_launch", "home": "", "recipe": "greybox:kicker", "stamp": "", "hole": false, "budget": "detail", "routes": ["east_benches"], "fragment": ""},
  {"id": "east_dive_windrow_1", "element": "bank", "landform": "open_pit", "society": "mining", "at": [308.0, 185.0], "y": null, "size": [60.0, 3.0, 4.0], "yaw_deg": 0.0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "east_dive_windrow_2", "element": "bank", "landform": "open_pit", "society": "mining", "at": [308.0, 75.0], "y": null, "size": [60.0, 3.0, 4.0], "yaw_deg": 0.0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "east_dive_2", "element": "kicker", "landform": "open_pit", "society": "mining", "at": [232, 133], "y": null, "size": [12, 2.5, 40], "yaw_deg": -90.0, "verb": "launch", "ride_fact": "kicker_launch", "home": "", "recipe": "greybox:kicker", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "east_dive_2_windrow_1", "element": "bank", "landform": "open_pit", "society": "mining", "at": [233.0, 205.0], "y": null, "size": [60.0, 3.0, 4.0], "yaw_deg": 0.0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "east_dive_2_windrow_2", "element": "bank", "landform": "open_pit", "society": "mining", "at": [233.0, 83.0], "y": null, "size": [60.0, 3.0, 4.0], "yaw_deg": 0.0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "east_dive_3", "element": "kicker", "landform": "open_pit", "society": "mining", "at": [157, 170], "y": null, "size": [12, 2.5, 30], "yaw_deg": -90.0, "verb": "launch", "ride_fact": "kicker_launch", "home": "", "recipe": "greybox:kicker", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "east_dive_3_windrow_1", "element": "bank", "landform": "open_pit", "society": "mining", "at": [158.0, 225.0], "y": null, "size": [60.0, 3.0, 4.0], "yaw_deg": 0.0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "east_dive_3_windrow_2", "element": "bank", "landform": "open_pit", "society": "mining", "at": [158.0, 115.0], "y": null, "size": [60.0, 3.0, 4.0], "yaw_deg": 0.0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "west_dive", "element": "kicker", "landform": "open_pit", "society": "mining", "at": [-160, -112], "y": null, "size": [12, 2.5, 14], "yaw_deg": 0.0, "verb": "launch", "ride_fact": "kicker_launch", "home": "", "recipe": "greybox:kicker", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "west_dive_windrow_1", "element": "bank", "landform": "open_pit", "society": "mining", "at": [-105.0, -113.0], "y": null, "size": [60.0, 3.0, 4.0], "yaw_deg": 90.0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "west_dive_windrow_2", "element": "bank", "landform": "open_pit", "society": "mining", "at": [-215.0, -113.0], "y": null, "size": [60.0, 3.0, 4.0], "yaw_deg": 90.0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "ore_pile_east", "element": "bank", "landform": "tailings_bench", "society": "mining", "at": [95, 245], "y": null, "size": [12, 6, 12], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "ore_pile_mid", "element": "bank", "landform": "tailings_bench", "society": "mining", "at": [70, 175], "y": null, "size": [12, 6, 12], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "ore_pile_north", "element": "bank", "landform": "tailings_bench", "society": "mining", "at": [5, 130], "y": null, "size": [12, 6, 12], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "ore_pile_west", "element": "bank", "landform": "tailings_bench", "society": "mining", "at": [-70, 140], "y": null, "size": [12, 6, 12], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "ore_pile_sw", "element": "bank", "landform": "tailings_bench", "society": "mining", "at": [-40, 190], "y": null, "size": [12, 6, 12], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "ore_pile_nw", "element": "bank", "landform": "tailings_bench", "society": "mining", "at": [-90, 85], "y": null, "size": [12, 6, 12], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "slickrock_1", "element": "bank", "landform": "slickrock", "society": "none", "at": [710, 710], "y": null, "size": [200, 6, 200], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "ridge", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "slickrock_2", "element": "bank", "landform": "slickrock", "society": "none", "at": [-710, -32], "y": null, "size": [200, 6, 200], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "ridge", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "spoil_heap_3", "element": "bank", "landform": "tailings_bench", "society": "mining", "at": [710, -288], "y": null, "size": [200, 6, 200], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "ridge", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "slickrock_4", "element": "bank", "landform": "slickrock", "society": "none", "at": [-256, -730], "y": null, "size": [160, 6, 160], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "ridge", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "slickrock_5", "element": "bank", "landform": "slickrock", "society": "none", "at": [-730, -672], "y": null, "size": [160, 6, 160], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "ridge", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "slickrock_6", "element": "bank", "landform": "slickrock", "society": "none", "at": [-710, 710], "y": null, "size": [200, 6, 200], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "ridge", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "slickrock_7", "element": "bank", "landform": "slickrock", "society": "none", "at": [710, 448], "y": null, "size": [200, 6, 200], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "ridge", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "slickrock_8", "element": "bank", "landform": "slickrock", "society": "none", "at": [-176, -512], "y": null, "size": [80, 6, 80], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "ridge", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "slickrock_9", "element": "bank", "landform": "slickrock", "society": "none", "at": [-480, 730], "y": null, "size": [160, 6, 160], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "ridge", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "slickrock_10", "element": "bank", "landform": "slickrock", "society": "none", "at": [480, 730], "y": null, "size": [160, 6, 160], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "ridge", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "slickrock_11", "element": "bank", "landform": "slickrock", "society": "none", "at": [-710, -256], "y": null, "size": [200, 6, 200], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "ridge", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "slickrock_12", "element": "bank", "landform": "slickrock", "society": "none", "at": [-730, -480], "y": null, "size": [160, 6, 160], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "ridge", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "spoil_heap_13", "element": "bank", "landform": "tailings_bench", "society": "mining", "at": [-30, -452], "y": null, "size": [100, 6, 100], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "ridge", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "spoil_heap_14", "element": "bank", "landform": "tailings_bench", "society": "mining", "at": [320, -400], "y": null, "size": [200, 6, 200], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "ridge", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "slickrock_15", "element": "bank", "landform": "slickrock", "society": "none", "at": [-400, -360], "y": null, "size": [80, 6, 80], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "ridge", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "spoil_heap_16", "element": "bank", "landform": "tailings_bench", "society": "mining", "at": [710, -80], "y": null, "size": [200, 6, 200], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "ridge", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "slickrock_17", "element": "bank", "landform": "slickrock", "society": "none", "at": [-710, 176], "y": null, "size": [200, 6, 200], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "ridge", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "spoil_heap_18", "element": "bank", "landform": "tailings_bench", "society": "mining", "at": [112, -416], "y": null, "size": [50, 6, 50], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "ridge", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "spoil_heap_19", "element": "bank", "landform": "tailings_bench", "society": "mining", "at": [672, -480], "y": null, "size": [200, 6, 200], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "ridge", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "slickrock_20", "element": "bank", "landform": "slickrock", "society": "none", "at": [-400, -770], "y": null, "size": [50, 6, 50], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "ridge", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "slickrock_21", "element": "bank", "landform": "slickrock", "society": "none", "at": [-290, -600], "y": null, "size": [40, 6, 40], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "", "stamp": "ridge", "hole": false, "budget": "landform", "routes": [], "fragment": ""}
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
  {"id": "incline_skip", "kind": "barge", "site": "pit", "recipe": "barge", "a": [0, -19.4, -225], "b": [0, -99.4, 100], "size": [14, 1.2, 14], "travel": 9.0, "dwell": 3.0, "offset": 0.0},
  {"id": "tipple_lift", "kind": "lift", "site": "tipple_deck", "recipe": "lift_platform", "at": [20, 262], "radius": 4.5, "rise": 40.0, "charge": 3.2, "offset": 0.0},
  {"id": "sump_geyser", "kind": "launcher", "site": "floor_sump", "recipe": "geyser_vent", "style": "geyser", "at": [-70, 128], "radius": 3.5, "target": [0, -59.2, 240], "floor": 16.0, "min_flight": 2.2, "charge": 3.0},
  {"id": "rim_zip", "kind": "cable", "site": "pit", "recipe": "", "from": [60, 1.5, -298], "to": [150, -38.5, -178], "radius": 6.0, "floor": 22.0},
  {"id": "adit_valve", "kind": "valve", "site": "adit_back_door", "recipe": "gauge", "at": [94, -374], "door": {"at": [88, -368], "size": [10, 5, 1], "turn": 2.16}, "vent": null},
  {"id": "sealed_portal", "kind": "cracked_wall", "site": "deep_adit", "recipe": "", "at": [262.5, 400], "size": [12, 7, 1.4], "turn": 1.24},
  {"id": "dust_devil_east", "kind": "thermal", "site": "tailings_bench_east", "recipe": "", "at": [400, -60], "radius": 5.0, "height": 62.0},
  {"id": "dust_devil_floor", "kind": "thermal", "site": "pit", "recipe": "", "at": [-30, 160], "radius": 12.0, "height": 60.0},
  {"id": "tailings_conveyor", "kind": "cable", "site": "tailings_bench_east", "recipe": "", "from": [337, -38.5, -40], "to": [337, -38.5, 110], "radius": 6.0, "floor": 22.0},
  {"id": "bench2_haul_cable", "kind": "cable", "site": "pit", "recipe": "", "from": [60, -38.5, -150], "to": [-90, -38.5, -150], "radius": 6.0, "floor": 22.0},
  {"id": "skip_cable", "kind": "cable", "site": "pit", "recipe": "", "from": [175, -38.5, -125], "to": [120, -78.5, 25], "radius": 6.0, "floor": 22.0},
  {"id": "west_winze_cable", "kind": "cable", "site": "pit", "recipe": "", "from": [-150, -58.5, -25], "to": [-100, -98.5, 170], "radius": 6.0, "floor": 22.0}
 ],
 "weather_rows": [
  {"id": "noon_shimmer", "kind": "heat_shimmer", "trigger": {"on": "always"}, "lead_s": 0.0, "live_s": 0.0, "gap_s": 0.0, "fog": {"density": 0.0015, "color": "#e8d7b0"}, "sky": "clear", "sound": "heat_tick", "music_layer": "shimmer_pad", "event_odds": {}, "handling": "none"},
  {"id": "dust_devils", "kind": "dust_squall", "trigger": {"on": "clock_tier", "value": 2}, "lead_s": 6.0, "live_s": 30.0, "gap_s": 90.0, "fog": {"density": 0.006, "color": "#c9a36b"}, "sky": "dust", "sound": "dust_hiss", "music_layer": "dust_grit", "event_odds": {"bench3_drill_barge": 1.5}, "handling": "none"}
 ],
 "activity_rows": [
  {"id": "cache_lip", "activity": "cracked_cache", "site": "spoil_heap_14", "at": [296, -320], "pack": [], "pay": {"rarities": ["rare"]}},
  {"id": "switchback_camp_site", "activity": "enemy_camp", "site": "switchback_camp", "at": [180, -160], "pack": ["burrower", "burrower", "drill_crew"], "pay": {"named": "rivet_plating"}},
  {"id": "bench3_altar", "activity": "ambush_altar", "site": "pit", "at": [-110, -84], "pack": [], "pay": {"rarities": ["common", "rare"]}}
 ]
}
```

**Flush liners, 2026-10-19 (coordinator's #183 ruling; World's 07:32Z recommendation (a)).** All six bake-conformed liners of this stage (`liner_dump_wash_1`, `liner_dump_wash_2`, `liner_canal_lip`, `liner_haul_road_west_5`, `liner_bench2_camp_lane`, `liner_bench2_east_bank`) carry `flush_lane` in `tools/blender/park/flume_works.py`, loading the ride footprints of `park_pit`. A liner has no `-col`, so anything visible in a ride lane taller than the 0.12 m flush band must be solid: inside any ride row's footprint the drawn surface stands no more than 0.12 m above the ground (the haul verge cobbles and canal lip are held to the band there and keep their relief outside). The reference is the game's ground mesh itself (`terrain.gd`'s 2 m grid cut a, b, c / b, d, c along the b-c diagonal, planar per triangle, not the bilinear height), and the test is exact: the surface minus that mesh is linear on each piece of a triangle cut by the mesh's edges and the footprints' edges, so `--check` (`liner_check`) reads the extremes at those pieces' vertices. Inside any ride row's footprint the surface stands between 0.03 m and 0.12 m above the ground mesh; everywhere else it stands at least 0.03 m above it (`FLUSH_MIN`; Terrain3D's own diagonals and LOD can fold the drawn ground above the collider planes), and its corners may rise up to 0.22 m outside every footprint. Nothing is left out: a lattice cell whose plain triangles keep that band stays plain (its corner offsets may be nudged together to fit), and any other cell is cut along the ground mesh's edges and the footprints' edges, each piece set on the ground plus its relief and clamped to the band inside a footprint, while a plain neighbour takes the shared edge's kink points, and `--check` fails the build on any crack or T-junction step. `--check` also fails a liner with a crack (a vertical step or a T-junction height mismatch over 3 mm), a lane point no drawn triangle covers (apart from cells another flush row takes), or more triangles than its registry class cap. Outside every footprint (the margin strips past a row's ends, say) the band does not apply: sheet styles may stand up to 0.22 m there, and the floor band is relaxed from 0.08 m to 0.12 m inside a footprint and 0.22 m outside one; whole-lane flatness is not claimed or checked. The sheets ship no rim rocks, tufts or detail shells, so the twelve `liner_*_detail{1,2}.glb` of these rows are deleted. `liner_dump_wash_1` and `liner_dump_wash_2` overlap (and `dump_wash_2` crosses `canal_lip`); an overlapping cell goes to the row whose lane holds it, then (where both or neither lane holds it) to the earlier row; a cell only partly covered stays. Pit colliders, sensors and the bake are unchanged; this is draw-only. The cut costs triangles, and all six rows still fit `landform` (8,000).
