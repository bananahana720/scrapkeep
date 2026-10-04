extends SceneTree

const Game := preload("res://src/game.gd")
const MindHand := preload("res://src/combat/mind_hand.gd")
const Hazard := preload("res://src/boss/hazard.gd")
const Habits := preload("res://src/combat/habits.gd")

# The Mind hand's brace is a bounded counter (DESIGN-V2 section 10): the warn is at least
# Hazard.MIN_WARN and shorter than the brace it precedes; the lens opens once per commit,
# only when the brace goes live; a braced verb meets plating * BRACE_MULT, so it still
# deals 1/BRACE_MULT of its damage, never nothing; any other verb meets the plating; the
# habit is one verb, cleared when the brace ends. Two commits in one run.

# Pinned at 1.6, the as-built value. The plan named 1.4; which one ships is an open owner
# question, so a change here is a decision, not a tune.
const PINNED_BRACE_MULT := 1.6
const COMMITS := 2

var _game
var _fleet
var _failures := 0
var _step := 0
var _clock := 0.0
var _hand: Node3D
var _opened: Array = []
var _commits_seen := 0


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
			_constants()
			_setup()
			_feed(6)
			_hand = _spawn_hand()
			_step = 1
			_clock = 0.0
		1:
			if _hand.phase == MindHand.Phase.WARN:
				_commits_seen += 1
				var n := _commits_seen
				_report("commit %d: the lens stays shut through the warn" % n, _opened.size() == n - 1 and not _hand.braced()
						and _hand.weak_points().is_empty(),
					"weak_point_opened %d times before go-live, braced %s" % [_opened.size(), _hand.braced()])
				_report("commit %d: the habit is one verb" % n, typeof(_hand.habit) == TYPE_STRING and _hand.habit == "ram"
						and Habits.BRACES.has(_hand.habit) and _hand.braced_kinds == Habits.BRACES["ram"]["kinds"],
					"habit %s (%s), braced kinds %s" % [_hand.habit, type_string(typeof(_hand.habit)), _hand.braced_kinds])
				_step = 2
				_clock = 0.0
			elif _clock > 8.0:
				_report("commit %d" % (_commits_seen + 1), false, "the hand never warned in 8 s")
				return _finish()
		2:
			if _hand.braced():
				_braced()
				_step = 3
				_clock = 0.0
			elif _clock > 4.0:
				_report("commit %d: brace" % _commits_seen, false, "the hand never braced")
				return _finish()
		3:
			if not _hand.braced():
				var n := _commits_seen
				_report("commit %d: the brace ends and clears the habit" % n, absf(_clock - MindHand.BRACE) < 0.1 and _hand.habit == ""
						and _hand.braced_kinds.is_empty() and _hand.plating_for("ram", "") == _hand.plating
						and _hand.plating_for("runner", "lens") == _hand.plating and _hand.weak_points().is_empty(),
					"brace lasted %.2f s; habit '%s', braced kinds %s, ram meets %.1f of %.1f" % [_clock, _hand.habit,
						_hand.braced_kinds, _hand.plating_for("ram", ""), _hand.plating])
				_report("commit %d: one lens opening for the commit" % n, _opened.size() == n,
					"weak_point_opened %d times after %d commits" % [_opened.size(), n])
				if n >= COMMITS:
					return _finish()
				_feed(6)
				_hand._rest = 0.2
				_step = 1
				_clock = 0.0
			elif _clock > MindHand.BRACE + 2.0:
				_report("commit %d: brace ends" % _commits_seen, false, "still braced after %.1f s" % _clock)
				return _finish()
	return false


func _constants() -> void:
	_report("the warn is readable", MindHand.WARN >= Hazard.MIN_WARN, "WARN %.2f s, MIN_WARN %.2f s" % [MindHand.WARN, Hazard.MIN_WARN])
	_report("the warn precedes a longer brace", MindHand.WARN < MindHand.BRACE, "WARN %.2f s, BRACE %.2f s" % [MindHand.WARN, MindHand.BRACE])
	_report("BRACE_MULT pinned", is_equal_approx(MindHand.BRACE_MULT, PINNED_BRACE_MULT) and MindHand.BRACE_MULT > 1.0,
		"BRACE_MULT %.2f (pinned %.2f; the plan's 1.4 is an open owner question)" % [MindHand.BRACE_MULT, PINNED_BRACE_MULT])


func _braced() -> void:
	var n := _commits_seen
	var opening: Array = _opened.back() if not _opened.is_empty() else []
	_report("commit %d: the lens opens at go-live" % n, _opened.size() == n and opening[0] == "lens"
			and opening[1] == MindHand.Phase.LIVE and is_equal_approx(opening[2], MindHand.BRACE)
			and absf(_hand.last_warn - MindHand.WARN) < 0.05,
		"weak_point_opened %s after a %.2f s warn" % [_opened, _hand.last_warn])
	var plating: float = _hand.plating
	var ram: float = _hand.plating_for("ram", "")
	var shot: float = _hand.plating_for("runner", "")
	var ratio := plating / ram if ram > 0.0 else 0.0
	_report("commit %d: a braced verb is slowed, not stopped" % n, plating > 0.0 and is_equal_approx(ram, plating * MindHand.BRACE_MULT)
			and ratio > 0.0 and is_equal_approx(ratio, 1.0 / MindHand.BRACE_MULT),
		"plating %.1f, braced ram meets %.1f, damage ratio %.3f (1/BRACE_MULT %.3f)" % [plating, ram, ratio, 1.0 / MindHand.BRACE_MULT])
	_report("commit %d: an unbraced verb meets the plating" % n, shot == plating and _hand.plating_for("runner", "lens") == 0.0,
		"a shot meets %.1f, the open lens %.1f" % [shot, _hand.plating_for("runner", "lens")])


func _setup() -> void:
	var ctx = _game.ctx
	ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.run.set_max_hp(99999.0)
	_fleet = ctx.spawner.fleet
	_game.events.weak_point_opened.connect(func(id: String, _at: Vector3, seconds: float):
		_opened.append([id, _hand.phase if is_instance_valid(_hand) else -1, seconds]))


func _spawn_hand() -> Node3D:
	var ctx = _game.ctx
	var ball: Vector3 = ctx.terrain.drop_point(ctx.terrain.spawn_point(1).x, ctx.terrain.spawn_point(1).z, 1.05)
	_game.player.reset_to(ball)
	var at: Vector3 = ball + Vector3(11.0, 0.0, 4.0)
	var hand: Node3D = ctx.spawner.spawn_enemy("mind_hand", ctx.terrain.drop_point(at.x, at.z, 1.9))
	hand._rest = 0.3
	return hand


# The bus facts play publishes when the player rams.
func _feed(times: int) -> void:
	for i in times:
		_game.events.enemy_struck.emit(null, "ram", 20.0)


func _finish() -> bool:
	var ok := _failures == 0 and _commits_seen >= COMMITS
	print("warden_mind_brace_test: %s" % ("PASS" if ok else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if ok else 1)
	return true
