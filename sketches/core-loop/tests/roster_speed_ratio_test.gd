extends SceneTree

const Roster := preload("res://src/combat/roster.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const Augments := preload("res://src/movement/augments.gd")
const T := preload("res://tests/support/t.gd")

# SQ4, the speed table (comps/roboquest/movement-and-feel.md: run is about 2.35x the median
# enemy and 1.2x the p90 enemy). Reports now and gates from a later unit: it prints the
# enemy min, median, p90 and max against each pilot's cruise and boost, states the declared
# ratio, and lists every kind above 1.2x a pilot's cruise with its telegraph row. It asserts
# only the structure: every roster kind has a speed row, every number is finite, a row's
# move class agrees with its speeds, and the same listing reports a planted fast kind.
#
# Enemy speeds are read from each kind's own script constants (SOURCES: a constant name, or
# LENGTH/TIME for a committed lunge or charge). travel is the standing approach speed in
# m/s, burst the fastest committed speed of its attack; 0 means the kind does not move that
# way. kite_drone's burst is its dive's vertical drop over DIVE seconds, a lower bound.
# A pilot's cruise is the tuning default, times Rivet's sprint raise; boost adds the boost impulse.

const SOURCES := {
	"chaser": {"script": "chaser", "travel": "SPEED", "burst": "LUNGE_LENGTH/LUNGE_TIME"},
	"miniboss": {"script": "miniboss", "travel": "WALK", "burst": "CHARGE_LENGTH/CHARGE_TIME"},
	"swarm_remnant": {"script": "swarm_remnant", "travel": "MAX_SPEED", "burst": "MAX_SPEED"},
	"burrower": {"script": "burrower", "travel": "TUNNEL_SPEED", "burst": "BURST_REACH/WARN"},
	"lamp_swarm": {"script": "lamp_swarm", "travel": "BLOOM_SPEED", "burst": "SCATTER_SPEED"},
	"kite_drone": {"script": "kite_drone", "travel": "", "burst": "HOVER/DIVE"},
	"prop_crew": {"script": "prop_crew", "travel": "WALK", "burst": ""},
	"splitter": {"script": "splitter", "travel": "WALK", "burst": ""},
	"splitter_pod": {"script": "splitter_pod", "travel": "WALK", "burst": ""},
	"ballast_heavy": {"script": "ballast_heavy", "travel": "WALK", "burst": ""},
}
# Every other kind holds its ground (fixed) or hovers in place (winch_drone).
const STATIONARY := ["lobber", "vault", "warden", "mag_trapper", "hooker", "netcaster", "bola_thrower",
	"plated_brute", "deflector", "winch_drone", "gyro_jammer", "swatter", "ramp_flipper", "catch_trap",
	"reactor_relic", "mind_hand", "drill_crew", "line_cutter", "anchor_crew", "linker", "dispatcher", "foreman", "pit_jaw", "jolt_layer", "gap_net"]

var _t := T.new("roster_speed_ratio_test")


func _initialize() -> void:
	_run()
	quit(_t.verdict())


func _value(script: Script, expr: String) -> float:
	if expr == "":
		return 0.0
	var consts: Dictionary = script.get_script_constant_map()
	var parts := expr.split("/")
	if parts.size() == 2:
		return float(consts[parts[0]]) / float(consts[parts[1]])
	return float(consts[expr])


func _speeds() -> Dictionary:
	var out := {}
	for kind in SOURCES:
		var src: Dictionary = SOURCES[kind]
		var script: Script = load("res://src/combat/%s.gd" % src["script"])
		out[kind] = {"travel": _value(script, src["travel"]), "burst": _value(script, src["burst"])}
	for kind in STATIONARY:
		out[kind] = {"travel": 0.0, "burst": 0.0}
	return out


static func percentile(sorted_values: Array, p: float) -> float:
	var idx := p * float(sorted_values.size() - 1)
	var lo := int(floor(idx))
	var hi := int(ceil(idx))
	return lerpf(float(sorted_values[lo]), float(sorted_values[hi]), idx - float(lo))


func _pilots() -> Array:
	var cruise_base := 0.0
	for spec in Tuning.SPECS:
		if spec["key"] == "cruise":
			cruise_base = float(spec["value"])
	var sprint := float(Augments.SPRINT_CRUISE)
	var out := []
	for def in ClassDef.all():
		var cruise := cruise_base * (sprint if def.movement_id == "overdrive_sprint" else 1.0)
		out.append({"id": def.id, "cruise": cruise, "boost": cruise + float(Tuning.BOOST_IMPULSE)})
	return out


func _run() -> void:
	var speeds := _speeds()
	var missing := []
	for kind in Roster.ROWS:
		if not speeds.has(kind):
			missing.append(kind)
	_t.check("every roster kind has a speed row", missing.is_empty(), ", ".join(missing))
	var travel := []
	for kind in speeds:
		var s: Dictionary = speeds[kind]
		_t.check("finite speeds %s" % kind, is_finite(s["travel"]) and is_finite(s["burst"]) and s["travel"] >= 0.0 and s["burst"] >= 0.0)
		if Roster.has(kind):
			var move := String(Roster.ROWS[kind].get("move_class", ""))
			if move == "fixed":
				_t.check("fixed kind does not move: %s" % kind, s["travel"] == 0.0 and s["burst"] == 0.0)
			elif move == "ground":
				_t.check("ground kind moves: %s" % kind, s["travel"] > 0.0 or s["burst"] > 0.0)
		if s["travel"] > 0.0:
			travel.append(s["travel"])
	travel.sort()
	_t.check("some enemy travels", travel.size() > 0)
	if travel.is_empty():
		return
	var stats := {"min": travel[0], "median": percentile(travel, 0.5), "p90": percentile(travel, 0.9), "max": travel[travel.size() - 1]}
	print("enemy travel speed over %d moving kinds (m/s): min %.2f, median %.2f, p90 %.2f, max %.2f; %d kinds hold their ground"
		% [travel.size(), stats["min"], stats["median"], stats["p90"], stats["max"], speeds.size() - travel.size()])
	print("declared ratio: cruise %.2fx median enemy (comps start value), fast enemy above %.2fx cruise"
		% [Roster.RUN_TO_MEDIAN_RATIO, Roster.FAST_ENEMY_RATIO])
	var pilots := _pilots()
	_t.eq("six pilots", pilots.size(), 6)
	for pilot in pilots:
		_t.check("pilot speeds finite %s" % pilot["id"], is_finite(pilot["cruise"]) and pilot["cruise"] > 0.0 and pilot["boost"] > pilot["cruise"])
		print("%s: cruise %.1f (%.2fx median, %.2fx p90), boost %.1f (%.2fx median)"
			% [pilot["id"], pilot["cruise"], pilot["cruise"] / stats["median"], pilot["cruise"] / stats["p90"], pilot["boost"], pilot["boost"] / stats["median"]])
		var fast := _above(speeds, pilot["cruise"] * Roster.FAST_ENEMY_RATIO)
		for entry in fast:
			print("  above %.1fx cruise: %s top %.1f m/s, telegraph %s" % [Roster.FAST_ENEMY_RATIO, entry["kind"], entry["top"], entry["telegraph"] if entry["telegraph"] != "" else "none"])
		_t.check("fast list rows carry a telegraph %s" % pilot["id"], fast.all(_has_telegraph))
	# Positive control: a planted kind faster than any cruise must be listed.
	var planted := speeds.duplicate()
	planted["planted_fast"] = {"travel": 99.0, "burst": 99.0}
	var listed := _above(planted, 14.0 * Roster.FAST_ENEMY_RATIO).any(func(e): return e["kind"] == "planted_fast")
	_t.check("planted fast kind is listed", listed)
	# Negative control: a fast kind with no roster row has no telegraph, and the predicate must fail it.
	var untelegraphed := _above(planted, 14.0 * Roster.FAST_ENEMY_RATIO).filter(func(e): return e["kind"] == "planted_fast")
	_t.check("planted fast kind without a telegraph fails the predicate", untelegraphed.size() == 1 and not _has_telegraph(untelegraphed[0]))


func _has_telegraph(entry: Dictionary) -> bool:
	return String(entry["telegraph"]) != ""


func _above(speeds: Dictionary, limit: float) -> Array:
	var out := []
	for kind in speeds:
		var top: float = maxf(speeds[kind]["travel"], speeds[kind]["burst"])
		if top > limit:
			var tele := ""
			if Roster.has(kind):
				var t: int = int(Roster.ROWS[kind].get("telegraph", -1))
				if t >= 0:
					tele = String(Threat.Type.keys()[t])
			out.append({"kind": kind, "top": top, "telegraph": tele})
	out.sort_custom(func(a, b): return a["top"] > b["top"])
	return out
