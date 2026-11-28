"""Units of round 14, read by make-round.py. G6 changes Node scripts only."""
POOL = "the task pool, `git show " + BASE + ":project-guide/handoff/shared/structure-sweep/pool.tsv`"
UNITS = {
    "G6": dict(
        branch="entropy/g6-fast-check-and-git-runners",
        findings="The rows `LEAD-64`, `LEAD-65`, `LEAD-66` and `LEAD-77` of " + POOL + ". Then read `scripts/sketch-fast.mjs` (its `main`, from the argument parsing to `finish`), `scripts/lib/git.mjs` and `scripts/lib/git.test.mjs` on your base.",
        body=(
            "This unit has four parts, all Node code under `scripts/`. It changes no file the game loads and runs no Godot.\n\n"
            "**Part 1 (LEAD-64), the scratch checkout is removed on every way out.** `npm run sketch:fast` with `--pre <pull request>` makes a scratch checkout of the base with `git worktree add --detach` (the function `baseDir` in `main`) "
            "and removes it in `finish`. Several ways out of `main` call `process.exit` without going through `finish`: a `--test` name that matches no test, the plan-only exit, and the early argument errors that come after `baseDir()` has run. "
            "Each leaves the checkout and its entry in `git worktree list` behind. Give the checkout one owner that removes it on every way out, the ones a later change adds included: "
            "the smallest form is one removal that runs when the process exits (the removal is a synchronous git call, so it can run there) and that `finish` no longer has to remember. "
            "Check what a stop signal does today (the script already handles one for its child processes) and keep that working. "
            "Prove it with a Node test that fails on the base: build a scratch repository, start the script the way its other tests do, take the way out with an unmatched `--test` name after the checkout exists, and assert that `git worktree list` shows no extra entry and the folder is gone. "
            "If `--pre` needs a fetch from a remote the scratch repository does not have, drive the same code through the smallest seam that already exists or add one small exported function that owns the checkout (create, path, remove) and test that; do not start Godot.\n\n"
            "**Part 2 (LEAD-65), the tool says when it compares nothing.** When the commit the tool compares against (the merge base of `--base` and the head, or the head itself in the named-test form with no `--base-check`) is the head, the changed-file list is empty and the base-red proof proves nothing. "
            "Two writers were misled by this on a branch the base had already merged. Reproduce both shapes in a scratch repository first and say in the report which one the row describes: (a) the base ref already contains the head; (b) the head has merged the base. "
            "Then make the tool say so in plain words where a reader will see it: one line in the output that names the base, the head and why nothing is compared, the same fact as a field in the receipt, and the same sentence in the final summary line. "
            "Before you change an exit code, list every real caller of the script (`.github/workflows/ci.yml`, `scripts/hooks/`, `scripts/gate/`, `scripts/alpha-rc.mjs`, the package scripts, the skills and pages that tell a reader to run it) and what each passes as `--base`: "
            "a push to the default branch in CI and the gate's own run on a freshly merged tip are real callers of the shape where the base contains the head. Keep the exit code the same for every caller that works today. "
            "Put the decision in a pure exported function with a Node test for each shape.\n\n"
            "**Part 3 (LEAD-66), every run says where its time went.** One run with 21 named tests, `--base-check` and `--shuffle` took 4,233 seconds and nobody could say which stage took them. "
            "The receipt's `stages` rows hold `ms` measured from the start of the run, not the length of the stage. Add the length of each stage to its row (keep `ms` as it is: other tools read it; find them with a repository search before you add a field, and name them in the report), "
            "and end every run by printing the three longest stages with their seconds, next to the existing summary line. Where a stage runs work in parallel lanes or waits for a slot or an import, name that wait as its own stage if it is not one already, so a long wait is never hidden inside another stage. "
            "Then answer the row from the code, without running Godot: say what the form with named tests and `--base-check` does that the form without it does not (a second checkout, a second import, one run of each named test on the base, what the base cache saves and when it is trusted), "
            "which of those cannot run in parallel with the rest, and which single stage is the likeliest owner of the 4,233 seconds. Say plainly that this is a reading of the code and not a measurement. "
            "Test the new length and the three-longest line with a Node test on a made-up receipt.\n\n"
            "**Part 4 (LEAD-77), the last three scripts start git through the helper.** `scripts/card-runner.mjs`, `scripts/sketch-export.mjs` and `scripts/sketch-export-mac.mjs` start git through their own command runners, so inside a git hook they read the repository named by the hook's `GIT_DIR`, not the one their `cwd` is in. "
            "Move every git call in the three onto `git` or `gitOptional` from `scripts/lib/git.mjs`, keeping what each caller does with a failure (read both helpers first; where a caller needs the exit code and the output of a failed call, use what the helper already offers and add one small option to the helper only if it does not), and keep each script's own runner for the commands that are not git. "
            "Remove the three from the allowed list `STARTS_GIT_BY_HAND` in `scripts/lib/git.test.mjs`. Then close the gaps in that guard the row names, as far as a pattern can with no false alarm on today's tree: git started through a command runner whose first argument is the string `\"git\"` (the form these three used), "
            "and git started inside a shell string (`sh -c`, `bash -lc`, a template string that begins with `git `). For each form you add, add its case to the guard's own scratch test so the guard is shown to catch it, and run the guard on the tree to show it adds no file to the list. "
            "A form you cannot catch without false alarms (git through a variable or a wrapper binary) stays out: say so in the report, do not write a loose pattern. "
            "Leave `scripts/sketch-lint.test.mjs` on the list and do not change it or `scripts/sketch-lint.mjs`: another unit holds both.\n\n"
            "Do not change what `npm run sketch:fast` selects, runs or decides, the names or meaning of its existing receipt fields, or its exit codes for a caller that works today. "
            "Do not edit `package.json`. Add no code comment except a tool-read line or a note on an engine or operating-system quirk."
        ),
        done="the scratch checkout of `--pre` is gone after every way out, with a Node test that fails on the base; the tool says in its output, its summary and its receipt when it compares nothing, and no working caller's exit code changed; every stage row holds its own length and every run prints its three longest stages; "
        "the three scripts start git through the helper and are off the allowed list; the guard catches the two new forms with a case for each; and `npm test` passes in order and shuffled.",
        flight="Other units are in flight. One holds `scripts/sketch-lint.mjs`, `scripts/sketch-lint.test.mjs` and `scripts/sketch-lint.baseline.json`: change none of them. Four units change `.gd` files under `sketches/core-loop/`: change no `.gd` file. "
        "If the integration branch moves while you work and your pull request conflicts, merge `origin/entropy/gate` into your branch; never rebase or force-push.",
        checks=NODE_CHECKS.format(node_exception="", base=BASE) + " Also run `node scripts/sketch-fast.mjs --help` (or the nearest thing the script supports that starts no Godot) and one plan-only run if the script has one, and paste the new lines they print.",
    ),
}
