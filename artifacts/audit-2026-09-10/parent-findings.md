# Parent findings — verified outside the lanes

Round 1, 2026-09-10. Base `main` @ `b61feb1`. Every row is a command I ran and its observed result.

## F-P1 — Only two branches hold unmerged work (S1)

`git cherry main <branch>` → unmerged commit count:

| Branch | unmerged (+) | Status |
| --- | --- | --- |
| `wt/HF-04a` `72178cf` | 1 | **UNADMITTED candidate** — parked per decision D2 |
| `wt/HF-05` `ea522c3` | 1 | **UNADMITTED candidate** — parked per decision D2 |
| `wt/HF-01`, `wt/HF-02`, `wt/HF-03a` | 0 each | content already upstream in `main` |
| `wt/S0-09/11/12/13-operational` | 0 each | content already upstream in `main` |
| 10 loose branches (`wt/S0-01/04/05/07`, `wt/PS-01…PS-05b`) | 0 each | content already upstream; no remote upstream ref |

No stashes (`git stash list` empty). All nine worktrees clean (`git status --porcelain` → 0 entries).

## F-P2 — Candidate identity cross-validates against the board (S1, positive finding)

`sha256sum` of the parked HF-04a file = `7eb7ad2c909b715e62051d2d73e353f445b96270f3140b38c1c38c4c3fc171fb`,
byte-identical to the hash recorded in `TRACKING.md` EV-0091. The parked worktree is therefore the
exact candidate the cut-off coordinator declared — not a later edit. HF-05's board row records
`Candidate identity: null`, so its candidate was never recorded before the session died.

## F-P3 — Worktrees hold unique gitignored evidence that a naive prune would destroy (S2)

Removing a worktree also deletes its gitignored `artifacts/local/`. Contents found and archived to
`preserved/wt-local/` (957 files, 4.8 MB):

- `HF-01/tasks/HF-01/amendment-request.md` — governance artifact. **Already recorded in `main`**:
  amendment `AM-F01-001` is tracked under `artifacts/foundation-sprint-2026-09/amendments/AM-F01-001/`
  and admitted in EV-0067/EV-0068. The worktree copy is a draft, not an unrecorded decision.
- `HF-05/tasks/HF-05/scenario-review.md` + 14 other files unique to the unadmitted candidate.
- `S0-11/tasks/S0-11/writer-review.md`, `S0-12`/`S0-13` run logs, `HF-02` report json.
- `S0-09-operational/artifacts/local/native-export/` — 889 MB, 14 files: five Windows `scrapkeep.exe`
  (109 MB each) and Linux `scrapkeep.x86_64` builds. **Excluded** from the archive: regenerable build
  output inside a directory the project itself defines as disposable. Their receipts are retained.

Largest single cleanup win: removing that worktree reclaims ~1.17 GB.

## F-P4 — Gated dry-run passes; 2.2 GB reclaimable from worktrees (S4)

`bash artifacts/local/audit-2026-09-10/cleanup-dry-run.sh` → **GATE: PASS**, exit 0. Output saved to
`cleanup-dry-run.out`. Plan: remove 7 verified-merged worktrees (~2.2 GB incl. their generated
output), delete 10 merged branch refs, remove `dist/` (23 MB) and one worktree `.godot/` (1 MB).

Correction applied during the round: the planner initially listed the **live** `node_modules/`
(86 MB). That is required tooling for `npm test` / `npm run check:*`, not slop — now explicitly
`KEEP`. Live `node_modules` and `dist/` are also still in use by the running audit lanes.

`git branch -D` (not `-d`) is required: those commits are upstream **by patch-id**, not by ancestry,
so `-d` would refuse. Content is verified present in `main`; the refs themselves carry nothing unique.

## F-P5 — TRACKING.md carries a systematic glued-number text defect (S3, with an S2 edge)

Regex `\b[a-z]{2,}[0-9]{2,}\b` (excluding `sha256`/`sha`+hash, URLs, CI run ids):

| File | hits |
| --- | --- |
| `TRACKING.md` | ~38 |
| `BACKLOG.md` | 5 |
| `CONTRIBUTING.md` | 2 |
| `ORCHESTRATOR.md`, `BIBLE.md`, `docs/project/README.md` | 0 |

Examples: EV-0073 `produced from3ab3477`, EV-0074 `and13rows/32nativepaths`, EV-0052
`passed all37 checks`, EV-0054 `and81 scoped tests PASS`, EV-0056 `and11 subprocess tests`, EV-0091
`sha7eb7ad2c…`, EV-0090 `one C-TICK owner,8 forbidden callback families`. It affects the
coordinator-written event log only, so it is prose-generation slop, not a repo-wide formatter bug —
but where an identity is glued to a word (`candidate19192bb…`), machine parsing of the SHA is at risk.
Lane 6 is asked to confirm the cause from the scripts.

## F-P6 — `test-game-2` is a second clone of this repo: stale code, unique evidence (S1 + S4)

`/home/andrew/Projects/test-game-2` (1.8 GB) has the **same origin** (`bananahana720/scrapkeep`)
and sits on `codex/lightning-playtest` @ `c5e61d3`.

- **Code: superseded, nothing unique is lost.** `git cherry`-style comparison found 0 commits absent
  from `scrapkeep/main` for its HEAD and for `codex/agent-recovery-a/b` and `codex/recovery-stationary`.
  Three branches — `codex/lightning-presentation` `9ed8bd5`, `codex/lightning-simulation` `7bc8bac`,
  `codex/lightning-ui` `a297d94` — have objects that are **absent from the main repo's object database
  entirely**, so they are unrecoverable if this clone is deleted. But every file they change is
  **byte-identical to `main`** (4/4, 2/2, 3/4 files by blob sha), and the single exception,
  `tests/orchard-browser-runner.js`, is **older** than main's copy: main adds the `#qa-lightning`
  fixture and 33 more lines (`main` log: `49175ac Add inspectable lightning and attack-height visual
  fixtures`). Conclusion: content-superseded, but confirm before deleting anything.
- **Worktree metadata: 15 stale registrations.** `git -C test-game-2 worktree list` shows 15
  `/tmp/scrapkeep-*` worktrees all marked `prunable`; the `/tmp` dirs are gone. `git worktree prune`
  in that clone clears the metadata.
- **Evidence: 1.4 GB that exists nowhere else on this machine.** `artifacts/local/agent-playtests`
  (650 MB), `agent-recovery-development` (671 MB), `player-playtest-2026-09-06` (65 MB), plus
  `lightning`, `swarm-prep` and `publication-2026-09-06` (~1.1–1.6 MB each). **None of these
  directories exist under `scrapkeep/artifacts/local/`.** Canonical records do reference
  `artifacts/local/...` paths (e.g. `BACKLOG.md:151` → `artifacts/local/publication-2026-09-06`).
- **Disposition: do not delete.** Copy the three small dirs (~3.8 MB) if the references matter; the
  1.3 GB of raw automated playtest captures is an owner decision, not housekeeping.

## F-P7 — CORRECTED: the unpublished backlog was 18 commits, not 94 (S2, my error)

**This finding was wrong and is corrected here after a real `git fetch origin` on 2026-09-10.**

The audit originally read `origin/main` from the *stale clone* `test-game-2`, whose last fetch left
it at `c5e61d3`, and concluded that 94 commits were unpublished. `c5e61d3` is an **older** published
tip, not the current one. A real fetch shows the remote tip is `f582918`, so:

- at the start of this session `main` was **18** commits ahead of `origin/main` — the original
  `git status` figure was right and my "correction" was the error;
- after this session's four commits it was **22**;
- **pushed on 2026-09-10**: `f582918..641f09f`, so `origin/main` = `641f09f` and **0 commits remain
  unpublished**. The foundation work now has an off-machine copy.

Lesson recorded for the audit method: a stale remote-tracking ref in a *second* clone is not a
better source than the working repo — fetch before making any claim about publication state.

## F-P8 — `test-game-1` is an unrelated project, not scrapkeep slop (S3, informational)

`/home/andrew/Projects/test-game-1` (104 KB) is *KATAMITE*, a two-player Katamari-style browser game,
with no git repository and no relation to Scrapkeep. Leave it alone.

## Deliberately NOT done yet

Worktree/branch removal is deferred until the six audit lanes settle: lanes 1, 2 and 5 are actively
reading those paths and running git commands against them, so removing them mid-flight would corrupt
their evidence. The gate is ready; execution is one command away.
