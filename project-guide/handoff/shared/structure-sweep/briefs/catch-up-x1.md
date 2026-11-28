You are bringing unit X1 of the Scrapkeep structure sweep up to date. Scrapkeep is a Godot 4.7.2 GDScript game under `sketches/core-loop` with a Node toolchain under `scripts/`. The sweep removes duplicate code, wrong-way dependencies and private reach-ins without changing anything a player or a test can observe. Another session wrote this unit earlier; it is finished and pushed, but it has fallen behind the integration branch. Your job is to merge the integration branch into it, keep the unit's change intact, prove it still holds, and push. You add no new work to the unit.

## Read first

Run `git fetch origin`. Read `git show origin/entropy/records:project-guide/handoff/STRUCTURE-SWEEP.md`, the section "Rules for every writer": its hard limits, checks and hand-in rules bind you. Read `AGENTS.md` in your checkout.

## The unit

Unit X1 is pull request 1323 (https://github.com/bananahana720/scrapkeep/pull/1323), branch `entropy/x1-experimental-duplicates`, head `a3eabfc9beb6e1ce879752dbf6e32cc766f0f14b`. It routes the experimental `never_brake` calls to `EventDirector` (Part A) and gives the environment-tag vocabulary, the payload builders and the validators one owner in `src/experimental/env_tags.gd` (Part B). Findings `XD-02` and `XD-03` in `git show origin/entropy/records:project-guide/handoff/shared/structure-sweep/experimental-dev.md`. Read its commits (`git log -p 7d7bc3d6c310ee8eb7c88a435450e91d2391e366..a3eabfc9beb6e1ce879752dbf6e32cc766f0f14b`) before you merge, so you know what it changed and why.

## Set up

Your checkout may start on another commit, and the branch name `entropy/x1-experimental-duplicates` may be checked out in another checkout on this machine, so work on a local branch of your own and push to the unit's branch:

```
git fetch origin
git switch -c x1-catch-up a3eabfc9beb6e1ce879752dbf6e32cc766f0f14b
git rev-parse HEAD
```

`git rev-parse HEAD` must print `a3eabfc9beb6e1ce879752dbf6e32cc766f0f14b`; stop with `BLOCKED` if it does not. Then follow the set-up steps of the rules page (`npm run worktree:deps`, the scratch `HOME`, the import).

## The work

1. `git merge 7d7bc3d6c310ee8eb7c88a435450e91d2391e366` (the integration tip; check that `git rev-parse origin/entropy/gate` contains it with `git merge-base --is-ancestor 7d7bc3d6c310ee8eb7c88a435450e91d2391e366 origin/entropy/gate`). Known conflicts: none in text (`git merge-tree` reports a clean merge), but more than thirty units landed since its base, among them one that changed `src/experimental/live_run_bridge.gd`, `src/dev/` and the experimental audio bank, and one that added `clear_families()` to `src/world/event_director.gd`. A clean text merge can still leave a caller on a name that no longer exists. Resolve each by hand so that both sides' intent survives: the integration branch's later changes stay, and the unit's change is applied on top of them. Say which files conflicted and how you resolved each.
2. After the merge, for every name the unit moved, renamed or deleted, search the whole tree for a stale use (`git grep -n -F '<name>' -- sketches/core-loop scripts`), including `.tscn`, `.tres` and string calls such as `call("name"`. Fix each stale use by pointing it at the unit's owner. Check the other way too: that the unit uses no name a landed unit moved.
3. In `scripts/sketch-lint.baseline.json` keep the integration branch's lists; remove only an entry the lint reports as `no longer offends`; never add an entry and never pass `--write-baseline`.
4. `src/world/event_director.gd` is covered by a formal model: after the merge, say exactly which of its lines differ from the integration tip because of this unit.

Limits: nothing a player, a test or a tool can observe changes. No test is deleted or weakened; a test changes only to follow a moved or renamed call. Add no code comments. Do not start sub-agents. Run every command in the foreground to completion and never end your turn while a command runs. Other units are in flight in most directories, so change only this unit's files and the lines the merge forces, and list every line you changed outside the unit's own files.

Done looks like: the unit's two parts are intact on top of the integration tip; `git grep` for each name the unit moved or deleted shows no stale caller in `src/`, `tests/` or `tools/`.

## Checks

Start every shell line with `export PATH=/opt/homebrew/bin:$PATH GODOT_BIN="$HOME/Applications/Godot_4.7.2.app/Contents/MacOS/Godot"`, and run Godot only with `HOME` set to a scratch folder under `artifacts/local/` as the rules page says. After your last commit make one call of `npm run sketch:fast -- --base 7d7bc3d6c310ee8eb7c88a435450e91d2391e366`. It picks tests from the changed files; make sure every test file the unit changed and those found by `git grep -l -i -E 'experimental|env_tag|never_brake|setpiece|encounter|adversity|refurbished|live_run|live_world' -- sketches/core-loop/tests` ran, and if any did not, run them in one more call with `--test` (on this repo `--test` replaces the automatic selection, so that second call is in addition to the first, not instead of it). Then `npm run sketch:lint`. `npm run sketch:fast` may wait several minutes for a machine slot before it starts: that is normal, wait for it, and make one call rather than several. Known failures that are not yours: `tests/profile_purity_test.gd` and `tests/slice1_patch_and_w1_craft_test.gd` are red on the base, and `tests/fub_ramp_flash_test.gd` can fail when it runs after `tests/enemy_ramp_flipper_asset_test.gd` in one process; rerun any other red alone before you call it red.

## Hand in

Push with `git push origin HEAD:entropy/x1-experimental-duplicates` (if the push is declined, do not try another way: report `BLOCKED` with the local commit SHA). Do not open a new pull request; pull request 1323 follows the branch. Lead your final message with `PASS`, `ISSUES` or `BLOCKED`. Give the integration tip you merged, the files that conflicted and how you resolved them, the stale uses you fixed, the `git grep` output behind "done looks like", the last lines of each check, and your model and effort. End with the line `PR https://github.com/bananahana720/scrapkeep/pull/1323, head <SHA>, checks and reviews <state>`.
