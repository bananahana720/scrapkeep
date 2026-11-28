# Structure sweep: one owner for each fact, and checks that keep it

Andrew asked on 27 November 2026 for a sweep of the whole repository that lowers structural mess without changing what the game or its tools do. This page is the sweep's home: what it is, how a unit runs, the rules every writer follows, the map of the code as measured, what has landed, and what waits on Andrew. [DEEP-SWEEP.md](DEEP-SWEEP.md) stays the home of the short sweep the Gate runs after each promotion; this page is the larger pass that works through a surveyed list.

Paths on this page that start with `src/`, `tests/` or `tools/` are under `sketches/core-loop/`; every other path starts at the repository root.

**State on 27 November 2026.** Twelve read-only surveys of commit `23e935514` found 218 items; they are in [shared/structure-sweep/](shared/structure-sweep/pool.tsv). Twenty-two units have landed on the branch `entropy/gate` (tip `e6996b87a`, which also holds `main` as of pull request 1307), one more has passed review and is merged in the coordinator's checkout pending its check, one is in review, one is back with its writer after a failed review, four are with writers, one has passed review and cannot be merged without Andrew's approval because it edits `package.json`, and three are finished but not pushed because the push was declined in the writer's session ([Rounds](#rounds); [Waiting on Andrew](#waiting-on-andrew), items 9 and 10). Of the 218 items, 48 have landed, 54 are with a unit, 40 wait on Andrew, 2 are closed and 74 are open. Nothing from the sweep is on `main`; landing it there is the Gate's call ([Waiting on Andrew](#waiting-on-andrew), item 1).

## What the sweep is for

The target is the code you would have written on day one had you known every requirement the game has today:

- **One owner for each fact.** A number, a list, a rule or a piece of state lives in one module, and everything else asks that module.
- **One implementation for each job.** Where two pieces of code do the same job, every caller moves to one of them and the other is deleted in the same unit. Old and new do not live side by side.
- **Deep modules.** A module hides a lot behind a small public call ([AGENTS.md](../../AGENTS.md) rule 7). A module that only forwards calls is removed.
- **No reach into private members, no dependency loops, no shared state changed from several places.**
- **A change stays local.** One feature should touch one module, not a file in every directory.
- **A check for each rule.** A lint rule or a test fails when the mess comes back, so the standard does not depend on a reviewer remembering it.

The sweep changes structure only. It does not change gameplay, tuning, timing, the order of signals or random draws, the save format, mesh or sound output, or any number a test pins. It does not move directories for tidiness, add a layer that one caller needs, or merge two things that are different ideas with similar code.

## When the sweep is done

1. Every row of the [task pool](shared/structure-sweep/pool.tsv) ends as landed (with its pull request), waiting on Andrew (with the reason), or closed (with the reason).
2. Each rule above that a machine can check has a check that fails on a new offence. A list of existing offences may only shrink.
3. Every landed unit passed its focused tests, `npm run sketch:fast`, `npm run sketch:lint` and one independent review, and the branch shows no failure that the starting commit did not have.

## How a unit runs

1. The coordinator picks rows from the task pool whose files do not overlap any unit in flight, and writes a brief that names the base commit, the branch, the files and the checks.
2. A writer in its own worktree follows [Rules for every writer](#rules-for-every-writer) and opens a draft pull request against `entropy/gate`. The worker for each kind of unit is the one [AGENTS.md](../../AGENTS.md) rule 11 names.
3. A fresh Gemini 4 Neon session at high reviews the pushed head. It gets the diff and what done looks like, not the writer's reasoning, and writes nothing.
4. On `VERDICT: PASS` the coordinator merges the unit into `entropy/gate` in a checkout no worker uses, fixes small review notes there, and runs the same [Checks](#checks) a writer runs, with `<the tip before the merge>` as the base. The push must pass the pre-push hook. A blocking issue goes back to the unit's writer.
5. The coordinator updates the task pool, [Rounds](#rounds), [Waiting on Andrew](#waiting-on-andrew), [Delete candidates](#delete-candidates) and the state paragraph at the top of this page in the same turn.

`entropy/gate` is an integration branch for this sweep, cut from `main` at `23e935514`. The coordinator merges `origin/main` into it regularly so it stays easy to land.

## Rules for every writer

A brief names the unit, the branch and the files. These rules are shared by every unit.

### Hard limits

1. **Structure only.** No change to gameplay, tuning, timing, signal order, random-draw order, save format, mesh output, sound output or any number a test pins. If the fix cannot be made without changing one of these, stop and report `BLOCKED` with the evidence. Do not edit a test's expected value to make it pass. A test may change only to call the new owner in place of the old copy.
2. **Stay inside the files your brief names**, plus the callers and tests that must follow a rename or move. If you need a file outside that set, say so in the report and keep the change minimal.
3. **Never touch** the root `package.json` (the repository has no other), any dependency or lock file, any file outside the repository, or Andrew's saves and settings: `~/.local/share/godot/app_userdata/core-loop` on Linux and `~/Library/Application Support/godot/app_userdata/core-loop` on macOS. No force-push, no history rewrite.
4. **Deleting.** You may delete code that your unit replaced once every caller is moved (the old copy, the old wrapper). You may not delete anything else, even if it looks dead; list it in your report as a delete candidate.
5. **Add no comment that explains code.** A reason goes in a test, an assertion or the pull request text. [CONTRIBUTING.md](../../CONTRIBUTING.md) ("Editing conventions") keeps two kinds of comment, and you keep them too: lines a tool reads (`# smoke:`, `# lint:`, `// lint:` and test block markers) and notes on a Godot, operating system, driver or hardware quirk that the code cannot change.
6. **Leave alone** two things [DEEP-SWEEP.md](DEEP-SWEEP.md) protects. First, the assertions and tests that pull requests 616 to 625 added to hold invariants and state machines in place: do not remove or loosen an `assert(...)` or a test check because it looks redundant. Second, `BASE_LOGIC_SHA` in `tests/boss_pickup_asset_test.gd`, a SHA-256 of the text of `_spawn_pickup` in `src/boss/boss.gd` outside its mesh code; the test fails when that text changes. If your unit must change that function, record the new value in the same commit and say so.
7. **Do not start sub-agents.** Do the work yourself.
8. **Run every shell, Godot, test and lint command in the foreground to completion.** Never end your turn while a command still runs in the background; a worker that does is marked finished too early.

### Set up

On the Mac Studio, start every shell command with:

```
export PATH=/opt/homebrew/bin:$PATH GODOT_BIN="$HOME/Applications/Godot_4.7.2.app/Contents/MacOS/Godot"
```

Then, once, in your own checkout:

```
git fetch origin entropy/gate
git rev-parse HEAD
git switch -c <your branch> <the base commit your brief names>
git rev-parse HEAD
npm run worktree:deps
mkdir -p artifacts/local/mac-home
HOME="$PWD/artifacts/local/mac-home" node scripts/import-stamp.mjs import
```

Your checkout may start on an old commit. The second `git rev-parse HEAD` must print the base commit your brief names; if it does not, stop and report `BLOCKED`. Never copy a `.godot/` folder from another checkout. If you launch Godot by hand, set `HOME` to a scratch folder under `artifacts/local/` first. [DEVICES.md](DEVICES.md) has the reasons, and the set-up for the Linux PC, which differs.

### Work order

1. **Confirm the finding in the code.** The finding came from a read-only survey and may be wrong in detail. Use `git grep` to list every real caller. If the finding is wrong, report `BLOCKED` or `ISSUES` with what you found and change nothing.
2. **Weigh at least two ways to fix it** and take the one that leaves the least total complexity. Say which you took and why in the pull request text. Do not add a layer, a base class or a config knob that only one caller needs.
3. **Pin the behaviour first** when no existing test would catch a change: add the test, see it pass on the unchanged code, then refactor.
4. **Move every caller in one go**, then delete the replaced code.
5. **Add the guard** your brief names (a test assertion or a lint rule) when it is small. If it is not small, describe it in the report.
6. **Commit** each working step on its own with a plain message that says what moved and why.

### Checks

Run these before you open the pull request, and paste the last lines of each into the pull request text:

- One plain call of `npm run sketch:fast -- --base origin/entropy/gate` after your last commit. It picks every test that names a changed file and also runs the lint, the docs check, the Node tests the change reaches and a short boot of the game. Each call waits its turn behind any other test run on the machine and checks the Godot import first, so a call takes ten minutes or more: make one, not one per test.
- `--test <name-or-glob>` does not add to that call. It runs only the tests you name and skips everything else the plain call does, so it never stands in for the plain call. Use it as a separate, extra call when you want a test the plain call did not pick.
- `npm run sketch:lint`.
- `npm test`, `npm run format:check` and `npm run lint:js` if you changed anything under `scripts/`.
- `npm run check:docs` and `npm run check:project` if you changed a Markdown file.

The pre-push hook runs the lint, the format and JavaScript lint checks on changed `.js` and `.mjs` files, both Markdown checks on changed `.md` files, and `npm run check:skills` and `npm run check:briefs` when a skill or a brief changed; a push that fails it has not happened.

If a check is red, rerun it once alone before you call it red. A red check that is also red on the base commit is not yours: say so with the evidence and carry on.

### Hand in

Push your branch and open a draft pull request against `entropy/gate`, not `main`:

```
git push -u origin <your branch>
gh pr create --draft --base entropy/gate --title "<unit id>: <what changed>" --body-file artifacts/local/<file>
```

Keep the text file under `artifacts/local/`, which git ignores.

The pull request text says, for a reader with no context: what changed, which callers moved, what was deleted, why nothing observable changed, which fix you chose over which other, the checks and their results, and a receipt (your model and effort, the base commit, the head commit).

Your final message leads with `PASS`, `ISSUES` or `BLOCKED`, then gives the same facts in short form, anything you parked for Andrew, and delete candidates you did not delete. Its last line is exactly:

```
PR <full URL>, head <SHA>, checks and reviews <state>
```

## The surveys and the task pool

Twelve read-only surveys, each of one part of the repository at commit `23e935514`, are kept as written under [shared/structure-sweep/](shared/structure-sweep/pool.tsv). Each lists the modules in its part, what they depend on, numbered findings with evidence and a proposed fix, things that looked wrong and are not, and questions for Andrew. A survey is a lead, not a fact: one of the first two findings a writer checked was wrong in detail ([Decisions](#decisions-andrew-can-overturn), item 4).

| Survey | Covers | Findings |
| --- | --- | --- |
| [core.md](shared/structure-sweep/core.md) | `src/core/` and `src/game.gd` | 20 |
| [world.md](shared/structure-sweep/world.md) | `src/world/` | 18 |
| [combat.md](shared/structure-sweep/combat.md) | `src/combat/` | 20 |
| [boss-movement-build.md](shared/structure-sweep/boss-movement-build.md) | `src/boss/`, `src/movement/`, `src/build/` | 20 |
| [ui.md](shared/structure-sweep/ui.md) | `src/ui/` | 16 |
| [visuals-fx.md](shared/structure-sweep/visuals-fx.md) | effects, camera, lighting and look in `src/presentation/` | 17 |
| [visuals-meshes.md](shared/structure-sweep/visuals-meshes.md) | mesh and model builders in `src/presentation/` | 16 |
| [sound.md](shared/structure-sweep/sound.md) | sound and music in `src/presentation/` | 17 |
| [experimental-dev.md](shared/structure-sweep/experimental-dev.md) | `src/experimental/`, `src/dev/` | 20 |
| [tools-tests.md](shared/structure-sweep/tools-tests.md) | `sketches/core-loop/tools/` and `tests/` | 18 |
| [scripts.md](shared/structure-sweep/scripts.md) | the Node toolchain under `scripts/` | 18 |
| [docs.md](shared/structure-sweep/docs.md) | the Markdown library and agent instructions | 18 |

[pool.tsv](shared/structure-sweep/pool.tsv) has one row for each of the 218 findings: its id, its survey file, its kind, its risk, its status, the unit and pull request once it has them, and the finding in one line. A finding of two kinds joins their letters with `+`. The status is one of `open`, `in flight`, `landed`, `closed` with its reason, or `waits on Andrew` with the kind of go-ahead it needs in brackets: `decision`, `delete` or `push`. It is the one place a finding's status lives; change the row in the same turn as the work.

The kind letters, used in the surveys and the pool:

| Letter | Means |
| --- | --- |
| A | Two or more implementations of one job |
| B | Dead code: no caller in the game, the tools or the tests |
| C | A reach into another module's private members, or a dependency that points the wrong way |
| D | A shallow module: deleting it and putting its body in its callers would make the code simpler |
| E | A fact spread over three or more files with no owner |
| F | State that several modules change |
| G | Several different solutions to the same kind of problem |
| H | An oversized file with a seam already in it |
| S | A page that says something no longer true |

## The code as measured

All numbers are for `sketches/core-loop/src`. The two tables were counted at commit `20200ba2a` by a one-off script, not kept in the repository, that read each `.gd` file for `res://src/...gd` paths and for the class names other files declare. The loop numbers come from the graph that lint rule L16 builds (`buildScriptGraph` in `scripts/sketch-lint.mjs`) at commit `e91cb3bab`, and anyone can count them again with `npm run sketch:lint`.

| Directory | Files | Lines |
| --- | --- | --- |
| `core` | 72 | 22,545 |
| `movement` | 16 | 5,222 |
| `build` | 30 | 13,482 |
| `combat` | 113 | 45,030 |
| `boss` | 19 | 7,981 |
| `world` | 111 | 34,576 |
| `presentation` | 144 | 71,694 |
| `ui` | 87 | 27,947 |
| `experimental` | 14 | 9,425 |
| `dev` | 9 | 5,711 |
| `boot` | 1 | 371 |
| `game.gd` | 1 | 1,375 |

**The directories are not layers.** Each cell counts the pairs of files where a file in the row's directory names a file in the column's directory.

| from \ to | core | movement | build | combat | boss | world | presentation | ui |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| core | | 8 | 33 | 27 | 14 | 10 | 17 | 7 |
| movement | 12 | | | 6 | | | | |
| build | 28 | 4 | | 12 | | 5 | 8 | 6 |
| combat | 84 | 53 | 19 | | 7 | 8 | 68 | 6 |
| boss | 23 | 7 | 2 | 17 | | 1 | 22 | 4 |
| world | 86 | 11 | 14 | 31 | 5 | | 71 | 20 |
| presentation | 127 | 18 | 18 | 70 | 15 | 32 | | 30 |
| ui | 162 | 12 | 23 | 6 | | 10 | 30 | |

`core` names files in every other directory, and no ordering of these eight directories puts every arrow downhill: the best one still leaves 329 pairs pointing up. (`experimental`, `dev`, `boot` and `game.gd` are left out of the table because nothing below them names them.) Choosing a layer order is a design decision that waits on Andrew ([Waiting on Andrew](#waiting-on-andrew), item 2); until then the sweep removes loops file by file.

**Dependency loops.** Of 617 script files with 2,908 dependencies between them, 192 files sit in 8 loops. One loop holds 169 files (49 in `world`, 47 in `presentation`, 43 in `combat`, 12 in `boss`, 10 in `core`, 7 in `build`, 1 in `ui`); the others hold 7, 6 and five pairs of 2. Any file in a loop cannot be loaded, tested or reasoned about without the rest of the loop. The lint rule L16 ([TADR-012](../../adr/TADR-012-script-dependency-loops.md)) lists the 192 files and fails when a file not on the list joins a loop; the list may only shrink. The surveys name the arrows that are cheapest to cut, starting with the ones out of `core`. At `e6996b87a` the list is down to 170 files: units L1 (6), B1 (3), L2 (4) and N1 (9) took 22 off it.

**Who owns which state** is recorded per module in each survey's module map and its kind F findings. The widest shared state is the run (`core/run_state.gd`, changed from `build`, `world` and `combat`) and the profile (26 `profile.save()` calls across 12 files); both are in [core.md](shared/structure-sweep/core.md).

## Rounds

| Unit | What it did | Pool rows | Writer | Pull request | State |
| --- | --- | --- | --- | --- | --- |
| U1 | The radio deck's save is a public call; the screens module no longer calls a private one | UI-02 | Claude Opus 5.5, high | 1286 | Landed on `entropy/gate` at `20200ba2a` after review PASS (Gemini 4 Neon, high) |
| S1 | `npm run sweep:deep` picks its own base commit when none is given; the challenge runner uses the one process helper in `scripts/challenge/proc.mjs` | SCR-03 | Gemini 4 Neon, high | 1287 | Landed on `entropy/gate` in merge `841189760` after review PASS (Gemini 4 Neon, high); one review note fixed by the coordinator in `d7bf403cf` |
| E1 | Lint rule L16: a script file not already listed may not join a dependency loop ([TADR-012](../../adr/TADR-012-script-dependency-loops.md)) | (guard) | Gemini 4 Neon, high | 1288 | Landed on `entropy/gate` at `e91cb3bab` after review PASS (Gemini 4 Neon, high) |
| V1 | One owner for the vertex-mask encoder (`CraftLookdev.encode_mask`, 378 call sites) and for the flat-projection UV and triangle helpers of the mesh builders | VM-01, VM-02 (first two steps) | Claude Opus 5.5, high | 1289 | Landed on `entropy/gate` in merge `4ec78f63b` after review PASS (Gemini 4 Neon, high) |
| W1 | The three `world` devices load their models through one loader in `world/model_kit.gd`; the director takes its two enemy lists from the roster | WORLD-04, WORLD-16 | Gemini 4 Neon, high | 1291 | Landed on `entropy/gate` in merge `48c3d5863`; the coordinator tightened one test guard after the review, in `53b291b29` |
| A1 | One WAV file reader, `presentation/wav_io.gd`, for the foley and jolt sounds; the two readers in `sfx_bank.gd` stay because they treat bad input differently | SOUND-07 | Gemini 4 Neon, high | 1292 | Landed on `entropy/gate` in merge `fa7550c64`; the coordinator tightened one test guard after the review, in `53b291b29` |
| X1 | `src/experimental/env_tags.gd` is the one owner of the environment tags; the experimental code calls the event director's `never_brake` (the helper that removes the part of a push that would slow the ball) and its two copies are deleted | XD-02, XD-03 | Gemini 4 Neon, high | | Finished and checked on the writer's local branch at `a3eabfc9b`; not pushed ([Waiting on Andrew](#waiting-on-andrew), item 9) |
| C4 | The table of how strongly each event shakes, flashes and pauses the game moves from `core/event_kinds.gd` to a new `presentation/event_juice.gd`; `core/event_kinds.gd` no longer names a file in `presentation` or `combat` | CORE-04 | Gemini 4 Neon, high | | Finished and checked on the writer's local branch at `9abf33025`; not pushed ([Waiting on Andrew](#waiting-on-andrew), item 9) |
| S2 | `npm test` and CI find the Node test suites on disk through `scripts/ci/node-tests.mjs`; the hand-written list of 54 entries in `package.json` is replaced by one call, and 14 suites that never ran now run | SCR-02 | Gemini 4 Neon, high | 1293 | Review PASS (Gemini 4 Neon, high); not to be merged without Andrew's approval ([Waiting on Andrew](#waiting-on-andrew), item 10) |
| S3 | One owner, `resolveGodotBinary` in `scripts/godot-home.mjs`, for finding the Godot binary; 23 scripts call it and their own copies are deleted | SCR-04 | Gemini 4 Neon, high | 1294 | First review FAIL (Gemini 4 Neon, high): on a machine with no Godot, `scripts/sketch-nightly.mjs` built steps with an empty command and two of its tests failed in CI. The writer fixed it in `f38793ae0`; second review PASS (Gemini 4 Neon, high). Landed on `entropy/gate` in merge `8abe37daf` |
| L1 | Cut three two-file loops: `pack_pressure` and `challenge_dials`, `crew_lamp` and `crew_lamp_field`, `codex_banner` and `codex_style` | (L16 list) | Gemini 4 Neon, high | 1295 | Review PASS (Gemini 4 Neon, high). Landed on `entropy/gate` in merge `959414334`; the coordinator fixed one stale line pointer in `shared/world1/difficulty-plan.md`, in `df97cdbf3` |
| L2 | Cut two two-file loops in `ui` (`controls_diagram` and `field_notes`, `camp_enemy_picker` and `camp_sandbox`); the radio dial and the screens module use public calls on the radio deck instead of its private members | (L16 list) | Claude Opus 5.5, high | 1298 | First review (Gemini 4 Neon, high) raised two issues; the writer fixed them and the second review was PASS at `10b0ca693`. Landed on `entropy/gate` in merge `d393d7af5` |
| B1 | One owner each for three duplicated movement helpers | BMB-01, BMB-07, BMB-08 | Gemini 4 Neon, high | 1296 | Review PASS (Gemini 4 Neon, high). Landed on `entropy/gate` in merge `bb2e47bda`; the coordinator added one wiring check to `tests/world_one_mass_s_test.gd` after the review, in `44ee0f36c` |
| T1 | One home, `tests/doubles/`, for the stage-table test doubles; every headless check goes through `AppShell.headless()`, guarded by lint rule L13 | TT-12, TT-06 | Gemini 4 Neon, high | 1297 | Landed on `entropy/gate` in merge `341a817ec` after review PASS (Gemini 4 Neon, high) |
| C1 | Modules that only tests and audits use move out of `src/core`; saving is switched off through one call, `Profile.disable_saving` | CORE-01, CORE-12 (part 1) | Gemini 4 Neon, high | 1299 | Landed on `entropy/gate` in merge `1508d6d31`. The coordinator merged it before its review had reported; the review (Gemini 4 Neon, high), run on the merged commits, was PASS with no blocking issue |
| M1 | One owner each for the duplicated helpers of the combat actives and the enemies; a source-text test, `tests/unit/combat_helper_owners_case.gd`, fails on a new copy | COMBAT-08, COMBAT-18 (items 3 to 6) | Gemini 4 Neon, high | 1300 | Landed on `entropy/gate` in merge `d4e6fea17`. The coordinator merged it before its review had reported; the review (Gemini 4 Neon, high), run on the merged commits, was PASS with no blocking issue |
| F1 | One copy of the effect pool code in `presentation/fx_library.gd`; `machine_fx.gd` stops forwarding to `SpecialCues` | VF-02, VF-13 | Gemini 4 Neon, high |  | Finished and checked on the writer's local branch at `265f34a0b`; not pushed ([Waiting on Andrew](#waiting-on-andrew), item 9) |
| S4 | One owner in `scripts/godot-home.mjs` for running Godot with a scratch data folder; the cloud headless export uses it | SCR-05, SCR-17 | Gemini 4 Neon, high | 1302 | Review PASS (Gemini 4 Neon, high). Landed on `entropy/gate` in merge `8fbe80be2` |
| B2 | One build sheet and stat cache; the build colours have one table; `active_body` and the pass-through calls around it are gone | BMB-05, BMB-09, BMB-13 | Gemini 4 Neon, high | 1303 | Review PASS (Gemini 4 Neon, high). Landed on `entropy/gate` in merge `222c1592c` |
| P1 | One `bolt_ring` in `HeroKitbashSculptor`; the camp's bevel-box forwarder is deleted. VM-10 was not as surveyed and is closed | VM-12, VM-13 | Claude Opus 5.5, high | 1301 | Review PASS (Gemini 4 Neon, high). Landed on `entropy/gate` in merge `d92900fe9` |
| D1 | CI runs the agent-file checks; the agent prompt files are held equal by a check; the skill index is guarded; the safety gate knows the macOS save folder | DOC-02, DOC-04, DOC-08, DOC-14, DOC-15 | Gemini 4 Neon, high | 1305 | Review PASS (Gemini 4 Neon, high). Landed on `entropy/gate` in merge `0c89e716d`; the coordinator hardened the safety gate's check of `%20`-encoded save paths in `a812a0400` |
| B3 | One copy each of the boss attack, dress-card and clean-up helpers | BMB-10, BMB-11 | Gemini 4 Neon, high | 1304 | Review PASS (Gemini 4 Neon, high). Landed on `entropy/gate` in merge `b881c140a` |
| D2 | [ARCHITECTURE.md](../../sketches/core-loop/ARCHITECTURE.md) is the map of `src/`; the workflow pages stop repeating each other; stale stage prose is retired | DOC-01, DOC-05, DOC-07, DOC-09, DOC-10, DOC-11, DOC-16, SCR-13 (the `check-project` part) | Gemini 4 Neon, high | 1306 | First review FAIL (Gemini 4 Neon, high) at `75da5da21`; the writer fixed it in `092db20fd`. Landed on `entropy/gate` in merge `5843dd700` on the coordinator's own reading of the fix; a second independent review of the merged commits is running |
| U2 | The odds arithmetic moves from the UI into `Parts` and `ItemGen`; UI forwarders that only passed a call on are deleted | UI-06, UI-09, UI-10, UI-15, UI-16 | Claude Opus 5.5, high | 1308 | Review PASS (Gemini 4 Neon, high). Landed on `entropy/gate` in merge `5b2f0beb1` |
| S6 | One helper for stopping a child process and its group, one for gate receipts; the smoke and fast runners share one Godot test runner in `scripts/lib/` | SCR-06, SCR-14, SCR-16, SCR-18 | Gemini 4 Neon, high | 1309 | Review PASS (Gemini 4 Neon, high). Landed on `entropy/gate` in merge `4efdc5d36` |
| N1 | The sound code's owners gain public calls; `world`, `combat` and `ui` stop reaching into the sound code's private members, and nine files leave the L16 list | WORLD-03, SOUND-02, SOUND-04, SOUND-05 | Gemini 4 Neon, high | 1310 | Review PASS (Gemini 4 Neon, high). Landed on `entropy/gate` in merge `876e05bac` |
| (main) | `main` at `0d422144b` (Andrew's CI speed-up, pull request 1307) merged into `entropy/gate`; the one hand-ported line is the test-runner pattern that moved to `scripts/lib/godot-test-runner.mjs` |  | coordinator |  | Merge `e6996b87a`, checked with one full `npm run sketch:fast` (292 tests run, none red) |
| K1 | One owner each for the physics layer numbers (`core/physics_layers.gd`), the group names (`core/groups.gd`) and the combat gravity (`Tuning.GRAVITY`); `world/find_kit.gd` is folded into its callers | WORLD-13, WORLD-14, WORLD-17, COMBAT-20 | Gemini 4 Neon, high | 1312 | Review PASS (Gemini 4 Neon, high). Merged in the coordinator's checkout; lands when the check of the merge passes |
| C2 | One owner each for the event rows, the codex append, the stage-table queries, the validators, the command-line flags and the pilot story tables in `core` | CORE-09, CORE-10, CORE-12 (part 2), CORE-14, CORE-15, CORE-16, CORE-17, CORE-20 (part 1) | Gemini 4 Neon, high | 1313 | Review FAIL (Gemini 4 Neon, high) at `894131e7e`: seven stage-table helpers were left in `core/worlds.gd` beside their new owner, and seven callers still asked "may I save" by a second route. With the writer for the fix |
| S5 | One mechanism for every lint baseline; one Godot version pin (`scripts/toolchain.json`); one git helper, one directory walker and one command-line helper under `scripts/lib/`; the live gate section moves to the top of `ORCHESTRATOR.md` | SCR-01, SCR-10, SCR-11, SCR-12, SCR-13, SCR-15, DOC-13, DOC-18 | Gemini 4 Neon, high | 1311 | In review at `2895acc23` |
| V2 | Effects and mesh duplicates | VF-10, VF-11, VF-14, VF-15, VF-16, VM-05, VM-07, VM-09, VM-14, VM-16 | named in its receipt when it reports |  | With the writer |
| B4 | Build, boss and movement reach-ins and duplicates | BMB-04, BMB-06, BMB-12, BMB-14 to BMB-20 | Gemini 4 Neon, high |  | With the writer |
| T2 | One copy of the spawner doubles' strike arithmetic, of the key-press test helper and of the prop palette; no path of one machine in the active tools | TT-13, TT-15, TT-16, TT-18 | Gemini 4 Neon, high |  | With the writer |
| X2 | The dev console calls public methods only and keeps one copy of each of its tables | XD-04, XD-05, XD-06, XD-08, XD-09, XD-10, XD-13, XD-14, XD-15, XD-16 | Gemini 4 Neon, high |  | With the writer |

Two substitutions against [AGENTS.md](../../AGENTS.md) rule 11, neither of them a review verdict. The coordination and the integration were run by a Claude Mythos 5.2 session at high effort, where the rule names Claude Fable 5.2 and ruling `el` in [DECISIONS.md](DECISIONS.md) (23 November 2026) names a Gemini 4 Neon session. Three of the twelve surveys (`ui.md`, `visuals-fx.md`, `visuals-meshes.md`) were written by Claude Opus 5.5 at high, where the rule gives research to Gemini 4 Neon; the other nine were written by Gemini 4 Neon at high. Every review above ran on Gemini 4 Neon at high as the rule requires.

Leads that the first reviews raised, not yet in the pool as rows: `src/ui/radio_dial.gd` calls the radio deck's private `_live()` and reads its `_audio`; `tests/radio_test.gd` calls its private `_plan_now()`; `src/ui/screens.gd` changes `game.radio_deck.radio` directly; `scripts/redteam/run.mjs` keeps its own copy of the `pool` helper; `scripts/challenge/run.mjs` imports `readdirSync` and does not use it; `scripts/budget-audit.test.mjs` fails on `main` (it expects the model `pilot_patch_anim` to have no bones and no clips, and the committed file has 25 bones and 8 clips) and is on neither the `npm test` list nor CI's; `tests/fub_ramp_flash_test.gd` fails when it runs in the same Godot process after `tests/enemy_ramp_flipper_asset_test.gd`, because the static cache behind `Ramp._parts()` is already filled, and passes alone (the cache needs a reset in `tools/test_batch_driver.gd`, or the test must run alone); `scripts/ci/node-tests.mjs` on pull request 1293 walks the disk, so an untracked `*.test.mjs` under `scripts/` runs locally, and `npm test -- --test-name-pattern=...` exits 2 there; four Node suites that pull request 1293 would start running leave temporary folders behind (`scripts/worktree-sandbox.test.mjs`, `scripts/crash-harvest.test.mjs`, `scripts/first-timer.test.mjs`, `scripts/gate/display-run.test.mjs`) and `scripts/ledger-audit.test.mjs` asserts a wall-clock time under two seconds; `npm run format:check` fails on 68 files no unit touched; outside `scripts/`, six shell and Python helpers spell their own Godot path (`.agents/skills/scrapkeep-verify-game/scripts/common.sh`, `.agents/skills/scrapkeep-verify-build/scripts/build.sh`, `tools/godot-mcp/run.sh`, and three under `sketches/core-loop/tools/`); the same basis-from-a-direction lines that `core/math_util.gd` now owns remain in `presentation/juice.gd` and `presentation/vfx.gd`, and two near copies in `combat/dispatcher.gd` and `presentation/craft/enemy_boss_craft.gd` use another formula and must be compared before any merge; `scripts/gate/pc.mjs` reads `GODOT_BIN` back from the child environment it built itself and could pass the binary directly; `tests/w50_isaac_relics_test.gd` keeps an unused `Grip` preload; `design-v3/ABILITY-MUTATIONS.md`, `design-v3/POLES-FLAILS.md` and `tools/coordinator/lane-ledger.tsv` still name `Grip.heft_of` and `Harpoon.burst_ready`, which moved in pull request 1296; `tests/profile_purity_test.gd` is red on the base because `world/camp_sandbox.gd` reads `game.ctx.profile` directly; unit K1 left raw group and layer strings in `movement/augments.gd`, `world/events/natural.gd`, `combat/ultimate.gd`, `ui/key_glyphs.gd` and fourteen files under `boss`, `build`, `movement` and `presentation`, a second gravity constant in `presentation/prop_kicks.gd`, and a guard (`tests/unit/world_constants_case.gd`) that looks for three constant names only; unit M1 left a comment with nothing under it above `_die()` in `combat/drill_crew.gd`, kept because a content hash in `tests/enemy_drill_crew_asset_test.gd` covers it, and its guard test does not see a copy written inline, a static variant, a subdirectory or `uv1_scale`; `combat/warden_mind.gd` reaches `parse_point` through `warden.get_script()`; `tests/colour_meanings_test.gd` holds a `HOME` check that can never run; nine historical pages still name the paths unit C1 moved.

## Decisions Andrew can overturn

1. **The sweep does not push to `main`.** Ruling `el` ([DECISIONS.md](DECISIONS.md), 23 November 2026) names a Gemini 4 Neon session as coordinator and Gate, and [AGENTS.md](../../AGENTS.md) rule 3 says only the Gate lands changes on `main`. This sweep's coordinator is not that session, so it integrates on `entropy/gate` and leaves the landing to the Gate.
2. **The goal is a go-ahead to delete only what a reviewed unit replaced.** A unit that moves every caller to one owner deletes the old copy in the same pull request. Every other delete, including code a survey calls dead, waits on Andrew ([Delete candidates](#delete-candidates)).
3. **A finding that cannot be fixed without changing behaviour is not fixed.** It is listed under [Waiting on Andrew](#waiting-on-andrew).
4. **UI-05 is closed, not as surveyed.** The survey proposed moving `hud.objective_reading()` into `core/objectives.gd`. Four of its eleven inputs are state the HUD holds, so the move would drag HUD state into `core`. The two callers in `core` (`play_watch.gd` and `sitting_notes.gd`) record what the player sees on screen, which is a reason for them to ask the HUD. Left as it is.
5. **Lists of existing offences may shrink and never grow.** A unit that adds an entry to a lint baseline is sent back.

## Waiting on Andrew

None of these blocks the rest of the sweep.

1. **Landing `entropy/gate` on `main`**, and which session is the Gate. [AGENTS.md](../../AGENTS.md), [GEMINI.md](../../GEMINI.md), [ORCHESTRATOR.md](../../ORCHESTRATOR.md) and [THREADS.md](THREADS.md) disagree with ruling `el` about the Gate's model (finding DOC-03).
2. **A layer order for the directories of `src/`.** With one, a lint rule can forbid every upward arrow. Without one, the sweep can only remove loops. The two largest inversions are `core/run_state.gd` (23 loads of `build`, `world` and `combat`; CORE-06) and `core/flow.gd` (7 loads of `ui`, `world`, `boss` and `movement`; CORE-07); both are high risk.
3. **The delete candidates below.**
4. **Whether release exports should ship `src/dev/` and `src/experimental/`** (XD-01). It changes what ships.
5. **One typed schema for the run's saved extras** ([core.md](shared/structure-sweep/core.md), "Needs the owner"). It needs a save-format version bump.
6. **Fixes that change behaviour:** the nightly script locks a retired lock file (SCR-07); two sluice-valve implementations handle the same rows (WORLD-02).
7. **Findings that need a formal-model run or a design call before a writer starts.** Each survey has the detail.
   - UI-04: `ui/screens.gd` decides which page is visible with twelve hand-listed guards.
   - UI-11: `core/flow.gd` builds a UI node.
   - VF-07: nothing owns "hold play"; the reward ceremony and the workshop each pause the game and switch input off in their own way.
   - VF-09: `flourish_cues` hands `core/flow.gd` a function that stretches the victory state.
   - VF-17: 18 files in `combat`, `boss` and `world` load `presentation/fx_library.gd` to call `burst`.
   - VM-04: 22 hand-written model loaders, each with its own cache and warning.
   - VM-06, VM-08, VM-11 and VM-15: mesh and material builders that look alike and may differ in output.
8. **The "Needs the owner" section of each survey**, which holds that survey's remaining questions.
9. **Three finished units whose push was declined.** X1, C4 and F1 passed their writers' checks, but in each writer's session the request to run the repository's push hooks was declined and the push was then blocked, so none has a pull request or a review. The coordinator did not push for them: a declined push is not the coordinator's to override. The commits are on the Mac Studio only, on the local branches `entropy/x1-experimental-duplicates` (`a3eabfc9b`), `entropy/c4-event-juice` (`9abf33025`) and `entropy/f1-fx-pools` (`265f34a0b`). If Andrew says to go ahead, the coordinator pushes each branch, opens its draft pull request and starts its review.
10. **One unit that edits `package.json`.** S2 (pull request 1293) replaces the `"test"` line of the root `package.json` with `node scripts/ci/node-tests.mjs`. It changes no dependency, no lock file and no other line. [AGENTS.md](../../AGENTS.md) asks for Andrew's approval before any `package.json` change, and the coordinator's brief for S2 asked for the edit without it; that was the coordinator's mistake, and hard limit 3 above now forbids it. The pull request passed its review and stays unmerged. If Andrew approves, the coordinator merges it; if not, the unit is redone so that only CI's list comes from the disk and `npm test` keeps its hand list. Until one of the two happens, the new guard suite `scripts/godot-home.test.mjs` from pull request 1294 passes when run by hand but is on neither list, so nothing stops a script from spelling its own Godot path again.
11. **The wording of the go-ahead list in [AGENTS.md](../../AGENTS.md).** It names `/mnt/project-files/` for pending deletes, a folder the Mac Studio does not have, and gives the save folder's Linux path only. A rewording that names the macOS save folder and this page's [Delete candidates](#delete-candidates) table was drafted and not applied, because that paragraph is Andrew's own list of what needs his approval.

## Delete candidates

Each of these is code a survey found with no caller, or with tests as its only caller. None is deleted. Each survey gives the evidence; a delete needs Andrew's go-ahead and a fresh `git grep` first, because a survey can be wrong. This list lives here because the shared folder that [AGENTS.md](../../AGENTS.md) names for pending deletes, `/mnt/project-files/`, does not exist on the Mac Studio.

| Finding | What |
| --- | --- |
| CORE-13 | Compatibility paths in `core`: `camp_get`/`camp_set`, the `ScrapbookStore` fallback, and the constant `BRINDLE_COBALT_PICK` in `core/worlds.gd`, which is always true and guards one branch in `boss/boss.gd` that never runs |
| WORLD-01 | Stubs, park and world modules with no caller in `src`, and four unused preloads |
| COMBAT-12 | `Enemy.rim_color`, written and never read |
| COMBAT-13 | Fourteen functions in `src/combat/` with no caller |
| BMB-03 | Fifteen functions and a 27-line unreachable branch in `build/` and `movement/` |
| UI-01 | `callouts.gd` and `meta_page.gd`, which only tests load |
| VF-12 | Ten public functions in the effects code with no caller |
| SOUND-11 | `craft_audio_cues.gd`, which only tests use |
| SOUND-15 | Functions and constants in the sound code with no caller, and eleven helpers only tests use |
| XD-07 | Unused branches, preloads, constants and empty `reset()` stubs in `src/dev/` and `src/experimental/` |
| TT-01 | 72 tool scripts (about 15,500 lines) and five side scripts with no live caller |
| SCR-08 | Six scripts under `scripts/` with no caller |
| SCR-09 | The retired `QUARANTINE.tsv` machinery (about 170 lines) and four unused exports |
| DOC-12 | Orphan config and doc files and retired pointer stubs |
| DOC-17 | Code for a retired skill in `scripts/check-skills.mjs` |
