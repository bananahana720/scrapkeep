"""Units of round 12, read by make-round.py. T4, Z3 and Z4 change the game's tree; G5 changes scripts only."""
POOL = "the task pool, `git show " + BASE + ":project-guide/handoff/shared/structure-sweep/pool.tsv`"
SURVEY = "`git show " + BASE + ":project-guide/handoff/shared/structure-sweep/"
NO_CALLER = (
    "**The caller search.** `scripts/no-caller.mjs` is on your base: `node scripts/no-caller.mjs <path> [<path> ...]` prints every tracked file that mentions each file given, "
    "leaves out mentions among the files given in the same call, and exits 0 for no mention, 1 for a mention and 2 when it could not search (treat 2 as a failure, never as a pass). "
    "Run it on every file before you delete it and put its output in your report. It searches for files, not for function names: for a function, a constant or a variable, search the whole repository for the name as a word "
    "(`git grep -n -w <name>`), and also for the name inside a string (`call(\"name\"`, `has_method(\"name\"`, `Callable(x, \"name\")`, a signal connection by name, a `.tscn` or `.tres` file). "
    "The script cannot see five things, so check each of them by hand for every file you delete: a path built from parts in code, "
    "a script that scans a folder and runs what it finds, a Python package run with `python -m`, a mention inside a binary file, and a generator whose only trace is the asset it once made "
    "(never delete the only script that can regenerate a file the game ships; keep it and say so)."
)
DELETE_RULES = (
    "For every item: confirm it in the code first, since the survey is two days old and several units have moved code since. If the name has moved to another file, follow it there. "
    "A name that only a test calls is dead when the test exists only to test that name: delete both. If the test checks something a player meets by way of that name, keep both and say so. "
    "When a deleted file or name is a row in a guard test's list or in `scripts/sketch-lint.baseline.json`, remove only that row. Delete each `.gd` file together with its `.gd.uid` file. "
    "Do not rename, move or tidy anything you keep: this unit only deletes. Leave alone the guards the page `project-guide/handoff/DEEP-SWEEP.md` names as kept on purpose, "
    "and do not change `sketches/core-loop/src/boss/boss.gd` inside `_spawn_pickup` (a test pins its text). "
    "Nothing a save file, a settings file or a receipt holds may change: a function that reads an old save field is a caller of that field, so keep it and say so."
)
OTHERS_GODOT = (
    "Other units are in flight. Stay inside the folders this brief names. One unit (pull request 1333) changes `load` lines in `sketches/core-loop/src/core/` and `tests/unit/core_upward_loads_case.gd`; "
    "one (pull request 1332) changes `sketches/core-loop/tools/test_batch_driver.gd`, `tests/test_tool_owners_test.gd`, `tests/test_batch_reset_test.gd`, `scripts/sketch-lint.mjs` and its test: touch none of those files. "
    "Three more units of this round run beside you: one moves the source reads of guard tests onto the shared reader (it changes how a guard reads, not what its lists hold), and the others delete dead code in the folders this brief does not name. "
    "If the integration branch moves while you work and your pull request conflicts, merge `origin/entropy/gate` into your branch; never rebase or force-push."
)
UNITS = {
    "T4": dict(
        branch="entropy/t4-source-guards-one-reader",
        findings="The row `LEAD-49` of " + POOL + ". Then read `sketches/core-loop/tests/support/source_scan.gd` and its proof `sketches/core-loop/tests/unit/source_scan_case.gd` on your base.",
        body=(
            "Many Godot tests enforce a rule by reading the game's source: \"only this file may declare that constant\", \"no file outside this folder calls that function\". "
            "Thirteen times in this sweep a reviewer found such a guard that passes when it reads nothing: the folder did not open, the file list was empty, the read came back empty, or the pattern did not compile. "
            "The shared reader `SourceScan` fails the test in each of those cases, and seven tests use it. On the base 317 test files call `FileAccess.get_file_as_string`, 107 of them on a literal `res://src` path, and 127 list a folder with `DirAccess`. "
            "This unit makes the shared reader the only way a test reads script source, in three parts.\n\n"
            "**Part 1, what the reader offers.** Today it has `matching(t, roots, pattern)` and `captures(t, roots, pattern)`, both over folders. Add only what Part 3's callers need, and no more. Two needs are known: "
            "reading one named script (`text(t, path)`, failing the test on an error or an empty read), and the declaration prefix that allows `static` and a same-line annotation, which `tests/unit/experimental_dev_seams_case.gd` holds today as its own constant `VAR_START`. "
            "Give the prefix one home in the reader and make that test use it. Every new call gets a case in `source_scan_case.gd` that shows it fail on a bad read. Keep the reader small: it reads and matches, and each guard keeps its own rule and its own list.\n\n"
            "**Part 2, a lint rule so a new guard cannot read by hand.** Add rule `L19` to `scripts/sketch-lint.mjs`, with a shrink-only list in `scripts/sketch-lint.baseline.json` as the other rules have (`BASELINE_RULES` in that file; read how `L14` to `L18` are built and tested, and build this one the same way). "
            "The rule: a script under `sketches/core-loop/tests/` other than `tests/support/source_scan.gd` reads a `.gd` script's text by hand. Weigh how to recognise that with few false alarms; at the least it must catch `FileAccess.get_file_as_string` or `FileAccess.open` given a literal path under `res://src`, `res://tools` or `res://tests` that ends in `.gd`, "
            "and a `DirAccess` listing of a literal folder under those three roots. A test that reads a data file, a scene, a picture or a receipt is not an offence. Say in the report what the rule matches, what it knowingly misses, and how many files it lists. "
            "The message of a finding names the fix: \"read script source through tests/support/source_scan.gd\". Add tests to `scripts/sketch-lint.test.mjs` in the style of the other rules, including one that the list cannot grow. "
            "The pull request 1332 named below also edits `scripts/sketch-lint.mjs` and its test (the `L14` and `L18` code): keep your change to new functions and one new entry in each table so the two merge cleanly.\n\n"
            "**Part 3, move the guards.** Move onto the reader every flagged file whose whole purpose is a source rule: the flagged `tests/unit/*_case.gd` files and the flagged `tests/*_owners_test.gd` and `tests/*_guard_test.gd` files. "
            "On the base those are about twenty files, among them `unit/sound_boundaries_case.gd`, `unit/ui_owners_case.gd`, `unit/mesh_fx_owners_case.gd`, `unit/world_constants_case.gd`, `unit/bmb_seams_case.gd` (it has its own `_read_src`), `movement_owners_test.gd`, `boss_owners_test.gd`, "
            "`dev_boundaries_owners_test.gd`, `craft_mesh_helper_owners_test.gd`, `presentation_random_guard_test.gd` and `pin_hash_guard_test.gd`. Do the first one by hand, then script the repeated shape if one emerges and commit the script under `sketches/core-loop/tools/` only if a later unit can rerun it; otherwise keep it out of the tree. "
            "For each file: it must report exactly what it reported before. Prove that by running the test before and after, and where a guard builds a list of findings, by printing the list both ways once. A moved guard holds no `FileAccess`, `DirAccess` or `RegEx.new()` of its own for script source, and its entry leaves the `L19` list. "
            "A test that reads source as one small step of a behaviour test stays as it is, on the list: do not widen this unit to all 107 files. Do not touch `tests/unit/core_upward_loads_case.gd`, `tests/test_tool_owners_test.gd` or `tests/test_batch_reset_test.gd`; other writers hold them."
        ),
        done="`npm run sketch:lint` passes with rule `L19` on and its list holding only files this unit chose to leave; every guard file named in Part 3 reads script source only through `SourceScan` and reports what it did before; the declaration prefix has one home; each new reader call has a failing-read case; and the report gives the `L19` count before and after Part 3.",
        flight=OTHERS_GODOT,
        checks=GODOT_CHECKS.format(base=BASE) + " Add `--test unit_suite_test` and one `--test <file name without .gd>` for each standalone guard test you moved to that one call. Also run `node scripts/ci/node-tests.mjs --shuffle` and `npx oxfmt -c scripts/ci/oxfmt.json --check scripts/sketch-lint.mjs scripts/sketch-lint.test.mjs`.",
    ),
    "Z3": dict(
        branch="entropy/z3-dead-code-combat-build-world",
        findings="Findings `COMBAT-12` and `COMBAT-13` in " + SURVEY + "combat.md`, finding `BMB-03` in " + SURVEY + "boss-movement-build.md` and finding `WORLD-01` in " + SURVEY + "world.md`.",
        body=(
            "This unit deletes game code that nothing calls in four folders: `sketches/core-loop/src/combat/`, `src/build/`, `src/movement/` and `src/world/`, with the tests that exist only for the deleted code. It changes nothing a player meets.\n\n"
            + DELETE + "\n\n" + NO_CALLER + "\n\n" + DELETE_RULES + "\n\n"
            "**Part 1 (COMBAT-13), fourteen functions under `src/combat/` with no caller, and (COMBAT-12) `Enemy.rim_color`, which is written and never read.** Since the survey a unit made several private combat functions public (`bolt_record`, `chain_hit`, `deal_hit`, `fire_line`, `detonate`) and moved helper calls into their owners: look for each listed function under its old and its new name.\n\n"
            "**Part 2 (BMB-03), fifteen functions and one unreachable fallback branch under `src/build/` and `src/movement/`.** Since the survey a unit split `parts.gd` into `part_offers.gd`, `part_mutations.gd`, `maker_defs.gd` and `relic_sync.gd`, and moved code from `player_ball.gd` into `kest_air.gd` and `speed_bank.gd`: follow each name to where it lives now. "
            "For the fallback branch, show why it cannot be reached (the condition that guards it and every place that sets what the condition reads) before you delete it.\n\n"
            "**Part 3 (WORLD-01), dead stubs, park and world modules that nothing under `src/` loads, and four unused preloads.** A module that only tests load is dead when those tests test only the module. An unused preload is a `const X := preload(...)` whose name appears nowhere else in its file; check that removing it does not break a dependency loop count in `scripts/sketch-lint.baseline.json` the wrong way (the `L16` list may shrink, never grow).\n\n"
            "Commit each part on its own. If a listed item has a caller, keep it and name the caller. If you find more dead code beside a listed item, delete it only when the same proof covers it, and list it apart in the report."
        ),
        done="every item the four findings list is deleted or kept with its caller named; no test was deleted that checks behaviour a player meets; `npm run sketch:lint` passes with no list grown; and the report gives, for each deleted name, the search that shows no caller.",
        flight=OTHERS_GODOT,
        checks=GODOT_CHECKS.format(base=BASE) + " Add `--test unit_suite_test` to that one call. If a model page under `.agents/skills/scrapkeep-verify-formal/references/` names a file you changed (`combat.gd`, `bolts.gd`, `event_director.gd`, `destructibles.gd`, `stage_locks.gd` and `overtime.gd` among them), say so in the report with the functions you deleted there; do not edit the model pages.",
    ),
    "Z4": dict(
        branch="entropy/z4-dead-code-ui-sound-dev",
        findings="Finding `UI-01` in " + SURVEY + "ui.md`, finding `VF-12` in " + SURVEY + "visuals-fx.md`, findings `SOUND-11` and `SOUND-15` in " + SURVEY + "sound.md`, finding `XD-07` in " + SURVEY + "experimental-dev.md`, and the rows `LEAD-53`, `LEAD-61` and `LEAD-63` of " + POOL + ".",
        body=(
            "This unit deletes game code that nothing calls in `sketches/core-loop/src/ui/`, `src/presentation/`, `src/dev/`, `src/experimental/` and the sound files wherever they live, with the tests that exist only for the deleted code, and one tool script. It changes nothing a player meets or hears.\n\n"
            + DELETE + "\n\n" + NO_CALLER + "\n\n" + DELETE_RULES + "\n\n"
            "**Part 1 (UI-01), `callouts.gd` and `meta_page.gd`, which only tests load.** Confirm nothing in the game, a scene or a tool reaches either. Delete each with its tests, and with any row a guard test holds for it.\n\n"
            "**Part 2 (VF-12), ten public functions in the visuals and effects files with no caller.**\n\n"
            "**Part 3 (SOUND-11 and SOUND-15).** `craft_audio_cues.gd` is loaded by tests only and overlaps `ExperimentalAudioBank`, which also carries texture specs only tests use; and the sound files hold dead functions, dead constants and eleven helpers on game classes that only tests call. "
            "Delete what is dead. For a helper on a game class that only a test calls: if the test checks sound a player hears, keep the helper and the test and say so; do not move helpers in this unit. No sound file under `assets/` changes, and nothing that names a bus, a cue or a stem changes.\n\n"
            "**Part 4 (XD-07 and LEAD-61), `src/dev/` and `src/experimental/`.** An unimplemented `complete_args`, the dead `contact_sheet_mode` and `contact_sheet` branches (in `dev_agent.gd` among others), an unused preload, unused constants and empty `reset()` stubs. An empty `reset()` that the test batch driver or a loop over modules calls is not dead: keep it. "
            "`dev_agent.gd` also uses `console.capture` without checking it exists: read what happens when it does not, and either show it cannot be absent or guard it, whichever is less code.\n\n"
            "**Part 5 (LEAD-53 and LEAD-63).** `sketches/core-loop/tools/cliff_gate_export.gd` has had no caller since the Python scripts that ran it were deleted: confirm and delete it with its `.uid` file. `tests/find_in_fight_test.gd` preloads `WhyCallout` and no longer uses it: remove the preload.\n\n"
            "Commit each part on its own. If a listed item has a caller, keep it and name the caller. If you find more dead code beside a listed item, delete it only when the same proof covers it, and list it apart in the report."
        ),
        done="every item the findings and rows list is deleted or kept with its caller named; no test was deleted that checks something a player meets or hears; `npm run sketch:lint` passes with no list grown; and the report gives, for each deleted name, the search that shows no caller.",
        flight=OTHERS_GODOT,
        checks=GODOT_CHECKS.format(base=BASE) + " Add `--test unit_suite_test` to that one call. If a model page under `.agents/skills/scrapkeep-verify-formal/references/` names a file you changed (`audio.gd`, `ace_sequencer.gd`, `music_arbiter.gd` and `melody_lease.gd` among them), say so in the report with the functions you deleted there; do not edit the model pages.",
    ),
    "G5": dict(
        branch="entropy/g5-git-through-one-helper",
        findings="The row `LEAD-51` of " + POOL + ". Then read `scripts/lib/git.mjs` and `scripts/lib/git.test.mjs` on your base.",
        body=(
            "This unit has two parts, both Node code under `scripts/`. It changes no file the game loads.\n\n"
            "**Part 1 (LEAD-51), one way to start git.** `scripts/lib/git.mjs` exports `git` and `gitOptional`. Both drop the variables git exports to a hook (`GIT_DIR`, `GIT_WORK_TREE`, `GIT_COMMON_DIR`, `GIT_INDEX_FILE`, `GIT_PREFIX`), so the `cwd` of the call decides which repository is read. "
            "A script that starts git itself keeps those variables, and inside the pre-push hook it has read the wrong repository twice in this sweep. On the base about forty files under `scripts/` and `tests/` start git with `spawnSync(\"git\"`, `spawn(\"git\"`, `execFileSync(\"git\"` or a shell string: list them with `git grep -n -E 'spawn(Sync)?\\(\\s*\"git\"|execFile(Sync)?\\(\\s*\"git\"|exec(Sync)?\\(\\s*[\"`]git ' -- scripts tests .agents project-guide`.\n\n"
            "Move each call in a script that is not a test onto the helper, keeping what the caller does with a failure (some callers treat a non-zero exit as an answer: `gitOptional` is for those; read both helpers before you choose, and add a small option to the helper rather than a second helper if one caller needs something neither gives). "
            "Three known exceptions, each to keep with its reason in the report: `scripts/ci/affected.mjs` (the CI job that runs it checks out only `scripts/ci` and `scripts/lib/cli.mjs`, so the helper is not on disk there; read `.github/workflows/ci.yml` to confirm), `scripts/lib/git.mjs` itself, and any script that must run before `node_modules` or the repository exists. "
            "For a test file that builds its own scratch repository, weigh moving it against leaving it: the risk is the same variables leaking in when the test runs inside a hook. Take the cheaper safe option and apply it the same way everywhere.\n\n"
            "Then add the check that keeps it so: one Node test (in `scripts/lib/git.test.mjs` or beside it) that lists every tracked `.mjs` and `.js` file which starts git by hand and compares the list with an exact allowed list in the test, so a new direct call fails with a message that names the helper. "
            "List the files with the helper (`git ls-files`), and make the test fail when the listing is empty. Show in the report that the test fails when you add a direct call to a scratch copy.\n\n"
            "Do not touch `scripts/sketch-lint.mjs` or `scripts/sketch-lint.test.mjs`: pull request 1332 holds them. Leave the direct calls there on the allowed list and name them in the report.\n\n"
            "**Part 2, leftovers of the unit that retired the quarantine list.** (a) `scripts/alpha-rc.mjs` still looks for a `quarantined (red) N` line in the output of `scripts/sketch-smoke.mjs`, and `scripts/ui-audit.mjs` still reads `quarantined` fields from its receipts and prints `quarantined red`; neither can be produced any more. "
            "Find every reader of what those branches write (the report shape of `ui-audit.mjs` among them) and every place an old receipt that still holds the fields is read. Remove the branches and their test cases where nothing reads the result; where an archived receipt is still read by a live command, keep the read and say so. "
            "(b) `scripts/challenge/flume-opening.mjs` is imported only by one case in `scripts/challenge/curve-reads.test.mjs`. Run `node scripts/no-caller.mjs scripts/challenge/flume-opening.mjs` and check by hand for a page that tells a reader to run it; if nothing else names it, delete it with that one test case and keep the rest of the test file.\n\n"
            + DELETE
        ),
        done="every script that is not a test starts git through the helper or is on the allowed list with a reason; a Node test fails on a new direct call and on an empty listing; the dead quarantine branches and `flume-opening.mjs` are deleted or kept with the reader named; and `npm test` passes in order and shuffled.",
        flight="Other units are in flight. Pull request 1332 changes `scripts/sketch-lint.mjs`, `scripts/sketch-lint.test.mjs` and `scripts/sketch-lint.baseline.json`: change none of them. Three units of this round change `.gd` files under `sketches/core-loop/`: change no `.gd` file. "
        "If the integration branch moves while you work and your pull request conflicts, merge `origin/entropy/gate` into your branch; never rebase or force-push.",
        checks=NODE_CHECKS.format(node_exception="", base=BASE) + " Also run the pre-push hook's own checks once from a subfolder with `GIT_DIR` exported to see the helper hold: `(cd scripts && GIT_DIR=\"$(git rev-parse --absolute-git-dir)\" node hooks/pre-push.mjs --help)` or the nearest thing that script supports; say what you ran.",
    ),
}
