# Traversal measure for the Cable Reach

Source: `LEGIBILITY.md` section 8. Andrew's words: "the map is just not fun to traverse, which is the whole point of the game is high speed traversal with high momentum." This file holds the number that says whether a ball can hold its speed across the Reach, today's value of it for each pilot, and the bar a rebuilt Reach has to clear. The number judges a bot. It does not certify fun; his play does that.

## Definitions

Each is implemented as written here. The detector is `RunLog.Traversal` in `src/core/run_log.gd`, so the headless measure and Andrew's run log count the same way.

- **Flow share.** The fraction of physics ticks, from the stage spawn to Warden engage, at speed tier 2 or above (16.1 m/s at cruise 14). A tick is counted only when the stage clock moved. The tier is the ball's own `speed_tier()`.
- **Dead stop.** Either of two events, counted once each.
  - More than 0.5 s under tier 1 with the brake not held and no mount or interaction. The clock resets while the brake is held or the ball is mounted, frozen, or pressing interact, and it arms only after the ball has first reached tier 1, so a standing start is not a stop.
  - One contact that removes more than half of planar speed: planar speed under half of the highest planar speed of the previous 0.1 s, with that highest speed at tier 1 or above. A contact that drops the ball under tier 1 and holds it there is one dead stop, not two.
  - A slowdown with the brake held is neither.
- **Max anchor gap.** The largest distance the ball travelled between two ticks where the harpoon had a valid world target within the rope's 45 m. A target is valid when the bot's own aim holds one, or when any of 36 rays cast from the ball (12 around, at 0, 0.4 and 0.8 rad above level; walkable ground refused) bites world geometry in range. The fan is cast every 0.1 s. The first gap runs from the spawn, the last to Warden engage.
- **Time to Warden.** Seconds of stage clock from spawn to the `warden_engaged` signal. The flow fires it when the ball enters the beacon ring, or when the Warden is struck.
- **The bar,** per pilot over 8 seeds: median flow share 0.70 or more, no seed under 0.60, zero dead stops, largest anchor gap 40 m or less. If today's map already clears 0.70 for a pilot, that pilot's bar is its baseline median plus 0.15.

## The bot

`traversal` in `tools/bot_driver.gd` follows the pilot's route from `tools/traversal_lines.json` (today none: spawn to beacon) and never fights. It steers from where the ball was `TRAVERSE_REACTION` (0.15 s) ago, so it answers no change sooner than that, and its presses pass one gate that drops a second verb inside `TRAVERSE_PRESS_GAP` (0.4 s). It steers every tick. `tests/traversal_measure_test.gd` asserts both limits, from the bot's own `reaction_ticks` and `press_ticks`.

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

Commit `8a6c846b00f1020a11b73e10fcd88af6626e4124`, slice table, spawn to beacon with no authored waypoints, seeds 1 to 8, nothing tuned. Wall time per pilot: Sable 19 s, Rivet 21 s, Kest 27 s.

| Pilot | JSON | Reached Warden | Median flow share | Worst seed | Dead stops | Max anchor gap | Time to Warden |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Sable | `artifacts/local/traversal/sable.json` | 8 of 8 | 0.898 | 0.898 (seed 1) | 0 | 14.2 m | 9.19 s |
| Rivet | `artifacts/local/traversal/rivet.json` | 8 of 8 | 0.889 | 0.889 (seed 5) | 0 | 14.1 m | 9.93 to 9.94 s |
| Kest | `artifacts/local/traversal/kest.json` | 8 of 8 | 0.942 | 0.826 (seed 7) | 1 (seed 7) | 14.1 m | 9.06 s, 10.75 s on seed 7 |

The JSON files are local evidence and are not committed.

## The bar per pilot

Every pilot's baseline median already clears 0.70, so each bar is the baseline median plus 0.15. That is above 1.0 for all three, which no run can reach (flow share is a fraction), so the route file holds 1.0 and keeps the rule's raw value beside it.

| Pilot | Baseline median | Rule value | Bar in `traversal_lines.json` | No seed under | Dead stops | Anchor gap |
| --- | --- | --- | --- | --- | --- | --- |
| Sable | 0.8983 | 1.0483 | 1.0 | 0.60 | 0 | 40 m or less |
| Rivet | 0.8893 | 1.0393 | 1.0 | 0.60 | 0 | 40 m or less |
| Kest | 0.9423 | 1.0923 | 1.0 | 0.60 | 0 | 40 m or less |

## What the baseline says

- The measure saturates on today's map. The bot reaches the beacon ring in about 9 to 10 s at tier 2 or better for nine ticks in ten. Against that the "+0.15" rule yields a bar of 1.0, which is every tick at tier 2: it cannot discriminate a rebuilt Reach. The owner has to decide whether the rule stands, the measure should run longer (past the beacon ring), or the bar should be set from play. This is for the coordinator to take to the retrofit unit; nothing here is tuned.
- The bot's line does not show what Andrew feels. A bot that holds tier 2 down the gorge in 9 s and a person who finds the map not fun to traverse can both be right, which is the case for logging his own run (below) and reading it beside these numbers.
- Kest seed 7 is the only dead stop (flow share 0.826, 10.75 s to Warden against 9.06 s on the other seeds). The measure does not say what stopped it.
- Anchor gaps of 14 m mean the gorge walls always offer a hookable surface in range. The 40 m limit is not tight on today's map.

## The run log

Every `runs.ndjson` record gains: `flow_share` (null before any measured tick), `dead_stops`, `bites`, `smashes`, `breaks` (count per cause, `unspecified` when the signal's cause is empty), `verb_fails` (count per verb) and `prompts_shown` (0 until the prompt unit lands). Bites are `line_state_changed` with state `latched_body`, smashes are `smash_lands`, breaks are `broke`, verb fails are `verb_failed`. The flow share and dead stops use the same detector as the measure, from each stage's start to its Warden engagement, accumulated across a run's stages and retries.

**Joined events.** `events_joined` now lists an event only when the ball entered it. The director publishes `event_started` for a participatory event (`scrap_stampede`, `surge_run`, `hold_the_relay`) at the tick the ball reaches its ring, so those count. It also publishes it for the flood, the dust squall and the terrain changes, which start on a timer whatever the player does, so those no longer count. The altar and the cache publish `interact_fired` and `ambush_ended` rather than `event_started`; they are not counted, and whether pressing interact on them is "entering" is left open.
