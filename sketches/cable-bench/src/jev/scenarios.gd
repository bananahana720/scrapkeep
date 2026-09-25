extends RefCounted

# Cable Bench scenarios for the Jev Lab (JL-26). Each is a spawn, an objective, a time
# limit, a success predicate and an optional starting scrap purse, placed with
# layout.gd's coordinates. The time limits are initial values, not calibrated.
#
# `Run` tracks one trial's progress from a read-only view (jev_state.gd) and judges
# it; `place()` is the harness's one gameplay write: it puts the ball at the spawn and
# sets the scrap purse, the same kind of setup ball-lab's place() does.
#
# Spawn jitter: a scenario with `jitter_m` > 0 places the ball at a point drawn from the
# trial seed, uniform in a disc round the nominal spawn, so every arm starts trial i at
# the same point. The stage's own random streams take the trial seed through
# stage.gd's seed_override, so trial i also meets the same scrap scatter, buffs and
# director rolls on every arm, until the arms' choices diverge.

const Layout := preload("res://src/layout.gd")
const Tuning := preload("res://src/tuning.gd")
const RunState := preload("res://src/run_state.gd")

const IDS := ["stage-run", "bench-one", "forge-charge"]
const JITTER_M := 3.0

# Anomalies, as PROTOCOL.md's events table defines them.
const OVERSPEED := 80.0
const TUNNEL_DEPTH := 0.5

# The top of road 1, where bench-one ends: the first switchback turn after the east
# ledge.
const BENCH_ONE_GOAL := Vector2(130.0, 36.0)
const BENCH_ONE_RADIUS := 12.0
# One tier-1 cache (25 scrap) and a little over, so the east-ledge cache is a live
# decision inside a 90 s scenario rather than never affordable.
const BENCH_ONE_SCRAP := 30
# On the forging apron, inside the 30 m ring, 36 m from the roadside cache at
# (34, -160) outside it.
const FORGE_SPAWN := Vector2(0.0, -150.0)
const FORGE_SCRAP := 30


static func all() -> Array:
	var out := []
	for id in IDS:
		out.append(make(id))
	return out


static func make(id: String) -> Dictionary:
	match id:
		"stage-run":
			# The whole loop: climb five switchbacks, charge the forge, take the exit.
			return _scenario(id, Layout.spawn_point(), "forge", Vector3.ZERO, 0.0, 600.0, 0,
				func(p: Dictionary) -> bool: return p["clear"])
		"bench-one":
			var goal := Layout.drop_at(BENCH_ONE_GOAL, Tuning.RADIUS)
			return _scenario(id, Layout.drop_point(-130.0, 100.0, 2.0), "road", goal,
				BENCH_ONE_RADIUS, 90.0, BENCH_ONE_SCRAP,
				func(p: Dictionary) -> bool: return p["reached"])
		"forge-charge":
			return _scenario(id, Layout.drop_at(FORGE_SPAWN, 2.0), "forge", Vector3.ZERO, 0.0, 150.0,
				FORGE_SCRAP, func(p: Dictionary) -> bool: return p["clear"])
	return {}


static func _scenario(id: String, spawn: Vector3, kind: String, point: Vector3, radius: float,
		limit_s: float, scrap: int, success: Callable) -> Dictionary:
	return {
		"id": id,
		"label": id,
		"spawn": spawn,
		"objective": {"kind": kind, "point": point, "radius": radius},
		"time_limit_s": limit_s,
		"start_scrap": scrap,
		"jitter_m": JITTER_M,
		"success": success,
	}


# Harness setup, the only gameplay write in these files: the ball at the spawn and the
# scrap purse. `seed` >= 0 applies the scenario's jitter; tests place at the nominal
# spawn.
static func place(stage, scenario: Dictionary, seed := -1) -> void:
	stage.player.reset_to(spawn_for(scenario, seed))
	stage.run.scrap = int(scenario.get("start_scrap", 0))


static func spawn_for(scenario: Dictionary, seed := -1) -> Vector3:
	var spawn: Vector3 = scenario["spawn"]
	var radius: float = scenario.get("jitter_m", 0.0)
	if seed < 0 or radius <= 0.0:
		return spawn
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var angle := rng.randf() * TAU
	var r := radius * sqrt(rng.randf())
	var clearance := spawn.y - Layout.height(spawn.x, spawn.z)
	return Layout.drop_point(spawn.x + r * cos(angle), spawn.z + r * sin(angle), clearance)


static func forge_point() -> Vector3:
	return Layout.drop_at(Layout.FORGE, Tuning.RADIUS)


# One trial's progress. `observe()` is fed a read-only view once per tick; every field
# in `progress` is a fact the success predicate or the result line may use.
class Run:
	extends RefCounted

	var scenario: Dictionary
	var tick_hz := 90
	var progress := {}
	var success_tick := -1

	var _open_anomalies := {}
	var _last_hp := -1.0
	var _on_mesa := -1

	func _init(scenario_ref: Dictionary, hz := 90) -> void:
		scenario = scenario_ref
		tick_hz = hz
		progress = {
			"tick": 0,
			"limit_ticks": limit_ticks(),
			"reached": false,
			"clear": false,
			"scrapped": false,
			"charge_tick": -1,
			"clear_tick": -1,
			"mesa_visits": [],
			"hp_lost": 0.0,
			"anomalies": [],
		}

	func limit_ticks() -> int:
		return int(round(scenario["time_limit_s"] * tick_hz))

	# The point the push drives to and the kind Jev sees. On the forge scenarios it
	# follows the stage's phase: the rig to start the charge, the ring while it
	# charges, and the rig again once it is ready.
	func objective(view) -> Dictionary:
		var goal: Dictionary = scenario["objective"]
		if goal["kind"] != "forge":
			return {"kind": goal["kind"], "point": goal["point"]}
		var phase: int = view.stage.run.phase
		if phase == RunState.Phase.READY:
			return {"kind": "exit", "point": forge_at()}
		return {"kind": "forge", "point": forge_at()}

	# Inner classes cannot call the outer statics, so the forge point is repeated here.
	static func forge_at() -> Vector3:
		return Layout.drop_at(Layout.FORGE, Tuning.RADIUS)

	func observe(view) -> void:
		var at: Vector3 = view.position()
		var v: Vector3 = view.velocity()
		var stage_run = view.stage.run
		progress["tick"] = view.tick
		var goal: Dictionary = scenario["objective"]
		if goal["radius"] > 0.0 and at.is_finite() \
				and Vector2(at.x, at.z).distance_to(Vector2(goal["point"].x, goal["point"].z)) <= goal["radius"]:
			progress["reached"] = true
		var charged: bool = stage_run.phase in [RunState.Phase.CHARGING, RunState.Phase.READY, RunState.Phase.CLEAR]
		if charged and progress["charge_tick"] < 0:
			progress["charge_tick"] = view.tick
		if stage_run.phase == RunState.Phase.CLEAR and not progress["clear"]:
			progress["clear"] = true
			progress["clear_tick"] = view.tick
		if stage_run.phase == RunState.Phase.DEAD:
			progress["scrapped"] = true
		if _last_hp >= 0.0 and stage_run.hp < _last_hp:
			progress["hp_lost"] += _last_hp - stage_run.hp
		_last_hp = stage_run.hp
		var mesa: int = view.mesa_under(at) if view.grounded() else -1
		if mesa >= 0 and mesa != _on_mesa:
			progress["mesa_visits"].append({"tick": view.tick, "mesa": mesa})
		if view.grounded():
			_on_mesa = mesa
		_check_anomalies(view.tick, at, v)
		if success_tick < 0 and progress["tick"] <= progress["limit_ticks"] and succeeded():
			success_tick = progress["tick"]

	func succeeded() -> bool:
		return scenario["success"].call(progress)

	# "success" once the predicate held within the limit; "timeout" past the limit or
	# once the ball is scrapped, since a scrapped run cannot succeed; otherwise
	# "running". `end()` tells the two timeouts apart.
	func result() -> String:
		if success_tick >= 0:
			return "success"
		if progress["scrapped"] or progress["tick"] > progress["limit_ticks"]:
			return "timeout"
		return "running"

	func end() -> String:
		if success_tick >= 0:
			return "success"
		if progress["scrapped"]:
			return "scrapped"
		if progress["tick"] > progress["limit_ticks"]:
			return "limit"
		return "running"

	func _check_anomalies(at_tick: int, at: Vector3, v: Vector3) -> void:
		var now := {}
		if not (at.is_finite() and v.is_finite()):
			now["nan"] = true
		else:
			if at.y < Layout.height(at.x, at.z) - TUNNEL_DEPTH:
				now["tunnel"] = true
			if absf(at.x) > Layout.HALF or absf(at.z) > Layout.HALF:
				now["out_of_bounds"] = true
			if v.length() > OVERSPEED:
				now["overspeed"] = true
		for what in now:
			if not _open_anomalies.has(what):
				progress["anomalies"].append({"tick": at_tick, "what": what})
		_open_anomalies = now
