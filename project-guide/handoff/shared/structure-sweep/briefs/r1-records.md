Unit R1 of the Scrapkeep structure sweep is the sweep's own records. The coordinator wrote it (Claude Mythos 5.2 at high effort), so it has no writer brief; this file says what the unit must be, in the shape the review-brief generator reads.

## The unit

The structure sweep removes duplicate code, dead code, wrong-way dependencies and facts kept in two places from the Scrapkeep repository, in small reviewed units that land on the branch `origin/entropy/gate`. Unit R1 (pull request 1290, branch `entropy/records`) adds the records that let a reader with no other context see what the sweep is, what it found, what has been done about each finding, and what is left. It changes no file the game loads.

It adds or changes:

- `project-guide/handoff/STRUCTURE-SWEEP.md`, the page: what the sweep is for, when it is done, how a unit runs, the rules that bind every writer, the code as measured, the units by round, the decisions Andrew can overturn, what waits on Andrew, branches for his prune list, and the delete candidates.
- `project-guide/handoff/shared/structure-sweep/pool.tsv`, one row for each survey finding and each later lead, with a status (`landed`, `in flight`, `open`, `closed`, `waits on Andrew`) and the unit or units that took it.
- `project-guide/handoff/shared/structure-sweep/units.tsv`, one row for each unit: what it did, its writer's model, its pull request, its stage (`landed`, `in review`, `with writer`) and notes, the reviews included.
- Fourteen survey files beside them (`core.md`, `combat.md`, `world.md` and so on), written by read-only survey sessions before any unit ran. They are a record of what was found at the time and are not kept current.
- `scripts/structure-sweep.mjs` and `scripts/structure-sweep.test.mjs`: a generator and checker. Two blocks of the page (the counts in "State" and the table under "Rounds") are generated from the two data files by `node scripts/structure-sweep.mjs --write`. The checker fails when a block does not match the data, when a pool row's status disagrees with the stage of a unit it names, when a row is closed or waiting with no reason on the page, when a unit is named with no row, and when the page or a lead cites a line number.
- `scripts/check-docs.mjs` calls the checker, so `npm run check:docs` runs it; `scripts/ci/affected.mjs` and its test make CI and the pre-push hook run `check:docs` when a data file or the checker changes.
- `AGENTS.md`: the "Rule enforcement" row for rule 6 names the checker, and the list "Get Andrew's go-ahead first for" is reworded in three places: it names the root `package.json` in place of `sketches/core-loop/package.json` (a file that does not exist), the macOS save folder beside the Linux one, and a tracked delete list for a machine that has no `/mnt/project-files/` folder.
- `project-guide/handoff/DECISIONS.md`: one new row, ruling `es`, recording Andrew's approval on 27 November 2026 that this sweep may delete what a reviewed unit replaced, may delete the listed candidates after a fresh search, may make one named edit to the root `package.json`, and may land on `main` through pull request 1322.
- Small link lines in `project-guide/handoff/README.md`, `project-guide/handoff/shared/INDEX.md`, `sketches/core-loop/ARCHITECTURE.md` and `sketches/core-loop/CONTRACTS.md`.

An earlier review of this unit, at commit `03e4d9a3348350e3bd25c43f18abef5a4036093f`, failed on two blocking issues. First, the page and the pool disagreed about one finding: the pool had `COMBAT-17` as `open` while it named a unit (B4) that had not landed and the page's table listed it with that unit. Second, four entries in a hand-written "Checked" list cited line numbers that had gone stale when other units landed. The page was written by hand at that time. The fix is meant to remove the two classes of mistake, not the two instances: the counts and the table are generated, the checker refuses a disagreement and refuses any line number, and the hand-written list of leads became rows in the pool.

Done looks like: the page stands on its own for a reader with no context, in plain words, with no term made up during the work and no shorthand left unexplained; every number and status on the page agrees with the two data files and with the repository (a unit marked `landed` has its merge commit on `origin/entropy/gate`; a unit marked `in review` or `with writer` does not); the checker fails on the copy that failed review and passes on the head; `npm run check:docs` runs it; the reworded go-ahead list is as strict as the old one or stricter in every item; ruling `es` claims no more than the words it quotes; every link resolves.

## Checks

The coordinator ran `npm test`, `node scripts/ci/node-tests.mjs --shuffle`, `npm run lint:js`, `npm run sketch:lint`, `npm run check:docs`, `npm run check:project` and `npm run check:skills` on the head.
