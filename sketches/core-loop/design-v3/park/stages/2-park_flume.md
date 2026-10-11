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

**The penstock tower** (`landmark_penstock_tower`, `hero_landmark`). PARK.md:375 places "the flume head house at the top of the penstock tower". This draft reconciles that with the ground lines: the head house sits at the top of the penstocks, on the bluff edge where the flume ends, and the 90 m tower rises beside it as the surge tower. Every line then arrives at the head house on the ground, and the floor line can reach the Warden without a contraption (veto item 12, PARK.md:584). The penstocks leave the head house's east wall and fall 95 m down the bluff into the lower gorge. `sight_top` is the tower top, [300, 116, 560]; the land falls toward it from the whole park, so the drop-in looks down onto it. `light` is `ancient_beam`.

**The head house** is a round concrete drum 70 m across with 16 m walls (`head_house_drum`, a `bowl` row), roofed by open steel trusses at about 32 m. The flume enters through the north wall about 12 m up and pours down a channel onto the drum floor. Doors: the forecourt on the north-west, the annex on the south-west, the gate doors on the east facing the gorge.

**The mounting, `flume`** (PARK.md:425). The relic clamps onto the flume's pour channel, anchor [230, 41, 470], 12 m above the drum floor. The engage ring is the drum, centre [230, 480], `reach_m` 30, today's `beacon_radius` (`alpha_defs.gd:77`).

**What the mounting adds: it boils the flume.** Today's meltdown rule (`warden.gd:29-31`): every pulse leaves a slag lane toward the ball, 14 m long and 4 m wide, filling over 1 s and burning a grounded ball for 6 s at 4 damage a second (`warden.gd:56-60`, `263-291`). In the head house each lane pours out of the flume's channel and runs down the drum floor toward the ball, so the lanes come from one readable place. A ball in the air over a lane is safe and earns `slag_hop` (`codex_entries.gd:131-135`). The core window lasts 1.5 times longer, 6 s instead of 4 (`warden.gd:55`, `112-114`; `boss_posture.gd:17`).

## 4. Region sketch, and the exit to Brindle

Top-down, 80 m cells, generated from section 13. `~` marks the planned pilot lines.

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
| a | Upper canal country | Open ground for KD2's filler rows |
| o | The horseshoe gorge and far rim | The bend's gorge, about 95 m deep |
| x | Siphon and wasteway | Second waymark (the siphon camp), the wasteway chute, the culvert wall |
| s | The south bench | Slickrock bench: the hauler bounty, the dropship landing |
| q | The bluff | The bluff rim, the forecourt, the head house, the annex, the tower |
| l | The lower gorge | The penstocks' fall; the launch to Brindle crosses it |

Placed things:

```
H weir_lobbers [-350, -310]
H trestle_drones [-185, 10]
H wasteway_chasers [55, 295]
H forecourt_brutes [150, 420]
H dropship_trappers [-300, 460]
C weir_valve [-160, -270]
C mesa_zip [-392, -442]
C hollow_lift [-210, -60]
C flume_trebuchet [-320, -100]
C forecourt_geyser [140, 400]
C squall_lane [120, 260]
C culvert_wall [117, 311]
C bend_zip [50, -170]
A siphon_camp [-28, 176]
A bend_cache [22, -123]
A bench_bounty [-119, 332]
E hollow_trestle_collapse [-185, 10]
E wasteway_flash_flood [55, 295]
E bench_dropship [-300, 460]
E bend_relic_wakes [120, -60]
E annex_reactor_blow [185, 525]
B bay dock [239, 480]
G gate row [300, 480]
L penstock_tower (landmark) [270, 510]
W Warden engage ring centre [230, 480]
D drop-in [-460, -650]
```

The three activities: the siphon camp (`enemy_camp` with today's Reach lobber pack and the named `loose_trigger` pay, `map_reach.gd:142`), the bend cache (`cracked_cache`) and the bench bounty (`hauler_bounty`). Today's Reach has a fourth, the ambush altar (`map_reach.gd:143`); it moves to stage 1's east bench, so world 1 keeps all four kinds and each stage has three (PARK.md:194).

**The exit to Brindle.** After the break, the reward gates stand on the bluff lip outside the drum's east doors at x 300, facing +x over the lower gorge, and the bay docks 61 m behind them over the drum (`bay.gd:37-41`, `143-153`), so `bay_dock.at` is [239, 480]. The launch throws the ball out of the east doors and across the gorge. Stage 2 is the world's last stage, so when the launch flight ends (`LAUNCH_FLIGHT` 0.6 s, `flow.gd:23`), `_finish_stage` calls `enter_boss` with the ball's velocity instead of advancing (`flow.gd:667-673`, `456-473`), and Brindle's module places the ball in the Slag Bowl (`boss.gd:15-17`). The arena stays small and authored (PARK.md:381). The park only points at it: from the bend overlook and the bluff, a smoke column and a furnace glow stand on the eastern horizon past the lower gorge, the launch arc aims at them, and the Requisition's anvil enters the music on the last chunk (section 10).

## 5. `park_rows` (96 rows, shipped 2026-10-11)

The shipped file is `src/world/park/park_flume.json`; the bake and the stage graph are under `assets/park/park_flume/` (KD2). 57 of the rows are height-only filler (shallow washes, low banks and the four edge washes) that keep every open node within 80 m of a row (`park_density_test`: worst 69.8 m).

**The canvas is three flat terraces, not one ramp.** The draft's 112 m fall as one tilted plane made `tools/park_graph.gd` never finish: on a tilted plane every lattice edge has its own irrational length and the line search (`search_prev`, float32 distances in `src/world/park/park_graph.gd`) re-pushed one node 300 000 times. Flat terraces with sheer steps settle like the fixture, and each step is a drop the lines ride. Heights: the ground north of z -380 is +15, north of z -150 another +15, north of z 220 another +24; the siphon scarp adds 15 m above its edge and the weir mesa 40 m.

| Row | Element / landform / society | Verb, ride fact | Note |
| --- | --- | --- | --- |
| `canal_country`, `canal_country_mid`, `canal_country_low` | ground (plateau) / dry_wash / none | roll | the three terraces, edges at z -380, -150 and 220 |
| `siphon_scarp`, `weir_mesa` | ground (plateau) / mesa_rim / none | roll | the 15 m siphon scarp across the canal country at yaw 31; the 40 m mesa |
| `weir_deck` | drop / mesa_rim / dam_era | drop, `ride_drop` | the drop-in deck, `greybox:drop` |
| `weir_chute`, `mesa_ramp` | half_pipe, drop / flume, mesa_rim | pump, drop | the two 40 m ramps off the mesa (east to the flume, south to the canal) |
| `flume_weir_reach`, `flume_gap_reach`, `flume_hollow_reach`, `flume_head_reach`, `pour_channel` | grind_line / flume / dam_era | grind, `ride_grapple_line` | decks at y 109.8, 71, 55, 25 and -4; each reach drops onto the next |
| `crew_ledges`, `crane_booms` | elevated_line, anchor_field / mesa_rim / dam_era | roll, swing | the crew camp on the mesa's south face (replaces the cliff rooms) |
| `mesa_rim_road` | drop / mesa_rim / dam_era | drop | home `weir_lobbers` |
| `main_canal`, `butte_gap`, `lateral_canal` | flow_line / canal / hohokam | roll, `ride_chute` | `ref_` only; the gap is the first waymark |
| `west_butte`, `east_butte` | anchor_field / butte / none | swing | the gap's two buttes |
| `trestle_hollow` | half_pipe / arroyo / none | pump, `ride_chute` | 8 m deep (was 16: the floor line stalled climbing out); home `trestle_drones`; the collapse site |
| `rim_road`, `bend_overlook`, `bend_rim_ledge`, `bluff_rim` | bank, ledge / mesa_rim, horseshoe_bend | bank | the rim line; `bend_rim_ledge` [22, -123] holds the bend cache |
| `horseshoe_gorge`, `lower_gorge` | flow_line / horseshoe_bend, river_canyon / none | | channel stamps, 95 m |
| `the_siphon` | drop / canal / dam_era | drop | the second waymark's site, `greybox:drop` |
| `wasteway_chute`, `wasteway_wall_line` | half_pipe, bank / canal / dam_era | pump, bank | home `wasteway_chasers`; the flash flood; the wall line the flood opens |
| `south_bench`, `bench_landing` | ground / slickrock / none | | the bounty's bench; dormant home `dropship_trappers` on the landing |
| `drum_forecourt`, `head_house_drum`, `heat_exchanger_annex` | ground, bowl, ledge / penstock / dam_era | roll, bank | home `forecourt_brutes`; the fight floor; the reactor blow site |
| `head_house_trusses`, `drum_lip_kicker`, `gate_lip` | anchor_field, kicker, ground / penstock / dam_era | swing, launch | the Warden exit: the kicker off the drum's lip feeds the trusses (`warden_exit` connected) |

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
| `flume_trebuchet` | launcher, `trebuchet` | canal fields [-320, -100] | Throws you into the trestle hollow at [-205, 32, 20] (the hollow reach's deck is not built in play on this head; the target goes back onto the deck when KC-INT places the rows) |
| `hollow_lift` | lift, `lift_platform` | trestle hollow [-210, -60] | Lifts 30 m to the trestle catwalk, inside harpoon range of the flume (45 m) |
| `bend_zip` | cable | bend overlook, [50, 55, -170] to [120, 40, -40] | A 150 m zip along the bend's rim; the Cannon's line rides it (`ride_grapple_line` measured) |
| `squall_lane` | thermal | bluff rim [120, 260] | The dust squall's visible wind lane, 50 m |
| `culvert_wall` | cracked_wall | beside the wasteway [117, 311], off its footprint (ruling R3) | Breaks at cruise into a culvert shortcut |
| `forecourt_geyser` | launcher, `geyser_vent` | forecourt [140, 400] | Lobs you over the drum wall onto the relic's channel at [222, -2, 462] |

**Time of day: `morning`.** The sun has cleared the mesas; long shadows of the trestles fall west across the canal fields, and the head house's green seams read against a pale sky.

**Weather.** `morning_clear` (always) and `dust_squall` from tier 2: 15 s warning, 60 s live, 90 s gap, ochre fog at 0.003, a `dust` sky, a squall hiss, a `squall_shaker` music layer, collapse odds 1.5 times and flash-flood odds 0.5 times. `handling` is `"none"`.

## 9. Traversal lines

Four waymarks: `drop_in`, `butte_gap`, `siphon_camp`, `landmark`. The lines are `tools/park_lines/park_flume.json`, re-cut against the baked stage (2026-10-11): every line now enters the butte gap north of the west butte, leaves the hollow by its open south end, and Kest and the Cannon pass north of the weir valve's door. Four distinct lines: the flume and trebuchet (Sable), the hollow (Rivet, Tarn, Kest, the floor line), the fields (Tally) and the rim with the bend zip (the Cannon).

| Line | Waypoints |
| --- | --- |
| Sable | drop_in [-520, -600] [-390, -570] [-280, -560] [-150, -470] [-160, -330] butte_gap [-320, -100] [-205, 20] [-110, 40] [-20, 170] siphon_camp [-150, 300] [-60, 420] [140, 420] [230, 480] landmark |
| Rivet | drop_in [-500, -550] [-470, -460] [-470, -340] [-330, -310] butte_gap [-320, -100] [-230, 0] [-200, 90] [-150, 150] [-20, 170] siphon_camp [80, 260] [0, 360] [130, 420] [230, 480] landmark |
| Kest | drop_in [-500, -550] [-470, -460] [-470, -340] [-330, -310] butte_gap [-320, -100] [-230, 0] [-200, 90] [-150, 150] [-20, 170] siphon_camp [140, 200] [290, 300] [300, 420] [230, 480] landmark |
| Tarn | drop_in [-560, -540] [-640, -460] [-600, -400] [-520, -270] [-330, -300] butte_gap [-320, -100] [-230, 0] [-200, 90] [-150, 150] [-20, 170] siphon_camp [-110, 290] [0, 390] [140, 420] [230, 480] landmark |
| Tally | drop_in [-500, -550] [-470, -460] [-470, -340] [-330, -310] butte_gap [-320, -100] [-205, 20] [-290, 100] [-150, 170] [-20, 170] siphon_camp [80, 260] [0, 360] [130, 420] [230, 480] landmark |
| The Cannon | drop_in [-500, -550] [-470, -460] [-470, -340] [-330, -310] butte_gap [-250, -160] [-140, -165] [50, -170] [120, -40] [40, 100] [-20, 170] siphon_camp [140, 200] [100, 330] [140, 400] [230, 480] landmark |
| Floor line | drop_in [-500, -550] [-470, -460] [-470, -340] [-330, -310] butte_gap [-320, -100] [-230, 0] [-200, 90] [-150, 150] [-20, 170] siphon_camp [80, 260] [0, 360] [130, 420] [230, 480] landmark |

**Measured** (KB7 `tools/traversal_line.gd`, 8 seeds, greybox pass; medians and worst seed). The full table with every band is `design-v3/park/traversal/park_flume.md`.

| Band | sable | rivet | kest | tarn | tally | cannon | floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| reached Warden (8 of 8) | 8 of 8 pass | 8 of 8 pass | 8 of 8 pass | 8 of 8 pass | 8 of 8 pass | 8 of 8 pass | 8 of 8 pass |
| time to Warden s (median 60-120, none over 150) | 62.25 / 64.46 pass | 90.77 / 94.85 pass | 84.845 / 88.45 pass | 89.82 / 91.07 pass | 98.115 / 100.01 pass | 96.975 / 98.68 pass | 91.335 / 96.82 pass |
| segment s (medians 12-45) | [26.42, 14.22, 22.04] / 26.42 pass | [31.6, 28.23, 30.62] / 31.87 pass | [28.68, 26.4, 30.04] / 30.035 pass | [37.45, 24.29, 27.71] / 37.455 pass | [31.79, 37.28, 28.84] / 37.275 pass | [29.43, 39.9, 27.93] / 39.9 pass | [32.03, 28.48, 31] / 32.25 pass |
| flow share (median >= 0.70, none under 0.60) | 0.949 / 0.943 pass | 0.739 / 0.668 pass | 0.686 / 0.576 MISS | 0.945 / 0.931 pass | 0.732 / 0.693 pass | 0.88 / 0.867 pass | 0.684 / 0.617 MISS |
| airborne share (0.12-0.45) | 0.265 / None pass | 0.171 / None pass | 0.192 / None pass | 0.201 / None pass | 0.162 / None pass | 0.217 / None pass | 0.17 / None pass |
| dead stops (0) | 0 / 0 pass | 0 / 0 pass | 0 / 1 MISS | 0 / 0 pass | 0 / 0 pass | 0 / 1 MISS | 0 / 0 pass |
| peak m/s (>= blazing on every seed) | 51.705 / 51.39 pass | 32.48 / 31.06 pass | 31.57 / 30 pass | 30 / 24.44 MISS | 31.445 / 31.27 pass | 30.245 / 29.59 pass | 32.14 / 30 pass |
| tier-3 s (median >= 3) | 49.3 / None pass | 10.42 / None pass | 10.385 / None pass | 10.185 / None pass | 10.305 / None pass | 8.405 / None pass | 10.485 / None pass |
| quiet max s (<= 20) | 6.69 / 6.69 pass | 6.69 / 6.69 pass | 6.69 / 6.69 pass | 6.69 / 6.69 pass | 6.69 / 6.69 pass | 6.69 / 6.69 pass | 6.69 / 6.69 pass |
| anchor gap m (<= 40) | 599.55 / 641.9 MISS | 548.6 / 555.1 MISS | 545.25 / 561 MISS | 547.4 / 551 MISS | 679.9 / 685.3 MISS | 312.95 / 322.1 MISS | 545.85 / 551.3 MISS |
| distinct ride facts (>= 3) | 1 / 1 MISS | 1 / 1 MISS | 1 / 1 MISS | 1 / 1 MISS | 1 / 1 MISS | 2 / 1 MISS | 1 / 1 MISS |
| length ratio (1.3-2.0) | 1.64 / None pass | 1.37 / None pass | 1.4 / None pass | 1.56 / None pass | 1.475 / None pass | 1.55 / None pass | 1.37 / None pass |
| progress m/s | not measured (KB7b) | not measured (KB7b) | not measured (KB7b) | not measured (KB7b) | not measured (KB7b) | not measured (KB7b) | not measured (KB7b) |

Floor band `floor` (reaches the Warden in at most 2.0 times rivet's median time, 0 dead stops): median 91.335, worst 181.54, pass

**Two bands miss on every line, and neither is a row problem** (the other misses, Kest and the Cannon's single dead stops at the mesa ramp's foot, Kest's and the floor line's flow share and Tarn's worst-seed peak, are listed in the traversal file). On this head no park row is built in play: `ParkRecipes.place` has no caller (only the bake's height stamps, the contraptions and the Warden reach the stage), so the greybox rows' ride sensors never fire and their faces are not there to hook. The countable ride facts left are a cable (`ride_grapple_line`) and a thermal (gliders only); `lift_fired` drops out at KB7b. The anchor gap reads only the terrain's steep faces. Both bands are re-measured when the rows are placed (follow-up).

**Tricks each line offers** (`class_def.gd:87-122`):

- **Sable**: the flume line from the weir, the trebuchet's throw off the gap into the hollow, then the bench side of the siphon.
- **Rivet**: the mesa ramp, the canal to the gap, the hollow end to end, the wasteway; every straight is a sprint lane.
- **Kest**: Rivet's way to the siphon, then east along the bluff and into the drum from the east.
- **Tarn**: the crew camp: off the mesa's south-west shoulder past the bunk ledges, round the ramp's foot to the gap.
- **Tally**: the trebuchet into the hollow, west across the fields and back east to the siphon.
- **The Cannon**: the rim: the rim road, the bend zip, back down to the siphon, the forecourt geyser into the drum.

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

The park file is `src/world/park/park_flume.json` (KD2 greybox, 2026-10-11) and the lines are `tools/park_lines/park_flume.json`; the stage test `tests/park_park_flume_test.gd` pins them. Changes from the draft that stood here:

- Removed `cliff_rooms` and `viga_beams`; added the crew camp (`crew_ledges`, `crane_booms`), the three terraces, `bend_rim_ledge`, `drum_lip_kicker` and the height-only filler rows (density).
- Removed `bend_far_rim`: the bend cache moved onto `bend_rim_ledge` [22, -123] beside the rim line (door 204 m by path, sight_ok), the pay deep enough for the reward band.
- `bench_bounty` moved to [-119, 332] on the bench's north edge (door 193 m by path); `dropship_trappers` and `bench_dropship` stand on `bench_landing`.
- `weir_valve` stands on the butte gap's east shelf with codex id `flume_weir_cache`; `culvert_wall` sits off the wasteway's footprint.
- `warden_exit` runs `drum_lip_kicker`, `head_house_trusses`, `head_house_drum`; `landmark.warden` is the reactor on the flume mounting with `harpoon_anchor` true.
- Every `_est`, `_detour_m` and `pocket_est` key is gone; the numbers come from `assets/park/park_flume/graph.json`.

| Pocket | Role | Door [x, z] | door_m | detour_m | d_spawn | d_landmark | sight_ok | pay |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `siphon_camp` | on the line | [-24, 176] | 0 | 0 | 980 | 419 | yes | common (`loose_trigger`) |
| `bend_cache` | reward | [24, -120] | 204 | 204 | 769 | 702 | yes | rare |
| `bench_bounty` | risk | [-120, 336] | 193 | 193 | 1140 | 415 | yes | common or rare |
| `weir_valve` | hidden | [-152, -248] | 108 | 110 | 561 | 908 | yes | the cache |


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
