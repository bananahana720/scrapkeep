# World 3, The Highdraft: the journey to the Mind's hand

**Status: historical wave 13 journey draft (2026-10-10); World 3 is now unparked and shipped flat on `main` under rulings `ep`/`eq` with `Worlds.FULL_ALPHA := true`.** This page builds no new mechanic. It strings the two stage pages and the kind sheet into one ordered ride, beat by beat, with the pull that carries the ball from each beat to the next; numbers below are the original wave-13 starting values. Historical `artifacts/local/alpha/push/w13/concepts/...` paths refer to the wave-13 candidate worktree.

**Cite keys.** Every `(KEY:line)` resolves against one file in this repository:

| Key | File |
| --- | --- |
| S5 | `sketches/core-loop/design-v3/park/stages/5-park_islands.md` |
| S6 | `sketches/core-loop/design-v3/park/stages/6-park_crown.md` |
| MIND | `sketches/core-loop/design-v3/wardens/mind.md` |
| PARK | `sketches/core-loop/design-v3/PARK.md` |
| DV3 | `sketches/core-loop/design-v3/DESIGN-V3.md` |
| AP | `sketches/core-loop/design-v3/ALPHA-PLAN.md` |
| BAY | `sketches/core-loop/src/world/bay.gd` |
| LAUNCH | `sketches/core-loop/src/world/launch.gd` |
| BIBLE | `BIBLE.md` |

Picture paths are absolute and point at the gitignored concept folder `artifacts/local/alpha/push/w13/concepts/codex/park/` in the candidate worktree.

## The journey in one paragraph

You start on the Lookout Mesa's pine-topped crown at golden hour, 220 m up, with the Hanging Isle and its green beam on the northern skyline (S5:20, S5:405). You ride a downhill park of mesas over the animals' nets, through two waymarks, into the net bowl under the isle, where the Mind's hand holds the mountain up and tips it at you (S5:16, S5:59). Break it, roll through a gate, and the stage launch fires you along a rail of rings, speed kept, onto the Watch Butte (LAUNCH:6-10, PARK:273). There it is dusk under a building thunderstorm, with the 330 m Crown Spire and its beam straight ahead (S6:16, S6:396). You ride the bajada down through two more waymarks into the Crown bowl, where the same hand flies between three perch spires and drags you with it (S6:54). Its break is the Highdraft's last Warden: the gates on the Crown Apron lead on to the Mind's own arena and, after the Mind, to the ending bowl (S6:60, PARK:383). The beam is the thread: it stands over every drop-in and every waymark, so the Warden is always where you are going (PARK:119).

## The world arc

| Act | Where | What you want | What the world does | Time | Music layer |
| --- | --- | --- | --- | --- | --- |
| 1. The golden drop | Stage 5, Lookout Mesa to the Saddle (S5:203) | Pick a way off and build speed toward the beam | Shows you the isle, the nets and three amber activity markers at once (S5:205, S5:405) | 20 to 23 s at 20 m/s (S5:277-283) | Theme 2 intro over the high wind bed, first drop on the Saddle (S5:334-335) |
| 2. The fans and the nets | Stage 5, the Saddle to the Anvil to the bowl (S5:133) | Choose a fan, clear or skip its home, keep the isle ahead | Collapses the fin rim at tier 1, raises the cloud deck and lands a dropship at tier 2 (S5:211-213, S5:267) | Segments 2 and 3: 25 to 41 s, then 18 to 29 s (S5:277-283) | Hats in the chute, Fleet anvil and brass at the Moorings, cloud pad, landmark hum (S5:336-340) |
| 3. The first hand | Stage 5, the net bowl under the Hanging Isle (S5:57) | Latch a knuckle, ride the tilt, open the lens, drop on it | Tips the island 10 degrees on each pulse and throws a latched ball across the bowl (S5:59, MIND:112) | World 3 Warden band 24.5 to 128 s; grown median 25 to 45 s (S5:381, MIND:163) | Warden pivot, the Mind's quote once, the wrong note each charge (S5:341-343) |
| 4. The bay and the launch flight | Stage 5, the Keel Bench gates; Moss's bay docked at [0, 650] (S5:61); then the air between the stages | Bank speed onto the bay or roll straight through a gate | Holds every event off for 20 s; the bay is opt-in, a pit stop that never stops the ball; a gate fires you along a rail of rings and the next stage swaps in on the landing (PARK:313, BAY:11-19, LAUNCH:6-10, PARK:273) | Bay: no figure. Flight: 0.6 s in today's flow, no park figure (LAUNCH:14, gap 1) | The unseal drop, then the rice-cooker clear (S5:345); no flight cue (gap 9) |
| 5. The storm fan | Stage 6, the Watch Butte to the Turnstone to the split spire (S6:198) | Carve the ramp, pass the cache, choose one of four middle fans | Lightning marks the needles from tier 1; the flood and the spire strike come at tier 2 (S6:206-208) | 24 s, then 21 to 38 s at 20 m/s (S6:271-277) | Theme 2 intro over the storm bed; pump layer in the meander or east wash (S6:328-330) |
| 6. The last fans | Stage 6, the split spire to the Crown bowl (S6:128) | Take the needles, the crown ramp or the Gauntlet into the bowl | Drops a dropship on the Gauntlet Shelf; the cloudburst adds rain (S6:210, S6:261) | 16 to 38 s at 20 m/s (S6:271-277) | Strikes land as kick and crash; rain hats; landmark hum rising (S6:331-334) |
| 7. The last hand | Stage 6, the Crown bowl and its three perches (S6:54-56) | Ride a flight, knock it out of the air, change your habit, drop from the collector | Flies to the next perch every 8 s and braces against your top habit on each stagger (MIND:89-92) | 24.5 to 128 s band; grown median 25 to 45 s (S6:376, MIND:163) | Wrong note each charge over the perch hum; full quote on each stagger (S6:336-337) |
| 8. The exit | Stage 6, the Crown Apron gates at z 670, bay at [0, 600] (S6:58) | Roll through a gate | The gates lead to the Mind's arena; after the Mind, the ending bowl (S6:60, PARK:383) | No figure (S6:166) | Unseal drop, rice-cooker clear (S6:339) |

**The Warden is the endpoint you can see.** On both stages the landmark row carries `light: "ancient_beam"`, a green column that keeps the landmark readable through fog (PARK:119), and every stage's landmark must be seen from 85% of open cells (PARK:113). Stage 5's rough model reaches 0.877 and stage 6's 0.854 (S5:26, S6:26). Each stage below names the drop-in sighting and at least two more. On stage 6 the Crown and its beam are the Warden read on every line; the hand itself is seen before engage only from the crown ramp (S6:400; see the approach under the Warden).

**How to read the beat numbers.** A number is a beat every player meets in order. A letter marks a branch: 4a, 4b and 4c are alternatives, and you ride one of them. Each beat's **Next** line names the beat its pull leads to.

## Stage 5: the sky islands, the line

Three fans between four waymarks: `drop_in`, `saddle`, `altar_anvil`, `landmark` (S5:133, S5:203). The beats follow the floor line, the centre route `main`, and name the side fans where they split (S5:189-191, S5:273). Beats 1 to 3 share segment 1, beats 4a to 6 segment 2 and beats 7a to 8 segment 3; the page gives seconds per segment only (S5:283).

### 1. Drop-in on the Lookout

- **Where:** Lookout Mesa, `lookout_mesa`, with `fire_lookout` and `lookout_stair` on its rims; spawn [0, -720], heading north (S5:143-145, S5:455).
- **You:** You spawn 220 m up among relict pines and pick a way off: the north lip, the dam-era stair west, or the fire lookout swing east (S5:20, S5:176).
- **You see:** The Hanging Isle and its green beam about 1.2 km north on the skyline, the Slickrock Run curling down to the Saddle, the Twin Fins, the net glinting between mesas, and the three activity markers on the horizon (S5:405). **Warden sighting 1.**
- **Pull:** The north lip falls away into the Run (S5:273).
- **Pressure:** None.
- **Seconds:** Inside segment 1, 20 s on the floor line (S5:283).
- **Music:** The theme's intro bars over the high wind bed (S5:334, S5:266).
- **Panel:** `/home/andrew/Projects/scrapkeep/.claude/worktrees/scrapkeep-wt-cand-alpha-w13/artifacts/local/alpha/push/w13/concepts/codex/park/park-islands/vista-1.png` (observed: pines left, fire lookout right, the Run's curl below, the tram cable, the isle with beam and waterfall upper right; no activity markers drawn, gap 6).
- **Next:** 2.

### 2. The Slickrock Run

- **Where:** `slickrock_run` on the floor line; `lookout_stair` west and the `east_ribs` kicker east (S5:145-147).
- **You:** You carve the Run as an S down its 45 m drop; Sable vaults the stair's switchback lips, Rivet sprints the ribs (S5:273, S5:289-290, S5:304).
- **You see:** The Saddle filling the middle of the frame, the isle high and centred above it (inference from the row positions, `saddle` [0, -400], landmark [0, 520], S5:148, S5:460).
- **Pull:** The drop itself: the Run ends on the Saddle, which every line carves (S5:177).
- **Pressure:** None.
- **Seconds:** Inside segment 1 (S5:283).
- **Music:** The launch off the lip is the build (S5:335).
- **Panel:** NEW S5-A, shared with beat 3.
- **Next:** 3.

> NEW S5-A (beats 2 and 3): Chase camera low behind and above where the ball would be, 3 m off pink slickrock, mid-carve on the Slickrock Run's S-bend, the Run dropping away toward a wide slickrock saddle ridge below. Beyond the saddle, two parallel tan rock fins with a half-pipe between them; to the right on the saddle's east lip, a timber tram station with a cable running down-right. Golden hour, sun low from the left, long blue shadows east. The upside-down floating mountain with a thin waterfall and a green beam sits high and centred in the top third. Rope nets on posts span the gaps. References: park-islands vista-1 and vista-2. No ball, no text, green ancient light only, copper never brass.

### 3. The Saddle (waymark 1)

- **Where:** `saddle`, a bank 220 m wide; `tram_head` on its east lip (S5:148, S5:158, S5:177).
- **You:** You bank across the Saddle and choose a fan: centre into the Fin Chute, west onto the shelf and hoodoos, east onto the tram cable (S5:133, S5:190-191).
- **You see:** The chute mouth between the Twin Fins straight down the fall line, the tram cable falling east, the Moorings' balloon west (S5:149-150, S5:250, S5:156).
- **Pull:** One per fan, all three in view from the bank. Centre: the fins' chute mouth on the fall line at [0, -230], 170 m ahead (S5:150). East: the timber tram station on the Saddle's east lip and its cable falling away toward the Ore Bench from [100, 199, -390] (S5:158, S5:250); vista-1 draws the cable (beat 1 panel). West: the West Shelf terrace at [-200, -280] stepping down to the hoodoo caps (S5:154-155), with the Moorings' moored balloon beyond (S5:42). The page names none of these as a pull; all three are call 4.
- **Pressure:** East fork only: `tram_cutters` (line cutters) from tier 1, every 30 s, at most 3; they throw across the cable while you hang on it; drop off early or ram the deck from the Saddle's east lip (S5:235).
- **Seconds:** End of segment 1: 20 s floor, 22 to 23 s on the side lines (S5:277-283).
- **Music:** The landing on the Saddle is the first drop (S5:335).
- **Panel:** Shares NEW S5-A.
- **Next:** 4a centre, 4b west or 4c east.

### 4a. The Fin Chute (centre fan, the floor line)

- **Where:** `twin_fins` and `fin_chute`, a 40 m half-pipe, floor 128 m, between two fins 140 m tall (S5:149-150, S5:178).
- **You:** You pump the 260 m chute wall to wall; Kest rocket-jumps from the Saddle's west lip into `fin_thermal` and climbs to about 250 m to glide west (S5:273, S5:291).
- **You see:** The west fin's sunlit face filling the left, the fin nose kicker ahead, and the isle floating in the gap (S5:406). **Warden sighting 2.**
- **Pull:** The chute runs straight into the fin nose kicker (S5:273).
- **Pressure:** `fin_rim_collapse`, clock tier 1, about 45 s in: a crumble line glows along the west fin's rim for 6 s, then a 260 m slab drops 8 m and leans on the fin as a ramp; it closes `main` and opens `slab`, a slower line to the net (S5:211, S5:219). It fires while most lines are past the Saddle, so you see it beside or above you, never under it (S5:219).
- **Seconds:** Segment 2: 25 s floor, 25 to 41 s on pilot lines (S5:277-283).
- **Music:** The hats layer joins while you pump; the collapse brings `riser_natural` then `drop_collapse` (S5:336, S5:211).
- **Panel:** NEW S5-B.
- **Next:** 5.

> NEW S5-B (beat 4a, frame p3_line with the p5_event telegraph): Chase camera low inside a 40 m sandstone half-pipe between two tall tan rock fins, mid-pump on the east wall, the west fin's sunlit face filling the left of frame. Along the west fin's rim, a glowing crumble line of cracked light-tan rock with dust lifting. Ahead, the chute ends in a short kicker and open golden sky; the upside-down floating mountain with its green beam sits in the gap between the fin tips, rope nets on posts far below. Golden hour, sun low from the left. References: park-islands vista-1 for the fins and isle. No ball, no text, green ancient light only, copper never brass.

### 4b. The west fan: the shelf, the hoodoos, the Moorings

- **Where:** `west_shelf`, `hoodoo_garden`, `mooring_mesa` (S5:154-156, S5:190).
- **You:** You bank the shelf, swing or claw hoodoo to hoodoo through the garden and drop off the Moorings to the net (Tarn) (S5:155, S5:292).
- **You see:** The Moorings' rim from below: winch posts, the moored balloon, the crew's cable lane and the roost ferry passing overhead (S5:407). The Anvil and the isle beyond are inference from the row positions (`anvil_rock` [0, 60], landmark [0, 520], S5:153, S5:460).
- **Pull:** The drop off the Moorings lands on the net with the Anvil, the second waymark, ahead (S5:292, S5:203).
- **Pressure:** `mooring_anchor_crew` from tier 0: winch posts hook a ball crossing below; jump the cable lane early or slam the post from the roost ferry (S5:237). Activity `camp_moorings` (two anchor crews and a line cutter, pays `rivet_plating`) sits here (S5:199). At tier 2, `mooring_burner_blow` (5 s burner shriek, 10 s flare, envelope drapes into a ramp) and `mooring_dropship` (10 s inbound, wakes `dropship_anchor_crew`) (S5:212-213, S5:220-221).
- **Seconds:** Segment 2: 32 to 41 s on the side lines (S5:278-282).
- **Music:** The Fleet's anvil and brass, one layer per difficulty tick, while a crew is live (S5:338).
- **Panel:** `/home/andrew/Projects/scrapkeep/.claude/worktrees/scrapkeep-wt-cand-alpha-w13/artifacts/local/alpha/push/w13/concepts/codex/park/park-islands/vista-2.png` (observed: a winch station with a moored balloon on a mesa rim, top right, nets and posts, the isle upper left).
- **Next:** 6.

### 4c. The east fan: the tramway, the adit, the ore chute

- **Where:** `tram_head`, `ore_bench`, `ore_adit`, `ore_chute` (S5:158-161, S5:191).
- **You:** You grapple the tram head, ride the tramway down to the Ore Bench, drop through the adit and grind the ore chute 60 m down to the Anvil (Rivet, Cannon) (S5:290, S5:294). **The shrug, first taught here:** if the tram cutters or the chute cutters cut your cable, the line drops and you fly on; a cut line drops you off the chute's high end onto the net (S5:235-236). The Warden's shrug works the same way, the line drops and the ball keeps its velocity (PARK:422); that a cut cable keeps your speed is inference.
- **You see:** The tram station, the cable down to the Ore Bench, the adit through it and the chute down to the Anvil, the mine's whole run in one look (S5:41).
- **Pull:** The cable falls one way, `from` to `to`, at an 18 m/s floor, and the chute grinds straight down to the Anvil (S5:250, S5:258, S5:41).
- **Pressure:** `tram_cutters` from tier 1 on the cable (beat 3, S5:235). `chute_cutters` from tier 2 overlook the grind; grind low and fast (S5:236). Activity `bounty_ore_bench` sits on the bench (S5:201).
- **Seconds:** Segment 2: 32 to 41 s on the side lines (S5:278-282).
- **Music:** No layer named for the mine fan (S5:332-345, gap 9).
- **Panel:** Shares vista-1, which draws the tram cable (beat 1 panel); no picture shows the adit or the chute (gap 6).
- **Next:** 6.

### 5. The fin nose flight (after 4a only)

- **Where:** `fin_nose_kicker` at [0, -95] (S5:151).
- **You:** You launch off the kicker into about 80 m of air, about 2.5 s, over the net; Sable slingshots off a pylon here for the stage's longest flight; Tally holds chute speed into it (S5:178, S5:289, S5:293, S5:303).
- **You see:** Open sky, the net below, the isle straight ahead and closing (inference from the kicker heading north, S5:151, S5:460).
- **Pull:** Gravity: the flight lands on the net short of the Anvil (S5:178).
- **Pressure:** None at the kicker; if the collapse fired, the floor line comes down the `slab` instead (S5:192, S5:219).
- **Seconds:** About 2.5 s of air inside segment 2 (S5:303).
- **Music:** The stage's longest build: the A7b9 holds through the air and the net landing resolves it (S5:337).
- **Panel:** NEW S5-C.
- **Next:** 6.

> NEW S5-C (beat 5): Camera in the air just behind and above the kicker lip of a tan rock fin, looking north and slightly down over 80 m of open air. Below, an ochre rope net on posts slung between mesas, sagging; ahead, a short rock stub with a ramp rising out of the net. Filling the upper half of frame, the upside-down floating mountain, pines on its top deck, a thin waterfall turning to mist, a green beam rising from it, and a dull petrol-green hand cupping its tip from below. Golden hour, sun low from the left. References: park-islands vista-1 and vista-3. No ball, no text, green ancient light only, copper never brass.

### 6. The net and the Anvil (waymark 2, the altar)

- **Where:** `net_deck` at 60 m and `anvil_rock`, a 72 m stub with a 0.3 grade ramp on its south side (S5:152-153, S5:179).
- **You:** You land on the net, or come off the Moorings or the ore chute, and roll up the Anvil's ramp through the altar ring; every line crosses it (S5:273, S5:205).
- **You see:** The net running north to the bowl, the knuckle buttes, and the isle filling the top half of the frame, its tip 22 m above the net and the hand's green seams visible (S5:409). **Warden sighting 3.**
- **Pull:** Two ways off the Anvil. The floor line's carve runs straight on across the net into the bowl, under the isle (S5:273). For the wing lines, two balloons ride the lifts at [-210, 80] and [210, 80], just north of the Anvil at [0, 60] and to either side (S5:252-253, S5:153); the page does not name them as the pull, so that is call 9.
- **Pressure:** `altar_anvil`, an ambush altar on the line: every line crosses its ring (S5:200, S5:205). From tier 2, `cloud_rise` climbs out of the void over 8 s and holds 60 s, 4 m under the net, never over it (S5:267, S5:269).
- **Seconds:** End of segment 2 (S5:283).
- **Music:** `layer_cloud_pad` while the cloud holds; the landmark hum under the band (S5:339-340).
- **Panel:** NEW S5-D.
- **Next:** 7a on the floor line, 7b on a wing line.

> NEW S5-D (beat 6, the landmark approach frame): Camera 2 m above a flat rock stub's top, standing inside a faint ring of scorched stones (the altar ring), looking north across an ochre rope net on posts. The net runs to a deeper net bowl with three short buttes in it, each wrapped by a banked spiral. The upside-down mountain fills the top half of the frame, its tip low over the bowl, a dull petrol-green hand cupping it with green seams and three green-rimmed knuckle studs; a green beam rises from the top deck. White cloud sea a few metres below the net. Golden hour. References: park-islands vista-3, warden-mind warden-1. No ball, no text, green ancient light only, copper never brass.

### 7a. The long carve across the net (the floor line)

- **Where:** `net_deck` at 60 m, from the Anvil north to the bowl; its 16 m posts stand on an 80 m lattice (S5:139, S5:152).
- **You:** You cross the net in one long carve; Rivet sprints it flat out, the stage's peak-speed line (S5:273, S5:290). **Optional bite:** a harpoon on a net post as you pass swings you round it, and letting go keeps your velocity (S5:139, PARK:421); the floor line never needs it (S5:273). This is the floor line's first latch before the Warden (call 10).
- **You see:** The knuckle buttes and the isle filling the top of the frame, the hand's green seams under its tip (S5:409).
- **Pull:** The bowl's open south side, straight ahead (S5:57).
- **Pressure:** None on the line; the cloud deck, if it rose, holds 4 m under the net (S5:269).
- **Seconds:** Segment 3: 18 s (S5:283).
- **Music:** The landmark hum under the band (S5:340).
- **Panel:** Shares NEW S5-D.
- **Next:** 8.

### 7b. The wing lines: the balloon lifts, the washes, the cannons

- **Where:** `west_wing` and `cloud_wash_west`, `east_wing` and `cloud_wash_east`; `west_balloon_lift`, `east_balloon_lift`, `cloud_cannon_west`, `cloud_cannon_east` (S5:162-165, S5:252-255). West and east mirror each other.
- **You:** You ride a balloon lift up 60 m, pump the 320 m cloud wash and take the cannon onto a knuckle (S5:252, S5:163, S5:292).
- **You see:** A wing mesa on each side, the balloons on the lifts, the cannons aimed at the knuckles (S5:181, S5:254-255).
- **Pull:** The cannon throw, at least 3 s of flight, lands at [±75, 82, 505] beside a knuckle (S5:254-255).
- **Pressure:** None on the lines. Off them, by choice: `roost_kites` at the Kite Roost and `lens_rocks_wake`, the field hand eruption at tier 2 with a 9 s wrong-note hum (S5:239, S5:214, S5:222).
- **Seconds:** Segment 3: 29 s on the wing lines (S5:277).
- **Music:** The landmark hum under the band (S5:340).
- **Panel:** Shares `/home/andrew/Projects/scrapkeep/.claude/worktrees/scrapkeep-wt-cand-alpha-w13/artifacts/local/alpha/push/w13/concepts/codex/park/park-islands/vista-2.png` with beat 4b (observed: balloon lifts on a frame and half-pipe mesas over the net).
- **Next:** 8.

### 8. The bowl and the engage ring

- **Where:** `net_bowl`, a 200 m net with its floor at 44 m; `knuckle_w`, `knuckle_e`, `knuckle_n`, tops 80 m, banked spirals; the south side open (S5:57, S5:168-171).
- **You:** You roll in from the open south side and cross the engage ring, `reach_m` 120; a knuckle spiral carries you up toward a hardpoint about 37 m from its top (S5:57, S5:182).
- **You see:** The hand under the tip, its three green-rimmed knuckle hardpoints at 88 m and the lens cluster at 72 m tracking you (S5:55, MIND:22-23).
- **Pull:** The hardpoints are inside rope range from a knuckle top (S5:57); this is where the climax starts.
- **Pressure:** The Warden (next section). `bowl_thermal` beside the east knuckle lifts 160 m for a first slam from above (S5:249, S5:291).
- **Seconds:** End of segment 3; drop-in to engage 58 to 89 s on pilot lines, 49 to 63 s on the floor line (S5:277-283).
- **Music:** The Warden pivot, then the Mind's quote once (S5:341-342).
- **Panel:** `/home/andrew/Projects/scrapkeep/.claude/worktrees/scrapkeep-wt-cand-alpha-w13/artifacts/local/alpha/push/w13/concepts/codex/park/park-islands/vista-3.png` (observed: the isle, the hand under its tip, three spiral buttes in the net bowl, three gate frames on the bench beyond).
- **Next:** W1, the Warden.

## The bay between the stages

After stage 5's break the hand opens, goes dark and sinks into the bowl net, and no event starts for 20 s (S5:63, PARK:313). You roll up the bowl's north bank onto the Keel Bench, where three reward gates face north at z 720 and Moss's bay docks at [0, 650] (S5:61, S5:471).

- **What the bay offers.** A hover barge docked behind and above the gates; a steam cradle beside the gate row banks your speed and throws you onto the deck, and the bow pad throws you back down in front of a gate with that speed returned (BAY:11-19). Aboard: Moss's shutter and hatch, a practice yard with no cooldowns, a jukebox, and a timed lap round the rim (BAY:25-28). It is opt-in: rolling past the cradle leaves it behind (BAY:12-13).
- **The workshop.** Companion pieces are assembled or reconfigured at intermission (DV3:248); a zone's workshop intermission is not the between-run camp (DV3:28). That the bay is this intermission is inference.
- **Rescue or unlock.** World 3 has no rescue on these pages. The remembered cannon unlocks by beating the Mind, and the Mind's ledger leaf is the third (AP:34, DV3:220). So the Highdraft's reward is held until after both hands, which is what makes stage 6's gates the inevitable endpoint.
- **The save.** Run save keeps a durable snapshot at each zone entrance (AP:196); the first death in a world restarts the current zone (DV3:29). Stage 6's drop-in is therefore the world's second save point (inference from AP:196).
- **The handoff.** The gate roll is the launch flight below, the seam between the two climaxes.

### The launch flight (stage 5 gate to stage 6 drop-in)

- **Where:** From a Keel Bench gate at z 720 (S5:471) to the Watch Butte, stage 6's spawn at [0, -720] (S6:445).
- **You:** You roll through a gate and the stage launch fires you up a rail: a line of rings drawn along the exact arc you will fly, which holds you to it so nothing you clip costs speed (LAUNCH:6-9). The next stage swaps in on the landing (PARK:273). A second rail of rings brings you down onto a landing hill that turns the fall back into forward speed (LAUNCH:9-10). The bay's two throws ride the same rail maths (BAY:17-18).
- **You see:** Call 1: the sky crossfades from stage 5's golden hour to stage 6's dusk across the arc, and the building storm and the Crown's green beam rise ahead, so you land already looking at the next Warden (PARK:389, S6:396). The sources alone give a snap: time of day is entered with the stage (PARK:389), and the stage swaps on the landing (PARK:273).
- **Pull:** The landing rail of rings pointing down at the Watch Butte, with the beam beyond (LAUNCH:9-10).
- **Pressure:** None: no event starts for 20 s after the break (PARK:313). The budget allows no main-thread frame over 33 ms during the flight (PARK:493).
- **Momentum:** Horizontal speed is kept exactly, raised to a floor if slow, plus the lift (LAUNCH:40). You arrive at stage 6 beat 1 with your stage 5 speed.
- **Seconds:** 0.6 s in today's flow (LAUNCH:14); no figure for the park stages (gap 1). At 0.6 s the crossfade in call 1 is a blink.
- **Music:** The rice-cooker clear from the break carries over (S5:345); no flight cue is named (gap 9).
- **Panel:** NEW L-A.
- **Next:** Stage 6, beat 1.

> NEW L-A (the launch flight): Camera rides just behind and above a ballistic arc, high over open air, looking ahead along a curving line of seven thin pale rings. Behind, the last golden light on sandstone mesas and an upside-down floating mountain on its green beam. Ahead, the sky deepens to violet dusk over red-orange buttes; a towering anvil thunderstorm, and a 330 m sandstone spire sending a green beam into it. A second short line of rings falls toward a flat-topped butte's north edge and a sloped landing hill. Golden light behind, dusk ahead. References: park-islands vista-3, park-crown vista-1. No ball, no text, green ancient light only, copper never brass.

## Stage 6: the crown, the line

Three fans between four waymarks: `drop_in`, `cache_turnstone`, `split_spire`, `landmark` (S6:128, S6:198). The beats follow the floor line, `main`, and name each fan (S6:183-188, S6:267). Beats 1 to 3 share segment 1 (24 s on every line), beats 4a to 5 segment 2 and beats 6a to 7 segment 3 (S6:271-277).

### 1. Drop-in on the Watch Butte

- **Where:** `watch_butte`, top 200 m; spawn [0, -720], heading north (S6:20, S6:138, S6:445).
- **You:** You start on the butte's north edge under a building storm and drop off its nose (S6:170, S6:396).
- **You see:** The bajada fanned out below with fallen blocks, the Turnstone at the ramp's foot, hoodoos left, the gooseneck centre, the east wash right, and on the skyline the Crown Spire with its green beam and three tiny perches under an anvil cloud; a bolt strikes a needle on the left (S6:396). **Warden sighting 1.** The three activities are signposted from here (S6:200).
- **Pull:** The drop ramp falling 120 m from the butte's nose (S6:170).
- **Pressure:** None.
- **Seconds:** Inside segment 1, 24 s (S6:271-277).
- **Music:** The theme's intro over the storm bed, thunder far off (S6:328).
- **Panel:** `/home/andrew/Projects/scrapkeep/.claude/worktrees/scrapkeep-wt-cand-alpha-w13/artifacts/local/alpha/push/w13/concepts/codex/park/park-crown/vista-1.png` (observed: ball on the ledge, hoodoo field left, masts on the far left butte, winding washes, the Crown with beam and three perches in a bowl, a bolt on a far spire; the Turnstone is not drawn).
- **Next:** 2.

### 2. The drop ramp

- **Where:** `drop_ramp`, a steep slickrock nose (S6:139, S6:170).
- **You:** You carve the slickrock S down 120 m onto the bajada's head (S6:170).
- **You see:** The bajada rushing up, first rain streaks, the Crown dead ahead (S6:397). **Warden sighting 2.**
- **Pull:** The drop funnels every line onto the bajada at the Turnstone (S6:128).
- **Pressure:** None.
- **Seconds:** Inside segment 1 (S6:271).
- **Music:** The launch off the nose is the build (S6:329).
- **Panel:** NEW S6-A, shared with beat 3.
- **Next:** 3.

> NEW S6-A (beats 2 and 3, frame p3_line): Chase camera low over wet red-orange slickrock, mid-carve on a steep S-shaped rock ramp falling toward a wide alluvial fan studded with fallen sandstone blocks. At the ramp's foot a tall balanced rock (the Turnstone) with a small cracked cache at its base and a thin cable running from its cap down-left toward a hoodoo field. Dead ahead on the skyline, a 330 m sandstone spire with a green beam, three short spires at its foot, under a violet anvil cloud; first rain streaks. Dusk, sun just above the western horizon, buttes' west faces burning orange. References: park-crown vista-1 and vista-3. No ball, no text, green ancient light only, copper never brass.

### 3. The Turnstone and its cache (waymark 1)

- **Where:** `bajada`, `bajada_blocks`, `turnstone` at [0, -330]; the cache at [0, -315] (S6:140-142, S6:195).
- **You:** You land on the bajada and bank round the Turnstone; a cruise-speed ram or a slam cracks the cache at its foot (S6:171, DV3:130).
- **You see:** The four middle fans spreading from here; the `turnstone_wire` running from its cap toward the hoodoo forest (S6:128, S6:171). The drop-in frame set up the rest: the gooseneck glinting in the centre and the east wash running right (S6:396).
- **Pull:** One per fan. Centre, the floor line: the gooseneck's glint, the meander at [110, -200] (S6:396, S6:267, S6:149). East: the east wash running right (S6:396). Hoodoo: `turnstone_wire`, from the cap down to [-80, 70, -60] in the hoodoo forest (S6:245); it pulls only that fan. West: no pull named; the west wash leaves toward [-155, -262] (S6:143, gap 2).
- **Pressure:** `cache_turnstone`, a cracked cache every line passes (S6:195, S6:200).
- **Seconds:** End of segment 1, 24 s on every line (S6:271-277).
- **Music:** The bajada landing is the first drop (S6:329).
- **Panel:** Shares NEW S6-A.
- **Next:** 4a centre, 4b east, 4c hoodoo or 4d west.

### 4a, 4b. The centre and east fans: the meander (the floor line) and the east wash

- **Where:** `meander` and `meander_bend`, a gooseneck cut 18 m into the bajada; `east_wash` and `east_ribs` (S6:149-152, S6:173).
- **You:** You pump the gooseneck and bank its bend; Kest rocket-jumps off the bank, the Cannon recoil-rams the cracked wall; Rivet sprints the east wash and launches the ribs north-west to the split spire (S6:267, S6:284-285, S6:288).
- **You see:** The bend leading on to the Crown and its beam (inference from vista-3 below).
- **Pull:** The bend's exit points at the split spire (S6:183).
- **Pressure:** `meander_flash_flood`, tier 2: a 7 s roar upstream, then the gooseneck fills 1 m deep over 4 s for 30 s, closing `main` and `toppled`; it waits while you are within 20 m of the bend (S6:208, S6:217). The cloudburst triples its odds (S6:261). `meander_wall` opens only to a hard ram (S6:249, S6:252).
- **Seconds:** Segment 2: 24 s meander, 36 s east wash (S6:272-277).
- **Music:** The bass line's pump layer joins (S6:330); the flood brings `riser_natural` then `drop_flood` (S6:208).
- **Panel:** `/home/andrew/Projects/scrapkeep/.claude/worktrees/scrapkeep-wt-cand-alpha-w13/artifacts/local/alpha/push/w13/concepts/codex/park/park-crown/vista-3.png` (observed: winding washes and half-pipes leading to the Crown and its three perches; it also draws the hand on a mid-valley spire outside the bowl, gap 7).
- **Next:** 5.

### 4c, 4d. The hoodoo and west fans: the forest and the alcove

- **Where:** Hoodoo: `hoodoo_forest`. West: `west_wash`, `alcove_talus`, `alcove_ledge`, `alcove_horns` (S6:143-148).
- **You:** Hoodoo, you vault cap to cap (Sable). West, you pump the wash, roll the alcove ledge 33 m above the bajada and claw off the rock horns (Tarn) (S6:172, S6:283, S6:286).
- **You see:** The small stone room under the alcove's overhang, untouched; the split spire ahead (S6:39, S6:403).
- **Pull:** The split spire at [0, 40], where every middle route rejoins (S6:128, S6:153).
- **Pressure:** None. These fans can never close (S6:190), and the alcove carries no home or event (S6:44).
- **Seconds:** Segment 2: 21 s hoodoo, 38 s west (S6:271, S6:274).
- **Music:** No layer named for these fans (gap 9).
- **Panel:** NEW S6-B.
- **Next:** 5.

> NEW S6-B (beat 4d, the alcove spare frame): Camera low on a narrow rock ledge running along a sandstone butte's south-east face, 33 m above a wide fan. Under the overhang beside the ledge, a small stone room of shaped sandstone blocks in mud mortar, untouched. Above, natural rock horns with a single taut harpoon line running from one horn out of frame toward the camera. Through the gap ahead, a tall spire with a lightning scar, and far beyond it a 330 m spire with a green beam into a violet storm. Dusk, orange light on the rock, rain beginning. References: park-crown vista-1. No ball, no text, green ancient light only, copper never brass.

### 5. The split spire (waymark 2)

- **Where:** `split_spire`, 120 m, a lightning scar down its north side (S6:153, S6:174).
- **You:** You swing or slingshot round the spire; every route passes it (S6:183-188, S6:283). **Optional bite on the floor line:** the floor line swings past the spire (S6:267) with no harpoon; a line on it as you pass is the floor line's stage 6 latch before the Warden, and letting go keeps your velocity (S6:153, PARK:421, call 10).
- **You see:** The last fans: the needles left, the crown ramp ahead, the Gauntlet right (S6:128). The Crown's beam above them is inference: the beam stands on the landmark row and reads through fog (PARK:119). **Warden sighting 3.**
- **Pull:** The beam and the three last fans; once struck, the toppled ramp points from the spire's foot toward the Crown (S6:216).
- **Pressure:** `split_spire_strike`, tier 2, once: a 6 s blue-white mark crawls up the spire, then the bolt shears off its top 40 m, which falls north as a ramp and opens `toppled`; it waits while you are within 30 m (S6:207, S6:216).
- **Seconds:** End of segment 2 (S6:198, S6:271-277).
- **Music:** `riser_natural` into `drop_lightning` on the bar (S6:207, S6:331).
- **Panel:** NEW S6-C.
- **Next:** 6a centre, 6b west or 6c east.

> NEW S6-C (beat 5, frame p5_event): Camera at bajada level 40 m south of a lone 120 m sandstone spire with a dark lightning scar down its north side. A crackling blue-white mark crawls up the spire toward its top; fulgurite glass glints in the sand at its foot. Behind and beyond, the last fans open: needle spires left, a slickrock kicker ahead, two long buttes with a rope net right; on the skyline the 330 m spire with its green beam into a violet storm. Dusk, heavy cloud, first rain. References: park-crown vista-1, vista-2 and vista-3. No ball, no text, green ancient light only, copper never brass.

### 6a. The crown ramp (centre last fan, the floor line)

- **Where:** `crown_ramp`, a kicker at [0, 310] (S6:162).
- **You:** You run the bajada's last stretch flat out and launch the crown ramp into the bowl (S6:267, S6:284).
- **You see:** In the air: the bowl below, three perch spires, the hand mid-flight between two, the collector on the Crown's face, the beam into the storm (S6:400). **Warden sighting 4, and the only line that sees the hand itself before engage.**
- **Pull:** The launch carries you over the bowl and across the engage ring (S6:400).
- **Pressure:** None; this is the page's quiet-stretch risk, broken by the ramp itself (S6:299).
- **Seconds:** Segment 3: 16 s at 20 m/s, about 13 s for a fast Rivet (S6:277, S6:279).
- **Music:** The landmark hum rises as you near the beam (S6:334).
- **Panel:** NEW S6-E.
- **Next:** 7.

> NEW S6-E (beat 6a, the landmark approach frame): Camera in the air just past a slickrock kicker lip, looking north and down into a 240 m scoured slickrock bowl. Three short perch spires stand round the foot of a 330 m sandstone spire; a dull petrol-green mechanical hand with glowing green seams flies between two perches, fingers spread like flight feathers, a green arc trail behind it. A copper catwalk ringed with rods clings to the big spire's south face; a green beam rises from its tip into a violet thunderstorm. Dusk, wet rock mirroring lightning. References: park-crown vista-3, warden-mind warden-2 and warden-3. No ball, no text, green ancient light only, copper never brass.

### 6b. The needles and the signal wire (west last fan)

- **Where:** `needles`, `signal_masts`, `signal_wire`; `signal_butte` and `lens_spire` off the line (S6:154-157, S6:246).
- **You:** You ride `needle_updraft` and glide over the needles, or swing and claw needle to needle, then catch the signal wire down into the bowl's west wall (S6:285-286). **Fire from the line, taught here:** the kites' counter is "Shoot them while they circle, or swing the needles" (S6:232); hanging on a needle line and shooting them at once is call 11. **The shrug again:** if the mast cutters cut the signal wire, the line drops and you fly on (S6:230).
- **You see:** Kite drones circling in a rain-lit updraft above the needle tips; the signal wire running to the bowl (S6:398, S6:246). Ahead, the open lens seat glowing on the current perch is the hand's read from this line (S6:54, call 12).
- **Pull:** The wire runs from [-265, 62, 300] down to [-100, 20, 430], into the bowl (S6:246).
- **Pressure:** `needle_strikes` from tier 1: three needles marked for 3 s, the bolt lands on the downbeat with an 8 m ring, 20 s windows every 40 s (S6:206, S6:215). `needle_kites` hold above ram reach; shoot them or swing and leave the mark (S6:232). `mast_cutters` throw across the wire as you leave the needles; drop off early or glide under the arc (S6:230). Off the line by choice: `camp_signal` on the Signal Butte and `lens_spire_wakes`, a 9 s wrong-note hum and a larger field hand (S6:194, S6:209, S6:218).
- **Seconds:** Segment 3: 29 s (S6:273-274).
- **Music:** Each strike lands as a kick and crash on the bar; the cloudburst adds rain hats (S6:331-332).
- **Panel:** NEW S6-D.
- **Next:** 7.

> NEW S6-D (beat 6b, frame p4_home): Camera inside a field of tall thin sandstone needle spires, looking up. Kite drones circle in a rain-lit updraft column above the needle tips; a dive mark on the ground is half lost in a blue-white lightning flash striking one needle. On a butte rim beyond, copper signal masts with a wire running down toward a bowl. Far ahead, the 330 m spire with its green beam into the storm. Dusk, violet sky, rain. References: park-crown vista-1 and vista-2. No ball, no text, green ancient light only, copper never brass.

### 6c. The Gauntlet and the shelf cannon (east last fan)

- **Where:** `gauntlet_west`, `gauntlet_east`, `gauntlet_net` at 110 m, `gauntlet_shelf`; `gauntlet_balloon_lift`, `shelf_cannon` (S6:158-161, S6:247-248).
- **You:** You ride the balloon lift up 90 m onto the net, pump it under the anchor crews' rim, drop to the shelf and fire the shelf cannon into the bowl (Sable, Tally); the Cannon runs the bajada east to the shelf (S6:247, S6:283, S6:287-288).
- **You see:** Two long buttes turned toward the Crown, the net between them, the balloon, the dropship pad on the shelf, the Crown's beam beyond (S6:175, vista-2 observed). The open lens seat glowing on the current perch is the hand's read from this line (S6:54, call 12).
- **Pull:** The cannon, aimed at [100, 0, 480] in the bowl, with at least 3.2 s of flight (S6:248).
- **Pressure:** `gauntlet_anchor_crew` from tier 0 hooks a ball on the net; jump the cable lane or ride the lift high and slam the post (S6:231). `gauntlet_dropship` at tier 1: 10 s inbound, lands on the shelf, wakes `dropship_cutters`; its ramp is a kicker toward the Crown (S6:210, S6:219, S6:234). `bounty_gauntlet` sits on the shelf (S6:196).
- **Seconds:** Segment 3: 28 to 38 s (S6:271, S6:275-276).
- **Music:** The Fleet's anvil and brass while a crew is live (S6:333).
- **Panel:** `/home/andrew/Projects/scrapkeep/.claude/worktrees/scrapkeep-wt-cand-alpha-w13/artifacts/local/alpha/push/w13/concepts/codex/park/park-crown/vista-2.png` (observed: the two buttes and their net, the balloon, a pad on a shelf right, the Crown with beam and perches, a bolt on a needle).
- **Next:** 7.

### 7. The Crown bowl and the engage ring

- **Where:** `crown_bowl`, 240 m across and 12 m deep; `perch_spires` 45 m from the Crown's axis and 78 m apart; `crown_collector` at 64 m (S6:56, S6:163-165, S6:54).
- **You:** You cross the engage ring, `reach_m` 120, where the traversal measure stops (S6:56, S6:298).
- **You see:** The hand palm down on a perch, its lens at 18 m and its three knuckle studs 2 m above the perch top (S6:54, MIND:106).
- **Pull:** From the bowl floor beside a perch the knuckles are about 27 m away, inside the 45 m rope (MIND:106).
- **Pressure:** The Warden (next section). `crown_updraft` lifts 120 m on the bowl's west side (S6:243).
- **Seconds:** Drop-in to engage 58 to 99 s on pilot lines, 50 to 65 s on the floor line (S6:271-277).
- **Music:** The Warden pivot (S6:335).
- **Panel:** `/home/andrew/Projects/scrapkeep/.claude/worktrees/scrapkeep-wt-cand-alpha-w13/artifacts/local/alpha/push/w13/concepts/codex/park/warden-mind/warden-2.png` (observed: the hand gripping a perch top, two empty perches with green seats, the Crown and beam behind, storm and lightning).
- **Next:** W1, the Warden.

## The Warden: the Mind's hand, the climax

The same 16 m hand closes both stages: palm up under the Hanging Isle, palm down on the Crown's perches (MIND:20, MIND:25). Four lit fingers are its four chunks, readable from 150 m (MIND:21). Stage 5: plating 170, health 1,250. Stage 6: plating 190, health 1,400 (MIND:53).

**The approach.** On stage 5 the mounting first reads from the drop-in as a tiny hand under the isle's tip (vista-1 observed), then from the Anvil with its green seams (S5:409). On stage 6 the Crown and its beam are the Warden read on every line: three tiny perches at the Crown's foot from the drop-in (S6:396), the Crown dead ahead on the drop ramp (S6:397), and the beam over the last fans from the split spire (inference from PARK:119). The hand itself is seen early only on the centre line, in flight from the crown ramp (S6:400). On the needles and Gauntlet lines the one early hand read is the open lens seat glowing on the current perch (S6:54, call 12); the fingers read only from 150 m (MIND:21), so those players first see the hand clearly at engage. The three knuckle hardpoints are rimmed in the ancients' green on both (MIND:22, PARK:418).

**Where the stages teach the harpoon anchor before the fight.**

| Anchor behaviour | Taught on stage 5 | Taught on stage 6 |
| --- | --- | --- |
| Latch | The fire lookout grapple swing and the tram head grapple (S5:144, S5:158, S5:290). Floor line: an optional bite on a net post, beat 7a (S5:139, call 10) | The split spire swing and slingshot (S6:153, S6:283). Floor line: an optional bite as it swings past the spire, beat 5 (S6:267, call 10) |
| Ride and winch | The 16 m posts on the net's 80 m lattice and the relict pines are anchors on every line (S5:139) | `bajada_blocks`, hoodoos, needles and spires (S6:134) |
| Fire from the line | Not taught on stage 5; the roost kites sit off the lines (S5:239, gap 4) | Shoot the needle kites while you hang on a needle line, beat 6b (S6:232, call 11) |
| Drag | The tramway and roost line carry you one way at an 18 m/s floor; the roost ferry is a moving island (S5:258) | The two wires; `needle_barge`, a moving rock raft (S6:250, S6:252) |
| Resist (the shrug) | The tram and chute cutters cut your cable; the line drops and you fly on, beat 4c (S5:235-236) | The mast cutters cut the signal wire, beat 6b (S6:230) |
| Lift (the pulse) | Thermals lift you straight up, as the pulse does (S5:247-249) | The needle and crown updrafts (S6:242-243) |
| The quote | The Lens Rocks field hand quotes you small first (MIND:153, S5:222) | The lens spire hand and the `spire_hands` home (MIND:153, S6:233) |

The floor line uses no harpoon and no contraption (S5:273, S6:267). Its anchor lessons are the two optional bites; fire from the line and the shrug are taught on side lines only, so a floor-line player meets both first at the Warden (gap 4).

### W1. Engage and the greeting

- **You:** You cross the 120 m engage ring (MIND:60).
- **You see:** The hand idle: fingers flex one at a time, seams breathe, the lens cluster tracks you (MIND:122). Under the island it hangs 28 m above the bowl floor; on the Crown it perches 24 m above it (MIND:55).
- **Pull:** The hand quotes your class motif once, inverted, last note a semitone flat: its greeting (MIND:140, MIND:144). The plate switches to "Break its guard" and the activity markers hide (DV3:136, DV3:139).
- **Pressure:** None yet.
- **Seconds:** The fight band starts here: 24.5 to 128 s (S5:381, S6:376).
- **Music:** The Warden pivot, then the quote on the game frame; the Mind never enters the band (S5:330, S5:341-342).
- **Panel:** Stage 5 `/home/andrew/Projects/scrapkeep/.claude/worktrees/scrapkeep-wt-cand-alpha-w13/artifacts/local/alpha/push/w13/concepts/codex/park/warden-mind/warden-1.png`; stage 6 shares warden-2 with beat 7.

### W2. Latch

- **You:** You fire the harpoon at a knuckle from up to 45 m: under the island from a knuckle butte's top edge, about 37 m; on the Crown from the bowl floor beside the perch, about 27 m (MIND:106).
- **You see:** Three round green-rimmed studs on the back of the hand (MIND:22; warden-1 and warden-2 observed).
- **Pull:** The bite holds; a hardpoint line follows the body (PARK:418).
- **Pressure:** None.
- **Seconds:** Inside the band.
- **Music:** No cue named.
- **Panel:** Shares warden-1 (stage 5) and warden-2 (stage 6).

### W3. Ride and fire from the line

- **You:** You swing as on a world line and winch shorter; the line never drops inside the minimum rope (PARK:419). Under the island a 16 m line hangs you level with the lens for a ram swing; on the Crown you orbit the perch spire (MIND:107). The weapon fires while you hang: 1.5 posture a bolt, 3 during the charge (MIND:108).
- **You see:** The posture filling 0 to 100 (MIND:47).
- **Pull:** The charge: its doubled posture rate (MIND:47).
- **Pressure:** Posture drains 12 a second after 3 s without gain (MIND:47).
- **Seconds:** Inside the band.
- **Music:** Stage 6: the occupied perch hums a low sine (MIND:151).
- **Panel:** NEW W-A, shared with W5.

> NEW W-A (W3 and W5, board panel w4_anchor): Camera rides a taut harpoon line, looking up along it from just below frame bottom to a green-rimmed knuckle stud on the back of a 16 m dull petrol-green mechanical hand. The hand cups the tip of an upside-down mountain that is tipped 10 degrees, its thin waterfall leaning; the whole tip and hand are swinging away across an ochre net bowl with three spiral buttes, motion blur on the rock. The wrist stalk hangs below with a big lens ringed by five small lenses, narrowed, glowing green. Golden hour. References: warden-mind warden-1 and warden-4, park-islands vista-3. No ball, no text, green ancient light only, copper never brass.

### W4. The charge and the pulse

- **You:** You use the lift or stay out of the 6 m core sphere round the lens (MIND:46, MIND:59).
- **You see:** The reach ring, 30 m, drawn on the arena floor under the lens during the 2 s charge; the five small lenses blink; the fingers tighten (MIND:58, MIND:123). Under the island the island creaks and the waterfall leans toward you (MIND:70).
- **Pull:** The pulse: +10 m/s straight up inside the reach ring, 10 damage only in the core (MIND:46). Under the island it tips 10 degrees on the same frame (MIND:71). On the Crown a pulse always comes from a perch (MIND:90).
- **Pressure:** A camper under the island's lens finds it 20 m away after every pulse (MIND:77).
- **Seconds:** A 2 s charge every 6 s (MIND:45).
- **Music:** Only the quote's wrong last note, held on sine for the 2 s charge, landing on the pulse (MIND:145).
- **Panel:** Shares warden-1 (stage 5) and warden-2 (stage 6).

### W5. The drag and the throw

- **You:** Under the island, latched at the pulse, the swing drags you about 20.5 m in 1.2 s at about 27 m/s and the line lets go when the swing stops; you fly on with that speed plus the 10 m/s lift toward the opposite knuckle's banked spiral (MIND:72, MIND:110, MIND:112). On the Crown, latched while it perches, its takeoff drags you along a 3 s, 85 m arc at about 28 m/s and lets you go at the next perch with that speed (MIND:89, MIND:96).
- **You see:** The flared knuckle flicks outward (MIND:127).
- **Pull:** The throw lands on a spiral or a perch, which is the next latch (MIND:112).
- **Pressure:** The resist never stops the ball (MIND:112). Stage 6 never flies during a charge; the perch clock waits up to 2 s (MIND:90).
- **Seconds:** Swing 1.2 s out, 2.8 s back (MIND:72); flight every 8 s, 3 s long (MIND:89).
- **Music:** Stage 5: a wind roar panned with the hand. Stage 6: a 3 s sine glide between the perches' hums (MIND:150-151).
- **Panel:** Stage 5 shares NEW W-A. Stage 6 `/home/andrew/Projects/scrapkeep/.claude/worktrees/scrapkeep-wt-cand-alpha-w13/artifacts/local/alpha/push/w13/concepts/codex/park/warden-mind/warden-3.png` (observed: the hand in flight, fingers spread, a green arc trail from a perch, no line or ball).

### W6. The stagger window

- **You:** You fill posture to 100 and stay on your line: every hardpoint holds through the stagger (MIND:48, MIND:114). On the Crown you hit it in flight with a line or long jump to knock it to the bowl floor (MIND:91).
- **You see:** The lens opens to 1.3 scale, fingers splay, seams blaze (MIND:125). Under the island the island sinks 2 m, the waterfall breaks to spray and the lens drops 10 m to 62 m, 18 m above the floor (MIND:79). On the Crown a knock-down tumbles it palm up onto the floor, lens open; the full quote plays and the lens shows the habit it braced (MIND:91-92, MIND:133).
- **Pull:** The open lens, the weak point (MIND:48).
- **Pressure:** The pulse pauses (MIND:48). Stage 6: hits of your most-used habit meet 1.6 times the plating; change the tune (MIND:49, MIND:92). The plate reads "Smash the core" (DV3:136).
- **Seconds:** 4 s (MIND:48).
- **Music:** Stage 5: the waterfall cuts out for the 4 s window. Stage 6: a dull stone thud, then silence while the lens lies open (MIND:150-151).
- **Panel:** Stage 5 `/home/andrew/Projects/scrapkeep/.claude/worktrees/scrapkeep-wt-cand-alpha-w13/artifacts/local/alpha/push/w13/concepts/codex/park/warden-mind/warden-4.png` (observed: fingers splayed, stalk straight down, lens blazing, waterfall to spray). Stage 6 NEW W-B, shared with W7.

### W7. The drop finisher

- **You:** You release above the open lens and haul (MIND:51, PARK:414). Under the island it is a 26 m fall from a knuckle line onto the dropped lens; on the Crown, a fall from the collector catwalk at 64 m or a perch line onto the hand perched or on the floor (MIND:79, MIND:114).
- **You see:** The blazing open lens rushing up.
- **Pull:** The shatter: a chunk breaks at speed tier 2 or better (MIND:50).
- **Pressure:** Never a bowl hammer: the harpoon finishes from above (PARK:414).
- **Seconds:** Inside the 4 s stagger (MIND:48).
- **Music:** Half broken, the key lifts; three quarters, the sinister break (S5:344, S6:338).
- **Panel:** NEW W-B.

> NEW W-B (W6 and W7 on stage 6, board panel w5_break): Camera falls with the drop, looking straight down a hauled harpoon line from a copper catwalk ringed with lightning rods on a 330 m sandstone spire's south face. Far below, on a wet scoured slickrock bowl floor, a 16 m dull petrol-green mechanical hand lies palm up where it was knocked out of the air, fingers splayed, its big lens wide open and blazing green, a small habit icon shown in the lens. Three short perch spires stand round it, their seats dark. Dusk thunderstorm, lightning reflected on the rock. References: warden-mind warden-2 and warden-3, park-crown vista-3. No ball, no text, green ancient light only, copper never brass.

### W8. The break, four times

- **You:** You repeat the cycle until four chunks are gone, at most one per stagger (MIND:50).
- **You see:** One finger goes dark and curls shut, little finger first, then ring, middle, index (MIND:126).
- **Pull:** The count of lit fingers (MIND:21).
- **Pressure:** Stage 5, first chunk: `isle_shed`, a 6 s mark, then a boulder off the isle's rim leaves a 40 m rideable crater on the West Wing (S5:215, S5:223). Stage 6, second chunk: `collector_burst`, a 5 s whistle, an 8 s steam cone 24 by 10 m, then the catwalk leans on the nearest perch as a ramp to the perch tops (S6:211, S6:220).
- **Seconds:** Grown median 25 to 45 s for the whole fight (MIND:163).
- **Music:** `riser_natural` into `drop_impact`; `riser_industrial` into `drop_boiler` (S5:215, S6:211).
- **Panel:** Shares warden-4 (finger count reads loosely, gap 7).

### W9. Final quiet and the exit

- **You:** You roll to the gates: stage 5 up the bowl's north bank onto the Keel Bench, stage 6 onto the Crown Apron (S5:63, S6:58).
- **You see:** The thumb, the last lit seam, goes dark and the lens closes like an eye (MIND:134). Stage 5: the hand sinks into the bowl net; the island stays up on its beam (S5:63). Stage 6: the hand drops into the bowl, the three lens seats go dark, the beam stays (S6:60).
- **Pull:** The plate says "Roll through a gate" (DV3:138); three gates and Moss's bay dock above them (S5:61, S6:58).
- **Pressure:** None: no event starts for 20 s (PARK:313).
- **Seconds:** No figure.
- **Music:** The unseal drop, then the rice-cooker clear (S5:345, S6:339).
- **Panel:** Stage 5 NEW W-C; stage 6 NEW W-D.
- **You carry.** Out of the Highdraft into the Mind's arena: a part and 180 Scrap for each activity you finished (DV3:131); the named `rivet_plating` from each camp you cleared, the Moorings and the Signal Butte (S5:199, S6:194); and the stage 6 lesson, change the tune against the brace (MIND:92), which the Mind boss's own choir Warden asks of you again (S6:373, S6:377, PARK:448).
- **What opens.** Stage 5's gates fire the launch flight to stage 6 (the bay section above). Stage 6's gates lead to the Mind's own arena, authored and small, and after the Mind to the ending bowl (S6:60, PARK:383). Beating the Mind finds ledger leaf 3 and unlocks the remembered cannon for the next run (DV3:220, AP:34).

> NEW W-C (W9, stage 5 exit): Camera on a flat mesa bench at the north rim of an ochre net bowl, looking back south and up. In the bowl net below, a 16 m dull petrol-green mechanical hand lies open and dark, every seam unlit. Overhead, the upside-down mountain still hangs on its green beam, its thin waterfall restored. On the bench, three tall stone gate frames face north; a hover barge docks above and behind them with a steam cradle beside the gate row. Last golden light, long shadows. References: park-islands vista-3, warden-mind warden-1. No ball, no text, green ancient light only, copper never brass.

> NEW W-D (W9, stage 6 exit): Camera on a wet slickrock shelf north of a scoured bowl, looking south. Three stone gate frames stand on the shelf in the rain; a hover barge docks above and behind them. In the bowl below, a 16 m dull petrol-green mechanical hand lies dark among three short perch spires whose seats are dark. The 330 m sandstone spire behind still sends its green beam up into the violet thunderstorm; a copper catwalk leans against one perch as a ramp. Dusk turning to night. References: park-crown vista-3, warden-mind warden-2. No ball, no text, green ancient light only, copper never brass.

## Overhead route

The planned plot tool would draw each route from the park file's `routes[].via` row ids, placing each id at its row's `at` [x, z]; hung rows carry an absolute `y` (S5:137, S6:132). `p1_overhead` from unbuilt `tools/park_plot.py` (not in checkout) stays due (PARK:393).

**Stage 5, `park_islands`** (appendix S5:445-552). Start: spawn [0, -720], heading 0 (S5:455). Warden: landmark [0, 520], anchor [0, 80, 520] (S5:460, S5:469). Bay dock [0, 650]; gates at z 720 (S5:470-471).

| Route | Ordered row ids, with `at` | Cite |
| --- | --- | --- |
| `main` (floor line) | `lookout_mesa` [0, -660], `slickrock_run` [0, -560], `saddle` [0, -400], `twin_fins` [0, -230], `fin_chute` [0, -230] y 128, `fin_nose_kicker` [0, -95], `net_deck` [0, 0] y 60, `anvil_rock` [0, 60], `net_bowl` [0, 520] y 44 | S5:189, S5:143-168 |
| `west` | `lookout_mesa`, `lookout_stair` [-110, -560], `saddle`, `west_shelf` [-200, -280], `hoodoo_garden` [-250, -160], `mooring_mesa` [-240, -10], `net_deck`, `anvil_rock`, `west_wing` [-210, 250], `cloud_wash_west` [-210, 250], `knuckle_w` [-60, 520], `net_bowl` | S5:190, S5:143-169 |
| `east` | `lookout_mesa`, `fire_lookout` [130, -640], `east_ribs` [110, -500], `saddle`, `tram_head` [100, -390], `ore_bench` [290, -150], `ore_adit` [290, -130], `ore_chute` [190, -20] y 100, `anvil_rock`, `east_wing` [210, 250], `cloud_wash_east` [210, 250], `knuckle_e` [60, 520], `net_bowl` | S5:191, S5:143-170 |
| `slab` (event) | `lookout_mesa`, `slickrock_run`, `saddle`, `twin_fins`, `net_deck`, `anvil_rock`, `net_bowl` | S5:192 |
| `envelope` (event) | `lookout_mesa`, `lookout_stair`, `saddle`, `west_shelf`, `mooring_mesa`, `net_deck`, `anvil_rock`, `net_bowl` | S5:193 |

After the break: `net_bowl` to `keel_bench` [0, 700], the bay and the gates (S5:172).

**Stage 6, `park_crown`** (appendix S6:435-541). Start: spawn [0, -720], heading 0 (S6:445). Warden: landmark [0, 470], anchor [0, 18, 515], path [0, 18, 515], [39, 18, 447.5], [-39, 18, 447.5] (S6:450, S6:459). Bay dock [0, 600]; gates at z 670 (S6:460-461).

| Route | Ordered row ids, with `at` | Cite |
| --- | --- | --- |
| `main` (floor line) | `watch_butte` [0, -640], `drop_ramp` [0, -470], `bajada` [0, -35], `turnstone` [0, -330], `meander` [110, -200], `meander_bend` [90, -40], `split_spire` [0, 40], `crown_ramp` [0, 310], `crown_bowl` [0, 470] | S6:183, S6:138-163 |
| `hoodoo` | `watch_butte`, `drop_ramp`, `bajada`, `turnstone`, `hoodoo_forest` [-80, -170], `split_spire`, `needles` [-170, 180], `crown_bowl` | S6:184 |
| `west` | `watch_butte`, `drop_ramp`, `bajada`, `turnstone`, `west_wash` [-155, -262], `alcove_talus` [-300, -215], `alcove_ledge` [-236, -98] y 80, `alcove_horns` [-246, -91] y 120, `split_spire`, `needles`, `signal_masts` [-270, 300], `crown_bowl` | S6:185, S6:143-156 |
| `east` | `watch_butte`, `drop_ramp`, `bajada`, `turnstone`, `east_wash` [260, -210], `east_ribs` [240, -50], `split_spire`, `gauntlet_shelf` [220, 330], `crown_bowl` | S6:186, S6:151-161 |
| `gauntlet` | `watch_butte`, `drop_ramp`, `bajada`, `turnstone`, `east_wash`, `split_spire`, `gauntlet_west` [170, 170], `gauntlet_net` [280, 175] y 110, `gauntlet_shelf`, `crown_bowl` | S6:187, S6:158-161 |
| `toppled` (event) | `watch_butte`, `drop_ramp`, `bajada`, `turnstone`, `meander`, `meander_bend`, `split_spire`, `crown_bowl` | S6:188 |

The `bajada` row's `at` is the ramp stamp's centre, not a point on the line; the plot should skip it or draw it as an area (inference from S6:140). After the break: `crown_bowl` to `crown_apron` [0, 660], the bay and the gates (S6:166).

## Connecting material

The two principles this page is checked against: the movement loop reads an opening, rolls into it and uses momentum to reach the next (BIBLE:487), and every threat shows readable preparation and a visible vulnerability (BIBLE:491). So every beat above names one visible or audible pull, and every pressure names its telegraph.

**Signposting rules this world uses.**

| Says | Colour | Shape | Sound | Cite |
| --- | --- | --- | --- | --- |
| The Warden is that way | Uranium-glass green #9dff3c beam; only the ancients glow green | A vertical column from the landmark, through fog and cloud | The landmark hum under the band, rising as you near | PARK:119, S5:47, S5:51, S6:263, S6:334 |
| An activity is that way | Amber, from the activity row | Edge markers point at offscreen goals; site-specific shape still owed | None named | DV3:134, DV3:140-141 |
| Your verb works now | Mint | | | DV3:143 |
| Not yet; loss; damage coming | Slate; rust; hazard stripes | | | DV3:144 |
| A hostile event is coming | The hostile family's colour | The event's `form` row | A falling, pure sound and a riser over the lead | PARK:309, PARK:312 |
| A ride event is coming | | | A rising, breathy sound | PARK:309 |
| The Mind is here | Green seams on dull petrol enamel | A hand, never a pile or hive | Your motif played back inverted and wrong | MIND:24, MIND:31, MIND:35 |
| How far the run has come | The sun: golden on stage 5, dusk on stage 6 | | | PARK:389 |

The plate carries the order of play: "Find an activity" before engage while a site remains, "Break its guard" or "Smash the core" in the fight, "Roll through a gate" after the break (DV3:135-138).

**The three activities per stage, and where each is first seen.**

| Stage | Activity | Site | First seen | On the line |
| --- | --- | --- | --- | --- |
| 5 | `camp_moorings`, enemy camp | `mooring_mesa` [-250, -40] | From the drop-in (S5:205); up close on beat 4b, west fan | West line passes it (S5:205) |
| 5 | `altar_anvil`, ambush altar | `anvil_rock` [0, 60] | From the drop-in; up close on beat 6 | Waymark 2, every line (S5:205) |
| 5 | `bounty_ore_bench`, hauler bounty | `ore_bench` [330, -110] | From the drop-in; up close on beat 4c, east fan | East line passes it (S5:205) |
| 6 | `cache_turnstone`, cracked cache | `turnstone` [0, -315] | From the drop-in; up close on beat 3 | Waymark 1, every line (S6:200) |
| 6 | `camp_signal`, enemy camp | `signal_butte` [-440, 320] | From the drop-in; on beat 6b as a detour off the west line | Off the west line (S6:200) |
| 6 | `bounty_gauntlet`, hauler bounty | `gauntlet_shelf` [250, 365] | From the drop-in; up close on beat 6c | East lines (S6:200) |

Rows from S5:199-201 and S6:194-196.

**How the music carries across both stages into the fight.** Both stages play theme 2, stage 5 with the `highdraft` ACE set and stage 6 with `highdraft_crown`, under the same gem rules: keep the core, add layers, never swap, land the payoff on the gameplay moment (S5:330, S6:324). Each stage opens on the theme's intro bars over its own bed, wind then storm (S5:334, S6:328), lands its first drop on the first landing (S5:335, S6:329), adds a pump layer in its first chute (S5:336, S6:330) and lets the landmark hum rise under the band on approach (S5:340, S6:334). The fight grammar is the same on both: the pivot on engage, the wrong note on each charge, the key lift at half, the sinister break at three quarters, the unseal drop and the rice-cooker clear (S5:341-345, S6:335-339). Stage 6 adds one thing at the climax: the full quote returns on each stagger, naming your habit (S6:337). The Mind never joins the band, so the band is yours all the way to the gates (S5:330, S6:324).

## Gaps and calls

**Calls made here under the creative charge (veto list).**

1. **The launch flight is the seam, and it shows the next Warden.** Rolling through a stage 5 gate fires the stage launch: a rail of rings, speed kept, the next stage swapping in on the landing on the Watch Butte (LAUNCH:6-10, LAUNCH:40, PARK:273). The call is what the flight shows: the sky crossfades from golden to dusk across the arc and the storm and the Crown's beam rise ahead (PARK:389, S6:396), where the sources alone give a snap on landing. The bay stays the only stop, and it is opt-in (BAY:12-13).
2. **The ball stays out of every panel except the drop-ins**, per this wave's art rule. Panels that need the harpoon show the taut line running out of frame toward the camera (NEW S6-B, W-A, W-B). This departs from frames 6 and 8 as written, which put the ball in frame (S5:410, S6:401, S6:403).
3. **Copper, not brass, in every NEW brief.** The stage pages and the kind sheet call the Fleet's metal brass (S5:47, S6:46, S6:50); the briefs say copper per the wave's art rule. One of the two must change so the term is single.
4. **The Saddle's three pulls.** Centre: the chute mouth on the fall line, 170 m ahead at [0, -230] (S5:150). East: the tram station on the east lip and its falling cable (S5:158, S5:250). West: the West Shelf terrace and the hoodoo caps, with the Moorings' balloon beyond (S5:154-155, S5:42). The page names none of them as a pull. No marker is added.
5. **Fans cross over only at waymarks.** A player changes fan at the Saddle, the Anvil, the Turnstone or the split spire; nothing on either page offers a crossing between them (S5:133, S6:128).
6. **On stage 6 the perch clock starts at engage**, with the hand on the perch at [0, 18, 515] (MIND:197). The page does not say when the first flight comes; this makes it 8 s after engage.
7. **The quote is the approach read on both stages.** The page gives the beam and the hum; the kind sheet's engage quote is the moment the player learns the Warden is here (MIND:144).
8. **Beat 4a and the fin rim collapse share one panel** (NEW S5-B), so `p3_line` and the `p5_event` telegraph are one frame. The slab result gets no panel.
9. **The balloons pull the wing lines off the Anvil.** The two balloons on the lifts at [-210, 80] and [210, 80], just north of the Anvil and to either side, are the visible pull from beat 6 to beat 7b (S5:252-253). The page says the lifts are the way back up for a lost ball (S5:258); this call also reads them as the wing lines' sign.
10. **The floor line gets two optional bites.** A harpoon on a net post during the long carve (beat 7a, S5:139) and a line on the split spire as the floor line swings past (beat 5, S6:267, S6:153). Neither is needed; both teach the latch before the Warden to a player who takes no side fan.
11. **Fire from the line is taught on the needles.** The needle kites' counter offers shooting or swinging (S6:232); this call has you do both at once, shooting from a needle line (beat 6b). Whether today's weapon fires from a world line is unconfirmed: PARK:420 says so for a hardpoint line only.
12. **The lit lens seat is the hand's read on the west and east last fans.** The open lens seat is the current perch (S6:54), and the Warden frame draws it glowing (S6:401). From the needles at [-170, 180] or the Gauntlet Shelf at [220, 330] the perches are about 250 to 340 m away (inference from the row positions), past the 150 m at which the fingers read (MIND:21), so only a glow can carry. If it does not read, those lines see only the Crown and beam until engage.

**Gaps that go back to a source page.**

1. **Bay time, and what the launch flight shows and how long it lasts.** No page gives a time for the bay. The flight exists (PARK:273, PARK:493, LAUNCH:6-10), but no page says what it shows or how long it lasts on a park stage; today's flow flight is 0.6 s (LAUNCH:14). Stage 6's page gives the spawn (S6:445) but places no landing hill on the Watch Butte. Back to PARK.md section 6 (the run between stages).
2. **Pulls the pages leave unnamed.** This page names a pull for every pair, but several are calls or borrowed reads, not page facts: the Saddle's three (call 4), the balloons off the Anvil (call 9), and the Turnstone's centre and east pulls, borrowed from the drop-in frame (S6:396). Stage 6's west fan, the Turnstone to the west wash, still has none. Back to each stage page's section 3.
3. **Activity marker look.** vista-1 on stage 5 draws no markers, and DV3 says the site-specific marker shape is still owed (DV3:141). Back to the activity row spec.
4. **Fire from the line and the shrug reach the floor line late.** Stage 6 teaches fire from the line on the needles (call 11), and both stages teach the shrug with the line cutters (S5:235-236, S6:230), but only on side lines. The floor line uses no harpoon (S5:273, S6:267), so it meets both first at the Warden. Stage 5 teaches fire from the line nowhere; the roost kites sit off the lines (S5:239). Back to MIND section 4 and stage 5 section 7.
5. **Tier 2 events and skippers.** Tier 2 lands near the landmark for a skipper (S5:225), and pilot lines engage at 58 to 89 s, so the burner, the dropship and the Lens Rocks may fire during the fight. Back to stage 5 section 6 for a rule on events once engaged.
6. **Pictures missing or off-brief.** No picture shows the stage 5 chase cam, the fin rim collapse, the stage 6 drop ramp, the needles home, the split spire strike, the stage 6 approach, the harpoon line, the knock-down, either exit, the launch flight or the stage 5 mine fan; the 14 NEW briefs here cover all but the mine fan. vista-2 on stage 6 was drawn for `p5_event` but shows the Gauntlet (S6:399).
7. **Continuity faults in existing pictures.** park-crown vista-3 draws the hand on a mid-valley spire outside the bowl, which no mounting allows (MIND:87). warden-4's dark finger is ambiguous. Every Fleet structure is drawn brass. Back to the concept board fix list.
8. **Kind sheet cite drift.** MIND cites PARK.md:410 for the drop finisher and PARK.md:412-418 for the anchor rules; the lines are now PARK:414 and PARK:416-422 (MIND:51, MIND:102). Both stage pages cite PARK.md:311 for the 20 s calm; it is PARK:313 (S5:63, S6:60).
9. **Music holes.** Stage 6 names no layer for the alcove, the hoodoo forest, the toppled route or the crown ramp launch (S6:326-339). Stage 5 names none for the mine fan (S5:332-345), and neither page names a cue for the launch flight.
10. **Sight numbers are rough.** Both come from a box model on a 50 m grid, not Godot (S5:442-443, S6:432-433); stage 6's margin is thin (S6:52). If KD6's test fails, the Warden sightings on stage 6 move with it.
11. **The world 3 rescue.** Neither page places a rescue site; the cannon and the third ledger leaf wait for the Mind (AP:34, DV3:220). If Andrew wants a pilot moment inside the Highdraft, it belongs in the bay or on a stage page.
12. **Momentum check.** No beat stops the ball: events never stop it (PARK:310), the resist throws it (MIND:112), the bay never stops it (BAY:18-19) and the launch flight keeps horizontal speed exactly (LAUNCH:40). The bot has not confirmed any of this; nothing here ran in Godot (S5:443, S6:433).
