extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")

# The heft-scaled magnet (DEMO-SPEC, owner B, nice-to-have): the reach is
# min(18, 6 * sqrt(heft)) at standstill, monotonic in heft and capped at 18 m, and the
# pull scales by the same factor. Live, a pickup changes the ball's planar speed by
# less than 1%, because scrap never touches the ball's velocity.

const LANE_X := -62.0
const SPEED := 20.0

var _game
var _build
var _source := Intent.Scripted.new()
var _failures := 0
var _ticks := 0
var _last_speed := 0.0
var _collect_changes: Array[float] = []


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
	_ticks += 1
	if _ticks == 1:
		_game.ctx.calm = true
		_game.player.source = _source
		_game.flow.press_start()
		_game.flow.choose_class(0)
		_build = _game.ctx.build
		return false
	if _ticks == 12:
		_check_curve()
		_start_roll()
		return false
	if _ticks > 12:
		_last_speed = _game.player.planar_velocity().length()
	if _ticks == 12 + 90:
		_check_pickups()
		print("build_magnet_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
		_game.free()
		quit(0 if _failures == 0 else 1)
		return true
	return false


func _check_curve() -> void:
	var scrap = _build.scrap
	var reaches: Array[float] = []
	var pulls: Array[float] = []
	var monotonic := true
	for heft in [1.0, 1.5, 2.2, 3.2, 4.6, 6.0, 9.0, 12.0, 20.0]:
		scrap.heft = heft
		reaches.append(scrap.heft_reach())
		pulls.append(scrap.pull_scale())
		if reaches.size() > 1 and reaches[-1] < reaches[-2]:
			monotonic = false
	var formula := true
	for i in reaches.size():
		var heft: float = [1.0, 1.5, 2.2, 3.2, 4.6, 6.0, 9.0, 12.0, 20.0][i]
		if not is_equal_approx(reaches[i], minf(18.0, 6.0 * sqrt(heft))) or not is_equal_approx(pulls[i], reaches[i] / 6.0):
			formula = false
	_report("magnet curve", monotonic and formula and reaches.max() <= 18.0 and is_equal_approx(reaches[0], 6.0),
		"reach at heft 1 to 20: %s m; pull x%s" % [reaches.map(func(r): return snappedf(r, 0.1)), pulls.map(func(p): return snappedf(p, 0.01))])
	scrap.heft = _game.run.heft()


func _start_roll() -> void:
	var at: Vector3 = _game.ctx.terrain.drop_point(LANE_X, -92.0, 1.05)
	_game.player.reset_to(at, Vector3(0.0, 0.0, SPEED))
	_game.player.body().global_position = at
	_game.camera.snap(Vector3(0.0, 0.0, 1.0))
	_source.hold = {"move": Vector2(0.0, 1.0)}
	_build.scrap.clear()
	for i in 6:
		var z := -86.0 + 3.0 * i
		var side := 3.0 if i % 2 == 0 else -3.0
		_build.scrap._add(_game.ctx.terrain.drop_point(LANE_X + side, z, 1.4))
	_game.events.scrap_collected.connect(_on_collected)
	_last_speed = SPEED


func _on_collected(_amount: int, _at: Vector3, _total: int) -> void:
	var now: float = _game.player.planar_velocity().length()
	if _last_speed > 0.1:
		_collect_changes.append(absf(now - _last_speed) / _last_speed)


func _check_pickups() -> void:
	var worst: float = _collect_changes.max() if not _collect_changes.is_empty() else 1.0
	_report("pickups keep speed", _collect_changes.size() >= 4 and worst < 0.01,
		"%d pickups at about %.0f m/s; the worst planar speed change on a pickup tick was %.3f%%"
			% [_collect_changes.size(), SPEED, worst * 100.0])
