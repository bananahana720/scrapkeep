extends SceneTree

const Game := preload("res://src/game.gd")
const Warden := preload("res://src/combat/warden.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")

# Warden III's two threats read differently. The pulse lifts inside a ring; the magnet
# pulls inside its own wedge, aimed from the arm at the ball, with a dashed rim and
# chevrons pointing home. With both charging at once the two telegraphs are different
# shapes and the wedge contains the ball it was aimed at. The magnet is not a weak point
# while it only telegraphs, so an early shot meets the body; it becomes one in the tug.

const BALL_OFFSET := Vector3(15.0, 0.0, 4.0)

var _game
var _warden: Node3D
var _failures := 0
var _step := 0
var _ticks := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(check: String, ok: bool, detail: String) -> void:
	print("[%s] %s -> %s" % [check, detail, "PASS" if ok else "FAIL"])
	if not ok:
		_failures += 1


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	match _step:
		0:
			_setup()
			_step = 1
		1:
			_ticks += 1
			if _warden.magnet_state == Warden.Magnet.TELEGRAPH and _warden.state_name() != "":
				_check_telegraph()
				_step = 2
			elif _ticks > 120:
				_report("telegraph", false, "the magnet never telegraphed in 120 ticks")
				return _finish()
		2:
			if _warden.magnet_state == Warden.Magnet.TUG:
				_report("tug_weak_point", _has_magnet(_warden.weak_points()),
					"in the tug the magnet is a weak point: %s" % [_warden.weak_points()])
				return _finish()
			_ticks += 1
			if _ticks > 400:
				_report("tug_weak_point", false, "the tug never started")
				return _finish()
	return false


func _setup() -> void:
	var ctx = _game.ctx
	ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(1)
	_game.flow.enter_stage(3, Vector3.ZERO, false)
	_game.run.set_max_hp(99999.0)
	_warden = ctx.spawner.spawn_enemy("warden", ctx.terrain.beacon_point(3))
	var at: Vector3 = _warden.global_position + BALL_OFFSET
	at = ctx.terrain.drop_point(at.x, at.z, 1.05)
	_game.player.reset_to(at)
	_game.player.body().global_position = at
	_warden._pulse_clock = Warden.PULSE_CYCLE - Warden.PULSE_TELEGRAPH - 0.02
	_warden._magnet_clock = Warden.MAGNET_CYCLE - Warden.MAGNET_TELEGRAPH - 0.02


func _check_telegraph() -> void:
	var pulse: Node3D = _warden.telegraph()
	var magnet: Node3D = _warden.get("_magnet_ring")
	var both: bool = pulse != null and magnet != null
	_report("both_live", both and _warden.state_name() == "magnet_telegraph",
		"pulse charging and magnet telegraphing together: pulse %s, magnet %s" % [pulse != null, magnet != null])
	if not both:
		return
	_report("shapes_differ", pulse.shape == Telegraph.Shape.RING and magnet.shape != pulse.shape,
		"pulse telegraph shape %s, magnet telegraph shape %s" % [Telegraph.Shape.keys()[pulse.shape], Telegraph.Shape.keys()[magnet.shape]])
	_report("aimed_at_ball", magnet.contains(_game.player.ball_position()),
		"the magnet telegraph contains the ball it was aimed at")
	_report("no_early_weak_point", not _has_magnet(_warden.weak_points()),
		"while the magnet only telegraphs, weak_points() is %s" % [_warden.weak_points()])


func _has_magnet(points: Array) -> bool:
	for point in points:
		if point["id"] == "magnet":
			return true
	return false


func _finish() -> bool:
	var ok := _failures == 0
	print("combat_magnet_telegraph_test: %s" % ("PASS" if ok else "FAIL"))
	_game.free()
	quit(0 if ok else 1)
	return true
