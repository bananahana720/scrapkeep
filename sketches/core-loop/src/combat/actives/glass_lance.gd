extends "res://src/combat/actives/active_base.gd"

const ActiveFx := preload("res://src/combat/actives/active_fx.gd")
const Palette := preload("res://src/core/palette.gd")

const BASE_DAMAGE := 34.0
const REACH := 40.0
const HALF_WIDTH := 0.9
const HEIGHT := 1.5
const DEFAULT_GIRTH := 0.6
const SAMPLE := 2.5
const CLIMB := 12.0
const DIVE := 6.0
const RIDE_MIN := 0.4
const RIDE_MAX := 1.6
const SPEED := 120.0
const FAN_DEG := 7.0
const TELL_HOLD := 0.12
const DRAW_LIFT := 0.3
const KNOCK := 8.0
const CHAIN_RANGE := 8.0
const CHAIN_FALLOFF := 0.7
const COLOR := Color(0.78, 1.0, 0.62)
const SHARD_COLOR := Color(0.94, 1.0, 0.9)
const KIND := "lance"
const SOURCE := "special"

var lances: Array = []
var pierced := 0
var _generation := 0


func clear() -> void:
	lances.clear()
	_generation += 1


func count_for(bonus: int) -> int:
	return 1 + bonus + pattern_level("cross_split")


func damage() -> float:
	return scaled_damage(BASE_DAMAGE)


func fire(_rack, _row: Dictionary, bonus: int) -> int:
	var count := count_for(bonus)
	var forward := flat_aim()
	var from: Vector3 = ctx.player.ball_position()
	var dmg := damage()
	for i in count:
		var dir := forward.rotated(Vector3.UP, deg_to_rad(FAN_DEG * (float(i) - float(count - 1) * 0.5)))
		var lance := {"from": from, "dir": dir, "s": 0.0, "hit": {}, "damage": dmg, "heights": _skim(from, dir)}
		_tell(lance)
		lances.append(lance)
	return count


func _skim(from: Vector3, dir: Vector3) -> PackedFloat32Array:
	var heights := PackedFloat32Array()
	var terrain = ctx.terrain
	var flat: bool = terrain == null or not terrain.has_method("height")
	var ride: float = 0.0 if flat else clampf(from.y - float(terrain.height(from.x, from.z)), RIDE_MIN, RIDE_MAX)
	for k in int(ceil(REACH / SAMPLE)) + 1:
		var at := from + dir * minf(REACH, k * SAMPLE)
		var y: float = from.y if flat or k == 0 else float(terrain.height(at.x, at.z)) + ride
		heights.append(clampf(y, from.y - DIVE, from.y + CLIMB))
	return heights


static func band_y(lance: Dictionary, along: float) -> float:
	var heights: PackedFloat32Array = lance["heights"]
	var at := clampf(along / SAMPLE, 0.0, float(heights.size() - 1))
	var k := mini(int(at), heights.size() - 2)
	return lerpf(heights[k], heights[k + 1], at - k)


func _point(lance: Dictionary, along: float) -> Vector3:
	var at: Vector3 = lance["from"] + lance["dir"] * along
	return Vector3(at.x, band_y(lance, along) + DRAW_LIFT, at.z)


func _tell(lance: Dictionary) -> void:
	var life := REACH / SPEED + TELL_HOLD
	var side: Vector3 = lance["dir"].cross(Vector3.UP).normalized() * HALF_WIDTH
	var heights: PackedFloat32Array = lance["heights"]
	for k in heights.size() - 1:
		var a := _point(lance, k * SAMPLE)
		var b := _point(lance, minf(REACH, (k + 1) * SAMPLE))
		combat.effects.beam(a, b, ActiveFx.peak(COLOR), life)
		for edge in [side, -side]:
			combat.effects.beam(a + edge, b + edge, ActiveFx.peak(Color(COLOR, 0.45)), life)


func step(delta: float) -> void:
	if lances.is_empty():
		return
	var generation := _generation
	var flying: Array = []
	for lance in lances.duplicate():
		if not _fly(lance, delta):
			flying.append(lance)
		if _generation != generation:
			return
	lances = flying


func _fly(lance: Dictionary, delta: float) -> bool:
	var before: float = lance["s"]
	var after := minf(REACH, before + SPEED * delta)
	lance["s"] = after
	var from: Vector3 = lance["from"]
	var dir: Vector3 = lance["dir"]
	combat.effects.beam(_point(lance, before), _point(lance, after), ActiveFx.peak(SHARD_COLOR), 0.08)
	var generation := _generation
	for enemy in combat.get_tree().get_nodes_in_group("enemy"):
		if enemy.is_dead() or lance["hit"].has(enemy.get_instance_id()):
			continue
		var girth := enemy_girth(enemy, DEFAULT_GIRTH)
		var rel: Vector3 = enemy.global_position - from
		var along := rel.dot(dir)
		if along < 0.0 or along > REACH or along > after or along < before - girth - 0.5:
			continue
		var lateral := Vector3(rel.x, 0.0, rel.z) - dir * along
		if lateral.length() > HALF_WIDTH + girth or absf(enemy.global_position.y - band_y(lance, along)) > HEIGHT + girth:
			continue
		lance["hit"][enemy.get_instance_id()] = true
		_pierce(enemy, lance)
		if _generation != generation:
			return true
	return after >= REACH


func _pierce(enemy: Node3D, lance: Dictionary) -> void:
	pierced += 1
	var dmg: float = lance["damage"]
	combat.effects.spark(enemy.global_position + Vector3.UP, ActiveFx.peak(SHARD_COLOR))
	combat._hit(enemy, KIND, dmg, lance["dir"], KNOCK, "", SOURCE)
	var jumps := pattern_level("chain_arc")
	if jumps > 0:
		combat._chain(enemy, enemy.global_position, {"damage": dmg, "chain_jumps": jumps, "chain_range": CHAIN_RANGE,
			"chain_falloff": CHAIN_FALLOFF, "color": ActiveFx.peak(COLOR), "kind": KIND, "knock": KNOCK, "source": SOURCE})
