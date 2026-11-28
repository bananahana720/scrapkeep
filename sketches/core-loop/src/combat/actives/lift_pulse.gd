extends "res://src/combat/actives/active_base.gd"

const ActiveFx := preload("res://src/combat/actives/active_fx.gd")
const Palette := preload("res://src/core/palette.gd")

const RANGE := 10.0
const HALF_ANGLE := 35.0
const SPREAD_PER_LEVEL := 10.0
const MAX_HALF_ANGLE := 75.0
const HEIGHT_BAND := 3.0
const BASE_DAMAGE := 6.0
const KNOCK := 18.0
const KNOCK_PER_CLASS := 12.0
const BONUS_KNOCK := 0.2
const ECHO_GAP := 0.2
const ECHO_SHARE := 0.6
const FAN_RADIUS := 1.6
const EDGE_STEP := 1.25
const CHAIN_RANGE := 8.0
const CHAIN_FALLOFF := 0.7
const COLOR := Palette.ARC
const KIND := "lift_pulse"
const IMPACT := "ram"
const SOURCE := "special"

var echoes: Array = []
var pulses := 0
var chain_hits := 0
var last_cone := {}


func clear() -> void:
	echoes.clear()


func damage() -> float:
	return scaled_damage(BASE_DAMAGE)


func knock_for(bonus: int) -> float:
	var heft_class := 1
	if ctx.run != null and ctx.run.has_method("heft_class"):
		heft_class = int(ctx.run.heft_class())
	return (KNOCK + KNOCK_PER_CLASS * float(maxi(heft_class, 1) - 1)) * (1.0 + BONUS_KNOCK * float(bonus))


func half_angle() -> float:
	return minf(HALF_ANGLE + SPREAD_PER_LEVEL * float(pattern_level("spiral_wave")), MAX_HALF_ANGLE)


func cone(bonus: int) -> Dictionary:
	return {"origin": ctx.player.ball_position(), "forward": flat_aim(), "range": RANGE,
		"half_angle": half_angle(), "knock": knock_for(bonus), "damage": damage()}


static func inside(shape: Dictionary, at: Vector3) -> bool:
	var origin: Vector3 = shape["origin"]
	if absf(at.y - origin.y) > HEIGHT_BAND:
		return false
	var flat := Vector3(at.x - origin.x, 0.0, at.z - origin.z)
	if flat.length() > float(shape["range"]):
		return false
	if flat.length() < 0.01:
		return true
	return rad_to_deg(flat.angle_to(shape["forward"])) <= float(shape["half_angle"])


func fire(_rack, _row: Dictionary, bonus: int) -> int:
	var shape := cone(bonus)
	last_cone = shape
	var echo_count := pattern_level("cross_split")
	for i in echo_count:
		echoes.append({"cone": shape, "at": ECHO_GAP * float(i + 1), "share": ECHO_SHARE})
	var struck := _pulse(shape, 1.0)
	var jumps := pattern_level("chain_arc")
	if jumps > 0:
		for enemy in struck:
			if is_instance_valid(enemy) and not enemy.is_dead():
				_chain(shape, enemy, jumps)
	return 1 + echo_count


func _chain(shape: Dictionary, first: Node3D, jumps: int) -> void:
	var visited := [first]
	var at: Vector3 = first.global_position
	var dmg: float = shape["damage"]
	for jump in jumps:
		dmg *= CHAIN_FALLOFF
		var next: Node3D = null
		var best := CHAIN_RANGE
		for enemy in combat.get_tree().get_nodes_in_group(Groups.ENEMY):
			if enemy in visited or enemy.is_dead() or not inside(shape, enemy.global_position):
				continue
			var distance: float = enemy.global_position.distance_to(at)
			if distance <= best:
				best = distance
				next = enemy
		if next == null:
			return
		visited.append(next)
		combat.effects.arc(at, next.global_position, ActiveFx.peak(COLOR))
		combat.deal_hit(next, KIND, dmg, next.global_position - at, float(shape["knock"]) * 0.3, "", SOURCE, IMPACT)
		chain_hits += 1
		at = next.global_position


func step(delta: float) -> void:
	if echoes.is_empty():
		return
	var waiting: Array = []
	for echo in echoes:
		echo["at"] = float(echo["at"]) - delta
		if float(echo["at"]) <= 0.0:
			_pulse(echo["cone"], float(echo["share"]))
		else:
			waiting.append(echo)
	echoes = waiting


func _pulse(shape: Dictionary, share: float) -> Array:
	pulses += 1
	_draw(shape)
	var origin: Vector3 = shape["origin"]
	var struck: Array = []
	for enemy in combat.get_tree().get_nodes_in_group(Groups.ENEMY):
		if enemy.is_dead() or not inside(shape, enemy.global_position):
			continue
		var away: Vector3 = enemy.global_position - origin
		away.y = 0.0
		if away.length() < 0.01:
			away = shape["forward"]
		combat.deal_hit(enemy, KIND, float(shape["damage"]) * share, away, float(shape["knock"]) * share, "", SOURCE, IMPACT)
		struck.append(enemy)
	return struck


func _draw(shape: Dictionary) -> void:
	var origin: Vector3 = shape["origin"]
	var forward: Vector3 = shape["forward"]
	var reach: float = shape["range"]
	var half := deg_to_rad(float(shape["half_angle"]))
	combat.effects.ring(origin, FAN_RADIUS, ActiveFx.peak(COLOR))
	var lift := Vector3.UP * 0.4
	for side in [-1.0, 1.0]:
		var edge := forward.rotated(Vector3.UP, half * side)
		var steps := ceili(reach / EDGE_STEP)
		for i in steps:
			combat.effects.arc(origin + lift + edge * reach * float(i) / steps, origin + lift + edge * reach * float(i + 1) / steps, ActiveFx.peak(COLOR))
	var arc_steps := maxi(2, ceili(reach * half * 2.0 / EDGE_STEP))
	for i in arc_steps:
		var a := forward.rotated(Vector3.UP, lerpf(-half, half, float(i) / arc_steps))
		var b := forward.rotated(Vector3.UP, lerpf(-half, half, float(i + 1) / arc_steps))
		combat.effects.arc(origin + lift + a * reach, origin + lift + b * reach, ActiveFx.peak(COLOR))
