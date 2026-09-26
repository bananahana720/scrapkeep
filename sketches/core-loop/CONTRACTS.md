# Core-loop contracts

This file is the seam between the spine and the four wave-2 modules. [DEMO-SPEC.md](DEMO-SPEC.md) owns the demo's progression rules (heft, plating, the Warden, cores); this file owns the seams that carry them. The spine builds the run, owns movement, flow and the shared records, and hands one context object to each module. Modules talk to the spine and to each other only through that context and the `GameEvents` bus. A module never loads, calls or edits a file in another module's folder.

## Ownership

| Owner | May edit | Tests |
| --- | --- | --- |
| Writer A, combat and classes | `src/combat/**` | `tests/combat_*.gd` |
| Writer B, build and growth | `src/build/**` | `tests/build_*.gd` |
| Writer C, audio and feel | `src/presentation/**` | `tests/presentation_*.gd` |
| Writer D, events and stages | `src/world/**` | `tests/world_*.gd` |
| Spine (frozen) | everything else: `project.godot`, `main.tscn`, `.gitignore`, `README.md`, this file, `src/game.gd`, `src/core/**`, `src/movement/**`, `src/ui/**`, `tests/spine_*.gd` | `tests/spine_*.gd` |

`DESIGN-NOTES.md` has one section per owner. Each writer appends only inside its own section, so four branches merge without conflicts.

A module needs a spine change, such as a new signal, a new camera hook, a field note or a README line? Put the exact request in the handoff under "requested shared-file changes". The coordinator applies it at integration. Do not edit spine files on a module branch.

Each module folder holds one entry script with `setup(ctx)`: `combat/combat.gd`, `build/build.gd`, `presentation/presentation.gd` and `world/world.gd`. The entry script extends `Node`. The root adds it as a child and calls `setup(ctx)` once, in this fixed order:

1. `world`, which must set `ctx.terrain`.
2. `combat`, which must set `ctx.spawner`.
3. `build`.
4. `presentation`.

`game.gd` asserts that `ctx.terrain` and `ctx.spawner` are set. The flow starts after all four are set up. Everything in a module folder may be replaced wholesale, as long as the entry script keeps its path and its obligations below.

## Rules every module follows

- Talk through `ctx` and `GameEvents` only. Do not `preload` another module's files.
- Change run state only through the `run` mutators. Each mutator publishes its own fact, so do not emit `scrap_collected`, `part_gained`, `player_hit`, `player_died`, `enemy_killed` or `milestone_won` yourself.
- Emit only the signals your row in the signal table names.
- A signal reports a committed result and applies nothing (TADR-008). Resolve an outcome once, then publish it. Presentation reads the publication.
- Momentum is sacred. Nothing a module does may stop or slow the ball in a way the player did not cause. Pickups, gates, fabricators and launches work at speed. `spine_run_test.gd` measures the gate and the launch, and the integration review looks for any other blocker.
- Honour `ctx.calm`. While it is true, spawn no enemies and apply no world pushes. The spine's momentum tests depend on it.
- Stay in play. Gameplay work runs only while `ctx.flow.in_play()` is true.
- Reset on `stage_entered(stage, retry)`. Clear stage content: enemies, gates, events and pickups. Rebuild it for `stage`. After a retry the run state is already restored, so recompute anything derived from `ctx.run.parts`.
- Add world children under `ctx.root`.

## The context (`src/core/context.gd`)

| Field | Type | Meaning |
| --- | --- | --- |
| `events` | `GameEvents` node | the bus |
| `run` | `RunState` | the run record; mutators below |
| `tuning` | `Tuning` | movement knobs; `f(key)`, `base(key)`, `set_mod(key, x)`, `mod(key)`, `clear_mods()`, `boost_cooldown_scale` |
| `player` | `PlayerBall` | the ball; hooks below |
| `camera` | `ChaseCamera` | the camera; hooks below |
| `flow` | flow node | read-only: `in_play()`, `state_name()`, `stage()`, `stage_def()`, `objective_text()` |
| `terrain` | set by world | the terrain API below |
| `spawner` | set by combat | the spawner API below |
| `root` | `Node3D` | parent for world children |
| `rng` | `RandomNumberGenerator` | the run's one seeded stream (seed 20260926) |
| `calm` | `bool` | tests set it; no spawns, no world pushes |
| `aim_origin()`, `aim_forward()` | `Vector3` | the camera's centre ray |
| `hit_stop(seconds)` | method | a short freeze for weight; capped at 60 ms, never stacks, only in play |

Flow states, as `state_name()` returns them: `title`, `class_select`, `stage`, `beacon`, `gates`, `launch`, `summary` and `dead`. `in_play()` is true for `stage`, `beacon`, `gates` and `launch`.

`stage_def()` returns the current row of `src/core/stage_defs.gd`, with these fields: `stage`, `name`, `threat` (a multiplier), `event_mix` (event id to weight), `scrap_density` (a multiplier), `beacon_seconds` and `beacon_radius`.

## Run state mutators (`src/core/run_state.gd`)

| Call | Effect | Publishes |
| --- | --- | --- |
| `add_scrap(amount, at)` | adds scrap | `scrap_collected(amount, at, total)` |
| `spend_scrap(amount) -> bool` | spends if affordable | nothing (the part it buys publishes `part_gained`) |
| `add_part(part_id, source)` | appends to `parts` | `part_gained(part_id, source)` |
| `set_max_hp(value)` | new ceiling; a raise heals by the gain | nothing |
| `heal(amount)` | heals up to the ceiling | nothing |
| `damage(amount, source)` | lowers HP | `player_hit(amount, source)`, then `player_died` at 0 |
| `record_kill(kind, at, scrap_value)` | counts a kill | `enemy_killed(kind, at, scrap_value)` |
| `record_milestone(event_id)` | counts an event won | `milestone_won(event_id)` |

Readable fields: `class_def` (a `ClassDef` resource: `id`, `display_name`, `weapon_id`, `special_id`, `color`, `pitch`), `stage`, `hp`, `max_hp`, `scrap`, `parts` (an array of part ids, one entry per stack), `kills`, `events_won`, `run_time`, `stage_time` and `retries`. Only flow calls `begin`, `snapshot`, `restore` and `advance`.

The stage-start snapshot holds `max_hp`, `hp`, `scrap`, `parts`, `kills`, `events_won`, the entry position, the entry velocity and the camera yaw. A retry restores all of them. Anything a module derives from parts, such as tuning mods or max HP, must be recomputable from `run.parts`. Make that recompute idempotent. `tuning.clear_mods()` followed by reapplying every part is the pattern.

## GameEvents signals (`src/core/game_events.gd`)

Every signal has a row in `event_kinds.gd` keyed by its name. `spine_event_kinds_test.gd` fails if one is missing.

| Signal | Arguments | Emitted by | Meaning |
| --- | --- | --- | --- |
| `run_started` | `class_id: String` | spine flow | a run began |
| `flow_changed` | `state: String` | spine flow | the flow state changed |
| `stage_entered` | `stage: int, retry: bool` | spine flow | a stage began or was retried; reset stage content now |
| `stage_cleared` | `stage: int` | spine flow | the launch flight ended and the stage is done |
| `run_ended` | `won: bool` | spine flow | the run finished (summary) |
| `beacon_charge_changed` | `fraction: float` | spine flow | beacon charge, 0 to 1; exactly `1.0` once per stage when it completes |
| `scrap_collected` | `amount: int, at: Vector3, total: int` | `run.add_scrap` | scrap taken |
| `part_gained` | `part_id: String, source: String` | `run.add_part` | a part was added; source is `gate`, `fabricator`, `milestone` or similar |
| `player_hit` | `amount: float, source: String` | `run.damage` | the player took damage |
| `player_died` | none | `run.damage` | HP reached zero |
| `enemy_killed` | `kind: String, at: Vector3, scrap_value: int` | `run.record_kill` | an enemy died |
| `milestone_won` | `event_id: String` | `run.record_milestone` | a participatory event was won |
| `jumped` | `air: bool` | spine ball | a jump; air is the double jump |
| `boosted` | `direction: Vector3` | spine ball | the ground boost fired |
| `dashed` | `direction: Vector3` | spine ball | the air dash fired |
| `landed` | `impact: float` | spine ball | a hard landing, in m/s of fall |
| `slammed` | `at: Vector3, strength: float, flatness: float` | spine ball | a slam landed; flatness 1 is flat ground |
| `grapple_fired` | `anchor: Vector3` | spine ball | the hook attached |
| `grapple_released` | none | spine ball | the hook let go |
| `mounted` | `at: Vector3, banked_speed: float` | spine ball | a pylon was planted; banked_speed is the speed it arrived with |
| `dismounted` | `velocity: Vector3` | spine ball | left the pylon; the velocity is the slingshot, zero for an E drop |
| `enemy_spawned` | `enemy: Node3D, kind: String` | A | an enemy entered the stage |
| `enemy_struck` | `enemy: Node3D, kind: String, force: float` | A (from `strike`) | a resolved hit; kind is `stomp`, `ram`, `slam`, `arc`, `turret` or `runner` |
| `shot_fired` | `weapon_id: String, from: Vector3, to: Vector3` | A | a weapon fired; the segment it drew |
| `special_used` | `special_id: String, at: Vector3` | A | a class special fired |
| `reward_offered` | `offers: Array` | B | gates are open or moved; offer records below |
| `reward_chosen` | `part_id: String` | B | a gate was taken, after `run.add_part` |
| `event_announced` | `event_id: String, seconds_until: float` | D | a stage event is coming |
| `event_started` | `event_id: String` | D | it is live |
| `event_ended` | `event_id: String, outcome: String` | D | outcome is `won`, `lost` or `passed` (for ambient events) |
| `launched` | `velocity: Vector3` | D | the ball was launched toward the next stage |
| `pressure_changed` | `pressure: float` | D | director pressure, 0 to 1, for music layers |

### The beacon, gate and launch handshake

1. Flow emits `beacon_charge_changed(1.0)` and enters `gates`.
2. B opens its gates and emits `reward_offered(offers)`. Each offer is a Dictionary with these keys: `part_id: String`, `at: Vector3` (the gate's ground centre), `facing: Vector3` (the way through, flat and unit length) and `width: float`. B emits `reward_offered` again whenever the gates move. `spine_run_test.gd` drives the ball through `offers[0]` using these records.
3. When the ball rolls through a gate, B calls `run.add_part(id, "gate")`, then emits `reward_chosen(id)`.
4. D launches the ball and emits `launched(velocity)`. D may launch from inside its own `reward_chosen` handler, before flow has heard `reward_chosen`. Flow accepts a launch in either `gates` or `launch`.
5. Flow counts `LAUNCH_FLIGHT` (0.6 s) of flight, emits `stage_cleared`, then enters the next stage. The entry keeps the ball's horizontal speed exactly, turns it onto the new stage's entry heading, keeps the vertical part, and drops the ball in from 14 m above the spawn. After stage 3 it emits `run_ended(true)` instead.

The launch must keep horizontal speed within 15%. Raising a slow ball to a floor speed counts as a gift, not a cost.

## event_kinds schema (`src/core/event_kinds.gd`)

`ROWS[signal_name]` is a Dictionary with these fields:

| Field | Values | Used by |
| --- | --- | --- |
| `group` | `movement`, `combat`, `economy`, `flow`, `event` | music and VFX families |
| `color` | a `Color` from `palette.gd` | HUD, VFX, legend |
| `shape` | `ring`, `diamond`, `square`, `chevron`, `arrow`, `burst`, `bar`, `star`, `cross`, `wave`, `none` | VFX and HUD glyphs, so colour never carries a fact alone |
| `sound` | a sound id, never empty | C's synth bank; kinds may share an id |
| `hud` | toast wording or `""`; placeholders `{stage}`, `{part}`, `{event}` | HUD toasts |
| `objective` | standing objective wording or `""`; placeholders `{distance}`, `{percent}` | the objective line |
| `priority` | 0 ambient, 1 feedback, 2 notable (toast), 3 critical (big toast, stinger on the beat) | HUD, audio mix |

Helpers: `EventKinds.row(kind)`, `color(kind)`, `priority(kind)`, `hud(kind, fields)`, `objective(kind, fields)`, and `TOAST_PRIORITY` (2). C bakes one sound per distinct `sound` id. To change a row, send a shared-file request.

## Spawner API (combat, `ctx.spawner`)

- `spawn_enemy(kind: String, at: Vector3) -> Node3D`. The kinds are `chaser`, `lobber` and `miniboss`, and A may add more. The call adds the enemy under `ctx.root`, wires its damage to `run.damage` and its death to `run.record_kill`, and emits `enemy_spawned`.
- `strike(enemy: Node3D, kind: String, force: float)` resolves one hit into damage and emits `enemy_struck`. The spine calls it for ball contacts: `stomp` (force is fall speed), `ram` (force is speed, at the fast tier or above) and `slam` (force is knockback after falloff). Combat's own weapons call it too.

Every enemy is in group `enemy`, is on physics layer 3, and implements `knock(direction: Vector3, force: float)` and `flash()`. The ball calls those two for contact physics, so collisions have weight whatever combat does with the damage.

## Terrain API (world, `ctx.terrain`)

Instance methods the spine and other modules may call:

- `height(x, z) -> float`
- `drop_point(x, z, clearance) -> Vector3`
- `spawn_point(stage) -> Vector3`
- `entry_heading(stage) -> Vector3` (flat, unit length)
- `beacon_point(stage) -> Vector3` (on the ground)
- `scrap_lines(stage) -> Array` (each entry is `[Vector2 from, Vector2 to]` on the ground plane)
- `contains(point) -> bool`
- `rescue_point(near) -> Vector3`

Flow calls `spawn_point`, `entry_heading` and `beacon_point` right after `stage_entered`. If D swaps the geometry per stage, do it synchronously inside the `stage_entered` handler. The world layer is physics layer 1; the grapple, pylon and camera all read it.

## Camera hooks (`src/movement/chase_camera.gd`)

- `shoulder_target: float` (0 to 1). Combat sets it: 1 while mounted, 0 otherwise. The rig eases `shoulder_blend` toward it, shortens the arm to 4.2 m and shifts the ball left of the crosshair.
- `punch_fov(amount_degrees, time)` adds field of view that bleeds away over `time`, capped at 20 degrees.
- `kick(direction: Vector3, amount)` knocks the camera along a world direction, and it springs back.
- `shake(amount, time = 0.4)` shakes the camera; the strongest shake wins.
- `aim_origin()`, `aim_forward()`, `yaw_basis()` and `yaw` are read-only for modules.

Juice follows the player's actions and must never hide the next threat. Keep punches and shakes short.

## Ball hooks (`src/movement/player_ball.gd`)

- `juice_node() -> Node3D` belongs to presentation. It follows the ball and never rotates. Scale it for squash and stretch, and parent trails or speed lines to it. The spine never writes it.
- `roll_node() -> Node3D` rolls with the ball's surface. Parent anything that should stick to the ball there, such as accreted scrap (B).
- `pylon_node() -> Node3D` is the drawn pylon, for plant and eject animation.
- `builtin_squash: bool` is the spine's landing squash. Presentation sets it false when it draws its own.
- `speed_tier() -> int` (0 walk, 1 cruise, 2 fast, 3 blazing), `speed_fraction() -> float`, `shown_position()`, `planar_velocity()`, `ball_position()`.
- `state` (`BallState`: `velocity`, `grounded`, `contact_normal`, `impact`, `tier`) and `kit` (`AugmentKit`: `mounted`, `mount_banked`, `mount_point`, `mount_normal`, `hooked`, `gliding`, `slamming`) are read-only.
- `intent` holds this tick's input. Combat reads `fire_pressed`, `fire_held` and `special_pressed`. The spine fills it.
- `add_external_accel(accel)` adds a push in m/s², accumulated per physics tick and spent once. The world uses it for the flood. It does nothing while the ball is planted or mounted.
- `set_velocity_now(velocity)` sets velocity for a launch. Only D's launch uses it.

## Tests

- Name module tests `tests/combat_*.gd`, `tests/build_*.gd`, `tests/presentation_*.gd` and `tests/world_*.gd`.
- A test extends `SceneTree`, prints one line per check in the form `[check] detail -> PASS` or `-> FAIL`, then a final `<name>: PASS` line, and quits 0 or 1.
- Never print a line that starts with `ERROR` or `FAIL`. The smoke runner treats those as failures.
- Build the game with `Game.new()`, set `test_mode = true`, add it to `root` and wait for `flow` to be set. Drive input with `Intent.Scripted` (`hold` and `press`). Set `ctx.calm` when measuring speed.
- `npm run sketch:smoke` runs every sketch's import, a 300-frame boot and every test. All the `spine_*` tests must keep passing with your module installed.
