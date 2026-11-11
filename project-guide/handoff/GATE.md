# The promotion gate: recipe

How the full gate runs, step by step, with the tools checked in. [ORCHESTRATOR.md](../../ORCHESTRATOR.md) owns the gate rule (what must pass, and when); this page is only the method. Written 2026-11-09 by the workflows pass from the wave 19 to 32 shard notes, so a fresh thread does not need another thread's memory or a hand-copied script.

The stage, the board and the receipts folder to compare against are in the Wave facts table of [STATE.md](STATE.md).

## The wave gate and the release gate

Since 11 November 2026 (ruling cy) a promotion runs the wave gate, and the full gate below is the release gate, run once at the end of a sprint on the head a sitting build is cut from. [ORCHESTRATOR.md](../../ORCHESTRATOR.md) has the rule. The wave gate's method:

1. The node suite and the three test windows, as below.
2. The scoped set, one shard run by name: the bot-tier tests and posture-band proofs the fast lane's receipt names for the stage diff, `world1_run_test`, and any fight, stage or bot run the diff plainly touches. Write the list and the reason for each name in the gate plan.
3. The plan's tally has the test-window rows and one `scoped` row. A release shard may have a row that opens with DEFERRED and names the receipt of its last full read.
4. `node scripts/gate/tally.mjs --wave --plan <plan>` must exit 0. Without `--wave` the tally is the release gate's and defers nothing.

On the PC one command runs steps 1 to 4: `node scripts/gate/pc.mjs run --wave N --head <sha> --scoped-from <the stage's sketch:fast receipt.json> [--scoped a_test,b_test] --tally`. `--scoped-from` takes the bot shards that receipt names, `--scoped` adds more by name, and `world1_run_test` is always in. A non-bot name is left out, because the windows run the whole non-bot list. The weekly sweep runs as in a release gate (ruling ca), because the tally holds a wave gate to it too. `plan` with the same flags prints the scoped names. The reason for each name still goes in the gate plan.

## What a full gate is

One promotion, one full gate, on the frozen stage head. The Gate thread writes a plan at `/mnt/project-files/gate/w<N>-<head>-gate-plan.md` and the coordinator starts about 13 shard threads from one post:

| Shard | What it runs | Usual wall time on a 4 vCPU cloud box |
| --- | --- | --- |
| tests, three windows | the non-bot list in thirds | 50 to 60 min each |
| bots 1 to the last block | the bot list in blocks of 5 (23 tests, so 5 blocks, while the weekly list holds 9) | 35 to 60 min each |
| bands A | the posture-band tests, `skill_band`, `run_tier_dials`, the word budgets, less any test the weekly list names | 60 min |
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

`run` does the whole shard: it records the head, imports the sketch twice, and a third time when the second was not clean (Godot's first import of a fresh checkout can die on signal 11 or 6 in its font reimport; that is the engine's race and never a project red, so a crashed import is tried again, and the shard stops before any test only when the last import crashed, failed or exited 0 still printing `SCRIPT ERROR`; the runner and the fast lane give their own import up to three tries and take the first that is clean in that sense; the fast lane's import of the merge-base tree gets three tries too, judged by its exit code alone), runs the window (non-bot tests in chunks of 60, two chunks at a time; bot tests one at a time), reruns every failure alone twice, sorts the failures with the known-failing ledger and writes `receipt.md` and `shard.json` in the folder. `state.json` records each finished step, so a killed run continues from the next step. It refuses to continue in a folder that holds a different head, window, chunk size, solo count or time scale. It also refuses a checkout with uncommitted changes or with an untracked test or list file under `tests/`, because the lists are built from the files on disk: one stray file renumbers every window. The checkout is checked before each step and once more after the last.

What the folder holds afterwards: `import-N.log` (each import's whole output), `chunkNN.log` or `bot-<test>.log` (the runner's own output), `logs/<test>.log` (every test's whole output, pass or fail), `solo-<test>-<n>.log` and `solo-logs-<n>/`, and the receipt. The receipt's last section is left for the thread: compare `logs/` with the last promoted head's receipts and say what moved. A moved tick, pin or floor is a finding even when the test passes.

How a failure is called:

| Call | Meaning | Blocks? |
| --- | --- | --- |
| carried | the test has a ledger row | No, if it fails the check its row names. A different failing check in the same test is a new red |
| mismatch | its row says `flake` and it failed every solo run (it gets twice the solo runs before this call) | Yes. The run contradicts the ledger: read the solo log, then re-list the test as `red` with its failing check, or fix it |
| new-flake | no row; it passed every solo run | No. Add a flake row in the receipt's follow-up |
| new-red | no row; it failed alone at least once | Yes. A new deterministic red goes to the pull request's owner (ruling ai). Confirm it is green on main before blaming the stage |
| suspect-load | would be a new red or a mismatch, but every failed solo run timed out (`exit=null`) with no failing check line, and one started with the 1-minute load above half the thread count | Yes, and it is neither red nor pass: the shard says INCONCLUSIVE and exits 2. Once the other lanes have drained, settle it with `node scripts/gate/shard.mjs retime --tests <names> --out <folder>`. Post the retime receipt beside the shard's |

For each failure the receipt prints the failing lines of its last solo run, so the check that failed sits beside the cause its row names. An `ERROR` line at exit fails a run even when every check passed. The receipt counts `ERROR`, `SCRIPT ERROR`, "still in use" and "previously freed" lines across every test's log, passing tests included.

Every test the runner starts gets its own empty user data folder (`XDG_DATA_HOME`, in `scripts/sketch-smoke.mjs` and `scripts/sketch-fast.mjs`), removed when the test ends. So `user://` carries nothing from one test file to the next, in a shard or in the fast lane; the child runs a test starts share that test's folder unless the test or its helper gives them their own (a launched child gets its own, `tests/trees/child_runs.gd`). A bare Godot command typed by hand does not get one: it reads and writes the container's one shared folder, `~/.local/share/godot/app_userdata/core-loop`, with whatever earlier hand runs left there. Rerun a suspect test through the runner, or set `XDG_DATA_HOME` to a new empty folder first.

### Running shards on one PC

- A solo rerun uses a slot pool inside the shard's own `--out` folder (`solo-locks/`), so reruns from different shards never queue for one slot. The first run keeps the caller's `SCRAPKEEP_LOCK_DIR`.
- A headless Godot test wants about two threads. A 32-thread PC runs about 16 Godot processes at full speed. A bot test starts up to 8 child processes, so three bot lanes are the PC's limit.
- A time-out taken under load is `suspect-load`. It is not a red and it is not a pass. After the other lanes have drained, rerun the named tests alone with `retime`. It waits until the 1-minute load is at or under a quarter of the thread count (`--max-load` changes this), for at most 30 minutes, then runs each test alone `--runs` times (3 by default) and writes `receipt.md`. When the retime passes, the shard's row on the gate plan reads `PASS after retime` and names both receipts; when it is red or still inconclusive, the row keeps the shard's own verdict.
- Every step in a receipt shows the load it started and ended at, and the Box line says how many threads that load is read against. A receipt from before this change shows a dash.
- One command runs a whole gate on the PC: `node scripts/gate/pc.mjs run --wave N --head <sha> [--base <last gated head's folder>] [--persona <id>] [--root <dir>] [--budget n] [--tally]`, from a checkout of that head, with `GODOT_BIN` set. `plan` takes the same flags and prints the steps with their weights and the order, writing nothing (`npm run gate:pc` is the same script). It starts steps in order while their Godot-process weights fit the budget (half the thread count by default), gives each step its own worktree, slot pool and scratch data home, and runs the red team pass and any retime alone at the end. The band lists live in `scripts/gate/bands.json`, not in a lane script. A step that is already finished is skipped, so the same command resumes; `--redo <step id>` runs one again.
- It writes receipts to `<root>/w<N>-<head8>/<step id>/` (each with a `step.json`), `compare.md` (every band against the `--base` folder's receipts, run for run, with wall time and the play watch ignored), and `<root>/w<N>-<head8>-gate-plan.md`, whose `| Shard | Verdict |` table is the one the tally reads. A band row is `PASS` only when its step exited 0 and the comparison found it identical; with no `--base` it reads `NO BASE`. With no `--persona` the plan file says the red team row is owed. It prints the tally command; `--tally` runs it.

### Slow boxes

Cloud boxes differ by about a third in speed. On a slow one, export `SMOKE_TIME_SCALE=1.5` (1 to 4) before `run`: every test's time limit is multiplied after its marker and ceiling. The receipt names the scale. It does not reach a limit a test sets for its own child processes; those live in the test files. Do not patch the runner: the wave 19 to 32 shards each carried a local patch for full output and bot time limits, and both are now options (`SMOKE_LOG_DIR`, `SMOKE_FULL=1`, `SMOKE_TIME_SCALE`).

## Band shards

The band shards read numbers, not only pass or fail, so they keep their own lane scripts: copy the last wave's from the receipts folder (`bands-A-logs/`, `bands-B-logs/`, `bands-C-logs/`) and change the label.

- **Bands A**: each test alone through the runner with `--sketch core-loop` (`--bots` only for the tests on the bot list). The lane script is copied from the last wave, so first strike every name that `node scripts/gate/shard.mjs list --weekly` and `list --weekly --bots` print (on 9 Nov: `posture_bands_mind_test`, `alpha_posture_bands_w23_test`, `bot_isle_stage5_test`); those run in the weekly sweep. Sort the `->` lines (`LC_ALL=C sort`) and strip wall seconds before comparing with the last head; they print in completion order.
- **Bands B**: `node scripts/challenge/run.mjs --only=w1 --seeds=24 --no-top --jobs=4 --label=w<N>-<head>-w1`. Every job is the stage 1 Warden, so Brindle changes never show here. Compare `runs.ndjson` seed for seed with the last head.
- **Bands B and C, what a player would report**: every `scripts/challenge/run.mjs` job plays with the play watch on (`--qa-log=1`), and `table.md` ends with "What a player would report": wedged, fell, blank, bar, stuck and hung rows gathered by place. It is information, not a verdict: copy the section into the shard receipt, and name any wedged, fell, blank or bar place on the board for its owner. The watch only reads the game (8 of 8 sample runs were identical with it on and off, 9 Nov), but each run's line gains a `qa` field and each bot row a `qa` count, so the first comparison against a head without them compares `row` less `qa` and `wall_seconds`.
- **Bands C**: `run_tier_dials_test`, `posture_bands_swarm_camper_test`, `posture_bands_swarm_test` and `run_tier_test`, each alone; then the HARD rungs, `node scripts/challenge/run.mjs --only=w1 --seeds=S --bands=expert --no-top --jobs=4 --tier=N --label=w<N>-<head>-C-tN`, with S 24 for rungs 1 to 4 and 48 for rung 5.
- A band sweep starts many child runs. A child that reads 300 s, or goes missing, on a 4-core box is suspect: rerun it alone before calling a red. Wait on a process by its PID (`kill -0`), never with `pgrep -f` or `pkill -f`, which match the waiting shell itself.
- A `bot_driver` change moves every bot stream: rerun all bot shards and bands, and put `posture_bands_test` and `posture_bands_reactor_test` in that pull request's focused set.

## The weekly list

`project-guide/handoff/WEEKLY.tsv`, beside the ledger, names the tests a promotion does not run (ruling ca): worlds 2 and 3, parked by ruling at, and whole-run bot proofs on maps the launched game does not use, and (group `no-catch`, Andrew, 10 Nov 2026) 20 long tests that ran six or more of the 22 planted world 1 faults and caught none. The measurement behind that group is the Gate Catch Table (shared folder `testing/plant-measure/`); bots stay in every promotion until they are re-measured with balance faults, and the four tests that are the only catcher of a planted fault (`dunk_charge_test`, `park_recipes_dam_dressing_test`, `build_codex_test`, `panels_isolation_test`) never join the list. Columns: test, group, reason, returns-when. The testing lane owns the rows and lands the file; `scripts/gate/shard.mjs` reads it.

- `list`, `list --bots` and both `run` windows leave the weekly names out, so the windows in a gate plan count the shortened lists.
- `--weekly` with `list` or `run` selects the weekly names instead: the weekly sweep is the same command with one flag, and its receipt says "weekly" in its title.
- The fast lane does not read the file: a weekly test still runs on any pull request whose diff reaches it. `npm run sketch:smoke` still runs everything.
- A file that does not parse, or a row that names a test that does not exist, stops the shard with an error. It never skips nothing, or everything, silently. `npm run check:docs` fails on the same two faults, so a pull request catches them first.
- The tally prints how many tests the promotion did not run. With no file on the head, the lists hold every test.
- A weekly test can also have a ledger row. Its review date does not hold a promotion, because the promotion does not run it; the weekly sweep judges it, and `--promotion` prints the row as a note.
- The hold: while the list names any test, the tally needs a `weekly sweep` row in the plan. Its verdict opens with `PASS`, gives the day the sweep ran as `YYYY-MM-DD` and names its receipts; a sweep more than 7 days old, a row with no day, or no row at all refuses CLEAN. Days are counted in UTC from the day in the row to the day the tally runs: a sweep 7 days back still counts, 8 refuses. The newest row wins, as for every shard.
- Running it: when the newest sweep would be more than 7 days old at the tally, the gate plan adds one more shard thread, `weekly sweep`, which runs `node scripts/gate/shard.mjs run --weekly --tests 1-N --out ~/gate/weekly-tests` and then `run --weekly --bots 1-N --out ~/gate/weekly-bots` on the frozen head (about an hour on one box before the `no-catch` group joined on 10 Nov; its 20 tests add about 38 minutes of single-test time). Otherwise the plan copies the last sweep's row and receipts path forward. Nothing is scheduled: a promotion asks for the sweep when it is due.
- A red in the sweep is judged like any shard red (alone, then the ledger). The testing lane owns the fix; the row stays `RED` and holds the promotion until the test passes, is carried on the ledger, or comes off the list.
- The first row: every test on the list last ran in the wave 32 full gate on 2026-11-08, before the list existed, so the first plan after the list landed may write `PASS 2026-11-08, in the wave 32 full gate. Receipts gate/w32-58a6de62/`. The first sweep proper is due by 2026-11-15.

## The known-failing ledger

[KNOWN-FAILING.tsv](KNOWN-FAILING.tsv) lists every red test a promotion may carry: test, kind (`red` fails alone; `flake` fails under load or some runs), cause, owner, date added, review date (ruling bq). The coordinator owns the file; a row is added, re-dated or removed by a pull request on the open stage.

```
node scripts/known-failing.mjs --check              # shape; part of npm run check:docs
node scripts/known-failing.mjs --judge a_test b_test   # carried or new, for a list of failed tests
node scripts/known-failing.mjs --promotion          # fails if any row is past its review date
```

- At a promotion a row never changes how a test runs or whether a run fails. The shard still reruns the test alone and still reads which check failed. In the fast lane a `flake` row buys more head runs before the test fails a pull request; ORCHESTRATOR, "Tiered gate", has the rule.
- The cost of a row: while a test is listed, a second fault in the same test is easy to miss. That is why the cause names the failing check and the receipt asks the thread to read the solo log.
- A test that has passed in two full gates in a row comes off the ledger. If it fails again it is judged fresh.
- A row past its review date holds the next promotion. Either the owner fixed it (remove the row) or the coordinator gives it a new date and says why in the pull request.
- `sketches/core-loop/tests/QUARANTINE.tsv` is a different tool with a different job: at most three rows, a listed test stops failing runs, and a release candidate carries none. Nothing is in it today.

## The play findings list

[PLAY-FINDINGS.tsv](PLAY-FINDINGS.tsv) lists every open thing a player would feel that a red team pass has found: what the player meets, where it was seen, grade (`blocker`, `major`, `minor`, or `check` when a PC film must decide first), owner, date added, review date (ruling cn). The testing lane owns the file. It is not a gate: a finding never holds a promotion, and no gate step or test reads the file. `node scripts/redteam/findings.mjs --print` lists it by owner and `--overdue` names the rows past their date, for the wave's red team receipt. [scripts/redteam/README.md](../../scripts/redteam/README.md) has the pass that fills it.

## The node tests, once per promotion

The fast lane runs only the node tests a diff selects, and the shards run Godot tests. So once per promotion the whole node suite runs on the PC, where no test is skipped for the box: a full clone, an ordinary user, installed packages. The coordinator queues it on the PC lane when the Gate calls the promotion.

```
git fetch origin && git checkout --detach <stage head>
npm ci
SCRAPKEEP_WHOLE_TESTS=1 npm test
```

Pass means the last command exits 0 and its summary reads `# fail 0`. `SCRAPKEEP_WHOLE_TESTS=1` turns the box skips in `tests/preconditions.mjs` (as root, two tests; in a shallow clone, seven) into errors, so a pass cannot come from a box that skipped them. Skips that remain are tests with their own stated need (a Godot binary, for one) and do not fail the run. The PC lane posts the summary lines (`# tests`, `# pass`, `# fail`, `# skipped`) on the board. A failure is a new red and blocks like any other (ruling ai); there is no ledger for node tests.

In a cloud thread, plain `npm test` should also read `# fail 0`, with up to 9 more skipped than on the PC. It is a useful check before a pull request that touches `scripts/` or `tests/`, and it does not replace the PC run.

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

The plan's tally is a table headed `| Shard | Verdict |`, one row per shard: `tests FIRST-LAST`, `bots 1` to the last block of five, `bands A`, `bands B`, `bands C`, `red team <persona>`, and `weekly sweep` while the weekly list names any test. A verdict opens with `PASS` (`CLEAR` for the red team) or with `RED`; the shard receipt's verdict line is written that way, so copy it. The checker refuses CLEAN while a row is missing or empty, a verdict names no receipt, the test windows leave a gap in the list, the newest row for a shard does not open with PASS or CLEAR, the plan's file name gates a head other than the one checked out (the lists are counted in the checkout), a ledger row is past its review date, or the weekly sweep is missing or more than 7 days old. When a shard is read again on a moved head, add a new row under a new table; the newest row for a name wins.

## After the promotion

The steps are in STATE.md ("After each promotion"). The first one keeps the docs honest: on the new stage, `node scripts/wave-state.mjs --write --board <new board issue> --compare <receipts folder>`. The check passes while the stage head is still the promotion commit itself; from the first commit after it, `npm run check:docs` fails on the new stage until this lands, on purpose.

The check finds the last promotion by its commit subject, so a promotion is merged with the subject `Promote alpha wave N (stage/alpha-wN <head>) to main (#PR)`. Under GitHub's default "Merge pull request" subject (waves 24 to 30) the promotion is invisible to it and the table can fall behind unnoticed.

The fast lane orders and prices its tests from the gate's times, so refresh them in the same pull request: `node scripts/sketch-fast.mjs --fold-timings /mnt/project-files/gate/w<N>-<head>/*/shard.json`. Passing tests only; a test that did not pass keeps its old row.
