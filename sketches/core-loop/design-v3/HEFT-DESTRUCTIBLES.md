# Heft destructibles (Wave 45, W45-C, spec only)

Andrew approved the payoff: **combat, optional shortcuts and capped light loot**. A heavier ball breaks heavier world props without losing a metre per second, and a lighter ball sees why it cannot. This page is the spec. It changes no code, data or test. Build units are in [section 10](#10-build-units-and-verification); nothing starts until the Gate admits a card.

Read with [AGENTS.md](../../../AGENTS.md) rules 7 to 10, [BIBLE.md](../../../BIBLE.md) (movement and growth), [Q-P22](../../../BACKLOG.md#q-p22), [DECISIONS.md](../../../project-guide/handoff/DECISIONS.md) ("Research first" and "Fixed outline"), [DRESSING-KITS.md](park/DRESSING-KITS.md), [LEGIBILITY.md](LEGIBILITY.md) section 13 and the [economy audit](../../../docs/systems-audit/economy/README.md).

## 1. What exists today (verified in code at `fc8507686`)

All paths are under `sketches/core-loop/` unless a path starts at the repo root.

**Heft.** `RunState.HEFT_CLASS_AT := [1.0, 1.5, 2.2, 3.2, 4.6]` ([run_state.gd:32](../src/core/run_state.gd)) gives classes I to V. `heft()` ([run_state.gd:380](../src/core/run_state.gd)) is `1.0 + mass / 450 + 0.2 per part + panel mass`; `raw_heft_class()` (388) and `heft_class()` (399) read the table. Heft "scales punch and never touches handling". The ball's outline and collision radius stay 1.0 at every class (DECISIONS.md "Fixed outline", 22 Oct 03:10), so a destructible can never be sized against the ball's drawn size; the only honest carrier of "you are heavy enough" is the class number.

**Breakables that already exist.** Each one is a one-off with its own break rule:

| Piece | Where | Rule today |
| --- | --- | --- |
| Cracked cache wall | [cracked_cache.gd](../src/world/cracked_cache.gd) `_watch_wall` (184), `crumble` (202) | Breaks the tick before contact at `BREAK_SPEED` 18, or 8 when sprinting, or on a slam within `SLAM_REACH` 7. Reach is `WALL_REACH 3.0 + toward / 30`. It parks the collider 400 m down (`_wall.position += DOWN * 400`) and hides it. Heft is not read. |
| Cracked wall contraption | [contraptions.gd](../src/world/contraptions.gd) `_build_wall` (1050), `_step_wall` (1102), `WALL_SPEED` 8 (34) | Sprint, or `break_at_cruise` at `0.85 x cruise` (`Activities.RAM_MIN_PER_CRUISE`). Same 400 m park. Heft is not read. Rows: `slot_bulkhead` ([park_dam.json:197](../src/world/park/park_dam.json)), `culvert_wall` ([park_flume.json:290](../src/world/park/park_flume.json)), `grade_wall` (292). |
| Valve | contraptions.gd `_step_valve` (1018) | Ram at cruise within `RAM_REACH` 2.8, or a slam within `SLAM_REACH` 4.5. |
| Tagged crates | [bowl_approach.gd](../src/world/bowl_approach.gd) `_physics_process` (274), `_burst` (330) | No collider. A ball at `SurveyPosts.MIN_SPEED` inside `TOUCH_M` bursts a crate: four newly spawned pieces (`340-351`) tween out, shrink to 0.05 scale and free themselves; `CRATE_SCRAP` 1, a cluster of three pays `CLUSTER_SCRAP` 4. Approach rows only, behind `--approach=on`. |
| Park dressing kicks | [prop_kicks.gd](../src/presentation/prop_kicks.gd) `mode_of` (56), `LIVE_CAP` 24 (22) | Presentation only: `fly`, `shove` or `bend` at `KICK_SPEED` 4. "Props carry no collision, so movement, schedules and run hashes cannot move" ([DRESSING-KITS.md](park/DRESSING-KITS.md)). |

Heft appears in none of these. A Class I ball and a Class V ball break the same walls at the same speed. That is the gap this page fills.

**The pre-contact precedent.** Two mechanisms already make a ball pass something with no speed loss:

1. The walls above relocate or hide their collider the tick before contact, using the approach speed and a reach that grows with speed.
2. The **bow sensor**: `_build_bow()` ([player_ball.gd:1258](../src/movement/player_ball.gd)) adds an `Area3D` of radius `RADIUS + BOW_REACH` (`BOW_REACH` 1.0, line 35) to the rigid ball on mask 3. `_try_crush()` (1297) asks `crush_check`, calls `exceptions.hold(body)` ([exception_hold.gd:31](../src/movement/exception_hold.gd)), strikes through `struck`, and releases after `CRUSH_PASS`. The comment at 1255 names it "the Katamari moment: fodder the ball now outweighs is rolled straight through ... the pass costs no speed, knock or hit-stop." Destructibles are the same promise for the world.

**Collision and cover facts.** Every park row body is on `WORLD_LAYER := 1` ([park_recipes.gd:67](../src/world/park/park_recipes.gd)); a lobber shell's cover ray reads `Projectile.COVER_MASK := 1` ([projectile.gd:32](../src/combat/projectile.gd)); [park_cover_tags_test.gd](../tests/park_cover_tags_test.gd) treats any layer-1 collider 2.0 m or taller as hard cover and requires the share of hard rows on the cover layer to stay at 1.00. The grapple's centre ray hits `Augments.WORLD_MASK` ([harpoon.gd:29](../src/movement/harpoon.gd)), so any layer-1 body is a grapple surface.

**Combat and economy entry points** (the only legal ones for this feature):
- `Combat.strike(enemy, kind, force, ...)` ([combat.gd:692](../src/combat/combat.gd)) and `DamageDoor.pass_hit(hit, stages)` ([damage_door.gd:64](../src/combat/damage_door.gd)); `Enemy.knock(direction, force)` ([enemy.gd:454](../src/combat/enemy.gd)).
- Slam: `PlayerBall._on_slammed` (1416) emits `events.slammed`, calls `_push_enemies` (1568) over `slam_radius()` (1393), and `slam_strength = clamp(speed / 30, 0.4, 1.6) * flatness` (1397).
- Blast sources: Redline `detonated(at, force)` with `BLAST_RADIUS 7.0` ([redline.gd:30](../src/combat/redline.gd)); Kest sticky `drop(at, damage, radius, ...)` ([sticky.gd:68](../src/combat/sticky.gd)); Q landing `landing_radius()` ([ultimate.gd:806](../src/combat/ultimate.gd)); actives `scrap_rocket` (`BLAST_RADIUS 3.0`, [scrap_rockets.gd:20](../src/combat/actives/scrap_rockets.gd)), `silo_battery` (`RADIUS 3.0`, [silo_battery.gd:23](../src/combat/actives/silo_battery.gd)) and `quake_knock` (`RADIUS 7.0 + 0.75 per bonus`, [quake_knock.gd:21](../src/combat/actives/quake_knock.gd)), all registered in [active_defs.gd](../src/combat/actives/active_defs.gd).
- Scrap: `ScrapField.drop(at, amount, rng)` ([scrap_field.gd:513](../src/build/scrap_field.gd)) takes the caller's RNG; `drop_cogs(at, amount)` (462) draws none ("Gears are placed without the rng, so the loot stream draws what it drew before"). `MAX_PIECES 400` bounds loose scrap (48). Device luck streams are seeded per `luck_seed(run_seed, run_id, stage, device_id)` ([interact.gd:260](../src/world/interact.gd)).
- Refused cue: [activities.gd](../src/world/activities.gd) `refused` rule (`{"worlds": [1], "floor": 0.4, "gap_s": 3.0}`, line 122, handler near 2369) plays "faster, not solid" under the bar, once per face per gap.
- Death look: [enemy_motion.gd](../src/presentation/enemy_motion.gd) pieces shrink to `SPECK := 0.01` (36) over their life (`clampf(... , SPECK, 1.0)`, 250) and never fade alpha.

### Why a new module, and not a hack of the existing ones

- `PropKicks` is presentation-only by contract, indexes MultiMesh batches, and its tests (`prop_kicks_test`, `park_props_test`) pin "no collision". Adding a body or a break there would end that guarantee for all ~600 dam props.
- `cracked_cache.gd` and `contraptions.gd` each carry a private copy of "approach speed, reach, relocate the collider 400 m, puff". A third copy for a tiered rule would be the third inconsistent one. Their rule stays as is: they are **secrets and route fixtures**, not heft payoffs, and their rows keep working untouched.
- AGENTS.md rule 7: the state (tier, intact or shattered, collider, debris, loot meter) belongs to one module. Callers get one small call.

**Decision:** one new deep module, `src/world/destructibles.gd`. It owns the registry, the tier rule, the collider switch, the debris pool and the stage loot meter. Callers (the ball, slam and blast sources, map build) see three calls: `Destructibles.build(map, ctx)` (once per stage), `Destructibles.on_ball(ball_pos, velocity, heft_class)` (once per physics tick, from the world tick), and `Destructibles.on_blast(at, radius, source, tier_bonus)` (from each blast source), plus one `piece_shattered(bounds: AABB)` signal for world-line release. Everything else is private.

## 2. Hard safety boundaries

Authority: BIBLE.md movement paragraph ("Growth should add physical presence while preserving ordinary route clearance ... A passage that fits the starter but traps a normally developed mech breaks the collection fantasy"), [Q-P22](../../../BACKLOG.md#q-p22) (an open question owned by Andrew whose closing condition requires terrain alteration to be "either selected with bounds or parked"; this spec refuses literal heightfield terrain alteration while bounding standalone destructible props), and the ten-point map standard (rulings ct to cv), points 5 (hard cover is real, dressing is soft) and 8c (no snags).

### 2.1 Allowed: the whole list

A destructible is a **standalone, non-load-bearing, authored prop** that nothing else reads for ground, a route or an anchor:

| Family | Examples | Tier |
| --- | --- | --- |
| Light clutter | crate stacks, barrels, drums, chain-link fence runs, tarp racks | 1 |
| Timber and scrap | plank barricades, scrap-sheet shanties, lean-to shacks | 2 |
| Masonry and steel | loose masonry walls, concrete jersey barriers, steel storage tanks and silos | 3 |
| Reinforced | industrial housings, pump cages, vault-front plates | 4 |
| Trophy | one reinforced shortcut slab per stage at most | 5 |

### 2.2 Forbidden: each one a test, not a note

| Never destructible | Why | Guard |
| --- | --- | --- |
| `ParkTerrain` heightfield and any landform collider | Q-P22 leaves terrain alteration open until Andrew closes it; this feature refuses literal heightfield terrain alteration. Ground, banks, canyon walls and `ground`/`bank`/`terrace` rows are the map. | `park_recipes.gd` bodies are never registered. A planted row on the heightfield fails `destructibles_test`. |
| Bridge decks, flume troughs, kickers, ramps, drop lips, half-pipes, rails, grind lines | They are ridden. Removing one mid-ride is a hard cut (ruling cv: one ride, no cut). Rows: `kicker`, `drop`, `half_pipe`, `rail`, `grind_line`, `elevated_line`, `flow_line`, `ledge`, `bowl`, `tunnel`. | Registration refuses any body parented under a row of those elements. |
| Grapple footings: `anchor_field` posts, `world_anchor`, `flume_bent_*`, `flume_ride_pier_*` pylons, hoodoos, saguaros | The grapple and the pylon mount depend on them. Breaking one under a hooked ball strands the ride. | Registration refuses the `anchor_field` element, any `world_anchor` node, and any prop asset whose manifest sets the `perch` field or `tall` tag (`DRESSING-KITS.md:41,82`, distinct from the `TALL` height band). |
| `GUARDED_SOCIETIES` heritage rows (`hohokam`, `ancestral_puebloan`, [park_schema.gd:109](../src/world/park/park_schema.gd)) | Guarded: they carry only `ref_` fragments and house no home. | Registration refuses any row whose `society` is guarded. |
| A mandatory progression choke point | All required routes are passable at Class I and II. | A route-reachability check (section 10, unit D) walks every required `routes` leg with every destructible treated as solid and Class I heft. A leg that needs a break fails. |
| `ParkProps` soft foliage | `PropKicks` `bend` stays a presentation effect; plants never get bodies. | Destructibles are separate nodes, never `ParkProps` instances. |
| Existing breakables | `cracked_cache`, `cracked_wall` contraptions, valves and bowl-approach crates keep their rules. | No row is registered twice; the module skips ids that a contraption owns. |
| Anything that closes a telegraph, event zone, spawn, beacon, gate or home | Same keepouts DRESSING-KITS applies to props (`telegraph`, `home_clear`, `line_clear`). | Reuse `ParkProps.validate` rules; planted failure per keepout. |

### 2.3 Cover and the grapple, stated

- **Intact:** a destructible 2.0 m or taller stands on `WORLD_LAYER = 1`, so it is hard cover (stops lobber shells on `Projectile.COVER_MASK`). Note that `tests/park_cover_tags_test.gd:75-77` scans only nodes carrying `park_recipe` metadata, so it will not see standalone `Destructibles` nodes automatically; Unit D adds a destructibles cover check (section 10.2) verifying every intact `>= 2.0 m` destructible sits on layer 1 and every shattered one is excluded. Pieces under 2.0 m also sit on layer 1 to stop an under-tier ball, without counting as hard cover.
- **Shattered:** the collider is **disabled**, not parked 400 m away. Parking a body leaves it counted by the cover test and by the snag sweep's piece list. The module sets `collision_layer = 0` and `CollisionShape3D.disabled = true` (deferred), hides the intact mesh, and frees both at the stage end. A shell that was blocked now flies through, which is the honest result: the cover is gone, and the mark that read "hard cover" is gone with it.
- **Grapple (aimed AND already latched):** while intact, a destructible is a valid world surface like any layer-1 body.
  - *Aimed piece shattered before press:* `_press_harpoon` attaches immediately on the press tick from `kit.aim` (`player_ball.gd:1022-1028`); if a targeted piece shatters before the press, the re-sampled aim ray misses cleanly instead of latching onto empty space.
  - *Already latched world line:* because destructibles are forbidden from `WORLD_ANCHOR_GROUP`, `_world_aim` (`augments.gd:472-477`) passes `null` as the anchor body, so `grapple_to(point, normal, null)` (`player_ball.gd:1028`, `augments.gd:380-381`) stores a fixed world point (`on_body = false`, `anchor_body = null`, `kit.anchor = point`). Nothing ties that world line to the collider afterwards, so a fused sticky, Redline detonation or explosive active shattering the piece remotely would leave the ball dangling from empty air. Therefore `Destructibles` emits `piece_shattered(bounds: AABB)` on every break, and Unit B wires that signal on `player_ball.gd`: if `kit.hooked and not kit.on_body` and `bounds.grow(0.25).has_point(kit.anchor)`, call `cut_line("shattered")` (`player_ball.gd:639`). Both the pre-press aim-shatter case and the remote-shatter-while-latched case carry planted tests in section 10.2.

## 3. Heft tiers and the +1 rule

### 3.1 Tier table

Tier maps straight onto the class number, so there is **one number to learn** and nothing new on the HUD.

| Tier | Needs heft class | Family | Typical height | Intact cover |
| --- | --- | --- | --- | --- |
| 1 | I (heft 1.0) | light clutter | 0.6 to 1.8 m | no |
| 2 | II (1.5) | timber and scrap | 1.8 to 3 m | yes at 2.0 m or more |
| 3 | III (2.2) | concrete and steel | 2.5 to 4 m | yes |
| 4 | IV (3.2) | reinforced housings | 3 to 5 m | yes |
| 5 | V (4.6) | trophy slab | 4 to 6 m | yes |

World 1's reachable heft is the open number. Before placement the band sweep reports the class histogram at each stage entry and at the Warden, so tier 4 and 5 only land where a real run holds that class. Tier 5 is optional and may be cut entirely if no band run reaches class V before the stage's end.

### 3.2 The break test

`effective_tier = heft_class() + bonus`. A piece of tier T breaks when `effective_tier >= T` **and** the delivery meets its speed or strength bar:

| Delivery | Bonus | Bar |
| --- | --- | --- |
| Contact (roll or ram) | 0 | Flat planar speed at least `0.85 x cruise` (`Activities.RAM_MIN_PER_CRUISE`, the same bar the cracked face uses), or `WALL_SPEED` 8 for tier 1 |
| Slam or harpoon smash landing (`player_ball._on_slammed`, `player_ball.gd:1406`) | +1 | `slam_strength >= 0.05` (the existing floor for a shockwave), inside the committed `slam_radius()` *(note: `src/combat/dunk.gd:3-9` is a single-target reel charge, not a ground slam)* |
| Redline detonation (`redline.detonated`) | +1 | Inside `BLAST_RADIUS 7.0` |
| Kest sticky or mine (`sticky.gd`, `kest_kit.gd`) | +1 | Inside the sticky's own committed `radius` |
| Q ultimate landing (`ultimate.gd` `landing_radius()`) | +1 | Inside whatever ring radius the ultimate caller resolved (`landing_radius()`; `ultimate.gd:906` passes `+3.0`, whereas `881`, `911` and `1124` pass the plain radius) |
| Explosive actives: `scrap_rocket`, `silo_battery`, `quake_knock` | +1 | Inside each active's committed blast radius (3.0, 3.0, 7.0 + 0.75 per bonus) |

So a Class I slam breaks tier 2; a Class II slam breaks tier 3; a Class IV slam breaks tier 5. Nothing breaks more than one tier above the class, so no early kit trivialises the table, and "you are one class short" is always answerable with one slam.

- **The +1 uses the committed geometry** (BIBLE.md: "Simulation resolves attack geometry once. Collision, previews, effects and damage use that result."). `on_blast(at, radius, source, bonus)` reads the radius the source already resolved; it never computes a second one. A destructible inside the ring breaks, one outside does not, and the same ring that damages enemies breaks the prop.
- **No stacking.** Two sources in one tick still give +1 total, and a bonus never applies to contact.
- **Heft stays one-way.** The class a build holds is not changed by breaking things (loot is small, section 7.3).

## 4. Two-state physics and zero snag

A destructible has exactly two states, and nothing in between (no partial collider, no health bar, no chip-and-hold):

| State | Collider | Look | Feedback to an under-tier hit |
| --- | --- | --- | --- |
| Intact | `StaticBody3D`, layer 1 (the ball bounces and loses speed exactly as against any wall) | One authored mesh | Crack and chip, refused cue, silhouette read (below) |
| Shattered | Disabled (section 2.3) | Intact mesh hidden, 4 to 6 debris shards live | Not applicable |

### 4.1 Under tier: it is a wall, and the wall says why

A ball that meets a piece below its tier meets a normal wall. Jolt resolves the bounce; the module does not intervene. Feedback is **at the hit**, cooldown-gated per piece:

1. **Chip and crack VFX:** two or three chips fly 1 to 1.5 m, using the same pooled shard meshes as the break. No new shader, no new material.
2. **Refused cue:** the roll's refused audio cue from `activities.gd` (`refused` pattern: a floor of `0.4 x cruise`, once per piece per 3.0 s), the cue the cracked face already teaches in World 1. Wood and metal variants map to the existing sfx bank rows; no new loop.
3. **Silhouette heft read (LEGIBILITY section 13 carrier order: position, shape, colour, icon, motion, sound, then a word):** the piece's own **shape** carries its tier. Tier 1 and 2 are chunky and seamed (planks, crates); tier 3 and up have thick cast edges, rivet rows and a cracked-seam band that matches the tier's visible seam count (one seam per tier above 1). No text, no meter, no icon, no eyebrow. This is the same trick the bow uses for enemies: the ball is judged by what it can do, not by a label.
4. **Colour law.** Pieces use the park palette's rust, charcoal, sandstone and concrete. Never HAZARD `#ff5a3c` or any red, orange or amber stripe; never ANCIENT `#9dff3c` or MINT `#8bf0d3` (mint is reserved for completed synergies in `FEEL-READABILITY.md`, and dressing rules at `DRESSING-KITS.md:46` keep scenery out of gameplay signal colours); BRASS `#d9b44a` only on Fleet gear; nothing emissive. A destructible must read as scenery, never as an enemy, pickup or route.
5. **Shape read over colour.** Dressing kits forbid crate and barrel shapes because they "read as caches or breakables". Destructibles invert that: they are the *only* props allowed that read; DRESSING-KITS' "avoid" list stays for non-breakable dressing. Any piece of this module's families that is not breakable must not use the break-look seams, so a seam always means "this breaks". That is the one name for one thing (rule 8).

### 4.2 At or above tier: shatter before the solver, so no loss

The break is decided **before** Jolt resolves the contact, so the ball never touches the collider:

1. No `Area3D` or bow-sensor hook is added to `player_ball.gd` (the ball's bow sensor at `player_ball.gd:1262-1263` watches layer 3 only and `_try_crush` at `1298` ignores non-`"enemy"` bodies, whereas destructibles are layer-1 static walls). Instead, `Destructibles.on_ball(ball_pos, velocity, heft_class)` runs each 60 Hz physics tick and sweeps the ball's forward segment `[prev_ball_pos, ball_pos + flat_vel * dt]` against intact pieces inside `WALL_REACH + flat / 30.0` (3.0 m plus `flat / 30.0`, the cracked wall's reach at `cracked_cache.gd:188`). Because one 60 Hz tick travels `flat / 60.0` m, `3.0 + flat / 30.0` stays at least one full tick ahead of solver contact at every attainable ball speed, including jumps and launches, with zero contact-sweep touchpoints on `player_ball.gd` (Unit B touches `player_ball.gd` only for `piece_shattered` line release). The broadphase is a `Vector3i` cell grid of 12 m (deliberately twice `PropKicks.CELL_M := 6.0` because intact destructibles are larger and sparser than litter), so per-tick cost is a handful of cells.
2. If the rule passes, the piece is shattered on that tick: collider disabled by `set_deferred`, intact mesh hidden, shards spawned, and `piece_shattered(bounds)` emitted. The ball's next solver step finds no body in front of it. Speed in equals speed out within 1 percent, no bounce, no snag.
3. A slam or blast shatters on the event: `events.slammed` and the sources' signals call `on_blast` the same tick; no contact is involved.

**No snag test.** The test is a planted pair: a tier-2 piece across a fixture floor, a Class II ball rolled at cruise into it, speed measured 5 ticks before and after, passes at `after >= 0.99 x before` and fails if the collider is left on through the contact tick. The control is the same piece with a Class I ball, which must lose speed (the wall is real). See section 10 for the existing sweep that guards the rest of the map.

### 4.3 What this does not change

- Handling. Heft "scales punch and never touches handling". Destructibles read heft; they never write it. Nothing about turn rate, roll, jump or grapple changes for the ball.
- Run state. A shattered piece writes only into its own module state. Run hashes from `run_tier_test` and the park ride tests stay equal; destructibles are seeded from the stage seed so two runs of one seed break the same pieces for the same bot.

## 5. Payoff 1: combat

A shatter is a small attack the player already paid for with the ball. It is not a free power fantasy and not a new damage source.

- **Debris:** at most **4 shards** for tiers 1 and 2 and **6** for tiers 3 to 5. Each shard is a lightweight, non-physics node (no `RigidBody3D`, no Jolt body). It follows a scripted arc with bounce and skid, matching `PropKicks` (`prop_kicks.gd:27-30, 175`: `FLY_BOUNCE 0.3`, `FLY_SKID 0.55`, `FLY_MAX_S 3.0`), then **shrinks to `SPECK`** over 0.7 to 1.2 s (`enemy_motion.gd:36, 250`). **No alpha fade.** The brief for this wave records that fading transparent materials stalled frames by 43 to 48 ms on first use because they needed a new shader pipeline; `enemy_motion.gd` already avoids that by scaling to `SPECK`. This page does not carry a fresh measurement of that stall; Unit C re-measures it (section 10.2, Test F) and uses opaque materials either way.
- **Pool:** one shared pool of 24 shard nodes per stage (the same bound as `PropKicks.LIVE_CAP`), and a hard stage ceiling of 32 including dust puffs. When the pool is full a new shatter reuses the oldest shard, which finishes at once. The pool is built over the sliced stage build, not at the break (see section 9).
- **Shrapnel check:** the shatter calls one outward directional check from the break point: every enemy inside `SHRAPNEL_M` (2.5 m, short and local) and inside a 90-degree cone around the ball's travel direction gets `enemy.knock(dir, force)` and one `Combat.strike(enemy, "debris", force, ...)`. `force = base x tier_scale x clamp(speed / cruise, 0.6, 1.4)`, with `tier_scale` 0.5, 0.7, 1.0, 1.3, 1.6. Damage is resolved **only** through `DamageDoor.pass_hit` (the damage door's stages), so crit, armour, elite affixes, `wrecking_ball`, `domino_wire` and `ten_pin` see it as a normal strike and nothing special is added to skip them. A strike comes out at most once per enemy per shatter and at most 3 enemies per shatter, so a crowd is not a free boom.
- **Synergy, not bypass:** `wrecking_ball`, `domino_wire` and `ten_pin` read `strike` events already; a debris strike participates with `kind = "debris"` and its own `source`, so a dev who wants to opt a synergy out does it by kind. Redline spends on `SPEND_KINDS` only; `debris` is **not** added to that list, so shards cannot set Redline off.
- **Sound and sight:** one sfx row per tier family (wood, scrap, masonry, steel). The shatter does not shake the camera past what a slam already does; dust sits low and short.

## 6. Payoff 2: optional shortcuts (World 1)

A shortcut is a destructible that turns a longer way into a shorter or faster one. It is never the **only** way. The test in section 10, unit D, enforces this by routing every required leg with all destructibles solid.

Candidate menu of sites, chosen from rows that exist in `park_dam.json` and `park_flume.json`. These five rows are a **selection pool, not all placed at once** (hard cap: at most **2 shortcut pieces per stage**). Because terrain edits are forbidden, Unit D must prove an existing open physical passage sits behind each selected shortcut site before placing it, and confirm against the ten-point standard; none edits a route.

| Site | Park | Row evidence | Tier | Payoff |
| --- | --- | --- | --- | --- |
| Bulkhead flank | Dam | `slot_bulkhead` already breaks at sprint ([park_dam.json:197](../src/world/park/park_dam.json)); a **second** tier-2 plank barricade on the corkscrew slot's far side opens a straight line past the slot's switchback | 2 | Cuts the corkscrew's turn for a Class II ball; Class I takes the switchback it takes today |
| Gate row lean-to | Dam | `gate_row_apron` bank (130; `[0, 540]`, 30 by 60) beside `gate_piers` (an `anchor_field`, so the shacks stand outside its footprint and its grapple approach; [park_dam.json:129](../src/world/park/park_dam.json)) | 2 and 3 | Two shacks beside, never on, the gate line: a flank lane to the Warden approach for a heavy ball |
| Training-wall fence | Dam | `training_wall_west` and `_east` ([park_dam.json:99](../src/world/park/park_dam.json)) are `elevated_line` rows, so they are **never** touched; a chain-link run (tier 1) at their foot only opens a ground-level shortcut between the two | 1 | Light clutter, so it also teaches the rule at class I |
| Wasteway wall line | Flume | `wasteway_wall_line` bank row ([park_flume.json:74](../src/world/park/park_flume.json)) is a bank, not a wall; a tier-3 masonry segment in a gap of the bank offers a side lane into the wasteway chute | 3 | Beside the existing `culvert_wall` (290) so a Class III ball has two ways; the culvert wall keeps its own rule |
| Canal country grade | Flume | `grade_wall` (292) already sits on `canal_country_grade` with a cache; a tier-4 housing cluster two grades away is the "you are stronger now" return trip | 4 | Optional, behind the cache's own gate; no heavy lane without a lighter way round |

Hard rules for shortcuts: destructibles obey the full `DRESSING-KITS.md:57` `line_clear` keepouts by height (6 m for LOW, 10 m for MEDIUM, 20 m for TALL) — a solid collider never gets a looser keepout than collision-free dressing, with the sole exception of tier-1 clutter (`<= 1.2 m`) intentionally placed across a side-line mouth where Class I breaks it at cruise; a shortcut's reward is **time and positioning**, never a part, relic or cache (those stay with the secrets family); a map ships at most **2 shortcut pieces per stage** in the first card, so the sitting tests the idea before it scales.

## 7. Payoff 3: capped light loot

### 7.1 Per-tier drop

Scrap uses `ScrapField.drop(at, amount, rng)` and cogs use `drop_cogs(at, amount)` (which uses no RNG).

| Tier | Scrap | Cogs | Notes |
| --- | --- | --- | --- |
| 1 | 0 or 1 (isolated roll, 50 percent) | 0 | Clutter is mostly for the sound and the shards |
| 2 | 2 | 1 | |
| 3 | 3 | 2 | |
| 4 | 4 | 2 | |
| 5 | 4 | 2 | The reward is the shortcut and the trophy look, not more scrap |

A piece pays once, at the break, from its own position. A slam that breaks four pieces pays four times and the stage cap below still holds.

### 7.2 The stage cap

A stage meter inside the module allows at most **35 scrap and 20 cogs** from all destructibles together. The meter is checked before each drop: if the remaining room is smaller than a piece's normal drop, the drop is **clamped to the remaining room** (so the meter never exceeds 35/20), and any break after the cap is full still shatters and still hits, dropping nothing. Placement budget keeps the cap a backstop and not the normal case (worst case, by design): 4 tier-1 (4 scrap), 6 tier-2 (12 scrap, 6 cogs), 4 tier-3 (12 scrap, 8 cogs), 1 tier-4 (4 scrap, 2 cogs) is 15 pieces for 32 scrap and 16 cogs (if a tier-5 trophy piece is kept, the 16th piece's 4-scrap drop clips by 1 against the 35-scrap cap).

### 7.3 Why these numbers are small

From the [economy audit](../../../docs/systems-audit/economy/README.md) (lines 41 and 64; 24 runs per player type, before arm):
- Measured World 1 run length is about **7.0 game minutes** for the rusher and min-maxer and **10.0 game minutes** for the completionist across two stages (dam and flume, `park_cover_tags_test.gd:34`), i.e. **~3.5 to 5.0 game minutes per stage**.
- Net held scrap is **223 / 208 / 231 per game minute** (rusher, completionist, min-maxer — counted as scrap held at end of run, a net figure rather than gross income) and cogs are **223 / 206 / 235 per game minute**. At ~3.5 minutes per stage (~780 net scrap and ~780 cogs per stage), the **35 scrap / 20 cogs** cap is **~4.5 percent of net stage scrap** (~9.4 s) and **~2.6 percent of stage cogs** (~5.4 s).
- One activity pays `PAY_SCRAP = 180` ([activities.gd:59](../src/world/activities.gd)), so the whole destructible cap is under one fifth of one activity.
- Mass is 1 per scrap piece and `HEFT_PER_MASS` is 1/450: 35 scrap is at most 0.078 heft per stage (~15.5 percent of the smallest class interval 1.0 to 1.5), so loot cannot lift a class by itself or feed a loop of "heavier, break more, get heavier".
- The Moss shelf and Warden difficulty bands (`HEFT_CLASS_AT`, the shelf prices in the audit) stay where they are. Unit D reruns the economy ledger arm and the band sweep (section 10.2, Test G) and placement is refused if either median moves by more than the audit's own noise.

### 7.4 Isolated RNG

Drops consume only a stream seeded by `luck_seed(run_seed, run_id, stage, "destructible:" + id)`. They never touch the part, panel or kill-loot streams, so `panels_drop_sim_test` and every kill-drop pin stay byte-equal. `drop_cogs` uses no RNG. The ScrapField `rng` argument is the isolated stream. A planted control asserts that breaking every piece in a stage leaves the next panel roll unchanged.

## 8. Research and rejected options (Research first)

What other games do, and what this page takes:

| Game | What it does | Taken | Not taken |
| --- | --- | --- | --- |
| Katamari Damacy | Size decides what you roll up; too big to pick up bounces you off | The size-threshold read: bigger or lighter changes what happens, and the world shows it. Matches the bow sensor already in this ball | The ball growing. Heft must not scale the ball (Fixed outline) |
| Burnout Paradise | Smash gates and shortcut barriers that break at speed with no speed penalty | Break before contact, zero loss, shortcuts that reward time | Crash cams and fail states; a miss here is a bounce, not a wreck |
| Risk of Rain 2 | Breakable barrels and chests reward in small amounts and the loop is the combat | Small capped payoffs from breakables | Chest economy and open-ended spending |
| Hades | Breakable urns and pillars that give a little and add to the fight (they hurt and block) | Breakables as combat furniture; debris that hits | Rooms locked until broken |
| The Binding of Isaac | A rock needs a bomb; a tinted rock needs a bigger one | The +1 bypass idea: a source with committed radius opens one more tier | Hidden rooms behind it; no secrets in this module |

Options considered and **rejected**:

| Option | Reason |
| --- | --- |
| Dynamic `RigidBody3D` debris piles | Physics bodies make snags and CPU spikes; the ball can climb or catch them. Debris here is scripted and non-colliding |
| Literal terrain carving | Q-P22 leaves terrain alteration open until Andrew closes it; this spec refuses terrain edits because ParkTerrain is baked and the map standard counts on it |
| Uncapped scrap for breaking things | Breaks the economy audit's floor and ceiling, the `HEFT_CLASS_AT` pacing, and the Warden bands |
| Alpha-fade debris | First-use shader pipeline stall (section 5); shrink to `SPECK` is the house style |
| Breaking grapple footings, bridges, ramps | Strands rides and breaks the "one ride, no hard cut" ruling |
| A heft meter or text on a prop | Fails LEGIBILITY section 13 (S4, S6): shape and sound carry it |
| Painting destructibles in `LEGIBILITY.md` live/slate rims | `LEGIBILITY.md:22,24` assigns live to a breakable rim and slate to "not yet", but carrier order (line 348) puts shape before colour, and painting scattered scenery props in interactive-door signal colours adds visual noise vs real route fixtures |
| Making it also a "health bar" wall that takes N hits | Adds a state, a number and a snag-prone half-open collider. Two states only |
| Changing the existing cracked walls to the tier rule | They are secrets. Changing them re-opens their pins and tests for no player win |

## 9. Performance, draw budget and determinism

- **Draws.** Dressing adds at most **120 draws** at any sampled ride-path pose and the park stays at or under **1,400 draws** on `p1` and 1.3 times base p99 on `s3` (DRESSING-KITS "Frame cost"). Destructibles are counted in that dressing allowance: one MultiMesh per (piece kind, LOD) and one shared shard mesh per family, no per-piece `MeshInstance3D` for LOD2. Intact pieces use the dress_prop and dress_hero classes in [asset_budgets.json](../assets/asset_budgets.json) (3,000 and 20,000 triangles at LOD0, 1 draw per LOD). The shard pool is 24 nodes on one mesh per family.
- **Frame.** Target is 33 ms on the 4080 reference and a clean 60 Hz on the Mac Studio (16.7 ms); the break must add at most 0.3 ms to a worst-case tick (the tick scan is cell-gridded) and at most one frame over the 4080 budget on the break frame. Cloud frame times never count (DRESSING-KITS).
- **Build slicing.** The module builds in slices of `ParkProps.BUILD_SLICE_USEC := 3000` ([park_props.gd:110](../src/presentation/park_props.gd)), the same budget and the same slice loop, so entering a stage hitches on nothing. Shards, the intact meshes and the shard materials are built and warmed during the slice, not at the first break.
- **No shader-compile stutter.** All materials are opaque vertex-colour `StandardMaterial3D` already in the park kit's cache. No transparent, no new shader variant, no new light. Warm every material once during the sliced build.
- **Determinism.** Under `--bot-no-visuals=1` the module still runs: it keeps tier, intact and shattered state, collider state and the loot meter, and skips shards and sfx. Break order, loot and combat strikes are functions of (seed, stage, ball path, class) alone, never wall-clock time or frame count, so a bot batch is reproducible and the pins from `run_tier_test` do not move.
- **Teardown.** Colliders, shards and the pool are freed with the stage (`ParkProps.release_shared` precedent in `activities.gd`). A shard or a disabled body must not outlive its stage: a leak is a planted test.

## 10. Build units and verification

### 10.1 Units (disjoint, small and medium)

| Unit | Size | Owns | Does not touch |
| --- | --- | --- | --- |
| A. Module and rule | M | New `src/world/destructibles.gd`, its `Destructibles` break rule, collider switch, `piece_shattered(bounds: AABB)` signal, debris pool, loot meter, `Destructibles.build / on_ball / on_blast`; new `tests/destructibles_test.gd` | The ball, the blast sources, any map |
| B. Ball, grapple and source hooks | S | One call from the world tick to `on_ball`; one `on_blast` call per source (`_on_slammed`, `redline.detonated`, `sticky`, `ultimate`, three actives); world-line release wire in `player_ball.gd` (`piece_shattered(bounds)` calls `cut_line("shattered")` when `kit.hooked and not kit.on_body and bounds.grow(0.25).has_point(kit.anchor)`) | The break rule, the maps |
| C. Models and look | M | Piece GLBs per tier family, shard mesh, sfx rows, seam art, `registry.d` fragment, asset budget row, and Test F (fixture break-frame opaque vs alpha-fade hardware check) | Collision, the rule |
| E. Combat integration | S | The `debris` strike kind, `DamageDoor` stage reads, `wrecking_ball`, `domino_wire`, `ten_pin` opt-in check | Redline `SPEND_KINDS` |
| D. World 1 placement | M | A `destructible_rows` list in `park_dam.json` and `park_flume.json` (schema key, max 2 shortcut pieces with verified physical open gaps and no terrain edits, placement budget per stage), destructibles cover check beside `park_cover_tags_test.gd`, route reachability check, loot-budget check, park-pose draw re-check (Test F2), and Test G (economy ledger arm + band sweep + heft-class histogram) | The module internals |

Order: **A**, then **B, C, and E in parallel**, then **D** (landing E before D ensures the `debris` strike kind is registered before any live World 1 piece can fire it). Each is one pull request, its own focused tests plus `npm run sketch:fast -- --base <stage>` and one independent review (AGENTS.md rule 4). The Gate admits one at a time.

### 10.2 Tests (every one has a planted failing control)

| ID & Test | Owner | Proves | Planted control |
| --- | --- | --- | --- |
| T1. Under-tier (`destructibles_test`) | A | A tier-3 piece with a Class II ball at cruise stays solid, the ball bounces and loses speed, the chip VFX and the refused cue fire once per 3.0 s | A hand-set Class III ball must break it, so the test fails if the rule is a no-op |
| T2. At-tier zero snag | A | A tier-2 piece, Class II at cruise, speed 5 ticks after >= 0.99 x speed before, no bounce, no contact event | The same run with the collider forced on through the contact tick must fail |
| T3. +1 bypass | B | A Class I slam breaks tier 2 and not tier 3; the same for Redline, a Kest sticky, a Q landing, `scrap_rocket`, `silo_battery`, `quake_knock`, each inside and outside its committed radius | A radius computed separately from the source's own ring must disagree and fail |
| T4. Debris & `DamageDoor` | A / E | At most 6 shards live per break and 32 per stage; shards finish at `SPECK`; materials are opaque; `debris` strike kind is registered; a `DamageDoor` stage sees the debris strike; `enemy.knock` fires once per enemy per shatter | A shard material with alpha below 1.0 fails; an unregistered strike kind fails |
| T5. Loot cap | A | Breaking every piece leaves at most 35 scrap and 20 cogs (clamping a partial last drop); a break after the cap pays nothing but still hits | A cap of 0 must pay nothing; a cap of 100 must fail |
| T6. RNG isolation | A | Breaking all pieces leaves the next panel roll and the next kill-drop roll unchanged (compare against `panels_drop_sim_test`) | A drop drawn from the shared stream must change the roll and fail |
| T7. Exclusions & route walk | A / D | The module refuses terrain, anchors, `perch` field / `tall` tag prop manifests, guarded societies, ridden elements and existing contraption ids; a route walk at Class I with all pieces solid still reaches every required leg; each chosen shortcut has a verified open passage behind it | One planted row on each forbidden family must be refused; a planted required-route piece must fail the walk |
| T8. Cover | D | Destructibles cover check beside [park_cover_tags_test.gd](../tests/park_cover_tags_test.gd) (`75-77` reads `park_recipe` only): every intact `>= 2.0 m` destructible stands on layer 1, every shattered one is excluded, and `park_cover_tags_test` stays at 1.00 | Put one intact `>= 2.0 m` destructible off layer 1 and the check fails |
| T9. Grapple (aimed & latched) | B | (1) An aim record (`kit.aim`) resolved against a piece that shatters before `_press_harpoon` misses cleanly on press; (2) latching onto an intact piece via `_press_harpoon` (`on_body = false`, `kit.anchor` inside piece bounds) and shattering it remotely via `on_blast` calls `cut_line("shattered")` on the same tick so `kit.hooked` becomes false and the ball never hangs in midair | Leaving `kit.hooked` true (the world line still standing) after the remote shatter must fail |
| T10. Invisible walls | D | [invisible_walls_test.gd](../tests/invisible_walls_test.gd): no collider remains after a shatter, no collider without a mesh while intact | A body left behind with no mesh fails |
| T11. Snag sweep | D | Run `tools/qa/snag_sweep.gd` for `park_dam` and `park_flume` with the pieces intact and with the pieces shattered; no new snag **above the intact pieces** other than the pieces themselves, and none after | [snag_sweep_test.gd](../tests/snag_sweep_test.gd) is the planted control; run it first (the sweep's own doc says a zero means nothing if it is red) |
| T12. Teardown and determinism | A | No body, shard or exception survives a stage change; two runs of one seed break the same pieces | A leaked shard must fail |
| **Test F. Alpha-fade & break-frame hardware check** | C / D | Unit C measures fixture tick cost (`<= 0.3 ms`), break-frame time on Mac Studio (60 Hz) and 4080 (`<= 33 ms`), and opaque shrink-to-`SPECK` vs alpha-fade shader stall; Unit D re-checks placed park-pose draw counts (`<= +120` dressing, `<= 1,400` on `p1`) and captures chase-camera before/after stills | A planted alpha-faded shard variant or a break frame / draw count over budget fails; `NEEDS: gpu` on the board (rule 12) |
| **Test G. Economy arm, band sweep & heft histogram** | D | Rerun the [economy audit](../../../docs/systems-audit/economy/README.md) arm and World 1 band sweep before/after placement: (1) prints the Class I–V heft histogram at each stage entry and Warden (deciding whether Tier 5 stays or is cut), (2) refuses placement if scrap/cogs or Warden difficulty medians shift beyond audit noise | A planted uncapped-scrap arm must shift the economy median and fail |

### 10.3 Existing tools the sweep cites

- Snag sweep tool: [tools/qa/snag_sweep.gd](../tools/qa/snag_sweep.gd), probe [tools/qa/snag_probe.gd](../tools/qa/snag_probe.gd), notes [tools/qa/snag_sweep.md](../tools/qa/snag_sweep.md), planted control [tests/snag_sweep_test.gd](../tests/snag_sweep_test.gd).
- Collision: [tools/qa/collision_sweep.gd](../tools/qa/collision_sweep.gd), [tools/qa/invisible_walls.gd](../tools/qa/invisible_walls.gd).
- Drops: [tests/panels_drop_sim_test.gd](../tests/panels_drop_sim_test.gd).
- Dressing: [tests/park_props_test.gd](../tests/park_props_test.gd), [tests/prop_kicks_test.gd](../tests/prop_kicks_test.gd).
- Run pins: [tests/run_tier_test.gd](../tests/run_tier_test.gd).

### 10.4 Open items for Andrew and the Gate

1. **Tier 5.** At 223 scrap/min and `1/450` heft per mass (before parts), Class II arrives near 1.0 min, Class III near 2.4 min, Class IV near 4.4 min, and Class V near 7.3 min — likely out of reach inside a 7-minute World 1 run. Keep Tier 5 only if Test G's heft histogram shows Class V reachable inside a stage; otherwise drop it and ship four tiers.
2. **Cogs from props.** `drop_cogs` exists. If Andrew does not want a second currency drop from scenery, scrap alone is the fallback and the cog column becomes zero; the cap logic is unchanged.
3. **Seam art.** The seam-per-tier read (section 4.1) needs one blind still read before the family models are finished: show a tier-2 and a tier-4 piece and ask which one a Class II ball can break.
4. **`debris` kind.** Whether `ten_pin` and `domino_wire` count a debris strike is a one-line call for the combat card; the default here is yes, opt-out by kind.
