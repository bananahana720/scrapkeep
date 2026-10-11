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
H dropship_trappers [-200, 520]
C weir_valve [-380, -350]
C mesa_zip [-390, -440]
C hollow_lift [-210, -60]
C flume_trebuchet [-320, -100]
C forecourt_geyser [140, 400]
C squall_lane [120, 260]
C culvert_wall [40, 330]
C bend_zip [50, -170]
A siphon_camp [-28, 176]
A bend_cache [150, -80]
A bench_bounty [-160, 480]
E hollow_trestle_collapse [-185, 10]
E wasteway_flash_flood [55, 295]
E bench_dropship [-200, 520]
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

## 5. `park_rows` draft (29 rows)

KD2 grows it to the 40 to 70 rows of PARK.md:67, mostly filler in the upper canal country and the far rim, until the density test passes (PARK.md:474).

| Row | Element / landform / society | Verb, ride fact | Note |
| --- | --- | --- | --- |
| `canal_country`, `weir_mesa` | ground / dry_wash, mesa_rim / none | roll | the 112 m fall and the 40 m mesa |
| `weir_deck` | drop / mesa_rim / dam_era | drop, `ride_drop` | the drop-in deck |
| `weir_chute` | half_pipe / flume / dam_era | pump, `ride_chute` | the weir's spill chute onto the flume |
| `flume_weir_reach`, `flume_gap_reach`, `flume_hollow_reach`, `flume_head_reach` | grind_line / flume / dam_era | grind, `ride_grapple_line` | the flume in four reaches, y 136 to 62 |
| `mesa_ramp` | drop / mesa_rim / none | drop | off the mesa into the canal fields |
| `main_canal`, `butte_gap`, `lateral_canal` | flow_line / canal / hohokam | roll, `ride_chute` | `ref_` only; the gap is the first waymark |
| `west_butte`, `east_butte` | anchor_field / butte / none | swing | harpoon anchors at the gap |
| `cliff_rooms`, `viga_beams` | elevated_line, anchor_field / cliff_dwelling / ancestral_puebloan | roll, swing | `ref_` only |
| `mesa_rim_road` | drop / mesa_rim / dam_era | drop, `ride_drop` | home `weir_lobbers` |
| `trestle_hollow` | half_pipe / arroyo / none | pump, `ride_chute` | home `trestle_drones`; the collapse site |
| `the_siphon` | drop / canal / dam_era | drop, `ride_drop` | the second waymark's site |
| `wasteway_chute` | half_pipe / canal / dam_era | pump, `ride_chute` | home `wasteway_chasers`; the flash flood |
| `south_bench` | ground / slickrock / none | | dormant home `dropship_trappers` |
| `rim_road`, `bend_overlook`, `bluff_rim` | bank / mesa_rim, horseshoe_bend | bank, `ride_bowl` | the rim line |
| `horseshoe_gorge`, `lower_gorge` | ground / horseshoe_bend / none | | channel stamps, 95 m |
| `drum_forecourt` | ground / penstock / dam_era | roll | home `forecourt_brutes` |
| `head_house_drum` | bowl / penstock / dam_era | bank, `ride_bowl` | the fight floor |
| `heat_exchanger_annex` | ledge / penstock / dam_era | roll | the reactor blow site |

## 6. `event_rows` draft (5 rows)

| Row | Family, kind | Site | Trigger | Telegraph | What changes | Route change |
| --- | --- | --- | --- | --- | --- | --- |
| `hollow_trestle_collapse` | natural, `collapse` | trestle hollow | tier 2 (90 s) | 6 s `trestle_groan` | A flume span over the hollow drops into a ramp | closes `flume_mid`, opens `trestle_ramp_line` |
| `wasteway_flash_flood` | natural, `flash_flood` | wasteway chute | tier 1 (45 s) | 5 s `flood_rising` | 1.6 m of water for 30 s | closes `canal_lower`, opens `wasteway_wall` |
| `bench_dropship` | fleet, `fleet_landing` | south bench | tier 2 | 10 s `fleet_inbound` | a dropship lands and wakes `dropship_trappers` | none (no line crosses the bench) |
| `bend_relic_wakes` | ancient, `machine_eruption` | bend overlook | tier 2 | 8 s `ancient_stirring` | a `reactor_relic` miniboss erupts from the bend's rock | none |
| `annex_reactor_blow` | industrial, `reactor_blow` | heat-exchanger annex | Warden `chunk_2` | 5 s `reactor_overload` | a 20 m fallout ring, 6 damage, 8 s; the annex roof becomes a ramp into the drum | opens `annex_ramp_line` |

**The collapse is a ride, not a wall.** The span falls only when the ball is clear of it by `hold_clear_m` (20 m) and its next 2 s of travel (PARK.md:308), after a 6 s groan on the flume. A ball arriving at the break later rides off the flume's end onto the fallen span, now a ramp down into the hollow: Tally's line. Only a player who ignores six seconds of groaning loses the grind.

**The industrial row changes kind.** PARK.md:383 starts stage 2 with a head-house boiler at chunk 2. Stage 1 already has a boiler at chunk 2, so this draft makes stage 2's a `reactor_blow` in the annex: breaking the relic's chunks overloads the dam-era heat exchanger it was feeding. On the veto list below.

The route test passed in scratch over every allowed overlap.

## 7. `home_rows` (5 homes)

| Home | Kind | Site, landform | Advantage | Counter | Reinforce | Break |
| --- | --- | --- | --- | --- | --- | --- |
| `weir_lobbers` | lobber | mesa rim road, mesa_rim | The rim road looks down the flume and the canal, two long held lines inside 75 m (`lobber.gd:12`) | Drop off the flume into the canal or back: the shell lands on the line you left (`lobber.gd:3-7`) | tier 1, 30 s, 4, `grounded` | slam, 80, 14 |
| `trestle_drones` | winch_drone | trestle hollow, arroyo | Drones roost in the bents; a 20 m winch lane along the flume (`winch_drone.gd:15`) hooks a ball that cannot step off a grind | Hold 19 m/s and the cable snaps (`winch_drone.gd:20`); a jump snaps it too | tier 1, 35 s, 3, `elite` | damage, 90, 16 |
| `wasteway_chasers` | chaser | wasteway chute, canal | One straight concrete floor, the lane a chaser lunges down | Pump the walls and come down on them from above the lane | tier 1, 25 s, 5, `run_down` | ram, 60, 12 |
| `forecourt_brutes` | plated_brute | forecourt, penstock | The forecourt is the drum's front door; a brute's 6 m slam ring (`plated_brute.gd:12`) covers the doorway | Take the forecourt geyser over the ring, or land on the brute from the bluff rim | tier 2, 40 s, 2, `elite` | damage, 140, 20 |
| `dropship_trappers` (dormant) | mag_trapper | south bench, slickrock | A landed crew pits the bench a light ball crosses to reach the hauler | Grow past the rating, or jump and smash the disc (`mag_trapper.gd:6-9`) | tier 1, 35 s, 3, `grounded` | smash, 90, 16 |

The winch drone is the flume's natural enemy: it is the one kind whose threat is a held line, and the flume is the longest held line in world 1.

## 8. `contraption_rows` (8 rows), weather and time of day

| Row | Kind, skin | Where | What it does for the line |
| --- | --- | --- | --- |
| `weir_valve` | valve, `gauge` | mesa rim road | Opens a cache pocket; keeps today's codex row `reach_pressure_cache` (`codex_world.gd:59`, `map_reach.gd:232-235`) |
| `mesa_zip` | cable | mesa rim road | A 225 m zip from the mesa edge down to the butte gap |
| `flume_trebuchet` | launcher, `trebuchet` | canal fields | Throws you from the lateral canal up onto the flume's hollow reach |
| `hollow_lift` | lift, `lift_platform` | trestle hollow | Lifts 30 m to the trestle catwalk, inside harpoon range of the flume (45 m, PARK.md:414) |
| `bend_zip` | cable | bend overlook | A 150 m zip along the bend's rim |
| `squall_lane` | thermal | bluff rim | The dust squall's visible wind lane, 50 m; the only wind that moves the ball (PARK.md:188) |
| `culvert_wall` | cracked_wall | wasteway chute | Breaks at cruise into a culvert shortcut |
| `forecourt_geyser` | launcher, `geyser_vent` | forecourt | Lobs you over the drum wall onto the relic's channel: the air entry into the fight |

**Time of day: `morning`** (PARK.md:375). The sun has cleared the mesas; long shadows of the trestles fall west across the canal fields, and the head house's green seams read against a pale sky.

**Weather.** `morning_clear` (always) and `dust_squall` from tier 2: 15 s warning, 60 s live, 90 s gap, ochre fog at 0.003, a `dust` sky, a squall hiss, a `squall_shaker` music layer, collapse odds 1.5 times and flash-flood odds 0.5 times. `handling` is `"none"`; the squall's push exists only as the `squall_lane` thermal. Today's squall is a stage event with its own codex row (`src/world/dust_squall.gd`; `squall_sail`, `codex_world.gd:33`); KE7 decides whether that event folds into this weather row.

## 9. Traversal lines

Four waymarks: `drop_in`, `butte_gap`, `siphon_camp`, `landmark`. Bands from PARK.md:452-468; estimates at a 20 m/s mean.

**The flow line a skater would take** (Rivet's and the floor line): roll off the weir deck down the mesa ramp, carve the main canal's bends to the butte gap, follow the lateral canal through the fields, drop through the siphon, pump the wasteway, cross the forecourt and roll into the drum. No harpoon, no contraption. Sable's line is the other natural reading: never leave the flume.

| Line | Path (m) | Length ratio (band 1.3 to 2.0) | Segments (m) | Est. segment s (band 12 to 45) | Est. drop-in to Warden s (band 60 to 120) |
| --- | --- | --- | --- | --- | --- |
| Sable | 1799 | 1.36 | 671, 577, 550 | 34, 29, 28 | 90 |
| Rivet | 1767 | 1.33 | 611, 633, 522 | 31, 32, 26 | 88 |
| Kest | 1969 | 1.49 | 671, 742, 556 | 34, 37, 28 | 98 |
| Tarn | 1937 | 1.46 | 754, 633, 550 | 38, 32, 28 | 97 |
| Tally | 1749 | 1.32 | 611, 615, 522 | 31, 31, 26 | 87 |
| Cannon | 1909 | 1.44 | 611, 742, 556 | 31, 37, 28 | 95 |
| Floor line | 1767 | 1.33 | 611, 633, 522 | 31, 32, 26 | 88 |

Straight distance drop-in to engage centre: 1324 m. The floor line rides Rivet's waypoints with no harpoon and no contraption; its band is at most 2.0 times the pilot line's median time (PARK.md:467). Flow share, airborne share, peak speed, quiet stretch, anchor gap and distinct verbs need the bot on the baked greybox (KB7, KD); the line JSON carries today's bar keys at the band floors.

Distinct lines: 13 of 15 pilot pairs share fewer than half their samples within 8 m.

**Tricks each line offers** (`class_def.gd:87-122`):

- **Sable**: the flume end to end. Slingshot off trestle bents to skip the gap reach's bend; vault off the weir chute's wall onto the flume; at the end, a vault off the pour channel's cheek onto the relic.
- **Rivet**: the canal end to end. Every straight of the main canal and the wasteway is a sprint lane; the sprint holds through the camp's crowd control, and the wasteway's last straight carries it into the forecourt at speed.
- **Kest**: the flume's first kilometre, then the rim. Rocket-jump off the flume at the butte gap onto the rim road, glide the horseshoe bend from its overlook, ride the bend zip, glide the squall lane's updraft onto the bluff.
- **Tarn**: the crew camp. Claw-pull along the mesa's south face from bunk ledge to bunk ledge, swing the crane booms, pull down onto the rim road, then the canal, then claw up onto the flume's last reach at the siphon.
- **Tally**: the hollow. Surge down the main canal, drop into the trestle hollow and pump its walls, refill by rolling the hollow's length, surge through the wasteway. After the collapse this is the line the fallen span feeds.
- **The Cannon**: the canal, then the rim. Recoil-hop across the bend's gorge corner, take the bend zip, recoil onto the bluff rim and come into the drum from the east.

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

## 13. The draft park file

KD2 copies this to `src/world/park/park_flume.json`.

```json
{
 "schema": "scrapkeep-park/1",
 "map": "park_flume",
 "size_m": 1600,
 "time_of_day": "morning",
 "spawn": {"at": [-460, -650], "heading_deg": 31},
 "play_rect": [-780, -780, 1300, 1560],
 "landmark": {"id": "penstock_tower", "kind": "penstock_tower", "at": [270, 510], "size": [140, 90, 120], "yaw_deg": 31, "recipe": "landmark_penstock_tower", "budget": "hero_landmark", "sight_top": [300, 116, 560], "sight_share": 0.85, "beacon": [230, 480], "reach_m": 30, "warden": {"mounting": "flume", "anchor": [230, 41, 470], "path": [], "hardpoints": 3}, "bay_dock": {"at": [239, 480], "facing_deg": 90}, "gate_slots": [{"at": [300, 466], "facing_deg": 90}, {"at": [300, 480], "facing_deg": 90}, {"at": [300, 494], "facing_deg": 90}], "light": "ancient_beam", "music": "landmark_hum", "fragment": "headhouse_relic_plate"},
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
  {"id": "flume_lower", "from": "the_siphon", "to": "landmark", "via": ["flume_head_reach", "head_house_drum"]},
  {"id": "canal_lower", "from": "the_siphon", "to": "drum_forecourt", "via": ["wasteway_chute"]},
  {"id": "wasteway_wall", "from": "the_siphon", "to": "drum_forecourt", "via": ["wasteway_chute"]},
  {"id": "rim_lower", "from": "the_siphon", "to": "landmark", "via": ["bluff_rim", "head_house_drum"]},
  {"id": "forecourt_entry", "from": "drum_forecourt", "to": "landmark", "via": ["drum_forecourt", "head_house_drum"]},
  {"id": "annex_ramp_line", "from": "drum_forecourt", "to": "landmark", "via": ["heat_exchanger_annex", "head_house_drum"]}
 ],
 "park_rows": [
  {"id": "canal_country", "element": "ground", "landform": "dry_wash", "society": "none", "at": [0, 0], "y": null, "size": [1600, 112, 1600], "yaw_deg": 31, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "ramp", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "weir_mesa", "element": "ground", "landform": "mesa_rim", "society": "none", "at": [-560, -620], "y": null, "size": [380, 40, 360], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "mesa", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "weir_deck", "element": "drop", "landform": "mesa_rim", "society": "dam_era", "at": [-460, -650], "y": null, "size": [44, 10, 30], "yaw_deg": 31, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:drop", "stamp": "mesa", "hole": false, "budget": "landform", "routes": ["flume_upper", "canal_upper"], "fragment": "dam_era_flume_survey"},
  {"id": "weir_chute", "element": "half_pipe", "landform": "flume", "society": "dam_era", "at": [-425, -610], "y": null, "size": [106, 40, 16], "yaw_deg": 41, "verb": "pump", "ride_fact": "ride_chute", "home": "", "recipe": "wash_dropin_lip", "stamp": "ramp", "hole": false, "budget": "landform", "routes": ["flume_upper"], "fragment": ""},
  {"id": "flume_weir_reach", "element": "grind_line", "landform": "flume", "society": "dam_era", "at": [-270, -520], "y": 136, "size": [260, 8, 8], "yaw_deg": 67, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "flume_span", "stamp": "", "hole": false, "budget": "landform", "routes": ["flume_upper"], "fragment": ""},
  {"id": "flume_gap_reach", "element": "grind_line", "landform": "flume", "society": "dam_era", "at": [-215, -350], "y": 120, "size": [273, 8, 8], "yaw_deg": -28, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "flume_span", "stamp": "", "hole": false, "budget": "landform", "routes": ["flume_upper"], "fragment": "dam_era_trestle_tag"},
  {"id": "flume_hollow_reach", "element": "grind_line", "landform": "flume", "society": "dam_era", "at": [-150, -30], "y": 96, "size": [477, 8, 120], "yaw_deg": 33, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "flume_span", "stamp": "", "hole": false, "budget": "landform", "routes": ["flume_mid", "trestle_ramp_line"], "fragment": ""},
  {"id": "flume_head_reach", "element": "grind_line", "landform": "flume", "society": "dam_era", "at": [105, 325], "y": 62, "size": [398, 8, 120], "yaw_deg": 39, "verb": "grind", "ride_fact": "ride_grapple_line", "home": "", "recipe": "flume_span", "stamp": "", "hole": false, "budget": "landform", "routes": ["flume_lower"], "fragment": ""},
  {"id": "mesa_ramp", "element": "drop", "landform": "mesa_rim", "society": "none", "at": [-480, -595], "y": null, "size": [117, 40, 50], "yaw_deg": -20, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:drop", "stamp": "ramp", "hole": false, "budget": "landform", "routes": ["canal_upper"], "fragment": ""},
  {"id": "main_canal", "element": "flow_line", "landform": "canal", "society": "hohokam", "at": [-390, -385], "y": null, "size": [380, 3, 120], "yaw_deg": 35, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "canal_lip", "stamp": "channel", "hole": false, "budget": "landform", "routes": ["canal_upper"], "fragment": "ref_canal_headgate"},
  {"id": "butte_gap", "element": "flow_line", "landform": "canal", "society": "hohokam", "at": [-280, -230], "y": null, "size": [80, 3, 30], "yaw_deg": 30, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "canal_lip", "stamp": "channel", "hole": false, "budget": "landform", "routes": [], "fragment": "ref_canal_gap_cut"},
  {"id": "west_butte", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-350, -250], "y": null, "size": [70, 100, 70], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "east_butte", "element": "anchor_field", "landform": "butte", "society": "none", "at": [-210, -205], "y": null, "size": [60, 90, 60], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "", "stamp": "butte", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "lateral_canal", "element": "flow_line", "landform": "canal", "society": "hohokam", "at": [-210, -40], "y": null, "size": [405, 3, 140], "yaw_deg": 20, "verb": "roll", "ride_fact": "ride_chute", "home": "", "recipe": "canal_lip", "stamp": "channel", "hole": false, "budget": "landform", "routes": ["canal_mid"], "fragment": "ref_canal_turnout"},
  {"id": "crew_ledges", "element": "elevated_line", "landform": "mesa_rim", "society": "dam_era", "at": [-600, -425], "y": 110, "size": [120, 8, 10], "yaw_deg": 85, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "mesa_rim_ledge", "stamp": "", "hole": false, "budget": "landform", "routes": ["camp_rim"], "fragment": "dam_era_crew_bunks"},
  {"id": "crane_booms", "element": "anchor_field", "landform": "mesa_rim", "society": "dam_era", "at": [-470, -405], "y": 112, "size": [60, 4, 4], "yaw_deg": 90, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "detail", "routes": ["camp_rim"], "fragment": "dam_era_boom_tag"},
  {"id": "mesa_rim_road", "element": "drop", "landform": "mesa_rim", "society": "dam_era", "at": [-350, -310], "y": null, "size": [213, 30, 14], "yaw_deg": 41, "verb": "drop", "ride_fact": "ride_drop", "home": "weir_lobbers", "recipe": "mesa_rim_ledge", "stamp": "ramp", "hole": false, "budget": "landform", "routes": ["camp_rim"], "fragment": "dam_era_road_marker"},
  {"id": "trestle_hollow", "element": "half_pipe", "landform": "arroyo", "society": "none", "at": [-185, 10], "y": null, "size": [289, 16, 160], "yaw_deg": 14, "verb": "pump", "ride_fact": "ride_chute", "home": "trestle_drones", "recipe": "greybox:half_pipe", "stamp": "wash", "hole": false, "budget": "landform", "routes": ["hollow_run", "trestle_ramp_line"], "fragment": ""},
  {"id": "the_siphon", "element": "drop", "landform": "canal", "society": "dam_era", "at": [-20, 170], "y": null, "size": [40, 6, 30], "yaw_deg": 31, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:drop", "stamp": "", "hole": false, "budget": "landform", "routes": [], "fragment": "dam_era_siphon_plate"},
  {"id": "wasteway_chute", "element": "half_pipe", "landform": "canal", "society": "dam_era", "at": [55, 295], "y": null, "size": [292, 10, 140], "yaw_deg": 31, "verb": "pump", "ride_fact": "ride_chute", "home": "wasteway_chasers", "recipe": "half_pipe_concrete", "stamp": "wash", "hole": false, "budget": "landform", "routes": ["canal_lower", "wasteway_wall"], "fragment": "dam_era_wasteway_gauge"},
  {"id": "south_bench", "element": "ground", "landform": "slickrock", "society": "none", "at": [-200, 520], "y": null, "size": [260, 6, 300], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "dropship_trappers", "recipe": "", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "rim_road", "element": "bank", "landform": "mesa_rim", "society": "dam_era", "at": [-85, -130], "y": null, "size": [438, 6, 60], "yaw_deg": 63, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:bank", "stamp": "terrace", "hole": false, "budget": "landform", "routes": ["rim_mid"], "fragment": "dam_era_rim_milepost"},
  {"id": "bend_overlook", "element": "bank", "landform": "horseshoe_bend", "society": "none", "at": [120, -60], "y": null, "size": [140, 8, 100], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:bank", "stamp": "", "hole": false, "budget": "landform", "routes": ["rim_mid"], "fragment": ""},
  {"id": "horseshoe_gorge", "element": "ground", "landform": "horseshoe_bend", "society": "none", "at": [270, -60], "y": null, "size": [500, 95, 180], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "channel", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "lower_gorge", "element": "ground", "landform": "river_canyon", "society": "none", "at": [420, 420], "y": null, "size": [500, 95, 120], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "channel", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "bluff_rim", "element": "bank", "landform": "mesa_rim", "society": "none", "at": [140, 295], "y": null, "size": [406, 5, 60], "yaw_deg": 52, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:bank", "stamp": "terrace", "hole": false, "budget": "landform", "routes": ["rim_lower"], "fragment": ""},
  {"id": "drum_forecourt", "element": "ground", "landform": "penstock", "society": "dam_era", "at": [150, 420], "y": null, "size": [40, 2, 60], "yaw_deg": 31, "verb": "roll", "ride_fact": "", "home": "forecourt_brutes", "recipe": "", "stamp": "plateau", "hole": false, "budget": "landform", "routes": ["forecourt_entry"], "fragment": ""},
  {"id": "head_house_drum", "element": "bowl", "landform": "penstock", "society": "dam_era", "at": [230, 480], "y": null, "size": [70, 16, 70], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "bench_coping", "stamp": "bowl", "hole": false, "budget": "landform", "routes": ["flume_lower", "rim_lower", "forecourt_entry", "annex_ramp_line"], "fragment": "dam_era_headhouse_log"},
  {"id": "heat_exchanger_annex", "element": "ledge", "landform": "penstock", "society": "dam_era", "at": [185, 525], "y": null, "size": [40, 14, 24], "yaw_deg": 35, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "greybox:ledge", "stamp": "", "hole": false, "budget": "detail", "routes": ["annex_ramp_line"], "fragment": "dam_era_annex_dial"}
 ],
 "event_rows": [
  {"id": "hollow_trestle_collapse", "kind": "collapse", "family": "natural", "site": "trestle_hollow", "trigger": {"on": "clock_tier", "value": 2}, "weight": 1.0, "telegraph": {"lead_s": 6.0, "form": "trestle_groan", "on_bar": true}, "live_s": 0.0, "effect": {"swap": "trestle_ramp"}, "route_change": {"closes": ["flume_mid"], "opens": ["trestle_ramp_line"]}, "hold_clear_m": 20.0, "cooldown_s": 0.0, "once": true, "music_cue": {"telegraph": "riser_natural", "land": "drop_collapse"}},
  {"id": "wasteway_flash_flood", "kind": "flash_flood", "family": "natural", "site": "wasteway_chute", "trigger": {"on": "clock_tier", "value": 1}, "weight": 0.6, "telegraph": {"lead_s": 5.0, "form": "flood_rising", "on_bar": true}, "live_s": 30.0, "effect": {"depth_m": 1.2, "fill_s": 4.0, "material": "water"}, "route_change": {"closes": ["canal_lower"], "opens": ["wasteway_wall"]}, "hold_clear_m": 15.0, "cooldown_s": 120.0, "once": false, "music_cue": {"telegraph": "riser_natural", "land": "drop_flash_flood"}},
  {"id": "bench_dropship", "kind": "fleet_landing", "family": "fleet", "site": "south_bench", "trigger": {"on": "clock_tier", "value": 2}, "weight": 1.0, "telegraph": {"lead_s": 10.0, "form": "fleet_inbound", "on_bar": true}, "live_s": 0.0, "effect": {"vessel": "dropship", "home": "dropship_trappers", "footprint_m": [36, 16]}, "route_change": {"closes": [], "opens": []}, "hold_clear_m": 25.0, "cooldown_s": 0.0, "once": true, "music_cue": {"telegraph": "riser_fleet", "land": "drop_fleet"}},
  {"id": "bend_relic_wakes", "kind": "machine_eruption", "family": "ancient", "site": "bend_overlook", "trigger": {"on": "clock_tier", "value": 2}, "weight": 1.0, "telegraph": {"lead_s": 8.0, "form": "ancient_stirring", "on_bar": true}, "live_s": 0.0, "effect": {"miniboss": "reactor_relic", "swap": "bend_vent_lip"}, "route_change": {"closes": [], "opens": []}, "hold_clear_m": 15.0, "cooldown_s": 0.0, "once": true, "music_cue": {"telegraph": "riser_ancient", "land": "drop_ancient"}},
  {"id": "annex_reactor_blow", "kind": "reactor_blow", "family": "industrial", "site": "heat_exchanger_annex", "trigger": {"on": "warden_phase", "value": "chunk_2"}, "weight": 1.0, "telegraph": {"lead_s": 5.0, "form": "reactor_overload", "on_bar": true}, "live_s": 8.0, "effect": {"hazard": "fallout_ring", "hazard_m": [20, 20], "damage": 6.0, "swap": "annex_ramp"}, "route_change": {"closes": [], "opens": ["annex_ramp_line"]}, "hold_clear_m": 14.0, "cooldown_s": 0.0, "once": true, "music_cue": {"telegraph": "riser_industrial", "land": "drop_industrial"}}
 ],
 "home_rows": [
  {"id": "weir_lobbers", "enemy": "lobber", "site": "mesa_rim_road", "landform": "mesa_rim", "advantage": "From the rim road a lobber looks down the flume and the canal, two long held lines inside its 75 m range (lobber.gd:12).", "counter": "Drop off the flume into the canal, or the other way: the shell lands on the line you left (lobber.gd:3-7).", "reinforce": {"from_tier": 1, "every_s": 30.0, "max_alive": 4, "pack": "grounded"}, "break": {"by": "slam", "hp": 80.0, "scrap": 14}, "stops_kind": true, "dormant": false},
  {"id": "trestle_drones", "enemy": "winch_drone", "site": "trestle_hollow", "landform": "arroyo", "advantage": "Drones roost in the trestle bents; a 20 m winch lane along the flume (winch_drone.gd:15) hooks a ball that cannot step off a grind.", "counter": "Hold 19 m/s and the cable snaps on its own (winch_drone.gd:20); a jump snaps it too.", "reinforce": {"from_tier": 1, "every_s": 35.0, "max_alive": 3, "pack": "elite"}, "break": {"by": "damage", "hp": 90.0, "scrap": 16}, "stops_kind": true, "dormant": false},
  {"id": "wasteway_chasers", "enemy": "chaser", "site": "wasteway_chute", "landform": "canal", "advantage": "The wasteway floor is one straight concrete lane, the lane a chaser lunges down.", "counter": "Pump the wasteway walls and come down on them from above the lane.", "reinforce": {"from_tier": 1, "every_s": 25.0, "max_alive": 5, "pack": "run_down"}, "break": {"by": "ram", "hp": 60.0, "scrap": 12}, "stops_kind": true, "dormant": false},
  {"id": "forecourt_brutes", "enemy": "plated_brute", "site": "drum_forecourt", "landform": "penstock", "advantage": "The forecourt is the drum's front door, and a brute's 6 m slam ring (plated_brute.gd:12) covers the doorway every ground line rolls through.", "counter": "Take the forecourt geyser over the ring into the drum, or come off the bluff rim and land on the brute from above.", "reinforce": {"from_tier": 2, "every_s": 40.0, "max_alive": 2, "pack": "elite"}, "break": {"by": "damage", "hp": 140.0, "scrap": 20}, "stops_kind": true, "dormant": false},
  {"id": "dropship_trappers", "enemy": "mag_trapper", "site": "south_bench", "landform": "slickrock", "advantage": "A landed crew pits the bench a light ball crosses to reach the hauler.", "counter": "Grow past the rating, or jump and smash the disc (mag_trapper.gd:6-9).", "reinforce": {"from_tier": 1, "every_s": 35.0, "max_alive": 3, "pack": "grounded"}, "break": {"by": "smash", "hp": 90.0, "scrap": 16}, "stops_kind": true, "dormant": true}
 ],
 "contraption_rows": [
  {"id": "weir_valve", "kind": "valve", "site": "mesa_rim_road", "recipe": "gauge", "at": [-380, -350], "door": {"at": [-372, -332], "size": [12, 6, 1], "turn": 0.6}, "cache": {"at": [-362, -318]}, "codex": "reach_pressure_cache"},
  {"id": "mesa_zip", "kind": "cable", "site": "mesa_rim_road", "recipe": "", "from": [-390, 129, -440], "to": [-290, 78, -245], "radius": 4.0, "floor": 18.0},
  {"id": "hollow_lift", "kind": "lift", "site": "trestle_hollow", "recipe": "lift_platform", "at": [-210, -60], "radius": 4.5, "rise": 30.0, "charge": 3.2, "offset": 0.0},
  {"id": "flume_trebuchet", "kind": "launcher", "site": "canal_country", "recipe": "trebuchet", "style": "trebuchet", "at": [-320, -100], "radius": 3.5, "target": [-230, 100, -50], "floor": 30.0, "min_flight": 3.2, "charge": 4.0},
  {"id": "forecourt_geyser", "kind": "launcher", "site": "drum_forecourt", "recipe": "geyser_vent", "style": "geyser", "at": [140, 400], "radius": 3.5, "target": [225, 52, 470], "floor": 16.0, "min_flight": 2.2, "charge": 3.0},
  {"id": "squall_lane", "kind": "thermal", "site": "bluff_rim", "recipe": "", "at": [120, 260], "radius": 6.0, "height": 50.0},
  {"id": "culvert_wall", "kind": "cracked_wall", "site": "wasteway_chute", "recipe": "", "at": [40, 330], "size": [10, 6, 1.4], "turn": 1.2, "break_at_cruise": true},
  {"id": "bend_zip", "kind": "cable", "site": "bend_overlook", "recipe": "", "from": [50, 72, -170], "to": [120, 62, -40], "radius": 4.0, "floor": 18.0}
 ],
 "weather_rows": [
  {"id": "morning_clear", "kind": "clear", "trigger": {"on": "always"}, "lead_s": 0.0, "live_s": 0.0, "gap_s": 0.0, "fog": {"density": 0.0006, "color": "#b4c6d2"}, "sky": "clear", "sound": "bench_morning_bed", "music_layer": "", "event_odds": {}, "handling": "none"},
  {"id": "dust_squall", "kind": "dust_squall", "trigger": {"on": "clock_tier", "value": 2}, "lead_s": 15.0, "live_s": 60.0, "gap_s": 90.0, "fog": {"density": 0.003, "color": "#c8a878"}, "sky": "dust", "sound": "squall_hiss", "music_layer": "squall_shaker", "event_odds": {"hollow_trestle_collapse": 1.5, "wasteway_flash_flood": 0.5}, "handling": "none"}
 ],
 "activity_rows": [
  {"id": "siphon_camp", "activity": "enemy_camp", "site": "the_siphon", "at": [-28, 176], "pack": ["lobber", "lobber", "lobber"], "pay": {"named": "loose_trigger"}},
  {"id": "bend_cache", "activity": "cracked_cache", "site": "bend_overlook", "at": [150, -80], "pack": [], "pay": {}},
  {"id": "bench_bounty", "activity": "hauler_bounty", "site": "south_bench", "at": [-160, 480], "pack": [], "pay": {}}
 ]
}
```

The draft pilot lines for `tools/park_lines/park_flume.json`:

```json
{
 "map": "park_flume",
 "stage": 2,
 "pilots": {
  "sable": {"waypoints": ["drop_in", [-390, -570], [-280, -560], [-150, -470], [-160, -330], [-280, -230], "butte_gap", [-170, -190], [-230, -50], [-110, 40], [-20, 170], "siphon_camp", [-110, 290], [0, 390], [140, 420], [230, 480], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}},
  "rivet": {"waypoints": ["drop_in", [-500, -550], [-420, -460], [-500, -370], [-390, -280], [-280, -230], "butte_gap", [-320, -100], [-230, 0], [-260, 110], [-140, 150], [-20, 170], "siphon_camp", [80, 260], [0, 360], [130, 420], [230, 480], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}},
  "kest": {"waypoints": ["drop_in", [-390, -570], [-280, -560], [-150, -470], [-160, -330], [-280, -230], "butte_gap", [-110, -250], [50, -170], [110, -30], [40, 100], [-20, 170], "siphon_camp", [140, 200], [290, 300], [300, 420], [230, 480], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}},
  "tarn": {"waypoints": ["drop_in", [-580, -520], [-660, -430], [-540, -420], [-420, -390], [-280, -230], "butte_gap", [-320, -100], [-230, 0], [-260, 110], [-140, 150], [-20, 170], "siphon_camp", [-110, 290], [0, 390], [140, 420], [230, 480], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}},
  "tally": {"waypoints": ["drop_in", [-500, -550], [-420, -460], [-500, -370], [-390, -280], [-280, -230], "butte_gap", [-220, -130], [-300, -20], [-200, 60], [-150, 150], [-20, 170], "siphon_camp", [80, 260], [0, 360], [130, 420], [230, 480], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}},
  "cannon": {"waypoints": ["drop_in", [-500, -550], [-420, -460], [-500, -370], [-390, -280], [-280, -230], "butte_gap", [-110, -250], [50, -170], [110, -30], [40, 100], [-20, 170], "siphon_camp", [140, 200], [290, 300], [300, 420], [230, 480], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}}
 },
 "floor": {"waypoints": ["drop_in", [-500, -550], [-420, -460], [-500, -370], [-390, -280], [-280, -230], "butte_gap", [-320, -100], [-230, 0], [-260, 110], [-140, 150], [-20, 170], "siphon_camp", [80, 260], [0, 360], [130, 420], [230, 480], "landmark"]}
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
