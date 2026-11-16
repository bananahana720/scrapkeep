# Wave state: the live board, the open wave and carried reds

Heads and open pull requests change by the hour, so read them live (`git ls-remote origin`, the open pull requests, the board's latest comments). This page keeps what a head listing cannot show. The table below is the one place in the repo that names the live board; every other page points here. `npm run check:docs` compares the table with git history and fails when a promotion has landed that the table does not record. The order of what is left is [ROADMAP.md](ROADMAP.md).

## Wave facts

| Fact | Value |
| --- | --- |
| Last promotion | wave 41, main 3996f591, #1043 |
| Open stage | stage/alpha-w42 |
| Live board | #1044 |
| Red team | first-timer |
| Compare against | gate/w41-e2770d85/ |

The board is the GitHub issue in the table. It also holds the file fences of the open pull requests. The stage log (`git log --first-parent origin/stage/alpha-w<N>`) is the stack queue. "Compare against" names the receipts the next full gate reads its base values from, published on a `scratch/gate-receipts-<folder>` branch. The Gate updates the table as its first commit on a new stage: `node scripts/wave-state.mjs --write --board <new board issue> --compare <receipts folder>` (the red team persona rotates by itself).

## Now (16 Nov 2026, wave 42 closing)

**Wave 42 closes on what it has (16 Nov).** The coordinator session on the PC hit a usage limit at 10:22Z and was picked up by a new local session at 10:35Z; the PC rebooted between them. Wave 42's remaining rows move to wave 43 (Andrew accepted the reorder at 09:30Z), and ruling dz moves the whole-run film to the release, so the wave closes on its records, the wave gate and the promotion. Landed after PR 1070: hit words (PR 1063, its Brindle test made load-proof), Brindle's eject ground mark (PR 1071, W1-107) and the radio names (PR 1072, PF-51). In review: sound twins with the UA-07 list (W1-108). Moved to wave 43: the sitting launch's played run (one of six loops fired; it would add a red test) and PF-55, a Continue after a quit in Brindle's victory beat that fights him again (replayed on seed 2883; `break_run.gd` flags it as `won_boss_refought`, PR 1073). Five fixed findings read "open until the release film" (PF-06, PF-16, PF-22, PF-26, PF-50).

### Earlier (15 Nov 2026, resumed on the PC)

**Resumed 15 Nov 02:30Z.** One local Claude Code session on Andrew's PC is coordinator and Gate (ruling ds); the claude.ai project threads stay stopped and this session finishes their open pull requests. The plan Andrew approved runs five waves. Wave 41 settles the queue below and adds the rows that decide "world 1 done" to `npm run sketch:world1-bands -- --sitting` (ruling dt). Wave 42 is clarity: warnings, the HUD and the camera. Wave 43 is sound, difficulty and frame time. Wave 44 is map sites and bodies. Wave 45 is the sitting build. The pause of 14 Nov 18:30Z is over. Wave 40 is on `main` (8d92764c, pull request 1011). `stage/alpha-w41` is open; read its head with `git log --first-parent origin/stage/alpha-w41`.

**Wave 41 is on main** (3996f591, PR 1043, 15 Nov). Its stack queue is `git log --first-parent 8d92764c..7b232972`. The wave gate ran on e2770d85 and was red on four tests with no ledger row; the close commit 7b232972 settled them and each was rerun alone on that head: ambient_view_test (a critter call still playing at quit; the test now waits for the sound to release), run_tier_test (20 schedule fingerprints re-recorded after PR 957 and PR 1033 moved park rows; whole-run fingerprints unchanged), posture_bands_flume_test (pins back to main's 26.5 / 18.5 / 18.5 s; the PC reads 25.1 / 17.6 s) and park_reactor_fight_test (ledger row due 22 Nov: seed 13 at 61.9 s against a 53.7 s test allowance, a 24-seed read decides). Receipts: the board issue of wave 41, #1012.

The wave gate is faster from wave 42: the scoped bot shard runs two bot lanes with the six wall-clock or machine-filling bot tests alone afterwards, and a red that fails a check alone with no flake row gets one solo rerun ([GATE.md](GATE.md)). Wave 41 took 3 h 40 min; record the wave 42 time on the board. A gate that ends red is closed the way waves 40 and 41 were: one close commit, then the named tests alone on the close head.

Carried into wave 42:
1. **PR 948** (critique rows W1-63/77, W1-65 and W1-67, 12aba88a): held, and being landed row by row. Learner rung 1, 72 seeds, on the wave 42 stage (8d503975: 47 clears, 10 deaths, 15 time caps): W1-63/77 alone is identical run for run and is stacked as PR 1046; W1-65 alone reads 49 clears, 5 deaths, 18 caps, not shown equal or harder, so it waits for more seeds. Neither explains the whole pull request's 40 to 50 clears of 14 Nov, which leaves W1-67: its commit also lets the dam sheet open one of two lanes, so it is read alone next. W1-66 opens as its own pull request after that. The plain stage itself moved from 40 clears and 17 deaths (7ab5aee0, 14 Nov) to 47 and 10 (8d503975); wave 43's difficulty pass reads whether wave 41's yard work made the dam easier.
2. **park_reactor_fight_test**: the 24-seed clamp-open-to-break read against the 35.7 s median (DECISIONS, ruling ai). A risen median goes to Andrew beside the 73.1 s small reactor band; otherwise swap the seed.
3. **The yard camera lift (PR 1032)** may move where shots start from in every shut yard, because the aim origin follows the camera arm. One control run with the lift off confirms or clears it; if confirmed it is a design question for the camera owner.
4. **PF-48 and PF-49**: replay the run that stalled at the flume exit and the Brindle fight that ran 420 s. Also replay posture_bands_reactor_test small seed 2, which did not break the reactor in 120 s.
5. **PF-16, PF-22 and PF-26** keep their rows until the PC film read of the dam and flume gate scenes, the lunge and charge looks and Brindle's words.
6. **The ledger**: most rows fall due 23 to 24 Nov; fix or re-date each with a fresh reading. bot_fairness_test still owes its redesign.

For Andrew at the sitting, as assumptions he can overturn: the small-build reactor break is 73.1 s against the 45 to 70 s ordinary-pilot ruling (ruling cu is the newer one); the flume Warden fight is about 5 percent shorter than on wave 40; the dam kicker sits at (0, 476). Owed look follow-ups: the flume trough culls its legs at 120 m and shows as a slab; bowl approach look notes (gantry leg crowding the camera, plain weighbridge plate, small camp tally post, survey post contrast); the Tripo hooker barrel reads a little like a small robot at 22 m.

Follow-ups from the three clarity fixes, for wave 42: hostile-warning rectangles keep a near-plane artefact and hold back most hit words; Brindle's magnets, sockets and caps are avoided by placeholder shapes; a mark made by the hit itself is drawn after the word; a word's stamp-in overshoot is not counted; no test pins the safe-area rule on the new word spots. Warnings: the swarm dive, the rogue crane sweep and haul, the landing crack ring timing, escape precedence and a sideways-shoved chaser are not yet held to the body-arrival rule, and the near-miss award timing (0.25 s) is an owner call. Gate names: 5 to 7 percent of visible gates at opening spacing get no sign (an icon-only level would close it), and the steered gate can lose its sign at 1280x720.

Every band read and bot run must start from a worktree prepared with `node scripts/import-stamp.mjs import`; never copy a `.godot` between worktrees (LESSONS 71).

Done for the sitting is one read: `npm run sketch:world1-bands -- --sitting --head <sha>` prints READY ([GATE.md](GATE.md), "The world 1 done read"; ruling dt). Its gate rows cover all 11 areas: no blocker, major or minor world 1 row left in [PLAY-FINDINGS.tsv](PLAY-FINDINGS.tsv) and no undecided `check` row, a clean release gate, 4080 frames in budget, zero placeholders, the difficulty targets of ruling cu, and that build installed on the PC. Each row that reads a receipt names a planted fault its check must catch. What only Andrew can judge is listed beside them and is never counted as passed. The first read, on 15 Nov, is NOT READY on 31 gate rows. Andrew has played only the dam (wave 26 build, 30 Oct) and has marked no area yet.

**After each promotion,** in this order: (1) the Gate cuts the next stage at the new main, opens its board and runs `node scripts/wave-state.mjs --write` as above, so the first pull request on the new stage passes `check:docs`; (2) the deep-modules sweep runs on the promoted main ([DEEP-SWEEP.md](DEEP-SWEEP.md)) and never holds a promotion; (3) the merged-branch list goes to Andrew's PC prune script (the cloud proxy refuses `git push --delete`). Past promotions: `git log --first-parent origin/main`.

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

[ROADMAP.md](ROADMAP.md) lists what is parked and what is ruled to be re-read after the sitting. PC capture rules are in [DEVICES.md](DEVICES.md). The promotion flow and its gates are in [ORCHESTRATOR.md](../../ORCHESTRATOR.md), the tiered gate's only owner.
