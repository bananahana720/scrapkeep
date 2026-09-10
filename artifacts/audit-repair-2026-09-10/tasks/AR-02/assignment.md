# Assignment packet — AR-02-A1 / lease AR-02-L1

**GOAL:** AR-02 card revision 1. One observable outcome: the Sprint 0 closure authority record
resolves its 12 pinned `path` + `sha256` entries through **tracked** files, so it no longer depends on
a directory `AGENTS.md` calls disposable.

**SCOPE**

- Worktree: `/home/andrew/Projects/scrapkeep-wt-AR-02` (branch `wt/AR-02`).
- Base identity: `641f09f54a37af15da2ea35ced7f281f60959d13`. Verify `git rev-parse HEAD` equals it
  before your first edit and stop on mismatch.
- Lease AR-02-L1, exclusive: `artifacts/sprint-0-closure-2026-09-06/**` (new),
  `docs/project/sprint-0/closure.json` (**`path` values only**), `artifacts/local/README.md` (new),
  `docs/project/sprint-0/README.md`. Scratch evidence: `artifacts/local/tasks/AR-02/`.
- Any other path needs an amended lease from the coordinator first.

**CONTEXT**

- Card: `BACKLOG.md` → `### AR-02` (anchor `#ar-02`). Read only that card.
- Audit findings H-01, T5-1, T5-6 in `artifacts/local/audit-2026-09-10/lane-5-hygiene.md`.
- `docs/project/sprint-0/closure.json` pins 12 entries that resolve to **9 distinct files** under
  `artifacts/local/sprint-0/closed/` (gitignored, disposable). All 12 were present and matching when
  the audit ran. Copying is what preserves them; nothing may be deleted from the source.
- `scripts/sprint-close.mjs` validates closure receipts. It requires
  `nextProposal.status === "awaiting_review"` — **do not change that value**; it is a separate
  owner decision. It may also constrain the shape of the pinned evidence list: if it refuses the
  repointed paths, stop and submit an amendment request with the exact validator error rather than
  loosening the check or the receipt.

**ACCEPTANCE** — every item in `BACKLOG.md#ar-02` "Definition of done":

1. The nine distinct pinned files exist under a tracked directory, byte-identical to the pinned
   hashes.
2. The pinned `path` values in `closure.json` resolve through tracked files.
3. `artifacts/local/README.md` states the disposal contract and names every pin-critical path that
   must be copied before any cleanup.
4. The receipt still validates: `node scripts/sprint-close.mjs` behaviour on it is unchanged. If the
   script cannot be run standalone against a receipt, say so explicitly and show instead that its
   validation functions and inputs are untouched.

**VERIFY**

- A `path` + `sha256` walk over `docs/project/sprint-0/closure.json` reporting `present+match=12`
  resolving through tracked files — include the script and its output in your evidence. The audit
  used a small Python walk; write your own and keep it in `artifacts/local/tasks/AR-02/`.
- `git ls-files artifacts/sprint-0-closure-2026-09-06` lists the copies plus their `README.md`.
- `npm run check:docs` and `npm run check:project` → exit 0.
- `git check-ignore -v` each new tracked path to prove it is not ignored.

**TIMEBOX** Checkpoint at 15 minutes of active work and at handoff. Attempt budget: this attempt plus
at most two revised attempts.

**FORBIDDEN**

- Deleting, moving or editing anything under `artifacts/local/sprint-0/` — the originals stay until a
  separate cleanup is authorized. You are copying, not moving.
- Changing any pinned `sha256` value, re-running a closure gate, or altering `nextProposal` in either
  receipt.
- Editing anything outside the leased set; touching other worktrees; `git clean/reset/checkout --`.
- `npm run verify`, `npm run build`, browser tests, Godot/native commands, installs, network.

**REPORT** Commit in your worktree (this is a repository change needing a local commit identity).
Write `artifacts/local/tasks/AR-02/handoff.json` with: task, revision, attempt, lease, base, candidate
commit, branch, worktree, changed paths, the hash-walk output, the commands you ran, and any blocker.
Return a short summary: candidate SHA, changed paths, hash-walk result, validator result, remaining
uncertainty.
