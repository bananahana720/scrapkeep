# Next-work shortlist — drawn from the 2026-09-10 audit

**This is not a queue.** `BACKLOG.md` owns task definitions and `TRACKING.md` owns execution state.
This file is disposable planning evidence (`artifacts/local/`) listing what the six audit lanes
recommended, deduplicated, so Andrew can pick. Nothing here is authorized; any accepted item must be
materialized as a proper card with exact inputs, permitted files, observable acceptance and a
verification method before dispatch (ORCHESTRATOR, "Questions and scope changes").

## Already closed by this pass (no card needed)

| Was | Closed by |
| --- | --- |
| L2-C1 coordination transfer and sequence reconciliation | EV-0093 (`00f64e2`) |
| L2-C2 + L3 Task 3 record the HF-05 handoff, retain receipts, fix the row | EV-0094/EV-0095 (`00f64e2`) |
| L2-C3 uncommitted board defects (state token, count, glued text, summary) | `00f64e2` |
| L2-C4 / T5-3 commit HF-04a's retained attempt-1 receipts | `00f64e2` |
| L3 Task 1 superseded foundation authorization in README/scope | `80fc004` |
| L3 Task 4 publication rows + D04 register cell | `80fc004` |
| T5-4 stale remote claims | `80fc004` |
| T5-8 strip generated material from worktrees; A1–A2 worktree/branch pruning | cleanup execution (~1.14 GB) |
| H-01 immediate risk: the 12 hash-pinned closure files | archived and re-verified in `preserved/sprint-0-closure/` |

## Completed since this shortlist was written

All four Tier 1 + 2 repair cards are **done and integrated**, each through its own worktree, a fresh
independent review and serial admission: AR-01 (`e1e15fe`, checker validates board state), AR-02
(`c689cb8`, closure evidence chain tracked), AR-03 (`2995598`, asserted gate patrols the shipped PATH),
AR-04 (`ae42480`, native scan covers all 32 files). Retention items executed: `sprint-0/final/` exports
pruned (175 MB) and the S0-09 worktree with its 872 MB of unique exports removed, both with hashes
recorded; `main` is pushed.

**Still open:** the `test-game-2` capture decision (1.3 GB of playtest captures), the `public/art` move,
the TRACKING archive split, and three small accepted follow-ups — AR-03's overstated comments, AR-04's
unlisted `MultiplayerSpawner`/`MultiplayerSynchronizer`, and the missing `dispatch-validation.json` line
in `artifacts/README.md`.

## In flight

- **L2-C5 + L2-C6** — one fresh independent reviewer for the disjoint HF-04a (`72178cf`) and HF-05
  (`ea522c3`) wave. Report lands at `review-wave-hf04a-hf05.md`.
- **L2-C7** — admit the two sections and update `docs/tech/sections/README.md`. **Blocked on that
  verdict**; it is the integration repair that unlocks HF-04b and HF-06a.

## Recommended next wave (4 cards, per the ≤4 rule)

| # | Card | Size | Why this order | Gate |
| --- | --- | --- | --- | --- |
| 1 | **Admit HF-04a/HF-05 on an independent PASS; update the section index** (L2-C7) | S | Integration repair first: it is the only item that unlocks queued foundation work (HF-04b, HF-06a) | review verdict |
| 2 | **T5-1 + T5-6: copy the 12 hash-pinned closure files into tracked evidence and write `artifacts/local/README.md` stating the disposal contract and pin-critical paths** | S | Closes the last S1 where evidence can still be lost; a tracked canonical receipt currently depends on a directory the project calls disposable | owner answer to decision C5 |
| 3 | **L6-A: validate the `State` column in `scripts/check-docs.mjs`** | S | The gate reported 0 failures on a board that violated its own legend. Must land **after** the `IN_REVIEW` → `review` fix, which is now committed | none |
| 4 | **L3 Task 6: archive `EV-0001..EV-0057` into a tracked archive and reorder TRACKING** | M | Structural fix for the file where live state is only 19.6% of bytes and sits 11th of 15 sections | owner: archive location/policy |

## Groomed queue behind that (owner picks)

**Record integrity** — L2-C8 harden the `run_checks.py` wrapper that rewrites `handoff.json` from the
passed repo's HEAD (S); L3 Task 2 retire the two superseded proposal sections in TRACKING (S);
L3 Task 7 close the `COHESION_REPORT.md:94` and `PLANNING.md` executability follow-ups (S);
T5-2 reconcile the dangling `artifacts/local/` references in tracked proof docs (M) — **must first
classify each path**: this pass proved that two of the three "missing" dirs were a completed card's
*files-touched* contract and a verification *instruction*, not lost evidence, and that both have
tracked counterparts (`DISPOSITIONS.md` §A0c). Only genuine dangling pointers are defects;
T5-5 add READMEs to the nine unoriented retained evidence dirs (M).

**Code correctness-adjacent** — L6-B gate the orchard QA bridge on `import.meta.env.DEV` and extend
the production assertion (M, **needs decision D05**); L6-D make the asserted expedition gate patrol
the game's real 20-point `PATH` (S); L6-C one static-path implementation for the server and
`check-build` (M); L6-E widen the native networking check to all 32 files (S); L6-F/T5-9 decide where
the 22 MB of concept art lives (S, owner).

**Documentation hygiene** — L4-C1 banner the four audit papers; L4-C2 banner the Bible staging
manuscripts; L4-C3 banner the superseded design records; L4-C4 correct the character-authority
claim; L4-C5 index the newest records in the design desk; L4-C7 align prompt filenames with outputs;
L4-C8 art revision ledger; L4-C9 dedupe machine evidence in `artifacts/` (all S/M).

**Owner-only** — L4-C6 de-stale the 363 absolute provenance paths (must precede any `test-game-2`
decision); L4-C10 retire the stale sibling checkout; T5-7 reduce export-binary retention.

## Owner decisions these depend on

`DISPOSITIONS.md` §C: (1) `sprint-0/final/` retention, (2) the 1.3 GB `test-game-2` captures,
(3) a retention budget, (4) `public/art`, (5) whether the closure receipt must stay independently
re-verifiable, (6) decision D05, (7) approval of the staged corrections — **now applied**.
