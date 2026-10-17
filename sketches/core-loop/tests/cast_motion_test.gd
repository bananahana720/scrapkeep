extends SceneTree

const Game := preload("res://src/game.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const T := preload("res://tests/support/t.gd")
const Intent := preload("res://src/movement/intent.gd")

# Q2, "Depends on the pilot" (Andrew, 2026-10-17 22:12:39Z; design-v3/FIELDS-AND-CASTS.md
# section 4): the heavy pilots, Tarn and the Cannon, plant for their heavy casts (their depth-3
# Q variants), braking to a stop through the wind-up; Sable, Kest, Rivet and Tally cast on the
# move. For each pilot a ball rolling at SPEED presses a depth-3 Q: at the end of the wind-up a
# planting pilot is near still and a moving one keeps most of its speed. The plant rows are
# exactly the Tarn and Cannon variants. A Tarn at the 60 m/s soft cap with the drive held is
# still by the plant's 0.15 s mark and stays still through the wind-up.

const PILOTS := {
	"pylon_engineer": {"pilot": "pylon_engineer", "variant": "ball_lightning", "plant": false},
	"runner_gunner": {"pilot": "runner_gunner", "variant": "prism_cutter", "plant": false},
	"demolitions_caster": {"pilot": "demolitions_caster", "variant": "air_raid", "plant": false},
	"tarn": {"pilot": "tarn", "variant": "rake_run", "plant": true},
	"tally": {"pilot": "tally", "variant": "plate_audit", "plant": false},
	"remembered_cannon": {"pilot": "remembered_cannon", "variant": "cannon_creeping_barrage", "plant": true},
	"tarn at the cap, driving": {"pilot": "tarn", "variant": "vice_leap", "plant": true, "speed": 60.0, "drive": true},
}
const SPEED := 12.0
const PLANT_MARK := 0.15
const STILL := 1.0
const KEPT := 0.6
const LIMIT := 120
const EXPECTED_CHECKS := 17

var _t := T.new("cast_motion_test")
var _order: Array = PILOTS.keys()
var _game
var _ticks := 0
var _pressed := false
var _speed_at_end := -1.0
var _speed_at_mark := -1.0
var _winding := 0.0


func _initialize() -> void:
	var plants := []
	for id in AbilityState.ABILITIES:
		if bool(AbilityState.ABILITIES[id].get("plant", false)):
			plants.append(id)
	plants.sort()
	_t.eq("the plant rows are the Tarn and Cannon variants", plants,
		["cannon_creeping_barrage", "cannon_plate_mortar", "rake_run", "vice_leap"])
	_next()


func _next() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_ticks = -1
	_pressed = false
	_speed_at_end = -1.0
	_speed_at_mark = -1.0
	_winding = 0.0


func _physics_process(_delta: float) -> bool:
	if _order.is_empty() or _game.flow == null:
		return false
	var pilot: String = _order[0]
	var row: Dictionary = PILOTS[pilot]
	var speed := float(row.get("speed", SPEED))
	if _ticks < 0:
		var index := -1
		for i in _game.flow.classes.size():
			if String(_game.flow.classes[i].id) == String(row["pilot"]):
				index = i
		_game.ctx.calm = true
		_game.flow.press_start()
		_game.flow.choose_class(index)
		_game.run.set_max_hp(99999.0)
		_ticks = 0
		return false
	_ticks += 1
	var player = _game.player
	var ult = _game.combat.ultimate
	if _ticks == 2:
		var terrain = _game.ctx.terrain
		var at: Vector3 = terrain.drop_point(terrain.spawn_point(1).x, terrain.spawn_point(1).z, 1.05)
		player.abilities.ultimate_id = row["variant"]
		player.reset_to(at, Vector3(speed, 0.0, 0.0))
		if bool(row.get("drive", false)):
			var source := Intent.Scripted.new()
			source.hold["move"] = Vector2(0.0, 1.0)
			player.source = source
	if _ticks == 4 and not _pressed:
		_pressed = true
		ult.meter.refund(ult.meter.CAP)
		var refusal: String = ult.press()
		_t.check("%s starts its Q" % pilot, refusal == "" and ult.winding_up(), "refusal %s" % refusal)
	if _pressed and _speed_at_end < 0.0 and (not ult.winding_up() or _ticks > LIMIT):
		_speed_at_end = _last_speed
	if _pressed and ult.winding_up():
		_last_speed = player.planar_velocity().length()
		_winding += _delta
		if _speed_at_mark < 0.0 and _winding >= PLANT_MARK + 1.0 / 60.0:
			_speed_at_mark = _last_speed
	if _speed_at_end >= 0.0:
		if bool(row["plant"]):
			_t.check("%s plants through the wind-up" % pilot, _speed_at_end <= STILL, "speed %.2f m/s" % _speed_at_end)
			if row.has("speed"):
				_t.check("%s is still by the plant mark" % pilot, _speed_at_mark >= 0.0 and _speed_at_mark <= STILL,
					"speed %.2f m/s at %.2f s" % [_speed_at_mark, PLANT_MARK])
		else:
			_t.check("%s casts on the move" % pilot, _speed_at_end >= speed * KEPT, "speed %.2f m/s" % _speed_at_end)
		_game.free()
		_order.pop_front()
		if _order.is_empty():
			_t.eq("the check count", _t.checks + 1, EXPECTED_CHECKS)
			quit(_t.verdict())
			return true
		_next()
	return false


var _last_speed := 0.0
