# Wave state: the live board, holds and carried reds (9 Nov 2026)

Heads and open PRs change by the hour, so read them live (`git ls-remote origin`, the GitHub MCP tools for open PRs). This page keeps what a head listing cannot show. The table below is the one place in the repo that names the live board; every other page points here. `npm run check:docs` compares the table with git history and fails when a promotion has landed that the table does not record, so it cannot go stale silently. The roadmap is [ROADMAP.md](ROADMAP.md). Rewritten 2026-11-09 by the workflows pass; older versions are in git history.

## Wave facts

| Fact | Value |
| --- | --- |
| Last promotion | wave 36, main 47c79b49, #750 |
| Open stage | stage/alpha-w37 |
| Live board | #749 |
| Red team | first-timer |
| Compare against | gate/w36-fe7c68a0/ |

The board is the GitHub issue in the table; the stage log (`git log origin/stage/alpha-w<N>`) is the stack queue. "Compare against" is the receipts folder the next full gate reads its base values from, under `~/scratch/` on the PC (under `/mnt/project-files/` while the project ran the gate). The Gate updates the table as its first commit on a new stage: `node scripts/wave-state.mjs --write --board <new board issue> --compare <receipts folder>` (the red team persona rotates by itself).

**Priority (Andrew, 23 Oct 19:31Z).** World 1 first: a finished Spillway (dam, flume, Brindle, with the camp and title lead-in) and early progression, played at a world 1 sitting (10-15 min average run, about 30 min completionist, repeatable). Worlds 2 and 3 start nothing new (ruling at).

**Now (11 Nov).** Wave 36 is on `main` (47c79b49, #750): CLEAN on fe7c68a0 on the first wave gate (ruling cy), with bands B, bands C and the red team deferred to the release gate. Two receipt folders matter on the PC. `~/scratch/gate/w36-fe7c68a0/` (branch `scratch/gate-receipts-w36-fe7c68a0`) holds the tests, the bot blocks and bands A, and is the base for the wave 37 gate. `~/scratch/gate/w36-f165fbb4/` holds this sprint's last full read of bands B, bands C and the red team, and is the band base for the release gate. Wave 37 is open: one ride and the bugs, with polish in wave 38. The difficulty stack is built and parked on `claude/w37-difficulty` and lands last in the sprint, before the release gate. The local session on the PC is coordinator and Gate, and Andrew ruled the sitting waits for world 1 fully polished (ruling cs). For a session that is not on the PC: the coordinator's log, briefs and helper scripts are on branch `scratch/coordinator-notes-2026-11-11`, the wave gate's receipts on `scratch/gate-receipts-w36-fe7c68a0`, and the last full read of bands B, bands C and the red team on `scratch/gate-receipts-w36-f165fbb4`. Three built units wait as draft pull requests on `stage/alpha-w37` (the swipe over both launches, the film tool, and the launch that lands where it aimed); the hand-off comment on the wave board gives the order.

**The world 1 polish program (ruling cs).** On 10 Nov Andrew added three directions: a map standard with a fast check for each point (ruling ct), harder and never easier (ruling cu), and one ride through a world (ruling cv). The program is five more waves, each with its own board and promotion: wave 35, words and first checks (kit pick cards, the run summary, item words, key prompts, the sound contract checks, three map checks and the PC gate command); wave 36, read the fight and build the instruments (danger marks, the HUD, the landmark beam, a snag sweep, the difficulty measurement, the hand-over test, the capture tools and a behaviour-preserving split of the Warden form out of `audio.gd`); wave 37, harder by movement (chasers that catch a stopped ball, the Warden pulse, regen only while rolling, terrain as cover, and the conductor link default off); wave 38, one ride (both stage cuts covered, heading carried, the Slag Bowl ahead of the flume launch, markers and breathers); wave 39, the sitting build (the Warden form on the synth band and on Brindle, the final gate and the install). The audits behind it are in [shared/world1/](shared/world1/). Done is counted: no major or minor row left in [PLAY-FINDINGS.tsv](PLAY-FINDINGS.tsv), a clean gate with a fresh weekly sweep, 4080 frames in budget, zero placeholders, and that build installed.

**World 1 sitting.** Andrew played the dam on the wave 26 build on 30 Oct: fun, many invisible walls, models clipping. Every fix shipped in wave 29. He has not marked any area yet. The PC has the wave 32 build installed (main 8180ec6c, 9 Nov; boss smokes PASS; cold launch to menu 4386 ms, 0 errors); the wave 33 build (main 45691e94) is next to install, with wave 32 as its rollback. The sitting sheet is refreshed for the build he plays, once that build is promoted.

**Promotions since wave 18.** w19 a4c5b963 (#511), w20 46245f69 (#555), w21 421c8244 (#562), w22 1a0516d1 (#567), w23 462ca7ef (#570), w24 65d34cdb (#580), w25 dc1da31a (#582), w26 83f02396 (#585), w27 a7151583 (#594), w28 1e172aee (#598), w29 556cca8e (#606), w30 98727408 (#614), w31 645893f3 (#626), w32 8180ec6c (#632), w33 45691e94 (#737), w34 bc4adc1a (#745), w35 1b5221c0 (#747), w36 47c79b49 (#750). `git log --first-parent origin/main` is the source; this line is a convenience.

**After each promotion.** In this order: (1) the Gate cuts the next stage at the new main, opens its board and runs `node scripts/wave-state.mjs --write` as above, so the first PR on the new stage passes `check:docs`; (2) the deep-modules sweep runs on the promoted main ([DEEP-SWEEP.md](DEEP-SWEEP.md)); it never holds a promotion; (3) Andrew runs the PC branch-prune script from the prepared list (the cloud proxy refuses `git push --delete`).

## Carried reds

A promotion carries a red test only while that test has a row in [KNOWN-FAILING.tsv](KNOWN-FAILING.tsv) with a cause, an owner and a review date (ruling bq). The ledger replaced the list that used to live here; [GATE.md](GATE.md) says how a row is added, read and removed. In short:

- A fail needs a solo rerun before it counts, and a "base" red must also be red on the bare head or on main (LESSONS 51-52). No bisect for a carried red (ruling d).
- A red with no row is new. A new deterministic red blocks, and its fix lane is the PR's owner (ruling ai).
- A row past its review date holds the next promotion until the test is fixed or the coordinator re-dates the row.
- skill_band's hull order is a report (ruling bi), not a red.

Two things a test ledger cannot hold:

- Open play findings (what a player would feel) have one list with owners and review dates, [PLAY-FINDINGS.tsv](PLAY-FINDINGS.tsv) (ruling cn); they never hold a promotion.
- Base-same play issues, tracked on the live board: a miniboss presses the ball under the dam Warden yard in staked runs (main 4 of 6); the Brindle charge fling shows in 4 of 18 speedrunner runs.
- Oggs-present vs Oggs-absent base: the packed music Oggs are gitignored, so cloud boxes play the synth engine while a PC with synced Oggs plays ACE. Compare a head and its base with the same Ogg state, and name it in the receipt (23 Oct, #411).

## Parked until after the sitting

- Perf: sinkhole Dispatcher 265-277 ms; EventFamilies.build 69 ms at stage 5; Dig pit beacon bursts; Jolt shape build on the main thread. Dig and world 2 perf is out of scope (ruling at). Dam perf left: f4045 riser, Warden break and engage remainders, seed 3 f14k swing, the over-16 engage spike (a real game spike; its old watch issue is closed, so post perf receipts on the live board).
- Brindle cobalt pick (ruling ap); flume length levers (ruling ax); HARD rung 5 re-read (rulings aq, bc, be); w1 Novice ceiling re-read (ruling bk).

## PC capture rules

- Frame-time captures run only on an idle 4080 (device 0) through headless gamescope; the 3060 takes throughput work. A capture is void if Andrew plays or another process touches the card during it. Run the stems sync first. Power caps: 4080 280 W, 3060 140 W (#446).
- The live wallpaper pauses only for a process named exactly `godot`, so launch captures through a `godot` link and count `mpvpaper` as foreign (#446).
- Cloud perf numbers never count, and the cloud ratio differs by kind of work (LESSONS 55-58).

## Promote-fast flow

The flow and its gates are in [ORCHESTRATOR.md](../../ORCHESTRATOR.md) (the tiered gate is its only owner); the per-PR test pace is in [DECISIONS.md](DECISIONS.md) section 10.
