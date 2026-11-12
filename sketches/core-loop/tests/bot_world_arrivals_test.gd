# smoke: bots timeout=1500s (eight bot children at once, the four Dig and Highdraft parks x two seeds, one stage each up to the driver's 240 s limit)
extends SceneTree

const Game := preload("res://src/game.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const ChildRuns := preload("res://tests/trees/child_runs.gd")
const SimClock := preload("res://src/core/sim_clock.gd")
const T := preload("res://tests/support/t.gd")

# The world-native events under real bot play on the park table (design-v3/WORLD-ROSTERS.md).
# Each child jumps a completionist bot to one Dig or Highdraft stage and plays it to its exit
# or the driver's stage limit, logging what the events did:
# - the stage's arrival (the Dig's lift cage, the Highdraft's zipline drop) announced, landed,
#   and was answered (cage slammed down, line cut);
# - Dig stages: cave-ins over surfacing burrowers, and how many hit the ball; and a prop
#   crew dropped next to the first pack the director sends, to see whether a bot's own rams
#   bring its roof down on the pack;
# - every event's ball contact never set the ball's speed to zero (events never stop it).
# The parent checks the facts every child must show; the rest is printed for the read.
#
# Evidence limit: two seeds, one pilot, one policy per park, on the cloud's headless build.
# It says nothing about feel, Andrew's read of the cage or the zipline, or the GPU budget.

const STAGES := [3, 4, 5, 6]
const SEEDS := [1, 2]
const WALL_BUDGET := 1440.0
const PROP_AT_S := 15.0

var _t := T.new("bot_world_arrivals_test")
var _child := false
var _game
var _driver
var _stage := 0
var _seed := 0
var _seconds := 0.0
var _done := false
var _scrap_serial := 0
var _counter_serial := 0
var _facts := {"announced": [], "started": [], "forms": [], "prop_drops": 0}
var _prop
var _prop_placed := false
var _arrival_id := ""


func _initialize() -> void:
	_child = "--child" in OS.get_cmdline_user_args()
	if not _child:
		_parent()
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--stage="):
			_stage = int(arg.split("=")[1])
		elif arg.begins_with("--seed="):
			_seed = int(arg.split("=")[1])
	SimClock.ticks = true
	node_added.connect(_on_node_added)
	seed(_seed)
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _parent() -> void:
	var jobs := []
	for stage in STAGES:
		for seed_value in SEEDS:
			jobs.append({"script": "res://tests/bot_world_arrivals_test.gd",
				"args": ["--child", "--table=park", "--stage=%d" % stage, "--seed=%d" % seed_value]})
	var results := ChildRuns.run(jobs, WALL_BUDGET)
	var by_kind := {"lift_cage": {"announced": 0, "landed": 0}, "zipline_drop": {"announced": 0, "landed": 0}}
	var caves := 0
	var drops := 0
	for i in results.size():
		var result: Dictionary = results[i]
		var summary := ChildRuns.summary(result)
		var line := ""
		for text in String(result["log"]).split("\n"):
			if text.begins_with("ARRIVALS "):
				line = text.substr(9)
		var job: Array = jobs[i]["args"]
		var label := "%s %s" % [job[2], job[3]]
		_t.check("%s ran clean" % label, result["code"] == 0 and not result["timed_out"] and summary["errors"].is_empty(),
			"code %d, timed out %s, errors %s" % [result["code"], result["timed_out"], summary["errors"].slice(0, 3)])
		var data = JSON.parse_string(line) if line != "" else null
		if not data is Dictionary:
			_t.check("%s reported" % label, false, "no ARRIVALS line")
			continue
		print("%s: %s" % [label, line])
		var kind: String = data.arrival_kind
		_t.check("%s carries its world's arrival" % label, kind == ("lift_cage" if int(data.stage) <= 4 else "zipline_drop"), kind)
		if by_kind.has(kind):
			by_kind[kind].announced += int(data.arrival_announced)
			by_kind[kind].landed += int(data.arrival_landed)
		_t.check("%s never publishes the Spillway's landing form" % label, not (data.forms as Array).has("fleet_inbound"), str(data.forms))
		_t.eq("%s: no event stopped the ball" % label, int(data.ball_stops), 0)
		if int(data.stage) <= 4:
			caves += int(data.cave_ins)
			drops += int(data.prop_drops)
	for kind in by_kind:
		_t.check("%s announced in some bot stage" % kind, by_kind[kind].announced > 0, str(by_kind[kind]))
		_t.check("%s landed in some bot stage" % kind, by_kind[kind].landed > 0, str(by_kind[kind]))
	_t.check("burrowers caved the roof in under bot play", caves > 0, "%d cave-ins" % caves)
	print("prop crew roofs dropped by bot play: %d" % drops)
	_done = true
	quit(_t.verdict())


func _physics_process(delta: float) -> bool:
	if _done or _game == null or _game.flow == null:
		return false
	if _driver == null:
		_driver = BotDriver.new(_game, "completionist", _seed)
		_game.presentation.audio.bake_now()
		_driver.start()
		_game.flow.enter_stage(_stage, Vector3.ZERO, false)
		_game.events.event_announced.connect(func(id, _lead, _at): _facts.announced.append(String(id)))
		_game.events.event_started.connect(func(id): _facts.started.append(String(id)))
		_game.events.world_fact.connect(func(kind, _at): if not _facts.forms.has(String(kind)): _facts.forms.append(String(kind)))
		return false
	if _arrival_id == "" and _game.ctx.terrain.map() != null and "park" in _game.ctx.terrain.map():
		for row in _game.ctx.terrain.map().park.get("event_rows", []):
			if row.family == "fleet":
				_arrival_id = row.id
				_facts["arrival_kind"] = row.kind
	_seconds += delta
	_watch_ball()
	if _stage <= 4 and not _prop_placed and _seconds >= PROP_AT_S:
		_place_prop()
	var over: bool = _driver.tick(delta)
	if over or _game.flow.state_name() == "launch" or _game.run.stage > _stage or _seconds > BotDriver.STAGE_LIMIT + 5.0:
		_finish()
	return false


var _last_speed := 0.0
var _ball_stops := 0


# An event that set the ball dead still would show as a moving ball at zero the next tick
# while an event's hazard or arrival was live. The bot never parks, so any such tick counts.
func _watch_ball() -> void:
	var speed: float = _game.player.state.velocity.length()
	var fleet = _fleet()
	var live: bool = fleet != null and fleet.cave_ins != null and fleet.cave_ins._live.any(func(f): return is_instance_valid(f) and f.committed() and f.hazard.is_live())
	if live and _last_speed > 6.0 and speed < 0.05:
		_ball_stops += 1
	_last_speed = speed


func _fleet():
	var families = _game.world.get("event_families") if _game.world != null else null
	return families.get("fleet") if families is Dictionary else null


# A prop crew beside the first living enemy at least 30 m from the ball.
func _place_prop() -> void:
	var ball: Vector3 = _game.player.ball_position()
	for enemy in get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy) or String(enemy.get("kind")) in ["warden", "vault", "prop_crew"]:
			continue
		if enemy.global_position.distance_to(ball) < 30.0:
			continue
		var at: Vector3 = enemy.global_position + Vector3(2.0, 0.0, 0.0)
		_prop = _game.combat.spawn_enemy("prop_crew", _game.ctx.terrain.drop_point(at.x, at.z, 1.8))
		_prop_placed = true
		var crew = _prop
		crew.tree_exiting.connect(func(): _facts.prop_drops = int(crew.drops))
		return


func _finish() -> void:
	_done = true
	var fleet = _fleet()
	var report := {"stage": _stage, "seed": _seed, "seconds": snappedf(_seconds, 0.1), "arrival_kind": _facts.get("arrival_kind", ""),
		"arrival_announced": _facts.announced.has(_arrival_id), "arrival_landed": _facts.started.has(_arrival_id),
		"forms": _facts.forms, "cave_ins": fleet.cave_ins.falls_started if fleet != null else -1,
		"cave_in_hits": fleet.cave_ins.balls_hit if fleet != null else -1,
		"cages_dropped": fleet.cages_dropped if fleet != null else -1, "lines_cut": fleet.lines_cut if fleet != null else -1,
		"prop_placed": _prop_placed, "prop_drops": int(_prop.drops) if is_instance_valid(_prop) else int(_facts.prop_drops),
		"ball_stops": _ball_stops, "bot_outcome": _driver.outcome, "warden_broken": _driver.warden_broken(),
		"exit_stage": _game.run.stage}
	print("ARRIVALS " + JSON.stringify(report))
	_t.check("child reported", true)
	_game.free()
	quit(_t.verdict())


func _on_node_added(node: Node) -> void:
	if _game == null or _game.build == null:
		return
	if "_strafe" in node:
		node.set_meta("bot_strafe", 1.0 if (_counter_serial + _seed) % 2 == 0 else -1.0)
		_counter_serial += 1
	if node.get_parent() == _game.build.scrap:
		node.set_meta("bot_side", 1.0 if (_scrap_serial + _seed) % 2 == 0 else -1.0)
		_scrap_serial += 1
