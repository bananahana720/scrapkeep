You are the independent reviewer of one pull request in the Scrapkeep repository (GitHub `bananahana720/scrapkeep`). Scrapkeep is a Godot 4.7.2 GDScript game under `sketches/core-loop` with a Node toolchain under `scripts/`. You did not write this change and you have not seen the writer's reasoning. Judge the diff against what the unit was asked to do, below.

## Hard limits

- Write nothing. Use read-only git only (`git fetch`, `git show`, `git diff`, `git log`, `git grep <pattern> <commit> -- <path>`, `git ls-tree`, `git merge-tree`). Do not check out, switch, stash, commit, push, edit a file, comment on the pull request or start a sub-agent. Other sessions share this checkout.
- Do not run Godot, `npm run sketch:fast` or any test. The coordinator runs them when it merges. Read the code.
- On this Mac `git grep -E` does not honour `\b`; write patterns without it.

## What to review

Pull request 1293 (https://github.com/bananahana720/scrapkeep/pull/1293), unit S2, branch `origin/entropy/s2-node-test-discovery`, head `ef2df1fb2806eeb93d03b1a65e9fe2319e053316`. Run `git fetch origin` and check that `git rev-parse origin/entropy/s2-node-test-discovery` prints that head; if it does not, say so and review what is there. The unit's own change is `git diff 7d7bc3d6c310ee8eb7c88a435450e91d2391e366 ef2df1fb2806eeb93d03b1a65e9fe2319e053316`; if the head contains merges of the integration branch, read the unit's change as `git diff 7d7bc3d6c310ee8eb7c88a435450e91d2391e366...ef2df1fb2806eeb93d03b1a65e9fe2319e053316` and `git log --first-parent 7d7bc3d6c310ee8eb7c88a435450e91d2391e366..ef2df1fb2806eeb93d03b1a65e9fe2319e053316` so that other units' landed work is not judged as this unit's. The integration branch is `origin/entropy/gate`, now at `7d7bc3d6c310ee8eb7c88a435450e91d2391e366`.

## What the unit was asked to do

The words below are the writer's instructions, copied unchanged. Lines that tell the writer how to set up or what to run are not for you; the description of the change and "Done looks like" are what you judge against.

Unit S2 is pull request 1293 (https://github.com/bananahana720/scrapkeep/pull/1293), branch `entropy/s2-node-test-discovery`, head `f0d01f69145c46ba83f7bfc12f0e744a2b09aa28`. It makes `scripts/ci/node-tests.mjs` list the Node test files from the disk, so that a new test file cannot be left off a hand-kept list, and replaces the `"test"` line of the root `package.json` with `node scripts/ci/node-tests.mjs`. It changes three files: `package.json` (that one line), `scripts/ci/node-tests.mjs` and `scripts/ci/node-tests.test.mjs`. Read its commits (`git log -p 7d7bc3d6c310ee8eb7c88a435450e91d2391e366..f0d01f69145c46ba83f7bfc12f0e744a2b09aa28`) before you merge, so you know what it changed and why.

### Set up

Your checkout may start on another commit, and the branch name `entropy/s2-node-test-discovery` may be checked out in another checkout on this machine, so work on a local branch of your own and push to the unit's branch:

```
git fetch origin
git switch -c s2-catch-up f0d01f69145c46ba83f7bfc12f0e744a2b09aa28
git rev-parse HEAD
```

`git rev-parse HEAD` must print `f0d01f69145c46ba83f7bfc12f0e744a2b09aa28`; stop with `BLOCKED` if it does not. Then follow the set-up steps of the rules page (`npm run worktree:deps`, the scratch `HOME`, the import).

### The work

1. `git merge 7d7bc3d6c310ee8eb7c88a435450e91d2391e366` (the integration tip; check that `git rev-parse origin/entropy/gate` contains it with `git merge-base --is-ancestor 7d7bc3d6c310ee8eb7c88a435450e91d2391e366 origin/entropy/gate`). Known conflicts: `scripts/ci/node-tests.mjs` and `scripts/ci/node-tests.test.mjs`. Since the unit was written, the integration branch gave the runner duration-balanced shards (`--shard INDEX/TOTAL`, `DURATION_HINTS_MS`), a seeded `--shuffle`, and a mode that keeps unbundled Node tests under `--ci-godot-only`; today the runner still reads its file list out of the `"test"` line of `package.json`. Resolve each by hand so that both sides' intent survives: the integration branch's later changes stay, and the unit's change is applied on top of them. Say which files conflicted and how you resolved each.
2. After the merge, for every name the unit moved, renamed or deleted, search the whole tree for a stale use (`git grep -n -F '<name>' -- sketches/core-loop scripts`), including `.tscn`, `.tres` and string calls such as `call("name"`. Fix each stale use by pointing it at the unit's owner. Check the other way too: that the unit uses no name a landed unit moved.
3. In `scripts/sketch-lint.baseline.json` keep the integration branch's lists; remove only an entry the lint reports as `no longer offends`; never add an entry and never pass `--write-baseline`.
4. **The `package.json` line.** The rules page forbids touching `package.json`. This unit is the one exception: Andrew approved exactly this one-line edit on 27 November 2026. Change that line and nothing else in the file: no dependency, no other script, no lock file. Keep every option the runner has today (shards, hints, shuffle, seed, the Godot-only mode) working as it does now, with the file list coming from the disk in place of `package.json`. Read every caller of the runner first: `git grep -n 'node-tests' -- .github scripts package.json CONTRIBUTING.md AGENTS.md project-guide`. A test file on disk that must not run in the plain `npm test` (a fixture, a file another command runs) goes on one short exclusion list in the runner with a reason beside it in a test assertion, and a test in `scripts/ci/node-tests.test.mjs` fails when a `*.test.mjs` or `tests/*.test.js` file on disk is neither run nor on that list. `scripts/godot-home.test.mjs` must be among the files that run.

Limits: nothing a player, a test or a tool can observe changes. No test is deleted or weakened; a test changes only to follow a moved or renamed call. Add no code comments. Do not start sub-agents. Run every command in the foreground to completion and never end your turn while a command runs. Other units are in flight in most directories, so change only this unit's files and the lines the merge forces, and list every line you changed outside the unit's own files.

Done looks like: `npm test` runs the runner; `git grep -n 'node --test' -- package.json` shows nothing; the runner holds no hand-kept list of files to run; the shard forms CI uses still partition every file exactly once; `git diff 7d7bc3d6c310ee8eb7c88a435450e91d2391e366 -- package.json` shows one changed line.

Rules that bind every unit: when a new call or a new home replaces an old one, every caller moves in the same commit and the old one is deleted, with no forwarding copy left behind; no code comment is added (only tool-read lines and engine quirk notes are allowed); no test is deleted or weakened, and a test changes only to follow a moved or renamed call; no `package.json` is edited unless the instructions above say Andrew approved it; every new `.gd` file has a tracked `.gd.uid` beside it; `scripts/sketch-lint.baseline.json` gains no entry.

## What to check, at least

1. **Behaviour is unchanged.** For every moved or renamed function the body is the same; for every new call, compare what each caller read or did before with what it gets now, for every input: same value, same object (not a copy) where the caller keeps or mutates it, same order of side effects and signals.
2. **No caller was missed.** For each old name, search the head for remaining uses in `src/`, `tests/`, `tools/`, `scripts/`, `.tscn` and `.tres` files and string calls (`call("name"`, `has_method("name"`, `Callable(x, "name")`, `get("name")`), including uses through an alias (a `const X := preload(...)` under another name) or `load("...")` at run time. A missed caller is a blocking issue because it fails only at run time.
3. **Names.** A new public name does not collide with a member of the same class, a subclass, a parent or a test double, and does not shadow a local variable or parameter in a way that changes meaning.
4. **Nothing is left behind and nothing is forced.** No forwarding copy, no dead code the change orphaned, no new layer that only passes calls through, no file split whose new file calls back into its parent for most of its work. Where the writer left an item with a reason, say whether the reason holds.
5. **The guard** (if the unit adds or extends one) fails on the old form, cannot pass by matching nothing (check its patterns against the head), and its allowed lists can only shrink.
6. **Formal models.** `.agents/skills/scrapkeep-verify-formal/SKILL.md` lists the files covered by a formal model. The models were not run. Say exactly which lines of covered files this unit changed and whether any of them changes how the modelled state is read, stepped, held or ended.
7. **Scope.** List every file the unit changed outside the area its instructions name, and whether a rename or a moved path forces each.
8. **Fit with the integration branch.** Run `git merge-tree --write-tree 7d7bc3d6c310ee8eb7c88a435450e91d2391e366 ef2df1fb2806eeb93d03b1a65e9fe2319e053316` (it writes no branch and touches no file in the checkout) and report any conflict. Look for a caller of an old name that exists at `7d7bc3d6c310ee8eb7c88a435450e91d2391e366` but not in the unit's diff, because a clean merge would leave it broken, and for a name this unit uses that a landed unit moved.
9. **This unit only.** (a) `git diff 7d7bc3d6c310ee8eb7c88a435450e91d2391e366 ef2df1fb2806eeb93d03b1a65e9fe2319e053316 -- package.json` shows exactly one changed line, the `"test"` line; Andrew approved that one line on 27 November 2026. The line `"test:leads": "node --test tests/legacy/leads.test.js"` is a separate script and was rightly left alone; the "done" line about `git grep 'node --test'` means the `"test"` line only. (b) Every file the old `"test"` line ran is still run: compare the old line's list with what `discoverTestFiles` finds at the head. (c) The exclusion list `EXCLUDED_TESTS` holds one entry, `scripts/budget-audit.test.mjs`; say whether a test asserts the reason and whether a new test file on disk that is neither run nor excluded makes a test fail. (d) Every caller of the runner still works: `.github/workflows/ci.yml` (the shard calls and their flags), `scripts/sketch-fast.mjs` (it now calls `discoverTestFiles`; check the Godot-only mode still leaves out exactly the files the CI Node job covers), `scripts/hooks/pre-push`, `CONTRIBUTING.md`. (e) The duration-balanced shards, the seeded shuffle and `--dry-run` behave as they did at `7d7bc3d6c310ee8eb7c88a435450e91d2391e366` for the same file list. (f) Twenty-one test files now run in `npm test` that did not before; list any that reads the network, a GPU, Godot or a tool the Linux CI image may lack, and whether it skips cleanly without it.


## Report

Lead with `VERDICT: PASS` or `VERDICT: FAIL`. Then, apart from each other: blocking issues (each with the file, the function or a `git grep` pattern that finds it, and what is wrong), and notes (things that do not block). For each note that is a small fix, say whether the coordinator can apply it while merging without another review. End with a receipt: your model and effort, the commits you checked, your method, and what you did not do. Write for a reader who has not seen this brief: plain words, full file paths, no shorthand.
