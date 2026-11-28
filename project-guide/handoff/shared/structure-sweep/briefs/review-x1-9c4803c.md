You are the independent reviewer of one pull request in the Scrapkeep repository (GitHub `bananahana720/scrapkeep`). Scrapkeep is a Godot 4.7.2 GDScript game under `sketches/core-loop` with a Node toolchain under `scripts/`. You did not write this change and you have not seen the writer's reasoning. Judge the diff against what the unit was asked to do, below.

## Hard limits

- Write nothing. Use read-only git only (`git fetch`, `git show`, `git diff`, `git log`, `git grep <pattern> <commit> -- <path>`, `git ls-tree`, `git merge-tree`). Do not check out, switch, stash, commit, push, edit a file, comment on the pull request or start a sub-agent. Other sessions share this checkout.
- Do not run Godot, `npm run sketch:fast` or any test. The coordinator runs them when it merges. Read the code.
- On this Mac `git grep -E` does not honour `\b`; write patterns without it.

## What to review

Pull request 1323 (https://github.com/bananahana720/scrapkeep/pull/1323), unit X1, branch `origin/entropy/x1-experimental-duplicates`, head `9c4803c16de8d5cccde74dd5d943a641d0bcf952`. Run `git fetch origin` and check that `git rev-parse origin/entropy/x1-experimental-duplicates` prints that head; if it does not, say so and review what is there. The unit's own change is `git diff 7d7bc3d6c310ee8eb7c88a435450e91d2391e366 9c4803c16de8d5cccde74dd5d943a641d0bcf952`; if the head contains merges of the integration branch, read the unit's change as `git diff 52d874d0bd36b313a25f5947ad22ebaa25689155...9c4803c16de8d5cccde74dd5d943a641d0bcf952` and `git log --first-parent 7d7bc3d6c310ee8eb7c88a435450e91d2391e366..9c4803c16de8d5cccde74dd5d943a641d0bcf952` so that other units' landed work is not judged as this unit's. The integration branch is `origin/entropy/gate`, now at `52d874d0bd36b313a25f5947ad22ebaa25689155`.

## What the unit was asked to do

The words below are the writer's instructions, copied unchanged. Lines that tell the writer how to set up or what to run are not for you; the description of the change and "Done looks like" are what you judge against.

Unit X1 is pull request 1323 (https://github.com/bananahana720/scrapkeep/pull/1323), branch `entropy/x1-experimental-duplicates`, head `a3eabfc9beb6e1ce879752dbf6e32cc766f0f14b`. It routes the experimental `never_brake` calls to `EventDirector` (Part A) and gives the environment-tag vocabulary, the payload builders and the validators one owner in `src/experimental/env_tags.gd` (Part B). Findings `XD-02` and `XD-03` in `git show origin/entropy/records:project-guide/handoff/shared/structure-sweep/experimental-dev.md`. Read its commits (`git log -p 7d7bc3d6c310ee8eb7c88a435450e91d2391e366..a3eabfc9beb6e1ce879752dbf6e32cc766f0f14b`) before you merge, so you know what it changed and why.

### Set up

Your checkout may start on another commit, and the branch name `entropy/x1-experimental-duplicates` may be checked out in another checkout on this machine, so work on a local branch of your own and push to the unit's branch:

```
git fetch origin
git switch -c x1-catch-up a3eabfc9beb6e1ce879752dbf6e32cc766f0f14b
git rev-parse HEAD
```

`git rev-parse HEAD` must print `a3eabfc9beb6e1ce879752dbf6e32cc766f0f14b`; stop with `BLOCKED` if it does not. Then follow the set-up steps of the rules page (`npm run worktree:deps`, the scratch `HOME`, the import).

### The work

1. `git merge 7d7bc3d6c310ee8eb7c88a435450e91d2391e366` (the integration tip; check that `git rev-parse origin/entropy/gate` contains it with `git merge-base --is-ancestor 7d7bc3d6c310ee8eb7c88a435450e91d2391e366 origin/entropy/gate`). Known conflicts: none in text (`git merge-tree` reports a clean merge), but more than thirty units landed since its base, among them one that changed `src/experimental/live_run_bridge.gd`, `src/dev/` and the experimental audio bank, and one that added `clear_families()` to `src/world/event_director.gd`. A clean text merge can still leave a caller on a name that no longer exists. Resolve each by hand so that both sides' intent survives: the integration branch's later changes stay, and the unit's change is applied on top of them. Say which files conflicted and how you resolved each.
2. After the merge, for every name the unit moved, renamed or deleted, search the whole tree for a stale use (`git grep -n -F '<name>' -- sketches/core-loop scripts`), including `.tscn`, `.tres` and string calls such as `call("name"`. Fix each stale use by pointing it at the unit's owner. Check the other way too: that the unit uses no name a landed unit moved.
3. In `scripts/sketch-lint.baseline.json` keep the integration branch's lists; remove only an entry the lint reports as `no longer offends`; never add an entry and never pass `--write-baseline`.
4. `src/world/event_director.gd` is covered by a formal model: after the merge, say exactly which of its lines differ from the integration tip because of this unit.

Limits: nothing a player, a test or a tool can observe changes. No test is deleted or weakened; a test changes only to follow a moved or renamed call. Add no code comments. Do not start sub-agents. Run every command in the foreground to completion and never end your turn while a command runs. Other units are in flight in most directories, so change only this unit's files and the lines the merge forces, and list every line you changed outside the unit's own files.

Done looks like: the unit's two parts are intact on top of the integration tip; `git grep` for each name the unit moved or deleted shows no stale caller in `src/`, `tests/` or `tools/`.

Rules that bind every unit: when a new call or a new home replaces an old one, every caller moves in the same commit and the old one is deleted, with no forwarding copy left behind; no code comment is added (only tool-read lines and engine quirk notes are allowed); no test is deleted or weakened, and a test changes only to follow a moved or renamed call; no `package.json` is edited unless the instructions above say Andrew approved it; every new `.gd` file has a tracked `.gd.uid` beside it; `scripts/sketch-lint.baseline.json` gains no entry.

## What to check, at least

1. **Behaviour is unchanged.** For every moved or renamed function the body is the same; for every new call, compare what each caller read or did before with what it gets now, for every input: same value, same object (not a copy) where the caller keeps or mutates it, same order of side effects and signals.
2. **No caller was missed.** For each old name, search the head for remaining uses in `src/`, `tests/`, `tools/`, `scripts/`, `.tscn` and `.tres` files and string calls (`call("name"`, `has_method("name"`, `Callable(x, "name")`, `get("name")`), including uses through an alias (a `const X := preload(...)` under another name) or `load("...")` at run time. A missed caller is a blocking issue because it fails only at run time.
3. **Names.** A new public name does not collide with a member of the same class, a subclass, a parent or a test double, and does not shadow a local variable or parameter in a way that changes meaning.
4. **Nothing is left behind and nothing is forced.** No forwarding copy, no dead code the change orphaned, no new layer that only passes calls through, no file split whose new file calls back into its parent for most of its work. Where the writer left an item with a reason, say whether the reason holds.
5. **The guard** (if the unit adds or extends one) fails on the old form, cannot pass by matching nothing (check its patterns against the head), and its allowed lists can only shrink. For every check, guard or tool the unit adds, name each way it could report a pass without having checked: an input that does not exist or is misspelt, a read that failed (a file, a git call, a fetch), an empty list. One that passes in any of those cases is a blocking issue; it must fail and say why.
6. **Formal models.** `.agents/skills/scrapkeep-verify-formal/SKILL.md` lists the files covered by a formal model. The models were not run. Say exactly which lines of covered files this unit changed and whether any of them changes how the modelled state is read, stepped, held or ended.
7. **Scope.** List every file the unit changed outside the area its instructions name, and whether a rename or a moved path forces each.
8. **Fit with the integration branch.** Run `git merge-tree --write-tree 52d874d0bd36b313a25f5947ad22ebaa25689155 9c4803c16de8d5cccde74dd5d943a641d0bcf952` (it writes no branch and touches no file in the checkout) and report any conflict. Look for a caller of an old name that exists at `52d874d0bd36b313a25f5947ad22ebaa25689155` but not in the unit's diff, because a clean merge would leave it broken, and for a name this unit uses that a landed unit moved.
This review is limited to one fix. A review of this unit at `21d4068bc` failed on one blocking issue: the guard the unit added to `sketches/core-loop/tests/experimental_worlds23_and_bridge_test.gd` could pass without reading anything. The writer added one commit, `9c4803c16`, that changes only that test file. You have not seen that review. The rest of the unit passed it, so checks 1 to 4 and 6 above need one line each (confirm with `git diff --stat 21d4068bc 9c4803c16de8d5cccde74dd5d943a641d0bcf952` that the fix touches only that file); spend the time on the checks below. The unit merged an older integration tip (`7d7bc3d6c310ee8eb7c88a435450e91d2391e366`); the integration branch is now at `52d874d0bd36b313a25f5947ad22ebaa25689155`.

9. **Every way the guards could pass without checking.** Read `_test_graph_and_code_hygiene` in that test at the head, and every helper it calls. For each of these say which line fails the test: `res://src/experimental` does not open; the walk finds no script; `env_tags.gd` is not among the scripts found; a file's text reads as empty or the read fails; each regular expression does not compile (there are four; name each and what it looks for). A path that reaches the end of the function with nothing read and no failure is a blocking issue.
10. **The walk.** Say whether it descends into sub-folders, how many scripts `git ls-tree -r --name-only 9c4803c16de8d5cccde74dd5d943a641d0bcf952 sketches/core-loop/src/experimental | grep -c '\.gd$'` reports against what the walk would find, and whether the test pins a count (a pinned count that must be edited each time a script is added is a note, not a blocking issue).
11. **What the guards assert.** Say in one line each what the function forbids (a tag constant declared outside `env_tags.gd`, a second payload maker or validator, a local never-brake rule, anything else), and for each give one line of the base code (`git show 7d7bc3d6c310ee8eb7c88a435450e91d2391e366:<path>`, before the unit) that it would have failed on. A guard that would have passed on the old form is a blocking issue.
12. **No assertion was removed or loosened** by the fix: compare the function at `21d4068bc` and at the head.
13. **No engine error line.** The test runner fails a test that prints a line starting `ERROR:`. Say whether any path in the function can print one on a pass (for example a `RegEx.compile` on a bad pattern, or opening a folder that is absent).
14. **Notes for the coordinator**, none blocking: say whether these are still true at the head. `tests/experimental_cross_pillar_test.gd` holds two assertions that are true by construction; `tests/experimental_vertical_setpieces_test.gd` has a check labelled `make_env_tag_clamps_positive_intensity` that names a deleted function; `sketches/core-loop/design-v3/experimental/DIRECTOR-AND-ENCOUNTERS-BLUEPRINT.md` mentions `RefurbishedElites.make_env_tag_payload`. For the page, say whether it is a dated record or a page that describes the project as it is.
15. **Fit with the other open units.** Run `git merge-tree --write-tree <other> 9c4803c16de8d5cccde74dd5d943a641d0bcf952` for `origin/entropy/b4-build-boss-movement-seams`, `origin/entropy/c3-core-upward-loads`, `origin/entropy/c4-event-juice`, `origin/entropy/f1-fx-pools`, `origin/entropy/m3-combat-collaborator-calls-2`, `origin/entropy/u3-ui-leaves-down`, `origin/entropy/w3-world-seams-2`, `origin/entropy/x1-experimental-duplicates` and `origin/entropy/x3-experimental-dev-seams-2` (skip this unit's own branch and any that does not exist). Report each conflict by file. Then look past the text: name any function, constant or file this unit renames, moves or deletes that one of those branches still uses at its head (`git grep -n -F '<name>' origin/<branch> -- sketches/core-loop`), because a clean text merge would leave that caller broken. Each is a note for the coordinator, not a blocking issue.


## Report

Lead with `VERDICT: PASS` or `VERDICT: FAIL`. Then, apart from each other: blocking issues (each with the file, the function or a `git grep` pattern that finds it, and what is wrong), and notes (things that do not block). For each note that is a small fix, say whether the coordinator can apply it while merging without another review. End with a receipt: your model and effort, the commits you checked, your method, and what you did not do. Write for a reader who has not seen this brief: plain words, full file paths, no shorthand.
