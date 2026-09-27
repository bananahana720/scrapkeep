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
- **Stand down on `stage_content_cleared`.** Flow publishes `stage_content_cleared(reason)` on entering the arena, with the reason `arena`, and on each arena retry, with the reason `arena_retry`. Each module then clears its stage content at once, whatever the reason:
  - combat clears stage enemies, which means every node in the groups `enemy`, `enemy_shot` and `telegraph`. The clear runs before the boss module's `enter_arena` on entry and on each retry, so the boss spawns its own pieces after it;
  - world stops its director and flood and parks the stage maps. Parking hides the stage maps and disables their collision until the next `stage_entered`;
  - build clears pickups and fabricators.

  Arena kills pay no scrap from the scrap field, because the scrap field is stage content. The boss module grants any arena scrap itself through `run.add_scrap`.
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
- `warden_plating` (45, 80, 140), `warden_hp` (800, 2200, 7500), `warden_lesson` (`plate`, `caps`, `magnet`) and `warden_hint` (the objective line's last sentence).

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
- `heft()`, which is `1 + mass * HEFT_PER_MASS + HEFT_PER_PART * parts.size()`, currently `1 + mass/450 + 0.2 * parts.size()`.
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
| `stage_content_cleared` | `reason: String` | spine flow | stage content must stand down now (reason `arena` on entering the boss arena, `arena_retry` on retrying it); quiet, priority 0 |
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
| `enemy_struck` | `enemy: Node3D, kind: String, force: float` | A (from `strike`) | a resolved hit; kind is `stomp`, `ram`, `slam`, `arc`, `turret`, `runner` or `synergy` (a build synergy's shockwave, shrapnel, frost ring or blade: resolved as the damage given, never a landing, so no weak point that takes a slam takes it) |
| `strike_deflected` | `enemy: Node3D, kind: String, punch: float, plating: float` | A | a hit below plating chipped for 20% |
| `shot_fired` | `weapon_id: String, from: Vector3, to: Vector3` | A | a weapon fired; the segment it drew |
| `special_used` | `special_id: String, at: Vector3` | A | a class special fired |
| `reward_offered` | `offers: Array` | B | gates are open or moved; offer records below |
| `reward_chosen` | `part_id: String` | B | a gate was taken, after `run.add_part` |
| `element_resolved` | `element_id: String, material_id: String, behaviour: String, at: Vector3` | B | an element met a material (TADR-009); C picks the sound by behaviour (freeze, electrify, shatter) |
| `event_announced` | `event_id: String, seconds_until: float` | D | a stage event is coming |
| `event_started` | `event_id: String` | D | it is live |
| `event_ended` | `event_id: String, outcome: String` | D | outcome is `won`, `lost` or `passed` (for ambient events) |
| `event_progress` | `event_id: String, fraction: float` | D | a live participatory event's own progress, 0 to 1, from its model (Hold the Relay: share held; Surge Run: gates taken; Scrap Stampede: hits on the hauler); published on its first live tick, then whenever it has moved at least 0.01, and on reaching 1, before its `event_ended`; quiet, priority 0 (presentation drives the event's music from it and plays no cue) |
| `launched` | `velocity: Vector3` | D | the ball was launched toward the next stage |
| `pressure_changed` | `pressure: float` | D | director pressure, 0 to 1, for music layers |
| `threat_rose` | `tier: int` | D | the director's time tier rose (clamped at +2) |
| `boss_arena_entered` | none | E | the ball is in the arena; the music's Brindle set starts |
| `boss_phase_changed` | `phase: int, name: String` | E | Brindle's phase and its name: 1 to 3 by hull health, then 4, `chase`, for the eject-scooter chase. The HUD toast capitalizes the name. The run log keeps the highest phase |
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
- `shred_of(enemy) -> float` is how much plating that enemy's landed hits have stripped for now; `plating_of`, `resolve`, `would_crush` and the tint already subtract it, floored at 0.
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
- `add_external_accel(accel)` adds a push in m/s², accumulated per physics tick and spent once. It does nothing while the ball is planted, mounted or frozen, and `set_frozen(true)` and `reset_to` drop any push already handed over, so a killing blow's shove never reaches the retry. Its users:
  - the world, for the flood;
  - combat, for the shove of a committed, telegraphed hit;
  - the Warden pulse and the magnet tug.

  A foreseen shove is an allowed performance cost. To turn a velocity change into an acceleration, divide it by the physics step actually run (the `delta` your `_physics_process` receives), never by `physics_ticks_per_second`: hit-stop changes `Engine.time_scale`, which would otherwise scale the push.
- `set_velocity_now(velocity)` sets velocity. Only D's launch uses it. The launch calls it every tick during the flight, as a rail, not once.
- `crush_check` (a Callable) is wired by `game.gd` to `ctx.spawner.would_crush`. A bow sensor a metre past the shell asks it for each enemy met from the cruise tier up. On yes, the ball ignores that enemy for 0.3 s and reports one `ram` strike, with no knock, shockwave or hit-stop.

## Flow seams (`src/core/flow.gd`)

- `force_warden` is a test knob: it seals calm stages.
- **The boss flow.**
  - **Arena entry.** After stage 3's launch flight, flow emits `stage_cleared(3)`. If `ctx.boss` exists it then enters `boss`, calls `ctx.boss.enter_arena(entry_velocity)` with the ball's velocity, and keeps an arena-entry checkpoint (the stage-3-end snapshot) once the call returns. The boss module builds its arena under `ctx.root`, places the ball keeping that velocity (entry must keep speed within 15%), and emits `boss_arena_entered`. The world's terrain API and the stage fall rescue are not used in the arena; the arena rescue (E's `floor_y()` and `rescue_point()`, below) is.
  - **Win.** `boss_defeated` in `boss` leads to `victory` for 2.5 s, then the summary and `run_ended(true)`.
  - **Death.** A death in `boss` leads to `dead`. There, R (or holding R in play) restores the arena-entry checkpoint and calls `enter_arena` again, T calls `replay_stage(3)` and restores the first stage-3 start the run kept, and N starts a new run.
  - **Boss seams.** The boss module sets `ctx.flow.boss_active` and `ctx.flow.boss_plating` (hull plating 120) on entry. The death screen reads them for its gap line and for offering T. `flow.in_arena` is read-only.
  - **Live boss reads (owner: E).** The boss module implements `live_plating() -> float`, the plating of whatever stands in the way right now (150 in a charge, 0 in a stun, the scooter's in the chase), and `objective_text() -> String`, the objective for the current phase ("" to use the standing one). Flow reads both through `boss_plating_now()` for the objective line and the death gap line; the gap line keeps the plating live at the moment of death. Without them flow falls back to `boss_plating` and the standing objective.
  - **Arena fall rescue (owner: E, the boss module).** The boss module implements `floor_y() -> float` and `rescue_point() -> Vector3`. Every tick in `boss`, flow checks the ball against `floor_y()`. Below it, flow puts the ball at `rescue_point()` keeping its horizontal speed, with no damage, like the stage rescue. If the boss module lacks either method, flow warns once and uses 40 m below the arena-entry checkpoint as the floor and the entry position as the landing.
- `discovery_burst(at)` grants 20 scrap times the stage at a discovery. The codex calls it, once per entry per run.

## Codex (`src/core/codex.gd`, `ctx.codex`)

The codex is saved to `user://codex.json` with the keys `discovered` (ids), `found` (descriptions) and `found_categories`. It is the demo's only meta-progression. Storage failures never throw: the codex keeps working in memory and sets `last_error`.

- An entry declared with an unknown category is not registered, and the codex warns once. Discovering an undeclared id also warns once, and the id files under `build` everywhere: the bus fact, the log line and the pages.
- A retry rewinds the run to the stage start, burst scrap included. The codex rewinds with it: entries first discovered or found during the retried attempt can fire again, and pay their burst again. The saved codex is never rewound.
- The arena is its own attempt. On `stage_content_cleared("arena")` the codex sets the stage-3 attempt aside; on `"arena_retry"` it rewinds only what the fight discovered. A T replay (`stage_entered` with retry) rewinds both.
- An owner calls `mark_discovered` every time its entry fires and leaves the once-per-attempt rule to the codex; a local once-per-run guard would keep a rewound entry from firing again and drop it from the run log.

- `declare({id, category, name, hint, clue, text})` registers an entry at setup, and a repeat declare is harmless. The categories are `build` (owned by B), `world` (owned by D), `enemy` (owned by A), and the reserved `npc` and `coop`.
- `mark_discovered(id, at := Vector3.ZERO, participants := ["player"]) -> bool` is called by the entry's owner every time it fires. The first call in a run publishes `synergy_discovered(id, category, first_time)`, grants the treasure burst at `at` and appends a line to `user://codex-log.ndjson`. It returns whether the saved codex had never seen the entry.
- `mark_found(text, category := "world", participants := ["player"]) -> bool` does the same for an unnamed interaction, publishing `interaction_found(text)`.
- The read API is `known(id)`, `discovered()`, `found()`, `found_category(text)`, `discovered_this_run()`, `name_of(id)`, `entries(category := "")`, which returns `{id, category, name, known, hint, clue, text}` records, and `completion(category)`, from 0 to 1.

Each codex log line holds `kind`, `run_id`, `stage`, `stage_ticks`, `category`, `id` or `text`, `participants`, `parts` and `heft`.

## Run log (`src/core/run_log.gd`)

At every death and at the end of a run, the spine appends one cumulative record to `user://runs.ndjson`. It shares the codex log's `run_id`. The record holds:

- `run_id`, `class` and `outcome` (`won`, `lost`, `died` or `abandoned`).
- `stages`, one entry per stage with `stage`, `ticks_to_warden_engaged` (the stage clock at `warden_engaged`), `ticks_to_warden_break`, `heft_at_exit`, `part_ids_at_exit`, `bonus_cores`, `deaths` (each `{x, y, z, ticks}`), `events_joined` and `events_won`.
- `codex`, the ids discovered this run.
- `brindle_phase_reached`, which stays null until wave 4 sets it.
- `arena`, present once the arena is entered: `entries` (entry plus each arena retry) and `deaths`, each `{x, y, z, ticks, run_ticks, phase}` with `ticks` on the arena clock, `run_ticks` on the run's and `phase` Brindle's. Arena deaths are never filed under stage 3.
- `anomalies`, the seam faults the run met (`{stage, kind, ticks}`, such as `warden_vanished`).

The record comes from bus signals and run state only. Records are cumulative and a run with retries writes several, so a reader takes the last line per `run_id`. Within a stage record, `deaths` accumulate across retries, and `ticks_to_warden_break` is the latest attempt's. A run that moved on since its last line and is then left, because a new run starts or the game closes, gets one last line with outcome `abandoned` and `abandoned_in` (`stage` or `arena`); that line and the `arena` block are how a reader sees a run that stopped in the arena or mid-stage.

## UI regions (`src/ui/screen_regions.gd`)

During play the screen is four horizontal bands, as shares of the visible height, and nothing drawn in one band reaches another:

| Band | Height | Holds |
| --- | --- | --- |
| `top` | 0 to 14% | screen titles, the objective line with its core pips, the run status |
| `toasts` | 15 to 29% | notable facts, at most 2 at once, and the hold-R restart meter |
| `prompts` | 62 to 84%, 6% side margins | world-attached prompts: reward gates and fabricators |
| `bottom` | 86 to 100% | the HUD: speed, heft and the key hints |

- The middle between `toasts` and `prompts` is the play view and the reticle.
- A toast whose words are already showing is not repeated; the showing one stays up for another full beat.
- A module that labels something in the world uses `src/ui/world_prompt.gd` (a `Label`), sets its text and colour, and calls `attach(anchor, offset, reach)`. It never uses a `Label3D` for words. The HUD places every prompt each frame: nearest first, at most 3, under its anchor's column where there is room, clamped inside `prompts`, never overlapping another prompt.
- Screens (title, class select, death, summary), the field notes and the tuning panel draw only while flow is out of play or the game is paused, when the HUD bands are hidden.
- Presentation's discovery banner follows the same rule: it belongs in `toasts` or in the middle view, never in `top` or `prompts`.

## Tests

- Name module tests `tests/combat_*.gd`, `tests/build_*.gd`, `tests/presentation_*.gd` and `tests/world_*.gd`.
- Drive contacts physically when the test is about contacts. `spine_stomp_test.gd` drops and rolls the real ball onto a target: a contact is classified and sized from the motion the ball had going into it (`player.pre_contact_velocity`), because the live velocity is already the solver's bounce.
- A test extends `SceneTree`, prints one line per check in the form `[check] detail -> PASS` or `-> FAIL`, then a final `<name>: PASS` line, and quits 0 or 1.
- Never print a line that starts with `ERROR` or `FAIL`. The smoke runner treats those as failures.
- Build the game with `Game.new()`, set `test_mode = true`, add it to `root` and wait for `flow` to be set. Test mode writes the codex and run logs to a per-process folder, removed when the game leaves the tree. Drive input with `Intent.Scripted` (`hold` and `press`). Set `ctx.calm` when measuring speed.
- `tests/doubles/spine_spawner_double.gd` is a spawner that follows A's plating rule, so spine tests don't depend on combat. The smoke runner reads only `tests/*.gd`, so helpers go in subfolders.
- `npm run sketch:smoke` runs every sketch's import, a 300-frame boot and every test. All the `spine_*` tests must keep passing with your module installed.

## Ability slots

The HUD's ability bar (`src/ui/ability_bar.gd`) draws one input, an ordered array of slot records. Order is the bar's, left to right: weapon (LMB), movement (RMB), special (F), smash (Ctrl), as `VISUAL-LANGUAGE.md` section 7 lays it out.

| Field | Type | Meaning |
| --- | --- | --- |
| `slot` | String | `weapon`, `movement`, `special` or `smash` |
| `id` | String | the ability id from the class row, such as `grapple` or `overdrive_blast` |
| `icon` | String | an Icons id (below): `ab_<pilot>_<role>`, the role being `weapon`, `move`, `special` or `smash` |
| `key` | String | a key glyph id: `key_lmb`, `key_rmb`, `key_f`, `key_ctrl` |
| `cooldown_frac` | float, 0 to 1 | the share of the recharging charge still to go; 0 when every charge is in |
| `charges` | int, 0 to `max_charges` | charges stocked now |
| `max_charges` | int, 1 or more | the stockpile cap; pips show under the key only when it is above 1 |
| `state` | String | one of `ready`, `cooling`, `active`, `unavailable` |
| `gauge` | float, 0 to 1 | the fill of a charging hold-gauge-release; the reticle's gauge ring shows the fullest |

- `ready` means pressing the key does the thing now. `cooling` means no charge is in. `active` means the ability is running or its gauge is charging. `unavailable` means the key does nothing useful now.
- The bar tells the states apart by shape as well as colour. `ready` has a solid frame. `cooling` has a petrol wedge that uncovers the icon clockwise from twelve. `active` has a doubled frame in the class colour and a lifted slot. `unavailable` has a faded icon struck through. A slot going from `cooling` to `ready` swells once, and the swell and the charge pips wear the class row's `shape`.
- **Publisher (W3).** `player.abilities.slots()` (`src/core/ability_state.gd`). The HUD reads it every frame through `src/ui/ability_slots.gd`, which names icons and keys the Icons way. An `icon` that is not an Icons id becomes `ab_<pilot>_<role>`, the pilot being the class row's `display_name` in lower case. A `key` label such as `LMB` or `F` becomes `key_lmb` or `key_f`. A record that then fails `AbilitySlots.valid_slot` empties the bar and warns once.
- **Reticle gauge.** While any slot's `gauge` is above 0, a ring round the reticle fills clockwise from twelve, linearly, in the class colour. It closes when the gauge is full.
- `ui_ability_slots_test.gd` checks all three pilots' records, a charging special and its ring, the release to cooling, the normaliser and the swell.

## Icons

`Icons.texture(id) -> Texture2D` (`src/ui/icons.gd`) loads `res://assets/icons/<id>.svg` when it exists, imported or not. All 70 ids have their SVG now (`ui_contract_test.gd` checks it). Otherwise it returns a 64 px procedural placeholder, white on clear, drawn from a signed-distance glyph. `Icons.tint(id, color)` gives the modulate to draw with: the fact's colour on a placeholder, and only its alpha on an SVG, which carries its own colours (a bone glyph on a charcoal backplate with one accent). An id outside the list still draws a placeholder picked by its prefix, so a new ability shows before its SVG and its contract line land.

The ids are the 70 of `VISUAL-LANGUAGE.md` section 5, which owns each one's meaning and drawing. `ui_contract_test.gd` fails if this list and the registry disagree.

- **Class emblems.** `cls_sable`, `cls_rivet`, `cls_kest`.
- **Abilities.**
  - Sable: `ab_sable_weapon`, `ab_sable_move`, `ab_sable_special`, `ab_sable_smash`, `ab_sable_vault`, `ab_sable_mount`.
  - Rivet: `ab_rivet_weapon`, `ab_rivet_move`, `ab_rivet_special`, `ab_rivet_smash`.
  - Kest: `ab_kest_weapon`, `ab_kest_move`, `ab_kest_special`, `ab_kest_smash`, `ab_kest_glide`, `ab_kest_cloak`.
- **Key glyphs.** `key_lmb`, `key_rmb`, `key_f`, `key_ctrl`, `key_space`, `key_shift`, `key_e`, `key_q`, `key_r`, `key_tab`. Any other key is drawn as a keycap from its id: key_1 reads 1, key_n reads N (`src/ui/keycap.gd`). The menus draw their number keys (1 to 3) and the N, C and T keys this way until those keys have SVGs.
- **Item categories.** `cat_damage`, `cat_mobility`, `cat_defense`, `cat_utility`, `cat_charge`, `cat_transform`.
- **Elements.** `el_frost`, `el_arc`, `el_kinetic`.
- **Triggers.** `trg_on_hit`, `trg_on_kill`, `trg_on_smash`, `trg_on_rebound`, `trg_on_vault`, `trg_on_charge_release`, `trg_on_cloak_break`, `trg_on_land`, `trg_on_speed_tier_up`, `trg_on_pickup`, `trg_on_damage_taken`, `trg_timed`.
- **Threat types.** `thr_instant`, `thr_wave`, `thr_projectile`, `thr_lane`.
- **Objectives.** `obj_beacon`, `obj_warden`, `obj_gate`, `obj_fabricator`, `obj_vault`, `obj_event`.
- **Resources.** `res_scrap`, `res_heft`, `res_health`, `res_core`, `res_timer`, `res_difficulty`.
- **Factions.** `fac_fleet`, `fac_reactor`, `fac_swarm`, `fac_mind`.

The event_kinds shapes (`ring`, `diamond`, `chevron` and the rest) are glyphs, not files: `Icons.shape(name)` draws them, and a toast wears its row's shape.

### Where the HUD uses them

- **Top band.**
  - The run status shows stage pips, `fac_fleet` for the arena, `res_timer` in mono digits, and `res_difficulty` over a notched bar that fills with `threat_rose`.
  - The objective shows its `obj_` icon ringed by the Warden's broken share, at most five words, and the core diamonds. While a lock stands it shows two bars: punch (`cat_damage`) over plating (`cat_defense`, hatched), with a white notch at the plating.
- **Toast band.** It holds the stage card (`obj_beacon` and the stage name, or `fac_fleet` for Brindle) or one toast, then a first-run callout or the hold-R meter (`key_r`). This supersedes the UI regions table above: one toast at a time (`ScreenRegions.TOAST_ROWS` is 1).
- **Bottom band.** Left to right: the speed chevrons, health as a tank gauge (`res_health`), the ability bar, the heft dial (`res_heft`) and scrap (`res_scrap`). This replaces the speed line and the key hints.
- **Play view.**
  - Contextual key glyphs sit beside the ball or the grapple target: `key_e` with `ab_sable_mount`, `key_rmb` with `ab_sable_move` and `key_space` with `ab_sable_vault`.
  - Edge markers use `obj_warden`, `obj_beacon` or `obj_gate`.
- **Menus.** Class cards use `cls_<pilot>`, and every button draws its key's cap.
- **Type.** Noto Sans Bold for words and Noto Sans Mono Bold for numbers, vendored in `assets/fonts/` with `OFL.txt` and `PROVENANCE.txt` (`src/ui/ui_fonts.gd`).

### World prompt parts

A world prompt (`src/ui/world_prompt.gd`) shows an icon and a title of at most three words at range, and adds its detail lines within 12 m of the ball (`DETAIL_RANGE`).

- **Structured.** An owner calls `prompt.set_parts(title, detail, icon)`:
  - `title` is at most three words.
  - `detail` is lines joined by `\n`.
  - `icon` is an Icons id: `obj_gate` for a reward gate, `obj_fabricator` for a fabricator, `obj_vault` for the vault, or `fac_fleet` for a Brindle readout.
- **Parsed.** Until the owner calls it, the text it sets is parsed.
  - The first line is the title. Text after a colon, and words past the third, move to the front of the detail. The remaining lines are the detail.
  - The icon is `obj_vault` for a title starting "Vault", `obj_fabricator` for "FABRICATING..." or a detail that names a price in scrap, and `obj_gate` otherwise.
- **Unchanged.** The prompt's `text` stays what the owner wrote, so owners and tests that read it keep working. The HUD places the drawn size (`shown_extent()`) in the prompts band as before.

## Threat grammar

Every enemy threat is a committed telegraph (`src/combat/telegraph.gd`) or boss hazard (`src/boss/hazard.gd`) with one attack type from `src/combat/threat_grammar.gd`: `Threat.Type.INSTANT`, `WAVE`, `PROJECTILE` or `LANE`. The type decides how the threat draws and sounds; the committed geometry decides where it hits. Both nodes build `descriptor()` from the fields `contains()` reads, and the grammar draws from that descriptor, so the drawing and the damage cannot disagree.

| Type | Draws | Hurts | Row |
| --- | --- | --- | --- |
| INSTANT | a sharp edge; a striped fill closing in from the edge over the warning; a solid flash on landing | the whole area, at once | `threat_instant`: `ring`, `threat_tick` |
| WAVE | a faint dashed reach; a bright front at speed x elapsed, chevrons, a curtain as tall as its height band; 15% stripes on the swept ground | only the front band, `WAVE_EDGE` (1 m) either side | `threat_wave`: `wave`, `threat_whoosh` |
| PROJECTILE | a dotted flight trace to the landing point; a reticle whose brackets close on the blast edge | the blast ring, when the shell lands | `threat_projectile`: `cross`, `threat_whistle` |
| LANE | rails and a far cap; a striped fill running from the source | the strip, where the body or beam is | `threat_lane`: `bar`, `threat_hum` |

Instant, projectile and lane also draw their height band as posts and a rail at `reach`.

The type is a required argument everywhere; no factory defaults it, and a node committed without one pushes an error.

- **Ring, lane or wedge.** `Telegraph.ring(parent, ground, type, at, radius, reach := 3.5, tint := HAZARD)`, `Telegraph.lane(parent, ground, type, from, heading, length, width, reach := 3.5)` and `Telegraph.wedge(parent, ground, type, apex, heading, radius, half_angle_deg, reach := 3.5)`. The owner calls `set_progress(0..1)` across the warning. An INSTANT flash fires on reaching 1.
- **Wave.** `Telegraph.wave(parent, ground, at, radius, speed, warn, reach := 3.5)` is always WAVE. The owner calls `step(delta)` every tick; `front_radius()` is -1 while it arms, and `is_spent()` turns true once the front has passed the reach.
- **Projectile.** Commit a PROJECTILE ring at the landing point, then call `set_flight(launch, bump)` with `Threat.lob_bump(gravity, flight_seconds)` for a fixed-time lob. The shell must fly `Threat.flight_point(launch, landing, bump, t / flight)`.
- **From an enemy.** `enemy.gd`'s `_commit_ring(type, at, radius, reach, tint := HAZARD)` and `_commit_lane(type, from, heading, length, width, reach)` keep one telegraph per enemy and return it.
- **A boss hazard.** `commit_sector(id, type, ...)`, `commit_annulus(id, type, ...)` and `commit_lane(id, type, ...)`. A WAVE hazard is a sector sweep whose front is `front()`, the same `span x live_fraction()` a sweep test reads.
- **Stance.** The tint decides it (`Threat.stance`). `Palette.HAZARD` is hostile: striped areas, a warn sound, and the group `threat`. `AMBER` is the player's own: clean fills and no sound. `Palette.SAND` (bone) is a harmless field that only draws a dashed ring. A boss hazard tinted `BRASS` draws in HAZARD with brass owner ticks.
- **Sound.** Each type's row is in `EventKinds.THREAT_ROWS` (the `ROWS` schema), with the sound's recipe in `sfx_bank.gd`. Every hostile telegraph and hazard joins the group `threat` (`Threat.GROUP`) and answers `threat_kind()` with its row key. `audio.gd` plays the row's sound at the end of the frame the node enters the tree, never on the beat. It then plays the node's `owner_voice` (the owner's timbre) and `mechanic_tag` when set; set both right after the commit. No unit adds a fifth type sound.
- **Colour.** Every layer draws with no depth test at `Threat.PRIORITY` (40), and the charcoal keylines at 39. The grammar only lightens the tone for the moving pieces.
- **Seam.** `hazard.gd` preloads `combat/threat_grammar.gd`. It is the one boss-to-combat preload, kept on purpose so the two systems share one grammar.

## Classes and abilities (v2 W3)

- **The class row** (`src/core/class_def.gd`) is the one source for a character: `id`, `display_name`, `role`, `species`, `pitch`, the four ability ids (`weapon_id`, `movement_id`, `special_id`, `smash_id`), `color`, `shape` (an event_kinds shape; the indicator's rim ticks), `motif` (the leitmotif id, `sable`, `rivet` or `kest`, whose notes live in W5's motif table in `harmony.gd`), `sound` (a synth id standing in now), `bible_home` and `synergy_hooks`. `ClassDef.all()` is ordered Sable, Rivet, Kest, and flow's class index follows it. `SABLE_COLOR`, `RIVET_COLOR` and `KEST_COLOR` are what class-owned event rows and the indicator read.
- **The ability state** (`src/core/ability_state.gd`) lives on the ball as `player.abilities` (the kit's). Movement and combat spend from it, and nothing else writes it. Slots are `weapon`, `movement`, `special` and `smash`.
  - `slots() -> Array` returns W1's ability-slot records in bar order: `{slot, id, icon, key, cooldown_frac, charges, max_charges, state, gauge}`. `state` is `ready`, `cooling`, `active` or `unavailable`. `cooldown_frac` is the share of the recharging charge still to go, 0 when full. `gauge` is the fill of a charging hold, 0 to 1, for the reticle ring.
  - `set_max_charges(slot, n)` and `set_cooldown_scale(slot, s)` are the item seams. Charges recharge one at a time and stockpile. No scale takes a cooldown under `COOLDOWN_FLOOR` (0.4 s), and `AbilityState.floored(base, scale)` applies the same floor to cooldowns outside the slots, such as combat's `rocket_cooldown_scale`.
  - `Gauge` is the one hold-gauge-release rule. Only ticks with the key down fill it. Release fires at the fraction reached, a full gauge fires by itself 0.5 s later, and a cancel spends nothing.
- **The grammar** is the same for every class: LMB weapon, RMB class movement, F hold-gauge-release special, Ctrl smash, Space jump, Shift boost. `Intent` adds `special_held`, `special_released`, `movement_pressed`, `movement_held`, `movement_released`, `fire_released` and `cancel_pressed`. The ball turns an RMB press made during any charge into `cancel_pressed`. Sable's grapple rides RMB through the intent; `game.gd` has no RMB branch.
- **Skill-shot geometry.** `player.indicator` (`src/movement/indicator.gd`) is player-owned and draws to VISUAL-LANGUAGE §3 and §4: class colour (never `Palette.HAZARD`), a 15% clean fill, a charcoal keyline, rounded caps, the class's rim ticks, a dashed full-charge extent and a fill that breathes on a 0.5 s period at full. `player.yours(record)` adds the colour and ticks. `set_shape(layer, record)` draws exactly the record a release commits, and `last_shape[layer]` keeps the last one drawn. `collapse(layer)` shrinks a cancelled or knocked shape into its origin in 120 ms. A record with `blocked` draws in bone, dashed, with a charcoal cross, and its release fires nothing. Hit tests forgive a hull up to `AbilityState.FORGIVENESS` (18%) past the drawn edge: combat's `in_ring()` and `in_line()` are the rule.
- **Crowd control.** `player.crowd_control(kind, shove := Vector3.ZERO, interrupts := true) -> bool` is the one door for a stop an enemy imposes. An interrupting one force-cancels every charging gauge (publishing `gauge_cancelled(id, kind)`) and collapses the indicator; a steady pull passes `interrupts = false` so it does not wipe a charge every tick. It applies the shove (an acceleration, as `add_external_accel`) and returns true. While Rivet sprints it does neither, publishes `cc_ignored(kind)` at most every 250 ms per kind and returns false. Damage never goes through it. Its users: combat's committed-hit knock (`knock`), the Warden's pulse (`warden_pulse`) and magnet (`warden_magnet`, steady), and Brindle's tug (`brindle_tug`, steady), slag bounce (`brindle_slag`) and charge shove (`brindle_charge`). Wave 3's crowd control should use it too. The world's flood and event pushes stay on `add_external_accel`: they are terrain, not crowd control.
- **Contact.** `src/movement/contact.gd` is the bowling-ball rule: `rebounds(weight, heft, sprinting)` and `rebound_velocity(v, normal, jump_speed)`. The ball asks `heft_of` (combat wires it to `combat.heft`) and an enemy's `weight`. A body without `weight` is never a rebound. A rebound refreshes like a stomp through `player.refresh_air()`.
- **Enemy sight.** Combat hands chasers, lobbers and minibosses a `Sight` proxy as their target (`ball_position()`, `planar_velocity()`, `add_external_accel()`), which answers the cloak's smoke point to enemies beyond `CLOAK_SIGHT` of their reach. An enemy that needs more of the player must add it to the proxy.
- **Bus facts and their owners.** Movement (`player_ball`) publishes `enemy_rebounded`, `vault_kicked`, `sprint_started`, `blink_used`, `arc_slammed`, `skid_smashed`, `demo_slammed`, `cc_ignored`, `dashed` (the movement burst of any class) and the slingshot's `gauge_*`. Combat publishes `enemy_pinned`, the specials' `gauge_charging`, `gauge_released` and `gauge_cancelled`, `cloak_started`, `cloak_broken`, `sticky_detonated` and `rocket_jumped`. `special_used(special_id, at)` now carries `detonation_gauge`, `overdrive_blast` or `detonation_line`.

## Enemies v2

- **The roster** (`src/combat/roster.gd`) is the one source for an enemy: `faction`, `role`, `mechanic`, `telegraph`, `holds`, `breaks`, `tag` (and `tag_next`), `hold`, `tests` and `line`, per kind. `Roster.COUNTERS` is the Fleet unlock order and `Roster.ANCIENTS` the three families. `Roster.voiced(id, motif)` turns `mind_quote` into `mind_<motif>`.
- **Spawner kinds.** `spawn_enemy` also takes `mag_trapper`, `hooker`, `netcaster`, `bola_thrower`, `plated_brute`, `deflector`, `winch_drone`, `gyro_jammer`, `swatter`, `ramp_flipper`, `catch_trap`, `reactor_relic`, `swarm_remnant` and `mind_hand`. One `swarm_remnant` spawn brings its whole rack of six. Every one is in group `enemy`, carries `kind` and `faction`, and sees the player through `Sight`.
- **`combat.fleet`** (`src/combat/fleet.gd`) owns `holds`, `habits`, `mind_memory` and the swarms. `build_read()` on the spawner returns `{class, habits: {habit: share}, branch_tags}` for the director.
- **Holds** (`src/combat/holds.gd`, `fleet.holds`). A unit never touches the ball; it calls `catch(source, kind, breaks, max_seconds, shove, anchor)`, then `pull(source, accel)` each tick, and `release(source, reason)`. Both go through `player.crowd_control`, so Rivet's sprint refuses them. Tenacity: 1.8 s summed over a sliding 4 s releases every hold with the reason `tenacity` and makes `catch` refuse for 2.5 s. A player break is one of `jump`, `boost`, `smash`, `glide`, `speed`; it kicks the ball forward and refunds 0.6 s of the movement slot. `released(source_id, kind, reason)` is the node's own signal.
- **Bus facts and their owner.** Combat publishes `hold_started(kind, at)`, `hold_broken(kind, method)`, `hold_ended(kind, reason)`, `tenacity_gained(seconds)`, `pack_arrived(faction, at, kinds)`, `shield_vaulted(at, speed)`, `vent_charging(at, seconds)`, `vent_erupted(at)`, `swarm_scattered(at, drones)`, `mind_adapted(habit, icon)` and `weak_point_opened(point_id, at, seconds)`. `kind` in the hold facts is the unit's mechanic; `faction` is `fleet`, `reactor`, `swarm` or `mind`, and `EventKinds.faction_icon(faction)` is its `fac_` icon.
- **Packs.** The director times a pack's members on one arrival ring, so every reinforcement spawned in one physics frame is one pack; combat publishes `pack_arrived` once per faction in it. A lone chaser or lobber is not a pack.
- **The director's inputs** (`src/world/director.gd`). World may set `director.stage` (1 to 3; 0 reads it from the threat dial) and `director.build` (the spawner's `build_read()`); both default safely, so the director works before world sets them. `KIND_NAMES` holds every spawnable reinforcement; `packs` records each pack composed.
- **Warden family kits.** The stage Warden has `family` (`Roster.warden_family(stage)`), `family_point()` (`core`, `queen` or `lens`), `family_open()` and `braced()`. An open family point meets plating 0 through `plating_for(kind, part)`, is listed in `weak_points()`, and takes contacts near the top through `contact_part`. The lessons are unchanged.
- **The plating dress.** `set_tint("amber")` now means "breaks now": a class-colour rim (`Enemy.rim_color`, which fleet sets from the run's class row) and the open-crack glyphs; `"slate"` means closed dark plates. The state names are kept for their callers.
