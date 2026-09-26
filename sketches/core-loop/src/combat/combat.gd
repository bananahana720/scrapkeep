extends Node

const Chaser := preload("res://src/combat/chaser.gd")
const Lobber := preload("res://src/combat/lobber.gd")
const Miniboss := preload("res://src/combat/miniboss.gd")
const Projectile := preload("res://src/combat/projectile.gd")
const Hitscan := preload("res://src/combat/hitscan.gd")
const Pattern := preload("res://src/combat/pattern.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const Bolts := preload("res://src/combat/bolts.gd")
const Effects := preload("res://src/combat/effects.gd")
const Palette := preload("res://src/core/palette.gd")

# Writer A's module: the two class kits, the pattern system parts transform, enemies
# with committed telegraphs, the miniboss, damage and drops, and the shoulder view
# while mounted. It is ctx.spawner. README.md in this folder is the contract other
# modules read (spawner kinds, pattern transformer ids, the part registration call).
#
# The loop each physics tick, only while the flow is in play:
# 1. The shoulder view follows the mount: shoulder_target is 1 exactly while mounted.
# 2. Held fire throws one volley per weapon interval. The volley is aimed with the
#    shared aim query (hitscan.gd), laid out by the weapon's Pattern, and published
#    once as shot_fired(weapon, muzzle, the point the centre bolt is sent to).
# 3. The special fires on its key: overdrive for the runner, the pylon discharge for
#    the engineer. Planting a pylon as the engineer fires the discharge for free,
#    powered by the banked speed (the turret's opening burst).
# 4. Bolts step; a bolt that reaches an enemy is resolved once through strike().

const MUZZLE := 1.25
const AIM_SLACK := 14.0
const KINDS := ["chaser", "lobber", "miniboss"]

# Ball contacts: base damage plus a share of the contact's force.
const STRIKE_DAMAGE := {
	"stomp": [30.0, 1.1],
	"ram": [14.0, 1.3],
	"slam": [0.0, 1.2],
}

var ctx
var bolts
var effects
var volleys := 0
# The last committed volley and discharge, for tests and anything that wants to read them.
var last_shot := {}
var last_burst := {}

var _patterns := {}
var _part_map := {}
var _cooldown := 0.0
var _special_cooldown := 0.0
var _overdrive := 0.0


func setup(ctx_ref) -> void:
	ctx = ctx_ref
	name = "Combat"
	ctx.spawner = self
	effects = Effects.new()
	ctx.root.add_child(effects)
	effects.setup()
	bolts = Bolts.new()
	ctx.root.add_child(bolts)
	bolts.setup()
	bolts.on_hit = _on_bolt_hit
	bolts.on_stop = func(at: Vector3, color: Color): effects.spark(at, color)
	ctx.events.stage_entered.connect(_on_stage_entered)
	ctx.events.run_started.connect(func(_class_id: String): _rebuild_patterns())
	ctx.events.part_gained.connect(func(_part: String, _source: String): _rebuild_patterns())
	ctx.events.mounted.connect(_on_mounted)
	_rebuild_patterns()


# --- Spawner API (CONTRACTS.md) -----------------------------------------------------

# kind is "chaser", "lobber" or "miniboss". An unknown kind spawns a chaser, with a
# warning, so a typo in an event table never leaves a stage empty.
func spawn_enemy(kind: String, at: Vector3) -> Node3D:
	var enemy: Node3D
	match kind:
		"lobber":
			enemy = Lobber.new()
		"miniboss":
			enemy = Miniboss.new()
		"chaser":
			enemy = Chaser.new()
		_:
			push_warning("spawn_enemy: unknown kind '%s', spawning a chaser" % kind)
			kind = "chaser"
			enemy = Chaser.new()
	ctx.root.add_child(enemy)
	enemy.global_position = at
	enemy.setup(ctx.player, ctx.terrain, ctx.root, Callable(ctx.flow, "in_play"), _threat())
	enemy.hit_player.connect(_on_player_hit.bind(kind))
	enemy.died.connect(func(where: Vector3, scrap: int): ctx.run.record_kill(kind, where, scrap))
	if enemy.has_signal("fired"):
		enemy.fired.connect(_on_lobber_fired)
	ctx.events.enemy_spawned.emit(enemy, kind)
	return enemy


# A hit the spine or a weapon made, resolved into damage exactly once. The bus fact
# goes out before the damage so a kill never publishes a freed node.
func strike(enemy: Node3D, kind: String, force: float) -> void:
	if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
		return
	if enemy.has_method("is_dead") and enemy.is_dead():
		return
	ctx.events.enemy_struck.emit(enemy, kind, force)
	var amount := force
	if STRIKE_DAMAGE.has(kind):
		var row: Array = STRIKE_DAMAGE[kind]
		amount = row[0] + force * row[1]
	enemy.take_damage(amount)


# --- Pattern API for parts (README.md) ----------------------------------------------

# A part applies these transformer ids once per stack in run.parts. Build calls this
# from its setup (combat is set up first). A part whose id is itself a transformer id
# needs no registration.
func register_part(part_id: String, transformer_ids: Array) -> void:
	_part_map[part_id] = transformer_ids.duplicate()
	_rebuild_patterns()


func transformer_ids() -> PackedStringArray:
	return PackedStringArray(Pattern.TRANSFORMERS.keys())


func transformer_info(id: String) -> Dictionary:
	var row: Dictionary = Pattern.TRANSFORMERS.get(id, {})
	return {"label": row.get("label", id), "text": row.get("text", "")}


# The transformer ids the current parts apply, in part order.
func active_transformers() -> Array:
	var ids := []
	if ctx == null or ctx.run == null:
		return ids
	for part in ctx.run.parts:
		if _part_map.has(part):
			ids.append_array(_part_map[part])
		elif Pattern.has_transformer(part):
			ids.append(part)
	return ids


# A copy of a weapon's current pattern, after every part.
func pattern(weapon_id: String) -> Resource:
	return (_patterns[weapon_id] as Resource).copy()


func live_projectiles() -> int:
	return bolts.live()


func active_weapon() -> String:
	var def = ctx.run.class_def
	if def == null:
		return ""
	if def.weapon_id == Weapons.ARC_CASTER and ctx.player.kit.mounted:
		return Weapons.PYLON_TURRET
	return def.weapon_id


# The discharge a given speed would fire right now, with the current parts.
func discharge_preview(speed: float) -> Dictionary:
	var p: Resource = _patterns[Weapons.PYLON_TURRET]
	return Weapons.burst(speed, p.burst_scale, p.damage / Weapons.BASE[Weapons.PYLON_TURRET]["damage"])


# --- The tick -----------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if ctx == null:
		return
	var playing: bool = ctx.flow.in_play()
	ctx.camera.shoulder_target = 1.0 if playing and ctx.player.kit.mounted else 0.0
	if not playing or ctx.run.class_def == null:
		return
	_cooldown -= delta
	_special_cooldown = maxf(0.0, _special_cooldown - delta)
	_overdrive = maxf(0.0, _overdrive - delta)
	var intent = ctx.player.intent
	var weapon := active_weapon()
	if intent.fire_held and _cooldown <= 0.0 and _patterns.has(weapon):
		_fire(weapon)
		_cooldown += 1.0 / _rate(weapon)
	if not intent.fire_held:
		_cooldown = maxf(_cooldown, 0.0)
	if intent.special_pressed and _special_cooldown <= 0.0:
		_special()
	bolts.step(delta, ctx.root.get_world_3d().direct_space_state, get_tree().get_nodes_in_group("enemy"))


func _rate(weapon: String) -> float:
	var rate: float = _patterns[weapon].rate
	if _overdrive > 0.0:
		rate *= Weapons.OVERDRIVE_RATE
	return rate


func _fire(weapon: String) -> void:
	var p: Resource = _patterns[weapon]
	var space: PhysicsDirectSpaceState3D = ctx.root.get_world_3d().direct_space_state
	var ball: Vector3 = ctx.player.ball_position()
	var aim := Hitscan.aim(space, ctx.aim_origin(), ctx.aim_forward(), ball, p.range_m + AIM_SLACK)
	var point: Vector3 = aim["point"]
	var forward := point - ball
	if forward.length() < MUZZLE * 1.5:
		forward = ctx.aim_forward()
	forward = forward.normalized()
	var muzzle := ball + forward * MUZZLE
	var color := Weapons.color(weapon)
	var kind := Weapons.strike_kind(weapon)
	var layout: Array = p.layout(forward, volleys)
	for entry in layout:
		bolts.fire({
			"origin": muzzle, "dir": entry["dir"], "speed": p.speed, "max_dist": p.range_m,
			"damage": p.damage, "kind": kind, "weapon_id": weapon, "radius": p.bolt_radius,
			"knock": p.knock, "chain_jumps": p.chain_jumps, "chain_range": p.chain_range,
			"chain_falloff": p.chain_falloff, "color": color,
			"wave_amp": 0.0 if entry["centre"] else p.wave_amp, "wave_hz": p.wave_hz, "phase": entry["phase"],
		})
	volleys += 1
	last_shot = {"weapon_id": weapon, "from": muzzle, "to": aim["to"], "point": point,
		"blocked": aim["blocked"], "bolts": layout.size(), "volley": volleys}
	ctx.events.shot_fired.emit(weapon, muzzle, aim["to"])


func _on_bolt_hit(bolt: Dictionary, enemy: Node3D, point: Vector3) -> void:
	effects.spark(point, bolt["color"])
	var from: Vector3 = enemy.global_position
	_hit(enemy, bolt["kind"], bolt["damage"], bolt["dir"], bolt["knock"])
	if bolt["chain_jumps"] > 0:
		_chain(enemy, from, bolt)


# One resolved weapon hit: the shove, the flash, then strike() for damage and the fact.
func _hit(enemy: Node3D, kind: String, damage: float, direction: Vector3, knock: float, lift := 0.25) -> void:
	var push := Vector3(direction.x, 0.0, direction.z)
	push = push.normalized() if push.length() > 0.01 else Vector3.FORWARD
	enemy.knock(push + Vector3.UP * lift, knock)
	enemy.flash()
	strike(enemy, kind, damage)


# The arc jumps from the struck enemy to the nearest one it has not touched, losing
# chain_falloff of its damage per jump.
func _chain(first: Node3D, from: Vector3, bolt: Dictionary) -> void:
	var visited := [first]
	var damage: float = bolt["damage"] * bolt["chain_falloff"]
	var at := from
	for _jump in int(bolt["chain_jumps"]):
		var next := _nearest(at, bolt["chain_range"], visited)
		if next == null:
			return
		visited.append(next)
		var to: Vector3 = next.global_position
		effects.arc(at, to, bolt["color"])
		_hit(next, bolt["kind"], damage, to - at, bolt["knock"] * 0.5)
		damage *= bolt["chain_falloff"]
		at = to


func _nearest(at: Vector3, reach: float, exclude: Array) -> Node3D:
	var best: Node3D = null
	var best_distance := reach
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy in exclude or enemy.is_dead():
			continue
		var distance: float = enemy.global_position.distance_to(at)
		if distance <= best_distance:
			best_distance = distance
			best = enemy
	return best


func _nearest_list(at: Vector3, reach: float, limit: int) -> Array:
	var found := []
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.is_dead():
			continue
		var distance: float = enemy.global_position.distance_to(at)
		if distance <= reach:
			found.append([distance, enemy])
	found.sort_custom(func(a, b): return a[0] < b[0])
	var out := []
	for i in mini(limit, found.size()):
		out.append(found[i][1])
	return out


# --- Specials -----------------------------------------------------------------------

func _special() -> void:
	var def = ctx.run.class_def
	var at: Vector3 = ctx.player.ball_position()
	if def.weapon_id == Weapons.ARC_CASTER:
		var kit = ctx.player.kit
		var speed: float = kit.mount_banked if kit.mounted else ctx.player.state.velocity.length()
		_discharge(at, speed, "turret" if kit.mounted else "arc")
		_special_cooldown = Weapons.DISCHARGE_COOLDOWN
	else:
		_overdrive_blast(at)
		_special_cooldown = Weapons.OVERDRIVE_COOLDOWN
	ctx.events.special_used.emit(def.special_id, at)


# The pylon's opening burst: planting as the engineer discharges the banked speed.
func _on_mounted(at: Vector3, banked_speed: float) -> void:
	if ctx.run.class_def == null or not ctx.flow.in_play():
		return
	if ctx.run.class_def.weapon_id != Weapons.ARC_CASTER:
		return
	_discharge(at, banked_speed, "turret")
	ctx.events.special_used.emit(ctx.run.class_def.special_id, at)


func _discharge(at: Vector3, speed: float, kind: String) -> void:
	var burst := discharge_preview(speed)
	var targets := _nearest_list(at, burst["radius"], burst["targets"])
	var color := Weapons.color(Weapons.PYLON_TURRET)
	for enemy in targets:
		var to: Vector3 = enemy.global_position
		effects.arc(at, to, color)
		_hit(enemy, kind, burst["damage"], to - at, Weapons.BURST_KNOCK, 0.4)
	effects.ring(at, burst["radius"], color)
	last_burst = burst.duplicate()
	last_burst["at"] = at
	last_burst["hit"] = targets.size()
	last_burst["kind"] = kind


func _overdrive_blast(at: Vector3) -> void:
	var p: Resource = _patterns[Weapons.RAPID_LASER]
	var damage: float = Weapons.OVERDRIVE_DAMAGE * p.damage / Weapons.BASE[Weapons.RAPID_LASER]["damage"]
	var hit := 0
	for enemy in _nearest_list(at, Weapons.OVERDRIVE_RADIUS, 64):
		_hit(enemy, "runner", damage, enemy.global_position - at, Weapons.OVERDRIVE_KNOCK, 0.5)
		hit += 1
	_overdrive = Weapons.OVERDRIVE_SECONDS * p.special_scale
	effects.ring(at, Weapons.OVERDRIVE_RADIUS, Weapons.color(Weapons.RAPID_LASER))
	last_burst = {"at": at, "radius": Weapons.OVERDRIVE_RADIUS, "damage": damage, "hit": hit, "kind": "runner",
		"overdrive": _overdrive}


# --- Enemy attacks ------------------------------------------------------------------

# An enemy's committed attack reached the ball. The run takes the damage; the shove is
# the hit's weight (a hit taken is the player's performance, principle 1).
func _on_player_hit(amount: float, shove: Vector3, source: String) -> void:
	if not ctx.flow.in_play():
		return
	ctx.run.damage(amount, source)
	if shove != Vector3.ZERO and not ctx.calm:
		ctx.player.add_external_accel(shove * Engine.physics_ticks_per_second)


func _on_lobber_fired(origin: Vector3, landing: Vector3, flight: float) -> void:
	var shell := Projectile.new()
	ctx.root.add_child(shell)
	shell.setup(ctx.player, ctx.terrain, ctx.root, Callable(ctx.flow, "in_play"), origin, landing, flight)
	shell.hit_player.connect(_on_player_hit.bind("lobber"))
	shell.exploded.connect(func(at: Vector3, blast: float, _hit: bool): effects.ring(at, blast, Palette.HAZARD))


func _threat() -> float:
	return ctx.flow.stage_def()["threat"]


# --- Stage reset --------------------------------------------------------------------

# A stage entry or retry starts the fight clean, and recomputes every pattern from the
# restored part list, so a retry restores the build exactly.
func _on_stage_entered(_stage: int, _retry: bool) -> void:
	for group in ["enemy", "enemy_shot", "telegraph"]:
		for node in get_tree().get_nodes_in_group(group):
			node.queue_free()
	bolts.clear()
	effects.clear()
	ctx.camera.shoulder_target = 0.0
	_cooldown = 0.0
	_special_cooldown = 0.0
	_overdrive = 0.0
	volleys = 0
	last_shot = {}
	last_burst = {}
	_rebuild_patterns()


func _rebuild_patterns() -> void:
	var ids := active_transformers()
	for weapon in Weapons.ALL:
		_patterns[weapon] = Weapons.base(weapon).transformed(ids)
