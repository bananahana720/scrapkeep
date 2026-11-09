# smoke: solo timeout=330s (one isolated fixed-90-fps skipper child jumped to stage 6; 300 s wall budget: the cap
# catches a hang, not a slow box. The child ran 96-116 s on the w31 and w32 gate boxes and 164-188 s on w30's, where
# the old 180 s budget killed it after its checks had passed)
extends SceneTree

const Game := preload("res://src/game.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const ChildRuns := preload("res://tests/trees/child_runs.gd")
const SimClock := preload("res://src/core/sim_clock.gd")
const T := preload("res://tests/support/t.gd")

# The crown stall: a skipper jumped to stage 6 (Highdraft: the crown, the choir mind Warden on
# the beacon island) must break the Warden within BUDGET_SECONDS of game time. The crown's
# islands dogleg through the middle island, so the straight line from spawn to the Warden
# leaves the spawn island for the net deck and meets the beacon's cliff, away from the shoulder
# ramps beside the mid-to-beacon bridge. Seed 1 pressed that cliff until the watchdog; the
# bot's fight climb route (bot_driver.gd _fight_way_up) is its way up. Without it it fails.
#
# Evidence limit: one seed and one class on the default table; it says nothing about the
# other pilots, the completionist, or feel.

const SEED := 1
const JUMP_STAGE := 6
const BUDGET_SECONDS := 200.0
const WALL_BUDGET := 300.0

var _t := T.new("crown_warden_bot_test")
var _child := false
var _game
var _driver
var _seconds := 0.0
var _done := false
var _scrap_serial := 0
var _counter_serial := 0


func _initialize() -> void:
	_child = "--child" in OS.get_cmdline_user_args()
	if not _child:
		var results := ChildRuns.run([{"script": "res://tests/crown_warden_bot_test.gd", "args": ["--child"]}], WALL_BUDGET)
		var result: Dictionary = results[0]
		print(result["log"])
		_t.check("isolated child", result["code"] == 0 and not result["timed_out"]
			and ChildRuns.summary(result)["errors"].is_empty())
		_done = true
		quit(_t.verdict())
		return
	SimClock.ticks = true
	node_added.connect(_on_node_added)
	seed(SEED)
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(delta: float) -> bool:
	if _done or _game == null or _game.flow == null:
		return false
	if _driver == null:
		_driver = BotDriver.new(_game, "skipper", SEED)
		_game.presentation.audio.bake_now()
		_driver.start()
		_game.flow.enter_stage(JUMP_STAGE, Vector3.ZERO, false)
		return false
	_seconds += delta
	var over: bool = _driver.tick(delta)
	if over or _driver.warden_broken() or _seconds >= BUDGET_SECONDS:
		_finish()
	return false


# The spawn-order signs tools/bot_run.gd sets, so the bot's strafe and scrap sides do not
# hang on object IDs and the run repeats.
func _on_node_added(node: Node) -> void:
	if _game == null or _game.build == null:
		return
	if "_strafe" in node:
		node.set_meta("bot_strafe", 1.0 if (_counter_serial + SEED) % 2 == 0 else -1.0)
		_counter_serial += 1
	if node.get_parent() == _game.build.scrap:
		node.set_meta("bot_side", 1.0 if (_scrap_serial + SEED) % 2 == 0 else -1.0)
		_scrap_serial += 1


func _finish() -> void:
	_done = true
	var ball: Vector3 = _game.player.ball_position()
	_t.eq("stage", _game.run.stage, JUMP_STAGE)
	_t.check("Warden broken within %d s" % int(BUDGET_SECONDS), _driver.warden_broken(),
		"%.1f s, bot outcome '%s', goal '%s', ball (%.0f, %.0f, %.0f)"
		% [_seconds, _driver.outcome, _driver._goal, ball.x, ball.y, ball.z])
	_game.free()
	quit(_t.verdict())
