# Break it: world 1 (systems audit pass F)

**Result.** Twenty-one bot runs tried to break world 1 on the park maps, and none of them broke it. They mashed every key, quit and continued in every flow state, and stacked a full build with a curse and low hull. No run crashed, logged a script error, soft-locked, made a number escape or lost a save. One finding is high enough to fix. If the player quits after the dam Warden breaks but before the launch lands, Continue replays the whole cleared stage (F1). The fix belongs in `flow.gd`, which the wave 37 board thread holds, so it goes there with its replay command. Three smaller findings are backlog rows. The bots' input mash cannot finish the dam Warden's spillway-sheet fight, but that is a weakness of the bot's hands, not of the game.

**Card.** SA-F in [BACKLOG.md](../../../BACKLOG.md#sa-f-break-it-world-1). It was read at `stage/alpha-w37` 5268fe06 and written at bcccc24f. The runs used the 4-core cloud box with `--bot-no-visuals=1`, which plays the same ticks (PR 784).

**Severity.** This page uses the [alpha bug bar](../../../sketches/core-loop/BUG-BAR.md). The card says "high and above"; the bar has no "high", so this page reads it as Blocker and Major.

## How it was attacked

The tool is [`tools/sysaudit/break_run.gd`](../../../sketches/core-loop/tools/sysaudit/break_run.gd). It wraps `bot_run.gd`, so the run and its `bots.ndjson` row are the normal bot's, with `--qa-log=1` for the play watch (stuck, hung, wedged, fell). Every attack is seeded, so the command in a row replays it tick for tick. That was checked: seed 2880 gave the same stall and the same hung row twice.

| Attack | `--break=` | What it does |
| --- | --- | --- |
| Input spam | `spam` | On top of the bot's own input, presses each key about three times a second: jump, the go verb (Sable's boost, Rivet's sprint, Kest's blink), interact, fire, harpoon press and release, cancel, slot picks, the ultimate and the racked active. It also adds short holds, a random stick now and then, and pause pressed and lifted a few ticks later. It keeps mashing through launches, the gates, cards and the boss, so an input taken in the wrong state shows up. This is the bot that presses boost which pass C asked for. |
| Sequence breaks | `spam` | The same mash in every flow state, with the skipper (fastest line) and the random first-timer. |
| Save-and-quit | `quit` | Frees the game with no save, as a closed window or a crash does, and continues through the title's Continue (`flow.resume_run`) in a fresh game. `--quit-in=<state>:<s>` aims the quit at a state: `beacon` (the Warden fight), `gates` (after the break), `launch`, `boss` or `dead`. The check is that the continued run is the saved entrance and never more: stage, cogs, parts, the death save and hull. After a death or the summary, Continue must be refused. |
| Buffs with debuffs | `stack` | A random legal build of 13 to 15 parts (item fuzz's draft), a curse deal taken, scrap wear on (the default), the hull set to 15% at every new stage, and the run seed's own stage modifiers. |

The watch writes a row to `break-<seed>.ndjson` for each of these: a non-finite position, velocity or hull; hull above max; hull at zero in play for over 1 s; speed over 200 m/s; the ball under −400 m or 6 km out; a negative resource; cogs or scrap up by more than 400 in one game second; the flow stuck outside play for 30 s; the game left paused 2 s after the bot let go; and the continue checks.

## What broke

| # | Issue | Repro | Severity | Fix | Verified |
| --- | --- | --- | --- | --- | --- |
| F1 | **Quitting after a Warden breaks loses the cleared stage.** The break opens the gates, and the next save is written only when the launch lands at the next stage. A quit or crash in that window (picking a gate, the launch flight) continues at the stage's start, with its cogs and parts gone. The bots spent 5 to 100 s in that window; a player choosing a gate can spend longer. | `break_run.gd -- --break=quit --quit-in=gates:3 --policy=completionist --seeds=2884 --table=park --until=2`: before the quit, stage 1 was cleared with 661 cogs and 1 part; after Continue, stage 1 started again with 0 and 0. Seed 2876 (skipper, seeded quit at the gates) did the same with 728 cogs. | Major. Progress is lost, the save is not. BIBLE section 6 says "Completed levels preserve the build and resolved rewards". Whether a broken Warden counts as a completed level is for `flow.gd`'s owner to read. If it does not count, F1 is Minor, and the window should at least be short. | Not fixed here: `flow.gd` is held by the wave 37 board thread. Suggested fix: write a checkpoint at the break that continues at the open gates, with the reward pick still to make, or at the next entrance with the pick carried. Add a replay test from the repro command. | Yes for the issue: 2 of 2 quits at the gates. The fix is not built. |
| F2 | **The play watch calls Sable's pylon mount "hung".** A pylon engineer who mounts the pylon rests in the air at zero speed, and `play_watch.gd` logs that as an ungrounded rest. The same watch writes Andrew's sitting notes, so his notes would show it too. | `break_run.gd -- --break=spam --policy=random --seeds=2880 --table=park --until=1 --qa-log=1`: a hung row at stage second 127.1, (−34.8, 103.8, 136.3). A tick probe showed `kit.mounted` true for the whole rest. | Minor (a tool false alarm) | Backlog row: leave the mounted pylon out of hung and stuck in `play_watch.gd`. | Yes, the probe |
| F3 | **One stuck row in the flume.** The completionist sat still for 8 s or more, on the ground, fighting a plated brute at (−63.7, 2.3, 187.0). The run went on and cleared world 1. | seed 2877, `--break=quit`, completionist; at stage 2, second 131.5 | Minor, as a watch. The red team counts three stuck rows on one stage as a finding. | Backlog row: watch for it in the next sweeps. | No; seen once |
| F4 | **The launch flight was never quit into.** Headless bot runs cut the launch at once, so the `launch` state lasts under a second and `--quit-in=launch:1` never fired. The code path is F1's, because the save is written on landing. | seed 2882 | Coverage gap | Backlog row: quit in the flight on a rendered build (the PC lane). | No |

**What did not break** (every run, `runs.json`):
- No crash, script error or engine error in 21 runs.
- No non-finite number, hull over max, hull at zero without a death, speed over 200 m/s (the peak was 97 m/s, in the stacked build), fall out of the world, negative resource, flow stuck outside play, or pause left on.
- Continue matched the saved entrance in all 7 quits, in the Warden fight, at the gates, in Brindle's arena and mid-stage. It never held more than when the game was quit.
- After a planted death (`--plant=damage=25`, seed 2885), Continue was refused and the run file was a tombstone.
- Spam with pause pressing never left the game paused or broke a launch, the gates, a card or Brindle. Spam seed 2874 beat Brindle while mashing.

**Not tested:**
- A spent death save across a quit. No run earned one. `run_save_interrupt_test` covers the spent flag on disk.
- Moss's counter while mashing. The bots never shop. The sell price is pinned to the price paid (`shop.gd` `sell_quote`, after the w24 and 8 Nov red-team catches), and the scale only pays for scrap carried, which has no free source. A loop there would need a shop-pressing bot.
- Pads, frame times and anything a person feels.

**Notes that are not game bugs:**
- The bot's hands under spam. Four of five skipper and random runs stalled at the dam Warden. All four that were rerun with the mash stopped at a set second (`--spam-until`) broke the Warden within about 25 s of the stop. The game was not left broken: the mash ruins the bot's timed hook release on the spillway sheet.
- The stacked build ended world 1 with 2,852 cogs (seed 2879), against 1,681 to 2,223 for the plain and spam runs, and paid out about 480 cogs and 480 scrap in one second at each Warden break. That is a bigger payout, not a loop. Pass B's prices own it ([economy/](../economy/README.md)).
- Low hull did not last. A hull set to 15% at each stage start healed before the first fight: the lowest hull in a stacked run was 17 of 140. (The first two stacked runs set it from stage 2 on, because the tool missed stage 1; seed 2886 sets it from stage 1.) This is pass A's hull-regen finding ([systems-map.md](../systems-map.md)), not a new one.

## Change request for the coordinator

ORCHESTRATOR owns the tiered gate, so this is a request, not an edit. At each sprint close, run pass F's break bot together with pass B's balance sim (one spam, one quit and one stack run per world, about 10 minutes each on 4 cores). Reopen the sprint if they find a new dominant strategy, or a break that is Major or above on the bug bar. The release gate already reruns the red team; this adds the save-and-quit and stacking attacks, which the red team does not run.

## Rerun

From `sketches/core-loop`, with `G=$GODOT_BIN`, run one seed per process. bot_run forks multi-seed runs into children that run `bot_run.gd` itself, without this wrapper.

```bash
$G --headless --fixed-fps 90 --path . --script res://tools/sysaudit/break_run.gd -- \
  --out=<abs dir> --policy=skipper --seeds=<n> --table=park --until=2 --qa-log=1 --bot-no-visuals=1 \
  --break=spam|quit|stack [--quit-in=gates:3] [--spam-until=200] [--plant=damage=25]
```

`--out` must be an absolute path. Each run takes 3 to 10 minutes on the cloud box. The raw logs (`break-*.ndjson`, `qa-*.ndjson`, `bots.ndjson` and the console logs) are on branch `scratch/systems-audit-pass-f`. `runs.json` here has one line per run. The first runs (plain, stack1, spamtrace and spam 2873 to 2875) used the first version of the tool, and stack1 ran on into world 2 (`--until=3`). It differs only in the quit timer and the stage-modifier row, so their spam and stack rows stand.

## Systems health (for the coordinator's digest)

| System group | Pass status | Top open issue | Last result | What changed |
| --- | --- | --- | --- | --- |
| Saves and Continue | F done; F1 to the board thread | a quit after a Warden breaks replays the stage (F1) | 7 of 7 continues matched the entrance; Continue refused after a death | nothing in the game |
| Input and flow states | F done | none | 10 spam runs: no crash, no stuck pause, no soft-lock | the break bot presses boost and every other key |
| Build stacking | F done | none new; pass B owns the payout size | 3 stacked runs: no number escaped; peak 97 m/s | nothing in the game |

**One finding in plain words.** World 1 holds up well against a player trying to break it. Mash every button, pause mid-launch, quit in a boss fight, pile on fifteen parts and a curse at low hull: it keeps working and the numbers stay sane. The one way to lose real progress is to quit in the few seconds between breaking a Warden and landing at the next stage. You come back to the start of the stage you just cleared.
