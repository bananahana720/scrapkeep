extends RefCounted

# Ball-lab UAT scenarios (plan section 3). Each is a spawn, an objective, a time limit
# and a success predicate, all placed with field.gd's coordinates. The time limits in
# make() are the initial values; MODE_LIMITS_S replaces them per physics mode.
#
# `Run` tracks one trial's progress from a read-only view (jev_state.gd) and judges
# it; `place()` is the harness's one gameplay write, putting the ball at the spawn.
#
# Spawn jitter (JL-21). A scenario with `jitter_m` > 0 places the ball at a point drawn
# from the trial seed, uniform in a disc of that radius round the nominal spawn. Trial i
# gets the same point on every arm, so arms compare on paired starts, and a
# deterministic arm's trials are no longer replicates of one run.

const Field := preload("res://src/field.gd")
const Tuning := preload("res://src/tuning.gd")

const IDS := ["downhill-run", "run-to-pad", "bench-climb", "kicker-gap", "dummy-knock", "pillar-weave", "soak"]

const KICKER_SPEED_MIN := 14.0
const KICKER_SPEED_MAX := 28.0
const KICKER_SPEED_DEFAULT := 21.0
# kicker-gap starts this far down the ramp from the lip, so the lip speed is close to
# the scenario's speed; Run records the exact one.
const KICKER_RUNWAY := 1.0
const JITTER_M := 3.0

# field.gd builds these props from inline literals in _build_props, so they are
# repeated here; jev_state_test.gd checks them against the built lab.
const PILLARS := [Vector2(2.0, 40.0), Vector2(14.0, 48.0), Vector2(26.0, 38.0),
	Vector2(38.0, 50.0), Vector2(48.0, 40.0), Vector2(10.0, 62.0), Vector2(56.0, 66.0)]
const STEEP_KICKER := Vector3(30.0, 4.4, 45.0)
const SERVICE_RAMP := Vector3(50.0, 4.6, 76.0)
const SERVICE_RAMP_HALF := Vector2(4.5, 19.0)
# The weave runs through the zigzag row A-B-C-D-E: one gate between each neighbour.
const WEAVE := [0, 1, 2, 3, 4]

# JL-21b: max(initial, 2x scripted p90) per scenario and physics mode, 20 scripted
# trials each, p90 read at 3x the limit where it was censored at the limit, after
# stomp and ram stopped targeting knocked dummies (A2). Only run-to-pad kinematic rises
# (p90 30.2 s). dummy-knock kinematic (p90 5.5 s), downhill-run and kicker-gap finish
# well inside theirs; the other choice-scenario modes stay censored at 3x
# (inconclusive) and keep the initial limit. Evidence: A2 at bec6560 for the groups it
# re-ran; A3 on the merged head (7ba2d0d) for bench-climb and pillar-weave rigid and
# for downhill-run and kicker-gap in both modes.
const MODE_LIMITS_S := {
	"run-to-pad": {"kinematic": 61.0},
}

# Anomalies, as PROTOCOL.md's events table defines them.
const OVERSPEED := 80.0
const TUNNEL_DEPTH := 0.5


static func all() -> Array:
	var out := []
	for id in IDS:
		out.append(make(id))
	return out


# `id` is a scenario id, or `kicker-gap@<speed>` for a kicker run at that speed.
# Returns {} for an unknown id or a speed outside 14-28 m/s.
static func make(id: String) -> Dictionary:
	if id.begins_with("kicker-gap@"):
		var text := id.trim_prefix("kicker-gap@")
		if not text.is_valid_float():
			return {}
		return kicker_gap(text.to_float())
	match id:
		"downhill-run":
			return _scenario(id, Field.drop_point(Field.RUN_X, -100.0, 2.5), Vector3.ZERO,
				"run_bottom", Field.drop_point(Field.RUN_X, Field.RUN_BOT_Z, Tuning.RADIUS), 12.0, 20.0,
				func(p: Dictionary) -> bool: return p["reached"])
		"run-to-pad":
			return _jittered(_scenario(id, Field.drop_point(Field.RUN_X, -100.0, 2.5), Vector3.ZERO,
				"pad", Field.drop_point(Field.PAD_CENTER.x, Field.PAD_CENTER.y, Tuning.RADIUS), 10.0, 45.0,
				func(p: Dictionary) -> bool: return p["reached"]))
		"bench-climb":
			# Flat ground south of the pad, between the steep kicker's foot (x 30) and the
			# service ramp's (x 50), so both routes are open.
			return _jittered(_scenario(id, Field.drop_point(40.0, 32.0), Vector3.ZERO,
				"bench", Geo.bench_point(), 0.0, 30.0,
				func(p: Dictionary) -> bool: return p["on_bench"]))
		"kicker-gap":
			return kicker_gap(KICKER_SPEED_DEFAULT)
		"dummy-knock":
			var knock := _scenario(id, Field.drop_point(30.0, 28.0), Vector3.ZERO,
				"dummy", Vector3.ZERO, 0.0, 60.0,
				func(p: Dictionary) -> bool: return p["knocked"].size() >= 3)
			knock["dynamic_objective"] = true
			return _jittered(knock)
		"pillar-weave":
			var weave := _scenario(id, Field.drop_point(-8.0, 44.0), Vector3.ZERO,
				"gate", Geo.gate_mid(0), 0.0, 40.0,
				func(p: Dictionary) -> bool: return p["gates"] >= WEAVE.size() - 1)
			weave["dynamic_objective"] = true
			return _jittered(weave)
		"soak":
			# KRIs only: survive the whole limit on the random arm with no anomaly.
			var soak := _scenario(id, Field.drop_point(Field.RUN_X, -100.0, 2.5), Vector3.ZERO,
				"roam", Field.drop_point(Field.PAD_CENTER.x, Field.PAD_CENTER.y, Tuning.RADIUS), 0.0, 120.0,
				func(p: Dictionary) -> bool: return p["tick"] >= p["limit_ticks"] and p["anomalies"].is_empty())
			soak["arm"] = "random"
			return soak
	return {}


# The ball leaves the steep kicker's lip at about `speed` m/s: it starts on the ramp
# KICKER_RUNWAY short of the lip, moving up the ramp. So `speed` is the lip speed that
# requires_speed_ms is calibrated against (JL-21). From the flat short of the foot even
# 28 m/s leaves the lip below 11 m/s, so the ramp, not `speed`, would decide the run.
static func kicker_gap(speed: float) -> Dictionary:
	if speed < KICKER_SPEED_MIN or speed > KICKER_SPEED_MAX:
		return {}
	# jev_agent.gd preloads this file, so its kicker frame is loaded at run time.
	var frame: Dictionary = load("res://src/jev/jev_agent.gd").kicker_frame()
	var up_ramp: Vector3 = (frame["lip"] - frame["heel"]).normalized()
	var normal := up_ramp.cross(Vector3.RIGHT).normalized()
	if normal.y < 0.0:
		normal = -normal
	var spawn: Vector3 = frame["lip"] - up_ramp * KICKER_RUNWAY + normal * (Tuning.RADIUS + 0.05)
	var scenario := _scenario("kicker-gap", spawn, up_ramp * speed,
		"bench", Geo.bench_point(), 0.0, 8.0,
		func(p: Dictionary) -> bool: return p["on_bench"])
	scenario["label"] = "kicker-gap@%s" % String.num(speed)
	scenario["params"] = {"speed": speed}
	return scenario


static func _scenario(id: String, spawn: Vector3, velocity: Vector3, kind: String, point: Vector3,
		radius: float, limit_s: float, success: Callable) -> Dictionary:
	return {
		"id": id,
		"label": id,
		"spawn": spawn,
		"velocity": velocity,
		"objective": {"kind": kind, "point": point, "radius": radius},
		"time_limit_s": limit_s,
		"arm": "",
		"params": {},
		"dynamic_objective": false,
		"jitter_m": 0.0,
		"success": success,
	}


static func _jittered(scenario: Dictionary) -> Dictionary:
	scenario["jitter_m"] = JITTER_M
	return scenario


# Puts the ball at the scenario's spawn with its start velocity. This is harness
# setup, the only gameplay write in the Jev lab files; jev_state.gd never writes.
# `seed` >= 0 applies the scenario's jitter; tests place at the nominal spawn.
#
# place() also sets the limit for the lab's physics mode: jev_run.gd calls it after
# set_mode() and before building the Run, and applies --time-limit-s after it.
static func place(lab, scenario: Dictionary, seed := -1) -> void:
	# jev_agent_test.gd places bare {spawn, velocity} dictionaries: no id, no limit.
	var by_mode: Dictionary = MODE_LIMITS_S.get(scenario.get("id", ""), {})
	var mode: String = lab.player.mode_name()
	if by_mode.has(mode):
		scenario["time_limit_s"] = by_mode[mode]
	lab.player.reset_to(spawn_for(scenario, seed))
	if scenario["velocity"] != Vector3.ZERO:
		lab.player.active_body().set_velocity_now(scenario["velocity"])


static func spawn_for(scenario: Dictionary, seed := -1) -> Vector3:
	var spawn: Vector3 = scenario["spawn"]
	var radius: float = scenario.get("jitter_m", 0.0)
	if seed < 0 or radius <= 0.0:
		return spawn
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var angle := rng.randf() * TAU
	var r := radius * sqrt(rng.randf())
	var clearance := spawn.y - Field.height(spawn.x, spawn.z)
	return Field.drop_point(spawn.x + r * cos(angle), spawn.z + r * sin(angle), clearance)


# Field geometry the scenarios and Run share. An inner class, because GDScript
# inner classes can read the outer constants but not call the outer statics.
class Geo:
	extends RefCounted

	static func bench_point() -> Vector3:
		return Vector3(Field.BENCH_CENTER.x, Field.BENCH_TOP + Tuning.RADIUS, Field.BENCH_CENTER.y)


	# Gate i spans the pillars WEAVE[i] and WEAVE[i + 1].
	static func gate_ends(i: int) -> Array:
		return [PILLARS[WEAVE[i]], PILLARS[WEAVE[i + 1]]]


	static func gate_mid(i: int) -> Vector3:
		var ends := gate_ends(i)
		var mid: Vector2 = (ends[0] + ends[1]) * 0.5
		return Field.drop_point(mid.x, mid.y, Tuning.RADIUS)


	static func on_bench(at: Vector3, is_grounded: bool) -> bool:
		var d := Vector2(at.x, at.z) - Field.BENCH_CENTER
		return is_grounded and absf(d.x) <= Field.BENCH_HALF.x and absf(d.y) <= Field.BENCH_HALF.y \
			and at.y >= Field.BENCH_TOP + Tuning.RADIUS * 0.5


	static func on_service_ramp(at: Vector3) -> bool:
		return absf(at.x - SERVICE_RAMP.x) <= SERVICE_RAMP_HALF.x and absf(at.z - SERVICE_RAMP.z) <= SERVICE_RAMP_HALF.y


	# True when the segment a-b crosses the segment c-d (2D, proper or touching).
	static func crosses(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
		var ab := b - a
		var cd := d - c
		var denom := ab.cross(cd)
		if is_zero_approx(denom):
			return false
		var t := (c - a).cross(cd) / denom
		var u := (c - a).cross(ab) / denom
		return t >= 0.0 and t <= 1.0 and u >= 0.0 and u <= 1.0


# One trial's progress. `observe()` is fed a read-only view once per tick; every
# field in `progress` is a fact the success predicate may use.
class Run:
	extends RefCounted

	var scenario: Dictionary
	var tick_hz := 90
	var progress := {}
	var success_tick := -1

	var _last_flat = null
	var _last_at = null
	var _open_anomalies := {}

	func _init(scenario_ref: Dictionary, hz := 90) -> void:
		scenario = scenario_ref
		tick_hz = hz
		progress = {
			"tick": 0,
			"limit_ticks": limit_ticks(),
			"reached": false,
			"on_bench": false,
			"bench_tick": -1,
			"route": "",
			"used_service_ramp": false,
			"gates": 0,
			"knocked": [],
			"stomps": 0,
			"rams": 0,
			"anomalies": [],
			"lip": [],
		}

	func limit_ticks() -> int:
		return int(round(scenario["time_limit_s"] * tick_hz))

	func objective(view) -> Dictionary:
		var goal: Dictionary = scenario["objective"]
		match scenario["id"]:
			"dummy-knock":
				return {"kind": goal["kind"], "point": _nearest_unknocked(view)}
			"pillar-weave":
				var next := mini(progress["gates"], WEAVE.size() - 2)
				return {"kind": goal["kind"], "point": Geo.gate_mid(next)}
		return {"kind": goal["kind"], "point": goal["point"]}

	func observe(view) -> void:
		var at: Vector3 = view.position()
		var v: Vector3 = view.velocity()
		var is_grounded: bool = view.grounded()
		progress["tick"] = view.tick
		var goal: Dictionary = scenario["objective"]
		if goal["radius"] > 0.0 and Vector2(at.x, at.z).distance_to(Vector2(goal["point"].x, goal["point"].z)) <= goal["radius"]:
			progress["reached"] = true
		if at.is_finite() and Geo.on_service_ramp(at) and is_grounded:
			progress["used_service_ramp"] = true
		if not progress["on_bench"] and Geo.on_bench(at, is_grounded):
			progress["on_bench"] = true
			progress["bench_tick"] = view.tick
			progress["route"] = "service_ramp" if progress["used_service_ramp"] else "kicker"
		_check_lip(view, at, v)
		var flat := Vector2(at.x, at.z)
		if _last_flat != null and progress["gates"] < WEAVE.size() - 1:
			var ends := Geo.gate_ends(progress["gates"])
			if Geo.crosses(_last_flat, flat, ends[0], ends[1]):
				progress["gates"] += 1
		_last_flat = flat
		var knocked: Array = progress["knocked"]
		progress["stomps"] = view.knock_count("stomp")
		progress["rams"] = view.knock_count("ram")
		for knock in view.knocks:
			if knock["enemy"] >= 0 and not knocked.has(knock["enemy"]):
				knocked.append(knock["enemy"])
		_check_anomalies(view.tick, at, v)
		if success_tick < 0 and progress["tick"] <= progress["limit_ticks"] and succeeded():
			success_tick = progress["tick"]

	func succeeded() -> bool:
		return scenario["success"].call(progress)

	# "success" once the predicate held within the limit, "timeout" past the limit,
	# otherwise "running".
	func result() -> String:
		if success_tick >= 0:
			return "success"
		if progress["tick"] > progress["limit_ticks"]:
			return "timeout"
		return "running"

	# Every pass over the steep kicker's lip going +z, with the speed there: what
	# requires_speed_ms is calibrated against. A ball rolling under the lip is not a pass.
	func _check_lip(view, at: Vector3, v: Vector3) -> void:
		var lip: Vector3 = view.kicker_lip()
		var crossed: bool = _last_at != null and _last_at.z < lip.z and at.z >= lip.z
		if crossed and absf(at.x - lip.x) <= view.kicker_half_width() and at.y >= lip.y - 0.5 and v.is_finite():
			progress["lip"].append({"tick": view.tick, "speed": round(v.length() * 10.0) / 10.0})
		_last_at = at

	func _check_anomalies(at_tick: int, at: Vector3, v: Vector3) -> void:
		var now := {}
		if not (at.is_finite() and v.is_finite()):
			now["nan"] = true
		else:
			if at.y < Field.height(at.x, at.z) - TUNNEL_DEPTH:
				now["tunnel"] = true
			if absf(at.x) > Field.HALF or absf(at.z) > Field.HALF:
				now["out_of_bounds"] = true
			if v.length() > OVERSPEED:
				now["overspeed"] = true
		# One record per stretch: an anomaly is logged when it begins, not every tick.
		for what in now:
			if not _open_anomalies.has(what):
				progress["anomalies"].append({"tick": at_tick, "what": what})
		_open_anomalies = now

	func _nearest_unknocked(view) -> Vector3:
		var at: Vector3 = view.position()
		var best := Vector3.ZERO
		var best_d := INF
		var positions: Array = view.enemy_positions()
		for i in positions.size():
			if progress["knocked"].has(i):
				continue
			var d: float = at.distance_to(positions[i])
			if d < best_d:
				best_d = d
				best = positions[i]
		return best if best_d < INF else at
