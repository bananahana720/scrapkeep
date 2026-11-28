extends "res://src/combat/actives/active_base.gd"

const ActiveFx := preload("res://src/combat/actives/active_fx.gd")
const Palette := preload("res://src/core/palette.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")

const BASE_DAMAGE := 30.0
const RADIUS := 7.0
const BONUS_RADIUS := 0.75
const BONUS_DAMAGE := 0.15
const REACH_UP := 2.5
const KNOCK := 12.0
const AFTERSHOCK_GROW := 3.0
const AFTERSHOCK_WARN := 0.3
const AFTERSHOCK_SCALE := 0.6
const CHAIN_FALLOFF := 0.7
const LINGER := 0.2
const CRACKS := 7
const CRACK_EVERY := 0.06
const COLOR := Palette.AMBER
const KIND := "quake"
const SOURCE := "special"
const ELEMENT := "kinetic"
const IMPACT := "slam"

var pending: Array = []
var spent: Array = []
var knocks := 0
var _crack_clock := 0.0


func clear() -> void:
	for entry in pending:
		_free(entry["ring"])
	for entry in spent:
		_free(entry[0])
	pending.clear()
	spent.clear()


func cancel() -> void:
	_drop_rack_ring()


func _drop_rack_ring() -> void:
	var kept: Array = []
	for entry in pending:
		if entry["rack"]:
			_free(entry["ring"])
		else:
			kept.append(entry)
	pending = kept


func radius_for(bonus: int) -> float:
	return RADIUS + BONUS_RADIUS * bonus


func damage(bonus := 0) -> float:
	return (BASE_DAMAGE + punch_bonus()) * (1.0 + BONUS_DAMAGE * bonus) * weapon_damage_mult()


func begin(rack, row: Dictionary) -> void:
	_drop_rack_ring()
	var bonus := int(rack.bonus)
	var warn := float(row["windup"])
	pending.append({"ring": _commit(ctx.player.ball_position(), radius_for(bonus)), "left": warn, "warn": warn,
		"damage": damage(bonus), "rack": true})
	_crack_clock = 0.0


func fire(rack, row: Dictionary, bonus: int) -> int:
	var heads := pending.filter(func(entry): return entry["rack"] and is_instance_valid(entry["ring"]))
	if heads.is_empty():
		if float(row["windup"]) > 0.0:
			return 0
		begin(rack, row)
		heads = pending.filter(func(entry): return entry["rack"])
	var first: Dictionary = heads[0]
	pending.erase(first)
	var ring: Node3D = first["ring"]
	var rings := 1
	var dmg := maxf(float(first["damage"]), damage(bonus))
	var hit := dmg
	var radius: float = ring.radius
	for level in pattern_level("cross_split"):
		radius += AFTERSHOCK_GROW
		dmg *= AFTERSHOCK_SCALE
		var warn := AFTERSHOCK_WARN * (level + 1)
		pending.append({"ring": _commit(ring.center, radius), "left": warn, "warn": warn, "damage": dmg, "rack": false})
		rings += 1
	_strike(ring, hit)
	return rings


func step(delta: float) -> void:
	var lingering: Array = []
	for entry in spent:
		entry[1] -= delta
		if entry[1] > 0.0:
			lingering.append(entry)
		else:
			_free(entry[0])
	spent = lingering
	if pending.is_empty():
		return
	_crack_clock -= delta
	var draw := _crack_clock <= 0.0
	if draw:
		_crack_clock = CRACK_EVERY
	var waiting: Array = []
	for entry in pending:
		var ring: Node3D = entry["ring"]
		if not is_instance_valid(ring):
			continue
		entry["left"] = float(entry["left"]) - delta
		var progress := 1.0 - maxf(0.0, float(entry["left"])) / maxf(float(entry["warn"]), 0.001)
		ring.set_progress(progress)
		if draw:
			_cracks(ring, progress)
		if float(entry["left"]) <= 0.0 and not entry["rack"]:
			_strike(ring, float(entry["damage"]))
		else:
			waiting.append(entry)
	pending = waiting


func _commit(at: Vector3, radius: float) -> Node3D:
	var ring: Node3D = Telegraph.ring(ctx.root, combat.ground, Threat.Type.INSTANT, at, radius, REACH_UP, COLOR)
	ring.set_progress(0.0)
	return ring


func _strike(ring: Node3D, dmg: float) -> void:
	knocks += 1
	ring.set_progress(1.0)
	combat.effects.ring(ring.center, ring.radius, ActiveFx.peak(COLOR))
	ctx.break_props(ring.center, ring.radius, "quake_knock")
	var struck: Array = []
	for enemy in combat.get_tree().get_nodes_in_group(Groups.ENEMY):
		if not enemy.is_dead() and ring.contains(enemy.global_position):
			struck.append(enemy)
	for enemy in struck:
		if is_instance_valid(enemy) and not enemy.is_dead():
			combat._hit(enemy, KIND, dmg, enemy.global_position - ring.center, KNOCK, "", SOURCE, IMPACT)
	_chain(struck, dmg)
	_shatter(ring)
	spent.append([ring, LINGER])


func _chain(struck: Array, dmg: float) -> void:
	var jumps := pattern_level("chain_arc")
	if jumps < 1 or struck.size() < 2:
		return
	for from in struck:
		var visited := [from]
		var at: Vector3 = from.global_position
		var hit := dmg
		for jump in jumps:
			hit *= CHAIN_FALLOFF
			var next: Node3D = null
			var best := INF
			for other in struck:
				if other in visited or not is_instance_valid(other) or other.is_dead():
					continue
				var d: float = other.global_position.distance_to(at)
				if d < best:
					best = d
					next = other
			if next == null:
				break
			visited.append(next)
			combat.effects.arc(at, next.global_position, ActiveFx.peak(COLOR))
			combat._hit(next, KIND, hit, next.global_position - at, KNOCK * 0.5, "", SOURCE, IMPACT)
			at = next.global_position


func _shatter(ring: Node3D) -> void:
	var build = ctx.build
	if build == null or not build.has_method("apply_element") or build.get("field") == null:
		return
	var inside: Array = []
	for slab in build.field.slabs():
		var at: Vector3 = slab["at"]
		if Vector2(at.x - ring.center.x, at.z - ring.center.z).length() <= ring.radius:
			inside.append(slab)
	for slab in inside:
		if build.field.slabs().has(slab):
			build.apply_element(ELEMENT, Vector3(slab["at"].x, float(slab["top"]) + 0.3, slab["at"].z), "active")


func _cracks(ring: Node3D, progress: float) -> void:
	var center: Vector3 = ring.center + Vector3.UP * 0.15
	var reach: float = ring.radius * clampf(progress * 1.15, 0.1, 1.0)
	var seed := float(knocks) * 2.39996
	for i in CRACKS:
		var a := seed + TAU * i / CRACKS
		combat.effects.arc(center, center + Vector3(cos(a), 0.0, sin(a)) * reach, ActiveFx.peak(COLOR))
	var rim := ceili(CRACKS * 2 * progress)
	for i in rim:
		var a0 := seed + TAU * i / (CRACKS * 2)
		var a1 := seed + TAU * (i + 1) / (CRACKS * 2)
		combat.effects.arc(center + Vector3(cos(a0), 0.0, sin(a0)) * ring.radius,
			center + Vector3(cos(a1), 0.0, sin(a1)) * ring.radius, ActiveFx.peak(COLOR))


func _free(ring) -> void:
	if is_instance_valid(ring):
		ring.queue_free()
