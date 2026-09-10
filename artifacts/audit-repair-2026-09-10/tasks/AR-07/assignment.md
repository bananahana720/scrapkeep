# Assignment packet — AR-07-A1 / lease AR-07-L1

**GOAL:** AR-07 card revision 1. One observable outcome: the documentation check can resolve an event ID
from a tracked **archive** file as well as from `TRACKING.md`, so events can move out of the board
without breaking the rows that cite them — while still rejecting an ID that exists nowhere and an ID
that appears twice.

**SCOPE**

- Worktree: `/home/andrew/Projects/scrapkeep/.claude/worktrees/AR-07` (branch `wt/AR-07`).
- Base identity: `33d455f` (verify `git rev-parse HEAD` equals the full SHA before your first edit; stop
  on mismatch).
- Lease AR-07-L1, exclusive: `scripts/check-docs.mjs`; `tests/check-docs.test.js`; new fixtures under
  `tests/fixtures/check-docs/**`. Scratch evidence: `artifacts/local/tasks/AR-07/`.
- Any other path needs an amended lease from the coordinator first.

**CONTEXT**

- Card: `BACKLOG.md` → `### AR-07` (anchor `#ar-07`). Read only that card.
- Why this exists: the approved plan is to archive `EV-0001..EV-0057` out of `TRACKING.md` into
  `docs/project/tracking/EVENTS-0001-0057.md` (Andrew's chosen location). **117 index rows** currently
  cite an event at or before `EV-0057`, and the AR-01 rules validate those citations — an unresolvable
  `Last event` fails, and a `Last event` that predates a later record-level event naming the same record
  fails. So the checker must learn about archives **before** any event moves.
- The three AR-01 rules to preserve across the boundary are in `scripts/check-docs.mjs`: state
  vocabulary, unresolvable `Last event`, and stale `Last event`. The program-level exclusion
  (`authorization|coordination|closure` in the kind cell) must keep behaving as it does now.
- This card is deliberately checker-only: **it must not move an event, edit `TRACKING.md`, or create an
  archive.** The coordinator performs the split afterwards using the convention you establish.

**ACCEPTANCE** — every item in `BACKLOG.md#ar-07` "Definition of done":

1. Event IDs resolve from `TRACKING.md` **and** from tracked files that declare themselves event
   archives. **Choose and document a clear, robust convention** for that declaration (for example a
   front-matter line or a fixed heading) — the coordinator has to author the archive against it, so state
   it exactly in your handoff and in the checker's own documentation.
2. An ID present in no checked source still fails, and a duplicate ID across sources fails.
3. The three AR-01 rules keep working across the boundary, including when the later naming event lives in
   an archive or the row points into one.
4. Fixtures cover four cases: an event resolved from an archive, a missing ID, a duplicate ID, and a
   stale row whose later naming event is in an archive.

**VERIFY**

- `npm test` → all pass, including the new fixture cases.
- `npm run check:docs` → exit 0 on the current board, unchanged in behaviour.
- Show each new fixture **failing** without its rule, quoting the exact message.
- Keep the existing summary format intact (`check:docs pass: … N failures`).

**TIMEBOX** Checkpoint at 15 minutes of active work and at handoff. Attempt budget: this attempt plus at
most two revised attempts.

**FORBIDDEN**

- Moving, editing or deleting any event; editing `TRACKING.md`, `BACKLOG.md` or any other canonical
  record; creating the archive file (the coordinator does that).
- Weakening, relaxing or making conditional any existing check, including the AR-01 rules and the
  program-level exclusion.
- Editing outside the leased set; touching other worktrees; `git clean/reset/checkout --`.
- `npm run verify`, `npm run build`, browser tests, Godot/native commands, installs, network.

**REPORT** Commit in your worktree. Write `artifacts/local/tasks/AR-07/handoff.json` with task, revision,
attempt, lease, base, candidate commit, branch, worktree, changed paths, the archive-declaration
convention stated verbatim, the commands you ran and their results, and any blocker. Return a short
summary: candidate SHA, changed paths, **the exact archive convention**, fixture evidence, remaining
uncertainty.
