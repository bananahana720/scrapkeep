# Dev Console Command Reference

In-game console sources live under `sketches/core-loop/src/dev/` (`sketches/core-loop/src/dev/dev_console.gd`, `sketches/core-loop/src/dev/dev_commands.gd`, `sketches/core-loop/src/dev/dev_fight.gd`, `sketches/core-loop/src/dev/dev_lens.gd`, `sketches/core-loop/src/dev/dev_look.gd`, plus `DevInspect`, `DevAgent`, `DevOverlay`, and `DevSession`). Separate chained commands with `;`.

## Flow, time, and navigation

| Command | Purpose |
| --- | --- |
| `run [pilot]` / `pilot <idx\|id>` | Start a run from the title screen (`1` = Sable) |
| `pick <card>` | Take an open start card or kit card (`1` = left) |
| `unpause` | Close the pause menu |
| `stage <1..6\|dam\|flume\|pit\|sinkhole\|islands\|crown>` | Jump directly into a stage |
| `boss [phase]` | Enter the current world's boss arena, or jump to phase `1..4` |
| `retry` | Retry the current stage or boss |
| `seed <n>` | Override run seed and RNG seed |
| `warp <x> <z> \| spawn \| beacon \| landmark \| moss \| vault \| warden \| ahead [m]` | Place the ball via `PlayerBall.reset_to` |
| `vel <vx> <vy> <vz>` / `speed <m/s>` | Set ball velocity directly |
| `time <scale>` / `freeze` | Scale time (`0.05..4.0`) or toggle `freeze_for_dev` photo mode |
| `wait <frames>` | Await `N` process frames |
| `tick <n>` | Advance exact `N` physics ticks (even while frozen; refuses if menu/workshop paused) |
| `until <state\|play\|enemies\|event> <val> [max_frames]` | Wait until a condition matches or max frames elapse |
| `quit` | Exit cleanly after flushing receipt/response |

## Combat, build, and quality

| Command | Purpose |
| --- | --- |
| `spawn <kind> [count] [affix]` / `kinds [world]` | Spawn enemies ahead of the ball or list available kinds |
| `clear [hard]` | Kill living enemies (`hard` removes posture-gated Wardens/boss parts) |
| `calm [on\|off]` | Silence director packs, Warden pushes, floods, and events |
| `god [on\|off]` / `heal` / `damage <n>` | Invulnerability, full heal, or direct hull damage |
| `scrap <n>` / `cogs <n>` | Grant scrap at the ball or cogs |
| `give <part_id> [count]` / `parts [list\|clear]` | Grant, list, or clear build parts |
| `panel <panel_id> <tier>` | Adjust build panel tiers |
| `quality <low\|medium\|high\|ultra>` | Switch graphics preset live |

## Inspection, events, and assertions (`DevInspect`)

- `inspect <topic>`: returns structured JSON data for:
  - `state`: flow state, stage, world, seed, run time, pause/calm/freeze flags
  - `player`: `ball_position`, `shown_position`, velocity, speed, hp/max_hp, heft, scrap, cogs
  - `enemies`: active enemy list (kind, hp, position, affix, posture)
  - `warden` / `boss`: active Warden or boss phase, hp, staggered, chunks, hazards, floor
  - `telegraphs`: active threat descriptors and ball-containment checks
  - `build`: parts, panel counts, relics, synergies, punch/power
  - `look` / `lens`: current look overrides + active passes, camera mode/knobs
  - `perf`: fps, process/physics ms, draws, objects, primitives, memory, emitting particles
  - `prims`: visible `PrimitiveMesh` census
  - `ui`: visible `Control` nodes with text and rects
  - `events`: recent signal ring buffer (up to 256 entries)
  - `anomalies`: non-finite positions/velocities across player, camera, enemies, telegraphs, and run anomalies
- `events <on|off|tail [n]|clear>`: control the event ring buffer (auto-enabled under `DevAgent`).
- `assert <check>`:
  - `assert finite` / `assert no_anomalies`
  - `assert state <name>` / `assert stage <n>`
  - `assert enemies <op> <n>` (or `assert enemies <n>`)
  - `assert hp <op> <n>` / `assert draws <op> <n>`
  - `assert event <signal> [min_count]` / `assert no_event <signal>`
  - `assert expr <godot_expr>`

## Look, lens, overlays, and captures

- **Look / Paint / Print**: `look [preset]`, `presets`, `set <key> <value>`, `reset <key|all>`, `colour <ink|paper|riso_a|riso_b> <#hex>`, `bake <name>`, `load <name>`, `baked`.
- **Lens**: `cam <game|orbit|iso|side|top|hero|high|cinema>` or `cam <fov|distance|pitch|yaw|size|lift|spin|tilt|cut> <value>`, `ortho [on|off]`, `hud [on|off]`.
- **Overlays (`DevOverlay`)**: `overlay <all|none|bounds|telegraphs|spawns|sight|nav|vel|off>` draws 3D/HUD debug geometry over the live frame.
- **Captures**: `shot [name]` saves a single PNG without the console drawer; `sheet [presets|cams|quality] [name]` captures a labeled contact sheet into `--dev-out` (or `user://dev_shots`).

## In-process GDScript `DevSession`

For headless GDScript probes and tests inside `sketches/core-loop`, `DevSession` wraps boot, command execution, ticking, inspection, assertions, and teardown with zero static state:

```gdscript
var s := await DevSession.start(self, {"table": "park", "seed": 7, "pilot": 1, "calm": true})
await s.exec("spawn chaser 2")
await s.tick(30)
var enemies: Dictionary = s.inspect("enemies")
s.assert_ok("assert finite")
s.close()
```
