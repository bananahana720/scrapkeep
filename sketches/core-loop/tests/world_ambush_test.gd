extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const AmbushAltar := preload("res://src/world/ambush_altar.gd")

# The ambush altar on stage 1's east line (LOOP-REDESIGN section 9), in the running
# game as Rivet. Held E brings its pack at once, round the ring; while it runs the prompt
# shows the time left and no keycap; clearing the pack inside 30 s pays one bonus core
# and publishes ambush_ended won. A second run whose clock runs out pays nothing.

const RIVET := 1

var _game
var _source := Intent.Scripted.new()
var _failures := 0
var _steps: Array = []
var _index := 0
var _ticks := 0
var _entered := false
var _ended: Array = []
var _fired: Array = []
var _altar
var _cores_before := 0


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
	if _steps.is_empty():
		_begin()
		return false
	if _index >= _steps.size():
		print("world_ambush_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
		quit(0 if _failures == 0 else 1)
		return true
	var step: Array = _steps[_index]
	if not _entered:
		_entered = true
		_ticks = 0
		(step[0] as Callable).call()
		return false
	_ticks += 1
	if _ticks < int(step[1]):
		return false
	(step[2] as Callable).call()
	_index += 1
	_entered = false
	return false


func _begin() -> void:
	_game.player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(RIVET)
	_game.events.ambush_ended.connect(func(id: String, won: bool, _at: Vector3): _ended.append([id, won]))
	_game.events.interact_fired.connect(func(family: String, id: String, _at: Vector3): _fired.append([family, id]))
	_steps = [
		[_noop, 30, _find_altar],
		[_approach, 10, _hold_e],
		[_noop, 45, _check_pack],
		[_noop, 2, _clear_pack],
		[_noop, 6, _check_paid],
		[_rerun, 2, _run_out],
		[_noop, 6, _check_unpaid],
	]


func _noop() -> void:
	pass


func _find_altar() -> void:
	for device in _game.world.interact.devices:
		if device is AmbushAltar:
			_altar = device
	_report("altar placed", _altar != null, "stage 1 carries an ambush altar: %s" % (_altar.id if _altar != null else "none"))


# Four metres west of the altar, looking at it.
func _approach() -> void:
	var at: Vector3 = _altar.global_position
	var ball: Vector3 = _game.ctx.terrain.drop_point(at.x - 4.0, at.z, 1.05)
	_game.player.reset_to(ball, Vector3.ZERO)
	_game.player.body().global_position = ball
	_game.camera.snap(Vector3(1.0, 0.0, 0.0))
	_cores_before = _game.run.bonus_cores


func _hold_e() -> void:
	_source.press["mount_pressed"] = true
	_source.hold["mount_held"] = true


func _check_pack() -> void:
	_source.hold = {}
	var prompt = _altar.prompt
	_report("a pack arrives now", _altar.running and _altar.pack.size() == AmbushAltar.PACK.size() and _fired.has(["fight", _altar.id]),
		"held E at the altar: running %s, %d of %d arrived, fight fired %s" % [_altar.running, _altar.pack.size(), AmbushAltar.PACK.size(), _fired.has(["fight", _altar.id])])
	_report("running shows its clock", prompt.keycap == "" and prompt.gauge > 0.9 and prompt.gauge < 1.0,
		"while it runs the prompt has no keycap and its gauge reads %.2f of the time left" % prompt.gauge)


func _clear_pack() -> void:
	for enemy in _altar.pack:
		if is_instance_valid(enemy):
			enemy.take_damage(100000.0)


func _check_paid() -> void:
	var paid: int = _game.run.bonus_cores - _cores_before
	_report("a clear in time pays a core", paid == 1 and _ended.size() == 1 and _ended[0] == [_altar.id, true] and _altar.spent,
		"pack cleared with %.1f s left: +%d core, ended %s, spent %s" % [_altar.left, paid, _ended, _altar.spent])


# The same altar again, fired directly, with its clock run down to the last tick.
func _rerun() -> void:
	_altar.spent = false
	_cores_before = _game.run.bonus_cores
	_ended.clear()
	_game.world.interact.fire(_altar)
	_altar.left = 0.01


func _run_out() -> void:
	pass


func _check_unpaid() -> void:
	var paid: int = _game.run.bonus_cores - _cores_before
	_report("a clock run out pays nothing", paid == 0 and _ended.size() == 1 and _ended[0] == [_altar.id, false],
		"clock ran out with %d of the pack standing: +%d core, ended %s" % [_altar.alive(), paid, _ended])
