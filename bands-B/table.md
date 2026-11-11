# Challenge band table

Label w35-0e258a0e-w1, commit 0e258a0e, 2026-11-11T04:19Z.

Learner a1 at bosses and Wardens is information only (DECISIONS section 5, 19 Oct 19:00): no ✓/✗; the old reference range was 15%-35%. Parks still grade Learner a1 reach.

Win rate (runs) [Wilson 95%] ✓/✗ against the target; ✓/✗ judges the point estimate. Brackets after a cell count deaths, fight caps (fight_capped, boss_stalled) and stalls; none is a win. Runs with no record, an unresumed doc or a harness kill are excluded from n and the rate and noted as `excluded`; over 10% excluded makes the column incomplete. Fight s and HP lost are medians over the cell's runs; top/ord is the Expert top fight time over the Expert ordinary fight time.

## Bosses and Wardens

| Cell | Novice | Learner a1 | Learner a5 | Expert ordinary | Expert top | Learner deaths < 45 s | Fight s (ord / top) | HP lost (ord) | top/ord (reported, not graded) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| w1 | 38% (24) [21%-57%] ✗ vs <= 15% (5 died, 10 capped) | 75% (24) [55%-88%] (6 capped) | 75% (24) [55%-88%] ✓ vs >= 60% (1 died, 5 capped) | 100% (24) [86%-100%] ✓ vs >= 85% | - | - | 69.0 / - | 65.0 | - |

## Fight report (comps study format)

From research/comps/difficulty/SUMMARY.md, Lab measure. Reference rows, which are tuning ranges, not rulings: boss TTK 50-90 s and Warden 90-150 s at an ordinary build (rows 1, 2); an ordinary hit 15-25% of pilot health, a heavy one 30-50%, and no single hit kills from full (rows 9, 10); a Learner loses well under full health in the first 45 s (row 11). Largest hit is the biggest single hit in any band's run, with its source id. Hit and HP-lost shares are the whole hit before scrap armour; the hull columns are what reached the hull after armour (blank for rows recorded before the driver kept them). Tells and recovery come from the attack sheet (`tools/attack_sheet.gd`), not from these runs. Warden rows count from the Warden fight's start.

| Cell | Expert ordinary TTK s | Largest hit, share of HP (source) | Learner a1 HP lost in first 45 s, share (median / max) | Largest hull hit | Learner a1 hull lost in first 45 s (median / max) |
| --- | --- | --- | --- | --- | --- |
| w1 | 69.0 | 38% (silt_boil) | 26% / 150% | 30% | 0% / 30% |

Cells with a ✗: w1.

## What a player would report

The play watch (src/core/play_watch.gd) read 96 of 96 runs. It only reads the game, so the win rates above are what they would be without it. Information, not graded: a wedge, a fall, an empty objective plate or a hull bar off the hull is a bug to chase wherever it shows; a stuck or hung row is read with the bot's goal, since a camper waits by design.

| Kind | Rows | Runs with one |
| --- | --- | --- |
| wedged | 0 | 0 |
| fell | 0 | 0 |
| blank | 0 | 0 |
| bar | 0 | 0 |
| stuck | 37 | 37 |
| hung | 18 | 9 |

| Kind | Stage | Near (x, y, z) | Runs | Rows | Cells | Bot's goal |
| --- | --- | --- | --- | --- | --- | --- |
| stuck | 1 | 0, 0, 570 | 8 | 8 | w1 | ride spillway sheet; wait spillway sheet |
| stuck | 1 | 10, 0, 570 | 7 | 7 | w1 | ride spillway sheet; wait spillway sheet |
| stuck | 1 | -10, 0, 570 | 5 | 5 | w1 | ride spillway sheet; wait spillway sheet |
| stuck | 1 | -10, 0, 610 | 3 | 3 | w1 | ride spillway sheet |
| stuck | 1 | -20, 0, 580 | 2 | 2 | w1 | wait spillway sheet |
| stuck | 1 | -20, 0, 600 | 2 | 2 | w1 | ride spillway sheet |
| stuck | 1 | 130, 0, 480 | 2 | 2 | w1 | roll to spillway sheet |
| stuck | 1 | 20, 0, 570 | 2 | 2 | w1 | ride spillway sheet |
| stuck | 1 | -20, 0, 570 | 1 | 1 | w1 | ride spillway sheet |
| stuck | 1 | -20, 0, 590 | 1 | 1 | w1 | ride spillway sheet |
| stuck | 1 | 0, 0, 610 | 1 | 1 | w1 | wait spillway sheet |
| stuck | 1 | 0, 30, 640 | 1 | 1 | w1 | fight mag_trapper charge climb |
| stuck | 1 | 10, 0, 610 | 1 | 1 | w1 | ride spillway sheet |
| stuck | 1 | 20, 0, 580 | 1 | 1 | w1 | ride spillway sheet |
| hung | 1 | 0, 20, 380 | 9 | 9 | w1 | roll to spillway sheet |
| hung | 1 | 10, 0, 460 | 3 | 3 | w1 | fight plated_brute runup |
| hung | 1 | -20, 0, 520 | 2 | 2 | w1 | fight plated_brute charge |
| hung | 1 | -30, 0, 460 | 1 | 1 | w1 | fight plated_brute charge |
| hung | 1 | -30, 0, 520 | 1 | 1 | w1 | fight plated_brute charge |
| hung | 1 | 20, 0, 450 | 1 | 1 | w1 | fight lobber charge |
| hung | 1 | 60, 0, 460 | 1 | 1 | w1 | roll to spillway sheet |
