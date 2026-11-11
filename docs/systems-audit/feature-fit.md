# Feature fit (pass D, world 1)

**What this page says.** Of the 30 player-facing features in world 1, 22 earn their place as they are. Four should be merged into the item ladder so a player meets three build systems, not ten. One page (head starts) should be hidden until it can pay. Six are deferred: they are specs with nothing a player meets. Three new mechanics are proposed, each extending a rule already in the game, and each answers one of pass A's problems. The design thread's three mechanics (Heat, Reservoir, Called Shot) are already approved by Andrew and are logged, not re-judged. Every cut, merge and new mechanic here is a NEEDS ANDREW card in the thread; nothing is built by this pass.

**Read at.** `stage/alpha-w37` head `995f3dd2`, 11 Nov 2026, with pass A's map ([systems-map.md](systems-map.md)) and its eight world 1 bot runs. Card: [SA-D in BACKLOG.md](../../BACKLOG.md#sa-d).

**How to read the table.** Pillars are BIBLE.md section 1's three, by short word: **mastery** (joyful physical mastery), **build** (scrap becomes your build), **world** (a world worth crossing). *Cost to learn* is what a first-timer must hold in their head before the feature helps them: **low** (one look or one try), **medium** (a rule to remember), **high** (a rule plus a list). *Cost to maintain* is the code that carries it, counted in lines of GDScript on this head (the files are named, so the count can be rerun), plus anything that makes it expensive beyond its size. *Verdict* is keep, merge, cut or defer.

## The table

| # | Feature | Pillar | Cost to learn | Cost to maintain | Verdict | Why |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Rolling ball, boost, jump, slam | mastery | low | high: the physics authority (`player_ball.gd` 1,690 lines, `rigid_ball.gd`) | keep | It is the game. |
| 2 | Harpoon line: swing, fling, reel | mastery | medium | low: `harpoon.gd` 72 lines, with line code in the ball | keep | Everyone's mobility (Story map); the reel opens weak points. |
| 3 | Carve | mastery, world | low | low | keep, connect | Add the game event so sound and the tricks book can hear it (pass C). |
| 4 | Six pilots and kits | mastery | medium | high: six kits, `rivet_kit.gd` alone 1,718 lines | keep | Replay variety; each is a way of working (Story map). |
| 5 | Rack actives (six) and the ultimate | mastery | medium | high: `src/combat/actives/` 1,715 lines, `ultimate.gd` 1,143 | keep | Low-cooldown choices while moving (BIBLE.md section 6). |
| 6 | Reactor Wardens, Brindle, rogues | mastery, world | medium | high: `warden.gd`, `boss.gd`, `rogue.gd` | keep | The world's tests. |
| 7 | Event director and stage events | world | low | high: `director.gd`, `event_director.gd`, `src/world/events/` | keep | "Chaos you can learn". |
| 8 | Side spots (caches, relay, rescue, surge, radio) | world, build | low each | high together | keep | The things to explore; pass B makes them pay more than the direct path (problem 2). |
| 9 | Scrap: mass, heft, armour, spill | build | low | medium | keep | "You are made of what you broke." |
| 10 | Cogs and Moss's counter | build | medium | high: shop and bay 2,177 lines | keep | Pass B fixes the rates (problem 4). |
| 11 | Cores | build | high: they raise the next gate, buy a heal, ride a bet, and vanish at the stage end | low: about 50 lines in `run_state.gd` | keep, connect | 0 cores reached any of 8 bot runs. New mechanic 3 below gives a core a home. |
| 12 | Grey panels | build | low per panel; high as a stack of percentage lines | low: 590 lines | keep | The flat-stat rung of the ladder. Pass C makes a panel read as a part on the ball, not a percentage. |
| 13 | Mint and cobalt parts at gates | build | medium | high: `parts.gd` and item code 2,789 lines | keep | The heart of the ladder. |
| 14 | Relics from cracked caches | build | medium: a separate kind with its own slot rule | medium: 684 lines | merge into the ladder | A relic is a part with a pilot-slot effect. Shown as a rung, it stops being an eleventh thing to learn. |
| 15 | Hot-wire (Spark Tread) | build | medium: fit or recycle, a stripe, a wear rule | medium: 421 lines | merge into the ladder | One part with an extra offer screen. Make it a rare part offered at a gate like any other. |
| 16 | Maker sets (three of one maker) | build, world | medium | medium: 475 lines | keep as the one set rule | It carries the world's makers (Story map: "Every find was made by someone for another job"). |
| 17 | Named synergies | build | high: nine hidden pairings on top of maker sets | low: 239 lines | merge into maker sets | Two hidden set rules beside a visible one; a player cannot tell which is firing. |
| 18 | Three-part sets | build | high: a third set list | low: 162 lines | merge into maker sets | Same as row 17. Keep the rule changes they make; move them onto maker tricks. |
| 19 | Upgrade tree, depths 1 and 2 | build | medium | high: 1,961 lines with UI | keep | The Bible's Path. |
| 20 | Start pick of three | build | low | low: 685 lines | keep | A small first decision; fold under Path in what the player reads. |
| 21 | Trade spots: keeper's gamble, foreman's kindness | build, theme | medium | medium: 866 lines | keep, reprice | The theme's one choice (ruling ci). New mechanic 1 makes the hull price cost something. |
| 22 | Bet crate | build | medium | low | keep | Rides on cores; lives once cores arrive. |
| 23 | SPIL-9 companion, two sockets | mastery | medium | high: 1,540 lines | keep | The Crew door. |
| 24 | Devices (charges, sentry, stakes) | mastery | low | medium: 651 lines | keep | Part of three pilots' kits. |
| 25 | Element by material (ice on water, live water) | mastery, world | low to see, medium to plan | medium: 751 lines | keep | A world rule the player finds (TADR-009). |
| 26 | Run tier (HARD ladder) | mastery | low | low: 146 lines | keep | Opens after the first win; "harder, never easier" (ruling cu). |
| 27 | Death, fast restart, resume | mastery | low | high: persistence | keep | "A death is a fast restart, never a punishment." |
| 28 | Camp: Moss, skee, trial, sandbox, bay | mastery, world | low | high: 2,168 lines | keep | Practice and the crew's home. |
| 29 | Shift board, marks, cosmetics, codex, scrapbook | world | low | medium | keep | Unlocks that widen the game, never a stat. |
| 30 | Achievements | world | low | medium: 644 lines | keep, connect | Eleven are record-only (`achievements.gd` `RECORD_ONLY`); each should pay a look, a tune or a scrapbook sticker. |
| 31 | Head starts page | none today | low, but it reads as broken | low: 243 lines | cut the page until it fills | `open_earned` has no caller; the page shows "0 of 4" forever. Keep the code; hide the page. |

### Deferred (specs with nothing a player meets)

| Feature | Pillar | Why defer |
| --- | --- | --- |
| Pearl and gold rungs, brass trophies | build | After the alpha (Story map). |
| The Mind's offerings | build, theme | After the alpha (ruling of 23 Oct, Story map). |
| Scrap-bot crew (TADR-011) | build | Not built; SPIL-9 stands in. See change request 1. |
| Respec by a special opportunity | build | Not built. See change request 2. |
| Stage variants and whole-run modifiers (night shift, backwash, overtime, short crew) | world | Four seeds on the shift board, read by nothing; already planned for after the sitting. |
| Worlds 2 and 3 features | all | Parked (ruling at). |

## Already approved: the design thread's three mechanics

Andrew accepted these on 11 Nov 2026 at 18:42Z and wants them in before the sitting (ruling in [DECISIONS.md](../../project-guide/handoff/DECISIONS.md)). The thread "Design loops you can't put down" builds them behind flags and owns their files ([docs/design/loops.md](https://github.com/bananahana720/scrapkeep/pull/763) on pull request 763). Logged here, not re-judged:

| Mechanic | Rule it extends | New decision | Pass A problem it touches |
| --- | --- | --- | --- |
| Heat | speed tiers (blazing) and the ram | hold the heat for the blast, or bleed it before the next hit on a hot shell | 2: it pays for riding fast through the fight, not past it |
| Reservoir (overtime bell and sluice) | the keeper's gamble and the dam's water | ring again for a bigger pot with the next wave arriving, or cash out | 1 and 2: a stake that bites, in the yard you would otherwise skip |
| Called Shot | the Warden break, the dunk and the reel | which finisher you can land on this Warden with this build | 4: it spends the Warden's bonus core |

## Three new mechanics (NEEDS ANDREW)

Each one extends a rule the game already has, answers one of pass A's five problems, and avoids the twelve loops in pull request 763.

### 1. Marked hull

- **Rule it extends.** The trade chest's hull price (`stake_devices.gd`, 25, 50 or 75% of max hull) and free regen (`run_state.gd`, 6 hull a second after 5 s).
- **The change.** Paying hull at a keeper's gamble lowers **max** hull by that share until the next Warden break. Regen fills only to the marked line. The mark shows as a brass bracket on the hull bar and a welded plate on the ball; the Warden break pops the plate off with a clang.
- **New decision.** A part now against a thinner bar through the next fight. Today the price is about 9 to 18 s of waiting (pass A regen probe), so there is no decision at all.
- **Answers.** Problem 1. It also makes the foreman's kindness (a heal for cores or cogs) worth something, because a heal can lift a mark.
- **Risk.** A low-hull player cannot afford the gamble at all. The existing floor (`FLOOR_SHARE` 10%) stays.

### 2. Moss weighs your haul

- **Rule it extends.** Scrap as size and armour (`run_state.gd` mass and spill) and Moss's counter (`shop.gd`). Proposed in the 9 Nov systems plan as "Moss weighs your haul"; this page makes it a rule.
- **The change.** At Moss's bay, the player may drop mass onto Moss's scale for cogs. Cogs from kills fall (pass B sets the number), so the shelf becomes a real choice again.
- **New decision.** Arrive at the next Warden heavy (armour, punch from heft) or light with a better part. Today mass and cogs both rise together, one cog per scrap unit, and neither asks anything.
- **Answers.** Problem 4 (cogs inflate and ask no decision) and problem 3 (it ties scrap to the Parts door instead of adding a door).
- **Risk.** A player who sells all mass gets small and fragile. That is the trade; size never touches handling (BIBLE.md section 6).

### 3. Carry a core in SPIL-9

- **Rule it extends.** Cores raise the next gate's offer and vanish at the stage end (`run_state.gd` `enter_stage`, `bonus_cores = 0`); SPIL-9 has two module sockets (`companion.gd`).
- **The change.** One core can be socketed in SPIL-9 and carried into the next stage. While it rides, it takes a module socket. At the next gate, the carried core counts toward the offer.
- **New decision.** SPIL-9's help in this stage against a better gate in the next. Today a core that arrives must be used in its own stage or it is lost, and in 8 bot runs none arrived.
- **Answers.** Problem 4 (cores never reach the player) and problem 3 (it puts cores under the Crew door instead of being their own thing).
- **Risk.** Needs cores to arrive at all; pass B checks the core sources first.

## Change requests (the Bible and the game differ)

These go to the coordinator. This pass does not edit BIBLE.md or an ADR.

1. **The crew.** TADR-011 (10 Oct) replaced "one main companion" with a scrap-bot crew, and BIBLE.md section 6 was amended to match. The game has SPIL-9 with two sockets and no crew. Either the ADR is deferred to after the alpha in its own text, or the crew is scheduled. Recommendation: defer, and say so in TADR-011, because SPIL-9 works and world 1 is the priority.
2. **Respec.** BIBLE.md section 6 says a branch changes only through "a special respec opportunity, such as a stage discovery or event". None exists. Recommendation: mark it deferred in the Bible, or make it one of the rescue-site rewards in world 2.
3. **The four slots.** BIBLE.md section 6 still frames the build as weapon, main hero skill, mobility and ultimate in a close-third-person mech. The game is a rolling ball whose verbs are roll, line, carve and aim, with a rack of actives. A one-paragraph alpha note in that section would stop the next reader from building to the old frame.
4. **Path, Relic and Parts.** BIBLE.md section 1 names three build parts. If Andrew takes the merge card, the Bible line becomes "Path, Parts and Crew", with relics as a rung of Parts.

## Decisions sent to Andrew

Three cards in the thread, each with a recommended default and "none of these":

1. Fold the build systems: merge relics and hot-wire into the part ladder, and named synergies and three-part sets into maker sets (rows 14, 15, 17, 18).
2. Build the three new mechanics above: all three, Marked hull first, or none.
3. Hide the head starts page until it can fill (row 31).

Their answers are recorded here when they come back.

## Systems health (for the coordinator's digest)

| System group | Pass status | Top open issue | Last result | What changed |
| --- | --- | --- | --- | --- |
| Build systems | D done; cards to Andrew | Ten doors where three would do | 31 features judged: 22 keep, 4 merge, 1 cut, 4 keep and wire | Nothing in the game |
| Resources | D done | Hull free, cogs piling, cores missing | Three mechanics proposed, one per problem | Nothing |
| Spec-only systems | D done | Crew and respec in the Bible, not the game | Four change requests | Nothing |

**One finding in plain words.** A feature costs twice: once in the code we keep, and once in the player's head. The relics, hot-wire, synergies and three-part sets are small in code, but each is another list a player has to learn before it helps. Folding them into the ladder and the maker sets keeps what they do and removes four things to learn.
