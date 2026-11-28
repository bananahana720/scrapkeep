You are bringing unit F1 of the Scrapkeep structure sweep up to date. Scrapkeep is a Godot 4.7.2 GDScript game under `sketches/core-loop` with a Node toolchain under `scripts/`. The sweep removes duplicate code, wrong-way dependencies and private reach-ins without changing anything a player or a test can observe. Another session wrote this unit earlier; it is finished and pushed, but it has fallen behind the integration branch. Your job is to merge the integration branch into it, keep the unit's change intact, prove it still holds, and push. You add no new work to the unit.

## Read first

Run `git fetch origin`. Read `git show origin/entropy/records:project-guide/handoff/STRUCTURE-SWEEP.md`, the section "Rules for every writer": its hard limits, checks and hand-in rules bind you. Read `AGENTS.md` in your checkout.

## The unit

Unit F1 is pull request 1325 (https://github.com/bananahana720/scrapkeep/pull/1325), branch `entropy/f1-fx-pools`, head `265f34a0b20f09ab20155bfa4a91c84cf999c0f7`. It puts the owner-filtered effect pools in `src/presentation/fx_library.gd` (finding `VF-02`) and removes the `SpecialCues` forwarders from `src/presentation/machine_fx.gd` (finding `VF-13`); four files. The findings are in `git show origin/entropy/records:project-guide/handoff/shared/structure-sweep/visuals-fx.md` (list the folder with `git ls-tree --name-only origin/entropy/records project-guide/handoff/shared/structure-sweep/` if that name is not there). Read its commits (`git log -p 7d7bc3d6c310ee8eb7c88a435450e91d2391e366..265f34a0b20f09ab20155bfa4a91c84cf999c0f7`) before you merge, so you know what it changed and why.

## Set up

Your checkout may start on another commit, and the branch name `entropy/f1-fx-pools` may be checked out in another checkout on this machine, so work on a local branch of your own and push to the unit's branch:

```
git fetch origin
git switch -c f1-catch-up 265f34a0b20f09ab20155bfa4a91c84cf999c0f7
git rev-parse HEAD
```

`git rev-parse HEAD` must print `265f34a0b20f09ab20155bfa4a91c84cf999c0f7`; stop with `BLOCKED` if it does not. Then follow the set-up steps of the rules page (`npm run worktree:deps`, the scratch `HOME`, the import).

## The work

1. `git merge 7d7bc3d6c310ee8eb7c88a435450e91d2391e366` (the integration tip; check that `git rev-parse origin/entropy/gate` contains it with `git merge-base --is-ancestor 7d7bc3d6c310ee8eb7c88a435450e91d2391e366 origin/entropy/gate`). Known conflicts: `sketches/core-loop/src/presentation/vfx.gd`. A unit that landed since split `vfx.gd` into several files, so the lines this unit changed may now live in another file under `src/presentation/`. Resolve each by hand so that both sides' intent survives: the integration branch's later changes stay, and the unit's change is applied on top of them. Say which files conflicted and how you resolved each.
2. After the merge, for every name the unit moved, renamed or deleted, search the whole tree for a stale use (`git grep -n -F '<name>' -- sketches/core-loop scripts`), including `.tscn`, `.tres` and string calls such as `call("name"`. Fix each stale use by pointing it at the unit's owner. Check the other way too: that the unit uses no name a landed unit moved.
3. In `scripts/sketch-lint.baseline.json` keep the integration branch's lists; remove only an entry the lint reports as `no longer offends`; never add an entry and never pass `--write-baseline`.
4. Find where each line this unit changed in `vfx.gd` lives now (`git log --oneline --first-parent -- sketches/core-loop/src/presentation/vfx.gd` on the integration tip names the split) and apply the unit's change there.

Limits: nothing a player, a test or a tool can observe changes. No test is deleted or weakened; a test changes only to follow a moved or renamed call. Add no code comments. Do not start sub-agents. Run every command in the foreground to completion and never end your turn while a command runs. Other units are in flight in most directories, so change only this unit's files and the lines the merge forces, and list every line you changed outside the unit's own files.

Done looks like: one pool implementation, in `fx_library.gd` (give the grep that shows no second copy); `machine_fx.gd` holds no `SpecialCues` forwarder and every caller calls the owner.

## Checks

Start every shell line with `export PATH=/opt/homebrew/bin:$PATH GODOT_BIN="$HOME/Applications/Godot_4.7.2.app/Contents/MacOS/Godot"`, and run Godot only with `HOME` set to a scratch folder under `artifacts/local/` as the rules page says. After your last commit make one call of `npm run sketch:fast -- --base 7d7bc3d6c310ee8eb7c88a435450e91d2391e366`. It picks tests from the changed files; make sure every test file the unit changed and those found by `git grep -l -i -E 'fx_library|machine_fx|special_cues|vfx|fx_pool|pool|bead|burst' -- sketches/core-loop/tests` ran, and if any did not, run them in one more call with `--test` (on this repo `--test` replaces the automatic selection, so that second call is in addition to the first, not instead of it). Then `npm run sketch:lint`. `npm run sketch:fast` may wait several minutes for a machine slot before it starts: that is normal, wait for it, and make one call rather than several. Known failures that are not yours: `tests/profile_purity_test.gd` and `tests/slice1_patch_and_w1_craft_test.gd` are red on the base, and `tests/fub_ramp_flash_test.gd` can fail when it runs after `tests/enemy_ramp_flipper_asset_test.gd` in one process; rerun any other red alone before you call it red.

## Hand in

Push with `git push origin HEAD:entropy/f1-fx-pools` (if the push is declined, do not try another way: report `BLOCKED` with the local commit SHA). Do not open a new pull request; pull request 1325 follows the branch. Lead your final message with `PASS`, `ISSUES` or `BLOCKED`. Give the integration tip you merged, the files that conflicted and how you resolved them, the stale uses you fixed, the `git grep` output behind "done looks like", the last lines of each check, and your model and effort. End with the line `PR https://github.com/bananahana720/scrapkeep/pull/1325, head <SHA>, checks and reviews <state>`.
