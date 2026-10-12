# Stage 1, `park_dam`: Spillway: the dam

World 1, Spillway Works. Warden kind `reactor` on the `dam_face` mounting, variant `""`. Time of day `dawn`. Storyboard board id `park-1-park_dam`. Status: dressed candidate under automated qualification (2026-10-12). Andrew's visual and play verdict remains open.

This page follows the park schema in `design-v3/PARK.md` section 2 and `adr/TADR-011-park-terrain-and-warden-kinds.md`. Section 13 mirrors the shipped park file. The graph, recipe bounds and automated traversal qualify that file; they do not establish its rendered look or human feel.

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

## 5. `park_rows` (176 rows, dressed candidate 2026-10-12)

The file contains 42 native family pieces replacing 16 greybox family parents. Each piece has its measured GLB bounds, no stamp, and normal ground placement. The loader offsets the entry-lip origin by half the piece length; it never scales or pitches a piece. Long rides use a chain of native pieces. The pieces supply their colliders and ride sensors.

The original stamps now live on separate `ground` rows ending in `_terrain`. They retain the baked geology under the fitted pieces. The native pieces instantiate the colliders and ride sensors.

Sable's `sable_shelf_runout_anchor` is one 18 m post at [-100, -236], with an 8 by 8 m footprint. On head `cacaba8`, all eight batch seeds have a worst gap of 36.4 m, down from 45.3 m. Rivet, Tarn and the floor row also passed their required reruns. Final dressed receipts are recorded separately in section 9.

The wash uses five 60 m concrete pieces with open entry and exit run-outs. The upper slot uses seven 48 m sandstone pieces; the corkscrew uses six, leaving an open northern run-up before the first piece. Their waypoint centres fit the native interiors. The overlong first corkscrew piece is removed to clear Kest and Cannon's entry turn before the remaining native chain. Rivet stays on the tailwater liner centreline at x -30 until z 500, past its exit. `slot_fin_west` loses 60 m at its south end so the runs converge without a ridge across the exit. The obsolete west canyon fin stamp is removed. Its two native ledges stand at [-70,410] and [-70,452.5], with open landing space north of them. The western hook fin is a narrow 30 m rock at [-65,360], replacing the unsuccessful canyon post field. The eastern Eye spire moves to [15,300] and rises 45 m beside the early flight. The west Eye rock stays at [-28,224] and rises 22 m. The spine piece moves to [40,370] to clear the central Warden approach. Sable's canyon points carry her into the broad western arc. The tailwater liner moves 10 m west to clear the apron approach.

The service ledge uses two pieces. Its north landing is [-180, 505], facing north, and the gallery piece is [-180, 538], facing west. The gauge and door keep their positions. The lift still rises 24 m to the baked bench; the native ledge has its own 2.5 m roll-up. This needs the coordinator's rendered review and Andrew's play.

| Parent | Recipe | Pieces | Native size, length / height / width m |
| --- | --- | --- | --- |
| `west_wash` | `half_pipe_concrete` | `west_wash_piece_n2`, `west_wash_piece_n1`, `west_wash`, `west_wash_piece_1`, `west_wash_piece_2` | [60, 11.9797, 34.64] |
| `upper_slot` | `slot_canyon_flow` | `upper_slot_piece_n3`, `upper_slot_piece_n2`, `upper_slot_piece_n1`, `upper_slot`, `upper_slot_piece_1`, `upper_slot_piece_2`, `upper_slot_piece_3` | [48, 14.4202, 26] |
| `corkscrew_slot` | `slot_canyon_flow` | `corkscrew_slot_piece_n2`, `corkscrew_slot_piece_n1`, `corkscrew_slot`, `corkscrew_slot_piece_1`, `corkscrew_slot_piece_2`, `corkscrew_slot_piece_3` | [48, 14.4202, 26] |
| `west_lane_fin` | `mesa_rim_ledge` | `west_lane_fin`, `west_lane_fin_piece_1` | [60, 19.0219, 34.1729] |
| `east_lane_fin` | `mesa_rim_ledge` | `east_lane_fin_piece_n1`, `east_lane_fin`, `east_lane_fin_piece_1` | [60, 19.0219, 34.1729] |
| `incline_spine` | `mesa_rim_ledge` | `incline_spine` | [60, 19.0219, 34.1729] |
| `west_rim_bench` | `mesa_rim_ledge` | `west_rim_bench_piece_n1`, `west_rim_bench`, `west_rim_bench_piece_1` | [60, 19.0219, 34.1729] |
| `spillway_tunnel` | `spillway_tunnel` | `spillway_tunnel_piece_n1`, `spillway_tunnel` | [90, 46.1333, 15.0] |
| `cliff_rooms_west` | `cliff_dwelling_row` | `cliff_rooms_west_piece_n1`, `cliff_rooms_west`, `cliff_rooms_west_piece_1` | [60, 22.3102, 21.287] |
| `viga_span` | `viga_pivot` | `viga_span` | [36, 18.7, 20.02] |
| `service_ledge` | `mesa_rim_ledge` | `service_ledge`, `service_ledge_gallery` | [60, 19.0219, 34.1729] |
| `lobber_ledge` | `mesa_rim_ledge` | `lobber_ledge` | [60, 19.0219, 34.1729] |
| `tailwater_bar` | `half_pipe_concrete` | `tailwater_bar` | [60, 11.9797, 34.64] |
| `pipeline_bridge` | `pipeline_rail` | `pipeline_bridge` | [120.4797, 11.0151, 4.4784] |
| `canal_lips` | `canal_lip` | `canal_lips` | [120.1375, 11.0967, 12.018] |
| `east_rim_bench` | `mesa_rim_ledge` | `east_rim_bench_piece_n1`, `east_rim_bench`, `east_rim_bench_piece_1` | [60, 19.0219, 34.1729] |

Every row left on a greybox recipe, with its reason:

| Row | Reason |
| --- | --- |
| `top_shelf_deck` | No slickrock recipe exists for this drop. Keep the authored stamp and ride sensor, or the anchor posts. |
| `slickrock_domes` | No slickrock recipe exists for this bank. Keep the authored stamp and ride sensor, or the anchor posts. |
| `dome_1` | No slickrock recipe exists for this bank. Keep the authored stamp and ride sensor, or the anchor posts. |
| `dome_2` | No slickrock recipe exists for this bank. Keep the authored stamp and ride sensor, or the anchor posts. |
| `dome_3` | No slickrock recipe exists for this bank. Keep the authored stamp and ride sensor, or the anchor posts. |
| `dome_4` | No slickrock recipe exists for this bank. Keep the authored stamp and ride sensor, or the anchor posts. |
| `dome_5` | No slickrock recipe exists for this bank. Keep the authored stamp and ride sensor, or the anchor posts. |
| `dome_6` | No slickrock recipe exists for this bank. Keep the authored stamp and ride sensor, or the anchor posts. |
| `dome_7` | No slickrock recipe exists for this bank. Keep the authored stamp and ride sensor, or the anchor posts. |
| `dome_8` | No slickrock recipe exists for this bank. Keep the authored stamp and ride sensor, or the anchor posts. |
| `dome_9` | No slickrock recipe exists for this bank. Keep the authored stamp and ride sensor, or the anchor posts. |
| `dome_10` | No slickrock recipe exists for this bank. Keep the authored stamp and ride sensor, or the anchor posts. |
| `dome_11` | No slickrock recipe exists for this bank. Keep the authored stamp and ride sensor, or the anchor posts. |
| `dome_12` | No slickrock recipe exists for this bank. Keep the authored stamp and ride sensor, or the anchor posts. |
| `dome_13` | No slickrock recipe exists for this bank. Keep the authored stamp and ride sensor, or the anchor posts. |
| `dome_14` | No slickrock recipe exists for this bank. Keep the authored stamp and ride sensor, or the anchor posts. |
| `dome_15` | No slickrock recipe exists for this bank. Keep the authored stamp and ride sensor, or the anchor posts. |
| `dome_16` | No slickrock recipe exists for this bank. Keep the authored stamp and ride sensor, or the anchor posts. |
| `dome_17` | No slickrock recipe exists for this bank. Keep the authored stamp and ride sensor, or the anchor posts. |
| `dome_18` | No slickrock recipe exists for this bank. Keep the authored stamp and ride sensor, or the anchor posts. |
| `dome_19` | No slickrock recipe exists for this bank. Keep the authored stamp and ride sensor, or the anchor posts. |
| `dome_20` | No slickrock recipe exists for this bank. Keep the authored stamp and ride sensor, or the anchor posts. |
| `dome_21` | No slickrock recipe exists for this bank. Keep the authored stamp and ride sensor, or the anchor posts. |
| `dome_22` | No slickrock recipe exists for this bank. Keep the authored stamp and ride sensor, or the anchor posts. |
| `dome_23` | No slickrock recipe exists for this bank. Keep the authored stamp and ride sensor, or the anchor posts. |
| `dome_24` | No slickrock recipe exists for this bank. Keep the authored stamp and ride sensor, or the anchor posts. |
| `dome_25` | No slickrock recipe exists for this bank. Keep the authored stamp and ride sensor, or the anchor posts. |
| `shelf_lip` | No slickrock recipe exists for this kicker. Keep the authored stamp and ride sensor, or the anchor posts. |
| `wash_fin_west` | No slickrock recipe exists for this elevated_line. Keep the authored stamp and ride sensor, or the anchor posts. |
| `slot_fin_west` | No slickrock recipe exists for this elevated_line. Keep the authored stamp and ride sensor, or the anchor posts. |
| `slot_fin_east` | No slickrock recipe exists for this elevated_line. Keep the authored stamp and ride sensor, or the anchor posts. |
| `slot_fin_far` | No slickrock recipe exists for this elevated_line. Keep the authored stamp and ride sensor, or the anchor posts. |
| `domes_fin_west` | No slickrock recipe exists for this elevated_line. Keep the authored stamp and ride sensor, or the anchor posts. |
| `domes_fin_mid` | No slickrock recipe exists for this elevated_line. Keep the authored stamp and ride sensor, or the anchor posts. |
| `domes_fin_east` | No slickrock recipe exists for this elevated_line. Keep the authored stamp and ride sensor, or the anchor posts. |
| `domes_kicker` | No slickrock recipe exists for this kicker. Keep the authored stamp and ride sensor, or the anchor posts. |
| `wash_kicker` | This family has no kicker recipe. The baked launch lip retains its calibrated ramp; the sky-island kicker is a different piece. |
| `upper_slot_step` | This family has no kicker recipe. The baked launch lip retains its calibrated ramp; the sky-island kicker is a different piece. |
| `corkscrew_step` | This family has no kicker recipe. The baked launch lip retains its calibrated ramp; the sky-island kicker is a different piece. |
| `eye_fin_west` | No slickrock recipe exists for this elevated_line. Keep the authored stamp and ride sensor, or the anchor posts. |
| `eye_fin_east` | No slickrock recipe exists for this elevated_line. Keep the authored stamp and ride sensor, or the anchor posts. |
| `the_eye` | No slickrock recipe exists for this tunnel. Keep the authored stamp and ride sensor, or the anchor posts. |
| `eye_chute_west` | No river_canyon recipe exists for this elevated_line. Keep the authored stamp and ride sensor, or the anchor posts. |
| `eye_chute_east` | No river_canyon recipe exists for this elevated_line. Keep the authored stamp and ride sensor, or the anchor posts. |
| `pool_rock` | No dam_face recipe exists for this elevated_line. Keep the authored stamp and ride sensor, or the anchor posts. |
| `pool_pillar` | No dam_face recipe exists for this elevated_line. Keep the authored stamp and ride sensor, or the anchor posts. |
| `training_wall_west` | No dam_face recipe exists for this elevated_line. Keep the authored stamp and ride sensor, or the anchor posts. |
| `training_wall_east` | No dam_face recipe exists for this elevated_line. Keep the authored stamp and ride sensor, or the anchor posts. |
| `outlet_bucket` | This family has no kicker recipe. The baked launch lip retains its calibrated ramp; the sky-island kicker is a different piece. |
| `construction_incline` | No open concrete incline or haul-road drop recipe exists. The tunnel family supplies enclosed drops; this is the exposed descent. |
| `east_haul_road` | No open concrete incline or haul-road drop recipe exists. The tunnel family supplies enclosed drops; this is the exposed descent. |
| `east_abutment` | No dam_face recipe exists for this ledge. Keep the authored stamp and ride sensor, or the anchor posts. |
| `eye_fall_spire_east` | No river_canyon family recipe exists. A 45 m stamped spire stands east of the early flight at [15,300], with a 16 m footprint and no route through its centre. |
| `apron_kicker` | This family has no kicker recipe. The baked launch lip retains its calibrated ramp; the sky-island kicker is a different piece. |
| `plunge_pool` | No dam_face recipe exists for this bowl. Keep the authored stamp and ride sensor, or the anchor posts. |
| `toe_apron` | No dam_face recipe exists for this bank. Keep the authored stamp and ride sensor, or the anchor posts. |
| `powerhouse` | No dam_face recipe exists for this ledge. Keep the authored stamp and ride sensor, or the anchor posts. |
| `powerhouse_roof_ramp` | No dam_face recipe exists for this bank. Keep the authored stamp and ride sensor, or the anchor posts. |
| `toe_vent_pits` | No dam_face recipe exists for this bowl. Keep the authored stamp and ride sensor, or the anchor posts. |
| `dam_face_quarter` | No dam_face recipe exists for this bank. Keep the authored stamp and ride sensor, or the anchor posts. |
| `gate_piers` | No dam_face recipe exists for this anchor_field. Keep the authored stamp and ride sensor, or the anchor posts. |
| `gate_row_apron` | No dam_face recipe exists for this bank. Keep the authored stamp and ride sensor, or the anchor posts. |
| `crest_rail` | No dam_face recipe exists for this rail. Keep the authored stamp and ride sensor, or the anchor posts. |
| `hoodoo_1` | No hoodoo_field recipe exists for this anchor_field. Keep the authored stamp and ride sensor, or the anchor posts. |
| `saguaro_2` | No saguaro_stand recipe exists for this anchor_field. Keep the authored stamp and ride sensor, or the anchor posts. |
| `hoodoo_3` | No hoodoo_field recipe exists for this anchor_field. Keep the authored stamp and ride sensor, or the anchor posts. |
| `saguaro_4` | No saguaro_stand recipe exists for this anchor_field. Keep the authored stamp and ride sensor, or the anchor posts. |
| `hoodoo_5` | No hoodoo_field recipe exists for this anchor_field. Keep the authored stamp and ride sensor, or the anchor posts. |
| `saguaro_6` | No saguaro_stand recipe exists for this anchor_field. Keep the authored stamp and ride sensor, or the anchor posts. |
| `hoodoo_7` | No hoodoo_field recipe exists for this anchor_field. Keep the authored stamp and ride sensor, or the anchor posts. |
| `saguaro_8` | No saguaro_stand recipe exists for this anchor_field. Keep the authored stamp and ride sensor, or the anchor posts. |
| `hoodoo_9` | No hoodoo_field recipe exists for this anchor_field. Keep the authored stamp and ride sensor, or the anchor posts. |
| `saguaro_10` | No saguaro_stand recipe exists for this anchor_field. Keep the authored stamp and ride sensor, or the anchor posts. |
| `hoodoo_11` | No hoodoo_field recipe exists for this anchor_field. Keep the authored stamp and ride sensor, or the anchor posts. |
| `saguaro_12` | No saguaro_stand recipe exists for this anchor_field. Keep the authored stamp and ride sensor, or the anchor posts. |
| `hoodoo_13` | No hoodoo_field recipe exists for this anchor_field. Keep the authored stamp and ride sensor, or the anchor posts. |
| `saguaro_14` | No saguaro_stand recipe exists for this anchor_field. Keep the authored stamp and ride sensor, or the anchor posts. |
| `hoodoo_15` | No hoodoo_field recipe exists for this anchor_field. Keep the authored stamp and ride sensor, or the anchor posts. |
| `saguaro_16` | No saguaro_stand recipe exists for this anchor_field. Keep the authored stamp and ride sensor, or the anchor posts. |
| `hoodoo_17` | No hoodoo_field recipe exists for this anchor_field. Keep the authored stamp and ride sensor, or the anchor posts. |
| `saguaro_18` | No saguaro_stand recipe exists for this anchor_field. Keep the authored stamp and ride sensor, or the anchor posts. |
| `hoodoo_19` | No hoodoo_field recipe exists for this anchor_field. Keep the authored stamp and ride sensor, or the anchor posts. |
| `saguaro_20` | No saguaro_stand recipe exists for this anchor_field. Keep the authored stamp and ride sensor, or the anchor posts. |
| `hoodoo_21` | No hoodoo_field recipe exists for this anchor_field. Keep the authored stamp and ride sensor, or the anchor posts. |
| `saguaro_22` | No saguaro_stand recipe exists for this anchor_field. Keep the authored stamp and ride sensor, or the anchor posts. |
| `hoodoo_23` | No hoodoo_field recipe exists for this anchor_field. Keep the authored stamp and ride sensor, or the anchor posts. |
| `saguaro_24` | No saguaro_stand family recipe exists. Its west edge moves 30 m east after the corkscrew entrance opens, keeping generated posts at least 15 m from Kest and Cannon. |
| `hoodoo_25` | No hoodoo_field recipe exists for this anchor_field. Keep the authored stamp and ride sensor, or the anchor posts. |
| `saguaro_26` | No saguaro_stand recipe exists for this anchor_field. Keep the authored stamp and ride sensor, or the anchor posts. |
| `sable_shelf_runout_anchor` | No saguaro_stand recipe exists for this anchor_field. Keep the authored stamp and ride sensor, or the anchor posts. |
| `canyon_hook_fin` | No river_canyon family recipe exists. A narrow stamped 30 m rock fin offers a high hook surface beside the western flight, without the former continuous 26 m canyon wall. |

## 6. `event_rows` (6 rows)

| Row | Family, kind | Site | Trigger | Telegraph | Effect | Route change |
| --- | --- | --- | --- | --- | --- | --- |
| `plunge_pool_flood` | natural, `flood_fill` | `plunge_pool` | clock_tier 1 | 6 s `flood_rising` | depth_m 1.2, fill_s 10.0, material water | closes `pool_floor`, opens `pool_rim` |
| `west_wash_flash_flood` | natural, `flash_flood` | `west_wash` | clock_tier 2 | 6 s `flood_rising` | depth_m 1.2, fill_s 4.0, material water | closes `west_wash_run`, opens none |
| `dome_lightning` | natural, `lightning` | `slickrock_domes` | clock_tier 3 | 3 s `lightning_charge` | strike_m 6.0, damage 8.0 | closes none, opens none |
| `east_bench_dropship` | fleet, `fleet_landing` | `east_bench_flats` | clock_tier 1 | 10 s `fleet_inbound` | vessel dropship, home dropship_winches, footprint_m [36, 16] | closes none, opens `dropship_ramp` |
| `toe_vents_wake` | ancient, `machine_eruption` | `toe_vent_pits` | clock_tier 2 | 8 s `ancient_stirring` | miniboss reactor_relic, swap vent_pit_lip | closes none, opens none |
| `powerhouse_boiler` | industrial, `boiler_burst` | `powerhouse` | warden_phase chunk_2 | 5 s `boiler_pressure` | hazard steam_cone, hazard_m [24, 10], damage 6.0, swap powerhouse_roof_ramp | closes `powerhouse_floor`, opens `roof_ramp_line` |

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

The baked ledges are 24 m plateaus beneath the native recipe pieces (section 5), so `service_lift` stands at the foot of `lobber_ledge`'s north face and lifts the ball 24 m to its top, the way onto the service ledge and the gallery; `gallery_valve`'s door faces the plunge pool from the service ledge's east edge, in sight of the line, and its cache stays at the back of the ledge. `crest_trebuchet` stands at the foot of the east abutment's ramp, at [192, 548], 22 m east of the Cannon line's [170, 540] waypoint: at [170, 545] it caught the Cannon bot on 5 of 8 seeds and threw it 260 m over the crest with no anchor in reach (the 40 m anchor band). It stays a momentum tool a player takes on purpose (`wardens/reactor.md` section 3.1: none is required).

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

Dressed geometry candidate `1a7d598`, after merging `1fb07b1`. Final eight-seed receipts are pending. The anchor repair was qualified on `cacaba8`; its nearby-line reruns are in `/tmp/claude-1000/w13-sol/kd1-dam-r2/anchor-try1/`. The historical table below is the merged-kit baseline until the final sweep fills it.

| Line | Route after the domes | Length ratio (1.3 to 2.0) | Segment medians s (12 to 45) | Drop-in to Warden s, median (worst) (60 to 120, none over 150) | Peak m/s, median | Airborne share |
| --- | --- | --- | --- | --- | --- | --- |
| Sable | shelf A loop, west wash, west (tunnel, bucket, pool) | 1.640 | 27.65, 17.12, 17.31 | 62.03 (66.86) | 54.12 | 0.2486 |
| Rivet | shelf B, upper slot, centre (incline, apron) | 1.325 | 38.29, 29.59, 13.49 | 81.83 (82.29) | 42.62 | 0.1633 |
| Kest | shelf C, corkscrew, east (bridge, bench) | 1.340 | 30.37, 30.55, 22.38 | 83.75 (86.02) | 31.65 | 0.2832 |
| Tarn | shelf B, upper slot, west (tunnel, bucket, pool; the waypoints in the lines file) | 1.380 | 31.63, 26.62, 16.31 | 74.72 (76.10) | 39.59 | 0.2158 |
| Tally | shelf C, west wash, plunge pool | 1.320 | 31.94, 31.26, 17.17 | 81.07 (82.30) | 44.58 | 0.1643 |
| Cannon | shelf C, corkscrew, crest | 1.450 | 29.54, 29.60, 25.21 | 84.39 (85.07) | 36.67 | 0.1751 |
| Floor line | shelf B, upper slot, west (tunnel, bucket, pool), no contraption | 1.380 | 38.70, 31.42, 15.85 | 85.98 (87.16) | 42.70 | 0.1148 |

The baseline table above predates dressing. The final sweep must pass every pilot band, using worst seeds for per-seed limits. The floor is judged by its own row only. The batch anchor repair passed on all eight Sable seeds, with a worst gap of 36.4 m and zero dead stops. The shared process-history defect belongs to TRAV-DET; isolated seed runs do not qualify this stage.

Three line re-cuts on the KB9 head, each from a traced seed. Sable's line goes straight at `domes_camp` from [-60, -450]: at 40 m/s she passed 16.6 m from the camp and looped for 75 s to come back within the bot's 12 m. Her east turn on the shelf loop moves to [-25, -555], short of `domes_fin_east`. Her wash entry point moves onto the wash axis at [-137, -190]. Cannon's descent turns east at [120, 285] and [145, 350], so she lands east of `powerhouse_stair` and clear of the `rim_zip` head, and her bench points ([150, 410], [156, 470]) keep 10 m off the `canal_lips` ridge.

The shipped pilot lines (`tools/park_lines/park_dam.json`):

```json
{
  "map": "park_dam",
  "stage": 1,
  "pilots": {
    "sable": {"waypoints": ["drop_in", [-260, -660], [-370, -600], [-360, -520], [-180, -545], [-25, -555], [-60, -450], "domes_camp", [-90, -310], [-137, -190], [-99, -60], [-65, 60], [-15, 130], "the_eye", [0, 255], [-120, 370], [-135, 410], [-100, 445], [-90, 480], [-45, 530], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}},
    "rivet": {"waypoints": ["drop_in", [-30, -650], [-65, -555], [-250, -530], [-130, -450], "domes_camp", [-58, -372], [-90, -310], [-68, -220], [-43, -60], [-23, 60], [-12, 130], "the_eye", [-25, 250], [-25, 285], [-35, 330], [-42, 370], [-30, 400], [-30, 425], [-30, 500], [0, 520], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}},
    "kest": {"waypoints": ["drop_in", [-150, -630], [20, -650], [95, -560], [-5, -450], "domes_camp", [-58, -372], [-90, -310], [11, -240], [12, -150], [20, 0], [18, 90], [8, 130], "the_eye", [15, 250], [65, 285], [95, 300], [110, 300], [60, 520], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}},
    "tarn": {"waypoints": ["drop_in", [-30, -650], [-65, -555], [-250, -530], [-130, -450], "domes_camp", [-58, -372], [-90, -310], [-68, -220], [-43, -60], [-23, 60], [-12, 130], "the_eye", [-55, 235], [-65, 285], [-100, 315], [-109, 410], [-100, 445], [-90, 480], [-45, 530], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}},
    "tally": {"waypoints": ["drop_in", [-150, -630], [20, -650], [95, -560], [-5, -450], "domes_camp", [-58, -372], [-90, -310], [-140, -220], [-99, -60], [-65, 60], [-15, 130], "the_eye", [-12, 250], [-30, 285], [-45, 360], [-55, 450], [-80, 505], [-45, 545], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}},
    "cannon": {"waypoints": ["drop_in", [-150, -630], [20, -650], [95, -560], [-5, -450], "domes_camp", [-58, -372], [-90, -310], [11, -240], [12, -150], [20, 0], [18, 90], [8, 130], "the_eye", [15, 250], [65, 285], [120, 285], [145, 350], [150, 410], [156, 470], [170, 540], [100, 560], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}}
  },
  "floor": {"waypoints": ["drop_in", [-30, -650], [-65, -555], [-250, -530], [-130, -450], "domes_camp", [-85, -385], [-95, -330], [-90, -310], [-68, -220], [-43, -60], [-23, 60], [-12, 130], "the_eye", [-55, 235], [-65, 285], [-100, 315], [-109, 410], [-100, 445], [-90, 480], [-45, 530], "landmark"]}
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

## 13. The park file

Dressed candidate measured on `1a7d598`. The file has 176 park rows, 6 events, 5 homes, 9 contraptions and 3 activities. Bake and graph are committed under `assets/park/park_dam/`. The Warden remains reactor / dam_face / harpoon_anchor, and the two floods remain 1.2 m.

| Pocket | Role | Door | door_m | detour_m | d_spawn | d_landmark | sight_ok | pay.rarities |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `domes_camp` | online | [-48, -392] | 0 | 0 | 344 | 1016 | True | ['common'] |
| `rim_cache` | reward | [-208, 304] | 307 | 307 | 1065 | 424 | True | ['rare'] |
| `bench_altar` | risk | [208, 248] | 251 | 251 | 1137 | 454 | True | ['common', 'rare'] |
| `gallery_valve` | hidden | [-168, 544] | 241 | 259 | 1392 | 196 | True | [] |

Spawn to beacon is 1350 m by path. Spawn.run is True, beacon_ok is True, and breaches are []. reward_ratio 0.842 and full_visit_ratio 1.716 are reported targets. The hidden pocket keeps its beacon-distance exemption.

The shipped park file:

```json
{
 "schema": "scrapkeep-park/1",
 "map": "park_dam",
 "size_m": 1600,
 "time_of_day": "dawn",
 "spawn": {"at": [-150, -690], "heading_deg": 20},
 "play_rect": [-760, -780, 1520, 1480],
 "landmark": {"id": "spillway_dam", "kind": "dam", "at": [0, 620], "size": [120, 120, 320], "yaw_deg": 180, "recipe": "landmark_dam", "budget": "hero_landmark", "sight_top": [0, 141, 640], "sight_share": 0.85, "beacon": [0, 575], "reach_m": 30, "warden": {"family": "reactor", "mounting": "dam_face", "anchor": [0, 22, 590], "path": [], "hardpoints": 3, "harpoon_anchor": true}, "bay_dock": {"at": [0, 467], "facing_deg": 0}, "gate_slots": [{"at": [-16, 528], "facing_deg": 0}, {"at": [0, 528], "facing_deg": 0}, {"at": [16, 528], "facing_deg": 0}], "light": "ancient_beam", "music": "landmark_hum", "fragment": "dam_dedication_plaque"},
 "waymarks": ["drop_in", "domes_camp", "the_eye", "landmark"],
 "routes": [
  {"id": "shelf", "from": "drop_in", "to": "shelf_lip", "via": ["top_shelf_deck", "slickrock_domes"]},
  {"id": "west_wash_run", "from": "shelf_lip", "to": "the_eye", "via": ["west_wash_piece_n2", "west_wash_piece_n1", "west_wash", "west_wash_piece_1", "west_wash_piece_2"]},
  {"id": "upper_slot_run", "from": "shelf_lip", "to": "the_eye", "via": ["upper_slot_piece_n3", "upper_slot_piece_n2", "upper_slot_piece_n1", "upper_slot", "upper_slot_piece_1", "upper_slot_piece_2", "upper_slot_piece_3"]},
  {"id": "corkscrew_run", "from": "shelf_lip", "to": "the_eye", "via": ["corkscrew_slot_piece_n2", "corkscrew_slot_piece_n1", "corkscrew_slot", "corkscrew_slot_piece_1", "corkscrew_slot_piece_2", "corkscrew_slot_piece_3"]},
  {"id": "pool_floor", "from": "the_eye", "to": "toe_apron", "via": ["the_eye", "west_rim_bench_piece_n1", "west_rim_bench", "west_rim_bench_piece_1", "spillway_tunnel_piece_n1", "spillway_tunnel", "outlet_bucket", "plunge_pool"]},
  {"id": "pool_rim", "from": "the_eye", "to": "toe_apron", "via": ["the_eye", "west_rim_bench_piece_n1", "west_rim_bench", "west_rim_bench_piece_1", "spillway_tunnel_piece_n1", "spillway_tunnel", "outlet_bucket", "service_ledge", "plunge_pool"]},
  {"id": "bucket_flight", "from": "the_eye", "to": "toe_apron", "via": ["the_eye", "west_rim_bench_piece_n1", "west_rim_bench", "west_rim_bench_piece_1", "spillway_tunnel_piece_n1", "spillway_tunnel", "outlet_bucket"]},
  {"id": "ledge_line", "from": "the_eye", "to": "toe_apron", "via": ["the_eye", "west_rim_bench_piece_n1", "west_rim_bench", "west_rim_bench_piece_1", "cliff_rooms_west_piece_n1", "cliff_rooms_west", "cliff_rooms_west_piece_1", "viga_span", "service_ledge"]},
  {"id": "ledge_drop", "from": "the_eye", "to": "toe_apron", "via": ["the_eye", "west_rim_bench_piece_n1", "west_rim_bench", "west_rim_bench_piece_1", "service_ledge", "plunge_pool"]},
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
  {"id": "west_wash_terrain", "element": "ground", "landform": "arroyo", "society": "dam_era", "at": [-102.5, -75.0], "y": null, "size": [397.0, 10, 44], "yaw_deg": 16.8, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "west_wash_piece_n2", "element": "half_pipe", "landform": "arroyo", "society": "dam_era", "at": [-137.1838, -189.8783], "y": null, "size": [60, 11.9797, 34.64], "yaw_deg": 16.8, "verb": "pump", "ride_fact": "ride_chute", "home": "", "recipe": "half_pipe_concrete", "stamp": "", "hole": false, "budget": "landform", "routes": ["west_wash_run"], "fragment": ""},
  {"id": "west_wash_piece_n1", "element": "half_pipe", "landform": "arroyo", "society": "dam_era", "at": [-119.8419, -132.4392], "y": null, "size": [60, 11.9797, 34.64], "yaw_deg": 16.8, "verb": "pump", "ride_fact": "ride_chute", "home": "", "recipe": "half_pipe_concrete", "stamp": "", "hole": false, "budget": "landform", "routes": ["west_wash_run"], "fragment": ""},
  {"id": "west_wash", "element": "half_pipe", "landform": "arroyo", "society": "dam_era", "at": [-102.5, -75.0], "y": null, "size": [60, 11.9797, 34.64], "yaw_deg": 16.8, "verb": "pump", "ride_fact": "ride_chute", "home": "culvert_chasers", "recipe": "half_pipe_concrete", "stamp": "", "hole": false, "budget": "landform", "routes": ["west_wash_run"], "fragment": "dam_era_wash_liner"},
  {"id": "west_wash_piece_1", "element": "half_pipe", "landform": "arroyo", "society": "dam_era", "at": [-85.1581, -17.5608], "y": null, "size": [60, 11.9797, 34.64], "yaw_deg": 16.8, "verb": "pump", "ride_fact": "ride_chute", "home": "", "recipe": "half_pipe_concrete", "stamp": "", "hole": false, "budget": "landform", "routes": ["west_wash_run"], "fragment": ""},
  {"id": "west_wash_piece_2", "element": "half_pipe", "landform": "arroyo", "society": "dam_era", "at": [-67.8162, 39.8783], "y": null, "size": [60, 11.9797, 34.64], "yaw_deg": 16.8, "verb": "pump", "ride_fact": "ride_chute", "home": "", "recipe": "half_pipe_concrete", "stamp": "", "hole": false, "budget": "landform", "routes": ["west_wash_run"], "fragment": ""},
  {"id": "upper_slot_terrain", "element": "ground", "landform": "slot_canyon", "society": "none", "at": [-45.0, -75.0], "y": null, "size": [384.7, 2, 30], "yaw_deg": 9.0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "upper_slot_piece_n3", "element": "flow_line", "landform": "slot_canyon", "society": "none", "at": [-67.5266, -217.2271], "y": null, "size": [48, 14.4202, 26], "yaw_deg": 9.0, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "slot_canyon_flow", "stamp": "", "hole": false, "budget": "landform", "routes": ["upper_slot_run"], "fragment": ""},
  {"id": "upper_slot_piece_n2", "element": "flow_line", "landform": "slot_canyon", "society": "none", "at": [-60.0177, -169.8181], "y": null, "size": [48, 14.4202, 26], "yaw_deg": 9.0, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "slot_canyon_flow", "stamp": "", "hole": false, "budget": "landform", "routes": ["upper_slot_run"], "fragment": ""},
  {"id": "upper_slot_piece_n1", "element": "flow_line", "landform": "slot_canyon", "society": "none", "at": [-52.5089, -122.409], "y": null, "size": [48, 14.4202, 26], "yaw_deg": 9.0, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "slot_canyon_flow", "stamp": "", "hole": false, "budget": "landform", "routes": ["upper_slot_run"], "fragment": ""},
  {"id": "upper_slot", "element": "flow_line", "landform": "slot_canyon", "society": "none", "at": [-45.0, -75.0], "y": null, "size": [48, 14.4202, 26], "yaw_deg": 9.0, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "slot_canyon_flow", "stamp": "", "hole": false, "budget": "landform", "routes": ["upper_slot_run"], "fragment": ""},
  {"id": "upper_slot_piece_1", "element": "flow_line", "landform": "slot_canyon", "society": "none", "at": [-37.4911, -27.591], "y": null, "size": [48, 14.4202, 26], "yaw_deg": 9.0, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "slot_canyon_flow", "stamp": "", "hole": false, "budget": "landform", "routes": ["upper_slot_run"], "fragment": ""},
  {"id": "upper_slot_piece_2", "element": "flow_line", "landform": "slot_canyon", "society": "none", "at": [-29.9823, 19.8181], "y": null, "size": [48, 14.4202, 26], "yaw_deg": 9.0, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "slot_canyon_flow", "stamp": "", "hole": false, "budget": "landform", "routes": ["upper_slot_run"], "fragment": ""},
  {"id": "upper_slot_piece_3", "element": "flow_line", "landform": "slot_canyon", "society": "none", "at": [-22.4734, 67.2271], "y": null, "size": [48, 14.4202, 26], "yaw_deg": 9.0, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "slot_canyon_flow", "stamp": "", "hole": false, "budget": "landform", "routes": ["upper_slot_run"], "fragment": ""},
  {"id": "corkscrew_slot_terrain", "element": "ground", "landform": "slot_canyon", "society": "none", "at": [15.0, -75.0], "y": null, "size": [380.1, 2, 34], "yaw_deg": 1.5, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "corkscrew_slot_piece_n2", "element": "flow_line", "landform": "slot_canyon", "society": "none", "at": [12.487, -170.9671], "y": null, "size": [48, 14.4202, 26], "yaw_deg": 1.5, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "slot_canyon_flow", "stamp": "", "hole": false, "budget": "landform", "routes": ["corkscrew_run"], "fragment": ""},
  {"id": "corkscrew_slot_piece_n1", "element": "flow_line", "landform": "slot_canyon", "society": "none", "at": [13.7435, -122.9836], "y": null, "size": [48, 14.4202, 26], "yaw_deg": 1.5, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "slot_canyon_flow", "stamp": "", "hole": false, "budget": "landform", "routes": ["corkscrew_run"], "fragment": ""},
  {"id": "corkscrew_slot", "element": "flow_line", "landform": "slot_canyon", "society": "none", "at": [15.0, -75.0], "y": null, "size": [48, 14.4202, 26], "yaw_deg": 1.5, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "slot_canyon_flow", "stamp": "", "hole": false, "budget": "landform", "routes": ["corkscrew_run"], "fragment": ""},
  {"id": "corkscrew_slot_piece_1", "element": "flow_line", "landform": "slot_canyon", "society": "none", "at": [16.2565, -27.0164], "y": null, "size": [48, 14.4202, 26], "yaw_deg": 1.5, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "slot_canyon_flow", "stamp": "", "hole": false, "budget": "landform", "routes": ["corkscrew_run"], "fragment": ""},
  {"id": "corkscrew_slot_piece_2", "element": "flow_line", "landform": "slot_canyon", "society": "none", "at": [17.513, 20.9671], "y": null, "size": [48, 14.4202, 26], "yaw_deg": 1.5, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "slot_canyon_flow", "stamp": "", "hole": false, "budget": "landform", "routes": ["corkscrew_run"], "fragment": ""},
  {"id": "corkscrew_slot_piece_3", "element": "flow_line", "landform": "slot_canyon", "society": "none", "at": [18.7695, 68.9507], "y": null, "size": [48, 14.4202, 26], "yaw_deg": 1.5, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "slot_canyon_flow", "stamp": "", "hole": false, "budget": "landform", "routes": ["corkscrew_run"], "fragment": ""},
  {"id": "wash_fin_west", "element": "elevated_line", "landform": "slickrock", "society": "none", "at": [-157.5, -70.0], "y": null, "size": [358.9, 26, 22], "yaw_deg": 18.7, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "greybox:elevated_line", "stamp": "ridge", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "slot_fin_west", "element": "elevated_line", "landform": "slickrock", "society": "none", "at": [-81.4577, -84.7089], "y": null, "size": [240.0, 26, 22], "yaw_deg": 14.0, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "greybox:elevated_line", "stamp": "ridge", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
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
  {"id": "eye_chute_west", "element": "elevated_line", "landform": "river_canyon", "society": "none", "at": [-28, 224], "y": null, "size": [52.0, 22, 8], "yaw_deg": 0.0, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "greybox:elevated_line", "stamp": "ridge", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "eye_chute_east", "element": "elevated_line", "landform": "river_canyon", "society": "none", "at": [28.0, 224.0], "y": null, "size": [52.0, 15, 8], "yaw_deg": 0.0, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "greybox:elevated_line", "stamp": "ridge", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "pool_rock", "element": "elevated_line", "landform": "dam_face", "society": "none", "at": [-120, 500], "y": null, "size": [20, 14, 20], "yaw_deg": 0, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "greybox:elevated_line", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "pool_pillar", "element": "elevated_line", "landform": "dam_face", "society": "dam_era", "at": [-62, 560], "y": null, "size": [16, 14, 16], "yaw_deg": 0, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "greybox:elevated_line", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "west_lane_fin", "element": "elevated_line", "landform": "mesa_rim", "society": "none", "at": [-70.0, 410], "y": null, "size": [60, 19.0219, 34.1729], "yaw_deg": 0, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "mesa_rim_ledge", "stamp": "", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "west_lane_fin_piece_1", "element": "elevated_line", "landform": "mesa_rim", "society": "none", "at": [-70.0, 452.5], "y": null, "size": [60, 19.0219, 34.1729], "yaw_deg": -90, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "mesa_rim_ledge", "stamp": "", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "east_lane_fin_terrain", "element": "ground", "landform": "mesa_rim", "society": "none", "at": [70.0, 392.5], "y": null, "size": [155.0, 26, 20], "yaw_deg": 0.0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "ridge", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "east_lane_fin_piece_n1", "element": "elevated_line", "landform": "mesa_rim", "society": "none", "at": [70.0, 332.5], "y": null, "size": [60, 19.0219, 34.1729], "yaw_deg": 0.0, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "mesa_rim_ledge", "stamp": "", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "east_lane_fin", "element": "elevated_line", "landform": "mesa_rim", "society": "none", "at": [70.0, 392.5], "y": null, "size": [60, 19.0219, 34.1729], "yaw_deg": 0.0, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "mesa_rim_ledge", "stamp": "", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "east_lane_fin_piece_1", "element": "elevated_line", "landform": "mesa_rim", "society": "none", "at": [70.0, 452.5], "y": null, "size": [60, 19.0219, 34.1729], "yaw_deg": 0.0, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "mesa_rim_ledge", "stamp": "", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "incline_spine_terrain", "element": "ground", "landform": "mesa_rim", "society": "dam_era", "at": [15.0, 370.0], "y": null, "size": [100.0, 20, 16], "yaw_deg": 0.0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "ridge", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "incline_spine", "element": "elevated_line", "landform": "mesa_rim", "society": "dam_era", "at": [40, 370], "y": null, "size": [60, 19.0219, 34.1729], "yaw_deg": 0.0, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "mesa_rim_ledge", "stamp": "", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "training_wall_west", "element": "elevated_line", "landform": "dam_face", "society": "dam_era", "at": [-28.0, 492.5], "y": null, "size": [55.0, 14, 8], "yaw_deg": 0.0, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "greybox:elevated_line", "stamp": "ridge", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "training_wall_east", "element": "elevated_line", "landform": "dam_face", "society": "dam_era", "at": [50.0, 502.5], "y": null, "size": [65.0, 8, 8], "yaw_deg": 0.0, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "greybox:elevated_line", "stamp": "ridge", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "west_rim_bench_terrain", "element": "ground", "landform": "mesa_rim", "society": "dam_era", "at": [-235, 300], "y": null, "size": [220, 4, 60], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "bowl", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "west_rim_bench_piece_n1", "element": "bank", "landform": "mesa_rim", "society": "dam_era", "at": [-235.0, 240.0], "y": null, "size": [60, 19.0219, 34.1729], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "mesa_rim_ledge", "stamp": "", "hole": false, "budget": "landform", "routes": ["pool_floor", "pool_rim", "bucket_flight", "ledge_line", "ledge_drop"], "fragment": ""},
  {"id": "west_rim_bench", "element": "bank", "landform": "mesa_rim", "society": "dam_era", "at": [-235.0, 300.0], "y": null, "size": [60, 19.0219, 34.1729], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "mesa_rim_ledge", "stamp": "", "hole": false, "budget": "landform", "routes": ["pool_floor", "pool_rim", "bucket_flight", "ledge_line", "ledge_drop"], "fragment": "dam_era_overflow_channel"},
  {"id": "west_rim_bench_piece_1", "element": "bank", "landform": "mesa_rim", "society": "dam_era", "at": [-235.0, 360.0], "y": null, "size": [60, 19.0219, 34.1729], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "mesa_rim_ledge", "stamp": "", "hole": false, "budget": "landform", "routes": ["pool_floor", "pool_rim", "bucket_flight", "ledge_line", "ledge_drop"], "fragment": ""},
  {"id": "spillway_tunnel_terrain", "element": "ground", "landform": "spillway_tunnel", "society": "dam_era", "at": [-150, 330], "y": null, "size": [200, 4, 60], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "park_large", "routes": [], "fragment": ""},
  {"id": "spillway_tunnel_piece_n1", "element": "tunnel", "landform": "spillway_tunnel", "society": "dam_era", "at": [-150.0, 240.0], "y": null, "size": [90, 46.1333, 15.0], "yaw_deg": 0, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "spillway_tunnel", "stamp": "", "hole": false, "budget": "park_large", "routes": ["pool_floor", "pool_rim", "bucket_flight"], "fragment": ""},
  {"id": "spillway_tunnel", "element": "tunnel", "landform": "spillway_tunnel", "society": "dam_era", "at": [-150.0, 330.0], "y": null, "size": [90, 46.1333, 15.0], "yaw_deg": 0, "verb": "drop", "ride_fact": "ride_drop", "home": "outlet_brutes", "recipe": "spillway_tunnel", "stamp": "", "hole": false, "budget": "park_large", "routes": ["pool_floor", "pool_rim", "bucket_flight"], "fragment": "dam_era_tunnel_gauge"},
  {"id": "outlet_bucket", "element": "kicker", "landform": "spillway_tunnel", "society": "dam_era", "at": [-100, 445], "y": null, "size": [16, 0, 24], "yaw_deg": 15, "verb": "launch", "ride_fact": "kicker_launch", "home": "", "recipe": "greybox:kicker", "stamp": "plateau", "hole": false, "budget": "detail", "routes": ["pool_floor", "pool_rim", "bucket_flight"], "fragment": ""},
  {"id": "outlet_bucket_ramp", "element": "ground", "landform": "spillway_tunnel", "society": "dam_era", "at": [-100, 445], "y": null, "size": [16, 4, 24], "yaw_deg": 195, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "ramp", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "cliff_rooms_west_terrain", "element": "ground", "landform": "cliff_dwelling", "society": "ancestral_puebloan", "at": [-190, 330], "y": null, "size": [160, 8, 16], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "ridge", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "cliff_rooms_west_piece_n1", "element": "elevated_line", "landform": "cliff_dwelling", "society": "ancestral_puebloan", "at": [-190.0, 270.0], "y": null, "size": [60, 22.3102, 21.287], "yaw_deg": 0, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "cliff_dwelling_row", "stamp": "", "hole": false, "budget": "landform", "routes": ["ledge_line"], "fragment": ""},
  {"id": "cliff_rooms_west", "element": "elevated_line", "landform": "cliff_dwelling", "society": "ancestral_puebloan", "at": [-190.0, 330.0], "y": null, "size": [60, 22.3102, 21.287], "yaw_deg": 0, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "cliff_dwelling_row", "stamp": "", "hole": false, "budget": "landform", "routes": ["ledge_line"], "fragment": "ref_cliff_rooms"},
  {"id": "cliff_rooms_west_piece_1", "element": "elevated_line", "landform": "cliff_dwelling", "society": "ancestral_puebloan", "at": [-190.0, 390.0], "y": null, "size": [60, 22.3102, 21.287], "yaw_deg": 0, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "cliff_dwelling_row", "stamp": "", "hole": false, "budget": "landform", "routes": ["ledge_line"], "fragment": ""},
  {"id": "viga_span", "element": "anchor_field", "landform": "cliff_dwelling", "society": "ancestral_puebloan", "at": [-190.0, 425.0], "y": null, "size": [36, 18.7, 20.02], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "viga_pivot", "stamp": "", "hole": false, "budget": "landform", "routes": ["ledge_line"], "fragment": "ref_viga_beams"},
  {"id": "service_ledge_terrain", "element": "ground", "landform": "mesa_rim", "society": "dam_era", "at": [-180, 520], "y": null, "size": [90, 24, 30], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "service_ledge", "element": "ledge", "landform": "mesa_rim", "society": "dam_era", "at": [-180, 505], "y": null, "size": [60, 19.0219, 34.1729], "yaw_deg": 180, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "mesa_rim_ledge", "stamp": "", "hole": false, "budget": "landform", "routes": ["ledge_line", "pool_rim", "ledge_drop"], "fragment": "dam_era_ledge_stencil"},
  {"id": "service_ledge_gallery", "element": "ledge", "landform": "mesa_rim", "society": "dam_era", "at": [-180.0, 538.0], "y": null, "size": [60, 19.0219, 34.1729], "yaw_deg": -90, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "mesa_rim_ledge", "stamp": "", "hole": false, "budget": "landform", "routes": ["ledge_line", "pool_rim", "ledge_drop"], "fragment": ""},
  {"id": "lobber_ledge_terrain", "element": "ground", "landform": "mesa_rim", "society": "dam_era", "at": [-185, 455], "y": null, "size": [30, 24, 26], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "plateau", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "lobber_ledge", "element": "ledge", "landform": "mesa_rim", "society": "dam_era", "at": [-185.0, 455.0], "y": null, "size": [60, 19.0219, 34.1729], "yaw_deg": 0, "verb": "roll", "ride_fact": "ride_ledge", "home": "ledge_lobbers", "recipe": "mesa_rim_ledge", "stamp": "", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "construction_incline", "element": "drop", "landform": "mesa_rim", "society": "dam_era", "at": [0, 330], "y": null, "size": [230, 1, 100], "yaw_deg": 180, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:drop", "stamp": "ramp", "hole": false, "budget": "landform", "routes": ["incline_line"], "fragment": "dam_era_incline_tally"},
  {"id": "tailwater_bar_terrain", "element": "ground", "landform": "dry_wash", "society": "none", "at": [-20, 460], "y": null, "size": [70, 2, 60], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "tailwater_bar", "element": "flow_line", "landform": "dry_wash", "society": "none", "at": [-30, 460.0], "y": null, "size": [60, 11.9797, 34.64], "yaw_deg": 0, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "half_pipe_concrete", "stamp": "", "hole": false, "budget": "landform", "routes": ["incline_line"], "fragment": ""},
  {"id": "pipeline_bridge_terrain", "element": "ground", "landform": "pipeline", "society": "dam_era", "at": [130, 260], "y": null, "size": [80, 3, 6], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "ridge", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "pipeline_bridge", "element": "grind_line", "landform": "pipeline", "society": "dam_era", "at": [130.0, 260.0], "y": null, "size": [120.4797, 11.0151, 4.4784], "yaw_deg": 0, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "pipeline_rail", "stamp": "", "hole": false, "budget": "landform", "routes": ["canal_run", "dropship_ramp", "crest_line"], "fragment": "dam_era_bridge_plate"},
  {"id": "east_bench_flats", "element": "ground", "landform": "slickrock", "society": "none", "at": [165, 475], "y": null, "size": [90, 6, 70], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "dropship_winches", "recipe": "", "stamp": "", "hole": false, "budget": "landform", "routes": ["canal_run", "dropship_ramp", "crest_line"], "fragment": ""},
  {"id": "canal_lips_terrain", "element": "ground", "landform": "canal", "society": "dam_era", "at": [170, 380], "y": null, "size": [120, 3, 8], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "ridge", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "canal_lips", "element": "grind_line", "landform": "canal", "society": "dam_era", "at": [170.0, 380.0], "y": null, "size": [120.1375, 11.0967, 12.018], "yaw_deg": 0, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "canal_lip", "stamp": "", "hole": false, "budget": "landform", "routes": ["canal_run"], "fragment": "dam_era_canal_headworks"},
  {"id": "east_haul_road", "element": "drop", "landform": "mesa_rim", "society": "dam_era", "at": [135, 330], "y": null, "size": [220, 1, 110], "yaw_deg": 180, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:drop", "stamp": "ramp", "hole": false, "budget": "landform", "routes": ["canal_run"], "fragment": "dam_era_haul_sign"},
  {"id": "east_abutment", "element": "ledge", "landform": "dam_face", "society": "dam_era", "at": [170, 585], "y": null, "size": [60, 16, 50], "yaw_deg": 180, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "greybox:ledge", "stamp": "ramp", "hole": false, "budget": "landform", "routes": ["crest_line"], "fragment": ""},
  {"id": "canyon_hook_fin", "element": "elevated_line", "landform": "river_canyon", "society": "none", "at": [-65, 360], "y": null, "size": [52, 30, 8], "yaw_deg": 0, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "greybox:elevated_line", "stamp": "ridge", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "eye_fall_spire_east", "element": "elevated_line", "landform": "river_canyon", "society": "none", "at": [15, 300], "y": null, "size": [30, 45, 16], "yaw_deg": 0, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "greybox:elevated_line", "stamp": "spire", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "apron_kicker", "element": "kicker", "landform": "dry_wash", "society": "none", "at": [0, 448], "y": null, "size": [20, 0, 26], "yaw_deg": 0, "verb": "launch", "ride_fact": "kicker_launch", "home": "", "recipe": "greybox:kicker", "stamp": "plateau", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "apron_kicker_ramp", "element": "ground", "landform": "dry_wash", "society": "none", "at": [0, 448], "y": null, "size": [20, 5, 26], "yaw_deg": 180, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "ramp", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "plunge_pool", "element": "bowl", "landform": "dam_face", "society": "dam_era", "at": [-85, 515], "y": null, "size": [110, 8, 110], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:bowl", "stamp": "bowl", "hole": false, "budget": "landform", "routes": ["pool_floor", "pool_rim", "ledge_drop"], "fragment": ""},
  {"id": "toe_apron", "element": "bank", "landform": "dam_face", "society": "dam_era", "at": [0, 520], "y": null, "size": [160, 2, 140], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:bank", "stamp": "bowl", "hole": false, "budget": "landform", "routes": ["face", "powerhouse_floor", "roof_ramp_line"], "fragment": ""},
  {"id": "powerhouse", "element": "ledge", "landform": "dam_face", "society": "dam_era", "at": [120, 515], "y": null, "size": [60, 20, 40], "yaw_deg": 0, "verb": "roll", "ride_fact": "ride_ledge", "home": "powerhouse_trappers", "recipe": "greybox:ledge", "stamp": "plateau", "hole": false, "budget": "landform", "routes": ["powerhouse_floor", "roof_ramp_line"], "fragment": "dam_era_powerhouse_log"},
  {"id": "powerhouse_stair", "element": "ground", "landform": "dam_face", "society": "dam_era", "at": [120, 455], "y": null, "size": [60, 20, 16], "yaw_deg": 180, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "ramp", "hole": false, "budget": "landform", "routes": ["powerhouse_floor", "roof_ramp_line"], "fragment": ""},
  {"id": "powerhouse_roof_ramp", "element": "bank", "landform": "dam_face", "society": "dam_era", "at": [92, 515], "y": null, "size": [60, 2, 16], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:bank", "stamp": "bowl", "hole": false, "budget": "detail", "routes": ["roof_ramp_line"], "fragment": ""},
  {"id": "toe_vent_pits", "element": "bowl", "landform": "dam_face", "society": "ancient", "at": [165, 430], "y": null, "size": [50, 3, 50], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:bowl", "stamp": "bowl", "hole": false, "budget": "detail", "routes": [], "fragment": "ancient_vent_plate"},
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
  {"id": "saguaro_24", "element": "anchor_field", "landform": "saguaro_stand", "society": "none", "at": [170, -140], "y": null, "size": [320, 2, 260], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
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
  {"id": "east_rim_bench_terrain", "element": "ground", "landform": "mesa_rim", "society": "none", "at": [235, 260], "y": null, "size": [160, 4, 60], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "bowl", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "east_rim_bench_piece_n1", "element": "bank", "landform": "mesa_rim", "society": "none", "at": [235.0, 200.0], "y": null, "size": [60, 19.0219, 34.1729], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "mesa_rim_ledge", "stamp": "", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "east_rim_bench", "element": "bank", "landform": "mesa_rim", "society": "none", "at": [235.0, 260.0], "y": null, "size": [60, 19.0219, 34.1729], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "mesa_rim_ledge", "stamp": "", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "east_rim_bench_piece_1", "element": "bank", "landform": "mesa_rim", "society": "none", "at": [235.0, 320.0], "y": null, "size": [60, 19.0219, 34.1729], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "mesa_rim_ledge", "stamp": "", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
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
  {"id": "rim_cache", "activity": "cracked_cache", "site": "west_rim_bench", "at": [-206, 300], "pack": [], "pay": {"rarities": ["rare"]}},
  {"id": "bench_altar", "activity": "ambush_altar", "site": "east_rim_bench", "at": [206, 250], "pack": [], "pay": {"rarities": ["common", "rare"]}}
 ]
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

**Frame 5, the landmark approach.** Off the construction incline, the camera falling with the ball down the canyon wall toward the toe; the dam fills the frame, 120 m of curved concrete, the relic a squat green-seamed drum clamped to its centre 22 m up, the powerhouse steaming to the right.

**Frame 6, the Warden fight.** From the toe apron looking up the face: the gates over the relic open, a white water sheet pouring down the face, and the ball riding up the sheet toward the relic's open core, a harpoon line taut from a gate pier to the ball.

**Frame 7, the exit.** After the break: the three gates on the apron, Moss's bay hovering behind them, and the ball arcing up the face and over the crest, the reservoir and a far mesa with a weir on it in the morning haze.
