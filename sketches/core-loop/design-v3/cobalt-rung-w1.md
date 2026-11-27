# Cobalt rung, world 1 (wave 20 plan)

Sources: the historical item ladder design page (shared folder outside this repo: `/mnt/project-files/design/item-ladder.html`, wave 20 scope: one rung table replacing `RARITY`, items mapped onto the rungs, cobalt guaranteed from every Warden, boss and won event and one shop slot), DECISIONS rows 171, 190 and 191, and pilot call (d). Wave 20 reused existing items, with no new models.

## What the code does today (stage 55a8cd96)

- **Rarity table.** `item_gen.gd` `RARITY` has four ids:
  - common: sandstone, weight 87
  - rare: amber, 10
  - relic: mint ARC, 3
  - evolved: 0
- **Duplicate colour maps.** `fabricators.gd`, `accretion.gd` and `shop_tile.gd` each repeat their own copy of the rarity colours.
- **The world 1 pool.** `AlphaDefs.PARTS` plus Spare Frame resolves to about 40 common, 4 rare (Sunforged Core, Gatling Heart, Load Dividend, Spare Cell) and 1 relic (Spare Frame).
- **Reward sources:**
  - Warden reward gates roll by cores: 0 cores common; 1 common or rare; 2 rare or relic.
  - Brindle pays a fixed Admiral's Crest.
  - Park activities pay common/rare, and the rim and bend caches pay rare.
  - Shop: 3 shelf slots common/rare, plus a top slot that is relic (the Spare Frame hook).
  - Kills drop grey panels only.
- **No guarantee exists today.**
- **No `Palette.COBALT` exists.** The ruled cobalt is `#3d8bff`, the retired ANCIENT value.

## The rung table (PR 1, look only, no RNG change)

The table keeps the four ids, so no save, digest or row key changes meaning. Each rung gets a colour, a stamp, a frame, a sound and a light column, read from one place:

| Id | Rung | Colour | Stamp | Sound (ladder page) |
| --- | --- | --- | --- | --- |
| (panels) | grey | worn bone and steel | — | ratchet tick (as now) |
| common | green, field kit | field mint | FIELD KIT | two-note chirp (`rarity_tick`, as now) |
| rare | **cobalt, fleet grade** | `#3d8bff` | FLEET GRADE | `rarity_bell`, with `rung_coil` (a coil whine and click) under it on every cobalt find |
| relic | gold | amber with a mint heart | RELIC | four-note horn sting |
| evolved | (unchanged) | ancient | EVOLVED | as now |

- `fabricators.gd`, `accretion.gd` and `shop_tile.gd` read this table instead of their copies.
- Frame shapes stay, so colour never carries the rung alone (VISUAL-LANGUAGE §5).
- A cobalt part on the ball gets a cobalt trim ring on its accretion piece. That is the "cobalt part hangs on the shell" line, without new models.
- Bot runs stay byte-identical; only colours and sounds change.

## Cobalt in world 1 (PRs 2 and 3, change the rolls)

- **The pool (card A).** The guarantees below pay about 4 to 5 cobalt in a world 1 run, and a picked item leaves the pool. Four cobalt rows would run dry by Brindle.
- **The guarantees:**
  - **Wardens (card B):** one of the two reward gates is always cobalt or better; cores still lift the other.
  - **Brindle:** the Crest stays. At wave 20 (World 1 sitting only), the post-Brindle cobalt pick was parked; under ruling `ep` (`FULL_ALPHA := true`, Worlds 2 and 3 unparked), continuing runs enter World 2 after Brindle (seed on #512).
  - **Shop:** shelf slot 1 has a cobalt floor; the Spare Frame top hook stays.
  - **Won events (card C):** the park has no timed events, so this row has nothing to guarantee in world 1 today.
- **World cap.** Ordinary kills never drop cobalt in world 1, per row 190: world 1 is grey and green, and world 2 adds cobalt.
- **Bot impact.** Gate and shop rolls move `ctx.rng` and the shop rng, so these PRs re-baseline bot streams. The receipts compare distributions (ruling aj style). `run_tier` re-pins one commit per stage (ruling j).

## IL-01 re-fit and the 3.8 row (PR 4)

- World 1 now drops about 3.8 panels a stage, against the ruled 2.5 to 3. The fix is a re-fit of `Panels.DROP_BY_WORLD[1]` to the ruled panel counts on re-recorded world 1 kill streams; no new ruling is needed (row 191).
- It lands after the rung, because the cobalt picks change the builds the streams come from.

## References

- **Hades:** boon rarity shows on the door before you choose, and pricier sources raise the odds. Here the gate topper and the cobalt frame show the rung before the pick.
- **Risk of Rain 2:** boss kills pay a tier up, and Shrine of the Mountain pays more of the same. Here the Warden and Brindle floors pay cobalt.
- **Isaac:** a picked item leaves the pool. Hence card A: the guarantees need enough cobalt rows to stay new.

## Rejected options

- **Renaming the ids** (common to field_kit, and so on). It churns 15 or more tests, golden digests and saves for no player-visible gain. The table keeps the ids and changes what they show.
- **Cobalt from ordinary world 1 kills.** It breaks the world-tier reading in row 190.
- **New projectile and rope restyles** (Mass-Driver Coil and the rest). These are after-alpha content with look hooks; wave 20 reuses today's items.
- **A per-build adaptive floor** (a better pick when the build is weak). It breaks "your build never changes the schedule", and the matchup lean already covers weak builds.

## Where it landed (27 Oct)

- PR 1 rung colours: #525. PR 1b stamps (FIELD KIT, FLEET GRADE, RELIC) and this note: this PR.
- PR 2 pool: #529, Andrew's revised card A option 1 (Impact Driver promoted at tier 2; Horizon Optic, Ram Plow, Rime Rounds, Galvanic Rounds listed; 4 to 9 cobalt rows). The first option, promoting six kit commons, failed the pattern guarantee, the evolution-ingredient pools and Kest's kit share.
- PR 3 floors: #536 (every Warden pair and shop slot 1 hold a cobalt; cards B and C on their defaults).
- Finish (wave 24): the find card wears the rung stamp, so a first cobalt find reads NEW FLEET GRADE instead of a bare NEW, and every cobalt find plays `rung_coil` under its bell (`EventKinds.REWARD_RUNG_CUES`). Test: `tests/cobalt_rung_voice_test.gd`. Still owed: the three colour copies reading the table, and the cobalt trim ring on the ball.
- IL-01: #535. World 1 panels are ruled per run (DROP_BY_WORLD[1] stays 32% + 6%); the under-three-a-stage bar reads the later worlds' row.
