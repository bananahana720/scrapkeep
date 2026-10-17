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

48 runs (three playable rows, before the Splitter was built) took about 7 minutes at four processes in a 4 vCPU cloud container.

## The encounter

A calm stage 1 (no Warden, no director packs). Once the ball has been on the ground for a second, six crew spawn in a 22 m arc ahead of it (the attacker budget's opening six, PR #15) and the special 12 m behind them. The bot is the stock `BotDriver` with one change, which enemy it fights:

| Arm | Picks |
| --- | --- |
| target | the special while it lives, then the nearest crew |
| ignore | the nearest crew while any stands, then the special |

Both arms end on the same clear (everything down, and nothing still to come) or the cap, so clear time compares too. Bolts and rams hit whatever they hit; "ignore" is about where the bot goes. Anything the encounter makes after it starts (a Dispatcher's drop, a Splitter's budded or popped pods) joins the crew, toughened by `--hp-mult` like the rest, and a Splitter's seam flare that has not popped yet keeps the fight open. Each run records `joined` (later spawns) and `special_split`.

**Dodging.** The stock bot answers every telegraph it has seen for 0.25 s and rams constantly, so stage 1 attacks rarely land: in trials at `--dodge=1` neither arm lost any hull. `--dodge` makes it miss a share, each telegraph decided once from the seed, as a player who misses about a third. Hull lost below 5 on the ignore arm reads "too little damage", not a ratio.

## The rows

`SPECIALS` in the tool, one line each. `mode` is read at run time:

- **built**: the roster has the id and its script exists, so it spawns through `combat.spawn_enemy`.
- **model**: the enemy does not exist yet, but the row carries the design's start values. A lab-only stand-in plays them on a non-attacking body (a vault with plating 0 and 120 health): the Foreman wipes its crew's plating shred every 5 s; the Dispatcher drops a chaser every 8 s while fewer than six stand. A model is a read on the design numbers, never proof the built enemy works.
- **not built**: neither; no runs, and the report says so.
- **control**: a current pack controller (the mag trapper) as the special, the instrument's positive control.

When the machine lands an enemy, check its row's `id` matches the roster id; the row then plays as built and its model values are ignored.

## Results

### 2026-10-17, origin/main cf63e622, cloud container (4 vCPU, headless), defaults and `--hp-mult=3` (hp x column)

Mean hull lost and clear seconds over 8 paired seeds; every run cleared.

| Special | Mode | hp x | Target hull / clear | Ignore hull / clear | Ratio | Ignore worse | Verdict |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Foreman | model | 1 | 3.3 / 13.2 s | 12.0 / 14.3 s | 3.64 | 6 of 8 | pass |
| Foreman | model | 3 | 10.6 / 22.7 s | 20.8 / 26.8 s | 1.96 | 6 of 8 | pass |
| Dispatcher | model | 1 | 0.0 / 6.8 s | 0.5 / 7.8 s | - | 1 of 8 | too little damage |
| Dispatcher | model | 3 | 6.3 / 11.8 s | 3.9 / 17.8 s | 0.62 | 3 of 8 | too little damage (would miss) |
| Dispatcher, 4 s drops | model | 3 | 6.3 / 11.9 s | 3.9 / 17.9 s | 0.62 | 3 of 8 | too little damage (would miss) |
| Splitter | not built | | | | | | not built (built since; see below) |
| Linker | not built | | | | | | not built |
| Mag trapper (control) | built | 1 | 0.0 / 8.6 s | 0.2 / 11.3 s | - | 1 of 8 | too little damage |
| Mag trapper (control) | built | 3 | 1.5 / 13.6 s | 2.3 / 16.0 s | 1.53 | 4 of 8 | too little damage |

What it says:

- No special exists in the game yet; all four rows above are models or not built. The Foreman and the Dispatcher read on the design's start values only.
- The Foreman's shred wipe makes order matter: ignoring it costs 2 to 3.6 times the hull.
- The Dispatcher does not: its chasers die before they land a hit (twice the drops, 4 s apart, changed no hull), and the target arm pays for diving through the crew to reach a Dispatcher on the ground. Ignoring it costs about 6 s of clear time, not hull. The design's 6 to 10 m perch and a stream that threatens on its own are what would change that; re-run once both exist.
- The control misses too: at stage 1 numbers a six-strong pack barely touches the stock bot, so a controller's hold has nothing to set up. Priority matters only where packs can hurt; this is a lab limit and a finding about stage 1 pressure, not about the specials.

### 2026-10-17, the Splitter built as the mama (branch claude/splitter-3mgbv8 on cf63e622 plus PR #54 and PR #24), cloud container (4 vCPU, headless), `--specials=splitter`, hp x 1 and 3

The Splitter chases the ball and buds a fuse pod every 4.5 s (three at most); each pod chases, lights a 1 s ring and blows up. A ram pops the Splitter into three more pods.

| Special | Mode | hp x | Target hull / clear | Ignore hull / clear | Ratio | Ignore worse | Verdict |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Splitter | built | 1 | 0.5 / 9.1 s | 1.4 / 9.2 s | 2.8 | 3 of 8 | too little damage |
| Splitter | built | 3 | 0.1 / 15.7 s | 8.3 / 19.2 s | 83.0 | 3 of 8 | pass |

What it says:

- Leaving the Splitter alive means more pods: the ignore arm met 5 later spawns a run against the target arm's 3, killed the Splitter at 10 s instead of 5 s, and cleared 3.5 s later at hp x3.
- The pass is thin. Its hull mean rides one seed (seed 3 lost 53 hull to pods fusing on a ball pinned by the crew); the median ignore run lost no hull, and only 3 of 8 seeds went the right way. At stage 1 numbers the ignore arm stays under 5 hull, the lab limit the control shows too.
- The stock bot rams, so it split the Splitter in 14 of 16 runs at hp x3. The proof measures kill order, not the clean-kill answer; the matchup lab (lever 7) is where "from above or from range" gets measured.
