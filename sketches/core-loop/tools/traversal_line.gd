extends SceneTree

const Game := preload("res://src/game.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const SimClock := preload("res://src/core/sim_clock.gd")
const RunLog := preload("res://src/core/run_log.gd")
const Augments := preload("res://src/movement/augments.gd")

# The traversal measure (design-v3/TRAVERSAL.md): one pilot's traversal bot crosses the slice
# table's stage once per seed, from the spawn to the Warden's engagement, and one JSON file
# holds the four numbers per seed, the median, the worst seed, the pilot, the table and the
# commit. One command per pilot, one frame one physics tick:
#
#   godot --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/traversal_line.gd \
#     -- --pilot=sable|rivet|kest [--seeds=1,2,3,4,5,6,7,8] [--out=<dir>] [--commit=<sha>] [--trace]
#
# The default out is artifacts/local/traversal at the repository root. The pilot's route and
# bar come from tools/traversal_lines.json. The number judges a bot, not the feel of the map.
#
# Route measures, per seed: path_length_m (the distance travelled from spawn to engage), rides
# (which of ride_grapple_line, ride_chute, ride_skylight, ride_glide_drop, wall_crumbled,
# kicker_launch and thermal_ride fired, by name) and
# uphill_m (the most z the ball gave back from its furthest point toward the Warden). The summary
# holds each one's median.

const TABLE := "slice"
const ROUTES := "res://tools/traversal_lines.json"
const PILOTS := ["sable", "rivet", "kest"]
const DEFAULT_SEEDS := [1, 2, 3, 4, 5, 6, 7, 8]
const DEFAULT_OUT := "res://../../artifacts/local/traversal"
const WORLD_AIMS := [Augments.AIM_REACH, Augments.AIM_ASSIST]
const PROBE_SECONDS := 0.1
const PROBE_SPOKES := 12
const PROBE_PITCHES := [0.0, 0.4, 0.8]
const RIDE_FACTS := ["ride_grapple_line", "ride_chute", "ride_skylight", "ride_glide_drop", "wall_crumbled", "thermal_ride"]
const KICKER_LAUNCH := "kicker_launch"


# One seed's measurement, fed once per physics tick from the spawn until the Warden engages.
class Sampler:
	extends RefCounted

	var game
	var traversal: RunLog.Traversal
	var engaged := false
	var time_to_warden = null
	var max_anchor_gap := 0.0
	var _path := 0.0
	var _last_anchor := 0.0
	var _last_ball := Vector3.INF
	var _clock := -1.0
	var _rides: Array[String] = []
	var _was_grounded := true
	var _furthest_z := -INF
	var _uphill := 0.0
	var tracing := false
	var trace: Array = []

	func _init(game_ref) -> void:
		game = game_ref
		traversal = RunLog.Traversal.new(Engine.physics_ticks_per_second, game.player.tuning.f("cruise"))
		game.events.warden_engaged.connect(_on_engaged)
		game.events.world_fact.connect(_on_fact)

	func _on_fact(kind: String, _at: Vector3) -> void:
		if not engaged and kind in RIDE_FACTS and not kind in _rides:
			_rides.append(kind)

	func _on_engaged(_stage: int) -> void:
		if engaged:
			return
		engaged = true
		time_to_warden = snappedf(game.run.stage_time, 0.01)
		_close_gap()

	func sample() -> void:
		if engaged or not game.flow.in_stage() or game.run.stage_time <= _clock:
			return
		_clock = game.run.stage_time
		var player = game.player
		var ball: Vector3 = player.ball_position()
		if _last_ball != Vector3.INF:
			_path += ball.distance_to(_last_ball)
		_last_ball = ball
		_furthest_z = maxf(_furthest_z, ball.z)
		_uphill = maxf(_uphill, _furthest_z - ball.z)
		var grounded: bool = player.state.grounded
		if _was_grounded and not grounded and game.ctx.terrain.map().near_kicker_lip(Vector2(ball.x, ball.z)) and not KICKER_LAUNCH in _rides:
			_rides.append(KICKER_LAUNCH)
		_was_grounded = grounded
		if _anchored(ball):
			max_anchor_gap = maxf(max_anchor_gap, _path - _last_anchor)
			_last_anchor = _path
		var intent = player.intent
		traversal.step(player.speed_tier(), player.planar_velocity().length(), intent.brake_held, RunLog.Traversal.is_exempt(player))
		if tracing:
			_record_tick(player, ball, grounded)

	func _record_tick(player, ball: Vector3, grounded: bool) -> void:
		var contacts: Array = []
		for body in player._rigid.get_colliding_bodies():
			contacts.append(str(body.get_path()))
		var velocity: Vector3 = player.state.velocity
		trace.append({
			"tick": traversal.ticks, "time": snappedf(game.run.stage_time, 0.001),
			"at": [snappedf(ball.x, 0.01), snappedf(ball.y, 0.01), snappedf(ball.z, 0.01)],
			"velocity": [snappedf(velocity.x, 0.01), snappedf(velocity.y, 0.01), snappedf(velocity.z, 0.01)],
			"planar_speed": snappedf(player.planar_velocity().length(), 0.01), "tier": player.speed_tier(),
			"grounded": grounded, "contacts": contacts, "dead_stops": traversal.dead_stops,
		})

	func _anchored(ball: Vector3) -> bool:
		var reach: float = game.player.grapple_range()
		var aim: Dictionary = game.player.kit.aim
		if int(aim.get("state", Augments.AIM_NONE)) in WORLD_AIMS and ball.distance_to(aim["point"]) <= reach:
			return true
		if traversal.ticks % maxi(1, int(round(PROBE_SECONDS * Engine.physics_ticks_per_second))) != 0:
			return false
		var space = game.get_world_3d().direct_space_state
		for pitch in PROBE_PITCHES:
			for i in PROBE_SPOKES:
				var yaw := TAU * float(i) / float(PROBE_SPOKES)
				var dir := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
				var hit: Dictionary = Augments.grapple_target(space, ball, dir, ball, reach, 0.0, Augments.WORLD_MASK, false)
				if int(hit.get("state", Augments.AIM_NONE)) in WORLD_AIMS and ball.distance_to(hit["point"]) <= reach:
					return true
		return false

	func _close_gap() -> void:
		max_anchor_gap = maxf(max_anchor_gap, _path - _last_anchor)

	func result(seed_number: int, outcome: String) -> Dictionary:
		if not engaged:
			_close_gap()
		var share = traversal.flow_share()
		return {
			"seed": seed_number,
			"flow_share": snappedf(float(share), 0.0001) if share != null else 0.0,
			"dead_stops": traversal.dead_stops,
			"max_anchor_gap_m": snappedf(max_anchor_gap, 0.1),
			"time_to_warden_s": time_to_warden,
			"reached_warden": engaged,
			"path_length_m": snappedf(_path, 0.1),
			"rides": _rides.duplicate(),
			"uphill_m": snappedf(_uphill, 0.1),
			"outcome": outcome,
			"ticks": traversal.ticks,
		}


# The file's content: the per-seed numbers, the median flow share, the worst seed and the totals.
static func document(pilot: String, table: String, commit: String, runs: Array, bar: Dictionary) -> Dictionary:
	var shares: Array = []
	var worst := {}
	var dead := 0
	var gap := 0.0
	var reached := 0
	var lengths: Array = []
	var uphills: Array = []
	var ride_counts: Array = []
	for run in runs:
		shares.append(float(run["flow_share"]))
		lengths.append(float(run.get("path_length_m", 0.0)))
		uphills.append(float(run.get("uphill_m", 0.0)))
		ride_counts.append(float((run.get("rides", []) as Array).size()))
		if worst.is_empty() or float(run["flow_share"]) < float(worst["flow_share"]):
			worst = {"seed": run["seed"], "flow_share": run["flow_share"]}
		dead += int(run["dead_stops"])
		gap = maxf(gap, float(run["max_anchor_gap_m"]))
		if run["reached_warden"]:
			reached += 1
	return {
		"pilot": pilot, "table": table, "commit": commit, "bar": bar, "runs": runs,
		"median_flow_share": snappedf(median(shares), 0.0001), "worst_seed": worst,
		"dead_stops_total": dead, "max_anchor_gap_m": gap, "reached_warden": reached,
		"median_path_length_m": snappedf(median(lengths), 0.1), "median_uphill_m": snappedf(median(uphills), 0.1),
		"median_rides": median(ride_counts),
	}


static func median(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	var mid := sorted.size() / 2
	if sorted.size() % 2 == 1:
		return float(sorted[mid])
	return (float(sorted[mid - 1]) + float(sorted[mid])) / 2.0


static func write_document(path: String, doc: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(doc, "  "))
	file.close()
	return true


static func load_routes() -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(ROUTES))
	return parsed if parsed is Dictionary else {}


static func route_of(routes: Dictionary, pilot: String) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for pair in routes.get("pilots", {}).get(pilot, {}).get("waypoints", []):
		points.append(Vector2(float(pair[0]), float(pair[1])))
	return points


var _settings := {}
var _seeds: Array[int] = []
var _pilot := ""
var _routes := {}
var _index := -1
var _game
var _driver
var _sampler: Sampler
var _runs: Array = []


func _initialize() -> void:
	SimClock.ticks = true
	_settings = _parse(OS.get_cmdline_user_args())
	_pilot = String(_settings.get("pilot", ""))
	if not _pilot in PILOTS:
		printerr("traversal_line: usage: -- --pilot=sable|rivet|kest [--seeds=1,2,3] [--out=<dir>] [--commit=<sha>] [--trace]")
		quit(2)
		return
	var seeds: Array = DEFAULT_SEEDS
	if _settings.has("seeds"):
		seeds = []
		for part in String(_settings["seeds"]).split(",", false):
			seeds.append(int(part))
	for value in seeds:
		_seeds.append(int(value))
	_routes = load_routes()
	_next()


static func _parse(args: PackedStringArray) -> Dictionary:
	var out := {}
	for arg in args:
		if arg.begins_with("--") and "=" in arg:
			out[arg.substr(2, arg.find("=") - 2)] = arg.substr(arg.find("=") + 1)
		elif arg.begins_with("--"):
			out[arg.substr(2)] = "1"
	return out


func _next() -> void:
	_index += 1
	if _index >= _seeds.size():
		_finish()
		return
	Engine.time_scale = 1.0
	seed(_seeds[_index])
	_game = Game.new()
	_game.test_mode = true
	_game.table = TABLE
	root.add_child(_game)
	_driver = null


func _physics_process(delta: float) -> bool:
	if _game == null or _game.flow == null:
		return false
	if _driver == null:
		_driver = BotDriver.new(_game, "traversal", _seeds[_index])
		_driver.class_index = PILOTS.find(_pilot)
		_driver.route = route_of(_routes, _pilot)
		_driver.start()
		_sampler = Sampler.new(_game)
		_sampler.tracing = _settings.has("trace")
		return false
	var over: bool = _driver.tick(delta)
	_sampler.sample()
	if not over and not _sampler.engaged:
		return false
	var run := _sampler.result(_seeds[_index], "engaged" if _sampler.engaged else _driver.outcome)
	_runs.append(run)
	if _sampler.tracing:
		var trace_path := String(_settings.get("out", ProjectSettings.globalize_path(DEFAULT_OUT))).path_join("%s-seed-%d-trace.json" % [_pilot, _seeds[_index]])
		write_document(trace_path, {"pilot": _pilot, "seed": _seeds[_index], "ticks": _sampler.trace})
	print("traversal_line: %s seed %d -> %s, flow share %.3f, dead stops %d, anchor gap %.1f m, to Warden %s s, path %.1f m, rides %s, uphill %.1f m"
		% [_pilot, run["seed"], run["outcome"], run["flow_share"], run["dead_stops"], run["max_anchor_gap_m"], run["time_to_warden_s"],
			run["path_length_m"], run["rides"], run["uphill_m"]])
	_game.free()
	_game = null
	_next()
	return false


func _finish() -> void:
	var bar: Dictionary = _routes.get("pilots", {}).get(_pilot, {}).get("bar", {})
	var doc := document(_pilot, TABLE, _commit(), _runs, bar)
	var out := String(_settings.get("out", ProjectSettings.globalize_path(DEFAULT_OUT)))
	var path := out.path_join("%s.json" % _pilot)
	var written := write_document(path, doc)
	print("traversal_line: %s median flow share %.3f, worst seed %s, written %s to %s"
		% [_pilot, doc["median_flow_share"], doc["worst_seed"], written, path])
	quit(0 if written else 1)


func _commit() -> String:
	if _settings.has("commit"):
		return String(_settings["commit"])
	var output: Array = []
	var code := OS.execute("git", ["-C", ProjectSettings.globalize_path("res://"), "rev-parse", "HEAD"], output)
	return String(output[0]).strip_edges() if code == 0 and output.size() > 0 else "unknown"
