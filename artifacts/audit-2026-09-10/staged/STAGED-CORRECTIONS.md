# Staged canonical corrections — for Andrew's review

Nothing here is applied. `canonical-corrections.patch` is a complete, apply-checked patch against the
current working tree (`main` @ `b61feb1` plus the coordinator's uncommitted `TRACKING.md` edits).

```bash
# review
git apply --stat artifacts/local/audit-2026-09-10/staged/canonical-corrections.patch
# apply when approved (from the repo root)
git apply -p1 artifacts/local/audit-2026-09-10/staged/canonical-corrections.patch
```

## What it changes (14 lines, 7 files, all factual)

| File | Finding | Change |
| --- | --- | --- |
| `README.md:13` | L3-01 | "foundation-contract sprint is proposed and has not started" → states the fourteen-card sprint is authorized as documentation-only and in progress, linked to the authorization row |
| `docs/project/sprint-0/AUTHORIZATION.md:5` | L3-02 | "Keep … awaiting_review" → keeps Q-E06 open and adds a dated supersession clause for EV-0078 |
| `TRACKING.md:119` | L2-02, L3-06, L6-01 | State `IN_REVIEW` → `review` (the only row of 84 outside the board's own legend) |
| `TRACKING.md:520` | L2-06, L3-08 | Summary no longer asserts "no active writer" against its own index; now names EV-0092 and the real HF-04a/HF-05 positions |
| `TRACKING.md:338-340` | L2-04, L2-11, F-P5 | `118` → `126` paper/source checks (the retained receipts say 126; nothing records 118) and the glued-text/casing repairs (`HF04a`, `S004`, `candidate72178cf…`, `sectionsha…`, `original100`, `,8`/`,5`, `inspected,5`) |
| `BACKLOG.md:11` | L3-12b, L3-18 | Stops describing the superseded four-card proposal model; points authorization at `TRACKING.md` |
| `docs/project/HOUSEKEEPING.md:22` | L3-27, H-11 | "No remote is configured yet" → dated supersession naming the verified private remote |
| `docs/project/SOURCE-DISPOSITIONS.md:28,44,299` | L3-09 | Three rows that still call publication open → resolved with `EV-0007`/`EV-0018` cited, historical wording retained |
| `docs/project/DECISION-REGISTER.md:22` | L3-10 | Row D04 status `Open` → superseded, naming Q-E07/PUB-01 |

## Verification performed

1. **Every replacement asserted exactly one match** before being written; a mismatch aborts the
   build (`stage-corrections.py`), so no edit can silently no-op or hit the wrong occurrence.
2. **`git apply --check` → OK** against the working tree.
3. **The project's own gate passes on the patched tree**: `npm run check:docs` → `120 Markdown files,
   3342 local links, 77 cards, 92 events, 0 failures` (3340 before; the two additional links are the
   new `TRACKING.md#program-authorization` references, and the anchor exists at `TRACKING.md:7`).
4. **Reversal is exact**: after `git apply -R`, all seven files hash identically to their pre-test
   values, and `git status` still shows only the pre-existing ` M TRACKING.md` and the untracked
   HF-04a attempt directory. The coordinator's uncommitted work was never at risk.

## Deliberately excluded

- **Owner-decision items** — the closure-receipt supersession field (L3-04/L3-05: `sprint-close.mjs:253`
  *requires* `awaiting_review`), retiring the two superseded proposal sections in `TRACKING.md`
  (L3-03), the archive split at EV-0057 (L3-25/L3-30), and the `README`/register framing choices.
- **Sprint-recovery items** (deferred by decision D2) — recording the HF-05 handoff, retaining its
  receipts under `artifacts/foundation-sprint-2026-09/tasks/HF-05/attempt-1/`, the `HF-05` row
  revision bump, and the new handoff event. The `EV-0092` correction above is text-only and does not
  substitute for that event.
- **Code changes** — see `lane-6-code-tooling.md`; notably the production `?qa` QA bridge
  (`src/orchard/main.js:783-812`) and the expedition-balance gate that asserts an 18-point route
  while the game ships a 20-point `PATH`.

## Known limitation

`check:docs` validates structure only. Passing it proves the corrections break no link, anchor, card
field or event sequence — not that the corrected statements match reality. The factual claims come
from the lane evidence cited above, each of which carries the command that produced it.
