# Rivet: pilot sheet

Status: historical wave 13 design sheet (`unit A2`, 2026-10-10, `runner_gunner`); kit rows, line skill (`line_drive`), and ultimate (`foundry_cutter`) have since landed in `sketches/core-loop/src/` (`PILOT-CADENCE.md` owns current weapon timing). Paths without a prefix are under `sketches/core-loop/`. A number marked **start** was a starting tune value. A line marked **Call** is a decision made under the creative charge; section 11 lists them as the veto list.

**Weapon fire (ruling ek, 22 Nov 2026):** how this pilot's weapon fires, with its timers, damage and first tree pick, is now [PILOT-CADENCE.md](../PILOT-CADENCE.md) section 3.1. Where this sheet's weapon text differs, that page wins.

Reads with: [SKILL-BAR.md](../SKILL-BAR.md) (the bar, the line-skill hook and the set-piece contract; this sheet uses its names exactly), [ROSTER-LOOK.md](../ROSTER-LOOK.md) (the Hoberman mecha, section 0) and the sibling sheets in this folder. It supersedes the Rivet kit text in `design-v2/I1-character-kits.md:56-77`, `DESIGN-V2.md:30-50` and `docs/CHARACTER-BIBLE.md:64-74` where they disagree. The code wins over all three: Rivet's colour is copper (`src/core/class_def.gd:14`), not the mint of `CHARACTER-BIBLE.md:68`, and the sprint is on Shift (`src/movement/player_ball.gd:484-495`), not the RMB of `DESIGN-V2.md:34`.

Terms used here, defined once:

- **Punch**: Line Drive on a machine. The winch kicks force down the cable and throws the machine away from Rivet.
- **Haul**: Line Drive on a wall or post. The winch drags Rivet to the anchor in a straight line, and crowd control slides off.
- **Breach Skid**: the landing of every Rivet set piece. A forward skid that strikes a cone ahead and keeps the ball rolling.
- **Pin**: a thrown machine that hits another (`src/combat/weapons.gd:213-221`).

## 1. Fantasy and difference

**Fantasy in one line.** A nearly blind mole machinist who cannot be stopped: he holds a laser-true line of fire, shrugs off every hold, kicks force down the cable, and drives one measured cut from here to there.

**Rivet in one rule:** everything Rivet does runs in a straight line and turns back into forward speed.

| Axis | Rivet | The other five |
| --- | --- | --- |
| Answer to crowd control | Ignores it. The sprint shuts the crowd-control door (`player_ball.gd:357-367`); the haul and Juggernaut Drive do the same | They dodge, hide, clamp first or spend a resource to break free |
| Weapon | Held, 12 bolts a second, no spread, 85 m (`weapons.gd:22-33`) | Sable's arc bolts chain at 5 a second (`:34-35`), Kest lobs charges, Tarn sweeps at 5 m, Tally runs cards, the Cannon commits lanes |
| Line flavour | **Force away from Rivet.** The punch throws the machine down the cable; the haul drags Rivet in, unstoppable | Sable swings and leaves faster, Kest sends a payload, Tarn drags the target to him, Tally clips it, the Cannon fires a lane through it (plan table, settled today) |
| Smash | No plant. The fall becomes forward speed (`augments.gd:501-514`) | The other five plant, pull in, scatter charges, stamp or ring |
| Ultimate tech | One hand-aimed beam on the reticle, cutting on every beat | The framework default is auto-targeted volleys (SKILL-BAR section 4); no sibling sheet uses a beam |
| Ultimate landing | A forward cone that keeps Rivet rolling on the ground at his banked speed, with a sprint charge in hand (the speed gift belongs to Sable alone, A2-CRITIC) | Round landings, launches and flings |
| Juggle | Difficulty 1 (`src/ui/class_kit.gd:71`). One gauge on the bar; every other input is a hold or a tap | Sable, Tally and the Cannon 3; Kest and Tarn 2 |

**Four force shapes, four jobs.** Rivet's kit pushes things a lot, so each push has its own shape and purpose. The shapes are all chevrons pointing out from him, his class shape (`class_def.gd:97`).

| Shape | Ability | Job |
| --- | --- | --- |
| Ring, around the ball | Overdrive Blast (slot 2) | Get them off me, then gun faster |
| Line, one machine at range | Line Drive punch (slot 3) | Bowl the lead machine into the file behind it |
| Cone, ahead on the ground | Shockwave Skid (Ctrl) and the Breach Skid landing | Clear the road and keep rolling |
| Beam, no knock | Foundry Cutter (Q) | Cut through a line of machines with precision |

**Never a reskin of an enemy.** Rivet's drill never bores the floor, which is the drill crew's mechanic (`src/combat/drill_crew.gd:3-6`). Rivet never burrows, which is the burrower's (`src/combat/burrower.gd:3-6`). The drill nose is the lens housing; the cut is light. Rivet's beam is instant and steered by hand, so it never reads as the Cannon's committed lane, which lands after a delay.

## 2. Kit

| Place | Ability (id) | Fire shape | Numbers | Today's code | New |
| --- | --- | --- | --- | --- | --- |
| 1, home | Rapid Laser (`rapid_laser`) | auto: hold left click | 7 damage, 12 a second (84 a second), 85 m, bolt 190 m/s, radius 0.25 m, knock 3 (`weapons.gd:32-33`, `src/core/event_kinds.gd:248`). x1.6 rate while boosted (`combat.gd:1130-1134`) | All of it | Nothing. It is home and never snaps back |
| 2 | Overdrive Blast (`overdrive_blast`) | gauge: hold left click, release | Gauge 1.0 s, grace 0.5 s (`ability_state.gd:56`, `:86`). Ring 12 m tapped to 18 m full; damage 30 to 45; knock 34 to 51 (`weapons.gd:61-67`). Then 3 s of laser rate x1.6, stacking to 6 s (`:64-65`, `:247`). Cooldown 6.0 s | `_specials` row and fire path (`combat.gd:298`, `:1400-1410`, `:1936-1964`) | Picked with 2 and cast with left click instead of F (SKILL-BAR section 1) |
| 3 | Line Drive (`line_drive`) | tap | Punch: a ram at 60% of the ball's speed, knock 34. Haul: 24 m/s, crowd control slides off. Cooldown 8.0 s, 1 charge, load 4.0 s **start** | The harpoon, the ram rule and the rail maths it reuses | All of it. Full spec in 2.3 |
| Shift chip | Overdrive Sprint (`overdrive_sprint`) | hold | 1 charge, 2.0 s, cooldown 5.0 s (`ability_state.gd:55`). Cruise x1.25 (`augments.gd:101`). Contact punch x1.25 (`weapons.gd:224`). Rebounds only off weight of at least heft x1.0, not x1.15 (`DESIGN-V2.md:56`, `player_ball.gd:1121-1125`) | `_sprint` (`augments.gd:215-247`), the crowd-control door (`player_ball.gd:357-367`) | A verb chip readout only; never selectable |
| Ctrl chip | Shockwave Skid (`shockwave_skid`) | instant, airborne | The shared slam: 9 m ring, knock 26 x strength (`augments.gd:67-68`, `player_ball.gd:891-904`). The skid: no plant, exit speed is the speed along the ground plus 0.6 of the fall (`augments.gd:119`, `:503-514`). Cone ahead 10 m, half-angle 70 degrees, knock 26 x strength x falloff, +0.5 s of sprint back per hit (`player_ball.gd:43-47`, `:966-982`) | All of it | A verb chip readout and the `smash` clip |
| Q | Foundry Cutter (`foundry_cutter`) | press at a full meter | A ride on the framework paths. One beam, 40 m, cutting 3 machines a beat for 12 x heft multiplier. Peak sweep 90 degrees, 18 x heft. Breach Skid landing 60 x heft multiplier x chain multiplier **start** | The rail maths, the aim query and the skid it reuses | All of it. Full spec in section 3 |

### 2.1 Slot 1: Rapid Laser

What it does: the laser-true gun. Hold left click and it never stops (`weapons.gd:22-23`). Andrew's ruling stands: "the gunning feels great" (`DESIGN-V2.md:33`).

Sees and hears: copper bolts (`weapons.gd:150-151`). Each bolt is one closed-hat tick (`SOUND-STORY.md:45`).

Card line: "1: hold for a tight, fast laser." (7 words)

### 2.2 Slot 2: Overdrive Blast, kept

What it does: hold to grow a ring around the ball, release to throw everything in it off you. Then the laser fires 60% faster for 3 s. The ring is committed at the ball and drawn with chevron ticks (`combat.gd:1400-1403`; `tests/char_kits_test.gd:255`).

Sees and hears: the copper ring grows with the gauge. The hat roll speeds up as it fills, and the release is an open-hat crash (`SOUND-STORY.md:44`, `:90-92`).

Kept as it is. **Call:** no number changes. One cost is new and is Rivet's alone. Under the bar, charging slot 2 routes left click to the gauge, so the laser falls silent for up to 1.5 s (the 1.0 s gauge plus the 0.5 s grace). Today he holds F and fires at once. The boost that follows pays it back: 3 s at x1.6 is 1.8 s of extra fire, so a cast still nets about 0.3 s of fire or more. Hip Fire (`r_hip_fire`, `combat.gd:1284-1290`) removes the gap entirely: picked mid-sprint, the gauge starts full and fires on the press. Section 11 asks Andrew about this.

Card line: "2: blast them off you, then fire faster." (8 words)

### 2.3 Slot 3: Line Drive (the force flavour)

The line-skill contract, field by field (SKILL-BAR section 3):

| Field | Rivet |
| --- | --- |
| `id`, icon, name | `line_drive`, `ab_rivet_line`, "Line Drive" |
| Fire shape | Tap. A tap keeps Rivet at one gauge on his bar, which is his difficulty 1 |
| `cooldown`, charges | 8.0 s, 1 (framework default) |
| `on_body`: the punch | A copper pulse runs down the cable at 150 m/s **start**: 0.1 s at 15 m, 0.3 s at 45 m. It strikes the latched machine as a ram, through `punch_of("ram", f)` (`combat.gd:869-880`), with force f = max(8, 0.6 x the ball's planar speed) **start**. That is (14 + 1.3 f) x heft, x1.25 while sprinting, x `chain.multiplier()` when it lands (`src/combat/chain.gd:49`). At heft 1.0 and chain x1: 24.9 rolling at cruise (14 m/s), 34.6 sprinting, 35.1 at blazing. Knock 34 along the cable, away from the ball, with the `overdrive` impact's 0.5 lift (`event_kinds.gd:255`). A machine thrown faster than 6 m/s pins what it meets within 1.2 m: 8 + 0.5 per m/s, capped at 40, and passes on 60% of its speed (`weapons.gd:216-221`). So one punch can bowl a file. **The line stays latched**: the anchor follows the body and breaks only past 67.5 m (`augments.gd:697-713`). Winch in after it and the smash lands in the pile you just made |
| `on_world`: the haul | Replaces the default `reel_burst`. The winch drags the ball straight to the anchor on a `RideRail.line` (`src/world/ride_rail.gd:77-90`), at the ball's speed or 24 m/s, whichever is higher **start**. The line does not sag. Crowd control slides off for the haul plus 0.3 s (`grant_immunity`, `player_ball.gd:378-379`); damage still lands, as with the sprint (`DESIGN-V2.md:49`). The haul ends 2.5 m short of the anchor (`MIN_ROPE`, `augments.gd:52`); the line lets go and the ball keeps its speed, since a ride never cuts speed (`ride_rail.gd:9-13`). 45 m takes 1.9 s at most. Rams on the way follow the normal contact rule |
| `load_seconds` | 4.0 (default). With no line, the cast loads; the next bite carries it. A body bite punches on the latch; a world bite hauls |
| Chain scaling | The punch multiplies by `chain.multiplier()`. The haul does no damage |
| Committed geometry | A tap has no hold, so the preview shows from the pick to the click, while slot 3 is selected and a line stands. On a body: the cable lit copper end to end and a 6 m chevron arrow from the machine pointing down the cable. The arrow is the committed direction; the distance depends on the machine's weight. On a world anchor: a straight copper rod to the anchor, chevrons running toward it, and the arrival ring 2.5 m short. The cast uses exactly that vector (TADR-008, via SKILL-BAR section 3) |
| Ground contact | The punch never grounds the ball. A haul to a low anchor can set the ball down at the end, and then the chain ends as usual |
| Warden and boss read | Warden, guard closed: the punch adds posture as one harpoon contact, capped at 12 **start**, and does not move it. Slate sparks and the low clank, the glance read. Warden, core open: the punch strikes the core as one ram contact; it never shatters a chunk, since the smash is the drop finisher (principle 23). Warden as an anchor (wave K-F): a ride point is a haul, a body is a punch, and the haul ignores the Warden's pulse and magnet, which are crowd control (`player_ball.gd:351-356`). Brindle, the Waking, the Mind: x0.5 damage, no knock, a brace pose and the "nope" glyph |
| Meter | The punch publishes `enemy_struck` with kind `ram`, so the meter counts it as contact: 2.0 points (SKILL-BAR section 4) |
| Sound | Punch: one clav stab on A4, the motif's hammered note, as the pulse leaves; `rivet_snare_flam` on impact (`event_kinds.gd:109`), one step higher per chain link, like `chain_link`. Haul: `rivet_hat_roll` for the haul's length (`event_kinds.gd:101`), landing the D (74), the motif's fourth, on arrival. New ids: `rivet_line_punch` and `rivet_line_arrive`, both keyed (`src/presentation/audio.gd:85`) |
| Card and codex | "3: punch down the cable, or ride it." (8 words). Codex row `rivet_line_drive` (section 8) |
| Clip | `cast_line`, 0.5 s (section 6) |

### 2.4 Shift chip: Overdrive Sprint, kept

What it does: hold Shift for up to 2.0 s. Cruise rises 25%, contact hits 25% harder, and every hold and knock slides off while the damage lands (`player_ball.gd:357-367`). The ignored hit says so, at most every 250 ms per kind (`player_ball.gd:37-38`).

Sees and hears: the exhaust mouths light copper (section 5; ROSTER-LOOK §0.2). The closed-hat roll plays for the sprint's whole length, and an ignored hit is a cymbal choke (`SOUND-STORY.md:100-101`).

Card line: "Shift: sprint; crowd control slides off." (6 words)

### 2.5 Ctrl chip: Shockwave Skid, kept

What it does: the shared slam, then no plant. The fall goes forward along the ground, so a slam costs Rivet no time, and machines in the cone ahead are thrown on and pay back sprint.

Sees and hears: the womp plus a snare flam, then one tick per 0.5 s refunded (`SOUND-STORY.md:104`). New: the `smash` clip (section 6).

Card line: "Ctrl: skid on; each hit refunds sprint." (7 words)

### 2.6 The class row

`src/core/class_def.gd:94-100` gains `"line_id": "line_drive"` and `"ultimate_id": "foundry_cutter"`. The pitch becomes "An unstoppable laser sprinter. Shrug off crowd control, punch force down the cable, then drive a measured cut." `FANTASY["runner_gunner"]` (`class_kit.gd:62`) stays: "Unstoppable sprinter. Crowd control is fuel." `synergy_hooks` stay (`class_def.gd:100`).

## 3. Foundry Cutter, the set piece

The Bible's direction for Rivet's ultimate is "a sustained major cutter. The player shapes its route while the working optics and beam corridor remain visible" (`BIBLE.md:378`). The framework's ride is the route, and the beam is the cutter.

```
 Q pressed     wind-up 0.35 s        flight: 1.6 to 3.2 s, whole beats                         recovery 0.25 s
 |--- drill spins up, lens lights ---|== beam cuts == beam cuts == FULL CUT == beam cuts ==|-- BREACH SKID -->  rolling on, banked speed
 music:   launch build                  A  .  A  .  A  (one clav A per beat, hat roll under)    D lands with the drop
                                                     ^ open-hat crash at the peak
```

The flight plays Rivet's motif stretched over the ride. The motif is A A A then D: "repetition is the rapid laser; the fourth is the sprint arriving" (`SOUND-STORY.md:41`). Each beat of the cut is a hammered A. The landing is the D.

### The contract, item by item (SKILL-BAR section 4, "What each pilot sheet must specify")

| Item | Foundry Cutter |
| --- | --- |
| 1. id, name, icon | `foundry_cutter`, "Foundry Cutter" (the class tie-in name in `CHARACTER-BIBLE.md:72`), `ab_rivet_ult` |
| 2. `paths` | `["line", "rail", "arc"]`, the framework order. Rivet keeps it: his punch, his haul and his Q all ride the line, so the line comes first. No reach override: line 45 m, arc 40 to 70 m by class |
| 3. Tech | One beam from the `DrillTip` lens along the shared aim query's centre ray, the ray the reticle marks (`src/combat/hitscan.gd:3-7`). It is clamped to 60 degrees off the travel heading, because the lens faces forward. Length 40 m. Width by heft class I to V: 0.6, 0.7, 0.8, 0.9, 1.0 m. Between beats it is a thin copper guide. On each beat it flashes to full width and deals 12 x heft multiplier to up to 3 machines along it, nearest first **start**: 36 a beat at class I, the framework budget (SKILL-BAR.md:272). A2-CRITIC cut the pierce from 4 to 3; at 4, Rivet's beats dealt 48, a third over every other pilot. Aim is fully manual: the beam is the reticle, so the 25-degree reticle bias does not apply |
| 4. Peak | "Full Cut", the middle beat. The beam widens to 2.5 m and sweeps 90 degrees, 45 to each side of the aim, in 0.25 s, out to 30 m. Every machine it crosses takes 18 x heft multiplier once, with no pierce cap **start** (A2-CRITIC: 24 before; 18 matches Tarn's uncapped peak ring per machine). A copper scar marks the swept ground for 1.5 s; the scar does no damage |
| 5. Landing | The Breach Skid. No plant. A forward cone along the path's heading, half-angle 70 degrees (the skid's cone, `player_ball.gd:46`), reaching 1.5 x the class landing radius (9, 10.5, 12, 13.5, 15 m), plus everything within 2.5 m. Damage 60 x heft multiplier x `chain.multiplier()`, then the chain ends (framework). Knock 26 forward x falloff x `ult_pins`, so thrown machines pin as the skid does (`player_ball.gd:966-982`). Exit: the ball leaves along the path's heading, flattened onto the ground, at its banked speed, which a ride never cuts (`src/world/ride_rail.gd:9-13`). **A2-CRITIC:** the earlier 27 m/s floor is gone, because Sable's Cable Run exit owns "leave faster than you came" and two line-first set pieces ending in the same speed gift read as one payoff. The landing also grants one sprint charge (the `grant_move` action, `combat.gd:2247`). **Call:** the Breach Skid counts as a slam for the burrower's marker and the drill crew's rig (`burrower.gd:5-6`, `drill_crew.gd:4-5`) |
| 6. Heft scaling beyond the table | The beam's width follows the lens, which grows with the drill cone (section 5): 0.6 m at class I to 1.0 m at class V. The cone's reach is 1.5 x the framework's landing radius. Damage uses the framework multiplier, 1.00 to 1.60 |
| 7. Music | Motif `rivet` (`src/presentation/harmony.gd:133`). Ready: A5 A5 A5 D6 as clav ticks and a small bell, the motif up an octave (the framework's ready cue). Wind-up: the launch build (framework). Flight: one clav A per beat, on the beam's flash, with the closed-hat roll in sixteenths under it. Peak stinger: the roll accelerates into the open-hat crash, the motif's own payoff (`SOUND-STORY.md:44`). Landing cadence: the D, the fourth home, lands on the drop beat with `drop_now` (framework) |
| 8. Mecha | Ready: the exhaust mouths breathe copper at 1 Hz and the drill turns at 0.5 revolutions a second. Wind-up: the drill spins up to 8 a second with a rising whine, and the lens lights. Flight: the drill at full spin, the exhausts lit, the beam leaving `DrillTip`. Peak: a lens flare, and the fin V opens 10 degrees. Landing: an exhaust puff; the drill spins down over 0.6 s. Throughout, the weapon ring stays level and yaws to the aim, so the twin barrels point along the beam |
| 9. Clips | `ult_ready` 0.8 s, `ult_windup` 0.35 s, `ult_strike` 0.6 s, `ult_recover` 0.7 s (section 6). The claws take the copper lap bar, the Q control, at wind-up and hold it through the flight in the shared `ult_ride_loop` (PILOT-CLIPS.md section 1) |
| 10. Depth 3 | Prism Cutter and Juggernaut Drive, below |
| 11. Depth 4 | Five knobs, below |
| 12. Wardens and bosses | Below |
| 13. Card, discovery, run-log id | "Q: drive a measured cut to your aim." (8 words). Codex row `rivet_foundry_cutter` (section 8). Run-log `ultimates[].id` is `foundry_cutter`, `prism_cutter` or `juggernaut_drive` |

### Wardens and bosses

Principle 14 holds: a boss resists with a visible "nope" and its windows stay as they are.

| Target | Beam on each beat | Full Cut | Breach Skid landing |
| --- | --- | --- | --- |
| Warden, guard closed | Fills posture as gun bolts do, at half damage (framework) | Counts as one bolt hit per Warden | One contact at most: up to 45 posture once; never cracks or shatters (framework) |
| Warden, core open | As above | As above | A core inside the cone shatters, as a harpoon smash does (framework) |
| Warden as an anchor (wave K-F) | A `line` path may end on it; the landing on it is the drop finisher | | As above, by guard state |
| Brindle, the Waking, the Mind | x0.5 | x0.5 | x0.5; phase windows untouched; brace pose and the "nope" glyph |

Rivet's edge at a Warden is range, not power: the beam's 40 m lets him fill posture on the approach, then land the skid on the core. The Juggernaut Drive's rams count as contacts, and a closed guard ends its flight as a landing at the contact point (framework).

### Depth 3: two set pieces to choose from

Depth 3 opens in world 2 (`src/core/upgrade_tree.gd:119-120`). A depth-3 node swaps the ultimate with the existing op shape, `"swap": {"ultimate": <id>}` (SKILL-BAR section 4). **Call:** the two children of every depth-2 node are always one Prism Cutter and one Juggernaut Drive, so the world-2 pick is the set-piece choice every time. This matches the Tally sheet (`pilots/tally.md:146`).

| Variant | id | Changes | Tech | Peak | Landing |
| --- | --- | --- | --- | --- | --- |
| Prism Cutter | `prism_cutter` | the tech: the lens splits the beam through a prism (the Bible's prism, `BIBLE.md:376`) | Three beams at minus 15, 0 and plus 15 degrees from the aim. Each 30 m long, 0.5 m wide at class I (plus 0.1 m a class), cutting 2 machines a beat for 8 x heft multiplier **start** | "Focus": the three converge on the aim ray for one beat, one 1.5 m beam, 40 m, 30 x heft multiplier to up to 6 machines | Breach Skid |
| Juggernaut Drive | `juggernaut_drive` | the tech: the beam is off and the ball is the weapon | Every machine whose hull passes within 3 m of the ball's centre is rammed once per flight: 30 x heft multiplier x 1.25, knock 34 half outward and half forward, so it pins. On each beat, a chevron bow wave throws machines 3 to 8 m beside the path ahead outward, away from the path: knock 20 x falloff, no damage, and a thrown machine pins what it meets as the punch does (`weapons.gd:216-221`). **A2-CRITIC:** the draft pulled them 2 m toward the path, which is Tarn's direction (`pilots/tarn.md` section 1) and sat beside Tarn's Rake Run corridor; Rivet's force always points away from him. Machines no longer end the flight; only world geometry and a Warden guard do **start** | "Shoulder": the corridor widens to 5 m for one beat, and rams deal double | Breach Skid, then crowd control slides off for 2.0 s more |

Prism Cutter rewards a wide pack and a dish-bearing deflector, whose face the side beams reach around. Juggernaut Drive rewards a dense lane and a path through a crowd. Both keep the Breach Skid, so both stay Rivet.

### Depth 4: modifiers

Each depth-4 node turns one ultimate knob with the existing `"knob"` op. Four knobs are the framework's (SKILL-BAR section 4). **Call:** one is Rivet's own.

| Knob | Default | Set to | Foundry Cutter | Prism Cutter | Juggernaut Drive |
| --- | --- | --- | --- | --- | --- |
| `ult_encore` | false | true | A second leg if a machine sits within 30 m of the landing (framework). Rivet's encore keeps the heading: it takes the machine nearest the cone's axis | same | same |
| `ult_beats` | 0 | 2 | +2 flight beats, so +2 cuts | +2 cuts | +2 bow waves |
| `ult_radius` | 0.0 | 2.0 | Breach Skid reach +2 m | same | same |
| `ult_volley` | 0 | 1 | The beam cuts +1 machine a beat | +1 per beam | The ram corridor +1 m each side |
| `ult_pins` (new, Rivet) | 1.0 | 2.0 | The Breach Skid throws twice as hard, so its pins hit harder | same | same, and the rams throw twice as hard |

`ult_pins` raises Demolisher's idea (`src/core/trees/rivet.gd:58-59`) to the set piece.

### Tree changes (`src/core/trees/rivet.gd`)

The tree is heap-ordered: indices 0 and 1 are depth 1, 2 to 5 depth 2, 6 to 13 depth 3, 14 to 29 depth 4; the children of node i are 2i+2 and 2i+3 (`upgrade_tree.gd:136-141`). The left half guns on the move from `r_gunline`; the right half cannot be stopped, from `r_juggernaut` (`rivet.gd:3-4`).

**Call: every changed node keeps its id, name, tags and old op, and gains the ultimate op.** No node is replaced, so world-2 and world-3 picks still grow the kit, and no two nodes in the tree are the same pick. The Tally, Kest and Tarn sheets make the same call (`pilots/tally.md:171`, `pilots/kest.md:256`, `pilots/tarn.md:214`). **A2-CRITIC (SKILL-BAR section 12, item 5):** every node keeps its `key` and `icon`, and its `effect` keeps only its own perk; the set-piece half of each "New effect" below moves to the card's second line from `SET_PIECE_LINES`, so the card cannot disagree with the op. Effects stay at 8 words or fewer and names at 3 or fewer (`upgrade_tree.gd:49-50`). Depths 1 and 2 do not change, so the world-one cards and `world_one_rtree_test` keep their meaning.

Depth 3 (world 2). Each pair holds one of each variant:

| i | id | Parent | Kept op (`rivet.gd` line) | Added op | New effect (words) |
| --- | --- | --- | --- | --- | --- |
| 6 | `r_crossfire` | 2 `r_tracer` | pattern, 3 arms (`:23-25`) | `"swap": {"ultimate": "prism_cutter"}` | Prism Cutter ultimate; bolts split three ways (7) |
| 7 | `r_magnet_blast` | 2 `r_tracer` | knob `blast_pull` (`:26-27`) | `"swap": {"ultimate": "juggernaut_drive"}` | Juggernaut Drive ultimate; your blast pulls in (7) |
| 8 | `r_skid_gunner` | 3 `r_run_gun` | proc `skid_smashed` to `overdrive` 2.0 (`:28-29`) | `"swap": {"ultimate": "prism_cutter"}` | Prism Cutter ultimate; skids boost fire rate (7) |
| 9 | `r_hip_fire` | 3 `r_run_gun` | knob `sprint_full_blast` (`:30-31`) | `"swap": {"ultimate": "juggernaut_drive"}` | Juggernaut Drive ultimate; sprinting blasts fire full (7) |
| 10 | `r_bulldozer` | 4 `r_ram_fins` | knob `skid_keep` 1.0 (`:32-33`) | `"swap": {"ultimate": "juggernaut_drive"}` | Juggernaut Drive ultimate; skids keep your fall (7) |
| 11 | `r_shrug` | 4 `r_ram_fins` | proc `cc_ignored` to `refund_special` (`:34-35`) | `"swap": {"ultimate": "prism_cutter"}` | Prism Cutter ultimate; ignored hits recharge blast (7) |
| 12 | `r_slipstream` | 5 `r_second_wind` | proc `skid_smashed` to `grant_move` (`:36-37`) | `"swap": {"ultimate": "juggernaut_drive"}` | Juggernaut Drive ultimate; skids refill a sprint (7) |
| 13 | `r_afterburner` | 5 `r_second_wind` | proc `sprint_started` to `air` (`:38-39`) | `"swap": {"ultimate": "prism_cutter"}` | Prism Cutter ultimate; sprints return air jump (7) |

Hip Fire's old text named F ("F while sprinting fires at full", `rivet.gd:30`); the new text drops it, since F retires.

Depth 4 (world 3). The variant comes from the parent's swap. Sibling pairs never share a knob. Where a node already has a `knob` op, the new key joins that dictionary.

| i | id | Parent (variant) | Kept op (`rivet.gd` line) | Added knob | New effect (words) |
| --- | --- | --- | --- | --- | --- |
| 14 | `r_rotary` | 6 (prism) | pattern, spin 30 (`:41-42`) | `{"ult_beats": 2}` | Spread rotates; ultimate cuts two beats longer (7) |
| 15 | `r_saturation` | 6 (prism) | pattern, wide fan (`:43-45`) | `{"ult_volley": 1}` | Wide laser fan; each cutter beam cuts more (8) |
| 16 | `r_vortex` | 7 (drive) | knob `special_echo` 0.5 (`:46-47`) | `{"ult_encore": true}` | Blast pulls, then throws; ultimate drives an encore (8) |
| 17 | `r_point_blank` | 7 (drive) | swap special `point_blank` (`:48-49`) | `{"ult_pins": 2.0}` | Tight double blast; ultimate throws twice as hard (8) |
| 18 | `r_skid_volley` | 8 (prism) | proc `skid_smashed` to `volley` 3 (`:50-51`) | `{"ult_radius": 2.0}` | Skids fire three volleys; ultimate skids wider (7) |
| 19 | `r_rampage` | 8 (prism) | proc `enemy_killed` to `refund_move` (`:52-53`) | `{"ult_encore": true}` | Kills recharge sprint; ultimate cuts an encore (7) |
| 20 | `r_blast_off` | 9 (drive) | proc `special_used` to `grant_move` (`:54-55`) | `{"ult_beats": 2}` | Blasts refill a sprint; ultimate drives longer (7) |
| 21 | `r_unstoppable` | 9 (drive) | knob `overdrive_immune` (`:56-57`) | `{"ult_volley": 1}` | Boosted, crowd control slides off; ultimate rams wider (8) |
| 22 | `r_demolisher` | 10 (drive) | knob `skid_pins` 2.0 (`:58-59`) | `{"ult_pins": 2.0}` | Skids and your ultimate throw machines into pins (8) |
| 23 | `r_crush_chain` | 10 (drive) | knob `crush_refund` 0.3 (`:60-61`) | `{"ult_radius": 2.0}` | Crushes stretch your sprint; ultimate skids wider (7) |
| 24 | `r_iron_will` | 11 (prism) | proc `cc_ignored` to `overdrive` 1.5 (`:62-63`) | `{"ult_beats": 2}` | Ignored hits boost fire; ultimate cuts longer (7) |
| 25 | `r_push_back` | 11 (prism) | proc `cc_ignored` to `blast` 0.5 (`:64-65`) | `{"ult_pins": 2.0}` | Ignored hits blast back; ultimate throws harder (7) |
| 26 | `r_perpetual` | 12 (drive) | knob `sprint_perpetual` (`:66-67`) | `{"ult_encore": true}` | Fast sprints never drain; ultimate drives an encore (8) |
| 27 | `r_nitro` | 12 (drive) | knob `sprint_kick` 8.0 (`:68-69`) | `{"ult_radius": 2.0}` | Sprints kick forward; ultimate skids wider (6) |
| 28 | `r_skyline` | 13 (prism) | knob `sprint_float` 0.5 (`:70-71`) | `{"ult_volley": 1}` | Airborne sprints float; each cutter beam cuts more (8) |
| 29 | `r_hammer_drop` | 13 (prism) | proc `skid_smashed` to `blast` 0.6 (`:72-73`) | `{"ult_encore": true}` | Skids end in blasts; ultimate cuts an encore (8) |

Coverage: Prism Cutter builds see `ult_beats` 2, `ult_volley` 2, `ult_encore` 2, `ult_radius` 1, `ult_pins` 1. Juggernaut Drive builds see `ult_encore` 2, `ult_pins` 2, `ult_radius` 2, `ult_beats` 1, `ult_volley` 1. No proc is added, so the proc-loop check (`upgrade_tree.gd:319-338`) sees the same links as today.

New `ABILITIES` rows (beside `src/core/ability_state.gd:54-58`):

```
"line_drive": {"icon": "ab_rivet_line", "cooldown": 8.0, "line": true, "load_seconds": 4.0},
"foundry_cutter": {"icon": "ab_rivet_ult", "paths": ["line", "rail", "arc"]},
"prism_cutter": {"icon": "ab_rivet_ult", "paths": ["line", "rail", "arc"], "variant_of": "foundry_cutter"},
"juggernaut_drive": {"icon": "ab_rivet_ult", "paths": ["line", "rail", "arc"], "variant_of": "foundry_cutter"},
```

`line_drive` has no `charge_max` (a tap) and no `pool`. No row sets `beats`, so flights take the framework's beat-rounded length.

## 4. Three worlds

`depth_cap = clamp(world + 1, 2, 4)` (`upgrade_tree.gd:119-120`): depths 1 and 2 in world 1, depth 3 opens in world 2, depth 4 in world 3.

| World | Depth cap | What Rivet's kit adds or changes | What the world asks, and Rivet's answer |
| --- | --- | --- | --- |
| 1, Spillway Works (Brindle; reactor relics on the dam face and the flume) | 2 | The full bar and the base Foundry Cutter. Picks at depth 1 (Gunline or Juggernaut) and depth 2 shape slots and movement only | Rivet unlocks here, by the rescue (`class_def.gd:99`). Flumes and the dam face are straight lines: the haul runs up the dam face with nothing able to hold him, and the punch bowls flume files. The world-one identity is the runner: sprint, gun and punch |
| 2, the Dig (the Waking; swarm remnants on headframe cables and in sinkholes) | 3 | The world-2 workshop pick is Prism Cutter or Juggernaut Drive, each with its old perk | The plan adds deflectors and counter-rams as answers to harpoon spam from world 2. Rivet's sprint already rolls through a dish (`src/combat/deflector.gd:13`); the Prism's side beams reach around one; the Drive rams through. Burrowers and drill crews meet the Breach Skid as a slam |
| 3, the Highdraft (the Mind; its hands under sky islands and between spires) | 4 | A depth-4 modifier on the chosen set piece, with its old perk | Spires and island undersides are anchors, so the haul is Rivet's island hop: straight, unholdable, and keeping speed. The beam's 40 m reach tracks the Mind's flying hands |

In one line each: world 1 is the runner, world 2 makes the set piece his, world 3 grows it.

## 5. The mecha

**Body direction (A2-CRITIC, 2026-10-10; rewritten to the Hoberman mecha the same evening).** ROSTER-LOOK §0, the Hoberman mecha, is the live body (`ROSTER-LOOK.md:3`, `:11-15`), and this section follows it. Rivet's concept pictures are `artifacts/local/alpha/push/w13/concepts/codex/rivet/hero.png`, `chase.png` and `sheet.png`. The silhouette rule below holds and PILOTS.md restates it.

ROSTER-LOOK §0.1 is the canon for the shared mecha. The lattice on Core is a fully expanded Hoberman sphere that tumbles with the roll. Its named Hub and Gap empties take the parts: modules clamp at hubs, and heft panels fill gaps. The WeaponRing under Pod stays level on its bearing collar and yaws to the aim. The cockpit Pod hangs upright on a two-axis gimbal and turns to the heading. It holds the seat, the controls and a seated, fully visible pilot. This section fills in Rivet's row of §0.2: the drill nose is a module filling the front gap, the twin exhaust stacks sit on gap brackets at the upper rear (rest pose at two upper rear hubs), the copper fins lie flat in the front lower gaps, and his twin laser barrels ride the weapon ring. The beam still leaves `DrillTip`.

### Machinery: the drill nose, the fins, the stacks, the weapon ring and the cockpit

| Part | Form | Function it shows |
| --- | --- | --- |
| Drill nose | A stepped drill-cone module hung under the weapon ring's front arc, filling the front gap in the rest pose, with the cutting lens at its tip. Three steps at class I; the lens 0.12 m across | The Foundry Cutter leaves from the lens. The drill spins with the set piece (section 3, item 8). It never bores the ground |
| Cooling fins | Copper fins on the front lower gaps, raked back so they form a V pointing forward, folded flat inside the lattice outline (under 0.05 m proud). They flare 10 degrees only at the set-piece peak. **A2-CRITIC:** the draft stood them out at 4 and 8 o'clock, which is Tarn's one defining break (`pilots/tarn.md` section 5) | Rivet's chevron, his class shape, read from the side and front, never from behind |
| Twin exhaust stacks | Two short stacks on gap brackets at the upper rear (rest pose at two upper rear hubs), at 11:30 and 12:30, 0.18 m tall | The rear tell. The mouths light copper during the sprint, the haul and the set piece |
| Weapon ring | Twin rapid-laser barrels in copper housings on the ring's front arc, at about 11 and 1 o'clock, parallel, muzzles forward. The band is worn-bone segments with charcoal clamp blocks over a dark-steel bearing collar (ROSTER-LOOK §0.7) | The ring stays level and yaws to the aim, so the barrels point where the bolts go |
| Cockpit | The seat hangs inside two nested dark-steel gimbal rings, both visible through the front gap, with a bone seat back behind the grey head. Twin yokes take the claws, and their triggers fire "1: Rapid Laser". A two-lever bank beside the right yoke holds "2: Overdrive Blast" and "3: Line Drive". The largest control is a copper two-handed lap bar with a sight at its centre: "Q: Foundry Cutter". Two pedals carry "Shift: Overdrive Sprint" (ROSTER-LOOK §0.7) | Each control moves when its skill fires, from the same event as its clip (ROSTER-LOOK §0.4; section 6) |

Named nodes, for P-D to add and kit code to read: `DrillTip` (an empty at the lens facing +Y, as ROSTER-LOOK names it) and `Drill` (the spinning cone) under Pod > WeaponRing, because the drill nose hangs under the ring's front arc; `Exhaust.L` and `Exhaust.R` (the glow mouths) on gap brackets from the Pod at 11:30 and 12:30 (ROSTER-LOOK §4; rest pose at the upper rear hubs). The cockpit controls under Pod take the clip spec's names: `Control.Trigger` on the yokes, `Control.Lever` for slot 2 and `Control.WinchLever` for slot 3 (PILOT-CLIPS.md section 5). Glow is the `class_accent` slot at the lens tip and the exhaust mouths only (ROSTER-LOOK §0.7, colour discipline and glow).

### Gap panels across heft classes

Gap panels follow `heft_class_changed` and `heft_class_dropped` (`src/core/game_events.gd:36-37`). Class up slams panels into their gaps. Losing a class flings the outermost layer out of its gaps. The budgets are ROSTER-LOOK section 5's and the gap order is §0.3's. Rivet's gap panels are raked chevron plates.

| Class | Rivet's layer |
| --- | --- |
| I | Bare lattice, weapon ring and pod, with no gap panels: a rider. Three-step drill, fins, stacks |
| II | Six raked chevron panels in the lower gaps below the pod, all below Z -0.35, points forward |
| III | Chevron panels in the side gaps, and thicker hub tread caps with a chevron tread |
| IV | Chevron panels in most gaps, carrying the fin V back along the flanks toward 3 and 9 o'clock inside the lattice outline. Only the sight gaps to the head stay open. Collars round the stack bases |
| V | Every gap paneled except the front and rear sight gaps to the head. The drill module grows to its heavy form: the big drill cone, five steps, the lens 0.20 m across |

One source, every layer: the heft class sets the lens size, and the lens size sets the beam width (0.6 m at class I to 1.0 m at class V). The bigger drill is why the beam is fatter.

### Silhouette rule

**Two short stacks standing straight up over a broad, earless head means Rivet.** No other pilot breaks the outline above the head with two parallel vertical stubs: Sable's single coil mast stands at 11 o'clock with nothing at 1, Kest's fin vanes sweep at 2 and 10, Tarn's claw arms sit low at 4 and 8, Tally's ledger drums are level at 3 and 9, and the Cannon's split ports sit low at 5 and 7 (ROSTER-LOOK §0.2 and the §0.7 game-size read). From the side, the drill nose and the forward fin V finish the read.

## 6. Clips

All clips play on the shared 25-bone `pilot-v1` rig through the pose-table route. A5 confirms the ids and P-E builds them. Rivet's motion language: perfectly still, then exact. The head moves in small, precise increments and one claw taps a dial (`CHARACTER-BIBLE.md:70`). His rarest expression, the visor flipping up to show tiny proud eyes (`:73`), is saved for class-up and the unlock. At rest the claws sit on the twin yokes. The cast and ultimate clips work the cockpit controls in section 5 (ROSTER-LOOK §0.4, §0.7).

| Clip | Length | Trigger signal | Pose beats |
| --- | --- | --- | --- |
| `idle_loop` | 4.0 s loop | none; the base layer | Still. The head ticks in three exact steps, then back. One claw taps the dial twice |
| `class_up` | 1.2 s | `heft_class_changed` | The visor flips up, tiny proud eyes for 0.5 s, then it snaps down. A firm nod |
| `cast_special` | 0.6 s | `slot_cast` with slot `special` | Both claws slam the slot-2 lever (`Control.Lever`, in the bank beside the right yoke) down; the shoulders brace against the seat back |
| `cast_line` | 0.5 s | `line_skill_fired` | The right claw yanks the slot-3 winch lever (`Control.WinchLever`, beside it in the bank) back hard. On a haul, the same pull flows into a forward lean |
| `ult_ready` | 0.8 s | `ultimate_ready` | Two taps on the visor; a small nod |
| `ult_windup` | 0.35 s | `ultimate_started` | The goggles drop, both claws leave the yokes for the copper lap bar (the Q control), the head lowers behind the sight at its centre |
| `ult_strike` | 0.6 s | `ultimate_peak` | Both claws on the lap bar. The head tracks the sweep; the shoulders turn with the beam |
| `ult_recover` | 0.7 s | `ultimate_landed` | Sits back, claws back to the yokes; one claw taps the dial: measured |
| `smash` | 0.7 s | `slammed` (`game_events.gd:50`), the shared roster row (PILOT-CLIPS.md section 1.1); priority 36, cooldown 1.0 s | A sideways lean into the skid, like a rider into a bend, both claws planted on the yokes |
| `unlock` | 2.4 s | `rescue_completed("rivet")` (`game_events.gd:177`; `src/world/rescue_site.gd:14-17`) | In the rescue cage: still; a calliper claw measures the latch; a nod; the latch gives. Matches the achievement beat "Asked who locked the cage from inside" (`src/core/achievements.gd:42`) |

The cast and ultimate rows' priorities and cooldowns are SKILL-BAR section 7's. The clip may outlast the control lock: `ult_recover` runs 0.7 s against the 0.25 s recovery, because timing follows what the action has to say (principle 15). The seven existing reactions stay as they are: `brace`, `heave`, `wince`, `slump`, `phew`, `big_cheer` and `drop_land` (`src/presentation/pilot_reactions.gd:5-18`).

## 7. Earned cosmetics

Nothing is bought. Each item comes from an achievement row in the shape `src/core/achievements.gd` already uses (`on`, `where`, `count`, `reward: {"cosmetic": id}`, `:23`, `:37`). The outfit and shell-variant slot kinds come from B5's scaffold; `cosmetics.gd` has only paint, trail, decal and companion paint today (`src/core/cosmetics.gd:17`).

| Item | Slot | Look | Granted by |
| --- | --- | --- | --- |
| Swarf Curl (`trail_rivet_swarf`) | trail | Curls of copper machining swarf peel off behind the ball, thicker while sprinting | `ach_rivet_line_true` "Line True": "Land ten Line Drive punches in one stage."; discovery `rivet_line_true` |
| Welding Hood (`outfit_rivet_hood`) | outfit | A flip-up welding hood over the visor. It snaps down on `ult_windup` | `ach_rivet_shrugged` "Shrugged Off": "Shrug off 30 holds and knocks in one run." **A2-CRITIC:** achievement rows cannot test the pilot (`src/core/progress.gd:259-288`), and `cc_ignored` also fires for any `grant_immunity` and for a mounted Sable with `mount_cc_immune` (`src/movement/player_ball.gd:357-362`). So the grant rides a discovery, `rivet_shrugged`, that Rivet's own code detects on the 30th ignored hit of a run, through `synergy_discovered` like the Cannon's grants |
| Calibrated (`shell_rivet_calibrated`) | shell variant | Enamel scale marks on the lattice struts, rubbed calibration bands (`BIBLE.md:369`), numbered drill steps | `ach_rivet_full_breach` "Full Breach": "Land one set piece on 6 machines." On `ultimate_landed` with a Rivet ultimate id and `hits` of 6 or more |

The paint rows stay as they are: Moss as the starter and Forge Blue from 100 kills (`cosmetics.gd:28-29`, `achievements.gd:47`).

## 8. Discovery and codex rows

Two first-time cards in the combat codex's shape (`src/combat/codex_entries.gd:12`), detected in Rivet's own code. Each card's picture is a short loop of the act (principle 17).

| id | Name | Hint | Clue | Text | Fires when |
| --- | --- | --- | --- | --- | --- |
| `rivet_line_drive` | Line Drive | The cable carries more than you. | Rivet + slot 3 + a line on a machine | Pick 3 and click with a line on a machine: the winch throws it into whatever stands behind. On a wall it hauls you in and nothing holds you. With no line, the next bite carries it. | the first punch that pins a second machine |
| `rivet_foundry_cutter` | Foundry Cutter | Measured twice. Firing once. | Rivet + a full ring + Q | Q drives you from here to where you aim. The lens cuts wherever you look, on every beat. The middle beat sweeps wide. The landing skids on, and you keep the speed. | the first Rivet set piece whose beam cuts 3 or more machines |

The hint for the cutter is Rivet's own bark (`BIBLE.md:371`). The framework's shared rows (`loaded_line`, `set_piece`, `set_piece_core`, `set_piece_cash_in`, `set_piece_breakout`) also fire for Rivet.

Tree card copy for the depth-3 picks, one line each, in `src/core/trees/world_one_cards.gd` (`ROWS` at `:10`). Depth-4 cards show the node's own effect.

| Node | Card |
| --- | --- |
| `r_crossfire` | Your cutter splits through a prism. So do bolts. |
| `r_magnet_blast` | Q drives you through them. The blast pulls in. |
| `r_skid_gunner` | Your cutter splits three ways. Skids boost fire. |
| `r_hip_fire` | Q drives you through them. Sprinting blasts fire full. |
| `r_bulldozer` | Q drives you through them. Skids keep the fall. |
| `r_shrug` | Your cutter splits three ways. Shrugged hits recharge. |
| `r_slipstream` | Q drives you through them. Skids refill sprint. |
| `r_afterburner` | Your cutter splits three ways. Sprints return air. |

## 9. Tests and bot checks

All run headless through `npm run sketch:smoke -- --sketch core-loop --test <name>`. Rivet has no kit test of his own today; his cases sit in `char_kits_test`, `char_combat_test` and `char_movement_test`.

| File | Kind | Cases |
| --- | --- | --- |
| `tests/rivet_kit_test.gd` | new | The class row names `line_drive` and `foundry_cutter`. Punch: damage equals `punch_of("ram", max(8, 0.6 x speed))` x chain multiplier, x1.25 while sprinting; knock 34 along the cable; the line still latched after. A punched machine pins a second one standing 1 m behind it. The drawn throw arrow's direction equals the committed knock direction to 1 degree. Haul: ball speed at least 24 m/s toward the anchor; `crowd_control` returns false during the haul; the line lets go 2.5 m short and the speed is kept. Load: a cast with no line loads; a body bite within 4.0 s punches; a world bite hauls; expiry at 4.01 s. Warden closed guard: at most 12 posture, no movement, the glance read. Boss: x0.5, no knock. Slot 2 through the bar: pick 2, click, release draws and commits the same 12 m ring |
| `tests/rivet_set_piece_test.gd` | new | The beam hits only machines on the reticle ray within 40 m and its class width; it cuts at most 3 a beat, on beats only; it clamps at 60 degrees off the heading. Full Cut sweeps 90 degrees once. The Breach Skid hits the forward cone at 1.5 x the class radius and the 2.5 m ring, pays the chain, exits at the banked speed along the heading, and grants one sprint charge. At class V the beam is 1.0 m and the cone 15 m. An open Warden core in the cone shatters; a closed guard takes 45 posture at most. Prism Cutter draws three beams 15 degrees apart. Juggernaut Drive rams each machine once, pulls on each beat, ignores machine collisions, and adds 2.0 s of immunity after recovery. Picking `r_crossfire` swaps to `prism_cutter`; picking `r_magnet_blast` swaps to `juggernaut_drive`. Each knob in section 3 changes its number |
| `tests/tree_data_test.gd` | must pass | `UpgradeTree.problems("runner_gunner")` is empty with the new rows |
| `tests/tree_safe_picks_test.gd` | pass or re-pin | Ultimate swaps replace an ability by design. Either B1 exempts `ultimate` swaps, or `UNSAFE["runner_gunner"]` (`:20`) lists the 8 depth-3 ids under a dated header |
| `tests/world_one_rtree_test.gd` | must pass unchanged | Depths 1 and 2 do not change. Its `r_rampage` case (`:370`) still holds: the id and its proc stay |
| `tests/char_kits_test.gd` | re-pin, dated header | Rivet's row (`:71-77`) gains the line and ultimate ids; the slot-count case (`:113-141`) follows B1's five slots |
| `tests/char_combat_test.gd`, `tests/char_movement_test.gd`, `tests/enemy_rivet_test.gd` | must pass unchanged | The tapped blast ring (`char_combat_test.gd:184-199`), the sprint ignoring knocks (`char_movement_test.gd:232-255`), every holder refused mid-sprint (`enemy_rivet_test.gd:6-9`) |
| `tests/ui_ability_slots_test.gd`, `tests/hud_icon_distinct_test.gd` | re-pin | The two new icons are distinct from Rivet's other four |
| `tests/audio_cue_resolution_test.gd` | re-pin | `rivet_line_punch` and `rivet_line_arrive` resolve |
| `tests/combat_codex_test.gd`, `tests/codex_coverage_test.gd` | pass | The two Rivet rows open once on their scripted triggers |
| `tests/bot_six_runner_gunner_test.gd` | the bot win | At least 3 of 4 seeds win (`tests/bot_six_pilots_test.gd:12-13`). Each winning run casts slot 2 and slot 3 at least once and fires at least one ultimate (B4's acceptance) |
| `tests/posture_bands_test.gd`, `tests/alpha_posture_bands_test.gd` | must stay in band | The grown band stays at 25 s or more (SKILL-BAR section 11). If a band moves, re-pin with a dated header and a `docs/decisions.tsv` row |

Bot hands for Rivet in `tools/bot_driver.gd` (B4 owns the shared helpers): cast slot 2 through `_cast(1, 0.6)` when 4 or more machines stand within 12 m, or at once mid-sprint with Hip Fire. Cast slot 3 when latched on a machine with 2 or more others within 8 m beyond it along the cable, or before a planned bite on a wall over 15 m away. Q through `_ultimate_hands()`, aiming the beam at the nearest group of 3 or more.

### Measures: how each part shows it works

| Part | Measure, from the run log (SKILL-BAR section 7) | Healthy band **start** |
| --- | --- | --- |
| Line Drive | `line_skill_fired` split by `on`; pins per punch | both body and world used; 1.0 pin a punch or more |
| Overdrive Blast | `slot_casts.special` per stage; seconds of laser silence per cast | 3 or more; under 1.2 s |
| Foundry Cutter | beam hits per flight beat, from `ultimates[].volley_hits` over the beats | 2.0 or more |
| The meter | the speed share of `meter_points` | under 40% (Rivet is the pilot most likely to pass it) |
| Depth 3 | which variant bots and Andrew pick in world 2 | neither above 80% over 10 runs |

## 10. Implementation map: wave P-C, unit Rivet

**SCOPE** (exact files; the Rivet block only where a file is shared):

- `src/core/class_def.gd`: the `runner_gunner` row (`:94-100`): `line_id`, `ultimate_id` and the pitch (section 2.6).
- `src/core/ability_state.gd`: the four rows in section 3.
- `src/combat/weapons.gd`: Rivet constants beside `:58-67`: `LINE_PULSE_SPEED := 150.0`, `LINE_PUNCH_SHARE := 0.6`, `LINE_PUNCH_FLOOR := 8.0`, `LINE_HAUL_SPEED := 24.0`, `LINE_HAUL_GRACE := 0.3`, `LINE_WARDEN_POSTURE := 12.0`, `CUTTER_LENGTH := 40.0`, `CUTTER_WIDTH := [0.6, 0.7, 0.8, 0.9, 1.0]`, `CUTTER_PIERCE := 3`, `CUTTER_DAMAGE := 12.0`, `CUTTER_CLAMP_DEG := 60.0`, `FULL_CUT_WIDTH := 2.5`, `FULL_CUT_DEG := 90.0`, `FULL_CUT_REACH := 30.0`, `FULL_CUT_DAMAGE := 18.0`, `BREACH_REACH_SCALE := 1.5`, `BREACH_INNER := 2.5`, `PRISM_*` and `DRIVE_*` per section 3.
- `src/combat/combat.gd`: the Rivet block beside `:1400-1425`: `_line_skills["line_drive"]` with `on_body`, `on_world` and `geometry`; the `rivet_line_drive` detection.
- `src/combat/ultimate.gd`: `_ult_rows` entries for `foundry_cutter`, `prism_cutter` and `juggernaut_drive`; the `rivet_foundry_cutter` detection.
- `src/movement/player_ball.gd`: `_skid_push` (`:966-982`) gains `reach` and `inner` parameters, defaulting to today's values, so the Breach Skid reuses it.
- `src/core/trees/rivet.gd`: the 24 row edits in section 3.
- `src/core/upgrade_tree.gd`: one `KNOBS` row, `"ult_pins": {"default": 1.0}` (beside `:54-76`). The coordinator serializes this line with the other pilots' units.
- `src/core/trees/world_one_cards.gd`: the 8 rows in section 8.
- `src/ui/class_kit.gd`: `WORDS` (`:15-46`) gains `line_drive` "line drive", `foundry_cutter` "foundry cutter", `prism_cutter` "prism cutter", `juggernaut_drive` "juggernaut drive".
- `src/combat/codex_entries.gd`: the two rows in section 8.
- `src/core/achievements.gd` and `src/core/cosmetics.gd`: the three rows in section 7, if B5's scaffold accepts rows whose art lands in P-D. Otherwise they move to the P-D Rivet unit.
- `src/presentation/audio.gd`: `rivet_line_punch` and `rivet_line_arrive`, in `KEYED_SOUNDS` (`:85`).
- `assets/icons/ab_rivet_line.svg`, `assets/icons/ab_rivet_ult.svg`, and their rows in `src/ui/icons.gd` (`EXTRA`, `:44`).
- `tools/bot_driver.gd`: Rivet's hands only (section 9).
- The tests in section 9.

**ACCEPTANCE:**

- Keys 1, 2 and 3 play Rapid Laser, Overdrive Blast and Line Drive; Q plays Foundry Cutter.
- Line Drive refuses a pick for 8.0 s after a cast.
- A punch strikes as a ram at max(8, 0.6 x speed), times the chain multiplier, throws the machine 34 along the cable, and leaves the line latched.
- A haul moves the ball at 24 m/s or faster with crowd control refused, and lets go 2.5 m short with the speed kept.
- The beam damages only what lies on the reticle ray within 40 m and the class width, on beats only.
- The Breach Skid hits the forward cone, pays and ends the chain, exits at the banked speed with no loss, and grants one sprint charge.
- No Rivet source cracks or shatters a closed Warden guard; the landing on an open core shatters it.
- A boss takes x0.5 from every Rivet source, and its windows do not move.
- A world-2 tree offer for Rivet shows one Prism Cutter node and one Juggernaut Drive node as siblings.
- Each depth-4 knob changes the number section 3 names.
- `tests/bot_six_runner_gunner_test.gd` wins on at least 3 of 4 seeds, with one slot-2 cast, one slot-3 cast and one ultimate per winning run.
- Every test in section 9 passes, with dated headers on every re-pin.
- `git diff --name-status` against the base shows only SCOPE files.

**Depends on wave P-B:**

| P-B unit | What Rivet needs from it |
| --- | --- |
| B1 | The slot model and router; `_line_skills`, `_step_line` and the load; `line_id` and `ultimate_id` on class rows; `SWAPPABLE`. Also `upgrade_tree.KEYS` (`:45`) must gain `line` and `ultimate`, or every depth-3 and depth-4 row here fails `problems()` (`:280-281`). `safe_pick_problems` (`:183-229`) and `apply_pick` (`:464-472`) must accept an `ultimate` swap, since both iterate `AbilityState.SLOTS` today |
| B2 | The tree card draws key `ultimate` as the Q keycap; the bar shows the slot-3 load badge |
| B3 | `ultimate.gd`, the meter and `_ult_rows`; the four framework knobs in `KNOBS`; the landing callable may set the exit velocity and grant a charge |
| B4 | `_cast`, `_line_hands` and `_ultimate_hands` |
| B5 | The outfit and shell-variant slot kinds and the cosmetic reward path |
| B6 | The codex framework rows, so `codex_coverage_test` counts Rivet's two on top |

Order: the Rivet unit starts after B1, B3 and B4 merge. Its cosmetic rows wait for B5 and its codex rows for B6. It edits `combat.gd` and `player_ball.gd` after B3, never at the same time. The P-D Rivet unit adds `DrillTip`, `Drill` and `Exhaust.L/R`; until then the beam leaves the ball's centre and the mecha reads in section 3 (item 8) are skipped.

**Difficulty.** Rivet gains two power sources. P-C retunes Rivet's own **start** numbers first, against the bot clear time and damage taken on the pre-wave base. `pack_scale` (`src/core/alpha_defs.gd:60-63`) is shared by all six pilots, so it moves only at the wave close.

## 11. For Andrew

### Veto list (Calls; say "veto" on a line and it changes)

1. Line Drive on a machine throws it down the cable and keeps the line latched, so you can winch in after it.
2. Line Drive on a wall hauls you in at 24 m/s, and crowd control slides off for the haul.
3. Line Drive is a tap, so Rivet's bar keeps one gauge only.
4. The blast keeps today's numbers; charging it now silences the laser for up to 1.5 s, and the 3 s boost pays it back.
5. The Foundry Cutter is a hand-aimed beam on the reticle, with no auto-targeting.
6. Every Rivet set piece lands in a forward skid that keeps your banked speed and hands you a sprint charge (A2-CRITIC removed the 27 m/s floor).
7. The Breach Skid counts as a slam for burrowers and drill crews.
8. In world 2 the tree pick is always Prism Cutter against Juggernaut Drive.
9. Depth 3 and 4 picks keep their old kit perk beside the ultimate change.
10. Rivet gets one knob of his own: set-piece throws twice as hard, so pins hit harder.
11. The beam grows with the drill: 0.6 m at class I, 1.0 m at class V.
12. Earned items: Swarf Curl trail, Welding Hood outfit, Calibrated shell.

### Open questions for Andrew

1. Should Rivet's slot 2 become a tap (a full-size blast on the click) so the laser never goes quiet? Default: no, it stays a gauge; the run log's silence measure decides after your sitting.
2. Magnet Blast (kept at depth 3) pulls machines in, close to Tarn's clamp. Keep it, or cut it in a later pass? Default: keep it this wave.

### Open for the coordinator (not Andrew)

1. Resolved (SKILL-BAR section 12, item 3): B1 adds `line` and `ultimate` to `upgrade_tree.KEYS` and accepts a swap to a `variant_of` row as growth.
2. Resolved (SKILL-BAR section 12, item 4): B1 pre-seeds one marked block per pilot in `KNOBS` and the other shared tables.
3. The beam's clamp and its 3-machine pierce override the framework's "3 targets within 10 m". Default: B3's `_ult_rows` tech callable owns its own targeting.
4. Stale text: the comment at `achievements.gd:40` calls Rivet a starter, and `CHARACTER-BIBLE.md:68` gives him mint. Default: fix both in the polish lane.
5. Cosmetic rows whose art lands in P-D. Default: rows land in P-C only if B5 accepts pending assets.

### Optional extras (separable, not in the unit)

- **Overclock.** While the sprint runs, Line Drive's cooldown runs twice as fast. The sprint already turns other actions into speed; this would turn it into punches. It risks spam against the world-2 counters, so it waits for a sitting.
- **The scar as a rail.** The Full Cut's copper scar becomes a 1.5 s ground rail that any later pilot move can grind. It touches the rail search in `plan()` and the world's rail rows, so it waits for a later wave.
- **Calliper reading.** Before Q, holding the aim on one Warden plate for 1 s marks it; the beam does double posture to a marked plate. Precision as a mechanic, in the spirit of "Measured twice. Firing once." It adds a read to the Warden fight, so it needs the K-F Warden sheets first.
