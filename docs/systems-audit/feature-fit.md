# Feature fit (pass D, world 1)

**What this page says.** Of the 31 player-facing features in world 1 judged here, 27 stay (4 of them need connecting to the rest of the game and 1 needs a new price). Four should be merged into the item ladder so a player meets three build systems, not ten. Head starts are earned but never shown; their four rewards should be re-pointed. Six are deferred: they are specs with nothing a player meets. Three new mechanics are proposed, each extending a rule already in the game, and each answers one of pass A's problems. The design thread's three mechanics (Heat, Reservoir, Called Shot) are already approved by Andrew and are logged, not re-judged. Every cut, merge and new mechanic here is a NEEDS ANDREW card in the thread; nothing is built by this pass.

**Read at.** `stage/alpha-w37` head `995f3dd2`, 11 Nov 2026, with pass A's map ([systems-map.md](systems-map.md)) and its eight world 1 bot runs. Card: [SA-D in BACKLOG.md](../../BACKLOG.md#sa-d).

**How to read the table.** Pillars are named as in [systems-map.md](systems-map.md) (top of the page). *Cost to learn* is what a first-timer must hold in their head before the feature helps them: **low** (one look or one try), **medium** (a rule to remember), **high** (a rule plus a list). *Cost to maintain* is the code that carries it, counted in lines of GDScript on this head; the files behind each count are listed under "Where the line counts come from" so it can be rerun, plus anything that makes it expensive beyond its size. *Verdict* is keep, merge, cut or defer.

## The table

| # | Feature | Pillar | Cost to learn | Cost to maintain | Verdict | Why |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Rolling ball, boost, jump, slam | mastery | low | high: the physics authority (`player_ball.gd` 1,690 lines, `rigid_ball.gd`) | keep | It is the game. |
| 2 | Harpoon line: swing, fling, reel | mastery | medium | low: `harpoon.gd` 72 lines, with line code in the ball | keep | Everyone's mobility (Story map); the reel opens weak points. |
| 3 | Carve | mastery, world | low | low: a few lines in `player_ball.gd`; no event in `game_events.gd` | keep, connect | Add the game event so sound and the tricks book can hear it (pass C). |
| 4 | Six pilots and kits | mastery | medium | high: six kits, `rivet_kit.gd` alone 1,718 lines | keep | Replay variety; each is a way of working (Story map). |
| 5 | Rack actives (six) and the ultimate | mastery | medium | high: `src/combat/actives/` 1,715 lines, `ultimate.gd` 1,143 | keep | Low-cooldown choices while moving (BIBLE.md section 6). |
| 6 | Reactor Wardens, Brindle, rogues | mastery, world | medium | high: `warden.gd`, `boss.gd`, `rogue.gd` | keep | The world's tests. |
| 7 | Event director and stage events | world | low | high: `director.gd`, `event_director.gd`, `src/world/events/` | keep | "Chaos you can learn". |
| 8 | Side spots (caches, relay, rescue, surge, radio) | world, build | low each | high together: `cracked_cache.gd`, `hold_relay.gd`, `relay_stake.gd`, `rescue_site.gd`, `surge_course.gd`, `surge_run.gd`, `radio_cache.gd` | keep | The things to explore; pass B makes them pay more than the direct path (problem 2). |
| 9 | Scrap: mass, heft, armour, spill | build | low | medium: `scrap_field.gd`, `accretion.gd` 1,023 lines, plus `run_state.gd` mass | keep | "You are made of what you broke." |
| 10 | Cogs and Moss's counter | build | medium | high: shop and bay 2,187 lines | keep | Pass B fixes the rates (problem 4). |
| 11 | Cores | build | high: they raise the next gate, buy a heal, ride a bet, and vanish at the stage end | low: about 50 lines in `run_state.gd` | keep, connect | 0 cores reached any of 8 bot runs. New mechanic 3 below gives a core a home. |
| 12 | Grey panels | build | low per panel; high as a stack of percentage lines | low: 590 lines | keep | The flat-stat rung of the ladder. Pass C makes a panel read as a part on the ball, not a percentage. |
| 13 | Mint and cobalt parts at gates | build | medium | high: parts and item code 3,224 lines | keep | The heart of the ladder. |
| 14 | Relics from cracked caches | build | medium: a separate kind with its own slot rule | medium: 463 lines | merge into the ladder | A relic is a part with a pilot-slot effect. Shown as a rung, it stops being an eleventh thing to learn. |
| 15 | Hot-wire (Spark Tread) | build | medium: fit or recycle, a stripe, a wear rule | medium: 421 lines | merge into the ladder | One part with an extra offer screen. Make it a rare part offered at a gate like any other. |
| 16 | Maker sets (three of one maker) | build, world | medium | medium: 475 lines | keep as the one set rule | It carries the world's makers (Story map: "Every find was made by someone for another job"). |
| 17 | Named synergies | build | high: nine hidden pairings on top of maker sets | low: 239 lines | merge into maker sets | Two hidden set rules beside a visible one; a player cannot tell which is firing. |
| 18 | Three-part sets | build | high: a third set list | low: 162 lines | merge into maker sets | Same as row 17. Keep the rule changes they make; move them onto maker tricks. |
| 19 | Upgrade tree, depths 1 and 2 | build | medium | high: 1,961 lines with UI | keep | The Bible's Path. |
| 20 | Start pick of three | build | low | low: 685 lines | keep | A small first decision; fold under Path in what the player reads. |
| 21 | Trade spots: keeper's gamble, foreman's kindness | build, theme | medium | medium: 474 lines | keep, reprice | The theme's one choice (ruling ci). New mechanic 1 makes the hull price cost something. |
| 22 | Bet crate | build | medium | low: `bet_crate.gd` | keep | Rides on cores; lives once cores arrive. |
| 23 | SPIL-9 companion, two sockets | mastery | medium | high: 1,540 lines | keep | The Crew build system. |
| 24 | Devices (charges, sentry, stakes) | mastery | low | low: 385 lines | keep | Part of three pilots' kits. |
| 25 | Element by material (ice on water, live water) | mastery, world | low to see, medium to plan | medium: 751 lines | keep | A world rule the player finds (TADR-009). |
| 26 | Run tier (HARD ladder) | mastery | low | low: 146 lines | keep | Opens after the first win; "harder, never easier" (ruling cu). |
| 27 | Death, fast restart, resume | mastery | low | high: `run_store.gd` and the save format | keep | "A death is a fast restart, never a punishment." |
| 28 | Camp: Moss, skee, trial, sandbox, bay | mastery, world | low | high: 3,071 lines | keep | Practice and the crew's home. |
| 29 | Shift board, marks, cosmetics, codex, scrapbook | world | low | medium: `shift_board.gd` 322 lines, `camp_scrapbook.gd` | keep | Unlocks that widen the game, never a stat. |
| 30 | Achievements | world | low | medium: 644 lines | keep, connect | Eleven are record-only (`achievements.gd` `RECORD_ONLY`); each should pay a look, a tune or a scrapbook sticker. |
| 31 | Head starts | none today | none: a player never sees them | low: 243 lines | keep, connect | Corrected 11 Nov 19:12Z: the page is already unreachable (no screen opens `ui/meta_page.gd`), so Andrew's "hide it" (ruling de) is satisfied with no commit. The live problem: the four `ach_meta_*` achievements pay head-start ids that nothing shows. Re-point those four rewards to a look, a tune or a sticker, as row 30 does for the record-only ones (decided here; Andrew can overturn). |

### Deferred (specs with nothing a player meets)

| Feature | Pillar | Why defer |
| --- | --- | --- |
| Pearl and gold rungs, brass trophies | build | After the alpha (Story map). |
| The Mind's offerings | build, theme | After the alpha (ruling of 23 Oct, Story map). |
| Scrap-bot crew (TADR-011) | build | Not built; SPIL-9 stands in. See change request 1. |
| Respec by a special opportunity | build | Not built. See change request 2. |
| Stage variants and whole-run modifiers (night shift, backwash, overtime, short crew) | world | Four seeds on the shift board, read by nothing; already planned for after the sitting. |
| Worlds 2 and 3 features | all | Parked (ruling at). |

### Not judged here

Six systems from [systems-map.md](systems-map.md) have no row because they are the game's frame rather than features a player opts into, and another pass owns them: aim and weapons (map row 4) and ordinary enemies (row 8) go to pass C; hull and regen (row 7) to pass B and new mechanic 1 below; the HUD and tips (row 37) to the thread "Rebuild game UI for clarity"; reactive music (row 38) and the chain counter and tricks book (row 39) to pass C's feedback check.

## Already approved: the design thread's three mechanics

Andrew accepted these on 11 Nov 2026 at 18:42Z and wants them in before the sitting (ruling da, [DECISIONS.md](../../project-guide/handoff/DECISIONS.md)). The thread "Design loops you can't put down" builds them behind flags and owns their files ([docs/design/loops.md](https://github.com/bananahana720/scrapkeep/pull/763) on pull request 763). Logged here, not re-judged:

| Mechanic | Rule it extends | New decision | Pass A problem it touches |
| --- | --- | --- | --- |
| Heat | speed tiers (blazing) and the ram | hold the heat for the blast, or bleed it before the next hit on a hot shell | 2: it pays for riding fast through the fight, not past it |
| Reservoir (overtime bell and sluice) | the keeper's gamble and the dam's water | ring again for a bigger pot with the next wave arriving, or cash out | 1 and 2: a stake that bites, in the yard you would otherwise skip |
| Called Shot | the Warden break, the dunk and the reel | which finisher you can land on this Warden with this build | 4: it spends the Warden's bonus core |

## Three new mechanics (NEEDS ANDREW)

Each one extends a rule the game already has and answers one of pass A's five problems. Checked against the twelve loops and four fusions in `docs/design/loops.md` on pull request 763: none sells mass, carries a core across stages or prices hull in max hull. The nearest is Scar Tissue (loop 11, killed in that doc's scoring), which lowers max hull for the rest of the run after a near death; Marked hull is a price you choose at a chest and it clears at the next Warden. Reservoir also extends the keeper's gamble, but it raises the stake on a wave in the dam yard and does not touch the hull price, so the two stack; Called Shot spends the Warden's bonus core in the stage it lands, which a carried core does not change.

### 1. Marked hull

- **Rule it extends.** The trade chest's hull price (`stake_devices.gd`, 25, 50 or 75% of max hull) and free regen ([systems-map.md](systems-map.md) problem 1).
- **The change.** Paying hull at a keeper's gamble lowers **max** hull by that share until the next Warden break. Regen fills only to the marked line. The mark shows as a brass bracket on the hull bar and a welded plate on the ball; the Warden break pops the plate off with a clang. A heal at the foreman's kindness also lifts the mark.
- **New decision.** A part now against a thinner bar through the next fight. Today regen refunds the price in seconds ([systems-map.md](systems-map.md) problem 1), so there is no decision at all.
- **Answers.** Problem 1. It also makes the foreman's kindness (a heal paid in cores, `trade_pockets.gd`) worth something, because a heal lifts a mark.
- **Risk.** A low-hull player cannot afford the gamble at all. The existing floor (`FLOOR_SHARE` 10%) stays.

### 2. Moss weighs your haul

- **Rule it extends.** Scrap as size and armour (`run_state.gd` mass and spill) and Moss's counter (`shop.gd`). Proposed in the 9 Nov systems audit (the Claude Doc "Game systems: audit and plan", linked from [PLAN.md](PLAN.md)) as "Moss weighs your haul"; this page makes it a rule.
- **The change.** At Moss's bay, the player may drop mass onto Moss's scale for cogs. Cogs from kills fall (pass B sets the number), so the shelf becomes a real choice again.
- **New decision.** Arrive at the next Warden heavy (armour, punch from heft) or light with a better part. Today mass and cogs both rise together, one cog per scrap unit, and neither asks anything.
- **Answers.** Problem 4 (cogs inflate and ask no decision) and problem 3 (it ties scrap to Parts instead of adding a new build system).
- **Risk.** A player who sells all mass gets small and fragile. That is the trade; size never touches handling (BIBLE.md section 6).

### 3. Carry a core in SPIL-9

- **Rule it extends.** Cores raise the next gate's offer and vanish at the stage end (`run_state.gd` `enter_stage`, `bonus_cores = 0`); SPIL-9 has two module sockets (`companion.gd`).
- **The change.** One core can be socketed in SPIL-9 and carried into the next stage. While it rides, it takes a module socket. At the next gate, the carried core counts toward the offer.
- **New decision.** SPIL-9's help in this stage against a better gate in the next. Today a core that arrives must be used in its own stage or it is lost, and in 8 bot runs none arrived.
- **Answers.** Problem 4 (cores never reach the player) and problem 3 (it puts cores under Crew instead of being their own thing).
- **Risk.** Needs cores to arrive at all; pass B checks the core sources first.
- **Conflicts with the Bible.** BIBLE.md section 6 says cores stay zone-local, and STORY-MAP.md section 4 calls a core "good for one stage and then cold". Carrying one breaks that rule on purpose, so it needs change request 5 below.

## Change requests (the Bible and the game differ)

These go to the coordinator. This pass does not edit BIBLE.md or an ADR.

1. **The crew.** TADR-011 (10 Oct) replaced "one main companion" with a scrap-bot crew, but BIBLE.md section 6 still says "One main companion" and "no second companion", and the game has SPIL-9 with two sockets and no crew. The ADR disagrees with both the Bible and the game. Either the ADR is deferred to after the alpha in its own text, or the crew is scheduled. Recommendation: defer, and say so in TADR-011, because SPIL-9 works and world 1 is the priority.
2. **Respec.** BIBLE.md section 6 says a branch changes only through "a special respec opportunity, such as a stage discovery or event". None exists. Recommendation: mark it deferred in the Bible, or make it one of the rescue-site rewards in world 2.
3. **The four slots.** BIBLE.md section 6 still frames the build as weapon, main hero skill, mobility and ultimate in a close-third-person mech. The game is a rolling ball whose verbs are roll, line, carve and aim, with a rack of actives. A one-paragraph alpha note in that section would stop the next reader from building to the old frame.
4. **Path, Relic and Parts.** BIBLE.md section 1 names three build parts. If Andrew takes the merge card, the Bible line becomes "Path, Parts and Crew", with relics as a rung of Parts.
5. **Cores stay zone-local.** BIBLE.md section 6 and STORY-MAP.md section 4 keep a core in its own stage. If Carry a core is built, both lines gain one exception: a core socketed in SPIL-9 rides to the next stage.

## Decisions sent to Andrew

Three cards in the project thread "Audit and improve game systems" (11 Nov 2026, 19:03Z), each with a recommended default and "none of these":

1. Fold the build systems: merge relics and hot-wire into the part ladder, and named synergies and three-part sets into maker sets (rows 14, 15, 17, 18).
2. Build the three new mechanics above: all three, Marked hull first, or none.
3. Hide the head starts page (row 31). Since satisfied: the page was already unreachable; see row 31.

Andrew chose the recommended option on all three on 11 Nov 2026 at 19:08Z; his answers are rulings dc, dd and de in [DECISIONS.md](../../project-guide/handoff/DECISIONS.md).

Who builds them is the coordinator's call, because the files belong to other threads: the fold touches `src/build/` item code and the UI thread's screens, Marked hull touches `stake_devices.gd` and the hull bar, and Carry a core touches `run_state.gd`, which pull request 763 holds.

## Systems health (for the coordinator's digest)

| System group | Pass status | Top open issue | Last result | What changed |
| --- | --- | --- | --- | --- |
| Build systems | D done; Andrew chose all three | Ten build systems where three would do | 31 features judged: 27 keep (4 need connecting, 1 a new price), 4 merge; 6 specs deferred | Nothing in the game |
| Resources | D done | Hull free, cogs piling, cores missing | Three mechanics proposed, one per problem | Nothing |
| Spec-only systems | D done | Crew and respec in the Bible, not the game | Four change requests | Nothing |

**One finding in plain words.** A feature costs twice: once in the code we keep, and once in the player's head. The relics, hot-wire, synergies and three-part sets are small in code, but each is another list a player has to learn before it helps. Folding them into the ladder and the maker sets keeps what they do and removes four things to learn.

## Where the line counts come from

`wc -l` on `stage/alpha-w37` at `995f3dd2`, paths under `sketches/core-loop/src/`:

| Row | Files |
| --- | --- |
| 1 | `movement/player_ball.gd` (1,690), `movement/rigid_ball.gd` |
| 2 | `movement/harpoon.gd` (72) |
| 4 | `combat/rivet_kit.gd` (1,718) and the other pilots' kit files |
| 5 | `combat/actives/*.gd` (1,715), `combat/ultimate.gd` (1,143) |
| 10 | `build/shop.gd`, `build/fabricators.gd`, `ui/shop_counter.gd`, `ui/shop_tile.gd`, `ui/workshop.gd` (2,187) |
| 12 | `build/panels.gd`, `build/panel_shell.gd`, `ui/panel_drawer.gd` (590) |
| 13 | `build/parts.gd`, `part_def.gd`, `items.gd`, `item_gen.gd`, `item_effects.gd`, `reward_gates.gd` (3,224) |
| 14 | `build/relics.gd`, `combat/reactor_relic.gd` (463) |
| 15 | `build/hotwire_rules.gd`, `ui/hotwire_choice.gd`, `ui/hotwire_screen.gd` (421) |
| 16 | `build/maker_sets.gd`, `build/maker_bonuses.gd` (475) |
| 17 | `build/synergies.gd` (239) |
| 18 | `build/part_sets.gd` (162) |
| 19 | `core/upgrade_tree.gd`, `core/trees/*.gd`, `ui/tree_card.gd`, `ui/tree_crumb.gd`, `ui/tree_pick.gd` (1,961) |
| 20 | `core/start_picks.gd`, `ui/start_pick_card.gd` (685) |
| 21 | `world/trade_pockets.gd`, `world/stake_devices.gd` (474) |
| 23 | `core/companion.gd`, `presentation/companion_body.gd`, `ui/companion_panel.gd` (1,540) |
| 24 | `core/devices.gd`, `world/device.gd` (385) |
| 25 | `build/elements.gd`, `build/element_field.gd` (751) |
| 26 | `core/run_tier.gd` (146) |
| 28 | `world/camp_*.gd`, `ui/camp_*.gd`, `core/camp_lines.gd` (3,071) |
| 30 | `core/achievements.gd`, `ui/achievements_page.gd` (644) |
| 31 | `core/meta_options.gd`, `ui/meta_page.gd` (243) |
