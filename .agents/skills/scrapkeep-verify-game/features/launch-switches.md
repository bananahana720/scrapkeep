# Launch switches

The game takes switches after `--` on its command line that change what a run looks like or holds, so a candidate can be judged beside today's game without replacing it. Three of them carry work in review: the ball look, the Tripo models and the Stocktake yard. A switch that silently does nothing looks exactly like the game without it, so each is proven as a pair: one drive with the switch, one without.

## Sub-features

- `LS-1` `--ball-look=today|gyro|bell|cutaway`: every pilot's ball wears that look's shell; the default look is now `cutaway` (`tuning.gd`), so proving the switch on vs off compares `--ball-look=cutaway` (or `gyro`/`bell`) against `--ball-look=today`.
- `LS-2` `--models=tripo` (and `--models=tripo-all`): a model with an accepted `_tripo` sibling file loads the sibling; without it, or with no sibling, the authored file.
- `LS-3` `--stocktake=on`: the stage holds a Stocktake yard (a survival count) at one of the map's yard sites; without it there is none.

## How to get to it (user POV)

- Start the game with the switch after `--` and start a run ([Start a run](./start-a-run.md)). The ball look shows the moment the ball drops in. The Tripo props and the yard stand out in the map: the dam's survey tent, wheelhouse and mixer wreck are about 200 m from the drop, the yard at one of two sites.

## Driving it with drive.sh

Preconditions: `$S/doctor.sh` passes; the assets are imported since the stage last added models. `S=.agents/skills/scrapkeep-verify-game/scripts`.

- **All three, on:** `$S/drive.sh .agents/skills/scrapkeep-verify-game/features/steps/launch-switches.steps switches-on -- --no-intro --ball-look=cutaway --models=tripo --stocktake=on`. Expect exit 0 and 24 passed steps.
- **The control, off:** `$S/drive.sh .agents/skills/scrapkeep-verify-game/features/steps/launch-switches.steps switches-off -- --no-intro --ball-look=today` (because `cutaway` is now the default ball look; `stocktake` defaults to `off` and Tripo models default to off).
- **What the pair must show** (`steps.ndjson`, rows 15 to 22):

| Row | On | Off (`--ball-look=today`) |
| --- | --- | --- |
| `read tuning.option("ball_look")` | `cutaway` | `today` |
| `meshes "ball_look"` | 1, `ball_look_cutaway_cockpit.glb` at the ball | 0 |
| `read tuning.option("stocktake")` | `on` | `off` |
| `read world.activities.site("stocktake_yard") != null` | `true` | `false` |
| `meshes "_tripo"` (25 s into the stage) | 48 on the dam, the row names the first six files and where they stand | 0 |

- **The picture:** `14-in-play.png` of each drive, side by side. The ball is in the middle of the frame: plated with a window on the pilot under `cutaway`, today's shell without.
- **One switch alone, or another look:** pass only that switch; the rows for the others read as the control's.

## Gotchas

- `meshes` right at the drop counts 0 Tripo files: props load as the stage wakes. The step file waits 25 game seconds first.
- The Tripo props and the yard are too far from the drop to be in the picture, and a step file cannot steer the ball to them. The rows say the files are drawn and the yard is built; nobody has looked at them or played a count through this skill. A film of the bot (`bot-run.sh`, [A whole run](./whole-run.md)) passes some of them; Andrew's eye is the judge of the look.
- Enemies' models are cast into the game's own meshes and keep no file path, so `meshes "enemy_"` reads 0 either way. It cannot say whether the Tripo chaser is on.
- The yard's site is drawn from the run's seed; a new profile's first run drew the same site each time here, but do not write its position into a step.
- Software rendering: colour, light and the cutaway window's fringe are not the PC's. This proves the switch, never the look.
