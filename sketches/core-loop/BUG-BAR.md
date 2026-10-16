# Alpha bug bar

How to grade a bug found while playing the alpha, and what the alpha can ship with. The acceptance rule comes from the alpha goal Andrew adopted on 16 Oct 2026; the severity lines and the area mapping are Claude's default, open to his change.

## Acceptance rule

The alpha is accepted when all three hold:

1. No verdict area is "Not yet". The 11 areas: core feel, Wardens and bosses, in-run growth, progression across runs, pilots, stage and world design, look, sound and music, clarity, difficulty and pacing, stability.
2. No crash or blocker bug is open.
3. Five first-time players reach the end of world one unaided.

## Severity

| Severity | What it is | Examples | Effect on the alpha |
| --- | --- | --- | --- |
| Blocker | Stops a player finishing a run, loses their progress, or stops the game starting | Crash or freeze. A soft-lock: stuck with no way on but quitting. A Warden or boss that cannot be beaten. Lost or corrupted save. The AppImage or app-menu entry does not open the main menu. A main-menu item that leads nowhere. Input stops responding | Fails the alpha while open. Fix before the sitting closes |
| Major | Hurts one of the 11 areas, but a player can get past it | A hitch over 33 ms that repeats at the same spot, or any during the stage-swap launch flight. Frame p99 over 16.7 ms across a stage. A telegraph that does not match where damage lands. A stuck spot that a restart clears. A missing sound or music cue. A placeholder model or text on screen. An unlock or cosmetic that does not save | The area can be "Accept with fixes" at best while it is open |
| Minor | Noticeable, does not change how the game plays | One hitch at a load or menu change. Clipping, z-fighting, a typo, a slightly wrong colour | Does not hold back any verdict. Batch for a later wave |

When unsure between two severities, pick the higher one. A crash is always a blocker, even if it happened once.

## Frame-time budget

These numbers come from the repo. Measure on Andrew's PC at 1920x1080.

| Measure | Budget | Source |
| --- | --- | --- |
| Frame time p99 in play | at most 16.7 ms (60 fps), dense fights included | `design-v2/visual-development/README.md` and `ITERATION.md`, the demo requirement |
| Any single frame | none over 33 ms in play; none during the stage-swap launch flight | `design-v3/PARK.md` section 9, stage swap |
| Next stage ready | within 20 s of Warden engage | `design-v3/PARK.md` section 9 |
| CPU main thread p99 | at most 10 ms | `scripts/checkpoint.mjs`, perf band (perf bench, not MangoHud) |
| GPU p99 | at most 7 ms | `scripts/checkpoint.mjs`, perf band (perf bench, not MangoHud) |

Frames over 50 ms are counted separately, as `ITERATION.md` asks.

## Measuring frame times in a sitting

MangoHud is a Linux overlay that shows and logs frame times. Install it once with `sudo pacman -S mangohud`, then:

```bash
node scripts/frametime-check.mjs
```

It launches the installed AppImage, or else the newest `npm run sketch:export` build, under MangoHud, logs every frame for 5 minutes after a 10-second warm-up, and prints PASS or OVER BUDGET with the time of each frame over 33 ms. The log and `summary.json` go to `artifacts/local/frametime/<time>/`. Play past the 5 minutes, then quit. `--seconds=<n>` changes the log length, `--exe=<path>` picks another build, `--log=<csv>` grades an existing log, and anything after `--` goes to the game.

The script turns vsync off so the numbers show headroom, as the perf bench does. `--keep-vsync` measures what the player sees instead; on a 60 Hz display that pins p99 near 16.7 ms.

An OVER BUDGET result is not itself a bug grade. Match each listed time to what was on screen, then grade it with the table above.

## Filing a bug

One line in playtest entry 13: severity, area, what happened, how to make it happen again, and the build (the sha in `HOW-TO-RUN.txt`). Add the `summary.json` path for a frame-time bug. Each blocker and major becomes a card for the wave coordinator.
