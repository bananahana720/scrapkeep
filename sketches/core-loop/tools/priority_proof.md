# Priority proof

Asks one question per kill-first special (design-v3/ENEMY-PRIORITY.md section 4; alpha-status ambition map, unit 7): does a player who kills the special first lose less hull than one who leaves it for last? The target: the ignore arm loses at least 1.25 times the hull the target arm loses, over 8 paired seeds. It feeds the wave 18 matchup lab.

Automated; not a feel verdict.

## Run it

From the repository root (Godot 4.7.2, headless, assets imported):

```
$GODOT_BIN --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/priority_proof.gd -- --out=$PWD/artifacts/local/priority_proof/run.json
```

`--out` is an absolute path under `artifacts/local/`. The parent keeps `--procs` child processes going, one run each, prints a table and writes the JSON report.

| Option | Default | Meaning |
| --- | --- | --- |
| `--procs=N` | 4 | child processes, 1 to 8 |
| `--seeds=1,...,8` | 1 to 8 | paired seeds; the pilot is seed mod 6, as in `bot_run.gd` |
| `--cap=120` | 120 | encounter seconds before a run counts as not cleared |
| `--dodge=0.65` | 0.65 | share of telegraphs the bot answers (below) |
| `--hp-mult=1` | 1 | every spawned body's health times this: a stand-in for a later, tougher pack |
| `--spawn-every=<s>` | the row's | overrides a model's drop cadence |
| `--start-mass=0` | 0 | the ball's opening mass (heft 1) |
| `--specials=a,b` | all | names from `SPECIALS` |

48 runs (three playable rows) took about 7 minutes at four processes in a 4 vCPU cloud container.

## The encounter

A calm stage 1 (no Warden, no director packs). Once the ball has been on the ground for a second, six crew spawn in a 22 m arc ahead of it (the attacker budget's opening six, PR #15) and the special 12 m behind them. The bot is the stock `BotDriver` with one change, which enemy it fights:

| Arm | Picks |
| --- | --- |
| target | the special while it lives, then the nearest crew |
| ignore | the nearest crew while any stands, then the special |

Both arms end on the same clear (everything down) or the cap, so clear time compares too. Bolts and rams hit whatever they hit; "ignore" is about where the bot goes.

**Dodging.** The stock bot answers every telegraph it has seen for 0.25 s and rams constantly, so stage 1 attacks rarely land: in trials at `--dodge=1` neither arm lost any hull. `--dodge` makes it miss a share, each telegraph decided once from the seed, as a player who misses about a third. Hull lost below 5 on the ignore arm reads "too little damage", not a ratio.

## The rows

`SPECIALS` in the tool, one line each. `mode` is read at run time:

- **built**: the roster has the id and its script exists, so it spawns through `combat.spawn_enemy`.
- **model**: the enemy does not exist yet, but the row carries the design's start values. A lab-only stand-in plays them on a non-attacking body (a vault with plating 0 and 120 health): the Foreman wipes its crew's plating shred every 5 s; the Dispatcher drops a chaser every 8 s while fewer than six stand. A model is a read on the design numbers, never proof the built enemy works.
- **not built**: neither; no runs, and the report says so.
- **control**: a current pack controller (the mag trapper) as the special, the instrument's positive control.

When the machine lands an enemy, check its row's `id` matches the roster id; the row then plays as built and its model values are ignored.

## Results

### 2026-10-17, origin/main cf63e622, cloud container (4 vCPU, headless), defaults plus `--hp-mult=3`

Mean hull lost and clear seconds over 8 paired seeds; every run cleared.

| Special | Mode | hp x | Target hull / clear | Ignore hull / clear | Ratio | Ignore worse | Verdict |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Foreman | model | 1 | 3.3 / 13.2 s | 12.0 / 14.3 s | 3.64 | 6 of 8 | pass |
| Foreman | model | 3 | 10.6 / 22.7 s | 20.8 / 26.8 s | 1.96 | 6 of 8 | pass |
| Dispatcher | model | 1 | 0.0 / 6.8 s | 0.5 / 7.8 s | - | 1 of 8 | too little damage |
| Dispatcher | model | 3 | 6.3 / 11.8 s | 3.9 / 17.8 s | 0.62 | 3 of 8 | too little damage (would miss) |
| Dispatcher, 4 s drops | model | 3 | 6.3 / 11.9 s | 3.9 / 17.9 s | 0.62 | 3 of 8 | too little damage (would miss) |
| Splitter | not built | | | | | | not built |
| Linker | not built | | | | | | not built |
| Mag trapper (control) | built | 1 | 0.0 / 8.6 s | 0.2 / 11.3 s | - | 1 of 8 | too little damage |
| Mag trapper (control) | built | 3 | 1.5 / 13.6 s | 2.3 / 16.0 s | 1.53 | 4 of 8 | too little damage |

What it says:

- No special exists in the game yet; all four rows above are models or not built. The Foreman and the Dispatcher read on the design's start values only.
- The Foreman's shred wipe makes order matter: ignoring it costs 2 to 3.6 times the hull.
- The Dispatcher does not: its chasers die before they land a hit (twice the drops, 4 s apart, changed no hull), and the target arm pays for diving through the crew to reach a Dispatcher on the ground. Ignoring it costs about 6 s of clear time, not hull. The design's 6 to 10 m perch and a stream that threatens on its own are what would change that; re-run once both exist.
- The control misses too: at stage 1 numbers a six-strong pack barely touches the stock bot, so a controller's hold has nothing to set up. Priority matters only where packs can hurt; this is a lab limit and a finding about stage 1 pressure, not about the specials.

### 2026-10-17, the Foreman built (branch claude/project-thread-qpwany: cf63e622 plus PR #15, PR #44 and PR #54), cloud container (4 vCPU, headless), `--specials=foreman`, hp x 1 and 3

The Foreman claims the six crew in reach, wipes their plating shred every 5 s (the horn one beat before) and never attacks; killed first, the standing crew clocks out for 1.5 s. Its health is the model's 120 x threat. The table now also reports the median of the paired seeds' own ratios, so a mean carried by one seed shows.

| Seeds | hp x | Target hull / clear | Ignore hull / clear | Ratio | Median seed ratio | Ignore worse | Verdict |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 to 8 | 1 | 5.5 / 13.6 s | 11.5 / 13.3 s | 2.09 | inf | 7 of 8 | pass |
| 1 to 8 | 3 | 9.0 / 22.6 s | 16.9 / 28.4 s | 1.88 | 1.33 | 5 of 8 | pass |
| 1 to 16 | 1 | 5.6 / 13.3 s | 8.3 / 14.1 s | 1.48 | 3.9 | 10 of 16 | pass |
| 1 to 16 | 3 | 9.8 / 23.0 s | 13.5 / 28.0 s | 1.38 | 1.62 | 10 of 16 | pass |

What it says:

- Ignoring the Foreman costs more on most seeds, not one: at hp x3 over 16 seeds the median ignore run lost 11.1 hull against the target run's 5.2, and dropping the worst ignore seed still leaves ignore ahead (11.3 against 9.8). An "inf" median means most target runs lost no hull at all.
- It costs time too: at hp x3 the ignore arm clears 5 s later, through 3 to 8 wipes a run.
- The built Foreman reads lower than the model did (1.38 to 2.09 against 1.96 to 3.64): the target arm now walks through a crew to reach a body that stands its ground, and ignoring it is cheaper at 16 seeds than at 8. A pass, with less margin than the model promised.
- Seeds 3, 11, 14 and 16 go the wrong way at hp x3; in each the target arm took its hits diving through the crew. The wipe only bites on plated crew (the two brutes here), so a Foreman's pack needs plating to matter.
