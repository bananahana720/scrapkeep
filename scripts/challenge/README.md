# Challenge band table

The challenge lane says every boss and Warden should beat a Novice, give a Learner a fair fight and fall to an Expert, and that a park should be reachable by a Learner and often not by a Novice. This harness measures that. It plays each boss, each Warden and each world's approach to its Warden with the Novice, Learner and Expert bot bands from saved builds, grades the win rates against the targets, and prints one table.

It changes nothing in the game and is not the gate. The bands (what a Novice, Learner and Expert bot do differently: reaction, aim, dodging, how the attempt number teaches) live in `sketches/core-loop/tools/skill_band.gd` and are read by `tools/bot_run.gd` as `--band=novice|learner|expert` and `--attempt=N`. This harness only chooses builds, seeds and cells and counts.

## The targets

From the coordinator ruling, `project-guide/handoff/DECISIONS.md` section 5, 19 Oct 01:58 (encoded in `lib.mjs` as `TARGETS`):

> Base-tier targets with an ordinary build: bosses and Wardens beat Novice in at least 85% of attempts; Learner wins 15-35% on a first attempt and 60% or more by the fifth; Expert wins 85% or more; a top-decile (cracked) build with an Expert wins 97% or more and keeps the existing growth ratios. Every lethal attack has a readable tell of at least 0.6 s, and no boss kills a Learner in its first 45 s. Parks: Novice reaches the world's Warden in at most half its runs, Learner in 80% or more.

| Column | Cell | Target |
| --- | --- | --- |
| Novice | boss, Warden | win at most 15% |
| Learner a1 | boss, Warden | win 15% to 35% on attempt 1 |
| Learner a5 | boss, Warden | win at least 60% on attempt 5 |
| Expert ordinary | boss, Warden | win at least 85% |
| Expert top | boss, Warden | win at least 97%; the fight-time ratio top/ordinary is shown for the growth-ratio check |
| Learner a1 deaths | boss | no death before 45 s of boss time |
| Novice, Learner a1 | park (world) | reach the Warden: Novice at most 50%, Learner at least 80% |

The 0.6 s tell is not measured: a bot cannot say what a person reads. It stays a design and Andrew-sitting check.

A cell's mark is a point-estimate check (`✓`/`✗`); the Wilson 95% interval sits beside it, so a `✗` inside a wide interval reads as "run more seeds", not "broken". A timeout (stall, fight cap, tick guard) is never a win and is counted apart; so is an error (no record).

## Cells

| Id | Cell | What runs |
| --- | --- | --- |
| `brindle`, `waking`, `mind` | boss | Resume the last stage of the world (stages 2, 4, 6) and enter the boss at once (`--to-boss=1`). Win is `boss.defeated_s`. |
| `w1` to `w6` | Warden | Resume stage N and play it to its exit (`--until=N`). Win is the stage note's `warden_broken_s`. Guard (240+90) s. |
| `world1` to `world3` | park | Resume the world's first stage (1, 3, 5) and stop the tick the world's Warden is engaged (`--stop-at=engaged:<last stage>`). Win is outcome `reached`. |

Stage 1 has no build to carry, so `w1`, `brindle`-style stage-1 cells and `world1` play fresh and the seed picks the pilot.

## Run it

```bash
# 1. The build library: full park runs of today's bot, every stage entrance saved.
npm run challenge:bands -- --library --lib-seeds=4 --label=lib-main     # about 1 hour on 4 cores
# 2. The table.
npm run challenge:bands -- --library=artifacts/local/challenge/library/lib-main --label=main
npm run challenge:bands -- --library=<dir> --only=w1,brindle --seeds=4 --dry-run   # job count and time first
# 3. Several sandboxes: split, then join.
npm run challenge:bands -- --library=<dir> --shard=1/3 --label=main-1
npm run challenge:bands -- --merge=artifacts/local/challenge/main-1,artifacts/local/challenge/main-2,artifacts/local/challenge/main-3 --label=main
```

| Option | Default | What it does |
| --- | --- | --- |
| `--library` (bare) | | Build the library. `--lib-seeds=<n>` (4) seeds for each of 6 pilots and 2 policies (completionist, skipper); `--lib-pilots=a,b` restricts the pilots. No band: today's bot. Cut at `--until=6`, 3600 s timeout. Runs that die early still add the stages they reached. |
| `--library=<dir>` | | Use a library for the table. |
| `--cells=` | `boss,warden,world` | Which kinds. |
| `--only=` | all | `brindle,waking,mind,w1..w6,world1..world3`. |
| `--seeds=<n>` | 16 | Runs per cell per column. Seeds are fixed per cell, so columns face the same seeds; each seed takes the next build of its bucket, so pilots mix. |
| `--bands=` | `novice,learner1,learner5,expert` | Columns. The Expert top column is added whenever `expert` is, unless `--no-top`. Parks run only `novice` and `learner1`. |
| `--persona=` | `brawler` | The bot policy for bosses and Wardens (`brawler` is the completionist's fight profile). `--park-persona=skipper` for parks. |
| `--jobs=<n>` | 4 | Godot processes at once (at most 6). Band sweeps can run out of memory; a job that times out or is killed is rerun once alone before it counts. |
| `--label=` | `run-<stamp>` | Output folder name under `artifacts/local/challenge/`. |
| `--shard=i/n` | | Jobs `k` where `k mod n = i-1`, over the planned list: deterministic, disjoint, joined by `--merge`. |
| `--merge=<dir,...>` | | Aggregate existing `runs.ndjson` files and print the table; runs nothing. |
| `--dry-run` | | Print the job count and an estimated wall time. |
| `--strict` | | Exit 1 when any cell has a `✗`. Otherwise exit 0 whenever the harness ran. |

`tools/band_run.gd` is the Godot side: `tools/bot_run.gd` plus `--entrance=<file>` (resume a saved doc), `--keep-entrances=1` (save each stage entrance as `entrance-s<N>.json`), `--to-boss=1`, `--stop-at=engaged:<stage>` and `--cell=<id>`.

Output: `artifacts/local/challenge/<label>/`: `runs.ndjson` (one line per job: its fields, the bot row, the grade, wall seconds), `table.md`, `table.json` and `jobs/<id>/` (log and `out/bots.ndjson`).

## Limits

- Bots, not people. The bands model reaction and skill with parameters; a win rate here says how the bands fare, and Andrew's sitting decides whether a Learner feels like one. The 0.6 s tell is a design check and is not measured.
- Headless simulation time at 90 ticks a second, one process per run, on the source tree, with the park table and the gate switches. It is not a frame-time or hardware result.
- Builds come from today's bot runs (no band), at each stage entrance: they are what the completionist and skipper happen to carry, not what a player would build. "Ordinary" is the middle fifth of the library by mass, then parts count; "top" is the top tenth. A library from a different commit measures a different game; the table's `table.json` records the commit it ran on, not the library's.
- Boss cells enter the boss at the stage's start with the saved ball position, not carried from the exit run; a Warden fight starts from the stage's entrance, so it includes the approach.
- One Learner attempt number per run: the a5 column plays attempt 5 fresh with the band's teaching applied, not five consecutive fights.
- The seed counts decide the interval width; 16 seeds per column gives about plus or minus 20 points near 50%.
