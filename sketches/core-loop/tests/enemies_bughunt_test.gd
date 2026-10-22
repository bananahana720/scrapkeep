extends SceneTree

# BUGFIX-COMBAT-B (wave 12-F, 2026-10-09): the hunter's enemy-file findings, each a check that
# failed on eb87cb8.
# F007 Rivet's wear trail keeps the sub-unit remainder of wear: two halves leave one patch.
# F008 The miniboss steps and poses with a null or a freed target and raises no script error.
# F012 A swatter body mesh with no fleet_paint surface builds without an engine index error.
const Game := preload("res://src/game.gd")
const WearTrail := preload("res://src/combat/wear_trail.gd")
const Miniboss := preload("res://src/combat/miniboss.gd")
const Swatter := preload("res://src/combat/swatter.gd")
const Intent := preload("res://src/movement/intent.gd")
const T := preload("res://tests/support/t.gd")

var _t := T.new("enemies_bughunt_test")
var _game
var _log := ErrorLog.new()


class ErrorLog:
	extends Logger
	var errors: Array[String] = []

	func _log_error(_function: String, _file: String, _line: int, code: String,
			rationale: String, _editor_notify: bool, error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != Logger.ERROR_TYPE_WARNING:
			errors.append("%s:%d %s %s" % [_file, _line, code, rationale])


class FakeTuning:
	extends RefCounted
	func world_one() -> bool:
		return true


class FakeTree:
	extends RefCounted
	func path() -> Array:
		return [WearTrail.NODE_ID]


class FakeState:
	extends RefCounted
	var grounded := true
	func on_floor() -> bool:
		return grounded


class FakePlayer:
	extends RefCounted
	var tree := FakeTree.new()
	var state := FakeState.new()
	func ball_position() -> Vector3:
		return Vector3(0.0, 0.5, 0.0)


class FakeCtx:
	extends RefCounted
	var tuning := FakeTuning.new()
	var player := FakePlayer.new()
	var run = null


func _initialize() -> void:
	_run.call_deferred()


func _floor(at: Vector3) -> Vector3:
	return Vector3(at.x, 0.0, at.z)


func _wear() -> void:
	var trail = WearTrail.new()
	trail.setup(FakeCtx.new(), null, _floor)
	trail._on_wear(0.5)
	trail._on_wear(0.5)
	_t.eq("F007 two halves", trail.patches.size(), 1)
	trail._on_wear(1.5)
	trail._on_wear(0.5)
	_t.eq("F007 remainder kept", trail.patches.size(), 3)
	trail._on_wear(1.0)
	_t.eq("F007 whole unit unchanged", trail.patches.size(), 4)


func _miniboss() -> void:
	var terrain = _game.ctx.terrain
	var at := Vector3(-100.0, 0.0, -90.0)
	at.y = terrain.height(at.x, at.z) + Miniboss.HALF_HEIGHT
	var boss = _game.ctx.spawner.spawn_enemy("miniboss", at)
	boss.set_physics_process(false)
	var states := [Miniboss.State.STALK, Miniboss.State.CHARGE_BRACE, Miniboss.State.WEAK, Miniboss.State.SLAM_CROUCH]
	var freed := Node3D.new()
	freed.free()
	for case in [["null", null], ["freed", freed]]:
		boss.target = case[1]
		var before := _log.errors.size()
		for s in states:
			boss.state = s
			boss._pose(1.0 / 60.0)
			boss._physics_process(1.0 / 60.0)
		var raised := _log.errors.slice(before)
		_t.check("F008 %s target" % case[0], raised.is_empty(),
			"%d errors stepping four states (first %s)" % [raised.size(), "" if raised.is_empty() else raised[0]])
	boss.queue_free()


func _swatter() -> void:
	var body := BoxMesh.new()
	var paddle := BoxMesh.new()
	Swatter._shared = [
		{"mesh": body, "xform": Transform3D.IDENTITY, "body": -1, "paddle": false},
		{"mesh": paddle, "xform": Transform3D.IDENTITY, "body": -1, "paddle": true},
	]
	var at: Vector3 = _game.ctx.terrain.drop_point(-80.0, -90.0, 1.6)
	var before := _log.errors.size()
	var swatter = _game.ctx.spawner.spawn_enemy("swatter", at)
	var raised := _log.errors.slice(before)
	_t.check("F012 no fleet_paint surface", raised.is_empty(),
		"%d errors building a body without fleet_paint (first %s)" % [raised.size(), "" if raised.is_empty() else raised[0]])
	var built: Array = swatter.find_children("SwatterBody", "MeshInstance3D", true, false)
	_t.check("F012 body built", built.size() == 1, "%d SwatterBody meshes" % built.size())
	Swatter._shared = []
	swatter.queue_free()


func _run() -> void:
	OS.add_logger(_log)
	_wear()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	_miniboss()
	_swatter()
	OS.remove_logger(_log)
	quit(_t.verdict())
