# Poles and flails: what the harpoon does to an enemy

Status: design proposal, written 2026-10-17 for wave 20 (decision row ENEMY-SPLIT: "Wave 20: poles and flails on the harpoon, first in the wave"). Nothing here changes code. Code in `src/` belongs to the wave coordinator; each unit names the files it would touch. Numbers marked (start) are starting values for the lab and the sitting. Paths are under `sketches/core-loop/`. Builds on `ENEMY-PRIORITY.md` lever 6 (PR #23, merged into the wave 16 candidate, not yet on main) and [HOOK-CHAIN.md](HOOK-CHAIN.md); written against the tone bible (`tone/TONE-BIBLE.md` on the project's shared folder, repo copy on PR #20).

Andrew's asks this answers: chaos with many attackers that stays learnable and fair (16 Oct 23:44Z); the 3D space as a jungle gym with grapple tricks; ball downforce and half-pipe carving; fun depth, not gimmicks; difficulty that scales with player power like Binding of Isaac (all in project memory, 16-17 Oct).

## 1. The ask as verbs

- **Using an enemy as terrain.** A big machine is a post you can swing round: it redirects your speed without a wall.
- **Using an enemy as a weapon.** A small machine on your line is a wrecking ball: you drag it through its friends, then throw it.
- **Outgrowing the fight.** What was a pole in stage 1 is a flail by stage 5, because you got heavier. Growth is felt in the hands, not only in a number.
- **Reading before you press.** The lock shows which one you will get before you fire.

Disciplines: systems design (the weight rule), encounter design (enemy answers), level design (where heavies stand in a bowl), sound (three bite voices), playtesting (lab arms and the red team's exploit hunt).

## 2. What the harpoon does today (checked in code)

| Fact | Where |
| --- | --- |
| A press bites the locked enemy or the world, reach `rope_range` 45 m | `src/movement/harpoon.gd` `target()`, `tuning.gd:18` |
| Holding the harpoon on an enemy winches the **ball** to it; the line only ever pulls the ball | `augments.gd` `_winch_body` (line 790) |
| Ctrl on an enemy line commits the smash, which homes on the body | `augments.gd` `commit_smash`, `_haul` |
| A Warden is already a moving **anchor**: the line rides it like a world line, the held winch stops at 6 m and the ball orbits | `augments.gd` `anchor_line`, `_ride_anchor`, `ANCHOR_MIN_ROPE` |
| Coil Hook flings you on along your swing when you let go | `player_ball.gd` `_fling`, knob `grapple_fling` |
| Heft vs an enemy's rating already decides two holds (mag trapper pit, hooker tether): heavier than the rating rolls through | `mag_trapper.gd:161`, `hooker.gd:138` |
| Ball heft classes at 1.0, 1.5, 2.2, 3.2, 4.6 | `run_state.gd:24` |
| The roster has no enemy weight column (ENEMY-PRIORITY lever 6 assumed a "roster weight"; it does not exist) | `roster.gd` CHASSIS table, lines 141-176 |

So the pole is half built (the Warden anchor orbit) and the weight test is a pattern the game already teaches (the mag pit). The flail is new: nothing today moves an enemy along the line.

## 3. The rule, one line: weigh more and it comes to you

Each enemy gets a **heft** by chassis. When you hold the harpoon on a bitten enemy, the game compares your heft with its heft:

| Your heft against its heft | You get | What happens |
| --- | --- | --- |
| lighter by 0.25 or more | **Pole** | you winch in to 6 m and orbit it; let go to slingshot off the tangent |
| within 0.25 | **Reel** | today's harpoon, unchanged: you winch to it |
| heavier by 0.25 or more | **Flail** | it winches to you, hangs on the line at 5 m and swings behind you as a weapon |

Ctrl is the smash in every row, unchanged. A combo of 1 and a ball that never holds the harpoon play exactly today's game: the floor stays, the ceiling rises (the HOOK-CHAIN principle).

### Enemy heft by chassis (start)

| Chassis | Kinds | Heft (start) | Stage 1 fresh ball (1.0) | Grown ball (3.2+) |
| --- | --- | --- | --- | --- |
| swarm | swarm remnant, lamp swarm (one drone at a time) | 0.6 | flail | flail |
| hover | winch drone, kite drone | 1.1 | reel | flail |
| crawler | chaser, Splitter pieces (0.6 scale: 0.7) | 1.4 | pole | flail |
| burrower | burrower (only while surfaced) | 1.8 | pole | flail |
| emplacement | lobber, mag trapper, hooker, netcaster, bola, deflector, gyro, swatter, ramp flipper, catch trap, drill crew, line cutter, anchor crew, mind hand, Foreman, Linker | 2.6 | pole | flail: **ripped out of the floor** (see fork 2) |
| heavy | miniboss, plated brute, reactor relic | 4.0 | pole | pole until class V (4.6) |
| cache, Warden, bosses | vault, Wardens, Brindle, the Waking, the Mind | never a flail | pole | pole |

Elites add +0.5 (a hard-tier affix is a bigger machine). The director's threat scaling does not raise heft, so growth always wins in the end.

**Why weight and not a button.** It reuses one fact the player already reads (am I big?) and turns the growth rule into a feel: the same chaser that dragged you round at stage 1 is a club at stage 5. A Binding of Isaac power curve the player can see without a menu.

## 4. The pole

| Piece | Rule (start) | Player feels |
| --- | --- | --- |
| Orbit | Reuse `_ride_anchor` for a pole line: the held winch stops at 6 m, tangential speed is kept, the rope cancels only outward speed measured against the moving body | swing round a brute like a lamp post |
| Exit | Let go: the existing fling (`grapple_fling`) plus a pole bonus of 15% of tangential speed (start), along the tangent | slingshot out at an angle no wall offers |
| Speed cap | Exit speed obeys the speed soft cap (Andrew, 07:17Z 17 Oct): past 60 m/s it becomes hit damage and the blazing trail, not velocity | infinite laps cannot make infinite speed |
| Brace | After 1.6 s (start, about two laps at cruise) the enemy braces: a creak, its bite collar flashes on the beat, and 0.4 s later it snaps the line with a 4 m/s outward kick. No hull damage | you choose when to leave, but you must leave |
| Turn | A poled enemy turns to follow the line. Its facing-dependent read (the brute's raised slab, the deflector's dish, the lobber's tube) swings round with you | orbit to its back: the pole is a flanking tool |
| Chain | A pole bite is an enemy link (+1); laps add nothing (walls and laps are routing, enemies are the beat) | pole, fling, bite the next one |

## 5. The flail

| Piece | Rule (start) | Player feels |
| --- | --- | --- |
| Yank | The held winch pulls the enemy to the ball at `reel_speed` 16 m/s; it hangs at 5 m and trails behind on the line as a kinematic follower (no ragdoll physics, so the frame budget holds) | a machine on a string |
| Out of the fight | A flailed enemy cancels its warning with a visible fizzle and gives its attacker slot back (`attack_budget.gd` `release`). The director does not refill that slot while it hangs | yanking one out of a pack makes the pack smaller, honestly |
| Hits | It strikes what it touches. Damage = its own contact damage x (ball speed / cruise), at most 3 hits, 0.4 s per target (start). Each hit also costs it a third of its health | swing it through the crowd |
| Throw | Let go: it flies on along the ball's velocity and strikes once more on landing. After 2.5 s or the third hit it is thrown for you | the finisher is a throw, not a drop |
| Smash | Ctrl while flailing: overhead slam, the flail hits the ground ahead in a 4 m ring (the same ring geometry draws its own warning ring, so the hit and its read never differ) | the comic-book KLANG |
| Weight on you | While towing, turn rate drops 15% (start). Carving with a flail drags it along the wall in a spark trail that hits everything on the wall lane | heavy, satisfying, and a little clumsy |
| Chain | Each flail hit on another enemy is a link (+1) while airborne | a flail is the fastest combo builder, on purpose |

**The kind gag** (tone bible "Enemy moments"): a flailed chaser's little legs pedal in the air; a thrown one clocks out mid-flight with an "OVERTIME" stamp. Sound-effect words only: WHIRR on a pole, YOINK on a yank, KRAK on a rip-out, BONK on a throw. No text the player must read.

## 6. With the grapple, half-pipe carving and the attacker budget

| System | How poles and flails fit |
| --- | --- |
| Grapple and hook chain | Pole and flail are what holding the harpoon does on an enemy; walls stay as today. A pole is the enemy-side pivot HOOK-CHAIN lacked: enemy (pole) to enemy (bite) keeps the combo rising instead of resetting through a wall |
| Half-pipe (grip and carve, wave 18) | A heavy at a bowl's centre is an air pivot: carve the wall, pole the brute, exit onto the opposite wall at speed and grip catches you. Level rule for stage builders: every bowl's centre or lip deck has one pole-weight enemy (heavy or emplacement) in at least one pack |
| Speed soft cap | Pole exits feed the cap; flail damage scales with ball speed, and past 60 m/s the flail catches the blazing trail too (a burning wrecking ball) |
| Attacker budget (PR #15) | A flailed enemy leaves the count; a poled one keeps its slot. Flail hits are not warnings, so MIN_GAP 0.2 s is untouched. A grown ball meets a larger cap and gets more flails to spend it on: chaos scales both ways |
| Growth rule (grown clears hives 2x faster) | Flails are where a grown ball's extra speed goes. The lab gate below checks the 2x still holds and does not jump past 3x |

## 7. How enemies answer it

At most two new behaviours a wave (ENEMY-SPLIT). Pole and flail are wave 20's two; every answer below is a row or a reuse, not a new behaviour.

| Enemy | Answer | Lesson |
| --- | --- | --- |
| Line cutter (Highdraft) | Its thrown disc already cuts any harpoon line it lands on (`line_cutter.gd`), so it cuts poles and flails with no change | the Highdraft taxes long orbits; glide under the arc or kill it first |
| Drill crew (Dig) | A line that stays on it past one beat is cut (HOOK-CHAIN, "what the enemies get later") | the Dig rewards quick yanks over long orbits |
| Deflector | A flail thrown into its dish comes back at restitution 0.9 and can hit you | throw round it, or pole it to its back first |
| Hooker | Its tether and your line make a tug of war: the existing heft vs `rating` decides who flies | weight is the counter, as it already is |
| Plated brute, heavies | The brace (section 4); the brute's slab turns with you, so a long orbit can bring the slam round to you | two laps, then leave |
| Swarm remnant | Yanking one drone breaks the formation: the whole dive lane cancels | one yank answers a swarm |
| Foreman (kill first) | A pole; its crew are flails. Fling a crew member into the Foreman to reach it through the pack | the jungle-gym route to the kill-first target |
| Dispatcher (perched) | A pole on its perch is a way up; its dropped chasers are flails to throw back | go up, or throw up |
| Splitter | A thrown flail counts as a hit from range: it dies clean. Rammed or flailed at ground level, it splits | throw it, never drag it |
| Linker | A flail swung through its cable cuts it | a second way to cut the cable |
| Bosses | Never flails. Their Wardens stay anchors (pole only during stagger, as `haul_open` already rules) | bosses are never limited |

## 8. Pilots

| Pilot | Twist (start) | Why |
| --- | --- | --- |
| Tarn | Counts every enemy one band lighter (pole becomes reel, reel becomes flail); Claw Drag already "climbs what it cannot move" | "everything comes to the tiger"; a flail throw reaches the perched targets she struggles with |
| Sable | Pole exit bonus 25% instead of 15%; her stakes stay world posts | the fastest pilot gets the best slingshot |
| Rivet | Flail hits count as Overdrive hits | answers her swarm nemesis with the flail |
| Kest | A charge laid on a flail rides it and detonates on the throw | a delivered bomb fixes her fuse problem |
| Tally | Each flail hit refills one round, as rolling does | answers "a held ball has an empty gun" |
| Cannon | None on purpose; it keeps the base rules | its identity is the lane, not the line |

## 9. Items

Existing items that change meaning with no new code beyond the rule:

| Item | Effect on poles and flails |
| --- | --- |
| Ballast Drum, Scrap Armor, Rivet Seam, Low Rider (mass) | heft items become harpoon items: they move enemies from pole to flail sooner |
| Grapple Coil (+20% rope range) | longer reach for the yank; orbit radius stays 6 m |
| Coil Hook (`grapple_fling`) | adds to every pole exit |
| Pin Setter, Ten Pin, Domino Wire (on smash) | a thrown flail counts as a pin, so pin items trigger off throws |
| Momentum Thief | flail hits on you do not count; it stays a hit-taken item |

New items, after the sitting unless Andrew pulls them in (each needs an icon and art, so it would add placeholders in wave 20):

| Item | Effect (start) | Effort |
| --- | --- | --- |
| Tow Hook (replaces ENEMY-PRIORITY lever 10, now base) | flail lasts 4 s and 5 hits | S |
| Pendulum Weight (ENEMY-PRIORITY lever 11) | pole exit speed above cruise adds to the next smash | S |
| Double Line | hold two flails at once, on opposite sides | M |

The `answers` tags (lever 8, "Nudge loot") gain one value, `line`, on Ballast Drum and Tow Hook, which answers the swarm and perched nemeses.

## 10. Fair and learnable: the read

| Read | Pole | Reel | Flail |
| --- | --- | --- | --- |
| Lock bracket shape (before the press) | a ring round the body | today's bracket | a hook under the body |
| Bite voice | low clunk | today's `line_bite` | high zing |
| Line look | taut, straight | today | slack, bowed |

The lock already shows before the press (`harpoon.gd` `target()` feeds the reticle and the world marker), so the read costs one field on its record. Colour stays on the line's existing palette; shape carries the meaning so it reads in colour-blind modes.

## 11. Units for wave 20

| Unit | Owner files | Done when |
| --- | --- | --- |
| PF1 weight rule and read | `roster.gd` CHASSIS `heft` column, `harpoon.gd` record field `grip: pole/reel/flail`, `src/presentation/line_view.gd` bracket shapes | table test: 12 pairs of ball heft and enemy kind give the expected grip; still of each bracket |
| PF2 pole | `augments.gd` (`anchor_line` widened to pole lines, brace timer), `player_ball.gd` exit bonus | scripted orbit: exit speed within 5% of the formula; brace breaks at 1.6 s; no orbit lasts past 2.0 s in 16 seeds |
| PF3 flail | `augments.gd` `_winch_body` reversed for flails, new follower in `src/combat/flail.gd`, `attack_budget.gd` release on yank | scripted yank: warning cancelled, slot freed, 3 hits then throw; no flailed enemy ever damages the ball |
| PF4 sound and words | `event_kinds.gd` rows `line_pole`, `line_flail`, `pole_brace`, `flail_hit`, `flail_throw`, `flail_rip`; `audio.gd`; music thread cues | sound test: each row has a cue within 5 ms; hit sounds land, musical answers on the next beat (INTEGRATION.md) |
| PF5 enemy answer rows | roster rows for the answers in section 7 | one scripted case per answer |
| PF6 lab arms | headless lab: `harpoon: pole_flail on/off` arm, matchup lab cells | gate below |

PF1 lands first and alone (it touches the harpoon). PF2 and PF3 follow on disjoint functions, then PF4 to PF6.

**Hard targets for the gate** (no thread grades itself; a tool check plus an independent reviewer):

1. Grown ball still clears hives at least 2x faster than small, and no more than 3x (flails must not trivialise the late game).
2. Explorer bot `best_combo` median rises by at least 1 over 16 seeds with the arm on.
3. The skipper bot's smash damage per fight moves less than 10% (players who never hold the harpoon play today's game).
4. Frame time p99 stays in the 60 fps budget in a swarm flail stress scene (12 attackers, two flails thrown per second).
5. The red team's speedrunner gets one session hunting pole and flail exploits (orbit speed, throw-through-walls, flail into boss arena); every find is a bug-bar row.

## 12. Forks for Andrew

1. **What decides pole or flail.** Recommended: weight (this page). Alternatives: a button (Ctrl-tap yanks, hold orbits; any enemy can be either, more control, but it takes Ctrl from the smash and drops the growth feel); or a fixed kind per enemy (simplest, no growth payoff).
2. **Can a grown ball rip emplacements out of the floor.** Recommended: yes (14 of the 25 kinds are emplacements, so late runs turn most of the Fleet into clubs; the KRAK moment). Alternative: emplacements stay bolted down and are always poles (late game keeps more of its threat; flails stay drones, crawlers and Splitter pieces).

Decided here, reversible: Ctrl stays the smash on every line; flails never hurt the ball; bosses are never flails; new items wait for the sitting.
