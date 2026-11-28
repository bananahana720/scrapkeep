You are the independent reviewer of two small commits in the Scrapkeep repository (GitHub `bananahana720/scrapkeep`). Scrapkeep is a Godot 4.7.2 GDScript game under `sketches/core-loop` with a Node toolchain under `scripts/`. You did not write these changes and you have not seen the writer's reasoning. The coordinating session wrote both directly on the integration branch `entropy/gate` to unblock other work, so neither has had a review. Both are already on the pushed branch; your verdict decides whether they stay as they are or get a follow-up fix.

## Hard limits

- Write nothing. Use read-only git only (`git fetch`, `git show`, `git diff`, `git log`, `git grep <pattern> <commit> -- <path>`, `git ls-tree`). Do not check out, switch, stash, commit, push, edit a file, comment on a pull request or start a sub-agent. Other sessions share this checkout.
- Do not run any test. Read the code.
- On this Mac `git grep -E` does not honour `\b`; write patterns without it.

## What to review

Run `git fetch origin`. Both commits are ancestors of `origin/entropy/gate` (check with `git merge-base --is-ancestor <commit> origin/entropy/gate`).

**Commit A, `afc081c69ba366b09ee6d4cd93d7cc8c3b40d095`: "The shared git helper reads the repository its cwd is in".** Files: `scripts/lib/git.mjs` and `scripts/lib/git.test.mjs`. The problem it answers: git exports `GIT_DIR`, `GIT_WORK_TREE`, `GIT_COMMON_DIR`, `GIT_INDEX_FILE` and `GIT_PREFIX` to a hook. A script started by the pre-push hook that then ran `git` in another folder (a temp repository in a test, or a worktree) read the hook's repository instead of the one in its working directory. The fix adds `cwdDecidesRepository(env)`, which returns the environment without those five variables, and makes the helper's `git()` and `gitOptional()` pass it.

**Commit B, `f7a3bd03cb4efb27932e406a95f5de220c8b0864`: "The process helper listens for a stop signal before it starts the child".** Files: `scripts/lib/proc.mjs` and `scripts/lib/proc.test.mjs`. The problem it answers: `runProcess` installed its `SIGINT` and `SIGTERM` listeners after `spawn` returned. A signal that arrived in between killed Node by the default action and left the child's process group running. CI showed it as a test in `scripts/gate/look-receipts.test.mjs` ("display-run: SIGTERM to the node process kills the run's group") reading exit code `null` where it expects `143`. The fix installs the listeners before `spawn` and removes them when the spawn fails or the run finishes.

Read each with `git show <commit>`.

## What to check, at least

For commit A:

1. **The list of variables.** Read `git help environment` knowledge you have, and say whether a hook can export any other variable that changes which repository or index a child `git` reads (for example `GIT_OBJECT_DIRECTORY`, `GIT_ALTERNATE_OBJECT_DIRECTORIES`, `GIT_NAMESPACE`, `GIT_CONFIG_*`, `GIT_QUARANTINE_PATH`, which a pre-receive hook gets). Say which matter for a pre-push or pre-commit hook on a developer machine and whether leaving any out can make a script read the wrong repository. A variable that can and is left in is a blocking issue.
2. **Who wanted the old behaviour.** A caller that runs inside a hook and means the hook's own repository must still get it. Read every caller of `git()` and `gitOptional()` from `scripts/lib/git.mjs` (`git grep -n -E "from \"(\./|\.\./)+lib/git.mjs\"|from \"\./git.mjs\"" origin/entropy/gate -- scripts sketches/core-loop/tools`) and say for each whether it passes a `cwd`, and whether dropping the variables changes what it reads when it runs from `scripts/hooks/pre-push.mjs`. In a linked worktree the hook's `GIT_DIR` points at the worktree's own git folder: say whether a call with no `cwd`, started from the worktree root, still finds that worktree after the variables are dropped. In a hook that git starts with `GIT_INDEX_FILE` set to a temporary index (a commit with paths, `git commit -a`), say whether any caller reads the index and would now read the wrong one.
3. **A caller's own environment.** If a caller passes `env` in its options, say whether the helper drops the variables from that environment, from `process.env`, or from neither, and whether the caller can still set one of the five on purpose.
4. **The other spawns.** About 23 scripts spawn `git` directly instead of through the helper (this is recorded as an open lead). Do not list them all; say whether `scripts/hooks/pre-push.mjs` itself or anything it runs is among them and still inherits the hook's variables.
5. **The test.** Read the new test in `scripts/lib/git.test.mjs`. Say whether it fails on the parent commit's helper (`git show afc081c69^:scripts/lib/git.mjs`), whether it cleans up its temp folders on a pass and on a throw, and whether it can pass by construction (for example because the variables it sets point at a repository that gives the same answer).

For commit B:

6. **The race is closed.** Read `runProcess` at the commit. Say whether any window remains between the child existing and the listeners being installed, and whether `onSignal` can run before `child` is assigned: read `terminate` and everything it touches and say what it does when `child` is undefined, and whether a signal that lands before the spawn then leaves the child running once it does start. If such a window exists, say how wide it is in practice (`spawn` is synchronous) and whether it is a blocking issue or a note.
7. **Listeners always come off.** List every way `runProcess` can end (normal exit, timeout, abort signal, spawn throwing synchronously, the child emitting `error` after spawn, output over the buffer limit) and say for each whether the two listeners are removed. A listener left on the process after a run is a blocking issue, because later runs would stack listeners and a later signal would act on a finished run.
8. **Behaviour for callers that do not forward signals.** `forwardSignals` is an option. Say whether a caller that does not set it sees any change at all.
9. **The exit code.** A caller reads `interrupted` (130 for `SIGINT`, 143 for `SIGTERM`) and `process.exitCode` is set. Say whether both are the same as before for a signal that arrives mid-run, and what a signal that arrives before the spawn now gives.
10. **Two runs at once.** Say what happens when two `runProcess` calls with `forwardSignals` are live and a signal arrives: do both children get reaped, and does each run remove only its own listener.
11. **The test.** Read the new test in `scripts/lib/proc.test.mjs` ("a signal that lands the moment the child starts still reaps its group"). It writes a small runner script that calls `runProcess` and sends itself `SIGTERM` from the `onChild` callback, then expects exit code 143 and the child's process group to be gone. Say when `onChild` runs relative to the old listener installation (`git show f7a3bd03c^:scripts/lib/proc.mjs`) and so whether the test fails on the old helper every time or only sometimes. Say whether it cleans up on a pass and on a throw, whether it can leave a `sleep 30` running when an assertion fails, and whether it depends on timing that a slow CI runner could miss (name each wait and its limit).
12. **Windows.** `detached` is false on Windows and the group kill differs. Say whether the change alters anything on that path. The project ships for Linux and develops on macOS, so this is a note at most.

## Report

Lead with `VERDICT: PASS` or `VERDICT: FAIL`, one verdict for the pair, and say for each commit whether it passes on its own. Then, apart from each other: blocking issues (each with the file, the function or a `git grep` pattern that finds it, and what is wrong), and notes (things that do not block). For each note that is a small fix, say whether the coordinator can apply it without another review. End with a receipt: your model and effort, the commits you checked, your method, and what you did not do. Write for a reader who has not seen this brief: plain words, full file paths, no shorthand.
