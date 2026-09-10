# Assignment packet — AR-04-A1 / lease AR-04-L1

**GOAL:** AR-04 card revision 1. One observable outcome: the native networking check scans **every**
tracked file under `native/` and recognises the full forbidden API set, with a planted-symbol fixture
proving the check can fail.

**SCOPE**

- Worktree: `/home/andrew/Projects/scrapkeep/.claude/worktrees/AR-04` (branch `wt/AR-04`).
- Base identity: `642afe0eadd9a7f97c3bd1352609faf8560f70d5`. Verify `git rev-parse HEAD` equals it
  before your first edit and stop on mismatch.
- Lease AR-04-L1, exclusive: `scripts/native-smoke.mjs`; `tests/native-smoke.test.js`; new fixture
  material under `tests/fixtures/native-smoke/**` if your design needs it. Scratch evidence:
  `artifacts/local/tasks/AR-04/`.
- Any other path needs an amended lease from the coordinator first.

**CONTEXT**

- Card: `BACKLOG.md` → `### AR-04` (anchor `#ar-04`). Read only that card.
- Audit finding L6-07 / card L6-E in `artifacts/audit-2026-09-10/lane-6-code-tooling.md`.
- `scripts/native-smoke.mjs` currently scans **16 of 32** tracked native files (`:30`, `:147`) and its
  forbidden list omits `MultiplayerPeer`, `WebRTC`, `SceneMultiplayer`, `DTLSServer` and `UPNP`. The
  widening was recorded as a follow-up at `TRACKING.md:276` and never implemented, so the check has
  been reporting a narrower guarantee than a reader would assume.
- `tests/native-smoke.test.js` is the existing unit-level check for this runner; `native/` is a real
  32-file Godot scaffold.

**ACCEPTANCE** — every item in `BACKLOG.md#ar-04` "Definition of done":

1. The scan covers every tracked file under `native/` — derive the file list from the repository, not
   from a hard-coded subset, so a new file cannot silently escape the check.
2. The forbidden list includes `MultiplayerPeer`, `WebRTC`, `SceneMultiplayer`, `DTLSServer` and `UPNP`.
3. A fixture with a planted forbidden symbol is shown **failing**, and the real tree passes. State how
   many files the widened scan covers.

**VERIFY**

- `npm test` → the `native-smoke` unit checks pass, including your planted-symbol case.
- Show the planted-symbol fixture failing and quote the exact message.
- `npm run native:smoke` needs the Godot toolchain and may not be available here. If you cannot run it,
  say so plainly and do not claim it ran — a documented, hardware-dependent check reported as
  unverified is the correct outcome.

**TIMEBOX** Checkpoint at 15 minutes of active work and at handoff. Attempt budget: this attempt plus at
most two revised attempts.

**FORBIDDEN**

- Any engine or `native/` source change: this card widens a check, it does not touch the scaffold.
- Claiming the native tree was executed or qualified — this is a static scan.
- Editing `TRACKING.md`, `BACKLOG.md` or any canonical record; editing outside the leased set; touching
  other worktrees; `git clean/reset/checkout --`.
- `npm run verify`, `npm run build`, browser tests, installs, network, dependency changes.

**REPORT** Commit in your worktree. Write `artifacts/local/tasks/AR-04/handoff.json` with task, revision,
attempt, lease, base, candidate commit, branch, worktree, changed paths, the exact commands you ran and
their results, the file count now covered, and any blocker. Return a short summary: candidate SHA,
changed paths, check results, coverage count, remaining uncertainty.
