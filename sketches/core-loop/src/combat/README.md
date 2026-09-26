# Combat and classes (writer A)

This folder is `ctx.spawner`. It owns the two class kits, the weapon pattern system that parts transform, the enemies and their committed telegraphs, the miniboss, damage and drops, and the shoulder view while mounted. Other modules reach it only through `ctx.spawner` and the `GameEvents` bus, as [CONTRACTS.md](../../CONTRACTS.md) requires. Nothing here reads another module's folder.

## Files

| File | Holds |
| --- | --- |
| `combat.gd` | the entry script: the spawner API, the pattern API for parts, the fire and special loop, the shoulder hook, the stage reset |
| `pattern.gd` | the emission pattern Resource and the transformer catalogue |
| `weapons.gd` | the base pattern per weapon, strike kinds, colours, overdrive and the pylon discharge |
| `hitscan.gd` | the shared aim query every weapon reads |
| `bolts.gd` | every live player projectile, the live cap and the crowd fade |
| `effects.gd` | chain arcs, blast rings and impact sparks |
| `telegraph.gd` | the committed ring or lane an enemy attack both draws and damages with |
| `enemy.gd` | what every enemy shares: health, weight, knock, flash, death, telegraph |
| `chaser.gd`, `lobber.gd`, `projectile.gd`, `miniboss.gd` | the enemies and the lobber's shell |

## Spawner API

`spawn_enemy(kind, at) -> Node3D` adds the enemy under `ctx.root` at `at`, wires its committed hits to `run.damage(amount, kind)` and its death to `run.record_kill(kind, at, scrap)`, then emits `enemy_spawned`. Pass a point with clearance, for example `ctx.terrain.drop_point(x, z, 3.6)` for the miniboss. The spawner does not check `ctx.calm`; a caller that spawns on its own schedule checks it, as the director does.

| Kind | Health (times stage threat) | Scrap | Weight | Attack |
| --- | --- | --- | --- | --- |
| `chaser` | 40 | 3 | 1 | a 0.6 s wind-up lays a lane 11 m long toward you, then it lunges down it |
| `lobber` | 26 | 4 | 3 | the muzzle glows for 1.3 s, then it commits a 3.6 m landing ring where you will be and the shell lands there 1.9 s later |
| `miniboss` | 900 | 24 | 5 | alternates a leap slam (a 7 m ring) and a charge (a 30 m lane), with a 2.4 s weak window after each attack |

An unknown kind spawns a chaser and prints a warning.

Every enemy is in group `enemy`, on physics layer 3, and implements `knock(direction, force)` and `flash()`. Modules may also read `kind`, `hp`, `max_hp`, `is_dead()` and `telegraph()` (the live ring or lane, or null). The miniboss adds `state_name()` (`stalk`, `slam_crouch`, `slam_leap`, `charge_brace`, `charge`, `weak`), `is_weak()`, `attacks` and `weak_windows`. An event that is won by killing the miniboss listens for `enemy_killed` with kind `miniboss`.

`strike(enemy, kind, force)` resolves one hit. The spine's contacts pass `stomp`, `ram` and `slam`, and combat's weapons pass `runner`, `arc` and `turret`. `enemy_struck` goes out before the damage.

## Pattern API for parts (writer B)

A weapon's volley is a `pattern.gd` Resource. Parts never touch weapon code; they name **transformer ids**, and combat folds those ids over each weapon's base pattern.

- `ctx.spawner.register_part(part_id, transformer_ids: Array)` says a part applies these transformers. Call it from `build.setup(ctx)`, since combat is set up first. A part whose id is itself a transformer id needs no registration.
- Each entry in `run.parts` applies its transformers once, so a part taken twice applies twice. Combat recomputes every pattern from `run.parts` on `part_gained`, `run_started` and `stage_entered`. The recompute is idempotent, so a retry restores the build exactly. Do not apply transformers yourself.
- `transformer_ids()` lists the ids. `transformer_info(id)` returns `{label, text}` for gate and fabricator wording.
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

| Class | Weapon id | Fires | F (special id) |
| --- | --- | --- | --- |
| Runner-gunner | `rapid_laser` | 12 a second, 7 damage, a 0.25 m field, laser-true | `overdrive`: a 12 m ring blast (30 damage, a heavy shove), then 3 s of 1.6 times the fire rate; 6 s cooldown |
| Pylon engineer | `arc_caster` | 5 a second, 12 damage, a 0.55 m field, one chain jump within 9 m | `pylon_turret`: the pylon discharge, powered by your current speed, or by the bank while mounted; 5 s cooldown |
| Pylon engineer, mounted | `pylon_turret` | 9 a second, 11 damage, two chain jumps within 16 m, 95 m range | as above |

Planting a pylon as the engineer fires the discharge for free, powered by the banked speed. That is the turret's opening burst, and it publishes `special_used("pylon_turret", at)` like the key does. Speed buys arcs (2, plus 1 per 5 m/s, up to 8), reach (12 m plus 0.45 m per m/s, up to 30 m) and damage (14 plus 1.4 per m/s). `discharge_preview(speed)` returns what a given speed would fire now.

Both classes fire while rolling. The runner can plant too, since the kit is shared, and keeps its laser in the shoulder view. The turret and the discharge belong to the engineer.

## What combat publishes

- `shot_fired(weapon_id, from, to)` fires once per volley, not per bolt. `from` is the muzzle and `to` is where the centre bolt is sent: the reticle's point, or the cover in front of it. `weapon_id` is `rapid_laser`, `arc_caster` or `pylon_turret`.
- `special_used(special_id, at)` fires for overdrive and for each discharge, including the opening burst on a plant.
- `enemy_struck(enemy, kind, force)`: for weapon kinds, `force` is the damage before the enemy's armour.
- `enemy_spawned(enemy, kind)`.

## The aim

Every weapon reads one aim query (`hitscan.gd`). The camera's centre ray, which the reticle marks, finds the point. It starts level with the ball, so nothing behind the shooter catches it, which matters in the shoulder view. A second ray from the ball to that point finds cover. The centre bolt of every volley flies from the muzzle straight at the point and never corkscrews, so what the reticle shows is what the shot hits (TADR-008). There is no aim magnetism. The arc caster forgives with a wider field and its chain instead.

## Enemy attacks and the committed telegraph

An enemy damages the player only through its committed telegraph. The attack lays a ring or a lane once, at commit, and later asks that same node's `contains(ball)`. Touching an enemy that is not attacking costs nothing but the bump. Rings and lanes reach 3.5 to 4 m above the ground under the ball, so a jump or a glide clears them. A hit taken shoves the ball 5 to 10 m/s along the attack through `ctx.player.add_external_accel`.

Telegraphs draw in `HAZARD` with no depth test at render priority 40. Player bolts draw at 0 and combat's effects at 1. **For presentation (writer C):** keep juice below priority 40 and out of `HAZARD`, so no effect of ours ever paints over the next threat.
