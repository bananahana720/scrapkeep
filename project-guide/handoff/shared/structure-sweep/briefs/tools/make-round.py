"""Write the writer briefs of one round of the structure sweep.

Usage: python3 -I make-round.py <round number> <full SHA of the pushed tip of origin/entropy/gate>
The units of round N are the dict UNITS in units-rN.py beside this file; that file may use
BASE, DELETE, NODE_CHECKS and GODOT_CHECKS from here. Each unit has: branch, findings, body,
done, flight, checks.
Safe to rerun: it overwrites r<N>-<unit>.md beside the other briefs and nothing else.
Two shapes of unit: one that runs no Godot (scripts and pages), and one that
changes the game's tree and runs `npm run sketch:fast` once.
"""
import pathlib
import re
import runpy
import sys

ROUND, BASE = sys.argv[1:3]
assert re.fullmatch(r"[0-9]+", ROUND), "pass the round number first"
assert re.fullmatch(r"[0-9a-f]{40}", BASE), "pass the full 40-character SHA of origin/entropy/gate"
OUT = pathlib.Path(__file__).resolve().parent.parent

LONG = (
    "Never end your turn while a command you started still runs. Your shell tool may stop a command after ten minutes. "
    "If a command can run longer than that, start it with `nohup <command> > artifacts/local/<name>.log 2>&1 &`, note its process id (`echo $!`), "
    "wait for it in the foreground with `caffeinate -w <process id>`, repeat that wait if it is cut off, and read the log once the process has exited."
)

DELETE = (
    "**Deleting.** Andrew approved deleting what the surveys listed as having no caller (27 November 2026, ruling `es`: "
    "`git show origin/entropy/gate:project-guide/handoff/DECISIONS.md | grep 'Ruling es'`). A survey can be wrong and the tree has moved since, "
    "so prove each delete first. A caller is anything that loads, runs or imports the file or calls the name: another script, a scene or resource file, "
    "a string call (`call(\"name\"`, `has_method(\"name\"`, `Callable(x, \"name\")`, a `load(` of a path built from parts), a line in `package.json`, "
    "a workflow under `.github/`, a hook under `scripts/hooks/`, a skill under `.agents/skills/`, a shell or Python helper, or a page that tells a reader to run it. "
    "Search the whole repository, not one folder. A page or a ledger that only mentions the name in a record of past work is not a caller: leave that record as it is. "
    "Keep whatever has a caller and name the caller in your report. Files that only call each other are dead together."
)

STANDING = (
    "## Mistakes earlier units made\n\n"
    "Each of these sent a unit back from review at least once. Check your work against every one before you hand in.\n"
    "1. **A check that passes when it read nothing.** A test or tool you add or change must fail when it cannot read or compare its input: a folder that does not open, an empty file list, an empty read, a pattern that does not compile, a command that exits non-zero or prints nothing. "
    "A Godot test that reads source to enforce a rule does every read through `sketches/core-loop/tests/support/source_scan.gd` (`SourceScan.matching` for the files that match, `SourceScan.captures` for what each match captured) and holds no `FileAccess`, `DirAccess` or `RegEx` of its own. "
    "Write each such check as \"the files that match equal exactly this list\", and say in your report how the check fails on the code before your change.\n"
    "2. **A pattern narrower than the language.** A pattern for a declaration must allow `static` and an annotation on the same line: start it with `(?m)^\\s*(?:static\\s+|@[a-z0-9_]+(?:\\([^)]*\\))?\\s+)*`.\n"
    "3. **A forwarding copy left behind.** When you move a function or a constant, delete the old one and change its callers. Keep a one-line forwarder only for a caller outside the folders you may change, and name that caller.\n"
    "4. **A test weakened in passing.** When a signature changes or gains an optional argument, read every test that calls it and confirm each still exercises what its label says.\n"
    "5. **An edited record.** Never edit a dated record of past work, not even a path that moved: ledgers, receipts, wave memos, the survey files, entries in `sketches/core-loop/DESIGN-NOTES.md`, and dated specs such as `design-v3/SKILL-BAR.md`, `design-v3/FEEL-READABILITY.md`, `design-v3/pilots/*.md` and `research/comps/*.md`. Live pages you do keep current: `ARCHITECTURE.md`, `CONTRACTS.md`, `VISUAL-LANGUAGE.md` and every `SEAMS.md`.\n"
    "6. **A stray file committed.** Stage files by name. Never `git add -A` or `git add .`: your checkout may hold an untracked `node_modules` link.\n"
    "7. **A test filter that matched nothing or everything.** `npm run sketch:fast` refuses an argument it does not know. Each `--test` takes one pattern matched against the test file's name, and each is its own argument: `--test unit_suite_test --test boss_owners_test`. A `--test` replaces the tests the call would have picked from your changed files; it never adds to them, so the call that qualifies your unit carries no `--test`.\n"
    "8. **A grown list.** `scripts/sketch-lint.baseline.json` only shrinks. If it conflicts when you merge, keep the integration branch's blocks and remove only what `npm run sketch:lint` says no longer offends.\n"
    "9. **Git started by hand in a script.** A Node script starts git through `scripts/lib/git.mjs`, which reads the repository of its `cwd` even inside a git hook.\n"
    "10. **A pin that holds only on the machine that made it, and a report sent before CI answered.** You work on a Mac (arm64); the pull request's CI runs Linux on x86-64, where floating-point results can differ in the last bit. "
    "A test that pins bytes or hashes of computed floats (mesh arrays, audio samples, positions after a simulation) recorded on one of them fails on the other: make such a test exact only on the platform its pin names and tolerant elsewhere, and never round and then hash. "
    "After your last push, read the pull request's CI (`gh pr checks <number>`) and put its lines in your report. The Node jobs answer within two minutes and the Godot job within about ten: read it again a few times over that span, with real work or a single plain command between reads, not a sleep, a loop or a watch flag, which your host forbids. "
    "If a check is still pending when you report, name it and say so plainly; the coordinator reads CI again before merging, so a pending check does not make your report `ISSUES`. A red check that your change caused is yours to fix before you report; one it did not cause, name with the reason.\n"
    "11. **A command that stops at a permission prompt.** Nobody is there to answer a prompt, so a writer that meets one sits idle until someone notices; eight units lost between half an hour and five hours each this way. Two causes are known exactly. "
    "First, never run `gh api` or `gh repo`: the project's safety hook (`.agents/hooks/safety-gate.mjs`) asks for confirmation on every one. Read CI with `/opt/homebrew/bin/gh pr checks <number>`, and fetch what a run uploaded with `/opt/homebrew/bin/gh run download <run> -D artifacts/local/ci-<run>`. "
    "Second, run every `git push` and every `gh` command alone as its own call with nothing else on the line: no `export`, no shell variable (not even `$PATH`), no `&&`, no pipe; write `git push origin <your branch>` and call `gh` by its full path. The line this brief has you start shell calls with does not go on a push or a `gh` call. "
    "For every other call, keep to one plain command with literal paths and values: no `$(...)` or backticks, no variable set and then used in the same command (`H=...; HOME=\"$H\" ...`), no heredoc (`<<'EOF'`), and no long chain of unlike commands. "
    "Edit files with the file edit tool, never with a script typed into the shell. For anything longer, write a small script file under `artifacts/local/` with the file tool and run it by name; put the `export` lines a command needs inside that file. "
    "To read a CI log, send it to a file (`/opt/homebrew/bin/gh run view <run> --log-failed > artifacts/local/<name>.log`) and search the file. If a command is refused or asks for approval anyway, reshape it and go on; never wait on it."
)

HEAD = """You are the writer of unit {unit} of the Scrapkeep structure sweep. Scrapkeep is a Godot 4.7.2 GDScript game under `sketches/core-loop` with a Node toolchain under `scripts/`. The sweep removes duplicate code, dead code, wrong-way dependencies and facts kept in two places, without changing anything a player or a test can observe.

## Read first

Run `git fetch origin`. The sweep's own pages are on your base; read them at the base with `git show`, since your checkout may start on another commit:
1. `git show {base}:project-guide/handoff/STRUCTURE-SWEEP.md`, the section "Rules for every writer". Those rules bind you: hard limits, set up, work order, checks and hand in. Follow them exactly.
2. {findings}
Also read `AGENTS.md` in your checkout. A survey finding can be wrong in detail, and line numbers have moved since the survey: confirm each item in the code before you change anything, and report any that is not as described.

## Base and branch

Base commit: `{base}` (a pushed tip of `origin/entropy/gate`). Branch: `{branch}`. Your checkout may start on another commit: create your branch from the base (`git switch -c {branch} {base}`), and stop with `BLOCKED` if `git rev-parse HEAD` does not print the base afterwards.

## The unit

{body}

For every change: find every caller first, weigh at least two options, and take the one that leaves the least code and adds no new layer. If the cheapest option for one item still adds more code or indirection than the problem it removes is worth, leave that item and say so with the reason: a left item with a reason is a good result, a forced fix is not. When a new call or a new home replaces an old one, move every caller in the same commit and delete the old one; no forwarding copy stays behind. Add no code comments (the repo's rule in `CONTRIBUTING.md`, "Editing conventions"). No test may be deleted or weakened, except a test whose only subject is a file this brief has you delete. Never edit any `package.json`. Never change a line of a dated record of past work (a ledger, a receipt, a wave memo, a survey file, a snapshot kept verbatim, an entry in a notes log such as `sketches/core-loop/DESIGN-NOTES.md`): it keeps the names and paths it was written with, and a new fact goes in the page that describes the project today. Stage files by name, never with `git add -A` or `git add .`. Any check, guard, test or tool you add or change must fail, not pass, when it cannot read, find or compare its input (a folder that does not open, an empty file list, an empty read, a failed `git` call, a pattern that does not compile, a missing argument): cover each such case with a test and name them in your report. Never add an entry to `scripts/sketch-lint.baseline.json`; the lint fails when one of its lists grows against the base, so fix the offence instead. Before your final push, run `git fetch origin` and merge the pushed tip of `origin/entropy/gate` into your branch (a merge, never a rebase). If that tip is newer than your base, resolve any conflict by keeping both sides' intent, make any generated file again instead of picking a side, rerun every check on the merged head with that tip as the base, and name the tip's full SHA in your report. A unit that does not merge cleanly onto the integration branch goes back to its writer before its review. One commit for each part.

Done looks like: {done}

{standing}

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
    "Then `npm run sketch:lint`, `npm test`, `npm run lint:js` and `npm run check:docs`. Known failures that are not yours: `tests/slice1_patch_and_w1_craft_test.gd` and `tests/stage_modifier_test.gd` are red on `main` on this machine; rerun any other red alone before you call it red, and call a red old only when it is red on `main`, not when it is red on the integration branch. "
    "`tests/profile_purity_test.gd` guards whole folders and the call above does not pick it by itself: if you change or add a script under `src/movement`, `src/combat`, `src/build`, `src/world` or `src/boss`, run it by name in a second short call (`npm run sketch:fast -- --base {base} --test profile_purity_test`); it passes on the base."
)

UNITS = runpy.run_path(str(pathlib.Path(__file__).with_name(f"units-r{ROUND}.py")), init_globals=dict(BASE=BASE, DELETE=DELETE, NODE_CHECKS=NODE_CHECKS, GODOT_CHECKS=GODOT_CHECKS))["UNITS"]

for unit, u in UNITS.items():
    text = HEAD.format(unit=unit, base=BASE, long=LONG, standing=STANDING, **u)
    path = OUT / f"r{ROUND}-{unit.lower()}.md"
    path.write_text(text)
    print(path.name, len(text.split()), "words")
