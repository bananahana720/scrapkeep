extends "res://src/combat/actives/active_base.gd"

const ActiveFx := preload("res://src/combat/actives/active_fx.gd")
const Palette := preload("res://src/core/palette.gd")
const Hitscan := preload("res://src/combat/hitscan.gd")

const BEAM_SECONDS := 1.6
const BONUS_SECONDS := 0.25
const REACH := 14.0
const WIDTH := 0.9
const SWEEP := 3.5
const BURN := 60.0
const CUT_DAMAGE := 7.5
const DEFAULT_GIRTH := 1.0
const FAN_DEG := 12.0
const HEAT_STEPS := 8
const GLOW_REACH := 1.6
const GLOW_COLD := Palette.RUST
const LIFT := 0.5
const KNOCK := 0.0
const COLOR := Palette.HAZARD
const KIND := "torch"
const IMPACT := "runner"
const SOURCE := "special"
const LAYER := "active_cutting_torch_%d"
const ID := "cutting_torch"

var guiding := false
var beam_left := 0.0
var heading := Vector3.FORWARD
var cuts := 0
var lanes: Array = []
var _beams := 1
var _burn := BURN
var _heat := {}
var _glow := {}


func clear() -> void:
	_heat.clear()
	_glow.clear()
	_end()


func cancel() -> void:
	_end()


func _end() -> void:
	guiding = false
	beam_left = 0.0
	_erase()


func beams_for() -> int:
	return 1 + pattern_level("spiral_wave")


func burn() -> float:
	return BURN * (CUT_DAMAGE + punch_bonus()) / CUT_DAMAGE * weapon_damage_mult()


func begin(_rack, _row: Dictionary) -> void:
	_beams = beams_for()
	heading = flat_aim()
	guiding = true
	_commit()


func fire(_rack, _row: Dictionary, bonus: int) -> int:
	if not guiding:
		_beams = beams_for()
		heading = flat_aim()
	guiding = false
	_burn = burn()
	beam_left = BEAM_SECONDS + BONUS_SECONDS * bonus
	_commit()
	return _beams


func step(delta: float) -> void:
	if not guiding and beam_left <= 0.0:
		return
	_turn(delta)
	_commit()
	if guiding:
		return
	_cut(delta)
	beam_left -= delta
	if beam_left <= 0.0:
		_end()


func _turn(delta: float) -> void:
	var want := flat_aim()
	var angle := heading.angle_to(want)
	var turn := SWEEP * delta
	heading = want if angle <= turn else heading.slerp(want, turn / angle).normalized()


func _commit() -> void:
	var from: Vector3 = ctx.player.ball_position()
	lanes.clear()
	for i in _beams:
		var offset := 0.0 if _beams == 1 else lerpf(-0.5, 0.5, float(i) / float(_beams - 1)) * deg_to_rad(FAN_DEG) * float(_beams - 1)
		var dir := heading.rotated(Vector3.UP, offset)
		var lane := {"kind": "line", "from": from, "to": _reach(from, dir), "width": WIDTH, "fill": 0.0 if guiding else 1.0}
		lanes.append(lane)
		ctx.player.indicator.set_shape(LAYER % i, ctx.player.yours(lane.duplicate()))
		if not guiding:
			combat.effects.arc(from + Vector3.UP * LIFT, lane["to"] + Vector3.UP * LIFT, ActiveFx.peak(COLOR))


func _reach(from: Vector3, dir: Vector3) -> Vector3:
	var to := from + dir * REACH
	var space: PhysicsDirectSpaceState3D = combat.get_viewport().get_world_3d().direct_space_state
	var cover := space.intersect_ray(PhysicsRayQueryParameters3D.create(from + Vector3.UP * LIFT, to + Vector3.UP * LIFT, Hitscan.WORLD))
	return Vector3(cover["position"].x, from.y, cover["position"].z) if not cover.is_empty() else to


func _cut(delta: float) -> void:
	for enemy in combat.get_tree().get_nodes_in_group("enemy"):
		if enemy.is_dead() or not _in_lanes(enemy):
			continue
		var id: int = enemy.get_instance_id()
		var heat: float = float(_heat.get(id, 0.0)) + _burn * delta
		var bite := maxf(CUT_DAMAGE * _burn / BURN, _plate(enemy))
		if heat >= bite:
			cuts += 1
			combat.effects.spark(enemy.global_position + Vector3.UP, ActiveFx.peak(COLOR))
			combat._hit(enemy, KIND, heat, enemy.global_position - ctx.player.ball_position(), KNOCK, "", SOURCE, IMPACT)
			heat = 0.0
			_glow.erase(id)
		elif bite > CUT_DAMAGE * _burn / BURN:
			_show_heat(enemy, id, heat / bite)
		_heat[id] = heat


func _show_heat(enemy: Node3D, id: int, fraction: float) -> void:
	var shown := floori(fraction * HEAT_STEPS)
	if shown <= int(_glow.get(id, 0)):
		return
	_glow[id] = shown
	var hot := float(shown) / HEAT_STEPS
	var at := enemy.global_position
	combat.effects.ring(at + Vector3.UP * 0.3, enemy_girth(enemy, DEFAULT_GIRTH) + GLOW_REACH * (1.0 - hot), ActiveFx.peak(GLOW_COLD.lerp(COLOR, hot)))
	combat.effects.spark(at + Vector3.UP, ActiveFx.peak(GLOW_COLD.lerp(COLOR, hot)))
	ctx.events.active_heat.emit(ID, at, hot)


func _in_lanes(enemy: Node3D) -> bool:
	var hull := enemy_girth(enemy, DEFAULT_GIRTH)
	for lane in lanes:
		if combat.in_line(lane["from"], lane["to"], lane["width"], enemy.global_position, hull):
			return true
	return false


func _plate(enemy: Node3D) -> float:
	if enemy.has_method("fight") and enemy.fight() == "posture":
		return 0.0
	if enemy.has_method("plating_for"):
		return maxf(0.0, enemy.plating_for(KIND, "") - combat.shred_of(enemy))
	return 0.0


func _erase() -> void:
	lanes.clear()
	if ctx == null or ctx.player == null or ctx.player.indicator == null:
		return
	for i in _beams:
		ctx.player.indicator.clear(LAYER % i)
