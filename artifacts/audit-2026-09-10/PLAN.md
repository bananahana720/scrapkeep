# Repo deslop audit — plan of record

Date: 2026-09-10. Owner: Andrew. Coordinator: DSH session.
Base: `main` @ `b61feb1` (18 ahead of `origin/main`).
Status: audit in progress (6 read-only lanes). No repo mutation without an approved disposition.

## Why

- A foundation-sprint swarm session was cut off mid-flight. `TRACKING.md` has uncommitted coordinator
  edits, `HF-04a` sits in review, `HF-05` produced a candidate the board never recorded
- Nine worktrees (~2.4 GB) remain registered; ten more branches have no worktree
- The repo carries 1369 tracked files under `artifacts/`, ~431 MB of working-tree evidence, and
  ~87 MB under `docs/`, plus ignored build output (`dist/`, `node_modules/` in a worktree)

## Scope and method

Six read-only lanes, each writing one report to `artifacts/local/audit-2026-09-10/` and returning a
bounded summary. Lanes never mutate tracked files, never run builds, browser tests or Godot.

| Lane | Report | Covers |
| --- | --- | --- |
| 1 worktrees | `lane-1-worktrees.md` | Branch/branch-content reconciliation, unadmitted candidates, safe cleanup commands |
| 2 recovery | `lane-2-recovery.md` | Cut-off sprint state, HF-04a/HF-05 candidates, board defects, resume actions |
| 3 canonical | `lane-3-canonical.md` | TRACKING/BACKLOG/ORCHESTRATOR/BIBLE/ADR: duplication, contradiction, links, size |
| 4 docs/assets | `lane-4-docs-assets.md` | `docs/**`, `public/**`: superseded, orphan, dead-link, byte-identical duplicates |
| 5 hygiene | `lane-5-hygiene.md` | `artifacts/**`, ignored/untracked weight, tracked junk, CI/config drift |
| 6 code/tooling | `lane-6-code-tooling.md` | `src/ tools/ scripts/ tests/ native/` + agent config: dead code, drift, record-writing scripts |

Severity scale: **S1** authority/trust (a canonical record is wrong or work is mislabeled),
**S2** maintenance hazard (duplication, drift, dead references), **S3** cosmetic,
**S4** disk weight.

## Governance constraints (from AGENTS.md / ORCHESTRATOR.md)

- Preserve owner changes and historical evidence. `artifacts/local/` is disposable; the rest of
  `artifacts/` is retained evidence. Never reset, stash or stage owner changes.
- The coordinator alone writes `TRACKING.md`, `BACKLOG.md`, `ORCHESTRATOR.md` and canonical assembly.
- Code tasks need worktree isolation and a local commit identity; documentation-only work may use a
  coordinator-admitted file-hash manifest.
- Housekeeping authorizes no dependency upgrade, engine migration, new feature, paid service or
  deployment. `/` and `/orchard.html` stay separate working proofs.
- Deleting tracked content is only "reversible" via git history; deleting an unmerged branch or an
  untracked evidence dir is not reversible. Those are called out per finding.

## Deliverables

1. Six lane reports (evidence: exact command → observed result per finding).
2. One consolidated disposition table: keep / archive / delete / rewrite, each with severity,
   reversibility and owner-decision flag.
3. Atomic remediation cards sized S/M with exact files, observable acceptance and verification method.
4. Board corrections for the interrupted sprint, staged for coordinator admission.

## Decisions (Andrew, 2026-09-10)

- **D1 cleanup authority = reversible cleanup + staged canonical fixes.** Approved: prune stale
  worktrees/branches once their content is verified present in `main`; remove generated output
  (`dist/`, worktree `node_modules/`, `.godot/`); archive superseded docs; stage `TRACKING.md` /
  `BACKLOG.md` corrections for review. **Not** approved: deleting tracked evidence, historical
  artifacts or art, or restructuring the large canonical docs.
- **D2 priority = deslop and organize first, sprint recovery after.** The unadmitted `HF-04a` and
  `HF-05` candidates stay parked but must be preserved: their worktrees are excluded from cleanup,
  and their commits/blobs are hashed into this directory before anything else is removed.

No lane result is treated as an approved change; automation cannot approve deletion of historical
evidence or the owner's product direction.
