# The promotion gate: recipe

How the full gate runs, step by step, with the tools checked in. [ORCHESTRATOR.md](../../ORCHESTRATOR.md) owns the tiered gate policy (what must pass, and when) and [CONTRIBUTING.md](../../CONTRIBUTING.md) owns the CLI command matrix; this page owns shard execution mechanics. Written 2026-11-09 from wave 19 to 32 shard notes and updated for flat `main` and the Mac Studio Gate.

The open branch (`main`) and carried state live in the Wave facts table of [STATE.md](STATE.md).

## The wave gate and the release gate

Development runs flat on `main` (`ruling ep`, `ruling eq`); [ORCHESTRATOR.md](../../ORCHESTRATOR.md) owns which checks run per PR, per promotion (wave gate), and per sitting (release gate). Receipts live under `artifacts/local/` locally and on `scratch/gate-receipts-*` branches when shared.

On the Gate host (Mac Studio under `ruling eb`, or Linux `ahana` per [DEVICES.md](DEVICES.md)), one command runs the wave gate (`node scripts/gate/pc.mjs run --wave N --head <sha> --scoped-from <the diff's sketch:fast receipt.json> [--scoped a_test,b_test] --tally`), which executes the Node suite, the three non-bot test windows, and the scoped bot/posture shard (`world1_run_test` always included) and runs `node scripts/gate/tally.mjs --wave --plan <plan>` (omit `--wave` for a release gate, which defers nothing). The plan's tally has the test-window rows and one `scoped` row (a release shard may have a row that opens with DEFERRED and names the receipt of its last full read). `plan` with the same flags prints the scoped names; record each scoped reason in the gate plan.

## What a full gate is

The release gate runs via `scripts/gate/pc.mjs` on the Mac Studio (`ruling eb`) or Linux `ahana`. Worker routing and shard models follow [AGENTS.md](../../AGENTS.md) rule 11 (Gemini 4 Neon at high effort; fallback `scrapkeep-verifier`). For an overflow multi-shard run:

| Shard | What it runs | Usual wall time on a 4 vCPU cloud box |
| --- | --- | --- |
| tests, three windows | the non-bot list in thirds | 50 to 60 min each |
| bots 1 to the last block | the bot list in blocks of 5 (23 tests, so 5 blocks, while the weekly list holds 9) | 35 to 60 min each |
| bands A | the posture-band tests, `skill_band`, `run_tier_dials`, the word budgets, less any test the weekly list names | 60 min |
| bands B | the world 1 challenge, 24 seeds | 90 min |
| bands C | swarm bands, `run_tier`, the HARD rungs | 3 h, one resume |
| red team | one persona, rotating: greedy, line-rider, speedrunner, first-timer, cautious | 60 min |

Shard workers run and compare; they write no fixes, commit nothing, and push nothing. Each follows [AGENTS.md](../../AGENTS.md) rule 11, writes its receipt under `artifacts/local/gate/w<N>-<head>/` (published on `scratch/gate-receipts-*` when shared), and reports the verdict back to the Mac Studio Gate session.

## Every shard, first

1. `bash tools/cloud/setup.sh` (installs the pinned Godot on cloud/Linux hosts; exit 0).
2. Check out the frozen head, detached, and confirm it with `git rev-parse HEAD`. The checkout must be clean.
3. Keep working files and receipts on local disk under `artifacts/local/` (never on shared network mounts); publish gate receipts to a `scratch/gate-receipts-*` branch or PR report at the end.
4. A background command is stopped after 2 hours. Every tool below resumes when the same command is run again.

## Test and bot shards

```
node scripts/gate/shard.mjs list            # the numbered non-bot list
node scripts/gate/shard.mjs list --bots     # the numbered bot list
node scripts/gate/shard.mjs run --tests 361-720 --out ~/gate/tests-361-720
node scripts/gate/shard.mjs run --bots 16-20 --out ~/gate/bots-4
```

`run` does the whole shard: it records the head, imports the sketch twice, and a third time when the second was not clean (Godot's first import of a fresh checkout can die on signal 11 or 6 in its font reimport; that is the engine's race and never a project red, so a crashed import is tried again, and the shard stops before any test only when the last import crashed, failed or exited 0 still printing `SCRIPT ERROR`; the runner and the fast lane give their own import up to three tries and take the first that is clean in that sense; the fast lane's import of the merge-base tree gets three tries too, judged by its exit code alone), runs the window (non-bot tests in chunks of 60, two chunks at a time; bot tests one at a time, or in the wave gate's scoped shard two at a time with the wall-clock and machine-filling bot tests in `BOT_ALONE` run alone afterwards), reruns every failure alone (twice, or once when a check fails alone on the first rerun and the test has no flake row, because that already settles the call; not at all when the test has a `red` row and its first run failed a check without timing out, because that run's failing checks are read against the row and a rerun adds only time), sorts the failures with the known-failing ledger and writes `receipt.md` and `shard.json` in the folder. `state.json` records each finished step, so a killed run continues from the next step. It refuses to continue in a folder that holds a different head, window, chunk size, solo count or time scale. It also refuses a checkout with uncommitted changes or with an untracked test or list file under `tests/`, because the lists are built from the files on disk: one stray file renumbers every window. The checkout is checked before each step and once more after the last.

What the folder holds afterwards: `import-N.log` (each import's whole output), `chunkNN.log` or `bot-<test>.log` (the runner's own output), `logs/<test>.log` (every test's whole output, pass or fail), `solo-<test>-<n>.log` and `solo-logs-<n>/`, and the receipt. The receipt's last section is left for the thread: compare `logs/` with the last promoted head's receipts and say what moved. A moved tick, pin or floor is a finding even when the test passes.

How a failure is called:

| Call | Meaning | Blocks? |
| --- | --- | --- |
| carried | the test has a ledger row, and for a `red` row everything its failed runs did is named in the row's `check` column | No. The shard reads every failed run against the row, the first run and each rerun alone (since 15 Nov 2026). Any of these makes it a new red: a failing check the row does not name; a run killed at its limit when the row has no `TIME-OUT`; a failed run that left no log or verdict line; an `ERROR` or `SCRIPT ERROR` line in a failed run when the row has no `ERROR-LINE`. Each counts also beside a named check, and also when the test passed alone afterwards |
| mismatch | its row says `flake` and it failed every solo run (it gets twice the solo runs before this call) | Yes. The run contradicts the ledger: read the solo log, then re-list the test as `red` with its failing check, or fix it |
| new-flake | no row; it passed every solo run | No, not yet: making it block is a later step of ruling dx ("Check speed and honesty"). No flake row is added for it since ruling dx; the test's owner fixes it |
| new-red | no row and it failed alone at least once; or a `red` row that does not name what a failed run did | Yes. A new deterministic red goes to the pull request's owner (ruling ai). Confirm it was green on the base commit (or the last promoted head in [STATE.md](STATE.md)) before blaming the candidate head on `main` |
| suspect-load | would be a new red or a mismatch, but every failed solo run timed out (`exit=null`) with no failing check line, and one started with the 1-minute load above half the thread count | Yes, and it is neither red nor pass (a failing check or error line that a `red` row does not name is never this call; it is a new red at any load. A test with a `red` row that gets this call fails its named check in the retime, and the retime does not read the ledger, so settle that one by running the shard again in a new folder): the shard says INCONCLUSIVE and exits 2. Once the other lanes have drained, settle it with `node scripts/gate/shard.mjs retime --tests <names> --out <folder>`. Post the retime receipt beside the shard's |

For each failure the receipt prints the failing lines of its last failed solo run, or of its first run when no solo run failed, so the check that failed sits beside the cause its row names. An `ERROR` line at exit fails a run even when every check passed. The receipt counts `ERROR`, `SCRIPT ERROR`, "still in use" and "previously freed" lines across every test's log, passing tests included.

Every test the runner starts gets its own empty user data folder (`XDG_DATA_HOME`, in `scripts/sketch-smoke.mjs` and `scripts/sketch-fast.mjs`), removed when the test ends. So `user://` carries nothing from one test file to the next, in a shard or in the fast lane; the child runs a test starts share that test's folder unless the test or its helper gives them their own (a launched child gets its own, `tests/trees/child_runs.gd`). A bare Godot command typed by hand does not get one: it reads and writes the container's one shared folder, `~/.local/share/godot/app_userdata/core-loop`, with whatever earlier hand runs left there. Rerun a suspect test through the runner, or set `XDG_DATA_HOME` to a new empty folder first.

### Running shards on one PC

- A solo rerun uses a slot pool inside the shard's own `--out` folder (`solo-locks/`), so reruns from different shards never queue for one slot. The first run keeps the caller's `SCRAPKEEP_LOCK_DIR`.
- Measured on the 32-thread PC (timed gate on `375fe11a`, 15 Nov): a test window holds a load of about 5, one bot lane about 8, and the wave gate's bot shard beside two windows held a median load of 15 with bursts above 32 (one bot test starts 48 children). The step weights understate those bursts, so two bot lanes stay the limit until a heavy test has its own weight. A time-out that starts with the load above half the thread count reads suspect-load, which at this budget is most time-outs: it still blocks as INCONCLUSIVE and is settled alone.
- A time-out taken under load is `suspect-load`. It is not a red and it is not a pass. After the other lanes have drained, rerun the named tests alone with `retime`. It waits until the 1-minute load is at or under a quarter of the thread count (`--max-load` changes this), for at most 30 minutes, then runs each test alone `--runs` times (3 by default) and writes `receipt.md`. When the retime passes, the shard's row on the gate plan reads `PASS after retime` and names both receipts; when it is red or still inconclusive, the row keeps the shard's own verdict.
- Every step in a receipt shows the load it started and ended at, and the Box line says how many threads that load is read against. A receipt from before this change shows a dash.
- One command runs a whole gate on the PC: `node scripts/gate/pc.mjs run --wave N --head <sha> [--base <last gated head's folder>] [--persona <id>] [--root <dir>] [--budget n] [--tally]`, from a checkout of that head, with `GODOT_BIN` set. `plan` takes the same flags and prints the steps with their weights and the order, writing nothing (`npm run gate:pc` is the same script). It starts steps in order while their weights, in busy threads of measured load, fit the budget (the thread count less four by default; the wave gate's bot shard starts first, beside two test windows), gives each step its own worktree, slot pool and scratch data home, and runs the red team pass and any retime alone at the end. The band lists live in `scripts/gate/bands.json`, not in a lane script. A step that is already finished is skipped, so the same command resumes; `--redo <step id>` runs one again.
- It writes receipts to `<root>/w<N>-<head8>/<step id>/` (each with a `step.json`), `compare.md` (every band against the `--base` folder's receipts, run for run, with wall time and the play watch ignored), and `<root>/w<N>-<head8>-gate-plan.md`, whose `| Shard | Verdict |` table holds the shard rows and whose `| Check | Verdict |` table holds the `node tests` row; the tally reads both. A run with `--tally` exits 1 when any step was red, whatever the tally says; a shard that a retime settled is not red. A band row is `PASS` only when its step exited 0 and the comparison found it identical; with no `--base` it reads `NO BASE`. With no `--persona` the plan file says the red team row is owed. It prints the tally command; `--tally` runs it.

### Slow boxes

Cloud boxes differ by about a third in speed. On a slow one, export `SMOKE_TIME_SCALE=1.5` (1 to 4) before `run`: every test's time limit is multiplied after its marker and ceiling. The receipt names the scale. It does not reach a limit a test sets for its own child processes; those live in the test files. Do not patch the runner: the wave 19 to 32 shards each carried a local patch for full output and bot time limits, and both are now options (`SMOKE_LOG_DIR`, `SMOKE_FULL=1`, `SMOKE_TIME_SCALE`).

## Band shards

The band shards read numbers, not only pass or fail, so they keep their own lane scripts: copy the last wave's from the receipts folder (`bands-A-logs/`, `bands-B-logs/`, `bands-C-logs/`) and change the label.

- **Bands A**: each test alone through the runner with `--sketch core-loop` (`--bots` only for the tests on the bot list). The lane script is copied from the last wave, so first strike every name that `node scripts/gate/shard.mjs list --weekly` and `list --weekly --bots` print (on 9 Nov: `posture_bands_mind_test`, `alpha_posture_bands_w23_test`, `bot_isle_stage5_test`); those run in the weekly sweep. Sort the `->` lines (`LC_ALL=C sort`) and strip wall seconds before comparing with the last head; they print in completion order.
- **Bands B**: `node scripts/challenge/run.mjs --only=w1 --seeds=24 --no-top --jobs=12 --label=w<N>-<head>-w1`. Every job is the stage 1 Warden, so Brindle changes never show here. Compare `runs.ndjson` seed for seed with the last head.
- **Bands B and C, what a player would report**: every `scripts/challenge/run.mjs` job plays with the play watch on (`--qa-log=1`), and `table.md` ends with "What a player would report": wedged, fell, blank, bar, stuck and hung rows gathered by place. It is information, not a verdict: copy the section into the shard receipt, and flag any wedged, fell, blank or bar place in the report back to the Mac Studio Gate session for its owner. The watch only reads the game (8 of 8 sample runs were identical with it on and off, 9 Nov), but each run's line gains a `qa` field and each bot row a `qa` count, so the first comparison against a head without them compares `row` less `qa` and `wall_seconds`.
- **Bands C**: `run_tier_dials_test`, `posture_bands_swarm_camper_test`, `posture_bands_swarm_test` and `run_tier_test`, each alone; then the HARD rungs, `node scripts/challenge/run.mjs --only=w1 --seeds=S --bands=expert --no-top --jobs=12 --tier=N --label=w<N>-<head>-C-tN`, with S 24 for rungs 1 to 4 and 48 for rung 5.
- A band sweep starts many child runs. A child that reads 300 s, or goes missing, on a 4-core box is suspect: rerun it alone before calling a red. Wait on a process by its PID (`kill -0`), never with `pgrep -f` or `pkill -f`, which match the waiting shell itself.
- A `bot_driver` change moves every bot stream: rerun all bot shards and bands, and put `posture_bands_test` and `posture_bands_reactor_test` in that pull request's focused set.

## The weekly list

`project-guide/handoff/WEEKLY.tsv` is currently empty on `main`: Worlds 2–3 unparked (`ruling ep`) and all rows graduated in `1e0de5210`. Historically (`ruling ca`), it held parked worlds, old-map bot proofs, and 20 `no-catch` long tests (while keeping the four single-catcher tests `dunk_charge_test`, `park_recipes_dam_dressing_test`, `build_codex_test`, and `panels_isolation_test` in every gate). `scripts/gate/shard.mjs` and `npm run check:docs` validate `WEEKLY.tsv` schema whenever rows exist.

- `list`, `list --bots` and both `run` windows leave the weekly names out, so the windows in a gate plan count the shortened lists.
- `--weekly` with `list` or `run` selects the weekly names instead: the weekly sweep is the same command with one flag, and its receipt says "weekly" in its title.
- The fast lane does not read the file: a weekly test still runs on any pull request whose diff reaches it. `npm run sketch:smoke` still runs everything.
- A file that does not parse, or a row that names a test that does not exist, stops the shard with an error. It never skips nothing, or everything, silently. `npm run check:docs` fails on the same two faults, so a pull request catches them first.
- The tally prints how many tests the promotion did not run. With no file on the head, the lists hold every test.
- A weekly test can also have a ledger row. Its review date does not hold a promotion, because the promotion does not run it; the weekly sweep judges it, and `--promotion` prints the row as a note.
- The hold: while the list names any test, the tally needs a `weekly sweep` row in the plan. Its verdict opens with `PASS`, gives the day the sweep ran as `YYYY-MM-DD` and names its receipts; a sweep more than 7 days old, a row with no day, or no row at all refuses CLEAN. Days are counted in UTC from the day in the row to the day the tally runs: a sweep 7 days back still counts, 8 refuses. The newest row wins, as for every shard.
- Running it: when the newest sweep would be more than 7 days old at the tally, the gate plan adds one more shard thread, `weekly sweep`, which runs `node scripts/gate/shard.mjs run --weekly --tests 1-N --out ~/gate/weekly-tests` and then `run --weekly --bots 1-N --out ~/gate/weekly-bots` on the frozen head (about an hour on one box before the `no-catch` group joined on 10 Nov; its 20 tests add about 38 minutes of single-test time). Otherwise the plan copies the last sweep's row and receipts path forward. Nothing is scheduled: a promotion asks for the sweep when it is due.
- A red in the sweep is judged like any shard red (the ledger, and a rerun alone unless a `red` row carries it and its first run failed a check). The testing lane owns the fix; the row stays `RED` and holds the promotion until the test passes, is carried on the ledger, or comes off the list.
- The first row: every test on the list last ran in the wave 32 full gate on 2026-11-08, before the list existed, so the first plan after the list landed may write `PASS 2026-11-08, in the wave 32 full gate. Receipts gate/w32-58a6de62/`. The first sweep proper is due by 2026-11-15.

## The known-failing ledger

[KNOWN-FAILING.tsv](KNOWN-FAILING.tsv) lists every red test a promotion may carry: test, kind (`red` fails alone; `flake` fails under load or some runs; since ruling dx no new `flake` row is added: a new failure that shows only under load gets no row (the shard still calls it new-flake and lets it through until the later step of ruling dx makes it block), and a row that was already `red` for such a failure, like `tree_play_test`, stays `red` with a cause that says so until the test is fixed), cause, owner, date added, review date (ruling bq), and check (ruling dx): for a `red` row, the checks it covers as the test prints them between the square brackets of a `-> FAIL` line, joined by ` ;; `, where a star stands for any text inside one check (a check of stars alone is refused), `TIME-OUT` covers a run killed at its limit and `ERROR-LINE` a run that prints an `ERROR` or `SCRIPT ERROR` line or fails with no failing check (the two words are matched whole and are needed also beside a named check; `ERROR-LINE` covers any error line of the test, so the row's cause names the one it means); a `flake` row has `-` and keeps its allowance until it is fixed. The coordinator owns the file; a row is added, re-dated or removed by a pull request on the open stage. A `red` row for a test that is red on `main` itself starts its cause with `red on main at <commit> on <YYYY-MM-DD>: `, the commit of `main` and the day it was seen red there; no other row starts that way. Such a row names each check exactly as the test prints it, and the ledger check refuses a star, `ERROR-LINE` or `TIME-OUT` in it: a star matches checks nobody saw fail on `main`, `ERROR-LINE` lets any error line through, and `TIME-OUT` can never apply, since a run killed at its limit is never marked. When the fast check runs a test without its base run (the CI Godot job, and `npm run sketch:fast -- --test <name>` without `--base-check`), it reads the ledger at `--base`. A row never changes whether a run fails (ruling bq): a listed test that is red is still red and the run fails with exit code 1, as any red does. What the row changes is the report. The test is reported as `known red on main` with its row, and the run goes on to its other tests, when every run of the test in the invocation (its first run, in a warm batch or alone, the run alone after a batch, and the rerun) qualifies on its own: it ended with its exit code 0 or 1 and its `<test>: FAIL` line, was not stopped by a signal, the lane or its time limit, printed at least one failing check, and every failing line the gate counts (each `-> FAIL` check, a `FAIL` line with no `-> FAIL`, an `ERROR` or `SCRIPT ERROR` line) is one the row names; otherwise, or when the row is past its review date, the run says which run failed the rule and why, and the test is this change's red. A first run in a warm batch shares one engine with the batch's other tests: its `-> FAIL` checks and its `<test>: FAIL` line are read from its own part of the output and its exit code is the one the batch driver gives it, but an `ERROR` or `SCRIPT ERROR` line can land in another test's part, so an error line anywhere in the batch counts against every red test of it. A run in a warm batch that ended while the test ran (no `BATCH END` line for it), or in a batch whose results are thrown away (an error line outside every test's part, or an unexpected exit), cannot speak for the test: it still goes with the test's later runs, so a listed test that is red with such a run is this change's red; a test the batch never started carries nothing from it. A listed test that passes is reported so its row can be removed, and a ledger the fast check cannot read at the base lists nothing. The run's last line names the known reds in one fixed form a tool can match: `sketch:fast fail: only known reds on main (<count>): <tests>` when every red is a known red, and `sketch:fast fail: new reds (<count>): <tests>; known reds on main (<count>): <tests>` when another red is present beside them; with no known red the line is absent. The JSON receipt's `main_red` holds `known`, `new_reds`, `passed`, `line` and `only_known_reds`, which is `true` only when there is a known red and no other red. In the CI Godot job the budget wrapper `scripts/ci/check-budget.mjs` prints its own line after the fast check's, `budget[godot-affected]: <seconds>s / 900s (<status>)`, where the status is `PASS`, `FAIL`, `OVER_BUDGET`, or `FAIL+OVER_BUDGET` for a run that failed and also ran past its budget; the exit code stays the failing run's. Whether a run whose only reds are known reds may turn the job green is a question for Andrew; until he rules, it fails.

```
node scripts/known-failing.mjs --check              # shape; part of npm run check:docs
node scripts/known-failing.mjs --judge a_test b_test   # listed or not, by test name only; the shard reads the checks
node scripts/known-failing.mjs --promotion          # fails if any row is past its review date
```

- At a promotion a row never changes how a test runs or whether a run fails. The shard still reads which check failed: from the first run when that run failed a check and the row is `red` (since 15 Nov 2026; that run is read against the row, so a rerun adds only time, and two of them took 14 minutes of the timed gate on `375fe11a`), and from the first run and each rerun alone otherwise, which covers a time-out, a killed run and every `flake` row. In the fast lane a `flake` row buys more head runs before the test fails a pull request; ORCHESTRATOR, "Tiered gate", has the rule.
- The cost of a row: while a test is listed, a second fault in the same test is easy to miss. That is why the cause names the failing check and the receipt asks the thread to read the failing lines. It has happened: `stage_modifier_test` gained a second failing check in wave 41 (the stage 1 draw pin) under its row for a stage 5 check, and nothing flagged it until the receipt lines were read on 15 Nov. Ruling dx (a row covers only the check it names) is the rule, and the shard enforces it for `red` rows from the `check` column: replayed on the wave 41 and wave 42 gate logs, that test reads new red, and on the wave 40 log it reads carried. A check is named by its label, so a row covers that check at any value it prints; the cause carries the value. Not yet enforced: a `flake` row still covers its whole test, and the fast lane still reads "red on the base too" by test and not by check.
- A test that has passed in two full gates in a row comes off the ledger. If it fails again it is judged fresh.
- A row past its review date holds the next promotion. Either the owner fixed it (remove the row) or the coordinator gives it a new date and says why in the pull request.
- `sketches/core-loop/tests/QUARANTINE.tsv` is retired: the lint (rule L5) refuses any row in it, and no test runner reads it. A red test is carried only by a row in the known-failing ledger above.

## The play findings list

[PLAY-FINDINGS.tsv](PLAY-FINDINGS.tsv) lists every open thing a player would feel that a red team pass has found: what the player meets, where it was seen, grade (`blocker`, `major`, `minor`, or `check` when a PC film must decide first), owner, date added, review date (ruling cn). The testing lane owns the file. It is not a gate: a finding never holds a promotion, and no promotion step or test reads the file; the world 1 done read below counts its rows for the sitting. Rows that only a film can close are closed together at the release film (ruling dz), not wave by wave: a fix lands on its tests and review, and its row reads "open until the release film". `node scripts/redteam/findings.mjs --print` lists it by owner and `--overdue` names the rows past their date, for the wave's red team receipt. [scripts/redteam/README.md](../../scripts/redteam/README.md) has the pass that fills it.

## The world 1 done read

`npm run sketch:world1-bands -- --sitting --head <sha>` is the one read that says whether world 1 is done (ruling dt). It starts no Godot. It reads `scripts/world1-bands.rows.json`, which gives each of the 11 areas its rows, and prints READY only when every gate row passes. Receipts are tied to the head named; without `--head` the read judges the checkout's own head, and a receipt from any other commit is no data.

- **A gate row** is decided by a machine. Some rows read files in the tree: the open play findings (blocker, major and minor rows about world 1; a row that opens with "World 2" or "World 3" is left out), the play findings a PC film has not decided yet (`check` rows), the known-failing rows past their review date, and the placeholder scan. The rest read what the Gate hands in: `--bots`, `--challenge`, `--frames`, and receipts.
- **A receipt** is the JSON output of a check the reader cannot run: `{ "head": "<commit>", "pass": true, "measured": "<one line>", "plant_caught": true }`. Pass one as `--receipt <row id>=<file>` or put `<row id>.json` files in a folder and pass `--receipts <folder>`. The row names the command that writes its receipt (`producer`) and the fault that check must catch (`plant`). A receipt for another head is no data. A passing receipt that does not say its planted fault was caught is void, because a check nobody has seen fail decides nothing.
- **A sitting row** is a thing only Andrew can judge: feel, fun, taste, by-ear sound, real hardware. There is one for each area. It is listed under the table, never graded, and never counted as passed.

A missing input is "no data" and blocks, so the read starts NOT READY and each wave turns rows green. Rows whose producer says "not built yet" name the wave that builds them. The read never holds a wave promotion; it decides only the sitting build. Record its result in the gate receipt (published on `scratch/gate-receipts-*` when shared) and report it to the Mac Studio Gate session after each promotion.

## The node tests, once per promotion

The fast lane runs only the node tests a diff selects, and the shards run Godot tests. So once per promotion the Mac Studio Gate (or Linux `ahana` per [DEVICES.md](DEVICES.md)) runs the whole node suite on a full clone with an ordinary user and installed packages (`scripts/gate/pc.mjs` runs this step automatically).

```
git fetch origin && git checkout --detach <head>
npm ci
SCRAPKEEP_WHOLE_TESTS=1 npm test
```

Pass means the last command exits 0 and its summary reads `# fail 0`. `SCRAPKEEP_WHOLE_TESTS=1` turns the box skips in `tests/preconditions.mjs` (as root, two tests; in a shallow clone, seven) into errors, so a pass cannot come from a box that skipped them. Skips that remain are tests with their own stated need (a Godot binary, for one) and do not fail the run. Record the summary lines (`# tests`, `# pass`, `# fail`, `# skipped`) in the gate plan receipt. A failure is a new red and blocks like any other (ruling ai); there is no ledger for node tests.

In a cloud worker, plain `npm test` should also read `# fail 0`, with up to 9 more skipped than on the Gate host. It is a useful check before a pull request that touches `scripts/` or `tests/`, and it does not replace the full-clone Gate run.

## When the head moves after the shards ran

A small fix can land on a frozen head (a re-pin, a text fix). Rows carry only for tests the change cannot reach:

```
node scripts/gate/carry.mjs <head the rows were read on>
```

Run it in a checkout of the new head. If any game file changed, nothing carries. Otherwise it lists the tests to run again: each changed test, and each test that reaches a changed file under `tests/` (a test that `extends` another runs its parent's checks; wave 31 promoted a red because one was carried). A change under `scripts/` is judged by hand.

## Before CLEAN

```
node scripts/gate/tally.mjs --plan artifacts/local/gate/w<N>-<head>-gate-plan.md
```

The plan's tally is a table headed `| Shard | Verdict |`, one row per shard: `tests FIRST-LAST`, `bots 1` to the last block of five, `bands A`, `bands B`, `bands C`, `red team <persona>`, and `weekly sweep` while the weekly list names any test. A verdict opens with `PASS` (`CLEAR` for the red team) or with `RED`; the shard receipt's verdict line is written that way, so copy it. The checker refuses CLEAN while a row is missing or empty, a verdict names no receipt, the test windows leave a gap in the list, the newest row for a shard does not open with PASS or CLEAR, the plan's file name gates a head other than the one checked out (the lists are counted in the checkout), a ledger row is past its review date, or the weekly sweep is missing or more than 7 days old. It also refuses unless a `| Check | Verdict |` table has a `node tests` row whose newest verdict opens with `PASS`, reads `N tests, 0 fail` with N above zero and names its receipt, for example `| node tests | PASS. 1506 tests, 0 fail. Receipt node/summary.txt |`; a hand-written plan adds that table too. When a shard is read again on a moved head, add a new row under a new table; the newest row for a name wins.

## Check speed and honesty

Andrew, 15 Nov 2026: make the checks as fast as they can be without letting them lie. Two rules outrank speed. Everything runs before anything reaches `main`. A check never gets faster by hiding a failure: no retry that decides a verdict, no wider time limit, no skipped test. Rulings dv to dy in [DECISIONS.md](DECISIONS.md) are the four decisions; the sections above still describe today's gate and change as each step below lands.

The audit behind this (15 Nov, wave 41 gate on `e2770d85`, 100 fast-lane receipts) is on board issue #1044. The gate took 3 h 53 min: bot tests one at a time 131 min, reruns of reds alone 57 min, the bot step waiting for the scheduler at load 8 of 32 threads 34 min, the fast lane run first only to name bot tests 14 min. The fast lane's median is 6 min and its 95th percentile 15 min.

Budgets. A step that runs over its budget is reported in the receipt, and the cause is fixed; the budget is not raised.

| Check | Budget | 15 Nov |
| --- | --- | --- |
| Fast lane, median | 5 min | 6 min |
| Fast lane, 95th percentile | 10 min | 15 min |
| Promotion gate on a green head, with the weekly list and every bot test | 1 h 45 min | 3 h 53 min without them |
| Waiting inside the gate (scheduler, slots, load) | 2 min | 34 min |
| A verdict for a fix commit after a red gate | 30 min | no verdict issued |

The order. Each step is one small pull request with before and after numbers from real runs, and none starts until the one before is green.

1. Gate schedule: weights from measured load so every step starts together, bot lanes filled longest first, windows cut by measured seconds, the bot test names taken without running the fast lane first.
2. The gate runs the weekly list and every bot test (ruling dw).
3. The gate posts its verdict on the tested commit and `main` requires it (ruling dv).
4. Retries stop deciding verdicts (ruling dx); skipped checks are counted and a skip not on the PC's expected list is red.
5. A fix commit gets its own verdict (ruling dy).
6. Fast lane: record width, slot wait and per-test start in the receipt; stop taking the width from the load at start; a selected test deferred by the budget is listed for the gate to prove it ran.
7. Test speed, family by family with a before and after compare of check lines: a fixed-frame-rate marker for tests that count ticks, one shared game for the tests whose body is under 2 s, the music trace run once.

## After promotion or milestone updates

On legacy staged promotions, `node scripts/wave-state.mjs --write` updated [STATE.md](STATE.md); under flat `main` mode (`ruling ep`), keep `Wave facts` accurate (`--direct` / manual update when a milestone closes; see `scripts/wave-state.mjs:359-387`) and fold passing test timings with `node scripts/sketch-fast.mjs --fold-timings <receipt-glob>`.
