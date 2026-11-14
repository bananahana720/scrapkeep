# World 1 gameplay critique (12 Nov 2026)

Read on `stage/alpha-w39` at 618dfc9b9, with the difficulty stack of pull request 845 read as a diff (not yet stacked). Thread "Critique world 1 gameplay design". Sibling critiques own the look ("Critique world 1 visual assets") and the effects ("Critique world 1 effects"); this page owns gameplay only. The buildable rows are W1-60 to W1-79 in [BACKLOG.md](../../../../BACKLOG.md#world-1-now-from-the-gameplay-critique-12-november-2026); this page says why, the rows say what to build.

## Verdict

World 1 teaches well and plays fair, but it does not yet deliver the mission's two big promises. **A strong build does not show**, and **run five plays like run one**. Four fixed seeds on the current stage make the first point plain: a skipper reaches Brindle holding 2 parts and a completionist 5 or 6, and Brindle lasts 79 to 87 s either way, because his phase floors turned the fight at 27.99 s and 52.0 s in all four runs. The second point is structural: per run, each stage draws one pocket, a stage modifier rolls 40% of the time, and everything else (terrain, routes, activities, lock waves, Brindle) is fixed.

The fixes are mostly small rows. The biggest single change is not a row but a choice for Andrew: in the sitting build, beating Brindle rolls the ball on into the Dig, which is parked and has an open blocker (PF-42). The run never ends as a world 1 clear.

## The sitting run as it plays today

Four bot runs, park table, `--stages=2`, seeds 3101 and 3102, pilots Cannon and Pylon Engineer. Bot game seconds (the pacing budget reads a human at about 1.75 times a bot, an inferred factor).

```
 intensity
   high |        ##                                   ######
        |       ####                                 ########
    mid |   ## ######        #     ###              ##########
        |  ##############   ###   #####             ##########
    low |####################################  ####################
        +---------------------------------------------------------> run time
          drop  yard   dam Warden | launch  flume yard  Warden | Brindle
          0 s   70 s   110-190 s  | 150-230 s       230-480 s  | +80 s
 parts    .     .      [gate] +1  |                 [gate] +1  |  (none)
 skipper  0 ------------------->1 |---------------------------->2 at Brindle
 complet. 0 --[camp]+1-----[gate]2|--[side sites]+2-[gate]---->5-6 at Brindle
```

| Run | Pilot | Dam exit | Flume exit | Brindle | Parts at Brindle | Brindle phases turned at |
| --- | --- | --- | --- | --- | --- | --- |
| skipper 3101 | Cannon | 156 s | 151 s | 79.3 s | 2 | 27.99, 52.0, 74.0 |
| skipper 3102 | Pylon Engineer | 149 s | 116 s | 86.6 s | 2 | 27.99, 52.0, 83.1 |
| completionist 3101 | Cannon | 228 s | 251 s | 79.5 s | 5 | 27.99, 52.0, 74.0 |
| completionist 3102 | Pylon Engineer | 222 s | 219 s | 85.9 s | 6 | 28.0, 52.0, 80.7 |

Whole runs: skipper 361 to 395 s, completionist 537 to 569 s. Secrets found: 0 in every run (bots do not seek them). Receipt: `/mnt/project-files/testing/gameplay-critique-w39/bots-618dfc9b.tar.gz` (bots, runs, qa and codex logs). Command per run: `godot --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/bot_run.gd -- --out=<dir> --policy=<p> --seeds=<s> --table=park --stages=2 --qa-log=1 --bot-no-visuals=1`. Four runs are a shape, not a band: no ratio here is a 24-seed median.

## Scorecard

| Area | Grade | One line |
| --- | --- | --- |
| Teaching order and fairness floors | Strong | One verb per lesson; 0.6 s tell floor, warning gap and cued follow-ups are in code |
| Moment-to-moment verbs | Good, one hole | The plating read is the biggest per-hit decision and is only taught on the death screen |
| Encounters and enemy roster | Weak | Every world 1 enemy asks "are you fast?"; both lock rings are chasers and lobbers only |
| Wardens | Weak | A fixed pulse with no escalation; the fight's length is set by heft |
| Brindle | Mixed | Four readable phases, but the floors make him a timer for every build |
| Difficulty shape | Weak | Peak at the dam, then four valleys in a row; the stack raises the dam peak, not the flume |
| Items and build cadence | Weak | A skipper makes 2 build choices in a whole world; the guaranteed cobalts are mostly stat lines |
| Economy | Weak | Cogs die unspent; Moss's hook shelf is a tease that never opens |
| Discovery | Good | Secrets with seeded spots and two tells, smoke plumes over caches, 42 field notes |
| Repeatability | Weak | One drawn pocket per stage; activities, lock waves and call-in lines are the same every run |
| Meta pull after a run | Weak | The summary says what you did, never what to chase next |
| The sitting's ending | Missing | A Brindle clear rolls into the parked Dig instead of ending the run |

## Findings, ranked by how much they change the sitting

Each finding names its row. "Measured" means a receipt; "read" means a file and line read on 618dfc9b9; "ASSERTED" is inferred from code with no run.

### 1. The sitting run has no world 1 ending (W1-60, Andrew's call)

Read: `flow.gd:1040-1059` sends Brindle's clear to `_advance_from`, which enters the next stage unless the stage is the run's last. In the sitting build that is the Dig, parked by ruling at and carrying blocker PF-42. A "won" run (`flow.gd:296-303`) is what opens `first_win`, HARD rung 1, the secret rooms and the clean-win paint, so a world 1 player never reaches any of them. W1-51 (a rim kicker launches the ball toward the Dig) assumes the run goes on. The recommended fix is a sitting flag that ends the run won after Brindle, reusing SG-02's planned `final` field per world row. It is a card because it changes what Andrew gets at the end of his sitting.

### 2. Power is invisible where it should pay most (W1-61, W1-62)

Measured: Brindle's phases turned at the floors (28 s, 52 s) in 8 of 8 turns across four runs, and the fight lasted 79 to 87 s with 2 parts or 6, heft 3.7 or 5.3. Read: `boss_rules.gd:22` `PHASE_MIN_SECONDS := [28.0, 24.0, 22.0]`, enforced at `boss.gd:267`. Ruling bs banks overflow hits toward the next bar, but the bank does not shorten anything, so the strong build waits. The economy pass already found a 19-part min-maxer at 83.6 s against a 3-part rusher at 84.1 s. The Wardens share the shape the other way round: the dam sheet needs 3 rams from a grown ball and 7 from heft 1.0 (`warden_reactor.gd:53-59`), so the fight measures size, not learning.

This breaks "overpowered pays" in the run's last fight. The floors exist so the set piece plays; keep them. W1-61 makes the overflow felt instead: a chunk broken before its floor puts Brindle in a reel for the rest of that floor, during which he takes no new attacks, sheds scrap and cogs per hit, and fills the ultimate. A strong build gets a loot shower and a victory lap inside the fight; a weak build sees nothing change. W1-62 gives the Wardens the same pay: a Warden broken under its par time adds one part roll to its gate, so a grown ball's quick break is worth more than time saved.

### 3. A skipper makes two build choices in a whole world (W1-63, W1-64)

Measured: the skipper's parts were one Warden gate per stage and nothing else (2 parts at Brindle in both runs); the first came at the dam exit, 149 to 156 bot seconds, about four and a half minutes of human play. The completionist reached 5 or 6, mostly from side-site pay that is a flat sum (`activities.gd` RULES, 180 scrap and one part for every site). Read: 5 of the 9 cobalt rows are stat lines with no behaviour (Sunforged Core "hit far harder", Gatling, Horizon Optic, Ram Plow, Spare Cell); Sunforged Core and Ram Plow were 5 of the 8 gate parts in these runs. The behaviour-changing relics come only from cracked caches.

The mission is "items are the heart of progression" with Isaac as the model. Today the heart beats twice in six minutes and both beats are often a bigger number. W1-63 adds a part moment at the first won fight on the dam (the yard crew's lock), so the skipper has three choices and the first one lands inside the first two minutes. W1-64 makes the Warden gate's guaranteed cobalt a behaviour part (a trigger or a transformer, by the DEMO-SPEC rule at `parts.gd:15-18`) and re-tags the two weakest stat cobalts to carry one.

### 4. Every world 1 enemy asks the same question, and the climaxes ask it loudest (W1-65, W1-66)

Read: every world 1 kind but the chaser is a fixed emplacement (`roster.gd` CHASSIS, move class "fixed"); the difficulty plan says mag trapper, jolt layer, ramp flipper and boom tender "punish a slow ball, never a fast one". Both lock rings, the climax before each Warden, hold only chasers and lobbers (`lock_rows.gd:21-29`: 5 waves on the dam, 7 on the flume). The difficulty stack (PR 845) doubles down: chasers at 9 m/s, a lead that vanishes at cruise, boils on a stalled ball. All of that is right for ruling cu ("harder by movement"), but it leaves speed as the one answer to every question.

"Chaos you can learn" needs more than one lesson. The world already has counters that are not speed: ram the chaser in its wind-up, jump or turn under a lobber shell, bite a second post to break a hooker's tether. W1-65 puts one lesson kind into each ring's late waves (a jolt layer on the dam's wave 4, a flap on wave 5; both never hold the ball, so the ring's no-holding rule stands). W1-66 gives two packs a non-speed ask: jolt layers lay a mat across the exit lane, so the answer is a jump, and the boom tender sweeps across the ball's line, so the answer is a turn.

### 5. The Wardens never escalate (W1-67)

Read: `warden.gd:40-43` runs the same pulse every chunk (2 s charge in a 6 s cycle). The stack makes that cycle 5.1 s for the whole fight; it is still flat. Only Brindle and the minibosses use `FightPhases`. Ruling "fights have phases" gives mini-bosses two phases; the Wardens are the world's mini-bosses in all but name. W1-67 ratchets the pulse per chunk lost (cycle times 0.9 per chunk, tell unchanged) and, on the dam, the sheet opens one of two lanes per chunk, shown in the telegraph, so the second half of the fight asks the player to read which side.

### 6. The difficulty curve peaks at the dam and then rests four times (to the "Tune dam yard and Brindle pressure" thread, W1-31)

Read: `MOBS_DAMAGE_W1` is 1.5 on the dam and 1.0 on the flume today, and 2.0 and 1.0 with the stack. The dam gate needs 5 packs (4 before PR 956) and the flume gate 1 (`lock_rows.gd`). The flume's director breather sits on its landing (`breather_rows.gd` "landing_breather"), and Brindle's first phase deals no damage. Measured: the flume took 116 to 151 s for the skipper, still under ruling ax's 180 s floor. So the run's hardest minute is its fourth, and the next eight minutes get easier. This is W1-31's job (its target already says the flume's opening must not be a rest); this page adds the cause list and hands it to the owning thread instead of filing a second row.

### 7. The plating read is never taught in the run (W1-68)

Read: a third to a half of all strikes are deflected (mechanics README, section 3), so a deflected hit is the most common way a player wastes a hit. The tips list has no plating tip (`field_tips.gd:44-53`), the first-steps lessons cover only roll and slam (`first_steps.gd:26`), and the only words about it are on the death screen for Warden and boss deaths (`death_tips.gd:29`). The amber and slate tint is the best-read mechanic in the game, per pass C; it needs a lesson, not a change. W1-68 adds a third first-steps lesson carried by shape and motion (ruling cx): on the first deflected strike the slate tint pulses on the target and a speed streak stretches from the ball, and the lesson retires on the first strike that beats plating.

### 8. The objective line tells the player to skip (W1-69)

Read: the Warden is the goal from the drop, and a side site takes the row only while the ball is already at it (`objectives.gd:155-161`). The prologue's goal is "Bring them back up", and the rescue cage that answers it is never named by the objective line. "Get heavy, then return" shows only after the player is struggling at the Warden. The design wants a 10 to 15 minute run with detours that pay; the line pushes a 6 minute hallway. W1-69 adds a dim second row with an edge marker for the cage and for the nearest unvisited site while the Warden is not engaged, and dims it once the Warden is.

### 9. Run five plays like run one (W1-70, W1-71)

Read: `stage_modifier.gd:55-57` gives one drawn pocket per world 1 stage (two with the surplus row), a modifier rolls 40% of the time, field finds move between two spots, and the rogue site is one of two. Terrain, routes, the 4 dam and 5 flume activities, the lock waves, the six event rows and Brindle are fixed. Call-in lines are a single `text` per row (`lore_rows.gd:33-66`), so a player hears the same words every run; `flourish_rows.gd:49-58` already rotates arrays. W1-70 lets an authored activity row list alternatives, one drawn per site from the run seed, which is the cheapest real layout variety and a step toward FD-02. W1-71 lets call-in rows carry text arrays and writes two or three variants for each world 1 row.

### 10. Nothing says what to chase next (W1-72)

Read: the summary's board line (`shift_board.gd:166-184`) reports only what was just stamped; the next rung and its reward are read only by the achievements page, and the "N / 7 Spillway secrets" count lives in the camp menu, two screens away. The shift board's written future unlocks (`shift_board.gd:72-90`, "the player sees it coming on the board") are read by nothing outside the file. W1-72 adds one summary line with the next rung's stamp and the world's secret count, and shows each locked seed under the rung that opens it on the achievements page. Display only, so no band moves; it is the slice of FD-03 that belongs before the sitting.

### 11. Cogs die at Brindle (W1-73, extends W1-58)

Read and measured: the economy pass found 1,332 to 2,012 cogs unspent at the end, and Moss's hook shelf is locked one heft class above the ball in every visit (`shop.gd:190,451,465`). With Moss's scale on in the sitting, selling mass makes the ball lighter, so the hook moves further away. W1-58 puts a second sink "on the main route"; the cause is that the sitting ends at Brindle. W1-73 docks Moss once at the Slag Bowl's mouth for a last call: one shelf, always one slot that completes the player's nearest maker set (the 3-piece bonus is otherwise out of reach: `parts.gd` maker nudge 1.1, 50 parts across 7 makers), and one cog-fed boss consumable. Leftover cogs become Brindle power, which finding 2 then makes visible.

### 12. Skill expression pays nothing you can see (W1-74)

Read: a chain multiplies smash damage from 1.3 to a 2.5 cap at 6 links (`chain.gd:17-19`) and is shown only as a counter from combo 2. Pass C counted exactly 4 ultimates in all four census runs, from 425 to 629 s, which suggests the meter's rate caps flatten skill (ASSERTED; not re-run). W1-74 makes a paid chain of 3 or more drop a scrap burst stepped by combo, and adds the combo count to the bot census so the ultimate claim gets measured. The sting and burst look go to the effects thread.

### 13. The Foreman barely appears (W1-75)

Read: STORY-MAP places the Foreman in world 1 as memos. Stage memos show only when a modifier rolls, so about a third of runs see none (ASSERTED from 40% per stage); there is no loss memo on the death screen, and 2 of 42 world 1 field notes mention the Foreman. W1-75 gives every stage card a Foreman memo, with seeded "conditions nominal" lines when no modifier rolls, and puts one logged-loss memo above the crew's tip on the death screen, so the crew keeps the last word.

### 14. Smaller findings

- **Shift has no job in world 1, and the census cannot see it (W1-76).** Read: five of six pilots' Shift emits `dashed`, not `boosted` (`augments.gd:236-373`; `boosted` is Sable's only, `rigid_ball.gd:238`), so pass C's "bots never boost" is a census gap, not a bot gap. Surge and recoil set speed to 20.8 m/s, below the blazing tier, so above it Shift adds nothing. No world 1 map asks for boost. W1-76 counts `dashed` in the census and puts one blazing-tier ask on the dam (a sluice jump only a boosted ball clears).
- **The start pick and boost prompt land before the first roll (W1-77).** Read: `opening.gd:22-24` pauses the drop on the kit and start pick; the boost prompt is open from the start. Hold the boost prompt until the ball first reaches the fast tier, and move the start pick to the yard crew's clear (where W1-63 adds a part moment anyway).
- **The sitting profile pre-opens what it should test (W1-78).** Read: `game.gd:561-579` opens every pilot and first-win secret and never saves, so the sitting cannot judge the first unlock. A launch option for earned unlocks and one Sitting Kit block on a fresh profile; the coordinator owns the kit.
- **Moss's hook never opens (W1-79).** Carry the locked hook into the next stage's stock and pin the class it needs, so carrying scrap through the flume has a goal.
- **One flume radio take has no cache.** `take-brindles-bolero` has a catalogue row (`assets/radio/catalogue.json:2197`) and no entry in `assets/radio/cache_spots.json`. Passed to the thread "Add side spots to the flume" with W1-17, along with the count that the flume (5 activities, a valve cache, 2 field finds, 2 Signal caches, a pocket) is close to the dam by number, so W1-17's gain is variety more than more spots.
- **Brindle's drop does nothing.** The Admiral's Crest is a token, never read as a part (`parts.gd:738`). Parked with the cobalt pick (ruling ap); listed in the after-sitting rows.

## What already works (keep it)

- **Teaching order.** From the yard crew on, each lesson is one verb, and each Brindle phase reuses one verb the player already has (first-15 README section 1). `opening.gd` gives the first minute one voice at a time and `field_tips.gd` holds tips to one per 20 s and none in a fight.
- **Fairness floors in code.** A 0.6 s tell floor, a 0.2 s warning gap, cued follow-ups (`fight_phases.gd`) and Brindle's charge stop radius (`boss_rules.gd`).
- **Maker tricks change behaviour, not numbers,** and wake at two pieces; a gate whose part completes a trick names it and pulses; a trick's first firing gets a why-callout and a codex burst.
- **The secrets layer** borrows Isaac's pattern without copying it: seeded spots with two tells (a seep at 22 m, a radio at 40 m), the timed Shift Clock Door, logbook hints for unfound rows, and smoke plumes over caches and the cage.
- **The two Wardens use different verbs** (the dam's sheet ride, the flume's latch and shoot with a slag hop), each with a clear old-job silhouette.

## For future worlds

Four findings are rules, not world 1 bugs, and each world's design card should meet them: a world's lock rings carry that world's lesson kinds; its Wardens ratchet per chunk; a boss floor pays its overflow; and the first won fight of a world's first stage pays a part. They are written into the rows below as "Future worlds" lines (FD-11 to FD-14) so worlds 2 and 3 inherit them.

## Out of this silo (sent on)

- Effects thread: the chain-pay burst and sting (W1-74's look), the Brindle reel's look (W1-61), the plating lesson pulse (W1-68).
- Visual assets thread: none new; the telegraph and readability items are already PF rows and W1-03 to W1-14.
- "Tune dam yard and Brindle pressure": finding 6, and the note that W1-65 and W1-67 touch files PR 845 changes (`lock_rows.gd`, the Warden dials), so they build after it stacks.
- "Add side spots to the flume": the bolero cache and the flume count.

## Method and limits

A mode at squad level: four read-only scouts (feel and onboarding, encounters and bosses, items and economy, discovery and repeatability) read the docs and code; every finding kept here was re-read on 618dfc9b9 by this thread, and the four bot runs above were run here. Automated play does not establish feel. Nothing here was played by a person or on the PC; a first-timer film on the build that carries these rows is the check that counts.
