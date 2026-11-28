You are the independent reviewer of one pull request in the Scrapkeep repository (GitHub `bananahana720/scrapkeep`). Scrapkeep is a Godot 4.7.2 GDScript game under `sketches/core-loop` with a Node toolchain under `scripts/`. You did not write this change and you have not seen the writer's reasoning. Judge the diff against what the unit was asked to do, below.

## Hard limits

- Write nothing. Use read-only git only (`git fetch`, `git show`, `git diff`, `git log`, `git grep <pattern> <commit> -- <path>`, `git ls-tree`, `git merge-tree`). Do not check out, switch, stash, commit, push, edit a file, comment on the pull request or start a sub-agent. Other sessions share this checkout.
- Do not run Godot, `npm run sketch:fast` or any test. The coordinator runs them when it merges. Read the code.
- On this Mac `git grep -E` does not honour `\b`; write patterns without it.

## What to review

Pull request 1341 (https://github.com/bananahana720/scrapkeep/pull/1341), unit G4, branch `origin/entropy/g4-fast-args`, head `e1d85f2f28ed4d4dc64b417d8038350cc10a736f`. Run `git fetch origin` and check that `git rev-parse origin/entropy/g4-fast-args` prints that head; if it does not, say so and review what is there. The unit's own change is `git diff 52d874d0bd36b313a25f5947ad22ebaa25689155 e1d85f2f28ed4d4dc64b417d8038350cc10a736f`; if the head contains merges of the integration branch, read the unit's change as `git diff 52d874d0bd36b313a25f5947ad22ebaa25689155...e1d85f2f28ed4d4dc64b417d8038350cc10a736f` and `git log --first-parent 52d874d0bd36b313a25f5947ad22ebaa25689155..e1d85f2f28ed4d4dc64b417d8038350cc10a736f` so that other units' landed work is not judged as this unit's. The integration branch is `origin/entropy/gate`, now at `52d874d0bd36b313a25f5947ad22ebaa25689155`.

## What the unit was asked to do

The words below are the writer's instructions, copied unchanged. Lines that tell the writer how to set up or what to run are not for you; the description of the change and "Done looks like" are what you judge against.

Pool item LEAD-56. `scripts/sketch-fast.mjs` is the fast Godot check every writer runs (`npm run sketch:fast -- --base <ref> --test <name> ...`). Its argument parser, `parseArgs`, silently ignored any argument it did not recognise. Two writers passed several test names as one quoted argument (`"--test a --test b"`); the parser dropped it and the tool ran its default selection, so each writer reported named tests as run when they had not been.

Asked:

1. `parseArgs` throws on an argument it does not know, and on a flag that takes a value (`--base`, `--budget`, `--receipt`, `--width`, `--pre`) when the value is missing. The message tells the reader to pass each flag and each value as its own argument.
2. `main` prints that reason on one line and exits with a non-zero code, with no stack trace.
3. In named mode (`--test`), a pattern that matches no `tests/*.gd` file stops the run with a non-zero code and names every such pattern, even when another pattern did match.
4. Nothing else about the tool changes: every existing caller's argument list parses to the same options as before, and the `--fold-timings` path is untouched.
5. Tests in `scripts/sketch-fast.test.mjs` that fail on the old file.

Only `scripts/sketch-fast.mjs` and `scripts/sketch-fast.test.mjs` may change. No `package.json`.

Rules that bind every unit: when a new call or a new home replaces an old one, every caller moves in the same commit and the old one is deleted, with no forwarding copy left behind; no code comment is added (only tool-read lines and engine quirk notes are allowed); no test is deleted or weakened, and a test changes only to follow a moved or renamed call; no `package.json` is edited unless the instructions above say Andrew approved it; every new `.gd` file has a tracked `.gd.uid` beside it; `scripts/sketch-lint.baseline.json` gains no entry.

## What to check, at least

1. **Behaviour is unchanged.** For every moved or renamed function the body is the same; for every new call, compare what each caller read or did before with what it gets now, for every input: same value, same object (not a copy) where the caller keeps or mutates it, same order of side effects and signals.
2. **No caller was missed.** For each old name, search the head for remaining uses in `src/`, `tests/`, `tools/`, `scripts/`, `.tscn` and `.tres` files and string calls (`call("name"`, `has_method("name"`, `Callable(x, "name")`, `get("name")`), including uses through an alias (a `const X := preload(...)` under another name) or `load("...")` at run time. A missed caller is a blocking issue because it fails only at run time.
3. **Names.** A new public name does not collide with a member of the same class, a subclass, a parent or a test double, and does not shadow a local variable or parameter in a way that changes meaning.
4. **Nothing is left behind and nothing is forced.** No forwarding copy, no dead code the change orphaned, no new layer that only passes calls through, no file split whose new file calls back into its parent for most of its work. Where the writer left an item with a reason, say whether the reason holds.
5. **The guard** (if the unit adds or extends one) fails on the old form, cannot pass by matching nothing (check its patterns against the head), and its allowed lists can only shrink. For every check, guard or tool the unit adds, name each way it could report a pass without having checked: an input that does not exist or is misspelt, a read that failed (a file, a git call, a fetch), an empty list. One that passes in any of those cases is a blocking issue; it must fail and say why.
6. **Formal models.** `.agents/skills/scrapkeep-verify-formal/SKILL.md` lists the files covered by a formal model. The models were not run. Say exactly which lines of covered files this unit changed and whether any of them changes how the modelled state is read, stepped, held or ended.
7. **Scope.** List every file the unit changed outside the area its instructions name, and whether a rename or a moved path forces each.
8. **Fit with the integration branch.** Run `git merge-tree --write-tree 52d874d0bd36b313a25f5947ad22ebaa25689155 e1d85f2f28ed4d4dc64b417d8038350cc10a736f` (it writes no branch and touches no file in the checkout) and report any conflict. Look for a caller of an old name that exists at `52d874d0bd36b313a25f5947ad22ebaa25689155` but not in the unit's diff, because a clean merge would leave it broken, and for a name this unit uses that a landed unit moved.
This unit changes one Node script and its test; no game script changes. Say in one line which of the checks above do not apply.

9. **Every caller still parses.** Find every place that runs the tool: `git grep -n -E 'sketch-fast\.mjs|sketch:fast' e1d85f2f28ed4d4dc64b417d8038350cc10a736f -- .github scripts .agents package.json sketches/core-loop/package.json CONTRIBUTING.md AGENTS.md ORCHESTRATOR.md project-guide/handoff ':!project-guide/handoff/shared/structure-sweep/pool.tsv'`. For each caller that passes arguments (the Godot job in `.github/workflows/ci.yml`, `scripts/card-runner.mjs`, `scripts/hooks/`, the scripts under `.agents/skills/`, and any documented command line on a page that describes the project as it is), list the arguments and say whether `parseArgs` at the head accepts each one. A caller or a documented command that the head would now refuse is a blocking issue; name it.
10. **The full flag list.** Read `parseArgs` at the base and at the head. List every flag the base accepted and confirm the head accepts the same set with the same meaning. Say whether any flag is handled outside `parseArgs` (for example `--fold-timings`, or one read directly from `process.argv`) and would now be refused by the new final branch. Say whether `npm run sketch:fast -- ...` can hand the script an argument the user did not type.
11. **Value flags.** For each of `--base`, `--budget`, `--receipt`, `--width`, `--pre`, `--test`, `--shard`, `--seed`: what happens at the head when it is the last argument with no value, and what happens when its value starts with `--`. A case that silently takes the next flag as a value was true at the base too and is a note, not a blocking issue; a case that the head silently ignores is a blocking issue.
12. **Unmatched test names.** Read `unmatchedTestPatterns` and its call site. Say how a pattern is matched (basename, glob, with or without `.gd`, with or without the `tests/` prefix), whether the forms writers use (`fx_library_test`, `tests/fx_library_test.gd`, a glob) each still resolve, and what the run prints and exits with when one of three patterns matches nothing. A form that resolved at the base and is refused at the head is a blocking issue.
13. **Exit path.** Confirm `main` catches only the parse error, prints one line and exits 2, and that no other error is swallowed. Say whether the base-ref check, the slot wait or any Godot work can start before the argument error is reported.
14. **The tests.** For each new test in `scripts/sketch-fast.test.mjs`, say what it asserts and whether it would fail on the base file (`git show 52d874d0bd36b313a25f5947ad22ebaa25689155:scripts/sketch-fast.mjs`). A test that would pass on the base is a blocking issue.
15. **Fit with the open units.** `git merge-tree --write-tree <other> e1d85f2f28ed4d4dc64b417d8038350cc10a736f` for `origin/entropy/c3-core-upward-loads` (it edits `scripts/sketch-fast.timings.json` at most) and `origin/entropy/t3-test-seams-and-resets`; report any conflict by file.


## Report

Lead with `VERDICT: PASS` or `VERDICT: FAIL`. Then, apart from each other: blocking issues (each with the file, the function or a `git grep` pattern that finds it, and what is wrong), and notes (things that do not block). For each note that is a small fix, say whether the coordinator can apply it while merging without another review. End with a receipt: your model and effort, the commits you checked, your method, and what you did not do. Write for a reader who has not seen this brief: plain words, full file paths, no shorthand.
