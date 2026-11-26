# World 1, Spillway Works: the journey

Wave 13 journey board for world 1 (2026-10-10; park terrain, reactor mountings, and Brindle have since shipped on `main` under rulings `ep`/`eq`). It strings the two stage pages and the reactor kind sheet into one ride from the first drop to the exit toward the Dig. Historical `artifacts/local/alpha/push/w13/concepts/...` paths below refer to the wave-13 candidate worktree. It adds no mechanic: every rule here is already on a stage page, PARK.md, the kind sheet or code. Where a beat needed something undefined, section 7 says so and names the smallest existing mechanism picked.

**Cite key.** `1-park_dam.md` and `2-park_flume.md` are under `sketches/core-loop/design-v3/park/stages/`. `reactor.md` is `design-v3/wardens/reactor.md`. `PARK.md` and `DESIGN-V3.md` are under `design-v3/`. `flow.gd`, `bay.gd` and `reward_gates.gd` are under `sketches/core-loop/src/` (`core/`, `world/`, `build/`). `BIBLE.md` and `decisions.tsv` (`docs/`) are at the repository root. Pictures are under `artifacts/local/alpha/push/w13/concepts/codex/park/` in the candidate worktree; paths are given in full where a beat uses one.

**Seconds.** The pages give seconds per segment only (waymark to waymark, at a 20 m/s mean, `1-park_dam.md:190`; `2-park_flume.md:188`). A per-beat figure marked "inference" is the length between the floor line's waypoints (`1-park_dam.md:397`; `2-park_flume.md:380`) at that same 20 m/s. The bot's runs replace all of them.

## 1. The journey in one paragraph

You drop in at dawn on a survey deck 1.3 km north of a 120 m dam, with its green beam dead ahead on the skyline (`1-park_dam.md:9`, `416`). Everything you ride falls toward that beam: the shelf at y 150, the plateau at y 100, the canyon floor at y 0 (`1-park_dam.md:13`). You funnel through the Eye, fall 100 m by one of four ways, and meet the reactor relic clamped to the dam face, where the spillway's water sheet is your road up to its core (`1-park_dam.md:9`, `34`). Breaking it opens the gates and Moss's bay, and the launch throws you over the crest toward a weir on a far mesa (`1-park_dam.md:36`, `428`). You land on that weir in the morning still carrying the launch's speed (`flow.gd:21-25`), ride a 1.6 km flume down falling canal country, and meet the same relic again inside the head house at the penstock tower, where it boils the flume into slag lanes (`2-park_flume.md:9`, `36`). The second break is the world's climax. The launch out of the east doors aims at a smoke column and a furnace glow on the horizon: Brindle, then the Dig (`2-park_flume.md:114`; `flow.gd:626-629`, `678-682`).

## 2. The world arc

| Act | Where | What you want | What the world does | Time | Music layer |
| --- | --- | --- | --- | --- | --- |
| 1. The high start | Stage 1 top shelf: deck, domes, domes camp | Speed, and the green beam on the skyline | Rolls you downhill over domes; the camp offers a fight at speed (`1-park_dam.md:110`, `192`) | 22 s, all lines (`1-park_dam.md:196-202`) | Calm keys and pad; reese bass on the first ride fact (`1-park_dam.md:223`) |
| 2. The funnel | Shelf lip, three runs, the Eye | Pick a run, keep the flow | The lip throws you into slots or the wash; all three pinch at the Eye (`1-park_dam.md:9`, `296-298`) | 37 to 38 s (`1-park_dam.md:196-202`) | Full band on `first_drop`; one-bar dip at the Eye (`1-park_dam.md:224-226`) |
| 3. The fall | Four ways down 100 m to the toe apron | The fastest way down to the face | Homes, the dropship and the pool flood press each way; the toe vents erupt a small relic and play the Warden's pedal first (`1-park_dam.md:146-153`) | 23 to 39 s; arrival 84 to 98 s (`1-park_dam.md:196-202`) | B section at the canyon floor; Ab pedal at the vents (`1-park_dam.md:227`, `231`) |
| 4. First meeting: the dam face | Toe apron, the face, the relic 22 m up | Ride the sheet to the core, break it four times | Each pulse opens the gates and pours a 3 s sheet you can ride up (`reactor.md:55-60`) | Skipper band 50 to 90 s (`1-park_dam.md:265`) | Spillway pivot to four on the floor at 129 (`1-park_dam.md:234`) |
| 5. The bay between the stages | Gate row at z 528, Moss's bay at [0, 467], the crest | A part from a gate; optional pit stop | Gates give parts with no collider and no menu (`reward_gates.gd:11-14`); the bay is opt-in and gives your speed back (`bay.gd:11-19`); the launch throws you over the crest (`1-park_dam.md:36`) | 20 s calm after the break (`PARK.md:313`); flight 0.6 s (`flow.gd:23`) | Unseal drop, cadence home; the launch rides the cadence (`1-park_dam.md:237`) |
| 6. The long ride | Stage 2: weir, flume or canals, butte gap, hollow or bend, siphon | Hold the grind, read which line the event leaves open | Lobbers, drones and the flood push you between flume, canal and rim (`2-park_flume.md:161-163`) | 31 to 38 s, then 29 to 37 s (`2-park_flume.md:194-199`) | Slap bass, `trestle_ticks`, `gap_break` (`2-park_flume.md:221-223`) |
| 7. The approach | Wasteway, bluff rim or flume head reach, forecourt | Into the drum at speed | Brutes guard the doorway; the geyser lobs you over them (`2-park_flume.md:164`, `180`) | 26 to 28 s; arrival 87 to 98 s (`2-park_flume.md:194-199`) | Flood riser and drop; `squall_shaker` (`2-park_flume.md:224`, `227`) |
| 8. The climax: the head house | The drum, the relic on the pour channel 12 m up | Stay airborne over the slag, break it, drop the finisher | Each pulse pours a slag lane at you; the core stays open 6 s (`reactor.md:68-70`) | Reach skipper 35 to 80 s, re-measured at KF0 (`2-park_flume.md:263`) | World-1 pivot at 129; Brindle's anvil on the last chunk; the launch rides into Brindle (`2-park_flume.md:229-234`) |

**The inevitable endpoint.** From each drop-in the Warden's landmark is the thing in front of you, and the ground falls toward it. Stage 1: the crest breaks the skyline from every open plateau cell and the beam rises from the relic itself (`1-park_dam.md:30`). Stage 2: the land falls toward the head house from the whole park, so the drop-in looks down onto it (`2-park_flume.md:30`). Both landmarks carry `sight_share` 0.85 (`1-park_dam.md:292`; `2-park_flume.md:281`), which the sight test enforces on a 50 m grid (`PARK.md:478`).

**The pilot rescue.** Rivet's rescue cage stays in world 1, at [60, -594] on stage 1's top shelf, 120 m east of every line (`1-park_dam.md:273`). Rivet unlocks by that rescue (`DESIGN-V3.md:181`). Section 7 has the signposting call.

## 3. The lines

### Stage 1: Spillway: the dam, the line

Dawn, `dawn_still`; the monsoon builds from tier 2 (`1-park_dam.md:184-186`). Tier 1 is 45 s and tier 2 is 90 s on the stage clock (`1-park_dam.md:146-147`). Beats 7, 8 and 9 are the three ways down from the Eye; a run takes one of them.

**1. The survey deck**
- **Where:** slickrock top shelf; `top_shelf_deck`, `canyon_country`, `shelf_rise` (`1-park_dam.md:316-318`).
- **You:** You roll off the 10 m deck at 0.8 of cruise (`flow.gd:26-27`). The drop is your first ride fact, `ride_drop` (`1-park_dam.md:318`).
- **You see:** Due south, the dam crest is a pale bar 1.3 km away with a thin green beam from its middle; domes, two dark slot mouths and the pale wash lie between (`1-park_dam.md:416`). The sun is low on your left (`1-park_dam.md:184`). Amber edge markers point at the three activities (`1-park_dam.md:110`; `DESIGN-V3.md:134`, `140`).
- **Pull:** Gravity and the beam. The deck's plate reads "downhill from here, all of it." (`1-park_dam.md:245`).
- **Pressure:** none.
- **Seconds:** about 6 s of segment 1's 22 s (inference, 127 m).
- **Music:** Calm layer, keys and pad, no drums; the reese bass enters on the first ride fact (`1-park_dam.md:223`).
- **Panel:** existing `/home/andrew/Projects/scrapkeep/.claude/worktrees/scrapkeep-wt-cand-alpha-w13/artifacts/local/alpha/push/w13/concepts/codex/park/park-dam/vista-1.png` (shared with beat 2). Observed: ball on a stone deck pad, domes, the lined wash, slot mouths, the dam with two gate towers and the green beam, the sun at left.

**2. The slickrock domes**
- **Where:** `slickrock_domes`, bank, `ride_hop`, 260 by 240 m at [-110, -520] (`1-park_dam.md:319`).
- **You:** You carve the domes left, right, left (`1-park_dam.md:192`). Or you take the domes cannon, which fires you 117 m over the shelf lip into the corkscrew's head (`1-park_dam.md:173`).
- **You see:** The crest and its two gate towers stay on the skyline (`1-park_dam.md:30`); the domes camp ahead.
- **Pull:** The rollers keep the shelf from going quiet (`1-park_dam.md:120`); the camp is the next waymark.
- **Pressure:** contraption `domes_cannon` at [60, -450] (`1-park_dam.md:368`). `dome_lightning` (tier 3, 3 s `lightning_charge`, 6 m strikes, 8 damage) fires only with veto item 16 (`1-park_dam.md:148`, `153`).
- **Seconds:** about 16 s of segment 1 (inference, 312 m).
- **Music:** Calm layer continues; a stinger on the beat if lightning fires (`1-park_dam.md:229`).
- **Panel:** shared with beat 1, `vista-1.png`.

**3. The domes camp (first waymark)**
- **Where:** activity `domes_camp` at [-51, -396] on `slickrock_domes` (`1-park_dam.md:376`).
- **You:** You pass within 12 m of the camp. Its ring starts only inside 8 m, so you choose the fight at speed (`1-park_dam.md:110`).
- **You see:** Three chasers on the dome; past them the shelf drops away to the lip.
- **Pull:** The lip, and the three run mouths behind it.
- **Pressure:** `enemy_camp`, three chasers, named pay `hot_rivets` (`1-park_dam.md:376`). Since 2026-11-09 (ruling bu) the camp pays a common part rolled from the pool, with no named part (PARK.md 2.12).
- **Seconds:** waymark at 22 s for every line (`1-park_dam.md:196-202`).
- **Music:** Calm layer; a fight lifts layers through `escalate` (`1-park_dam.md:225` names this for the runs; applying it here is inference).
- **Panel:** NEW `j1-p01`, shared with beat 4. 1536x1024. Camera 3 m above slickrock domes 30 m north of a small camp, looking south at dawn, low sun on the left. Foreground: three small chaser crews idle on a pale dome. About 130 m on: a slickrock lip curling up into a kicker. Beyond it, three run mouths cut 25 m into pink plateau: a pale concrete-lined wash on the right, a dark meandering slot ahead, a tighter corkscrew slot on the left. On the skyline, centred, the dam crest as a pale bar with two gate towers and a thin green beam. References: park-dam vista-1.png for palette and the dam, vista-2.png for the rock. No text, no pilot ball, green ancient light only, copper never brass.

**4. The shelf lip**
- **Where:** `shelf_lip`, kicker, 20 by 30 m at [-90, -300] (`1-park_dam.md:320`).
- **You:** You catch the lip and it throws you into one of three runs (`1-park_dam.md:121`).
- **You see:** Mid-air, the three mouths: the lined wash to the right (west), the upper slot ahead, the corkscrew to the left (`1-park_dam.md:321-323`).
- **Pull:** The launch itself; you land in a run.
- **Pressure:** none.
- **Seconds:** about 5 s from the camp (inference, 104 m).
- **Music:** First launch: the full drum-and-bass groove lands on the landing downbeat, cue `first_drop` (`1-park_dam.md:224`).
- **Panel:** shared with beat 3, `j1-p01`.

**5. The three runs**
- **Where:** `west_wash` (arroyo half-pipe), `upper_slot` and `corkscrew_slot` (slot canyons 22 to 26 m deep) (`1-park_dam.md:321-323`).
- **You:** You pump the wash walls, or pump the upper slot's meanders, or recoil-hop and rocket-jump the corkscrew's walls (`1-park_dam.md:210-215`). The corkscrew's bulkhead breaks at cruise into a cut-through (`1-park_dam.md:174`).
- **You see:** Walls 25 m high, a stripe of sky; ahead the run opens into the Eye's arch with daylight and the far canyon framed in it (`1-park_dam.md:418`).
- **Pull:** The daylight in the Eye. All three runs end there (`1-park_dam.md:296-298`).
- **Pressure:** home `culvert_chasers` in the wash: a straight 11 m lunge lane on the floor; pump the wall; tier 1, every 25 s, 5 alive (`1-park_dam.md:161`). `west_wash_flash_flood` at tier 2 (6 s telegraph, 1.6 m for 30 s, closes `west_wash_run`) (`1-park_dam.md:147`). Tier 1 lands while you are in the runs (45 s): the pool flood and the dropship fire out of sight (`1-park_dam.md:146`, `149`).
- **Seconds:** about 33 s of segment 2's 37 to 38 s (inference, 663 m).
- **Music:** The full band; combat lifts through `escalate` (`1-park_dam.md:225`).
- **Panel:** NEW `j1-p02`. 1536x1024. Chase-height camera low in the upper slot canyon at dawn, looking down a meander: smooth banded sandstone walls 25 m high close on both sides, a narrow stripe of pale sky overhead, the outside wall of the bend polished into a banked curve. Ahead, the slot opens into a round arch worn through a sandstone fin; daylight and a far canyon framed in it, with a pale dam bar and a thin green beam centred in the arch. References: park-dam vista-2.png for the arch rock and the dam, vista-1.png for palette. No text, no pilot ball, green ancient light only, copper never brass.

**6. The Eye (waymark)**
- **Where:** `the_eye`, a tunnel hole through a sandstone fin at [0, 150] (`1-park_dam.md:324`).
- **You:** You shoot through the Eye and choose how to fall 100 m (`1-park_dam.md:9`).
- **You see:** South through the arch: the pipeline bridge on the left, the straight incline in the middle, the cliff rooms and the tunnel mouth on the right, and the dam face filling the gap with its beam (observed in vista-2). The carved marks round the Eye glow the face's green (`1-park_dam.md:255`).
- **Pull:** The face, and four visible ways down to it.
- **Pressure:** none.
- **Seconds:** waymark at about 60 s (22 s plus 37 to 38 s, `1-park_dam.md:196-202`).
- **Music:** A one-bar low-pass dip inside the tunnel, opening on the far side, cue `eye_filter` (`1-park_dam.md:226`).
- **Panel:** existing `/home/andrew/Projects/scrapkeep/.claude/worktrees/scrapkeep-wt-cand-alpha-w13/artifacts/local/alpha/push/w13/concepts/codex/park/park-dam/vista-2.png` (shared with beat 7). Observed: the arch frames the bridge left, incline centre, rooms and tunnel mouth right, dam and beam behind.

**7. West: the tunnel or the ledges (one of three ways down)**
- **Where:** `west_rim_bench`, `spillway_tunnel`, `outlet_bucket`, `cliff_rooms_west`, `viga_span`, `service_ledge` (`1-park_dam.md:325-330`).
- **You:** You bank the overflow channel on the rim. Then you drop the 100 m tunnel and the flip bucket throws you over the brutes' ring (`1-park_dam.md:126-127`, `164`). Or you claw-pull onto the cliff-room ledges, swing the viga span and slam the lobbers off the service ledge (`1-park_dam.md:213`).
- **You see:** The rim cache's amber marker on the bench at [-200, 215] (`1-park_dam.md:377`); below, the plunge pool and the face.
- **Pull:** The tunnel's drop, or the viga span: a world line to swing, the stage's first harpoon read (`1-park_dam.md:329`).
- **Pressure:** home `outlet_brutes` (6 m slam ring over the one landing spot; take the bucket over it; tier 2, 45 s, 2 alive) (`1-park_dam.md:164`). Home `ledge_lobbers` (75 m range from 24 m up; change line under the shell; tier 1, 30 s, 4 alive) (`1-park_dam.md:162`). Contraptions `service_lift` (24 m) and `gallery_valve` (`1-park_dam.md:175-176`).
- **Seconds:** segment 3, Sable 35 s, Tarn 30 s (`1-park_dam.md:196`, `199`).
- **Music:** Full band; `drop_flood` on the landing if the pool flood is live (`1-park_dam.md:228`).
- **Panel:** shared with beat 6, `vista-2.png`.

**8. The floor line: the incline (one of three ways down)**
- **Where:** `construction_incline`, `river_canyon`, `tailwater_bar` (`1-park_dam.md:331-333`).
- **You:** You take the incline's 94 m drop straight down the canyon wall and roll the tailwater bar onto the toe apron with the descent's speed. No harpoon, no contraption (`1-park_dam.md:192`).
- **You see:** The dam fills the frame, 120 m of curved concrete, the relic a squat green-seamed drum 22 m up, the powerhouse steaming (`1-park_dam.md:424`).
- **Pull:** The drop, and the relic dead ahead.
- **Pressure:** none on the route (`1-park_dam.md:192`).
- **Seconds:** segment 3, 23 s for Rivet and the floor line (`1-park_dam.md:197`, `202`): the incline about 11 s and the bar about 7 s (inference).
- **Music:** The B section lands as the ball first reaches y 10 or lower, cue `canyon_floor` (`1-park_dam.md:227`).
- **Panel:** NEW `j1-p03`. 1536x1024. Camera falling down a straight concrete construction incline cut into a red canyon wall, looking south toward the dam toe at dawn; the canyon floor still in shadow. The dam fills the upper two thirds: a curved pale concrete arch 120 m tall, two gate towers on the crest, a squat ribbed drum with three rod stacks clamped to the face centreline a fifth of the way up, its seams glowing green, a green beam rising past the crest. A powerhouse steams at the left foot, a round plunge pool at the right. References: park-dam vista-3.png for the dam, vista-2.png for the incline. No text, no pilot ball, green ancient light only, copper never brass.

**9. East: the bridge and the bench (one of three ways down)**
- **Where:** `pipeline_bridge` at y 100, `east_bench_flats`, `canal_lips`, `east_haul_road`, `east_abutment`, `crest_rail` (`1-park_dam.md:335-344`).
- **You:** You grind the bridge across the east gorge, cross the bench, grind the canal lips and drop the haul road, or ride the 175 m rim zip to the toe (`1-park_dam.md:177`, `211-212`). The Cannon takes the crest trebuchet onto the crest rail (`1-park_dam.md:178`, `215`).
- **You see:** A Fleet dropship on the bench, landed at tier 1, and the bench altar's amber marker at [330, 420] (`1-park_dam.md:149`, `378`).
- **Pull:** The dropship's crew home, and the zip's line to the toe.
- **Pressure:** event `east_bench_dropship` (tier 1, 10 s `fleet_inbound`, wakes `dropship_winches`, opens `dropship_ramp`) (`1-park_dam.md:149`). Home `dropship_winches`: hold 19 m/s across the bench or jump and the cable snaps (`1-park_dam.md:165`; `decisions.tsv:119`).
- **Seconds:** segment 3, Kest 34 s, Cannon 39 s (`1-park_dam.md:198`, `201`).
- **Music:** Brindle's anvil and brass, one layer, for the dropship (`1-park_dam.md:230`): the world boss's first hint.
- **Panel:** NEW `j1-p04`. 1536x1024. Camera on a steel pipeline bridge at plateau height, looking south-east across a 70 m side gorge onto flat slickrock bench at dawn. On the bench a grey Fleet dropship sits on its landing struts, ramp down, three winch drones lifting off it with dangling cables. A dam-era concrete canal lip runs along the bench toward a switchback haul road falling to the right. At the right edge, the curved dam face in shade with its green-seamed drum and beam. References: park-dam vista-2.png for the bridge and vista-3.png for the dam and haul road. No text, no pilot ball, green ancient light only, copper never brass.

**10. The toe apron: the vents wake**
- **Where:** `toe_apron`, `plunge_pool`, `toe_vent_pits`, `powerhouse` (`1-park_dam.md:340-343`).
- **You:** You land on the apron carrying your speed. Tally pumps the pool bowl twice and surges out (`1-park_dam.md:214`).
- **You see:** The face and the relic straight ahead. East of the apron and short of the face, a vent pit stirs (`toe_vent_pits` at [140, 440], `1-park_dam.md:343`), then a small relic erupts from it (`1-park_dam.md:150`). If the pool flood is live, the coping is lit in the flood colour and the ball rides the rim line (`1-park_dam.md:422`).
- **Pull:** The vent's 8 s `ancient_stirring` plays the Warden's sound for the first time, small; then the engage ring at [0, 575] (`1-park_dam.md:153`, `231`).
- **Pressure:** `toe_vents_wake` (tier 2, 8 s telegraph, a `reactor_relic` miniboss, no route change) (`1-park_dam.md:150`). `plunge_pool_flood` (tier 1, 6 s `flood_rising`, 35 s of water, closes `pool_floor`, opens `pool_rim`) (`1-park_dam.md:146`). Home `powerhouse_trappers` (jump the disc or grow past it; tier 2, 35 s, 3 alive) (`1-park_dam.md:163`). Contraptions `pool_geyser`, `spray_thermal` (`1-park_dam.md:179-180`).
- **Seconds:** arrival 84 to 98 s; tier 2 at 90 s lands on it (`1-park_dam.md:153`, `196-202`).
- **Music:** The reactor's Ab pedal under the band, the Geiger tick speeding toward the eruption (`1-park_dam.md:231`).
- **Panel:** NEW `j1-p05`. 1536x1024. Camera low on dry canyon floor north of a curved dam at dawn, looking south, low sun on the left. Foreground: a shallow vent pit beside the apron with a cast green-seamed plate, cracking open; a small ribbed drum with three stubby rod stacks bursting up through it in a ring of steam, seams blazing green. Just behind it, a steaming powerhouse. Across the back, the curved dam face rising out of frame, its larger green-seamed relic clamped low on the face right of centre, a flat concrete apron at its foot. References: park-dam vista-3.png for the dam and powerhouse, warden-reactor warden-3.png for the relic body. No text, no pilot ball, green ancient light only, copper never brass.

### Between the stages: the dam fight, the gates and the bay

The dam fight is section 4.1. After its break:

- **The gates.** The plate says "Roll through a gate" (`DESIGN-V3.md:138`). Three reward gates stand on the apron at z 528, facing the face (`1-park_dam.md:36`). A gate takes a part as you roll through it, with no collider and no menu, so choosing never costs speed (`reward_gates.gd:11-14`). No new event starts within 20 s of the break (`PARK.md:313`).
- **The bay.** Moss's bay docks at [0, 467], 61 m behind the gates and 46 m up (`1-park_dam.md:36`). It is opt-in: a steam cradle beside the gate row banks your speed and throws you onto the deck, and the bow pad throws you back in front of a gate with that speed returned (`bay.gd:11-19`). Aboard: Moss's shutter and hatch, a practice yard where abilities cost no cooldown, a bell, a jukebox and a timed lap round the rim (`bay.gd:25-28`). Section 7 calls the bay the zone's workshop intermission.
- **The launch.** The launch throws you up the face and over the crest into the reservoir country that feeds stage 2's weir (`1-park_dam.md:36`). Frame 7 shows the reservoir and a far mesa with a weir on it in the haze (`1-park_dam.md:428`). After 0.6 s of flight the next stage takes the ball with its velocity, entering 14 m above so the launch lands rather than appears (`flow.gd:21-25`).
- **Panel:** NEW `j1-p07` (section 4.1, exit).

### Stage 2: Spillway: the flume, the line

Morning, `morning_clear`; the dust squall from tier 2 (`2-park_flume.md:182-184`). Tier 1 is 45 s and tier 2 is 90 s (`2-park_flume.md:145-146`). Beats 5, 6 and 7 are the three middle ways; beats 9 and 10 are the two last ways in.

**1. Landing on the weir**
- **Where:** `weir_deck` on the 40 m `weir_mesa`, `canal_country` (`2-park_flume.md:300-302`).
- **You:** You come down onto the deck from above, still carrying the crest launch's speed (`flow.gd:21-25`). The drop is `ride_drop` (`2-park_flume.md:302`).
- **You see:** South-east down a long fall of canal country: the flume leaves the weir at your feet in a long S, two buttes stand at the first bend, and 1.3 km away and below you a slim tower with a green beam stands beside a round head house on a bluff (`2-park_flume.md:399`).
- **Pull:** The ground falls 112 m toward the head house (`2-park_flume.md:13`, `30`), and water runs that way in the flume.
- **Pressure:** none.
- **Seconds:** segment 1 is 31 to 38 s (`2-park_flume.md:194-199`); deck and ramp about 5 s (inference, 108 m).
- **Music:** The calm layer over the weir's water hiss (`2-park_flume.md:221`).
- **Panel:** existing `/home/andrew/Projects/scrapkeep/.claude/worktrees/scrapkeep-wt-cand-alpha-w13/artifacts/local/alpha/push/w13/concepts/codex/park/park-flume/vista-1.png` (shared with beats 2 and 6). Observed: weir water at left, ball on slickrock, the S flume, two buttes, canal fields at right, the tower with its beam at upper right.

**2. The weir chute or the mesa ramp**
- **Where:** `weir_chute`, `flume_weir_reach` at y 136, `mesa_ramp` (`2-park_flume.md:303-304`, `308`).
- **You:** You pump the weir chute and vault off its wall onto the flume (`2-park_flume.md:208`), or you drop the 40 m mesa ramp into the canal fields (`2-park_flume.md:285`, `308`).
- **You see:** The timber channel ahead on trestles, canal lines in tan fields below, the tower on the far skyline.
- **Pull:** The grind ahead, or the drop into the canal.
- **Pressure:** none.
- **Seconds:** within segment 1.
- **Music:** The slap bass enters at the first grind or the first canal; on the flume each trestle bent ticks a hat accent, cue `trestle_ticks` (`2-park_flume.md:221-222`).
- **Panel:** shared with beat 1, `vista-1.png`.

**3. The upper reaches and the crew camp**
- **Where:** `flume_gap_reach` (y 120), `main_canal`, `crew_ledges`, `crane_booms`, `mesa_rim_road` (`2-park_flume.md:305`, `309`, `314-316`).
- **You:** You slingshot off trestle bents on the flume, or sprint the main canal's straights, or claw-pull bunk ledge to bunk ledge and swing the crane booms (`2-park_flume.md:208-211`). The 225 m mesa zip runs down to the gap (`2-park_flume.md:174`).
- **You see:** The butte gap opening ahead with the canal glinting through it (`2-park_flume.md:401`).
- **Pull:** The lobbers' shells land on the line you left, so you switch lines toward the gap (`2-park_flume.md:161`).
- **Pressure:** home `weir_lobbers` on the rim road (tier 1, 30 s, 4 alive) (`2-park_flume.md:161`). Contraption `weir_valve` opens a cache pocket (`2-park_flume.md:173`).
- **Seconds:** rest of segment 1, about 25 s on the canal (inference, 503 m).
- **Music:** The held groove with `trestle_ticks` (`2-park_flume.md:222`).
- **Panel:** NEW `j2-p01`, shared with beat 4. 1536x1024. Camera beside a timber flume 45 m above the ground in clear morning light, looking along its water channel as it runs away on tall trestle bents. Ahead, two red buttes stand either side of a gap; a canal glints through the gap below. Tan fields cut by green canal lines fall away to the right, long trestle shadows lying west across them. Far off at the right, past the fields, a slim concrete tower with a green beam beside a round head house on a bluff. References: park-flume vista-1.png for the flume, buttes and tower. No text, no pilot ball, green ancient light only, copper never brass.

**4. The butte gap (first waymark)**
- **Where:** `butte_gap`, `west_butte`, `east_butte` (`2-park_flume.md:310-312`).
- **You:** You thread the 80 m gap. The buttes are harpoon anchors (`2-park_flume.md:128`); Kest rocket-jumps off the flume here onto the rim road (`2-park_flume.md:210`).
- **You see:** The flume and the canal pinch together between the buttes. Facing down the gap (yaw 30, south-south-east, `2-park_flume.md:310`), the mouths read by side. Ahead: the hollow's tallest trestles and the flume's hollow reach striding on them (`2-park_flume.md:72`, `306`, `317`). On the right: the lateral canal turning into the tan fields; the floor line's first point past the gap, [-320, -100], lies south-south-west (`2-park_flume.md:313`, `380`). On the left: the rim road, a dam-era terrace running east toward the bend (`2-park_flume.md:321`). Sides are inference from the row positions.
- **Pull:** The pinch, then a choice by side: trestles ahead, fields right, rim road left.
- **Pressure:** none.
- **Seconds:** waymark at 31 to 38 s (`2-park_flume.md:194-199`).
- **Music:** A one-bar break as the lines pinch, the groove back on the far side, cue `gap_break` (`2-park_flume.md:223`).
- **Panel:** shared with beat 3, `j2-p01`.

**5. The trestle hollow (one of three middle ways)**
- **Where:** `trestle_hollow`, arroyo half-pipe; `flume_hollow_reach` at y 96 (`2-park_flume.md:306`, `317`).
- **You:** You pump the hollow's walls under the 49 m trestles, or hold the grind on the hollow reach. The hollow lift raises you 30 m to the catwalk, inside harpoon range of the flume (`2-park_flume.md:176`).
- **You see:** Winch drones roosting in the bents; the head house and tower on the far bluff (observed in vista-2).
- **Pull:** The hollow itself: the arroyo runs on under the flume to the siphon, where the canal dives under the hollow (`hollow_run`, `2-park_flume.md:11`, `289`). The span's groan joins it only if call 5 is accepted; at tier 2 (90 s) it fires after a straight run has passed (`2-park_flume.md:145`, `194-199`).
- **Pressure:** home `trestle_drones`: a 20 m winch lane hooks a ball on the grind; hold 19 m/s or jump and the cable snaps; tier 1, 35 s, 3 alive (`2-park_flume.md:162`). Event `hollow_trestle_collapse`: 6 s `trestle_groan`, the span falls into a ramp only when the ball is 20 m clear, closes `flume_mid`, opens `trestle_ramp_line` (`2-park_flume.md:145`, `151`).
- **Seconds:** segment 2, 29 to 37 s (`2-park_flume.md:194-199`).
- **Music:** Stage-band riser on the groan, the drop on the landing (`2-park_flume.md:224`).
- **Panel:** existing `/home/andrew/Projects/scrapkeep/.claude/worktrees/scrapkeep-wt-cand-alpha-w13/artifacts/local/alpha/push/w13/concepts/codex/park/park-flume/vista-2.png`. Observed: tall trestles, drones with dangling winches, a sagging span with falling dust, the half-pipe wash, the head house and beam at upper right.

**6. The lateral canal (one of three middle ways)**
- **Where:** `lateral_canal` through the fields (`2-park_flume.md:313`).
- **You:** You roll the lateral canal through the fields: the floor line, no harpoon, no contraption (`2-park_flume.md:190`). The flume trebuchet throws you up onto the hollow reach if you want the grind back (`2-park_flume.md:175`).
- **You see:** Tan fields, green canal lines, the trestles' long shadows falling west (`2-park_flume.md:182`).
- **Pull:** The canal's own fall carries you to the siphon.
- **Pressure:** none; canal rows hold no home and no event (`2-park_flume.md:26`).
- **Seconds:** about 32 s, all of segment 2 (inference, 633 m).
- **Music:** The held groove.
- **Panel:** shared with beat 1, `vista-1.png` (the canal fields at right).

**7. The rim road and the horseshoe bend (one of three middle ways)**
- **Where:** `rim_road`, `bend_overlook`, `horseshoe_gorge` 95 m deep (`2-park_flume.md:321-323`).
- **You:** You glide the bend from the overlook, or recoil-hop the gorge corner, then ride the 150 m bend zip (`2-park_flume.md:177`, `210`, `213`).
- **You see:** Past the lower gorge, a smoke column and a furnace glow on the eastern horizon: Brindle (`2-park_flume.md:114`). The bend cache's amber marker at [150, -80] (`2-park_flume.md:360`).
- **Pull:** Into the bend: the zip, which runs south-east down the rim to the overlook (`2-park_flume.md:352`). Out of the bend toward the siphon: pull missing, back to stage 2 page (`rim_mid` return; section 7, gap 6). The smoke is east and the tower beam south-south-east, both away from the siphon at [-20, 170], which lies about 250 m south-south-west of the zip's foot at [120, -40] (`2-park_flume.md:114`, `281`, `318`, `352`). Smallest existing candidate (inference from positions): on the right, the flume's hollow reach on its tallest trestles, which ends at the siphon (`flume_mid`, `2-park_flume.md:72`, `287`, `306`); Kest's line follows it back down through [40, 100] (`2-park_flume.md:375`).
- **Pressure:** `bend_relic_wakes` (tier 2, 8 s `ancient_stirring`, a `reactor_relic` miniboss, no route change) (`2-park_flume.md:148`).
- **Seconds:** segment 2, Kest and Cannon 37 s (`2-park_flume.md:196`, `199`).
- **Music:** The Ab pedal and the Geiger tick at the wake (`2-park_flume.md:226`).
- **Panel:** NEW `j2-p02`. 1536x1024. Camera on a red rim road at a horseshoe bend overlook in clear morning light, looking east over the bend: a river loops round a rock tongue 95 m below. A steel zip cable runs along the rim from the foreground. On the far eastern horizon, beyond a second gorge, a dark smoke column with an orange furnace glow at its foot; to the right, small and far, the slim green-beamed tower by its round head house. References: park-flume vista-3.png for the smoke and the head house, vista-1.png for palette. No text, no pilot ball, green ancient light only, copper never brass.

**8. The siphon (second waymark)**
- **Where:** `the_siphon`, a canal drop under the hollow; activity `siphon_camp` at [-28, 176] (`2-park_flume.md:318`, `359`).
- **You:** You drop through the siphon, `ride_drop` (`2-park_flume.md:318`). Every middle way ends here (`2-park_flume.md:287-291`).
- **You see:** The siphon's plate: "Inverted siphon: the water goes down, under, and up again. So will you." (`2-park_flume.md:243`); the camp's lobbers on its lip.
- **Pull:** Three last ways in, each visible from the lip. The concrete wasteway opening on the far side (beat 9). Overhead, the flume's last reach running on to enter the head house's north wall (`2-park_flume.md:307`, `407`); Tarn claws up onto it here (`2-park_flume.md:211`). On the left, the squall lane's visible wind lane on the bluff rim, about 165 m south-east at [120, 260] (`2-park_flume.md:178`, `350`), the way onto the bluff (beat 10).
- **Pressure:** `enemy_camp`, three lobbers, named pay `loose_trigger` (`2-park_flume.md:112`, `359`). Since 2026-11-09 (ruling bu) the camp pays a common part rolled from the pool, with no named part (PARK.md 2.12).
- **Seconds:** waymark at about 60 to 75 s (segments 1 and 2, `2-park_flume.md:194-199`).
- **Music:** A low-pass dip under the hollow, open on the far side (`2-park_flume.md:228`).
- **Panel:** NEW `j2-p03`. 1536x1024. Camera at the lip of an inverted canal siphon in morning light, looking down-slope: a dam-era concrete mouth where a canal dives under, its far outlet visible 40 m on, rising out into a wide concrete wasteway chute. Three lobber crews stand on the near lip beside stencilled gauge plates. Overhead, timber trestles stride across the hollow behind. On the skyline ahead, the round head house on its bluff with the green-beamed tower beside it. References: park-flume vista-2.png for the trestles, vista-3.png for the head house. No text, no pilot ball, green ancient light only, copper never brass.

**9. The wasteway chute (one of two last ways in)**
- **Where:** `wasteway_chute`, concrete half-pipe (`2-park_flume.md:319`).
- **You:** You pump the wasteway's walls. The culvert wall breaks at cruise into a shortcut (`2-park_flume.md:179`).
- **You see:** The round head house filling the frame, the tower behind, the flume's last reach entering its north wall (`2-park_flume.md:407`).
- **Pull:** The flood closes `canal_lower` and opens `wasteway_wall`, so the water lifts you onto the wall line toward the forecourt (`2-park_flume.md:146`).
- **Pressure:** `wasteway_flash_flood` (tier 1, 5 s `flood_rising`, 30 s of water) (`2-park_flume.md:146`); it fires at 45 s, so it is likely live as lines arrive here (inference). Home `wasteway_chasers`: pump the walls and come down on them from above the lane; tier 1, 25 s, 5 alive (`2-park_flume.md:163`).
- **Seconds:** segment 3, 26 to 28 s (`2-park_flume.md:194-199`); the wasteway about 13 s (inference, 263 m).
- **Music:** Riser over the lead, the drop on the landing (`2-park_flume.md:224`).
- **Panel:** NEW `j2-p04`, shared with beat 11. 1536x1024. Camera low at the top of a concrete wasteway chute in morning light, looking up-slope toward a bluff. A round concrete head house 70 m across fills the upper frame, open steel roof trusses on top; a timber flume enters its north wall on trestles; a slim surge tower with a green beam rises behind it. On the paved forecourt before its doorway, two plated brutes walk, one slamming a dust ring across the doorway. References: park-flume vista-3.png for the head house, flume and tower. No text, no pilot ball, green ancient light only, copper never brass.

**10. The flume head reach or the bluff rim (one of two last ways in)**
- **Where:** `flume_head_reach` at y 62, `bluff_rim`, `squall_lane` (`2-park_flume.md:307`, `325`, `350`).
- **You:** You grind the flume's last reach straight into the drum through its north wall (`2-park_flume.md:292`). Or you glide the squall lane's updraft onto the bluff (`2-park_flume.md:210`) and come in from the east (`2-park_flume.md:213`).
- **You see:** The head house, the penstocks falling 95 m to the lower gorge, the smoke on the east horizon (`2-park_flume.md:30`, `114`).
- **Pull:** The flume pours into the drum, and you ride the water in.
- **Pressure:** weather `dust_squall` (tier 2, 15 s warning, 60 s live) (`2-park_flume.md:184`); the squall lane is its only push (`2-park_flume.md:178`).
- **Seconds:** segment 3, 28 s for Sable, Kest and the Cannon (`2-park_flume.md:194`, `196`, `199`).
- **Music:** `squall_shaker` while the squall is live (`2-park_flume.md:227`).
- **Panel:** existing `/home/andrew/Projects/scrapkeep/.claude/worktrees/scrapkeep-wt-cand-alpha-w13/artifacts/local/alpha/push/w13/concepts/codex/park/park-flume/vista-3.png`. Observed: the forecourt road curving to the head house, the flume entering its wall, penstocks down the bluff, the tower and beam, smoke and furnace glow on the far horizon.

**11. The forecourt**
- **Where:** `drum_forecourt`, `heat_exchanger_annex` (`2-park_flume.md:326`, `328`).
- **You:** You roll the forecourt to the doorway, or take the forecourt geyser over the brute ring onto the relic's channel, or land on a brute from the bluff rim (`2-park_flume.md:164`, `180`).
- **You see:** The drum's doors: the forecourt on the north-west, the annex on the south-west, the gate doors on the east (`2-park_flume.md:32`). A slam ring dusting the doorway (`2-park_flume.md:407`).
- **Pull:** The doorway, and the geyser's lob onto the channel.
- **Pressure:** home `forecourt_brutes`: a 6 m slam ring covers the doorway every ground line rolls through; tier 2, 40 s, 2 alive (`2-park_flume.md:164`). Contraption `forecourt_geyser` (`2-park_flume.md:349`).
- **Seconds:** about 7 s on the forecourt, then 6 s into the drum (inference); arrival 87 to 98 s (`2-park_flume.md:194-199`).
- **Music:** not stated on the page; section 7 calls the landmark hum.
- **Panel:** shared with beat 9, `j2-p04`.

## 4. The Warden: the reactor relic, the climax

The reactor relic is a squat ribbed drum about 9 m across with three rod stacks and a caged core dome; only its seams glow, uranium-glass green #9dff3c (`reactor.md:20-22`). It never moves; its mounting turns the pulse into terrain (`reactor.md:34`). World 1 meets it twice: first on the dam face, where it teaches the fight, then in the head house, the world's climax.

**Where the mounting first reads.**

- Dam face: the beam from the drop-in (`1-park_dam.md:416`); the face and beam through the Eye (vista-2); the relic itself from the incline, 22 m up the face (`1-park_dam.md:424`).
- Head house: the tower and beam from the weir deck (`2-park_flume.md:399`); the head house from the hollow and the siphon (vista-2, `j2-p03`); the flume entering its wall from the wasteway (`2-park_flume.md:407`).
- The hardpoints are rimmed in the ancients' green and bite from 45 m (`PARK.md:418`). On the dam they are the two gate piers and the crown; in the head house the pour channel's two cheeks and the crown (`reactor.md:78`).

**Where each anchor behaviour is taught before you need it.**

| Behaviour | Taught on the line | First used on a Warden | Tested in the climax |
| --- | --- | --- | --- |
| Latch, ride | Stage 1: the viga span, a world swing line (`1-park_dam.md:329`). Stage 2: the butte anchors and the crane booms (`2-park_flume.md:311-312`, `315`) | Dam: a gate pier, a pendulum over the apron (`reactor.md:78-79`) | Orbit round the relic under the trusses (`reactor.md:79`) |
| Fire from the line | Stage 1: hang from the viga span at [-135, 430], about 66 m from the service-ledge lobbers inside their 75 m range, and shoot them (`1-park_dam.md:162`, `329-330`). Stage 2: hang from the west butte, about 60 m from the weir lobbers on the rim road (`2-park_flume.md:161`, `311`, `316`). That the weapon slot fires on a world line is inference from "as today" (`PARK.md:420`) | Dam: hang from a pier, shoot during the charge (`reactor.md:80`) | Hang over the drum while the lanes burn (`reactor.md:80`) |
| Shrug | Warden-only by definition: only a Warden's lined hardpoint flares and drops the line (`PARK.md:422`). The dam fight is its teaching beat | Dam: the throw arcs you up the face (`reactor.md:84`) | The throw lifts you over a fresh lane (`reactor.md:84`) |
| Drag | World 2 by design: the relic never moves (`reactor.md:81`); drag needs a moving mounting (`PARK.md:421`) | none | none; drag arrives in world 2 (`PARK.md:421`, `430`) |

Latch and ride are met on the line before the dam, but only on harpoon lines; fire from the line is met on the line only at the two spots above, both off the floor line. The floor line meets latch, ride and fire at the dam's piers, and the shrug is met there by every line. So the dam fight is the teaching beat for all three, and the head house is the test (call 6).

### 4.1 First meeting: the dam face (stage 1's end)

**D1. Into the ring**
- **Where:** `toe_apron`; the engage ring at [0, 575], `reach_m` 30 (`1-park_dam.md:32`).
- **You:** You roll into the ring. The plate says "Ride the water sheet up" (`src/core/objectives.gd` `ride_sheet`; "Break its guard" before 9 Nov 2026).
- **You see:** While you are inside the ring it charges 2 s every 6 s, showing the reach ring and a 6 m core ring (`reactor.md:40`); the gates glow and the stacks rise 0.6 m (`reactor.md:60`, `95`).
- **Pull:** The charge: the next pulse opens the road.
- **Pressure:** the pulse adds 10 damage inside the 6 m core ring (`reactor.md:41`).
- **Seconds:** a 6 s cycle: 2 s charge, the pulse, 3 s of sheet, 1 s dry (`reactor.md:60`).
- **Music:** The Spillway pivot: half-note triplets, then four on the floor at 129 (`1-park_dam.md:234`). A white-noise swell rises under each charge (`reactor.md:110`).
- **Panel:** existing `/home/andrew/Projects/scrapkeep/.claude/worktrees/scrapkeep-wt-cand-alpha-w13/artifacts/local/alpha/push/w13/concepts/codex/park/warden-reactor/warden-1.png`. Observed: low shot from the wet apron, the relic high on the curved face, gates open, water in two streams round the relic, not one 24 m sheet.

**D2. Ride the sheet**
- **Where:** the face, a quarter pipe from flat at z 560 to vertical about 30 m up (`1-park_dam.md:32`).
- **You:** On the pulse the gates open and a 24 m sheet runs down the face for 3 s. You enter it from the apron moving toward the face and ride up to core height with your planar speed kept (`reactor.md:55-57`).
- **You see:** A white sheet centred on the relic; the core above its top. Green-rimmed hardpoints on both gate piers, 45 m bite (`reactor.md:78`; `PARK.md:418`).
- **Pull:** The sheet is the road; a grown ball rams the core on it (`reactor.md:60`). The piers: a line across the sheet's foot (`reactor.md:79`).
- **Pressure:** none; missing the sheet costs nothing (`reactor.md:58`).
- **Seconds:** the sheet lives 3 s (`reactor.md:60`).
- **Music:** The pulse lands on the beat and the pedal stops as the vent blows (`reactor.md:106`).
- **Panel:** NEW `j1-p06`. 1536x1024. Camera low on a flat concrete toe apron at dawn, looking up a curved dam face that bends from flat to vertical. Two spillway gates high on the face are open; one smooth white water sheet 24 m wide runs down the face, centred on a squat ribbed drum clamped to the centreline 22 m up, its three rod stacks dropping, a ring of steam at its foot, seams green. The sheet's foot spreads across the apron toward the camera. Green-rimmed round hardpoints on both gate piers. References: warden-reactor warden-1.png and warden-4.png for the relic and piers. No text, no pilot ball, green ancient light only, copper never brass.

**D3. Latch a pier and fire**
- **Where:** a gate pier hardpoint, 45 m rope range (`reactor.md:78`; `PARK.md:418`).
- **You:** You latch a pier and swing a pendulum across the sheet's foot (`reactor.md:79`). Hanging, you fire: each bolt adds 1.5 posture, 3 during the charge (`reactor.md:42`, `80`).
- **You see:** The taut line to the green-rimmed pier; the seams ramping toward full on the charge (`reactor.md:95`).
- **Pull:** Posture climbs fastest during the charge.
- **Pressure:** posture drains 12 a second after 3 s without gain (`reactor.md:42`).
- **Seconds:** one charge is 2 s of every 6 s (`reactor.md:40`).
- **Music:** The Ab pedal under each 2 s charge (`1-park_dam.md:235`).
- **Panel:** existing `/home/andrew/Projects/scrapkeep/.claude/worktrees/scrapkeep-wt-cand-alpha-w13/artifacts/local/alpha/push/w13/concepts/codex/park/warden-reactor/warden-4.png` (shared with D4). Observed: a pier hardpoint ringed in green, a taut cable to the hanging ball, an orange bolt toward the relic; it shows the ball, the one existing exception to the no-ball rule.

**D4. The shrug**
- **Where:** the lined pier hardpoint.
- **You:** The lined hardpoint flares for the 2 s charge and drops your line on the pulse. You keep your swing velocity plus 10 m/s up, an arc up the face (`reactor.md:82`, `84`).
- **You see:** The flared hardpoint kicks outward, its flare the gates' glow (`reactor.md:82`, `99`).
- **Pull:** The throw: it is a ride, so it never stops the ball (`reactor.md:84`).
- **Pressure:** once per pulse cycle (`reactor.md:82`).
- **Seconds:** `shrug` clip 0.4 s (`reactor.md:99`).
- **Music:** The charge's pedal and tick.
- **Panel:** shared with D3, `warden-4.png`.

**D5. The stagger and the break**
- **Where:** the relic; `powerhouse` for the boiler (`1-park_dam.md:151`).
- **You:** At posture 100 it staggers for 4 s and the core opens; the pulse pauses (`reactor.md:43`). At speed tier 2 or better you shatter one of four chunks (`reactor.md:44`). The pool geyser lobs you onto the face 10 m above the relic; the spray thermal lifts you 60 m (`1-park_dam.md:179-180`).
- **You see:** Jaws lean open 14 degrees, the cage splits, the core blazes; a quarter of the jacket falls away (`reactor.md:97-98`).
- **Pull:** The open core, and height above it.
- **Pressure:** `powerhouse_boiler` at the second chunk: 5 s `boiler_pressure`, a 24 by 10 m steam cone, 6 damage, 8 s; the roof becomes a ramp, closes `powerhouse_floor`, opens `roof_ramp_line` (`1-park_dam.md:151`).
- **Seconds:** the stagger lasts 4 s (`reactor.md:43`).
- **Music:** The half-step lift at half broken, the sinister break at three quarters (`1-park_dam.md:236`); a steam whistle into a percussion hit at the boiler (`1-park_dam.md:232`).
- **Panel:** existing `/home/andrew/Projects/scrapkeep/.claude/worktrees/scrapkeep-wt-cand-alpha-w13/artifacts/local/alpha/push/w13/concepts/codex/park/warden-reactor/warden-3.png` (shared with D6, H6). Observed: jaw plates open, split cage, blazing core, one quarter of the jacket fallen as slabs.

**D6. The drop finisher, then the exit**
- **Where:** above the open core, then the gate row at z 528 (`1-park_dam.md:36`).
- **You:** Every hardpoint holds during the stagger. You release above the open core and haul: the drop finisher (`reactor.md:86`; `PARK.md:414`). The Cannon's line meets it from above off the crest (`1-park_dam.md:215`).
- **You see:** Seams going dark one by one (`reactor.md:102`); then three gates on the apron and Moss's bay hovering behind them.
- **Pull:** The plate's "Roll through a gate" (`DESIGN-V3.md:138`), then the launch up the face and over the crest (`1-park_dam.md:36`).
- **Pressure:** none for 20 s after the break (`PARK.md:313`).
- **Seconds:** the stage's skipper band is 50 to 90 s at the break, re-measured at KF2 (`1-park_dam.md:265`).
- **Music:** `final_quiet`: the Ab pedal stops on the last seam (`reactor.md:102`). The unseal drop and the cadence home; the launch rides the cadence (`1-park_dam.md:237`).
- **Panel:** NEW `j1-p07`. 1536x1024. Camera above crest height over the canyon, north of a hovering barge, looking south at early morning. Foreground below: the barge with a workshop deck and a steam cradle, hanging 46 m up. Beyond it on a flat apron, three reward gate arches in a row facing the dam. Behind them the curved dam face, its relic dark, jacket broken open. Beyond the crest, a calm reservoir runs to a far mesa with a timber weir on its top in morning haze. References: park-dam vista-3.png for the dam and reservoir, warden-3.png for the broken relic. No text, no pilot ball, green ancient light only, copper never brass.

### 4.2 The climax: the head house (stage 2's end)

**H1. Into the drum**
- **Where:** `head_house_drum`, a 70 m bowl with 16 m walls under open steel trusses at about 32 m; the engage ring is the drum, centre [230, 480], `reach_m` 30 (`2-park_flume.md:32`, `34`).
- **You:** You come in through the doorway, over the wall on the geyser, or riding the flume through the north wall (`2-park_flume.md:292`, `296`, `180`).
- **You see:** The relic clamped on the pour channel 12 m up, green seams, the channel boiling (`2-park_flume.md:34`, `409`).
- **Pull:** The charge: lanes will pour from one place, the channel (`reactor.md:68`).
- **Pressure:** the pulse, as on the dam (`reactor.md:41`).
- **Seconds:** the same 6 s cycle, 2 s of charge (`reactor.md:40`).
- **Music:** The world-1 Warden pivot to four on the floor at 129; the Ab pedal under every 2 s charge (`2-park_flume.md:229`).
- **Panel:** existing `/home/andrew/Projects/scrapkeep/.claude/worktrees/scrapkeep-wt-cand-alpha-w13/artifacts/local/alpha/push/w13/concepts/codex/park/warden-reactor/warden-2.png` (shared with H2). Observed: drum interior, open roof truss, the flume entering on a trestle, two orange lanes running from beneath the relic, not from the channel.

**H2. The first pour**
- **Where:** the drum floor below the channel.
- **You:** Each pulse leaves a slag lane toward you, 14 m long and 4 m wide, filling over 1 s and burning a grounded ball for 6 s at 4 damage a second. You stay in the air, no more than 8 m above the lane, and earn `slag_hop` (`reactor.md:68-69`). The drum's walls are a bowl to bank (`2-park_flume.md:327`).
- **You see:** The lane pouring from the channel and running down the floor at you (`2-park_flume.md:36`).
- **Pull:** Air: the wall, the line, the shrug's throw.
- **Pressure:** the slag lane (`reactor.md:68`).
- **Seconds:** 1 s fill, 6 s burn (`reactor.md:68`).
- **Music:** The lane's fill is a rising hiss; the burn crackles on the Geiger tick (`2-park_flume.md:230`).
- **Panel:** shared with H1, `warden-2.png`.

**H3. Latch and orbit**
- **Where:** a cheek or the crown hardpoint (`reactor.md:78`); the roof trusses are world anchors (`2-park_flume.md:267`).
- **You:** You latch and orbit the relic under the trusses; the line does not drop inside the minimum rope (`reactor.md:79`; `PARK.md:419`).
- **You see:** The lanes below your orbit.
- **Pull:** The orbit keeps you airborne over every lane.
- **Pressure:** the next pour.
- **Seconds:** the 6 s cycle.
- **Music:** The pedal under each charge.
- **Panel:** NEW `j2-p05` (shared with H4, H5). 1536x1024. Camera inside a round concrete drum in morning light, 14 m above the floor, looking across at a squat ribbed drum relic clamped on a timber flume's pour channel 12 m up, three rod stacks, a caged green core dome. A harpoon line runs taut from a green-rimmed hardpoint on the channel's cheek out of frame toward the camera. Below, two orange cracked-slag lanes pour from the channel lip and run down the pale floor. Steel roof trusses overhead, sky between them. References: warden-reactor warden-2.png. No text, no pilot ball, green ancient light only, copper never brass.

**H4. Fire from the line**
- **Where:** hanging from a hardpoint over the drum.
- **You:** You fire while the lanes burn below; bolts add 3 posture during the charge (`reactor.md:80`).
- **You see:** The seams ramping on the charge (`reactor.md:95`).
- **Pull:** Posture toward 100.
- **Pressure:** a drain of 12 a second after 3 s without gain (`reactor.md:42`).
- **Seconds:** 2 s of each 6 s.
- **Music:** The pedal and the tick speeding toward the pulse (`reactor.md:106`).
- **Panel:** shared with H3, `j2-p05`.

**H5. The shrug over a fresh lane**
- **Where:** the lined cheek.
- **You:** The cheek flares for the charge and drops your line on the pulse; the throw lifts you over the lane just poured (`reactor.md:82`, `84`).
- **You see:** The cheek's flare in the channel's glow (`reactor.md:82`).
- **Pull:** The throw, a ride.
- **Pressure:** the fresh lane under the throw.
- **Seconds:** `shrug` 0.4 s (`reactor.md:99`).
- **Music:** The pulse lands on the beat.
- **Panel:** shared with H3, `j2-p05`.

**H6. The long window and the annex blow**
- **Where:** the relic; the `heat_exchanger_annex` (`2-park_flume.md:328`).
- **You:** The core stays open 6 s instead of 4 (`reactor.md:70`). You shatter a chunk at speed tier 2 or better (`reactor.md:44`).
- **You see:** The stagger read of D5 (`reactor.md:97`).
- **Pull:** The open core; at the second chunk, the annex roof becomes a ramp into the drum (`2-park_flume.md:149`).
- **Pressure:** `annex_reactor_blow` at the second chunk: 5 s `reactor_overload`, a 20 m fallout ring, 6 damage, 8 s, opens `annex_ramp_line` (`2-park_flume.md:149`).
- **Seconds:** the window is 6 s (`reactor.md:70`).
- **Music:** The half-step lift, then the sinister break; a steam whistle into a percussion hit at the blow (`2-park_flume.md:231-232`).
- **Panel:** shared with D5, `warden-3.png`.

**H7. The last chunk and the drop finisher**
- **Where:** above the open core.
- **You:** You release above the open core and haul: the drop finisher, never a bowl hammer (`reactor.md:45`, `86`; `PARK.md:414`).
- **You see:** The core blazing white-green through the split cage (`reactor.md:97`).
- **Pull:** The open core under you.
- **Pressure:** none during the stagger; every hardpoint holds (`reactor.md:86`).
- **Seconds:** the Reach skipper band is 35 to 80 s, re-measured at KF0 (`2-park_flume.md:263`).
- **Music:** Brindle's anvil enters under the sinister break: the boss is next (`2-park_flume.md:233`).
- **Panel:** NEW `j2-p06`. 1536x1024. Camera at roof-truss height inside a round concrete drum, looking straight down onto a squat ribbed drum relic on a timber pour channel: its four jaw plates leaning open, the lattice cage split, the core blazing white-green, one quarter of the jacket fallen as slabs on the floor. A harpoon line runs taut from a truss straight down past the camera toward the core. Two dying orange slag lanes on the pale floor. References: warden-reactor warden-3.png for the open body, warden-2.png for the drum. No text, no pilot ball, green ancient light only, copper never brass.

**H8. The quiet and the gates**
- **Where:** the gate row on the bluff lip outside the east doors at x 300, facing over the lower gorge; Moss's bay over the drum at [239, 480] (`2-park_flume.md:114`).
- **You:** You roll through a gate (`DESIGN-V3.md:138`) and the launch throws you out of the east doors across the gorge (`2-park_flume.md:114`).
- **You see:** Seams going dark one by one (`reactor.md:102`); through the doors, the smoke column and the furnace glow the launch aims at (`2-park_flume.md:114`).
- **Pull:** The launch arc toward the glow.
- **Pressure:** none for 20 s (`PARK.md:313`).
- **Seconds:** flight 0.6 s (`flow.gd:23`).
- **Music:** The unseal drop; the launch rides into Brindle's music (`2-park_flume.md:234`).
- **Panel:** NEW `j2-p07`. 1536x1024. Camera inside a round concrete head house at its open east doors, late morning, looking out east. On the bluff lip just outside, three reward gate arches face the drop; a hover barge with a workshop deck hangs over the drum roof behind the camera's shoulder, its shadow on the floor. Beyond the lip, a 95 m gorge with penstocks falling into it, and on the far horizon a dark smoke column with an orange furnace glow at its foot. References: park-flume vista-3.png. No text, no pilot ball, green ancient light only, copper never brass.

### 4.3 The exit: Brindle, then the Dig

- Stage 2 is the world's last stage, so when the 0.6 s flight ends, `_finish_stage` calls `enter_boss` with the ball's velocity and Brindle's module places the ball in the Slag Bowl (`2-park_flume.md:114`; `flow.gd:667-671`). The arena stays small and authored (`PARK.md:383`).
- After Brindle, the ball keeps rolling for 2.5 s, then the next world's first stage takes it with its velocity (`flow.gd:19-20`, `626-629`, `678-682`): `park_pit`, the Dig, at noon (`PARK.md:378`).
- **What you carry.** Your speed, entering from above (`flow.gd:21-25`). The parts from both gate rows. Build tree depths one and two, which world one reaches (`BIBLE.md:65`). Rivet, if the cage was reached (section 2, `DESIGN-V3.md:181`). The named pays `hot_rivets` and `loose_trigger`, if the camps were broken (`1-park_dam.md:376`; `2-park_flume.md:359`). Beating Brindle finds ledger leaf 1, which the profile keeps across runs (`DESIGN-V3.md:220`), and unlocks Tarn for the next run (`DESIGN-V3.md:182`). World 2 brings a fresh retry: the one retry is per world (`DESIGN-V3.md:29`).

## 5. Overhead route

`tools/park_plot.py` was planned as an unbuilt plot helper (`PARK.md:393`, not in the checkout); these lists are the polylines it would draw. Position fields in each appendix: `spawn.at` and `heading_deg`; `park_rows` carry `at` [x, z], `y`, `size` [x, y, z] and `yaw_deg`; `landmark` carries `at`, `sight_top`, `beacon`, `warden.anchor`, `bay_dock.at` and `gate_slots`; contraption rows carry `at`, or `from` and `to`, and `target`; activity rows carry `at`; event and home rows carry only a `site` row id (`1-park_dam.md:290-378`; `2-park_flume.md:279-361`). Pilot waypoints are `[x, z]` points or waymark ids (`1-park_dam.md:390-397`; `2-park_flume.md:373-380`).

**Stage 1, `park_dam`** (routes `1-park_dam.md:294-313`).

- Start: spawn [-150, -690], heading 30 (`1-park_dam.md:290`).
- Floor line: `top_shelf_deck`, `slickrock_domes`, waymark `domes_camp` [-51, -396], `shelf_lip`, `upper_slot`, waymark `the_eye` [0, 150], `construction_incline`, `river_canyon`, `tailwater_bar`, `toe_apron`, engage ring [0, 575], landmark `spillway_dam` [0, 620].
- Run alternatives: `west_wash` or `corkscrew_slot` for `upper_slot`.
- West: `the_eye`, `west_rim_bench`, then `spillway_tunnel`, `outlet_bucket`, `plunge_pool`, `toe_apron`; or `cliff_rooms_west`, `viga_span`, `service_ledge`, `toe_apron`.
- East: `the_eye`, `pipeline_bridge`, `east_bench_flats`, then `canal_lips`, `east_haul_road`, `toe_apron`; or `east_abutment`, `crest_rail`, landmark.
- Warden site: anchor [0, 22, 590] on the face. Gate row at z 528 ([-16, 528], [0, 528], [16, 528]). Bay dock [0, 467] (`1-park_dam.md:292`).

**Stage 2, `park_flume`** (routes `2-park_flume.md:284-297`).

- Start: spawn [-460, -650], heading 31 (`2-park_flume.md:279`).
- Floor line: `weir_deck`, `mesa_ramp`, `main_canal`, waymark `butte_gap` [-280, -230], `lateral_canal`, waymark `siphon_camp` on `the_siphon` [-20, 170], `wasteway_chute`, `drum_forecourt`, `head_house_drum` [230, 480].
- Flume line: `weir_deck`, `weir_chute`, `flume_weir_reach`, `flume_gap_reach`, `butte_gap`, `flume_hollow_reach`, `the_siphon`, `flume_head_reach`, `head_house_drum`.
- Camp line: `crew_ledges`, `crane_booms`, `mesa_rim_road`, `butte_gap`.
- Middle alternatives: `trestle_hollow`; `flume_hollow_reach` then `trestle_hollow` after the collapse; `rim_road`, `bend_overlook`.
- Last ways in: `bluff_rim`, `head_house_drum`; or `heat_exchanger_annex`, `head_house_drum` after the blow.
- Warden site: anchor [230, 41, 470] on the pour channel. Gate row at x 300 ([300, 466], [300, 480], [300, 494]). Bay dock [239, 480]. Landmark `penstock_tower` [270, 510] (`2-park_flume.md:281`).

## 6. Connecting material

**Signposting rules this world uses.** One meaning per layer, read from one source.

| Says | Colour | Shape | Sound | Where it comes from |
| --- | --- | --- | --- | --- |
| The Warden is that way | Uranium-glass green #9dff3c, only on ancient things | A vertical beam over the landmark; the ground falling toward it | The Ab pedal and Geiger tick, heard first at the small relics | `1-park_dam.md:23`, `30`; `2-park_flume.md:23`, `30`; `reactor.md:106`, `113` |
| You are on the way | Green marks repeat the beam on the line: the Eye's marks, the vent plate, the head house plate | Pinches: the Eye; the butte gap and the siphon | A filter dip or a one-bar break at each pinch | `1-park_dam.md:226`, `255-256`; `2-park_flume.md:223`, `228`, `248` |
| An offer off the line | Amber edge markers from the activity row | The activity site | none | `DESIGN-V3.md:134`, `140` |
| Damage is coming | Hazard stripes; the event's warning colour | The event's committed shape (ring, lane, cone) | A riser over the lead, the drop on the landing | `DESIGN-V3.md:144`; `1-park_dam.md:228`; `BIBLE.md:491` |
| The world boss is ahead | Orange furnace glow under a smoke column | A horizon mark east of stage 2 | Brindle's anvil and brass | `2-park_flume.md:114`, `225`, `233`; `1-park_dam.md:230` |
| How far the run has come | The sun: dawn at the dam, morning at the flume | The sun's height | none | `PARK.md:389` |

**The activities, and where each is first seen from the line.** All three per stage are signposted from the drop-in by amber edge markers (`1-park_dam.md:110`; `DESIGN-V3.md:134`).

| Stage | Activity | Site | First seen from the line |
| --- | --- | --- | --- |
| 1 | `domes_camp`, enemy camp, `hot_rivets` | [-51, -396], on the line | From the deck; passed within 12 m at 22 s (`1-park_dam.md:110`) |
| 1 | `rim_cache`, cracked cache | [-210, 400], west rim bench (moved from [-206, 300] 2026-10-19, greybox) | Leaving the Eye, on the right (inference from position, `1-park_dam.md:377`; the pocket now sits 100 m farther south, off the canyon wall, door sight_ok still true) |
| 1 | `bench_altar`, ambush altar | [330, 420], east bench | From the pipeline bridge (inference from position, `1-park_dam.md:378`) |
| 2 | `siphon_camp`, enemy camp, `loose_trigger` | [-28, 176], on the siphon | At the second waymark (`2-park_flume.md:359`) |
| 2 | `bend_cache`, cracked cache | [150, -80], bend overlook | From the rim road (inference, `2-park_flume.md:360`) |
| 2 | `bench_bounty`, hauler bounty | [-160, 480], south bench | Only by marker; no line crosses the bench (`2-park_flume.md:147`) |

**How the music carries across both stages into the fight.**

1. Stage 1 opens calm and earns its band: keys and pad, the reese bass on the first ride fact, the full groove on `first_drop`, the B section on the canyon floor (`1-park_dam.md:223-227`).
2. Two threads are planted early. The reactor's Ab pedal arrives small at the vents (`1-park_dam.md:231`). Brindle's anvil and brass arrive as one layer with the dropship (`1-park_dam.md:230`).
3. The dam fight pivots to four on the floor at 129 with the pedal under each charge, and resolves on the cadence the crest launch rides (`1-park_dam.md:234-237`).
4. Stage 2 restarts calm over the weir's water hiss, then the slap bass and the flume's tempo-locked ticks take over (`2-park_flume.md:217`, `221-222`).
5. The two threads return: the pedal at the bend relic, the anvil with the bench dropship (`2-park_flume.md:225-226`).
6. The climax uses the same pivot and pedal, adds the slag hiss and crackle, and on the last chunk the anvil enters under the sinister break; the launch rides into Brindle's music (`2-park_flume.md:229-234`).

**Momentum is sacred.** No beat above stops the ball: holds never brake (`decisions.tsv:119`), the collapse falls only when you are clear (`2-park_flume.md:151`), missing the sheet costs nothing (`reactor.md:58`), the shrug is a throw (`reactor.md:84`), the gates have no collider (`reward_gates.gd:11-14`) and the bay returns your speed (`bay.gd:15-19`). The movement loop the line tests is read, roll, land, rebound (`BIBLE.md:487`).

## 7. Gaps and calls

**Calls made under the creative charge (veto list).**

1. **The bay is the zone's workshop intermission.** DESIGN-V3 names a workshop intermission distinct from the camp and puts SPIL-9 assembly there (`DESIGN-V3.md:28`, `248`); `bay.gd:11` calls the bay Moss's workshop bay. This board treats the two as one stop.
2. **Two Wardens, one climax.** World 1 meets the same kind twice (`reactor.md:7-10`). This board makes the dam the teaching fight and the head house the climax, because the head house is the world's last stage and hands off to Brindle (`2-park_flume.md:114`).
3. **Rivet's cage gets an edge marker.** The cage at [60, -594] (`rescue_rows` rivet_cage) (`1-park_dam.md:273`). Smallest existing signpost: an edge marker, which already points at offscreen goals (`DESIGN-V3.md:134`). Back to the stage 1 page with the park-key question.
4. **The landmark hum carries the stage 2 doorway.** The page gives no music at the forecourt (beat 11). Both landmark rows already carry `music` `landmark_hum` (`1-park_dam.md:292`; `2-park_flume.md:281`); this board has it rise on the forecourt. Back to stage 2 section 10.
5. **Stage 2's tier-2 events miss a straight run.** The collapse, the bend relic, the dropship and the squall fire at 90 s (`2-park_flume.md:145-148`, `184`), while lines reach the drum at 87 to 98 s (`2-park_flume.md:194-199`) and pass the hollow and the bend around 35 to 75 s (inference from the segments). A skipper never sees the collapse or hears the bend relic. Proposed: move `hollow_trestle_collapse` and `bend_relic_wakes` to `clock_tier` 1, an existing trigger. Back to the stage 2 page.
6. **The dam fight is the teaching beat; the head house is the test.** The floor lines carry no harpoon (`1-park_dam.md:192`; `2-park_flume.md:190`), so a floor-line player first latches and fires from a line on the dam's pier. Off the floor line, fire from the line has two on-line spots, the viga span by the ledge lobbers and the west butte by the weir lobbers (section 4 table). The shrug is Warden-only (`PARK.md:422`) and drag is world 2's by design (`PARK.md:421`). Accepted: the pier is 45 m from the apron, the plate words lead, and the bay's practice yard follows before the climax (`bay.gd:26-27`).
7. **NEW briefs correct the existing Warden pictures.** `warden-1.png` and `warden-4.png` show two water streams; the sheet is one 24 m sheet centred on the relic (`reactor.md:56`). `warden-2.png` pours the lanes from beneath the relic; the lanes pour from the channel (`reactor.md:68`). `j1-p06` and `j2-p05` draw the rule.

**What the pages did not settle (back to the page or sheet named).**

1. **Stage 1 Frame 5 puts the powerhouse on the right** (`1-park_dam.md:424`). From the north looking south, east is on the left, and the powerhouse is at x 120 (`1-park_dam.md:342`); vista-3 shows it on the left. `j1-p03` puts it on the left. Stage 1 page.
2. **Flood depths disagree.** Stage 1 pool flood 3 m in the table against `depth_m` 1.2 (`1-park_dam.md:146`, `347`); wash flash flood 1.6 m against 1.2 (`1-park_dam.md:147`, `348`); stage 2 wasteway 1.6 m against 1.2 (`2-park_flume.md:146`, `332`). Both stage pages.
3. **The toe apron's size** is [40, 2, 300] at [0, 545] (`1-park_dam.md:341`); if 300 is the z extent it runs past the dam at z 620. Stage 1 page.
4. **No per-beat seconds.** Only segments are timed (`1-park_dam.md:196-202`; `2-park_flume.md:194-199`); every per-beat figure here is inference. The bot's `segment_s` needs beat-level waymarks or split samples (`PARK.md:474`). PARK.md section 8.
5. **What is live on arrival differs by pilot.** Stage 1 lines arrive at 84 to 98 s against tier 2 at 90 s (`1-park_dam.md:153`), so the vents and the monsoon may or may not be up; the pool flood's 35 s from tier 1 may have ended. Whether `lead_s` runs before or inside the tier time is not stated (`1-park_dam.md:347`). PARK.md section 5.
6. **The stage 2 rim line's return.** `rim_mid` ends at the siphon, about 230 to 300 m from the rim road and the overlook, with no landform named for the return (`2-park_flume.md:291`, `321-322`, `375`). Stage 2 page.
7. **The south bench has no route** (`2-park_flume.md:147`), so `bench_bounty` and the bench dropship sit off every line. Stage 2 page.
8. **The kind sheet has no stagger sound** beyond the clip table and the pedal (`reactor.md:97`, `106`). Kind sheet section 6.
9. **The kind sheet cites the drop-finisher principle at `PARK.md:410`** (`reactor.md:45`); it is at `PARK.md:414`. Kind sheet.
10. **No board slot for the approach, the exit or the bay.** The six-panel stage board (`PARK.md:410`) maps no panel to Frames 5 and 7 (`1-park_dam.md:405-412`; `2-park_flume.md:388-395`). The journey's NEW panels need a journey board or extra panel keys. PARK.md section 6.1.
11. **The bend relic, not the hollow, carries stage 2's tell**, but the dam fight has already taught the pedal, so stage 2's tell is a reminder. If call 5 is vetoed, the climax still reads.
12. **Gate count.** Both stage pages place three gate slots (`1-park_dam.md:36`; `2-park_flume.md:281`); today's code comment says two arches stand ahead of the ball (`reward_gates.gd:11-12`). Stage pages or the gate code.

**Out-of-page cites checked (wave 13 fix round).** Each line cited here from `flow.gd`, `bay.gd`, `reward_gates.gd`, `DESIGN-V3.md`, `PARK.md`, `BIBLE.md` and `decisions.tsv` was read with `sed -n` at base `5d0c2d871b` and says what this board cites it for. The one mismatch is gap 12.

**NEW panels:** `j1-p01` to `j1-p07` (7, of which 5 on the stage 1 line) and `j2-p01` to `j2-p07` (7, of which 4 on the stage 2 line): 14 in all.
