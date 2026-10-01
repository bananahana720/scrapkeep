# Core-loop v3: systems and chaos (the snowball and the replay)

Design only. The Systems and Chaos lead's answer to LOOP-REDESIGN §8 ("go nuts, go butts") under the recommended Drop Loop (§1 Option A), with §13 saying what changes under Laps. Base `proto/core-loop-v3-systems` at 43eeeea. Sources read: `docs/playtests/PLAYTEST-LOG.md` entries 7 and 8, `LOOP-REDESIGN.md`, `research/R1`, `research/R2`, `DESIGN-V2.md` §7 and §15, `design-v2/PROGRESSION.md`, `design-v2/I2-item-generator.md`, `DESIGN-NOTES.md` (writer B, writer L, W3 trees, W4 loot, W7 enemies), and the code under `src/build/` (`parts.gd`, `items.gd`, `part_def.gd`, `synergies.gd`, `triggers.gd`, `item_effects.gd`, `shop.gd`, `reward_gates.gd`, `fabricators.gd`, `run_clock.gd`), `src/core/upgrade_tree.gd`, `src/core/trees/*.gd`, `src/core/stage_defs.gd`, `src/core/run_state.gd` and `src/world/director.gd`. Numbers cited from those files are facts; numbers introduced here are starting values for the balance report, never tuning.

Spikes run for this doc are in §14: S1 (offer-rule simulator, branch `proto/core-loop-v3-systems-2`), S2 (one evolution end to end behind a flag, `proto/core-loop-v3-systems-3`), and R3 (web scout, `proto/core-loop-v3-systems-1`). None is merged.

**The one sentence.** A run starts as one gun on a ball and ends as a ball that is the weapon: every rebound, drop, crush and lap feeds a chain the player assembled from small picks at speed, the Warden fight shows the growth as fewer drops, the clock answers with fuller packs, and no two runs assemble the same chain.

**What the code already gives us (facts).** 28 catalogue rows plus 58 item rows and 4 shop cells (`parts.gd`, `items.gd`); 12 closed trigger kinds with a one-kind-per-pass guard and chain depth 1 (`triggers.gd:17-23`); three stacking rules, `linear`, `hyperbolic`, `capped` (`part_def.gd:137-145`); 8 named synergies as literal hint cards plus one unnamed tag rule (`synergies.gd`); 3 pattern parts with the stage-2 guarantee (`parts.gd:144-145`); gates at 0/1/2+ cores (`parts.gd:261-266`); a 25% generated-recipe share (`parts.gd:150`); heft `1 + mass/450 + 0.2 × parts` with classes at 1.0, 1.5, 2.2, 3.2, 4.6 (`run_state.gd:13-15`); 30-node binary trees per pilot with 16 ends and director tags (`upgrade_tree.gd`); the director's build-tilt at `BUILD_TILT = 1.0` over eight tagged packs, 45 s ticks clamped at +2 and `PAST_BREAK_STEP = 0.08` (`director.gd:40-56, 68-69`). What is missing is compounding (a synergy changes behaviour once) and cadence (a pick per stage, not per minute), which LOOP-REDESIGN §8 already names.

## 1. The snowball

### 1.1 The shape of growth

Four ladders, each visible on the ball, each feeding the next:

| Ladder | Grows by | Reads on the ball | Feeds |
| --- | --- | --- | --- |
| **Heft** (exists) | scrap, parts | chunks (36 cap), shell scale per class | drop damage (`heft × impact speed × K`), crush, tether snap |
| **Parts and stacks** (exists, stacks made visible) | hoops, drop gates, break gates, shelf | a piece per part; a stacked part's piece grows a notch per copy and a dark **socket** at cap | triggers, synergies, evolutions |
| **Evolutions** (new) | a ripe part plus its pair, at the Warden break | a **rig** on the pod (Codex visual track) | the chains in §1.4 |
| **Rule parts** (new, §3) | Moss's hook, cursed caches | a paint **band** across the hull per rule (3 max) | the run's shape |

The snowball is the Drop Loop's own rhythm: lap, pick, drop, pick, break, evolve. LOOP-REDESIGN §1 makes heft the damage of a drop, so growth shows in the fight as fewer segments (4 drops at heft I, 2 at heft III on stage 1), and §8's cage on the mast shows the break reward growing. Everything below hangs on that.

### 1.2 Evolutions: the catalogue

**The rule.** A part is **ripe** at `min(2, stack_cap)` copies for linear and capped rows (S1 in §14 measured ripe 3 as too rare for a lapper), at level 2 for the three pattern parts, and when held for rows whose cap is 1 or whose rarity is rare_plus (Ten Pin's cap is 3 in `items.gd:61`, so without this clause it would never ripen). Holding a ripe part plus any *other* held part carrying the pair's tag arms the evolution (the hint-card grammar, `synergies.gd:100-109`, read loosely on the pair side because the catalogue's tag carriers are the accidents). At the Warden break the mast hands the evolved part: the ripe copies leave the part list and the evolved row enters it with `heft_bonus` equal to what left, so **an evolution never lowers heft**. One evolution per break, so three per run at most; the arena has no break. Evolved rows are `rare_plus`, `evolved: true`, never offered by any source and never sold. The pair part stays; it is still a part.

Every evolution below is a **ball verb**: rebounds, rams, drops, momentum, heft, pins. None is a bigger gun. The pair tag names a family so the card can say "something fast" and the socket can wear the family glyph.

| # | Ripe part (copies) | + pair tag (a carrier in the pool) | Evolves into | What it does | Cap (clarity) | Rig on the pod | Director axis |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | Spring Hull ×2 | speed (Light Frame, Tread Plating) | **Pinball Hull** | Every rebound off anything (enemy, wall, deflector, the Warden's core) keeps 95% speed instead of 65%, refreshes an air jump, and re-racks pins within 7 m. The ball is a pinball. | 1 re-rack per 0.5 s | chrome bumper rails on the equator | contact |
| 2 | Ballast Drum ×2 | kinetic (Hot Rivets, Ram Plow) | **Wrecking Drum** | Heft counts ×1.5 for punch and crush. Every crush throws its scrap 12 m down your line (the Katamari trail), and two crushes within 1 s are a Strike. | crush pass-through 6/s (combat's) | a hanging drum on chains | heft |
| 3 | Spiral Wave lvl 2 | split (Double Feed, Cross Split) | **Screaming Spiral** | The spiral stops corkscrewing away: up to 12 bolts orbit the ball at 4 m, and every rebound releases them as a shotgun down the rebound heading. | 12 orbiting; 64 live (`Bolts.MAX_LIVE`) | a spiral vane | weapon |
| 4 | Chain Arc lvl 2 | anchor (Focus Lens, Long Barrel) | **Storm Tether** | Tesla Pylon unmounted: an arc field follows the ball, 2 nearest every 0.5 s within 12 m, and a rebound discharges it as a 12-damage ring. | 12 zap lines (existing) | an arc mast | weapon |
| 5 | Cross Split lvl 2 | kinetic (Slag Rounds, Pin Setter) | **Bowling Cross** | Every split fragment carries knock: an enemy a fragment hits is a pin at 6 m/s (DESIGN-V2 §3 pin rule). The gun bowls. | knock 1 per enemy per 0.5 s | a cross brace | weapon, contact |
| 6 | Impact Driver ×2 | kinetic (Warhead Slug) | **Hammer Hull** | Each rebound fires a weapon volley at the live pattern level down the rebound heading; the third rebound in 4 s (Strike Pocket's window) is a Wrecking Ball ring at ×2. | 1 volley per 0.3 s | hammer heads | contact |
| 7 | Tumbler Bearing ×2 | kinetic (Warhead Slug, Hot Rivets) | **Meteor Frame** | Any landing from 8 m or more, and every drop on the Warden's core, is a crater burst of `10 + 0.8 × fall speed` in 6 m and refreshes both jumps. Drop impact on the open core +20%. | 1 per 0.6 s | a fin skirt | air |
| 8 | Light Frame ×2 | spiral (Gatling Heart, Slipstream) | **Afterimage** | Above the fast tier a 12 m lane trails the ball: enemies it crosses take weapon damage every 0.3 s and scrap in it is pulled. Pinwheel's trailing cousin. | 4 targets per tick | streamer fins | speed |
| 9 | Magnet Coil ×2 | mass (Scrap Armor, Low Rider) | **Scrap Singularity** | The magnet reaches 30 m and pulls enemies lighter than heft toward the ball at 4 m/s, so you crush what you did not steer at. | 6 enemies at once | a coil halo | heft |
| 10 | Static Burr ×2 | arc (Arc Coil, Shock Liner) | **Live Hull** | The hull is electrified: every contact (ram, rebound, stomp) zaps the 3 nearest within 8 m for 8, and water under the ball electrifies (existing table). | 6 zaps/s | arc rings | contact |
| 11 | Frost Barb ×2 | frost (Frost Vane, Rime Rounds) | **Glacier Wake** | The ball freezes a 3 m road behind it on any ground for 6 s; enemies on it slide (knocks travel ×1.5, so more pins); slams shatter it (existing kinetic × ice row). | 12 slabs live | a frost skirt | steer |
| 12 | Hairline Fracture ×2 | anchor (Overpressure, Focus Lens) | **Fault Line** | Every 8 s the next ram at cruise or faster cracks a 20 m lane along your heading: weapon damage ×3 to everything on it over 1 s, and it holds a Warden window open 1 s. | 1 per 8 s | cracked plates | contact |
| 13 | Ring Wave ×2 | kinetic (Warhead Slug, Ram Plow) | **Seismic Slam** | Slams and drops send a ground ring 25 m outward that knocks everything it crosses (pins outward); on the open core the ring is a second hit at 50%. | 1 ring live per 0.6 s | piston legs | contact, air |
| 14 | Cap Relay ×2 | chain (Clean Break, Chain Arc) | **Capacitor Bank** | The special stockpiles to 4 and a full-gauge release fires every stored charge at once, scaled `N^0.7`. | 4 (`MAX_CHARGES`) | a capacitor stack | weapon |
| 15 | Ten Pin (1, rare_plus) | chain (Domino Wire, Chain Arc) | **Perpetual Rack** | Pins chain to depth 3 within 3 s, and every Strike re-racks: the knocked enemies stand back up as a 1-2-3 rack 15 m ahead of you. | depth 3; 1 re-rack per 3 s | rack pins | contact |
| 16 | Salvage Drone (1) | mass (Cache Key, Rivet Seam) | **Drone Rack** | A kill within 1 s of a rebound wakes a follower drone (C11 "Awaiting operator") that rams what you rebound off for 20 s. §9's temporary ally as a build. | 3 drones | dormant drones docked on the pod | contact |

**New parts needed.** None for the sixteen; every ripe part and every pair tag is in the pool today. Two optional commons widen the pair carriers where S1 (§14) shows a tag is scarce: `bumper_skirt` (common, mass + speed, "+10% rebound impulse") and `keel_plate` (common, kinetic + anchor, "+5 punch"). Add them only if S1 shows a pair below 10% reach.

**Reachability is the design risk, not the effects.** S1 (§14) measured it against the real offer code: with no bait and ripe 3, a lapper arms a pair by break 2 in 16.5% of seeds and a completionist in 37.5%; with ripe 2 and an **evolution bait** of 0.35 (one offer slot goes to the ripening part or the missing tag, the `SYNERGY_BAIT` shape at `parts.gd:138`), the lapper reaches 47.5% and the completionist 84% by break 2, and 73.5% and 98.5% by break 3. That is the band: **ripe 2, bait 0.35**, so a completionist's first evolution lands at stage 2 in most runs and a lapper's at stage 3 in most. Two cautions from S1: the bait as simulated fires on any unripe pair in the pool, looser than the live `SYNERGY_BAIT`'s "one piece away", so the wave S1 writer should gate it on the shown part being *held* (the lapper's break-2 number will fall toward the greedy-0 rows); and `tumbler_bearing/mass` topped the reach table (1949 of 4800 cell-seeds) because `mass` is on 33 rows and the bearing ripens at one copy, so Meteor Frame's ripe rule is **2 copies** and its pair tag is `kinetic`, not mass. The evolved row carries `heft_bonus`, because S2 measured heft 1.800 to 1.444 when three copies left and one part entered; without it the break would read as a loss.

**When evolutions arrive (Codex review finding 9).** The evolution lands at the break, after the stage's central challenge, so it pays in the *next* stage's loop, and the run has one stage to learn the rig before the Mind reads it. What lands *during* the stage: the socket notches on every drop gate, the ripe glow, the silhouette in the cage, and Cracked Core (§4), the one way to evolve mid-stage. A rig must change a decision on the loop, which §5.6 measures.

**The tease (LOOP-REDESIGN §8).** A part with an evolution grows a dark socket on its piece from its first copy, shaped as the pair tag's family glyph; each copy adds a notch; at ripe the socket glows; when the pair is held the cage on the mast shows the evolved rig's silhouette rotating. The card names the recipe only after the first evolution ("Spring Hull ×2 + something fast" before; "Pinball Hull" after), and the offer mark reads "* ripens ??? *" until then, the ingredient mark's pattern; S2's prototype leaks the name from zero copies and its hand-back flags it.

### 1.3 Proc chains through the twelve triggers

The guard stays: one kind per pass, chain depth 1, build never feeds itself (`triggers.gd`, DESIGN-NOTES W4 items 1 to 3). Chains do not run *inside* a pass; they run **across passes through the ball's motion**, because each ball verb is its own commitment. That is what makes the snowball ball-native and bounded: a chain advances only as fast as the ball rebounds, lands, crushes and picks up.

Three canonical chains the Drop Loop produces, each link a separate pass:

| Link | Trigger | Ball verb that opens it | Effects that answer it (examples) | Bound |
| --- | --- | --- | --- | --- |
| **The drop** | `on_land` | the drop lands on the core | Meteor Frame crater, Brace Frame, Tumbler Bearing jump, Re-Rack | 1 per landing |
| | `on_kill` | the crater kills the bowl's pack | Drone Rack wakes a drone, Cache Key scrap, Clean Break, Shrapnel Bloom | one on_kill per pass (five kills, one proc) |
| | `on_pickup` | the scrap flies in on the rebound | Lightning Rod arc, Scrap Geyser pins | 6 zaps/s |
| | `on_rebound` | the core throws the ball up the bank | Pinball Hull re-rack, Screaming Spiral shotgun, Hammer Hull volley, Storm Tether ring, Gutter Guard jump | 1 per 0.3 to 0.5 s per effect |
| | `on_speed_tier_up` | the bank into the lift | Slipstream surge, Flywheel charge | 1 per 1 s |
| **The lap** | `timed` | the lap itself | Overpressure arm, Fault Line arm, Beacon Lamp ping | per its period |
| | `on_hit` / `on_smash` | the pack on the lip | Static Burr, Bowling Cross knock, Pin Setter window | weapon proc 0.4 to 1.0 |
| | `on_charge_release` | the special at the lip | Overcharge, Echo Charge, Capacitor Bank | 1 per release |
| **The bet** | `on_damage_taken` | the curse or a punish | Momentum Thief speed, Last Word, Shock Liner return | 1 per hit |
| | `on_vault`, `on_cloak_break` | the pilot's own verb on the line | Long Lane, Jet Vent | 1 per verb |

**The chain rule for new effects.** An evolution's effect may answer a trigger and cause a *different* kind's fact (a rebound causing kills is fine); it may never post its own kind, and every effect declares its per-second cap in its row so `build_catalogue_test` can assert it. The fuzzer (`tools/item_fuzz.gd`) runs with `evolutions` on and reports any effect that exceeds its cap as an anomaly for HAPPY-ACCIDENTS.

### 1.4 Stacking rules, per effect class

The three rules exist (`part_def.gd:137-145`, DESIGN-NOTES W4 item 5). What is new is deciding per effect class and making the choice legible.

| Effect class | Rule | Cap | Why | Reads as |
| --- | --- | --- | --- | --- |
| Flat punch | linear, uncapped | none (heft is the display) | punch is the Warden number; it must keep growing | the objective's "Punch n" |
| Weapon damage / rate / range % | multiplicative per copy (exists) | rate 20/s, 16 bolts a volley, 64 live | combat's caps already bound the screen | bolt stream thins, never stops |
| Cruise speed | linear | +40% (`max_speed` 45) | past 45 m/s the drop lines overshoot the mast | the speed glyph's top tier |
| Damage reduction, cooldown cut, CC resist | hyperbolic | 30 to 40% | never a wall (I2 rule 2) | the dial approaches, never touches, the stop |
| Proc chance (zap, burst, extra hit) | linear to cap copies (3 to 5) | at cap the chance is shown lit, not rolled | a capped chance reads as a rule | the trigger glyph fills |
| Charges | capped integer | 4 | stockpiling stays timing | pips |
| Pins and chains | capped depth | 1, or 3 with Perpetual Rack | the bowling read needs countable pins | the rack |
| Evolutions | 1 per break | 3 per run | 3 rig slots on the pod | rigs |
| Rule parts | 1 per bay | 3 per run | 3 bands on the hull | bands |
| Heft | linear, uncapped | shell scale stops at class V (1.28×) | growth is the fantasy; the collider never changes | the chunk pile |

**Hyperbolic versus linear, the test.** Anything a player could push to "always" or "never" (no damage, no cooldown, no crowd control) is hyperbolic. Anything that reads as "more" (punch, speed to a hard number, pins) is linear with a cap the eye can count. A percentage that would become a rule at 100% becomes a rule *at its cap* instead, and the glyph says so, which keeps Andrew's "insane scaling" honest without the wall.

### 1.5 Where power caps visually

Principle 4 (readability-capped scaling) is the balance rule. The caps are one ledger, `Density`, read by every drawer (form mirrors function: one source), with a **shed order** for the frame budget:

1. Player bolt tails thin first (alpha 0.9 to 0.4, exists).
2. Synergy and evolution rings dim to outlines (8 rings max, exists).
3. Pin trails and scrap fountains shorten.
4. Drone and rack followers stop drawing their seams.
5. **Never shed:** enemy telegraphs (priority 40, exists), the Warden's window beam, the objective, the class ring, kicker lips.

Budgets at stage 3, past the break, with two evolutions: 24 to 30 enemy bodies plus one rack (§6), 64 bolts, 12 zap lines, 8 rings, 12 pins in flight, 36 chunks, 3 rigs, 3 bands. The report's `density_p99` (§8) is the number that says whether "screen-filling" stayed readable; the play verdict is Andrew's.

## 2. Pick cadence

### 2.1 Sources on the Drop Loop

| Source | Where on the loop | Size | Per stage: lapper / completionist | Stops? |
| --- | --- | --- | --- | --- |
| Tree pick (exists) | class select, then each bay | 1 of 2, a key changes | 1 | the bay, a chosen stop |
| **Hoop** (fabricator, exists; placement changes) | one per drop line, 20 m before the lip | take or skip; uncommon; costs scrap | 1 to 2 / 2 to 4 | none |
| **Drop gate** (new) | on the bank, 20 to 30 m up the rebound heading from the core, after every landed drop | 1 of 2; common or uncommon | 3 to 4 / 4 to 6 | none |
| Break gates (exist) | after the break | 1 of 2; tier by cores | 1 | none |
| Moss's shelf (exists) | the bay | 0 to 3 buys, the hook | 0 / 1 to 3 | a chosen stop |
| Event, vault (exist) | the long line | rare, rare_plus | 0 / 1 to 2 | none |
| Evolution | the break | automatic when armed | 0 to 1 | none |

A drop gate is small on purpose (common or uncommon) so the break gates stay the big one, and it is **a pick that the drop earned**: land the drop, get a choice on the way to the return. A missed drop gets no gate. The pair stands on the bank between the core and the return and does not chase the ball (unlike the break gates, `reward_gates.gd:116-121`); the next landed drop re-rolls it. Skipping both is free.

### 2.2 The picks-per-minute curve

| Run minute | Beat | Picks in the minute | ppm |
| --- | --- | --- | --- |
| 0 to 0.5 | class select, the tree's first pick, the entry drop | 1 | 2 |
| 0.5 to 2.5 | stage 1 laps (a hoop, 3 to 4 drop gates) | 4 to 5 | 2 to 2.5 |
| 2.5 to 3.5 | the break: gates, evolution, the bay (shelf, tree) | 3 to 6 | 3 to 6 |
| 3.5 to 7 | stage 2 laps (2 hoops, 4 to 5 drop gates, the vault) | 8 to 10 | 2.5 to 3 |
| 7 to 8 | the break and bay | 3 to 6 | 3 to 6 |
| 8 to 12 | stage 3 laps (more lines, 5 to 6 drop gates, the event) | 10 to 12 | 2.5 to 3 |
| 12 to 13 | the break and bay | 3 to 6 | 3 to 6 |
| 13 to 16 | the arena | 0 | 0 |

A lapper's run is 25 to 30 picks in 12 minutes; a completionist's 40 to 45 in 16. Vampire Survivors runs 4 to 6 picks a minute early and slows (R2); ours runs flatter at 2.5 to 3 and *rises* by stage, because the Drop Loop's lap count rises. The band the report holds: **2.5 to 3.5 ppm inside a stage, never under 1.5 for any 60 s window** (a 60 s window without a pick is a hallway again, entry 8's complaint).

### 2.3 What a pick looks like at speed

Reading time is 1.5 to 2 s: 38 m at 20 to 25 m/s. Nothing at that range is text (W4 item 11 already does this for gates). What reads, in the order the eye needs it:

1. **Rarity topper** shape (bar, diamond, star, tall star with a mint heart; exists).
2. **Family glyph, trigger glyph, element glyph** (exist).
3. **The socket pulse**: the gate pulses in the *piece's* colour when the part would add a copy to a held stack ("ripens"), in mint when it completes a synergy (exists). One pulse, two meanings, told apart by colour and the socket glyph over the topper.
4. **Left or right.** Two arches 9 m apart; the ball steers into one. Under 6 m the prompt shows five words at most.

The drop gate's pair sits on the rebound heading, so the choice is a lean, never a turn. The hoop is a roll-through with its price on the ring (exists). A pick never stops the ball; only the bay does, and the player chooses the bay.

## 3. Rule-changers (the run's arcana)

**What they are.** Rare_plus **rule parts** that change one rule for the rest of the run. Never a stat. They are the run's shape: the summary names them, the codex collects them, and Andrew's "unique run capability" comes from three of them stacking on a build nobody planned.

**When they appear.** Two doors, so a lapper and a completionist both meet them:

- **Moss's hook** (the Potion Seller gag, DESIGN-V2 §12): the top-shelf part is a rule part on every visit. Heft-locked as today, so the gag is unchanged and the growth goal now buys a rule, not a number. One per bay, three per run.
- **A cursed cache** (§4): its prize is a rule part or a cursed part, 50/50, shown on the crate's dial.

**How they are capped.** Three per run, one band on the hull each (Codex visual track). A fourth offer replaces one (the player chooses which band to strip, at the hook, a chosen stop). Rule parts cannot be sold and carry no heft. Each rule declares the single system it changes and the tuning key it sets through `ctx.rules`, so combat, the director, the Warden and the bets read one source and the run log tags the run with its rules.

| # | Rule part | Changes | Costs | System it rewrites | Measure |
| --- | --- | --- | --- | --- | --- |
| 1 | **Every Rebound Is A Pin** | any enemy the ball rebounds off is launched as a pin at the rebound speed | rebound restitution −0.1 (the ball gives the speed to the pin) | contact (`player_ball` rebound branch reads `rules.rebound_pins`) | pins per minute |
| 2 | **Open Season** | a landed drop opens the window for every plated enemy within 20 m: plating 0 for the window's length | the window is 0.5 s shorter | combat `plating_of` | plated kills inside windows |
| 3 | **Clock Cores** | every difficulty tick drops a bonus core on the loop's far shelf | ticks come 10 s sooner | run clock, world core spawn | cores per stage |
| 4 | **Hot Lips** | every kicker lip fires at ×1.25 | the Warden's window is 30% shorter | stage map lips, warden window | drops landed per lap |
| 5 | **Glass Hull** | heft counts ×2 for punch | max HP ×0.5 | combat `resolve` | drops to break, deaths |
| 6 | **Scrap Rain** | kills drop ×2 scrap | the magnet is off; you roll over it | scrap field | heft at exit, route length |
| 7 | **Full Rack** | every pack arrives as a rack (a 1-2-3 of fodder in front of it) | pack cap +6 | director `compose` | bodies on screen, strikes |
| 8 | **Loaded Dice** | every luck bet's odds are 2 in 3 | every stake doubles | bets | bets taken, won |
| 9 | **Long Window** | windows +2 s | drops deal −25% | warden | window hits per window |
| 10 | **No Brakes** | the ball never drops below cruise on flat ground; crush threshold −20% | the brake key is gone; the slam is the only stop | movement tuning | speed p50, deaths to hazards |
| 11 | **Tally's Gearbox** (unlock, §5.5) | the tree's picks re-roll every stage | none; chaos is the price | upgrade tree | distinct tree paths |

Rules 1, 4, 5 and 9 are the ones a speedrunner takes; 3, 6 and 7 the ones a completionist takes; 8 is for the gambler. Each is at most eight words on the hook and one paint band.

## 4. Risk and luck: the bet family

Andrew: "risks that can really hit or miss depending on either luck or skill". The family from LOOP-REDESIGN §9 (rigged caches, timed trials), given odds, stakes and a skill tilt. Every bet is E, hold 0.35 s (the class ring fills), a drum roll on the hold, the slot clunk on the roll, the crit crack on a win, the dry bone on a loss. Every bet writes `bet_taken(id, stake)` and `bet_settled(id, won)` so the report can hold the take-rate and win-rate bands.

| Bet | Kind | Where | Odds | Stake | Prize | Skill tilt | Cap |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **Double or Nothing** | luck | a crate at the bay's cradle | 50% | every bonus core held | cores ×2 (applies to the next stage's first gates) | none; the choice is whether the next stage's gate tier is worth the run's cores | once per bay |
| **Cursed Cache** | luck then skill | a HAZARD-striped crate on the long line | 100% prize | a curse: one hit kills until 5 kills | a rule part or a cursed part, 50/50 on the dial | kill five fodder fast; Rivet's sprint and a rack are the answer | one per stage |
| **Timed Drop Trial** | skill | a post at a chute mouth | pass or fail | nothing | gate tier +1 at this break | land the next drop within 20 s of arming | one per stage |
| **Long Lip** | skill | the long line's higher lip, a speed gauge on it | pass or fail | nothing | the drop counts two segments | come off the lip at 32 m/s or more (Rivet's sprint, Sable's vault, Kest's glide-dive all reach it differently) | every lap |
| **Call the Warden** | skill and luck | a post on the bowl rim | certain | the clock jumps a tier now | windows +2 s this stage | a strong lapper trades packs for time | once per stage |
| **Blind Gate** | luck | one of the break gates, its glyphs hidden behind a shutter | 70% one rarity band up, 30% a percentage-only common | the other gate's known part | a surprise part | none; the tell is the shutter | one per break |
| **Sealed Vault** (Dead Cells' timed door, R1) | skill | the vault plinth, a par clock over it | pass or fail | nothing | the vault opens (rare part + core); sealed it is a wall | land two drops in the stage's first 90 s | one per stage |
| **Rack Wager** | skill | the ambush altar | pass or fail | 15% of scrap on a fail (a theft: chunks fly) | a bonus core | clear the pack in 30 s | one per stage |
| **Heavy Ante** | skill | the drop gate's post | pass or fail | 60 scrap | 180 scrap | land the next drop within 0.3 s of the window opening (the beat) | once per lap |

**Bounded economics (Codex review finding 7).** Five rules, each a test with an adversarial bot policy:

1. **One committed wager per cache or post, per stage attempt.** A crate or post that has settled shows its result dial and takes no second E. A retry (R) restores the stage's start state, so the wager is offered again, but its roll is drawn from the stage plan's seed, so the same bet in the same attempt lands the same way: restart fishing gets the same answer. The stake and the odds are on the dial before the hold begins.
2. **Stakes are disclosed and persist.** A lost stake is gone for the run, not the stage; a won prize is a part, a core or scrap, never a rule that outlives the run.
3. **One window-extension budget per opening.** Weapon hits, cores and Fault Line share one pool: at most +3 s over the family's base window (2.5 s reactor, 4 s hive, 5 s Mind), whatever the source. Long Window (§3) adds its +2 s to the base, not the pool. So a window is never longer than 8 s and timing still exists.
4. **Call the Warden costs something at the clock's cap.** At the +2 clamp the tier cannot rise, so the call spawns a blessed leader pack now (§5.4) instead. The call is never free.
5. **Allies cost wallet scrap only (finding 10).** `spend_scrap()` keeps mass (`run_state.gd:168`), so an ally never lowers heft; LOOP-REDESIGN §9's "lowers heft" wording is withdrawn. A theft is its own telegraphed event with chunks flying (the Rack Wager's fail case is one).

**Odds design.** Luck bets are 50/50 with an expected value slightly above even (a doubled core is worth more than a core to a build with a synergy pending), so a gambler is right to gamble and a non-gambler loses nothing. Skill bets pay 100% when executed, with hard thresholds the gauge shows (32 m/s, 20 s, 0.3 s), so "hit or miss" is the player's hands; luck enters through what the director rolls onto the line meanwhile. Stakes rise by stage through the scrap and core numbers, never through odds. Loaded Dice (§3) is the only thing that moves odds.

**Cursed parts.** Rare_plus parts with a curse, from cursed caches and 10% of rare_plus break-gate offers at 2 or more cores. The curse **lifts at the next Warden break**: bounded, and the break is already the run's cadence. It shows as a HAZARD-striped band on the pod that cracks off at the break (the eye candy Andrew asked for: something to watch happen). A curse never stops the ball; it prices the loop.

| Cursed part | The gift | The curse (to the next break) |
| --- | --- | --- |
| **Lead Shot** | +30 punch | cruise −10% |
| **Cracked Core** | an evolution now, of any armed pair, no break needed | max HP −40% |
| **Rust Lung** | magnet ×2, scrap ×1.5 | every tick without a landed drop steals 5% of scrap |
| **Dead Weight** | heft +1.0 | no air jump |
| **Glass Jaw** | rebounds crit ×2 | damage taken ×2 |
| **Hungry Magnet** | magnet 30 m | every pickup costs 1 HP until 40 have been picked |

Moss buys a curse off for half the part's price (a chosen stop, the "lighter, but faster" wording pattern from `shop.gd`).

## 5. Run variety

### 5.1 Seeded per run (what changes between two runs of the same stage)

The loop and the drop lines are fixed geometry (LOOP-REDESIGN §3). Everything *on* them is a seeded draw, published in `stage_plan` so the Tab picture can draw it:

| Draw | Options | Rule |
| --- | --- | --- |
| Which line holds what | event ring, vault, cursed cache, ambush altar, timed trial post, ally housing, sealed vault | 2 to 3 things per line, never two bets on one line, the fabricator on the fast line |
| Which packs the director draws | the eight tagged packs, weighted by the build (§6) | never two controllers in one pack |
| Warden modifier | one of three per family, 60% of runs (§5.3) | shown in the cage from the entry drop |
| Stage variant | one of two per stage (§5.2) | announced by the stage's own event grammar |
| Blessed pack | 1 in 6 packs past tick 1 | a leader with a Cherenkov halo |
| Terrain event timing | cave-in 30 to 45 s, impact 55 to 75 s (exist) | changes a line mid-stage |
| Generated recipes | 25% of offers (exists) | |

**Seed entry.** The class card carries the seed (six characters); typing one replays a run's draws. The summary and the Tab picture show it. "Same run again" is a replay hook Andrew has not asked for but Isaac's seed screen proves; it costs one field.

### 5.2 Stage variants

Two per stage, drawn per run, each reusing an event the stage already has as its *mode* rather than a new stage:

| Stage | Variant A | Variant B | What changes on the loop |
| --- | --- | --- | --- |
| 1 Spillway | **Dry**: the basin floor is the bowl's apron | **Flooded**: the 90 s flood fills the basin; the west line's foot becomes water (frost and arc find water; Rime Heart makes a road) | the fast line's landing; the flood is a timed cost |
| 2 Cable Reach | **Docked**: the barges are moored, the sky line is walkable | **Sailing**: barges move; the skylight line's timing is a ride | the long line's rhythm |
| 3 Weir | **Surge**: the surge run's front chases down the pipe (exists) | **Squall**: the dust squall crosses the hill every 60 s and hides the lips; Kest's cloak is free inside it | the fast line's visibility |

### 5.3 Warden family modifiers ("blessed" Wardens)

One per family per run, 60% of runs. Each changes what the drop loop asks, never the grammar (LOOP-REDESIGN §2). A blessed Warden wears a Cherenkov crown in its cage and drops a second core at the break. The codex names the modifier after the first break against it.

| Family | Modifier | The change | The tell |
| --- | --- | --- | --- |
| Reactor | **Hot Core** | craters burn 10 s; windows +1 s | the crater rings stay lit |
| Reactor | **Twin Vent** | two pulses a cycle, each window half as long | two stacks swell |
| Reactor | **Cold Reactor** | no craters; 5 drops at heft I | the stacks are dark |
| Hive | **Full Rack** | the guard rack re-forms in 5 s; scattering it drops scrap | the rack is ten-wide |
| Hive | **Queen's Guard** | the rack follows the ball for one lap after a scatter | the rack's seams stay lit |
| Hive | **Hollow Hive** | the rack is six, not ten; the cell opens 2 s, not 4 | a thin rack |
| Mind | **Prophet** | it reads two verbs, braces both | two icons on the lens |
| Mind | **Amnesiac** | it reads nothing; the lens is always open; the lane strike is 2× | no icon, a bright lens |
| Mind | **Mirror** | it quotes your *class motif's* line, and the lane comes from behind | the motif plays before the icon |

### 5.4 Blessed and elite packs

Risk of Rain's elites, ball-culture. Past tick 1, one pack in six carries a **leader**: 2× HP, a Cherenkov halo, and a core on death. Three kinds, each a *stage* rule the pack carries with it, never a stat reskin (DESIGN-V2 §10 no-reskins):

| Leader | Its pack's rule | Counterplay |
| --- | --- | --- |
| **Blazing** | its members leave 3 s crater rings where they die | kill them off the line |
| **Magnetic** | its pack's holds last +50% | tenacity, Rivet's sprint, kill the leader first |
| **Hollow** | the pack is fodder and drops ×2 scrap; the leader is a rack | bowl it |

### 5.5 Run 20 against run 1

PROGRESSION §2 to §4's rule stands: persistence is options, knowledge, looks and pressure, never a stat. What the snowball adds:

| Thread | Run 1 | Run 20 | Owner |
| --- | --- | --- | --- |
| **Mastery branches** | the base tree | three alternate nodes per pilot, each unlocked by a play milestone (PROGRESSION §2), opening alternate paths; the tree's 16 ends become 20-plus | `upgrade_tree.gd`, trees data |
| **Codex hunts** | 8 synergy cards | 16 evolution cards, 9 Warden modifiers, 3 leaders, 11 rule parts, bowling scores (Strike, Spare, Turkey), the interaction Found list | `codex.gd` categories |
| **The Tally thread** | a dormant housing on Moss's shelf | every evolution the pilot completes is "remembered" by the housing (a light per evolution kind); at three distinct evolutions per pilot the housing flickers and Tally's Gearbox (§3 rule 11) enters the hook pool; the playable Tally is post-alpha (DESIGN-V2 §11) | profile, shop |
| **Par ghosts** | none | per stage and per lap (`run_clock.gd` `record`) | run clock |
| **Heat** | Scrapless, par timer (exist) | Pressure valves 1 to 5 (PROGRESSION §3), plus two for Andrew's little-gear and timer taste: **Bare Hull** (no evolutions, no rule parts) and **Dead Clock** (ticks every 22 s); all tagged in `runs.ndjson` and excluded from tuning | run clock modifiers |
| **Seeds** | random | typed | class card |

### 5.6 Variety that changes decisions, not only build ids

Codex review finding 9: build ids can differ while the fight plays the same. S1 confirmed the risk from the other side: every one of 4800 simulated runs had a distinct sorted part list, so a distinct-build count is saturated and says nothing. The measure is **changed decisions**: which drop line a build takes, and how much of the Warden's damage comes from drops against the gun.

Every evolution declares a **line preference** the loop can satisfy, so a rig pulls the player onto a different route:

| Rig | Prefers | Why on the loop |
| --- | --- | --- |
| Meteor Frame, Seismic Slam | the long line's higher lip | fall speed is the damage |
| Afterimage, Pinball Hull | the fast line, tight laps | speed tier and rebounds per minute |
| Glacier Wake | the Flooded variant's west foot, the canal | ice roads on water |
| Scrap Singularity, Wrecking Drum | the pack-heavy line (where the director's rack lands) | food |
| Storm Tether, Bowling Cross, Screaming Spiral | the bank inside the bowl, the window | gun damage inside windows |
| Drone Rack, Perpetual Rack | the ambush altar's line | kills near rebounds |

The **bad-luck recovery route**: a run with no armed pair by break 2 always finds Cracked Core's cursed cache on stage 3's long line (the stage plan guarantees it when the run holds no evolution), so a dry run can gamble into one. And the report holds two numbers per build family: the drop-line choice distribution (a rig should move it by 20 points or more against the base kit) and the drop-versus-gun damage share at the Warden (a gun rig should move it toward the gun, a drop rig toward drops). Voluntary restarts per run are logged as a third; a spike over 0.5 per run in one family says that family's picks feel like traps.

## 6. Enemies against the build

W7 item 16's build-tilt stays the rule: the pack that tests your axis comes up to twice as often (`BUILD_TILT = 1.0`), every open pack still comes, no hard counter. The snowball needs four additions.

1. **Tilt reads evolutions and rule parts.** Each evolution declares its axis (the last column of §1.2); each rule part its axis where it has one. `build.evolution_tags()` joins `branch_tags()` in `director.build_axes()` at `CLASS_AXIS_SHARE` each (`director.gd:246-264`). A Pinball Hull build meets the rebound pack (deflector plus chaser) more often, which is also its food.
2. **Food, not only counters.** A snowball needs pins. When the build holds one evolution or more, one pack in three is a **rack**: a 1-2-3 of six fodder (chasers) in front of a punisher, so the fodder-to-counter body ratio stays at 2:1 or above. The rack is W7's bowling callback; here it is the director's answer to growth, and it is measured (§8).
3. **Fairness both ways.** An evolution declares what it *feeds on* (Bowling Cross on fodder, Scrap Singularity on light enemies, Glacier Wake on ground units). The director guarantees that kind stays at 20% of spawns or more, so a build is tested, never starved. Tested and fed is the pair of rules that keeps "no hard counter" true for a snowball.
4. **Control chains are capped before population rises (finding 9).** At most one controller per pack (exists in `PACKS`), at most two holds pending on the ball across every pack at once (the third controller waits its attack), and tenacity's 1.8 s in 4 s stays the one clock. Population rises only after the density ledger's stage-3 test is green with telegraphs unobscured; the stills in row 6 of the roadmap are the check.
5. **Per lap, and full both ways.** LOOP-REDESIGN §1 moves `PAST_BREAK_STEP` to per completed lap; the review's finding 8 is right that `0.12 × tier` already prices staying before the break (`director.gd:218-222`), so the per-lap step is the *extra* term, and the report measures which packs actually reach the lapper before the break rather than assuming none do. At stage 3 with two evolutions the cap rises from 24 to 30 bodies (`HARD_CAP` plus a heft step of 3 at stage 3), a rack counts its drones at a third each, and one pack in six is blessed. That is the screen "full both ways": 30 bodies, a rack, a leader's halo against 64 bolts, 8 rings and 12 pins, with telegraphs on top and the density ledger shedding the player's effects first.

**What packs ask a snowballed ball (the late-run reads).** A rebound pack against Pinball Hull is a pinball table; a grounded pack against Wrecking Drum is a mag pit the heft rolls through; a netted pack against Meteor Frame is a net you fall through into a crater; a strung pack against Afterimage is a tether you outrun at 19 m/s. Each is a counter the evolution turns into its own verb, which is DESIGN-V2 §10.6's rule ("each counter also becomes an opportunity") applied to the snowball.

## 7. Stages 2 and 3 as loops (deepening LOOP-REDESIGN §3)

Stage 1's loop is §3's; here the systems land on all three. Geometry rules: a hoop stands 20 m before each lip on the line's own kerb; the drop gate pair stands on the bank 20 to 30 m up the rebound heading (the bowl is r 62, `Features.BOWL_OUT`, so the bank is wide enough for two arches at 9 m spread with the climb check, `reward_gates.gd:158-178`); the return is the only piece with no choice, and it carries the ball at 85% (W6).

| | Stage 1 Spillway | Stage 2 Cable Reach | Stage 3 Weir |
| --- | --- | --- | --- |
| **Loop** | top shelf, two chutes, bowl, steam lift | bowl, geyser, dish, shelf, canal, bowl (closed already) | landing hill, halfpipe, bowl, basin, cannon |
| **Fast line** | west chute, lip at the mast | the canal's end lip | the halfpipe itself: pump the walls, drop on the Regard |
| **Long line** | east chute, higher lip, past the stampede ring | the skylight halfpipe's foot, past the reactor vent and the vault | the west wing's kickers (`KICKERS` at x −62), past the surge run and the vault |
| **Third line** | none | the impact crater, after the impact event (55 to 75 s) | the mesa's relay walls, after a structural collapse |
| **Hoops** | one per line | one per line, one on the dish | one per line, one on the hill |
| **Drop gates** | the bank, toward the lift | the bank, toward the geyser | the bank, toward the basin |
| **Family rule on the lines** | the crater blocks the last line you missed from | the rack forms on the line you last used; take the other | the Mind braces against your last verb; alternate drop and gun |
| **Interactables** (LOOP-REDESIGN §9) | the lift (travel); the ambush altar on the east line; the cracked wall behind the vault (cache); double-or-nothing at the cradle; the timed drop post at the west mouth | the geyser (travel, exists); the ally housing on the shelf; the cursed cache in the e1 tunnel; the Warden-call post on the bowl rim; the sealed vault (timed door) on the skylight line; Kest's thermal vent as a secret line | the cannon (travel); the relay mesa as the opt-in fight; the surge front as the timed trial (ride ahead of it: the pipe line is faster); the Long Lip bet on the west kickers; the Heavy Ante post at the halfpipe's foot |
| **Per-lap pressure** | packs on the loop from 0:45; a reinforcement step per lap | the same, plus the rack | the same, plus blessed leaders from lap 2 |
| **Stage variant** | Dry / Flooded | Docked / Sailing | Surge / Squall |
| **The Warden's snowball read** | 4 drops at heft I; heft II takes a third a drop | 5 drops; the rack is the door, so Bowling Cross and Pinball Hull open it in one motion | 6 drops; the Mind's brace punishes one-verb builds, so a build with a drop evolution *and* a gun evolution always has an open lens |

**Where the rewards are seen from** (LOOP-REDESIGN §8 sightlines): every interactable shows its family glyph at 30 m; from the return's landing the long line's prizes are in view; the cage on the mast shows the break's tier and the armed evolution's silhouette from every point on the loop.

## 8. Measures

Bot policies: `camper` (the old skipper), `lapper`, `completionist` (LOOP-REDESIGN §4), plus `gambler` (takes every bet, always the long line) for the bet bands. 16 seeds per policy per class is the report unit; 200 seeds for the offer simulator and the fuzzer. Everything below is a row in `tools/balance_report.gd` or a line in `runs.ndjson`.

| System | Metric | Read from | Band (starting values) |
| --- | --- | --- | --- |
| Evolutions | share of runs with an evolution by break 1, 2, 3 | run log `evolutions[]` | completionist ≥ 60% by break 2; lapper 20 to 40%; ≥ 1 in 50% of all runs |
| Evolutions | time to first evolution (stage time) | run log | median stage 2 |
| Evolutions | distinct evolutions reached over 48 runs | run log | ≥ 10 of 16; none over 40% of runs |
| Evolutions, offers | pair reachability by ripe count and bait (S1) | `tools/snowball_sim.gd` | see §14 |
| Cadence | picks per minute per stage, per policy | run log `parts_by_source` with stage ticks | 2.5 to 3.5 in-stage; no 60 s window under 1.5 |
| Cadence | drop gates taken / offered | `drop_gate_taken` rows | ≥ 70% taken |
| Build space | distinct `build_id` (sorted parts + tree path + evolutions + rules) per 16 seeds | run log | 16 of 16 distinct; Jaccard similarity of part sets < 0.5 median |
| Power curve | ram punch at cruise at each stage exit; drops to break per stage | power-curve test bands (writer B item 33), `warden_drop_landed` | lapper 4/5/6 drops at heft I to II; completionist ≤ 60% of the lapper's fight length (LOOP §4) |
| Power curve | modelled DPS multiple against the base kit at stage 3 exit | `build_sheet` | 30× to 400× (the "absurd" band), with `density_p99` green |
| Density | p99 of bodies, bolts, rings, zaps, pins per frame at stage 3 | a `Density` ledger row per second in the bot notes | bodies ≤ 30, bolts ≤ 64, rings ≤ 8, zaps ≤ 12, pins ≤ 12; p99 frame ≤ 16.7 ms |
| Rule parts | rules taken per run; each rule's take rate | run tags | 1 to 3 per completionist; no rule over 50% or under 10% of hook offers taken (retune the rule, not the odds) |
| Bets | take rate and win rate per bet | `bet_taken`, `bet_settled` | luck bets 45 to 55% won; skill bets 30 to 70% won by the bots (a 100% skill bet is too easy; under 20% too hard) |
| Curses | curse deaths / curse taken | run log | ≤ 25% |
| Director | tilt ratio (the build's axis pack / the rarest pack) | `director.packs` | ≤ 2.0 |
| Director | fodder-to-counter body ratio with ≥ 1 evolution | pack composition | ≥ 2.0 |
| Director | packs met before the break | `world_director_test` | lapper ≥ 2, completionist ≥ 4 |
| Variety | distinct (variant, Warden modifier, line contents) plans per 16 seeds | `stage_plan` | ≥ 12 of 16 |
| Meta | mastery milestones per 10 runs; codex completion by category | profile, codex | 4 to 6 of 9 milestones by run 10 (PROGRESSION §5) |
| Momentum | speed after a drop gate, a hoop, a bet arm, an evolution | existing gate tests | ≥ 0.85× before, no hit-stop over 70 ms |

A green table is the gate to Andrew's play, never a verdict on fun (LOOP-REDESIGN §4).

## 9. Needs from Audio

| System | Needs |
| --- | --- |
| Evolutions | one **evolution fanfare** family (the class motif whole, then the evolved rig's own two-note tag, so each of the 16 rigs is heard as "mine plus that"); a **socket tick** per copy toward ripe (a climbing note per notch on the reward ladder); the ripe **socket hum**; the rig's running sound at low priority (Pinball Hull's bumper ding on each rebound, Storm Tether's crackle, Glacier Wake's creak), each under the SOUND-STORY reward register and ducked by threats |
| Cadence | the drop gate's roll-through as the gate cue pitched by rarity (exists); a **lean cue** left or right at 6 m so the choice is heard before it is read; hoops keep theirs |
| Rule parts | a **band cue** on the hook's relent (the Potion Seller grumble resolving into a low brass hit, since a rule is Fleet-scale); each rule's change played once when it first fires (the pin's whip for rule 1, a second Geiger for Clock Cores) |
| Bets | the drum roll on the hold, the slot clunk on the roll, the crit crack on a win, the dry bone on a loss (LOOP-REDESIGN §9), plus a **stake tick** while the class ring fills; the curse's band cracking off at the break as a glass break inside the stage-clear cadence |
| Variety | a blessed Warden's crown adds one Cherenkov shimmer layer to the family idle; a blessed pack's leader borrows the miniboss riser a fourth lower; each stage variant is one extra layer in the level theme (water for Flooded, wind for Squall) |
| Director | the rack's arrival as the anvil in a 1-2-3 rhythm; "full both ways" is the band at its top layer (W5b) with threats still low and minor |

## 10. Needs from Feel and Readability

| System | Needs |
| --- | --- |
| Evolutions | the socket and notch on the accretion piece (`accretion.gd`); the rig silhouette in the mast's cage; the **evolution beat** at the break: 120 ms hit-stop (the one place over the 60 ms cap, as a chosen stop inside the break's own beat), the three ripe pieces flying off and the rig snapping on, the FOV punch; a one-line toast in the class colour ("Pinball Hull") and nothing else |
| Cadence | drop gates on the bank drawn smaller than break gates (5 m tall, no gantry) so size says "small pick"; the socket pulse in the piece colour distinct from the synergy pulse in mint; the lean read at 38 m |
| Rule parts | three paint bands on the hull in the rule's colour, always visible from the chase camera; the rule's icon on the Tab picture's ball; the fourth-rule replacement UI at the hook (a chosen stop) |
| Bets | the dial on every crate and post (odds or par) readable at 30 m; the class ring as the hold gauge (exists); the curse band in HAZARD stripes; the win crack and the loss bone as W11's universal cues |
| Variety | the crown in the cage; the leader's halo in Cherenkov blue with a 1 s edge marker; the variant announced by the stage's event grammar (klaxon for Flooded, the squall's telegraph) |
| Director | the rack drawn as one threat (W7 item 9); the density ledger's shed order in `vfx.gd` and `bolts.gd`; a `density` readout on the tuning panel for the sitting |
| Measures | the run summary shows evolutions, rules and bets as three rows of icons under the pilot |

## 11. Needs from the Codex visual track (visible stacking)

- **Rig slots on the pod.** Three attachment points on the `class_accent` seam (`hero_assets.gd`), one per evolution, each rig a small mesh in the family's shape (bumper rails, a drum on chains, a spiral vane, an arc mast, a cross brace, hammer heads, a fin skirt, streamer fins, a coil halo, arc rings, a frost skirt, cracked plates, piston legs, a capacitor stack, rack pins, docked drones). Each reads at 30 m against the pilot; none hides the pilot (AC-01).
- **Sockets and notches on accretion pieces.** A dark socket in the pair tag's family glyph on the piece's face; a notch per copy; a glow at ripe. The piece shapes are V3's (barrel, cross, coil, rod, vane, capacitor, gem).
- **Paint bands.** Three hull bands in the rule's colour, painted over the chunks, so a rule shows from across the bowl.
- **The curse band.** HAZARD stripes on the pod, cracking off at the break.
- **The crown and the halo.** The Cherenkov crown mesh in the cage for a blessed Warden; the leader's halo ring.
- **The cage on the mast** (LOOP-REDESIGN §8) needs a slot for the rig silhouette.

## 12. Build waves

Each wave is one writer. Seams that collide are serialized; everything else runs beside the A-waves of LOOP-REDESIGN §5. My workers' branches (§14) are inputs, not merges.

| Wave | Files and seams | Depends on | Serial or parallel |
| --- | --- | --- | --- |
| **S1 Evolutions** | new `src/build/evolutions.gd` (rows: shown, ripe, pair tag, evolved id, rig, axis, feeds_on); `parts.gd` (16 evolved rows, `evolved: true` excluded from `offer_pool`); `build.gd` (the arm check on `recompute`, the evolve on the Warden's `enemy_killed`, `offer_mark` "* ripens X *", codex declarations); `item_effects.gd` (an effect list per row, the new effect ids: `orbit_release`, `field_follow`, `fragment_knock`, `rebound_volley`, `crater`, `trail_lane`, `pull_enemies`, `contact_zap`, `freeze_road`, `fault_lane`, `ground_ring`, `bank_release`, `chain_depth`, `wake_drone`); `accretion.gd` sockets; `tuning.gd` `evolutions` flag; `event_kinds.gd` rows `evolution_armed`, `evolution_completed`. Tests: `build_evolution_test`, `build_catalogue_test` (cap assertions), `item_fuzz` with the flag. S2's branch is the seam proof. | A1 (the Warden break) | parallel with A2 to A4 |
| **S2 Cadence** | `reward_gates.gd` (a `small` mode: 5 m arches, no chase, re-roll on the next drop); `fabricators.gd` (placement per drop line from `stage_map.drop_lines`); `build.gd` (open a drop gate on `warden_drop_landed`); `flow.gd` objective words unchanged. Tests: `build_drop_gate_test`, `build_cadence_test` (ppm bands from the bot). | A1, A2 | after A2 |
| **S3 Rule parts** | new `src/build/rules.gd` (11 rows, `ctx.rules` with one key per rule); `shop.gd` (the hook draws a rule part; the fourth-rule swap); readers: `combat.gd` `plating_of` (Open Season, Glass Hull), `director.gd` (Full Rack), `run_clock.gd` (Clock Cores), `warden.gd` (Long Window, Hot Lips: A1's writer adds the key read), `player_ball.gd` rebound branch (rule 1: L3's writer adds the key read), `movement/tuning.gd` (No Brakes). Tests: `build_rules_test`, one per reader. | S1 (the band slot), A1 | after S1 |
| **S4 Bets and curses** | new `src/build/bets.gd` (odds, stakes, settle, the two event rows); `interactables.gd` rows for the crate, posts and the timed door (L3's file: a row per bet, added by L3's writer from this spec); `parts.gd` (6 cursed rows, `curse` field, lifted on the break in `build.gd`); `shop.gd` (buy a curse off). Tests: `build_bets_test`, `build_curse_test`. | A7 (E and the interactable families) | after A7 |
| **S5 Director** | `director.gd` (evolution and rule axes, the rack as one pack in three, `feeds_on` floors, blessed leaders, the stage-3 cap, per-lap step from A4); `combat/roster.gd` and a `leader.gd` (halo, the three pack rules); `fleet.gd` (crater on death, hold bonus). Tests: `world_director_test` (tilt ≤ 2, fodder ≥ 2:1, leaders 1 in 6), `enemy_roster_test` (no reskins: a leader is a rule, not a stat). | A4, S1 | after A4 |
| **S6 Variety** | `stage_defs.gd` (variants, modifiers), `warden_kit.gd` (9 modifiers as data: A1's file, a follow-up by A1's writer), new `src/world/stage_plan.gd` (the seeded draws, published for the Tab picture), `class_def.gd` and the class card's seed field (W12's file: one field), `run_log.gd` (`seed`, `variant`, `modifier`, `evolutions`, `rules`, `bets`, `build_id`). Tests: `world_stage_plan_test` (≥ 12 distinct plans per 16 seeds), `warden_modifier_test`. | A1, A3 | after A3 |
| **S7 Measures** | `tools/bot_driver.gd` (`gambler`; the lapper takes drop gates), `tools/balance_report.gd` (§8's bands), the `Density` ledger in `vfx.gd` (Feel's file: the ledger is a read seam), `tools/snowball_sim.gd` promoted from S1's branch. | S1 to S6 | last |
| **S8 Meta** | `upgrade_tree.gd` and the trees (3 alternate nodes per pilot, unlocked by PROGRESSION §2's milestones), `codex.gd` (evolution, modifier, leader and rule categories), `profile.json` (PROGRESSION §8, plus `tally_evolutions`), `run_clock.gd` (Bare Hull, Dead Clock). Tests: `tree_data_test` (alternates keep the loop check), `spine_codex_test`. | S1, S3, S6 | after S6; may slip past the alpha |

Order: S1 beside A2 to A4 once A1 lands; S2 after A2; S3 after S1; S4 after A7; S5 after A4; S6 after A3; S7 last; S8 after S6. The gate to play is S7's report with §8's evolution, cadence, density and director bands green.

## 13. Under Laps (Option C)

The snowball and the replay survive; where they *stand* moves, and the fight shows less of them.

- **Cadence.** The drop gate becomes a **lap gate** at the checkpoint ring nearest the bell: one pick per completed lap, same size. Hoops stand on the course. Picks per minute hold at 2.5 to 3 because a lap is 25 to 40 s.
- **Evolutions.** Armed pairs evolve when the Warden *wakes* (the third notch), then at its break, so a run still gets one per stage; the tease is the bell's notch ring, weaker than the cage.
- **Bets.** Long Lip, Timed Drop Trial and Heavy Ante lose their verb (no drop). Replace with **Lap Under Par** (a lap under the par ghost: gate tier +1), **Extra Lap** (a fourth lap before waking strips plating, the clock steps), and **Early Bell** (wake it at two notches for a shorter fight at full plating). Call the Warden is Early Bell.
- **Rule parts.** Hot Lips and Long Window have no target; swap for **Short Course** (four rings, not five; packs +1 per lap) and **Double Notch** (each lap counts two notches; the Warden wakes at +15% plating).
- **Director.** Per-lap steps are native to Laps; the rack on the course is the same.
- **What is lost.** The fight is the v2 fight, so heft and cores do not show in it: the snowball reads on the course (fewer laps to strip plating) and in the packs, never in the Warden's segments. That is the reason to prefer Drop (LOOP-REDESIGN §1) from this bucket's side too.

## 13b. Under the hybrid: the drop staggers, the gun deals the damage (`full` gun role)

Codex review finding 11, which L1 is prototyping as the `full` toggle. The snowball works under it with one shift: growth shows as **gun output inside the stagger** rather than as fewer segments.

- **Heft** still opens the door (a heavier drop staggers longer: `stagger = base + K × heft`, capped by the extension pool in §4), so the map still makes the opportunity.
- **Gun rigs** (Screaming Spiral, Storm Tether, Bowling Cross, Capacitor Bank, Hammer Hull) carry the fight; **drop rigs** (Meteor Frame, Seismic Slam) lengthen the stagger and add a second hit. Both families stay worth taking, which is the hybrid's advantage for variety (§5.6).
- **The badge** shows integrity as segments still, each segment a stagger's worth of gun damage at the base kit, so progress stays whole steps.
- **Bets** are unchanged; Long Lip's "two segments" becomes "a double-length stagger".
- **Measures** add the drop-versus-gun damage share band: under `hold` drops carry 80% or more (LOOP §4); under `full` the gun carries 60 to 80% and the drop the rest; a build that lands at 100% either way has lost one of the two verbs.
- **What is lost against `hold`:** the cage's segment tease is weaker, because a gun build's growth is not a number on the badge but a shorter window, and Rivet's rapid laser needs the same bolt caps as now.

## 14. Spikes

Each spike is an experiment on its own branch, never merged. I verified each commit and its files in the worker's worktree; where I reran a command myself it says so.

### S1 Offer-rule simulator (Sonnet, `proto/core-loop-v3-systems-2`)

Commit 1cb5f7c: `tools/snowball_sim.gd` (353 lines) and `design-v3/spikes/S1-snowball-sim.md`. 200 seeds per cell, the real `Parts.roll` and `Parts.roll_gate` with a synthetic pick schedule (lapper 15 picks, completionist 27), sweeping ripe {2, 3}, bait {0, 0.35, 0.5}, greedy {0, 0.8}; 24 cells. The worker reports the tool ran in seconds and `build_catalogue_test` still passed; I verified the commit and the results file, not that rerun. Evidence: a draw simulation of the offer rules, not play.

| Policy | Ripe | Bait | Greedy | Armed by break 1 | by break 2 | by break 3 | Mean pairs at end |
| --- | --- | --- | --- | --- | --- | --- | --- |
| lapper | 3 | 0 | 0 | 5.5% | 16.5% | 29.5% | 0.35 |
| lapper | 2 | 0 | 0 | 6.5% | 23% | 42% | 0.51 |
| lapper | 2 | 0.35 | 0 | 17% | 47.5% | 73.5% | 1.18 |
| lapper | 2 | 0.35 | 0.8 | 24% | 65.5% | 85.5% | 1.54 |
| completionist | 3 | 0 | 0 | 12% | 37.5% | 71% | 1.05 |
| completionist | 2 | 0 | 0 | 16% | 47% | 82% | 1.46 |
| completionist | 2 | 0.35 | 0 | 39.5% | 84% | 98.5% | 3.20 |
| completionist | 2 | 0.35 | 0.8 | 56.5% | 95% | 99% | 3.89 |

The full 24-cell table is in the results file. Most-reached pairs: `tumbler_bearing/mass` 1949, `cross_split/kinetic` 1429, `spiral_wave/split` 1402, `chain_arc/anchor` 1292, `impact_driver/kinetic` 610 of 4800 cell-seeds; the pattern parts rank high because the stage-2 guarantee (`parts.gd:354-368`) force-feeds one copy. Distinct build ids were 200 of 200 in every cell (saturated; see §5.6). The `offered` down-weighting mattered less than expected because it resets each stage. Design consequences are in §1.2: ripe 2, bait 0.35 gated on the shown part being held, Meteor Frame's pair moved off `mass`.

### S2 Pinball Hull end to end (Opus, `proto/core-loop-v3-systems-3`)

Commit daf58c4, 9 files, +347/−2: `synergies.gd` (+64, an `EVOLUTIONS` table and cards), `build.gd` (+45, `try_evolve()` on the Warden's `enemy_killed`, the "ripens" mark), `item_effects.gd` (+15, a `combo` effect id that runs a list of existing effects under the row's stack rule), `items.gd` (+15, `Items.EVOLVED`), `parts.gd`, `part_def.gd`, `tuning.gd` (`evolutions`, default off), `tests/build_evolution_test.gd` (+197). I reran `build_evolution_test` and `build_synergy_test` in the worker's worktree: both `PASS`, exit 0. The test proves: the card is declared before the evolution exists; the mark reads on Spring Hull at 0 and 2 copies and on a speed carrier at 3; the break turns `[spring_hull ×3, light_frame]` into `[light_frame, pinball_hull]` with the part published as source `evolution`; a second break does nothing; heft went 1.800 to 1.444 (the `heft_bonus` rule in §1.2 comes from this); a rebound fired `speed` and `air_jump` in one pass with 0 refused; a retry to the pre-break checkpoint restored the three copies.

Seams the wave S1 writer meets: `run_state` has no `remove_part` (the prototype copies `shop._remove_part`'s `rfind` and `remove_at`; the spine should add the mutator); evolved rows live in `Items.EVOLVED` because `build_catalogue_test` pins exact counts over `Parts.ids()`; the card is declared only while the flag is on, for the same reason; a combo entry's `every` is ignored (only the row's counts); the mark leaks the name from zero copies (fixed in §1.2's rule). Cost of a second evolution whose effects exist: two rows. Evolutions that change a pattern (Screaming Spiral, Bowling Cross, Storm Tether) need combat code, not rows: those are wave S1's real work.

### R3 Web scout (Haiku, `proto/core-loop-v3-systems-1`)

Commit b2cfbe5, `design-v3/research/R3-snowball-catalogues.md`, 144 lines with 8 URL lines (fewer than "every claim", so read it as leads): 16 Vampire Survivors evolution pairs and the 22-arcana cap; Risk of Rain 2's linear, hyperbolic, exponential and reciprocal stacking with examples, seven elite affixes, the director's credit pricing, the 79/20/1 split; Hades' duo and legendary rules and the 15 Pact conditions at 63 heat; Isaac's room pools and Guppy-style transformation sets; Gunfire Reborn's blessing and cursed scrolls and per-hero ascensions. What this doc took from it: the hyperbolic rule for anything that could reach 100% (§1.4), elites as pack rules rather than stat reskins (§5.4), heat as a chosen ladder (§5.5), and transformation sets as the shape of an evolution recipe (§1.2). Not verified page by page.

## 15. Open questions for Andrew (recommendation first)

1. **What an evolution does to the parts.** (a) The ripe copies leave and the evolved part enters with their heft, so the ball keeps its weight and gains a rig. (b) The copies stay and the evolved part adds on top (stronger, and the piece count creeps toward the 24 cap).
2. **Where rule parts come from.** (a) Moss's hook and cursed caches, so a light lapper can still gamble for one. (b) The hook alone, so the gag is the only door.
3. **How long a curse lasts.** (a) To the next Warden break, so the band cracks off at the run's own beat. (b) For N kills, Dead Cells' way, so a fast player clears it in seconds.
4. **Blessed Wardens from run 1.** (a) On from the first run at 60%, so run 1 can meet a Twin Vent. (b) Unlocked by the first win, Hades' way.
5. **A seed field on the class card.** (a) Yes, six characters, shown on the summary. (b) Not in the demo.
6. **The drop gate's shape.** (a) One of two arches on the bank, a lean. (b) One arch, take it or leave it, so the bank stays emptier.
7. **Evolution count.** (a) Three per run, one per break. (b) Cracked Core's "evolve now" is the only way to a fourth.

## 16. Measures against the roadmap's definition of done

`ROADMAP.md` (branch `proto/core-loop-v3-design`, 1589f4f) gives this design rows 3 and 4 and a share of row 1. Each measure in §8 and §5.6 maps to one row.

| DoD row | Measure here | Band |
| --- | --- | --- |
| 1 Why stay | packs met before the break; drop-versus-gun damage share (§13b) | lapper ≥ 2, completionist ≥ 4; ≥ 80% drops under `hold`, 60 to 80% gun under `full` |
| 1 Why stay | stages 2 and 3 loop plans (§7): distinct plans per 16 seeds | ≥ 12 |
| 3 The snowball | evolution reach by break (S1 bands, then the bots) | completionist ≥ 60% by break 2, lapper 20 to 40% |
| 3 | time to first evolution | median stage 2 |
| 3 | distinct evolutions over 48 runs | ≥ 10 of 16, none over 40% |
| 3 | picks per minute per stage; drop gates taken | 2.5 to 3.5; no 60 s under 1.5; ≥ 70% taken |
| 3 | power curve: drops to break, fight length, DPS multiple | 4/5/6 at heft I to II; completionist ≤ 0.6× lapper; 30× to 400× |
| 3 | density p99 | bodies ≤ 30, bolts ≤ 64, rings ≤ 8, zaps ≤ 12, pins ≤ 12, frame ≤ 16.7 ms |
| 3 | rule parts per run and take rate | 1 to 3; 10 to 50% per rule |
| 3 | changed decisions (§5.6): line choice shift per rig, damage-share shift, voluntary restarts | ≥ 20 points; toward the rig's verb; < 0.5 per run |
| 3 | run 20 versus run 1: milestones by run 10, codex completion, variety plans | 4 to 6 of 9; rising; ≥ 12 of 16 |
| 4 Discovery | bet take and win rates; curse deaths | luck 45 to 55% won, skill 30 to 70%; ≤ 25% |
| 4 | one committed wager per cache; the extension pool; the call's cost at the cap (adversarial bot policies) | 0 second wagers, windows ≤ 8 s, 0 free calls |
| 4 | Warden modifiers and leaders found (codex) | rising across runs |
| 6 Readability | control chains: holds pending on the ball | ≤ 2 |
| 6 | shed order never touches telegraphs or the window beam | stills |
| 8 Sound | one cue per evolution, rule, bet outcome (§9) | the beat-grid log |
| 11 Robustness | `item_fuzz` 200 seeds with `evolutions` on | 0 anomalies unmarked |
| 11 | momentum through every new pick and bet | ≥ 0.85× speed, no hit-stop over 70 ms outside the evolution beat |
4. **Blessed Wardens from run 1.** (a) On from the first run at 60%, so run 1 can meet a Twin Vent. (b) Unlocked by the first win, Hades' way.
5. **A seed field on the class card.** (a) Yes, six characters, shown on the summary. (b) Not in the demo.
6. **The drop gate's shape.** (a) One of two arches on the bank, a lean. (b) One arch, take it or leave it, so the bank stays emptier.
7. **Evolution count.** (a) Three per run, one per break. (b) Cracked Core's "evolve now" is the only way to a fourth.
