extends Node

# --self-play (src/game.gd): a bot plays the launched game with real ticks, as a player's
# game runs (no SimClock), so `npm run sketch:frametime -- --self-play` can log a stage swap
# or a stage exit unattended (SWAP-HITCH-6, STAGE6-GATE). Only packs that carry tools/ have
# it: `npm run sketch:export -- --self-play`. Seconds are since launch.
#
# Flags (after `--`):
#   --self-play-seed=<n>      run seed (default 1)
#   --self-play-pilot=<id>    class id, e.g. pylon_engineer
#   --self-play-policy=<p>    a BotDriver policy: skipper (default), completionist, random,
#                             camper, traversal, brawler
#   --self-play-from=<stage>  enter that stage directly (tools/bot_run.gd --from-stage)
#   --self-play-until=<what>  <n>: stop once stage n is entered (default 2); exit<n>: once
#                             stage n's exit is taken; win: once the run is won
#   --self-play-hold=<s>      keep playing this long after the goal (default 30)
#   --self-play-min=<s>       and until this many seconds since launch (default 0)
#   --self-play-stall=<s>     seconds the exit may stay untaken after the fight ends (default 120)
#   --self-play-beat=<s>      print a "self-play: beat" progress line every s seconds (default off)
#
# Lines: "self-play: stage <n> entered at <s> s" (one per stage entered, retries marked),
# "self-play: stage <n> exit taken at <s> s", "self-play: done at <s> s".
# Quit codes: 0 goal reached, 1 the run ended first, 2 bad flag or no tools/ in the pack
# (game.gd), 3 stalled (1 and 3 wait for --self-play-min first, so a frame log stays whole): "self-play: stalled at stage <n> exit at <s> s pos <x,y,z>".

const BotDriver := preload("res://tools/bot_driver.gd")

var game: Node
var _driver
var _goal_at := -1.0
var _hold := 30.0
var _min := 0.0
var _seed := 1
var _pilot := ""
var _policy := "skipper"
var _from := 0
var _until := "2"
var _stall := 120.0
var _fight_end := -1.0
var _stage := 0
var _beat := 0.0
var _beat_at := 0.0
var _quit_code := -1


func _ready() -> void:
	# Run before Game each tick, as bot_run does, so the bot's intent is read the same tick.
	process_physics_priority = -1
	# A reward ceremony or the pause menu pauses the tree; the bot must keep answering them.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--self-play-hold="):
			_hold = float(arg.trim_prefix("--self-play-hold="))
		elif arg.begins_with("--self-play-min="):
			_min = float(arg.trim_prefix("--self-play-min="))
		elif arg.begins_with("--self-play-seed="):
			_seed = int(arg.trim_prefix("--self-play-seed="))
		elif arg.begins_with("--self-play-pilot="):
			_pilot = arg.trim_prefix("--self-play-pilot=")
		elif arg.begins_with("--self-play-policy="):
			_policy = arg.trim_prefix("--self-play-policy=")
		elif arg.begins_with("--self-play-from="):
			_from = int(arg.trim_prefix("--self-play-from="))
		elif arg.begins_with("--self-play-until="):
			_until = arg.trim_prefix("--self-play-until=")
		elif arg.begins_with("--self-play-stall="):
			_stall = float(arg.trim_prefix("--self-play-stall="))
		elif arg.begins_with("--self-play-beat="):
			_beat = float(arg.trim_prefix("--self-play-beat="))
	if not (_policy in BotDriver.POLICIES or _policy in BotDriver.PROFILES):
		push_error("self-play: unknown policy '%s'" % _policy)
		get_tree().quit.call_deferred(2)
	if _until != "win" and not (_until.is_valid_int() or (_until.begins_with("exit") and _until.trim_prefix("exit").is_valid_int())):
		push_error("self-play: --self-play-until wants <stage>, exit<stage> or win, got '%s'" % _until)
		get_tree().quit.call_deferred(2)


func _physics_process(delta: float) -> void:
	if game.flow == null:
		return
	if _driver == null:
		# The played game builds stage 1's ground behind the menu (ground_behind_menu); start the
		# run once it is built, as a player pressing start after the menu settles.
		if not game.ctx.terrain.is_ready(1):
			return
		_start()
		return
	if _quit_code >= 0:
		# A failed run idles until --self-play-min so a frame log that needs its full length is whole.
		if _now() >= _min:
			get_tree().quit(_quit_code)
		return
	_answer_workshop()
	var state: String = game.flow.state_name()
	if _beat > 0.0 and _now() - _beat_at >= _beat:
		_beat_at = _now()
		var b: Vector3 = game.player.ball_position()
		print("self-play: beat %.1f s stage %d %s%s stage_time %.1f pos %.0f,%.0f,%.0f" % [_now(), game.run.stage, state, " PAUSED" if get_tree().paused else "", game.run.stage_time, b.x, b.y, b.z])
	var over: bool = _driver.tick(delta)
	if over:
		_finish()
		return
	if _fight_end < 0.0 and state == "gates":
		_fight_end = _now()
	if _fight_end >= 0.0 and _goal_at < 0.0 and _now() - _fight_end > _stall:
		_stalled("exit")
		return
	if _goal_at >= 0.0 and _now() >= maxf(_goal_at + _hold, _min):
		print("self-play: done at %.2f s" % _now())
		get_tree().quit(0)


# A pick the offer signal did not settle (the workshop reopened it) is taken by its first card, so
# the paused tree never waits on a player.
func _answer_workshop() -> void:
	var workshop: Node = game.get_node_or_null("Workshop")
	if workshop != null and workshop.get("pick") != null and workshop.pick.is_open():
		workshop.choose(0)


# Print the verdict now, quit with its code once --self-play-min has passed.
func _end_run(code: int) -> void:
	_quit_code = code


func _start() -> void:
	_driver = BotDriver.new(game, _policy, _seed)
	if _pilot != "":
		_driver.class_index = BotDriver.class_index_for(_seed, _pilot)
	game.run.run_seed_override = _seed
	# The played game's workshop pauses the tree on an upgrade pick (bot_run's test_mode game has no
	# workshop); the driver answers each offer as it arrives, with a seeded random pick.
	_driver.tree_policy = "random"
	game.events.stage_entered.connect(_on_stage_entered)
	game.events.stage_cleared.connect(_on_stage_cleared)
	_driver.start(false)
	# As bot_run does: the stage is entered over the one the start pick opened.
	if _from > 1:
		game.flow.enter_stage(_from, Vector3.ZERO, false)
	print("self-play: %s seed %d until %s started at %.2f s" % [_policy, _seed, _until, _now()])


# The driver ended the run. A stall is the driver's own limit; won ends a "win" goal.
func _finish() -> void:
	var outcome: String = _driver.outcome
	if _goal_at >= 0.0:
		print("self-play: done at %.2f s" % _now())
		get_tree().quit(0)
	elif outcome == "won" and _until == "win":
		print("self-play: run won at %.2f s" % _now())
		get_tree().quit(0)
	elif outcome == "stalled" or outcome == "boss_stalled" or outcome == "fight_capped":
		_stalled("exit" if _fight_end >= 0.0 else outcome)
	else:
		print("self-play: run ended '%s' at stage %d before the goal at %.2f s" % [outcome, game.run.stage, _now()])
		_end_run(1)


func _stalled(what: String) -> void:
	var p: Vector3 = game.player.ball_position()
	print("self-play: stalled at stage %d %s at %.2f s pos %.1f,%.1f,%.1f" % [game.run.stage, what, _now(), p.x, p.y, p.z])
	_end_run(3)


func _on_stage_entered(stage: int, retry := false) -> void:
	_stage = stage
	_fight_end = -1.0
	print("self-play: stage %d entered%s at %.2f s" % [stage, " (retry)" if retry else "", _now()])
	if _until.is_valid_int() and stage >= int(_until) and _goal_at < 0.0 and not retry:
		_goal_at = _now()


func _on_stage_cleared(stage: int) -> void:
	print("self-play: stage %d exit taken at %.2f s" % [stage, _now()])
	if _until == "exit%d" % stage and _goal_at < 0.0:
		_goal_at = _now()


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
