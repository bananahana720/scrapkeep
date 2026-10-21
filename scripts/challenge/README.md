# Challenge band table

The challenge lane says every boss and Warden should beat a Novice, give a Learner a fair fight and fall to an Expert, and that a park should be reachable by a Learner and often not by a Novice. This harness measures that. It plays each boss, each Warden and each park's approach to its own Warden with the Novice, Learner and Expert bot bands from saved builds, grades the win rates against the targets, and prints one table.

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
| Learner deaths (a1 and a5) | boss | no death before 45 s of boss time |
| Novice, Learner a1 | park | reach the park's Warden: Novice at most 50%, Learner at least 80% |

The 0.6 s tell is not measured: a bot cannot say what a person reads. It stays a design and Andrew-sitting check.

A fight-report section follows the win rates, in the per-Warden format the coordinator set on #149 (`sketches/core-loop/design-v3/research/comps/difficulty/SUMMARY.md`, Lab measure): Expert ordinary TTK, the largest single hit as a share of pilot health with its source, and the Learner attempt-1 health lost in the first 45 s (`largest_hit*` and `hp_lost_45s` in the bot record, counted from the boss entry or the Warden fight's start). Tell lengths and recovery in data come from the attack sheet (`tools/attack_sheet.gd`).

A cell's mark is a point-estimate check (`✓`/`✗`); the Wilson 95% interval sits beside it, so a `✗` inside a wide interval reads as "run more seeds", not "broken". A timeout (stall, fight cap, tick guard) is never a win and is counted apart, beside the deaths. An error (no record, boss never entered, no boss module in the boss state, doc not resumed) and a harness kill (`killed`, a wall timeout that a rerun alone did not fix) are excluded from n and the rate and noted per column as `excluded: N error, M killed`; when more than 10% of a column's jobs are excluded, the column is `incomplete` and gets no ✓/✗.

The top/ord fight-time ratio is reported, not graded: the 2x hive rule is graded by `posture_bands_*`, and the ruling's "keeps the existing growth ratios" is not asserted here. The Learner 45 s check covers both attempt 1 and attempt 5 boss deaths.

## Cells

| Id | Cell | What runs |
| --- | --- | --- |
| `brindle`, `waking`, `mind` | boss | Resume the last stage of the world (stages 2, 4, 6) and enter the boss at once (`--to-boss=1`). Win is `boss.defeated_s`. |
| `w1` to `w6` | Warden | Resume stage N and play it to its exit (`--until=N`). Win is the stage note's `warden_broken_s`. The fight may last 240 s from engagement (`--fight-limit`, over 3x the 45-85 s stagger bands); the stage cap is lifted to 600 s (`--stage-limit`) so it cannot cut an engaged fight first. A `fight_capped` or `stalled` run is a timeout, never a win, and is counted beside the deaths. |
| `park1` to `park6` | park | Resume park N and stop the tick its own Warden is engaged (`--stop-at=engaged:N`). Win is outcome `reached`. This is the default park measure: the ruling's "reaches the world's Warden" is read per park, because a Learner who wins a Warden 15-35% of the time on a first try cannot reach the next park's Warden 80% of the time. |
| `world1` to `world3` | park, only with `--cells=world` | Resume the world's first park (1, 3, 5) and stop the tick its second park's Warden is engaged, so the run must break the first Warden on the way. Information only (coordinator ruling 19 Oct 04:32Z, "chain, information only"): the table prints it in its own section with no target and no ✓/✗, and it never counts as failing. |

Stage 1 has no build to carry, so only `w1`, `park1` and `world1` play fresh runs and the seed picks the pilot. Every other cell resumes a library doc, and the run checks it did: stage, parts count and mass must match the doc (`resumed` in the row). A run that did not resume is an error.

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
| `--lib-shard=i/n` | | With `--library`: run only shard i of n of the 48 library runs (deterministic). |
| `--library-merge=<dir,...>` | | With `--label=<name>`: join shard library folders into `library/<label>` with one `index.json`. |
| `--library=<dir>` | | Use a library for the table. |
| `--cells=` | `boss,warden,park` | Which kinds (`world` adds the world chains). |
| `--only=` | all | `brindle,waking,mind,w1..w6,park1..park6,world1..world3`. |
| `--seeds=<n>` | 24 fights, 16 parks | Runs per cell per column. Seeds are fixed per cell, so columns face the same seeds; each seed takes the next build of its bucket, so pilots mix. |
| `--bands=` | `novice,learner1,learner5,expert` | Columns. The Expert top column is added whenever `expert` is, unless `--no-top`. Parks run only `novice` and `learner1`. |
| `--persona=` | `brawler` | The bot policy for bosses and Wardens (`brawler` is the completionist's fight profile) for bosses; Wardens use `--warden-persona=skipper`, which beelines to the Warden (the completionist spends the stage cap on scrap lines before engaging); parks use `--park-persona=skipper`. |
| `--jobs=<n>` | 4 | Godot processes at once (at most 6). Band sweeps can run out of memory; a job that times out or is killed is rerun once alone before it counts. |
| `--label=` | `run-<stamp>` | Output folder name under `artifacts/local/challenge/`. |
| `--tune=k=v,k=v` | none | Difficulty dials (`src/core/challenge_dials.gd`), passed to every job as Godot `--tune=` and printed in the table header. Arrays use `a/b/c/d`. Run records carry a `dials` field only when set. |
| `--shard=i/n` | | Jobs `k` where `k mod n = i-1`, over the planned list: deterministic, disjoint, joined by `--merge`. |
| `--merge=<dir,...>` | | Aggregate run folders and print the table; runs nothing. Each folder's `meta.json` (shard, plan hash, commit, library) must agree, and every shard i of n must be present, or the merge is refused (`--allow-mixed` waives the plan, commit and library checks, never a missing or duplicate shard; with it, the same cell from two plans counts twice). |
| `--resume` | | Continue an existing `--label`. Without it an existing label is refused, so rows never pile up across runs. Jobs whose row is for this plan and commit are skipped, except rows graded error or killed, which run again. |
| `--allow-mixed` | | Let the table or a merge take rows or folders from different commits or plans. |
| `--tune=<text>` | | Free text folded into the plan hash and forwarded to the runner as `--tune=`. |
| `--dry-run` | | Print the job count and an estimated wall time. |
| `--strict` | | Exit 1 when any cell has a `✗`. Otherwise exit 0 whenever the harness ran. |

`tools/band_run.gd` is the Godot side: `tools/bot_run.gd` plus `--entrance=<file>` (resume a saved doc), `--keep-entrances=1` (save each stage entrance as `entrance-s<N>.json`), `--to-boss=1`, `--stop-at=engaged:<stage>` and `--cell=<id>`.

`runs.ndjson` keeps each job's entrance relative to its library and grading reads only the record, so run folders from different machines merge with `--merge`. The run ends by printing wall and game medians per job kind, saved as `timing` in `table.json`, to re-estimate `--dry-run`.

Output: `artifacts/local/challenge/<label>/`: `meta.json` (shard, plan hash, commit, library, buckets), `runs.ndjson` (one line per job: its fields, `key` = library:plan:commit:id, the bot row, the grade, wall seconds), `table.md`, `table.json` and `jobs/<id>/` (log and `out/bots.ndjson`).

## Limits

- Bots, not people. The bands model reaction and skill with parameters; a win rate here says how the bands fare, and Andrew's sitting decides whether a Learner feels like one. The 0.6 s tell is a design check and is not measured.
- Headless simulation time at 90 ticks a second, one process per run, on the source tree, with the park table and the gate switches. It is not a frame-time or hardware result.
- Builds come from today's bot runs (no band), at each stage entrance: they are what the completionist and skipper happen to carry, not what a player would build. "Ordinary" is the 40th to 60th percentile of the library by mass, then parts count; "top" is the 90th and up. A bucket under three docs widens (ordinary one rank each way, top downward) until it has three or holds every doc, so a small library makes the buckets overlap, even share docs. The table lists each stage's bucket sizes and the overlap, and marks the Expert-top column and ratio `(overlaps ordinary)` when it is not zero; with overlap the top-vs-ordinary contrast is not measured. A library from a different commit measures a different game; the table's `table.json` records the commit it ran on, not the library's.
- Boss cells enter the boss at the stage's start with the saved ball position, not carried from the exit run; a Warden fight starts from the stage's entrance, so it includes the approach.
- One Learner attempt number per run: the a5 column plays attempt 5 fresh with the band's teaching applied, not five consecutive fights.
- The seed counts decide the interval width; 16 seeds per column gives about plus or minus 20 points near 50%.

## Cost (measured 19 Oct, 4 vCPU, 4 jobs at once, commit 0a70e5c7)

| Job | Game s (median) | Wall s per job |
| --- | --- | --- |
| Library run, full park to stage 6 | 475 to 1402 | 624 to 1429 |
| Boss cell (`brindle`) | 90 | 120 to 360 (93 s on a quiet box; process start is about 40 s of it) |
| Warden cell (`w1`) | 240 (cap) or 207 | 165 to 410 |
| Park cell (`world1`, 2 jobs at once) | 207 to 240 | 129 to 147 |

The default table is now 1,272 jobs (boss 360, Warden 720, park 192: six parks × Novice and Learner a1 × 16 seeds; the dry run counts park jobs under `world`, their kind), about 29 hours at 4 parallel on the loaded numbers; `--cells=world` adds 96 chain jobs; `--dry-run` prints the estimate. Split it with `--shard`. These numbers were taken with the completionist Warden persona, whose w1 runs stalled at the 240 s stage cap before engaging; Warden cells now use the skipper.
