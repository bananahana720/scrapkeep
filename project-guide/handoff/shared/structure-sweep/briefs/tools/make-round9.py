"""Write the writer briefs of round 9 of the structure sweep.

Usage: python3 -I make-round9.py <full SHA of the pushed tip of origin/entropy/gate>
Safe to rerun: it overwrites r9-<unit>.md beside the other briefs and nothing else.
Two shapes of unit: one that runs no Godot (scripts and pages), and one that
changes the game's tree and runs `npm run sketch:fast` once.
"""
import pathlib
import re
import sys

BASE = sys.argv[1]
assert re.fullmatch(r"[0-9a-f]{40}", BASE), "pass the full 40-character SHA of origin/entropy/gate"
OUT = pathlib.Path(__file__).resolve().parent.parent

LONG = (
    "Never end your turn while a command you started still runs. Your shell tool may stop a command after ten minutes. "
    "If a command can run longer than that, start it with `nohup <command> > artifacts/local/<name>.log 2>&1 &`, note its process id (`echo $!`), "
    "wait for it in the foreground with `caffeinate -w <process id>`, repeat that wait if it is cut off, and read the log once the process has exited."
)

DELETE = (
    "**Deleting.** Andrew approved deleting what the surveys listed as having no caller (27 November 2026, ruling `es`: "
    "`git show origin/entropy/records:project-guide/handoff/DECISIONS.md | grep 'Ruling es'`). A survey can be wrong and the tree has moved since, "
    "so prove each delete first. A caller is anything that loads, runs or imports the file or calls the name: another script, a scene or resource file, "
    "a string call (`call(\"name\"`, `has_method(\"name\"`, `Callable(x, \"name\")`, a `load(` of a path built from parts), a line in `package.json`, "
    "a workflow under `.github/`, a hook under `scripts/hooks/`, a skill under `.agents/skills/`, a shell or Python helper, or a page that tells a reader to run it. "
    "Search the whole repository, not one folder. A page or a ledger that only mentions the name in a record of past work is not a caller: leave that record as it is. "
    "Keep whatever has a caller and name the caller in your report. Files that only call each other are dead together."
)

HEAD = """You are the writer of unit {unit} of the Scrapkeep structure sweep. Scrapkeep is a Godot 4.7.2 GDScript game under `sketches/core-loop` with a Node toolchain under `scripts/`. The sweep removes duplicate code, dead code, wrong-way dependencies and facts kept in two places, without changing anything a player or a test can observe.

## Read first

Run `git fetch origin`. The sweep's own pages live on the branch `origin/entropy/records`, not on your base, so read them with `git show`:
1. `git show origin/entropy/records:project-guide/handoff/STRUCTURE-SWEEP.md`, the section "Rules for every writer". Those rules bind you: hard limits, set up, work order, checks and hand in. Follow them exactly.
2. {findings}
Also read `AGENTS.md` in your checkout. A survey finding can be wrong in detail, and line numbers have moved since the survey: confirm each item in the code before you change anything, and report any that is not as described.

## Base and branch

Base commit: `{base}` (a pushed tip of `origin/entropy/gate`). Branch: `{branch}`. Your checkout may start on another commit: create your branch from the base (`git switch -c {branch} {base}`), and stop with `BLOCKED` if `git rev-parse HEAD` does not print the base afterwards.

## The unit

{body}

For every change: find every caller first, weigh at least two options, and take the one that leaves the least code and adds no new layer. If the cheapest option for one item still adds more code or indirection than the problem it removes is worth, leave that item and say so with the reason: a left item with a reason is a good result, a forced fix is not. When a new call or a new home replaces an old one, move every caller in the same commit and delete the old one; no forwarding copy stays behind. Add no code comments (the repo's rule in `CONTRIBUTING.md`, "Editing conventions"). No test may be deleted or weakened, except a test whose only subject is a file this brief has you delete. Never edit any `package.json`. One commit for each part.

Done looks like: {done}

{flight}

## Checks

{checks} {long} Do not start sub-agents.

## Hand in

As the rules page says: push, open a draft pull request against `entropy/gate` titled `{unit}: ...`, and end your final message with the line `PR <full URL>, head <SHA>, checks and reviews <state>`. Lead with `PASS`, `ISSUES` or `BLOCKED`. For each part say what changed and give the `git grep` output that shows the old form is gone; list anything you left, with the reason. If the push is declined, do not try another way: report `BLOCKED` with the local commit SHA. Name your model and effort in the receipt.
"""

NODE_CHECKS = (
    "This unit changes no file the game loads, so do not run Godot or `npm run sketch:fast`{node_exception}. Start every shell line with `export PATH=/opt/homebrew/bin:$PATH`. "
    "After your last commit run: `npm test`; `node scripts/ci/node-tests.mjs --shuffle`; `npm run lint:js`; `npx oxfmt -c scripts/ci/oxfmt.json --check <each .mjs or .js file you changed>`; "
    "`npm run sketch:lint`; `npm run check:project`; `npm run check:docs`; `npm run check:skills`. `npm test` lists its test files from the disk, so a new `*.test.mjs` file under `scripts/` runs without any list to edit. "
    "Rerun a red alone before you call it red, and check a red on the base (`git stash` is forbidden here: use `git worktree add` on the base or `git show {base}:<file>`) before you call it yours."
)

GODOT_CHECKS = (
    "Start every shell line with `export PATH=/opt/homebrew/bin:$PATH GODOT_BIN=\"$HOME/Applications/Godot_4.7.2.app/Contents/MacOS/Godot\"`, and run Godot only with `HOME` set to a scratch folder under `artifacts/local/` as the rules page says. "
    "After your last commit make one call of `npm run sketch:fast -- --base {base}`; it picks tests from the changed files and may wait several minutes for a machine slot before it starts: wait for it, and make one call rather than several. "
    "Then `npm run sketch:lint`, `npm test`, `npm run lint:js` and `npm run check:docs`. Known failures that are not yours: `tests/profile_purity_test.gd` and `tests/slice1_patch_and_w1_craft_test.gd` are red on the base, and `tests/fub_ramp_flash_test.gd` can fail when it runs after `tests/enemy_ramp_flipper_asset_test.gd` in one process; rerun any other red alone before you call it red."
)

UNITS = {
    "G1": dict(
        branch="entropy/g1-guards",
        findings="The task pool, `git show origin/entropy/records:project-guide/handoff/shared/structure-sweep/pool.tsv`: the rows `LEAD-01`, `LEAD-05`, `LEAD-06`, `LEAD-07`, `LEAD-22` and `SCR-07`. `SCR-07` is described in full in `git show origin/entropy/records:project-guide/handoff/shared/structure-sweep/scripts.md`.",
        body=(
            "This unit turns three rules that writers and reviewers have kept by hand into checks that fail, and clears a handful of small script leftovers. All of it is Node code under `scripts/`.\n\n"
            "**Part 1 (LEAD-01), a stale test.** `scripts/budget-audit.test.mjs` fails on the base. Find the assertion with `git grep -n 'pilot_patch_anim' -- scripts/budget-audit.test.mjs`: it expects the Patch pilot model to have no bones and no clips, and the committed model has 25 bones and 8 clips, like every other pilot. Run the test (`node --test scripts/budget-audit.test.mjs`), confirm that is the only failure, and make the assertion hold every pilot to the same rule (bones and clips present), with no special case. "
            "The file is listed in `EXCLUDED_TESTS` in `scripts/ci/node-tests.mjs` with the reason that it fails on the base. Decide what is true after your fix: the CI job `node-tests` in `.github/workflows/ci.yml` checks out only part of the tree (read its `sparse-checkout` list). If this test reads files that job leaves out, keep the entry and replace its reason with the true one, in the form of the entry for `scripts/far-faults.test.mjs`, and make sure `scripts/sketch-fast.mjs` still runs the test on a full checkout when the files it covers change (read `NODE_PATH_RULES` and how `selectStage1NodeTests` treats a file that CI does not cover). If it reads nothing that job leaves out, remove the entry. Either way bring the pinned assertions in `scripts/ci/node-tests.test.mjs` along.\n\n"
            "**Part 2, the lint's lists of existing offences may only shrink.** `scripts/sketch-lint.baseline.json` holds, for each lint rule, the offences that existed when the rule was added. The standing rule is that a change never adds an entry (it fixes the offence instead), and today only a reviewer's eye keeps it. Add a check that compares the file with its copy at a base commit and fails when any rule's list holds more entries than at the base, or when a rule that had no list gains one with entries. Compare counts for each rule, not the entries themselves: a file that moves changes an entry's path without adding an offence. The failure names the rule, both counts, the entries that are new, and the fix (fix the offence; for rule L14, register a reset in `sketches/core-loop/tools/test_batch_driver.gd`). "
            "Write the comparison as one exported function beside the code that reads the baseline, and call it from a place that already knows the base commit, so that the same command runs on a writer's machine and in CI: read how `scripts/sketch-fast.mjs` takes `--base` and how `.github/workflows/ci.yml` and `scripts/hooks/pre-push.mjs` find theirs, and pick the fewest call sites that cover a local run, the pre-push hook and CI. A new rule's first list (see Part 3) must be possible: allow a rule key that does not exist at the base. Prove the check with tests on made-up lists: one added entry fails with the message above, a moved entry passes, a removed entry passes.\n\n"
            "**Part 3, every script has its uid file.** The repository tracks a `NAME.gd.uid` file beside every `NAME.gd` under `sketches/core-loop/`. A script committed without it gets a new identity on every machine. No check covers this today (`git grep -n 'gd.uid' -- scripts/sketch-lint.mjs` shows only an allowed-names message). Add a rule to `npm run sketch:lint`, in the form its whole-tree rules already use, that fails for a tracked `.gd` with no tracked `.gd.uid` beside it and for a `.gd.uid` with no `.gd`, naming the file and the fix (run a Godot import and commit the `.uid` file; delete the orphan). Read which folders hold scripts with uid files today and cover exactly those. If the tree has offenders today, do not create or delete uid files in this unit: list them under the new rule's key in the baseline file, the way the lint's other rules began, and name them in your report.\n\n"
            "**Part 4, small leftovers.** Confirm each in the code first and skip, with the reason, any that is not as described. "
            "(a) `LEAD-05`: `scripts/challenge/run.mjs` imports `readdirSync` and does not use it. "
            "(b) `LEAD-06`: `scripts/gate/pc.mjs` reads `env.GODOT_BIN` back out of the child environment it has just built, where it could pass the binary it already holds. "
            "(c) `LEAD-07`: `scripts/gate/display-run.mjs` spells the Godot version string itself; `scripts/toolchain.json` owns the version and `scripts/lib/game-defs.mjs` reads it. Make the script read the owner only if the string it needs can be built from what the owner holds for every case; if the build hash is not in `toolchain.json`, leave it and say so. "
            "(d) `LEAD-22`: four Node test files leave temporary folders behind (`scripts/worktree-sandbox.test.mjs`, `scripts/crash-harvest.test.mjs`, `scripts/first-timer.test.mjs`, `scripts/gate/display-run.test.mjs`). `AGENTS.md` says a Node test cleans its temporary folders in a `finally` block. Find each `mkdtemp` in those four files and make the clean-up certain; change nothing a test asserts. "
            "(e) `SCR-07`: `scripts/sketch-nightly.mjs` takes a lock file that nothing else uses any more, where `scripts/sketch-smoke.mjs` owns the lock the other runs honour. Read the finding and both scripts. If the smoke script exports a call that takes its lock, make the nightly script use it and delete its own; if using it would change when the nightly run waits or gives up in a way a test pins, leave it and report what you found."
        ),
        done="`node --test scripts/budget-audit.test.mjs` passes; the entry for it in `EXCLUDED_TESTS` is gone or carries its true reason; a test shows the baseline check failing on one added entry; `npm run sketch:lint` fails on a script with no uid file (show it on a scratch copy, not in the tree); `npm test` is green.",
        flight="Other units are in flight in the game's tree (`sketches/core-loop/src`, `tests` and `tools`): change no file there. Two of them remove entries from `scripts/sketch-lint.baseline.json`; if you add a key to that file, add it at the end so the merges stay simple.",
        checks=NODE_CHECKS.format(node_exception="", base=BASE),
    ),
    "D4": dict(
        branch="entropy/d4-doc-numbers-and-orphans",
        findings="Findings `DOC-06` and `DOC-12` in `git show origin/entropy/records:project-guide/handoff/shared/structure-sweep/docs.md`, and the rows `LEAD-18` and `LEAD-19` of the task pool, `git show origin/entropy/records:project-guide/handoff/shared/structure-sweep/pool.tsv`.",
        body=(
            "This unit changes pages and small tracked data files only. It changes no script the game or the toolchain runs.\n\n"
            "**Part 1 (DOC-06), two decision records share one number.** `adr/TADR-011-scrap-bot-crew.md` and `adr/TADR-011-park-terrain-and-warden-kinds.md` are both numbered TADR-011, so a citation of \"TADR-011\" does not say which is meant. Find which file is newer (`git log --diff-filter=A --format='%ad %h' --date=short -- <file>`). Give the newer one the next free number (`ls adr`): `git mv` the file, change the number in its title and in `adr/README.md`, and fix every citation that means it. Find the citations with `git grep -n 'TADR-011'` over the whole repository and read each one in its context to tell which record it means; a citation of the older record stays. "
            "Change citations in pages, `.tsv` and `.json` files. Do not edit a file under `sketches/core-loop/src`, `sketches/core-loop/tests` or `sketches/core-loop/tools`: a citation in a code comment there stays for now, since some tests pin a file's exact bytes; list each such line in your report with the record it means. A dated record of past work (a ledger row, a receipt, a session log) keeps the number it had: add nothing to it and list it.\n\n"
            "**Part 2 (DOC-12), orphan files.** The finding lists config and page files that nothing reads and three-line stubs that only point somewhere else. " + DELETE + " For a page, a caller is also a link to it from another page: `npm run check:docs` checks every link in the repository, so run it after each delete. Delete each file that has no caller and no link, and point any remaining link at the page the stub pointed to.\n\n"
            "**Part 3 (LEAD-18 and LEAD-19), pages that name code that moved.** (a) `sketches/core-loop/design-v3/ABILITY-MUTATIONS.md` names `Grip.heft_of` and `Harpoon.burst_ready`; both moved in an earlier unit. Find where each lives now (`git grep -n 'func heft_of\\|func burst_ready' -- sketches/core-loop/src`) and name the current owner. `tools/coordinator/lane-ledger.tsv` names them too: read what that file is, and if it is a record of past work leave it and say so. "
            "(b) Pages still give `src/core/` paths for four modules that moved to `sketches/core-loop/tests/support/` (`colour_meanings.gd`, `content_registry.gd`, `defence_bars.gd`, `pending_content.gd`). Find them with `git grep -n -E 'src/core/(colour_meanings|content_registry|defence_bars|pending_content)' -- '*.md'`. In a page that describes the code as it is, give the current path. In a dated record of past work, leave the old path and list the page."
        ),
        done="`ls adr | grep -c 'TADR-011'` prints 1; every page citation of the renumbered record uses the new number; each file DOC-12 lists is deleted or kept with its caller named; `npm run check:docs` passes with no broken link.",
        flight="Other units are in flight. A records unit (pull request 1290, branch `entropy/records`) changes `AGENTS.md`, `adr/README.md`, `project-guide/handoff/DECISIONS.md` and adds `project-guide/handoff/STRUCTURE-SWEEP.md`: in `adr/README.md` change only the lines the renumbering forces, and do not edit `AGENTS.md` or `DECISIONS.md` (if one of them cites the renumbered record, list the line in your report and the coordinator will change it). Writers are at work in `sketches/core-loop/src`, `tests` and `tools`: change no file there.",
        checks=NODE_CHECKS.format(node_exception="", base=BASE),
    ),
    "Z1": dict(
        branch="entropy/z1-dead-tool-scripts",
        findings="Findings `TT-01` and `TT-02` in `git show origin/entropy/records:project-guide/handoff/shared/structure-sweep/tools-tests.md`. They list the files.",
        body=(
            "This unit deletes tool scripts that nothing runs. All paths are under `sketches/core-loop/` unless they start with `scripts/`. "
            "`TT-01` lists 72 scripts under `tools/` (about 15,500 lines) and five side scripts with no live caller. `TT-02` lists 13 capture scripts under `tools/` (`w12_side_*.gd` and `w12_recipe_cart_side.gd`, about 5,070 lines) that are copies of each other and that no script, test or command runs.\n\n"
            + DELETE + "\n\n"
            "**Part 1, the tool that proves it.** There are too many files to check by hand, and later units will delete more. Write `scripts/no-caller.mjs`: given file paths, it prints for each one every tracked file that mentions it, and exits 1 if any file given has a mention. A mention is the file's name with its folder as the game spells it (`res://tools/NAME.gd`), its path from the repository root, or its bare file name; for a `.gd` file also its `class_name`, if it declares one. Do not count the file itself, its `.uid` file, or another file given in the same call (files that only call each other are dead together). Search every tracked file with `git grep -l -F`, the whole repository. Print each mention as `path:line`, so a reader can judge it. Keep it small: one file, no options beyond the paths, and a test file `scripts/no-caller.test.mjs` that builds a scratch git repository with one called file, one dead file and two files that only call each other. Prove it on the tree first: run it on three scripts you know are live (for example `tools/test_batch_driver.gd`) and check that it finds their callers.\n\n"
            "**Part 2, the deletes.** Run the tool on every file the two findings list. For each file with no mention, delete it with its `.uid` file (`git rm` both). For each file with a mention, read the mention: if it is a record of past work or a page that only lists the file, the file is still dead, so delete it and leave the record; if a page tells a reader to run it, or a script, test, skill, workflow or command runs it, keep the file and name the caller. If a deleted script was the only user of another file (a helper, a fixture, a scene), run the tool on that file too and delete it if it is now dead; stop there and list anything further you suspect. Put the tool's output for the deleted files in the pull request body, shortened to a count and the mentions you judged."
        ),
        done="every file `TT-01` and `TT-02` list is deleted or kept with its caller named; `node scripts/no-caller.mjs <a live script>` exits 1 and lists its callers; `npm run sketch:lint` is green with no entry added to `scripts/sketch-lint.baseline.json` (remove an entry the lint reports as `no longer offends`); nothing a player or a test can observe changes.",
        flight="Other units are in flight. A tests and tools unit changes `tools/bot_profile.gd`, `tools/skill_band.gd`, `tools/traversal_line.gd`, `tools/bot_fairness.gd`, `tools/alpha_capture.gd` and `tools/test_batch_driver.gd`; three more change `tools/perf_bench.gd`, `tools/bot_run.gd` and `tools/audio_board.gd` by a line or two. If a finding lists one of those, leave it and say so. Change no file under `src/` or `tests/` other than a test whose only subject is a script you delete.",
        checks=GODOT_CHECKS.format(base=BASE),
    ),
}

for unit, u in UNITS.items():
    text = HEAD.format(unit=unit, base=BASE, long=LONG, **u)
    path = OUT / f"r9-{unit.lower()}.md"
    path.write_text(text)
    print(path.name, len(text.split()), "words")
