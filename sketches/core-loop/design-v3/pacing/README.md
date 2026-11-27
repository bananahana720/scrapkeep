# Pacing budgets

`world1-pacing.json` is the Spillway's run-length and optional-content budget as data. The companion human ledger sits outside the repo at `/mnt/project-files/world1/BUDGETS.md` (keep both in sync when editing numbers here).

All times are bot game seconds at fixed 90 fps. A person's time is estimated with `human_per_bot` (1.75, inferred from the plan's 1.5 to 2, not measured). Replace it with the ratio from Andrew's world 1 sitting.

## Measure

```sh
npm run sketch:pacing -- --run                      # the full measure: 2 policies x 3 pilots x 8 seeds, 4 at a time
npm run sketch:pacing -- --run --seeds=1,2,3,4 --pilots=seed   # a quick read: 8 runs, the pilot picked by seed
npm run sketch:pacing -- --from=<dir> --level=target           # read bots.ndjson already on disk
```

- `--level=floor` (the default) is the per-PR guard. It fails when a run does not reach Brindle's rout, or when a median falls under its `floor`.
- `--level=target` is the sitting acceptance. It also checks each band's `min` and `max`, and each content slot.
- Output: `artifacts/local/pacing/<stamp>/summary.json` and `report.md`. Exit 0 pass, 1 fail, 2 nothing measured.

The completionist runs with `--explore-by=520`. The default explorer goes to the Warden at stage second 140 and stalls at 240, so it cannot show a park longer than about 4 minutes. The flag moves both limits for this measure only; each activity keeps its default 40 s of patience, so a site the bot cannot finish adds no more time than it does today. Without the flag the bot is unchanged.

## Content slots

Each slot names a per-stage key the bots write in `bots.ndjson` `stages[]`. A list counts its entries, a number is used as it is, and `true` counts as 1. A key that no bot writes yet reads as pending:

| Slot | Key | Owner |
| --- | --- | --- |
| Activities | `activities_finished` | exists |
| Events | `events_joined` | exists |
| Rogue mini-boss | `rogues_beaten` | rogue sites in world 1 |
| Secrets | `secrets_found` | Spillway secrets |
| Rib caches | `rib_caches_taken` | grey item panels (#398) |
