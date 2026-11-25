# Findings of the destructibles model

Each finding is a break the model found that replayed on the real game. A closed finding names the change that closed it.

## None open

`destructibles-today` reports no break at the sync commit (`465769205`, 83,322 distinct states including `OnCapCharge` and `ConsCap`, checked with TLC 2.19 from tla2tools 1.7.4, 8 workers, on the Mac Studio on 25 November 2026; up from 27,096 at `1c94e96b5`). No candidate needed a replay.

## What the first runs showed about the code

- **Two guards keep a blast off rubble.** The planned plant for a piece paying twice was `on_blast` without its `not p.intact` skip. On its own that plant reports no break (`destructibles-belt-repay`): `_shatter` also calls `_unfile`, so `_near` never hands `on_blast` a shattered piece again. The plant that breaks `PaysOnce` (`destructibles-broken-repay`) takes both away. Lesson VFM-11.
- **A retry needs both halves to stop a farm.** `run.restore()` alone is not enough: with uncollected drops left on the ground through a retry, the second attempt banks its own payout and the first one's (`destructibles-broken-keepdrops`, 6 states: a class 3 ball breaks the tier 3 piece, the stage is retried, a blast breaks the rebuilt piece, and the ball collects two cogs against a cap of one). The retry's stage entry clears them today, through `scrap.lay_out`, which calls `clear()` first.
- **A mount can take a line's anchor with no ray.** `_mount_spot` falls back to the anchor of a world line when no face is in reach, so a line left on rubble would let the ball mount the rubble too. The model has this path; it cannot happen while `cut_line` runs on the break.
