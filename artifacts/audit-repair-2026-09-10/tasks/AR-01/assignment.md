# Assignment packet — AR-01-A1 / lease AR-01-L1

**GOAL:** AR-01 card revision 1. One observable outcome: `check:docs` rejects a task-index `State` cell
that is outside the board's own vocabulary, and rejects a row whose `Last event` cannot be resolved —
with fixtures proving both rules fire.

**SCOPE**

- Worktree: `/home/andrew/Projects/scrapkeep-wt-AR-01` (branch `wt/AR-01`).
- Base identity: `641f09f54a37af15da2ea35ced7f281f60959d13`. Verify `git rev-parse HEAD` equals it
  before your first edit and stop on mismatch.
- Lease AR-01-L1, file-level and exclusive: `scripts/check-docs.mjs`, `tests/check-docs.test.js`,
  `tests/fixtures/check-docs/**` (new fixture directories only). Scratch evidence:
  `artifacts/local/tasks/AR-01/`.
- Any other path needs an amended lease from the coordinator first.

**CONTEXT**

- Card: `BACKLOG.md` → `### AR-01` (anchor `#ar-01`). Read only that card.
- The board's state vocabulary is defined at `TRACKING.md:30`:
  `queued, blocked, ready, in_progress, review, changes_requested, done, parked or cancelled`.
- The historical defect this rule exists to catch: `TRACKING.md` carried `HF-04a` in state
  `IN_REVIEW` — the only row of 84 outside that vocabulary — and `check:docs` reported 0 failures
  because `scripts/check-docs.mjs:400-429` reads only `cells[0]` and the last cell.
- Existing checker structure: `scripts/check-docs.mjs` already has `backlog` and `tracking` check
  families, an event-sequence check, and an index `Last event` existence check. Follow the existing
  `docs.fail("tracking", file, line, message)` pattern and the existing fixture layout under
  `tests/fixtures/check-docs/`; `tests/check-docs.test.js` is the fixture runner.
- `docs.fail` counts must keep the summary format intact (`check:docs pass: … N failures`).

**ACCEPTANCE** — every item in `BACKLOG.md#ar-01` "Definition of done":

1. A task-index `State` cell outside the `TRACKING.md:30` vocabulary fails `check:docs`.
2. An index row whose `Last event` is unresolvable fails, and a row whose `Last event` predates an
   event that names the same record also fails (this is what hid a delivered handoff).
3. Both rules have passing and failing fixtures in `tests/check-docs.test.js`, including one that
   reproduces the historical `IN_REVIEW` token.
4. The current board passes both rules with no board edit.

**VERIFY**

- `npm test` → all tests pass, including your new fixture cases.
- `npm run check:docs` → exits 0 on the current board.
- Demonstrate each new rule failing: run the checker against the failing fixture and capture the
  exact failure line in your evidence. A rule that cannot be shown failing is not done.

**TIMEBOX** Checkpoint at 15 minutes of active work and at handoff. Attempt budget: this attempt plus
at most two revised attempts.

**FORBIDDEN**

- Editing `TRACKING.md`, `BACKLOG.md` or any canonical record — your job is the checker, not the board.
- Editing anything outside the leased set; touching other worktrees; `git clean/reset/checkout --`.
- `npm run verify`, `npm run build`, browser tests, Godot/native commands, installs, network,
  dependency changes.
- Weakening an existing check to make a new one pass.

**REPORT** Commit in your worktree (code tasks need a local commit identity). Write
`artifacts/local/tasks/AR-01/handoff.json` with: task, revision, attempt, lease, base, candidate
commit, branch, worktree, changed paths, the exact commands you ran with their results, and any
blocker. Return a short summary: candidate SHA, changed paths, check results, remaining uncertainty.
