# World-one economy

Proposal, 2026-09-28. Static inspection at `f86f24a75cf9357f12b98d2de61548e93d5e1c65`; no playtest performed. Paths are relative to `sketches/core-loop/`. Every design quantity marked `*` is a playtest starting value, including totals and guarantees; citation numbers identify evidence.

## Keep scrap and cogs; merge cores into cogs

Scrap asks, "Can I take that line and keep my size?" Cogs ask, "Which missing piece should I buy?" Scrap cannot buy anything or become cogs. Cogs never add mass, spill, wear or get stolen with armour. Both reset on a fresh run.

The audit rejected the wallet before Andrew ruled that cogs buy dependable build control (`design-v3/research/PURPOSE-AUDIT-1.md:72-82,556-557`; `design-v3/ROADMAP.md:160-174`). Free loot supplies growth; money corrects its direction.

| Core option | Reason |
|---|---|
| Keep | A non-fungible prize can make optional danger improve the coming reward without competing with shop spending. Today cores raise gate rarity and reset on stage entry (`src/core/run_state.gd:224-240,387-390`; `src/build/build.gd:619-623`; `src/build/parts.gd:259-266`). |
| Merge, recommended | Pay optional danger in cogs, so its reward can fix the player's actual build. The existing core reward improves random gate quality; it does not buy a distinct action. Its all-in wager also overlaps a cog wager (`src/world/bet_crate.gd:94-103`). |
| Cut without replacement | Removes a reward layer, but weakens the reason to detour. Vaults and milestones already grant parts alongside the core paths (`src/build/build.gd:604-609,634-638`; `src/world/world.gd:381`). |

Remove bonus-core accounting and its gate-rarity ladder. Gate picks stay free, with progress-based rarity and pity. Replace event, vault and ambush cores with cog jackpots; their direct parts count against the free-loot budget. Equipment named "Core" stays.

## Sources, sinks and buying power

Proposed rules below. A staple costs **40 cogs***. Fix prices per world, removing held-part inflation and replacing random staples (`src/build/fabricators.gd:38-41`; `src/build/shop.gd:412-417`).

| Resource / source | Yield and boundary |
|---|---|
| Scrap | Authored routes, enemy remains, discovery, scrap-producing parts and events supply mass only. Recovery and theft returns restore mass only; they mint no money or fresh-pickup bonuses. Retain the durability supply for the first comparison, then tune against wear and damage. |
| Cogs: ordinary combat | **2-4*** per eligible kill, scattered as individual gears; tougher enemies spend the encounter's larger allocation. No bonus for taking damage or recollecting scrap. |
| Cogs: crates and breakables | **6-10*** per authored cache, burst along the outgoing line. Each has a consumed identity; respawned scenery and repeated bay toys pay nothing. |
| Cogs: optional danger | **30*** per event, vault or ambush replacing a core award. Distinct completions pay once; a repeated lap or respawn does not reset a cleared source. |
| Cogs: recycling | Common **10***, uncommon **20***, rare **30***, hot-wired **60***. Rejecting a whole earned pick pays once; unchosen alternatives pay nothing. Recycling removes the offered or owned part. Purchased parts refund at most half their actual paid price, including discounts. |
| Free build growth | Earned picks, direct part drops and kit progression remain free. No fee to claim a pity offer. Brindle's defeat payout belongs to the next leg, never the budget for beating him. |

| Sink | Starting price / terms |
|---|---|
| Moss staples | **40*** each. Fixed world shelf: damage, mobility and collection staples, each available once per world. No heft lock on essential correction. Leaving and re-entering cannot restock it. |
| Fabricator hoop | Exact visible part: common **40***, uncommon **60***, rare **100***. Roll through to buy; each authored offer sells once. Buying and recycling cannot profit. |
| Moss specialty / charge cell | Specialty **100***; charge capacity **60***, then **100*** for another in that slot. Optional luxuries; essential correction stays on the staple shelf. |
| Reroll a pick | **10***, then **20***, at most **2*** per earned pick. Never reroll the staple shelf. Replaced offers earn no recycling refund. |
| Hold a pick | **10*** reserves that earned choice through world end in **1*** holding slot. Redeeming costs nothing; holding creates no extra pick. At world exit, unresolved held loot recycles once. |
| Steer next pick | **20*** guarantees an eligible option with the selected tag on the next earned pick. Other options remain random. Show only tags supported by the world pool; refund if no valid candidate exists. |
| Small wager | Optional stake **10***, equal chance of losing it or receiving **20*** total, once per world. Never all-in; unnecessary for the target budgets. |
| Scrap loss | Armour damage, unrecovered spills, theft and rolling wear. No shopping sink. Hull repair remains outside this currency design. |

Discovery and bonus-scrap effects stay mass-only (`src/core/flow.gd:282-288`; `src/build/item_effects.gd:387-390`). Split `add_scrap`, which still raises both wallet and mass (`src/core/run_state.gd:133-140`).

| Before entering Brindle | Combat | Crates | Optional danger | Recycling | Total and affordable basket |
|---|---:|---:|---:|---:|---|
| Clean: catches streams, takes a detour | **100*** | **40*** | **30*** | **10*** | **180***: staple **40*** + uncommon hoop **60*** + another staple **40*** + steer **20*** + hold **10***; **10*** remains. |
| Messy: misses streams, skips detour, rejects more loot | **60*** | **20*** | **0*** | **20*** | **100***: staple **40*** + common hoop **40*** + steer **20***. Alternatively save **60*** after the staple for a cell. |

These are income targets, not measured yields. The main route alone must fund a staple. Keep useful magnet reach at minimum size to prevent a poverty spiral; reach currently grows with heft and speed (`src/build/scrap_field.gd:128-139`). No idle income, cache farming or loans.

Seed pools by run and world; checkpoint offers, pity, stock and consumed rewards. Raise each tag's weight after misses; force the chosen build tag by the **3rd*** missed earned pick, rotating other overdue tags. Exclude capped/unusable parts. Reset on appearance; paid rerolls cannot advance or erase pity. Existing rarity, synergy and repeat weighting does not supply this tag floor (`src/build/parts.gd:293-339`).

## Different at a glance, by ear, under the hand

- Look: small brass gears with clear holes stream into the cog counter; irregular chunky scrap plates visibly join the hull. Reuse the shop's cog price mark (`src/ui/shop_tile.gd:139-144`), not the scrap silhouette.
- Sound: cogs play a short ascending pitched clink run, grouped during dense collection; scrap lands with a low crunch and bolt snap. Reserve the larger growth cue for a heft change.
- Feel: cogs arrive in a quick magnet ribbon and change purchasing power only; scrap adds visible bulk and recoverable protection. A purchase ticks the counter down without shrinking the ball.

## Smallest slice to feel it

Propose `--economy=cogs` alongside `--scrap=armor --wear=on`, default off. A fixed route contains separate scrap and cog streams, an enemy cog burst, a known Moss staple, a priced hoop and a take-or-recycle offer. Use **3 minutes*** for the first comparison. No full economy implementation is authorized by this page.

Preserve mitigation → armour → hull, mass-only recovery and grounded wear outside the shop (`src/core/run_state.gd:290-336`; `src/build/build.gd:728-740`). Brindle's arena currently destroys spills without recovery (`src/build/build.gd:711-721`; `DESIGN-NOTES.md:1115-1122`); budget for that limitation.

| Proposed slice ownership, paths relative to `src/` unless noted | Responsibility |
|---|---|
| `movement/tuning.gd`, `core/run_state.gd`, `core/game_events.gd`, `core/run_log.gd` | Flag, separate cog mutations and facts, checkpoint/restore, source/sink ledger and summary. Damage, theft, wear and recovery cannot mutate cogs. |
| `build/build.gd`, `build/scrap_field.gd`, new `build/cog_field.gd` | Split acquisition, share magnet behavior, preserve scrap-only effects, add bounded cog bursts and one recycle transaction. |
| `build/shop.gd`, `build/fabricators.gd`, `build/parts.gd` | Fixed staple and hoop prices, consumed stock, fixture pool and minimal chosen-tag pity. Disable other paid services in this slice. |
| `ui/hud.gd`, `ui/shop_tile.gd`, `ui/shop_counter.gd`, `ui/workshop.gd`, `presentation/audio.gd` | Separate readouts and cues, cog price wording, clear take/recycle choice. |
| New `tests/economy_test.gd` and fixture under `tests/` | Prove accounting, no double collection, no recycling profit, retry restoration, pity and flag-off behavior. |

Use a route without core-awarding events or bets for this first slice; leave full core migration, hold/steer/reroll UI, charge cells, hot-wired content, world-wide loot placement and final reward cadence out. Moss's bay already banks entry speed and restores an exit speed floor (`src/world/bay.gd:273-284,299-307`); use it without changing its geometry or movement.

Andrew compares flag off/on on the same route, then repeats with deliberate hits and missed pickups. He names what pickup, damage and spending changed; chooses hoop-now versus shelf-later; recycles; and recovers a spill. Log income/spending, missed value, purchase timing, mass, hull loss and reversing. Pass: resources read without explanation, spending changes a decision, and messy play still funds the staple. If money feels pointless, improve the correction it buys. Only a subsequent full Brindle run validates the budget.

## What waits for the lab sitting

Drop versus laps settles pick cadence, world length, repeated-route rewards, bay access, total supply, rare-gate progression and hold timing. Retune prices and Brindle baskets together afterward.

Specify the split, core merge, sensory language, staple pricing, anti-farming rules, checkpoints and offer-count pity now. Implementation follows the lab sitting (`design-v3/ROADMAP.md:174`). Next: use Andrew's loop verdict to set earned picks and purchase opportunities, then tune this budget.
