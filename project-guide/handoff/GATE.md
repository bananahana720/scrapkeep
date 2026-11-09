# The promotion gate: recipe

How the full gate runs, step by step, with the tools checked in. [ORCHESTRATOR.md](../../ORCHESTRATOR.md) owns the gate rule (what must pass, and when); this page is only the method. Written 2026-11-09 by the workflows pass from the wave 19 to 32 shard notes, so a fresh thread does not need another thread's memory or a hand-copied script.

The stage, the board and the receipts folder to compare against are in the Wave facts table of [STATE.md](STATE.md).

## What a full gate is

One promotion, one full gate, on the frozen stage head. The Gate thread writes a plan at `/mnt/project-files/gate/w<N>-<head>-gate-plan.md` and the coordinator starts about 13 shard threads from one post:

| Shard | What it runs | Usual wall time on a 4 vCPU cloud box |
| --- | --- | --- |
| tests, three windows | the non-bot list in thirds | 50 to 60 min each |
| bots 1 to 6 | the bot list in blocks of 5 | 35 to 60 min each |
| bands A | the posture-band tests, `bot_isle_stage5`, `skill_band`, `run_tier_dials`, the word budgets | 60 min |
| bands B | the world 1 challenge, 24 seeds | 90 min |
| bands C | swarm bands, `run_tier`, the HARD rungs | 3 h, one resume |
| red team | one persona, rotating: greedy, line-rider, speedrunner, first-timer, cautious | 60 min |

Shard threads run and compare; they write no fixes, commit nothing and push nothing. They run on the mid model tier (ruling bp). Each posts "started, import ok" on the board within 20 minutes, writes its receipt under `/mnt/project-files/gate/w<N>-<head>/`, posts the verdict on the board and replies to the Gate thread. Before relaunching a shard that looks missing, check the thread list and the board.

## Every shard, first

1. `bash tools/cloud/setup.sh` (installs the pinned Godot; exit 0).
2. Check out the frozen head, detached, and confirm it with `git rev-parse HEAD`. The checkout must be clean.
3. `/mnt/project-files` does not run scripts directly: use `bash script.sh`, and keep working files on local disk. Copy results to the shared folder at the end.
4. A background command is stopped after 2 hours. Every tool below resumes when the same command is run again.

## Test and bot shards

```
node scripts/gate/shard.mjs list            # the numbered non-bot list
node scripts/gate/shard.mjs list --bots     # the numbered bot list
node scripts/gate/shard.mjs run --tests 361-720 --out ~/gate/tests-361-720
node scripts/gate/shard.mjs run --bots 16-20 --out ~/gate/bots-4
```

`run` does the whole shard: it records the head, imports the sketch twice (the first import of a fresh checkout can crash; the second is the one that counts), runs the window (non-bot tests in chunks of 60, two chunks at a time; bot tests one at a time), reruns every failure alone twice, sorts the failures with the known-failing ledger and writes `receipt.md` and `shard.json` in the folder. `state.json` records each finished step, so a killed run continues from the next step. It refuses to continue in a folder that holds a different head or window.

What the folder holds afterwards: `chunkNN.log` or `bot-<test>.log` (the runner's own output), `logs/<test>.log` (every test's whole output, pass or fail), `solo-<test>-<n>.log` and `solo-logs-<n>/`, and the receipt. The receipt's last section is left for the thread: compare `logs/` with the last promoted head's receipts and say what moved. A moved tick, pin or floor is a finding even when the test passes.

How a failure is called:

| Call | Meaning | Blocks? |
| --- | --- | --- |
| carried | the test has a ledger row | No, if it fails the check its row names. A different failing check in the same test is a new red |
| new-flake | no row; it passed every solo run | No. Add a flake row in the receipt's follow-up |
| new-red | no row; it failed alone at least once | Yes. A new deterministic red goes to the pull request's owner (ruling ai). Confirm it is green on main before blaming the stage |

An `ERROR` line at exit fails a run even when every check passed. The receipt counts `ERROR`, `SCRIPT ERROR`, "still in use" and "previously freed" lines across every test's log, passing tests included.

### Slow boxes

Cloud boxes differ by about a third in speed. On a slow one, export `SMOKE_TIME_SCALE=1.5` (1 to 4) before `run`: every test's time limit is multiplied after its marker and ceiling. The receipt names the scale. It does not reach a limit a test sets for its own child processes; those live in the test files. Do not patch the runner: the wave 19 to 32 shards each carried a local patch for full output and bot time limits, and both are now options (`SMOKE_LOG_DIR`, `SMOKE_FULL=1`, `SMOKE_TIME_SCALE`).

## Band shards

The band shards read numbers, not only pass or fail, so they keep their own lane scripts: copy the last wave's from the receipts folder (`bands-A-logs/`, `bands-B-logs/`, `bands-C-logs/`) and change the label.

- **Bands A**: each test alone through the runner with `--sketch core-loop` (`--bots` only for the tests on the bot list). Sort the `->` lines (`LC_ALL=C sort`) and strip wall seconds before comparing with the last head; they print in completion order.
- **Bands B**: `node scripts/challenge/run.mjs --only=w1 --seeds=24 --no-top --jobs=4 --label=w<N>-<head>-w1`. Every job is the stage 1 Warden, so Brindle changes never show here. Compare `runs.ndjson` seed for seed with the last head.
- **Bands C**: `run_tier_dials_test`, `posture_bands_swarm_camper_test`, `posture_bands_swarm_test` and `run_tier_test`, each alone; then the HARD rungs, `node scripts/challenge/run.mjs --only=w1 --seeds=S --bands=expert --no-top --jobs=4 --tier=N --label=w<N>-<head>-C-tN`, with S 24 for rungs 1 to 4 and 48 for rung 5.
- A band sweep starts many child runs. A child that reads 300 s, or goes missing, on a 4-core box is suspect: rerun it alone before calling a red. Wait on a process by its PID (`kill -0`), never with `pgrep -f` or `pkill -f`, which match the waiting shell itself.
- A `bot_driver` change moves every bot stream: rerun all bot shards and bands, and put `posture_bands_test` and `posture_bands_reactor_test` in that pull request's focused set.

## The known-failing ledger

[KNOWN-FAILING.tsv](KNOWN-FAILING.tsv) lists every red test a promotion may carry: test, kind (`red` fails alone; `flake` fails under load or some runs), cause, owner, date added, review date (ruling bq). The coordinator owns the file; a row is added, re-dated or removed by a pull request on the open stage.

```
node scripts/known-failing.mjs --check              # shape; part of npm run check:docs
node scripts/known-failing.mjs --judge a_test b_test   # carried or new, for a list of failed tests
node scripts/known-failing.mjs --promotion          # fails if any row is past its review date
```

- A row never changes how a test runs or whether a run fails. The shard still reruns the test alone and still reads which check failed.
- The cost of a row: while a test is listed, a second fault in the same test is easy to miss. That is why the cause names the failing check and the receipt asks the thread to read the solo log.
- A test that has passed in two full gates in a row comes off the ledger. If it fails again it is judged fresh.
- A row past its review date holds the next promotion. Either the owner fixed it (remove the row) or the coordinator gives it a new date and says why in the pull request.
- `sketches/core-loop/tests/QUARANTINE.tsv` is a different tool with a different job: at most three rows, a listed test stops failing runs, and a release candidate carries none. Nothing is in it today.

## When the head moves after the shards ran

A small fix can land on a frozen stage (a re-pin, a text fix). Rows carry only for tests the change cannot reach:

```
node scripts/gate/carry.mjs <head the rows were read on>
```

Run it in a checkout of the new head. If any game file changed, nothing carries. Otherwise it lists the tests to run again: each changed test, and each test that reaches a changed file under `tests/` (a test that `extends` another runs its parent's checks; wave 31 promoted a red because one was carried). A change under `scripts/` is judged by hand.

## Before CLEAN

```
node scripts/gate/tally.mjs --plan /mnt/project-files/gate/w<N>-<head>-gate-plan.md
```

The plan's tally is a table headed `| Shard | Verdict |`, one row per shard: `tests FIRST-LAST`, `bots 1` to `bots 6`, `bands A`, `bands B`, `bands C`, `red team <persona>`. The checker refuses CLEAN while a row is missing or empty, a verdict names no receipt, the test windows leave a gap in the list, the newest row for a shard is red, or a ledger row is past its review date. When a shard is read again on a moved head, add a new row under a new table; the newest row for a name wins.

## After the promotion

The steps are in STATE.md ("After each promotion"). The first one keeps the docs honest: on the new stage, `node scripts/wave-state.mjs --write --board <new board issue> --compare <receipts folder>`. Until that commit lands, `npm run check:docs` fails on the new stage, on purpose.
