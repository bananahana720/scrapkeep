You are bringing unit S2 of the Scrapkeep structure sweep up to date. Scrapkeep is a Godot 4.7.2 GDScript game under `sketches/core-loop` with a Node toolchain under `scripts/`. The sweep removes duplicate code, wrong-way dependencies and private reach-ins without changing anything a player or a test can observe. Another session wrote this unit earlier; it is finished and pushed, but it has fallen behind the integration branch. Your job is to merge the integration branch into it, keep the unit's change intact, prove it still holds, and push. You add no new work to the unit.

## Read first

Run `git fetch origin`. Read `git show origin/entropy/records:project-guide/handoff/STRUCTURE-SWEEP.md`, the section "Rules for every writer": its hard limits, checks and hand-in rules bind you. Read `AGENTS.md` in your checkout.

## The unit

Unit S2 is pull request 1293 (https://github.com/bananahana720/scrapkeep/pull/1293), branch `entropy/s2-node-test-discovery`, head `f0d01f69145c46ba83f7bfc12f0e744a2b09aa28`. It makes `scripts/ci/node-tests.mjs` list the Node test files from the disk, so that a new test file cannot be left off a hand-kept list, and replaces the `"test"` line of the root `package.json` with `node scripts/ci/node-tests.mjs`. It changes three files: `package.json` (that one line), `scripts/ci/node-tests.mjs` and `scripts/ci/node-tests.test.mjs`. Read its commits (`git log -p 7d7bc3d6c310ee8eb7c88a435450e91d2391e366..f0d01f69145c46ba83f7bfc12f0e744a2b09aa28`) before you merge, so you know what it changed and why.

## Set up

Your checkout may start on another commit, and the branch name `entropy/s2-node-test-discovery` may be checked out in another checkout on this machine, so work on a local branch of your own and push to the unit's branch:

```
git fetch origin
git switch -c s2-catch-up f0d01f69145c46ba83f7bfc12f0e744a2b09aa28
git rev-parse HEAD
```

`git rev-parse HEAD` must print `f0d01f69145c46ba83f7bfc12f0e744a2b09aa28`; stop with `BLOCKED` if it does not. Then follow the set-up steps of the rules page (`npm run worktree:deps`, the scratch `HOME`, the import).

## The work

1. `git merge 7d7bc3d6c310ee8eb7c88a435450e91d2391e366` (the integration tip; check that `git rev-parse origin/entropy/gate` contains it with `git merge-base --is-ancestor 7d7bc3d6c310ee8eb7c88a435450e91d2391e366 origin/entropy/gate`). Known conflicts: `scripts/ci/node-tests.mjs` and `scripts/ci/node-tests.test.mjs`. Since the unit was written, the integration branch gave the runner duration-balanced shards (`--shard INDEX/TOTAL`, `DURATION_HINTS_MS`), a seeded `--shuffle`, and a mode that keeps unbundled Node tests under `--ci-godot-only`; today the runner still reads its file list out of the `"test"` line of `package.json`. Resolve each by hand so that both sides' intent survives: the integration branch's later changes stay, and the unit's change is applied on top of them. Say which files conflicted and how you resolved each.
2. After the merge, for every name the unit moved, renamed or deleted, search the whole tree for a stale use (`git grep -n -F '<name>' -- sketches/core-loop scripts`), including `.tscn`, `.tres` and string calls such as `call("name"`. Fix each stale use by pointing it at the unit's owner. Check the other way too: that the unit uses no name a landed unit moved.
3. In `scripts/sketch-lint.baseline.json` keep the integration branch's lists; remove only an entry the lint reports as `no longer offends`; never add an entry and never pass `--write-baseline`.
4. **The `package.json` line.** The rules page forbids touching `package.json`. This unit is the one exception: Andrew approved exactly this one-line edit on 27 November 2026. Change that line and nothing else in the file: no dependency, no other script, no lock file. Keep every option the runner has today (shards, hints, shuffle, seed, the Godot-only mode) working as it does now, with the file list coming from the disk in place of `package.json`. Read every caller of the runner first: `git grep -n 'node-tests' -- .github scripts package.json CONTRIBUTING.md AGENTS.md project-guide`. A test file on disk that must not run in the plain `npm test` (a fixture, a file another command runs) goes on one short exclusion list in the runner with a reason beside it in a test assertion, and a test in `scripts/ci/node-tests.test.mjs` fails when a `*.test.mjs` or `tests/*.test.js` file on disk is neither run nor on that list. `scripts/godot-home.test.mjs` must be among the files that run.

Limits: nothing a player, a test or a tool can observe changes. No test is deleted or weakened; a test changes only to follow a moved or renamed call. Add no code comments. Do not start sub-agents. Run every command in the foreground to completion and never end your turn while a command runs. Other units are in flight in most directories, so change only this unit's files and the lines the merge forces, and list every line you changed outside the unit's own files.

Done looks like: `npm test` runs the runner; `git grep -n 'node --test' -- package.json` shows nothing; the runner holds no hand-kept list of files to run; the shard forms CI uses still partition every file exactly once; `git diff 7d7bc3d6c310ee8eb7c88a435450e91d2391e366 -- package.json` shows one changed line.

## Checks

This unit changes no Godot file, so do not run Godot or `npm run sketch:fast`. Start every shell line with `export PATH=/opt/homebrew/bin:$PATH`. Run, after your last commit: `npm test` (it must now go through the runner); `node scripts/ci/node-tests.mjs --shuffle`; each shard form the CI workflow uses (read `.github/workflows/ci.yml` for the exact calls, run each, and check that the shards together run every file exactly once); `npm run lint:js`; `npm run format:check`; `npm run check:project`; `npm run check:docs` if you changed a Markdown file. A known failure that is not yours: `scripts/budget-audit.test.mjs` can be red on the base; check it on the base before you call it yours.

## Hand in

Push with `git push origin HEAD:entropy/s2-node-test-discovery` (if the push is declined, do not try another way: report `BLOCKED` with the local commit SHA). Do not open a new pull request; pull request 1293 follows the branch. Lead your final message with `PASS`, `ISSUES` or `BLOCKED`. Give the integration tip you merged, the files that conflicted and how you resolved them, the stale uses you fixed, the `git grep` output behind "done looks like", the last lines of each check, and your model and effort. End with the line `PR https://github.com/bananahana720/scrapkeep/pull/1293, head <SHA>, checks and reviews <state>`.
