# Enemy priority, pilot struggles and the jungle gym

Status: design proposal, written 2026-10-16 from Andrew's project-chat asks (23:44Z, 23:46Z, 23:49Z). Nothing here changes code. Code in `src/` belongs to the wave coordinator; each lever below names the files it would touch so the coordinator can cut units. Numbers marked (start) are starting values to tune in play. Paths are under `sketches/core-loop/`.

Andrew's asks, in his words (23:50Z added the half-pipe): some enemies should be "a priority to take out, or should be avoided or dodged a certain way, and could also breed innovation from the player"; pilots "may have struggles ... a really hard time dealing with some enemies", which "player skill and the ability to also augment themselves by chance or by intentional player choice overcome"; difficulty scales with player power like Binding of Isaac; use Roboquest too; treat the 3D space as a jungle gym, with grapple, pilot and item twists; give the ball "downforce" so it "adheres to surfaces ... like you're a skateboard shredding in a half pipe", where the half-pipe is the arena; and design maps whose terrain and enemy placement complement each other, with layers that have depth but "don't feel like gimmicks" and are not "super austere or complex".

## 1. The ask as verbs

- **Choosing a kill order.** A pack has one enemy that makes everything else worse while it lives. Reading which one, and getting to it, is the skill.
- **Reading a dodge.** Each enemy's attack has one right answer (already true: the no-reskins rule and each row's `breaks`).
- **Being moved by the fight.** The right dodge throws you up, around or through the park, so combat feeds traversal instead of stopping it.
- **Carving.** Speed holds the ball to a wall; the wall turns speed into height; height turns into a hit.
- **Losing a matchup, then winning it.** Each pilot has enemies its kit handles badly. Skill handles some of it; an item found by luck or picked on purpose handles the rest.

Disciplines: encounter design (kill order), level design (perches and anchors), systems design (item answers), playtesting (the matchup lab, a red team).

## 2. What already exists and gets reused

| System | Where | What it already gives |
| --- | --- | --- |
| One mechanic per enemy, with its answer | `src/combat/roster.gd` rows: `mechanic`, `breaks`, `tests` | the Isaac "dodge it this way" half is built: 22 kinds, each with its own read |
| Controller plus punisher packs | `src/world/director.gd:61-70` | enemy synergy: one holds you, one punishes the hold |
| Build tilt | `director.gd:27-31`, `:764-787` | packs that test your build's own axis come up to twice as often |
| Hook chain | `design-v3/HOOK-CHAIN.md` | enemy, wall, enemy chains pay the smash up to x2.5; walls are pivots |
| Hold break kick | `src/combat/holds.gd:41-44` | a player-made break shoves 4 m/s and refunds 0.6 s |
| Contraptions | `src/world/contraptions.gd`, `PARK.md` 2.6 | launchers, cables, lifts, thermals: momentum tools in every park |
| Elite affixes | `src/combat/elite_affixes.gd` | one added behaviour plus one stat on an existing chassis |
| Pilot kits and hulls | `design-v3/PILOTS.md` sections 1, 2, 7 | reach, fuse, pressure and hull already differ a lot between pilots |
| Item pool | `src/build/items.gd`, `parts.gd` | range, spread, chain, fuse, cc and mobility items already exist to answer a weakness |

## 3. Four gaps found in the code

1. **No enemy is a kill-first target.** Every roster row is a `controller`, a `punisher`, a `cache` or a `warden` (`roster.gd` header). Nothing makes the room worse until it is removed, which is the core of Isaac's kill order (spawners, buffers) and of Roboquest's elites with auras.
2. **The harpoon cannot get you out of a grab.** `PLAYER_BREAKS` is jump, boost, smash, glide, speed and ultimate (`holds.gd:41`). Biting a wall does nothing to a hold, so the game's best verb is useless at the moment it matters most. Only Rivet's Line Drive hauls out (`PILOTS.md` section 1).
3. **The pilot tilt never fires in play (bug).** `CLASS_AXIS` is keyed `sable`, `rivet`, `kest` (`director.gd:83`), but `build_read()` passes the class id, such as `demolitions_caster` (`src/combat/fleet.gd:200-202`, ids in `src/core/class_def.gd:96-137`). Tarn, Tally and the Cannon have no row. The unit test passes because it builds its read with `"kest"` (`tests/unit/enemy_director_case.gd:118`). Found by reading the code; not reproduced in a run.
4. **The ball cannot ride a wall.** It counts as grounded only on a surface whose normal is above 0.45 (`src/movement/tuning.gd:81`, `ball_rules.gd:39`), a slope under about 63 degrees. Steeper than that, it is airborne and falls, whatever its speed. The Warden bowl's 24 degree bank (`LOOP-REDESIGN.md` section 1, option A) is a ramp, not a half-pipe.

## 3a. The half-pipe: downforce and carving

**The rule, one line: speed holds you on.** Above cruise, the ball grips any surface up to vertical, and past it for a moment; below cruise it peels off. This is the rule Tony Hawk's and Sonic's loops teach without a tutorial, so it needs none here.

| Piece | Rule (start values) | What the player feels |
| --- | --- | --- |
| Grip | At speed tier 2 or above (16.1 m/s), the grounded threshold drops from a normal of 0.45 to -0.2: walls and the first part of an overhang count as ground. A downforce of `k x speed` (k 0.6, start) presses the ball into the surface so it stays on through curves. Below tier 2 for 0.25 s on a surface steeper than 63 degrees, it peels off. | carve round the bowl wall; slow down and you drop |
| Pump | Landing on a down-slope keeps the speed along it; landing flat costs it as today. The smash (Ctrl) on a down-slope pushes along the slope instead of down, the way Rivet's Shockwave Skid already turns a fall into forward speed. | pumping the transition: the skater's way to make speed without a boost |
| Lip | A wall that ends at a lip throws the ball straight up off it at its wall speed. Air off the lip and land back on the wall to keep the speed. | big air on purpose, and a clean re-entry |
| Read | Grip shows as a spark trail where the ball meets the wall and a rising grind tone; peeling off is a scrape and the trail breaks. | you hear and see when the grip is about to go |

**Why this is depth, not a gimmick.** It feeds the spine the game already chose: the Warden takes real damage only from a ball that lands on its open core at speed from above (`LOOP-REDESIGN.md` option A). A half-pipe bowl is the run-up built into the arena: carve the wall to build speed, launch off the lip, drop onto the core. One rule (speed holds you) serves movement, combat and the boss.

**Risks.** This changes the core feel of rolling, so every traversal bar in `TRAVERSAL.md` is re-run with it on and off. The chase camera must follow the ball onto a wall without flipping; the first unit is the camera test. It ships behind a lab toggle (`grip: on | off` in `tuning.gd`) so Andrew can feel both at the sitting.

## 3b. Maps where terrain and enemies complement each other

Each park area gets three heights, and each height has a reason to go there and an enemy that taxes it.

| Height | Why you go there | What taxes it | Answer that moves you |
| --- | --- | --- | --- |
| Floor | loot, pickups, the core when it is open | mag trapper pits, swatters, catch traps, burrowers | carve up the wall; hook out to a post |
| Wall | speed: it is the safe lane while you are fast | lobbers on the lip deck lob shells onto the wall lane; the chaser's lunge lane runs along it | bat the shell while carving (speed already bats it); jump the lane into air |
| Air | the drop on the core; kill-first targets on perches | netcasters over the lip, line cutters, kite drones | glide under, land early, carve back down |

Placement rules for stage builders (start):

1. A kill-first target (Foreman, Dispatcher) sits at the height the stage's main pack does not cover, so reaching it changes your height.
2. Every hold on the floor has a wall or a post within harpoon reach (45 m) to hook out to.
3. Every bowl has one lip that throws toward the Warden's core and one that throws toward a perch: the player chooses damage or kill order.
4. An enemy is never placed so its telegraph sits on a lip's landing zone; you must be able to read where you will land.

## 4. Levers, ranked by fun per effort

Effort: S is a row or a constant plus a test; M is a new behaviour on an existing chassis or a lab scenario; L is a new body, model or system.

### Before the sitting: reuses existing enemies and systems

| Rank | Lever | What the player feels | Effort | Touches |
| --- | --- | --- | --- | --- |
| 1 | **Hook out.** A harpoon bite on world geometry is a player break for any hold whose row lists `hook`. The break kick goes along the line, not straight back, at 7 m/s (the snap kick). Add `hook` to mag trapper, gyro jammer, catch trap, winch drone and bola thrower; leave it off the netcaster (air is its point) and the anchor crew (its own cable). | every grab is a grapple prompt; escaping flings you toward a wall and into the next chain | S | `holds.gd` `PLAYER_BREAKS`, harpoon bite hook in `src/movement/player_ball.gd`, roster `breaks` |
| 2 | **Grip and carve** (section 3a), behind a lab toggle, plus the half-pipe rim on the stage 1 bowl first. | the arena becomes a half-pipe; speed builds on the wall and pays on the core | M | `ball_rules.gd`, `tuning.gd`, `chase_camera.gd`, bowl geometry in the stage 1 park |
| 2b | **Fix the pilot tilt and add a nemesis column.** Key `CLASS_AXIS` by class id and add the three missing pilots. Add `nemesis` per pilot: the one or two axes its kit is weakest on (section 5). From world 2, nemesis packs weigh 1 + 0.5 (start), alongside the build tilt. | each pilot meets its bad matchups often enough to learn them | S | `director.gd:83`, `enemy_director_case.gd` |
| 3 | **The Foreman** (kill first: buffer). An elite affix on the lobber chassis with a horn mast. Thin tether lines run from it to each crew member in its pack. While it lives, its crew's plating shred is wiped every 5 s (start) and the horn blasts on the beat before each wipe. Kill it and the crew clocks out for 1.5 s: a stamped "SHIFT OVER" word and a sigh of steam, the tone bible's downed-machine gag. It never attacks, so it does not count as an attacker. | a pack you cannot grind down until you find and reach the boss of it | M | `elite_affixes.gd` row plus a behaviour, `src/combat/lobber.gd` hook, director pack rule |
| 4 | **The Dispatcher** (kill first: spawner). The cache chassis (the vault body) on a perch 6 to 10 m up: a post top, a ledge or a contraption. It drops one chaser every 8 s (start) until broken, spending the attacker budget, so it fills the cap rather than breaking it. Reach it by grapple, vault or a long gun. | Isaac's spawner: ignore it and the field fills; deal with it and you had to go up | M | new behaviour on the vault body, park perch points, the attacker budget from PR #15 |
| 5 | **Perches.** Kill-first targets spawn on high points the park already has: post tops, ledges, cable towers. The director asks the park for a perch within 40 m of the pack. | the fight pulls you vertical; the gym is where the priority is | M | `director.gd` placement, park rows gain `perch` points (stage builders) |
| 6 | **Poles and flails.** A harpoon bite on an enemy heavier than the ball (roster weight 3 or more: lobber, miniboss, brute) swings you round it like a pole; a bite on a lighter one yanks it to you. Check today's harpoon first; Tarn's Claw Drag already climbs what it cannot move. | enemies are monkey bars; a big one is a pivot for the hook chain | M | `src/movement/harpoon.gd`, `player_ball.gd` |
| 7 | **The matchup lab.** A headless duel table: each of the six pilots against each enemy kind alone, 8 seeds, recording time to kill and hull lost. It prints a heatmap. The gate: every pilot has at least one cell marked hard (time to kill over 2x the row median), and the brawler bot wins every hard cell once given that cell's answer item. | proof that each pilot struggles and that every struggle can be beaten | M | `tools/`, headless lab scenarios (scrapkeep-lab) |
| 8 | **Answer weighting.** Each item gets an `answers` tag (range, spread, fuse, cc, air, plating). Reward gates and shops weigh items that answer the run's pilot nemesis by 1.5 (start). See the decision card. | luck leans your way, so a hard matchup becomes a run where you hunted for the fix | S | `src/build/reward_gates.gd`, `shop.gd`, item rows |

### After the sitting: new bodies or new systems

| Rank | Lever | What the player feels | Effort |
| --- | --- | --- | --- |
| 9 | **Zip Spool** (item). Two harpoon bites within 1 s string a rail between the anchors for 6 s. | build your own grind rails mid-fight | M |
| 10 | **Tow Hook** (item). A light enemy on your line trails behind you as a flail and hits what it touches. | the yank becomes a weapon | M |
| 11 | **Pendulum Weight** (item). Swing speed at the bottom of an arc adds to the next smash. | rewards long swings round poles and posts | S |
| 12 | **The Splitter** (kill carefully). A scrap-bomb chaser that bursts into three small chasers when rammed, but dies clean to a smash from above or a shot from range. | breeds the innovation Andrew named: you learn to kill it from the air | M |
| 13 | **The Linker** (kill order). A deflector that braces its dish over a partner instead of itself. Flank through the air or break the dish first. | the protected target is behind the gym, not behind a health bar | M |
| 14 | **Pilot gym twists.** Tally's clipped enemies become anchor nodes (a ledger web); Kest's charges stuck to walls launch her (her `on_rocket_jump` hook); the Cannon's committed lanes become grind rails; Sable's stakes already stand as posts. | each pilot plays the same park a different way | L |
| 15 | **Altitude bands.** Spillway's kill-first targets sit on the ground, the Dig's under and above you, the Highdraft's in the air, so each world tests a different height. | each world's chaos has its own shape | L |

## 5. Pilot struggles

Inferred from each kit's numbers (`PILOTS.md` sections 1 and 2, `src/combat/weapons.gd`); the matchup lab (lever 7) measures them. Each pilot gets one or two hard cells on purpose. Andrew said he does not mind if a pilot has a really hard time.

| Pilot | Why it struggles | Hard against | Skill answer | Item answer (existing) |
| --- | --- | --- | --- | --- |
| Sable | 12 damage a bolt chips off plating at 20% | plated brute, deflector | Bank Shot into a ram at blazing speed | `damage_tier` (Hot rounds), `ballast_drum`, heft |
| Rivet | 84 a second, but one target at a time | swarm remnant, lamp swarm, the Dispatcher's stream | Overdrive Blast ring on the cluster | `cross_split`, `fan_spread`, `chain_arc` |
| Kest | 1.2 s fuse and the lightest hull (80) | chaser, burrower, kite drone: they leave the charge | lay charges on the lane they will use | `quick_fuse`, `tracer_round` |
| Tarn | 5 m reach | kite drone, winch drone, lobber, line cutter, any perched target | Claw Pull up to it, Claw Drag it down | `long_barrel`, `range_tier`, later the Tow Hook |
| Tally | rolling refills her gun; she has no burst | catch trap, mag trapper, anchor crew (a held ball has an empty gun); plated brute | Flywheel Surge before the hold lands; Gather Plate the pack | cc parts such as `brace_frame`, `damage_tier` |
| Cannon | its lane lands 1.4 s late | kite drone, chaser, swarm remnant | fire where they are going; Recoil Split away | `tracer_round`, `rate_tier` |

## 6. How difficulty scales with power

The attacker budget thread (PR #15) scales how many attack at once with build strength. This page adds what they are: the director's kill-first share rises with the same build strength, from 0 in stage 1 to one Foreman or Dispatcher in about every third pack by stage 6 (start). A stronger build therefore meets more packs that need a kill order, not only more enemies. Bosses are unchanged.

## 7. References, used for structure only

- **Binding of Isaac:** spawners and buffers that set the kill order; enemies with one right dodge; item pools that let luck fix a weak character; characters that are bad at some rooms on purpose.
- **Roboquest:** elites with auras that you remove first; snipers and fliers that make you go vertical; jump pads and the grapple as combat tools.

## 8. Open calls for Andrew

Three decision cards go to the project chat through the coordinator:

1. How a pilot's bad matchups get answered: loot nudged toward the answer (recommended), one answer guaranteed in the world 2 shop, or pure luck.
2. Which kill-first enemies go in before the sitting: the Foreman and the Dispatcher (recommended), all four, or none until after.
3. How the ball sticks to walls: speed holds you on, automatically (recommended), a held grip key, or grip only as an item or pilot trait.

Decided here, reversible: hook out applies per row, not to every hold; the Foreman never attacks; the Dispatcher spends the attacker budget.
