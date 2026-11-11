# seam_strip_capture

One run films the two world 1 stage launches (dam to flume, flume to Slag Bowl) as 1920x1080 frame strips and one contact sheet per seam, so a person can judge whether the hand-over reads as one move.

## Command

Headless on the 3060, never a window on the desktop, one capture at a time. `--fixed-fps 60` makes a frame exactly 1/60 s of game time whatever the renderer's speed:

```
source /home/andrew/scratch/world1/env-pc.sh <name> 1 2 <pool>
PULSE_SINK=claude_silent timeout 600 nice -n 10 gamescope --backend headless --prefer-vk-device 10de:2504 \
  -W 1920 -H 1080 -w 1920 -h 1080 -- $GODOT_BIN --path sketches/core-loop --gpu-index 1 \
  --resolution 1920x1080 --fixed-fps 60 --audio-driver Dummy --script res://tools/seam_strip_capture.gd -- \
  --out=<absolute dir> [--seed=0] [--selftest=1]
```

The worktree must have been imported once. Sheets come from ImageMagick `montage`, which must be installed.

gamescope does not pass the tool's exit code on. Read `exit_code` in `capture.json` (0, or 1 with the seams in `missed`), or the `NOT REACHED` line on stderr.

## What it writes

- `<seam>-<nnn>-<+/-ms>ms.png`: a frame every 0.1 s of game time, from 2 s before the launch to 1.5 s after touchdown (for example `dam-flume-003--1700ms.png`).
- `<seam>-sheet.png`: the frames in order, six to a row, each labelled with its time from the launch and any moment that falls on it.
- `capture.json`: per seam, `times_s` (seconds from the launch: `swipe_fully_closed`, `cut`, `reveal_starts`, `touchdown`, `control`), the landing impact, and one row per frame (file, time, bytes, take phase and progress, stage, flow state).

## How it reaches a launch

A calm run of the seed's pilot with the take forced live. The ball is set rolling toward the stage's beacon (from the terrain's own spawn and beacon points), the Warden's seal is lifted as the tests do (`flow._unseal`), and 2 s later a reward is chosen (`events.reward_chosen`), which makes `world.gd` fire the ball. Dam to flume runs first; the flume to Slag Bowl launch follows from the same run. No position or heading is hard coded: the launch is the `launched` signal, the swipe's moments are the take's own `progress` and `phase`, the cut is the stage or the boss state changing, touchdown is the first `landed` after the cut, and control is the first frame after the cut with the take idle and the ball unfrozen.

## Failure

Exit 1 naming the seam when a stage is not ready or the launch never comes, no touchdown arrives within 8 s of the launch, a moment (full cover, cut, reveal, control) never comes, any frame is flat colour or under 50 KB, or no frame sits between full cover and the reveal's start. Exit 2 on a bad argument or a non-rendered display. A run that stalls ends at 400 s of wall time. `--selftest=1` adds a seam whose launch is never fired, to show the failure path.

## What it cannot show

The ball is put in motion by the tool and the launch is taken by choosing a reward, not by rolling through a gate, so the pre-launch frames show a calm roll and not a player's approach. The run is calm: no enemies. The flume to Slag Bowl touchdown and control can land on the same frame, because the boss module holds the ball until the take ends.
