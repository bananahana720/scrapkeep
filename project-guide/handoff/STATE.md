# Wave state: the live board, the open wave and carried reds

Heads and open pull requests change by the hour, so read them live (`git ls-remote origin`, the open pull requests, the board's latest comments). This page keeps what a head listing cannot show. The table below is the one place in the repo that names the live board; every other page points here. `npm run check:docs` compares the table with git history and fails when a promotion has landed that the table does not record. The order of what is left is [ROADMAP.md](ROADMAP.md).

## Wave facts

| Fact | Value |
| --- | --- |
| Last promotion | wave 40, main 8d92764c, #1011 |
| Open stage | stage/alpha-w41 |
| Live board | #1012 |
| Red team | speedrunner |
| Compare against | gate/w40-bd5b30f5/ |

The board is the GitHub issue in the table. It also holds the file fences of the open pull requests. The stage log (`git log --first-parent origin/stage/alpha-w<N>`) is the stack queue. "Compare against" names the receipts the next full gate reads its base values from, published on a `scratch/gate-receipts-<folder>` branch. The Gate updates the table as its first commit on a new stage: `node scripts/wave-state.mjs --write --board <new board issue> --compare <receipts folder>` (the red team persona rotates by itself).

## Now (15 Nov 2026, resumed on the PC)

**Resumed 15 Nov 02:30Z.** One local Claude Code session on Andrew's PC is coordinator and Gate (ruling ds); the claude.ai project threads stay stopped and this session finishes their open pull requests. The plan Andrew approved runs five waves. Wave 41 settles the queue below and adds the rows that decide "world 1 done" to `npm run sketch:world1-bands -- --sitting` (ruling dt). Wave 42 is clarity: warnings, the HUD and the camera. Wave 43 is sound, difficulty and frame time. Wave 44 is map sites and bodies. Wave 45 is the sitting build. The pause of 14 Nov 18:30Z is over. Wave 40 is on `main` (8d92764c, pull request 1011). `stage/alpha-w41` is open; read its head with `git log --first-parent origin/stage/alpha-w41`.

Stacked on w41 since the cut: 1007, 1008, 1010, 1013, 923, 886, 1015, 1016 (rulings dn, do and dp; dq came with it), 1014, 1017, 1019, 1020, 1021, 1022, 1009 (survival forms and survey posts behind flags), 1023, 1025 (far props keep their shape), 1024, 1028 (bowl approach behind `--approach`, dam yard row moved), 1026, 1029, 1030, 957 (dam fight bowl), 1032 (shut-yard camera lift), the import stamp (LESSONS 71), 845 (the difficulty stack) and 1036 (docs cleanup). Every PC look and band read for those passed or went back to its thread as a follow-up.

845 passed its PC band read at the base tier and HARD rungs 2 and 5, harder on every arm (receipts on the board issue). One flag for the gate: at rung 2 learner5 clears rose 19 to 22 while its hull lost rose 1248 to 2169, which passes the rule but is worth a look.

Open pull requests on w41 and what each waits on, in stacking order:
1. **948** (critique rows, 12aba88a): 845 is in, so this is next. Its paired band read (w41+845 against w41+948) and the W1-66 read were queued and cancelled at the pause; the PC keeps their worktrees. W1-66 opens as its own pull request after 948.
2. **1027** (same-tick contact order, 3922becb3): fixes the run-to-run split that same-tick contacts caused (its LESSONS 72); its head repeats exactly under load on the PC. Its paired band read was cancelled at the pause; run it, then stack.
3. **1033** (dam apron kicker moved past the shut yard, 2428bea9b): the shut-yard still and the kicker landing pass on the PC (candidate scratch/w41-cand-1033). Its paired band read was cancelled at the pause; run it, then stack.
4. **1031** (Tripo arena props and a sluice shed that keeps its water wheel): stacked on 15 Nov. PC look: the shed's wheel reads as a big red wheel at 40, 110 and 160 m.
5. **1034** (a Tripo chaser that passes the render check, and a hooker barrel with no feet): stacked on 15 Nov. PC look: the hooker passes; the generated chaser is rejected (its body floats off its claws in the wind-up, commit 4148a85a4), so `--models=tripo` shows the authored chaser.
6. **1018** (played launches end at Brindle): stacked on 15 Nov as ruling du (its first letter, dr, was already the Tripo accept-list ruling).
7. **1035** (points of interest look fixes for the PR 1028 stills, and the stocktake_yard_test flake fix, 6efb2aee): stacked on 15 Nov. Stills pass, the flags-off trace pair is identical over 54,720 rows, and the stocktake_yard_test row is off the ledger. Frame time is read in wave 43.

Known w41 reds to settle before the wave gate: posture_bands_reactor's small median (71.5 s against a 60.2 s pin, same on base, so the pin is stale) and bot_park_trace_repeat timing out at 900 s on a 4-core cloud box (unchecked on the PC). stocktake_yard_test flakes on a repeated part draw (fixed in 1035). Owed follow-ups: the flume trough culls its legs at 120 m and shows as a slab (POI thread); bowl approach look notes (gantry leg crowding the camera, plain weighbridge plate, small camp tally post, survey post contrast); the Tripo hooker barrel reads a little like a small robot at 22 m.

The PC kept the cancelled reads ready under its scratch folder w41-pc: worktrees bj-base2, bj-head2 and bk-head2 (948 and W1-66, script bjk2-band.sh), bq-base and bq-head (1027, bq.sh, band part only), bu (the two reds, bu.sh) and bw-base and bw-cand (1033, bw.sh, step 3 only). Check each one's stamp against the current stage before reusing it.

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
