# Challenge band table

The challenge lane says every boss and Warden should beat a Novice, give a Learner a fair fight and fall to an Expert, and that a park should be reachable by a Learner and often not by a Novice. This harness measures that. It plays each boss, each Warden and each park's approach to its own Warden with the Novice, Learner and Expert bot bands from saved builds, grades the win rates against the targets, and prints one table.

It changes nothing in the game and is not the gate. The bands (what a Novice, Learner and Expert bot do differently: reaction, aim, dodging, how the attempt number teaches) live in `sketches/core-loop/tools/skill_band.gd` and are read by `tools/bot_run.gd` as `--band=novice|learner|expert` and `--attempt=N`. This harness only chooses builds, seeds and cells and counts.

## The targets

From the coordinator ruling, `project-guide/handoff/DECISIONS.md` section 5, 19 Oct 01:58 (encoded in `lib.mjs` as `TARGETS`):

> Base-tier targets with an ordinary build: bosses and Wardens beat Novice in at least 85% of attempts; Learner wins 15-35% on a first attempt and 60% or more by the fifth; Expert wins 85% or more; a top-decile (cracked) build with an Expert wins 97% or more and keeps the existing growth ratios. Every lethal attack has a readable tell of at least 0.6 s, and no boss kills a Learner in its first 45 s. Parks: Novice reaches the world's Warden in at most half its runs, Learner in 80% or more.

| Column | Cell | Target |
| --- | --- | --- |
| Novice | boss, Warden | win at most 15% |
| Learner a1 | boss, Warden | information only, no mark (DECISIONS section 5, 19 Oct 19:00, replaced the graded 15% to 35%); the old range is printed for reading |
| Learner a5 | boss, Warden | win at least 60% on attempt 5 |
| Expert ordinary | boss, Warden | win at least 85% |
| Expert top | boss, Warden | win at least 97%; the fight-time ratio top/ordinary is shown for the growth-ratio check |
| Learner deaths (a1 and a5) | boss | no death before 45 s of boss time |
| Novice, Learner a1 | park | reach the park's Warden: Novice at most 50%, Learner at least 80% |

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
| `w1clear` | whole World 1, only with `--only=w1clear` | One fresh run of the dam, the flume and Admiral Brindle in one attempt (`--until=2`, which ends when stage 3 opens after Brindle falls; no `--to-boss`, which would enter Brindle on the first tick; Warden and stage caps as `w1`), Novice, Learner a1, Learner a5 and Expert, 16 seeds. `--only=w1clear` alone selects it; `--cells=clear` selects nothing, and it is not part of `--only=w1` (the stage 1 Warden) or the default cells. Its seeds are `w1`'s (40300 up), so stage 1 pairs seed for seed. One run has one persona: the Warden persona (skipper), through Brindle too, so its Brindle leg is not comparable with the `brindle` cell (brawler). Win is Brindle defeated; the table says where each run ended (`s1`, `s2` or `boss`) and whether it died, capped or cleared, with game seconds. About 300 s of wall per job. Information only. |

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
| `--jobs=<n>` | 4 | Godot processes at once (at most one a core and 2 GiB of memory each, and never less than 6: 6 on the 4-vCPU cloud box, more on the PC). Band sweeps can run out of memory; a job that times out or is killed is rerun once alone before it counts. |
| `--early-stop` | off | Ruling dg: before a job starts, its column is checked, and once the seeds left cannot change the column's ✓/✗ (every way they could end, each a win or not, gives the mark the finished seeds give), the rest of that column is skipped. Columns with no target, a column over the excluded share, and a boss's Learner columns while the 45 s tell is clean run every seed. `table.md` gains a "Stopped early" list with how many of each column's planned seeds ran; `table.json` carries it as `early_stop`. Replayed over 89 finished PC band reads (waves 20 to 33, 6 jobs at once): 11% of jobs skipped, every column mark the same as the full read. The gate's band steps compare head and base run by run, so they do not pass it. |
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

- Bots, not people. The bands model reaction and skill with parameters; a win rate here says how the bands fare, and Andrew's sitting decides whether a Learner feels like one. Whether a hit had a telegraph up for the tell time is measured (F1 below); whether a person reads it in that time is not, and stays a design and Andrew-sitting check.
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

# Anti-kiting gates (card G-A)

`npm run challenge:gates` (`scripts/challenge/gates.mjs`, rules in `gates-lib.mjs`) runs the Challenge lane's three anti-kiting gates with their controls. The rules are fixed in scrapkeep#241 comment 6367573974, written before any run; no threshold here is tuned. Gate 3 (on-beat against off-beat) is card G-B.

| Gate | Real arm | PASS | Positive control (must PASS) | Held-out negative (must FAIL) |
| --- | --- | --- | --- | --- |
| 1 circling loses | `orbit`: circles a fixed anchor at cruise (at first contact, the nearest point to the live pack's centroid within 30 m whose 14 ± 3 m band rises under 3 m; never re-anchored) | on every stage all runs end `died` and the median death is within 120 s of the first hit | `orbit` with `--plant=rut=1` (a stand-in rut meter: 5% of max hull a second while the ball has travelled under 36 m net in 10 s; pack damage ×4 never killed the circling arm) | `orbit` with `--plant=packs_passive=1` |
| 2 terrain beats circling | `terrain` against `orbit`, hull lost per minute alive in the 120 s after first contact | over the contested pairs (both arms lost different hull; at least 10 needed), terrain lower in 80% and the pooled median of terrain / orbit at 0.75 or less | `orbit` against `orbit` with `--plant=damage=2` on arm B: A must be named the winner | `orbit` against a second `orbit` sample (A/A) |
| 4 sight-only clears | `deaf`: the Expert default driver (`skipper`, `--band=expert`) with `--bot-no-mix=1` | PARKED: clear rate 85% or more on every stage | the same runs (today's stage) | `--plant=hide_pack_telegraphs=1` |

If a control reads wrong, the gate is broken: the report prints `BROKEN` and withholds the real reading.

Rulings after the first sweep (24 Oct, scrapkeep#241 comment 6378906601). Gate 2 scores contested pairs only: most windows lose no hull, so 0 against 0 pairs made the old 24-of-30 count unreachable and said nothing about either arm. A pair where only one arm lost hull is the worst ratio for that arm, not dropped. Gate 4's absolute 85% check is parked until packs threaten: Expert cleared as well with telegraphs hidden, so the check cannot show that it reads them. Re-run it then as paired telegraph-on against hidden.

Measuring a game variant (the pack pressure experiments): put the variant behind a `ChallengeDials` key (`src/core/challenge_dials.gd`, default = today's game) and pass it with `--tune`, which every arm receives. A quick world 1 read of the real arms, about 60 jobs:

```
node scripts/challenge/gates.mjs --gates=1,2 --only=orbit,terrain --stages=1,2 --tune=<key>=<value> --label=<variant>-quick
```

The controls do not run, so the reading prints `BROKEN`; read the real rows (gate 1 deaths, gate 2 contested pairs and ratio) against the same command without `--tune`. `--stage-limit=300` cuts each run from 600 s to 300 s for a quick read only: a death more than 120 s after a late first hit can fall past it, so a gate 1 reading of record keeps 600. A full read drops `--only` (540 jobs over 6 arms; split with `--shard=i/n` and join with `--merge`). In a fresh worktree, import once first: `"$GODOT_BIN" --headless --path sketches/core-loop --import`.

Every arm plays stages 1 to 6, each entered fresh (`--from-stage=N --until=N`), seeds 1 to 5 and 3 runs a seed at `--fixed-fps 90`: 8 arms of 90 runs, 720 jobs (`--dry-run` counts them). The pilot is `seed % 6`, as in the band table. The three runs of a seed are the same seed run three times (ruling 6356590453, to expose run-to-run splits), told apart by the repeat index in the job id and out dir. The A/A arm `orbit_b` runs the same seeds as `orbit`, so on identical seeds it must tie and read FAIL. Each run saves `jobs/<id>/cmd.txt`. `--resume`, `--shard=i/n`, `--merge=<dir,dir>`, `--label` and `--jobs` work as in `challenge:bands`; `--gates=1,2,4` and `--only=<arm,arm>` choose arms, `--stages` and `--seeds` shrink the plan.

Instrument checks (a run that fails one is void, listed in the report and left out of the medians): an `orbit` run must spend 80% or more of its window circling (within 3 m of the 14 m ring around its fixed anchor; the window runs from first contact to 120 s or death, `alive_120s`); a `terrain` run must ride a line at least once per 30 s of that window, and a stage with no line within reach says so (`lines_in_reach` 0) and is void; gate 4 also needs `tools/bot_driver.gd` to read no audio or beat state (a static scan, also a unit test). A seed with fewer than 2 valid runs of 3 is void, and a gate with a void seed reads `VOID`, not `PASS`.

Choices the comment left open (each is a parameter in `gates-lib.mjs`): a seed's value is the median of its valid runs; gate 1's stage value is the median of its seeds' medians; gate 2's pooled median is over the per-pair ratios, and a pair with equal loss in both arms is a tie that neither arm wins; gate 4's rate is over runs (13 of 15 passes), and a stage with over 10% of its runs void is incomplete.

The policies are `orbit` and `terrain` in `tools/bot_kite.gd` (`--policy=orbit|terrain`); the plants are `tools/bot_plants.gd` (`--plant=name=value[,...]`): test-only, the tool layer only, and absent means no plant object exists. The stage note gains `first_contact_s` (the first tick a live enemy is within 30 m of the ball; a hit with none that close also opens it), `first_hit_s`, `hull_lost_120s`, `alive_120s`, `fight_s` (seconds the nearest enemy was within 30 m), `circle_s`, `circle_share` (`circle_s` / `alive_120s`), `line_rides`, `lines_in_reach`, `line_misses` and `telegraph_reads`; the dodge count is the existing `evasions`.

## Fairness numbers (wave 36)

Every run's record (`bots.ndjson` row, `runs.ndjson` `row.fairness`) carries the parts of the three numbers wave 37's difficulty changes are judged by (`project-guide/handoff/shared/world1/difficulty-plan.md`, rows F1 to F3). The pass lines, the tell time and the source lists are in [`fairness.json`](fairness.json), read by `lib.mjs` and by `tools/bot_fairness.gd`; change them there only. The recorder (`tools/bot_fairness.gd`) reads what the simulation publishes and steers nothing. `table.md` prints one line per cell and arm, never pooled across cells or across arms, with the runs behind it; runs graded error or unresumed are left out, as in the win table. `table.json` has the same as `fairness`. A number no run measured reads "not measured", never 0. The fairness marks are summed on their own line ("Fairness lines with a ✗"), apart from the win-rate sentence.

- **F1 telegraph share.** Each hit's hull goes to one bucket by the hit's own source, in this order: untelegraphed if the source is a plant; contact if it is on `contactSources` (printed beside F1, outside its share, since the ruling wants hardness from ramming); telegraphed or untelegraphed if it has a telegraph owner (a boss attack on `bossAttacks`, an `unownedSources` name, a kind seen publishing a telegraph this run, or a `TelegraphRecord` row), by whether a telegraph of its own covered the ball for the tell time or more; unknown otherwise. F1 = telegraphed over telegraphed plus untelegraphed. F1 carries no mark while unknown is over `unknownMaxShare` of hull, so a new hit source nobody listed cannot hide.
  - A source belongs on `contactSources` only when its hit is a body contact or ram that by design has no telegraph, and you have checked that the game sends it under that name; today none does (every enemy hit arrives under the enemy's kind).
  - A boss hit is matched only to hazards of the attack that landed: `bossAttacks` maps the hit's source (`brindle_slag`, `brindle_charge`) to the `attack_id` prefixes of its hazards (`slag_ring_`, `charge`). A boss source not on that map reads unknown; the Waking and the Mind are not on it because the recorder does not read their hazards yet.
  - Hit sources carry only the enemy kind, so machines of one kind share one owner: a chaser hit under another chaser's old lane reads telegraphed. A telegraph's age is how long it has stood, so a lane entered late is judged on the lane's age as it is now. Every published telegraph is read, including amber ones and rings wider than the steering's field radius.
- **F2 stop tax.** Hull per second of time below cruise speed over hull per second at or above it (planar ball speed against the pilot's `cruise`). The time counts every physics tick the run is in a stage or the boss fight with the ball alive, grounded or not, and all hull, contact included. The share of time at cruise prints beside the ratio, so a bot that barely cruises shows.
- **F3 first hit.** One reading per stage and for the boss fight: seconds from first contact with a pack (a live enemy within 30 m) to the first hit. A stage with no hit is the best case and reads as later than any, so it can move the median; the line prints how many took no hit. A hit that itself opens contact, with no enemy in range, is counted apart ("opened by a hit"), not read as 0 s.

`tests/bot_fairness_test.gd` classifies hand-made fixtures, then plays one seed unplanted and once per plant (`drain=K`, `fast_tax=K`, `ringless=K` in `tools/bot_plants.gd`; `rut=K` is the same untelegraphed drain only on a circling ball): unplanted every number is measured and passes, each plant moves its own number under the line and leaves the other two within a stated tolerance. It is on the weekly list; run it by hand after any change under `tools/bot_*`. The gate's run comparison (`scripts/gate/pc.mjs`) ignores the `fairness` key: it is a measurement, not an outcome.
