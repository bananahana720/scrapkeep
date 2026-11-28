You are the independent reviewer of one pull request in the Scrapkeep repository (GitHub `bananahana720/scrapkeep`). Scrapkeep is a Godot 4.7.2 GDScript game under `sketches/core-loop` with a Node toolchain under `scripts/`. You did not write this change and you have not seen the writer's reasoning. Judge the diff against what the unit was asked to do, below.

## Hard limits

- Write nothing. Use read-only git only (`git fetch`, `git show`, `git diff`, `git log`, `git grep <pattern> <commit> -- <path>`, `git ls-tree`, `git merge-tree`). Do not check out, switch, stash, commit, push, edit a file, comment on the pull request or start a sub-agent. Other sessions share this checkout.
- Do not run Godot, `npm run sketch:fast` or any test. The coordinator runs them when it merges. Read the code.
- On this Mac `git grep -E` does not honour `\b`; write patterns without it.

## What to review

Pull request 1323 (https://github.com/bananahana720/scrapkeep/pull/1323), unit X1, branch `origin/entropy/x1-experimental-duplicates`, head `21d4068bc7b917e5e8f67ce52283d3b397bcc479`. Run `git fetch origin` and check that `git rev-parse origin/entropy/x1-experimental-duplicates` prints that head; if it does not, say so and review what is there. The unit's own change is `git diff 7d7bc3d6c310ee8eb7c88a435450e91d2391e366 21d4068bc7b917e5e8f67ce52283d3b397bcc479`; if the head contains merges of the integration branch, read the unit's change as `git diff 294913bb32cc794a38a082e066e59d50b34ca79a...21d4068bc7b917e5e8f67ce52283d3b397bcc479` and `git log --first-parent 7d7bc3d6c310ee8eb7c88a435450e91d2391e366..21d4068bc7b917e5e8f67ce52283d3b397bcc479` so that other units' landed work is not judged as this unit's. The integration branch is `origin/entropy/gate`, now at `294913bb32cc794a38a082e066e59d50b34ca79a`.

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
8. **Fit with the integration branch.** Run `git merge-tree --write-tree 294913bb32cc794a38a082e066e59d50b34ca79a 21d4068bc7b917e5e8f67ce52283d3b397bcc479` (it writes no branch and touches no file in the checkout) and report any conflict. Look for a caller of an old name that exists at `294913bb32cc794a38a082e066e59d50b34ca79a` but not in the unit's diff, because a clean merge would leave it broken, and for a name this unit uses that a landed unit moved.
This unit was written on an older base and then merged up to an integration tip (`7d7bc3d6c310ee8eb7c88a435450e91d2391e366`); the integration branch has moved on since (`294913bb32cc794a38a082e066e59d50b34ca79a`). The unit's own change is `git diff 7d7bc3d6c310ee8eb7c88a435450e91d2391e366 21d4068bc7b917e5e8f67ce52283d3b397bcc479`, nine files under `src/experimental` and `tests`.

9. **One home for the environment tags.** Read `sketches/core-loop/src/experimental/env_tags.gd` at the head. Say what moved into it (the tag constants, the payload maker, the payload validator, anything else) and from which files, and compare each moved function body with every copy it replaced at the base, line by line: the same keys, the same defaults, the same order of checks, the same value returned for a bad payload. A copy that differed from the others at the base is the interesting case: say which behaviour the single home keeps and which callers therefore see a change. A caller whose result changes for any input is a blocking issue.
10. **`never_brake`.** The copies of the never-brake rule in `refurbished_elites.gd` and `dynamic_setpieces.gd` were replaced by `EventDirector.never_brake`. Read the deleted copies at the base and `never_brake` in `sketches/core-loop/src/core/event_director.gd` at the head and at `294913bb32cc794a38a082e066e59d50b34ca79a`. Say whether they agree for every input (speed thresholds, the comparison operators at the boundary, what a missing key gives). Project rule: difficulty presses a ball that slows or stops and never stops a ball that keeps rolling and turning; a change in when a hazard may brake the ball is a blocking issue.
11. **No caller of a removed name is left**, at the head and at `294913bb32cc794a38a082e066e59d50b34ca79a` merged with it: `make_env_tag_payload`, `is_valid_env_tag_payload`, `_never_brake_local`, `_make_tag`, `validate_env_tag`, `RefurbishedElites.never_brake`, `RefurbishedElites.ENV_TAGS`, `DynamicSetpieces.ENV_TAGS`, and any `TAG_` constant read through a class other than `EnvTags`. Search `src/`, `tests/`, `tools/`, `.tscn`, `.tres` and string calls. Then search the files that landed on the integration branch after `7d7bc3d6c310ee8eb7c88a435450e91d2391e366` (`git diff --name-only 7d7bc3d6c310ee8eb7c88a435450e91d2391e366 294913bb32cc794a38a082e066e59d50b34ca79a -- sketches/core-loop`) for a new use of any of those names: a clean merge would leave it broken.
12. **The tests.** Four test files changed. For each say whether any assertion was removed or loosened, and what `experimental_worlds23_and_bridge_test.gd` gained (the writer added a guard that no other file under `src/experimental` declares a tag constant): say what the guard reads, whether it can pass by matching nothing, and whether it fails on the old form.
13. **Dependency direction.** Say whether `src/experimental/env_tags.gd` loads anything, and whether any file outside `src/experimental` now loads a file inside it that it did not load at the base. `scripts/sketch-lint.baseline.json` must be unchanged by the unit.
14. **Fit with the other open units.** Run `git merge-tree --write-tree <other> 21d4068bc7b917e5e8f67ce52283d3b397bcc479` for `origin/entropy/x3-experimental-dev-seams-2` (if it exists), `origin/entropy/c4-event-juice`, `origin/entropy/f1-fx-pools`, `origin/entropy/b4-build-boss-movement-seams` and `origin/entropy/u3-ui-leaves-down`; report conflicts by file as notes.


## Report

Lead with `VERDICT: PASS` or `VERDICT: FAIL`. Then, apart from each other: blocking issues (each with the file, the function or a `git grep` pattern that finds it, and what is wrong), and notes (things that do not block). For each note that is a small fix, say whether the coordinator can apply it while merging without another review. End with a receipt: your model and effort, the commits you checked, your method, and what you did not do. Write for a reader who has not seen this brief: plain words, full file paths, no shorthand.
