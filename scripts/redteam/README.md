# Red team

The project rules say a red team plays every wave's build. This is that pass. It plays the real game headless with bot pilots, rotates who plays and on which seeds every wave, runs the attack tools, and writes one page of findings ranked on the [alpha bug bar](../../sketches/core-loop/BUG-BAR.md).

It runs in a cloud container (4 cores, no GPU) or on Andrew's machine. It changes nothing in the game and is not the gate: the full gate stays on Andrew's machine.

## Run it

```bash
npm run redteam -- --wave=16                 # full pass: about an hour on 4 cores
npm run redteam -- --wave=16 --quick         # harness check: stage 1 only, about 10 minutes
npm run redteam -- --wave=17 --carry=artifacts/local/redteam/w16-<stamp>/findings.json
```

| Option | Default | What it does |
| --- | --- | --- |
| `--wave=<n>` | required | Picks the seeds and the persona and pilot pairs. |
| `--runs=<n>` | 10 (5 quick) | Bot runs this pass. |
| `--slots=<n>` | 4 | Processes at once. |
| `--carry=<findings.json>` | none | Replays the last pass's blockers and majors (up to four) on their own seeds, to show whether they still happen. |
| `--quick` | off | Stops every run after stage 1, shortens the item fuzz, skips the dense-fight bench. |
| `--no-export` | export on | Skips the cloud export and headless boot. |
| `--persona=<id>` | off | A head pass: one persona on all six pilots, on six seeds that stay the same for every head in the wave, plus 6 fuzz seeds. Meant to run on every staging head; the full pass or sweep runs at wave close. |
| `--sweep` | off | A wider pass for spare compute: 60 runs (every persona and pilot pair twice) and 40 fuzz seeds, on its own seed block (20000 + 1000 per wave), so it never repeats a regular pass. About 3 hours on 4 cores. |

**Splitting a sweep across sandboxes.** Each sandbox has 4 cores and a 2-hour cap on background jobs. Give each one its own `--block=<0-4>` (its own seeds) and `--runs=30` (every pair once, about 90 minutes), then join the passes into one page with `node scripts/redteam/merge.mjs --out=<dir> <findings.json>...`.

`GODOT_BIN` must name the Godot 4.7.2 editor; the cloud SessionStart hook sets it. Output goes to `artifacts/local/redteam/w<wave>-<stamp>/`: `findings.md` (the page), `findings.json` (the same, plus the carry list for the next wave) and `jobs/` (every log, `bots.ndjson`, `runs.ndjson`, event audit and tick profile).

## Who plays

Each persona is a bot policy (`tools/bot_driver.gd`) played for a reason.

| Persona | Policy | Length | Hunts |
| --- | --- | --- | --- |
| speedrunner | skipper | whole run | stalls, softlocks and route skips on the fastest line |
| first-timer | random | whole run | getting lost, crowd deaths, odd choices |
| cautious | camper | 3 stages | stalls after a Warden breaks, from a player who never closes in |
| greedy | completionist, takes late offers | whole run | degenerate builds, long-run stability |
| line-rider | traversal | 90 s on one stage the seed picks | spots the ball gets stuck on the way to the Warden; it never fights, so its stalls do not count |

**Rotation.** Five personas and six pilots make 30 pairs. Wave `w` takes the next 10 pairs in a fixed walk, so every persona plays twice a wave and the whole grid turns over every three waves. Seeds come from a block each wave owns (`1000 + 100w` up), which no gate test uses, so every wave tries new runs.

## Attack playbooks

| Playbook | How | What becomes a finding |
| --- | --- | --- |
| Crashes | Every process's exit, timeout and log; the cloud export and two headless boots | Crash, freeze or no run record: blocker. `SCRIPT ERROR`: major. Engine `ERROR`: minor. Export or boot failure: blocker. |
| Stuck geometry | Each stage's `stuck_detours` | Three or more on one stage: minor (stage and world design). |
| Stalls and softlocks | Bot outcomes `stalled`, `boss_stalled`, `fight_capped`, `boss` | Skipper or completionist stall, any boss stall, or a missing boss: blocker candidate. Other personas: major candidate. A camper stall with no Warden broken is its design, not a finding. A stall is a candidate until its replay command reproduces it, as the cannon-lane bug on Brindle did. |
| Degenerate builds | Item fuzz (20 seeds, 60 s each, `tools/item_fuzz.gd`), build sweep stack and compose arms with the wave's seed, Warden fights under 2 s | A broken invariant (non-finite numbers, caps, cooldowns, leaks): major. An outlier or one-shot Warden: watch, for Andrew's keep or kill. |
| Unreadable crowd moments | The event audit of every run (`--bot-audit=1`): three or more hits from two or more sources inside 1 s, adding up to 35% of max HP | A death within 3 s of one: major (clarity). Without a death: minor, major once three runs see it on the same stage. |
| Frame-time spikes | Every run's tick profile (`--bot-profile=1`) with the bot's own cost removed, and the dense-fight bench (`tools/perf_bench.gd`, scene s3) run alone after the pool | Load on a shared box lands at random moments; a hitch the game causes lands at the same run moment for different seeds. A tick over 33 ms at the same moment (within 2 ticks) in two or more runs: major candidate, the bar's repeating hitch. The worst run is then replayed alone, as it was and with `--bot-no-mix=1`, to say whether the moments were load, the game, or the music mix. Other spikes: one watch line. Ticks just after a stage loads are counted apart. Run p99 over 10 ms: watch. |
| Placeholders | `scripts/placeholder-gate.mjs` | One major line with the count by kind. Expected until wave 20; read it as a trend. |
| Skips and getting lost | Each stage's beats (`src/core/stage_beats.gd`) | A stage left with no fight beat, or a first-timer roaming over 90 s before the Warden: watch. |

## The findings page

One page, worst first, graded on the bug bar's severities (blocker, major, minor) and its 11 areas, plus a watch list for taste and tuning calls that are not bugs. One line per root cause, however many runs hit it:

```
1. **BLOCKER** · Wardens and bosses · The boss fight never ends (boss, remembered_cannon) (candidate, replay to confirm)
   You are in the boss fight and nothing you do finishes it.
   Seen in 2: remembered_cannon seed 2507 as speedrunner: boss_stalled; ...
   Replay: `$GODOT_BIN --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/bot_run.gd -- ...`
```

The second line says what Andrew would feel at his sitting. Below the list: a table of every run (persona, pilot, seed, outcome, stage reached, hits and pile-ups, tick p99), the fuzz and placeholder counts, and what the pass cannot see.

Each blocker and major becomes a card for the wave coordinator, as the bug bar says. The page goes to Andrew as a phone-friendly Artifact; taste calls go to the project coordinator as decision-card text.

## Limits

Bots are automated play: they find numbers, stalls and crashes, not feel. Everything runs headless, so there is no GPU or picture: a hitch here is main-thread time on a shared 4-core box, to be checked with MangoHud (`scripts/frametime-check.mjs`) on Andrew's PC. Bot runs use the source tree, not the exported pack; the export step proves the build exports and boots. Andrew's sitting decides feel.
