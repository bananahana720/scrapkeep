You are the independent reviewer of one pull request in the Scrapkeep repository (GitHub `bananahana720/scrapkeep`). Scrapkeep is a Godot 4.7.2 GDScript game under `sketches/core-loop` with a Node toolchain under `scripts/`. You did not write this change and you have not seen the writer's reasoning. Judge the diff against what the unit was asked to do, below.

## Hard limits

- Write nothing. Use read-only git only (`git fetch`, `git show`, `git diff`, `git log`, `git grep <pattern> <commit> -- <path>`, `git ls-tree`, `git merge-tree`). Do not check out, switch, stash, commit, push, edit a file, comment on the pull request or start a sub-agent. Other sessions share this checkout.
- Do not run Godot, `npm run sketch:fast` or any test. The coordinator runs them when it merges. Read the code.
- On this Mac `git grep -E` does not honour `\b`; write patterns without it.

## What to review

Pull request 1325 (https://github.com/bananahana720/scrapkeep/pull/1325), unit F1, branch `origin/entropy/f1-fx-pools`, head `4c8fc4333e160fb8254fb10d42bcf12e97ec6a90`. Run `git fetch origin` and check that `git rev-parse origin/entropy/f1-fx-pools` prints that head; if it does not, say so and review what is there. The unit's own change is `git diff 7d7bc3d6c310ee8eb7c88a435450e91d2391e366 4c8fc4333e160fb8254fb10d42bcf12e97ec6a90`; if the head contains merges of the integration branch, read the unit's change as `git diff 52d874d0bd36b313a25f5947ad22ebaa25689155...4c8fc4333e160fb8254fb10d42bcf12e97ec6a90` and `git log --first-parent 7d7bc3d6c310ee8eb7c88a435450e91d2391e366..4c8fc4333e160fb8254fb10d42bcf12e97ec6a90` so that other units' landed work is not judged as this unit's. The integration branch is `origin/entropy/gate`, now at `52d874d0bd36b313a25f5947ad22ebaa25689155`.

## What the unit was asked to do

The words below are the writer's instructions, copied unchanged. Lines that tell the writer how to set up or what to run are not for you; the description of the change and "Done looks like" are what you judge against.

Unit F1 is pull request 1325 (https://github.com/bananahana720/scrapkeep/pull/1325), branch `entropy/f1-fx-pools`, head `265f34a0b20f09ab20155bfa4a91c84cf999c0f7`. It puts the owner-filtered effect pools in `src/presentation/fx_library.gd` (finding `VF-02`) and removes the `SpecialCues` forwarders from `src/presentation/machine_fx.gd` (finding `VF-13`); four files. The findings are in `git show origin/entropy/records:project-guide/handoff/shared/structure-sweep/visuals-fx.md` (list the folder with `git ls-tree --name-only origin/entropy/records project-guide/handoff/shared/structure-sweep/` if that name is not there). Read its commits (`git log -p 7d7bc3d6c310ee8eb7c88a435450e91d2391e366..265f34a0b20f09ab20155bfa4a91c84cf999c0f7`) before you merge, so you know what it changed and why.

### Set up

Your checkout may start on another commit, and the branch name `entropy/f1-fx-pools` may be checked out in another checkout on this machine, so work on a local branch of your own and push to the unit's branch:

```
git fetch origin
git switch -c f1-catch-up 265f34a0b20f09ab20155bfa4a91c84cf999c0f7
git rev-parse HEAD
```

`git rev-parse HEAD` must print `265f34a0b20f09ab20155bfa4a91c84cf999c0f7`; stop with `BLOCKED` if it does not. Then follow the set-up steps of the rules page (`npm run worktree:deps`, the scratch `HOME`, the import).

### The work

1. `git merge 7d7bc3d6c310ee8eb7c88a435450e91d2391e366` (the integration tip; check that `git rev-parse origin/entropy/gate` contains it with `git merge-base --is-ancestor 7d7bc3d6c310ee8eb7c88a435450e91d2391e366 origin/entropy/gate`). Known conflicts: `sketches/core-loop/src/presentation/vfx.gd`. A unit that landed since split `vfx.gd` into several files, so the lines this unit changed may now live in another file under `src/presentation/`. Resolve each by hand so that both sides' intent survives: the integration branch's later changes stay, and the unit's change is applied on top of them. Say which files conflicted and how you resolved each.
2. After the merge, for every name the unit moved, renamed or deleted, search the whole tree for a stale use (`git grep -n -F '<name>' -- sketches/core-loop scripts`), including `.tscn`, `.tres` and string calls such as `call("name"`. Fix each stale use by pointing it at the unit's owner. Check the other way too: that the unit uses no name a landed unit moved.
3. In `scripts/sketch-lint.baseline.json` keep the integration branch's lists; remove only an entry the lint reports as `no longer offends`; never add an entry and never pass `--write-baseline`.
4. Find where each line this unit changed in `vfx.gd` lives now (`git log --oneline --first-parent -- sketches/core-loop/src/presentation/vfx.gd` on the integration tip names the split) and apply the unit's change there.

Limits: nothing a player, a test or a tool can observe changes. No test is deleted or weakened; a test changes only to follow a moved or renamed call. Add no code comments. Do not start sub-agents. Run every command in the foreground to completion and never end your turn while a command runs. Other units are in flight in most directories, so change only this unit's files and the lines the merge forces, and list every line you changed outside the unit's own files.

Done looks like: one pool implementation, in `fx_library.gd` (give the grep that shows no second copy); `machine_fx.gd` holds no `SpecialCues` forwarder and every caller calls the owner.

Rules that bind every unit: when a new call or a new home replaces an old one, every caller moves in the same commit and the old one is deleted, with no forwarding copy left behind; no code comment is added (only tool-read lines and engine quirk notes are allowed); no test is deleted or weakened, and a test changes only to follow a moved or renamed call; no `package.json` is edited unless the instructions above say Andrew approved it; every new `.gd` file has a tracked `.gd.uid` beside it; `scripts/sketch-lint.baseline.json` gains no entry.

## What to check, at least

1. **Behaviour is unchanged.** For every moved or renamed function the body is the same; for every new call, compare what each caller read or did before with what it gets now, for every input: same value, same object (not a copy) where the caller keeps or mutates it, same order of side effects and signals.
2. **No caller was missed.** For each old name, search the head for remaining uses in `src/`, `tests/`, `tools/`, `scripts/`, `.tscn` and `.tres` files and string calls (`call("name"`, `has_method("name"`, `Callable(x, "name")`, `get("name")`), including uses through an alias (a `const X := preload(...)` under another name) or `load("...")` at run time. A missed caller is a blocking issue because it fails only at run time.
3. **Names.** A new public name does not collide with a member of the same class, a subclass, a parent or a test double, and does not shadow a local variable or parameter in a way that changes meaning.
4. **Nothing is left behind and nothing is forced.** No forwarding copy, no dead code the change orphaned, no new layer that only passes calls through, no file split whose new file calls back into its parent for most of its work. Where the writer left an item with a reason, say whether the reason holds.
5. **The guard** (if the unit adds or extends one) fails on the old form, cannot pass by matching nothing (check its patterns against the head), and its allowed lists can only shrink. For every check, guard or tool the unit adds, name each way it could report a pass without having checked: an input that does not exist or is misspelt, a read that failed (a file, a git call, a fetch), an empty list. One that passes in any of those cases is a blocking issue; it must fail and say why.
6. **Formal models.** `.agents/skills/scrapkeep-verify-formal/SKILL.md` lists the files covered by a formal model. The models were not run. Say exactly which lines of covered files this unit changed and whether any of them changes how the modelled state is read, stepped, held or ended.
7. **Scope.** List every file the unit changed outside the area its instructions name, and whether a rename or a moved path forces each.
8. **Fit with the integration branch.** Run `git merge-tree --write-tree 52d874d0bd36b313a25f5947ad22ebaa25689155 4c8fc4333e160fb8254fb10d42bcf12e97ec6a90` (it writes no branch and touches no file in the checkout) and report any conflict. Look for a caller of an old name that exists at `52d874d0bd36b313a25f5947ad22ebaa25689155` but not in the unit's diff, because a clean merge would leave it broken, and for a name this unit uses that a landed unit moved.
This unit was first written on an older base, then caught up: its head merged the integration tip `7d7bc3d6c310ee8eb7c88a435450e91d2391e366`, and the integration branch is now at `52d874d0bd36b313a25f5947ad22ebaa25689155`. Its own change is `git diff 7d7bc3d6c310ee8eb7c88a435450e91d2391e366 4c8fc4333e160fb8254fb10d42bcf12e97ec6a90`, four files. The writer reported `ISSUES` for one reason only: a wide extra test run never got a machine slot, so beyond the automatic selection only eight directly related tests ran. That gap is closed by the full gate, not by you; say in a note which tests you would want run before merge and why.

9. **One owner for the effect pools.** Read `FxLibrary.pools(root, name)` (and anything else the unit added to the library) at the head, and the code it replaced in `src/presentation/vfx.gd` and any other caller at the base. Say whether the pools are built with the same sizes, the same node names and parents, in the same order, and with the same materials; whether a pool that was per-owner became shared between owners or the reverse; and what `name` is used for. A change in how many nodes exist, in their order in the tree, or in which material instance they share is a behaviour change and a blocking issue unless a test pins it as equal.
10. **The resolved conflict.** `_build_fx` in `src/presentation/vfx.gd` conflicted with a landed unit: the head should keep this unit's `_fx = FxLibrary.pools(root, "vfx")` and the integration branch's `FxLibrary.TINT`. Read the function at `7d7bc3d6c310ee8eb7c88a435450e91d2391e366`, at the head and in the unit's commit before the merge, and say whether both sides survive whole.
11. **Lifetime.** Say who frees the pools and when, and whether a scene change, a retry or the shared test batch (`tools/test_batch_driver.gd`) can leave a pool pointing at freed nodes. Compare with the base.
12. **No caller missed.** Name every function or field the unit removed and search the head and `52d874d0bd36b313a25f5947ad22ebaa25689155` for uses, including string calls and test reads of private fields such as `_fx`.
13. **The lint list.** `git diff 7d7bc3d6c310ee8eb7c88a435450e91d2391e366 4c8fc4333e160fb8254fb10d42bcf12e97ec6a90 -- scripts/sketch-lint.baseline.json` must print nothing.
14. **Tests.** Say what in the four files is test code and whether any assertion was removed or loosened.
15. **Fit with the other open units.** Run `git merge-tree --write-tree <other> 4c8fc4333e160fb8254fb10d42bcf12e97ec6a90` for `origin/entropy/b4-build-boss-movement-seams`, `origin/entropy/c3-core-upward-loads`, `origin/entropy/c4-event-juice`, `origin/entropy/f1-fx-pools`, `origin/entropy/m3-combat-collaborator-calls-2`, `origin/entropy/u3-ui-leaves-down`, `origin/entropy/w3-world-seams-2`, `origin/entropy/x1-experimental-duplicates` and `origin/entropy/x3-experimental-dev-seams-2` (skip this unit's own branch and any that does not exist). Report each conflict by file. Then look past the text: name any function, constant or file this unit renames, moves or deletes that one of those branches still uses at its head (`git grep -n -F '<name>' origin/<branch> -- sketches/core-loop`), because a clean text merge would leave that caller broken. Each is a note for the coordinator, not a blocking issue.


## Report

Lead with `VERDICT: PASS` or `VERDICT: FAIL`. Then, apart from each other: blocking issues (each with the file, the function or a `git grep` pattern that finds it, and what is wrong), and notes (things that do not block). For each note that is a small fix, say whether the coordinator can apply it while merging without another review. End with a receipt: your model and effort, the commits you checked, your method, and what you did not do. Write for a reader who has not seen this brief: plain words, full file paths, no shorthand.
