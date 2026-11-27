# Scrapkeep roadmap

The one roadmap. Written 8 Nov 2026; status lines trimmed 14 Nov so STATE.md is the one home for live state. Phone copy: https://claude.ai/artifact/55bppMdvsEXW52ZVFyhNna (source /mnt/project-files/roadmap/roadmap.html). Live wave state is in [STATE.md](STATE.md); rulings are in [DECISIONS.md](DECISIONS.md) (newest wins).

The roadmap is ordered by what has to be true, not by dates. Wave numbers keep counting (STATE.md names the open one); "wave 21" in older records means the full-alpha sitting, not a wave number still ahead.

## Where we are

- **Goal (16 Oct, unchanged):** a finished-feeling Linux alpha, accepted at one sitting: 11 areas marked with no "Not yet", no open blocker, frame times in budget, zero placeholders.
- **Priority (25–26 Nov, rulings `ep`, `eq`):** `ruling at` is lifted under [ruling ep](DECISIONS.md), and the Full-Alpha milestone (`ruling eq`) closed flat on `main` across Worlds 1–3 with Patch active behind `HIDDEN_PILOTS`/`HIDDEN_SHELLS` (`src/presentation/hero_assets.gd`) and plain launches playing through all three worlds (`sketches/core-loop/src/core/worlds.gd`). Live status, open tests, and metrics stay in [STATE.md](STATE.md).

## Phase 1: Full-Alpha sitting & landed World 1 foundation

Waves 34–46 plus Waves 47–50 (Stages A–D) and the Full-Alpha close (`ruling eq`) landed all pre-sitting systems on `main` (see [STATE.md](STATE.md) for current counts). Ahead of or beside Andrew's human sitting:

- Dam perf remainders (the `f4045` riser, Warden break/engage spikes, seed 3 `f14k` swing); twin-line grapple prototype (PR #771); dam launch over the crest; non-`dam_night_shift` two-variant sub-regions; musical-grid arrivals; enemy health scaling (`ruling al`); dam Warden `sheet_dir` axis heading (`ruling cm`, unshipped).
- Remaining unfinished World 1 promise cards (`W1-131`..`W1-145` still at `report` in `scripts/world1-bands.rows.json` under `ruling ef`; see [docs/promises/README.md](../../docs/promises/README.md) for landed subtasks).
- **Engineering hygiene (non-blocking):** Remaining systems audit passes E–F in [BACKLOG.md](../../BACKLOG.md#systems-audit-add-on-11-november-2026), deep-modules sweep ([DEEP-SWEEP.md](DEEP-SWEEP.md)), ledger cleanup ([KNOWN-FAILING.tsv](KNOWN-FAILING.tsv)), and typing the four audio files ([issue 593](https://github.com/bananahana720/scrapkeep/issues/593)).

### Andrew plays

Under `ruling cs`, `ep`, and `eq`, Andrew plays the Full-Alpha sitting build across all 11 areas (`--profile=sitting-earned` keeps fresh unlocks, or plain play through Worlds 1–3 on `main`) and records verdicts on the [Sitting Kit](sitting-kit/README.md). A frame capture is void if he plays during it.

### Re-read after the sitting (already ruled to wait)

- HARD rung 5 target (`rulings aq, bc, be`), `w1` Novice drop target (`ruling cu`), Flume length (`ruling ax`), Completionist wall-time target (`ruling ag`), and Brindle's cobalt pick (`ruling ap`).

## Phase 2: Sitting fixes & post-sitting variety

Starts when Andrew's Full-Alpha sitting verdicts are in:

1. **Fix what he marks:** Every "fixes" or "Not yet" note becomes a tracked unit, World 1 first.
2. **Polish remaining World 2–3 depth & area blueprints:** Complete any remaining `AB-01`..`AB-09` area passes ([BACKLOG.md](../../BACKLOG.md#area-blueprint)) and soft-toy polish flagged during the Full-Alpha sitting.
3. **Final Linux AppImage sitting verification:** Re-verify `Scrapkeep.AppImage` across all 11 areas with zero blockers and frames in budget.

## Phase 3: after the alpha (parked until the full sitting)

- Story, lore, characters, boss and system tweaks from his sitting notes.
- Item rungs above cobalt (pearl prototypes, gold relics; ruling bn), brass boss trophies, hotwire kits, the Mind's offerings (purple), Work Orders as a camp menu.
- New game plus as world mutations; challenges; monster origins, park societies, pilot personality; richer world transitions; alternate worlds or paths.
- A fourth world, or a twist where the Mind you beat is not the real foreman (a seed, not a ruling).
- Toward a beta or a low-cost public release, ordered by what to add.
