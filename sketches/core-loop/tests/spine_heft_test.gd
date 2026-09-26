extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")

# Heft is the growth number and it never touches handling. The mutators move mass and
# heft as DEMO-SPEC says, class changes publish once, cores are stage-scoped, restore
# is exact, and the ball reaches cruise from rest in the same time at mass 0 and 600.

const DRIVE_FROM := Vector2(-100.0, -120.0)
const CRUISE_SHARE := 0.9
const DRIVE_LIMIT := 900
const HANDLING_TOLERANCE := 0.03
# A teleport lands with fresh contacts; letting the ball settle first makes repeat drives
# comparable, so the check measures heft and not the landing.
const SETTLE_TICKS := 45

var _game
var _source := Intent.Scripted.new()
var _failures := 0
var _started := false
var _counts := {"scrap_lost": 0, "heft_class_changed": 0, "heft_class_dropped": 0, "core_gained": 0}
var _drives: Array[int] = []
var _drive_ticks := -1
var _settle := 0


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
	if not _started:
		_started = true
		_game.ctx.calm = true
		_game.player.source = _source
		var events = _game.events
		events.scrap_lost.connect(func(_a, _b, _c, _d): _counts["scrap_lost"] += 1)
		events.heft_class_changed.connect(func(_a, _b): _counts["heft_class_changed"] += 1)
		events.core_gained.connect(func(_a, _b, _c): _counts["core_gained"] += 1)
		events.heft_class_dropped.connect(func(_a, _b): _counts["heft_class_dropped"] += 1)
		_game.flow.press_start()
		_game.flow.choose_class(0)
		_mutator_checks()
		_start_drive()
		return false
	if _settle > 0:
		_settle -= 1
		if _settle == 0:
			_source.hold = {"move": Vector2(0.0, 1.0)}
			_drive_ticks = 0
		return false
	if _drive_ticks >= 0:
		_drive_ticks += 1
		if _game.player.planar_velocity().length() >= _game.tuning.f("cruise") * CRUISE_SHARE or _drive_ticks >= DRIVE_LIMIT:
			_drives.append(_drive_ticks)
			_drive_ticks = -1
			if _drives.size() == 1:
				_start_drive()
			elif _drives.size() == 2:
				_game.run.add_scrap(600, Vector3.ZERO)
				_start_drive()
			else:
				return _finish()
	return false


func _mutator_checks() -> void:
	var run = _game.run
	run.add_scrap(60, Vector3.ZERO)
	_report("add scrap", is_equal_approx(run.mass, 60.0) and is_equal_approx(run.heft(), 1.4) and run.scrap == 60,
		"add_scrap(60): mass %.1f, heft %.3f (needs 1.4), wallet %d" % [run.mass, run.heft(), run.scrap])
	var spent: bool = run.spend_scrap(30)
	_report("spend keeps mass", spent and is_equal_approx(run.mass, 60.0) and is_equal_approx(run.heft(), 1.4) and run.scrap == 30,
		"spend_scrap(30): mass %.1f, heft %.3f, wallet %d" % [run.mass, run.heft(), run.scrap])
	var took: int = run.lose_scrap(20, Vector3.ZERO, "crane")
	_report("lose scrap", is_equal_approx(run.mass, 40.0) and run.scrap == 10 and took == 20 and _counts["scrap_lost"] == 1,
		"lose_scrap(20): mass %.1f, wallet %d, returned %d, scrap_lost fired %d time(s)" % [run.mass, run.scrap, took, _counts["scrap_lost"]])
	var before: float = run.heft()
	run.add_part("dash_vane", "test")
	_report("part heft", is_equal_approx(run.heft() - before, 0.2),
		"add_part raised heft from %.3f to %.3f" % [before, run.heft()])
	var class_before: int = run.heft_class()
	run.add_scrap(10, Vector3.ZERO)
	_report("class change", class_before == 1 and run.heft_class() == 2 and _counts["heft_class_changed"] == 1,
		"heft %.3f crossed 1.5: class %d to %d, heft_class_changed fired %d time(s) over the whole sequence" % [run.heft(), class_before, run.heft_class(), _counts["heft_class_changed"]])

	run.lose_scrap(30, Vector3.ZERO, "crane")
	_report("class drop", run.heft_class() == 1 and _counts["heft_class_dropped"] == 1 and _counts["heft_class_changed"] == 1,
		"a theft took heft to %.3f: heft_class_dropped fired %d time(s), heft_class_changed still %d" % [run.heft(), _counts["heft_class_dropped"], _counts["heft_class_changed"]])
	run.add_scrap(30, Vector3.ZERO)

	run.add_core("event", Vector3.ZERO)
	var one: int = run.gate_tier_bonus()
	run.add_core("vault", Vector3.ZERO)
	run.add_core("vault", Vector3.ZERO)
	_report("cores", run.bonus_cores == 3 and one == 1 and run.gate_tier_bonus() == 2 and _counts["core_gained"] == 3,
		"3 cores: bonus_cores %d, tier bonus %d after one and %d after three, core_gained fired %d times" % [run.bonus_cores, one, run.gate_tier_bonus(), _counts["core_gained"]])

	var ball: Vector3 = _game.player.ball_position()
	run.snapshot(ball, Vector3.ZERO, 0.0)
	var mass: float = run.mass
	var heft: float = run.heft()
	var cores: int = run.bonus_cores
	run.add_scrap(100, Vector3.ZERO)
	run.add_part("boost_coil", "test")
	run.add_core("event", Vector3.ZERO)
	run.restore()
	_report("restore", run.mass == mass and run.heft() == heft and run.bonus_cores == cores,
		"restore(): mass %.1f (was %.1f), heft %.4f (was %.4f), cores %d (was %d)" % [run.mass, mass, run.heft(), heft, run.bonus_cores, cores])

	_game.flow.enter_stage(2, Vector3(0.0, 0.0, 14.0), false)
	var reset_cores: int = run.bonus_cores
	run.add_core("event", Vector3.ZERO)
	_game.flow.retry_stage()
	_report("cores per stage", reset_cores == 0 and run.bonus_cores == 0 and run.snapshot_value("bonus_cores") == 0,
		"entering stage 2 reset cores to %d; a core won then retried back to %d" % [reset_cores, run.bonus_cores])


func _start_drive() -> void:
	var at: Vector3 = _game.ctx.terrain.drop_point(DRIVE_FROM.x, DRIVE_FROM.y, 1.05)
	_game.player.reset_to(at)
	_game.player.body().global_position = at
	_game.camera.snap(Vector3.RIGHT)
	_source.hold = {}
	_settle = SETTLE_TICKS


func _finish() -> bool:
	var light: int = _drives[0]
	var repeat: int = _drives[1]
	var heavy: int = _drives[2]
	var gap := absf(heavy - light) / float(maxi(1, light))
	var noise := absf(repeat - light) / float(maxi(1, light))
	_report("handling", light < DRIVE_LIMIT and heavy < DRIVE_LIMIT and gap < HANDLING_TOLERANCE,
		"rest to %.0f%% of cruise: %d ticks at mass 50, %d on a repeat (%.1f%% noise), %d at mass %.0f (heft %.2f), %.1f%% apart (needs < 3%%)"
			% [CRUISE_SHARE * 100.0, light, repeat, noise * 100.0, heavy, _game.run.mass, _game.run.heft(), gap * 100.0])
	print("spine_heft_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true
