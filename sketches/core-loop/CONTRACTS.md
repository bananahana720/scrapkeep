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
| `flow` | flow node | read-only: `in_play()`, `in_stage()`, `state_name()`, `stage()`, `stage_def()`, `objective_text()`, `sealed`, `warden`, `punch_now()`, `warden_plating()`, `death_cause`, `death_tip` |
| `terrain` | set by world | the terrain API below |
| `spawner` | set by combat | the spawner API below |
| `build` | set by build | the build module; read it through `has_method`. `build_module()` also reads a build that stored itself with `ctx.set_meta("build", self)` |
| `codex` | `Codex` node | the codex registry below |
| `boss` | set by boss | the boss module; flow calls `enter_arena(entry_velocity)` on it |
| `root` | `Node3D` | parent for world children |
| `rng` | `RandomNumberGenerator` | the run's one seeded stream (seed 20260926) |
| `calm` | `bool` | tests set it; no own-schedule spawns, no world pushes |
| `aim_origin()`, `aim_forward()` | `Vector3` | the camera's centre ray |
| `heading()` | `Vector3` | the level direction the player faces (the view's yaw, no pitch, unit length); the read side of `camera.snap(heading)`. Simulation code calls this, never the camera's basis |
| `hit_stop(seconds)` | method | a short freeze for weight; capped at 60 ms, never stacks, only in play |

Flow states, as `state_name()` returns them: `title`, `class_select`, `stage`, `beacon`, `gates`, `launch`, `boss`, `victory`, `summary` and `dead`. `in_play()` is true for `stage`, `beacon`, `gates`, `launch` and `boss`.

`stage_def()` returns the current row of `src/core/stage_defs.gd`, with these fields:

- `stage`, `name`.
- `threat` (a multiplier) and `event_mix` (event id to weight).
- `scrap_density` (a multiplier).
- `beacon_seconds` and `beacon_radius`, used only by the unsealed presence path.
- `warden_plating` (45, 80, 140), `warden_hp` (800, 2200, 7500) and `warden_hint` (the objective line's last sentence). Every Warden fights on the posture rule; the plating fight, its `warden_fight` key and the lessons were retired by F6 (2026-10-04). `warden_lesson` stays in the rows as `""` and nothing reads it.

Every number there is a starting value; tuning edits `stage_defs.gd`, the heft constants in `run_state.gd` and the part catalogue.

## Run state (`src/core/run_state.gd`)

| Call | Effect | Publishes |
| --- | --- | --- |
| `add_scrap(amount, at)` | adds to mass and to the `scrap` tally; never to `cogs` | `scrap_collected(amount, at, total)`, then `heft_class_changed` if the class rose |
| `add_cogs(amount)` | adds to the `cogs` wallet only; mass, heft and procs are unchanged | nothing |
| `spend_cogs(amount) -> bool` | spends cogs if affordable; short of the price, or a negative amount, spends nothing; mass is unchanged | nothing (the part it buys publishes `part_gained`) |
| `spend_scrap(amount) -> bool` | spends the old `scrap` tally if affordable; only world devices whose `cost` is `scrap` still call it | nothing |
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
- `death_save_hook` (Callable() -> the hull to live on at, or 0.0 when no earned save is held; run once per lethal hit before `player_died`), the `death_saved(hp)` signal it raises and the `death_save_spent` run-doc field (once per run, survives a save and Continue, never goes back to false), like `ward_hook` and `deflect_hook` beside it in `run_state.gd`.
- `run_id`, `stage`, `hp`, `max_hp`, `cogs` (the spend wallet), `scrap` (the old wallet, now a tally nothing in build spends), `mass`, `parts` (an array of part ids, one entry per stack), `bonus_cores`, `kills`, `events_won`, `run_time`, `stage_time` and `retries`.
- `heft()`, which is `1 + mass * HEFT_PER_MASS + HEFT_PER_PART * parts.size()`, currently `1 + mass/450 + 0.2 * parts.size()`.
- `heft_class()`, which returns 1 to 5 (classes start at heft 1.0, 1.5, 2.2, 3.2 and 4.6), and `heft_progress()`, the share of the way to the next class.
- `gate_tier_bonus()`, which returns 0, 1 or 2 for 0, 1 or 2+ bonus cores. Build reads it when it builds its offers.
- `RunState.roman(n)`, a class numeral for display.

Only flow calls `begin`, `enter_stage`, `snapshot`, `restore`, `use_stage_start` and `advance`.

Cogs (CG1) are the only build currency: Moss's shelf, hook, reroll and charge cells, the drive-through fabricators, and sell-back all move `cogs` through `spend_cogs` and `add_cogs`, priced from the one table `Fabricators.COG_PRICES`. Damage, theft (`lose_scrap`), wear and `recover_mass` never change `cogs`. A scrap piece the magnet takes calls `add_scrap(1, at)`; a gear calls `add_cogs(value)` with no proc and no `scrap_collected` (`scrap_field.cog_values`).

The stage-start snapshot holds `max_hp`, `hp`, `scrap`, `cogs`, `mass`, `bonus_cores`, `parts`, `kills`, `events_won`, the entry position, the entry velocity and the camera yaw. A retry restores all of them, and it changes the heft class silently, with no stinger. The run also keeps the first start of each stage, which `flow.replay_stage(index)` restores. Bonus cores reset when a stage begins. Anything a module derives from parts, such as tuning mods or max HP, must be recomputable from `run.parts`. Make that recompute idempotent. `tuning.clear_mods()` followed by reapplying every part is the pattern.

## GameEvents signals (`src/core/game_events.gd`)

Every signal has a row in `event_kinds.gd` keyed by its name. `spine_event_kinds_test.gd` fails if one is missing, if a row has no sound, or if an objective uses the word "optional".

| Signal | Arguments | Emitted by | Meaning |
| --- | --- | --- | --- |
| `run_started` | `class_id: String` | spine flow | a run began |
| `flow_changed` | `state: String` | spine flow | the flow state changed |
| `stage_entered` | `stage: int, retry: bool` | spine flow | a stage began or was retried; reset stage content now |
| `stage_cleared` | `stage: int` | spine flow | the launch flight ended and the stage is done |
| `run_ended` | `won: bool` | spine flow | the run finished (summary) |
| `death_saved` | `hp: float` | `run_state` | the earned save caught a lethal hit; flow writes `death_save_spent` to the entrance doc (`_on_death_saved`) |
| `beacon_charge_changed` | `fraction: float` | spine flow | beacon charge, 0 to 1; while sealed, the share of the Warden broken; exactly `1.0` once per stage when the gates open |
| `beacon_unsealed` | `stage: int` | spine flow | the Warden broke; the gates open wherever the ball is |
| `warden_sighted` | `stage: int` | spine flow | the ball first comes within `SIGHT_SHARE` (3.5) times the beacon ring's radius of the sealed Warden, before any engagement, once per stage attempt; intro lines and reveal cards play here and clear at `warden_engaged` |
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
| `bumped` | `at: Vector3, normal: Vector3, speed: float` | spine ball | the ball met a world face that is not a floor (wall, cliff, structure side, ceiling) at `speed` m/s of closing, at least `Contact.BUMP_MIN_SPEED`, at most once per `Contact.BUMP_GAP_S`; `normal` points face to ball |
| `slammed` | `at: Vector3, strength: float, flatness: float` | spine ball | a slam landed; flatness 1 is flat ground |
| `grapple_fired` | `anchor: Vector3` | spine ball | the hook attached |
| `grapple_released` | none | spine ball | the hook let go |
| `mounted` | `at: Vector3, banked_speed: float` | spine ball | a pylon was planted; banked_speed is the speed it arrived with |
| `dismounted` | `velocity: Vector3` | spine ball | left the pylon; the velocity is the slingshot, zero for an E drop |
| `enemy_spawned` | `enemy: Node3D, kind: String` | A | an enemy entered the stage |
| `enemy_struck` | `enemy: Node3D, kind: String, force: float` | A (from `strike`) | a resolved hit; kind is `stomp`, `ram`, `slam`, `arc`, `turret`, `runner` or `synergy` (a build synergy's shockwave, shrapnel, frost ring or blade: resolved as the damage given, never a landing, so no weak point that takes a slam takes it) |
| `enemy_walled` | `enemy: Node3D, at: Vector3, normal: Vector3, speed: float` | the enemy itself (`enemy.gd` `_wall_slam`) | a knock threw the enemy into a world face at `speed` m/s into it, at least `Contact.WALL_SLAM_SPEED`; it staggers, once per knock; presentation only: the knock, the body's path and the damage are unchanged |
| `strike_deflected` | `enemy: Node3D, kind: String, punch: float, plating: float` | A | a hit below plating chipped for 20% |
| `shot_fired` | `weapon_id: String, from: Vector3, to: Vector3` | A | a weapon fired; the segment it drew |
| `special_used` | `special_id: String, at: Vector3` | A | a class special fired |
| `slot_selected` | `slot: String, reason: String` | spine ball (`player_ball._route_slots`) | the skill bar's selection changed; reason `pick`, or the snap back's cause: `cast`, `deselect`, `cancel`, `swap`, `timeout`, `ultimate`, `reset` |
| `slot_cast` | `slot: String, ability_id: String, at: Vector3` | A | slot 2 or 3 committed a cast; the player's router snaps the selection back on it |
| `line_skill_loaded` | `ability_id: String, seconds: float` | A | a line skill cast with no line standing loaded the next bite |
| `line_skill_fired` | `ability_id: String, target: Node3D, at: Vector3, on: String` | A | the line skill fired along the line; on is `body` or `world`; target is null on the world |
| `line_skill_expired` | `ability_id: String` | A | a load ran out with no bite; nothing is refunded |
| `active_fired` | `active_id: String, at: Vector3, count: int` | A (`src/combat/actives`) | F fired the racked active; count is the pieces it launched (rockets in a volley) |
| `ultimate_ready` | `ultimate_id: String` | ultimate (`src/combat/ultimate.gd`, wave P-B B3) | the meter reached full |
| `ultimate_started` | `ultimate_id: String, path: String, from: Vector3, to: Vector3, seconds: float` | ultimate | Q committed a planned path; seconds is wind-up plus flight |
| `ultimate_peak` | `ultimate_id: String, at: Vector3` | ultimate | the flight's middle beat |
| `ultimate_landed` | `ultimate_id: String, at: Vector3, hits: int, damage: float` | ultimate | the landing strike resolved |
| `ultimate_cancelled` | `ultimate_id: String, reason: String, refunded: bool` | ultimate | `recall`, `bail`, `stage` or `death` |
| `reward_offered` | `offers: Array` | B | gates are open or moved; offer records below |
| `reward_chosen` | `part_id: String` | B | a gate was taken, after `run.add_part`; an active offer's id (`active:` + active id, `src/combat/actives/active_offers.gd`, --actives on) is racked instead and never added as a part |
| `element_resolved` | `element_id: String, material_id: String, behaviour: String, at: Vector3` | B | an element met a material (TADR-009); C picks the sound by behaviour (freeze, electrify, shatter) |
| `event_announced` | `event_id: String, seconds_until: float, at: Vector3` | D | a stage event is coming; `at` is where it lands, `Vector3.INF` for one with no single place |
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
3. When the ball rolls through a gate, B calls `run.add_part(id, "gate")` (or, for an active offer, racks it with `combat.actives.take(id, at)`), then emits `reward_chosen(id)`.
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

- `spawn_enemy(kind: String, at: Vector3, affix_id := "", perch := Vector3.INF, health_scale: float = 1.0) -> Node3D`. `health_scale` multiplies the health the enemy would otherwise spawn with (the Stocktake yard's count 6 and later). The kinds are `chaser`, `lobber`, `miniboss`, `warden` and `vault`, and A may add more. The call adds the enemy under `ctx.root`, wires its damage to `run.damage` and its death to `run.record_kill`, and emits `enemy_spawned`. It does not check `ctx.calm`.
- `strike(enemy: Node3D, kind: String, force: float)` resolves one hit into damage against plating and emits `enemy_struck`, plus `strike_deflected` below plating. The spine calls it for ball contacts: `stomp` (force is fall speed), `ram` (force is speed, at the cruise tier or above) and `slam` (force is knockback after falloff). Combat's own weapons call it too.
- `punch_now() -> float` is the punch the player would land now: ram punch at the ball's planar speed from the cruise tier up, or the current weapon's per-hit damage, whichever is larger.
- `plating_of(enemy) -> float`.
- `shred_of(enemy) -> float` is how much plating that enemy's landed hits have stripped for now; `plating_of`, `resolve`, `would_crush` and the tint already subtract it, floored at 0.
- `integrity_of(enemy) -> float` is HP over max HP, or 1.0 for an invalid enemy.
- `would_crush(enemy, kind, force) -> bool` is true when the enemy has no plating and the hit would kill it.

The spine calls all of these defensively (`has_method`). The fallbacks are integrity 1.0, punch 0, plating 0 and would_crush false. The one exception is the objective line, which shows the stage's `warden_plating` when the spawner cannot say.

### Special cues (`src/combat/special_cues.gd`)

The four kill-first specials (Foreman, Dispatcher, Splitter, Linker) each have a presence loop, a tell and a death sting. A body is a special by its `kind`, a `special` meta or its `elite_affix` meta. `spawn_enemy` calls `SpecialCues.attach(enemy)` before it emits `enemy_spawned`, which gives the body a `special_tell(moment: String)` signal if it has none; a body built outside `spawn_enemy` calls `attach` itself first. Presence and death need no call: `audio.gd` and `machine_fx.gd` start presence on `enemy_spawned` and play the death on the body's `died`. A Splitter rammed at ground level says so with `rammed_at_ground` (a property or a method) or a truthy `split` meta before it dies; sound and effects both read it through `SpecialCues.rammed`. A behaviour calls `SpecialCues.tell(self)` on the tell's first frame and does not emit `special_tell("tell")` itself: the hook emits it once, and `audio.gd` (sound), `special_rig.gd` (clip) and `machine_fx.gd` (effects) all start from that emit, on that frame. It returns "" with a warning for a body nobody listens to. Other moments (the Linker's `cut`) the body emits itself. Sound ids are `<special>_<moment>`, loaded by `sfx_bank.gd` from `assets/audio/specials/`; the audio gate counts a missing one as a placeholder.

Every enemy is in group `enemy`, is on physics layer 3, and implements `knock(direction: Vector3, force: float)` and `flash()`. The ball calls those two for contact physics, so collisions have weight whatever combat does with the damage.

## Terrain API (world, `ctx.terrain`)

Instance methods the spine and other modules may call:

- `height(x, z) -> float`
- `floor_height(x, z) -> float` (height with no overlay down: the ground a ball under an overlay's sheet stands on; the fall rescue reads it)
- `drop_point(x, z, clearance) -> Vector3`
- `spawn_point(stage) -> Vector3`
- `entry_heading(stage) -> Vector3` (flat, unit length)
- `beacon_point(stage) -> Vector3` (on the ground; the Warden spawns here on every map)
- `scrap_lines(stage) -> Array` (each entry is `[Vector2 from, Vector2 to]` on the ground plane)
- `scrap_trail(stage) -> Dictionary` (`{points, spacing_m, phrase, rest, gaps}`: the line scrap is laid along to the beat, with no gears or hoops; empty for a stage with none)
- `contains(point) -> bool`
- `rescue_point(near) -> Vector3`
- `material_at(point: Vector3) -> Dictionary`, which returns `{"material": "water" | "concrete" | "sand", "surface_y": float}` or `{}` where unknown. The Dictionary is the settled shape, because ice needs the surface height. D implements it. Until it does, build falls back to `build.register_material("water", provider)`.

Flow calls `spawn_point`, `entry_heading` and `beacon_point` right after `stage_entered`. If D swaps the geometry per stage, do it synchronously inside the `stage_entered` handler. The world layer is physics layer 1; the grapple, pylon and camera all read it.

## Camera hooks (`src/movement/chase_camera.gd`)

- `shoulder_target: float` (0 to 1). Combat sets it: 1 while mounted, 0 otherwise. The rig eases `shoulder_blend` toward it, shortens the arm to 4.2 m and shifts the ball left of the crosshair.
- `punch_fov(amount_degrees, time)` adds field of view that bleeds away over `time`, capped at 20 degrees.
- `kick(direction: Vector3, amount)` knocks the camera along a world direction, and it springs back.
- `shake(amount, time = 0.4)` shakes the camera; the strongest shake wins.
- `motion_scale: float` (0 to 1) is the viewer's Screen shake comfort. Juice sets it; the camera multiplies every punch, kick and shake by it, its own landing shake included.
- `aim_origin()`, `aim_forward()`, `yaw_basis()` and `yaw` are read-only for modules. A module that wants the facing direction calls `ctx.heading()`, not `yaw_basis()`.

Juice follows the player's actions and must never hide the next threat. Keep punches and shakes short.

## Ball hooks (`src/movement/player_ball.gd`)

- `juice_node() -> Node3D` belongs to presentation. It follows the ball and never rotates. Scale it for squash and stretch, and parent trails or speed lines to it. The spine never writes it.
- `pod_mount() -> Node3D` sits beside the juice node and takes only its position, never its basis. The cockpit pod parents here, so squash, stretch and heft never scale the pilot (MOTION-SPEC row 204).
- `roll_node() -> Node3D` rolls with the ball's surface. Parent anything that should stick to the ball there, such as accreted scrap (B). The drawn outline stays the collider's size at every heft class (DECISIONS, 22 Oct, fixed outline).
- `pylon_node() -> Node3D` is the drawn pylon, for plant and eject animation.
- `builtin_squash: bool` is the spine's landing squash. Presentation sets it false when it draws its own.
- `speed_tier() -> int` (0 walk, 1 cruise, 2 fast, 3 blazing), `speed_fraction() -> float`, `shown_position()`, `planar_velocity()`, `ball_position()`.
- `state` (`BallState`: `velocity`, `grounded`, `contact_normal`, `impact`, `tier`) and `kit` (`AugmentKit`: `mounted`, `mount_banked`, `mount_point`, `mount_normal`, `hooked`, `gliding`, `slamming`) are read-only.
- `intent` holds this tick's input. Combat reads `fire_pressed`, `fire_held` and `special_pressed`. The spine fills it.
- `touch_body(body, normal = Vector3.ZERO)` reports a contact the ball's own `enemy_touched` never sees, such as a boss weak part outside the `enemy` group, and runs the ordinary contact. `normal` points from the body to the ball, full 3D; omitted or zero, it is derived as RigidBall derives it, so a drop from above stomps; a given normal is normalized. A freed body is ignored.
- `add_external_accel(accel)` adds a push in m/s², accumulated per physics tick and spent once. It does nothing while the ball is planted, mounted or frozen, and `set_frozen(true)` and `reset_to` drop any push already handed over, so a killing blow's shove never reaches the retry. Its users:
  - the world, for the flood;
  - combat, for the shove of a committed, telegraphed hit;
  - the Warden pulse.

  A foreseen shove is an allowed performance cost. To turn a velocity change into an acceleration, divide it by the physics step actually run (the `delta` your `_physics_process` receives), never by `physics_ticks_per_second`: hit-stop changes `Engine.time_scale`, which would otherwise scale the push.
- `set_velocity_now(velocity)` sets velocity. Only D's launch uses it. The launch calls it every tick during the flight, as a rail, not once.
- `smash_landing: Node3D` is the enemy a harpoon smash is landing on, set for the whole of that landing's contact and shockwave strikes and null otherwise. Combat reads it to tell a smash from an ordinary contact; nothing else writes it.
- `crush_check` (a Callable) is wired by `game.gd` to `ctx.spawner.would_crush`. A bow sensor a metre past the shell asks it for each enemy met from the cruise tier up. On yes, the ball ignores that enemy for 0.3 s and reports one `ram` strike, with no knock, shockwave or hit-stop.

## Flow seams (`src/core/flow.gd`)

- `force_warden` is a test knob: it seals calm stages.
- **The boss flow.**
  - **Arena entry.** After stage 3's launch flight, flow emits `stage_cleared(3)`. If `ctx.boss` exists it then enters `boss`, calls `ctx.boss.enter_arena(entry_velocity)` with the ball's velocity, and keeps an arena-entry checkpoint (the stage-3-end snapshot) once the call returns. The boss module builds its arena under `ctx.root`, places the ball keeping that velocity (entry must keep speed within 15%), and emits `boss_arena_entered`. The world's terrain API and the stage fall rescue are not used in the arena; the arena rescue (E's `floor_y()` and `rescue_point()`, below) is.
  - **Win.** `boss_defeated` in `boss` leads to `victory` for 2.5 s (plus the boss's rout and sign-on flourishes' hold, at most 2.0 s more, from `flow.victory_plan`; the victory card waits over the world while the rout plays), then the summary and `run_ended(true)`.
  - **Death.** A death in `boss` leads to `dead` only in a storeless flow (tests and bots); a store-bearing game ends the run on the summary. In a storeless flow, holding R in play restores the arena-entry checkpoint and calls `enter_arena` again; on the storeless death screen R does nothing, T calls `replay_stage(3)` and restores the first stage-3 start the run kept, and N starts a new run.
  - **Boss seams.** The boss module sets `ctx.flow.boss_active` and `ctx.flow.boss_plating` (hull plating 120) on entry. The storeless death screen reads `boss_active` for offering T; its words are the run's `death_cause` and `death_tip`, as RUN OVER's are. `flow.in_arena` is read-only.
  - **Live boss reads (owner: E).** The boss module implements `live_plating() -> float`, the plating of whatever stands in the way right now (150 in a charge, 0 in a stun, the scooter's in the chase), and `objective_text() -> String`, the objective for the current phase ("" to use the standing one). Flow reads both through `boss_plating_now()` for the objective line. Without them flow falls back to `boss_plating` and the standing objective.
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
- `flow_share` (the fraction of measured ticks at speed tier 2 or above, null before any measured tick), `dead_stops`, `bites` (`line_state_changed` `latched_body`), `smashes` (`smash_lands`), `breaks` (`broke`, a count per cause, `unspecified` when the cause is empty), `verb_fails` (`verb_failed`, a count per verb) and `prompts_shown` (`prompt_shown`, one per key prompt drawn, counted on its rising edge). Flow share and dead stops come from `RunLog.Traversal`, fed from each stage's start to its Warden engagement and accumulated across stages and retries; the detector restarts at each stage entry. Definitions are in `design-v3/TRAVERSAL.md`. The chain record (`design-v3/HOOK-CHAIN.md`) adds `chains` (one `{links, pivots, combo, paid}` per `chain_end`, read from the last row of `player.chain.finished`), `best_combo` (the largest combo at a `chain_end`) and `misses` (`chain_miss`); all three count in the arena as bites and smashes do. The smash damage record adds `smash_damage` (the damage delivered by smash landings, read from combat's delivered-damage ledger between the landing's first `enemy_struck` and `smash_lands`) and `smash_damage_by_fight` (one slot per Warden fight, opened at `warden_engaged` or the arena's entry and closed at `stage_cleared` or death; a smash outside a fight counts in the total only); both count in the arena.
- `events_joined` lists an event only when the ball entered it: `event_started` for a member of `EventDirector.PARTICIPATORY` (`scrap_stampede`, `surge_run`, `hold_the_relay`). Timer events (the flood, the dust squall, terrain changes) no longer count, and the altar and the cache publish other signals and are not counted.

The record comes from bus signals and run state only. Records are cumulative and a run with retries writes several, so a reader takes the last line per `run_id`. Within a stage record, `deaths` accumulate across retries, and `ticks_to_warden_break` is the latest attempt's. A run that moved on since its last line and is then left, because a new run starts or the game closes, gets one last line with outcome `abandoned` and `abandoned_in` (`stage` or `arena`); that line and the `arena` block are how a reader sees a run that stopped in the arena or mid-stage.

## UI regions (`src/ui/screen_regions.gd`)

During play the screen is four horizontal bands, as shares of the visible height, and nothing drawn in one band reaches another:

| Band | Height | Holds |
| --- | --- | --- |
| `top` | 0 to 14% | screen titles, the objective line with its core pips, the run status |
| `toasts` | 15 to 29% | notable facts, at most 2 at once, and the hold-R restart meter |
| `prompts` | 62 to 84%, 6% side margins | world-attached prompts such as fabricators |
| `bottom` | 86 to 100% | the HUD: speed, heft and the key hints |

- The middle between `toasts` and `prompts` is the play view and the reticle. A reward gate's offer is a sign, not a band prompt, and follows the gate-slot rule. Every standing gate in front of the camera, placed or not, owns a slot of the sign room (`ScreenRegions.sign_room`: from under `toasts` to the bottom of `prompts`, inside the `prompts` side margins): from the midpoint to its left neighbour's column to the midpoint to its right neighbour's, an outermost gate's side running to the room's, each shared side inset by half `PROMPT_GAP`. A sign's rectangle lies wholly inside its own slot and holds its gate's column, so it never holds another gate's column, signs never stack and two signs never collide. All of its drawn words lie inside its rectangle. A gate whose column is outside the room's sides, or too close to a neighbour to have a slot holding it, shows no sign that frame; a sign is never clamped away from its own column. It hangs at its gate's crossbar point (6 px under it) or lower, never above it. The ring, the ball's square and the pickup lines move it down inside its slot only. When no row below fits it drops a level, and when none fits it shows no sign. A fabricator's band prompt yields to a sign. The fit is by the slot's width, best first: the name and its detail wrapped to at most two lines; the name alone; the name alone at the floor size (`UiTokens.BODY`); no sign. A sign showing detail keeps it until its slot is 16 px narrower than the width that fits it, and one showing the name takes the detail only when the slot is 16 px wider than that. A sign pushed down 24 px or more draws a leader to its gate, cut at the room's top and at the ring's edge.
- A toast whose words are already showing is not repeated; the showing one stays up for another full beat.
- A module that labels something in the world uses `src/ui/world_prompt.gd` (a `Label`), sets its text and colour, and calls `attach(anchor, offset, reach)`. It never uses a `Label3D` for words. The HUD places every prompt each frame. A reward gate's sign (`on_anchor`) is placed first, in its gate's slot (above), and is not counted against the cap: every standing gate is named, up to the four that stand. Every other prompt is placed nearest first, at most 3 (`MAX_PROMPTS`), under its anchor's column where there is room, clamped inside `prompts`, never overlapping another prompt or a sign.
- Grey panel pickup lines (`src/ui/pickup_lines.gd`) rise from the top edge of `bottom` at its left, over the speed and cogs readouts, in at most two rows; `presentation/panel_fx.gd` says what each line says and when (its `popped` signal), and a prompt stands clear of the lines while they show (PF-14).
- Screens (title, class select, death, summary), the field notes and the tuning panel draw only while flow is out of play or the game is paused, when the HUD bands are hidden.
- Presentation's discovery banner follows the same rule: it belongs in `toasts` or in the middle view, never in `top` or `prompts`.

## Tests

- Name module tests `tests/combat_*.gd`, `tests/build_*.gd`, `tests/presentation_*.gd` and `tests/world_*.gd`.
- Drive contacts physically when the test is about contacts. `spine_stomp_test.gd` drops and rolls the real ball onto a target: a contact is classified and sized from the motion the ball had going into it (`player.pre_contact_velocity`), because the live velocity is already the solver's bounce.
- A test extends `SceneTree`, prints one line per check in the form `[check] detail -> PASS` or `-> FAIL`, then a final `<name>: PASS` line, and quits 0 or 1.
- Never print a line that starts with `ERROR` or `FAIL`. The smoke runner treats those as failures.
- Build the game with `Game.new()`, set `test_mode = true`, add it to `root` and wait for `flow` to be set. Test mode writes the codex and run logs to a per-process folder, removed when the game leaves the tree. Drive input with `Intent.Scripted` (`hold` and `press`). Set `ctx.calm` when measuring speed.
- `game.bot_driven` means no human answers a prompt. Setting `test_mode` sets it, and `tools/bot_driver.gd` sets it for every bot run. While it is set the hot-wire screen never opens or pauses the tree; a pending offer stays pending unless the driver answers it (the completionist fits, every other policy recycles). A test that plays the human at the screen clears it after setting `test_mode`, as `ui_hotwire_screen_test` does.
- `tests/doubles/spine_spawner_double.gd` is a spawner that follows A's plating rule, so spine tests don't depend on combat. The smoke runner reads only `tests/*.gd`, so helpers go in subfolders.
- Rules, tables and state machines that need no scene are unit cases, not tests. A case is `tests/unit/NAME_case.gd`: it extends `RefCounted` and has `func run(t) -> void`, where `t` is `tests/support/t.gd` (`check(label, ok, detail)`, `eq(label, got, want)`, `near(label, got, want, tolerance)`). `tests/unit_suite_test.gd` runs every case in one Godot process and fails when a check fails, a case does not load or fewer than 3 cases exist. A case never references `res://src/game.gd`, never adds a node to a tree and never reads the clock. A scenario test is still right for a seam that needs a real `Game`. New tests use `tests/support/t.gd` rather than defining their own `_report` or `_check`.
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
| `pool` | string, optional | the slot whose charges this one spends (its own name unless the row names another) |
| `refill` | string, optional | `time` for a cooldown (the bar draws a clock), `contact` for pressure only rolling and contact refill (the bar draws an empty charge: dashed frame, hollow pips); absent reads as `time` |
| `charges` | int, 0 to `max_charges` | charges stocked now |
| `max_charges` | int, 1 or more | the stockpile cap; pips show under the key only when it is above 1 |
| `state` | String | one of `ready`, `cooling`, `active`, `unavailable` |
| `gauge` | float, 0 to 1 | the fill of a charging hold-gauge-release; the reticle's gauge ring shows the fullest |

- `ready` means pressing the key does the thing now. `cooling` means no charge is in. `active` means the ability is running or its gauge is charging. `unavailable` means the key does nothing useful now.
- The bar tells the states apart by shape as well as colour. `ready` has a solid frame. `cooling` with a `time` refill is a clock: a petrol wedge that shrinks clockwise from twelve under the icon, with a sand hand at its edge; `cooling` with a `contact` refill is an empty charge, a dashed frame over the pool's hollow pips. During the set piece the marks dim and solid plates stay behind them. `active` has a doubled frame in the class colour and a lifted slot. `unavailable` has a faded icon struck through. A slot going from `cooling` to `ready` swells once, and the swell and the charge pips wear the class row's `shape`.
- **Publisher (W3).** `player.abilities.slots()` (`src/core/ability_state.gd`). The HUD reads it every frame through `src/ui/ability_slots.gd`, which names icons and keys the Icons way. An `icon` that is not an Icons id becomes `ab_<pilot>_<role>`, the pilot being the class row's `display_name` in lower case. A `key` label such as `LMB` or `F` becomes `key_lmb` or `key_f`. A record that then fails `AbilitySlots.valid_slot` empties the bar and warns once.
- **Reticle gauge.** While any slot's `gauge` is above 0, a ring round the reticle fills clockwise from twelve, linearly, in the class colour. It closes when the gauge is full.
- A slot `key` may also be a glyph id (`key_*`, `pad_*`), which `normalized()` passes through.
- `ui_ability_slots_test.gd` checks all three pilots' records, a charging special and its ring, the release to cooling, the normaliser and the swell.

### The skill bar (design-v3/SKILL-BAR.md, wave P-B B1, 2026-10-10)

- **Slots.** `AbilityState.SLOTS` is `weapon, movement, special, smash, line`; `BAR` is `weapon, special, line` (keys 1, 2, 3), `CHIPS` is `movement, smash` (Shift, Ctrl, never selectable). `ULTIMATE` stays out of `SLOTS`; `SWAPPABLE` is `SLOTS` plus it. Each `slots()` record also carries `number` (1 to 3, 0 for a chip), `group` (`bar` or `chip`), `selected` and `select_left`.
- **Selection.** `abilities.selected` is the slot left click casts; the weapon is home. Only the player's router (`player_ball._route_slots`, which runs before `_read_grammar` on the player's physics tick, ahead of combat's) changes it, through `select(name) -> String` (`""` or the refusal) and `snap_back(reason)`, and it alone publishes `slot_selected`. A left click on a picked slot 2 or 3 is ORed into `intent.special_*` or `intent.line_*` and `fire_*` is cleared, so the weapon never sees it. A scripted source that writes `special_*` or `line_*` directly still drives a kit test; bots pick with `slot_pick`.
- **Casts.** Combat's `_step_special` keeps the gauge path and adds a tap path for a row with no `charge_max`; `_step_line` casts the line skill through the `_line_skills` table. Both publish `slot_cast(slot, id, at)` when a cast commits, and the router snaps back on it. A row with `pool` spends that slot's charges (Tally's gather plate and link clips spend slot 1's pressure).
- **Line skill.** On a standing line it fires now along it; with none it loads the next bite for the row's `load_seconds`. `combat.line_load()` is `{id, fraction, left}` or `{}`.
- **Injected hooks.** `player.set_piece_phase` (a Callable answering `idle`, `windup`, `flight` or `recover`) is the ultimate unit's to set; while it answers anything but `idle` the router swallows every input but `move`, `jump_*` and `ultimate_pressed`. `player.snap_slots(reason)` is the one door for a snap back from outside the router.

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
  - The run status shows stage pips, `fac_fleet` for the arena, `res_timer` in mono digits, and `res_difficulty` beside a ramp of rising steps in the `threat_rose` colour with the word THREAT, the lowest step always lit and one more per threat tier (never a filled bar, which reads as health). `rising()` is true for the 1.5 s a newly lit step blinks.
  - The objective shows its `obj_` icon ringed by the Warden's broken share, at most five words, and the core diamonds. While a lock stands it shows two bars: punch (`cat_damage`) over plating (`cat_defense`, hatched), with a white notch at the plating.
- **Toast band.** It holds the stage card (`obj_beacon` and the stage name, or `fac_fleet` for Brindle) or one toast, then a first-run callout or the hold-R meter (`key_r`). This supersedes the UI regions table above: one toast at a time (`ScreenRegions.TOAST_ROWS` is 1).
- **Bottom band.** Left to right: the speed chevrons, health as a tank gauge (`res_health`), the ability bar, the heft dial (`res_heft`) and scrap (`res_scrap`). This replaces the speed line and the key hints.
- **Play view.**
  - Contextual key glyphs sit beside the ball or the grapple target: `key_e` with `ab_sable_mount`, `key_rmb` with `ab_sable_move` and `key_space` with `ab_sable_vault`.
  - Edge markers use `obj_warden`, `obj_beacon` or `obj_gate`.
- **Menus.** Class cards use `cls_<pilot>`, and every button draws its key's cap.
- **Type.** Noto Sans Bold for words and Noto Sans Mono Bold for numbers, vendored in `assets/fonts/` with `OFL.txt` and `PROVENANCE.txt` (`src/ui/ui_fonts.gd`).

### World prompt parts

A world prompt (`src/ui/world_prompt.gd`) shows an icon and a title of at most three words at range, and adds its detail lines within 12 m of the ball (`DETAIL_RANGE`). A reward gate sets its `detail_range` to its reach (`LOST_BEYOND`, 110 m), since a gate is chosen by steering at it from across the yard, so the ball is near every gate in view and the slot's width alone decides whether its sign shows detail.

- **Structured.** An owner calls `prompt.set_parts(title, detail, icon)`:
  - `title` is at most three words.
  - `detail` is lines joined by `\n`.
  - `icon` is an Icons id: `obj_gate` for a reward gate, `obj_fabricator` for a fabricator, `obj_vault` for the vault, or `fac_fleet` for a Brindle readout.
- **Parsed.** Until the owner calls it, the text it sets is parsed.
  - The first line is the title. Text after a colon, and words past the third, move to the front of the detail. The remaining lines are the detail.
  - The icon is `obj_vault` for a title starting "Vault", `obj_fabricator` for "FABRICATING..." or a detail that names a price in scrap, and `obj_gate` otherwise.
- **Unchanged.** The prompt's `text` stays what the owner wrote, so owners and tests that read it keep working. The HUD places the drawn size (`shown_extent()`) in the prompts band as before. A sign (`on_anchor`) is the exception: its drawn size comes from `fit_sign(slot width)`, and its detail is wrapped to at most two lines inside its rectangle.

## Threat grammar

Every enemy threat is a committed telegraph (`src/combat/telegraph.gd`) or boss hazard (`src/boss/hazard.gd`) with one attack type from `src/combat/threat_grammar.gd`: `Threat.Type.INSTANT`, `WAVE`, `PROJECTILE` or `LANE`. The type decides how the threat draws and sounds; the committed geometry decides where it hits. Both nodes build `descriptor()` from the fields `contains()` reads, and the grammar draws from that descriptor, so the drawing and the damage cannot disagree.

| Type | Draws | Hurts | Row |
| --- | --- | --- | --- |
| INSTANT | a sharp edge; a striped fill closing in from the edge over the warning; a solid flash on landing | the whole area, at once | `threat_instant`: `ring`, `threat_tick` |
| WAVE | a faint dashed reach; a bright front at speed x elapsed, chevrons, a curtain as tall as its height band; 15% stripes on the swept ground | only the front band, `WAVE_EDGE` (1 m) either side | `threat_wave`: `wave`, `threat_whoosh` |
| PROJECTILE | a dotted flight trace to the landing point; a reticle whose brackets close on the blast edge | the blast ring, when the shell lands | `threat_projectile`: `cross`, `threat_whistle` |
| LANE | rails and a far cap; a striped fill running from the source | the strip, where the body or beam is | `threat_lane`: `bar`, `threat_hum` held from the draw, cut by `threat_tear` on the frame it goes live |

Instant, projectile and lane also draw their height band as posts and a rail at `reach`.

The landing (FX-05): on the tick a hostile enemy telegraph goes live, an instant, projectile or lane on the ground leaves an ink crack ring and a dust kick at its committed edge for half a second (`Threat.flash`, `Threat.landing`), and the attacker's body wears HAZARD for two physics frames on its strike (`enemy.gd` `_show_strike`). A wave, an air-only net, an aerial ring, a harmless field and the player's own marks leave no crack. Display only: nothing reads it for damage.

Every type's warning sound plays on the frame the threat is declared (`audio.gd` `_warn_threat`). A LANE also has a release half: both nodes emit `went_live` when the warning ends (`Hazard.step` reaching `warn_seconds`, `Telegraph.set_progress` reaching 1), and on that frame the held hum stops and `threat_tear` plays. The tear is fire time (SOUND-STORY section 7), so it lands on the tick the charge, lunge or beam starts, at any warning length.

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
  - `slots() -> Array` returns W1's ability-slot records in bar order: `{slot, id, icon, key, cooldown_frac, charges, max_charges, state, gauge, pool, refill}` (W1-06 added `pool` and `refill`). `state` is `ready`, `cooling`, `active` or `unavailable`. `cooldown_frac` is the share of the recharging charge still to go, 0 when full. `gauge` is the fill of a charging hold, 0 to 1, for the reticle ring.
  - `set_max_charges(slot, n)` and `set_cooldown_scale(slot, s)` are the item seams. Charges recharge one at a time and stockpile. No scale takes a cooldown under `COOLDOWN_FLOOR` (0.4 s), and `AbilityState.floored(base, scale)` applies the same floor to cooldowns outside the slots, such as combat's `rocket_cooldown_scale`.
  - `Gauge` is the one hold-gauge-release rule. Only ticks with the key down fill it. Release fires at the fraction reached, a full gauge fires by itself 0.5 s later, and a cancel spends nothing.
- **The grammar** is the same for every class: LMB weapon, RMB class movement, F hold-gauge-release special, Ctrl smash, Space jump, Shift boost. `Intent` adds `special_held`, `special_released`, `movement_pressed`, `movement_held`, `movement_released`, `fire_released` and `cancel_pressed`. The ball turns an RMB press made during any charge into `cancel_pressed`. Sable's grapple rides RMB through the intent; `game.gd` has no RMB branch.
- **Skill-shot geometry.** `player.indicator` (`src/movement/indicator.gd`) is player-owned and draws to VISUAL-LANGUAGE §3 and §4: class colour (never `Palette.HAZARD`), a 15% clean fill, a charcoal keyline, rounded caps, the class's rim ticks, a dashed full-charge extent and a fill that breathes on a 0.5 s period at full. `player.yours(record)` adds the colour and ticks. `set_shape(layer, record)` draws exactly the record a release commits (a record with nothing to draw yet, such as marks with no points, is skipped), and `last_shape[layer]` keeps the last one drawn. An aim mark's record is a cone with `aim` and `clear`, built in one place in `player_ball.gd` (`bank_geometry()` returns the bank shot's): the line the ball would leave along, drawn as one dashed line and a root of fill from its clear edge, on its own surface whose material fades it near the lens; `kit.vault_aim` is empty on any tick a kick is not on offer, so its mark never shows on a mount. `collapse(layer)` shrinks a cancelled or knocked shape into its origin in 120 ms. A record with `blocked` draws in bone, dashed, with a charcoal cross, and its release fires nothing. Hit tests forgive a hull up to `AbilityState.FORGIVENESS` (18%) past the drawn edge: combat's `in_ring()` and `in_line()` are the rule.
- **Crowd control.** `player.crowd_control(kind, shove := Vector3.ZERO, interrupts := true) -> bool` is the one door for a stop an enemy imposes. An interrupting one force-cancels every charging gauge (publishing `gauge_cancelled(id, kind)`) and collapses the indicator; a steady pull passes `interrupts = false` so it does not wipe a charge every tick. It applies the shove (an acceleration, as `add_external_accel`) and returns true. While Rivet sprints it does neither, publishes `cc_ignored(kind)` at most every 250 ms per kind and returns false. Damage never goes through it. Its users: combat's committed-hit knock (`knock`), the Warden's pulse (`warden_pulse`), and Brindle's tug (`brindle_tug`, steady), slag bounce (`brindle_slag`) and charge shove (`brindle_charge`). Wave 3's crowd control should use it too. The world's flood and event pushes stay on `add_external_accel`: they are terrain, not crowd control.
- **Contact.** `src/movement/contact.gd` is the bowling-ball rule: `rebounds(weight, heft, sprinting)` and `rebound_velocity(v, normal, jump_speed)`. The ball asks `heft_of` (combat wires it to `combat.heft`) and an enemy's `weight`. A body without `weight` is never a rebound. A rebound refreshes like a stomp through `player.refresh_air()`.
- **Enemy sight.** Combat hands chasers, lobbers and minibosses a `Sight` proxy as their target (`ball_position()`, `planar_velocity()`, `add_external_accel()`), which answers the cloak's smoke point to enemies beyond `CLOAK_SIGHT` of their reach. An enemy that needs more of the player must add it to the proxy.
- **Bus facts and their owners.** Movement (`player_ball`) publishes `enemy_rebounded`, `vault_kicked`, `sprint_started`, `blink_used`, `arc_slammed`, `skid_smashed`, `demo_slammed`, `cc_ignored`, `dashed` (the movement burst of any class) and the slingshot's `gauge_*`. Combat publishes `enemy_pinned`, the specials' `gauge_charging`, `gauge_released` and `gauge_cancelled`, `cloak_started`, `cloak_broken`, `sticky_detonated` and `rocket_jumped`. `special_used(special_id, at)` now carries `detonation_gauge`, `overdrive_blast` or `detonation_line`.

## Loot and shop (v2 W4)

Build owns the items, their triggers, the run and difficulty clocks, and Moss's shop economy (DESIGN-V2 sections 5, 7 and 12). Everything below is reached through `ctx.build`.

### Triggers (`src/build/triggers.gd`)

- **The vocabulary is closed at twelve kinds:** `on_hit`, `on_kill`, `on_smash`, `on_rebound`, `on_vault`, `on_charge_release`, `on_cloak_break`, `on_land`, `on_speed_tier_up`, `on_pickup`, `on_damage_taken` and `timed`. A thirteenth kind is a code change. Each kind's glyph is `trg_<kind>`.
- **Every kind reads a fact that is already published.** No other module emits anything new.

  | Kind | Read from |
  | --- | --- |
  | `on_hit` | `enemy_struck` |
  | `on_kill` | `enemy_killed` |
  | `on_smash` | `slammed`, `arc_slammed`, `skid_smashed` and `demo_slammed`, at most one per tick |
  | `on_rebound` | `enemy_rebounded` |
  | `on_vault` | `vault_kicked` |
  | `on_charge_release` | `gauge_released` (the amount is the fraction) |
  | `on_cloak_break` | `cloak_broken` |
  | `on_land` | `landed` (the amount is the impact) |
  | `on_damage_taken` | `player_hit` |
  | `on_pickup` | build's own scrap pickup |
  | `on_speed_tier_up` | build's own read of `player.speed_tier()` |
  | `timed` | the item's own clock |

- **The handlers only queue.** The passes resolve in build's physics step (TADR-008).
- **Proc coefficients.** A discrete action has a base proc of 1.0. `on_hit` and `on_kill` read the strike kind: `ram`, `stomp`, `slam` and `shell` 1.0; `arc` 0.6; `turret` and `pin` 0.5; `runner` 0.4; `synergy` 0. Build's own strikes never post `on_hit`. An item's `proc_coeff` multiplies the base.
- **The guard.** A root commitment opens a pass and takes one draw from build's loot stream. That stream is reseeded at each stage entry and is never `ctx.rng`. Inside the pass a kind already queued or resolved is refused, so each kind fires at most once per commitment and every pass ends within twelve resolutions. Domino Wire's explicit chain is capped at `MAX_CHAIN_DEPTH` 1.

### Part fields (`src/build/part_def.gd`)

- **New fields:** `trigger`, `proc_coeff`, `stack_rule` (`linear`, `hyperbolic` or `capped`), `stack_cap`, `icon_category` (the `cat_` family), `element` (the `el_` glyph), `effect` (`{"do": id, ...}` from `item_effects.gd`'s closed `EFFECTS`), `charges` (slot to extra `max_charges`), `needs` and `shop_only`.
- **Stack caps.** For linear and capped rows, `stack_cap` counts copies. For hyperbolic rows it is a value ceiling below 1. `PartDef.Stacking.value` is the one rule.
- **The seam gate.** A part whose `needs` seam is missing is never offered. Build fills `Parts.seams` at run start.

### The pool

- **Rows.** `Parts.rows()` holds the 28 first catalogue rows, the 58 new rows of `items.gd` and Moss's four shop-only cells. The first two together are I2's 61-item table plus 25 older rows.
- **Generated items.** A generated item's id is its recipe: `gen:<base>:<rarity>:<element|none>:<trigger>`. `Parts.def(id)` rebuilds it, so a generated part stacks, survives a retry and reads in the run log like any other.
- **Rolls.** `Parts.roll` draws each slot's rarity by the weights 60/27/10/3. A slot is a generated recipe 25% of the time. It down-weights parts already offered this stage (`offered`).
- **Class items.** `glide_vane`, `jet_vent` and `cloak_flask` go only to Kest. `sprint_cell` goes only to Rivet. `grapple_coil`, `anchor_spring` and `vault_battery` go only to Sable.

### Build API additions

| Call | Returns |
| --- | --- |
| `enemies_near(at, radius, count)` | the nearest enemies |
| `item_hit(enemy, damage, element := "")` | strikes as `synergy`, after the weapon multiplier, and applies the element where it lands |
| `item_procs()` | item id to procs this run |
| `trigger_stats()` | `{passes, fired, refused, max_same_kind, leaked}` |
| `has_perk(id)` | `lens` (hint marks name the synergy) or `par` (the par ghost) |
| `set_modifiers({"scrapless": bool, "par": bool})` | the class screen calls it before `choose_class`; it applies at `run_started` |
| `run_tags()`, `scrapless()` | the run's modifier tags; also on `ctx.run.get_meta("run_tags")` |
| `clock_record()` | the clock record below |
| `clock_paused()` | true while the ball is in Moss's bay |
| `shop` | the shop economy below |

**Scrapless.** No scrap pickup and no kill scrap. Gates, vaults and won events add no part. A gate still publishes `reward_chosen`, so the launch handshake holds.

**Gate offer records** add `family`, `icon` (`cat_*`), `trigger_icon` (`trg_*` or `""`) and `element_icon` (`el_*` or `""`). A gate draws the three glyphs beside its topper and pulses when it completes a synergy. Gates and fabricators pass `set_parts(title, detail, icon)` with `obj_gate` and `obj_fabricator`.

### The clock record (W1 draws it)

`clock_record()` returns:

```
{run_seconds, stage_seconds, timer_icon: "res_timer",
 difficulty: {fraction 0..1, tier 0..2, tiers 2, paused, icon: "res_difficulty"},
 par: {on, best (seconds or null), split (stage seconds - best, frozen at the Warden break), broken},
 tags}
```

- The difficulty schedule is the director's (45 s a tier, two tiers). `build_clock_test` fails if they drift.
- The bar pauses while `clock_paused()`. The par timer does not.
- `par.best` is the best `ticks_to_warden_break` for this stage in `runs.ndjson`.

### Moss's shop (`ctx.build.shop`, W6 and W1)

The shop is an economy with no geometry.

- **Result record.** Every verb returns `{ok, reason, part_id, price, scrap, bark?}`. `reason` is one of `ok`, `cant_afford`, `sold_out`, `locked`, `capped`, `no_reroll`, `welded`, `not_held` or `closed`. `bark` is `{line_id, text, root}`.
- **Line ids** are `moss.<beat>.<n>`, `moss.<beat>.<class>`, `moss.restart`, `moss.relent.<n>`, `moss.bark.<moment>` and `moss.remember.<key>`. The text is SOUND-STORY section 8's, word for word; `shop_lines_test` checks it.

| Call (caller) | Does |
| --- | --- |
| `enter()` (W6, the ball enters the bay) | stocks the shelf and the hook, pauses the difficulty clock, returns the greeting line |
| `leave()` (W6, the exit pad) | returns the leaving bark and restarts the clock |
| `shelf_offers()` (W1) | three `{index, part_id, name, price, sold, rarity, text, icon, trigger_icon, element_icon, affordable}`; with --actives on the last may be an active offer (`part_id` `active:<id>`), which adds `active`, `maker` and `headline` |
| `buy(index)` | spends scrap and adds the part with source `shop`; an active offer is racked instead (`combat.actives.take`) |
| `reroll_price()`, `reroll()` | one reroll per visit: 12 scrap, times 1.5 for each visit after the first |
| `charge_offers()`, `buy_charge(slot)` | `{slot, part_id, price, cells, cap, max_charges, icon, can}` for each slot that recharges; a cell is a shop-only part, at most 2 per slot, and the slot's ceiling is 4 charges |
| `sell_offers()`, `sell_quote(part_id)`, `sell(part_id)` | half the part's current price back; heft drops with the part |
| `top_shelf()`, `buy_top()` | `{part_id, name, price, locked, needs_class, heft_class, lock_icon: "res_heft", sold, relented}`; locked until the heft class at entry plus one |
| `talk()` (the key glyph by Moss) | `{beat 0..5 or 6 restart or -1 relent, beat_id, line_id, text, root, grumble, exasperation, relent, restart, loops}` |
| `greeting_line()`, `history`, `note_death(scrap)` | the remembers-you line; `history` takes PROGRESSION's keys (`died_last_run`, `won_last_run`, `class_changed`, `skipped_visits`); `relented_before` and `neglected` come from the codex and this run |

- **The loop.** Six beats, then the restart line, then fresh variations. A visit never repeats a variation until they are all used. Class lines are extra choices for that class.
- **The relent.** Once the heft class reaches the lock, the next press relents, the hook unlocks and the codex discovers `too_heavy_for_you`.

### event_kinds (`LOOT_ROWS`)

These rows are for shop and item facts that are not bus signals: `shop_entered`, `shop_left`, `shop_bought`, `shop_charge`, `shop_rerolled`, `shop_sold`, `shop_refused`, `moss_beat`, `moss_relent`, `item_proc` and `par_split`. Each `sound_next` names the cue W5 is to bake.

### Codex (category `build`)

`codex_declarations()` now also returns `strike`, `spare`, `turkey` (the bowling score, `src/build/lanes.gd`) and `too_heavy_for_you`.

### Requested shared-file changes (W4 handback)

1. **`run_state.gd`.** Add `remove_part(part_id, reason)`, which removes one copy and publishes a `part_lost(part_id, reason)` fact that combat rebuilds on, then `heft_class_dropped` if the class fell. Add `refund_scrap(amount)` for the wallet only. Until then the shop removes the part itself and never sells a pattern part (`welded`).
2. **`run_log.gd`.** Add `line["tags"] = run.get_meta("run_tags", [])` in `_write`.
3. **World's director.** Skip advancing `stage_time` while `ctx.build.clock_paused()`.
4. **Combat.** Add `pattern.gd` transformer rows `fan_spread` and `helix_drill`, and `extend_cloak(seconds)`.
5. **Movement.** Add `player.set_vault_cooldown_scale(s)` and `player.set_vault_charges(n)`. Five parts wait on these seams and are not offered until they exist.

### Upgrade trees (v2 W3)

One binary tree per pilot (DESIGN-V2 §15). There are four picks: the start pick at class select, then one at Moss's workshop after each of stages 1, 2 and 3. Each tree has 2, 4, 8 and 16 nodes by depth, 30 in all, and 16 end builds. A pick lasts the run, and a new run starts with the untouched kit.

- **Where.** The run's picks are `player.tree` (`src/core/upgrade_tree.gd`, also `player.kit.tree`). The data is `src/core/trees/sable.gd`, `rivet.gd` and `kest.gd`, in heap order: node `i`'s children are `2i + 2` and `2i + 3`.
- **Node record.** Every field below is a string unless noted.
  - `id`.
  - `name`: at most 3 words.
  - `effect`: at most 8 words.
  - `key`: `weapon`, `movement`, `special` or `smash`.
  - `icon`: an `ab_` id.
  - `tags`: an Array from `UpgradeTree.TAGS`.
  - One or more ops: `swap`, `knob`, `proc`, `pattern`, `charges` or `cooldown`. The header of `upgrade_tree.gd` says what each op does.
  - `UpgradeTree.problems(class_id)` is the validator. `tree_data_test` fails on any sentence it returns.
- **Picking.**
  - `offered(class_id, depth) -> Array` returns the two node records a pick chooses between. At depth 1 that is the root pair; after that it is the children of the pick one depth up. It returns `[]` for a depth not reached yet or for another class.
  - `pick(node_id) -> bool` takes an offered node. It refuses anything that was not offered and anything past the picks opened so far.
  - `pending()` is true while a pick is open.
  - `path()` returns the ids picked so far.
  - `open_checkpoint()` opens the next pick. The ball calls it on `run_started` (depth 1) and on `stage_cleared(1..3)`. When W6's bay takes over the visit, the bay calls it instead, and the one-line `stage_cleared` hook in `player_ball.setup` goes, so a visit never opens two picks.
  - A skipped pick stays open. Taking it then offers the next depth at once.
- **The start pick (W1).** The pair is known before the run exists: `UpgradeTree.nodes(class_id).slice(0, 2)`. Class select shows it, calls `flow.choose_class(i)`, and then calls `player.tree.pick(id)`. The depth-1 offer is already open when `choose_class` returns.
- **Bus.**
  - `tree_offered(class_id: String, depth: int, choices: Array)` carries the two node ids.
  - `tree_picked(class_id: String, node_id: String, depth: int)` fires after the pick's effects are live.
  - Both have event rows: economy, bone, diamond, with `sound_next` set to `motif_fork` and `motif_pick` for W5. Neither has HUD words; the pick UI owns the wording.
  - `special_used` can now also carry `point_blank`.
- **Icons.**
  - `UpgradeTree.icon_of(class_id, node_id)` returns `{id, notch}`: the node's `ab_` glyph plus one variant notch per depth. The notch is the one VISUAL-LANGUAGE §5 asks V2 to draw (primer ruling 12).
  - No new ids are required. V2 may later give the three slot swaps their own glyphs; proposed ids are `ab_sable_crater`, `ab_rivet_point_blank` and `ab_kest_rain`. Until then they wear their slot's glyph and notch.
- **The director (W7).** `player.tree.branch_tags() -> PackedStringArray` is read-only and returns a copy. It lists the build's leanings in pick order. The vocabulary is `air`, `burst`, `close`, `ranged`, `mobility`, `mounted`, `sustain`, `cc_immune`, `traps` and `stealth`. Weight packs so they test the build; never hard-counter it.
- **Items and the shop (build).**
  - A pick changes the live ability state on its own. `AbilityState.swap` keeps the slot's `max_charges` and `cooldown_scale`, because items and picks raise the slot, not the ability in it.
  - A tree `charges` op adds to the current cap.
  - **Build's charge upgrades must also add** (`set_max_charges(slot, abilities.slot(slot).max_charges + 1)`) and never set an absolute count, or they erase a pick.
- **Variants plug in by table, never by branch.**
  - A variant is one `AbilityState.ABILITIES` row. The rest of the game reads that row's capabilities: `pattern`, `mounted`, `lob`, `augments`, `rocket`, `cloak`, `plant_discharge`, `flavour` and `spends_special`.
  - A variant that plays differently adds one entry to the table its slot dispatches on:
    - combat's `_specials`, keyed by the special slot's id;
    - combat's `_actions`, keyed by proc action;
    - the ball's `_smashes`, keyed by the smash flavour.
  - Knobs are read at the point of use through `tree.knob(name)`: `kit.knob()` in movement, `_knob()` in combat.
- **Mastery (later).** Alternate branches from mastery unlocks would be extra node lists offered in place of a pair. The demo ships none.
- **Tests.** `tree_data_test`, `tree_apply_test`, `tree_play_test` and `tree_bot_test`. The play and bot tests run children at a fixed 90 fps through `tests/trees/child_runs.gd`, which gives the same ticks as real time, in parallel.

## Charge and cooldown layers (coordinator, after the W3 merge)

A slot's charge cap and cooldown scale take two layers: upgrade-tree picks change them directly (add to the cap, multiply the scale), and `item_effects.apply_abilities` re-applies the item layer as a delta it records on the slot (`item_charges`, `item_scale`). Nothing may set an absolute cap or scale except `AbilityState` on a new run. `tests/build_charge_layers_test.gd` holds this in both orders, through sell-back and the cap.

## World and stage v2 (v2 W6)

- **Signals** (`game_events.gd`, world publishes all three): `bay_entered(banked_speed)` when the cradle catches the ball; `bay_left(velocity)` when the pad fires it out or it rolls off the deck; `world_fact(kind, at)` for every contraption, terrain, layer, ride and toy fact. `kind` keys `EventKinds.WORLD_ROWS` (read with `EventKinds.world_row(kind)`), each row naming its sound id. Presentation (W5) needs listeners for all three; until then `presentation_sfx_test` lists them as unheard.
- **Terrain** (`terrain.gd`): `height()` is the higher of the grid and every live overlay; `overlays` resets from the map's `start_overlays` on `use()`. Also `landmark_point(index)`, `layer_at(point)` ("sky", "shelf" or "undercroft"), `in_bay(point)`, `moss_point()`, `near_moss(point)` and `ground_callable(index)`. Maps may define `overlay_height(id, x, z, ground)`; the default returns -INF.
- **Event director** (`event_director.gd`): `terrain_event(id)` returns the live `TerrainEvent` model; terrain events announce through `event_announced`, start through `event_started`, and swap through `world._swap(id)`, which logs `swap_log` rows with the call's microseconds.
- **Bay reads**: `world.bay.inside`, `in_yard(point)`, `on_deck(point)`, `deck_y()`, `cradle_at`, `facing`. While `inside`, world stops the difficulty director, the event clock and pushes and emits pressure 0.
- **Shop seam**: world calls `ctx.build_module().shop.enter()` on the catch and `leave()` on the way out, keeping the returned line in `world.bay_bark`. Build's own clock reads `shop.clock_paused()`.
- **Upgrade picks**: world opens `player.tree.open_checkpoint()` on the catch, or at `stage_cleared` for a skipped bay, once per stage per run (`world._open_pick`). player_ball keeps only the `run_started` pick.
- **Yard**: inside the yard lines world refills each slot's current charges with `abilities.grant(slot, max_charges)`. It never writes a cap or a cooldown scale (Charge and cooldown layers).
- **Carry in calm**: the barge carry fact is applied even when `ctx.calm` is set; the thermal's lift is a world push and applies only when not calm.

## v2 V3 hero assets (`src/presentation/hero_assets.gd`)

`presentation.gd` creates the hook as `presentation.hero_assets` and calls `setup(ctx)`. It edits no gameplay file. It reads only these existing seams.

| Owner | What the hook reads | What it adds |
| --- | --- | --- |
| `movement/player_ball.gd` | `class_def`, `class_color()`, `state.velocity`, `kit.gliding`, `roll_node()` (whose parent is the rolling mesh), `juice_node()`, `pod_mount()` | `HeroCore` under the rolling mesh, `HeroPod` under the pod mount (`pod_mount()`); the greybox ball mesh is hidden |
| `build/accretion.gd` | Each direct `MeshInstance3D` child is a chunk; its slot index is read back from `position` (`_slot(i, MAX_CHUNKS) * 1.02`) | `HeroChunk` under each chunk; the box is hidden |
| `build/reward_gates.gd` | Each child `Node3D` is a gate; its offer is the `offers` row whose `at` matches its position; `Topper`, `Glyph<i>` sprites, `rarity_color()` | `HeroArch`, `Topper/HeroTopper`, one `HeroPlate<i>` per glyph; posts, bar, topper and heart are hidden |

- **Hidden means hidden.** A placeholder keeps its node, script and transform, with `layers = 0` and shadows off. Anything that animates it (the topper's spin and pulse, the chunk pop and fling, the squash) still drives the hero child.
- **Slots to colours.** `SLOTS` in the hook is the one table from section 9 slot names to palette roles. glb surfaces are named for their slot. Change a colour there or in `palette.gd`, never in a recipe.
- **Shell nodes.** Each `shell_<class>.glb` is `Shell<Name>` > `Core`, `Pod` > `Dome` > `Pilot`, plus `RopeExit` (Sable) and `VaneL`/`VaneR` (Kest, hinged about Godot Z). The glbs use Godot axes, +Y up and -Z forward.
- **Carrier bank (MOTION-SPEC row 208, draw only).** `HeroAssets.carrier_bank(pod)` returns the world `Basis` of the bank the carrier wears now: a tilt about the horizontal axis `UP x normal` that leans the carrier's up toward the smoothed contact normal, the smallest angle that keeps `WeaponRing` and the bracket modules within 0.99 m along it (`carrier_bank.gd`; identity on floors and in the air). The `WeaponRing`, the `Fairlead` carriage and every part named in `HeroAssets.BRACKET_PARTS`, which `_split` moves under a `Pod > CarrierBank` holder, wear it as `bank * yaw`; the pod, the pilot and the Gyro rings stay level. Row 207's gimbal drive reads `carrier_bank(pod)` and leaves `counter_tilt` alone. `LineView.fairlead_point` takes the bank, read from the player's `carrier_bank` meta.

**Not wired (for the coordinator after W7 merges).** `warden_clamp_base.glb` is `WardenClampBase` > `Housing`, `Tower` > `KitMount`, `JawL`, `JawR`. The beacon stands at the origin. The jaw origins sit on the vertical hinge axis at x 2.2, so rotating them about Y opens the clamp, and closed is the modelled pose. `warden_kit_{reactor,hive,mind}.glb` roots sit at `KitMount`. Each has a `WeakPoint` node, plus `Vent0..2` (reactor), `Drone0..5` (hive), and `ArmL`, `ArmR` and `Shutter0..5` (mind). Their slots are `ancient_enamel`, `ancient_light`, `bare_metal` and `rubber` (the charcoal grooves). The hook's `paint(node, {})` dresses them with no tint.

**Requested seams (not blocking).**

1. **`player_ball.gd`.** Done (MOTION-SPEC swing row): `RopeExit` rides the `Fairlead` carriage on `HeroPod`, 1.06 m out on the anchor's planar side, and `line_view.gd` draws the rope from that fairlead. Physics still pulls through the centre.
2. **An ability-active fact per class.** Would let `class_accent` brighten only while its device works (section 9, "emissive only at the working device").
3. **`palette.gd`.** Add `ANCIENT` (W7's delta). The hook then drops its local candidate-A constant.

## Enemies v2

- **The roster** (`src/combat/roster.gd`) is the one source for an enemy: `faction`, `role`, `mechanic`, `telegraph`, `holds`, `breaks`, `tag` (and `tag_next`), `hold`, `tests` and `line`, per kind. `Roster.COUNTERS` is the Fleet unlock order and `Roster.ANCIENTS` the three families. `Roster.voiced(id, motif)` turns `mind_quote` into `mind_<motif>`.
- **Spawner kinds.** `spawn_enemy` also takes `mag_trapper`, `hooker`, `netcaster`, `bola_thrower`, `plated_brute`, `deflector`, `winch_drone`, `gyro_jammer`, `swatter`, `ramp_flipper`, `catch_trap`, `reactor_relic`, `swarm_remnant` and `mind_hand`. One `swarm_remnant` spawn brings its whole rack of six. Every one is in group `enemy`, carries `kind` and `faction`, and sees the player through `Sight`.
- **`combat.fleet`** (`src/combat/fleet.gd`) owns `holds`, `habits`, `mind_memory` and the swarms. `build_read()` on the spawner returns `{class, habits: {habit: share}, branch_tags}` for the director.
- **Holds** (`src/combat/holds.gd`, `fleet.holds`). A unit never touches the ball; it calls `catch(source, kind, breaks, max_seconds, shove, anchor)`, then `pull(source, accel)` each tick, and `release(source, reason)`. Both go through `player.crowd_control`, so Rivet's sprint refuses them. Tenacity: 1.8 s summed over a sliding 4 s releases every hold with the reason `tenacity` and makes `catch` refuse for 2.5 s. A player break is one of `jump`, `boost`, `smash`, `glide`, `speed`; it kicks the ball forward and refunds 0.6 s of the movement slot. `released(source_id, kind, reason)` is the node's own signal.
- **Bus facts and their owner.** Combat publishes `hold_started(kind, at)`, `hold_broken(kind, method)`, `hold_ended(kind, reason)`, `tenacity_gained(seconds)`, `pack_arrived(faction, at, kinds)`, `shield_vaulted(at, speed)`, `vent_charging(at, seconds)`, `vent_erupted(at)`, `swarm_scattered(at, drones)`, `mind_adapted(habit, icon)` and `weak_point_opened(point_id, at, seconds)`. `kind` in the hold facts is the unit's mechanic; `faction` is `fleet`, `reactor`, `swarm` or `mind`, and `EventKinds.faction_icon(faction)` is its `fac_` icon.
- **Packs.** The director times a pack's members on one arrival ring, so every reinforcement spawned in one physics frame is one pack; combat publishes `pack_arrived` once per faction in it. A lone chaser or lobber is not a pack.
- **The director's inputs** (`src/world/director.gd`). World may set `director.stage` (1 to 3; 0 reads it from the threat dial) and `director.build` (the spawner's `build_read()`); both default safely, so the director works before world sets them. `KIND_NAMES` holds every spawnable reinforcement; `packs` records each pack composed.
- **Warden family kits.** The stage Warden has `family` (`Roster.warden_family(stage)`), `family_point()` (`core`, `queen` or `lens`) and `family_open()`. The family point opens only on a stagger; an open point meets plating 0 through `plating_for(kind, part)`, is listed in `weak_points()`, and takes contacts near the top through `contact_part`. The swarm Warden keeps its guard-rack burst. Caps, the magnet, the mind brace, shred and the lessons were retired by F6 (2026-10-04).
- **The posture fight** (`src/combat/boss_posture.gd`, a scene-free rule object). Every Warden's `fight()` is `posture`: `resolve()` asks its `judge_hit(kind, punch, smash, tier)` first and returns its answer. `judge` is pure; `on_struck` calls `apply` once per strike; the Warden's `take_damage` removes only what a shattering strike armed, so no other path lowers its health. Readers: `fight()`, `posture()`, `staggered()`, `stagger_left()`, `chunks_left()`, `chunk_cracked()`, `glances()`. `posture_changed(enemy, posture, staggered)` goes out when the whole-number posture, the stagger, the chunk count or the crack changes. A stagger opens the core (`family_open()`, `weak_points()`, one `weak_point_opened("core", at, 4.0)`), pauses the pulse and cancels a charge in flight; `set_tint` is always `slate`.
- **The plating dress.** `set_tint("amber")` now means "breaks now": a class-colour rim (`Enemy.rim_color`, which fleet sets from the run's class row) and the open-crack glyphs; `"slate"` means closed dark plates. The state names are kept for their callers.

## Workshop UI (v2 W8)

- **Where.** The node `Workshop` under the game (`src/ui/workshop.gd`, a CanvasLayer on layer 4 that processes while paused; `game.get_node("Workshop")`) owns the upgrade pick (`pick`, `tree_pick.gd`), Moss's counter (`counter`, `shop_counter.gd`), his bubble (`bubble`, `moss_bubble.gd`) and the talk key (`talk`). It reads `player.tree`, `game.build.shop`, `ctx.terrain.near_moss(point)` and `world.bay_bark`, and listens to `tree_offered`, `tree_picked`, `bay_entered`, `bay_left`, `stage_entered` (a retry closes everything) and `flow_changed` (leaving play closes everything). World is unchanged.
- **The hold.** `game.gd` carries two one-line hooks: `_ready` adds the workshop as its child after the tuning panel, and `_input` skips its click-to-recapture while the game's meta `menu_held` is true. The workshop sets that meta while a screen is open, turns the ball's `keyboard` source off, frees the mouse through `game._capture_mouse(false)`, and for the pick holds `get_tree().paused`. It re-asserts all of it every frame and after every `flow_changed`, because game.gd writes the same state on flow changes and on P and Tab; P and Tab are swallowed while the pick is up. On release it restores the tree pause to `pause_toggled() or notes_held()`, the keyboard to `flow.in_play()` and the capture likewise.
- **armed.** `workshop.armed` is false in test mode, so no screen opens and nothing is held unless a test sets it.
- **The pick.** Opens deferred on `tree_offered` while in play, for `tree.path().size() + 1`. It calls `tree.pick(id)` and nothing else; a pending next depth reopens at once. `pick.chosen(index)` and `pick.later` are its signals; `workshop.open_pick()` opens a pending pick on demand (the counter's pick plate).
- **The counter.** Opens when `should_open_counter(shop.inside, near_moss, speed)` holds (in reach, under `PULL_UP` 4 m/s, re-armed after leaving reach). It parks the ball with `player.set_frozen(true)` and releases it on leave, a retry or leaving play. `counter.acted(fact, record)` carries every verb's result record with its `LOOT_ROWS` fact; a refusal of any verb is `shop_refused`.
- **Sound.** Shop facts play their `LOOT_ROWS` stand-in through `presentation.audio.play(fact, 0, pitch, "UI", row.sound)` when that method exists. A talk beat's pitch is its babble `root` relative to D3.
- **Words.** The calm-screen budget is 40 words per screen, counted by `word_budget.gd` over the workshop layer. The fight HUD budget (25) is unchanged.
- **Tests.** `ui_workshop_pick_test`, `ui_workshop_shop_test` and `ui_workshop_bay_test`; the input helper is `tests/workshop/push.gd`.

## Pause menu and help (v2 W10)

- **Where.** The node `PauseMenu` under the game (`src/ui/pause_menu.gd`, a CanvasLayer on layer 6 that processes while paused; `game.get_node("PauseMenu")`). It sits above the screens (5) and the workshop (4) and under the field notes (10). `is_open()`, `open()`, `close()`, `press(id)` and `row(id)` are its surface; the ids are `resume`, `restart`, `notes`, `music`, `effects` and `quit`.
- **game.gd hooks.** There are two small hunks. `_ready` adds the pause menu after the workshop, and `_screen_key` maps H on the title to `screens.toggle_help()`. Pausing goes through the existing `toggle_pause()`, `pause_toggled()`, `hold_notes()` and `_capture_mouse()`. P and Esc in play belong to the pause menu; field notes keep Tab only.
- **Coexistence.** It opens only when `flow.in_play()`, the game's meta `menu_held` is false and the notes are not held. On close it restores `get_tree().paused` for an open workshop pick.
- **Audio.** `audio.set_volume(bus, level)` sets `volumes[bus]` (0 to 1; SFX also sets UI) and calls `_apply_volumes()`. The menu plays its ticks through `audio.play("flow_changed", 0, pitch, "UI")`.
- **Settings.** `settings_store.gd` reads and writes `settings.json` in `game.storage_dir` as `{"volumes": {bus: level}}`. The per-process folder in test mode keeps tests off the player's file.
- **Help.** `screens.toggle_help()` and `help_open()`; `button_for("help")` and `button_for("back")`. The page (`help_page.gd`) lists the `FieldNotes.CONTROLS` rows that carry `caps` (key glyph ids) and `short` (one or two words).
- **Tests.** `ui_pause_menu_test`.
- **Auto-pause (w33).** The node `AutoPause` under the game (`src/ui/auto_pause.gd`, processes while paused) opens the pause menu in play when the window loses focus (`NOTIFICATION_APPLICATION_FOCUS_OUT`, which Godot sends on X11 about 0.25 s after the focus leaves) or when the pad last touched disconnects (`Input.joy_connection_changed`). It only calls `open()`, so the coexistence rule above holds, and it never closes the menu: the player resumes. A pause that a held screen keeps shut (a reward ceremony ends on its own timer) is owed and opens the frame the screen lets go, unless the focus or a pad came back first (`owed()`). Each pause moves the node last under the game, so its `_input` runs ahead of the pause menu's. It does nothing while `game.bot_driven` is set (tests, bots, `--self-play`). `pause_menu.note(text)` shows one line under PAUSED ("Controller disconnected" until a pad connects) and `note_text()` reads it; `close()` clears it. For `CLICK_GUARD_MS` after the focus returns to an open menu, mouse presses are swallowed, so the click that focuses the window takes no row. Tested by `auto_pause_test`.
- **Comfort rows (v3 W11).** `shake` (Screen shake) and `hitstop` (Hit-stop) sit under `effects`, drawn by `volume_row.gd`. A step calls `presentation.juice.set_comfort(id, level)` and `store.set_comfort(id, level)`; `settings.json` gains `"comfort": {id: level}`, applied at launch like the volumes. Tested by `presentation_comfort_test`.

## Juice v3 (v3 W11)

- **Rows.** `EventKinds.JUICE` holds how hard each fact lands, keyed by its `ROWS` kind: hit-stop bands, particle counts, camera shake, kick and punch, streak windows, the ball's pulse and the per-weapon shot feel. `juice.pulse(amount)` is the one door to the ball's swell: pulses that land together add, and the door holds any pile of them to a swell of a fifth (`PULSE_MAX`, `SHELL_SWING`) while one pickup lands as its row says. `EventKinds.STOP_GAP_MS` (clear time after a stop ends), `STOP_WINDOW_MS` with `STOP_WINDOW_BUDGET_MS` (60 ms per 300 ms), `STOP_BUDGET_MS` (100 ms per second) and `STOP_PER_EXTRA_HIT_MS` bound the stops. Every stop goes through `juice.request_hit_stop`, so all of them share the one budget. Presentation reads these rows; nothing else does.
- **`near_miss(kind, at)`.** Combat's watch (`src/combat/near_miss.gd`, `ctx.spawner.near_miss`) publishes it. It reads every node in the `threat` group through its own `contains()` and `descriptor()` (`live` or `progress >= 1` means landed). It fires when the ball was inside during the warning and is outside when the threat lands, or leaves within `grace_ms` without a `player_hit`. It never changes an outcome.
- **Read-only combat hooks.** `ctx.spawner.last_player_hit` is `{from, shove, source, frame}` for the last hit the ball took (presentation's edge flash). `ctx.spawner.sticky.stuck(at)` is the charge manager's own signal for a thrown charge biting in.
- **Knockback by class.** `knock` in `Weapons.BASE` is a gun's shove (3 to 6 m/s); a bomb's is its row's `knock` (26) and `BURST_KNOCK`, `LINE_KNOCK`, `OVERDRIVE_KNOCK` (24 to 34); a ram's is `Augments.RAM_KNOCK` (24). The enemy's `weight` divides every shove. Tested by `combat_knockback_test`.
- **Momentum.** Every feedback kick is camera and shell only. Hit-stop is `Engine.time_scale` through the spine. The ball's velocity changes only where the design already does it (the rocket jump). Tested by `presentation_hitstop_test` and `combat_knockback_test`.

## Interact seam (v3 L3)

E is interact everywhere (`design-v3/LOOP-REDESIGN.md` section 9). World owns the system (`world.interact`, `src/world/interact.gd`), its family rows (`src/world/interactables.gd`) and its devices. The spine keeps one hook.

- **Routing.** The spine hook is `player.interact_claim`. World sets it to `world.interact.claims` (`claims(face_in_reach: bool) -> bool`). `player_ball._route_interact()` asks it on an E press before Sable's mount, passing `face_in_reach()` (the pylon's face test, now on the player and shared with `key_glyphs.gd`). A claimed press becomes `intent.interact_pressed` and clears `intent.mount_pressed`, so it never also plants a pylon. Three things keep E for the mount. Mounted, E always drops off. A mobility move already under way (`player.mobility_started()`: the hook in, a slam plant, the slingshot drawing) is never interrupted. A lock farther than `REACH` yields to a face Sable could mount. `intent.mount_held` is E held. `key_glyphs.gd` shows the pylon glyph only when E would mount. `hud.gd` fills the reticle's class ring with `interact.hold_fraction()`.
- **Lock.** E locks the nearest ready device within `Interactables.LOCK_REACH` (18 m) of its `reach_point()` and inside `FACING_DEG` (60 degrees) of the camera's look. That gives a 40 m/s ball about 0.45 s. A travel device locks anywhere in its lane. The lock holds, facing or not, until the device is `RELEASE_REACH` (24 m) away, so a hold may finish after the ball has passed. While a hold runs, the held device keeps the lock. `interact.target` is this tick's lock.
- **Consent.** Each family row's `consent` sets it. `roll`: E in the lane arms it, and it fires as the ball crosses the mouth. `hold`: E held for `HOLD_SECONDS` (0.35 s); a release or losing the lock first does nothing. `press`: E once.
- **Families.** Each `Interactables.FAMILIES` row holds `icon`, `shape`, `color`, `accent`, `cost`, `consent`, `verb`, and the sound register: `arm`, `fire`, `won` and `lost`, each as `{sound, sound_next}`. Audio resolves each fact's cue with `Rows.heard(Interactables.sound(family, beat))`. VFX draws the family's shape and colour. `PLACEMENTS[stage]` lists each stage's devices, so the map files stay untouched.
- **Signals** (`game_events.gd`). The interact system and its devices publish all four, and presentation hears all four.
  - `interact_armed(family, device_id, at)` when consent is given.
  - `interact_fired(family, device_id, at)` when the device acts.
  - `ambush_ended(device_id, won, at)` when an altar's clock or pack ends; a won altar also calls `run.add_core("ambush", at)` first.
  - `bet_resolved(device_id, won, stake, at)` after a crate's `run.add_core("bet", at)` times the stake, or its `run.burn_cores()`.
- **Devices.** A device extends `src/world/device.gd`. It overrides `build`, `reach_point`, `ready_now`, `gauge` (a not-ready fill 0 to 1, or -1), `terms` (the words after the family verb), `fire`, `tick` and `stand_down`. `fire()` returns true when the device acts at once; false means the device calls `system.fired(self)` itself after its own beat. The base owns the prompt grammar, drawn through `WorldPrompt.set_interact(icon, words, key, fill)`:
  - within 30 m, the family glyph alone;
  - locked and ready, the E keycap, the glyph and at most `PROMPT_WORDS` (5) words, so a cost or a stake is on screen before any hold starts;
  - not ready, the gauge round the glyph and no keycap.
- **Luck.** `interact.luck(device_id)` returns the device's one stream for this run and stage, seeded by `luck_seed(run seed, run.run_id, stage, device_id)`. A stage restart replays it, so a restart never re-rolls a result. Another run (another `run_id`) rolls differently. A replay that restores `run_id` (the run log keeps it) matches. It never touches `ctx.rng`.
- **Economy rules** (review findings 7 and 10).
  - A bet is one committed wager per device per stage, and its stake shows on the locked prompt before the hold. A restart replays the same roll.
  - A family whose `cost` is `scrap` (allies) charges wallet scrap through `run.spend_scrap()`, which keeps mass, so paying never shrinks heft. Only a telegraphed theft (`run.lose_scrap`) takes mass.
  - A "call the Warden" device (fights, not built) must keep a real cost at the clock's cap. When the clock can jump no further, the call still costs something else, for example this stage's cores.

### How the lift (writer L1) and later travel devices adopt roll-through

1. Build the device once, parented under its stage's geometry root, with `world.interact.travel(id, mouth, heading, on_fire, parent)`. It returns a `TravelDevice` (`src/world/travel_device.gd`) that is registered for good. It sleeps while that stage's root is parked (it is live only while visible in the tree), so it needs no per-stage registration. With no `parent` it belongs to the current stage and goes at the next stage change.
2. `on_fire(ball: Vector3, velocity: Vector3)` is the owner's launch, for example `world.ride = RideRail.arc(...)`. The system calls it on the tick an armed ball crosses the mouth, then publishes `interact_fired("travel", id, at)`. A device that adopts consent must not also fire on mouth contact alone.
   - The ride banks the ball's speed and gives it back, never less. `device.banked` is the planar speed the ball crossed with; pass it as `RideRail.arc()`'s `planar_in`. The ride's release returns that speed or the ride's floor, whichever is higher (`ride_rail.gd`). A fixed 85% return is not allowed.
3. Two fields are optional. `device.ready_check` is a Callable returning bool; a not-ready device shows its gauge and no keycap. `device.destination` sets the words after "Ride: to", 5 words at most.
4. `RollThrough` (`src/world/roll_through.gd`) is the pure model a custom device may carry in `roll` instead. Its fields are `mouth`, `heading`, `length` (12 m), `half_width` (5 m) and `mouth_radius` (3 m). Its calls are `in_lane(p)`, `arm()` and `step(from, to) -> bool`. It tests the crossing on the tick's segment, so a ball at any speed fires. A ball that leaves the lane or crosses wide disarms it at no cost.

**Tests.** `world_interact_test` covers routing, a far lock yielding to a face, a started move keeping E, a lock at 40 m/s finishing after the pass, tap and hold, roll-through, a missed mouth and prompt words. `world_ambush_test`, `world_cache_test` and `world_bet_test` cover the devices; the bet test includes one wager per crate, the stake on the prompt, and a restart replaying the roll.

## Reward ceremony v3 (v3 W13)

- **Rows.** `EventKinds.LOOT_ROWS` holds `reward_common`, `reward_rare`, `reward_reveal`, `reward_ceremony` and `reward_payoff`, each with its tier, colour, sound, pause rule (`never` or `calm`) and timings. `REWARD_TIER_BY_RARITY` is the ladder from a part's rarity to its tier, `CEREMONY_SOURCES` lists the `part_gained` sources that are always a ceremony, and `REWARD_RUNGS` sets each rarity's bell on the reward ladder.
- **One rarity read.** `RewardCeremony.rarity_of(part_id)` reads the part row's `rarity`, and `tier_of(part_id, context)` maps it. No other code picks a tier per part id.
- **Sources.** A module that grants a ceremonial find calls `run.add_part(id, source)` with a source from `CEREMONY_SOURCES` (`cache`, `cage`, `warden` and `evolution` are reserved for sources not yet on this base). Nothing else is needed.
- **Reads, never decides.** The ceremony reads `part_gained`, the payoff facts and `build.item_procs()`. It pauses the tree only when calm, sets `menu_held` while it holds, and hands back the ball's exact velocity. `presentation.ceremony.pause_armed` is off in test mode.
- **Audio.** `audio.stop(sound)` cuts every SFX voice of a sound (a skipped build). Tested by `presentation_ceremony_test`.

## Boss contract

`src/boss/boss_contract.gd` (`BossContract`) lists the duck-typed surface a boss answers, and `tests/boss_contract_test.gd` checks it. `BossContract.conforms(obj, surface)` returns the missing or mistyped names (empty means conforming) and `describe()` prints both lists. Each row is a name, an argument count and a return type.

- `TARGET` is the boss body, an enemy node, as combat, the plate, the ring, audio and the run log call it: `fight`, `posture`, `staggered`, `stagger_left`, `chunks_left`, `glances`, `chunk_cracked`, `judge_hit(kind, punch, smash, tier)`, `take_damage`, `is_dead`, plus the enemy protocol combat reads (`plating_for`, `hit_mult`, `contact_part`, `on_struck`) and the calls and fields combat makes on any struck body without a guard (`knock`, `flash`, `set_tint`, `plating_now`; `plating`, `hp`, `max_hp`, `radius`, `half_height`, `kind` in `TARGET_PROPERTIES`, which `conforms` checks for `TARGET`). A method conforms when its argument count sits between its required and declared parameters. `combat.resolve()` sends any enemy whose `fight()` is `"posture"` through `judge_hit` before the plating rule.
- `MODULE` is the module on `ctx.boss`, as flow and the HUD call it: `enter_arena(entry_velocity)`, `exit_arena`, `active`, `ground_height_at`, `music_state`, `objective_text`.

Who conforms: the posture Warden (slice table) and Brindle's hull (`boss_target.gd`, forwarding to `boss.gd`) conform to `TARGET`, and the Slag Bowl module (`boss.gd`) conforms to `MODULE`; the test checks all three live. The Waking and the Mind answer `MODULE` through `stub_boss.gd` (see Per-boss modules below).

Brindle on the posture rule (unit F2a): `boss.gd` owns one `BossPosture` built from `boss_rules.gd` `POSTURE` (`curve` 2.0, `ram_shatters` false, the slice Warden's numbers). Only the hull answers `fight()` `"posture"`; the magnets, caps and scooter answer `"plating"` and keep combat's plating rule, and a full hit on one adds to the hull's bar as the rule weighs a hit at that plating, never touching an open core. A vent-cap slam on the hull's deck is judged at the cap's plating. A stagger opens the cockpit for its window. Health is the four chunks: `hp` reads the chunks left and `MAX_HP` is 4. Shattered chunks one to three end Requisition, Furnace and Scuttle, each no sooner than its phase's minimum seconds; a chunk broken early holds the phase and the hull takes no posture until the set piece ends. The fourth chunk is the scooter, taken by the catch through `_defeat`, which runs once, publishes `boss_defeated` and passes the scooter's `last_damage_source` to `run_state.record_kill`. A striker that skips `judge_hit` (the boss tests' spawner double) still meets the rule: `on_struck` judges the hull hit itself. Brindle publishes no `posture_changed` or `weak_point_opened`; the plate, ring and audio read is unit F2b's.

Limitation: `ctx.boss` is one slot, so two modules cannot both be current. The test only shows two conforming doubles can exist side by side without touching it; a real multi-module slot is not built.

### Per-boss modules

- **Table.** `Worlds.BOSSES` (`src/core/worlds.gd:22-29`) names, for `brindle`, `waking` and `mind`, the module `script`, the `music` section, the `title` and the `built` flag. All three rows are built. An optional `stamp` (the Mind's `HIRED`) is inked under the victory title by `screens.gd`.
- **Lookup.** `flow._module_for(world)` (`src/core/flow.gd:141-147`) reads the row's `script`, returns the scene's module for the scene boss, and otherwise loads and sets up the script once and caches it by path in `_row_modules`, shared by every row that names it. `flow.boss_row(world)` (`:167`) is the row, with `boss_row_override` for tests.
- **Scripts.** Brindle is `src/boss/boss.gd`. `src/boss/waking.gd` and `src/boss/mind.gd` extend `src/boss/stub_boss.gd`, which answers `MODULE` (`stub_boss.gd:45-223`: `active`, `enter_arena`, `exit_arena`, `ground_height_at`, `music_state`, `objective_text`).
- **The Waking** fights three floors over the stub's pit: `FLOOR_NAMES` Spoil, Seam, Bedrock (`waking.gd:14`), each shattered chunk telegraphs the highest live floor and drops it `FLOOR_WARN` later (`waking.gd:16`, `:66`).
- **The Mind** uses the `mind_attacks.gd` families `lane`, `split_lane`, `rush` and `plate` (`mind_attacks.gd:26`), a choir Warden whose stagger braces against the ball's habit (`warden.gd:511-518`; the objective line names the braced kinds, `mind.gd:191-192`) and `mind_hand` spawns from phase 2 (`mind.gd:11`, `:173`).

### Breach plates

`src/world/breach.gd:5-13` is the rule: a plate is `{id, rect: Rect2(x, z, w, d), drop_to}`, a slam inside an unbroken plate's rect breaks it, once per stage entry, and `slam()` returns the opened ids. The map supplies the plates (`map_dig.gd:28` `BREACH_PLATES`); `world.gd:189` builds a `Breach` for a map that has `breach_plates`, and `world.gd:384-394` swaps the overlay and the cover box for each opened id, sends one `breach_opened` fact (the `WORLD_ROWS` row copied as `Breach.ROW`) and marks it. `world.gd:399` `_breach_strike` strikes the tier below.

### Net deck

`src/world/map_highdraft.gd:3` and `:12`: islands stand over a flat net deck at `NET_H` (10.0). Only two ramps exist, both on the beacon island's bridge-mouth shoulders, listed in `RAMPS` (`:33-36`, `RAMP_HALF` `:37`, `RAMP_GRADE` `:38`), so a ball that falls to the deck can climb back toward the Warden. `highdraft_crown` inherits them through `_ramps()`; no other island has one.

### Row-level packs

`Director.author(def, stages)` (`src/world/director.gd`; `world._author_director` calls it) reads the stage row's `packs`, `elite` and `elite_arrival` and falls back to the table's (`stages.packs()`, `elite()`, `elite_arrival()`). The director spawns only authored packs when any exist. `Director.kinds_sent(def, stages)` names every kind those packs and that elite hold; `BakeWarm` stands each one out of sight before play.

### Table rows 1 to 6

`AlphaDefs.DEFS` (`src/core/alpha_defs.gd`), one row per stage with its world, map name, Warden family and variant. Map names resolve through `Terrain.MAPS` (`src/world/terrain.gd:13`).

| Stage | World | Map | Family and variant | Rows at |
| --- | --- | --- | --- | --- |
| 1 | 1 | `spillway` | reactor, none | `alpha_defs.gd:49-54` |
| 2 | 1 | `reach` | swarm, none | `:55-60` |
| 3 | 2 | `dig` | reactor, `meltdown` | `:61-70` |
| 4 | 2 | `dig_deep` | swarm, `brood` | `:71-80` |
| 5 | 3 | `highdraft` | mind, `choir` | `:81-90` |
| 6 | 3 | `highdraft_crown` | mind, `choir` | `:91-100` |

Rows 3 to 6 carry their own `packs`; rows 1 and 2 use the table's `PACKS`.

### Relic spot

`relic_spot` is an optional one-Vector2 map slot (`src/world/zone_schema.gd:7-9`, checked at `:59`). A map that has it gets a relic cache that always offers a relic (`src/world/interact.gd:57-66`), built after the terrain swap so the pedestals read the new ground. `map_dig.gd:45`, `map_dig_deep.gd:48`, `map_highdraft.gd:59` and `map_highdraft_crown.gd:62` set it.

## Run store (RS2)

`src/core/run_store.gd` (`RunStore.new(path = "user://run.json")`) keeps one run document on disk. It is pure file logic: it takes and returns the Dictionary `RunState.to_entrance_doc()` makes and does not know flow.

- **File.** `{"schema": 1, "generation": n, "run": <entrance doc>}`, written through `SafeStore.write_atomic`. `MIGRATIONS` maps a schema to its step (`0` rewrites v0's `[world, count]` retry pairs into the string-keyed map). A migrated file is kept as `run.json.v0` on the next save.
- **Calls.** `load() -> Dictionary` (`{}` for no run), `save(doc) -> String` (`""` saved, else a named cause: `newer_schema`, `quarantine_failed`, `changed_on_disk`, `backup_failed`, `write_failed`; `last_error` has the sentence), `clear() -> bool`, `generation()`, and the cause `run_ended`, and static `merge(ours, theirs)`.
- **Failure rules.** An unreadable file moves to `run.json.bad` with its bytes and loads as no run; the next save proceeds. A newer schema is left untouched, `load` returns `{}` and `save` refuses with `newer_schema` until `clear()`. `clear()` over a readable file writes a tombstone `{schema, generation: N+1, ended: true}` instead of deleting it; `load` treats it as no run, and a `save` from a store holding an older generation is refused with `run_ended`, so a second instance cannot resurrect an ended run. A missing, unreadable or newer-schema file is removed as before.
- **Merge.** A save whose file has a higher generation than the one we hold, and a load of a lower generation than the doc held in memory, merge: per world `retries_spent` takes the larger, and the run doc's extra keys `ended` (bool), `death_save_spent` (bool) and `worlds_cleared` (world ints) never go back (true stays true, lists union; a stale copy never hands a spent earned save back). A caller that sets those flags writes them into the doc it saves.
- **Caller (RS3).** `load()` once when continuing, `save(doc)` at each zone entrance, at each stage launch (SA-F1: `RunState.to_cleared_doc` marks the doc `cleared` with the run as it stands at the launch and the launch velocity; a Continue lands that flight, so `stage_cleared` fires, the owed workshop pick opens unless `pick_opened`, and the run enters the next stage or the world's boss arena; entering the arena saves the doc again marked `landed`, so a Continue from the fight re-enters it without a second `stage_cleared`; a quit at the open gates is before the exit and replays the entrance) and when the earned save is spent (flow's `_on_death_saved`, on `death_saved`, writes the entrance doc with `death_save_spent` true), `clear()` when the run ends for good (set `ended` first if a save must precede it). Test: `run_store_test`.

## Profile (`src/core/profile.gd`, META-7 and RS4)

`Profile.new(path)` keeps `profile.json`, schema 2. Preferences stay in `settings_store.gd`.

- **Schema 2 adds three fields.** `companion` is the companion's own dictionary (`Companion.to_dict()`: owned pieces, sockets, escape flag), stored and returned opaque through `companion()` and `set_companion(doc)`; the loader that applies it is `Companion.from_dict`, which refuses a bad one. `settled` is the list of settled one-time grant ids. `rewards_settled` is a bool marker, set once through `mark_rewards_settled()`.
- **Migration.** `MIGRATIONS` maps `0` and `1` to their steps. `_migrate_1` passes every schema-1 field through and adds the new ones empty. The first save of a migrated file keeps the old bytes as `profile.json.v1` (`.v0` for schema 0). A file with a schema above this build's (schema 3 today) is never saved over.
- **Merge** (two writers, one file): `settled` and owned pieces are unions, the saver's assembly and escape flag win when it has an assembly (else theirs), and `rewards_settled` never goes back to false.
- **Settle-once (RS4).** `Progress.settle(id) -> bool` is true the first time only. The run document's optional `settled` list (`RunState.settled`, entrance key `settled`, strings) and the profile's `settled` list are one set: an id in either is settled and settling copies it to both. `reconcile_settled()` unions the two after a run document loads. `grant_once(id, kind, target)` settles then unlocks a pilot, cosmetic or world and saves; achievement rewards go through it as `reward:<achievement>:<kind>`.
- **Owed.** Grants outside the profile still unguarded by the ledger: the build module's hotwire offer (`build.gd` `_hotwire_id`) and discovery-part offers, and companion piece finds. They live outside the profile files; each should call `progress.settle(id)` before it fires. Tests: `profile_store_test`, `unlock_settle_once_test`.

## Sitting notes and the play watch (w33, ruling cg)

- **Launch flag.** `--sitting-notes` (after `--`, or as an engine argument) adds the node `SittingNotes` under the game (`src/core/sitting_notes.gd`, processes while paused). Without the flag the node is never made, and a `test_mode` game never makes it. `--sitting-notes-hitch=<ms>` changes the hitch limit (25 ms).
- **File.** `user://sitting-notes/notes-<UTC start>.ndjson`, one JSON row a line through `SafeStore.append_line`, closed after every row so a crash keeps them. The game prints `SCRAPKEEP_SITTING_NOTES <full path>` once at launch. Every row has `t` (seconds since the notes started), `utc` and `kind`: `start`, `stuck`, `hung`, `wedged`, `fell`, `objective`, `blank`, `bar`, `hitch`, `mark`, `end`. The file's header comment lists each kind's fields.
- **Mark.** F8, or both sticks clicked together on a pad, writes a `mark` row with the place, the objective's words and the frame rate. Nothing shows and nothing sounds. The notes never mark input as handled, so the sticks' own bindings still fire.
- **Reads only.** The notes and the watch write no game state. The watch (`src/core/play_watch.gd`) takes a game and a sink: `watch(game, sink)`, `step(delta)` once a physics tick of play, `read_text(since)` about once a second, and the totals `counts`, `plates`, `blank_max`, `bar_off_max`. A bot's run uses the same watch through `tools/qa_watch.gd` (`bot_run --qa-log=1`, `--self-play-watch=1`), which adds the bot's goal to each row.
- **Reading a row.** `stuck` is also what a person standing still for 8 s writes. `blank` reads the row the HUD chose, not the pixels drawn. `bar` is the hull bar standing more than 5% of a full bar away from the hull for 3 s of play, timed from the first reading that found it off (one reading alone is never a row): it reads the share the HUD gave the bar (`hud.hull_shown()`), not the pixels drawn. A `hitch` row is one burst of long frames, cut every 5 s; frames while the window is not focused are not counted.
- **The film reads what the watch cannot.** `--self-play-film=<dir>` (`tools/eye_film.gd`, with `--self-play-keys=1 --self-play-eyes=1`) saves the picture on the screen at each screen, held screen, objective change, first prompt, offer, big hit (at most 16 a film, each with its two seconds of lead-in), stage clear, boss phase and death, one row of the game's own state a frame in `film.ndjson`. It needs a rendered display and `--fixed-fps`; it draws only the frames it keeps unless `--self-play-film-live=1`, so it is never a frame-time reading. In eyes mode the game is not told a bot is playing: the launch take and the briefing show, and each held screen is answered with its first key after 3 s. `--self-play-plant-hide=objective` draws the objective plate clear for a film's control run; the watch still reads its words. The red team's player's-eye pass (`scripts/redteam/README.md`, `scripts/redteam/eye.mjs`) is the user.
- **Tests.** `play_watch_test` (every row kind made to fire, with its look-alike that must not; no game), `sitting_notes_test` (a real game: the file, a real stuck row, hitches, marks, the end row), `world1_run_test` (the watch on six launched runs), `session_test` (the watch on a keys-only session: quit and Continue, a death and a second run).
