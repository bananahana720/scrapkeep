# Challenge band table

Run tier 2 (HARD ladder rung 2, bot_run --run-tier): every run picks it on the start card, or takes it as a resumed stage opens. The ✓/✗ marks still judge the base-tier targets.

Label w35-0e258a0e-C-t2, commit 0e258a0e, 2026-11-11T04:09Z.

Learner a1 at bosses and Wardens is information only (DECISIONS section 5, 19 Oct 19:00): no ✓/✗; the old reference range was 15%-35%. Parks still grade Learner a1 reach.

Win rate (runs) [Wilson 95%] ✓/✗ against the target; ✓/✗ judges the point estimate. Brackets after a cell count deaths, fight caps (fight_capped, boss_stalled) and stalls; none is a win. Runs with no record, an unresumed doc or a harness kill are excluded from n and the rate and noted as `excluded`; over 10% excluded makes the column incomplete. Fight s and HP lost are medians over the cell's runs; top/ord is the Expert top fight time over the Expert ordinary fight time.

## Bosses and Wardens

| Cell | Novice | Learner a1 | Learner a5 | Expert ordinary | Expert top | Learner deaths < 45 s | Fight s (ord / top) | HP lost (ord) | top/ord (reported, not graded) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| w1 | - | - | - | 96% (24) [80%-99%] ✓ vs >= 85% (1 capped) | - | - | 57.3 / - | 55.0 | - |

## Fight report (comps study format)

From research/comps/difficulty/SUMMARY.md, Lab measure. Reference rows, which are tuning ranges, not rulings: boss TTK 50-90 s and Warden 90-150 s at an ordinary build (rows 1, 2); an ordinary hit 15-25% of pilot health, a heavy one 30-50%, and no single hit kills from full (rows 9, 10); a Learner loses well under full health in the first 45 s (row 11). Largest hit is the biggest single hit in any band's run, with its source id. Hit and HP-lost shares are the whole hit before scrap armour; the hull columns are what reached the hull after armour (blank for rows recorded before the driver kept them). Tells and recovery come from the attack sheet (`tools/attack_sheet.gd`), not from these runs. Warden rows count from the Warden fight's start.

| Cell | Expert ordinary TTK s | Largest hit, share of HP (source) | Learner a1 HP lost in first 45 s, share (median / max) | Largest hull hit | Learner a1 hull lost in first 45 s (median / max) |
| --- | --- | --- | --- | --- | --- |
| w1 | 57.3 | 45% (silt_boil) | - | 17% | - |

No cell has a ✗.

## What a player would report

The play watch (src/core/play_watch.gd) read 24 of 24 runs. It only reads the game, so the win rates above are what they would be without it. Information, not graded: a wedge, a fall, an empty objective plate or a hull bar off the hull is a bug to chase wherever it shows; a stuck or hung row is read with the bot's goal, since a camper waits by design.

| Kind | Rows | Runs with one |
| --- | --- | --- |
| wedged | 0 | 0 |
| fell | 0 | 0 |
| blank | 0 | 0 |
| bar | 0 | 0 |
| stuck | 1 | 1 |
| hung | 5 | 4 |

| Kind | Stage | Near (x, y, z) | Runs | Rows | Cells | Bot's goal |
| --- | --- | --- | --- | --- | --- | --- |
| stuck | 1 | 130, 0, 480 | 1 | 1 | w1 | roll to spillway sheet |
| hung | 1 | -30, 0, 470 | 2 | 2 | w1 | fight chaser charge; fight lobber charge |
| hung | 1 | 0, 20, 380 | 1 | 1 | w1 | roll to spillway sheet |
| hung | 1 | 20, 0, 460 | 1 | 1 | w1 | fight plated_brute charge |
| hung | 1 | 40, 0, 520 | 1 | 1 | w1 | fight chaser charge |
