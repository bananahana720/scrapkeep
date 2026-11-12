# Scrapkeep roadmap

The one roadmap. Written 8 Nov 2026; facts refreshed 9 Nov after the wave 32 promotion (main 8180ec6c). Phone copy: https://claude.ai/artifact/55bppMdvsEXW52ZVFyhNna (source /mnt/project-files/roadmap/roadmap.html). Live wave state is in [STATE.md](STATE.md); rulings are in [DECISIONS.md](DECISIONS.md) (newest wins). The waves 18 to 21 plan in [../coord/ROADMAP.md](../coord/ROADMAP.md) is history.

The roadmap is ordered by what has to be true, not by dates. Wave numbers keep counting (STATE.md names the open one); "wave 21" in older records means the full-alpha sitting, not a wave number still ahead.

## Where we are

- **Goal (16 Oct, unchanged):** a finished-feeling Linux alpha, accepted at one sitting: 11 areas marked with no "Not yet", no open blocker, frame times in budget, zero placeholders.
- **Priority (23 Oct, ruling at):** world 1 first. Worlds 2 and 3 start nothing new until the world 1 sitting is done.
- **World 1 sitting:** started, not finished. Andrew played the dam on the wave 26 build on 30 Oct ("fun"; many invisible walls; models clipping). Every fix shipped in wave 29 (#600, #601, #602 and the clipping lane). No area verdicts are recorded yet (Sitting Kit store empty, read 8 Nov).
- **Build on the PC:** the promoted wave 32 build (main 8180ec6c), installed 9 Nov. Rollbacks: the wave 32 pre-gate and wave 31 AppImages.
- **Measured on w34 (gate CLEAN on 75099fa7, bands identical to w33 main run for run):** W1 Novice 38% (9 of 24), Rusty 75%, Expert 100%; HARD rungs 100/96/100/88/63%. 0 placeholders. The 4080 p99 medians are the wave 32 ones until the next frame pass: dam 14.8 ms, flume 15.2 ms, Brindle 12.2 ms.

## Phase 1: the world 1 sitting

World 1 is the title, the camp, the dam, the flume and Brindle in the Slag Bowl. Done means Andrew has played it through and marked its areas on the Sitting Kit.

### Left before he plays

| # | Item | Owner | State |
| --- | --- | --- | --- |
| 1 | Wave 34: the first full gate on the PC, the weekly sweep, promotion | Local coordinator | Done: main bc4adc1a (#745), 10 Nov |
| 2 | Wave 35, words and first checks: kit pick cards, the run summary and Esc in one press, item words, key prompts, the sound contract checks, three map checks (ruling ct), the PC gate command, stage 2's card named for the flume | Local coordinator | Stacked on `stage/alpha-w35`; its gate is next |
| 3 | Wave 36, read the fight and build the instruments: danger marks and the yard wall look (PF-16, 25, 27), the HUD (PF-19, 20, 21), the landmark beam (PF-28), the snag sweep and far-prop mesh faults, the difficulty measurement, the hand-over rows and test, the map sheet and transition strip captures, the Warden-form split out of `audio.gd`; a player's-eye read on its head | Local coordinator | Not started |
| 4 | Wave 37, harder by movement (ruling cu): chasers lead and run faster, the Warden pulse, a third clock tier, regen only while rolling, terrain stops shells with more lobber lead, boils punish the stall; the conductor link S1 to S3 default off | Local coordinator | Built and parked on `claude/w37-difficulty` (fd29b0873), not stacked. Ruling cy moves it to the end of the sprint: it lands after rows 5 and 6's polish and before the release gate. Paired band reads, 24 to 96 seeds an arm, to the targets in [the difficulty plan](shared/world1/difficulty-plan.md) |
| 5 | Wave 38, one ride (ruling cv): a swipe over both stage cuts, the rail turns to the arrival heading, the Slag Bowl ahead of the flume launch with landing rings and a smoke column, objective markers, scrap on the skill lines, breather zones paired with pressure, the four clip snaps | Local coordinator | Not started |
| 6 | Wave 39, the sitting build: the Warden form on the synth band and on Brindle, the camera only if the film asks, the Slag Bowl stand crew bodies, the sitting sheet refresh, the final gate with a first-timer red team, the install with rollbacks | Local coordinator | Not started. It closes as "ready for your verdict" |

Parked until after the sitting: the way out of the Slag Bowl into world 2, the dam launch over the crest, the rebuilt concave flume yard (the bowl test records it as OWED), a reactive valve, two-variant sub-regions, arrivals on the musical grid, enemy health (ruling al), and the dam Warden's sheet heading (ruling cm).

### Engineering hygiene that rides along (never holds a promotion)

- Slow-box time caps (boss_weak_parts, crown_warden_bot, run_tier children, bot_skill_bar): the dam leftovers lane raises the tests' own caps; the runner gains a time scale for slow boxes ([GATE.md](GATE.md)).
- Deep-modules batch 2 from the queued list ([DEEP-SWEEP.md](DEEP-SWEEP.md)).
- The systems audit add-on (Andrew, 11 Nov): six passes, world 1 first, defined as cards SA-A to SA-F in [BACKLOG.md](../../BACKLOG.md#systems-audit-add-on-11-november-2026), plan in [docs/systems-audit/PLAN.md](../../docs/systems-audit/PLAN.md). The economy and break-it passes rerun at every sprint close.
- Watches on the live board, and the carried reds in [KNOWN-FAILING.tsv](KNOWN-FAILING.tsv) (ruling bq).
- After the sitting, once the sound lane's pull requests have settled: type the four audio files that worker threads run (`synth.gd`, `harmony.gd`, `sfx_bank.gd`, `music_engine.gd`), make an untyped declaration in them an error, and add a cold two-thread stress test ([issue 593](https://github.com/bananahana720/scrapkeep/issues/593)). Parked on 10 November 2026: 300 cold boots (150 in the cloud, 150 on the PC) showed no crash.

### Andrew plays

Ruling bm named the wave 32 build and ruling bo (9 Nov) the promotion that carried the pre-sitting pass. Ruling cs (10 Nov) moved the sitting behind "world 1 fully polished": he plays the promotion that closes the polish program in [STATE.md](STATE.md), launched from the plain menu entry. He plays world 1 as often as he likes and marks the world 1 areas on the [Sitting Kit](https://claude.ai/artifact/HxmWTSrJf1vifhjXXPW1qT). The sheet tells him what to try. A capture is void if he plays during it.

### Re-read after the sitting (already ruled to wait)

- HARD rung 5 target (rulings aq, bc, be: 56% at 48 seeds when ruled; the wave 34 gate reads 63% on main and on the head).
- w1 Novice: no longer a ceiling to hold. Ruling cu makes it a target that must drop (20% or less at the dam Warden); the wave 34 gate reads 38%.
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
4. **Full-alpha sitting.** Title to the Mind's end through all six stages, the camp, pilot paint and 18 cosmetics, all six systems, the AppImage from the app menu. Accepted on 11 areas with no "Not yet", no blocker, frames in budget, zero placeholders.

The 11 areas: core feel; Wardens and bosses; in-run growth; progression across runs; pilots; stages and world; look; sound and music; clarity; difficulty and pacing; stability.

## Phase 3: after the alpha (parked until the full sitting)

- Story, lore, characters, boss and system tweaks from his sitting notes.
- Item rungs above cobalt (pearl prototypes, gold relics; ruling bn), brass boss trophies, hotwire kits, the Mind's offerings (purple), Work Orders as a camp menu.
- New game plus as world mutations; challenges; monster origins, park societies, pilot personality; richer world transitions; alternate worlds or paths.
- A fourth world, or a twist where the Mind you beat is not the real foreman (a seed, not a ruling).
- Toward a beta or a low-cost public release, ordered by what to add.
