# Wave state: the live board, the open wave and carried reds

Heads and open pull requests change by the hour, so read them live (`git ls-remote origin`, the open pull requests, the board's latest comments). This page keeps what a head listing cannot show. The table below is the one place in the repo that names the live board; every other page points here. `npm run check:docs` compares the table with git history and fails when a promotion has landed that the table does not record. The order of what is left is [ROADMAP.md](ROADMAP.md).

## Wave facts

| Fact | Value |
| --- | --- |
| Last promotion | wave 36, main 47c79b49, #750 |
| Open stage | stage/alpha-w37 |
| Live board | #749 |
| Red team | first-timer |
| Compare against | gate/w36-fe7c68a0/ |

The board is the GitHub issue in the table. It also holds the file fences of the open pull requests. The stage log (`git log --first-parent origin/stage/alpha-w<N>`) is the stack queue. "Compare against" names the receipts the next full gate reads its base values from, published on a `scratch/gate-receipts-<folder>` branch. The Gate updates the table as its first commit on a new stage: `node scripts/wave-state.mjs --write --board <new board issue> --compare <receipts folder>` (the red team persona rotates by itself).

## Now (12 Nov 2026)

Wave 36 is on `main` (47c79b49, pull request 750). Wave 37, "one ride, and the bugs", is open on `stage/alpha-w37` and its wave gate (ruling cy) is running on the PC. The stage carries the ride work (both launches under the swipe, heading carried across a launch), the lift and crate fixes, the systems audit fixes (Continue keeps a cleared stage's earnings), and the loop mechanics Heat, Overtime, Called Shot, marked hull and carry a core. Those mechanics are on in the "Scrapkeep sitting" launch and off for bots and tests (rulings da, dd, df).

The difficulty stack (ruling cu) was stacked, then backed out of wave 37 when the gate found seven new reds in it. Pull request 805 re-lands it for wave 38 by fixing those reds. Wave 38 is polish: play findings, markers, breathers, the Slag Bowl smoke column, and the sitting build's look and sound; its units wait as draft pull requests on `stage/alpha-w37`. The board's latest comments say what is stacked, what is fenced and what the gate has found.

Done for the sitting is counted: no major or minor row left in [PLAY-FINDINGS.tsv](PLAY-FINDINGS.tsv), a clean release gate, 4080 frames in budget, zero placeholders, and that build installed on the PC. Andrew has played only the dam (wave 26 build, 30 Oct) and has marked no area yet.

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
