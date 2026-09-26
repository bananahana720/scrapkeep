# Core-loop contracts

This file is the seam between the spine and the five modules: the four from wave 2 (combat, build, presentation, world) and the wave-4 boss. [DEMO-SPEC.md](DEMO-SPEC.md) owns the demo's progression rules: heft, plating, the Warden, cores, the codex and the run log. This file owns the seams that carry them. The spine builds the run, owns movement, flow and the shared records, and hands one context object to each module. Modules talk to the spine and to each other only through that context and the `GameEvents` bus. A module never loads, calls or edits a file in another module's folder.

## Ownership

| Owner | May edit | Tests |
| --- | --- | --- |
| Writer A, combat and classes | `src/combat/**` | `tests/combat_*.gd` |
| Writer B, build and growth | `src/build/**` | `tests/build_*.gd` |
| Writer C, audio and feel | `src/presentation/**` | `tests/presentation_*.gd` |
| Writer D, events and stages | `src/world/**` | `tests/world_*.gd` |
| Writer E, the boss (wave 4) | `src/boss/**` | `tests/boss_*.gd` |
| Spine (frozen) | everything else: `project.godot`, `main.tscn`, `.gitignore`, `README.md`, this file, `DEMO-SPEC.md`, `src/game.gd`, `src/core/**`, `src/movement/**`, `src/ui/**`, `tests/spine_*.gd`, `tests/doubles/**` | `tests/spine_*.gd` |

`DESIGN-NOTES.md` has one section per owner. Each writer appends only inside its own section, so the module branches merge without conflicts.

A module needs a spine change, such as a new signal, a new camera hook, a field note or a README line? Put the exact request in the handoff under "requested shared-file changes". The coordinator applies it at integration. Do not edit spine files on a module branch.

Each module folder holds one entry script with `setup(ctx)`: `combat/combat.gd`, `build/build.gd`, `presentation/presentation.gd` and `world/world.gd`. The entry script extends `Node`. The root adds it as a child and calls `setup(ctx)` once, in this fixed order:

1. `world`, which must set `ctx.terrain`.
2. `combat`, which must set `ctx.spawner`.
3. `build`, which sets `ctx.build`.
4. `boss` (`src/boss/boss.gd`), which sets `ctx.boss`. It is set up only when the file exists (`ResourceLoader.exists`), so the run works without it and ends on the summary after stage 3.
5. `presentation`.

`game.gd` asserts that `ctx.terrain` and `ctx.spawner` are set. The codex (`ctx.codex`) exists before any module is set up, so modules can declare their entries in `setup`. The flow starts after every present module is set up. Everything in a module folder may be replaced wholesale, as long as the entry script keeps its path and its obligations below.

## Rules every module follows

- Talk through `ctx` and `GameEvents` only. Do not `preload` another module's files.
- Change run state only through the `run` mutators. Each mutator publishes its own fact, so do not emit `scrap_collected`, `scrap_lost`, `part_gained`, `player_hit`, `player_died`, `enemy_killed`, `milestone_won`, `heft_class_changed` or `core_gained` yourself. The same goes for the codex: call its mutators, and never emit `synergy_discovered` or `interaction_found` directly.
- Emit only the signals your row in the signal table names.
- A signal reports a committed result and applies nothing (TADR-008). Resolve an outcome once, then publish it. Presentation reads the publication.
- Momentum is sacred. Nothing a module does may stop or slow the ball in a way the player did not cause. Pickups, gates, fabricators and launches work at speed. `spine_run_test.gd` measures the gate and the launch, and the integration review looks for any other blocker.
- A foreseen, telegraphed cost from the player's own performance is allowed; an unforeseen stop is not.
- Every new mechanic names in its DESIGN-NOTES line the stage demand it serves (Warden, event, vault, boss phase) and the principle it strains; a mechanic that serves none is parked, not built.
- Heft never changes RigidBody mass, radius, torque or air control. It scales punch, which combat reads; the ball handles the same at every heft (`spine_heft_test.gd`).
- An enemy records its kill (`run.record_kill`) on the same tick its HP reaches 0, and a crushed or killed enemy drops its collision layer on that tick, so nothing solid lingers where a kill already happened.
- Honour `ctx.calm`. While it is true, spawn nothing on your own schedule and apply no world pushes. The spine's momentum tests depend on it. The spawner itself does not check `calm`; callers that spawn on their own schedule do.
- **Stage content runs only in a stage.** Stage content means the director, the flood cycle and its pushes, stage events, the scrap field, fabricators, vaults and stage enemies. It runs only while `ctx.flow.in_stage()` is true, which covers `stage`, `beacon`, `gates` and `launch`.
- **Player-side work runs in play.** Player weapons, build synergies and presentation run while `ctx.flow.in_play()` is true, which adds the boss arena.
- **Stand down on `stage_content_cleared`.** Flow publishes `stage_content_cleared(reason)` on entering the arena and on each arena retry, with the reason `arena`. Each module then clears its stage content at once:
  - combat clears stage enemies;
  - world stops its director and flood and parks the stage maps;
  - build clears pickups and fabricators.
- Reset on `stage_entered(stage, retry)`. Clear stage content: enemies, gates, events and pickups. Rebuild it for `stage`. After a retry the run state is already restored, so recompute anything derived from `ctx.run.parts`. Flow takes the stage-start checkpoint before it publishes `stage_entered`, so anything a module grants inside that handler is play within the stage, and a retry takes it back.
- Add world children under `ctx.root`.
- Build owns all tuning mods. It calls `tuning.clear_mods()` on every recompute and reapplies every part. Keys that are not F1 sliders (`weapon_damage`, `weapon_rate`, `weapon_range`, `turret_damage` and any similar key) are read with `tuning.mod(key)`, never `tuning.f(key)`.

## The context (`src/core/context.gd`)

| Field | Type | Meaning |
| --- | --- | --- |
| `events` | `GameEvents` node | the bus |
| `run` | `RunState` | the run record; mutators below |
| `tuning` | `Tuning` | movement knobs; `f(key)`, `base(key)`, `set_mod(key, x)`, `mod(key)`, `clear_mods()`, `boost_cooldown_scale` |
| `player` | `PlayerBall` | the ball; hooks below |
| `camera` | `ChaseCamera` | the camera; hooks below |
| `flow` | flow node | read-only: `in_play()`, `in_stage()`, `state_name()`, `stage()`, `stage_def()`, `objective_text()`, `sealed`, `warden`, `punch_now()`, `warden_plating()`, `gap_line()` |
| `terrain` | set by world | the terrain API below |
| `spawner` | set by combat | the spawner API below |
| `build` | set by build | the build module; read it through `has_method`. `build_module()` also reads a build that stored itself with `ctx.set_meta("build", self)` |
| `codex` | `Codex` node | the codex registry below |
| `boss` | set by boss | the boss module; flow calls `enter_arena(entry_velocity)` on it |
| `root` | `Node3D` | parent for world children |
| `rng` | `RandomNumberGenerator` | the run's one seeded stream (seed 20260926) |
| `calm` | `bool` | tests set it; no own-schedule spawns, no world pushes |
| `aim_origin()`, `aim_forward()` | `Vector3` | the camera's centre ray |
| `hit_stop(seconds)` | method | a short freeze for weight; capped at 60 ms, never stacks, only in play |

Flow states, as `state_name()` returns them: `title`, `class_select`, `stage`, `beacon`, `gates`, `launch`, `boss`, `victory`, `summary` and `dead`. `in_play()` is true for `stage`, `beacon`, `gates`, `launch` and `boss`.

`stage_def()` returns the current row of `src/core/stage_defs.gd`, with these fields:

- `stage`, `name`.
- `threat` (a multiplier) and `event_mix` (event id to weight).
- `scrap_density` (a multiplier).
- `beacon_seconds` and `beacon_radius`, used only by the unsealed presence path.
- `warden_plating` (30, 60, 95), `warden_hp` (400, 700, 1000), `warden_lesson` (`plate`, `caps`, `magnet`) and `warden_hint` (the objective line's last sentence).

Every number there is a starting value; tuning edits `stage_defs.gd`, the heft constants in `run_state.gd` and the part catalogue.

## Run state (`src/core/run_state.gd`)

| Call | Effect | Publishes |
| --- | --- | --- |
| `add_scrap(amount, at)` | adds to the wallet and to mass | `scrap_collected(amount, at, total)`, then `heft_class_changed` if the class rose |
| `spend_scrap(amount) -> bool` | spends from the wallet if affordable; mass is unchanged | nothing (the part it buys publishes `part_gained`) |
| `lose_scrap(amount, at, cause) -> int` | lowers mass by `amount` (not below 0) and the wallet by what it holds; returns the mass taken | `scrap_lost(taken, at, wallet_total, cause)`, then `heft_class_dropped` if the class fell |
| `add_part(part_id, source)` | appends to `parts` | `part_gained(part_id, source)`, then `heft_class_changed` if the class rose |
| `add_core(source, at)` | adds a stage-scoped bonus core | `core_gained(source, at, count)` |
| `set_max_hp(value)` | new ceiling; a raise heals by the gain | nothing |
| `heal(amount)` | heals up to the ceiling | nothing |
| `damage(amount, source)` | lowers HP | `player_hit(amount, source)`, then `player_died` at 0 |
| `record_kill(kind, at, scrap_value)` | counts a kill | `enemy_killed(kind, at, scrap_value)` |
| `record_milestone(event_id)` | counts an event won | `milestone_won(event_id)` |

These fields and methods are readable:

- `class_def`, a `ClassDef` resource with `id`, `display_name`, `weapon_id`, `special_id`, `color` and `pitch`.
- `run_id`, `stage`, `hp`, `max_hp`, `scrap` (the wallet), `mass`, `parts` (an array of part ids, one entry per stack), `bonus_cores`, `kills`, `events_won`, `run_time`, `stage_time` and `retries`.
- `heft()`, which is `1 + mass/150 + 0.2 * parts.size()`.
- `heft_class()`, which returns 1 to 5 (classes start at heft 1.0, 1.5, 2.2, 3.2 and 4.6), and `heft_progress()`, the share of the way to the next class.
- `gate_tier_bonus()`, which returns 0, 1 or 2 for 0, 1 or 2+ bonus cores. Build reads it when it builds its offers.
- `RunState.roman(n)`, a class numeral for display.

Only flow calls `begin`, `enter_stage`, `snapshot`, `restore`, `use_stage_start` and `advance`.

The stage-start snapshot holds `max_hp`, `hp`, `scrap`, `mass`, `bonus_cores`, `parts`, `kills`, `events_won`, the entry position, the entry velocity and the camera yaw. A retry restores all of them, and it changes the heft class silently, with no stinger. The run also keeps the first start of each stage, which `flow.replay_stage(index)` restores. Bonus cores reset when a stage begins. Anything a module derives from parts, such as tuning mods or max HP, must be recomputable from `run.parts`. Make that recompute idempotent. `tuning.clear_mods()` followed by reapplying every part is the pattern.

## GameEvents signals (`src/core/game_events.gd`)

Every signal has a row in `event_kinds.gd` keyed by its name. `spine_event_kinds_test.gd` fails if one is missing, if a row has no sound, or if an objective uses the word "optional".

| Signal | Arguments | Emitted by | Meaning |
| --- | --- | --- | --- |
| `run_started` | `class_id: String` | spine flow | a run began |
| `flow_changed` | `state: String` | spine flow | the flow state changed |
| `stage_entered` | `stage: int, retry: bool` | spine flow | a stage began or was retried; reset stage content now |
| `stage_cleared` | `stage: int` | spine flow | the launch flight ended and the stage is done |
| `run_ended` | `won: bool` | spine flow | the run finished (summary) |
| `beacon_charge_changed` | `fraction: float` | spine flow | beacon charge, 0 to 1; while sealed, the share of the Warden broken; exactly `1.0` once per stage when the gates open |
| `beacon_unsealed` | `stage: int` | spine flow | the Warden broke; the gates open wherever the ball is |
| `warden_engaged` | `stage: int` | spine flow | first sealed ring entry or first strike on the Warden, once per stage attempt |
| `stage_content_cleared` | `reason: String` | spine flow | stage content must stand down now (reason `arena`: entering the boss arena or retrying it); quiet, priority 0 |
| `scrap_collected` | `amount: int, at: Vector3, total: int` | `run.add_scrap` | scrap taken |
| `scrap_lost` | `amount: int, at: Vector3, total: int, cause: String` | `run.lose_scrap` | mass taken (a crane theft); total is the wallet |
| `part_gained` | `part_id: String, source: String` | `run.add_part` | a part was added; source is `gate`, `fabricator`, `vault`, `milestone` or similar |
| `heft_class_changed` | `heft_class: int, heft: float` | run mutators | the heft class rose (never on a restore); sound `class_up` |
| `heft_class_dropped` | `heft_class: int, heft: float` | run mutators | the heft class fell after a theft (never on a restore); sound `class_down` |
| `core_gained` | `source: String, at: Vector3, count: int` | `run.add_core` | a bonus core; count is this stage's total |
| `player_hit` | `amount: float, source: String` | `run.damage` | the player took damage |
| `player_died` | none | `run.damage` | HP reached zero |
| `enemy_killed` | `kind: String, at: Vector3, scrap_value: int` | `run.record_kill` | an enemy died; kind `warden` unseals the beacon |
| `milestone_won` | `event_id: String` | `run.record_milestone` | a participatory event was won |
| `synergy_discovered` | `synergy_id: String, category: String, first_time: bool` | `codex.mark_discovered` | a named codex entry fired for the first time this run; first_time means the saved codex had never seen it |
| `interaction_found` | `description: String` | `codex.mark_found` | an unnamed interaction fired for the first time this run |
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
| `strike_deflected` | `enemy: Node3D, kind: String, punch: float, plating: float` | A | a hit below plating chipped for 20% |
| `shot_fired` | `weapon_id: String, from: Vector3, to: Vector3` | A | a weapon fired; the segment it drew |
| `special_used` | `special_id: String, at: Vector3` | A | a class special fired |
| `reward_offered` | `offers: Array` | B | gates are open or moved; offer records below |
| `reward_chosen` | `part_id: String` | B | a gate was taken, after `run.add_part` |
| `element_resolved` | `element_id: String, material_id: String, behaviour: String, at: Vector3` | B | an element met a material (TADR-009); C picks the sound by behaviour (freeze, electrify, shatter) |
| `event_announced` | `event_id: String, seconds_until: float` | D | a stage event is coming |
| `event_started` | `event_id: String` | D | it is live |
| `event_ended` | `event_id: String, outcome: String` | D | outcome is `won`, `lost` or `passed` (for ambient events) |
| `launched` | `velocity: Vector3` | D | the ball was launched toward the next stage |
| `pressure_changed` | `pressure: float` | D | director pressure, 0 to 1, for music layers |
| `threat_rose` | `tier: int` | D | the director's time tier rose (clamped at +2) |
| `boss_arena_entered` | none | E | the ball is in the arena; the music's Brindle set starts |
| `boss_phase_changed` | `phase: int, name: String` | E | Brindle's phase (1 to 3) and its display name; the run log keeps the highest |
| `boss_attack_telegraphed` | `attack_id: String, seconds_until: float` | E | an attack is committed and will land in seconds_until |
| `boss_weak_point_hit` | `point_id: String` | E | a strike landed on a weak point (a magnet, a cap, the scooter) |
| `boss_defeated` | none | E | Brindle is beaten; flow enters `victory`, then the summary |

### The Warden, gate and launch handshake

1. **The Warden seals the beacon.**
   - **Spawning.** In play (`not ctx.calm`, or `flow.force_warden` in tests), flow spawns one through `ctx.spawner.spawn_enemy("warden", ctx.terrain.beacon_point(stage))` right after `stage_entered`.
   - **Charge.** Rolling into the ring marks the beacon engaged but adds no charge. Every tick the charge shown is `1 - ctx.spawner.integrity_of(warden)`, capped at 0.99, so `1.0` is only ever published by the unseal.
   - **Unseal.** When `enemy_killed` arrives with kind `warden` and it is this stage's Warden, flow emits `beacon_unsealed(stage)`, enters `gates` and emits `beacon_charge_changed(1.0)`, wherever the ball is. "This stage's Warden" means `integrity_of(warden)` reads 0, or, for a spawner without `integrity_of`, the kill happened within 6 m of where it stood.
   - **Vanished Warden.** If the Warden leaves the tree with no kill recorded, flow unseals the same way, warns once, and adds a `warden_vanished` anomaly to the run log. If the spawner returns no Warden, or the stage is calm, the stage stays on the unsealed presence path: circling inside the ring charges it over `beacon_seconds`, then flow enters `gates` and emits `beacon_charge_changed(1.0)`.
2. B opens its gates and emits `reward_offered(offers)`. Each offer is a Dictionary with these keys: `part_id: String`, `at: Vector3` (the gate's ground centre), `facing: Vector3` (the way through, flat and unit length) and `width: float`. B reads `ctx.run.gate_tier_bonus()` when it builds the offers. B emits `reward_offered` again whenever the gates move. `spine_run_test.gd` drives the ball through `offers[0]` using these records.
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
| `shape` | `ring`, `diamond`, `square`, `chevron`, `arrow`, `burst`, `bar`, `star`, `cross`, `wave`, `core`, `none` | VFX and HUD glyphs, so colour never carries a fact alone |
| `sound` | a sound id, never empty | C's synth bank; kinds may share an id |
| `hud` | toast wording or `""`; placeholders `{stage}`, `{part}`, `{event}`, `{class}`, `{name}` | HUD toasts |
| `objective` | standing objective wording or `""`; placeholders `{distance}`, `{percent}`, `{punch}`, `{plating}`, `{hint}`; never the word "optional" | the objective line |
| `priority` | 0 ambient, 1 feedback, 2 notable (toast), 3 critical (big toast, stinger on the beat) | HUD, audio mix |

`CODEX_CATEGORIES[category]` gives each codex category a `label`, `color` and `shape`, and says whether it is `reserved` (`npc` and `coop` are, until the demo has either). The Tab codex pages, a discovery banner and a Found line all read it.

Helpers: `EventKinds.row(kind)`, `color(kind)`, `priority(kind)`, `hud(kind, fields)`, `objective(kind, fields)`, `category(id)`, and `TOAST_PRIORITY` (2). C bakes one sound per distinct `sound` id. To change a row, send a shared-file request.

## Spawner API (combat, `ctx.spawner`)

Per-kind stats, transformer ids and `register_part` are documented in `src/combat/README.md`.

- `spawn_enemy(kind: String, at: Vector3) -> Node3D`. The kinds are `chaser`, `lobber`, `miniboss`, `warden` and `vault`, and A may add more. The call adds the enemy under `ctx.root`, wires its damage to `run.damage` and its death to `run.record_kill`, and emits `enemy_spawned`. It does not check `ctx.calm`.
- `strike(enemy: Node3D, kind: String, force: float)` resolves one hit into damage against plating and emits `enemy_struck`, plus `strike_deflected` below plating. The spine calls it for ball contacts: `stomp` (force is fall speed), `ram` (force is speed, at the cruise tier or above) and `slam` (force is knockback after falloff). Combat's own weapons call it too.
- `punch_now() -> float` is the punch the player would land now: ram punch at the ball's planar speed from the cruise tier up, or the current weapon's per-hit damage, whichever is larger.
- `plating_of(enemy) -> float`.
- `integrity_of(enemy) -> float` is HP over max HP, or 1.0 for an invalid enemy.
- `would_crush(enemy, kind, force) -> bool` is true when the enemy has no plating and the hit would kill it.

The spine calls all of these defensively (`has_method`). The fallbacks are integrity 1.0, punch 0, plating 0 and would_crush false. The one exception is the objective line and gap line, which show the stage's `warden_plating` when the spawner cannot say.

Every enemy is in group `enemy`, is on physics layer 3, and implements `knock(direction: Vector3, force: float)` and `flash()`. The ball calls those two for contact physics, so collisions have weight whatever combat does with the damage.

## Terrain API (world, `ctx.terrain`)

Instance methods the spine and other modules may call:

- `height(x, z) -> float`
- `drop_point(x, z, clearance) -> Vector3`
- `spawn_point(stage) -> Vector3`
- `entry_heading(stage) -> Vector3` (flat, unit length)
- `beacon_point(stage) -> Vector3` (on the ground; the Warden spawns here on every map)
- `scrap_lines(stage) -> Array` (each entry is `[Vector2 from, Vector2 to]` on the ground plane)
- `contains(point) -> bool`
- `rescue_point(near) -> Vector3`
- `material_at(point: Vector3) -> Dictionary`, which returns `{"material": "water" | "concrete" | "sand", "surface_y": float}` or `{}` where unknown. The Dictionary is the settled shape, because ice needs the surface height. D implements it. Until it does, build falls back to `build.register_material("water", provider)`.

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
- `roll_node() -> Node3D` rolls with the ball's surface. Parent anything that should stick to the ball there, such as accreted scrap (B). The shell may grow visually; the collider never does.
- `pylon_node() -> Node3D` is the drawn pylon, for plant and eject animation.
- `builtin_squash: bool` is the spine's landing squash. Presentation sets it false when it draws its own.
- `speed_tier() -> int` (0 walk, 1 cruise, 2 fast, 3 blazing), `speed_fraction() -> float`, `shown_position()`, `planar_velocity()`, `ball_position()`.
- `state` (`BallState`: `velocity`, `grounded`, `contact_normal`, `impact`, `tier`) and `kit` (`AugmentKit`: `mounted`, `mount_banked`, `mount_point`, `mount_normal`, `hooked`, `gliding`, `slamming`) are read-only.
- `intent` holds this tick's input. Combat reads `fire_pressed`, `fire_held` and `special_pressed`. The spine fills it.
- `add_external_accel(accel)` adds a push in m/s², accumulated per physics tick and spent once. It does nothing while the ball is planted or mounted. Its users:
  - the world, for the flood;
  - combat, for the shove of a committed, telegraphed hit;
  - the Warden pulse and the magnet tug.

  A foreseen shove is an allowed performance cost. To turn a velocity change into an acceleration, divide it by the physics step actually run (the `delta` your `_physics_process` receives), never by `physics_ticks_per_second`: hit-stop changes `Engine.time_scale`, which would otherwise scale the push.
- `set_velocity_now(velocity)` sets velocity. Only D's launch uses it. The launch calls it every tick during the flight, as a rail, not once.
- `crush_check` (a Callable) is wired by `game.gd` to `ctx.spawner.would_crush`. A bow sensor a metre past the shell asks it for each enemy met from the cruise tier up. On yes, the ball ignores that enemy for 0.3 s and reports one `ram` strike, with no knock, shockwave or hit-stop.

## Flow seams (`src/core/flow.gd`)

- `force_warden` is a test knob: it seals calm stages.
- **The boss flow.**
  - **Arena entry.** After stage 3's launch flight, flow emits `stage_cleared(3)`. If `ctx.boss` exists it then enters `boss`, calls `ctx.boss.enter_arena(entry_velocity)` with the ball's velocity, and keeps an arena-entry checkpoint (the stage-3-end snapshot) once the call returns. The boss module builds its arena under `ctx.root`, places the ball keeping that velocity (entry must keep speed within 15%), and emits `boss_arena_entered`. The world's terrain API and the fall rescue are not used in the arena.
  - **Win.** `boss_defeated` in `boss` leads to `victory` for 2.5 s, then the summary and `run_ended(true)`.
  - **Death.** A death in `boss` leads to `dead`. There, R (or holding R in play) restores the arena-entry checkpoint and calls `enter_arena` again, T calls `replay_stage(3)` and restores the first stage-3 start the run kept, and N starts a new run.
  - **Boss seams.** The boss module sets `ctx.flow.boss_active` and `ctx.flow.boss_plating` (hull plating 120) on entry. The death screen reads them for its gap line and for offering T. `flow.in_arena` is read-only.
  - **Arena fall rescue (owner: E, the boss module).** The boss module implements `floor_y() -> float` and `rescue_point() -> Vector3`. Every tick in `boss`, flow checks the ball against `floor_y()`. Below it, flow puts the ball at `rescue_point()` keeping its horizontal speed, with no damage, like the stage rescue. If the boss module lacks either method, flow warns once and uses 40 m below the arena-entry checkpoint as the floor and the entry position as the landing.
- `discovery_burst(at)` grants 20 scrap times the stage at a discovery. The codex calls it, once per entry per run.

## Codex (`src/core/codex.gd`, `ctx.codex`)

The codex is saved to `user://codex.json` with the keys `discovered` (ids), `found` (descriptions) and `found_categories`. It is the demo's only meta-progression. Storage failures never throw: the codex keeps working in memory and sets `last_error`.

- An entry declared with an unknown category is not registered, and the codex warns once. Discovering an undeclared id also warns once, and the id files under `build` everywhere: the bus fact, the log line and the pages.
- A retry rewinds the run to the stage start, burst scrap included. The codex rewinds with it: entries first discovered or found during the retried attempt can fire again, and pay their burst again. The saved codex is never rewound.

- `declare({id, category, name, hint, clue, text})` registers an entry at setup, and a repeat declare is harmless. The categories are `build` (owned by B), `world` (owned by D), `enemy` (owned by A), and the reserved `npc` and `coop`.
- `mark_discovered(id, at := Vector3.ZERO, participants := ["player"]) -> bool` is called by the entry's owner every time it fires. The first call in a run publishes `synergy_discovered(id, category, first_time)`, grants the treasure burst at `at` and appends a line to `user://codex-log.ndjson`. It returns whether the saved codex had never seen the entry.
- `mark_found(text, category := "world", participants := ["player"]) -> bool` does the same for an unnamed interaction, publishing `interaction_found(text)`.
- The read API is `known(id)`, `discovered()`, `found()`, `found_category(text)`, `discovered_this_run()`, `name_of(id)`, `entries(category := "")`, which returns `{id, category, name, known, hint, clue, text}` records, and `completion(category)`, from 0 to 1.

Each codex log line holds `kind`, `run_id`, `stage`, `stage_ticks`, `category`, `id` or `text`, `participants`, `parts` and `heft`.

## Run log (`src/core/run_log.gd`)

At every death and at the end of a run, the spine appends one cumulative record to `user://runs.ndjson`. It shares the codex log's `run_id`. The record holds:

- `run_id`, `class` and `outcome` (`won`, `lost` or `died`).
- `stages`, one entry per stage with `stage`, `ticks_to_warden_break`, `heft_at_exit`, `part_ids_at_exit`, `bonus_cores`, `deaths` (each `{x, y, z, ticks}`), `events_joined` and `events_won`.
- `codex`, the ids discovered this run.
- `brindle_phase_reached`, which stays null until wave 4 sets it.
- `anomalies`, the seam faults the run met (`{stage, kind, ticks}`, such as `warden_vanished`).

The record comes from bus signals and run state only. Records are cumulative and a run with retries writes several, so a reader takes the last line per `run_id`. Within a stage record, `deaths` accumulate across retries, and `ticks_to_warden_break` is the latest attempt's.

## Tests

- Name module tests `tests/combat_*.gd`, `tests/build_*.gd`, `tests/presentation_*.gd` and `tests/world_*.gd`.
- A test extends `SceneTree`, prints one line per check in the form `[check] detail -> PASS` or `-> FAIL`, then a final `<name>: PASS` line, and quits 0 or 1.
- Never print a line that starts with `ERROR` or `FAIL`. The smoke runner treats those as failures.
- Build the game with `Game.new()`, set `test_mode = true`, add it to `root` and wait for `flow` to be set. Test mode writes the codex and run logs to a per-process folder, removed when the game leaves the tree. Drive input with `Intent.Scripted` (`hold` and `press`). Set `ctx.calm` when measuring speed.
- `tests/doubles/spine_spawner_double.gd` is a spawner that follows A's plating rule, so spine tests don't depend on combat. The smoke runner reads only `tests/*.gd`, so helpers go in subfolders.
- `npm run sketch:smoke` runs every sketch's import, a 300-frame boot and every test. All the `spine_*` tests must keep passing with your module installed.
