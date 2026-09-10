# Assignment packet — AR-06-A1 / lease AR-06-L1

**GOAL:** AR-06 card revision 1. One observable outcome: the three accepted review follow-ups are
closed — two comments now describe what the code actually does, and the artifacts policy file names the
one cited-but-unpinned local path it omitted.

**SCOPE**

- Worktree: `/home/andrew/Projects/scrapkeep/.claude/worktrees/AR-06` (branch `wt/AR-06`).
- Base identity: `1a4be2d` (verify against `git rev-parse HEAD` before your first edit; stop on mismatch).
- Lease AR-06-L1, exclusive: `tests/expedition-balance.mjs` (**comments only**),
  `scripts/native-smoke.mjs` (**comment only**), `artifacts/README.md`. Scratch evidence:
  `artifacts/local/tasks/AR-06/`.
- Any other path needs an amended lease from the coordinator first.

**CONTEXT**

- Card: `BACKLOG.md` → `### AR-06` (anchor `#ar-06`). Read only that card.
- The accepted notes are in `artifacts/audit-2026-09-10/review-wave-ar03-ar04.md`. The reviewer ruled that
  neither note blocks its card, so these are accuracy fixes, not rework of the candidates.
- **AR-03 comment (`tests/expedition-balance.mjs`, around `:82-87`).** The reviewer established that the
  replaced modulo wrap did **not** stop the player patrolling: all 20 waypoints were still visited. Its
  real defect was an unpublished last-to-first leg. The comment currently overstates this ("stop
  patrolling the geometry") and describes the new traversal as "the probe's traversal" when the probe
  differs in detail (it starts at waypoint 3, uses `d<0.65` and dashes over 3; the gate starts at 0,
  uses `d<1` and no dash). Correct the claims to match reality.
- **AR-04 comment (`scripts/native-smoke.mjs`, around `:30-34`).** The comment claims every replication
  class is covered while `MultiplayerSpawner` and `MultiplayerSynchronizer` are absent from the list.
  **Do not extend the list** — the reviewed AR-04 contract named exactly five APIs, and extending it now
  would change reviewed behaviour outside a card. Instead make the comment accurate: either narrow the
  claim or name what is and is not covered.
- **`artifacts/README.md`.** Its cited-but-unpinned list omits
  `artifacts/local/sprint-0/final/dispatch-validation.json`, which `docs/project/sprint-0/closure.json`
  cites. Add it in the same style as the neighbouring entries. Note that the file was written by the
  AR-02 candidate and is the tracked home of the disposal contract; keep its existing structure.

**ACCEPTANCE** — every item in `BACKLOG.md#ar-06` "Definition of done", including that no executable
behaviour changes.

**VERIFY**

- `npm test` → exit 0 with **the same pass count as the base** (203 at base). This is the proof that the
  two script edits are comment-only; record the count before and after.
- `npm run check:docs` → exit 0.
- Quote the three changed passages verbatim in your handoff, with the before and after.
- If you are unsure whether a line is a comment or code, treat it as code and leave it alone.

**TIMEBOX** Checkpoint at 15 minutes of active work and at handoff. Attempt budget: this attempt plus at
most two revised attempts.

**FORBIDDEN**

- Changing any executable statement, assertion, threshold, message string emitted at runtime, or the
  forbidden-API list; adding `MultiplayerSpawner`/`MultiplayerSynchronizer`; reformatting unrelated lines.
- Editing `TRACKING.md`, `BACKLOG.md` or any canonical record; editing outside the leased set; touching
  other worktrees; `git clean/reset/checkout --`.
- `npm run verify`, `npm run build`, browser tests, Godot/native commands, installs, network.

**REPORT** Commit in your worktree. Write `artifacts/local/tasks/AR-06/handoff.json` with task, revision,
attempt, lease, base, candidate commit, branch, worktree, changed paths, the before/after text, the test
count before and after, commands run, and any blocker. Return a short summary: candidate SHA, changed
paths, the three passages, test counts, remaining uncertainty.
