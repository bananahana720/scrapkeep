# Gate plan: wave 35, head 0e258a0e

Written by `scripts/gate/pc.mjs` on 2026-11-11. Base for the band comparison: /home/andrew/scratch/gate/w34-75099fa7. Check it with `node scripts/gate/tally.mjs --plan <this file>`.

## Gate-side

| Check | Verdict |
| --- | --- |
| node tests | PASS. 1292 tests, 0 fail. Receipt node/summary.txt |

## Tally

| Shard | Verdict |
| --- | --- |
| tests 1-352 | PASS, no new red. Receipt tests-1-352/receipt.md |
| tests 353-704 | PASS, no new red (1 carried on the ledger). Receipt tests-353-704/receipt.md |
| tests 705-1055 | RED: 1 new red (ui_workshop_bay_test). Receipt tests-705-1055/receipt.md |
| bots 1 | PASS, no new red. Receipt bots-1/receipt.md |
| bots 2 | PASS, no new red. Receipt bots-2/receipt.md |
| bots 3 | PASS, no new red. Receipt bots-3/receipt.md |
| bots 4 | PASS, no new red. Receipt bots-4/receipt.md |
| bots 5 | RED: 1 new red (world1_run_test). Receipt bots-5/receipt.md |
| bands A | RED: step exited 1. Receipt bands-A/ |
| bands B | PASS, identical to the base. Receipt bands-B/, compare.md |
| bands C | RED: the band moved against the base (bands C smoke run_tier_test: 3826 lines, 2 only in base, 2 only in head; base: [Continue stage 1 interactive visible pre-choice tier disclosure] words ["Long Barrel", "Shoot farther", "Rivet Plating", "Bolt on armour", "Chain Arc", "Chain hits to a neighbour", "Tier", "0", "1", "Crowd", "Hits", "Regen", "Pay", "Threat: 25% more crowd, 20% shorter intervals, plated elite brutes", "Pay: 25% more event cores and rare weight; gain cap 1.5x"] -> PASS \| base: [Continue stage 1 interactive visible pre-choice tier disclosure] words ["Long Barrel", "Shoot farther", "Rivet Plating", "Bolt on armour", "Chain Arc", "Chain hits to a neighbour", "Tier", "0", "1", "Crowd", "Hits", "Regen", "Pay", "Threat: 25% more crowd, 20% shorter intervals, plated elite brutes", "Pay: 25% more event cores and rare weight; gain cap 1.5x"] -> PASS \| head: [Continue stage 1 interactive visible pre-choice tier disclosure] words ["Long Barrel", "Shoot farther", "Rivet Plating", "Raise your max health", "Chain Arc", "Chain hits to a neighbour", "Tier", "0", "1", "Crowd", "Hits", "Regen", "Pay", "Threat: 25% more crowd, 20% shorter intervals, plated elite brutes", "Pay: 25% more event cores and rare weight; gain cap 1.5x"] -> PASS \| head: [Continue stage 1 interactive visible pre-choice tier disclosure] words ["Long Barrel", "Shoot farther", "Rivet Plating", "Raise your max health", "Chain Arc", "Chain hits to a neighbour", "Tier", "0", "1", "Crowd", "Hits", "Regen", "Pay", "Threat: 25% more crowd, 20% shorter intervals, plated elite brutes", "Pay: 25% more event cores and rare weight; gain cap 1.5x"] -> PASS). Receipt bands-C/, compare.md |
| red team line-rider | CLEAR. 0 blockers. Receipt redteam/findings.md |

## Tally, rows read again by the coordinator (stage head c10920e0)

The gated head is 0e258a0e. Two commits sit on top of it, and neither changes a game file: 7cbf2a4e mends one stale test, and c10920e0 adds one ledger row and one play finding. `node scripts/gate/carry.mjs 0e258a0e` on c10920e0 names one test to read again, `ui_workshop_bay_test`; every other row carries.

| Shard | Verdict |
| --- | --- |
| tests 705-1055 | PASS, no new red on c10920e0 (2 carried on the ledger: `trace_readonly_test`, `warden_counter_pulse_test`). `ui_workshop_bay_test` failed a stale check: wave 35 hides Moss's greeting behind a pick card on purpose and the test still wanted it drawn. The tests-only commit 7cbf2a4e mends it and it passes 2 of 2 alone. Receipts tests-705-1055/receipt.md and /home/andrew/scratch/gate/w35-7cbf2a4e/carry/summary.txt |
| bots 5 | PASS, no new red (1 carried on the ledger: `world1_run_test`, row added on c10920e0). It passed 1 of 2 alone. The failing check reads three engine errors when the ball dies in the Brindle arena with a dropped lobber alive; main bc4adc1a fails the same case, so it is not this wave's, and the fix is on `claude/w36-arena-exit` for wave 36. The first run's one caster fall did not repeat in either solo run and is play finding PF-32. Receipt bots-5/receipt.md |
| bands A | PASS, 7 of 8 exit 0 (1 carried on the ledger: `posture_bands_reactor_test`, its check lines identical to the base). Two lines moved and both pass. `ui_word_budget_first_find_test` reads 19 HUD words for 20 (budget 25); its log does not list the words, so the cause is not shown (the wave 34 gate read 20 against 19 on the main before it). `posture_bands_test` read small seed 1 at 64.55 s for 65.78 s (median 66.0 s for 66.7 s); a second run on the same game code reads 65.78 s again, so that one seed of 51 varies between runs and the wave did not move it. Finding for the testing lane: the posture sweep is not fully repeatable on seed 1. Receipts bands-A/ and /home/andrew/scratch/gate/w35-7cbf2a4e/bands-A-recheck/posture_bands_test.log |
| bands C | PASS, 144 rung runs identical to the base and 4 of 4 smoke tests exit 0. One smoke line moved: `run_tier_test` lists the Rivet Plating card's verb, which wave 35 reworded from "Bolt on armour" to "Raise your max health". Receipts bands-C/ and compare.md |
| weekly sweep | PASS 2026-11-10. Carried from the wave 34 gate on 75099fa7, one day old: weekly tests 72 of 75 on the first run (2 carried on the ledger, 1 load flake since listed), weekly bots 9 of 9. Receipts /home/andrew/scratch/gate/w34-75099fa7/weekly-tests/receipt.md and weekly-bots/receipt.md |
