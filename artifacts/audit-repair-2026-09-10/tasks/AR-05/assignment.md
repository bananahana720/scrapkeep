# Assignment packet — AR-05-A1 / lease AR-05-L1

**GOAL:** AR-05 card revision 1. One observable outcome: the eight documentation-only concept PNGs no
longer sit in the served static tree, and every tracked document that cites them still resolves.

**SCOPE**

- Worktree: `/home/andrew/Projects/scrapkeep/.claude/worktrees/AR-05` (branch `wt/AR-05`).
- Base identity: `1a4be2d` (full SHA from `git rev-parse HEAD`; verify it equals the worktree HEAD
  before your first edit and stop on mismatch).
- Lease AR-05-L1, exclusive: `public/art/**` (the move source), the new directory you choose under
  `docs/` (keep the file names exactly), and every tracked document whose links must change —
  multi-file, so list them in your handoff. Scratch evidence: `artifacts/local/tasks/AR-05/`.
- `TRACKING.md`, `BACKLOG.md` and every other canonical record are **not** in your lease.

**CONTEXT**

- Card: `BACKLOG.md` → `### AR-05` (anchor `#ar-05`). Read only that card.
- Audit findings H-09 (`artifacts/audit-2026-09-10/lane-5-hygiene.md`) and L6-F
  (`artifacts/audit-2026-09-10/lane-6-code-tooling.md`).
- Eight PNGs (22,149,367 bytes) live in `public/art/`. Nothing in `index.html`, `orchard.html`, `src/`,
  `server/`, `scripts/` or `tests/` loads them — they are reachable only from prose. Because they sit in
  Vite's `public/` directory, every production build copies all eight into `dist/art/`.
- `docs/project/ASSETS.md` requires the original file names to be retained, and
  `docs/CONCEPT-STUDY-03.md` documents some of these as revision history, so **nothing may be deleted,
  renamed or re-encoded** — this is a move plus link updates.
- Reference sites the coordinator observed include `docs/ART-DIRECTION.md`, `docs/BASELINE-GUIDE.md`,
  `docs/COMBAT-DESIGN-SWARM.md`, `docs/CONCEPT-STUDY-01/02/03.md`, `docs/CONFLICT-AND-COMBAT.md`,
  `docs/DISCOVERY.md`, `docs/VERIFICATION.md`, `docs/project/ASSETS.md`,
  `docs/project/SOURCE-DISPOSITIONS.md`, `docs/audit-2026-09-05/worker-4-universe.md`, `TRACKING.md` and
  the audit records under `artifacts/audit-2026-09-10/`. Derive the real list yourself with a
  repository-wide search; do not work from this list alone. For any reference inside `TRACKING.md` or
  another file outside your lease, **do not edit it** — list it in your handoff as a requested shared
  change and let the coordinator apply it.

**ACCEPTANCE** — every item in `BACKLOG.md#ar-05` "Definition of done": the eight files live under
`docs/` with unchanged names and bytes; every in-lease reference is updated; `public/art/` no longer
exists; no live-code reference exists or is introduced.

**VERIFY**

- `npm run check:docs` and `npm run check:project` → exit 0.
- A repository-wide search shows no remaining `public/art` reference outside deliberately recorded
  historical notes.
- `git ls-files public/art` → empty; `git ls-files <your new directory>` → 8 files.
- Prove the bytes are unchanged: compare `sha256sum` of each moved file against its value in the base
  commit (`git show <base>:public/art/<name> | sha256sum`).
- The build-copy effect is verified at admission by the coordinator with `npm run verify`. Do **not**
  run it.

**TIMEBOX** Checkpoint at 15 minutes of active work and at handoff. Attempt budget: this attempt plus at
most two revised attempts.

**FORBIDDEN**

- Deleting, renaming, re-encoding or resizing an image; changing any page, build configuration or code.
- Editing `TRACKING.md`, `BACKLOG.md` or another file outside the lease (request it instead).
- `npm run verify`, `npm run build`, browser tests, Godot/native commands, installs, network.
- Touching other worktrees; `git clean/reset/checkout --`.

**REPORT** Commit in your worktree. Write `artifacts/local/tasks/AR-05/handoff.json` with task, revision,
attempt, lease, base, candidate commit, branch, worktree, the full changed-path list, the requested
shared changes you did not apply, hash comparisons, commands run and results, and any blocker. Return a
short summary: candidate SHA, destination directory, files moved, references updated, requested shared
changes, remaining uncertainty.
