# Scrapkeep roadmap

The one roadmap. Written 8 Nov 2026 on stage/alpha-w32 24ebf5e8 (main 645893f3, the wave 31 promotion). Phone copy: https://claude.ai/artifact/55bppMdvsEXW52ZVFyhNna (source /mnt/project-files/roadmap/roadmap.html). Live wave state is in [STATE.md](STATE.md); rulings are in [DECISIONS.md](DECISIONS.md) (newest wins). The waves 18 to 21 plan in [../coord/ROADMAP.md](../coord/ROADMAP.md) is history.

The roadmap is ordered by what has to be true, not by dates. Wave numbers keep counting (32 now); "wave 21" in older records means the full-alpha sitting, not a wave number still ahead.

## Where we are

- **Goal (16 Oct, unchanged):** a finished-feeling Linux alpha, accepted at one sitting: 11 areas marked with no "Not yet", no open blocker, frame times in budget, zero placeholders.
- **Priority (23 Oct, ruling at):** world 1 first. Worlds 2 and 3 start nothing new until the world 1 sitting is done.
- **World 1 sitting:** started, not finished. Andrew played the dam on the wave 26 build on 30 Oct ("fun"; many invisible walls; models clipping). Every fix shipped in wave 29 (#600, #601, #602 and the clipping lane). No area verdicts are recorded yet (Sitting Kit store empty, read 8 Nov).
- **Build on the PC:** stage/alpha-w32 24ebf5e8 (#628, #629), installed 8 Nov 19:07Z at Andrew's request as a pre-gate build with the new mix. Rollback: the w31 AppImage.
- **Measured on w31 (gate CLEAN on 80af241e):** W1 Novice 42%, Learner a1 79%, a5 83%, Expert 100%; HARD rungs 100/100/96/88/56%. 4080 p99 medians: dam 14.8 ms, flume 15.2 ms, Brindle 12.2 ms. 0 placeholders.

## Phase 1: the world 1 sitting

World 1 is the title, the camp, the dam, the flume and Brindle in the Slag Bowl. Done means Andrew has played it through and marked its areas on the Sitting Kit.

### Left before he plays

| # | Item | Owner | State |
| --- | --- | --- | --- |
| 1 | Wave 32 full gate, first-timer red team, promotion | Gate | Stage open; #628 and #629 stacked |
| 2 | Dam Warden `sheet_dir` [0,0,-1] plus the bot sheet-foot return, then re-read Learner a5 | Dam lane | Queued on board #627 |
| 3 | Dam east-end airborne invisible patch at (200, 94-98, 642), owed under ruling aa | Needs an owner | Queued |
| 4 | Clip-audit correction | Clipping lane | Queued |
| 5 | Sitting sheet refresh for the build he plays (Try lines from the watch list) | Sitting prep | Owed |
| 6 | Esc on the run summary quits in one press (SITTING-GAPS 11) | Cloud | Not re-checked since 28 Oct |
| 7 | Slag Bowl stand crew bodies (163 recipe shapes): refsheets and one Mojulo shell, then a mesh swap | PC, then cloud | A Look note if it misses, not a gate fail |

The rest of the 28 Oct gap list is closed: the dunk tip, the held radio and active tips, the rung card on a fresh profile, the clamp crew marker and pause over the tier card are in the code; the audio gate and the 4080 frame row ran on the PC.

### Engineering hygiene that rides along (never holds a promotion)

- Slow-box time caps (boss_weak_parts, crown_warden_bot, run_tier children, bot_skill_bar): needs an owner.
- `--audio-driver Dummy` in `bossSmokeCommand` in `scripts/sketch-export.mjs`.
- Deep-modules batch 2 from the queued list ([DEEP-SWEEP.md](DEEP-SWEEP.md)).
- Stale band waiver: `scripts/world1-bands.rows.json` still grades w1 Learner a5 at >= 58% (ruling bb, a w29 waiver); w31 measured 83%. Return it to the >= 60% target once the dam sheet_dir PR lands and a5 is re-read.
- Watches on #627 and the owed base-same reds in STATE.md.

### Andrew plays

He launches the plain menu entry, plays world 1 as often as he likes and marks the world 1 areas on the [Sitting Kit](https://claude.ai/artifact/HxmWTSrJf1vifhjXXPW1qT). The sheet tells him what to try. A capture is void if he plays during it.

### Re-read after the sitting (already ruled to wait)

- HARD rung 5 target (rulings aq, bc, be: 56% at 48 seeds).
- w1 Novice ceiling (ruling bk: 42%, was ab's 40%).
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
   - Item rungs per world: world 2 adds cobalt drops to its pools; Brindle's cobalt pick returns.
   - Perf parked from world 1: sinkhole Dispatcher 265-277 ms, EventFamilies.build 69 ms at stage 5, Dig pit beacon bursts, Jolt shape builds.
   - Difficulty bands in all six stages and the HARD replay ladder across worlds (not a cut candidate, 21 Oct).
4. **Full-alpha sitting.** Title to the Mind's end through all six stages, the camp, pilot paint and 18 cosmetics, all six systems, the AppImage from the app menu. Accepted on 11 areas with no "Not yet", no blocker, frames in budget, zero placeholders.

The 11 areas: core feel; Wardens and bosses; in-run growth; progression across runs; pilots; stages and world; look; sound and music; clarity; difficulty and pacing; stability.

## Phase 3: after the alpha (parked until the full sitting)

- Story, lore, characters, boss and system tweaks from his sitting notes.
- Item rungs above cobalt (pearl prototypes, gold relics), brass boss trophies, hotwire kits, the Mind's offerings (purple), Work Orders as a camp menu.
- New game plus as world mutations; challenges; monster origins, park societies, pilot personality; richer world transitions; alternate worlds or paths.
- A fourth world, or a twist where the Mind you beat is not the real foreman (a seed, not a ruling).
- Toward a beta or a low-cost public release, ordered by what to add.
