# Scrapkeep deslop audit — 2026-09-10

Base: `main` @ `b61feb187cfdcad71700c629e315a77de4e0f975`.
Scope authorised by Andrew: **reversible cleanup + staged canonical fixes** (no deletion of tracked
evidence or art, no canonical restructuring); **deslop and organize first, sprint recovery after**.

| File | What it is |
| --- | --- |
| `PLAN.md` | Audit plan, lanes, severity scale, governance constraints, decisions |
| `parent-findings.md` | Findings verified by the coordinator outside the lanes (F-P1…F-P8) |
| `DISPOSITIONS.md` | **Consolidated disposition table + owner decisions** — the actionable index |
| `lane-1-worktrees.md` | Branch/worktree reconciliation and safe-cleanup verification |
| `lane-2-recovery.md` | Interrupted foundation-sprint state (HF-04a / HF-05) |
| `lane-3-canonical.md` | TRACKING / BACKLOG / ORCHESTRATOR / BIBLE / ADR records (46 findings) |
| `lane-4-docs-assets.md` | `docs/**`, `public/**` (21 findings) |
| `lane-5-hygiene.md` | Evidence weight, tracked junk, CI/config (15 findings) |
| `lane-6-code-tooling.md` | `src/ scripts/ tests/ native/` + agent config (14 findings) |
| `staged/canonical-corrections.patch` | **Staged, unapplied** corrections for review; `staged/STAGED-CORRECTIONS.md` is the cover |
| `preserved/` | Everything unique that a naive cleanup would have destroyed, hash-verified |
| `cleanup-dry-run.sh` / `.out` | Gated planner (exit 0 = safe) and its verified output |
| `cleanup-execution.log` | Full transcript of the executed cleanup |

## Headline results

**Recovered state.** The cut-off sprint left two finished-but-unadmitted candidates.
`HF-04a` `72178cf` was recorded (its file hash matches TRACKING EV-0091 byte-for-byte);
`HF-05` `ea522c3` was **never recorded by the board** — it still says `Candidate identity: null`,
`review: not_run`, lease active, while the worktree holds a clean commit, a `stopped_writer: true`
handoff and 126 passing checks. Both are parked and preserved.

**Reclaimed ~1.14 GB** (Projects tree 43,758 → 42,616 MB): six verified-merged worktrees removed,
16 fully-merged branch refs deleted (all 19 tips pinned by `audit-2026-09-10/*` safety tags first),
and 102 MB of regenerable build output stripped.

**Preserved before touching anything:** 957 files / 4.8 MB of unique worktree evidence
(`preserved/wt-local/`), the 12 hash-pinned closure files re-verified against `closure.json`
(`preserved/sprint-0-closure/`), the two candidate patches and delivered files plus the
coordinator's uncommitted board work (`preserved/`). Lane 1 independently confirmed by hashing all
2.67 GB of worktree content that every non-regenerable unique file was captured.

**Deliberately not touched:** `test-game-2` (a second 1.8 GB clone that is the sole home of three
branch objects *and* the resolution target of 363 absolute paths in the tracked Bible provenance
inventory), `wt/S0-09-operational` (889 MB of unique, non-reproducible Godot exports — owner
decision), and all tracked evidence, art and historical records.

## The three structural problems

1. **Superseded authorizations are never retired.** The sprint-close procedure has no
   "a later authorization superseded this" step, so the README, the live scope file, two TRACKING
   sections, two machine-readable closure receipts and two registers still describe older
   authorization generations as current. Root cause of most S1 findings.
2. **`TRACKING.md` (123 KB) is unmaintainable by ordering, not size** — events are 55.5% of bytes,
   superseded proposals 24.9%, live state 19.6%; the live checkpoint is the 11th of 15 sections.
   Recommended: archive `EV-0001..EV-0057` verbatim into a tracked archive and reorder.
3. **Nothing self-checks live state.** `check:docs` passes while the board contradicts itself: it
   never validates the `State` column, never compares a row's `Last event` to the events naming it,
   and never reads `docs/project/**/*.json` receipts.

**Code is in better shape than the records.** Lane 6: `npm test` 187/187, `check:docs`,
`check:project` and `check:scope` all exit 0; no unreachable module, no dead import, zero
TODO/FIXME/HACK and zero `console.*` in `src/`. The genuine code findings are evidential rather than
gameplay-breaking: the orchard QA bridge (`src/orchard/main.js:783-812`) is gated on `?qa` alone
with no `import.meta.env.DEV`, so the production bundle ships `orchard-browser-runner` and
`window.__orchard` (decision D05 is still Open); the asserted expedition-balance gate uses a
hard-coded 18-point route while the game ships a 20-point `PATH`, so it does not exercise real
geometry; and `scripts/check-build.mjs:18-26` is byte-identical to a block in `server/index.js`.

**The corrupted board text is not a script bug.** Lane 6 proved it: no repo code writes
`TRACKING.md`/`BACKLOG.md` (all five `writeFile` sites target `artifacts/local/`), and `hexdump` of
`TRACKING.md:338` shows the separator byte is genuinely absent (`ner,8`) with no invisible character.
The signature appears in coordinator artifacts no script touches, and prevalence tracks authoring
volume — 278 suspect tokens in `TRACKING.md` versus **0** in ORCHESTRATOR, BIBLE, CONTRIBUTING and
AGENTS. It is a model/prompt-output defect on the writing path, so the fix is to correct the rows
being admitted, not to patch code.

## What the green gate does not cover

`npm run check:docs` → exit 0 (`120 files, 3340 links, 77 cards, 92 events, 0 failures`) both before
and after cleanup. It checks link/anchor existence, card fields, event continuity and index
`Last event` existence only. Every S1 record contradiction below sits in its blind spots.

## Executed after your approval (2026-09-10)

- **Staged corrections applied** — all 9 corrections are now in `main` as `80fc004`
  (`docs: correct canonical records after the 2026-09-10 audit`), and the board reconciliation plus the
  recovery records as `00f64e2` (`docs: record coordination recovery, the HF-05 handoff and retained
  attempt receipts`). `check:docs` → `95 events, 3343 links, 0 failures`; working tree clean.
- **Recovery recorded** — EV-0093 (coordination transfer, with the model/effort substitution reported
  rather than silently chosen), EV-0094 (the HF-05 handoff the cut-off session never wrote), EV-0095
  (one fresh independent reviewer for the disjoint wave). HF-05's row is now `review` at revision 5
  and its 21 receipts are retained in-repo, so the TRACKING link no longer points at untracked
  evidence. HF-04a's 10 attempt-1 receipts are committed too.
- **Gate caught my own error**: the first board edit left a blank line inside the events table and
  `check:docs` failed with `blank line inside the events table` — fixed before commit.
- **Review in flight** — a fresh reviewer that wrote neither candidate is reviewing both against
  their cards. Neither candidate is admitted; integration waits on an independent PASS, and HF-04b /
  HF-06a stay locked on `done`.
- **Pushed 2026-09-10** — `f582918..641f09f`, so `origin/main` = `641f09f` and nothing is unpublished.
  Correction: the earlier "94/96 unpushed" figure was wrong; it compared against a stale ref in the
  `test-game-2` clone. The real backlog was 18 commits at session start, 22 at push time. See F-P7.

## Owner decisions needed (full list in `DISPOSITIONS.md` §C)

1. Who resumes the coordinator role (the named session is gone).
2. Model-map conflict: host map says `astra@high`; TRACKING records `xhigh`.
3. `artifacts/local/sprint-0/final/` — 183 MB of unique exports, superseded: archive or delete?
4. S0-09's 927 MB of unique Godot exports: accept the loss or keep?
5. Retention budget for `artifacts/` and worktrees — none is stated, so the problem regrows.
6. Closure-receipt supersession needs a schema field (`sprint-close.mjs:253` requires the stale value).
7. Whether `public/art` (21 MB, zero live references) stays in the served tree.

## Verification and limits

Every finding carries the command that produced it and its observed result. Read-only lanes ran no
builds, browser tests or Godot commands; lane 3 ran the documentation gate, lane 5 measured the
worktree bytes. Machine checks here are structural only — they say nothing about gameplay, human
feel, native performance or publication state. One lane (6) is still outstanding, and the canonical
corrections are **staged for review, not applied**.
