You are the independent reviewer of one pull request in the Scrapkeep repository (GitHub `bananahana720/scrapkeep`). Scrapkeep is a Godot 4.7.2 GDScript game under `sketches/core-loop` with a Node toolchain under `scripts/`. You did not write this change and you have not seen the writer's reasoning. Judge the diff against what the unit was asked to do, below.

## Hard limits

- Write nothing. Use read-only git only (`git fetch`, `git show`, `git diff`, `git log`, `git grep <pattern> <commit> -- <path>`, `git ls-tree`, `git merge-tree`). Do not check out, switch, stash, commit, push, edit a file, comment on the pull request or start a sub-agent. Other sessions share this checkout.
- Do not run Godot, `npm run sketch:fast` or any test. The coordinator runs them when it merges. Read the code.
- On this Mac `git grep -E` does not honour `\b`; write patterns without it.

## What to review

Pull request 1324 (https://github.com/bananahana720/scrapkeep/pull/1324), unit C4, branch `origin/entropy/c4-event-juice`, head `389d5a6da658787b2d521ac0cc91df48b85247b7`. Run `git fetch origin` and check that `git rev-parse origin/entropy/c4-event-juice` prints that head; if it does not, say so and review what is there. The unit's own change is `git diff 7d7bc3d6c310ee8eb7c88a435450e91d2391e366 389d5a6da658787b2d521ac0cc91df48b85247b7`; if the head contains merges of the integration branch, read the unit's change as `git diff 52d874d0bd36b313a25f5947ad22ebaa25689155...389d5a6da658787b2d521ac0cc91df48b85247b7` and `git log --first-parent 7d7bc3d6c310ee8eb7c88a435450e91d2391e366..389d5a6da658787b2d521ac0cc91df48b85247b7` so that other units' landed work is not judged as this unit's. The integration branch is `origin/entropy/gate`, now at `52d874d0bd36b313a25f5947ad22ebaa25689155`.

## What the unit was asked to do

The words below are the writer's instructions, copied unchanged. Lines that tell the writer how to set up or what to run are not for you; the description of the change and "Done looks like" are what you judge against.

Unit C4 is pull request 1324 (https://github.com/bananahana720/scrapkeep/pull/1324), branch `entropy/c4-event-juice`, head `9abf33025356d190a6b8ae0c74dae08e60dc6db3`. It moves the display weighting out of `src/core/event_kinds.gd` into `src/presentation/event_juice.gd`, so that a `core` file no longer holds presentation data (24 files, mostly callers and tests). Finding `CORE-04` in `git show origin/entropy/records:project-guide/handoff/shared/structure-sweep/core.md`. Read its commits (`git log -p 7d7bc3d6c310ee8eb7c88a435450e91d2391e366..9abf33025356d190a6b8ae0c74dae08e60dc6db3`) before you merge, so you know what it changed and why.

### Set up

Your checkout may start on another commit, and the branch name `entropy/c4-event-juice` may be checked out in another checkout on this machine, so work on a local branch of your own and push to the unit's branch:

```
git fetch origin
git switch -c c4-catch-up 9abf33025356d190a6b8ae0c74dae08e60dc6db3
git rev-parse HEAD
```

`git rev-parse HEAD` must print `9abf33025356d190a6b8ae0c74dae08e60dc6db3`; stop with `BLOCKED` if it does not. Then follow the set-up steps of the rules page (`npm run worktree:deps`, the scratch `HOME`, the import).

### The work

1. `git merge 7d7bc3d6c310ee8eb7c88a435450e91d2391e366` (the integration tip; check that `git rev-parse origin/entropy/gate` contains it with `git merge-base --is-ancestor 7d7bc3d6c310ee8eb7c88a435450e91d2391e366 origin/entropy/gate`). Known conflicts: `sketches/core-loop/src/core/event_kinds.gd`, `sketches/core-loop/tests/combat_juice_elevation_test.gd` and `sketches/core-loop/tests/unit/weight_table_case.gd`. Units that landed since moved the shared weight-table helper and several core tables. Resolve each by hand so that both sides' intent survives: the integration branch's later changes stay, and the unit's change is applied on top of them. Say which files conflicted and how you resolved each.
2. After the merge, for every name the unit moved, renamed or deleted, search the whole tree for a stale use (`git grep -n -F '<name>' -- sketches/core-loop scripts`), including `.tscn`, `.tres` and string calls such as `call("name"`. Fix each stale use by pointing it at the unit's owner. Check the other way too: that the unit uses no name a landed unit moved.
3. In `scripts/sketch-lint.baseline.json` keep the integration branch's lists; remove only an entry the lint reports as `no longer offends`; never add an entry and never pass `--write-baseline`.
4. If a landed unit already moved part of what this unit moves, keep the landed form and drop this unit's copy of that part; say which. A new script needs its `.gd.uid` file committed beside it.

Limits: nothing a player, a test or a tool can observe changes. No test is deleted or weakened; a test changes only to follow a moved or renamed call. Add no code comments. Do not start sub-agents. Run every command in the foreground to completion and never end your turn while a command runs. Other units are in flight in most directories, so change only this unit's files and the lines the merge forces, and list every line you changed outside the unit's own files.

Done looks like: `src/core/event_kinds.gd` holds no display weighting (give the grep); every reader of the moved names in `src/`, `tests/` and `tools/` reads `event_juice.gd`; no forwarding copy stays in `event_kinds.gd`.

Rules that bind every unit: when a new call or a new home replaces an old one, every caller moves in the same commit and the old one is deleted, with no forwarding copy left behind; no code comment is added (only tool-read lines and engine quirk notes are allowed); no test is deleted or weakened, and a test changes only to follow a moved or renamed call; no `package.json` is edited unless the instructions above say Andrew approved it; every new `.gd` file has a tracked `.gd.uid` beside it; `scripts/sketch-lint.baseline.json` gains no entry.

## What to check, at least

1. **Behaviour is unchanged.** For every moved or renamed function the body is the same; for every new call, compare what each caller read or did before with what it gets now, for every input: same value, same object (not a copy) where the caller keeps or mutates it, same order of side effects and signals.
2. **No caller was missed.** For each old name, search the head for remaining uses in `src/`, `tests/`, `tools/`, `scripts/`, `.tscn` and `.tres` files and string calls (`call("name"`, `has_method("name"`, `Callable(x, "name")`, `get("name")`), including uses through an alias (a `const X := preload(...)` under another name) or `load("...")` at run time. A missed caller is a blocking issue because it fails only at run time.
3. **Names.** A new public name does not collide with a member of the same class, a subclass, a parent or a test double, and does not shadow a local variable or parameter in a way that changes meaning.
4. **Nothing is left behind and nothing is forced.** No forwarding copy, no dead code the change orphaned, no new layer that only passes calls through, no file split whose new file calls back into its parent for most of its work. Where the writer left an item with a reason, say whether the reason holds.
5. **The guard** (if the unit adds or extends one) fails on the old form, cannot pass by matching nothing (check its patterns against the head), and its allowed lists can only shrink. For every check, guard or tool the unit adds, name each way it could report a pass without having checked: an input that does not exist or is misspelt, a read that failed (a file, a git call, a fetch), an empty list. One that passes in any of those cases is a blocking issue; it must fail and say why.
6. **Formal models.** `.agents/skills/scrapkeep-verify-formal/SKILL.md` lists the files covered by a formal model. The models were not run. Say exactly which lines of covered files this unit changed and whether any of them changes how the modelled state is read, stepped, held or ended.
7. **Scope.** List every file the unit changed outside the area its instructions name, and whether a rename or a moved path forces each.
8. **Fit with the integration branch.** Run `git merge-tree --write-tree 52d874d0bd36b313a25f5947ad22ebaa25689155 389d5a6da658787b2d521ac0cc91df48b85247b7` (it writes no branch and touches no file in the checkout) and report any conflict. Look for a caller of an old name that exists at `52d874d0bd36b313a25f5947ad22ebaa25689155` but not in the unit's diff, because a clean merge would leave it broken, and for a name this unit uses that a landed unit moved.
This unit was first written on an older base, then caught up: its head merged the integration tip `7d7bc3d6c310ee8eb7c88a435450e91d2391e366`, and the integration branch is now at `52d874d0bd36b313a25f5947ad22ebaa25689155`. The unit's own change is `git diff 7d7bc3d6c310ee8eb7c88a435450e91d2391e366 389d5a6da658787b2d521ac0cc91df48b85247b7`. The catch-up resolved three merge conflicts and moved more than the first brief asked, so judge the head as it stands.

9. **One owner for the event feel table.** Read `sketches/core-loop/src/presentation/event_juice.gd` at the head: it keeps `JUICE`, `juice()`, the `STOP_` constants and `stop_ms_for`. Compare each table row and each function body with what it replaced at the base (the copies in `src/core/event_kinds.gd` and anywhere else): same keys, same numbers, same defaults for a missing kind. A number that changed is a blocking issue.
10. **The second move.** To stay out of a dependency loop the catch-up moved `weigh`, `WEIGHT`, `WEIGHTED` and `WEIGHT_EXEMPT` into `src/presentation/rows.gd`. Compare bodies and tables with the base. List every caller (`src/presentation/juice.gd`, `tests/spine_event_kinds_test.gd`, `tests/unit/impact_table_case.gd`, `tests/unit/weight_table_case.gd`, `tests/w45_combat_feel_test.gd` and any other) and confirm none still reads the old home. Say whether `rows.gd` is a fitting owner for weights (what else it holds) or whether the move only relabels a wrong-way dependency.
11. **The three resolved conflicts** (`src/core/event_kinds.gd`, `tests/combat_juice_elevation_test.gd`, `tests/unit/weight_table_case.gd`). For each, read the file at `7d7bc3d6c310ee8eb7c88a435450e91d2391e366`, at the head and in the unit's commit before the merge, and say whether the head keeps both sides: nothing the integration branch added is lost, and nothing the unit deleted came back.
12. **The lint list.** `git diff 7d7bc3d6c310ee8eb7c88a435450e91d2391e366 389d5a6da658787b2d521ac0cc91df48b85247b7 -- scripts/sketch-lint.baseline.json` must only remove lines (the writer says 14 under `L16`, none added). Any added line is a blocking issue. Say which load the unit cut to take those files off the loop list, and whether any file under `src/core` at the head still loads a file under `src/presentation`.
13. **The `.uid` file.** `event_juice.gd.uid` was missing and is now committed. Confirm every `.gd` the unit adds or moves has its `.gd.uid` and no `.uid` is left without its script.
14. **Pages and one comment.** The unit repointed `sketches/core-loop/CONTRACTS.md`, `sketches/core-loop/design-v3/FEEL-READABILITY.md` and the header comment of `tests/w45_combat_feel_test.gd`. A dated record of past work (a ledger, a receipt, a wave memo, a snapshot kept verbatim, an entry in `sketches/core-loop/DESIGN-NOTES.md`, a design spec that carries a date or calls itself historical) is never edited, not even to follow a moved path or a renamed function. A page that describes the project as it is must follow the code. Read the top of `FEEL-READABILITY.md` and say which kind it is; if it is a dated record, any edit to it is a blocking issue. Say whether the comment change adds a comment or only corrects a path in one that was there.
15. **Tests.** No assertion removed or loosened: list each test file changed and what changed in it. `tests/prim_census_test.gd` is red at the head and on its base alike according to the writer (67 surfaces against 68 pinned); say whether anything in this unit's diff could change a surface count.
16. **The tool.** `tools/fx_capture.gd` changed; say what and why.
17. **Fit with the other open units.** Run `git merge-tree --write-tree <other> 389d5a6da658787b2d521ac0cc91df48b85247b7` for `origin/entropy/b4-build-boss-movement-seams`, `origin/entropy/c3-core-upward-loads`, `origin/entropy/c4-event-juice`, `origin/entropy/f1-fx-pools`, `origin/entropy/m3-combat-collaborator-calls-2`, `origin/entropy/u3-ui-leaves-down`, `origin/entropy/w3-world-seams-2`, `origin/entropy/x1-experimental-duplicates` and `origin/entropy/x3-experimental-dev-seams-2` (skip this unit's own branch and any that does not exist). Report each conflict by file. Then look past the text: name any function, constant or file this unit renames, moves or deletes that one of those branches still uses at its head (`git grep -n -F '<name>' origin/<branch> -- sketches/core-loop`), because a clean text merge would leave that caller broken. Each is a note for the coordinator, not a blocking issue.


## Report

Lead with `VERDICT: PASS` or `VERDICT: FAIL`. Then, apart from each other: blocking issues (each with the file, the function or a `git grep` pattern that finds it, and what is wrong), and notes (things that do not block). For each note that is a small fix, say whether the coordinator can apply it while merging without another review. End with a receipt: your model and effort, the commits you checked, your method, and what you did not do. Write for a reader who has not seen this brief: plain words, full file paths, no shorthand.
