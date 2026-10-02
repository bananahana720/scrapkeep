extends SceneTree

const Game := preload("res://src/game.gd")
const Holds := preload("res://src/combat/holds.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")

# Tenacity bounds every chain (DESIGN-V2 section 10.3):
# 1. The clock. Two holds from two sources, back to back, are cut when their sum reaches
#    1.8 s inside 4 s; the ball is then immune for 2.5 s (a catch is refused and the
#    neutral bracket flickers), and holds again after. Holds 4 s apart never sum.
# 2. A tagged pack. The director's "grounded" pair, a mag trapper and a bola thrower,
#    against a ball at rest: the pit holds, the bola wraps the held ball, both are cut
#    by tenacity together, and nothing holds the ball through the immunity.

const TICK := 1.0 / 60.0

var _game
var _holds
var _failures := 0
var _step := 0
var _clock := 0.0
var _a: Node3D
var _b: Node3D
var _mark := 0.0
var _saw_bracket := false
var _bracket_colors: Array = []
var _kinds := {}
var _tenacity := 0
var _held_in_immunity := 0
var _cut: Array = []
var _pack: Array = []


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(check: String, ok: bool, detail: String) -> void:
	print("[%s] %s -> %s" % [check, detail, "PASS" if ok else "FAIL"])
	if not ok:
		_failures += 1


func _physics_process(delta: float) -> bool:
	if _game.flow == null:
		return false
	_clock += delta
	match _step:
		0:
			_setup()
			_holds.catch(_a, "test_a", ["jump"])
			_clock = 0.0
			_step = 1
		1:
			if _clock >= 1.0:
				_holds.release(_a, "expired")
				_holds.catch(_b, "test_b", ["jump"])
				_step = 2
		2:
			if _holds.tenacity_grants > 0:
				_report("clock cuts the chain", _clock >= 1.8 - 2.0 * TICK and _clock <= 1.8 + 3.0 * TICK and not _holds.holding()
						and _holds.last_release.get("reason", "") == "tenacity",
					"two sources summed to the cut at %.2f s; released by %s" % [_clock, _holds.last_release.get("reason", "")])
				_report("immune", _holds.immune() and absf(_holds.immune_left - Holds.TENACITY_IMMUNE) < 0.05 and not _holds.catch(_a, "test_a", ["jump"]),
					"immune for %.2f s and a new catch is refused" % _holds.immune_left)
				_mark = _clock
				_step = 3
			elif _clock > 3.0:
				_report("clock cuts the chain", false, "no tenacity after %.1f s of chained holds" % _clock)
				_step = 3
		3:
			_saw_bracket = _saw_bracket or _holds.get("_bracket").visible
			if _holds.get("_bracket").visible:
				_bracket_colors.append(_holds.get("_bracket_material").albedo_color)
			if _clock - _mark >= Holds.TENACITY_IMMUNE + 0.1:
				var caught: bool = _holds.catch(_a, "test_a", ["jump"])
				_report("bracket and recovery", _saw_bracket and caught and not _holds.get("_bracket").visible,
					"the bracket flickered through the immunity; a catch lands again after %.2f s" % (_clock - _mark))
				var off_neutral := _bracket_colors.filter(func(c: Color) -> bool: return not c.is_equal_approx(EventKinds.role_color("neutral")))
				_report("bracket is neutral ink", not _bracket_colors.is_empty() and off_neutral.is_empty(),
					"%d bracket frames, %d off neutral (first %s)" % [_bracket_colors.size(), off_neutral.size(), "" if off_neutral.is_empty() else (off_neutral[0] as Color).to_html(false)])
				_holds.release(_a, "expired")
				_step = 4
				_mark = _clock
		4:
			if _clock - _mark >= 4.2:
				_holds.catch(_b, "test_b", ["jump"])
				_mark = _clock
				_step = 5
		5:
			if _clock - _mark >= 1.2:
				var grants: int = _holds.tenacity_grants
				_report("window slides", grants == 1 and _holds.held(_b),
					"a 1.0 s hold and a 1.2 s hold 4 s apart never summed (grants %d, still held %s)" % [grants, _holds.held(_b)])
				_holds.release(_b, "expired")
				_start_pack()
				_step = 6
		6:
			if _tenacity > 0 and _holds.immune():
				if _holds.holding():
					_held_in_immunity += 1
			if _tenacity > 0 and not _holds.immune():
				_report("pack chain forms", _kinds.has("mag_pit") and _kinds.has("bola_wrap"),
					"the pack held the ball with %s" % [_kinds.keys()])
				_report("pack chain ends by tenacity", _cut.size() >= 2 and _held_in_immunity == 0,
					"tenacity cut %s together; %d held ticks inside the immunity" % [_cut, _held_in_immunity])
				return _finish()
			if _clock - _mark > 9.0:
				_report("pack chain ends by tenacity", false, "no tenacity in 9 s; held %s, cut %s" % [_kinds.keys(), _cut])
				return _finish()
	return false


func _setup() -> void:
	var ctx = _game.ctx
	ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.run.set_max_hp(99999.0)
	_holds = ctx.spawner.fleet.holds
	_a = Node3D.new()
	_b = Node3D.new()
	ctx.root.add_child(_a)
	ctx.root.add_child(_b)
	_game.events.hold_started.connect(func(kind: String, _at: Vector3): _kinds[kind] = true)
	_game.events.tenacity_gained.connect(func(_seconds: float): _tenacity += 1)
	_game.events.hold_ended.connect(func(kind: String, reason: String):
		if reason == "tenacity" and _step == 6:
			_cut.append(kind))


func _start_pack() -> void:
	var ctx = _game.ctx
	_holds.clear()
	_kinds.clear()
	_tenacity = 0
	var ball: Vector3 = ctx.terrain.drop_point(ctx.terrain.spawn_point(1).x, ctx.terrain.spawn_point(1).z, 1.05)
	_game.player.reset_to(ball)
	for spec in [["mag_trapper", Vector3(10.0, 0.0, 2.0)], ["bola_thrower", Vector3(-12.0, 0.0, 6.0)]]:
		var at: Vector3 = ball + spec[1]
		var unit: Node3D = ctx.spawner.spawn_enemy(spec[0], ctx.terrain.drop_point(at.x, at.z, 1.8))
		unit._rest = 0.3
		_pack.append(unit)
	_mark = _clock


func _finish() -> bool:
	var ok := _failures == 0
	print("enemy_tenacity_test: %s" % ("PASS" if ok else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if ok else 1)
	return true
