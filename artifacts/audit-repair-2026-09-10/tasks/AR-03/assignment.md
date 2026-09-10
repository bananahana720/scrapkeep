# Assignment packet — AR-03-A1 / lease AR-03-L1

**GOAL:** AR-03 card revision 1. One observable outcome: the **asserted** expedition balance gate derives
its route from the game's shipped path, so the gate can no longer pass while testing geometry the game
does not use.

**SCOPE**

- Worktree: `/home/andrew/Projects/scrapkeep/.claude/worktrees/AR-03` (branch `wt/AR-03`).
- Base identity: `642afe0eadd9a7f97c3bd1352609faf8560f70d5`. Verify `git rev-parse HEAD` equals it
  before your first edit and stop on mismatch.
- Lease AR-03-L1, exclusive: `tests/expedition-balance.mjs`; `tests/balance.mjs` (only if it duplicates
  the route). Scratch evidence: `artifacts/local/tasks/AR-03/`.
- Any other path needs an amended lease from the coordinator first.

**CONTEXT**

- Card: `BACKLOG.md` → `### AR-03` (anchor `#ar-03`). Read only that card.
- Audit finding L6-05 in `artifacts/audit-2026-09-10/lane-6-code-tooling.md`, plus finding B7 in
  `artifacts/audit-2026-09-10/DISPOSITIONS.md`, where the coordinator re-verified this by hand.
- `src/game.js:2-23` exports `PATH` with **20** points. `tests/expedition-balance.mjs:12-31` hard-codes
  an **18**-point route of a different shape (it starts `[1,-2]` and ends `[-11,-7]`), so the run that
  `scripts/verify.mjs` asserts does not patrol the shipped path. The probe at `tests/balance.mjs:22`
  already uses the real `PATH` — only the asserted gate is wrong.

**ACCEPTANCE** — every item in `BACKLOG.md#ar-03` "Definition of done":

1. The asserted route is derived from the shipped `PATH` (imported, or asserted equal), so the two
   cannot drift.
2. The probe and the asserted gate use the same geometry.
3. The balance assertions still pass, and **a deliberate `PATH` change is shown to move the asserted
   route** — demonstrate this without committing a change to `src/game.js` (for example by exercising
   the derivation in a scratch copy, or by a test that mutates a local copy of the array).

**VERIFY**

- `node tests/expedition-balance.mjs` → exits 0 with the real path geometry.
- `npm test` → all tests pass.
- Show the drift-proof property explicitly: quote the code that ties the route to `PATH`, and show
  what would happen if `PATH` gained a point.
- `npm run verify` runs a build and belongs to admission, not to this attempt. Do not run it.

**TIMEBOX** Checkpoint at 15 minutes of active work and at handoff. Attempt budget: this attempt plus at
most two revised attempts.

**FORBIDDEN**

- Changing `src/game.js` or any gameplay value — `PATH` is the shipping authority and this card is test
  integrity only.
- Editing `TRACKING.md`, `BACKLOG.md` or any canonical record; editing outside the leased set; touching
  other worktrees; `git clean/reset/checkout --`.
- `npm run verify`, `npm run build`, browser tests, Godot/native commands, installs, network, dependency
  changes.

**REPORT** Commit in your worktree. Write `artifacts/local/tasks/AR-03/handoff.json` with task, revision,
attempt, lease, base, candidate commit, branch, worktree, changed paths, the exact commands you ran and
their results, and any blocker. Return a short summary: candidate SHA, changed paths, check results,
how you demonstrated the drift-proof property, remaining uncertainty.
