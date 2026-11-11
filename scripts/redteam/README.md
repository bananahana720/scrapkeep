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
| Frame-time spikes | Every run's tick profile (`--bot-profile=1`) with the bot's own cost removed and the audio warmed as a played game warms it (`--warm-band=1`: a headless run has no sound device, so without the flag each radio line and chord renders on the main thread at first use, 70 to 130 ms a tick that play never has; wave 36, PF-33), and the dense-fight bench (`tools/perf_bench.gd`, scene s3) run alone after the pool | Load on a shared box lands at random moments; a hitch the game causes lands at the same run moment for different seeds. A tick over 33 ms at the same moment (within 2 ticks) in two or more runs: major candidate, the bar's repeating hitch. The worst run is then replayed alone, as it was and with `--bot-no-mix=1`, to say whether the moments were load, the game, or the music mix. Other spikes: one watch line. Ticks just after a stage loads are counted apart. Run p99 over 10 ms: watch. |
| Placeholders | `scripts/placeholder-gate.mjs` | One major line with the count by kind. Expected until wave 20; read it as a trend. |
| Skips and getting lost | Each stage's beats (`src/core/stage_beats.gd`) | A stage left with no fight beat, or a first-timer roaming over 90 s before the Warden: watch. |

## The player's-eye pass

Everything above reads the game's numbers. None of it sees the screen, so a build with an invisible objective, a telegraph that does not draw or a briefing nobody can follow passes it. This pass looks. One play of the launched game is filmed as a player's screen shows it, the film is read cold by a reader who has never seen the game, and a judge sets what the reader said beside what the game knew. A place where the two disagree is a finding a player would feel.

```bash
node scripts/redteam/eye.mjs --persona=cautious                       # film, then lay it out
node scripts/redteam/eye.mjs --persona=cautious --plant=objective --death-at=60   # the control
node scripts/redteam/eye.mjs --persona=first-timer --film=whole
node scripts/redteam/eye.mjs --persona=cautious --from=<a film folder from the PC>
```

**The film** (`sketches/core-loop/tools/eye_film.gd`, `tools/self_play.gd --self-play-film`). The bot starts the game with its keys and the game is not told a bot is playing (`--self-play-eyes=1`), so the screens only a player's game shows are on film: the launch take, the briefing's kit pick and start pick, a hotwire offer. Frames are taken at each screen, each held (paused) screen, each objective change, each first key prompt and tip, each offer, each big hit with the two seconds before it (at most 16 a film, at least six seconds apart), each stage clear, each boss phase, the boss going down, each death, and every ten seconds of play. `film.ndjson` holds one row a frame of what the game knew: its state, the objective it had set, hull, and what hit.

| Film | Plays | Length |
| --- | --- | --- |
| `whole` | world 1 start to finish on the fastest line: the dam, the flume, Brindle, the win and the first screen of world 2 | 8.1 game minutes, 23 minutes to film in the cloud, 175 pictures (measured on w33). Give it to two or three readers, about 60 pictures each, cut between two moments and never inside a hit's lead-in: one reader cannot hold that many pictures |
| `wait` (the cautious default) | a player who hangs back in the dam for four minutes, a planted death, the death screen, and the start of a second run | 4.3 game minutes, 16 minutes to film in the cloud (measured on w33; the control with `--death-at=60` took 4 minutes) |

**The reader** gets `reader/`: the pictures renumbered `001.jpg` up and `BRIEF.md`, which holds the persona's card and the questions. Nothing in it says why a frame was taken, what the game knew or how the game works. The reader is a fresh agent that reads only that folder; never the thread that filmed, and never one that has read the code or the design. It answers per picture: what is on the screen, what it thinks it is meant to do, words it does not understand, and what it cannot see or read. For each hit and death it is asked what the earlier pictures told it was coming.

| Persona | Who reads |
| --- | --- |
| first-timer | has never seen the game; gives up on what it cannot work out in a few seconds |
| cautious | reads every word, hangs back, hates being hit by what it could not see and words that leave too soon |
| speedrunner | resents every screen that holds it and every second in which nothing is asked |
| greedy | wants to know exactly what every offer gives and costs |

**The judge** fills `judge/SHEET.md`, which lists each picture beside the game's own row. Findings come from disagreement: the reader thought it was meant to do one thing and the objective said another; the reader could not say what hit it and the row names the source; the reader quotes a word it does not know; the reader reports nothing where the game was showing something.

**The control.** A clean read is evidence only if a planted fault is caught the same way. Each pass films one control with `--plant=objective` (the objective plate is not drawn; the play watch still sees its words, so the bots pass it) and gives it to a second reader, who is not told anything is planted. The control is caught when that reader cannot say what they are meant to do on the pictures where the game had set an objective and the clean film's reader could. A control that reads the same as the clean film voids the pass.

Give each reader a copy of `reader/` at a path that says nothing (the film folder's own name can name the plant), and save its reply unedited beside the film as `READ.md`. The wait film's death is planted to reach the death screen, so a reader's complaint that it was killed by something it never saw is the plant and not a finding.

**What a cloud film can and cannot say.** The cloud draws with a software renderer. Words, layout, marks, what is on screen and when all read true. Colour, light, bloom and frame pacing do not; the film draws only the frames it keeps, so GPU particles are under-shown, a picture-in-picture panel (a boss's entrance) is black in its first picture, and it is never a frame-time reading; the renderer also caps per-instance shader values at 4,096 objects and logs an error past that, which a GPU does not. For look, the PC lane films a first-timer's run once a wave (ruling cp): `node scripts/redteam/eye.mjs --persona=first-timer --gpu` uses the machine's own display and renderer and draws every frame, and its brief asks the reader to judge the look as well. `--from` lays out a film made elsewhere (add `--look` when it is a PC film). Sound is not read at all.

## The receipt

A hand-written receipt opens with two verdicts, not one:

1. **Promotion:** new blockers against the base, as now. Base-same findings do not hold a promotion.
2. **Player read:** how many things a player would feel on this build, whatever wave they came from. Base-same is a fact about the code's history; the player meets the fault either way.

Each finding leads with one plain sentence of what the player sees or feels, then the picture numbers or the replay command, the bug-bar grade and area, and the thread that owns the fix. Ticks, seeds and file names go after that sentence, never in place of it. The receipt ends with what the pass could not see.

Every player-read finding then gets a row in [PLAY-FINDINGS.tsv](../../project-guide/handoff/PLAY-FINDINGS.tsv): what the player meets, where it was seen, a grade, an owner and a review date (ruling cn). A finding never holds a promotion; the list is how one stops being forgotten. A finding the cloud film cannot settle (colour, light, effects, the camera) is graded `check` until the wave's PC film has decided it (ruling cp). The pull request that fixes a finding removes its row. The next film of the stage then checks the fix where the player meets it: a fresh reader reads the film, and a fix that does not read on screen gets its row back, rewritten with what that reader saw. `node scripts/redteam/findings.mjs --check` reads the list's shape, `--print` lists it by owner and `--overdue` names the rows past their date.

## The findings page

One page, worst first, graded on the bug bar's severities (blocker, major, minor) and its 11 areas, plus a watch list for taste and tuning calls that are not bugs. One line per root cause, however many runs hit it:

```
1. **BLOCKER** · Wardens and bosses · The boss fight never ends (boss, remembered_cannon) (candidate, replay to confirm)
   You are in the boss fight and nothing you do finishes it.
   Seen in 2: remembered_cannon seed 2507 as speedrunner: boss_stalled; ...
   Replay: `$GODOT_BIN --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/bot_run.gd -- ...`
```

The second line says what Andrew would feel at his sitting. Below the list: a table of every run (persona, pilot, seed, outcome, stage reached, hits and pile-ups, tick p99), the fuzz and placeholder counts, and what the pass cannot see.

Each blocker and major becomes a card for the wave coordinator, as the bug bar says. The page goes to Andrew as a phone-friendly Artifact; taste calls go to the coordinator as decision-card text.

## Limits

Bots are automated play: they find numbers, stalls and crashes, not feel. Everything but the player's-eye pass runs headless, so there is no GPU or picture: a hitch here is main-thread time on a shared 4-core box, to be checked with MangoHud (`scripts/frametime-check.mjs`) on Andrew's PC. Bot runs use the source tree, not the exported pack; the export step proves the build exports and boots. Andrew's sitting decides feel.
