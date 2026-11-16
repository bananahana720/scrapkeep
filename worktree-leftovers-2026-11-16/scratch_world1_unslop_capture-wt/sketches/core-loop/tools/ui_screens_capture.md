# ui_screens_capture

One run writes `<nn>-<screen>.png` (1920x1080) for each menu and between-run screen that no other capture tool reaches, so a before and an after can sit side by side.

## Command

Headless on the 3060, never a window on the desktop, one capture at a time:

```
source /home/andrew/scratch/world1/env-pc.sh <name> 1 2 <pool>
PULSE_SINK=claude_silent timeout 600 nice -n 10 gamescope --backend headless --prefer-vk-device 10de:2504 \
  -W 1920 -H 1080 -w 1920 -h 1080 -- $GODOT_BIN --path sketches/core-loop --gpu-index 1 \
  --resolution 1920x1080 --audio-driver Dummy --script res://tools/ui_screens_capture.gd -- \
  --out=<absolute dir> [--screens=all|name,name] [--profile=fresh|played] [--seed=0]
```

The worktree must have been imported once (any `sketch-smoke --test` run does it). It prints one line per screen (name, file, bytes), writes `capture.json`, exits 1 naming each screen not reached, and exits 2 on an unknown screen name or a bad argument. `--selftest=1` adds a row whose settle test never comes true, to show the failure path. A frame that is flat colour or under 50 KB counts as not reached. A run that stalls ends at 500 s and names what is left.

`--profile=fresh` is the game's empty test profile with one companion piece. `--profile=played` owns every pilot, world, paint, tune and achievement, with stats set and a companion pair seated. Both live in the per-process test folder under the scratch data home; the owner's save is never opened.

## Screens

Each is one row of `SCREENS` at the top of the tool: name, group (`title` rows start from the title, `run` rows from a fresh calm run), the method that drives the game there, the method that says it settled, what the frame shows. A new screen is one new row and two methods.

| Screen | Shows |
|---|---|
| settings-display, -controls, -look, -feel | Settings from the title, one tab each |
| achievements | The achievements page |
| camp | The camp walk with its key strip |
| camp-jukebox, camp-radio, camp-customize | The jukebox, the radio mixtapes and the customize page, each over the walk |
| companion | The companion panel on the title |
| hud-toast-card | The HUD with a toast and the first kit card up |
| build-readout | The Build popup listing three fitted parts |
| pause-settings | Settings opened from the pause menu |
| hotwire | The hot-wire Fit or Recycle offer |
| shop | Moss's counter with a tile focused |
| death | The death screen |
| summary-loss, summary-win | The run summary after a loss and after a win |

## What it cannot reach

- A real fight: the run is calm, so the HUD still has no enemies on it. Fights are `visual_capture.gd`'s.
- A summary with real numbers: the run ends at once, so the summary stats read 0:00, 0 scrap and 1/6 stages.
- The summary's ending sequence and victory lap, which `lap_capture.gd` owns.
- A real warden break, a real purchase or a real death: the screens are reached by the same calls the game makes, but the triggering fact (a beacon unsealing, the ball dying) is emitted directly.
