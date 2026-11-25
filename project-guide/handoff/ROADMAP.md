# Scrapkeep roadmap

The one roadmap. Written 8 Nov 2026; status lines trimmed 14 Nov so STATE.md is the one home for live state. Phone copy: https://claude.ai/artifact/55bppMdvsEXW52ZVFyhNna (source /mnt/project-files/roadmap/roadmap.html). Live wave state is in [STATE.md](STATE.md); rulings are in [DECISIONS.md](DECISIONS.md) (newest wins).

The roadmap is ordered by what has to be true, not by dates. Wave numbers keep counting (STATE.md names the open one); "wave 21" in older records means the full-alpha sitting, not a wave number still ahead.

## Where we are

- **Goal (16 Oct, unchanged):** a finished-feeling Linux alpha, accepted at one sitting: 11 areas marked with no "Not yet", no open blocker, frame times in budget, zero placeholders.
- **Priority (23 Oct, ruling at):** world 1 first. Worlds 2 and 3 start nothing new until the world 1 sitting is done.
- **Where the wave stands, the last measures and each open pull request:** [STATE.md](STATE.md). This page keeps only the order of what is left.

## Phase 1: the world 1 sitting

World 1 is the title, the camp, the dam, the flume and Brindle in the Slag Bowl. Done means Andrew has played it through and marked its areas on the Sitting Kit.

### Left before he plays

| # | Item | State |
| --- | --- | --- |
| 1-3 | Waves 34 to 38: the first PC gate, one ride and the bugs (ruling cv), the loop mechanics (rulings da, dd, df), polish | Done, promoted 11 and 12 Nov |
| 4 | Harder by movement (ruling cu): chasers lead and run faster, the Warden pulse, a third clock tier, regen only while rolling, terrain stops shells, boils punish the stall | The difficulty stack, pull request 845; see STATE.md. Judged by paired band reads to the targets in [the difficulty plan](shared/world1/difficulty-plan.md) |
| 5 | The look rebuilds (ruling dj): the crew's distinct heads, the dam, the title screen and Brindle's armour plates, the last two areas with a taste page first | Build threads started 12 Nov; each lands on the open stage when it passes its checks (board issue in STATE.md) |
| 6 | The sitting run ends won at Brindle (ruling dk, W1-60), then Moss's last call and his hook (W1-73, W1-79) on the same flow fence | Build thread started 12 Nov; the Brindle ending is pull request 1018 in STATE.md |
| 7 | Wave 45 build diversity & destructibles (`W45-B1`, `W45-B2`, `W45-C`, rulings `eg` and `eh`) | In final wave 45 close on `stage/alpha-w45` (see STATE.md) |
| 8 | Wave 46 World 1 Demo Catalysts & Sitting Cut (`W46-C1` to `W46-C5` + `W46-S1`, ruling `ei`, [WORLD1-DEMO-CATALYST.md](../../sketches/core-loop/design-v3/WORLD1-DEMO-CATALYST.md)): 2010 vinyl/album-cover pop & living gig-poster title, playable Flow/districts/concave flume bowl/Brindle horizon, slapstick roster/Brindle true boss duel/Moss's Last Call, purple Foreman's Kindness/sight gags/cute babble call-ins/living camp, *Dam Night Shift* & rotating sites — followed last by Souls-like ruling-`cu` calibration (ruling `cy`), first-timer release film (ruling `dz`), full release gate, Sitting Kit refresh, and rollback-safe packed Linux install | Queued for `stage/alpha-w46`. Closes on `world1-bands -- --sitting` printing `READY` (35 active gate rows, ruling `ef`) |

Parked until after the sitting: dam perf remainders (the f4045 riser, the Warden break and engage spikes, the seed 3 f14k swing); the twin-line grapple prototype (pull request 771, waiting on Andrew's feel check); the way out of the Slag Bowl into world 2, the dam launch over the crest, two-variant sub-regions (other than `dam_night_shift` + `overtime`/`crew_short` in `W46-C5`), arrivals on the musical grid, enemy health (ruling al), the dam Warden's sheet heading (ruling cm), and the hidden seventh pilot, Patch (ruling dl; sheet [pilots/patch.md](../../sketches/core-loop/design-v3/pilots/patch.md)). (The rebuilt concave flume yard and playable sluice valves moved into Wave 46 under ruling `ei` / `W46-C2`.)

### Engineering hygiene that rides along (never holds a promotion)

- The world 1 and scaling backlog (Andrew, 12 Nov): every buildable row for world 1 now, the rows other threads own, and the groundwork for more stages, worlds and features, in [BACKLOG.md](../../BACKLOG.md#world-1-and-scaling-backlog-12-november-2026). World 1 rows rank first; a scaling row may not change what the sitting plays.
- Deep-modules batch 2 from the queued list ([DEEP-SWEEP.md](DEEP-SWEEP.md)).
- The systems audit add-on (Andrew, 11 Nov): six passes, world 1 first, defined as cards SA-A to SA-F in [BACKLOG.md](../../BACKLOG.md#systems-audit-add-on-11-november-2026) (historical plan `docs/systems-audit/PLAN.md` in git history). Passes A to D are done, E and F are open. The economy and break-it passes rerun at every sprint close.
- Watches on the live board, and the carried reds in [KNOWN-FAILING.tsv](KNOWN-FAILING.tsv) (ruling bq).
- After the sitting, once the sound lane's pull requests have settled: type the four audio files that worker threads run (`synth.gd`, `harmony.gd`, `sfx_bank.gd`, `music_engine.gd`), make an untyped declaration in them an error, and add a cold two-thread stress test ([issue 593](https://github.com/bananahana720/scrapkeep/issues/593)). Parked on 10 November 2026: 300 cold boots (150 in the cloud, 150 on the PC) showed no crash.

### Andrew plays

Ruling cs (10 Nov): he plays the promotion that closes the polish program in [STATE.md](STATE.md), launched from the menu entry "Scrapkeep sitting (fresh profile, unlocks earned)" (`--profile=sitting-earned`, W1-78). That launch carries the loops of rulings da, dd and df and ends the run won at Brindle (ruling dk) on a profile that keeps what it earns; the plain entry has none of the loops and plays on the player's own save, though since ruling du (14 Nov) it also ends at Brindle. He plays world 1 as often as he likes and marks the world 1 areas on the [Sitting Kit](https://claude.ai/artifact/HxmWTSrJf1vifhjXXPW1qT). The sheet tells him what to try. A capture is void if he plays during it.

### Re-read after the sitting (already ruled to wait)

- HARD rung 5 target (rulings aq, bc, be: 56% at 48 seeds when ruled; the wave 34 gate reads 63% on main and on the head).
- w1 Novice: no longer a ceiling to hold. Ruling cu makes it a target that must drop; the wave 37 band read is 35% against 15% or less.
- Flume length (ruling ax: skipper 154 s under its 180 s floor; levers: a 1-2 pack clamp or a longer route).
- Completionist time (ruling ag: bot 20.8 min against 15-20; his wall time decides).
- Brindle's cobalt pick (ruling ap): parked until world 2 is in a sitting.

## Phase 2: world 1 variety, then the full alpha

Starts when world 1's verdicts are in and his fixes are routed.

1. **Fix what he marks.** Every "fixes" or "Not yet" note becomes a unit, world 1 first.
2. **Layer repeatable variety on world 1** (23 Oct): stage variants, run modifiers and unlock-gated anticipation, Isaac-style but never copied. Designed as seeds behind the world 1 plan; built once the core holds.
3. **Lift ruling at** (world 2 out of scope) and bring worlds 2 and 3 to world 1's standard:
   - Dig (pit, sinkhole, the Waking) and Highdraft (islands, crown, the Mind): three-phase Waking and Mind fights with their anthem phases (+10 and +20 BPM covers), two-phase mini-bosses, rosters re-read against "unique per world, harder remixes".
   - Staged story beats outside world 1 (world 1 has the cold open, Rivet, the reveal and the clear card; the other worlds had none on 23 Oct).
   - Soft-toy polish and dressing to the dam's bar; refsheets before any new body.
   - Item rungs: cobalt is the top ordinary rung in every world for the alpha (ruling bn); Brindle's cobalt pick returns.
   - Perf parked from world 1: sinkhole Dispatcher 265-277 ms, EventFamilies.build 69 ms at stage 5, Dig pit beacon bursts, Jolt shape builds.
   - Difficulty bands in all six stages and the HARD replay ladder across worlds (not a cut candidate, 21 Oct).
   - Every area of the Dig and the Highdraft authored to [the area blueprint](../../sketches/core-loop/design-v3/park/AREA-BLUEPRINT.md) (Andrew, 19 Nov): a purpose, a reason to be there (something to find, work or set off, or a job as a breather), a high and a low route where the ground forks, a board and reference sheets before a model. Rows AB-01 to AB-09 in [BACKLOG.md](../../BACKLOG.md#area-blueprint).
4. **Full-alpha sitting.** Title to the Mind's end through all six stages, the camp, pilot paint and 18 cosmetics, all six systems, the AppImage from the app menu. Accepted on 11 areas with no "Not yet", no blocker, frames in budget, zero placeholders.

The 11 areas: core feel; Wardens and bosses; in-run growth; progression across runs; pilots; stages and world; look; sound and music; clarity; difficulty and pacing; stability.

## Phase 3: after the alpha (parked until the full sitting)

- Story, lore, characters, boss and system tweaks from his sitting notes.
- Item rungs above cobalt (pearl prototypes, gold relics; ruling bn), brass boss trophies, hotwire kits, the Mind's offerings (purple), Work Orders as a camp menu.
- New game plus as world mutations; challenges; monster origins, park societies, pilot personality; richer world transitions; alternate worlds or paths.
- A fourth world, or a twist where the Mind you beat is not the real foreman (a seed, not a ruling).
- Toward a beta or a low-cost public release, ordered by what to add.
