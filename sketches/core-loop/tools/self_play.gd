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
#   --self-play-plant-stall   TEST PLANT: freeze the bot after its first tick and count the fight as
#                             ended then, so the stall detector fires after --self-play-stall
#   --self-play-plant-end     TEST PLANT: end the run at once (outcome planted_end), so it quits 1
#   --self-play-plant-limit=<s>  TEST PLANT: give the driver this stage limit (sim seconds), so its
#                             own stall limit ends the run (the driver-limit branch)
#   --self-play-beat=<s>      print a "self-play: beat" progress line every s seconds (default off)
#   --self-play-watch=1       watch the run as a player would meet it (tools/qa_watch.gd, reads only): where the
#                             ball sat stuck, hung off the ground, wedged or fell through, each objective plate
#                             change, the longest stretch of play with an empty plate, and the boss fight's
#                             start and end. Rows go to qa.ndjson in the run's own save folder; the totals print
#                             on one "self-play: watch" line as the run ends. Absent, the run is unchanged.
#
# Lines: "self-play: stage <n> entered at <s> s" (one per stage entered, retries marked),
# "self-play: stage <n> exit taken at <s> s", "self-play: done at <s> s". With --self-play-watch=1 also
# "self-play: boss arena entered at <s> s", "self-play: boss defeated at <s> s" and
# "self-play: watch stuck=<n> hung=<n> wedged=<n> fell=<n> objectives=<n> blank_max=<s> stages=<list>".
# Quit codes: 0 goal reached, 1 the run ended first, 2 bad flag or no tools/ in the pack
# (game.gd), 3 stalled (every code waits for --self-play-min first, so a frame log stays whole): "self-play: stalled at stage <n> exit at <s> s pos <x,y,z>".

const BotDriver := preload("res://tools/bot_driver.gd")
const QaWatch := preload("res://tools/qa_watch.gd")

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
var _plant_stall := false
var _plant_end := false
var _plant_limit := 0.0
var _watch_on := false
var _watch
var _read_at := 0.0
var _blank := 0.0
var _blank_max := 0.0
var _plates := 0
var _plate := ""
var _stages: Array[int] = []
var _watch_told := false


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
		elif arg.begins_with("--self-play-script="):
			pass  # test override, read by src/game.gd; named here so the launch-flag lint finds its parser
		elif arg == "--self-play-plant-end":
			_plant_end = true
		elif arg == "--self-play-plant-stall":
			_plant_stall = true
		elif arg.begins_with("--self-play-plant-limit="):
			_plant_limit = float(arg.trim_prefix("--self-play-plant-limit="))
		elif arg.begins_with("--self-play-beat="):
			_beat = float(arg.trim_prefix("--self-play-beat="))
		elif arg.begins_with("--self-play-watch="):
			_watch_on = arg.trim_prefix("--self-play-watch=") == "1"
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
		# Every ending idles until --self-play-min so a frame log that needs its full length is whole.
		if _now() >= _min:
			get_tree().quit(_quit_code)
		return
	_answer_workshop()
	var state: String = game.flow.state_name()
	if _beat > 0.0 and _now() - _beat_at >= _beat:
		_beat_at = _now()
		var b: Vector3 = game.player.ball_position()
		print("self-play: beat %.1f s stage %d %s%s stage_time %.1f pos %.0f,%.0f,%.0f" % [_now(), game.run.stage, state, " PAUSED" if get_tree().paused else "", game.run.stage_time, b.x, b.y, b.z])
	if _plant_stall:
		# Planted stall: the bot stands still and the fight counts as over from now.
		_driver.source.hold = {}
		if _fight_end < 0.0:
			_fight_end = _now()
		if _now() - _fight_end > _stall:
			_stalled("exit")
		return
	var over: bool = _driver.tick(delta)
	if _watch != null and not get_tree().paused:
		_watch_step(delta)
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
		_end_run(0)


# A pick the offer signal did not settle (the workshop reopened it) is taken by its first card, so
# the paused tree never waits on a player.
func _answer_workshop() -> void:
	var workshop: Node = game.get_node_or_null("Workshop")
	if workshop != null and workshop.get("pick") != null and workshop.pick.is_open():
		workshop.choose(0)


# Print the verdict now, quit with its code once --self-play-min has passed.
func _end_run(code: int) -> void:
	_tell_watch()
	_quit_code = code


# The watch's ball checks every tick; once a second its plate read, and how long play has gone on
# with nothing on the objective plate (to the second).
func _watch_step(delta: float) -> void:
	_watch.step(delta)
	if _now() - _read_at < 1.0:
		return
	var since := _now() - _read_at
	_read_at = _now()
	if not game.flow.in_play() or game.hud == null:
		_blank = 0.0
		return
	_watch.read_text()
	var reading: Dictionary = game.hud.objective_reading()
	_blank = _blank + since if String(reading.get("words", "")).strip_edges() == "" else 0.0
	_blank_max = maxf(_blank_max, _blank)
	var id := String(reading.get("id", ""))
	if id != _plate:
		_plate = id
		_plates += 1


func _tell_watch() -> void:
	if _watch == null or _watch_told:
		return
	_watch_told = true
	var c: Dictionary = _watch.counts
	print("self-play: watch stuck=%d hung=%d wedged=%d fell=%d objectives=%d blank_max=%.1f stages=%s" % [int(c.get("stuck", 0)),
		int(c.get("hung", 0)), int(c.get("wedged", 0)), int(c.get("fell", 0)), _plates, _blank_max, ",".join(_stages.map(func(n): return str(n)))])


func _start() -> void:
	_driver = BotDriver.new(game, _policy, _seed)
	if _pilot != "":
		_driver.class_index = BotDriver.class_index_for(_seed, _pilot)
	game.run.run_seed_override = _seed
	# The played game's workshop pauses the tree on an upgrade pick (bot_run's test_mode game has no
	# workshop); the driver answers each offer as it arrives, with a seeded random pick.
	_driver.tree_policy = "random"
	if _plant_limit > 0.0:
		_driver.stage_limit = _plant_limit
	if _plant_end:
		_driver._end("planted_end")
	game.events.stage_entered.connect(_on_stage_entered)
	game.events.stage_cleared.connect(_on_stage_cleared)
	if _watch_on:
		_watch = QaWatch.new()
		_watch.setup(game, _driver, String(game.storage_dir).path_join("qa.ndjson"))
		game.events.boss_arena_entered.connect(func(): print("self-play: boss arena entered at %.2f s" % _now()))
		game.events.boss_defeated.connect(func(): print("self-play: boss defeated at %.2f s" % _now()))
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
		_end_run(0)
	elif outcome == "won" and _until == "win":
		print("self-play: run won at %.2f s" % _now())
		_end_run(0)
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
	if not retry:
		_stages.append(stage)
	print("self-play: stage %d entered%s at %.2f s" % [stage, " (retry)" if retry else "", _now()])
	if _until.is_valid_int() and stage >= int(_until) and _goal_at < 0.0 and not retry:
		_goal_at = _now()


func _on_stage_cleared(stage: int) -> void:
	print("self-play: stage %d exit taken at %.2f s" % [stage, _now()])
	if _until == "exit%d" % stage and _goal_at < 0.0:
		_goal_at = _now()


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
