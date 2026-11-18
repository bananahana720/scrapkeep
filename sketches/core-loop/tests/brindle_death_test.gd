extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const Requisition := preload("res://src/boss/requisition.gd")
const Arena := preload("res://src/boss/arena.gd")
const T := preload("res://tests/support/t.gd")

# A death to Brindle logs no script error (w28 cautious red team, edge 1). On the game's path (a run
# store on), the killing slag or charge hit ends the run inside run.damage and flow tears the arena
# and the ship down before the hit function goes on. Each case kills the ball through Brindle's own
# hit code, not calm, and reads RUN OVER and the error log.
#   slag:   _slag_hit (boss.gd), which went on to arena.radius_of
#   charge: _charge_hit, which went on to ship.hull
#   lane:   _run_charge running the committed lane into the ball, which went on to _charge["travelled"]
#   ring:   _step_hazards with both slag rings live, the ball in ring A: the loop went on to ring B and
#           put the torn-down hazards back on the list exit_arena had cleared
#   drone:  a slag kill with a dropped lobber standing in the bowl. The lobber is freed at the frame's
#           end, so it ticked once more that frame and read its ground from the bowl, which had left
#           the tree: three engine errors (w35 gate, world1_run_test, tally's lost run)

const DIR := "user://brindle_death_test/"
const PATH := DIR + "run.json"

var _t := T.new("brindle_death_test")
var _log := ErrorLog.new()


class ErrorLog:
	extends Logger
	var errors: Array[String] = []
	var engine: Array[String] = []

	func _log_error(_function: String, file: String, line: int, code: String,
			rationale: String, _editor_notify: bool, error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == Logger.ERROR_TYPE_SCRIPT:
			errors.append("%s:%d %s %s" % [file, line, code, rationale])
		elif error_type == Logger.ERROR_TYPE_ERROR:
			engine.append("%s:%d %s %s" % [file, line, code, rationale])


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	OS.add_logger(_log)
	_run.call_deferred()


func _run() -> void:
	for how in ["slag", "charge", "lane", "ring", "drone"]:
		await _die_to(how)
	DirAccess.remove_absolute(PATH)
	quit(_t.verdict())


func _die_to(how: String) -> void:
	var game := Game.new()
	game.test_mode = true
	game.run_store_path = PATH
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	await physics_frame
	game.player.source = Intent.Scripted.new()
	Harness.start_run(game)
	Harness.enter(game, Vector3(18.0, 0.0, 0.0))
	await physics_frame
	await physics_frame
	var boss = game.boss
	_t.check("%s: Brindle is up" % how, boss != null and boss.active())
	game.ctx.calm = false
	boss.phase = 2
	game.run.max_hp = 1000.0
	game.run.hp = 1.0
	_log.errors.clear()
	_log.engine.clear()
	var ball: Vector3 = game.player.ball_position()
	match how:
		"drone":
			boss._drop_drone(Harness.ground_spot(boss, 2.0, Arena.FLOOR_R * 0.5, 0.0))
			_t.eq("drone: a lobber stands in the bowl", boss._lobbers.size(), 1)
			var fake := Node.new()
			boss._slag_hit(fake, ball)
			fake.free()
		"slag", "charge":
			var fake := Node.new()
			if how == "slag":
				boss._slag_hit(fake, ball)
			else:
				boss._charge_hit(fake, ball)
			fake.free()
		"lane":
			boss._commit_charge()
			var lane: Dictionary = boss._charge
			var at: Vector3 = lane["from"] + lane["heading"] * Requisition.HULL.z * 0.5
			Harness.put_ball(game, Vector3(at.x, boss.arena.ground(at) + 1.0, at.z))
			boss._charge["state"] = "run"
			boss._run_charge(1.0 / 90.0, game.player.ball_position())
		"ring":
			var warn: float = maxf(boss._commit_slag(0, false), boss._commit_slag(1, false))
			var spot: Vector3 = Harness.ground_spot(boss, 0.0, (Arena.RING_A.x + Arena.RING_A.y) * 0.5, 0.5)
			boss._step_hazards(warn + 0.01, spot)
	await physics_frame
	await physics_frame
	_t.eq("%s: the run is over" % how, game.flow.state_name(), "summary")
	_t.check("%s: RUN OVER names Brindle" % how, game.flow.death_cause.begins_with("Scrapped by Brindle's"), game.flow.death_cause)
	_t.check("%s: no script error" % how, _log.errors.is_empty(), " | ".join(_log.errors))
	_t.check("%s: no engine error" % how, _log.engine.is_empty(), " | ".join(_log.engine))
	_t.check("%s: no hazard outlives the arena" % how, boss.hazards.is_empty(), "%d left" % boss.hazards.size())
	game.free()
	await physics_frame
