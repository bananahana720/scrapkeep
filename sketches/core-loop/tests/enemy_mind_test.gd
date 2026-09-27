extends SceneTree

const Game := preload("res://src/game.gd")

# The Mind's hands adapt within a run, bounded and telegraphed (DESIGN-V2 sections 10
# and 15, STORY-THREADS T5):
# - with ram the habit used most, a hand's first act is the quote: mind_adapted("ram")
#   on the frame its strike lane commits, the lane voiced as the class motif played
#   back (mind_sable for Sable), and nothing braced yet;
# - after the warning it braces: a ram meets 1.6 times its plating, a shot meets the
#   plating, and its lens is an open weak point at plating 0; the brace ends;
# - switch verbs and the next adaptation reads the new habit, in the same run;
# - a new run forgets it all: no habit, no memory, and a fresh hand stays still.

var _game
var _fleet
var _failures := 0
var _step := 0
var _clock := 0.0
var _hand: Node3D
var _adapted: Array = []
var _commit_frame := -1
var _lane_with_quote := false


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
			_feed("ram", 6)
			_hand = _spawn_hand()
			_step = 1
		1:
			if _hand.telegraph() != null and _commit_frame < 0:
				_commit_frame = Engine.get_physics_frames()
				var lane: Node3D = _hand.telegraph()
				_report("the quote is the telegraph", _adapted.size() == 1 and _adapted[0] == "ram" and _lane_with_quote
						and lane.owner_voice == "mind_sable" and not _hand.braced(),
					"mind_adapted %s with its strike lane already committed %s; lane voice %s; braced %s"
						% [_adapted, _lane_with_quote, lane.owner_voice, _hand.braced()])
			if _hand.braced():
				var ram: float = _hand.plating_for("ram", "")
				var shot: float = _hand.plating_for("runner", "")
				var lens: float = _hand.plating_for("runner", "lens")
				var open: bool = not _hand.weak_points().is_empty()
				_report("brace", ram > shot and absf(ram - shot * 1.6) < 0.01 and lens == 0.0 and open,
					"braced against ram: ram meets %.0f, a shot %.0f, the open lens %.0f" % [ram, shot, lens])
				_step = 2
				_clock = 0.0
			elif _clock > 8.0:
				_report("brace", false, "the hand never braced (warned %d)" % _hand.warned)
				return _finish()
		2:
			if not _hand.braced():
				_report("brace ends", absf(_clock - _hand.BRACE) < 0.1 and _hand.plating_for("ram", "") == _hand.plating
						and _hand.weak_points().is_empty(),
					"the brace lasted %.2f s, then ram meets the plating again" % _clock)
				_feed("weapon", 30)
				_hand._rest = 0.2
				_step = 3
				_clock = 0.0
		3:
			if _adapted.size() >= 2:
				_report("adapts within the run", _adapted[1] == "weapon" and _fleet.mind_memory.size() == 2,
					"second read %s; memory %s" % [_adapted[1], _fleet.mind_memory])
				_hand.queue_free()
				_game.flow.new_run()
				_report("resets per run", _fleet.habits.top() == "" and _fleet.mind_memory.is_empty(),
					"after a new run: top habit '%s', memory %s" % [_fleet.habits.top(), _fleet.mind_memory])
				_game.ctx.calm = true
				_hand = _spawn_hand()
				_step = 4
				_clock = 0.0
			elif _clock > 8.0:
				_report("adapts within the run", false, "no second adaptation in 8 s: %s" % [_adapted])
				return _finish()
		4:
			if _clock >= 3.0:
				_report("no memory across runs", _hand.warned == 0 and _adapted.size() == 2,
					"a fresh hand in the new run acted %d times with nothing learned" % _hand.warned)
				return _finish()
	return false


func _setup() -> void:
	var ctx = _game.ctx
	ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.run.set_max_hp(99999.0)
	_fleet = ctx.spawner.fleet
	_game.events.mind_adapted.connect(func(habit: String, _icon: String):
		_adapted.append(habit)
		_lane_with_quote = _hand != null and is_instance_valid(_hand) and _hand.telegraph() != null)


func _spawn_hand() -> Node3D:
	var ctx = _game.ctx
	var ball: Vector3 = ctx.terrain.drop_point(ctx.terrain.spawn_point(1).x, ctx.terrain.spawn_point(1).z, 1.05)
	_game.player.reset_to(ball)
	_game.run.set_max_hp(99999.0)
	var at: Vector3 = ball + Vector3(11.0, 0.0, 4.0)
	var hand: Node3D = ctx.spawner.spawn_enemy("mind_hand", ctx.terrain.drop_point(at.x, at.z, 1.9))
	hand._rest = 0.3
	return hand


# The bus facts play publishes when the player uses a verb.
func _feed(habit: String, times: int) -> void:
	for i in times:
		match habit:
			"ram":
				_game.events.enemy_struck.emit(null, "ram", 20.0)
			"weapon":
				_game.events.enemy_struck.emit(null, "runner", 10.0)


func _finish() -> bool:
	var ok := _failures == 0
	print("enemy_mind_test: %s" % ("PASS" if ok else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if ok else 1)
	return true
