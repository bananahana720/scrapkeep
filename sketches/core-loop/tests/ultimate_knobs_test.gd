extends SceneTree

const UpgradeTree := preload("res://src/core/upgrade_tree.gd")
const Ultimate := preload("res://src/combat/ultimate.gd")
const T := preload("res://tests/support/t.gd")

class PlayerFixture extends RefCounted:

	var tree := UpgradeTree.new()
	var abilities := {"ultimate_id": "ult_default"}
	var kit := {"aim": {}}


	func ball_position() -> Vector3:
		return Vector3.ZERO


	func set_velocity_now(_velocity: Vector3, _cause: String) -> void:
		pass


class LandingFixture extends Ultimate:


	var flights := 0


	func _begin_flight() -> void:
		flights += 1


	func _strike(_at: Vector3) -> void:
		pass


var _t := T.new("ultimate_knobs_test")


func _initialize() -> void:
	var player := PlayerFixture.new()
	var ult := LandingFixture.new()
	ult.ctx = {"player": player, "run": RefCounted.new(), "root": null}
	root.add_child(ult)
	ult.set_physics_process(false)
	var enemy := Node3D.new()
	root.add_child(enemy)
	enemy.position = Vector3(5.0, 0.0, 0.0)
	enemy.add_to_group("enemy")
	var values := {"ult_beats": 1, "ult_encore": true, "ult_radius": 1.5, "ult_volley": 2}
	var defaults := {"ult_beats": 0, "ult_encore": false, "ult_radius": 0.0, "ult_volley": 0}
	var unchanged := {"ult_beats": Ultimate.NO_MUSIC_BEATS, "ult_encore": false,
		"ult_radius": Ultimate.LANDING_RADIUS[0], "ult_volley": Ultimate.VOLLEY_TARGETS}
	var list := UpgradeTree.nodes("pylon_engineer")
	var original: Dictionary = list[0]
	for knob in values:
		player.tree.reset("pylon_engineer")
		var before = _read(ult, knob)
		_t.eq("%s unset reader" % knob, before, unchanged[knob])
		var fixture := original.duplicate(true)
		for op in UpgradeTree.OPS:
			fixture.erase(op)
		fixture["key"] = "ultimate"
		fixture["knob"] = {knob: values[knob]}
		list[0] = fixture
		var issues := UpgradeTree.problems("pylon_engineer")
		_t.check("%s validates" % knob, issues.is_empty(), str(issues))
		if not UpgradeTree.KNOBS.has(knob):
			list[0] = original
			continue
		_t.eq("%s default" % knob, player.tree.knob(knob), defaults[knob])
		_t.eq("%s default type" % knob, typeof(player.tree.knob(knob)), typeof(defaults[knob]))
		player.tree.open_checkpoint()
		_t.check("%s applies" % knob, player.tree.pick(fixture["id"]))
		_t.eq("%s stored" % knob, player.tree.knob(knob), values[knob])
		var after = _read(ult, knob)
		_t.eq("%s reader" % knob, after, true if knob == "ult_encore" else before + values[knob])
		list[0] = original
	_t.check("fixture restored", list[0] == original)
	enemy.free()
	ult.free()
	quit(_t.verdict())


func _read(ult, knob: String):
	match knob:
		"ult_beats":
			return ult.plan(Vector3.ZERO, {})["beats"]
		"ult_radius":
			return ult.landing_radius()
		"ult_volley":
			return ult.volley_targets()
		"ult_encore":
			ult.flights = 0
			ult._plan = {"legs": [{"strike": false}]}
			ult._leg = 0
			ult._beats = 7
			ult._beat_len = 0.3
			ult._land(Vector3.ZERO)
			return ult.flights == 1 and ult._plan["legs"].size() == 2
	return null
