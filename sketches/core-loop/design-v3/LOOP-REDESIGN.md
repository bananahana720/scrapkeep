# Core-loop v3: why stay, where to hit, and stages that invite

Design only, no code. Answers playtest entry 8 (`docs/playtests/PLAYTEST-LOG.md`): Andrew won the whole demo as Rivet with 0 deaths, 0 events and 0 bonus cores, Wardens breaking at about 100, 108 and 117 s of stage time, and called it "a half-baked attempt". The bots said it first: the skipper clears every stage with no deaths and the completionist is only 1.6 to 2.9 times faster (`DESIGN-NOTES.md`, Feedback loop notes 7, 12 to 17). Eight tuning passes moved numbers, not structure.

Base: `proto/core-loop-v2` at 19fc173. Sources read: `DESIGN-V2.md`, `DEMO-SPEC.md`, `DESIGN-NOTES.md` (writer D, writer L, W4, W6, W7), `design-v2/WARDEN-DESIGN.md` (branch `proto/core-loop-v2-bossdesign`), `design-v2/I3-vertical-stage.md`, `design-v2/PROGRESSION.md`, `design-v2/visual-development/LAYERED-SPILLWAY.md`, `SOUND-STORY.md` §3, and the code under `src/core`, `src/world`, `src/combat/warden*.gd`, `src/build`, `tools/bot_driver.gd`, `tests/world_route_test.gd`.

The two research briefs are archived in git history: `research/R1-why-stay-and-windows.md` and `research/R2-five-games-replay-juice.md`. Both are web-search summaries (leads, not verified facts); §10 says which leads this design takes. Andrew's later direction, forwarded by the coordinator on the same day, is folded into §2 (the three reads), §7 (the fun lab), §8 (chaos and replay) and §9 (the interact key).

## 0. Diagnosis: four facts in the code that make skipping correct

| Fact | Where | Effect |
| --- | --- | --- |
| Breaking the Warden anywhere unseals the beacon, and the Warden needs nothing from the map. | `flow.gd:470-476`; `warden.gd` header ("Breaking it is the stage's one MUST") | The map is a hallway to the boss. |
| The body chips 20% below plating and shreds under fire, so a heft-1 gun finishes it. | `DEMO-SPEC.md` Rules "Plating"; `DESIGN-NOTES` L13 ("guns deal 70 to 90% of Warden damage"), L17 | Growth changes fight length, never whether you can fight. |
| The clock's reinforcement step grows only past the Warden break. | `director.gd:51` `PAST_BREAK_STEP`; W7 item 15 | The stay-longer pressure arrives after the stage's requirement is done. A skipper never meets it. |
| The route test enforces the funnel: scrap within 25 m of the spawn-to-beacon line, vault and events 40 m or more off it, a straight descent. | `tests/world_route_test.gd:6-12`; writer D items 22 to 25 | "The map funnels me": by contract. |

Everything Andrew loves is intact and orthogonal to these: the gunning, the rigid ball's weight, rebounds and pins, the three pilots, the gorge's rides, Moss's bay, the ball culture. The redesign changes what the Warden needs and where the stage puts it, and leaves those alone.

## 1. Why stay: three spines

The test for a spine: engaging the map is necessary to win, or so rewarding that skipping is a real, costly choice; a skilled player can still speedrun at a cost; and the ball (momentum, rebounds, routes) is the thing doing the engaging.

### Option A. The Drop Loop (recommended)

**One sentence.** The Warden only takes real damage from a ball that arrives on its open core at speed from above, and the stage is the run-up: a loop from the bowl back up to the shelves and down again, with every drop line passing loot, an event or a risk.

**The rule set.**

- The Warden's body takes 0 below plating. No chip, no shred. Slate means nothing lands, and the objective line says where to go instead.
- The weak point (the family's core, cell or lens) opens on the family's own mechanic, as today, at plating 0.
- Contact on the open weak point deals `heft × impact speed × K`. A ram at cruise across the bowl floor is below the plating and bounces. A ball off a drop line (a kicker lip, a chute mouth, a launcher, a glide from the sky layer) arrives at 25 to 40 m/s and lands a real hit. Starting value: 3 to 5 drops break a Warden at heft I, 2 at heft III.
- Weapon hits on the open weak point deal a small share and **hold the window open**, 0.1 s per hit up to 2 s. The gun's job in the fight is to keep the door open for the drop and to clear the packs on the loop. The gun still feels great; it just is not the hammer.
- A landed drop rebounds the ball off the core (restitution 0.65, the DESIGN-V2 §3 rule) out onto the bowl's 24° bank, which throws it toward the return contraption. The bowl is a bumper.
- Every stage has a return: a steam lift, geyser or cannon at the bowl's rim that throws the ball back to the shelf at 85% of its speed, the W6 transitions rule. A lap is bowl, return, shelf, a drop line, the Warden.
- Bonus cores keep setting the gate tier, and each one also opens every window 1 s longer this stage. The map's rewards feed the fight, not only the shop.

**Minute by minute (stage 1).**

| Time | Beat |
| --- | --- |
| 0:00 to 0:20 | The entry drop. The Warden is in sight in its bowl at the foot of the riser, dome shut, slate. Two chute mouths are visible from the deck with kicker lips at their ends, one aimed at the bowl. The objective line: "Drop on the Warden from a chute. 4 drops." |
| 0:20 to 0:45 | The first drop, taken cold. Down the west chute, off the lip, onto the dome as it opens after the vent: the core cracks, the badge loses a quarter, the ball rebounds up the bank into the return lift. Or the drop misses the window and the pulse throws you; the lift still takes you. |
| 0:45 to 1:30 | The lap. Back on the top shelf with speed. The scrap lines and the fabricator are on the loop, the stampede ring and the vault sit on the long line (the east chute). The clock ticks at 0:45; the first pack lands on the loop, not in the bowl. Choose: west again (fast, same hit) or east (longer, heavier ball, a bigger drop off the higher lip). |
| 1:30 to 2:30 | Second and third drops. Heft II now, so a drop takes a third instead of a quarter. The bowl floor has one fallout crater from the pulses you missed; the drop lines route around it. |
| 2:30 to 3:00 | The break on the fourth drop, the drop on the beat, the jaws let go, the gates open on the bank, Moss's cradle behind them. A tight lapper is out by 2:00; a completionist who took the stampede and the vault is out by 4:00 at heft III with a rare gate. |

**What stops the beeline.** Sitting in the bowl and holding fire does nothing to the body and only extends windows nobody is dropping through. Ram laps on the floor bounce. The only way to hurt it is to leave the bowl, climb, and come back down: the map is the weapon.

**How the clock prices staying.** Unchanged 45 s ticks and the +2 clamp, plus one reinforcement step per completed lap (the `PAST_BREAK_STEP` moves from "past the break" to "per lap", and stays past the break too). A lapper who does 3 tight laps meets 3 pack rolls; a completionist who does 5 laps with the vault and the event meets 5, heavier. The bank of the bowl is where packs are cheapest to bowl through, so growth shows there.

**Existing systems used.** Heft and punch (the drop's damage is `punch_now()` with impact speed as the force), the pulse and the family windows, the crater (WARDEN-DESIGN §9.1), cores (window length), the vault and events (on the drop lines), fabricators (on the loop), the W6 contraptions (return lifts and launchers reuse `steam_cycle.gd` and `ride_rail.gd`), the kickers (`Features.kicker`, `stage_map.kickers`), `route.gd` for the loop, Moss's bay unchanged, the counters (mag pits on the drop lines are the Fleet's answer to the drop). New: the impact rule on the weak point, the window-hold rule, returns on stages 1 and 3, the loop and drop-line data on `stage_map.gd`, two bot policies.

**How it serves the ball.** The whole fight is momentum: speed is damage, the bank is the rebound, the lap is the route. The pinball loop the Layered Spillway study asked for ("pressure return, middle landing") is the stage's spine, and its acceptance questions apply. Rebounds off the core and off a deflector's shield (the ×1.8 vault, DESIGN-V2 §10.6) become ways to set up the next drop.

**Risks.**

1. A hit-count boss can read as a Sonic chore. Counter: 3 to 5 drops, laps of 25 to 40 s, and every lap visibly cuts the count as heft grows.
2. Rivet's identity is the gun. Counter: the gun holds the window (the skill is timing the hold to the drop) and owns the loop's packs; Rivet's sprint is the fastest lap and ignores the counters on the drop lines.
3. Landing precision at 35 m/s may be too hard. Counter: the weak point's hit test forgives 15 to 20% beyond the drawn edge (DESIGN-V2 §4), the drop lines aim at the mast by geometry, and a missed drop still rebounds off the body and reaches the return.
4. Stage 1 and 3 need geometry (a return each, kicker lips). Both are additions to existing height functions, not rebuilds (§3).
5. The bowl camper must not be able to finish. Acceptance §4 checks it.

### Option B. Cut the Feeds

**One sentence.** The Warden is invulnerable while its feeds are live: three set pieces at the stage's landmarks, each a ride that ends in an impact (a pressure valve off a kicker, a tower cap off a grapple or vault, a hauler you run down), and each cut drops one plating band and opens the family cycle.

**Minute by minute.** 0:00 the drop, the Warden dark, its three jaw plates lit with the feed colour. 0:20 to 1:30 the nearest feed (the stampede's hauler on stage 1: run it down and the first plate goes dark). 1:30 to 2:30 the second feed (the valve behind the vault plinth) or straight to the bowl to fight a hard Warden with one plate dark. 2:30 the fight, the windows open as today, the gun and rams both land.

**What stops the beeline.** A Warden with three live feeds takes nothing from anything. One cut makes it fightable at full plating; three make it soft.

**Clock.** Each feed is off the line, so each costs a tick; a speedrunner cuts one and fights long, a completionist cuts three and fights short.

**Existing systems.** The three participatory events become the feeds (stampede, surge, relay) plus the vault as an optional fourth; contraptions for the valves; the family windows unchanged; the plating dress reads the feed count (three plates, three lights).

**Ball.** Each feed is a ride (kicker into a valve, grapple to a cap, a chase), but the fight itself stays a floor fight.

**Risks.** DEMO-SPEC rejected key and fuse collection gates (R-27) and kill-all gates (R-28); this is a key gate with better clothes, and Andrew would have to overrule R-27. Interchangeable feeds read as a checklist unless each is a different verb. It fixes why-stay without fixing the fight's "when and where", so §2 would still be needed on top.

### Option C. The Bell and the Laps

**One sentence.** The Risk of Rain charge zone, ball-culture: rolling into the bowl rings the bell, the Warden is dormant, the beacon charges one notch per lap of the stage's course while the director escalates per lap, and the Warden wakes at full charge. Extra laps before waking it strip its plating.

**Minute by minute.** 0:00 the drop, the bell visible. 0:30 ring it; the course lights (a `route.gd` loop with checkpoint arches). 0:30 to 2:30 three laps, each past the scrap lines, an event ring and the vault, each adding a pack roll. 2:30 the Warden wakes and fights on the bowl as today, weaker for every lap beyond the third.

**What stops the beeline.** The Warden is asleep until the laps are run. You cannot fight before the course is lapped.

**Clock.** Per lap, and 45 s ticks. Staying past the third lap trades pack pressure for plating.

**Existing systems.** The beacon's charge and ring (`beacon.gd`), the surge run's route and gates as the course, the director's spike, the family windows unchanged.

**Ball.** The course is racing, the ball's native mode; lap times are the par timer's natural unit.

**Risks.** DEMO-SPEC removed presence charge on purpose ("a run that only sits in the beacon ring cannot clear"); laps fix that, but the fight still needs nothing from the map once the Warden wakes, so the fight is still the v2 fight. A mandated three laps before the boss is a fixed tax the skilled player cannot shorten, which fails the speedrun test. And the gorge is the only stage with a loop today.

### Comparison and recommendation

| | A. Drop Loop | B. Cut the Feeds | C. Bell and Laps |
| --- | --- | --- | --- |
| Map necessary to win | Yes: the map is the weapon | Yes: one feed minimum | Yes: three laps minimum |
| Speedrun at a cost | Tight laps, low heft, more drops | One feed, hard fight | No: the laps are fixed |
| Fixes "when and where to hit" | Yes, the same rule | No | No |
| Ball-native | The fight is momentum | The feeds are rides | The laps are racing |
| Conflicts with a ruling | None | R-27, R-28 | "no presence charge" (DEMO-SPEC) |
| Stage work | Returns on 1 and 3, kicker lips | Feed sites at landmarks | Loops on 1 and 3 |
| Fight work | Impact and window-hold rules | None | None |

**Recommend A.** It is the only option where the same rule answers both of Andrew's complaints: the map matters because the fight is made of it, and "when and where to hit" is "from above, on the open core, now". B and C bolt a gate onto a fight that stays a floor fight. Elements of C survive inside A (the clock steps per lap; the par timer counts laps), and B's set pieces survive as things on the drop lines.

## 2. The Warden reads "when and where to hit"

One grammar for all three families, five states, each with an eye, an ear (SOUND-STORY §3 registers: threats low on Eb, Ab, Bb; rewards up the D minor pentatonic) and a place to be. The current weak points, the crater, the rack and the brace stay. The 20% chip goes, the shred on the body goes, and the caps and magnet lessons become family limbs (WARDEN-DESIGN §9.5).

| State | Length | Eye | Ear | Where to be |
| --- | --- | --- | --- | --- |
| **Closed** | until the ball is in reach | Jaws shut, dome shut, body slate, the crack a thin line. The badge shows drops remaining as segments, not a percentage. | The family idle in the level theme: Geiger tick once per 4 s, quartal hum, the motif fragment on sine. | On the loop. Nothing lands now, and the objective line says "Drop on it from the shelf". |
| **Telegraph** | 2 s (1.5 s at 75%) | The skirt vents open one by one round the ring, the INSTANT ring fills edge-in in HAZARD stripes, the stacks swell, the crack widens. | Ratchet clicks accelerating, the Ab pedal under the band. The click rate is the clock. | Off the bowl floor: on a drop line, on the bank, or in the air. Inside the core ring at the clang means the pulse throws you. |
| **Open** | 2.5 s reactor, 4 s hive, 5 s Mind, +1 s per bonus core, +0.1 s per weapon hit up to 2 s | The pulse fires (the skirt blasts down, the jaws clench once), then the dome halves hinge open, the core rises and blazes in the class-colour rim ("breaks now"), the crack is an eye looking at you. | The clang on the beat, then `weak_point_opened`: the family chord snaps open and the band drops to the pumping loop. Every weapon hit that holds the door adds a tick on the ready pulse. | **Arriving from above at speed.** The drop landing in the window is the hit. The gun from anywhere in reach holds the window for the drop. |
| **Punish** | on a miss | Reactor: the pulse's crater stays as a burning ring on the floor, so the bowl fills with hazard (WARDEN-DESIGN §9.1). Hive: the rack dives its lane. Mind: it quotes your last verb as a LANE down the line you used (§9.2). | The threat type's own sound in the family timbre: Geiger crackle, the swarm chord, the inverted motif. | Anywhere but where you just were. A miss is never a stop: the pulse lifts, the dive stings, the lane shoves, and the bank still throws you to the return. |
| **Recover** | 0.4 s close, then the cycle | The halves close with a departure ease, the crack stays lit a little brighter than before, the badge loses a segment if a drop landed, the jaws sag if the Mind was unplated. | The cadence back to the level theme; on a landed drop, the reward ladder up one note per segment lost. | Leaving the bowl on the rebound, toward the return contraption. |

**Family answers to the same grammar.**

| Family | What opens the window | Its limb (the old lesson) | Its punish |
| --- | --- | --- | --- |
| Reactor, stage 1 | Every pulse, on its own. The simplest fight on purpose. | none (`plate`) | The crater. Every missed pulse leaves a 5 s burning ring; at 75% the cycle shortens to 4.5 s. |
| Hive, stage 2 | Bowling through the ten-drone guard rack, which forms on the drop line between the chute lip and the cell. A drop through the rack scatters it and lands on the open cell in one motion: the army is the door. | The three vent caps become brood cells on the deck, a slam target at plating 0 (`caps` at ×1.5), the in-bowl chip path for a ball that has just been dived. | The rack dives; a scattered guard re-forms in 10 s (7 s at 75%). |
| Mind, stage 3 | Every 10 s it reads your most-used verb, shows its icon 1.2 s, then braces 5 s against that verb with the lens open. A player who alternates drop and gun always has an open lens. | The magnet arm becomes Arm_Reach: the tug drags a slow ball on the floor into the core ring (the punish), and a weapon hit on the arm mid-tug unplates the body 3 s (`magnet`, kept). | The quoted LANE strike down your last line, 1.4 s warn, 10 damage. |

**The three reads that must be unmistakable.** Andrew: "I was just going around in circles and I don't know if I was dodging, maybe I was, maybe I wasn't ... I had no idea what the heck I was supposed to be doing." Each read has one owner in the code so the layers cannot drift.

| Read | Owner | Eye | Ear | Rule |
| --- | --- | --- | --- | --- |
| **I dodged it** | `threat_grammar.gd` near-miss (W11's universal near-miss cue) plus the Warden's own | A committed telegraph the ball leaves within 0.3 s of its clang flashes its rim in the class colour and the ball trails a short streak; the pulse that fires on an empty core ring shows its blast as a hollow ring. A ball inside at the clang is thrown and the ring fills solid. | The near-miss whip (a rising class-colour swish) on the clang instead of the clang alone. Silence on the ratchet is the tell that you were never in it. | A dodge is a near-miss: inside the drawn threat during its telegraph, outside at its clang. The Warden's telegraph ring is the reach ring (30 m) only for the lift; the core ring (6 m) is the damage. Both are drawn, as today, so "am I in it" is a ring under the ball. |
| **It is open now** | `warden.gd` `weak_point_opened` | The dome halves open, the core rises and blazes with the class-colour rim (breaks now), and a vertical class-colour beam stands on the core for the window's length, shrinking as it runs out. It is the only beam in the bowl. | The family chord snaps open on the beat, the band drops to the pumping loop, and every held-door weapon hit ticks. | Open is a state, never a percentage: the beam is up or it is not. |
| **I am getting somewhere** | `warden.gd` integrity, drawn on the badge and on the body | The badge is a ring of drop segments (4 at heft I on stage 1). A landed drop cracks one segment off with a pop, and a piece of the god falls off (WARDEN-DESIGN §10's 50% shear, now per segment). Body damage outside a window is 0, so a segment never chips slowly; the ring only ever loses whole pieces. | The reward ladder climbs one note per segment lost; the break resolves it. | A Sekiro-style posture read (R1 §2): progress is whole steps earned by the intended verb, never a bar that creeps. |

The anticipation, active, recovery shape (R1 §2) maps to telegraph, pulse, open: the open window *is* the long recovery, which is why the punish states above are for a ball that stayed on the floor through the pulse, not for one that missed the drop.

**How the fight uses the arena and the ball.** The bowl is a bumper: land, rebound off the core onto the 24° bank, ride the bank into the return, climb, choose a line, drop. The pulse's lift is a tool inside the bowl (the bot already "takes its own pulse for height" for a slam): a slam off the lift onto a brood cell or the open core is the small in-bowl hit for a ball caught on the floor. Rebounds off a deflector on the bank give the ×1.8 vault, which is a drop line with no shelf. The three pilots drop differently, and the class card should say so: Sable vault-kicks off a tower face into the bowl, Rivet sprints the lip at +25% cruise, Kest glides off the sky and rocket-jumps back out.

**What the UI must carry (for the storyboard that follows).** The badge as drop segments; the objective line under 25 words ("Drop on the Warden from a chute. 3 drops left."); the window's remaining time as the class-colour rim's brightness, not a bar; the drop lines drawn as amber kicker lips (writer D item 5's movement colour), never HAZARD.

## 3. Stages that invite, not funnel

The rule that changes: `world_route_test`'s fall line (scrap within 25 m of the spawn-to-beacon line, side content 40 m off) becomes a loop with drop lines. Each stage keeps its landmark, its Warden bowl, its events and its vault, and gains a return and named drop lines. Prefer additions to `sample()` and `build_props()` over rebuilds.

| Stage | Shape | Landmark | Return (bowl to shelf) | Drop lines (fast, long) | Reward sightlines | Optional risk |
| --- | --- | --- | --- | --- | --- | --- |
| 1 Spillway | Loop: top shelf, two chutes, bowl at the riser foot, lift back up | The pump house (already built) and the Warden's stacks | A steam lift at the bowl's south rim (`steam_cycle.gd`, W6) that throws the ball to the top shelf's east landing beside the vault plinth | West chute with a kicker lip at its mouth aimed at the mast (fast, 15 m descent). East chute with a higher lip and a longer run past the stampede ring (long, bigger hit). | From the east landing you see the vault, the stampede ring's beam, and both chute mouths. From the bowl you see the lift's gauge. | The stampede on the east line (the hauler runs the east chute already, `map_spillway.gd:64-68`); mag pits on the west lip from the second lap. |
| 2 Cable Reach | Layered loop, already closed: bowl, geyser to the dish, marble run or glide or grapple down, shelf, skylight or tunnels down, canal, bowl | The dam-works tower, kept | The geyser (exists) | The canal's end gets a kicker lip into the bowl (fast). The skylight halfpipe gets a lip at its foot (long, from the east shelf past the reactor vent and the vault). The rack forms on whichever line the ball last used. | Unchanged: the tower from every layer, the bridges under the sightline | The cave-in and impact events reroute a drop line mid-stage; the crater becomes a third line. |
| 3 Weir | Loop: landing hill, the halfpipe south through the bowl, basin, cannon back to the hill | The relay mesa, kept | A cannon at the basin's south rim firing north up the dry causeway to the landing hill (the "trebuchet as public transport", DESIGN-V2 §15) | The halfpipe itself: pump its walls and come down on the Regard (fast, the call-and-response). The west wing's kickers (`KICKERS` at x −62) into the bowl from the side (long, past the surge run and the vault). | The mesa and the relay walls from the hill; the cannon's gauge from the bowl | The surge run's front chases you down the pipe: ride ahead of it and the pipe line is faster; the relay on the mesa is the slow line with the Mind's hands. |

**Change versus rebuild.**

- `map_spillway.gd`: change. Add the lift spec and a contraptions entry for stage 1 (contraptions today are the gorge's; `world.gd:248` already steps `contraptions[stage]`), add two kickers to `kickers` at the chute mouths (`Features.kicker` exists), move two scrap lines onto the east line. The chutes, bowl, bypass, basin and pump house stay.
- `map_gorge.gd`: change. Two kicker lips and the rack's spawn point on the drop lines. Nothing else.
- `map_weir.gd`: change. The cannon spec at the basin rim and the causeway as its landing; the surge gates stay on the pipe lips. The pipe, mesa, berm and kickers stay.
- `stage_map.gd`: add `loop` (a `route.gd` polyline), `drop_lines` (lip, direction, the mast as target) and `return_at`. `off_line()` measures distance from the loop, not the spawn-to-beacon segment.
- `world_route_test.gd`: rewrite as `world_loop_test.gd` (§4).

**Where the spine sits in space.** Every drop line starts on the shelf where the loot is and ends on the Warden, so the loot is on the way to the hit, never a detour from it. The vault and the event sit on the long line, the fabricator on the fast one. The return is the only piece of the loop with no choice, and it is a ride.

## 4. Acceptance you can measure before Andrew plays

Bot policies (`tools/bot_driver.gd` `POLICIES`): keep `skipper` (beeline, hold fire, ram laps: the v2 skipper is the new **camper**), add `lapper` (tight laps on the fast line, no loot, drops on every open window) and keep `completionist` (laps the long line, takes the event and the vault). The report (`tools/balance_report.gd`) gets the bands below.

| Criterion | Measure | Band | Test |
| --- | --- | --- | --- |
| The bowl camper cannot win | The v2 skipper's damage to Warden I within 240 s | 0 body damage; the run ends `stalled` | `loop_camper_test.gd` (a `loop_bot_test` variant) |
| The map is the weapon | Share of Warden damage landed by drops from a drop line | ≥ 80% for every policy that clears | `warden_impact_test.gd` |
| Skilled speed pays | Lapper stage time to break, stage 1 | 60 to 120 s, 3 to 5 drops | `loop_lapper_test.gd`, report band |
| Loot pays in the fight | Completionist fight length from first drop to break against the lapper's | ≤ 0.6× (a grown ball routs it) while its stage time is 1.5 to 2.5× (the clock priced it) | report band, 16 seeds per policy |
| The map is used | Share of stage ticks with the ball outside the bowl (r > 62 m, `Features.BOWL_OUT`) | ≥ 50% for every clearing policy; ≥ 2 distinct drop lines used per stage by the completionist | `loop_bot_test` notes |
| The window is legible | Windows shown before the break, each preceded by its full telegraph | ≥ 4 windows per stage; telegraph ≥ 1.5 s before every open; 0 damage taken by the Warden outside a window | `warden_window_test.gd` |
| Momentum holds | Ball speed after a landed drop against before | ≥ 0.6×, no hit-stop over 70 ms, no trapped ball in a crater | `warden_impact_test.gd`, `stage_terrain_events_test` |
| The loop closes | From the bowl floor, the return carries every class to the shelf at ≥ 85% speed; every drop line's arc from its lip reaches the mast's 3.2 m radius at ≥ 25 m/s | all three stages, all three classes | `world_loop_test.gd` (replaces `world_route_test.gd`), extends `stage_transitions_test` |
| The clock bites before the break | Packs met before the break by the lapper and completionist | lapper ≥ 2, completionist ≥ 4 | `world_director_test` |
| Nothing regresses | `sketch:smoke` green; `warden_family_test`, `combat_warden_lessons_test` updated for the no-chip body | | existing |

These measure structure, not fun. A green table is the gate to Andrew's play, never a verdict on it.

## 5. Build waves for Option A

Each wave is one writer. The Codex visual track owns `hero_assets.gd`, `warden_look.gd` appearance, `palette.gd` and the `terrain.gd` sky and material code; waves that need it say so.

| Wave | Files and seams | Depends on | Needs the visual track for |
| --- | --- | --- | --- |
| **A1 Warden rules** | `src/combat/warden.gd` (0 chip on the body, impact damage on the open weak point from `punch_now()` with impact speed, the window hold, per-core window length, the crater on the reactor pulse, the shortened cycle at 75%), `warden_kit.gd` (brood cells, Arm_Reach tug as punish), `combat.gd` (`plating_of` for the Warden), `stage_defs.gd` (`warden_drops`, new hints), `event_kinds.gd` rows (`warden_window_opened`, `warden_window_held`, `warden_drop_landed`). Tests: `combat_warden_test`, `warden_family_test`, new `warden_window_test`, `warden_impact_test`. | none | The dome open and close states and the crater's look in `warden_look.gd` (the code publishes the state; the track dresses it). |
| **A2 Stage 1 loop** | `src/world/map_spillway.gd` (lift spec, two kicker lips, scrap lines on the lines), `stage_map.gd` (`loop`, `drop_lines`, `return_at`, `off_line` on the loop), `contraptions.gd` (stage 1 entry), `world.gd` (contraptions for stage 1). Tests: new `world_loop_test` for stage 1, `stage_gate_sweep_test` for the lift. | none (parallel with A1) | The lift's prop look; the kicker lips take writer D's amber. |
| **A3 Stages 2 and 3 loops** | `map_gorge.gd` (two lips, the rack's line), `map_weir.gd` (cannon and causeway landing), `world_loop_test` for stages 2 and 3. | A2 (the `stage_map` fields) | The cannon prop. |
| **A4 Director and clock** | `director.gd` (reinforcement step per lap, keep the past-break step), `run_clock.gd` (lap count for the par ghost), `build_clock_test`. | A2 (the loop to count laps on) | none |
| **A5 Bots and report** | `tools/bot_driver.gd` (`lapper`, the camper as the old skipper), `tools/balance_report.gd` (the §4 bands), `loop_camper_test`, `loop_lapper_test`, `loop_bot_test` notes. | A1, A2, A3 | none |
| **A6 Words and sound** | `flow.gd` objective lines, `hud.gd` and `objective_view.gd` (drop segments on the badge), `audio.gd`, `sfx_bank.gd`, `music_engine.gd` (the window's drop, the held-door tick, the crater's crackle). `ui_word_budget_test`, `presentation_sfx_test`. | A1 | none, but the UI storyboard should land first for the badge and the objective line. |

| **A0 Fun lab** (before A1 to A6, if Andrew picks the sitting in §6 q10) | `tuning.gd` `loop_mode`, the launcher flag, `ui/tuning_panel.gd` row, the three mode branches in `warden.gd` and `flow.gd`, the stage 1 lift and lips (the same as A2's), the §7 loop-mode juice, the §9 four interactables (`world_prompt.gd`, `contraptions.gd`, a new `src/world/interactables.gd`). One writer per mode plus one for the interactables, about a day each, all on stage 1. | none | none (greybox) |
| **A7 Interact and interactables** | `src/world/interactables.gd` (the five families as rows, one shape, sound and prompt each), `world_prompt.gd` (keycap plus glyph), `player_ball.gd` (E routing: interactable in reach, else Sable's mount), `contraptions.gd` (roll-through consent lanes), `event_kinds.gd` rows. Tests: `world_interact_test`, `ui_key_glyph_test`. | A2 | The interactable props' look (the altar post, the cache, the housing) |
| **A8 Evolutions and cadence** | `src/build/parts.gd` (pair rows), `synergies.gd` (evolution as a synergy kind with a stack-cap trigger), `reward_gates.gd` (a gate per landed drop), `fabricators.gd` (a hoop per drop line), `shop.gd` (the rule part on the hook). Tests: `build_catalogue_test`, `build_synergy_test`. | A1 | The evolved rigs on the pod (`hero_assets.gd`) |

Serial where seams collide: A0 first if the sitting is chosen, its `drop` branch becoming A1 and A2 on acceptance; A1 and A2 in parallel; A3 after A2; A4 after A2; A5 after A1 to A3; A6 after A1; A7 after A2; A8 after A1. The gate to Andrew's play is A5's report at 16 seeds per policy with every §4 band green.

## 6. Open questions for Andrew (recommendation first)

**Andrew's answers (AskUserQuestion, 2026-09-28).**
- Fun lab: **Drop plus Laps against v2** as the control. Feeds is not built.
- Gun's role: **a lab toggle to feel both.** `hold` (the gun holds the window; drops deal the damage) against `full` (the gun deals full damage inside the window; drops are burst).
- Interact key: **E everywhere**, Sable's mount contextual when no interactable is in reach, Q stays the winch.

The other questions (camper, cores, clock, stage 1 return, drop counts, feeds, evolutions) take the recommended option (a) for the lab. They are revisited after the sitting.

1. **The gun's role in the Warden fight.** (a) The gun holds the window open and clears the packs; contact from a drop deals the damage. (b) The gun deals full damage inside the window, and the drop is a bonus. (c) Keep the 20% chip.
2. **The bowl camper.** (a) Cannot break the Warden at all: nothing but a drop lands. (b) Can, through in-bowl slams off the pulse lift, in about 4 minutes. (c) Can, at twice a lapper's time.
3. **Bonus cores in the fight.** (a) A core also opens every window 1 s longer this stage, and still sets the gate tier. (b) Gate tier only, as today.
4. **The clock per lap.** (a) Keep the 45 s ticks and add one reinforcement step per completed lap. (b) Ticks per lap only. (c) Unchanged.
5. **Stage 1's return.** (a) A steam lift at the bowl's south rim to the top shelf's east landing. (b) A geyser, reusing the gorge's. (c) A cannon.
6. **The drop count at heft I.** (a) 4 on stage 1, 5 on stage 2, 6 on stage 3, with heft cutting each. (b) 3 on every stage, with heft cutting to 2. (c) Fixed drops that heft does not cut, so growth shows only on the loop.
7. **Option B's set pieces.** (a) Not gated; they sit on the long lines as opt-in rewards, as today. (b) Overrule R-27 and gate the Warden behind one cut feed as well as the drops.
8. **The interact key.** (a) E everywhere, Sable's mount contextual when no interactable is in reach, Q stays the winch. (b) F for interact and move the specials elsewhere. (c) A new key.
9. **Evolutions.** (a) At the Warden break, from a capped part plus its pair, shown as a hint card. (b) At Moss's hook for scrap. (c) Not in the demo.
10. **The fun lab's sitting.** (a) Three modes plus `v2` as control on stage 1, ten minutes each, one entry with four sub-verdicts. (b) Only `drop` and `v2`. (c) Build the recommended option in full first.

## 7. Fun lab: iterate the loop fast

Andrew: "juice things up and maybe do so in a faster manner just so we can kind of nail down the gameplay loops just faster and really hone in on what's enjoyable." Priority is map and gameplay, not visuals. So the three spines go into one greybox build he can switch between in one sitting, on stage 1 only, with the smallest new props.

**The switch.** One `loop_mode` key in `tuning.gd` (`drop`, `feeds`, `laps`, `v2`), settable three ways: a launcher flag (`scrapkeep core-loop-v3 --loop=drop`, through `OS.get_cmdline_user_args()`), a row on the title screen's settings, and the tuning panel in-run (`ui/tuning_panel.gd`) so a mode can be flipped and the stage restarted with R. Every mode runs the same stage, enemies, loot and Warden; the mode changes only the Warden's damage rule, the stage's gating and the objective line. The run log tags the mode so the bots and the report split by it.

**Each mode's build, about one writer-day.**

| Mode | What it needs beyond v2 | Props | Reuses |
| --- | --- | --- | --- |
| `drop` | The impact rule and window hold in `warden.gd`; 0 chip on the body; two kicker lips at the chute mouths (`Features.kicker`, exists); one return: a steam lift at the bowl rim (`steam_cycle.gd` and `ride_rail.gd`, exist) | A lift piston box and gauge (the gorge's lift, copied), two amber lips | Everything else |
| `feeds` | Three feed flags on the Warden (invulnerable while any is lit); the stampede win, the vault break and one valve smash (`contraptions.gd` valve, exists) each clear one | Three lit jaw plates (a colour on the existing plates), one valve prop from the gorge | Events and vault as they are |
| `laps` | A `route.gd` loop with five checkpoint rings (the surge run's gate ring, exists); the beacon charges one notch per lap; the Warden dormant until full; the same lift as `drop` for the return | Five rings, the lift | The beacon's ring and notches |

**Juice the lab needs for fun to be judgeable at all.** W11 is building the universal layer: hit-stop, camera kick, kill chains, pickup magnetism and pitch climbs, near-miss cues, damage-taken reads. The lab assumes those. What belongs to the loop modes, because it is what makes each spine legible:

| Belongs to the loop modes | Mode | Why it cannot wait for polish |
| --- | --- | --- |
| The drop landing: 70 ms hit-stop, FOV punch, a segment popping off the badge with a chunk of the god falling, the reward note, and the rebound's spring snap pitched by impact speed | `drop` | Without it a drop reads as a bump, and the whole spine is the drop |
| The window beam standing on the core and shrinking, the held-door tick per gun hit | `drop` | "It is open now" is the read Andrew lacked |
| The plate going dark with a chord dropping out of the theme | `feeds` | The only progress read the mode has |
| The lap notch: a checkpoint ring's pop, the beacon's notch, the director's `threat_rose` stinger on the same beat | `laps` | The lap must feel like a lap |
| The return contraption's fire: steam puff, the launch arpeggio, the arc rings | all | A ride that does not feel like a ride is a stop |
| The near-miss whip on the Warden's pulse specifically | all | "did I dodge" |

Left for later: pickup fountains beyond W11's magnetism, kill-chain banners, screen-filling late-run effects, any Blender prop.

**Sitting.** Play each mode for 10 minutes on stage 1, `v2` last as the control. Ask after each: did you know where to be, did you know you were getting somewhere, would you leave the bowl on purpose, and would you do it again. Log the verdicts as one playtest entry with four sub-verdicts.

**Bots first.** Before the sitting, run the §4 bands per mode. A mode the camper still clears is not ready to be played.

## 8. Chaos and replay: "go nuts, go butts"

Andrew wants a love project in the family of Isaac, Gunfire Reborn, Risk of Rain, Hades and Vampire Survivors: "crazy chaotic mess ... fun and dynamic and unique run capability to make me keep coming back over and over." R2's comparison says what those games share: builds that snowball into screen-filling power, a pace of small picks, difficulty priced against power, surprise rule changes, and visible growth. What v2 already has: 61 parts with 12 triggers, 9 named synergies plus accidental ones, the accretion chunks on the ball, the binary tree with 16 ends, the 45 s clock. What is missing is the *snowball* (a synergy changes behaviour once; nothing compounds) and the *cadence* (a pick every stage, not every minute).

**How runs escalate, in Option A.**

- **Pick cadence per lap.** A fabricator hoop stands on every drop line, and a gate opens on the bank after every landed drop, not only after the break. A tight stage 1 is 4 picks; a full one is 8. The picks are small (common and uncommon) so the bank's gate after the break stays the big one. This is Vampire Survivors' level-up rhythm at the ball's speed.
- **Evolutions at the break (R2, the coordinator's pick).** A part at its stack cap held with its paired part evolves when the Warden breaks: the jaws let go and the evolved part is what the mast hands you. Starting pairs from the existing catalogue: Spiral Wave plus Double Feed is a screen-filling spiral; Chain Arc plus Tesla Pylon is an arc field that follows the ball; Wrecking Ball plus Ballast Drum is a crush that rolls the bowl's packs up as scrap. The codex shows the pair as a hint card ("Spiral Wave at cap + something that feeds"), so the run has a goal from the first pick. Evolutions are the snowball: each makes the loop's packs a fountain, and the director's build-tilt (W7 item 16) answers it with the pack that tests it.
- **Arcana-like rule drops at set moments.** The bay's tree pick already changes a key; add one *rule part* per bay visit on Moss's top hook, rare_plus, that changes a rule for the rest of the run: every rebound is a pin, drops open windows for everyone in reach, the clock's packs drop cores. Three per run at most, so the run has a shape.
- **The clock against power.** Kept from RoR: 45 s ticks plus a step per lap, clamped, packs never toughness. By stage 3 a snowballed build meets six-pack laps, and the screen is full both ways.
- **Visible stacking.** The accretion chunks already bulk the ball by slot (V3 item 4). Add: an evolved part gets a rig on the pod (a spiral vane, an arc mast, a wrecking chain) so the build reads from across the bowl. Codex visual track work; the seam is `hero_assets.gd`'s `class_accent` slot.

**How runs differ.**

- The stage's drop lines and the loop are fixed; what is on them is seeded per run: which line the event ring sits on, where the vault stands, which packs the director draws for the build, which interactables (§9) spawn where.
- The tree's 16 ends times three pilots times the evolution pairs is the build space; the run log's `build_id` (parts plus tree) should be reported so the report can say how many distinct builds the bots and Andrew reached.
- Replay hooks beyond the run: the codex treasure hunt (exists), evolution pairs discovered (the hint cards), the par ghost per stage and per lap, mastery unlocks opening alternate tree branches (PROGRESSION §2), and the friendly-ancient thread. RoR2 unlocks and Hades' heat both say the same thing: the second run needs a reason the first run gave it.

**In B and C.** The same cadence and evolutions work in both; the difference is where the picks stand (on feeds, on laps). Neither spine changes the snowball; only the Drop Loop makes the snowball show in the fight, because the drop's damage reads heft and the window reads cores.

### Anticipation: "I want to see what this becomes"

Andrew, clarifying that his notes are direction, not specs: "juicy feedback ... eye candy ... where I'm wanting to know what's gonna happen next with these upgrades that I'm about to get ... a little bit more creativity and discovery." So anticipation is a design goal, and discovery means learning by experimenting, not reading. The rule for every option: **every reward is previewed before it is earned, and every preview is a shape you can already see, never a line of text.**

| Tease | What the player sees before they have it | Owner today | Discovery, not reading |
| --- | --- | --- | --- |
| **A part hints at its evolution** | A part at cap grows a dark socket on its accretion chunk in the shape of its pair's family glyph; the socket glows when its pair is offered at a gate ("* completes *" already pulses). The evolution's name is never shown until it happens. | `accretion.gd`, `reward_gates.gd` pulse (exists), `hero_assets.gd` chunk slots | The socket's shape is the only clue; the codex names the pair after the first evolution |
| **A half-built rig on the ball** | The tree's next pick is a bare bracket on the pod (a mast stub, a fin hinge, a satchel strap) from the moment the pick opens at the bay's catch; the pick fills it. Sixteen ends, so the rig reads which branch you are on. | `upgrade_tree.gd`, `hero_assets.gd` `class_accent` slot (Codex visual track) | The bracket says where, not what |
| **A locked thing you can see before you can afford it** | Moss's top-shelf hook (exists, heft-locked). Add: the dormant ally drone on its housing on the loop, seam dark, with the scrap cost as a pressure dial; the rigged cache's odds dial; the timed door's par over the gate. All in view from the loop before the first lap ends. | `shop.gd` (exists), §9 interactables | The dial is the ask; trying is how you learn what it does |
| **The Warden's break reward, previewed before the fight** | On the beacon mast, above the jaws, the break reward hangs in a cage from the first sight at the entry drop: the gate toppers' rarity frames (V3 item 10) and, when an evolution is armed, the evolved part's silhouette rotating in the cage. Cores add frames to the cage as you socket them. Breaking the Warden drops the cage. | `flow.gd` (`beacon_unsealed`), `reward_gates.gd` tier from `bonus_cores`, `beacon.gd` mast | You see the rare frame appear when the second core sockets; nobody tells you the rule |
| **The next drop line's payoff** | From the east landing, the long line's event beam and the vault's plinth are in view (§3 sightlines); a line with a challenge post shows its part's family glyph on the post. | `map_spillway.gd` props, §9 prompt grammar at 30 m | Hades' door preview, in the ground |
| **The window's next length** | The core's beam shows the window's length as its height; a socketed core visibly adds a band. | `warden.gd`, `warden_look.gd` | You watch the beam grow |

**Per option.**

- **A. Drop Loop.** The cage on the mast is the strongest tease the game can have, because the whole loop runs under it: every lap you pass beneath the thing you are earning, and every core you socket adds a frame to it. The drop count on the badge is the same tease inverted: each segment is one lap closer. The ball's half-built rig and the evolution sockets ride the loop with you and are seen at the bank before every drop.
- **B. Cut the Feeds.** The three lit plates are the tease: each feed's prize (the plate going dark, and a preview of what the fight becomes) is visible from the bowl. Weaker: the reward is "a shorter fight", which previews as less, not more.
- **C. Bell and Laps.** The beacon's notches count laps toward the wake, and each lap's checkpoint ring could hold the next pick's family glyph. Weaker: the tease is a bar filling, not a shape becoming.

**Fun-lab minimum.** The cage on the mast with the tier frames (a copy of the gate topper meshes, no Blender), the evolution socket on one capped part, and the ally drone's housing with its dial. Three teases, all reused geometry, so the sitting can judge whether "what's next" pulls.

## 9. The interact key and the map's interactables

Andrew asked for "the same universal interaction key" for consenting to travel, starting a fight, treasure hunting and switching on temporary allies, and said what he loves is discovering how to use the environment, finding treasure, and taking risks that "can really hit or miss depending on either luck or skill". Interactables are where the map's value lives; the spine says why you are on the loop, the interactables say what you find there.

**The key: E is interact everywhere. Sable's mount is E in context.** Today E is Sable's mount and Q her winch (DESIGN-V2 §1). The rule:

- E does the interactable in reach (within 6 m, facing within 60°). If none is in reach and the ball is at a steep face or hook, E mounts. Interactables win because they are rarer and chosen; a face is everywhere.
- The prompt says which: the world prompt (`world_prompt.gd`, exists) shows the E keycap with the interactable's glyph beside it; Sable's mount shows the keycap with the pylon ring glyph. One keycap, two glyphs, never both at once.
- Q stays the winch. Nothing else moves.

**Consent at speed.** Nothing forces a stop unless the player chooses it.

- **Roll-through consent.** A travel device arms when E is pressed inside its approach lane (a 12 m lane drawn on the ground in amber); the device fires when the ball crosses its mouth at any speed. Press early, keep rolling. Missing the mouth costs nothing.
- **Hold-to-arm (0.35 s)** for anything with a cost or a risk: allies, bets, calling the Warden. The gauge is the class ring around the reticle, the same as a skill shot. A tap does nothing, so nothing misfires.
- **Stop-and-choose only where the player stops on purpose**: Moss's shelf, and a cache's three-choice altar.

**The vocabulary.** Each family has one shape, one sound register and one prompt so the player learns five things, not fifty. Every shape reuses a form in the game already.

| Family | Shape and colour | Sound (SOUND-STORY registers) | Prompt | Members | Feeds the spine by |
| --- | --- | --- | --- | --- | --- |
| **Travel** (consent to go from A to B) | The contraption itself with an amber approach lane and its bone gauge; the arc's rings show the destination before commitment (LAYERED-SPILLWAY acceptance 2) | The launch arpeggio on release, pitched by speed; the gauge's tick | E, roll-through | Cannon, trebuchet, cable, lift, geyser, the bowl's return | The return and the long drop lines are travel; a class's best route is which travel it takes |
| **Opt-in fights** | A copper post with a HAZARD-striped cap and a ring on the ground (the event ring's shape, in the enemy colour) | A brass anvil hit on arm, the miniboss riser | E, hold 0.35 s | Ambush altar (a pack now, a core if you clear it in 30 s); challenge post (a timed pack on the drop line, a part); **call the Warden**: open every window 2 s longer this stage, but the clock jumps a tier now | Fights are cores and parts, on the lines; the Warden call is the speedrunner's gamble |
| **Secrets and treasure** | Verdigris concrete with a charcoal groove (the ancient seam) on a wall, a floor plate or a cache; a sunken bell pings before it is seen (I3) | The codex's discovery burst for a find; a cracked wall's crumble | E to open, or a smash or sprint at speed | Cracked walls (exist: Rivet's sprint wall), buried caches (a plate you slam), marble-maze vaults (a lap under par opens the door, I3's pit-stop lap made a vault) | Treasure is scrap and codex, so heft and the hunt |
| **Temporary allies** | A dormant dug-up drone on a housing with its blue seam dark; lit mint when running (the friendly-ancient thread, C11 "Awaiting operator") | The class motif on sine while it runs; a Cherenkov flicker on wake | E, hold 0.35 s, costs scrap (so it lowers heft, the wording says so) | A pin-carrier drone that follows for 30 s and rams what you rebound off; a turret housing on the bank that holds the Warden's window 1 s; a lift drone that refreshes one air jump per lap | Allies buy fight time with map scrap: the ball-culture form of RoR's drones, not their shape |
| **Risk bets** (hit or miss on luck or skill) | A rigged cache: a copper crate with a HAZARD stripe and a dial showing the odds; a timed trial: a gate with a par timer over it (Dead Cells' timed door, R1) | A drum roll on the hold, the slot-machine clunk on the roll, the crit crack on a hit, the dry refusal bone on a miss | E, hold 0.35 s | Double-or-nothing (bank your bonus cores: heads doubles, tails burns them); a cursed cache (a rare_plus part, then one hit kills for the next 5 enemies); a timed drop trial (land the next drop within 20 s for a gate tier up) | Bets are the "hit or miss" Andrew named; they price the loop's value in luck or skill |

**Smallest set for the fun lab (stage 1, one writer-day on top of the mode builds).** The lift as travel with roll-through E (needed by `drop` and `laps` anyway); one ambush altar on the east line; one cracked wall behind the vault plinth hiding a cache; one double-or-nothing crate at the bay's cradle. Four interactables, four families, one key. Allies wait for the second sitting because they need the drone's brain.

**Prompt grammar.** Every interactable shows, at 30 m, its family glyph over it; at 6 m, the E keycap plus the glyph plus at most five words ("Arm: 2 cores, 30 s"). Hold prompts fill the class ring. A device that is not ready shows its gauge and no keycap. This is W1's five-word rule and the keycap contract, unchanged.

## 10. What the research briefs gave this design

From `research/R1-why-stay-and-windows.md` and `research/R2-five-games-replay-juice.md` (archived in git history), both web-summary leads.

| Lead | Where it landed |
| --- | --- |
| RoR2 teleporter: a fixed zone that does not hard-gate exploration | Option C's shape; Option A keeps the clock and refuses the presence charge DEMO-SPEC removed |
| Dead Cells timed doors and cursed chests | §9 risk bets (the timed drop trial, the cursed cache); the par ghost per lap |
| Hades reward on the door, a skull for harder-but-richer | §9's family glyph at 30 m with the cost line; the Warden call's "longer windows, higher tier" |
| Anticipation, active, recovery with a long recovery | §2: the open window is the recovery |
| Sekiro posture as visible progress to the break | §2: drop segments, never a creeping bar |
| Titanfall and Sonic multi-path heights, Tony Hawk geometry as a combo instrument | §3: two drop lines per stage at different heights; the bank-lift-lip chain as the combo |
| Card plus ability preview for select | Out of scope; §12 says what the card must carry |
| Vampire Survivors evolutions from a maxed part plus its pair at a chest | §8: evolutions at the Warden break |
| Arcana-like rule drops at set moments; a frequent pick cadence | §8: the rule part on Moss's hook; the hoop per line and gate per drop |
| RoR2 clock versus power; visible stacking on the ball | §8: kept and extended; rigs on the pod |
| Layer four feedback types on a violent action; greybox before art | §7: the loop-mode juice list and the lab |

## 11. Storyboards: the first three minutes of stage 1, per option

Each is the base for a visual storyboard. Columns: what the player sees, what they do.

### A. The Drop Loop

| t | Sees | Does |
| --- | --- | --- |
| 0:00 | The landing pad on the drop deck; 150 m down, the Pile in its bowl, dome shut, slate, stacks dark; two chute mouths with amber lips, the west one pointing at the mast; the objective line "Drop on the Warden from a chute. 4 drops." | Lands at 21 m/s and rolls for the west chute. |
| 0:12 | The chute's kerbs; the scrap line down its middle; the fabricator hoop. | Rolls the line, takes the hoop, 25 m/s at the lip. |
| 0:20 | Off the lip: the bowl below, the reach ring filling in HAZARD stripes, ratchet clicks accelerating, the stacks swelling. | Is in the air over the bowl as the clang lands. |
| 0:22 | The dome splits, the core blazes with a copper rim, the crack an eye. | Lands on it. The first segment of the badge cracks off; the ball rebounds up the bank at 20 m/s. The band drops. |
| 0:26 | The lift's bone gauge at the south rim, needle near full; the crater ring burning behind. | Rides the bank into the lift; it fires; the top shelf swings into view. |
| 0:32 | The east landing beside the vault plinth (copper, slate-tinted: not yet); the stampede's beam over its ring; both chute mouths ahead. | Chooses. West is the same hit again in 20 s; east is the long line. |
| 0:45 | `threat_rose` on the beat; a Fleet pack's rings on the west lip; a mag trapper's disc. | Takes the east line this lap: the stampede ring. |
| 0:55 to 1:30 | The hauler bolting down the east chute; scrap bursting off it; the bonus core socketing on the third ram; the east lip, higher, 32 m/s. | Runs it down, comes off the east lip heavy (heft II). |
| 1:33 | The telegraph again; this time from higher, longer in the air; the dome opens; the rim brighter (the core bought 1 s). | Lands. Two segments go, not one. Rebound, bank, lift. |
| 1:40 to 2:20 | The vault, now amber (punch beats its plating); the pack on the west lip bowled through on the way. | Breaks the vault, second core, takes the west line. |
| 2:25 | The fourth drop on a 2.5 s window now 4.5 s long. | Lands. The jaws let go on the beat, the mast lights mint, the gates on the bank, the cradle behind them. |
| 2:40 to 3:00 | Three gates with rare toppers (two cores); Moss's cradle above. | Takes a gate, or the bay first. |

### B. Cut the Feeds

| t | Sees | Does |
| --- | --- | --- |
| 0:00 | The Pile in the bowl, three jaw plates lit in the feed colour, a beam over each feed: the pump house, the vault plinth, the bowl's own valve. Objective: "Cut a feed. The Warden is sealed." | Lands, picks the nearest beam. |
| 0:20 to 1:10 | The stampede ring at the pump house; the hauler; three rams; the hauler dies and the first plate goes dark, a chord dropping out of the theme. | Runs the hauler down. |
| 1:10 to 1:50 | The valve behind the vault plinth, a kicker in front of it. | Kicks off the lip into the valve; the second plate goes dark. Or skips it. |
| 1:50 to 3:00 | The bowl, the Warden fightable at plating 45 with one plate lit (or 15 with none); the pulse, the window, ram laps and the gun. | The v2 fight, shorter for each plate cut. |

### C. The Bell and the Laps

| t | Sees | Does |
| --- | --- | --- |
| 0:00 | The Pile asleep, jaws open, no glow; a bell on the mast; a chain of checkpoint arches down the west chute, across the mid shelf, up a lift, round the top shelf. Objective: "Ring the bell. Lap the course." | Lands, rolls to the bowl, rings it. |
| 0:25 | The course lights amber; the beacon's ring shows three notches; the director's first pack lands on the course. | Lap one: the chute, the arches, the lift, the shelf. |
| 1:00 to 2:10 | Notch one; the stampede ring beside the course; the vault on the top shelf; a heavier pack each lap. | Laps two and three, or a fourth for a stripped Warden. |
| 2:15 | The bell's third strike; the Pile wakes, jaws shut, the crack lights; the v2 fight. | Fights it as today. |

## 12. What this needs from the UI storyboard (out of scope here)

- The class card must say each pilot's drop: Sable vault-kicks off a face, Rivet sprints the lip, Kest glides in and rocket-jumps out.
- The Tab notes should be a picture of the loop: the lap with its drop lines, the return, the loot on each line, and the Warden's five states as a ring. No essay.
- The badge shows drops remaining as segments. The window's time left is the rim's brightness. The objective line stays under 25 words.
