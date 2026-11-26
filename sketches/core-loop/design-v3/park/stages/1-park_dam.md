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
E toe_vents_wake [190, 430]
E powerhouse_boiler [120, 505]
B bay dock [0, 467]
G gate row [0, 528]
L spillway_dam (landmark) [0, 620]
W Warden engage ring centre [0, 575]
D drop-in [-150, -690]
```

The three activities, signposted from the drop-in: the domes camp (`enemy_camp`, today's chaser pack and the named `hot_rivets` pay, `map_spillway.gd:98`), the rim cache (`cracked_cache`) and the bench altar (`ambush_altar`). Rules from `activities.gd:29-47`. The camp is also the first waymark: lines pass its point within 12 m, and its ring starts only inside 8 m (`activities.gd:31`), so the fight is a choice made at speed. Since 2026-11-09 (ruling bu) the camp pays a common part rolled from the pool, with no named part (PARK.md 2.12).

## 5. `park_rows` (137 rows, greybox round 5, 2026-10-12; authored pass 2026-10-17)

The shipped rows are in `src/world/park/park_dam.json`; this table follows that file. Every non-ground row carries `greybox:<element>` (R10), except the three rows the KD1-DRESS pilot dressed with landform recipes on 2026-10-16 (`west_wash`, `upper_slot`, `corkscrew_slot`; section 15) and the rows the authored pass dressed on 2026-10-17: the 40 ride lips and `eye_mouth` on drape recipes, the seven slalom gates and the `dome_11` benchmark (section 16). Heights are metres above the base plain; `size` is [length along the facing, height, width].

**Runtime placement (KB9, re-cut 2026-10-11).** Since KB9 the stage places its rows at runtime (`park_recipes.gd` `place_row`): a stamped greybox row keeps its ride sensor and drops its box, because the stamp is its shape, while an unstamped greybox row stands as a solid box of its whole size. The first greybox cut left 19 rows unstamped, and on the KB9 head `slickrock_domes` stood as a 24 m wall across every line (Rivet stalled 20 m from the drop on every seed). So every placed row except an anchor field now carries a stamp, which keeps the bake, the graph and the runtime in agreement:

- Rows whose shape the ground rows already give carry a shallow stamp that keeps their ride sensor: `slickrock_domes` a 1 m bowl, the two slots and `tailwater_bar` a 2 m wash, `spillway_tunnel` a 4 m wash, `construction_incline` and `east_haul_road` a 1 m ramp turned 180 degrees (flush where the descent starts at z 215 to 220, a 1 m step down off their foot at z 440 to 445), the benches and aprons a bowl of their height. Two other readings were measured and dropped: a 1 m wash on the haul road drifted the Cannon line east into `powerhouse_stair`'s sheer side on 4 of 8 seeds, and the ramp facing down the descent put a 1 m step up at its head that cost Kest the peak band on 3 of 8 seeds.
- Solid rows stamp their real shape: `service_ledge` and `lobber_ledge` 24 m plateaus (the lift climbs the lobber ledge, and the gallery sits on the service ledge), `cliff_rooms_west`, `pipeline_bridge`, `canal_lips` and `crest_rail` ridges, and `east_abutment` a ramp rising 16 m toward the dam (a plateau cut the `crest_line` route).
- Each kicker keeps its kick in its `_ramp` ground row, as before KB9, and carries a 0 m plateau stamp of its own, so no wedge stands on the ramp. A flat-based wedge on the 14 degree canyon descent stood 28 degrees off the slope, and Rivet bounced off `apron_kicker` on 2 of 8 seeds. The kick height is the `_ramp` row's height.
- Four anchor fields are pulled back off the domes shelf, so their posts stand at least 21 m from every line: `hoodoo_25`, `saguaro_6`, `saguaro_22` and `hoodoo_23`. The stage test pins 15 m.
- The cut left the strip south of the drop bare, and `park_density_test` measured 96.4 m at (-328, -800) with 16 open nodes over 80 m. `saguaro_26` (2026-10-12) fills it: 380 m east to west by 70 m at [-290, -755], covering x -480 to -100 and z -790 to -720, so its posts stand at least 30 m south of the drop and of every line out of it. The density worst is now 62.0 m (near `hoodoo_23`), with no node over 80 m. A row's `size` is [length along its facing, height, width across], so at yaw 0 the first number runs north to south.

| Group | Row | Element / landform / society | Stamp | At, size, yaw | Verb, ride fact | Note |
| --- | --- | --- | --- | --- | --- | --- |
| The canvas | `canyon_country` | ground / slickrock / none | plateau | [0, 0], [1600, 100, 1600], 0 | roll |  |
| The canvas | `shelf_rise` | ground / slickrock / none | ramp | [0, -305], [990, 50, 1600], 0 | roll |  |
| The canvas | `shelf_sag` | ground / slickrock / none | bowl | [0, -305], [990, 3, 1600], 0 | roll |  |
| The canvas | `shelf_sag_corner_1` | ground / slickrock / none | bowl | [-650, -720], [320, 3, 640], 0 | roll |  |
| The canvas | `shelf_sag_corner_2` | ground / slickrock / none | bowl | [650, -720], [320, 3, 640], 0 | roll |  |
| The canvas | `shelf_sag_corner_3` | ground / slickrock / none | bowl | [-650, 110], [320, 3, 640], 0 | roll |  |
| The canvas | `shelf_sag_corner_4` | ground / slickrock / none | bowl | [650, 110], [320, 3, 640], 0 | roll |  |
| The canvas | `river_canyon` | ground / river_canyon / none | plateau | [0, 415], [450, -100, 400], 0 | roll | routes `incline_line` |
| The canvas | `canyon_descent` | ground / river_canyon / none | ramp | [0, 305], [230, 100, 400], 0 | roll |  |
| The top shelf | `top_shelf_deck` | drop / slickrock / dam_era | mesa | [-150, -690], [44, 10, 30], 30 | drop, `ride_drop` | routes `shelf`; `dam_era_survey_deck` |
| The top shelf | `slickrock_domes` | bank / slickrock / none | bowl | [-110, -520], [260, 1, 240], 0 | bank, `ride_hop` | routes `shelf` |
| The top shelf | `shelf_lip` | kicker / slickrock / none | plateau | [-90, -300], [20, 0, 30], 0 | launch, `kicker_launch` | routes `shelf` |
| The top shelf | `shelf_lip_ramp` | ground / slickrock / none | ramp | [-90, -300], [20, 6, 30], 180 | roll |  |
| The top shelf | `domes_kicker` | kicker / slickrock / none | plateau | [-160, -468], [20, 0, 24], 59 | launch, `kicker_launch` |  |
| The top shelf | `domes_kicker_ramp` | ground / slickrock / none | ramp | [-160, -468], [20, 5, 24], 239 | roll |  |
| The top shelf | `domes_fin_west` | elevated_line / slickrock / none | ridge | [-400, -520], [40, 20, 8], 0 | roll, `ride_ledge` |  |
| The top shelf | `domes_fin_mid` | elevated_line / slickrock / none | ridge | [-85, -455], [30, 20, 8], 0 | roll, `ride_ledge` |  |
| The top shelf | `domes_fin_east` | elevated_line / slickrock / none | ridge | [55, -547.5], [15, 20, 8], 0 | roll, `ride_ledge` |  |
| The three runs | `west_wash` | half_pipe / arroyo / dam_era | wash | [-102.5, -75], [397, 10, 44], 16.8 | pump, `ride_chute` | home `culvert_chasers`; routes `west_wash_run`; `dam_era_wash_liner` |
| The three runs | `upper_slot` | flow_line / slot_canyon / none | wash | [-45, -75], [384.7, 2, 30], 9 | roll, `ride_chute` | routes `upper_slot_run` |
| The three runs | `corkscrew_slot` | flow_line / slot_canyon / none | wash | [15, -75], [380.1, 2, 34], 1.5 | roll, `ride_chute` | routes `corkscrew_run` |
| The three runs | `wash_fin_west` | elevated_line / slickrock / none | ridge | [-157.5, -70], [358.9, 26, 22], 18.7 | roll, `ride_ledge` |  |
| The three runs | `slot_fin_west` | elevated_line / slickrock / none | ridge | [-74.2, -55.6], [300, 26, 22], 14 | roll, `ride_ledge` |  |
| The three runs | `slot_fin_east` | elevated_line / slickrock / none | ridge | [-18.5, -75], [331.6, 26, 22], 5.7 | roll, `ride_ledge` |  |
| The three runs | `slot_fin_far` | elevated_line / slickrock / none | ridge | [53.5, -70], [340, 26, 22], -0.5 | roll, `ride_ledge` |  |
| The three runs | `wash_kicker` | kicker / arroyo / dam_era | plateau | [-110, -80], [20, 0, 24], 17 | launch, `kicker_launch` |  |
| The three runs | `wash_kicker_ramp` | ground / arroyo / dam_era | ramp | [-110, -80], [20, 5, 24], 197 | roll |  |
| The three runs | `upper_slot_step` | kicker / slot_canyon / none | plateau | [-53, -80], [20, 0, 22], 9 | launch, `kicker_launch` |  |
| The three runs | `upper_slot_step_ramp` | ground / slot_canyon / none | ramp | [-53, -80], [20, 5, 22], 189 | roll |  |
| The three runs | `corkscrew_step` | kicker / slot_canyon / none | plateau | [16, -110], [20, 0, 22], 4 | launch, `kicker_launch` |  |
| The three runs | `corkscrew_step_ramp` | ground / slot_canyon / none | ramp | [16, -110], [20, 5, 22], 184 | roll |  |
| The Eye | `eye_fin_west` | elevated_line / slickrock / none | ridge | [-142, 150], [236, 20, 24], 90 | roll, `ride_ledge` |  |
| The Eye | `eye_fin_east` | elevated_line / slickrock / none | ridge | [142, 150], [236, 20, 24], 90 | roll, `ride_ledge` |  |
| The Eye | `the_eye` | tunnel / slickrock / none | ramp | [0, 165], [50, 5, 30], 180 | roll, `ride_chute` | routes `pool_floor`, `pool_rim`, `bucket_flight`, `ledge_line`, `ledge_drop`, `incline_line`, `canal_run`, `dropship_ramp`, `crest_line`; `ancient_eye_marks` |
| The Eye | `eye_chute_west` | elevated_line / river_canyon / none | ridge | [-28, 224], [52, 15, 8], 0 | roll, `ride_ledge` |  |
| The Eye | `eye_chute_east` | elevated_line / river_canyon / none | ridge | [28, 224], [52, 15, 8], 0 | roll, `ride_ledge` |  |
| The Eye | `eye_fall_spire_west` | elevated_line / river_canyon / none | spire | [-120, 245], [30, 24, 30], 0 | roll, `ride_ledge` |  |
| The Eye | `eye_fall_spire_east` | elevated_line / river_canyon / none | spire | [120, 245], [30, 24, 30], 0 | roll, `ride_ledge` |  |
| West: rim, tunnel, ledges | `west_rim_bench` | bank / mesa_rim / dam_era | bowl | [-235, 300], [220, 4, 60], 0 | bank, `ride_bowl` | routes `pool_floor`, `pool_rim`, `bucket_flight`, `ledge_line`, `ledge_drop`; `dam_era_overflow_channel` |
| West: rim, tunnel, ledges | `spillway_tunnel` | tunnel / spillway_tunnel / dam_era | wash | [-150, 330], [200, 4, 60], 0 | drop, `ride_drop` | home `outlet_brutes`; routes `pool_floor`, `pool_rim`, `bucket_flight`; `dam_era_tunnel_gauge` |
| West: rim, tunnel, ledges | `outlet_bucket` | kicker / spillway_tunnel / dam_era | plateau | [-100, 445], [16, 0, 24], 15 | launch, `kicker_launch` | routes `pool_floor`, `pool_rim`, `bucket_flight` |
| West: rim, tunnel, ledges | `outlet_bucket_ramp` | ground / spillway_tunnel / dam_era | ramp | [-100, 445], [16, 4, 24], 195 | roll |  |
| West: rim, tunnel, ledges | `cliff_rooms_west` | elevated_line / cliff_dwelling / ancestral_puebloan | ridge | [-165, 330], [160, 8, 16], 0 | roll, `ride_ledge` | routes `ledge_line`; `ref_cliff_rooms` |
| West: rim, tunnel, ledges | `viga_span` | anchor_field / cliff_dwelling / ancestral_puebloan | none | [-190, 425], [30, 4, 16], 0 | swing | routes `ledge_line`; `ref_viga_beams` |
| West: rim, tunnel, ledges | `service_ledge` | ledge / mesa_rim / dam_era | plateau | [-180, 520], [90, 24, 30], 0 | roll, `ride_ledge` | routes `ledge_line`, `pool_rim`, `ledge_drop`; `dam_era_ledge_stencil` |
| West: rim, tunnel, ledges | `lobber_ledge` | ledge / mesa_rim / dam_era | plateau | [-185, 455], [30, 24, 26], 0 | roll, `ride_ledge` | home `ledge_lobbers` |
| West: rim, tunnel, ledges | `west_lane_fin` | elevated_line / mesa_rim / none | ridge | [-70, 392.5], [155, 26, 20], 0 | roll, `ride_ledge` |  |
| Centre: the incline | `construction_incline` | drop / mesa_rim / dam_era | ramp | [0, 330], [230, 1, 100], 180 | drop, `ride_drop` | routes `incline_line`; `dam_era_incline_tally` |
| Centre: the incline | `incline_spine` | elevated_line / mesa_rim / dam_era | ridge | [15, 370], [100, 20, 16], 0 | roll, `ride_ledge` |  |
| Centre: the incline | `tailwater_bar` | flow_line / dry_wash / none | wash | [-20, 460], [70, 2, 60], 0 | roll, `ride_chute` | routes `incline_line` |
| Centre: the incline | `apron_kicker` | kicker / dry_wash / none | plateau | [0, 476], [20, 0, 26], 0 | launch, `kicker_launch` |  |
| Centre: the incline | `apron_kicker_ramp` | ground / dry_wash / none | ramp | [0, 476], [20, 3, 26], 180 | roll |  |
| Centre: the incline | `east_lane_fin` | elevated_line / mesa_rim / none | ridge | [70, 392.5], [155, 26, 20], 0 | roll, `ride_ledge` |  |
| East: bridge, bench, canal, crest | `pipeline_bridge` | grind_line / pipeline / dam_era | ridge | [130, 260], [80, 3, 6], 0 | grind, `ride_grapple_line` | routes `canal_run`, `dropship_ramp`, `crest_line`; `dam_era_bridge_plate` |
| East: bridge, bench, canal, crest | `east_bench_flats` | ground / slickrock / none | none | [165, 475], [90, 6, 70], 0 | roll | home `dropship_winches`; routes `canal_run`, `dropship_ramp`, `crest_line` |
| East: bridge, bench, canal, crest | `canal_lips` | grind_line / canal / dam_era | ridge | [170, 380], [120, 3, 8], 0 | grind, `ride_grapple_line` | routes `canal_run`; `dam_era_canal_headworks` |
| East: bridge, bench, canal, crest | `east_haul_road` | drop / mesa_rim / dam_era | ramp | [135, 330], [220, 1, 110], 180 | drop, `ride_drop` | routes `canal_run`; `dam_era_haul_sign` |
| East: bridge, bench, canal, crest | `east_abutment` | ledge / dam_face / dam_era | ramp | [170, 585], [60, 16, 50], 180 | roll, `ride_ledge` | routes `crest_line` |
| East: bridge, bench, canal, crest | `east_rim_bench` | bank / mesa_rim / none | bowl | [235, 260], [160, 4, 60], 0 | bank, `ride_bowl` |  |
| The toe | `plunge_pool` | bowl / dam_face / dam_era | bowl | [-85, 515], [110, 8, 110], 0 | bank, `ride_bowl` | routes `pool_floor`, `pool_rim`, `ledge_drop` |
| The toe | `pool_rock` | elevated_line / dam_face / none | spire | [-120, 500], [20, 14, 20], 0 | roll, `ride_ledge` |  |
| The toe | `pool_pillar` | elevated_line / dam_face / dam_era | spire | [-62, 560], [16, 14, 16], 0 | roll, `ride_ledge` |  |
| The toe | `toe_apron` | bank / dam_face / dam_era | bowl | [0, 520], [160, 2, 140], 0 | bank, `ride_bowl` | routes `face`, `powerhouse_floor`, `roof_ramp_line` |
| The toe | `training_wall_west` | elevated_line / dam_face / dam_era | ridge | [-28, 492.5], [55, 14, 8], 0 | roll, `ride_ledge` |  |
| The toe | `training_wall_east` | elevated_line / dam_face / dam_era | ridge | [50, 502.5], [45, 8, 8], 0 | roll, `ride_ledge` |  |
| The toe | `powerhouse` | ledge / dam_face / dam_era | plateau | [120, 515], [60, 20, 40], 0 | roll, `ride_ledge` | home `powerhouse_trappers`; routes `powerhouse_floor`, `roof_ramp_line`; `dam_era_powerhouse_log` |
| The toe | `powerhouse_stair` | ground / dam_face / dam_era | ramp | [120, 455], [60, 20, 16], 180 | roll | routes `powerhouse_floor`, `roof_ramp_line` |
| The toe | `powerhouse_roof_ramp` | bank / dam_face / dam_era | bowl | [92, 515], [60, 2, 16], 0 | bank, `ride_bowl` | routes `roof_ramp_line` |
| The toe | `toe_vent_pits` | bowl / dam_face / ancient | bowl | [190, 430], [50, 3, 50], 0 | bank, `ride_bowl` | `ancient_vent_plate` |
| The toe | `dam_face_quarter` | bank / dam_face / dam_era | ramp | [0, 627.5], [25, 30, 400], 180 | bank, `ride_bowl` | routes `face`, `powerhouse_floor`, `roof_ramp_line` |
| The toe | `gate_piers` | anchor_field / dam_face / dam_era | none | [0, 605], [10, 8, 44], 0 | swing | routes `face`, `powerhouse_floor`, `roof_ramp_line` |
| The toe | `gate_row_apron` | bank / dam_face / dam_era | bowl | [0, 540], [30, 2, 60], 0 | bank, `ride_bowl` |  |
| The toe | `crest_rail` | rail / dam_face / dam_era | ridge | [0, 655], [300, 1, 4], 90 | grind, `ride_grapple_line` | routes `crest_line` |
| The slalom (section 16) | `dome_5`, `dome_6`, `dome_15`, `dome_18`, `dome_19`, `dome_24`, `dome_25` | bank / slickrock / dam_era | spire | 40 by 16 by 40 each | roll, `ride_hop` | the survey stations the rolling line turns round; a red or blue survey flag on each summit; `dam_era_station_marks` (dome_5), `dam_era_gate_flags` (dome_24) |
| The slalom (section 16) | `dome_11` | bank / slickrock / dam_era | spire | 40 by 16 by 40 | roll, `ride_hop` | the benchmark, the shelf's west end, off every line but Sable's; `dam_era_benchmark` |
| The slalom (section 16) | `dome_7` | bank / slickrock / none | spire | 40 by 16 by 40 | roll, `ride_hop` | Rivet's cage stands at its north foot (`rescue_rows`) |
| The slalom (section 16) | the other 16 domes | bank / slickrock / none | spire | 40 by 16 by 40 each | roll, `ride_hop` | the wide lines' turning marks and the anchor faces of the shelf |
| Filler | 37 hoodoo fields, saguaro stands and hoodoo stacks | anchor_field or ground / hoodoo_field, saguaro_stand | none, or spire for a stack | fields 320 by 320 (four cut back off the domes shelf, size as length north to south by width east to west: `hoodoo_25` 60 by 320 at [-60, -750], `saguaro_6` 320 by 80 at [-470, -640], `saguaro_22` 320 by 160 at [230, -700], `hoodoo_23` 320 by 190 at [245, -420]; and `saguaro_26` 70 by 380 at [-290, -755], the strip south of the drop), stacks 26 by 9 by 26 | swing, roll | the density rows of the open country (PARK.md section 8) |
| Shelf run-out | `sable_shelf_runout_anchor` | anchor_field / saguaro_stand / none | none | [-100, -236], [8, 18, 8], 0 | swing | round-2 greybox anchor retained |

## 6. `event_rows` (6 rows)

| Row | Family, kind | Site | Trigger | Telegraph | Effect | Route change |
| --- | --- | --- | --- | --- | --- | --- |
| `plunge_pool_flood` | natural, `flood_fill` | `plunge_pool` | clock_tier 1 | 6 s `flood_rising` | depth_m 1.2, fill_s 10.0, material water | closes `pool_floor`, opens `pool_rim` |
| `west_wash_flash_flood` | natural, `flash_flood` | `west_wash` | clock_tier 2 | 6 s `flood_rising` | depth_m 1.2, fill_s 4.0, material water | closes `west_wash_run`, opens none |
| `dome_lightning` | natural, `lightning` | `slickrock_domes` | clock_tier 3 | 3 s `lightning_charge` | strike_m 6.0, damage 8.0 | closes none, opens none |
| `east_bench_dropship` | fleet, `fleet_landing` | `east_bench_flats` | clock_tier 1 | 10 s `fleet_inbound` | vessel dropship, home dropship_winches, footprint_m [36, 16] | closes none, opens `dropship_ramp` |
| `toe_vents_wake` | ancient, `machine_eruption` | `toe_vent_pits` | clock_tier 2 | 8 s `ancient_stirring` | miniboss reactor_relic, swap vent_pit_lip | closes none, opens none |
| `powerhouse_boiler` | industrial, `boiler_burst` | `powerhouse` | warden_phase chunk_2 | 5 s `boiler_pressure` | hazard steam_cone, hazard_m [24, 10], damage 6.0, swap powerhouse_roof_ramp | closes `powerhouse_floor`, opens `roof_ramp_line` |

`toe_vent_pits` moved 25 m east to [190, 430] in round 3. Its 50 by 50 m footprint has 10.448 m of clearance from Cannon, the nearest pilot or floor corridor. `park_events_test.gd` requires `toe_vents_wake` to announce, telegraph and land once with all seven corridors present.

Both floods hold 1.2 m of water, the depth a ball rolls out of (PARK.md section 2.4), so the pool and the wash slow a ball and never trap it. `dome_lightning` waits for tier 3, which exists only with veto item 16 (PARK.md:588). World 1 fields no deflector.

## 7. `home_rows` (5 homes, one per kind)

| Home | Enemy | Site, landform | Reinforce | Break | Dormant |
| --- | --- | --- | --- | --- | --- |
| `culvert_chasers` | chaser | `west_wash`, arroyo | tier 1, every 25 s, 5 alive, `run_down` | ram, 60 hp, 12 scrap | no |
| `ledge_lobbers` | lobber | `lobber_ledge`, mesa_rim | tier 1, every 30 s, 4 alive, `grounded` | slam, 80 hp, 14 scrap | no |
| `powerhouse_trappers` | mag_trapper | `powerhouse`, dam_face | tier 2, every 35 s, 3 alive, `grounded` | smash, 90 hp, 16 scrap | no |
| `outlet_brutes` | plated_brute | `spillway_tunnel`, spillway_tunnel | tier 2, every 45 s, 2 alive, `elite` | damage, 140 hp, 20 scrap | no |
| `dropship_winches` | winch_drone | `east_bench_flats`, slickrock | tier 1, every 30 s, 3 alive, `elite` | damage, 70 hp, 14 scrap | yes |

Advantage and counter text is in the park file, row by row. `ledge_lobbers` now lives on its own row, `lobber_ledge` [-185, 455], 92 m from the gallery door at [-167, 545], so the 40 m clear ring round the hidden pocket's door holds (R3). The east bench home is winch drones (`src/combat/winch_drone.gd:13`, `:20`).

## 8. `contraption_rows` (9 rows), weather and time of day

Since the ledges are 24 m plateaus (section 5), `service_lift` stands at the foot of `lobber_ledge`'s north face and lifts the ball 24 m to its top, the way onto the service ledge and the gallery; `gallery_valve`'s door faces the plunge pool from the service ledge's east edge, in sight of the line, and its cache stays at the back of the ledge. `crest_trebuchet` stands at the foot of the east abutment's ramp, at [192, 548], 22 m east of the Cannon line's [170, 540] waypoint: at [170, 545] it caught the Cannon bot on 5 of 8 seeds and threw it 260 m over the crest with no anchor in reach (the 40 m anchor band). It stays a momentum tool a player takes on purpose (`wardens/reactor.md` section 3.1: none is required).

| Row | Kind, skin | Site | Where | Shape |
| --- | --- | --- | --- | --- |
| `rim_zip` | cable, `none` | `east_haul_road` | [110, 53.2, 300] | to [60, 4.0, 520]; radius 4.0; floor 18.0 |
| `crest_trebuchet` | launcher, `trebuchet` | `east_abutment` | [192, 548] | target [60, 123, 655]; radius 3.5; floor 30.0 |
| `pool_geyser` | launcher, `geyser_vent` | `plunge_pool` | [-110, 540] | target [-30, 32, 584]; radius 3.5; floor 16.0 |
| `spray_thermal` | thermal, `none` | `toe_apron` | [-40, 520] | radius 6.0; height 60.0 |
| `gallery_valve` | valve, `gauge` | `service_ledge` | [-190, 535] | door {"at": [-167, 545], "size": [12, 6, 1], "turn": 0.6}; cache {"at": [-196, 548]} |
| `slot_bulkhead` | cracked_wall, `none` | `corkscrew_slot` | [20, 30] | size [10, 6, 1.4] |
| `domes_cannon` | launcher, `cannon` | `slickrock_domes` | [60, -450] | target [20, 112, -230]; radius 4.0; floor 34.0 |
| `domes_zip` | cable, `none` | `slickrock_domes` | [-58, 130.9, -372] | to [-88, 128.4, -322]; radius 7.0; floor 18.0 |
| `service_lift` | lift, `lift_platform` | `lobber_ledge` | [-185, 432] | radius 4.5; rise 24.0 |

**Time of day: `dawn`.** **Weather:** `dawn_still` (clear, from always); `monsoon_buildup` (monsoon, from clock_tier 2).

## 9. Traversal lines

Measured on runtime head `c3c143ed114d1c7194ace87cbd29039b498f0606`, after merge `76757a256dfc31145f92d06dbb105a629c8584fe` of candidate `d8e507777a8c46ef641b5842e04a83116de9bc83`, using the committed traversal tool at fixed 90 FPS through the CPU queue at nice 10. All seven untraced eight-seed batches are complete, 56 rows. The independent PARK.md section 8 audit judges each gated worst seed and each required median. The floor uses its own row with Rivet as reference. Later page edits preserve these runtime inputs, checked by SHA256 across 391 files. Verdict: PASS+NOTES, evidence level 4. Evidence: `/home/andrew/scratch/w13/sol/kd1-dam-r5/final-sweep/`.

| Band | sable | rivet | kest | tarn | tally | cannon | floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| reached_warden | 8 (worst -), PASS | 8 (worst -), PASS | 8 (worst -), PASS | 8 (worst -), PASS | 8 (worst -), PASS | 8 (worst -), PASS | 8 (worst -), PASS |
| time_to_warden_s | 63.48 (worst 64.99), PASS | 80.9 (worst 80.93), PASS | 80.22 (worst 86.43), PASS | 73.87 (worst 75.7), PASS | 80.27 (worst 80.86), PASS | 84.68 (worst 84.82), PASS | 86.57 (worst 86.57), reported, pilot band, not the floor's |
| segment_s | 27.53, 17.24, 18.7 (worst 28.51), PASS | 38.16, 29.26, 13.48 (worst 38.41), PASS | 30.08, 30.89, 19.24 (worst 31.26), PASS | 31.56, 26.13, 16.17 (worst 33.09), PASS | 32.31, 31.23, 16.71 (worst 32.46), PASS | 29.51, 29.22, 25.93 (worst 30.53), PASS | 39.01, 31.84, 15.7 (worst 39.27), reported, pilot band, not the floor's |
| flow_share | 0.9276 (worst 0.9241), PASS | 0.8445 (worst 0.8354), PASS | 0.7691 (worst 0.758), PASS | 0.9687 (worst 0.9433), PASS | 0.8156 (worst 0.7646), PASS | 0.9273 (worst 0.9003), PASS | 0.7684 (worst 0.7684), reported, pilot band, not the floor's |
| airborne_share | 0.2143 (worst 0.2143, 0.2598), PASS | 0.1633 (worst 0.1633, 0.1697), PASS | 0.3 (worst 0.2157, 0.325), PASS | 0.2128 (worst 0.2081, 0.2219), PASS | 0.1636 (worst 0.1636, 0.1681), PASS | 0.1889 (worst 0.1717, 0.1889), PASS | 0.1162 (worst 0.1082, 0.1162), reported, pilot band, not the floor's |
| dead_stops | 0 (worst 0), PASS | 0 (worst 0), PASS | 0 (worst 0), PASS | 0 (worst 0), PASS | 0 (worst 0), PASS | 0 (worst 0), PASS | 0 (worst 0), PASS |
| peak_speed_mps | 52.66 (worst 52.66); tier3 median 47.31 s, PASS | 42.55 (worst 42.49); tier3 median 10.16 s, PASS | 28.29 (worst 27.5); tier3 median 13.52 s, PASS | 39.7 (worst 38.5); tier3 median 12.62 s, PASS | 44.36 (worst 43.98); tier3 median 8.8 s, PASS | 35.74 (worst 35.74); tier3 median 12.44 s, PASS | 42.99 (worst 42.47); tier3 median 11.67 s, reported, pilot band, not the floor's |
| quiet_max_s | 8.41 (worst 8.41), PASS | 12.14 (worst 12.14), PASS | 11.8 (worst 12.31), PASS | 10.5 (worst 10.84), PASS | 12.06 (worst 12.49), PASS | 10.91 (worst 11.82), PASS | 12.53 (worst 12.58), reported, pilot band, not the floor's |
| max_anchor_gap_m | 36.4 (worst 36.4), PASS | 33.2 (worst 33.2), PASS | 36.8 (worst 36.8), PASS | 35.6 (worst 35.6), PASS | 33.7 (worst 33.7), PASS | 35 (worst 35), PASS | 33.1 (worst 33.1), reported, pilot band, not the floor's |
| distinct_verbs | 5 (worst 5), PASS | 6 (worst 6), PASS | 7 (worst 7), PASS | 6 (worst 6), PASS | 6 (worst 6), PASS | 6 (worst 6), PASS | 5 (worst 5), reported, pilot band, not the floor's |
| length_ratio | 1.65 (worst 1.65, 1.69), PASS | 1.33 (worst 1.32, 1.33), PASS | 1.34 (worst 1.34, 1.34), PASS | 1.38 (worst 1.38, 1.38), PASS | 1.32 (worst 1.32, 1.32), PASS | 1.45 (worst 1.45, 1.45), PASS | 1.38 (worst 1.38, 1.38), reported, pilot band, not the floor's |
| floor | - | - | - | - | - | - | 86.57 (worst 86.57); cap 161.8 s, PASS |
| distinct_lines | 4 mutually distinct, PASS | 4 mutually distinct, PASS | 4 mutually distinct, PASS | 4 mutually distinct, PASS | 4 mutually distinct, PASS | 4 mutually distinct, PASS | - |

| Line | time_to_warden_s: max | segment_s: max | flow_share: min | airborne_share: both | dead_stops: max | peak_speed_mps: min | tier3_s: min | quiet_max_s: max | max_anchor_gap_m: max | distinct_ride_facts: min | length_ratio: both |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| sable | 64.99 (seed 3) | 28.51 (seed 3) | 0.9241 (seed 3) | 0.2143 (seed 1,2,4,5,6,7,8) / 0.2598 (seed 3) | 0 (seed 1,2,3,4,5,6,7,8) | 52.66 (seed 1,2,4,5,6,7,8) | 47.18 (seed 3) | 8.41 (seed 1,2,4,5,6,7,8) | 36.4 (seed 1,2,3,4,5,6,7,8) | 5 (seed 1,2,4,5,6,7,8) | 1.65 (seed 1,2,4,5,6,7,8) / 1.69 (seed 3) |
| rivet | 80.93 (seed 4) | 38.41 (seed 4) | 0.8354 (seed 4) | 0.1633 (seed 1,2,3,5,6,7,8) / 0.1697 (seed 4) | 0 (seed 1,2,3,4,5,6,7,8) | 42.49 (seed 4) | 10.16 (seed 1,2,3,5,6,7,8) | 12.14 (seed 1,2,3,5,6,7,8) | 33.2 (seed 1,2,3,4,5,6,7,8) | 6 (seed 1,2,3,4,5,6,7,8) | 1.32 (seed 4) / 1.33 (seed 1,2,3,5,6,7,8) |
| kest | 86.43 (seed 4) | 31.26 (seed 4) | 0.758 (seed 3) | 0.2157 (seed 2) / 0.325 (seed 4) | 0 (seed 1,2,3,4,5,6,7,8) | 27.5 (seed 4) | 2.93 (seed 4) | 12.31 (seed 3) | 36.8 (seed 1,2,3,4,5,6,7,8) | 7 (seed 1,2,3,4,5,6,7,8) | 1.34 (seed 1,2,3,4,5,6,7,8) / 1.34 (seed 1,2,3,4,5,6,7,8) |
| tarn | 75.7 (seed 6) | 33.09 (seed 6) | 0.9433 (seed 6) | 0.2081 (seed 6) / 0.2219 (seed 3,4) | 0 (seed 1,2,3,4,5,6,7,8) | 38.5 (seed 3,4) | 12.62 (seed 1,2,5,7,8) | 10.84 (seed 6) | 35.6 (seed 1,2,3,4,5,6,7,8) | 6 (seed 1,2,3,4,5,6,7,8) | 1.38 (seed 1,2,3,4,5,6,7,8) / 1.38 (seed 1,2,3,4,5,6,7,8) |
| tally | 80.86 (seed 3) | 32.46 (seed 3) | 0.7646 (seed 3) | 0.1636 (seed 1,2,4,5,6,7,8) / 0.1681 (seed 3) | 0 (seed 1,2,3,4,5,6,7,8) | 43.98 (seed 3) | 8.8 (seed 1,2,4,5,6,7,8) | 12.49 (seed 3) | 33.7 (seed 1,2,3,4,5,6,7,8) | 6 (seed 1,2,3,4,5,6,7,8) | 1.32 (seed 1,2,3,4,5,6,7,8) / 1.32 (seed 1,2,3,4,5,6,7,8) |
| cannon | 84.82 (seed 3) | 30.53 (seed 3) | 0.9003 (seed 3) | 0.1717 (seed 3) / 0.1889 (seed 1,2,5,6,7,8) | 0 (seed 1,2,3,4,5,6,7,8) | 35.74 (seed 1,2,5,6,7,8) | 12.44 (seed 1,2,5,6,7,8) | 11.82 (seed 4) | 35 (seed 1,2,3,4,5,6,7,8) | 6 (seed 1,2,5,6,7,8) | 1.45 (seed 1,2,3,4,5,6,7,8) / 1.45 (seed 1,2,3,4,5,6,7,8) |
| floor | 86.57 (seed 1,2,3,5,7,8) | 39.27 (seed 6) | 0.7684 (seed 1,2,3,5,7,8) | 0.1082 (seed 4) / 0.1162 (seed 1,2,3,5,7,8) | 0 (seed 1,2,3,4,5,6,7,8) | 42.47 (seed 4) | 11.47 (seed 4) | 12.58 (seed 6) | 33.1 (seed 1,2,3,4,5,6,7,8) | 5 (seed 1,2,3,4,5,6,7,8) | 1.38 (seed 1,2,3,4,5,6,7,8) / 1.38 (seed 1,2,3,4,5,6,7,8) |

Raw stops: 0 on 56 rows. Terrain stops: 0. Pack stops: 0. The final runs contain no stop to attribute when this count is zero. Any unresolved final stop counts as terrain under ruling 25. The historical failure and full trace remain preserved below and in the round-4 and round-5 folders.

| Stop classification | sable | rivet | kest | tarn | tally | cannon | floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Terrain stops | 0 on every seed | 0 on every seed | 0 on every seed | 0 on every seed | 0 on every seed | 0 on every seed | 0 on every seed |
| Pack stops | 0 on every seed | 0 on every seed | 0 on every seed | 0 on every seed | 0 on every seed | 0 on every seed | 0 on every seed |

The merged pre-repair Kest seed-4 trace reproduces the round-4 terrain stop at tick 7583, 84.224 s, [54.37,0.94,531.97], and matches all 7875 ticks of the retained read-only enemy probe. Ground/Tiles/Tile5_8 is the only contact in the preceding 90 ticks. Inspection of every authored footprint within 40 m and the baked grid identifies `training_wall_east`'s ridge tip: at [52,532] it contributes 4.5 m, while [54,532] has no ridge contribution, a 4.413469 m rise over a 2 m cell after the apron offset. The stop occurs as the 1 m ball turns into this east face. Round 5 shortens this row only, length 65 to 45 m at unchanged [50,502.5], height 8, width 8 and yaw 0. Its end moves from z 535 to 525. The new committed regression checks the recorded approach against the wall footprint with the ball radius; restoring the old tip in a copied input fails that clearance check. The new solo seed 4 has zero stops and matches its eight-seed batch row. Evidence: `cause.json`, `nearby-rows.json`, `red-baked-grid.log`, `green-baked-grid.log`, `baseline-agreement.json`, `f1-committed-red.log`, `f1-stage-green.log`, `green-kest/` and `final-audit.json` in the round-5 folder.

### Mounted reactor win proof, round 5

| Seed | Outcome | Engage s | Break s | Engage to break s | Damage | After break |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | stages_done | 169.07 | 347.03 | 177.96 | {'ram': 243.8, 'runner': 54.2, 'slam': 297.9, 'stomp': 54.2} | stage 2, exit 355.62 s |
| 2 | stalled | 169.03 | None | None | {'ram': 243.9, 'slam': 243.9} | stage 1, exit 600.0 s |
| 3 | stalled | 157.49 | None | None | {'slam': 162.6, 'stomp': 162.6} | stage 1, exit 600.01 s |

Every completed seed uses the scratch wrapper with a 600 s stage limit before the first driver tick, through the eight-core CPU queue with an 1800 s TERM timeout and 10 s kill grace. The original serial sequence hit its wall-time cap with seeds 1 and 2 complete, exit 124, so it is INCONCLUSIVE for three seeds. Seed 3 completed separately in a fresh output and XDG folder under the same wrapper, policy and queue. The final proof combines these completed per-seed records, with source paths in final-audit.json; this is not presented as an exact replay of the interrupted child. Every seed must reach and engage under ruling 23. A fight that exceeds the limit belongs to WT-PARK. Ruling 26 requires no `get_rid` error; none occurs in any win log. The Warden row and authored dam-face anchor are unchanged.

Three line re-cuts on the KB9 head, each from a traced seed. Sable's line goes straight at `domes_camp` from [-60, -450]: at 40 m/s she passed 16.6 m from the camp and looped for 75 s to come back within the bot's 12 m. Her east turn on the shelf loop moves to [-25, -555], short of `domes_fin_east`. Her wash entry point moves onto the wash axis at [-137, -190]. Cannon's descent turns east at [120, 285] and [145, 350], so she lands east of `powerhouse_stair` and clear of the `rim_zip` head, and her bench points ([150, 410], [156, 470]) keep 10 m off the `canal_lips` ridge.

The shipped pilot lines (`assets/park/park_dam/lines.json`):

```json
{
  "map": "park_dam",
  "stage": 1,
  "pilots": {
    "sable": {"waypoints": ["drop_in", [-260, -660], [-370, -600], [-360, -520], [-180, -545], [-25, -555], [-60, -450], "domes_camp", [-90, -310], [-137, -190], [-110, -60], [-65, 60], [-15, 130], "the_eye", [-15, 250], [-65, 285], [-100, 315], [-109, 410], [-100, 445], [-90, 480], [-45, 530], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}},
    "rivet": {"waypoints": ["drop_in", [-30, -650], [-65, -555], [-250, -530], [-130, -450], "domes_camp", [-58, -372], [-90, -310], [-80, -220], [-55, -60], [-30, 60], [-8, 130], "the_eye", [-12, 250], [-30, 285], [-45, 330], [-42, 370], [-30, 400], [-12, 425], [0, 450], [0, 520], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}},
    "kest": {"waypoints": ["drop_in", [-150, -630], [20, -650], [95, -560], [-5, -450], "domes_camp", [-58, -372], [-90, -310], [-20, -240], [12, -150], [20, 0], [18, 90], [8, 130], "the_eye", [15, 250], [65, 285], [95, 300], [110, 300], [60, 520], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}},
    "tarn": {"waypoints": ["drop_in", [-30, -650], [-65, -555], [-250, -530], [-130, -450], "domes_camp", [-58, -372], [-90, -310], [-80, -220], [-55, -60], [-30, 60], [-8, 130], "the_eye", [-15, 250], [-65, 285], [-100, 315], [-109, 410], [-100, 445], [-90, 480], [-45, 530], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}},
    "tally": {"waypoints": ["drop_in", [-150, -630], [20, -650], [95, -560], [-5, -450], "domes_camp", [-58, -372], [-90, -310], [-140, -220], [-110, -60], [-65, 60], [-15, 130], "the_eye", [-12, 250], [-30, 285], [-45, 360], [-55, 450], [-80, 505], [-45, 545], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}},
    "cannon": {"waypoints": ["drop_in", [-150, -630], [20, -650], [95, -560], [-5, -450], "domes_camp", [-58, -372], [-90, -310], [-20, -240], [12, -150], [20, 0], [18, 90], [8, 130], "the_eye", [15, 250], [65, 285], [120, 285], [145, 350], [150, 410], [156, 470], [170, 540], [100, 560], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}}
  },
  "floor": {"waypoints": ["drop_in", [-30, -650], [-65, -555], [-250, -530], [-130, -450], "domes_camp", [-85, -385], [-95, -330], [-90, -310], [-80, -220], [-55, -60], [-30, 60], [-8, 130], "the_eye", [-15, 250], [-65, 285], [-100, 315], [-109, 410], [-100, 445], [-90, 480], [-45, 530], "landmark"]}
}
```

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
| Leaving the Eye's south mouth, once per run | The Mind's first musical quote (Andrew's Q9), `layer_mind_quote_spillway` from row `eye_mouth` (section 16); the file renders on #12. On its first beat the crest crane's empty jib swings round toward the Eye |
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
| `dam_dedication_plaque` | the dam | Dedicated to the crews who poured the face. The bottom line is scratched out and rewritten in green. |
| `ancient_eye_marks` | the Eye | Marks cut round the Eye's rim, older than the wash. They glow faintly the same green as the face. |
| `ancient_vent_plate` | toe vent pits | A cast plate over a vent: no bolts, no seams. Warm. |
| `ref_cliff_rooms` | cliff rooms | Rooms built into an alcove of the canyon wall, stone laid in mud mortar, sheltered from sun and flood by the overhang above. |
| `ref_viga_beams` | viga span | Roof beams carried from far uplands, their ends left long past the wall. |
| `dam_era_canal_headworks` | canal lips | Headworks 2. The canal feeds fields nobody plants now. Gate oiled weekly anyway. |
| `dam_era_station_marks` | dome 5, the first slalom gate | Traverse, deck to lip. One station per dome, numbered as we went. Chainman rolled it on a barrel. Chief says that is not surveying. The numbers check. |
| `dam_era_gate_flags` | dome 24, the last slalom gate | Flags stay up after the survey. Roll between the pairs and round the odd red one. Nobody asked who for. |
| `dam_era_benchmark` | dome 11, the benchmark | Benchmark, elevation 152.0. Highest station on the shelf. Do not move this dome. |

## 12. What stays from today's stage, and what has no table yet

**Stays on the stage row** (`alpha_defs.gd:69-74`): stage 1, world 1, `warden_family` `reactor`, `ancient` `reactor_relic`, plating 90, hp 650, `beacon_seconds` 25, posture curve 2.0 with `ram_shatters` false, `PRESSURE[0]`, `PACKS` and `ELITE` (`alpha_defs.gd:42-47`, `60`). The display name changes to "Spillway: the dam" and the map id to `park_dam` at KD7 (PARK.md:524, 528, 573). Music stays theme 0, `spillway`.

**Warden band timing.** `SPILLWAY_SKIPPER_S` is 50 to 90 s (`tests/alpha_posture_bands_test.gd:31`), measured as stage clock at the break less the bot's turn to the Warden (`alpha_posture_bands_test.gd:12-13`). The face mounting changes how the ball reaches the core, so KF2 re-measures it on `--table=park` and re-pins with a dated header; the window stays unless the median leaves it. The slice cell in `tests/posture_bands_test.gd:25` and `45-46` is untouched by this stage.

**Tests to re-pin** (names from the `tests/` listing; KD1 confirms which pin stage 1 values): `alpha_posture_bands_test.gd`, `world_one_wardens_test.gd`, `world_warden_flow_test.gd`, `stage_bay_test.gd`, `warden_ring_test.gd`, `hero_warden_assets_test.gd`, and the win proof on `--table=park`.

**Fields today's map carries that the park file has no table for** (park_map fills only the list at PARK.md:216):

| Field | Today | Proposal |
| --- | --- | --- |
| `rescue_sites` | Rivet's cage at (60, -150), `map_spillway.gd:99-100`; Rivet unlocks by it (`class_def.gd:48`) | Must stay. The cage is `rescue_rows` rivet_cage at [60, -594] on the top shelf, at the north foot of dome_7 on flat ground, facing -x so the roll-in comes from the spawn side; moved 6 m from the first pick [60, -600], which sat on the dome's flank (park_rescue_test) |
| `vault` | (-5, -130), `map_spillway.gd:67` | A plinth at [-260, -520] on the shelf's west side, off the fall line with a downhill way back (`stage_map.gd:26-27`) |
| `unique_events` | `scrap_stampede`, `hold_the_relay`, `map_spillway.gd:86-97` | Retire into this page's event rows and the activities; the stampede's hauler becomes stage 2's `hauler_bounty` |
| `scrap_lines` | four short lines, `map_spillway.gd:80-85` | Built 9 Nov (ruling cd) as `scrap_trail`: the `scrap` row on the floor line of `assets/park/park_dam/lines.json`, laid to the beat by `scrap_field.gd` `lay_trail`. `scrap_lines` stays empty, so no gears and no fabricator hoops |
| `basin` | the flood bowl, `map_spillway.gd:77-78` | Replaced by `plunge_pool_flood` |
| `beacon_floor` | 15 m, `map_spillway.gd:66` | The toe apron's height, read from the bake |

## 13. The park file

Shipped 2026-10-11 as `src/world/park/park_dam.json` and re-cut the same day for KB9's runtime placement (section 5), with `saguaro_26` added 2026-10-12 for the density rule (136 park rows, 6 event rows, 5 homes, 9 contraptions, 3 activity rows), baked to `assets/park/park_dam/` with its graph. The draft JSON that stood here is retired; sections 5 to 8 follow the shipped file. Measured pockets (`assets/park/park_dam/graph.json`, PARK.md 2.12):

| Pocket | Role | Door | door_m | detour_m | d_spawn | d_beacon | sight_ok | pay.rarities |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| domes_camp | online | [-48, -392] | 0 | 0 | 344 | 1016 | True | ['common'] |
| rim_cache | reward | [-208, 400] | 403 | 403 | 1161 | 367 | True | ['rare'] |
| bench_altar | risk | [208, 248] | 251 | 251 | 1137 | 445 | True | ['common', 'rare'] |
| gallery_valve | hidden | [-168, 544] | 250 | 268 | 1394 | 196 | True | [] |

The graph has no breaches, `beacon_ok=true` and `spawn.run=true`. Spawn to beacon is 1352 m by path. All pocket clear rings are clear. The 2026-10-19 `rim_cache` move (section 15) puts its door at [-208, 400], 367 m from the beacon. Reported targets: reward_ratio 0.859, full_visit_ratio 1.805. Since ruling ac (26 Oct) reward_ratio is information only, with no target (DECISIONS.md section 8).

The shipped park file:

```json
{
 "schema": "scrapkeep-park/1",
 "map": "park_dam",
 "size_m": 1600,
 "time_of_day": "dawn",
 "spawn": {"at": [-150, -690], "heading_deg": 20},
 "play_rect": [-760, -780, 1520, 1540],
 "landmark": {"id": "spillway_dam", "kind": "dam", "at": [0, 620], "size": [120, 120, 320], "yaw_deg": 180, "recipe": "landmark_dam", "budget": "hero_landmark", "sight_top": [0, 141, 640], "sight_share": 0.85, "beacon": [0, 575], "reach_m": 30, "warden": {"family": "reactor", "mounting": "dam_face", "anchor": [0, 22, 590], "path": [], "hardpoints": 3, "harpoon_anchor": true}, "bay_dock": {"at": [0, 467], "facing_deg": 0}, "gate_slots": [{"at": [-16, 528], "facing_deg": 0}, {"at": [0, 528], "facing_deg": 0}, {"at": [16, 528], "facing_deg": 0}], "light": "ancient_beam", "music": "landmark_hum", "fragment": "dam_dedication_plaque"},
 "waymarks": ["drop_in", "domes_camp", "the_eye", "landmark"],
 "routes": [
  {"id": "shelf", "from": "drop_in", "to": "shelf_lip", "via": ["top_shelf_deck", "slickrock_domes"]},
  {"id": "west_wash_run", "from": "shelf_lip", "to": "the_eye", "via": ["west_wash"]},
  {"id": "upper_slot_run", "from": "shelf_lip", "to": "the_eye", "via": ["upper_slot"]},
  {"id": "corkscrew_run", "from": "shelf_lip", "to": "the_eye", "via": ["corkscrew_slot"]},
  {"id": "pool_floor", "from": "the_eye", "to": "toe_apron", "via": ["the_eye", "west_rim_bench", "spillway_tunnel", "outlet_bucket", "plunge_pool"]},
  {"id": "pool_rim", "from": "the_eye", "to": "toe_apron", "via": ["the_eye", "west_rim_bench", "spillway_tunnel", "outlet_bucket", "service_ledge", "plunge_pool"]},
  {"id": "bucket_flight", "from": "the_eye", "to": "toe_apron", "via": ["the_eye", "west_rim_bench", "spillway_tunnel", "outlet_bucket"]},
  {"id": "ledge_line", "from": "the_eye", "to": "toe_apron", "via": ["the_eye", "west_rim_bench", "cliff_rooms_west", "viga_span", "service_ledge"]},
  {"id": "ledge_drop", "from": "the_eye", "to": "toe_apron", "via": ["the_eye", "west_rim_bench", "service_ledge", "plunge_pool"]},
  {"id": "incline_line", "from": "the_eye", "to": "toe_apron", "via": ["the_eye", "construction_incline", "river_canyon", "tailwater_bar"]},
  {"id": "canal_run", "from": "the_eye", "to": "toe_apron", "via": ["the_eye", "pipeline_bridge", "east_bench_flats", "canal_lips", "east_haul_road"]},
  {"id": "dropship_ramp", "from": "the_eye", "to": "toe_apron", "via": ["the_eye", "pipeline_bridge", "east_bench_flats"]},
  {"id": "crest_line", "from": "the_eye", "to": "toe_apron", "via": ["the_eye", "pipeline_bridge", "east_bench_flats", "east_abutment", "crest_rail"]},
  {"id": "face", "from": "toe_apron", "to": "landmark", "via": ["toe_apron", "dam_face_quarter", "gate_piers"]},
  {"id": "powerhouse_floor", "from": "toe_apron", "to": "landmark", "via": ["toe_apron", "powerhouse", "dam_face_quarter", "gate_piers"]},
  {"id": "roof_ramp_line", "from": "toe_apron", "to": "landmark", "via": ["toe_apron", "powerhouse", "powerhouse_roof_ramp", "dam_face_quarter", "gate_piers"]}
 ],
 "park_rows": [
  {"id": "canyon_country", "element": "ground", "landform": "slickrock", "society": "none", "at": [0, 0], "y": null, "size": [1600, 100, 1600], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "shelf_rise", "element": "ground", "landform": "slickrock", "society": "none", "at": [0, -305], "y": null, "size": [990, 50, 1600], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "ramp", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "shelf_sag", "element": "ground", "landform": "slickrock", "society": "none", "at": [0, -305], "y": null, "size": [990, 3, 1600], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "bowl", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "shelf_sag_corner_1", "element": "ground", "landform": "slickrock", "society": "none", "at": [-650, -720], "y": null, "size": [320, 3, 640], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "bowl", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "shelf_sag_corner_2", "element": "ground", "landform": "slickrock", "society": "none", "at": [650, -720], "y": null, "size": [320, 3, 640], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "bowl", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "shelf_sag_corner_3", "element": "ground", "landform": "slickrock", "society": "none", "at": [-650, 110], "y": null, "size": [320, 3, 640], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "bowl", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "shelf_sag_corner_4", "element": "ground", "landform": "slickrock", "society": "none", "at": [650, 110], "y": null, "size": [320, 3, 640], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "bowl", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "river_canyon", "element": "ground", "landform": "river_canyon", "society": "none", "at": [0, 415], "y": null, "size": [450, -100, 400], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "plateau", "hole": false, "budget": "landform", "routes": ["incline_line"], "fragment": ""},
  {"id": "canyon_descent", "element": "ground", "landform": "river_canyon", "society": "none", "at": [0, 305], "y": null, "size": [230, 100, 400], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "ramp", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "top_shelf_deck", "element": "drop", "landform": "slickrock", "society": "dam_era", "at": [-150, -690], "y": null, "size": [44, 10, 30], "yaw_deg": 30, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:drop", "stamp": "mesa", "hole": false, "budget": "landform", "routes": ["shelf"], "fragment": "dam_era_survey_deck"},
  {"id": "slickrock_domes", "element": "bank", "landform": "slickrock", "society": "none", "at": [-110, -520], "y": null, "size": [260, 1, 240], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_hop", "home": "", "recipe": "greybox:bank", "stamp": "bowl", "hole": false, "budget": "landform", "routes": ["shelf"], "fragment": ""},
  {"id": "dome_1", "element": "bank", "landform": "slickrock", "society": "none", "at": [-230, -690], "y": null, "size": [40, 16, 40], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_hop", "home": "", "recipe": "greybox:bank", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "dome_2", "element": "bank", "landform": "slickrock", "society": "none", "at": [-80, -700], "y": null, "size": [40, 16, 40], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_hop", "home": "", "recipe": "greybox:bank", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "dome_3", "element": "bank", "landform": "slickrock", "society": "none", "at": [-300, -560], "y": null, "size": [40, 16, 40], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_hop", "home": "", "recipe": "greybox:bank", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "dome_4", "element": "bank", "landform": "slickrock", "society": "none", "at": [-190, -610], "y": null, "size": [40, 16, 40], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_hop", "home": "", "recipe": "greybox:bank", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "dome_5", "element": "bank", "landform": "slickrock", "society": "none", "at": [-110, -590], "y": null, "size": [40, 16, 40], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_hop", "home": "", "recipe": "greybox:bank", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "dome_6", "element": "bank", "landform": "slickrock", "society": "none", "at": [-30, -600], "y": null, "size": [40, 16, 40], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_hop", "home": "", "recipe": "greybox:bank", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "dome_7", "element": "bank", "landform": "slickrock", "society": "none", "at": [60, -620], "y": null, "size": [40, 16, 40], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_hop", "home": "", "recipe": "greybox:bank", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "dome_8", "element": "bank", "landform": "slickrock", "society": "none", "at": [110, -560], "y": null, "size": [40, 16, 40], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_hop", "home": "", "recipe": "greybox:bank", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "dome_9", "element": "bank", "landform": "slickrock", "society": "none", "at": [-330, -665], "y": null, "size": [40, 16, 40], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_hop", "home": "", "recipe": "greybox:bank", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "dome_10", "element": "bank", "landform": "slickrock", "society": "none", "at": [-325, -560], "y": null, "size": [40, 16, 40], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_hop", "home": "", "recipe": "greybox:bank", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "dome_11", "element": "bank", "landform": "slickrock", "society": "none", "at": [-405, -560], "y": null, "size": [40, 16, 40], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_hop", "home": "", "recipe": "greybox:bank", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "dome_12", "element": "bank", "landform": "slickrock", "society": "none", "at": [-290, -690], "y": null, "size": [40, 16, 40], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_hop", "home": "", "recipe": "greybox:bank", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "dome_13", "element": "bank", "landform": "slickrock", "society": "none", "at": [-250, -500], "y": null, "size": [40, 16, 40], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_hop", "home": "", "recipe": "greybox:bank", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "dome_14", "element": "bank", "landform": "slickrock", "society": "none", "at": [10, -590], "y": null, "size": [40, 16, 40], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_hop", "home": "", "recipe": "greybox:bank", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "dome_15", "element": "bank", "landform": "slickrock", "society": "none", "at": [-95, -480], "y": null, "size": [40, 16, 40], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_hop", "home": "", "recipe": "greybox:bank", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "dome_16", "element": "bank", "landform": "slickrock", "society": "none", "at": [-190, -630], "y": null, "size": [40, 16, 40], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_hop", "home": "", "recipe": "greybox:bank", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "dome_17", "element": "bank", "landform": "slickrock", "society": "none", "at": [-215, -480], "y": null, "size": [40, 16, 40], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_hop", "home": "", "recipe": "greybox:bank", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "dome_18", "element": "bank", "landform": "slickrock", "society": "none", "at": [-140, -505], "y": null, "size": [40, 16, 40], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_hop", "home": "", "recipe": "greybox:bank", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "dome_19", "element": "bank", "landform": "slickrock", "society": "none", "at": [-50, -510], "y": null, "size": [40, 16, 40], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_hop", "home": "", "recipe": "greybox:bank", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "dome_20", "element": "bank", "landform": "slickrock", "society": "none", "at": [60, -470], "y": null, "size": [40, 16, 40], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_hop", "home": "", "recipe": "greybox:bank", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "dome_21", "element": "bank", "landform": "slickrock", "society": "none", "at": [-170, -420], "y": null, "size": [40, 16, 40], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_hop", "home": "", "recipe": "greybox:bank", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "dome_22", "element": "bank", "landform": "slickrock", "society": "none", "at": [-100, -380], "y": null, "size": [40, 16, 40], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_hop", "home": "", "recipe": "greybox:bank", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "dome_23", "element": "bank", "landform": "slickrock", "society": "none", "at": [10, -400], "y": null, "size": [40, 16, 40], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_hop", "home": "", "recipe": "greybox:bank", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "dome_24", "element": "bank", "landform": "slickrock", "society": "none", "at": [-140, -330], "y": null, "size": [40, 16, 40], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_hop", "home": "", "recipe": "greybox:bank", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "dome_25", "element": "bank", "landform": "slickrock", "society": "none", "at": [-35, -330], "y": null, "size": [40, 16, 40], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_hop", "home": "", "recipe": "greybox:bank", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "shelf_lip", "element": "kicker", "landform": "slickrock", "society": "none", "at": [-90, -300], "y": null, "size": [20, 0, 30], "yaw_deg": 0, "verb": "launch", "ride_fact": "kicker_launch", "home": "", "recipe": "greybox:kicker", "stamp": "plateau", "hole": false, "budget": "detail", "routes": ["shelf"], "fragment": ""},
  {"id": "shelf_lip_ramp", "element": "ground", "landform": "slickrock", "society": "none", "at": [-90, -300], "y": null, "size": [20, 6, 30], "yaw_deg": 180, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "ramp", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "west_wash", "element": "half_pipe", "landform": "arroyo", "society": "dam_era", "at": [-102.5, -75.0], "y": null, "size": [397.0, 10, 44], "yaw_deg": 16.8, "verb": "pump", "ride_fact": "ride_chute", "home": "culvert_chasers", "recipe": "half_pipe_concrete", "stamp": "wash", "hole": false, "budget": "landform", "routes": ["west_wash_run"], "fragment": "dam_era_wash_liner"},
  {"id": "upper_slot", "element": "flow_line", "landform": "slot_canyon", "society": "none", "at": [-45.0, -75.0], "y": null, "size": [384.7, 2, 30], "yaw_deg": 9.0, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "slot_canyon_flow", "stamp": "wash", "hole": false, "budget": "landform", "routes": ["upper_slot_run"], "fragment": ""},
  {"id": "corkscrew_slot", "element": "flow_line", "landform": "slot_canyon", "society": "none", "at": [15.0, -75.0], "y": null, "size": [380.1, 2, 34], "yaw_deg": 1.5, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "slot_canyon_flow", "stamp": "wash", "hole": false, "budget": "landform", "routes": ["corkscrew_run"], "fragment": ""},
  {"id": "wash_fin_west", "element": "elevated_line", "landform": "slickrock", "society": "none", "at": [-157.5, -70.0], "y": null, "size": [358.9, 26, 22], "yaw_deg": 18.7, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "greybox:elevated_line", "stamp": "ridge", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "slot_fin_west", "element": "elevated_line", "landform": "slickrock", "society": "none", "at": [-74.2, -55.6], "y": null, "size": [300.0, 26, 22], "yaw_deg": 14.0, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "greybox:elevated_line", "stamp": "ridge", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "slot_fin_east", "element": "elevated_line", "landform": "slickrock", "society": "none", "at": [-18.5, -75.0], "y": null, "size": [331.6, 26, 22], "yaw_deg": 5.7, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "greybox:elevated_line", "stamp": "ridge", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "slot_fin_far", "element": "elevated_line", "landform": "slickrock", "society": "none", "at": [53.5, -70.0], "y": null, "size": [340.0, 26, 22], "yaw_deg": -0.5, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "greybox:elevated_line", "stamp": "ridge", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "domes_fin_west", "element": "elevated_line", "landform": "slickrock", "society": "none", "at": [-400.0, -520.0], "y": null, "size": [40.0, 20, 8], "yaw_deg": 0.0, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "greybox:elevated_line", "stamp": "ridge", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "domes_fin_mid", "element": "elevated_line", "landform": "slickrock", "society": "none", "at": [-85.0, -455.0], "y": null, "size": [30.0, 20, 8], "yaw_deg": 0.0, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "greybox:elevated_line", "stamp": "ridge", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "domes_fin_east", "element": "elevated_line", "landform": "slickrock", "society": "none", "at": [55.0, -547.5], "y": null, "size": [15.0, 20, 8], "yaw_deg": 0.0, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "greybox:elevated_line", "stamp": "ridge", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "domes_kicker", "element": "kicker", "landform": "slickrock", "society": "none", "at": [-160, -468], "y": null, "size": [20, 0, 24], "yaw_deg": 59, "verb": "launch", "ride_fact": "kicker_launch", "home": "", "recipe": "greybox:kicker", "stamp": "plateau", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "domes_kicker_ramp", "element": "ground", "landform": "slickrock", "society": "none", "at": [-160, -468], "y": null, "size": [20, 5, 24], "yaw_deg": 239, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "ramp", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "wash_kicker", "element": "kicker", "landform": "arroyo", "society": "dam_era", "at": [-110, -80], "y": null, "size": [20, 0, 24], "yaw_deg": 17, "verb": "launch", "ride_fact": "kicker_launch", "home": "", "recipe": "greybox:kicker", "stamp": "plateau", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "wash_kicker_ramp", "element": "ground", "landform": "arroyo", "society": "dam_era", "at": [-110, -80], "y": null, "size": [20, 5, 24], "yaw_deg": 197, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "ramp", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "upper_slot_step", "element": "kicker", "landform": "slot_canyon", "society": "none", "at": [-53, -80], "y": null, "size": [20, 0, 22], "yaw_deg": 9, "verb": "launch", "ride_fact": "kicker_launch", "home": "", "recipe": "greybox:kicker", "stamp": "plateau", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "upper_slot_step_ramp", "element": "ground", "landform": "slot_canyon", "society": "none", "at": [-53, -80], "y": null, "size": [20, 5, 22], "yaw_deg": 189, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "ramp", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "corkscrew_step", "element": "kicker", "landform": "slot_canyon", "society": "none", "at": [16, -110], "y": null, "size": [20, 0, 22], "yaw_deg": 4, "verb": "launch", "ride_fact": "kicker_launch", "home": "", "recipe": "greybox:kicker", "stamp": "plateau", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "corkscrew_step_ramp", "element": "ground", "landform": "slot_canyon", "society": "none", "at": [16, -110], "y": null, "size": [20, 5, 22], "yaw_deg": 184, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "ramp", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "eye_fin_west", "element": "elevated_line", "landform": "slickrock", "society": "none", "at": [-142.0, 150.0], "y": null, "size": [236.0, 20, 24], "yaw_deg": 90.0, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "greybox:elevated_line", "stamp": "ridge", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "eye_fin_east", "element": "elevated_line", "landform": "slickrock", "society": "none", "at": [142.0, 150.0], "y": null, "size": [236.0, 20, 24], "yaw_deg": 90.0, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "greybox:elevated_line", "stamp": "ridge", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "the_eye", "element": "tunnel", "landform": "slickrock", "society": "none", "at": [0, 165], "y": null, "size": [50, 5, 30], "yaw_deg": 180, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "greybox:tunnel", "stamp": "ramp", "hole": false, "budget": "park_large", "routes": ["pool_floor", "pool_rim", "bucket_flight", "ledge_line", "ledge_drop", "incline_line", "canal_run", "dropship_ramp", "crest_line"], "fragment": "ancient_eye_marks"},
  {"id": "eye_chute_west", "element": "elevated_line", "landform": "river_canyon", "society": "none", "at": [-28.0, 224.0], "y": null, "size": [52.0, 15, 8], "yaw_deg": 0.0, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "greybox:elevated_line", "stamp": "ridge", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "eye_chute_east", "element": "elevated_line", "landform": "river_canyon", "society": "none", "at": [28.0, 224.0], "y": null, "size": [52.0, 15, 8], "yaw_deg": 0.0, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "greybox:elevated_line", "stamp": "ridge", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "pool_rock", "element": "elevated_line", "landform": "dam_face", "society": "none", "at": [-120, 500], "y": null, "size": [20, 14, 20], "yaw_deg": 0, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "greybox:elevated_line", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "pool_pillar", "element": "elevated_line", "landform": "dam_face", "society": "dam_era", "at": [-62, 560], "y": null, "size": [16, 14, 16], "yaw_deg": 0, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "greybox:elevated_line", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "west_lane_fin", "element": "elevated_line", "landform": "mesa_rim", "society": "none", "at": [-70.0, 392.5], "y": null, "size": [155.0, 26, 20], "yaw_deg": 0.0, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "greybox:elevated_line", "stamp": "ridge", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "east_lane_fin", "element": "elevated_line", "landform": "mesa_rim", "society": "none", "at": [70.0, 392.5], "y": null, "size": [155.0, 26, 20], "yaw_deg": 0.0, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "greybox:elevated_line", "stamp": "ridge", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "incline_spine", "element": "elevated_line", "landform": "mesa_rim", "society": "dam_era", "at": [15.0, 370.0], "y": null, "size": [100.0, 20, 16], "yaw_deg": 0.0, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "greybox:elevated_line", "stamp": "ridge", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "training_wall_west", "element": "elevated_line", "landform": "dam_face", "society": "dam_era", "at": [-28.0, 492.5], "y": null, "size": [55.0, 14, 8], "yaw_deg": 0.0, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "greybox:elevated_line", "stamp": "ridge", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "training_wall_east", "element": "elevated_line", "landform": "dam_face", "society": "dam_era", "at": [50.0, 502.5], "y": null, "size": [45.0, 8, 8], "yaw_deg": 0.0, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "greybox:elevated_line", "stamp": "ridge", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "west_rim_bench", "element": "bank", "landform": "mesa_rim", "society": "dam_era", "at": [-235, 300], "y": null, "size": [220, 4, 60], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:bank", "stamp": "bowl", "hole": false, "budget": "landform", "routes": ["pool_floor", "pool_rim", "bucket_flight", "ledge_line", "ledge_drop"], "fragment": "dam_era_overflow_channel"},
  {"id": "spillway_tunnel", "element": "tunnel", "landform": "spillway_tunnel", "society": "dam_era", "at": [-150, 330], "y": null, "size": [200, 4, 60], "yaw_deg": 0, "verb": "drop", "ride_fact": "ride_drop", "home": "outlet_brutes", "recipe": "greybox:tunnel", "stamp": "wash", "hole": false, "budget": "park_large", "routes": ["pool_floor", "pool_rim", "bucket_flight"], "fragment": "dam_era_tunnel_gauge"},
  {"id": "outlet_bucket", "element": "kicker", "landform": "spillway_tunnel", "society": "dam_era", "at": [-100, 445], "y": null, "size": [16, 0, 24], "yaw_deg": 15, "verb": "launch", "ride_fact": "kicker_launch", "home": "", "recipe": "greybox:kicker", "stamp": "plateau", "hole": false, "budget": "detail", "routes": ["pool_floor", "pool_rim", "bucket_flight"], "fragment": ""},
  {"id": "outlet_bucket_ramp", "element": "ground", "landform": "spillway_tunnel", "society": "dam_era", "at": [-100, 445], "y": null, "size": [16, 4, 24], "yaw_deg": 195, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "ramp", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "cliff_rooms_west", "element": "elevated_line", "landform": "cliff_dwelling", "society": "ancestral_puebloan", "at": [-165, 330], "y": null, "size": [160, 8, 16], "yaw_deg": 0, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "greybox:elevated_line", "stamp": "ridge", "hole": false, "budget": "landform", "routes": ["ledge_line"], "fragment": "ref_cliff_rooms"},
  {"id": "viga_span", "element": "anchor_field", "landform": "cliff_dwelling", "society": "ancestral_puebloan", "at": [-190, 425], "y": null, "size": [30, 4, 16], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "detail", "routes": ["ledge_line"], "fragment": "ref_viga_beams"},
  {"id": "service_ledge", "element": "ledge", "landform": "mesa_rim", "society": "dam_era", "at": [-180, 520], "y": null, "size": [90, 24, 30], "yaw_deg": 0, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "greybox:ledge", "stamp": "plateau", "hole": false, "budget": "landform", "routes": ["ledge_line", "pool_rim", "ledge_drop"], "fragment": "dam_era_ledge_stencil"},
  {"id": "lobber_ledge", "element": "ledge", "landform": "mesa_rim", "society": "dam_era", "at": [-185, 455], "y": null, "size": [30, 24, 26], "yaw_deg": 0, "verb": "roll", "ride_fact": "ride_ledge", "home": "ledge_lobbers", "recipe": "greybox:ledge", "stamp": "plateau", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "construction_incline", "element": "drop", "landform": "mesa_rim", "society": "dam_era", "at": [0, 330], "y": null, "size": [230, 1, 100], "yaw_deg": 180, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:drop", "stamp": "ramp", "hole": false, "budget": "landform", "routes": ["incline_line"], "fragment": "dam_era_incline_tally"},
  {"id": "tailwater_bar", "element": "flow_line", "landform": "dry_wash", "society": "none", "at": [-20, 460], "y": null, "size": [70, 2, 60], "yaw_deg": 0, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "greybox:flow_line", "stamp": "wash", "hole": false, "budget": "landform", "routes": ["incline_line"], "fragment": ""},
  {"id": "pipeline_bridge", "element": "grind_line", "landform": "pipeline", "society": "dam_era", "at": [130, 260], "y": null, "size": [80, 3, 6], "yaw_deg": 0, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "ridge", "hole": false, "budget": "landform", "routes": ["canal_run", "dropship_ramp", "crest_line"], "fragment": "dam_era_bridge_plate"},
  {"id": "east_bench_flats", "element": "ground", "landform": "slickrock", "society": "none", "at": [165, 475], "y": null, "size": [90, 6, 70], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "dropship_winches", "recipe": "", "stamp": "", "hole": false, "budget": "landform", "routes": ["canal_run", "dropship_ramp", "crest_line"], "fragment": ""},
  {"id": "canal_lips", "element": "grind_line", "landform": "canal", "society": "dam_era", "at": [170, 380], "y": null, "size": [120, 3, 8], "yaw_deg": 0, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "ridge", "hole": false, "budget": "landform", "routes": ["canal_run"], "fragment": "dam_era_canal_headworks"},
  {"id": "east_haul_road", "element": "drop", "landform": "mesa_rim", "society": "dam_era", "at": [135, 330], "y": null, "size": [220, 1, 110], "yaw_deg": 180, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:drop", "stamp": "ramp", "hole": false, "budget": "landform", "routes": ["canal_run"], "fragment": "dam_era_haul_sign"},
  {"id": "east_abutment", "element": "ledge", "landform": "dam_face", "society": "dam_era", "at": [170, 585], "y": null, "size": [60, 16, 50], "yaw_deg": 180, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "greybox:ledge", "stamp": "ramp", "hole": false, "budget": "landform", "routes": ["crest_line"], "fragment": ""},
  {"id": "eye_fall_spire_west", "element": "elevated_line", "landform": "river_canyon", "society": "none", "at": [-120, 245], "y": null, "size": [30, 24, 30], "yaw_deg": 0, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "greybox:elevated_line", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "eye_fall_spire_east", "element": "elevated_line", "landform": "river_canyon", "society": "none", "at": [120, 245], "y": null, "size": [30, 24, 30], "yaw_deg": 0, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "greybox:elevated_line", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "apron_kicker", "element": "kicker", "landform": "dry_wash", "society": "none", "at": [0, 448], "y": null, "size": [20, 0, 26], "yaw_deg": 0, "verb": "launch", "ride_fact": "kicker_launch", "home": "", "recipe": "greybox:kicker", "stamp": "plateau", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "apron_kicker_ramp", "element": "ground", "landform": "dry_wash", "society": "none", "at": [0, 448], "y": null, "size": [20, 5, 26], "yaw_deg": 180, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "ramp", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "plunge_pool", "element": "bowl", "landform": "dam_face", "society": "dam_era", "at": [-85, 515], "y": null, "size": [110, 8, 110], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:bowl", "stamp": "bowl", "hole": false, "budget": "landform", "routes": ["pool_floor", "pool_rim", "ledge_drop"], "fragment": ""},
  {"id": "toe_apron", "element": "bank", "landform": "dam_face", "society": "dam_era", "at": [0, 520], "y": null, "size": [160, 2, 140], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:bank", "stamp": "bowl", "hole": false, "budget": "landform", "routes": ["face", "powerhouse_floor", "roof_ramp_line"], "fragment": ""},
  {"id": "powerhouse", "element": "ledge", "landform": "dam_face", "society": "dam_era", "at": [120, 515], "y": null, "size": [60, 20, 40], "yaw_deg": 0, "verb": "roll", "ride_fact": "ride_ledge", "home": "powerhouse_trappers", "recipe": "greybox:ledge", "stamp": "plateau", "hole": false, "budget": "landform", "routes": ["powerhouse_floor", "roof_ramp_line"], "fragment": "dam_era_powerhouse_log"},
  {"id": "powerhouse_stair", "element": "ground", "landform": "dam_face", "society": "dam_era", "at": [120, 455], "y": null, "size": [60, 20, 16], "yaw_deg": 180, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "ramp", "hole": false, "budget": "landform", "routes": ["powerhouse_floor", "roof_ramp_line"], "fragment": ""},
  {"id": "powerhouse_roof_ramp", "element": "bank", "landform": "dam_face", "society": "dam_era", "at": [92, 515], "y": null, "size": [60, 2, 16], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:bank", "stamp": "bowl", "hole": false, "budget": "detail", "routes": ["roof_ramp_line"], "fragment": ""},
  {"id": "toe_vent_pits", "element": "bowl", "landform": "dam_face", "society": "ancient", "at": [190, 430], "y": null, "size": [50, 3, 50], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:bowl", "stamp": "bowl", "hole": false, "budget": "detail", "routes": [], "fragment": "ancient_vent_plate"},
  {"id": "dam_face_quarter", "element": "bank", "landform": "dam_face", "society": "dam_era", "at": [0, 627.5], "y": null, "size": [25, 30, 400], "yaw_deg": 180, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:bank", "stamp": "ramp", "hole": false, "budget": "landform", "routes": ["face", "powerhouse_floor", "roof_ramp_line"], "fragment": ""},
  {"id": "gate_piers", "element": "anchor_field", "landform": "dam_face", "society": "dam_era", "at": [0, 605], "y": null, "size": [10, 8, 44], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "detail", "routes": ["face", "powerhouse_floor", "roof_ramp_line"], "fragment": ""},
  {"id": "gate_row_apron", "element": "bank", "landform": "dam_face", "society": "dam_era", "at": [0, 540], "y": null, "size": [30, 2, 60], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:bank", "stamp": "bowl", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "crest_rail", "element": "rail", "landform": "dam_face", "society": "dam_era", "at": [0, 655], "y": null, "size": [300, 1, 4], "yaw_deg": 90, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:rail", "stamp": "ridge", "hole": false, "budget": "detail", "routes": ["crest_line"], "fragment": ""},
  {"id": "hoodoo_1", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-640, -640], "y": null, "size": [320, 2, 320], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "saguaro_2", "element": "anchor_field", "landform": "saguaro_stand", "society": "none", "at": [-640, -330], "y": null, "size": [320, 2, 320], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_3", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-640, -20], "y": null, "size": [320, 2, 320], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "saguaro_4", "element": "anchor_field", "landform": "saguaro_stand", "society": "none", "at": [-640, 290], "y": null, "size": [320, 2, 320], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_5", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-640, 600], "y": null, "size": [320, 2, 320], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "saguaro_6", "element": "anchor_field", "landform": "saguaro_stand", "society": "none", "at": [-470, -640], "y": null, "size": [320, 2, 80], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_7", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-350, -330], "y": null, "size": [320, 2, 320], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "saguaro_8", "element": "anchor_field", "landform": "saguaro_stand", "society": "none", "at": [-350, -20], "y": null, "size": [320, 2, 320], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_9", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-350, 290], "y": null, "size": [320, 2, 320], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "saguaro_10", "element": "anchor_field", "landform": "saguaro_stand", "society": "none", "at": [-350, 600], "y": null, "size": [320, 2, 320], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_11", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [350, -640], "y": null, "size": [320, 2, 320], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "saguaro_12", "element": "anchor_field", "landform": "saguaro_stand", "society": "none", "at": [350, -330], "y": null, "size": [320, 2, 320], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_13", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [350, -20], "y": null, "size": [320, 2, 320], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "saguaro_14", "element": "anchor_field", "landform": "saguaro_stand", "society": "none", "at": [350, 290], "y": null, "size": [320, 2, 320], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_15", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [350, 600], "y": null, "size": [320, 2, 320], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "saguaro_16", "element": "anchor_field", "landform": "saguaro_stand", "society": "none", "at": [640, -640], "y": null, "size": [320, 2, 320], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_17", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [640, -330], "y": null, "size": [320, 2, 320], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "saguaro_18", "element": "anchor_field", "landform": "saguaro_stand", "society": "none", "at": [640, -20], "y": null, "size": [320, 2, 320], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_19", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [640, 290], "y": null, "size": [320, 2, 320], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "saguaro_20", "element": "anchor_field", "landform": "saguaro_stand", "society": "none", "at": [640, 600], "y": null, "size": [320, 2, 320], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_21", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [0, 730], "y": null, "size": [320, 2, 320], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "saguaro_22", "element": "anchor_field", "landform": "saguaro_stand", "society": "none", "at": [230, -700], "y": null, "size": [320, 2, 160], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_23", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [245, -420], "y": null, "size": [320, 2, 190], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "saguaro_24", "element": "anchor_field", "landform": "saguaro_stand", "society": "none", "at": [170, -140], "y": null, "size": [320, 2, 320], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_25", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-60, -750], "y": null, "size": [60, 2, 320], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "saguaro_26", "element": "anchor_field", "landform": "saguaro_stand", "society": "none", "at": [-290, -755], "y": null, "size": [70, 2, 380], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_stack_1", "element": "ground", "landform": "hoodoo_field", "society": "none", "at": [260, -560], "y": null, "size": [26, 9, 26], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_stack_2", "element": "ground", "landform": "hoodoo_field", "society": "none", "at": [330, -450], "y": null, "size": [26, 9, 26], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_stack_3", "element": "ground", "landform": "hoodoo_field", "society": "none", "at": [420, -620], "y": null, "size": [26, 9, 26], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_stack_4", "element": "ground", "landform": "hoodoo_field", "society": "none", "at": [300, -300], "y": null, "size": [26, 9, 26], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_stack_5", "element": "ground", "landform": "hoodoo_field", "society": "none", "at": [450, -380], "y": null, "size": [26, 9, 26], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_stack_6", "element": "ground", "landform": "hoodoo_field", "society": "none", "at": [560, -520], "y": null, "size": [26, 9, 26], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_stack_7", "element": "ground", "landform": "hoodoo_field", "society": "none", "at": [250, -150], "y": null, "size": [26, 9, 26], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_stack_8", "element": "ground", "landform": "hoodoo_field", "society": "none", "at": [-520, -520], "y": null, "size": [26, 9, 26], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_stack_9", "element": "ground", "landform": "hoodoo_field", "society": "none", "at": [-560, -300], "y": null, "size": [26, 9, 26], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_stack_10", "element": "ground", "landform": "hoodoo_field", "society": "none", "at": [-480, -120], "y": null, "size": [26, 9, 26], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "hoodoo_stack_11", "element": "ground", "landform": "hoodoo_field", "society": "none", "at": [-640, -640], "y": null, "size": [26, 9, 26], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "east_rim_bench", "element": "bank", "landform": "mesa_rim", "society": "none", "at": [235, 260], "y": null, "size": [160, 4, 60], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:bank", "stamp": "bowl", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "sable_shelf_runout_anchor", "element": "anchor_field", "landform": "saguaro_stand", "society": "none", "at": [-100.0, -236.0], "y": null, "size": [8.0, 18.0, 8.0], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""}
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
  {"id": "ledge_lobbers", "enemy": "lobber", "site": "lobber_ledge", "landform": "mesa_rim", "advantage": "From the west wall's ledge, a lobber leads every held line across the plunge pool and the west toe (75 m range, lobber.gd:12).", "counter": "Change line under the shell, or ride the ledge itself and slam them off it.", "reinforce": {"from_tier": 1, "every_s": 30.0, "max_alive": 4, "pack": "grounded"}, "break": {"by": "slam", "hp": 80.0, "scrap": 14}, "stops_kind": true, "dormant": false},
  {"id": "powerhouse_trappers", "enemy": "mag_trapper", "site": "powerhouse", "landform": "dam_face", "advantage": "The toe apron is flat and a ball off a drop arrives light; a pit there bends a light line toward the plunge pool.", "counter": "Grow past the pit's rating and roll straight through, or jump the disc and shatter it (mag_trapper.gd:6-9).", "reinforce": {"from_tier": 2, "every_s": 35.0, "max_alive": 3, "pack": "grounded"}, "break": {"by": "smash", "hp": 90.0, "scrap": 16}, "stops_kind": true, "dormant": false},
  {"id": "outlet_brutes", "enemy": "plated_brute", "site": "spillway_tunnel", "landform": "spillway_tunnel", "advantage": "The tunnel puts every ball on one landing spot, and a brute's 6 m slam ring (plated_brute.gd:12) covers it.", "counter": "Take the flip bucket's launch over the ring and come down on the brute from above.", "reinforce": {"from_tier": 2, "every_s": 45.0, "max_alive": 2, "pack": "elite"}, "break": {"by": "damage", "hp": 140.0, "scrap": 20}, "stops_kind": true, "dormant": false},
  {"id": "dropship_winches", "enemy": "winch_drone", "site": "east_bench_flats", "landform": "slickrock", "advantage": "The dropship's drones hover 5.5 m over bare bench rock (winch_drone.gd:13), out of ram reach, and winch a ball crossing to the canal lips toward the crew.", "counter": "Hold 19 m/s across the bench and the cable snaps (winch_drone.gd:20); the canal lips' grind carries that speed, and a jump snaps it too.", "reinforce": {"from_tier": 1, "every_s": 30.0, "max_alive": 3, "pack": "elite"}, "break": {"by": "damage", "hp": 70.0, "scrap": 14}, "stops_kind": true, "dormant": true}
 ],
 "contraption_rows": [
  {"id": "rim_zip", "kind": "cable", "site": "east_haul_road", "recipe": "", "from": [110, 53.2, 300], "to": [60, 4.0, 520], "radius": 4.0, "floor": 18.0},
  {"id": "crest_trebuchet", "kind": "launcher", "site": "east_abutment", "recipe": "trebuchet", "style": "trebuchet", "at": [192, 548], "radius": 3.5, "target": [60, 123, 655], "floor": 30.0, "min_flight": 3.2, "charge": 4.0},
  {"id": "pool_geyser", "kind": "launcher", "site": "plunge_pool", "recipe": "geyser_vent", "style": "geyser", "at": [-110, 540], "radius": 3.5, "target": [-30, 32, 584], "floor": 16.0, "min_flight": 2.2, "charge": 3.0},
  {"id": "spray_thermal", "kind": "thermal", "site": "toe_apron", "recipe": "", "at": [-40, 520], "radius": 6.0, "height": 60.0},
  {"id": "gallery_valve", "kind": "valve", "site": "service_ledge", "recipe": "gauge", "at": [-190, 535], "door": {"at": [-167, 545], "size": [12, 6, 1], "turn": 0.6}, "cache": {"at": [-196, 548]}, "codex": {"id": "spillway_gallery_cache", "title": "Spillway gallery cache", "category": "world", "name": "Spillway gallery cache", "hint": "A gauge on the service ledge ticks toward a sealed gallery."}},
  {"id": "slot_bulkhead", "kind": "cracked_wall", "site": "corkscrew_slot", "recipe": "", "at": [20, 30], "size": [10, 6, 1.4], "turn": 0.25, "break_at_cruise": true},
  {"id": "domes_cannon", "kind": "launcher", "site": "slickrock_domes", "recipe": "cannon", "style": "cannon", "at": [60, -450], "radius": 4.0, "target": [20, 112, -230], "floor": 34.0, "min_flight": 2.6, "charge": 2.5},
  {"id": "domes_zip", "kind": "cable", "site": "slickrock_domes", "recipe": "", "from": [-58, 130.9, -372], "to": [-88, 128.4, -322], "radius": 7.0, "floor": 18.0},
  {"id": "service_lift", "kind": "lift", "site": "lobber_ledge", "recipe": "lift_platform", "at": [-185, 432], "radius": 4.5, "rise": 24.0, "charge": 3.2, "offset": 0.0}
 ],
 "weather_rows": [
  {"id": "dawn_still", "kind": "clear", "trigger": {"on": "always"}, "lead_s": 0.0, "live_s": 0.0, "gap_s": 0.0, "fog": {"density": 0.0006, "color": "#a3bdd0"}, "sky": "clear", "sound": "canyon_dawn_bed", "music_layer": "", "event_odds": {}, "handling": "none"},
  {"id": "monsoon_buildup", "kind": "monsoon", "trigger": {"on": "clock_tier", "value": 2}, "lead_s": 20.0, "live_s": 90.0, "gap_s": 60.0, "fog": {"density": 0.0014, "color": "#7d8b99"}, "sky": "storm_build", "sound": "monsoon_far_thunder", "music_layer": "monsoon_pad", "event_odds": {"west_wash_flash_flood": 2.5, "dome_lightning": 3.0, "plunge_pool_flood": 1.5}, "handling": "none"}
 ],
 "activity_rows": [
  {"id": "domes_camp", "activity": "enemy_camp", "site": "slickrock_domes", "at": [-51, -396], "pack": ["chaser", "chaser", "chaser"], "pay": {"named": "hot_rivets", "rarities": ["common"]}},
  {"id": "rim_cache", "activity": "cracked_cache", "site": "west_rim_bench", "at": [-210, 400], "pack": [], "pay": {"rarities": ["rare"]}},
  {"id": "bench_altar", "activity": "ambush_altar", "site": "east_rim_bench", "at": [206, 250], "pack": [], "pay": {"rarities": ["common", "rare"]}}
 ]
}
```

## 14. Storyboard

Board `park-1-park_dam`, panels per PARK.md:406. `p1_overhead` was planned to be plotted from section 13 by `tools/park_plot.py` (an unbuilt helper not in this checkout); the rest are generated. The concept board `artifacts/local/alpha/push/w13/concepts/boards/park-w1.json` carries three vista subjects for this stage.

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

**Frame 5, the landmark approach.** Off the construction incline, the camera falling with the ball down the canyon wall toward the toe; the dam fills the frame, 120 m of curved concrete, the relic a squat green-seamed drum clamped to its centre 22 m up, the powerhouse steaming to the right.

**Frame 6, the Warden fight.** From the toe apron looking up the face: the gates over the relic open, a white water sheet pouring down the face, and the ball riding up the sheet toward the relic's open core, a harpoon line taut from a gate pier to the ball.

**Frame 7, the exit.** After the break: the three gates on the apron, Moss's bay hovering behind them, and the ball arcing up the face and over the crest, the reservoir and a far mesa with a weir on it in the morning haze.

## 15. Dressing pass, KD1-DRESS (2026-10-16)

The dressing pilot for PARK.md:581's "then recipes swapped in and the bands met again". Base `cand/alpha-w15` at `e357a8c8`. Evidence: `/home/andrew/scratch/w15/kd1dress/` (scripts, logs and per-seed JSON; local, not committed).

**The rule applied.** A row swaps from `greybox:<element>` to a landform recipe only when both hold. First, this page or the PARK.md section 4 family names that recipe for the row's element and landform. Second, the recipe's GLB seats on the stage as placed today: `park_recipes.gd` puts a GLB row's node on the ground at the row's centre (`row_transform`, `place_row`'s `seat`) and its origin on the entry lip (`ride_frame`), and it never scales the GLB to the row's `size`. The read-only probe `swap_probe.gd` measured every named candidate against the committed bake and the seven lines (`swap_probe.log`). No footprint, stamp, ride, line or Warden number changed; the bake and graph moved only by the park file's hash (the graph does not read `recipe`).

**Swapped (3 rows).**

| Row | Old recipe | New recipe | Named by | Probe: GLB against ground and lines |
| --- | --- | --- | --- | --- |
| `west_wash` | `greybox:half_pipe` | `half_pipe_concrete` | section 2 (wash liner), Frame 3 ("concrete-lined arroyo half-pipe"), the half-pipe family (dam-crew liners) | 60 m of the 397 m row from its entry lip; collider bottom at least 3.7 m under the ground everywhere (never floats), up to 5 m of its walls buried at the top end; Sable and Tally ride within 1.3 m |
| `upper_slot` | `greybox:flow_line` | `slot_canyon_flow` | section 1 (two slot canyons), the half-pipe family (slot canyons) | 48 m of the 384.7 m row; floor at least 4 m under the ground, walls at least 6 m above it; Rivet, Tarn and the floor line ride within 1.1 m |
| `corkscrew_slot` | `greybox:flow_line` | `slot_canyon_flow` | as `upper_slot` | 48 m of the 380.1 m row; floor at least 8 m under, walls at least 2 m above; Kest and Cannon within 9.4 m |

**Kept greybox (104 rows), with the reason.**

| Rows | Reason |
| --- | --- |
| `canal_lips` (grind_line, canal) | Named (`canal_lip`) and the footprint fits (120.1 by 8.8 m against 120 by 8), but the row lies on a 43 m fall (ground 43.9 m at the lip, 0.4 m at the far end): seated at the centre, the flat GLB floats 14.9 m at one end and buries 19.9 m at the other, 12.5 m from the Cannon line |
| `pipeline_bridge` (grind_line, pipeline) | Named (`pipeline_rail`), but the GLB is 120.5 m on an 80 m row: it overruns 40.5 m past the exit, floats up to 29.5 m and comes within 0.3 m of the Cannon line |
| `spillway_tunnel` (tunnel, spillway_tunnel) | Named (`spillway_tunnel`), but the 90 by 15 m GLB with its 36 m fall seats at the centre's ground (35.1 m), 47.5 m under the ground at its lip (82.6 m): the tunnel stands buried |
| `cliff_rooms_west` (elevated_line, cliff_dwelling) | Named (`cliff_dwelling_row`), but the 60 m GLB on a 160 m row seats 29.3 m under the ground at its lip (43.1 m against 72.4 m): the rooms stand buried |
| `service_ledge`, `lobber_ledge` (ledge, mesa_rim) | Named family (`mesa_rim_ledge`), but on the 24 m plateaus the GLB hangs 16 m over the ground at the service ledge's lip and runs 60 m on the lobber ledge's 30 m row, into the wall behind it |
| `viga_span` (anchor_field, cliff_dwelling) | `viga_pivot` is named for the beams, but the row is an anchor field: swapping drops the post lattice `place_row` builds for Tarn's swing (the max-anchor-gap band), and the GLB seats up to 89 m off the ground at the ledge foot |
| `crest_rail` (rail, dam_face) | No family recipe is a dam-crest parapet; `pipeline_rail` would cover 120.5 m of the 300 m crest |
| `tailwater_bar` (flow_line, dry_wash) | The half-pipe family names three recipes and none for a dry-wash bar; `wash_dropin_lip` would sit wholly under the ground, 0.5 m from the Rivet line |
| 7 kickers (`shelf_lip`, `domes_kicker`, `wash_kicker`, `upper_slot_step`, `corkscrew_step`, `outlet_bucket`, `apron_kicker`) | `mesa_lip_kicker` is a sky-island recipe (mesas and buttes, not slickrock, slots or the outlet), and section 5 measured a wedge on the canyon descent bouncing Rivet off `apron_kicker` on 2 of 8 seeds; the kick stays in each `_ramp` ground row |
| `the_eye` (tunnel, slickrock) | No tunnel recipe is a hole worn through a sandstone fin (lava tube, adit, shaft and spillway tunnel only) |
| `top_shelf_deck`, `construction_incline`, `east_haul_road` (drop) | No recipe names a survey deck, a construction incline or a haul road; `shaft_drop` is a 26 m mine shaft |
| `plunge_pool`, `toe_vent_pits` (bowl, dam_face) | The bowl family is open-pit mine benches and tailings, stage 3's; none names a plunge pool or a vent pit |
| `east_abutment`, `powerhouse` (ledge, dam_face) | No recipe names a dam abutment or a powerhouse; both belong to the landmark asset unit |
| 21 elevated lines: 9 slickrock fins (`wash_fin_west`, `slot_fin_west`, `slot_fin_east`, `slot_fin_far`, `domes_fin_west`, `domes_fin_mid`, `domes_fin_east`, `eye_fin_west`, `eye_fin_east`), 3 mesa-rim fins (`west_lane_fin`, `east_lane_fin`, `incline_spine`), 4 river-canyon pieces (`eye_chute_west`, `eye_chute_east`, `eye_fall_spire_west`, `eye_fall_spire_east`), 4 toe pieces (`pool_rock`, `pool_pillar`, `training_wall_west`, `training_wall_east`) and `cliff_rooms_west` above | They are lane walls, fins and spires; the ledge family's recipes are rideable shelves at least 8 m deep, not walls, and the fins carry the measured line clearances of section 9 |
| 32 banks (`slickrock_domes`, `dome_1` to `dome_25`, `west_rim_bench`, `east_rim_bench`, `toe_apron`, `powerhouse_roof_ramp`, `dam_face_quarter`, `gate_row_apron`) | No family lists `bank`; a bank is its height stamp |
| 29 anchor fields (13 hoodoo fields, 14 saguaro stands, `gate_piers`, `viga_span` above) | An anchor field is a post lattice built at runtime (`place_anchor_field`); no recipe replaces it |

The landmark (`landmark_dam`) still has no GLB and stands in as greybox (`park_recipes.gd:184-186`); it is a separate asset unit.

**Bands, eight seeds per line, before (`e357a8c8`) and after (this candidate).** Fixed 90 FPS through the CPU queue at nice 10; audit `audit_bands.py`, 56 seed rows and 82 checks on each side; distinct lines from traced seed 1 (`distinct_lines.py`).

| Line | time_to_warden_s median (max) | flow_share median (min) | airborne min to max | peak_speed min | tier3_s median | quiet_max_s | anchor gap max | dead stops |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| sable | 64.8 (64.8) / 64.8 (64.8) | 0.9335 (0.9335) / same | 0.2229 to 0.2647 / same | 54.05 / 54.05 | 47.36 / 47.36 | 8.41 / 8.41 | 36.4 / 36.4 | 0 / 0 |
| rivet | 82.51 (92.11) / 82.11 (83.29) | 0.8183 (0.7624) / 0.8165 (0.7978) | 0.1475 to 0.1708 / 0.1602 to 0.17 | 41.68 / 42.3 | 10.19 / 10.54 | 12.14 / 12.14 | 33.2 / 33.2 | 1 (seed 4) / 0 |
| kest | 83.36 (86.58) / 85.25 (86.58) | 0.7789 (0.7002) / 0.7873 (0.7002) | 0.2117 to 0.3222 / same | 27.07 / 27.07 | 6.57 / 4.01 | 12.31 / 12.31 | 36.8 / 36.8 | 2 seeds / 2 seeds |
| tarn | 74.56 (77.71) / same | 0.938 (0.913) / same | 0.2128 to 0.2227 / same | 39.13 / 39.13 | 13.16 / 13.16 | 10.84 / 10.84 | 35.6 / 35.6 | 8 seeds / 8 seeds |
| tally | 80.11 (83.38) / 84.78 (87.21) | 0.7956 (0.7101) / 0.7273 (0.6715) | 0.1628 to 0.1765 / 0.1676 to 0.1715 | 43.93 / 44.1 | 8.88 / 8.7 | 12.49 / 12.49 | 33.7 / 33.7 | 0 / 0 |
| cannon | 84.16 (84.83) / same | 0.9371 (0.916) / same | 0.1699 to 0.1725 / same | 35.35 / 35.35 | 12.93 / 12.93 | 11.82 / 11.82 | 35.0 / 35.0 | 0 / 0 |
| floor | 87.02 (89.26), cap 165.02 / 86.59 (89.26), cap 164.22 | 0.7453 to 0.7975 / 0.7453 to 0.7962 | reported | reported | reported | reported | reported | 7 seeds / 7 seeds |

Segments, length ratios and distinct ride facts stay inside their bands on both sides; distinct lines are 4 mutually distinct on both (sable, rivet, kest, tally). Every band holds after the swap except dead stops, and that miss is the base's: the same stops at the same place and time on both sides (Kest seeds 2 and 3, all eight Tarn seeds and seven floor seeds at about [-57, -403], 31 to 40 s in), 8 m from `domes_camp` ([-51, -396]) and 140 m before the first dressed row's lip at z -265. Section 9's round-5 sweep had none, so it arrived with a later merge; most likely the camp's chaser pack, an inference this pass did not trace. Rivet's base seed-4 stop at [-40.6, 412.3] does not recur. Tally's flow lost the most margin (median 0.7956 to 0.7273, worst seed 0.6715 against the 0.60 floor); her line rides the dressed west wash.

**Win proof on `--table=park`.** `bot_run.gd --policy=skipper --table=park --from-stage=1 --stages=1`, seeds 1 to 3 in separate processes: all three `stages_done` at stage 2 (runner_gunner 126.98 s, demolitions_caster 157.82 s, tarn 206.53 s), no `get_rid` error and no `park_recipes` stand-in warning in any log.

**Tests.** `npm run sketch:smoke -- --sketch core-loop` with every `park_park_dam*`, `park_dam*`, `park_reactor*` and `park_graph*` test and the park schema, bake, route, sight, density, pockets, place, recipes, dressing pin, table, map, events, gates and Warden tests, `SMOKE_BOT=1`: 42 runs, 0 failed, every test with a verdict line and a nonzero check count. `park_park_dam_test` is re-pinned (dated header 2026-10-16): exactly `DRESSED` names a GLB recipe and each base GLB loads, with a planted reverted row and a planted extra swap both turning it red.

**Graph ratios.** Unchanged by the swap: `full_visit_ratio` 1.694 (at most 3.0) holds (the graph read 1.756 on the base when `rim_cache` moved; see below); `reward_ratio` 0.841 misses its 1.5 start target on the base and on this candidate. The pocket that causes it is `rim_cache`, the reward pocket at 1,065 m from the spawn against a spawn-to-objective path of about 1,266 m (1,065 / 0.841), so the reward sits nearer than the objective. Moving it is greybox work (decisions.tsv:683), not dressing.

**`rim_cache` move, 2026-10-19 (greybox unit, decisions.tsv:683).** The attribution above is wrong on one point: `reward_ratio` is the median of the reward, risk and hidden pockets' spawn paths over the 1,352 m beacon path, and the median of 1,065 / 1,137 / 1,394 m is `bench_altar` at 1,137 m (1,137 / 1,352 = 0.841), not `rim_cache`. Moving `rim_cache` alone can raise the median only to the hidden pocket's 1,394 m, so 1.031 is the ceiling. 1.5 needs a median of 2,028 m, so two of the three pockets must sit past 2,028 m by path: `rim_cache` plus one other is enough, and on a 1,600 m map that is more than a pocket move. `rim_cache` is moved from [-206, 300] to [-210, 400], site `west_rim_bench` kept: door [-208, 400], spawn path 1,065 to 1,161 m, beacon 410 to 367 m, detour 307 to 403 m, `reward_ratio` 0.841 to 0.859 (reported, not gated; the coordinator retired the 1.5 start target for park_dam on 2026-10-19, issue #149, leaving reward-pocket spacing to the Challenge lane's band table), `full_visit_ratio` 1.756 to 1.805, no breaches, sight_ok true. Candidates tried (door, spawn m, ratio): [-300, 330] 1,079, 0.841, sight breach; [-240, 480] 1,228, 0.908, sight breach; [-300, 560] 1,311, 0.970, sight breach and 600 m detour; [-328, 520] 1,284, 0.950, sight breach; [-200, 480] 1,268, door_to_door/clear_ring/beacon breaches; east_bench_flats [165, 475] 1,312, 0.971, five breaches. Past x -210 the door loses the 240 m sight to a line node, so the chosen spot is the farthest breach-free one. Proof on this head: park, graph, graph precision, routes, schema, bake fresh, dressing pin, park_dam, pockets, table, Warden wiring, pocket kinds, pocket line clear and run tier tests all pass (13 tests, 0 failed, `run_tier_test` pins unmoved); `traversal_line.gd --table=park --stage=1` for sable, rivet, kest, tarn, tally and cannon, seeds 1 to 3 on this head against the read-only base, matches on every time_to_warden_s and flow_share (one sable seed-1 run under load showed one dead stop and did not recur on rerun); win proof seeds 1 to 3 all reach stages_done at stage 2 (193.1 s, 127.0 s, 171.0 s; seed 1 reran at 129.2 s, bot_run timing varies between runs).

**Perf, p1 on card 1** (`perf_bench.gd`, two interleaved rounds, ratios to the same round's s3, memory p1 at open less s3 at open; KB6 caps 1.3, 350 MB static, 300 MB video):

| Run | GPU p99 ratio | frame p99 ratio | draws p99 (ratio) | static MB | video MB |
| --- | --- | --- | --- | --- | --- |
| before a | 0.516 | 0.765 | 365 (0.404) | +131.4 | +67.8 |
| before b | 0.514 | 0.823 | 365 (0.320) | +133.5 | +93.2 |
| after a | 0.511 | 0.697 | 368 (0.402) | +132.8 | +92.9 |
| after b | 0.545 | 0.826 | 371 (0.331) | +130.9 | +85.9 |

Three GLBs with their shells add 3 to 6 draws and no measurable memory; frame times ran with other writers on the machine, so only the ratios count.

**Cost, for KD2 to KD6.** 3 rows swapped of 107 greybox rows. About 1.2 hours of wall time, nearly all of it machine time: two eight-seed sweeps of 56 rows (about 12 minutes each under the shared queue), the 42-run smoke (19 minutes), two perf series and the win proof. The edit itself is three recipe fields; the rebake takes 5.6 s for the bake and 8.6 s for the graph, and two rebakes give identical bytes. What blocked more swaps is placement, not assets: a GLB row seats on the ground at its centre and is never scaled, so a fixed-length GLB on a long or sloped row floats or buries, and only rows whose GLB seats within a few metres of the ground at its lip can swap without a footprint change.

## 16. Authored pass: the dam tests rolling (2026-10-17)

The pass for WHATS-LEFT unit 3 and placeholder unit H, modelled on the crown pass (#67). Andrew's Q4 ruling, "One skill per park", gives the dam rolling. The landforms stay where section 5 put them. What changed is what the shelf asks of a ball, and what every piece is made of. Branch `claude/dam-park-authored-pass-s1fxch`, PR #101, on `main` plus #40, #68, #29, #38 and #79.

**The skill, and why rolling.** The dam is the first park. Each line starts on a 152 m survey shelf and ends 150 m lower, at the foot of the face. Gravity does the work, so the question the park asks is whether you can keep a line without wasting the fall. The floor line (stick and brake, no fire, no rope) is the purest version of that question, so it is the line this pass shapes.

**The slalom (top shelf).** Before this pass the 25 domes were one bank row repeated: the same verb and size, no society and no reason (the scorecard's "25 numbered slickrock domes, all the same bank row"). The floor line meandered west round them and braked hard: flow 0.783, segments 39.0, 31.4 and 16.1 s on seed 1. Now the domes are the dam crew's survey traverse, and the floor line rolls down it as a slalom:

- All 25 domes and the `slickrock_domes` bowl have verb `roll`.
- Seven gate domes stand in the dam_era society, each with a survey flag on a dry-stacked cairn on its summit (`dam_survey_gate_red`, `dam_survey_gate_blue`): red gate `dome_5`/`dome_6` [-70, -595], blue gate `dome_18`/`dome_19` [-95, -507], the red turning post `dome_15` [-65, -478], then the domes camp, then blue gate `dome_24`/`dome_25` [-87, -330]. `assets/park/park_dam/lines.json` floor waypoints thread them in that order.
- `dome_11` at the shelf's west end is the benchmark, the highest station, which only Sable's wide line visits. It carries `dam_survey_benchmark`: the gate cairn with a copper band, a brass station disc and a 1.4 m stake, and no flag.
- `dome_7` keeps Rivet's cage at its north foot.
- The other 16 domes stay plain. They are the wide lines' turning marks and the shelf's anchor faces; a slalom needs open snow round its gates.
- Three crew-log fragments in section 11 tell the story in the crew's own words: `dam_era_station_marks` (dome_5), `dam_era_gate_flags` (dome_24) and `dam_era_benchmark` (dome_11).

**Enemies: placement unchanged, on purpose.** Each home already tests a rolling skill (section 7 advantage and counter text). Chasers lunge down a straight lane, and you beat them by pumping the wash wall. Lobbers lead a held line, and you beat them by changing line under the shell. A trapper's pit bends a light line, and you beat it by rolling straight through. Winch drones snap at 19 m/s held across the bench. A brute's slam ring covers the tunnel landing, and you beat it by flying the flip bucket over the ring. Moving any home would trade a rolling test for a weaker one. The domes camp [-51, -396] stays where it was. The floor line now runs through it, between the red post and the last gate, so the fight is part of the line instead of a detour from it. Section 15 recorded the base floor line's dead stops at [-57, -403], beside this camp, on 7 of 8 seeds, so the sweep below is the check on that stretch.

**The drape kit (unit H, 40 ride lips plus `eye_mouth`).** `tools/blender/park/dam_dressing.py` builds each greybox ride lip as its own GLB from the baked ground under its footprint (it matches `terrain.gd` `_grid_height`): 43 recipes × base and two detail shells = 129 GLBs, registry `assets/registry.d/park_dam_dressing.json`. A new opt-in fit `drape` (`park_schema.gd` FITS; `park_recipes.gd` `fits_drape`) seats a stamped row on the ground less its own stamp raise, so the piece lies flush on the shape its stamp made. Drape rows keep `y` null because `park_graph.gd` reads a row `y` as a deck: an early try with `y` set added 1,986 graph nodes and a gallery_valve breach. Each piece lies flush (at most 0.12 m off the ground, `tests/park_recipes_dam_dressing_test.gd`). The Eye's arch soffit stands 23.95 m up and the portal clears 12.43 m. The dome summits ride the shelf's fall (about 6.5 percent), so each gate stands 0.15 m under its seat's summit and keeps every stone within 2.2 m of the pole: the ground there lies 0 to 0.30 m over the cairn's foot, so no stone floats (the dressing test measures 16 points round each gate). Known limits: faces steeper than about 70° may z-fight, and the Eye arch legs stand in the fin-crest lane at x ±30 to ±54. No measured line rides there.

**The Mind's first musical quote (Q9).** It plays at the Eye's south mouth: row `eye_mouth` [0, 205], a 20 by 30 m flat plateau stamp, publishes ride fact `layer_mind_quote_spillway` as the ball leaves the Eye. Every line crosses the Eye once, downhill, so the quote plays once per run on every line. It goes through the place-layer path (`event_kinds.gd`, `sound_next` `music_layer_mind_quote_spillway`), and ui_tick stands in until the file on #12 lands. A ride sensor publishes on every entry, so a `layer_mind_quote_` fact gets a guard (`park_recipes.gd` `_fire`): the first entry plays it, and a bounce inside the box or a second crossing stays silent (`tests/park_mind_quote_once_test.gd`, red without the guard). The spot is outside every arena: the Warden's fight opens at the bay dock [0, 467], 247 m on, and the nearest other fight (the `bench_altar` ambush, [206, 250]) is 211 m away, while the row's sensor box is 20 by 30 m and reaches only 3 m above the ground. The flume thread was told of the spot, since the Mind's quote recurs on its stage.

**The crane that swings once (2026-10-18, Andrew's "All hands": the crew were the Mind's hands).** The dam crew's tower crane stands on the crest at [118, 664]: a 28 m lattice mast and a 34 m jib, parked along the crest with the hook hanging empty. It is `crest_rail`'s `rider` (`park_schema.gd`, `park_recipes.gd` `place_rider`, recipe `dam_crest_crane` from `dam_dressing.py`). When the quote first fires at the Eye's mouth, the same sensor turns the jib 75° over 4.5 s (`swing`), and the cab wheels round until the jib points back down the canyon at the Eye, about 470 m off, with nobody in it. It stays there for the rest of the run, a plant for the Mind fight beside PR #113's crane log line. The crane has no collider and stands off the crest rail's line. `tests/park_mind_quote_once_test.gd` (c) checks one swing of 75° about the mast and that a second entry does nothing.

**Bands, eight seeds per line, on `54702876`** (the head after #79's `a286cf1d` and the six-park re-bake; later commits change only a content pin and this page). `traversal_line.gd --table=park --stage=1`, seeds 1 to 8, fixed 90 FPS at nice 10, two lanes; evidence in `artifacts/local/dam-pass/final/` (local, not committed). Every pilot band holds on all six pilot lines, and the floor line holds its own band (Warden in at most twice Rivet's median, 0 dead stops). The last column is section 9's medians on main, for comparison.

| Line | Reached | time_to_warden_s median (max) | flow_share median (min) | segments median s | quiet_max_s | dead stops | Bands outside | Section 9 time / flow |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| sable | 8 of 8 | 64.8 (64.8) | 0.9335 (0.9335) | 27.53, 18.14, 19.12 | 8.41 | 0 | none | 63.48 / 0.9276 |
| rivet | 8 of 8 | 81.05 (81.05) | 0.8443 (0.836) | 38.16, 29.36, 13.52 | 12.14 | 0 | none | 80.9 / 0.8445 |
| kest | 8 of 8 | 87.61 (87.61) | 0.7609 (0.7314) | 30.08, 30.71, 26.81 | 11.8 | 0 | none | 80.22 / 0.7691 |
| tarn | 8 of 8 | 73.9 (75.49) | 0.9687 (0.9432) | 31.56, 26.09, 16.24 | 10.5 | 0 | none | 73.87 / 0.9687 |
| tally | 8 of 8 | 84.78 (84.78) | 0.7273 (0.7273) | 32.31, 32.71, 19.74 | 12.06 | 0 | none | 80.27 / 0.8156 |
| cannon | 8 of 8 | 84.07 (84.83) | 0.9461 (0.916) | 29.51, 29.47, 25.08 | 10.91 | 0 | none | 84.68 / 0.9273 |
| floor | 8 of 8 | 61.5 (62.31) | 0.9402 (0.9135) | 18.47, 27.18, 15.84 | 4.19 | 0 | length_ratio 1.13 (a pilot band, reported for the floor, as in section 9) | 86.57 / 0.7684 |

The floor line is the rolling line, and it is where this pass shows. It reaches the Warden 25 s sooner (86.6 to 61.5 s median). Flow rises from 0.77 to 0.94. The longest quiet stretch falls from 12.5 s to 4.2 s, and the dead stops that section 15 recorded beside the domes camp are gone on every seed. Its length ratio, 1.13, is under the pilots' 1.3 to 2.0 band. The slalom takes the fall line down the shelf, which is what a rolling line should do, and section 9 already reports that band for the floor without gating it. Tally's flow (0.73) and Kest's time (87.6 s) moved before this pass: section 15 measured 0.7273 and 85.25 s after the KD1 swap, and both stay inside their bands.

**Scorecard** (`intent-check/scorecard.py`, against `2fce8953` in `results/w16-2fce8953.md`):

| Measure | before | after |
| --- | --- | --- |
| Top verb (share) | bank (0.44) | roll (0.71) |
| Society share | 0.27 | 0.35 |
| Story fragments | 13 | 16 |
| Dressed rows | 3 | 81 |
| Placeholders | 105 | none |

**Filler that remains.** The 11 `hoodoo_stack` ground rows are identical density rows off every line. They are scenery, not moments, and they are left for the wave 18-19 dressing. The 16 plain domes are the slalom's open ground, a choice and not an oversight.
