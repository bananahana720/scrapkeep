# Gate plan: wave 34, head 75099fa7

Run on the PC "ahana" (32 threads) on 10 Nov 2026 by the local coordinator session, which is also Gate since the account change. Frozen head `75099fa7080378295788d9741a0a03fdf9e594b2` on `stage/alpha-w34`. Base for the band comparison: main `45691e94` (the wave 33 promotion), rerun on this PC the same day because the wave 33 receipts stayed with the old account. Receipts folder: `/home/andrew/scratch/gate/w34-75099fa7/`, published to `scratch/gate-receipts-w34-75099fa7`.

Check it with `node scripts/gate/tally.mjs --plan <this file>` in a checkout of the gated head.

## Gate-side

| Check | Verdict |
| --- | --- |
| node tests | PASS. `SCRAPKEEP_WHOLE_TESTS=1 npm test` under a scratch data home: 1265 tests, 1263 pass, 0 fail, 2 skipped (inputs not in this repository). Log `logs/w34-node/` |
| base rerun | Bands A, B and all five HARD rungs on main 45691e94, same PC, same Ogg state. Logs `logs/base-bands*/` |
| load note | The PC was oversubscribed for parts of the run (load up to 100 on 32 threads). Every time-out taken then was rerun alone on a quiet machine before its row was called |

## Tally

| Shard | Verdict |
| --- | --- |
| tests 1-350 | PASS, no new red. 350 of 350 on the first run. Receipt tests-1-350/receipt.md |
| tests 351-700 | PASS after a quiet rerun. The shard's own line read RED on two time-outs with no failing check (`music_params_test`, `park_permanent_capacity_test`), taken at load above 60 on 32 threads; each then passed 3 of 3 alone at load under 4 (243 s and 160 s against the 360 s limit). 1 carried on the ledger (`posture_bands_reactor_test`), 1 new load flake to list (`find_in_fight_test`). Receipts tests-351-700/receipt.md, retime/summary.txt |
| tests 701-1049 | PASS, no new red (4 carried on the ledger, 2 new load flakes to list: `presentation_hitstop_test`, `telegraph_timing_pack_test`). Receipt tests-701-1049/receipt.md |
| bots 1 | PASS, no new red. 5 of 5 on the first run. Receipt bots-1/receipt.md |
| bots 2 | PASS, no new red (1 new load flake to list: `bot_park_trace_repeat_test`, failed once under load, passed twice alone). Receipt bots-2/receipt.md |
| bots 3 | PASS, no new red. 5 of 5 on the first run. Receipt bots-3/receipt.md |
| bots 4 | PASS, no new red. 5 of 5 on the first run. Receipt bots-4/receipt.md |
| bots 5 | PASS, no new red. 3 of 3 on the first run. Receipt bots-5/receipt.md |
| bands A | PASS. 7 of 8 tests pass alone; the red is `posture_bands_reactor_test`, carried on the ledger, with its 16 lines identical on main. Every `->` line is identical to main except the first-find word count, 20 HUD words against 19 inside a budget of 25, which is wave 34's key-label change and not a band. Receipt bands-A/ |
| bands B | PASS, identical to main: 96 runs, identical 96, differing 0. Novice 38% (9 of 24), Rusty 75%, Expert 100%. Receipt bands-B/runs.ndjson |
| bands C | PASS, identical to main on all five HARD rungs: 144 runs, differing 0. Expert wins by rung: 100%, 96%, 100%, 88%, 63% (30 of 48). The four tests alone pass. Receipt bands-C/ |
| weekly sweep | PASS 2026-11-10. Weekly tests 72 of 75 on the first run: 2 carried on the ledger (`posture_bands_mind_test`, `waking_fight_test`), 1 new load flake to list (`bot_stub_boss_test`). Weekly bots 9 of 9. Receipts weekly-tests/receipt.md, weekly-bots/receipt.md |
| red team greedy | CLEAR. 0 blocker, 1 major, 2 minor, 3 to watch, run on the PC with 8 slots in 16 min. All six greedy runs won through stage 6; build sweep 0 problems; 0 placeholders. The major is a candidate hitch seen at shared moments in 5 runs that ran side by side; replayed alone it hitched at 0 of 11 moments, with and without the music mix, and the bench alone read p99 12.6 ms, max 31.3 ms. The minors are stuck detours on stage 2 and stage 6 geometry for one pilot and seed (runner_gunner 4479); the stage 2 one gets a play-findings row. Receipt redteam/findings.md |

## For the wave 35 ledger

Seven tests showed load sensitivity on this PC and get a `flake` row in `KNOWN-FAILING.tsv` on wave 35: `find_in_fight_test`, `presentation_hitstop_test`, `telegraph_timing_pack_test`, `bot_park_trace_repeat_test`, `bot_stub_boss_test`, `music_params_test`, `park_permanent_capacity_test`. `park_permanent_capacity_test` takes 243 s alone against a 360 s limit and starts about 20 children.

## Stale numbers this gate corrects

- Novice on the dam Warden reads 38% on both main and the head, not the 42% an older ruling records.
- HARD rung 5 reads 63% on both, not 56%.
