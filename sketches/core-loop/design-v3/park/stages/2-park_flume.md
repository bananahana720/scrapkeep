# Stage 2, `park_flume`: Spillway: the flume

World 1, Spillway Works, the world's last stage before Brindle. Warden kind `reactor` on the `flume` mounting, variant `meltdown`. Time of day `morning`. Storyboard board id `park-2-park_flume`. Status: draft for Andrew's approval (unit K-W1, 2026-10-10). Every number is a starting value to tune in play unless a file:line backs it.

This page follows `design-v3/PARK.md` section 2 and `adr/TADR-011-park-terrain-and-warden-kinds.md`. The draft park file in section 13 passed a scratch copy of the 2.10 checks, the route test and the line estimates in section 9. The name "The Cable Reach" retires (PARK.md:573).

## 1. The stage in one paragraph

You drop in on the weir at the top of a mesa, where the reservoir behind stage 1's dam spills into a wooden flume. The flume runs 1.6 km across falling canal country on trestles that grow taller as the land drops away, and it ends at a penstock tower in the south-east, 90 m tall, with a green beam on top. You can ride the flume the whole way as one long grind, or drop off it into the canal fields, the trestle hollow, or the rim road above a horseshoe bend. The lines pinch twice, at a gap between two buttes and at the siphon where the canal dives under the hollow. They meet again in the head house at the tower's foot, where a reactor relic sits on the flume's last channel and boils it.

## 2. Arizona landform and society layer

**Landforms** (PARK.md:73). A weir on a 40 m mesa (`mesa_rim`), canal country falling 112 m along yaw 31 from north-west to south-east (`dry_wash` ground with a `ramp` stamp), Hohokam-style canals (`canal`), two buttes (`butte`), a trestle-spanned arroyo (`arroyo`), a horseshoe bend (`horseshoe_bend`, this stage's alone: the real one lies below a dam, in dam-era country) and a lower river gorge (`river_canyon`), the flume itself (`flume`) and the penstock works (`penstock`). Heights: the weir deck near y 146, the head house floor near y 29, the gorge floors about 95 m below their rims.

**Society layers.**

| Society | Where | What it left |
| --- | --- | --- |
| `none` | the buttes, the hollow, the bend, the gorges, the south bench | the ground itself |
| `dam_era` | the weir, the flume and its trestles, the rim road, the siphon, the wasteway, the forecourt, the head house and its annex | timber, concrete, gauges; the flume crews' signs |
| `hohokam` (reference) | the main canal, the gap cut, the lateral canal | graded canals, ridden as flow lines only |
| `dam_era` (crew camp) | the flume crews' bunk ledges cut into the mesa's south face and their timber crane booms | ledges and swing pivots; the cliff-dwelling layer is stage 1's, so world 1 shows each real culture once |
| `ancient` | the relic in the head house; a buried relic under the bend | uranium-glass green (#9dff3c) seams |
| `fleet` | a dropship lands on the south bench at tier 2 | a crew home |

The guardrail holds (PARK.md:301): the canal rows house no home, are no event's site (including the water events), and carry only `ref_` fragments. The flash flood runs in the dam-era wasteway, not in a canal.

## 3. The hero landmark and the Warden's mounting

**The penstock tower** (`landmark_penstock_tower`, `hero_landmark`). PARK.md:375 places "the flume head house at the top of the penstock tower". This draft reconciles that with the ground lines: the head house sits at the top of the penstocks, on the bluff edge where the flume ends, and the 90 m tower rises beside it as the surge tower. Every line then arrives at the head house on the ground, and the floor line can reach the Warden without a contraption (veto item 12, PARK.md:584). The penstocks leave the head house's east wall and fall 95 m down the bluff into the lower gorge. `sight_top` is the tower top, [300, 90, 560] in the shipped file; the land falls toward it from the whole park, so the drop-in looks down onto it. `light` is `ancient_beam`.

**The head house** is a round concrete drum 70 m across with 16 m walls (`head_house_drum`, a `bowl` row), roofed by open steel trusses at about 32 m. The flume enters through the north wall about 12 m up and pours down a channel onto the drum floor. Doors: the forecourt on the north-west, the annex on the south-west, the gate doors on the east facing the gorge.

**The mounting, `flume`** (PARK.md:425). The relic clamps onto the flume's pour channel, anchor [230, -2, 470], 12 m above the drum floor. Measured on the bake (KD2 fix round, 2026-10-11): the drum floor is y -14 (the `head_house_drum` terrace), the anchor y -2, and the `pour_channel` deck runs from the head reach's end at [200, 446] with its top at y -2, the anchor's height (`tests/park_park_flume_test.gd` pins it). The channel stops 38 m from the beacon, outside the 30 m engage disc, because a deck inside the disc fails `beacon_ok` (`tools/park_graph.gd:87-90`); the relic hangs at the channel's mouth and the reactor driver lays the slag lanes from its pour side (`warden_reactor.gd` `POUR_OFFSET`). The engage ring is the drum, centre [230, 480], `reach_m` 30, today's `beacon_radius` (`alpha_defs.gd:77`).

**What the mounting adds: it boils the flume.** Today's meltdown rule (`warden.gd:29-31`): every pulse leaves a slag lane toward the ball, 14 m long and 4 m wide, filling over 1 s and burning a grounded ball for 6 s at 4 damage a second (`warden.gd:56-60`, `263-291`). In the head house each lane pours out of the flume's channel and runs down the drum floor toward the ball, so the lanes come from one readable place. A ball in the air over a lane is safe and earns `slag_hop` (`codex_entries.gd:131-135`). The core window lasts 1.5 times longer, 6 s instead of 4 (`warden.gd:55`, `112-114`; `boss_posture.gd:17`).

## 4. Region sketch, and the exit to Brindle

Top-down, 80 m cells: the draft's region sketch, kept for the regions; `~` marks the draft's planned lines (the shipped lines are section 9). The placed list under it is generated from the shipped file (`src/world/park/park_flume.json`, KD2 fix round 2026-10-11): homes at their site row, contraptions at their `at` (a cable at its `from`), events at their site row.

```
x from -800 (left) to 800 m (right); z from -800 (top) to 800 m (bottom); one cell = 80 m
  -800 m m m m m n n n n n a a a a a o o o o o
  -720 m m m m D n n n n n a a a a a o o o o o
  -640 m m m ~ ~ ~ ~ n n n a a a a a o o o o o
  -560 m m ~ ~ ~ n ~ ~ n n a a a a a o o o o o
  -480 m ~ ~ ~ ~ C n n ~ n a a a a a o o o o o
  -400 f f f ~ ~ C n n ~ n a a a a a o o o o o
  -320 f f f f ~ H ~ ~ ~ r r r r r o o o o o o
  -240 f f f f f f ~ ~ ~ ~ C r r r o o o o o o
  -160 f f f f f f C ~ r r ~ ~ r r o o o o o o
   -80 f f f f f f ~ C r r r E r r o o o o o o
     0 f f f f f f ~ E ~ r ~ ~ r r o o o o o o
    80 f f f f f f ~ ~ ~ ~ ~ x q q o o o o o o
   160 s s s s s s s s ~ A ~ ~ ~ q o o o o o o
   240 s s s s s s s s ~ ~ E C ~ ~ o o o o o o
   320 s s s s s s s s s ~ C x q ~ l l l l l l
   400 s s s s s s s s s q ~ C ~ ~ l l l l l l
   480 s s s s s s s E A q q q W L l l l l l l
   560 s s s s s s s s s q q q q q l l l l l l
   640 s s s s s s s s s q q q q q l l l l l l
   720 s s s s s s s s s q q q q q l l l l l l
```

| Code | Region | What happens there |
| --- | --- | --- |
| m | The weir mesa | Drop-in, weir chute, the flume's intake, the crew camp ledges on the south face |
| n | Flume north reach | The flume's first kilometre on 40 to 50 m trestles |
| f | Canal fields | The main canal and the lateral canal, field banks, the flume trebuchet |
| g | The butte gap | First waymark: the canal and the flume thread between two buttes |
| h | The trestle hollow | An arroyo half-pipe under the flume's tallest trestles; drone home; the collapse |
| r | Rim road and the bend | The rim road over the horseshoe bend, the bend overlook, the buried relic |
| a | Upper canal country | Open ground cut by shallow dry washes (KD2's filler, section 5) |
| o | The horseshoe gorge and far rim | The bend's gorge, about 95 m deep |
| x | Siphon and wasteway | Second waymark (the siphon camp), the wasteway chute, the culvert wall |
| s | The south bench | Slickrock bench: the hauler bounty, the dropship landing |
| q | The bluff | The bluff rim, the forecourt, the head house, the annex, the tower |
| l | The lower gorge | The penstocks' fall; the launch to Brindle crosses it |

Placed things:

```
H weir_lobbers [-370, -340]
H trestle_drones [-185, 10]
H wasteway_chasers [85, 335]
H forecourt_brutes [150, 420]
H dropship_trappers [-300, 460]
C weir_valve [-160, -270]
C mesa_zip [-392, -442]
C hollow_lift [-210, -60]
C flume_trebuchet [-345, -120]
C forecourt_geyser [140, 400]
C squall_lane [120, 260]
C culvert_wall [117, 311]
C bend_zip [50, -170]
A siphon_camp [-28, 176]
A bend_cache [42, -142]
A bench_bounty [-119, 332]
E hollow_trestle_collapse [-185, 10]
E wasteway_flash_flood [85, 335]
E bench_dropship [-300, 460]
E bend_relic_wakes [150, -60]
E annex_reactor_blow [185, 525]
B bay dock [239, 480]
G gate row [300, 480]
L penstock_tower (landmark) [270, 510]
W Warden engage ring centre [230, 480]
D drop-in [-460, -650]
```

The three activities: the siphon camp (`enemy_camp` with today's Reach lobber pack and the named `loose_trigger` pay, `map_reach.gd:142`), the bend cache (`cracked_cache`) and the bench bounty (`hauler_bounty`). Today's Reach has a fourth, the ambush altar (`map_reach.gd:143`); it moves to stage 1's east bench, so world 1 keeps all four kinds and each stage has three (PARK.md:194).

**The exit to Brindle.** After the break, the reward gates stand on the bluff lip outside the drum's east doors at x 300, facing +x over the lower gorge, and the bay docks 61 m behind them over the drum (`bay.gd:37-41`, `143-153`), so `bay_dock.at` is [239, 480]. The launch throws the ball out of the east doors and across the gorge. Stage 2 is the world's last stage, so when the launch flight ends (`LAUNCH_FLIGHT` 0.6 s, `flow.gd:23`), `_finish_stage` calls `enter_boss` with the ball's velocity instead of advancing (`flow.gd:667-673`, `456-473`), and Brindle's module places the ball in the Slag Bowl (`boss.gd:15-17`). The arena stays small and authored (PARK.md:381). The park only points at it: from the bend overlook and the bluff, a smoke column and a furnace glow stand on the eastern horizon past the lower gorge, the launch arc aims at them, and the Requisition's anvil enters the music on the last chunk (section 10).

## 5. `park_rows` (134 rows, KD2 fix round 2026-10-11)

The shipped file is `src/world/park/park_flume.json`; the bake and the stage graph are under `assets/park/park_flume/` (KD2). The rows come in three kinds: 56 authored rows (the rides, the landforms, the crew camp, the trestles and the head house, table below), 52 rock outcrops beside the lines, and 26 shallow washes. On this head every row with a recipe is built in play with its collider and ride sensor (`terrain.gd:218-220` calls `ParkRecipes.build_placed`), so the rows are what the traversal bot rides and hooks.

**The canvas is three flat terraces, not one ramp.** The draft's 112 m fall as one tilted plane made `tools/park_graph.gd` never finish: on a tilted plane every lattice edge has its own irrational length and the line search (`search_prev`, float32 distances in `src/world/park/park_graph.gd`) re-pushed one node 300 000 times. Flat terraces with sheer steps settle like the fixture, and each step is a drop the lines ride. Heights: the ground north of z -380 is +15, north of z -150 another +15, north of z 220 another +24; the siphon scarp adds 15 m above its edge and the weir mesa 40 m.

| Row | Element / landform / society | Verb, ride fact | Note |
| --- | --- | --- | --- |
| `canal_country`, `canal_country_mid`, `canal_country_low` | ground (plateau) / dry_wash / none | roll | the three terraces, edges at z -380, -150 and 220 |
| `siphon_scarp`, `weir_mesa` | ground (plateau) / mesa_rim / none | roll | the 15 m siphon scarp across the canal country at yaw 31; the 40 m mesa |
| `weir_deck`, `weir_gatehouse` | drop, ledge / mesa_rim / dam_era | drop `ride_drop`, roll | the drop-in deck (`greybox:drop`) and the gatehouse beside it |
| `weir_chute`, `mesa_ramp` | half_pipe, drop / flume, mesa_rim | pump, drop | the two 40 m ramps off the mesa (east under the flume, south to the canal) |
| `flume_weir_reach`, `flume_gap_reach`, `flume_hollow_reach`, `flume_head_reach`, `pour_channel` | grind_line / flume / dam_era | grind, `ride_grapple_line` | deck bottoms at y 109.8, 67, 55, 23 and -4 (2 m decks). The gap reach's deck top, 69, is flush with the upper terrace at its north end [-151, -470], so a ball rolls onto it (it stood 4 m proud and stopped Sable there), and 15 m over the canal country where it ends at the butte gap. The pour channel's top, -2, is the relic's height (section 3) |
| `weir_trestles`, `gap_trestles`, `hollow_trestles` | anchor_field / flume / dam_era | swing | the trestle bents either side of the weir reach's first 140 m (38 m tall), the gap reach (14 m) and the hollow reach (16 m): harpoon anchors along the flume line; posts keep out of every deck and lane (`ParkRecipes.anchor_posts`) |
| `crew_ledges`, `crane_booms` | elevated_line, anchor_field / mesa_rim / dam_era | roll, swing | the crew camp on the mesa's south face (replaces the cliff rooms); the crane booms are a row of 40 m masts west of the mesa ramp, [-514, -395], the ramp's anchors |
| `mesa_rim_road` | drop / mesa_rim / dam_era | drop | home `weir_lobbers` |
| `main_canal`, `butte_gap`, `lateral_canal`, `main_canal_kicker` | flow_line, kicker / canal / hohokam | roll `ride_chute`, launch | `ref_` only; the gap is the first waymark |
| `west_butte`, `east_butte` | anchor_field / butte / none | swing | the gap's two buttes |
| `trestle_hollow` | half_pipe / arroyo / none | pump, `ride_chute` | 8 m deep and 40 m wide (was 60: at 60 m a ball on the floor had no anchor within 40 m); home `trestle_drones`; the collapse site |
| `rim_road`, `rim_road_kicker`, `bend_overlook`, `bend_rim_ledge`, `bend_return_wash`, `bluff_rim` | bank, kicker, ledge, half_pipe / mesa_rim, horseshoe_bend, dry_wash | bank, launch | the rim line; `bend_rim_ledge` [42, -142] holds the bend cache; the return wash carries the rim lines back to the siphon |
| `horseshoe_gorge`, `lower_gorge` | flow_line / horseshoe_bend, river_canyon / none | | channel stamps, 95 m |
| `the_siphon` | drop / canal / dam_era | drop | the second waymark's site, `greybox:drop` |
| `wasteway_chute`, `wasteway_wall_line` | half_pipe, bank / canal / dam_era | pump, bank | home `wasteway_chasers`; the flash flood; the wall line the flood opens |
| `bench_run_wash`, `bench_lip_bank` | half_pipe, bank / slickrock / none | pump, bank | the bench finish (a lip kicker was tried here and taken out: it opened anchor gaps of 57 to 77 m on the sable line) |
| `south_bench`, `bench_landing` | ground / slickrock / none | | the bounty's bench; dormant home `dropship_trappers` on the landing |
| `drum_forecourt`, `head_house_drum`, `heat_exchanger_annex` | ground, terrace, ledge / penstock / dam_era | roll, bank | home `forecourt_brutes`; the fight floor at y -14; the reactor blow site |
| `head_house_trusses`, `drum_lip_kicker`, `gate_lip` | anchor_field, kicker, ground / penstock / dam_era | swing, launch | the Warden exit: the kicker off the drum's lip feeds the trusses (`warden_exit` connected) |
| `weir_pond`, `gap_wash`, `field_bank_4`, `mesa_spill`, `pad_bank_4`, `pad_bank_5`, `pad_bank_7` | bowl, half_pipe, bank / mesa_rim, arroyo, dry_wash | bank, pump | the weir's pond and the draft's side washes and banks |

**Rock outcrops (52 rows, `<region>_outcrop_<n>`: mesa 4, canal 15, fields 12, bend 6, bench 5, bluff 10).** Sandstone outcrops 18 m across (a `butte` stamp, no recipe, so the terrain itself is the rock), set 15 to 45 m beside the pilot lines where a line had no face to hook within 40 m (PARK.md section 8's anchor band). An outcrop beside a cut (a canal, the hollow, a wash) stands 12 m, so a ball on the cut's floor sees it over the rim; the rest stand 8 m, which keeps the tower's sight share at 0.86 (14 m outcrops took it to 0.83). They replace the 25 `saguaro_*` anchor fields that tiled the map on a 320 m grid: those posts stood across the pilot lines (Sable's stops at [-245, -543] and [5, 176] were posts) and the page never authored them.

**Shallow washes (26 rows, `<region>_wash_<n>`).** Dry washes 1.5 m deep and 36 m wide, 160 to 720 m long, most running with the fall (yaw 31 or -59), cut across the open country away from every ride row so every open node is within 80 m of a row (`park_density_test`, worst 79.6 m at the south-west corner). They are terrain only (no recipe); a line crossing one rolls through a dip.

## 6. `event_rows` (5 rows)

| Row | Family, kind | Site | Trigger | Telegraph | What changes | Route change |
| --- | --- | --- | --- | --- | --- | --- |
| `hollow_trestle_collapse` | natural, `collapse` | trestle hollow | tier 2 | 6 s `trestle_groan` | A flume span over the hollow drops into a ramp | closes `flume_mid`, opens `trestle_ramp_line` |
| `wasteway_flash_flood` | natural, `flash_flood` | wasteway chute | tier 1 | 5 s `flood_rising` | 1.2 m of water for 30 s | closes `canal_lower`, opens `wasteway_wall` |
| `bench_dropship` | fleet, `fleet_landing` | bench landing [-300, 460] | tier 2 | 10 s `fleet_inbound` | a dropship lands and wakes `dropship_trappers` | none |
| `bend_relic_wakes` | ancient, `machine_eruption` | bend overlook | tier 2 | 8 s `ancient_stirring` | a `reactor_relic` miniboss erupts from the bend's rock | none |
| `annex_reactor_blow` | industrial, `reactor_blow` | heat-exchanger annex | Warden `chunk_2` | 5 s `reactor_overload` | a 20 m fallout ring, 6 damage, 8 s; the annex roof becomes a ramp into the drum | opens `annex_ramp_line` |

**The collapse is a ride, not a wall.** The span falls only when the ball is clear of it by `hold_clear_m` (20 m), after a 6 s groan on the flume. A ball arriving later rides off the flume's end onto the fallen span, now a ramp down into the hollow.

**The industrial row changes kind.** Stage 1 already has a boiler at chunk 2, so stage 2's is a `reactor_blow` in the annex. On the veto list.

Every route, opened or not, is connected on the stage graph (`assets/park/park_flume/graph.json`, 2026-10-11).

## 7. `home_rows` (5 homes)

| Home | Kind | Site, landform | Advantage | Counter | Reinforce | Break |
| --- | --- | --- | --- | --- | --- | --- |
| `weir_lobbers` | lobber | mesa rim road, mesa_rim | The rim road looks down the flume and the canal, two long held lines inside 75 m (`lobber.gd:12`) | Drop off the flume into the canal or back: the shell lands on the line you left (`lobber.gd:3-7`) | tier 1, 30 s, 4, `grounded` | slam, 80, 14 |
| `trestle_drones` | winch_drone | trestle hollow, arroyo | Drones roost in the bents; a 20 m winch lane along the flume (`winch_drone.gd:15`) hooks a ball that cannot step off a grind | Hold 19 m/s and the cable snaps (`winch_drone.gd:20`); a jump snaps it too | tier 1, 35 s, 3, `elite` | damage, 90, 16 |
| `wasteway_chasers` | chaser | wasteway chute, canal | One straight concrete floor, the lane a chaser lunges down | Pump the walls and come down on them from above the lane | tier 1, 25 s, 5, `run_down` | ram, 60, 12 |
| `forecourt_brutes` | plated_brute | forecourt, penstock | The forecourt is the drum's front door; a brute's 6 m slam ring (`plated_brute.gd:12`) covers the doorway every ground line rolls through | Take the forecourt geyser over the ring, or land on the brute from the bluff rim | tier 2, 40 s, 2, `elite` | damage, 140, 20 |
| `dropship_trappers` (dormant) | mag_trapper | bench landing, slickrock | A landed crew pits the bench a light ball crosses to reach the hauler | Grow past the rating, or jump and smash the disc (`mag_trapper.gd:6-9`) | tier 1, 35 s, 3, `grounded` | smash, 90, 16 |

The winch drone is the flume's natural enemy: it is the one kind whose threat is a held line, and the flume is the longest held line in world 1.

## 8. `contraption_rows` (8 rows), weather and time of day

| Row | Kind, skin | Where | What it does for the line |
| --- | --- | --- | --- |
| `weir_valve` | valve, `gauge` | the butte gap's east shelf [-160, -270]; door [-152, -252], cache [-142, -238] | The hidden pocket: ram the valve, the door sinks, the crew's cache behind it. Codex id `flume_weir_cache` (ruling R5) |
| `mesa_zip` | cable | from the mesa's south-east corner [-392, 110, -442] to the gap [-290, 55, -245] | A 225 m zip off the mesa to the butte gap; its ends sit 1 m over the baked ground so a rolling ball starts it |
| `flume_trebuchet` | launcher, `trebuchet` | canal fields [-345, -120] | Throws you into the trestle hollow at [-190, 31, -20], the hollow's floor; Tally's line takes it |
| `hollow_lift` | lift, `lift_platform` | trestle hollow [-210, -60] | Lifts 30 m to the trestle catwalk, inside harpoon range of the flume (45 m) |
| `bend_zip` | cable | bend overlook, [50, 55, -170] to [120, 40, -40] | A 150 m zip along the bend's rim; the Cannon's line rides it (`ride_grapple_line` measured) |
| `squall_lane` | thermal | bluff rim [120, 260] | The dust squall's visible wind lane, 50 m |
| `culvert_wall` | cracked_wall | beside the wasteway [117, 311], off its footprint (ruling R3) | Breaks at cruise into a culvert shortcut |
| `forecourt_geyser` | launcher, `geyser_vent` | forecourt [140, 400] | Lobs you over the brute ring and the drum wall onto the drum floor beside the relic, target [222, -12, 462] (2 m over the floor at -14) |

**Time of day: `morning`.** The sun has cleared the mesas; long shadows of the trestles fall west across the canal fields, and the head house's green seams read against a pale sky.

**Weather.** `morning_clear` (always) and `dust_squall` from tier 2: 15 s warning, 60 s live, 90 s gap, ochre fog at 0.003, a `dust` sky, a squall hiss, a `squall_shaker` music layer, collapse odds 1.5 times and flash-flood odds 0.5 times. `handling` is `"none"`.

## 9. Traversal lines

Four waymarks: `drop_in`, `butte_gap`, `siphon_camp`, `landmark`. The lines are `tools/park_lines/park_flume.json` (KD2 fix round, 2026-10-11). Segment 1 (drop-in to the butte gap): Sable takes the flume reaches off the weir; the other five and the floor line take the mesa ramp and the rim road. Segment 2 (gap to the siphon): Rivet and Kest the rim road and the bend, the Cannon the bend zip at [50, -170], Tarn and the floor line the trebuchet side and the hollow, Tally the trebuchet side then east across the fields, Sable the canal. Segment 3 (siphon to the drum): Sable, Rivet, Tarn and the floor line the bench and the forecourt, Kest the bluff, Tally the bench then the forecourt pads, the Cannon the forecourt geyser.

| Line | Waypoints |
| --- | --- |
| Sable | drop_in [-430, -615] [-369, -595] [-300, -586] [-225, -530] [-151, -472] [-180, -415] [-215, -350] [-250, -265] butte_gap [-240, -163] [-212, -100] [-200, -50] [-188, 0] [-176, 50] [-164, 100] [-142, 140] [-100, 158] siphon_camp [-30, 228] [-80, 290] [-100, 370] [-95, 425] [-20, 437] [60, 440] [130, 440] [170, 440] [205, 450] landmark |
| Rivet | drop_in [-456, -560] [-466, -470] [-470, -420] [-470, -330] [-430, -288] [-360, -268] butte_gap [-220, -199] [-120, -148] [-20, -97] [60, -56] [110, -31] [125, 0] [90, 62] [30, 114] siphon_camp [-30, 228] [-80, 290] [-100, 370] [-95, 425] [-20, 437] [60, 440] [130, 440] [170, 440] [205, 450] landmark |
| Kest | drop_in [-456, -560] [-466, -470] [-470, -420] [-470, -330] [-430, -288] [-360, -268] butte_gap [-220, -199] [-120, -148] [-20, -97] [50, -60] [110, -25] [110, 45] [40, 100] siphon_camp [20, 212] [60, 220] [120, 270] [180, 320] [240, 370] [278, 402] [258, 430] landmark |
| Tarn | drop_in [-456, -560] [-466, -470] [-470, -420] [-470, -330] [-430, -288] [-360, -268] butte_gap [-300, -152] [-326, -85] [-298, -35] [-270, 15] [-242, 65] [-214, 115] [-200, 140] [-110, 155] siphon_camp [-30, 228] [-80, 290] [-100, 370] [-95, 425] [-20, 437] [60, 440] [130, 440] [170, 440] [205, 450] landmark |
| Tally | drop_in [-456, -560] [-466, -470] [-470, -420] [-470, -330] [-430, -288] [-360, -268] butte_gap [-300, -152] [-326, -85] [-298, -35] [-270, 15] [-242, 65] [-195, 70] [-164, 100] [-142, 140] [-100, 158] siphon_camp [-15, 235] [-60, 300] [-100, 375] [-50, 420] [20, 392] [78, 430] [130, 445] [200, 445] landmark |
| The Cannon | drop_in [-456, -560] [-466, -470] [-470, -420] [-470, -330] [-430, -288] [-360, -268] butte_gap [-220, -205] [-130, -180] [-40, -172] [50, -170] [120, -40] [100, 20] [40, 100] siphon_camp [-5, 215] [40, 235] [95, 290] [125, 340] [120, 390] [160, 425] [215, 455] landmark |
| Floor line | drop_in [-456, -560] [-466, -470] [-470, -420] [-470, -330] [-430, -288] [-360, -268] butte_gap [-300, -152] [-326, -85] [-298, -35] [-270, 15] [-242, 65] [-214, 115] [-200, 140] [-110, 155] siphon_camp [-30, 228] [-80, 290] [-100, 370] [-95, 425] [-20, 437] [60, 440] [130, 440] [170, 440] [205, 450] landmark |

**Measured** (KB7 `tools/traversal_line.gd`, 8 seeds, `--fixed-fps 90`, on commit b2da61d (park file, bake and graph; the lines file unchanged since); median / worst seed). Machine load average 20 to 71 during the runs (three runs started after the 10 minute load wait). The full table, with the dead-stop sites and the distinct-lines matrix, is `design-v3/park/traversal/park_flume.md`.

| Band | sable | rivet | kest | tarn | tally | cannon | floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| reached Warden (every seed) | 8 / - pass | 8 / - pass | 8 / - pass | 8 / - pass | 8 / - pass | 8 / - pass | 8 / - pass |
| time to Warden s (median 60-120, none over 150) | 61.925 / 63.33 pass | 104.595 / 105.18 pass | 90.26 / 91.27 pass | 85.905 / 89.33 pass | 98.49 / 100.94 pass | 87.345 / 89.7 pass | 100.65 / 104.5 pass |
| segment s (each median 12-45) | [24.86, 15.96, 20.81] / 24.855 pass | [27.05, 43.57, 34.2] / 43.57 pass | [25.37, 39.13, 25.59] / 39.125 pass | [24.28, 32.76, 29.02] / 32.76 pass | [26.63, 33.29, 38.56] / 38.56 pass | [24.84, 39.06, 23.44] / 39.065 pass | [27.42, 36.5, 36.28] / 36.75 pass |
| flow share (median >= 0.70, none under 0.60) | 0.9177 / 0.895 pass | 0.7256 / 0.6902 pass | 0.6382 / 0.6024 MISS | 0.8782 / 0.843 pass | 0.6088 / 0.5746 MISS | 0.9296 / 0.9231 pass | 0.5976 / 0.5695 MISS |
| airborne share (0.12-0.45) | 0.2309 / - pass | 0.13 / - pass | 0.1638 / - pass | 0.1639 / - pass | 0.1519 / - pass | 0.2609 / - pass | 0.1225 / - pass |
| dead stops (0 on every seed) | 0 / 1 MISS | 2 / 2 MISS | 0 / 1 MISS | 2.5 / 7 MISS | 3 / 5 MISS | 1 / 2 MISS | 1.5 / 2 MISS |
| peak m/s (>= 26.6 blazing on every seed) | 54.595 / 53.79 pass | 35.025 / 32.56 pass | 30.705 / 28.85 pass | 32.38 / 31.7 pass | 35.83 / 33.17 pass | 33.93 / 31.59 pass | 35.365 / 34.3 pass |
| tier-3 s (median >= 3) | 42.975 / - pass | 8.085 / - pass | 7.155 / - pass | 9 / - pass | 8.495 / - pass | 12.345 / - pass | 8.305 / - pass |
| quiet max s (<= 20) | 10.325 / 13.22 pass | 14.195 / 15.7 pass | 16.505 / 17.17 pass | 13.8 / 13.91 pass | 17.925 / 20.59 pass | 18.475 / 19.6 pass | 16.4 / 17.24 pass |
| anchor gap m (<= 40) | 51.65 / 94.7 MISS | 25.65 / 34.7 pass | 61.25 / 68.5 MISS | 32 / 34.5 pass | 22.4 / 24.5 pass | 218.15 / 233.8 MISS | 31.4 / 33.7 pass |
| distinct ride facts (>= 3) | 4 / 4 pass | 5 / 5 pass | 4 / 4 pass | 5 / 5 pass | 5 / 5 pass | 5 / 4 pass | 5 / 5 pass |
| length ratio (1.3-2.0) | 1.47 / - pass | 1.44 / - pass | 1.34 / - pass | 1.375 / - pass | 1.35 / - pass | 1.44 / - pass | 1.355 / - pass |
| progress m/s | not measured (KB7b) | not measured (KB7b) | not measured (KB7b) | not measured (KB7b) | not measured (KB7b) | not measured (KB7b) | not measured (KB7b) |

**Bands outside on this head** (row misses, open at the timebox; every park row with a recipe is built in play, `terrain.gd:218-220`, so these are row problems, not tool artifacts): flow share (median >= 0.70, none under 0.60); dead stops (0 on every seed); anchor gap m (<= 40). Details per line are in the traversal file.

**Tricks each line offers** (`class_def.gd:87-122`):

- **Sable**: the flume reaches off the weir, the canal past the trebuchet side, the bench, the forecourt.
- **Rivet**: the mesa ramp and rim road, the bend on the rim, the bench finish; every straight is a sprint lane.
- **Kest**: Rivet's rim and bend, then east along the bluff into the drum.
- **Tarn**: the mesa ramp, the trebuchet side of the gap, the hollow end to end, the bench.
- **Tally**: the trebuchet side, east across the fields to the siphon, the bench and the forecourt pads.
- **The Cannon**: the rim road, the bend zip, the forecourt geyser into the drum.

## 10. Music arc

The stage row keeps theme 1, the sluice palette with the funk slap bass (`alpha_defs.gd:75`; `harmony.gd:117`; MUSIC-GEMS.md:18), and its `ace` id `cable_reach` (renaming an audio id buys nothing). Cue ids are proposals for KE8.

| Where or when | What the music does |
| --- | --- |
| Drop-in on the weir | The calm layer over the weir's water hiss; the slap bass enters as the ball first grinds the flume or reaches the canal |
| The flume's long grind | A held groove; each trestle bent the ball passes ticks a hat accent, so speed reads as tempo-locked ticks (cue `trestle_ticks`) |
| The butte gap | A one-bar break as the lines pinch, the groove back on the far side (cue `gap_break`) |
| Wasteway flash flood, trestle collapse | Stage-band riser over the lead, the drop on the landing |
| Dropship | Brindle's anvil and brass, one layer (SOUND-STORY.md:74) |
| Bend relic wakes | The Ab pedal and the Geiger tick (SOUND-STORY.md:59, 140) |
| Dust squall | `squall_shaker` layer while live |
| The siphon | A low-pass dip under the hollow, open on the far side |
| Warden engage | The world-1 Warden pivot to four on the floor at 129 (MUSIC-GEMS.md:13); the Ab pedal under every 2 s charge (SOUND-STORY.md:69) |
| Slag lanes | The lane's 1 s fill is a rising hiss; the burn is a dry crackle on the Geiger tick |
| Half broken, three quarters | The half-step lift, then the sinister break (MUSIC-GEMS.md:17) |
| Annex reactor blow (chunk 2) | Steam whistle into a percussion hit |
| Last chunk | Brindle's anvil enters under the sinister break: the boss is next |
| Break and launch | The unseal drop; the launch over the gorge rides into Brindle's music (G6, MUSIC-GEMS.md:16) |

## 11. Codex fragments from the society layer

| Id | Found at | Draft text |
| --- | --- | --- |
| `dam_era_flume_survey` | weir deck | Flume line surveyed by eye and string. The string was wrong twice. The flume is right. |
| `dam_era_trestle_tag` | flume, gap reach | Trestle 41. Inspected. Inspected again because 40 fell down. |
| `dam_era_road_marker` | mesa rim road | Rim road. Watch for falling crews. |
| `dam_era_siphon_plate` | the siphon | Inverted siphon: the water goes down, under, and up again. So will you. |
| `dam_era_wasteway_gauge` | wasteway chute | Wasteway gauge. When it reads high, the weir is dumping. Leave. |
| `dam_era_rim_milepost` | rim road | Milepost 3. The bend is prettier from here than from the bottom. |
| `dam_era_headhouse_log` | head house | Head house log: flow normal. Relic warm. Do not let it touch the flume. Note added: it touched the flume. |
| `dam_era_annex_dial` | heat-exchanger annex | A dial with one red band. The needle is in it. |
| `headhouse_relic_plate` | the landmark | The relic's cast plate, the same green as the dam's. Two of them. There were always more than one. |
| `ref_canal_headgate` | main canal | A headgate where the canal leaves the river: a gap in a stone and brush weir, set so the river feeds the canal at its own pace. |
| `ref_canal_gap_cut` | butte gap | The canal threads the gap between two buttes on the only line that keeps its fall. |
| `ref_canal_turnout` | lateral canal | Turnouts let the main canal feed smaller ones; the fields get their water in turn. |
| `dam_era_crew_bunks` | crew ledges | Flume crew bunks, cut into the mesa face. Bunk 6 has the view. Bunk 6 also has the draught. |
| `dam_era_boom_tag` | crane booms | Boom 3. Swung every trestle bent into place. Swings other things now. |

The `ref_` texts need a fact check before they ship.

## 12. What stays from today's stage, and what has no table yet

**The stage row changes at KF0** (PARK.md:438, 544): `warden_family` `swarm` to `reactor`, `ancient` `swarm_remnant` to `reactor_relic`, `warden_variant` `""` to `meltdown` (`alpha_defs.gd:75-80`). **Stays:** plating 110, hp 800, `beacon_seconds` 25, `beacon_radius` 30, curve 2.0 with `ram_shatters` false, `PRESSURE[1]`, `PACKS` and `ELITE` (`alpha_defs.gd:42-47`, `61`). Display name "Spillway: the flume", map id `park_flume`.

**One knock-on to catch.** The meltdown mantle is keyed to stage 3 with family `reactor` (`hero_assets.gd:11-12`). After KF0, stage 3 fights the swarm, so that row mounts nothing ("a mismatch mounts nothing", `hero_assets.gd:10`) and stage 2's meltdown Warden has no mantle. KF0 or KF8 moves the row to stage 2.

**Warden band timing.** `REACH_SKIPPER_S` is 35 to 80 s and the completionist at most 1.25 times the skipper (`tests/alpha_posture_bands_test.gd:32`, `34`, `100-103`). Those were measured on the swarm's guard rack. The meltdown's 6 s core window shortens fights and its slag lanes lengthen them, so KF0 re-measures and re-pins with a dated header (PARK.md:444).

**Tests to re-pin** (names from the `tests/` listing; KD2 confirms): `alpha_posture_bands_test.gd`, `warden_variants_test.gd`, `warden_meltdown_slag_test.gd`, `warden_family_test.gd`, `world_one_wardens_test.gd`, `world_warden_flow_test.gd`, `stage_bay_test.gd`, `hero_warden_assets_test.gd`, `boss_flow_test.gd` (the hand-off to Brindle), and the win proof on `--table=park`.

**Fields today's map carries that the park file has no table for:** the Reach's three authored lines (`map_reach.gd:5-14`) retire into the pilot lines; its 13 `scrap_lines` (`map_reach.gd:120-134`) derive from `tools/park_lines/park_flume.json`; its kicker (`map_reach.gd:135`) becomes kicker rows. The four swing pillars at today's Warden site (`map_reach.gd:11`) become the head house's roof-truss anchors.

## 13. The shipped park file

The park file is `src/world/park/park_flume.json` (KD2 greybox, fix round 2026-10-11, 134 park rows) and the lines are `tools/park_lines/park_flume.json`; the stage test `tests/park_park_flume_test.gd` pins them. Changes from the draft:

- Removed `cliff_rooms` and `viga_beams`; added the crew camp (`crew_ledges`, `crane_booms`), the three terraces, `bend_rim_ledge`, `drum_lip_kicker` and sized filler rows (no tiled saguaro grid).
- Removed `bend_far_rim`: the bend cache moved onto `bend_rim_ledge` [42, -142] beside the rim line.
- `weir_valve` stands on the butte gap with codex id `flume_weir_cache` (R5); `culvert_wall` sits off the wasteway footprint (R3).
- `warden_exit` runs `drum_lip_kicker`, `head_house_trusses`, `head_house_drum`; `landmark.warden` is the reactor on the flume mounting with `harpoon_anchor` true.
- Every `_est`, `_detour_m` and `pocket_est` key is gone; the numbers below come from `assets/park/park_flume/graph.json`.

| Pocket | Role | Door [x, z] | door_m | detour_m | d_spawn | d_landmark | sight_ok | pay |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `siphon_camp` | online | [-24, 176] | 0 | 0 | 986 | 422 | yes | common (`loose_trigger`) |
| `bend_cache` | reward | [40, -144] | 226 | 226 | 754 | 730 | yes | rare |
| `bench_bounty` | risk | [-120, 336] | 194 | 194 | 1136 | 415 | yes | common or rare |
| `weir_valve` | hidden | [-152, -248] | 107 | 102 | 561 | 911 | yes | the cache |

The park file, verbatim (park_schema_test reads this block):

```json
{
 "schema": "scrapkeep-park/1",
 "map": "park_flume",
 "size_m": 1600,
 "time_of_day": "morning",
 "spawn": {"at": [-460, -650], "heading_deg": 31},
 "play_rect": [-780, -780, 1300, 1560],
 "landmark": {"id": "penstock_tower", "kind": "penstock_tower", "at": [270, 510], "size": [140, 90, 120], "yaw_deg": 31, "recipe": "landmark_penstock_tower", "budget": "hero_landmark", "sight_top": [300, 90.0, 560], "sight_share": 0.85, "beacon": [230, 480], "reach_m": 30, "warden": {"family": "reactor", "mounting": "flume", "anchor": [230, -2.0, 470], "path": [], "hardpoints": 3, "harpoon_anchor": true}, "bay_dock": {"at": [239, 480], "facing_deg": 90}, "gate_slots": [{"at": [300, 466], "facing_deg": 90}, {"at": [300, 480], "facing_deg": 90}, {"at": [300, 494], "facing_deg": 90}], "light": "ancient_beam", "music": "landmark_hum", "fragment": "headhouse_relic_plate"},
 "waymarks": ["drop_in", "butte_gap", "siphon_camp", "landmark"],
 "routes": [
  {"id": "flume_upper", "from": "drop_in", "to": "butte_gap", "via": ["weir_deck", "weir_chute", "flume_weir_reach", "flume_gap_reach"]},
  {"id": "canal_upper", "from": "drop_in", "to": "butte_gap", "via": ["weir_deck", "mesa_ramp", "main_canal"]},
  {"id": "camp_rim", "from": "drop_in", "to": "butte_gap", "via": ["crew_ledges", "crane_booms", "mesa_rim_road"]},
  {"id": "flume_mid", "from": "butte_gap", "to": "the_siphon", "via": ["flume_hollow_reach"]},
  {"id": "canal_mid", "from": "butte_gap", "to": "the_siphon", "via": ["lateral_canal"]},
  {"id": "hollow_run", "from": "butte_gap", "to": "the_siphon", "via": ["trestle_hollow"]},
  {"id": "trestle_ramp_line", "from": "butte_gap", "to": "the_siphon", "via": ["flume_hollow_reach", "trestle_hollow"]},
  {"id": "rim_mid", "from": "butte_gap", "to": "the_siphon", "via": ["rim_road", "bend_overlook"]},
  {"id": "flume_lower", "from": "the_siphon", "to": "landmark", "via": ["flume_head_reach", "pour_channel", "head_house_drum"]},
  {"id": "canal_lower", "from": "the_siphon", "to": "landmark", "via": ["wasteway_chute", "drum_forecourt", "head_house_drum"]},
  {"id": "wasteway_wall", "from": "the_siphon", "to": "landmark", "via": ["wasteway_wall_line", "drum_forecourt", "head_house_drum"]},
  {"id": "rim_lower", "from": "the_siphon", "to": "landmark", "via": ["bluff_rim", "head_house_drum"]},
  {"id": "forecourt_entry", "from": "drum_forecourt", "to": "landmark", "via": ["drum_forecourt", "head_house_drum"]},
  {"id": "bench_run", "from": "the_siphon", "to": "landmark", "via": ["bench_run_wash", "bench_lip_bank", "drum_forecourt", "head_house_drum"]},
  {"id": "annex_ramp_line", "from": "drum_forecourt", "to": "landmark", "via": ["heat_exchanger_annex", "head_house_drum"]},
  {"id": "warden_exit", "from": "landmark", "to": "gate_lip", "via": ["drum_lip_kicker", "head_house_trusses", "head_house_drum"]}
 ],
 "park_rows": [
  {"id": "canal_country", "element": "ground", "landform": "dry_wash", "society": "none", "at": [0, -690.0], "y": null, "size": [620.0, 15.0, 2000], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "canal_country_mid", "element": "ground", "landform": "dry_wash", "society": "none", "at": [0, -575.0], "y": null, "size": [850.0, 15.0, 2000], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "canal_country_low", "element": "ground", "landform": "dry_wash", "society": "none", "at": [0, -390.0], "y": null, "size": [1220.0, 24.0, 2000], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "siphon_scarp", "element": "ground", "landform": "mesa_rim", "society": "none", "at": [-553.2, -920.6], "y": null, "size": [2400, 15.0, 2400], "yaw_deg": 31, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "weir_mesa", "element": "ground", "landform": "mesa_rim", "society": "none", "at": [-560.0, -620.0], "y": null, "size": [360.0, 40.0, 380.0], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "weir_deck", "element": "drop", "landform": "mesa_rim", "society": "dam_era", "at": [-460, -650], "y": null, "size": [44, 0.5, 30], "yaw_deg": 31, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:drop", "stamp": "", "hole": false, "budget": "landform", "routes": ["flume_upper", "canal_upper"], "fragment": "dam_era_flume_survey"},
  {"id": "weir_gatehouse", "element": "ledge", "landform": "mesa_rim", "society": "dam_era", "at": [-480, -625], "y": null, "size": [12, 10, 12], "yaw_deg": 31, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "greybox:ledge", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "weir_chute", "element": "half_pipe", "landform": "flume", "society": "dam_era", "at": [-299.0, -595], "y": null, "size": [140, 40.0, 30], "yaw_deg": 90, "verb": "pump", "ride_fact": "ride_chute", "home": "", "recipe": "greybox:half_pipe", "stamp": "ramp", "hole": false, "budget": "landform", "routes": ["flume_upper"], "fragment": ""},
  {"id": "mesa_ramp", "element": "drop", "landform": "mesa_rim", "society": "none", "at": [-470, -369.0], "y": null, "size": [140, 40.0, 40], "yaw_deg": 0, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:drop", "stamp": "ramp", "hole": false, "budget": "landform", "routes": ["canal_upper"], "fragment": ""},
  {"id": "flume_weir_reach", "element": "grind_line", "landform": "flume", "society": "dam_era", "at": [-270.0, -520.0], "y": 109.8, "size": [260.8, 2, 8], "yaw_deg": 67.0, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "landform", "routes": ["flume_upper"], "fragment": ""},
  {"id": "weir_trestles", "element": "anchor_field", "landform": "flume", "society": "dam_era", "at": [-325.6, -543.6], "y": null, "size": [140, 38, 40], "yaw_deg": 67.0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "flume_gap_reach", "element": "grind_line", "landform": "flume", "society": "dam_era", "at": [-215.0, -349.5], "y": 67.0, "size": [272.9, 2, 8], "yaw_deg": -28.0, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "landform", "routes": ["flume_upper"], "fragment": "dam_era_trestle_tag"},
  {"id": "gap_trestles", "element": "anchor_field", "landform": "flume", "society": "dam_era", "at": [-215.0, -349.5], "y": null, "size": [272.9, 14, 40], "yaw_deg": -28.0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "flume_hollow_reach", "element": "grind_line", "landform": "flume", "society": "dam_era", "at": [-115.0, 5.5], "y": 55.0, "size": [373.0, 2, 8], "yaw_deg": 30.6, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "landform", "routes": ["flume_mid", "trestle_ramp_line"], "fragment": ""},
  {"id": "hollow_trestles", "element": "anchor_field", "landform": "flume", "society": "dam_era", "at": [-115.0, 5.5], "y": null, "size": [373.0, 16, 40], "yaw_deg": 30.6, "verb": "swing", "ride_fact": "", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "flume_head_reach", "element": "grind_line", "landform": "flume", "society": "dam_era", "at": [114.0, 337.5], "y": 23.0, "size": [297.8, 2, 8], "yaw_deg": 39.1, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "landform", "routes": ["flume_lower"], "fragment": ""},
  {"id": "pour_channel", "element": "grind_line", "landform": "flume", "society": "dam_era", "at": [200.0, 446.0], "y": -4.0, "size": [14.0, 2, 8], "yaw_deg": 38.4, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:grind_line", "stamp": "", "hole": false, "budget": "detail", "routes": ["flume_lower"], "fragment": ""},
  {"id": "crew_ledges", "element": "elevated_line", "landform": "mesa_rim", "society": "dam_era", "at": [-600, -432], "y": 76.5, "size": [120, 1, 10], "yaw_deg": 90, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "greybox:elevated_line", "stamp": "", "hole": false, "budget": "landform", "routes": ["camp_rim"], "fragment": "dam_era_crew_bunks"},
  {"id": "crane_booms", "element": "anchor_field", "landform": "mesa_rim", "society": "dam_era", "at": [-514, -395], "y": null, "size": [100, 40, 20], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "detail", "routes": ["camp_rim"], "fragment": "dam_era_boom_tag"},
  {"id": "mesa_rim_road", "element": "drop", "landform": "mesa_rim", "society": "dam_era", "at": [-370.0, -340.0], "y": null, "size": [156.2, 1, 14], "yaw_deg": 39.8, "verb": "drop", "ride_fact": "ride_drop", "home": "weir_lobbers", "recipe": "", "stamp": "", "hole": false, "budget": "landform", "routes": ["camp_rim"], "fragment": "dam_era_road_marker"},
  {"id": "main_canal", "element": "flow_line", "landform": "canal", "society": "hohokam", "at": [-385.0, -275.0], "y": null, "size": [177.2, 3, 40], "yaw_deg": 73.6, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "greybox:flow_line", "stamp": "wash", "hole": false, "budget": "landform", "routes": ["canal_upper"], "fragment": "ref_canal_headgate"},
  {"id": "main_canal_kicker", "element": "kicker", "landform": "canal", "society": "hohokam", "at": [-368, -270], "y": null, "size": [10, 3, 8], "yaw_deg": 73.6, "verb": "launch", "ride_fact": "kicker_launch", "home": "", "recipe": "greybox:kicker", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "butte_gap", "element": "flow_line", "landform": "canal", "society": "hohokam", "at": [-280, -230], "y": null, "size": [80, 3, 24], "yaw_deg": 30, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "greybox:flow_line", "stamp": "wash", "hole": false, "budget": "landform", "routes": ["flume_upper", "canal_upper", "camp_rim", "flume_mid", "canal_mid", "hollow_run", "trestle_ramp_line", "rim_mid"], "fragment": "ref_canal_gap_cut"},
  {"id": "west_butte", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-345, -195], "y": null, "size": [70, 100, 70], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "east_butte", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-215, -270], "y": null, "size": [60, 90, 60], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "lateral_canal", "element": "flow_line", "landform": "canal", "society": "hohokam", "at": [-270.0, 15.0], "y": null, "size": [286.5, 3, 40], "yaw_deg": 29.2, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "greybox:flow_line", "stamp": "wash", "hole": false, "budget": "landform", "routes": ["canal_mid"], "fragment": "ref_canal_turnout"},
  {"id": "turnout_kicker", "element": "kicker", "landform": "dry_wash", "society": "none", "at": [-155, 148], "y": null, "size": [10, 3, 8], "yaw_deg": 80, "verb": "launch", "ride_fact": "kicker_launch", "home": "", "recipe": "greybox:kicker", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "trestle_hollow", "element": "half_pipe", "landform": "arroyo", "society": "none", "at": [-185, 10], "y": null, "size": [289, 8, 40], "yaw_deg": 14, "verb": "pump", "ride_fact": "ride_chute", "home": "trestle_drones", "recipe": "greybox:half_pipe", "stamp": "wash", "hole": false, "budget": "landform", "routes": ["hollow_run", "trestle_ramp_line"], "fragment": ""},
  {"id": "rim_road", "element": "bank", "landform": "mesa_rim", "society": "dam_era", "at": [-85, -130], "y": null, "size": [438, 2, 40], "yaw_deg": 63, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:bank", "stamp": "ridge", "hole": false, "budget": "landform", "routes": ["rim_mid"], "fragment": "dam_era_rim_milepost"},
  {"id": "rim_road_kicker", "element": "kicker", "landform": "mesa_rim", "society": "dam_era", "at": [-163, -170], "y": null, "size": [10, 3, 8], "yaw_deg": 63, "verb": "launch", "ride_fact": "kicker_launch", "home": "", "recipe": "greybox:kicker", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bend_overlook", "element": "bank", "landform": "horseshoe_bend", "society": "none", "at": [150, -60], "y": null, "size": [140, 2, 30], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:bank", "stamp": "ridge", "hole": false, "budget": "landform", "routes": ["rim_mid"], "fragment": ""},
  {"id": "horseshoe_gorge", "element": "flow_line", "landform": "horseshoe_bend", "society": "none", "at": [290, -60], "y": null, "size": [500, 95, 180], "yaw_deg": 0, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "greybox:flow_line", "stamp": "channel", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "the_siphon", "element": "drop", "landform": "canal", "society": "dam_era", "at": [-21.7, 186.3], "y": null, "size": [45, 3, 40], "yaw_deg": 31, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:drop", "stamp": "wash", "hole": false, "budget": "landform", "routes": ["bench_run"], "fragment": "dam_era_siphon_plate"},
  {"id": "wasteway_chute", "element": "half_pipe", "landform": "canal", "society": "dam_era", "at": [85.0, 335.0], "y": null, "size": [214.0, 10, 30], "yaw_deg": 37.4, "verb": "pump", "ride_fact": "ride_chute", "home": "wasteway_chasers", "recipe": "greybox:half_pipe", "stamp": "wash", "hole": false, "budget": "landform", "routes": ["canal_lower"], "fragment": "dam_era_wasteway_gauge"},
  {"id": "wasteway_wall_line", "element": "bank", "landform": "canal", "society": "dam_era", "at": [45.0, 365.0], "y": null, "size": [214.0, 2, 16], "yaw_deg": 37.4, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:bank", "stamp": "ridge", "hole": false, "budget": "detail", "routes": ["wasteway_wall"], "fragment": ""},
  {"id": "bluff_rim", "element": "bank", "landform": "mesa_rim", "society": "none", "at": [180.0, 320.0], "y": null, "size": [312.4, 2, 30], "yaw_deg": 50.2, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:bank", "stamp": "ridge", "hole": false, "budget": "landform", "routes": ["rim_lower"], "fragment": ""},
  {"id": "lower_gorge", "element": "flow_line", "landform": "river_canyon", "society": "none", "at": [430, 420], "y": null, "size": [500, 95, 120], "yaw_deg": 0, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "greybox:flow_line", "stamp": "channel", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "drum_forecourt", "element": "ground", "landform": "penstock", "society": "dam_era", "at": [150, 420], "y": null, "size": [40, 2, 60], "yaw_deg": 31, "verb": "roll", "ride_fact": "", "home": "forecourt_brutes", "recipe": "", "stamp": "", "hole": false, "budget": "landform", "routes": ["forecourt_entry", "canal_lower", "wasteway_wall", "bench_run"], "fragment": ""},
  {"id": "head_house_drum", "element": "terrace", "landform": "penstock", "society": "dam_era", "at": [230, 480], "y": null, "size": [80, 14, 80], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:terrace", "stamp": "terrace", "hole": false, "budget": "landform", "routes": ["flume_lower", "rim_lower", "forecourt_entry", "annex_ramp_line", "canal_lower", "wasteway_wall", "warden_exit", "bench_run"], "fragment": "dam_era_headhouse_log"},
  {"id": "heat_exchanger_annex", "element": "ledge", "landform": "penstock", "society": "dam_era", "at": [185, 525], "y": null, "size": [40, 14, 24], "yaw_deg": 35, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "greybox:ledge", "stamp": "", "hole": false, "budget": "detail", "routes": ["annex_ramp_line"], "fragment": "dam_era_annex_dial"},
  {"id": "head_house_trusses", "element": "anchor_field", "landform": "penstock", "society": "dam_era", "at": [284, 480], "y": 16.0, "size": [48, 14, 20], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "detail", "routes": ["warden_exit"], "fragment": ""},
  {"id": "drum_lip_kicker", "element": "kicker", "landform": "penstock", "society": "dam_era", "at": [262, 480], "y": null, "size": [10, 3, 8], "yaw_deg": 90, "verb": "launch", "ride_fact": "kicker_launch", "home": "", "recipe": "greybox:kicker", "stamp": "", "hole": false, "budget": "detail", "routes": ["warden_exit"], "fragment": ""},
  {"id": "gate_lip", "element": "ground", "landform": "penstock", "society": "dam_era", "at": [292, 480], "y": null, "size": [40, 2, 70], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "", "hole": false, "budget": "detail", "routes": ["warden_exit"], "fragment": ""},
  {"id": "bench_run_wash", "element": "half_pipe", "landform": "slickrock", "society": "none", "at": [-80, 305], "y": null, "size": [190, 4, 30], "yaw_deg": -15, "verb": "pump", "ride_fact": "ride_chute", "home": "", "recipe": "greybox:half_pipe", "stamp": "wash", "hole": false, "budget": "landform", "routes": ["bench_run"], "fragment": ""},
  {"id": "bench_lip_bank", "element": "bank", "landform": "slickrock", "society": "none", "at": [20, 438], "y": null, "size": [230, 2, 30], "yaw_deg": 88, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:bank", "stamp": "ridge", "hole": false, "budget": "landform", "routes": ["bench_run"], "fragment": ""},
  {"id": "south_bench", "element": "ground", "landform": "slickrock", "society": "none", "at": [-200, 520], "y": null, "size": [260, 6, 300], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "bench_landing", "element": "ground", "landform": "slickrock", "society": "none", "at": [-300, 460], "y": null, "size": [70, 4, 60], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "dropship_trappers", "recipe": "", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "weir_pond", "element": "bowl", "landform": "mesa_rim", "society": "dam_era", "at": [-650, -690], "y": null, "size": [140, 3, 160], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:bowl", "stamp": "bowl", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "gap_wash", "element": "half_pipe", "landform": "arroyo", "society": "none", "at": [-255, -335], "y": null, "size": [180, 4, 40], "yaw_deg": -16, "verb": "pump", "ride_fact": "ride_chute", "home": "", "recipe": "greybox:half_pipe", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "field_bank_4", "element": "bank", "landform": "dry_wash", "society": "none", "at": [-470, -120], "y": null, "size": [400, 2, 30], "yaw_deg": 20, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:bank", "stamp": "ridge", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "mesa_spill", "element": "half_pipe", "landform": "mesa_rim", "society": "none", "at": [-570, -520], "y": null, "size": [120, 4, 30], "yaw_deg": 90, "verb": "pump", "ride_fact": "ride_chute", "home": "", "recipe": "greybox:half_pipe", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "bend_return_wash", "element": "half_pipe", "landform": "dry_wash", "society": "none", "at": [75.0, 35.0], "y": null, "size": [147.6, 4, 30], "yaw_deg": -28.3, "verb": "pump", "ride_fact": "ride_chute", "home": "", "recipe": "greybox:half_pipe", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "pad_bank_4", "element": "bank", "landform": "dry_wash", "society": "none", "at": [-152, -296], "y": null, "size": [140, 1, 30], "yaw_deg": 31, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:bank", "stamp": "ridge", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "pad_bank_5", "element": "bank", "landform": "dry_wash", "society": "none", "at": [288, 272], "y": null, "size": [140, 1, 30], "yaw_deg": 31, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:bank", "stamp": "ridge", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "pad_bank_7", "element": "bank", "landform": "dry_wash", "society": "none", "at": [120, 136], "y": null, "size": [140, 1, 30], "yaw_deg": 31, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:bank", "stamp": "ridge", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bend_rim_ledge", "element": "ledge", "landform": "horseshoe_bend", "society": "none", "at": [42, -142], "y": null, "size": [40, 2, 30], "yaw_deg": 0, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "", "stamp": "", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bench_outcrop_1", "element": "anchor_field", "landform": "slickrock", "society": "none", "at": [-105, 281], "y": null, "size": [18, 12, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bench_outcrop_2", "element": "anchor_field", "landform": "slickrock", "society": "none", "at": [-33, 297], "y": null, "size": [18, 12, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bench_outcrop_3", "element": "anchor_field", "landform": "slickrock", "society": "none", "at": [-64, 362], "y": null, "size": [18, 12, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bench_outcrop_4", "element": "anchor_field", "landform": "slickrock", "society": "none", "at": [-37, 407], "y": null, "size": [18, 8, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bench_outcrop_5", "element": "anchor_field", "landform": "slickrock", "society": "none", "at": [-116, 426], "y": null, "size": [18, 12, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bend_outcrop_1", "element": "anchor_field", "landform": "horseshoe_bend", "society": "none", "at": [118, -77], "y": null, "size": [18, 8, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bend_outcrop_2", "element": "anchor_field", "landform": "horseshoe_bend", "society": "none", "at": [-36, -68], "y": null, "size": [18, 8, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bend_outcrop_3", "element": "anchor_field", "landform": "horseshoe_bend", "society": "none", "at": [18, -40], "y": null, "size": [18, 8, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bend_outcrop_4", "element": "anchor_field", "landform": "horseshoe_bend", "society": "none", "at": [46, 12], "y": null, "size": [18, 12, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bend_outcrop_5", "element": "anchor_field", "landform": "horseshoe_bend", "society": "none", "at": [121, 12], "y": null, "size": [18, 12, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bend_outcrop_6", "element": "anchor_field", "landform": "horseshoe_bend", "society": "none", "at": [38, 48], "y": null, "size": [18, 12, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bluff_outcrop_1", "element": "anchor_field", "landform": "butte", "society": "none", "at": [13, 102], "y": null, "size": [18, 12, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bluff_outcrop_2", "element": "anchor_field", "landform": "butte", "society": "none", "at": [144, 255], "y": null, "size": [18, 8, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bluff_outcrop_3", "element": "anchor_field", "landform": "butte", "society": "none", "at": [160, 339], "y": null, "size": [18, 8, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bluff_outcrop_4", "element": "anchor_field", "landform": "butte", "society": "none", "at": [8, 351], "y": null, "size": [18, 8, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bluff_outcrop_5", "element": "anchor_field", "landform": "butte", "society": "none", "at": [211, 381], "y": null, "size": [18, 8, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bluff_outcrop_6", "element": "anchor_field", "landform": "butte", "society": "none", "at": [237, 402], "y": null, "size": [18, 8, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bluff_outcrop_7", "element": "anchor_field", "landform": "butte", "society": "none", "at": [50, 406], "y": null, "size": [18, 8, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bluff_outcrop_8", "element": "anchor_field", "landform": "butte", "society": "none", "at": [163, 461], "y": null, "size": [18, 8, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bluff_outcrop_9", "element": "anchor_field", "landform": "butte", "society": "none", "at": [27, 466], "y": null, "size": [18, 8, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bluff_outcrop_10", "element": "anchor_field", "landform": "butte", "society": "none", "at": [96, 467], "y": null, "size": [18, 8, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "canal_outcrop_1", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-366, -628], "y": null, "size": [18, 8, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "canal_outcrop_2", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-224, -502], "y": null, "size": [18, 8, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "canal_outcrop_3", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-144, -493], "y": null, "size": [18, 8, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "canal_outcrop_4", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-425, -350], "y": null, "size": [18, 8, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "canal_outcrop_5", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-423, -323], "y": null, "size": [18, 12, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "canal_outcrop_6", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-375, -310], "y": null, "size": [18, 12, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "canal_outcrop_7", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-443, -254], "y": null, "size": [18, 12, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "canal_outcrop_8", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-399, -245], "y": null, "size": [18, 12, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "canal_outcrop_9", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-385, -238], "y": null, "size": [18, 12, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "canal_outcrop_10", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-189, -220], "y": null, "size": [18, 8, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "canal_outcrop_11", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-120, -205], "y": null, "size": [18, 8, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "canal_outcrop_12", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-80, -205], "y": null, "size": [18, 8, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "canal_outcrop_13", "element": "anchor_field", "landform": "butte", "society": "none", "at": [32, -191], "y": null, "size": [18, 8, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "canal_outcrop_14", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-272, -175], "y": null, "size": [18, 12, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "canal_outcrop_15", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-40, -151], "y": null, "size": [18, 8, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "fields_outcrop_1", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-296, -113], "y": null, "size": [18, 12, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "fields_outcrop_2", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-282, -84], "y": null, "size": [18, 12, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "fields_outcrop_3", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-241, -78], "y": null, "size": [18, 12, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "fields_outcrop_4", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-355, -69], "y": null, "size": [18, 12, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "fields_outcrop_5", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-227, -22], "y": null, "size": [18, 12, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "fields_outcrop_6", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-325, -16], "y": null, "size": [18, 12, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "fields_outcrop_7", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-296, 36], "y": null, "size": [18, 12, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "fields_outcrop_8", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-212, 40], "y": null, "size": [18, 12, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "fields_outcrop_9", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-133, 86], "y": null, "size": [18, 12, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "fields_outcrop_10", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-247, 123], "y": null, "size": [18, 12, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "fields_outcrop_11", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-120, 127], "y": null, "size": [18, 12, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "fields_outcrop_12", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-180, 165], "y": null, "size": [18, 12, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "mesa_outcrop_1", "element": "anchor_field", "landform": "mesa_rim", "society": "none", "at": [-422, -647], "y": null, "size": [18, 8, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "mesa_outcrop_2", "element": "anchor_field", "landform": "mesa_rim", "society": "none", "at": [-478, -589], "y": null, "size": [18, 8, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "mesa_outcrop_3", "element": "anchor_field", "landform": "mesa_rim", "society": "none", "at": [-482, -521], "y": null, "size": [18, 12, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "mesa_outcrop_4", "element": "anchor_field", "landform": "mesa_rim", "society": "none", "at": [-488, -454], "y": null, "size": [18, 8, 18], "yaw_deg": 0, "verb": "swing", "ride_fact": "", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "detail", "routes": [], "fragment": ""},
  {"id": "bench_wash_1", "element": "half_pipe", "landform": "slickrock", "society": "none", "at": [-440, 240], "y": null, "size": [720, 1.5, 36], "yaw_deg": 31, "verb": "pump", "ride_fact": "", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "bench_wash_2", "element": "half_pipe", "landform": "slickrock", "society": "none", "at": [-480, 360], "y": null, "size": [520, 1.5, 36], "yaw_deg": -59, "verb": "pump", "ride_fact": "", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "bench_wash_3", "element": "half_pipe", "landform": "slickrock", "society": "none", "at": [-360, 440], "y": null, "size": [520, 1.5, 36], "yaw_deg": -59, "verb": "pump", "ride_fact": "", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "bench_wash_4", "element": "half_pipe", "landform": "slickrock", "society": "none", "at": [-760, 560], "y": null, "size": [160, 1.5, 36], "yaw_deg": 0, "verb": "pump", "ride_fact": "", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "bench_wash_5", "element": "half_pipe", "landform": "slickrock", "society": "none", "at": [-120, 560], "y": null, "size": [700, 1.5, 36], "yaw_deg": 90, "verb": "pump", "ride_fact": "", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "bench_wash_6", "element": "half_pipe", "landform": "slickrock", "society": "none", "at": [-360, 640], "y": null, "size": [700, 1.5, 36], "yaw_deg": 90, "verb": "pump", "ride_fact": "", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "bench_wash_7", "element": "half_pipe", "landform": "slickrock", "society": "none", "at": [-400, 720], "y": null, "size": [700, 1.5, 36], "yaw_deg": 90, "verb": "pump", "ride_fact": "", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "bend_wash_1", "element": "half_pipe", "landform": "dry_wash", "society": "none", "at": [520, -40], "y": null, "size": [700, 1.5, 36], "yaw_deg": 0, "verb": "pump", "ride_fact": "", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "bend_wash_2", "element": "half_pipe", "landform": "dry_wash", "society": "none", "at": [680, 0], "y": null, "size": [700, 1.5, 36], "yaw_deg": 0, "verb": "pump", "ride_fact": "", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "bluff_wash_1", "element": "half_pipe", "landform": "dry_wash", "society": "none", "at": [600, 240], "y": null, "size": [700, 1.5, 36], "yaw_deg": 0, "verb": "pump", "ride_fact": "", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "bluff_wash_2", "element": "half_pipe", "landform": "dry_wash", "society": "none", "at": [760, 320], "y": null, "size": [700, 1.5, 36], "yaw_deg": 0, "verb": "pump", "ride_fact": "", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "bluff_wash_3", "element": "half_pipe", "landform": "dry_wash", "society": "none", "at": [400, 720], "y": null, "size": [700, 1.5, 36], "yaw_deg": 90, "verb": "pump", "ride_fact": "", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "canal_wash_1", "element": "half_pipe", "landform": "dry_wash", "society": "none", "at": [240, -720], "y": null, "size": [700, 1.5, 36], "yaw_deg": 90, "verb": "pump", "ride_fact": "", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "canal_wash_2", "element": "half_pipe", "landform": "dry_wash", "society": "none", "at": [640, -720], "y": null, "size": [160, 1.5, 36], "yaw_deg": 31, "verb": "pump", "ride_fact": "", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "canal_wash_3", "element": "half_pipe", "landform": "dry_wash", "society": "none", "at": [280, -640], "y": null, "size": [700, 1.5, 36], "yaw_deg": 90, "verb": "pump", "ride_fact": "", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "canal_wash_4", "element": "half_pipe", "landform": "dry_wash", "society": "none", "at": [360, -520], "y": null, "size": [700, 1.5, 36], "yaw_deg": 90, "verb": "pump", "ride_fact": "", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "canal_wash_5", "element": "half_pipe", "landform": "dry_wash", "society": "none", "at": [-80, -480], "y": null, "size": [720, 1.5, 36], "yaw_deg": 31, "verb": "pump", "ride_fact": "", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "canal_wash_6", "element": "half_pipe", "landform": "dry_wash", "society": "none", "at": [360, -440], "y": null, "size": [700, 1.5, 36], "yaw_deg": 90, "verb": "pump", "ride_fact": "", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "canal_wash_7", "element": "half_pipe", "landform": "dry_wash", "society": "none", "at": [760, -400], "y": null, "size": [700, 1.5, 36], "yaw_deg": 0, "verb": "pump", "ride_fact": "", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "canal_wash_8", "element": "half_pipe", "landform": "dry_wash", "society": "none", "at": [80, -320], "y": null, "size": [160, 1.5, 36], "yaw_deg": 31, "verb": "pump", "ride_fact": "", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "canal_wash_9", "element": "half_pipe", "landform": "dry_wash", "society": "none", "at": [-600, -160], "y": null, "size": [720, 1.5, 36], "yaw_deg": 31, "verb": "pump", "ride_fact": "", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "fields_wash_1", "element": "half_pipe", "landform": "dry_wash", "society": "none", "at": [-720, 80], "y": null, "size": [700, 1.5, 36], "yaw_deg": 0, "verb": "pump", "ride_fact": "", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "fields_wash_2", "element": "half_pipe", "landform": "dry_wash", "society": "none", "at": [-600, 200], "y": null, "size": [160, 1.5, 36], "yaw_deg": 0, "verb": "pump", "ride_fact": "", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "mesa_wash_1", "element": "half_pipe", "landform": "dry_wash", "society": "none", "at": [-440, -760], "y": null, "size": [160, 1.5, 36], "yaw_deg": 90, "verb": "pump", "ride_fact": "", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "mesa_wash_2", "element": "half_pipe", "landform": "dry_wash", "society": "none", "at": [-760, -680], "y": null, "size": [160, 1.5, 36], "yaw_deg": 0, "verb": "pump", "ride_fact": "", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "mesa_wash_4", "element": "half_pipe", "landform": "dry_wash", "society": "none", "at": [-400, -480], "y": null, "size": [160, 1.5, 36], "yaw_deg": 31, "verb": "pump", "ride_fact": "", "home": "", "recipe": "", "stamp": "wash", "hole": false, "budget": "landform", "routes": [], "fragment": ""}
 ],
 "event_rows": [
  {"id": "hollow_trestle_collapse", "kind": "collapse", "family": "natural", "site": "trestle_hollow", "trigger": {"on": "clock_tier", "value": 2}, "weight": 1.0, "telegraph": {"lead_s": 6.0, "form": "trestle_groan", "on_bar": true}, "live_s": 0.0, "effect": {"swap": "trestle_ramp"}, "route_change": {"closes": ["flume_mid"], "opens": ["trestle_ramp_line"]}, "hold_clear_m": 20.0, "cooldown_s": 0.0, "once": true, "music_cue": {"telegraph": "riser_natural", "land": "drop_collapse"}},
  {"id": "wasteway_flash_flood", "kind": "flash_flood", "family": "natural", "site": "wasteway_chute", "trigger": {"on": "clock_tier", "value": 1}, "weight": 0.6, "telegraph": {"lead_s": 5.0, "form": "flood_rising", "on_bar": true}, "live_s": 30.0, "effect": {"depth_m": 1.2, "fill_s": 4.0, "material": "water"}, "route_change": {"closes": ["canal_lower"], "opens": ["wasteway_wall"]}, "hold_clear_m": 15.0, "cooldown_s": 120.0, "once": false, "music_cue": {"telegraph": "riser_natural", "land": "drop_flash_flood"}},
  {"id": "bench_dropship", "kind": "fleet_landing", "family": "fleet", "site": "bench_landing", "trigger": {"on": "clock_tier", "value": 2}, "weight": 1.0, "telegraph": {"lead_s": 10.0, "form": "fleet_inbound", "on_bar": true}, "live_s": 0.0, "effect": {"vessel": "dropship", "home": "dropship_trappers", "footprint_m": [36, 16]}, "route_change": {"closes": [], "opens": []}, "hold_clear_m": 25.0, "cooldown_s": 0.0, "once": true, "music_cue": {"telegraph": "riser_fleet", "land": "drop_fleet"}},
  {"id": "bend_relic_wakes", "kind": "machine_eruption", "family": "ancient", "site": "bend_overlook", "trigger": {"on": "clock_tier", "value": 2}, "weight": 1.0, "telegraph": {"lead_s": 8.0, "form": "ancient_stirring", "on_bar": true}, "live_s": 0.0, "effect": {"miniboss": "reactor_relic", "swap": "bend_vent_lip"}, "route_change": {"closes": [], "opens": []}, "hold_clear_m": 15.0, "cooldown_s": 0.0, "once": true, "music_cue": {"telegraph": "riser_ancient", "land": "drop_ancient"}},
  {"id": "annex_reactor_blow", "kind": "reactor_blow", "family": "industrial", "site": "heat_exchanger_annex", "trigger": {"on": "warden_phase", "value": "chunk_2"}, "weight": 1.0, "telegraph": {"lead_s": 5.0, "form": "reactor_overload", "on_bar": true}, "live_s": 8.0, "effect": {"hazard": "fallout_ring", "hazard_m": [20, 20], "damage": 6.0, "swap": "annex_ramp"}, "route_change": {"closes": [], "opens": ["annex_ramp_line"]}, "hold_clear_m": 14.0, "cooldown_s": 0.0, "once": true, "music_cue": {"telegraph": "riser_industrial", "land": "drop_industrial"}}
 ],
 "home_rows": [
  {"id": "weir_lobbers", "enemy": "lobber", "site": "mesa_rim_road", "landform": "mesa_rim", "advantage": "From the rim road a lobber looks down the flume and the canal, two long held lines inside its 75 m range (lobber.gd:12).", "counter": "Drop off the flume into the canal, or the other way: the shell lands on the line you left (lobber.gd:3-7).", "reinforce": {"from_tier": 1, "every_s": 30.0, "max_alive": 4, "pack": "grounded"}, "break": {"by": "slam", "hp": 80.0, "scrap": 14}, "stops_kind": true, "dormant": false},
  {"id": "trestle_drones", "enemy": "winch_drone", "site": "trestle_hollow", "landform": "arroyo", "advantage": "Drones roost in the trestle bents; a 20 m winch lane along the flume (winch_drone.gd:15) hooks a ball that cannot step off a grind.", "counter": "Hold 19 m/s and the cable snaps on its own (winch_drone.gd:20); a jump snaps it too.", "reinforce": {"from_tier": 1, "every_s": 35.0, "max_alive": 3, "pack": "elite"}, "break": {"by": "damage", "hp": 90.0, "scrap": 16}, "stops_kind": true, "dormant": false},
  {"id": "wasteway_chasers", "enemy": "chaser", "site": "wasteway_chute", "landform": "canal", "advantage": "The wasteway floor is one straight concrete lane, the lane a chaser lunges down.", "counter": "Pump the wasteway walls and come down on them from above the lane.", "reinforce": {"from_tier": 1, "every_s": 25.0, "max_alive": 5, "pack": "run_down"}, "break": {"by": "ram", "hp": 60.0, "scrap": 12}, "stops_kind": true, "dormant": false},
  {"id": "forecourt_brutes", "enemy": "plated_brute", "site": "drum_forecourt", "landform": "penstock", "advantage": "The forecourt is the drum's front door, and a brute's 6 m slam ring (plated_brute.gd:12) covers the doorway every ground line rolls through.", "counter": "Take the forecourt geyser over the ring into the drum, or come off the bluff rim and land on the brute from above.", "reinforce": {"from_tier": 2, "every_s": 40.0, "max_alive": 2, "pack": "elite"}, "break": {"by": "damage", "hp": 140.0, "scrap": 20}, "stops_kind": true, "dormant": false},
  {"id": "dropship_trappers", "enemy": "mag_trapper", "site": "bench_landing", "landform": "slickrock", "advantage": "A landed crew pits the bench a light ball crosses to reach the hauler.", "counter": "Grow past the rating, or jump and smash the disc (mag_trapper.gd:6-9).", "reinforce": {"from_tier": 1, "every_s": 35.0, "max_alive": 3, "pack": "grounded"}, "break": {"by": "smash", "hp": 90.0, "scrap": 16}, "stops_kind": true, "dormant": true}
 ],
 "contraption_rows": [
  {"id": "weir_valve", "kind": "valve", "site": "butte_gap", "recipe": "gauge", "at": [-160, -270], "door": {"at": [-152, -252], "size": [12, 6, 1], "turn": 0.6}, "cache": {"at": [-142, -238]}, "codex": {"id": "flume_weir_cache", "title": "Pressure keeps the change", "category": "world", "name": "Pressure keeps the change", "hint": "A cracked wheel beside a copper door.", "clue": "Ram the valve on the Reach's west shelf + the copper door", "text": "A rolling ram turns the old valve. Behind the sinking door, the crew's spare parts wait."}},
  {"id": "mesa_zip", "kind": "cable", "site": "mesa_rim_road", "recipe": "", "from": [-392, 110.0, -442], "to": [-290, 55.0, -245], "radius": 4.0, "floor": 18.0},
  {"id": "hollow_lift", "kind": "lift", "site": "trestle_hollow", "recipe": "lift_platform", "at": [-210, -60], "radius": 4.5, "rise": 30.0, "charge": 3.2, "offset": 0.0},
  {"id": "flume_trebuchet", "kind": "launcher", "site": "canal_country", "recipe": "trebuchet", "style": "trebuchet", "at": [-345, -120], "radius": 3.5, "target": [-190, 31.0, -20], "floor": 30.0, "min_flight": 3.2, "charge": 4.0},
  {"id": "forecourt_geyser", "kind": "launcher", "site": "drum_forecourt", "recipe": "geyser_vent", "style": "geyser", "at": [140, 400], "radius": 3.5, "target": [222, -12.0, 462], "floor": 16.0, "min_flight": 2.2, "charge": 3.0},
  {"id": "squall_lane", "kind": "thermal", "site": "bluff_rim", "recipe": "", "at": [120, 260], "radius": 6.0, "height": 50.0},
  {"id": "culvert_wall", "kind": "cracked_wall", "site": "wasteway_chute", "recipe": "", "at": [117, 311], "size": [10, 6, 1.4], "turn": 1.2, "break_at_cruise": true},
  {"id": "bend_zip", "kind": "cable", "site": "bend_overlook", "recipe": "", "from": [50, 55.0, -170], "to": [120, 40.0, -40], "radius": 4.0, "floor": 18.0}
 ],
 "weather_rows": [
  {"id": "morning_clear", "kind": "clear", "trigger": {"on": "always"}, "lead_s": 0.0, "live_s": 0.0, "gap_s": 0.0, "fog": {"density": 0.0006, "color": "#b4c6d2"}, "sky": "clear", "sound": "bench_morning_bed", "music_layer": "", "event_odds": {}, "handling": "none"},
  {"id": "dust_squall", "kind": "dust_squall", "trigger": {"on": "clock_tier", "value": 2}, "lead_s": 15.0, "live_s": 60.0, "gap_s": 90.0, "fog": {"density": 0.003, "color": "#c8a878"}, "sky": "dust", "sound": "squall_hiss", "music_layer": "squall_shaker", "event_odds": {"hollow_trestle_collapse": 1.5, "wasteway_flash_flood": 0.5}, "handling": "none"}
 ],
 "activity_rows": [
  {"id": "siphon_camp", "activity": "enemy_camp", "site": "the_siphon", "at": [-28, 176], "pack": ["lobber", "lobber", "lobber"], "pay": {"named": "loose_trigger", "rarities": ["common"]}},
  {"id": "bend_cache", "activity": "cracked_cache", "site": "bend_rim_ledge", "at": [42, -142], "pack": [], "pay": {"rarities": ["rare"]}},
  {"id": "bench_bounty", "activity": "hauler_bounty", "site": "south_bench", "at": [-119, 332], "pack": [], "pay": {"rarities": ["common", "rare"]}}
 ]
}
```

The pilot lines, verbatim:

```json
{
  "map": "park_flume",
  "stage": 2,
  "pilots": {
    "sable": {"waypoints": ["drop_in", [-430, -615], [-369, -595], [-300, -586], [-225, -530], [-151, -472], [-180, -415], [-215, -350], [-250, -265], "butte_gap", [-240, -163], [-212, -100], [-200, -50], [-188, 0], [-176, 50], [-164, 100], [-142, 140], [-100, 158], "siphon_camp", [-30, 228], [-80, 290], [-100, 370], [-95, 425], [-20, 437], [60, 440], [130, 440], [170, 440], [205, 450], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}},
    "rivet": {"waypoints": ["drop_in", [-456, -560], [-466, -470], [-470, -420], [-470, -330], [-430, -288], [-360, -268], "butte_gap", [-220, -199], [-120, -148], [-20, -97], [60, -56], [110, -31], [125, 0], [90, 62], [30, 114], "siphon_camp", [-30, 228], [-80, 290], [-100, 370], [-95, 425], [-20, 437], [60, 440], [130, 440], [170, 440], [205, 450], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}},
    "kest": {"waypoints": ["drop_in", [-456, -560], [-466, -470], [-470, -420], [-470, -330], [-430, -288], [-360, -268], "butte_gap", [-220, -199], [-120, -148], [-20, -97], [50, -60], [110, -25], [110, 45], [40, 100], "siphon_camp", [20, 212], [60, 220], [120, 270], [180, 320], [240, 370], [278, 402], [258, 430], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}},
    "tarn": {"waypoints": ["drop_in", [-456, -560], [-466, -470], [-470, -420], [-470, -330], [-430, -288], [-360, -268], "butte_gap", [-300, -152], [-326, -85], [-298, -35], [-270, 15], [-242, 65], [-214, 115], [-200, 140], [-110, 155], "siphon_camp", [-30, 228], [-80, 290], [-100, 370], [-95, 425], [-20, 437], [60, 440], [130, 440], [170, 440], [205, 450], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}},
    "tally": {"waypoints": ["drop_in", [-456, -560], [-466, -470], [-470, -420], [-470, -330], [-430, -288], [-360, -268], "butte_gap", [-300, -152], [-326, -85], [-298, -35], [-270, 15], [-242, 65], [-195, 70], [-164, 100], [-142, 140], [-100, 158], "siphon_camp", [-15, 235], [-60, 300], [-100, 375], [-50, 420], [20, 392], [78, 430], [130, 445], [200, 445], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}},
    "cannon": {"waypoints": ["drop_in", [-456, -560], [-466, -470], [-470, -420], [-470, -330], [-430, -288], [-360, -268], "butte_gap", [-220, -205], [-130, -180], [-40, -172], [50, -170], [120, -40], [100, 20], [40, 100], "siphon_camp", [-5, 215], [40, 235], [95, 290], [125, 340], [120, 390], [160, 425], [215, 455], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}}
  },
  "floor": {"waypoints": ["drop_in", [-456, -560], [-466, -470], [-470, -420], [-470, -330], [-430, -288], [-360, -268], "butte_gap", [-300, -152], [-326, -85], [-298, -35], [-270, 15], [-242, 65], [-214, 115], [-200, 140], [-110, 155], "siphon_camp", [-30, 228], [-80, 290], [-100, 370], [-95, 425], [-20, 437], [60, 440], [130, 440], [170, 440], [205, 450], "landmark"]}
}
```

## 14. Storyboard

Board `park-2-park_flume`. `p1_overhead` is plotted; the rest are generated. Three vista subjects for this stage are on `artifacts/local/alpha/push/w13/concepts/boards/park-w1.json`.

| Panel | Frame |
| --- | --- |
| `p1_overhead` | Frame 0 |
| `p2_drop_in` | Frame 1 |
| `p3_line` | Frame 2 |
| `p4_home` | Frame 3 |
| `p5_event` | Frame 4 |
| `p6_warden` | Frame 6 |

**Frame 0, the plan.** The section 4 grid to scale: the mesa top-left, the flume's long S to the tower bottom-right, the pinches at the gap and the siphon, the gorges on the east.

**Frame 1, the drop-in vista.** From the weir deck in clear morning light, looking south-east down a long fall of canal country. The flume leaves the weir at your feet on timber trestles and runs away in a long S, its trestles growing taller as the land drops; green canal lines cut the tan fields; two buttes stand at the first bend; at the far end, 1.3 km away and below you, a slim concrete tower with a green beam stands beside a round head house on a bluff over a gorge.

**Frame 2, the first flow line.** Chase camera beside the ball grinding the flume 45 m above the ground, the timber channel a ribbon ahead, the trestle bents flicking past below, the butte gap opening ahead with the canal glinting through it.

**Frame 3, an enemy home.** The trestle hollow from its floor: an arroyo half-pipe, the flume's tallest trestles striding across it 49 m up, winch drones roosting in the bents, one drone's winch lane drawn along the flume, the ball high on the hollow's wall below them.

**Frame 4, an event firing.** The hollow trestle collapse in two beats. Left: the span groaning, dust falling from its joints, the warning colour along 40 m of flume. Right: the span down at an angle into the hollow, a ramp now, and the ball riding off the broken flume end onto it.

**Frame 5, the landmark approach.** Up the wasteway chute toward the forecourt: the round head house filling the frame, the tower rising behind it, the flume's last reach entering its north wall, plated brutes walking the forecourt, a slam ring dusting the doorway.

**Frame 6, the Warden fight.** Inside the drum: steel trusses overhead, the relic clamped on the flume's pour channel 12 m up with green seams blazing, two orange slag lanes running down the floor toward the ball, and the ball in the air over one of them, a harpoon line taut to a truss.

**Frame 7, the exit.** Through the east doors after the break: the three gates on the bluff lip, the bay over the drum, the ball launched out across the lower gorge toward a smoke column and a furnace glow on the eastern horizon, where the Requisition waits.
