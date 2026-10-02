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

## The rebuilt Reach (unit Z3, 2026-10-02)

The slice table's stage now plays `src/world/map_reach.gd`: the gorge's ground with an authored line from the spawn to the Warden for each pilot (waypoints in `tools/traversal_lines.json`; the three-stage game keeps the gorge). Same commands as above, 8 seeds each, run on the Z3 working tree. The baseline section above stays as history.

Route measures, added to each seed's row and the summary: `path_length_m` (distance travelled from spawn to engage), `rides` (which of `ride_grapple_line`, `ride_chute`, `ride_skylight`, `ride_glide_drop`, `wall_crumbled`, `kicker_launch`, `thermal_ride` fired) and `uphill_m` (the most z the ball gave back from its furthest point toward the Warden). The summary holds `median_path_length_m`, `median_uphill_m` and `median_rides` (the count).

| Pilot | Reached Warden | Median flow share (bar) | Worst seed | Dead stops | Max anchor gap | Time to Warden | Median path | Rides | Median uphill |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Sable | 8 of 8 | 0.7345 (0.8974) miss | 0.6625 (seed 1) | 12 over 8 seeds | 12.4 m | 20.3 to 22.3 s | 465.0 m | kicker only | 9.4 m |
| Rivet | 8 of 8 | 0.8836 (0.8814) met | 0.8833 (seed 8) | 0 | 24.8 m | 16.0 to 16.1 s | 362.9 m | cable, wall, kicker on 8 of 8 | 0.0 m |
| Kest | 8 of 8 | 0.9139 (0.9019) met | 0.9130 (seed 7) | 0 | 18.4 m | 16.7 to 17.5 s | 403.4 m | cable on 8 of 8 | 0.3 m |

Rivet's and Kest's lines are 1.31 and 1.45 times the 278 m straight and meet the length floors (320 m and 350 m). Sable's line is the longest (465 m) and misses the bar: the bot leaves the marble run's second bend at 37 m/s, rides the west shelf for about four seconds, hits the satellite tower at (-72,-16) or the shelf, and lands in tunnel w1 hard enough to count as a stop (positions in the DESIGN-NOTES section). Her uphill figure is that detour, not the deck. The waypoint adjustment the layout allowed for a deck-leg miss (second waypoint 8 m downhill) was applied to Sable and Rivet: Rivet went from 0.866 to 0.884, Sable from 0.703 to 0.735.

The seed 7 stop of the baseline does not appear on Rivet or Kest. On Sable seed 7 still stops once, in tunnel w1.

## Round two: Sable's strand holds its speed (unit Z3, 2026-10-02)

Round one built the sheet's marble run and tunnel for Sable, and she missed her bar (median 0.7345, 12 dead stops, 6.4 to 11.2 m back toward the spawn, 0.74 of her ticks within 8 m of her line). The sheet was the cause: at the 28 to 33 m/s she carries off the deck, the marble run's lip throws her, its 43 and 55 degree corners cannot turn her, the satellite at (-72,-16) stands on her line and a roof over tunnel w1 is a wall for a ball that arrives in flight. Her strand was rebuilt in eight measured tries (the table is in `DESIGN-NOTES.md`). Rivet's and Kest's strands are unchanged and their numbers are the round-one numbers, measured again.

What her strand is now: the deck's glide lands her near (-28,-118) and she runs west into a banked sweeper (a `Features.banked_arc` of radius 58 to 70 about (-32.3,-78)) that carries her round the west shelf, then she dives down an open ramp that replaces tunnel w1's roof and floor (45 m before the mouth to 60 m past it, never steeper than about 23 degrees, a vertical radius of 55 to 63 m at its two bends, so a fast ball hops it for up to a second and lands on it) and is turned onto the trough floor toward the merge and the kicker. The marble run, the w1 roof and the satellite at (-72,-16) are gone from this map.

`--trace` on the traversal command writes one file per seed, `<pilot>-seed-<n>-trace.json`, with a row per tick (position, velocity, planar speed, tier, grounded, the colliders touched, dead stops). The on-line share is the fraction of ticks, from the first within 8 m of the third waypoint, whose planar distance to the drawn line is 8 m or less; its bar is a median of 0.85. `python3 tools/traversal_on_line.py tools/traversal_lines.json <pilot> <trace files>` prints it per seed and exits 1 under the bar.

| Pilot | Reached Warden | Median flow share (bar) | Worst seed | Dead stops | Max anchor gap | Time to Warden | Median path | Backward (max over seeds) | Median on-line | Rides |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Sable | 8 of 8 | 0.9453 (0.8974) met | 0.9415 (seed 6) | 0 | 10.7 m | 10.8 to 12.2 s | 373.6 m | 3.0 m | 0.935 | kicker on 3 of 8 |
| Rivet | 8 of 8 | 0.8837 (0.8814) met | 0.8835 (seed 1) | 0 | 24.8 m | 16.0 to 16.1 s | 363.0 m | 0.1 m | 0.933 | cable, wall, kicker on 8 of 8 |
| Kest | 8 of 8 | 0.9138 (0.9019) met | 0.9130 (seed 1) | 0 | 18.4 m | 16.7 to 17.5 s | 402.9 m | 2.0 m | 0.921 | cable on 8 of 8 |

### On the admitted line (after wave R2), 2026-10-02

The table above was measured on the candidate's base, before wave R2. R2 moved device placements to their own map, which took a misplaced Spillway cache off the Reach's spawn apron. Every pilot used to land on that cache (9 m above the apron) and roll off it with extra speed; now the ball drops 16 m onto a near-level deck and keeps about 14 m/s. Measured again on the merged build, 8 seeds each, with the duplicate post at (-60,-96) removed and tunnel e1's roof left off:

| Pilot | Reached Warden | Median flow share | Worst seed | Dead stops | Max anchor gap | Time to Warden | Median path | Median on-line | Rides (8 of 8) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Sable | 8 of 8 | 0.9565 | 0.9558 (seed 1) | 0 | 20.2 m | 10.6 to 11.1 s | 372.3 m | 1.000 | `ride_chute` |
| Rivet | 8 of 8 | 0.9164 | 0.9164 (seed 1) | 0 | 21.0 m | 15.7 to 15.8 s | 365.4 m | 0.931 | `ride_grapple_line`, `wall_crumbled`, `kicker_launch` |
| Kest | 8 of 8 | 0.8694 | 0.8693 (seed 5) | 0 | 16.5 m | 16.9 to 18.1 s | 404.8 m | 0.880 | `ride_grapple_line`, `ride_skylight` |

**Kest misses the bar written before the build (0.8694 against 0.9019).** Every tick the two east pilots spend under tier 2 falls in the first 6.5 s (Rivet 118 ticks, Kest 199): the drop from the spawn and about 3 s on the level deck at 14 to 16 m/s before the cable. After that neither line drops below tier 2. The bars themselves were set on the spawn with the cache on it. The old gorge map measured on this same base gives Sable 0.944, Rivet 0.963 and Kest 0.960, because its bot rolls straight down the fall line and reaches the Warden in about 11 s; against those, both east lines give up flow share for their length.

A launch crown under the drop (a mound of 7 m, 3 m top, 30 m foot at (0,-150)) was tried twice at the merge and taken out again. It does what it is for: Rivet reaches 24 m/s by 2.8 s where he had 18, and Kest's median rises to 0.939. But the speed carries down every line. Rivet arrives at tunnel e1 at 25.9 m/s, leaves the ground at its lip and stops dead on the roof in 8 of 8 seeds, and Sable overshoots her sweeper's entry, arrives late and stalls on the kicker's ramp in 6 of 8. Fading the crown out across the fall line makes a scarp where the ball lands and is worse for all three. The crown needs the three lines retuned with it, which is its own unit. Tunnel e1's roof stays off in the meantime, because a roof facing a ball in flight is a wall and a player who sprints arrives faster than the bot.

The slow start is named on the sitting sheet: the first three seconds on the east lines are a drop and a level roll.

Sable's flow share is high because she is fast, not because the route is long: she reaches the Warden in about 11 s, the shortest of the three. The only ticks she spends under tier 2 are 0.6 s of the spawn's glide. The kicker fires on 3 of her 8 seeds because she reaches it a few metres off its centre line on the others; the acceptance does not ask for it and it is not tuned.

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

### The spawn launch (unit ZL), 2026-10-02

The Reach's flank is steepened under the 16 m drop: `LAUNCH_DROP` (3.5 m) is taken off the ground between z = -158 and -135 and eased back to the old flank by z = -100, across the whole width (a function of z only, so there is no scarp for a ball landing off the fall line). Its own slope peaks at 12.9 degrees; the flank under it adds about 12. The spawn height is unchanged (57.2) and so is every other pin. This is not the crown that was tried at the merge: it adds no mound for the ball to climb, so the east lines do not arrive at tunnel e1 or the sweeper faster than they can use.

The landing now turns the fall into rolling speed: Rivet and Kest are above 16.5 m/s planar from 1.23 s on every seed (today they reach tier 2 at 2.2 s and 3.0 s), and Sable's entry is not faster than she can turn. One waypoint changed: Kest's (103,-100) is gone. Kest's Shift is a blink, and the bot used it at the cable's start to reach that waypoint, which moved him 7 m east of the cable's line at 19.5 m/s into the post at (92,-36), a dead stop on all 8 seeds. A person on the cable would not blink sideways. At 5.0 m of drop (try one) Sable also arrived at 42 m/s, could not turn onto the kicker's approach, and her slowest run was 14.7 s.

8 seeds each, last try:

| Pilot | Reached Warden | Median flow share | Bar | Worst seed | Dead stops | Time to Warden | Median on-line |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Sable | 8 of 8 | 0.9579 | 0.914 | 0.9552 | 0 | 10.4 to 11.5 s | 0.893 |
| Rivet | 8 of 8 | 0.9701 | 0.933 | 0.9700 | 0 | 15.6 to 15.7 s | 0.937 |
| Kest | 8 of 8 | 0.9746 | 0.930 | 0.9746 | 0 | 18.4 to 18.6 s | 0.948 |

The bars are the old gorge map on this base (0.944, 0.963, 0.960) less 0.03.
