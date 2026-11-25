extends RefCounted

const Threat := preload("res://src/combat/threat_grammar.gd")

const RECOVERY := 0.75
const REACTION_FLOOR := 0.4
const OVERLAP_FLOOR := 0.95
const BANDS := {
	"area_burst": [0.25, 0.5],
	"projectile": [0.75, 0.75],
	"ray": [1.0, 2.5],
}
const MARKERS := ["circle", "line", "text"]

const HOLD_REASON := "A hold, not a burst: the catch takes the ball, so the warning buys the escape read (BIBLE.md:491, an achievable response)."

const ROWS := {
	"E01": {"kind": "chaser", "pre_shoot": 0.6, "cooldown": 0.8, "radius": 1.4, "length": 11.0, "marker": "line", "band": "ray",
		"recovery_before": 0.9, "reason": "A lunge, not a beam: the lane is the whole danger and one roll leaves it, so fodder stays snappy at 0.6 s."},
	"E02": {"kind": "lobber", "pre_shoot": 1.9, "cooldown": 2.3, "radius": 3.6, "length": 0.0, "marker": "circle", "band": "projectile",
		"recovery_before": 0.0, "reason": "A mortar shell: the floor ring stands for the whole 1.9 s arc, after a 1.3 s charge on the body."},
	"E05": {"kind": "mag_trapper", "pre_shoot": 1.1, "cooldown": 2.75, "radius": 4.5, "length": 0.0, "marker": "circle", "band": "area_burst",
		"recovery_before": 0.0, "reason": HOLD_REASON},
	"E06": {"kind": "hooker", "pre_shoot": 1.0, "cooldown": 3.25, "radius": 1.2, "length": 24.0, "marker": "line", "band": "ray",
		"recovery_before": 0.0, "reason": ""},
	"E07": {"kind": "netcaster", "pre_shoot": 1.2, "cooldown": 2.75, "radius": 5.5, "length": 0.0, "marker": "circle", "band": "area_burst",
		"recovery_before": 0.0, "reason": HOLD_REASON},
	"E08": {"kind": "bola_thrower", "pre_shoot": 0.6, "cooldown": 2.45, "radius": 3.2, "length": 0.0, "marker": "circle", "band": "projectile",
		"recovery_before": 0.0, "reason": "A thrown hold: after the 0.6 s whirl the bola still flies 1.3 s to its committed ring, so the ring stands 1.9 s before a wrap."},
	"E09": {"kind": "plated_brute", "pre_shoot": 1.1, "cooldown": 2.05, "radius": 6.0, "length": 0.0, "marker": "circle", "band": "area_burst",
		"recovery_before": 0.0, "reason": "A 6 m slam that no knock interrupts: the longer read stands in for the interrupt."},
	"E10": {"kind": "deflector", "pre_shoot": 0.9, "cooldown": 1.75, "radius": 2.5, "length": 6.0, "marker": "line", "band": "ray",
		"recovery_before": 0.0, "reason": "A brace, not a ray: a 6 m face lane that turns the ball rather than burning it; 0.9 s is the dish swing."},
	"E11": {"kind": "winch_drone", "pre_shoot": 1.0, "cooldown": 2.75, "radius": 1.1, "length": 20.0, "marker": "line", "band": "ray",
		"recovery_before": 0.0, "reason": ""},
	"E12": {"kind": "gyro_jammer", "pre_shoot": 1.0, "cooldown": 3.05, "radius": 7.0, "length": 0.0, "marker": "circle", "band": "area_burst",
		"recovery_before": 0.0, "reason": HOLD_REASON},
	"E13": {"kind": "swatter", "pre_shoot": 0.8, "cooldown": 1.65, "radius": 7.5, "length": 0.0, "marker": "circle", "band": "area_burst",
		"recovery_before": 0.0, "reason": HOLD_REASON},
	"E14": {"kind": "ramp_flipper", "pre_shoot": 1.0, "cooldown": 2.25, "radius": 3.6, "length": 0.0, "marker": "circle", "band": "area_burst",
		"recovery_before": 0.0, "reason": HOLD_REASON},
	"E15": {"kind": "catch_trap", "pre_shoot": 1.0, "cooldown": 3.25, "radius": 2.6, "length": 0.0, "marker": "circle", "band": "area_burst",
		"recovery_before": 0.0, "reason": HOLD_REASON},
	"E16": {"kind": "reactor_relic", "pre_shoot": 2.4, "cooldown": 1.25, "radius": 5.5, "length": 0.0, "marker": "circle", "band": "area_burst",
		"recovery_before": 0.0, "reason": "An ancient eruption that no knock interrupts and that leaves a 5 s crater: the charge is the whole answer window."},
	"E17": {"kind": "swarm_remnant", "pre_shoot": 1.2, "cooldown": 2.0, "radius": 2.5, "length": 0.0, "marker": "line", "band": "ray",
		"recovery_before": 0.0, "reason": ""},
	"E18": {"kind": "mind_hand", "pre_shoot": 1.4, "cooldown": 2.25, "radius": 1.3, "length": 18.0, "marker": "line", "band": "ray",
		"recovery_before": 0.0, "reason": ""},
	"E19": {"kind": "burrower", "pre_shoot": 1.0, "cooldown": 2.25, "radius": 2.6, "length": 0.0, "marker": "circle", "band": "area_burst",
		"recovery_before": 0.0, "reason": "A burst from under the floor: the ring swells 1.0 s first, and a ball that reaches a bank, a wall or the air is already out of it."},
	"E20": {"kind": "drill_crew", "pre_shoot": 1.2, "cooldown": 2.25, "radius": 3.0, "length": 0.0, "marker": "circle", "band": "area_burst",
		"recovery_before": 0.0, "reason": "A breach that no knock interrupts: the lowering bit is the only answer window."},
	"E21": {"kind": "lamp_swarm", "pre_shoot": 0.9, "cooldown": 2.75, "radius": 9.0, "length": 0.0, "marker": "circle", "band": "area_burst",
		"recovery_before": 0.0, "reason": "A wave, not a burst: the front leaves after 0.9 s and runs outward, so a ball farther out has longer still."},
	"E22": {"kind": "line_cutter", "pre_shoot": 0.6, "cooldown": 2.25, "radius": 2.6, "length": 0.0, "marker": "circle", "band": "projectile",
		"recovery_before": 0.0, "reason": "A thrown cutter: after the 0.6 s cock it still flies 1.1 s to its committed ring, so the ring stands 1.7 s before a cut."},
	"E23": {"kind": "anchor_crew", "pre_shoot": 1.0, "cooldown": 2.75, "radius": 1.2, "length": 18.0, "marker": "line", "band": "ray",
		"recovery_before": 0.0, "reason": ""},
	"E24": {"kind": "kite_drone", "pre_shoot": 0.8, "cooldown": 2.25, "radius": 2.4, "length": 0.0, "marker": "circle", "band": "area_burst",
		"recovery_before": 0.0, "reason": "A dive that no knock interrupts: the mark lamp paints the spot 0.8 s before the 0.7 s dive."},
	"E25": {"kind": "splitter_pod", "pre_shoot": 1.0, "cooldown": 1.85, "radius": 4.5, "length": 0.0, "marker": "circle", "band": "area_burst",
		"recovery_before": 0.0, "reason": "A fuse, not a burst: the full second is the time to roll out of the ring; the spent husk sits out its recovery and crumbles, so the cooldown never runs."},
	"E26": {"kind": "dispatcher", "pre_shoot": 1.2, "cooldown": 6.0, "radius": 4.0, "length": 0.0, "marker": "circle", "band": "projectile",
		"recovery_before": 0.0, "reason": "A tube drop: the ring stands through the 0.45 s suck-up and the pod's 0.75 s flight, the lobber's grammar on a shorter arc. Cooldown is escalation step 0; unanswered drops climb to 2.5 s (step 1) and 1.0 s (step 2)."},
	"E27": {"kind": "jolt_layer", "pre_shoot": 1.0, "cooldown": 3.25, "radius": 6.0, "length": 0.0, "marker": "circle", "band": "area_burst",
		"recovery_before": 0.0, "reason": "A field, not a burst: the mat's first jolt lands a full pulse after it goes live, each pulse read over its own 0.5 s lead (FIELDS-AND-CASTS section 2.3)."},
	"E30": {"kind": "pit_jaw", "pre_shoot": 1.0, "cooldown": 3.25, "radius": 2.4, "length": 0.0, "marker": "circle", "band": "area_burst",
		"recovery_before": 0.0, "reason": HOLD_REASON},
	"E31": {"kind": "prop_crew", "pre_shoot": 1.0, "cooldown": 0.0, "radius": 3.3, "length": 0.0, "marker": "circle", "band": "area_burst",
		"recovery_before": 0.0, "reason": "The player starts it: ramming the prop drops the roof, which warns 1.0 s before it lands. It never repeats, so it has no cooldown."},
	"E32": {"kind": "ballast_heavy", "pre_shoot": 1.1, "cooldown": 2.45, "radius": 5.0, "length": 0.0, "marker": "circle", "band": "area_burst",
		"recovery_before": 0.0, "reason": "The brace is the answer window: 1.1 s with the slab up, light enough that a cruise ram throws it off the rim."},
	"E33": {"kind": "gap_net", "pre_shoot": 1.0, "cooldown": 1.25, "radius": 0.6, "length": 14.0, "marker": "line", "band": "ray",
		"recovery_before": 0.0, "reason": "A net that charges for 1.0 s and holds 3.5 s, then hangs slack for 2.0 s: cross in the slack or faster than it holds."},
	"E40": {"kind": "boom_tender", "pre_shoot": 1.1, "cooldown": 3.25, "radius": 1.5, "length": 8.4, "marker": "line", "band": "ray",
		"recovery_before": 0.0, "reason": "The lamps light out along the boom for 1.1 s, then it swings through the lane for 0.6 s: leave the lane, or bowl through it at FAST tier and pop the floats."},
}

const PLAYER_STARTED := {
	"E31": "Prop crew roof drop: a ram on the prop starts it once; the crew has no attack of its own (design-v3/WORLD-ROSTERS.md).",
}

const WARDEN_EXCEPTIONS := {
	"W01": "Reactor Warden pulse: the posture chassis' own cycle (telegraph_timing_reactor_test).",
	"W02": "Hive Warden pulse: the posture chassis' own cycle (telegraph_timing_swarm_test).",
	"W03": "Hive guard dive: the guard rack belongs to the Hive Warden's fight (telegraph_timing_swarm_test).",
	"W04": "Mind Warden pulse: the posture chassis' own cycle (telegraph_timing_mind_test).",
	"W06": "Mind Warden adaptation: a neutral field, no hit (telegraph_timing_mind_test).",
	"W07": "Caught-pulse crater: the reactor pulse's own aftermath (telegraph_timing_reactor_test).",
	"reactor:slag_lane": "Reactor slag lane: burns for its fill, reported by telegraph_timing_reactor_test.",
	"swarm:hoist_drop": "Hive hoist drop: one per stagger, reported by telegraph_timing_swarm_test.",
	"swarm:pool_swell": "Sinkhole pool swell: one per chunk lost, reported by telegraph_timing_swarm_test.",
	"mind:tilt": "Mind Warden tilt: the driver's own row, reported by telegraph_timing_mind_test.",
	"mind:knock_down": "Mind Warden knock-down: the driver's own row, reported by telegraph_timing_mind_test.",
}


static func id_of(kind: String) -> String:
	for id in ROWS:
		if String(ROWS[id]["kind"]) == kind:
			return id
	return ""


static func row_of(kind: String) -> Dictionary:
	return ROWS.get(id_of(kind), {})


static func recovery(_kind: String) -> float:
	return RECOVERY


static func cooldown(kind: String) -> float:
	return float(row_of(kind).get("cooldown", 0.0))


static func band_of(threat_type: int) -> String:
	match threat_type:
		Threat.Type.PROJECTILE:
			return "projectile"
		Threat.Type.LANE:
			return "ray"
	return "area_burst"


static func marker_of(descriptor: Dictionary) -> String:
	return "line" if String(descriptor.get("form", "")) == "lane" else "circle"


static func size_of(descriptor: Dictionary) -> float:
	if String(descriptor.get("form", "")) == "lane":
		return float(descriptor.get("half_width", 0.0))
	return float(descriptor.get("r_out", 0.0))


static func in_band(id: String) -> bool:
	var row: Dictionary = ROWS.get(id, {})
	var band: Array = BANDS.get(String(row.get("band", "")), [])
	if band.is_empty():
		return false
	var pre := float(row.get("pre_shoot", 0.0))
	return pre >= float(band[0]) - 0.0001 and pre <= float(band[1]) + 0.0001
