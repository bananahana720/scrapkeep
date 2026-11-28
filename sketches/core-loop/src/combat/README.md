# Combat and classes (writer A)

This folder is `ctx.spawner`. Originally structured around two class kits in v2, it now owns all six playable pilot kits (`src/core/class_def.gd`, `weapons.gd`, `weapon_driver.gd`; see `design-v3/PILOT-CADENCE.md`), the weapon pattern system that parts transform, the plating rule, the enemies and their committed telegraphs, the miniboss, the Warden and the vault, damage and drops, the `enemy` codex entries, and the shoulder view while mounted. Other modules reach it only through `ctx.spawner` and the `GameEvents` bus, as [CONTRACTS.md](../../CONTRACTS.md) requires. Nothing here reads another module's folder.

## Files

| File | Holds |
| --- | --- |
| `combat.gd` | the entry script: the spawner API, the pattern API for parts, the fire and special loop, the shoulder hook, the stage reset |
| `weapon_driver.gd` | the weapon trigger, cadence, magazine/reload, charge/beat/window state machine and read-only reticle snapshot owned by `combat.gd` |
| `hero_hooks.gd` | Sable's kinetic orbit pylon and vault-kick charge, Rivet's sixth hot round ricochet and Kest's fuse-spark trace, owned by `combat.gd` as `hero_hooks` |
| `consumable_runtime.gd` | the consumables in play: dropped cartridges, the C-key use, Nitro Siphon, Overclock Card, Foreman Memo, Anchor Flare balloons and the counter-kill drop roll, owned by `combat.gd` as `consumables` |
| `tally_kit.gd` | Tally's kit: the cards and their pressure, the gather plate, the ledger clips and clip post, the stamp ink, the three set pieces and their settles, and the kit's discovery cards, owned by `combat.gd` as `tally_kit` |
| `cannon_kit.gd` | the Remembered Cannon's kit: the committed lanes and set-piece calls, the walk, the wake, the recital, the lane paint, the Lane Charge line, the recoil surf and the piton stake, owned by `combat.gd` as `cannon` |
| `micro_mutations.gd` | the parts' micro-mutations (tread plating, long spool, dash vane, boost coil, loose trigger, long barrel) and the cross-system synergies (ricochet canyon, demolition derby, pendulum tesla, thermobaric dunk, gravity ledger, catalyst cartridge), with their counts, owned by `combat.gd` as `micro_mutations` |
| `grapple_mutations.gd` | the grapple mutations: the hot wire, the det cord, the live bus, the tether slam, the dragnet siphon, the wrecking flail and the sonic snap sling, owned by `combat.gd` as `grapple_muts` |
| `pattern.gd` | the emission pattern Resource and the transformer catalogue |
| `weapons.gd` | the base pattern per weapon, strike kinds, colours, overdrive and the pylon discharge |
| `hitscan.gd` | the shared aim query every weapon reads |
| `bolts.gd` | every live player projectile, the live cap and the crowd fade |
| `effects.gd` | chain arcs, blast rings and impact sparks |
| `telegraph.gd` | the committed ring, lane or wedge an enemy attack both draws and damages with |
| `threat_grammar.gd` | the four attack types (instant, wave, projectile, lane) and how each draws, shared with the boss's hazards; the stance a tint gives (hostile, the player's own, harmless) |
| `ground.gd` | the ground enemies, telegraphs and shells stand on: the terrain, or the boss floor in the arena |
| `enemy.gd` | what every enemy shares: health, plating, weak points, weight, knock, flash, tint, death, telegraph |
| `chaser.gd`, `lobber.gd`, `projectile.gd`, `miniboss.gd` | the enemies and the lobber's shell |
| `warden.gd`, `vault.gd` | the stage's Warden (pulse, vent caps, magnet) and the plated cache |
| `codex_entries.gd` | the `enemy` codex entries as data |

## Spawner API

`spawn_enemy(kind, at) -> Node3D` adds the enemy under `ctx.root` at `at`, wires its committed hits to `run.damage(amount, kind)` and its death to `run.record_kill(kind, at, scrap)`, then emits `enemy_spawned`. Pass a point with clearance, for example `ctx.terrain.drop_point(x, z, 3.6)` for the miniboss. The spawner does not check `ctx.calm`; a caller that spawns on its own schedule checks it, as the director does.

On `stage_content_cleared` (reason `arena` on arena entry, `arena_retry` on every arena retry, handled alike, before the boss module's `enter_arena`) combat frees every node in `enemy`, `enemy_shot` and `telegraph`, out of its group at once; a boss module spawns its adds after that call. The class kit's fire cooldown, special cooldown and overdrive reset there too, as they do on a stage retry, so a special on cooldown at death is ready in the retried fight.

| Kind | Health | Plating | Scrap | Weight | Attack |
| --- | --- | --- | --- | --- | --- |
| `chaser` | 60 x threat | 0 | 3 | 1 | a 0.6 s wind-up lays a lane 11 m long toward you, then it lunges down it |
| `lobber` | 26 x threat | 0 | 4 | 3 | the muzzle glows for 1.3 s, then it commits a 3.6 m landing ring where you will be and the shell lands there 1.9 s later |
| `miniboss` | 600 x threat | 1.25 x the stage Warden's, rounded; 0 in its weak window | 24 | 5 | alternates a leap slam (a 7 m ring) and a charge (a 30 m lane), with a 2.4 s weak window after each attack |
| `warden` | `warden_hp` | `warden_plating` | 30 x stage | immobile | every 6 s in reach: a 2 s telegraph, then +10 m/s straight up (and 10 damage inside 6 m); posture fight (F6 2026-10-04 retired the lessons) |
| `vault` | 400 x stage | the next stage's `warden_plating` (on the last stage, 1.2 times its own: 168) | 10 x stage | immobile | none |

Warden numbers come from `ctx.flow.stage_def()` (`warden_plating`, `warden_hp`, `beacon_radius` as its reach). The vault reads the next stage from the run's stage table, `ctx.stages.of(stage + 1)`, so a tuning edit to that table moves it too. Only a field a def is missing falls back to the spec's per-stage values: 30/60/95 plating, 400/700/1000 health. The Warden and the vault sit on the ground under `at`; the others are placed at `at`. An unknown kind spawns a chaser and prints a warning. Every enemy records its kill on the tick its health reaches 0: `died` fires, the spawner calls `run.record_kill`, and the body has already stopped colliding, before it leaves the tree at the end of the frame. A stage reset frees what is left without a kill, which is how a retry clears the field.

Warden lessons: `plate` adds nothing. `caps` adds three vent caps on top: a stomp or slam landing within 2.6 m of one meets plating 0 and hits for 1.5 times its punch. `magnet` swings a magnet arm up over the clamp every 8 s and lays a wedge from the arm toward you (35 degrees either side, a dashed rim, chevrons pointing home) for 1.5 s, then tugs a ball the wedge contains toward it at 3.5 m/s² for 1.5 s. The magnet is a weak point only in the tug: a weapon hit on it then drops the Warden's plating to 0 for 3 s, and a shot during the telegraph meets the body. It never pins and never pushes sideways.

Every enemy is in group `enemy`, on physics layer 3, and implements `knock(direction, force)` and `flash()`. Modules may also read `kind`, `hp`, `max_hp`, `is_dead()` and `telegraph()` (the live ring or lane, or null). The miniboss adds `state_name()` (`stalk`, `slam_crouch`, `slam_leap`, `charge_brace`, `charge`, `weak`), `is_weak()`, `attacks` and `weak_windows`. An event that is won by killing the miniboss listens for `enemy_killed` with kind `miniboss`.

Baked clips (world 1 unit 13): a kind with a clips file (`assets/models/world_one/clips/<kind>_clips.glb`, built by `tools/blender/world_one/field_motion.py`, checked by `tools/blender/verify_field_clips.py`) gets idle, move, windup, attack, hit and death clips from `src/presentation/enemy_clips.gd`. `enemy.gd` seats the driver on the first physics tick, passes it `react()` hits and hands it the death, which plays before the usual scatter. The driver reads only the attack facts and the body's motion, never changes a clock, collider or telegraph, and is off in headless runs unless a test sets `EnemyClips.headless`.

`strike(enemy, kind, force, part = "")` resolves one hit. The spine's contacts pass `stomp`, `ram` and `slam`; combat's weapons pass `runner`, `arc` and `turret`; a batted shell's blast passes `shell`; build's synergy shockwaves, shrapnel, frost rings and blades pass `synergy`, whose punch is the force given (build scales it by heft) and which always meets body plating: `resolve` drops any part it names, since a synergy is never a landing. `part` names a weak point (the Brindle boss can pass its own); a ball contact finds its weak point itself. `enemy_struck` goes out first, then `strike_deflected` when the punch fell short, then the damage.

## The plating rule

One function, `resolve(enemy, kind, force, part)`, decides every hit, and everything else reads it:

- Punch for `stomp`, `ram` and `slam` is `(base + force * k) * heft`, with base and k of 30 and 1.1, 14 and 1.3, and 0 and 1.2. Heft is `ctx.run.heft()` when the run has it, else 1.0. Punch for any other kind is `force`, the per-hit damage after parts.
- Punch at or above `enemy.plating_for(kind, part)` lands in full, times `enemy.hit_mult(kind, part)`. Below it the hit deals 20% and publishes `strike_deflected(enemy, kind, punch, plating)` when the bus has that signal.
- Called from an `enemy_struck` or `strike_deflected` handler with that strike's enemy, kind and force, `resolve(enemy, kind, force)` answers with the strike's own weak point, even one the caller named (a Brindle cap, a bolt on the magnet). A handler therefore reads the plating the hit actually meets, which is what presentation's hit-stop gate needs.
- `punch_now()` is the better of a ram at the ball's planar speed (from CRUISE up) and one hit of the weapon in hand. `plating_of(enemy)` is its plating right now. `integrity_of(enemy)` is hp / max_hp (1.0 for an invalid enemy). `would_crush(enemy, kind, force)` is true when the target's plating for that contact is 0 and the hit kills it outright; a plated break-through is not a crush. An enemy that cannot die at its current HP (a boss held at a phase floor) is never crushable: it implements `crushable()` returning false, and `would_crush` then answers false whatever the punch, so the crush pass-through never ends with the ball inside a live collider.
- `ram_punch_now()` is the ram term alone: a ram at the ball's planar speed from CRUISE up, 0 below it, with no weapon term.
- Shred: every landed hit, a chip included, strips 0.017 times its punch off that enemy's plating, capped at the most plating it has shown. While hits keep landing, and for 1.5 s after the last one, the strip decays at 0.05 a second, so held fire settles at a strip in proportion to damage per second. After that it decays at 1.0 a second and snaps to 0 below 0.5. `resolve`, `plating_of`, `would_crush` and the tint all subtract it, floored at 0, so a weak point already at 0 stays 0. `shred_of(enemy)` is the raw strip. An enemy with `set_shred(amount)` is told the strip every tick. The Warden takes no shred since F6 (2026-10-04). A stage or arena reset clears all shred. The rates are the wave-3b pass-8 rates (A4 started at 0.0184, 0.15 and 0.5 s; DESIGN-NOTES Feedback loop 16).
- Every physics tick, each enemy with plating is tinted amber when `punch_now()` beats its current plating and slate when it does not. An enemy whose `tint_verb()` returns `"ram"` (Brindle while charging, where only a ram clashes) is compared with `ram_punch_now()` instead; any other answer, or no method, means `punch_now()`.

Any enemy, including another module's, can take part by implementing `plating_now()`, `plating_for(kind, part)`, `hit_mult(kind, part)`, `weak_points()` (spheres `{id, at, radius}` a bolt tests before the body), `contact_part(ball, kind)`, `on_struck(kind, part, result)` and `set_tint(state)`. `enemy.gd` has the defaults.

## Pattern API for parts (writer B)

A weapon's volley is a `pattern.gd` Resource. Parts never touch weapon code; they name **transformer ids**, and combat folds those ids over each weapon's base pattern.

- `ctx.spawner.register_part(part_id, transformer_ids: Array)` says a part applies these transformers. Call it from `build.setup(ctx)`, since combat is set up first. A part whose id is itself a transformer id needs no registration.
- Each entry in `run.parts` applies its transformers once, so a part taken twice applies twice. Combat recomputes every pattern from `run.parts` on `part_gained`, `run_started` and `stage_entered`. The recompute is idempotent, so a retry restores the build exactly. Do not apply transformers yourself.
- `transformer_ids()` lists the ids.
- `pattern(weapon_id)` returns a copy of a weapon's current pattern. `active_transformers()` returns the ids the current parts apply.

| Id | Label | Effect per stack |
| --- | --- | --- |
| `cross_split` | Cross split | +3 arms around the aim line, at least 7 degrees out: a cross, then a seven-point star |
| `spiral_wave` | Spiral wave | the pattern turns 23 degrees per volley, and off-centre bolts corkscrew 0.35 m more; at least 2 arms |
| `chain_arc` | Chain arc | hits arc to one more enemy, 4 m further; the arc reaches at least 9 m |
| `damage_tier` | Hot rounds | +25% weapon damage, which also scales overdrive and the pylon discharge |
| `rate_tier` | Fast cycle | +20% fire rate |
| `range_tier` | Long barrel | +25% range, +10% bolt speed |
| `capacitor` | Pylon capacitor | the pylon discharge charges 50% harder; +3 m chain reach |
| `overclock` | Overclock | +30% fire rate; overdrive lasts 30% longer |

The pattern fields are `count`, `spread_deg`, `arms`, `arm_offset_deg`, `rotation_deg`, `spin_deg`, `wave_amp`, `wave_hz`, `damage`, `rate`, `range_m`, `speed`, `bolt_radius`, `knock`, `chain_jumps`, `chain_range`, `chain_falloff`, `burst_scale` and `special_scale`. A transformer row is data in `pattern.gd`: `add`, then `mul`, then `min` (a floor). A new transformer is a new row there, in this folder.

**The caps hold whatever stacks.** A volley has at most 16 bolts and 8 arms. Fire rate stops at 20 volleys a second, the corkscrew at 1.2 m and the arm offset at 14 degrees. At most 64 player bolts are live. Past that a new bolt retires the oldest, so at the heaviest stack the far end of the stream thins and the trigger never stalls. Bolts fade from 0.9 to 0.4 alpha as the count climbs. Damage has no cap.

## Weapons and specials

Build owns tuning mods (CONTRACTS). Combat reads `tuning.mod("weapon_damage")`, `weapon_rate`, `weapon_range` and, for the turret, `turret_damage` at the moment it fires, on top of the transformer pattern. They scale shots, `punch_now()`, overdrive and the discharge. A part should use a transformer or a mod for a stat, not both.

*(Note: `weapons.gd` now defines 7 weapon patterns across the six pilots — `rapid_laser`, `arc_caster`, `pylon_turret`, `sticky_charge`, `claw_sweep`, `ledger_reader`, `cannon_lane` — and active items replace the retired `F` special binding; see [design-v3/PILOT-CADENCE.md](../../design-v3/PILOT-CADENCE.md) and `src/core/bindings.gd`. The table below preserves the initial two-class baseline.)*

| Class | Weapon id | Fires | F (special id) |
| --- | --- | --- | --- |
| Runner-gunner | `rapid_laser` | 12 a second, 7 damage, a 0.25 m field, laser-true | `overdrive`: a 12 m ring blast (30 damage, a heavy shove), then 3 s of 1.6 times the fire rate; 6 s cooldown |
| Pylon engineer | `arc_caster` | 5 a second, 12 damage, a 0.55 m field, one chain jump within 9 m | `pylon_turret`: the pylon discharge, powered by your current speed, or by the bank while mounted; 5 s cooldown |
| Pylon engineer, mounted | `pylon_turret` | 9 a second, 11 damage, two chain jumps within 16 m, 95 m range | as above |

Planting a pylon as the engineer fires the discharge for free, powered by the banked speed. That is the turret's opening burst, and it publishes `special_used("pylon_turret", at)` like the key does. Speed buys arcs (2, plus 1 per 5 m/s, up to 8), reach (12 m plus 0.45 m per m/s, up to 30 m) and damage (14 plus 1.4 per m/s). `discharge_preview(speed)` returns what a given speed would fire now.

Both classes fire while rolling. The runner can plant too, since the kit is shared, and keeps its laser in the shoulder view. The turret and the discharge belong to the engineer.

## Codex entries (category `enemy`)

`codex_entries.gd` holds four entries: `shell_return` (a batted shell kills its own lobber), `counter_ram` (ram a chaser mid wind-up), `crush_chain` (three unplated one-hit ram kills in a second) and `parting_shot` (a weapon kill within 1 s of a slingshot); F6 (2026-10-04) removed `magnet_break` and `pulse_stomp` with the caps. Combat calls `ctx.codex.declare(entry)` for each at setup and `ctx.codex.mark_discovered(id, at, ["player"])` every time a trick fires, with no dedupe of its own; the codex dedupes per run and per attempt, so a trick first pulled in a retried attempt pays again after the retry. The codex publishes `synergy_discovered`, never combat. `discovered` and `discovery_log` hold this run's finds. A frozen chaser shattered by a ram waits for build's frost state.

**Batting a shell.** A bolt that reaches a lobber's shell in flight, or a ball at CRUISE or faster that passes within 2.4 m of one, sends it back at its lobber. The return commits a new ring, drawn in amber: it never hurts the player, and its blast strikes every enemy the ring contains with kind `shell` for 40.

## What combat publishes

- `shot_fired(weapon_id, from, to)` fires once per volley, not per bolt. `from` is the muzzle and `to` is where the centre bolt is sent: the reticle's point, or the cover in front of it. `weapon_id` is `rapid_laser`, `arc_caster` or `pylon_turret`.
- `special_used(special_id, at)` fires for overdrive and for each discharge, including the opening burst on a plant.
- `enemy_struck(enemy, kind, force)`: for weapon kinds, `force` is the damage before plating.
- `strike_deflected(enemy, kind, punch, plating)` for a hit whose punch fell short, once the spine adds the signal.
- `enemy_spawned(enemy, kind)`.

## The aim

Every weapon reads one aim query (`hitscan.gd`). The camera's centre ray, which the reticle marks, finds the point. It starts level with the ball, so nothing behind the shooter catches it, which matters in the shoulder view. A second ray from the ball to that point finds cover. The centre bolt of every volley flies from the muzzle straight at the point and never corkscrews, so what the reticle shows is what the shot hits (TADR-008). There is no aim magnetism. The arc caster forgives with a wider field and its chain instead.

## Enemy attacks and the committed telegraph

An enemy damages the player only through its committed telegraph. The Warden's pulse and tug are the same: the pulse tests the reach ring it shows and the tug the wedge it shows. The attack lays a ring, a lane or a wedge once, at commit, and later asks that same node's `contains(ball)`. Touching an enemy that is not attacking costs nothing but the bump. Rings and lanes reach 3.5 to 4 m above the ground under the ball, so a jump or a glide clears them. A hit taken shoves the ball 5 to 10 m/s along the attack through `ctx.player.add_external_accel`. Every push divides by the physics step actually run, so `Engine.time_scale` does not change its size.

**The ground in the arena.** Enemies, telegraphs and shells read the ground through `ground.gd`, not `ctx.terrain` directly. On a stage that is the terrain. When `ctx.flow.in_arena` is true and `ctx.boss` implements `ground_height_at(point: Vector3) -> float`, the boss floor answers instead, because the stage terrain stays parked under the bowl. A ring then centres on the floor you roll on, `contains()` measures height above that floor, and a drone lobber aims its landing at it.

Telegraphs draw in `HAZARD` with no depth test at render priority 40. Player bolts draw at 0 and combat's effects at 1. **For presentation (writer C):** keep juice below priority 40 and out of `HAZARD`, so no effect of ours ever paints over the next threat.
