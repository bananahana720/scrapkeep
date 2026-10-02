# Traversal measure for the Cable Reach

Source: `LEGIBILITY.md` section 8. Andrew's words: "the map is just not fun to traverse, which is the whole point of the game is high speed traversal with high momentum." This file holds the number that says whether a ball can hold its speed across the Reach, today's value of it for each pilot, and the bar a rebuilt Reach has to clear. The number judges a bot. It does not certify fun; his play does that.

## Definitions

Each is implemented as written here. The detector is `RunLog.Traversal` in `src/core/run_log.gd`, so the headless measure and Andrew's run log count the same way.

- **Flow share.** The fraction of physics ticks, from the stage spawn to Warden engage, at speed tier 2 or above (16.1 m/s at cruise 14). A tick is counted only when the stage clock moved. The tier is the ball's own `speed_tier()`, which reads the 3D speed, so a fall at tier 2 speed counts toward flow. The dead-stop contact rule reads planar speed.
- **Dead stop.** Either of two events, counted once each.
  - More than 0.5 s under tier 1 with the brake not held and no mount or interaction. The clock resets while the brake is held or the ball is mounted, frozen, or pressing interact, and it arms only after the ball has first reached tier 1, so a standing start is not a stop.
  - One contact that removes more than half of planar speed: planar speed under half of the highest planar speed of the previous 0.1 s, with that highest speed at tier 1 or above. A contact that drops the ball under tier 1 and holds it there is one dead stop, not two.
  - A slowdown with the brake held is neither.
- **Max anchor gap.** The largest distance the ball travelled between two ticks where the harpoon had a valid world target within the rope's 45 m. A target is valid when the bot's own aim holds one, or when any of 36 rays cast from the ball (12 around, at 0, 0.4 and 0.8 rad above level; walkable ground refused) bites world geometry in range. The fan is cast every 0.1 s. The first gap runs from the spawn, the last to Warden engage.
- **Time to Warden.** Seconds of stage clock from spawn to the `warden_engaged` signal. The flow fires it when the ball enters the beacon ring, or when the Warden is struck.
- **The bar,** per pilot over 8 seeds: median flow share at or above the larger of 0.70 and that pilot's baseline median minus 0.03, no seed under 0.60, zero dead stops, largest anchor gap 40 m or less. The earlier "baseline median plus 0.15" rule is retired: it gives values above 1.0, which no run can reach. The numbers are provisional (see the bar section).

## The bot

`traversal` in `tools/bot_driver.gd` follows the pilot's route from `tools/traversal_lines.json` (today none: spawn to beacon) and never fights. Its whole output, the stick, the camera turn and every press, goes out `TRAVERSE_REACTION` (0.15 s, 14 ticks) after it was decided, so nothing it reads (position, velocity, the wall rays, the stuck check) is answered sooner. The stick keeps the world direction it meant through the delay. Shift is pressed and held as the keyboard does it, only when the verb is ready. Its presses pass one gate that drops a second verb inside `TRAVERSE_PRESS_GAP` (0.4 s). It never holds fire. `tests/traversal_measure_test.gd` changes the route's target on one tick and asserts neither the camera nor the stick's world direction answers for 13 ticks and both have by tick 16, that no tick holds fire, and, with a press on every tick, that presses stay 0.4 s apart.

Fight profiles for the later Warden bands (this unit does not run the bands):

| Profile | Policy | Where it comes from |
| --- | --- | --- |
| brawler | `completionist` | reused: rolls loot to grow, then fights with the ram, the harpoon hand and the gun |
| skipper | `skipper` | reused: beelines at the Warden at starting size |
| camper | `camper` | new: gun held on the Warden from 30 m (`CAMP_RANGE`), brake held in range, never closes |

`BotDriver.new(game, "brawler" | "camper" | "skipper", seed)` takes the profile name; `record()` carries it as `profile`.

## Commands

From the worktree root. One command per pilot, 8 seeds (1 to 8) by default, one JSON per pilot under `artifacts/local/traversal/`. Add `--seeds=1,2` for fewer, `--out=<dir>`, `--commit=<sha>`.

```
godot --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/traversal_line.gd -- --pilot=sable
godot --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/traversal_line.gd -- --pilot=rivet
godot --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/traversal_line.gd -- --pilot=kest
```

Godot is the binary named in `scripts/sketch-smoke.mjs`. Each JSON holds the pilot, the table (`slice`), the commit, the bar, one row per seed (`flow_share`, `dead_stops`, `max_anchor_gap_m`, `time_to_warden_s`, `reached_warden`, `outcome`, `ticks`), the median flow share and the worst seed.

## Baseline: the Reach as it is

Taken on the merged wave R1a head, commit `b52f58e`: the harpoon canon, the synergy facts and this unit together, with the bot's camera delayed with its stick and its Shift pressed as the keyboard presses it. Slice table, spawn to beacon with no authored waypoints, seeds 1 to 8, nothing tuned. Earlier tables (commits `8a6c846` and the fix round's working tree) are replaced.

| Pilot | JSON | Reached Warden | Median flow share | Worst seed | Dead stops | Max anchor gap | Time to Warden |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Sable | `artifacts/local/traversal/sable.json` | 8 of 8 | 0.9274 | 0.9030 (seed 7) | 1 (seed 7) | 16.8 m | 8.26 to 8.32 s, 15.67 s on seed 7 |
| Rivet | `artifacts/local/traversal/rivet.json` | 8 of 8 | 0.9114 | 0.7447 (seed 7) | 1 (seed 7) | 14.4 m | 11.84 to 12.79 s, 14.11 s on seed 7 |
| Kest | `artifacts/local/traversal/kest.json` | 8 of 8 | 0.9319 | 0.6114 (seed 7) | 1 (seed 7) | 12.5 m | 10.66 to 11.33 s, 13.05 s on seed 7 |

The JSON files are local evidence and are not committed.

## The bar per pilot

Median flow share at or above the larger of 0.70 and the pilot's baseline median minus 0.03; no seed under 0.60; zero dead stops; largest anchor gap 40 m or less. The coordinator's ruling; it replaces "baseline plus 0.15".

| Pilot | Baseline median | Bar: median flow share | No seed under | Dead stops | Anchor gap |
| --- | --- | --- | --- | --- | --- |
| Sable | 0.9274 | 0.8974 | 0.60 | 0 | 40 m or less |
| Rivet | 0.9114 | 0.8814 | 0.60 | 0 | 40 m or less |
| Kest | 0.9319 | 0.9019 | 0.60 | 0 | 40 m or less |

**Provisional.** The map retrofit unit adds route measures: the authored line's length and the verbs it chains. A straight shot of 8 to 13 seconds to the beacon is itself what the owner called not fun to traverse, and flow share alone cannot see that.

## What the baseline says

- **Today's map fails the bar on one count: seed 7 stops every pilot once.** Each loses 2 to 7 seconds there. The measure does not say what stopped them; the retrofit unit finds it.
- The measure is near its ceiling on today's map. The bot reaches the beacon ring at tier 2 or better for nine ticks in ten, so the flow-share bar sits close to what the map already gives. It tells a stall from a clean run; it cannot tell a long, varied route from a short straight one. The route measures above are for that.
- Rivet and Kest are slower to the Warden than in the earlier tables (about 12 s and 11 s against 9.5 s and 9 s). The earlier bot pressed a plain boost that the keyboard cannot give those pilots; this one presses Shift, which is Rivet's sprint and Kest's blink.
- Flow share uses the 3D speed tier, so a fall counts as flow. If descents should not count, the measure should use planar speed.
- The eight seeds give nearly the same run per pilot. Read the median as one run's number with seed 7 as the outlier, not as a spread.
- The bot's line does not show what Andrew feels. A bot that holds tier 2 down the gorge in 8 s and a person who finds the map not fun to traverse can both be right, which is the case for logging his own run (below) and reading it beside these numbers.
- Anchor gaps of 12 to 17 m mean the gorge walls always offer a hookable surface in range. The 40 m limit is not tight on today's map.

## The run log

Every `runs.ndjson` record gains: `flow_share` (null before any measured tick), `dead_stops`, `bites`, `smashes`, `breaks` (count per cause, `unspecified` when the signal's cause is empty), `verb_fails` (count per verb) and `prompts_shown` (0 until the prompt unit lands). Bites are `line_state_changed` with state `latched_body`, smashes are `smash_lands`, breaks are `broke`, verb fails are `verb_failed`. The flow share and dead stops use the same detector as the measure, from each stage's start to its Warden engagement, accumulated across a run's stages and retries. The detector restarts at each stage entry (`Traversal.restart()` clears the arming and the slow clock, keeps the totals), so a stage boundary is not a stop. The exemption for a tick (frozen, mounted, interact pressed or mount held) is the static `RunLog.Traversal.is_exempt(player)`, used by the measure and the run log alike.

**Joined events.** `events_joined` now lists an event only when the ball entered it. The director publishes `event_started` for a participatory event (`scrap_stampede`, `surge_run`, `hold_the_relay`) at the tick the ball reaches its ring, so those count. It also publishes it for the flood, the dust squall and the terrain changes, which start on a timer whatever the player does, so those no longer count. The altar and the cache publish `interact_fired` and `ambush_ended` rather than `event_started`; they are not counted, and whether pressing interact on them is "entering" is left open.
