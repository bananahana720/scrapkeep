extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")

# Brake and slam share Ctrl (balance-loop L11). A brake held from the ground must not
# become a slam when a bump lifts the ball: the slam would plant it, an unforeseen
# stop. With real physics the ball rolls over a kicker ramp at speed with Ctrl held
# from the ground: it leaves the ground and must not slam. A second run releases Ctrl
# in the air and presses it again: that fresh press slams.

const SPEED := 22.0
const RAMP_AT := 10.0
const RAMP_LENGTH := 8.0
const RAMP_PITCH := 16.0
const LIMIT := 90 * 4

var _game
var _source := Intent.Scripted.new()
var _failures := 0
var _phase := "boot"
var _wait := 0
var _run := {}
var _runs: Array[Dictionary] = []
var _ramp: StaticBody3D


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_wait += 1
	match _phase:
		"boot":
			_game.ctx.calm = true
			_game.player.source = _source
			_game.flow.press_start()
			_game.flow.choose_class(0)
			_phase = "settle"
			_wait = 0
		"settle":
			if _wait == 120:
				_start_run(false)
		"run":
			_step_run()
	return false


func _heading() -> Vector3:
	return _game.ctx.terrain.entry_heading(1)


func _start_run(repress: bool) -> void:
	var t = _game.ctx.terrain
	var h := _heading()
	var here: Vector3 = _game.player.ball_position()
	var start: Vector3 = t.drop_point(here.x, here.z, 0.6)
	_place_ramp(start, h)
	_game.player.reset_to(start, h * SPEED)
	_game.player.body().global_position = start
	_game.camera.snap(h)
	_source.hold = {"brake_held": true}
	_run = {"repress": repress, "air_ticks": 0, "slammed": false, "released": false, "air_before_press": 0}
	_phase = "run"
	_wait = 0


# A ramp rising along the heading, its low lip on the ground RAMP_AT metres ahead.
func _place_ramp(start: Vector3, h: Vector3) -> void:
	if is_instance_valid(_ramp):
		_ramp.queue_free()
	var t = _game.ctx.terrain
	var pitch := deg_to_rad(RAMP_PITCH)
	var lip: Vector3 = start + h * RAMP_AT
	lip.y = t.height(lip.x, lip.z)
	_ramp = StaticBody3D.new()
	_ramp.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8.0, 0.4, RAMP_LENGTH)
	shape.shape = box
	_ramp.add_child(shape)
	_game.ctx.root.add_child(_ramp)
	var basis := Basis.looking_at(h, Vector3.UP) * Basis(Vector3.RIGHT, pitch)
	var centre := lip + h * (RAMP_LENGTH * 0.5 * cos(pitch)) + Vector3.UP * (RAMP_LENGTH * 0.5 * sin(pitch) - 0.2)
	_ramp.global_transform = Transform3D(basis, centre)


func _step_run() -> void:
	var state = _game.player.state
	var kit = _game.player.kit
	if not state.grounded:
		_run["air_ticks"] += 1
	if kit.slamming:
		_run["slammed"] = true
	if _run["repress"] and not state.grounded and _run["air_ticks"] >= 4 and not _run["released"]:
		_run["released"] = true
		_run["air_before_press"] = _run["air_ticks"]
		_source.hold = {}
	elif _run["repress"] and _run["released"] and _source.hold.is_empty():
		_source.hold = {"brake_held": true}
	if _wait >= 150 or (_run["air_ticks"] >= 12 and state.grounded):
		_runs.append(_run)
		if _runs.size() == 1:
			_start_run(true)
		else:
			_finish()


func _finish() -> void:
	var held: Dictionary = _runs[0]
	var fresh: Dictionary = _runs[1]
	_report("held brake over a bump", held["air_ticks"] >= 8 and not held["slammed"],
		"Ctrl held from the ground over a %d-degree kicker at %.0f m/s: airborne %d ticks, slammed %s"
			% [int(RAMP_PITCH), SPEED, held["air_ticks"], held["slammed"]])
	_report("fresh press in the air", fresh["air_ticks"] >= 4 and fresh["released"] and fresh["slammed"],
		"released Ctrl after %d airborne ticks and pressed again: slammed %s"
			% [fresh["air_before_press"], fresh["slammed"]])
	print("spine_brake_slam_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
