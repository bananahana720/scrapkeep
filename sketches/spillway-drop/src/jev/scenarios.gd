extends RefCounted

# Spillway Drop's Jev Lab scenarios (JL-27). Each is a spawn, an objective, a time
# limit and a success predicate, placed with terrain.gd's coordinates, chosen so the
# arms face the stage's own choices rather than a corridor:
#
#   mid-climb    from the basin floor up to a point on the mid shelf between the two
#                basin chutes. By a chute it is about 205-220 m, by the bypass ramp about
#                340 m, so the chute and the guaranteed ground route (README, "What to try
#                first" 2 and 3) are both live. Run records which one carried the climb.
#   flood-hatch  on the basin floor with the flood clock 45 s into its dry phase: the
#                klaxon at 12 s, water at 17 s, flooded 23-37 s, drained and the hatch
#                open at 45 s. Success is reaching the open hatch alive, so the choice is
#                riding the flood out in the basin or climbing out and coming back.
#
# The director runs in both, so chasers and lobbers add the combat choices. The time
# limits are initial values, not calibrated. Spawn jitter works as in ball-lab (JL-21):
# a disc of JITTER_M round the nominal spawn drawn from the trial seed, the same point
# for trial i on every arm.
#
# `place()` is the harness's one gameplay write besides the flood clock preset: it puts
# the ball at the spawn. `Run` tracks one trial's progress from a read-only view.

const Terrain := preload("res://src/terrain.gd")
const FloodCycle := preload("res://src/flood_cycle.gd")
const Geo := preload("res://src/jev/geo.gd")

const IDS := ["mid-climb", "flood-hatch"]
# The instrument epoch every scenario line carries (EV-0555): stage threat rule 2
# (jev_state.gd THREAT_RULE) with trials that end at death, as Cable Bench's do.
const EPOCH := "stage-threat-rule 2 + end-on-death"
const JITTER_M := 6.0
const HATCH_RADIUS := 4.0


static func make(id: String) -> Dictionary:
	match id:
		"mid-climb":
			# North of both mid-shelf benches and the basin chutes' tops, so every route's
			# last leg is open ground: the benches are 3 m boxes the height field does not
			# hold, and a leg through one stalls on its face.
			var objective := Terrain.drop_point(30.0, -10.0, Geo.BALL_CLEARANCE)
			return _scenario(id, Terrain.drop_point(40.0, 100.0, 2.0), "reach_shelf", objective, 10.0, 60.0, -1.0,
				func(p: Dictionary) -> bool: return p["reached"] and p["on_objective_shelf"] and p["dead_tick"] < 0)
		"flood-hatch":
			var hatch := Terrain.at(Terrain.HATCH, Geo.BALL_CLEARANCE)
			return _scenario(id, Terrain.drop_point(20.0, 92.0, 2.0), "reach_hatch", hatch, HATCH_RADIUS, 75.0, 45.0,
				func(p: Dictionary) -> bool: return p["hatch_open_tick"] >= 0 and p["reached"] and p["dead_tick"] < 0)
	return {}


static func _scenario(id: String, spawn: Vector3, kind: String, point: Vector3, radius: float, limit_s: float,
		flood_elapsed: float, success: Callable) -> Dictionary:
	return {
		"id": id,
		"label": id,
		"spawn": spawn,
		"objective": {"kind": kind, "point": point, "radius": radius},
		"time_limit_s": limit_s,
		# Seconds into the flood's dry phase at tick 0; below 0 leaves the stage's clock.
		"flood_elapsed_s": flood_elapsed,
		"jitter_m": JITTER_M,
		"success": success,
	}


# Harness setup: the ball at the (jittered) spawn, and the flood clock where the
# scenario starts it. jev_state.gd never writes.
static func place(stage, scenario: Dictionary, seed := -1) -> void:
	stage.player.reset_to(spawn_for(scenario, seed))
	var elapsed: float = scenario["flood_elapsed_s"]
	if elapsed >= 0.0:
		stage.flood.cycle.phase = FloodCycle.DRY
		stage.flood.cycle.elapsed = elapsed
		stage.flood.step(0.0)


static func spawn_for(scenario: Dictionary, seed := -1) -> Vector3:
	var spawn: Vector3 = scenario["spawn"]
	var radius: float = scenario.get("jitter_m", 0.0)
	if seed < 0 or radius <= 0.0:
		return spawn
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var angle := rng.randf() * TAU
	var r := radius * sqrt(rng.randf())
	var clearance := spawn.y - Terrain.height(spawn.x, spawn.z)
	return Terrain.drop_point(spawn.x + r * cos(angle), spawn.z + r * sin(angle), clearance)


# One trial's progress. `observe()` is fed a read-only view once per tick; every field
# in `progress` is a fact the success predicate or the batch record may use.
#
# Route attribution: the corridor (a chute, the bypass, or open ground) the ball was in
# most recently before it first stood on the objective's shelf, having started below
# it. "open" means it climbed a riser face somewhere else.
class Run:
	extends RefCounted

	var scenario: Dictionary
	var tick_hz := 90
	var progress := {}
	var success_tick := -1

	var _last_corridor := "open"
	var _open_anomalies := {}
	var _start_shelf := -1
	var _last_hp := -1.0

	func _init(scenario_ref: Dictionary, hz := 90) -> void:
		scenario = scenario_ref
		tick_hz = hz
		progress = {
			"tick": 0,
			"limit_ticks": limit_ticks(),
			"reached": false,
			"on_objective_shelf": false,
			"route": "",
			"route_tick": -1,
			"corridors": [],
			"hp_min": 100.0,
			"damage": 0.0,
			"dead_tick": -1,
			"submerged_ticks": 0,
			"caught": false,
			"hatch_open_tick": -1,
			"knocked": 0,
			"scrap": 0,
			"anomalies": [],
		}

	func limit_ticks() -> int:
		return int(round(scenario["time_limit_s"] * tick_hz))

	func objective(_view = null) -> Dictionary:
		var goal: Dictionary = scenario["objective"]
		return {"kind": goal["kind"], "point": goal["point"]}

	func observe(view) -> void:
		var at: Vector3 = view.position()
		var v: Vector3 = view.velocity()
		progress["tick"] = view.tick
		var goal: Dictionary = scenario["objective"]
		var point: Vector3 = goal["point"]
		var shelf := Geo.shelf_at(point.z)
		if _start_shelf < 0:
			_start_shelf = Geo.shelf_at(at.z)
		if Vector2(at.x, at.z).distance_to(Vector2(point.x, point.z)) <= goal["radius"]:
			progress["reached"] = true
		progress["on_objective_shelf"] = Geo.on_shelf(at, shelf)
		var corridor := Geo.corridor_at(at)
		var corridors: Array = progress["corridors"]
		if corridor != "open":
			if corridors.is_empty() or corridors[-1] != corridor:
				corridors.append(corridor)
			_last_corridor = corridor
		if progress["route_tick"] < 0 and _start_shelf < shelf and progress["on_objective_shelf"]:
			progress["route"] = Geo.route_kind(_last_corridor)
			progress["route_tick"] = view.tick
		var hp: float = view.hp()
		if _last_hp >= 0.0 and hp < _last_hp:
			progress["damage"] += _last_hp - hp
		_last_hp = hp
		progress["hp_min"] = minf(progress["hp_min"], hp)
		if progress["dead_tick"] < 0 and not view.alive():
			progress["dead_tick"] = view.tick
		if view.submersion() >= 0.5:
			progress["submerged_ticks"] += 1
			if view.flood_phase() == FloodCycle.HIGH:
				progress["caught"] = true
		if progress["hatch_open_tick"] < 0 and view.hatch_open():
			progress["hatch_open_tick"] = view.tick
		if scenario["id"] == "flood-hatch" and progress["hatch_open_tick"] < 0:
			progress["reached"] = false
		progress["knocked"] = view.knocked_count()
		progress["scrap"] = view.scrap_held()
		_check_anomalies(view.tick, at, v)
		if success_tick < 0 and progress["tick"] <= progress["limit_ticks"] and succeeded():
			success_tick = progress["tick"]

	func succeeded() -> bool:
		return scenario["success"].call(progress)

	# "success" once the predicate held within the limit; "timeout" past the limit or
	# once the ball is dead, since a dead run cannot succeed (EV-0555; Cable Bench's
	# scenarios.gd result()); otherwise "running". The runner ends the trial as soon as
	# this is not "running", so nothing is offered to a dead ball. `end()` tells the two
	# timeouts apart, keeping the harness's closed result list.
	func result() -> String:
		if success_tick >= 0:
			return "success"
		if progress["dead_tick"] >= 0 or progress["tick"] > progress["limit_ticks"]:
			return "timeout"
		return "running"

	func end() -> String:
		if success_tick >= 0:
			return "success"
		if progress["dead_tick"] >= 0:
			return "scrapped"
		if progress["tick"] > progress["limit_ticks"]:
			return "limit"
		return "running"

	func _check_anomalies(at_tick: int, at: Vector3, v: Vector3) -> void:
		var now := {}
		if not (at.is_finite() and v.is_finite()):
			now["nan"] = true
		else:
			if at.y < Terrain.height(at.x, at.z) - Geo.TUNNEL_DEPTH:
				now["tunnel"] = true
			if absf(at.x) > Terrain.HALF or absf(at.z) > Terrain.HALF:
				now["out_of_bounds"] = true
			if v.length() > Geo.OVERSPEED:
				now["overspeed"] = true
		for what in now:
			if not _open_anomalies.has(what):
				progress["anomalies"].append({"tick": at_tick, "what": what})
		_open_anomalies = now
