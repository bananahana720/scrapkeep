# Scrapkeep roadmap

The one roadmap. Written 8 Nov 2026, refreshed 12 Nov with wave 37 open. Phone copy: https://claude.ai/artifact/55bppMdvsEXW52ZVFyhNna (source /mnt/project-files/roadmap/roadmap.html). Live wave state is in [STATE.md](STATE.md); rulings are in [DECISIONS.md](DECISIONS.md) (newest wins).

The roadmap is ordered by what has to be true, not by dates. Wave numbers keep counting (STATE.md names the open one); "wave 21" in older records means the full-alpha sitting, not a wave number still ahead.

## Where we are

- **Goal (16 Oct, unchanged):** a finished-feeling Linux alpha, accepted at one sitting: 11 areas marked with no "Not yet", no open blocker, frame times in budget, zero placeholders.
- **Priority (23 Oct, ruling at):** world 1 first. Worlds 2 and 3 start nothing new until the world 1 sitting is done.
- **World 1 sitting:** started, not finished. Andrew played the dam on the wave 26 build on 30 Oct ("fun"; many invisible walls; models clipping); every fix shipped in wave 29. No area is marked yet. Ruling cs (10 Nov) holds the sitting until world 1 is fully polished.
- **Main:** wave 37 (b190dd26, 12 Nov). Wave 38 is open; [STATE.md](STATE.md) says where it stands.
- **Last measures with receipts:** the wave 37 difficulty band read (board, 12 Nov 04:08Z): w1 Novice 35% against a target of 15% or less (29% without the stack), Learner a5 79%, Expert 96%. The 4080 p99 medians are still wave 32's: dam 14.8 ms, flume 15.2 ms, Brindle 12.2 ms. 0 placeholders.

## Phase 1: the world 1 sitting

World 1 is the title, the camp, the dam, the flume and Brindle in the Slag Bowl. Done means Andrew has played it through and marked its areas on the Sitting Kit.

### Left before he plays

| # | Item | State |
| --- | --- | --- |
| 1 | Waves 34 to 36: the first PC gate, words and first checks, danger marks, the HUD and the instruments | Done: main 47c79b49 (#750), 11 Nov |
| 2 | Wave 37, one ride and the bugs (ruling cv): both launches under the comic swipe, heading carried across a launch, the Slag Bowl ahead of the flume launch, the lift and crate fixes; the systems audit fixes; the loop mechanics Heat, Overtime, Called Shot, marked hull and carry a core, behind the sitting launch (rulings da, dd, df) | Done: main b190dd26 (#812), 12 Nov |
| 3 | Wave 38, polish: the open play findings (PF-16, PF-22, PF-26, PF-34 to PF-40), objective markers, breathers, scrap on the skill lines, the clip snaps, the Slag Bowl smoke column, the sitting build's look and sound | Open on `stage/alpha-w38`; its wave gate runs on the PC |
| 4 | Harder by movement (ruling cu): chasers lead and run faster, the Warden pulse, a third clock tier, regen only while rolling, terrain stops shells, boils punish the stall | Backed out of wave 37 when the gate found seven new reds; re-landed on wave 38 with pull request 805. Judged by paired band reads to the targets in [the difficulty plan](shared/world1/difficulty-plan.md) |
| 5 | The look rebuilds (ruling dj): the crew's distinct heads, the dam, the title screen and Brindle's armour plates, the last two areas with a taste page first | Build threads started 12 Nov; they land on the wave after the one open when each passes its checks |
| 6 | The sitting run ends won at Brindle (ruling dk, W1-60), then Moss's last call and his hook (W1-73, W1-79) on the same flow fence | Build thread started 12 Nov |
| 7 | The sitting build: the Warden form on the synth band and on Brindle, the Slag Bowl stand crew bodies, the sitting sheet refresh, the release gate with a first-timer red team, the install with rollbacks | Not started. It closes as "ready for your verdict" |

Parked until after the sitting: dam perf remainders (the f4045 riser, the Warden break and engage spikes, the seed 3 f14k swing); the twin-line grapple prototype (pull request 771, waiting on Andrew's feel check); the way out of the Slag Bowl into world 2, the dam launch over the crest, the rebuilt concave flume yard (the bowl test records it as OWED), a reactive valve, two-variant sub-regions, arrivals on the musical grid, enemy health (ruling al), and the dam Warden's sheet heading (ruling cm).

### Engineering hygiene that rides along (never holds a promotion)

- The world 1 and scaling backlog (Andrew, 12 Nov): every buildable row for world 1 now, the rows other threads own, and the groundwork for more stages, worlds and features, in [BACKLOG.md](../../BACKLOG.md#world-1-and-scaling-backlog-12-november-2026). World 1 rows rank first; a scaling row may not change what the sitting plays.
- Deep-modules batch 2 from the queued list ([DEEP-SWEEP.md](DEEP-SWEEP.md)).
- The systems audit add-on (Andrew, 11 Nov): six passes, world 1 first, defined as cards SA-A to SA-F in [BACKLOG.md](../../BACKLOG.md#systems-audit-add-on-11-november-2026), plan in [docs/systems-audit/PLAN.md](../../docs/systems-audit/PLAN.md). Passes A to D are done, E and F are open. The economy and break-it passes rerun at every sprint close.
- Watches on the live board, and the carried reds in [KNOWN-FAILING.tsv](KNOWN-FAILING.tsv) (ruling bq).
- After the sitting, once the sound lane's pull requests have settled: type the four audio files that worker threads run (`synth.gd`, `harmony.gd`, `sfx_bank.gd`, `music_engine.gd`), make an untyped declaration in them an error, and add a cold two-thread stress test ([issue 593](https://github.com/bananahana720/scrapkeep/issues/593)). Parked on 10 November 2026: 300 cold boots (150 in the cloud, 150 on the PC) showed no crash.

### Andrew plays

Ruling cs (10 Nov): he plays the promotion that closes the polish program in [STATE.md](STATE.md), launched from the plain menu entry. He plays world 1 as often as he likes and marks the world 1 areas on the [Sitting Kit](https://claude.ai/artifact/HxmWTSrJf1vifhjXXPW1qT). The sheet tells him what to try. A capture is void if he plays during it.

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
4. **Full-alpha sitting.** Title to the Mind's end through all six stages, the camp, pilot paint and 18 cosmetics, all six systems, the AppImage from the app menu. Accepted on 11 areas with no "Not yet", no blocker, frames in budget, zero placeholders.

The 11 areas: core feel; Wardens and bosses; in-run growth; progression across runs; pilots; stages and world; look; sound and music; clarity; difficulty and pacing; stability.

## Phase 3: after the alpha (parked until the full sitting)

- Story, lore, characters, boss and system tweaks from his sitting notes.
- Item rungs above cobalt (pearl prototypes, gold relics; ruling bn), brass boss trophies, hotwire kits, the Mind's offerings (purple), Work Orders as a camp menu.
- New game plus as world mutations; challenges; monster origins, park societies, pilot personality; richer world transitions; alternate worlds or paths.
- A fourth world, or a twist where the Mind you beat is not the real foreman (a seed, not a ruling).
- Toward a beta or a low-cost public release, ordered by what to add.
