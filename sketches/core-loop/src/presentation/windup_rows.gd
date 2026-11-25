extends RefCounted

const EventKinds := preload("res://src/core/event_kinds.gd")

const ROWS := {
	"chaser": {"color_role": "hazard", "shape": "bar", "sound": "none", "attacks": {"E01": ["WINDUP"]},
		"idle": {"style": "bob", "amplitude": 0.06, "beats": 3.0}, "death": {"style": "scatter", "parts": 4, "seconds": 0.5}},
	"lobber": {"color_role": "hazard", "shape": "cross", "sound": "threat_whistle", "attacks": {"E02": ["TELEGRAPH"]},
		"idle": {"style": "breathe", "amplitude": 0.03, "beats": 2.5}, "death": {"style": "collapse", "parts": 6, "seconds": 0.6}},
	"miniboss": {"color_role": "hazard", "shape": "burst", "sound": "none", "attacks": {"E03": ["slam_crouch", "SLAM_LEAP"], "E04": ["charge_brace"]},
		"idle": {"style": "breathe", "amplitude": 0.025, "beats": 2.5}, "death": {"style": "scatter", "parts": 8, "seconds": 0.7}},
	"vault": {"color_role": "neutral", "shape": "none", "sound": "none", "attacks": {"none": []},
		"idle": {"style": "tick", "amplitude": 0.02, "beats": 2.0}, "death": {"style": "collapse", "parts": 8, "seconds": 0.7}},
	"warden": {"color_role": "hazard", "shape": "ring", "sound": "none", "attacks": {"W01": ["PULSE_TELEGRAPH"], "W02": ["PULSE_TELEGRAPH"], "W04": ["PULSE_TELEGRAPH"]},
		"idle": {"style": "breathe", "amplitude": 0.02, "beats": 2.0}, "death": {"style": "spin_down", "parts": 8, "seconds": 0.7}},
	"mag_trapper": {"color_role": "hazard", "shape": "ring", "sound": "none", "attacks": {"E05": ["warn_seconds"]},
		"idle": {"style": "sway", "amplitude": 0.05, "beats": 2.5}, "death": {"style": "scatter", "parts": 5, "seconds": 0.5}},
	"hooker": {"color_role": "hazard", "shape": "bar", "sound": "warn_tether", "attacks": {"E06": ["warn_seconds"]},
		"idle": {"style": "sway", "amplitude": 0.05, "beats": 2.5}, "death": {"style": "scatter", "parts": 5, "seconds": 0.5}},
	"netcaster": {"color_role": "hazard", "shape": "star", "sound": "none", "attacks": {"E07": ["warn_seconds"]},
		"idle": {"style": "sway", "amplitude": 0.05, "beats": 2.0}, "death": {"style": "scatter", "parts": 4, "seconds": 0.5}},
	"bola_thrower": {"color_role": "hazard", "shape": "cross", "sound": "none", "attacks": {"E08": ["warn_seconds"]},
		"idle": {"style": "bob", "amplitude": 0.06, "beats": 4.0}, "death": {"style": "scatter", "parts": 4, "seconds": 0.45}},
	"plated_brute": {"color_role": "hazard", "shape": "burst", "sound": "none", "attacks": {"E09": ["warn_seconds"]},
		"idle": {"style": "breathe", "amplitude": 0.03, "beats": 3.0}, "death": {"style": "collapse", "parts": 7, "seconds": 0.65}},
	"deflector": {"color_role": "hazard", "shape": "bar", "sound": "none", "attacks": {"E10": ["warn_seconds"]},
		"idle": {"style": "breathe", "amplitude": 0.04, "beats": 3.0}, "death": {"style": "collapse", "parts": 6, "seconds": 0.6}},
	"winch_drone": {"color_role": "hazard", "shape": "bar", "sound": "none", "attacks": {"E11": ["warn_seconds"]},
		"idle": {"style": "hover", "amplitude": 0.07, "beats": 2.0}, "death": {"style": "spin_down", "parts": 3, "seconds": 0.45}},
	"gyro_jammer": {"color_role": "hazard", "shape": "ring", "sound": "none", "attacks": {"E12": ["warn_seconds"]},
		"idle": {"style": "hover", "amplitude": 0.06, "beats": 2.0}, "death": {"style": "spin_down", "parts": 4, "seconds": 0.5}},
	"swatter": {"color_role": "hazard", "shape": "chevron", "sound": "none", "attacks": {"E13": ["warn_seconds"]},
		"idle": {"style": "sway", "amplitude": 0.05, "beats": 3.0}, "death": {"style": "scatter", "parts": 5, "seconds": 0.55}},
	"ramp_flipper": {"color_role": "hazard", "shape": "ring", "sound": "warn_flap", "attacks": {"E14": ["warn_seconds"]},
		"idle": {"style": "bob", "amplitude": 0.05, "beats": 2.5}, "death": {"style": "scatter", "parts": 5, "seconds": 0.5}},
	"linker": {"color_role": "neutral", "shape": "none", "sound": "none", "attacks": {"none": []},
		"idle": {"style": "sway", "amplitude": 0.04, "beats": 3.0}, "death": {"style": "collapse", "parts": 6, "seconds": 0.6}},
	"foreman": {"color_role": "neutral", "shape": "none", "sound": "none", "attacks": {"none": []},
		"idle": {"style": "tick", "amplitude": 0.03, "beats": 2.0}, "death": {"style": "collapse", "parts": 6, "seconds": 0.6}},
	"catch_trap": {"color_role": "hazard", "shape": "ring", "sound": "none", "attacks": {"E15": ["warn_seconds"]},
		"idle": {"style": "tick", "amplitude": 0.05, "beats": 2.0}, "death": {"style": "scatter", "parts": 6, "seconds": 0.6}},
	"reactor_relic": {"color_role": "hazard", "shape": "burst", "sound": "none", "attacks": {"E16": ["warn_seconds"]},
		"idle": {"style": "breathe", "amplitude": 0.025, "beats": 1.5}, "death": {"style": "collapse", "parts": 7, "seconds": 0.7}},
	"swarm_remnant": {"color_role": "hazard", "shape": "arrow", "sound": "none", "attacks": {"E17": ["LOCK_WARN"]},
		"idle": {"style": "hover", "amplitude": 0.08, "beats": 1.5}, "death": {"style": "pop", "parts": 3, "seconds": 0.4}, "pose": {"style": "dip", "degrees": 14.0}},
	"mind_hand": {"color_role": "hazard", "shape": "bar", "sound": "none", "attacks": {"E18": ["warn_seconds"]},
		"idle": {"style": "sway", "amplitude": 0.035, "beats": 2.0}, "death": {"style": "spin_down", "parts": 6, "seconds": 0.6}},
	"burrower": {"color_role": "hazard", "shape": "ring", "sound": "warn_burrow", "attacks": {"E19": ["warn_seconds"]},
		"idle": {"style": "breathe", "amplitude": 0.05, "beats": 2.5}, "death": {"style": "collapse", "parts": 5, "seconds": 0.55}},
	"drill_crew": {"color_role": "hazard", "shape": "square", "sound": "warn_bore", "attacks": {"E20": ["warn_seconds"]},
		"idle": {"style": "tick", "amplitude": 0.035, "beats": 2.5}, "death": {"style": "collapse", "parts": 6, "seconds": 0.6}},
	"lamp_swarm": {"color_role": "hazard", "shape": "wave", "sound": "warn_lure", "attacks": {"E21": ["warn_seconds"]},
		"idle": {"style": "hover", "amplitude": 0.06, "beats": 2.0}, "death": {"style": "pop", "parts": 4, "seconds": 0.45}},
	"line_cutter": {"color_role": "hazard", "shape": "cross", "sound": "warn_cut", "attacks": {"E22": ["warn_seconds"]},
		"idle": {"style": "bob", "amplitude": 0.06, "beats": 3.0}, "death": {"style": "scatter", "parts": 4, "seconds": 0.45}},
	"anchor_crew": {"color_role": "hazard", "shape": "arrow", "sound": "warn_winch", "attacks": {"E23": ["warn_seconds"]},
		"idle": {"style": "sway", "amplitude": 0.04, "beats": 3.0}, "death": {"style": "collapse", "parts": 6, "seconds": 0.6}},
	"kite_drone": {"color_role": "hazard", "shape": "diamond", "sound": "warn_dive", "attacks": {"E24": ["warn_seconds"]},
		"idle": {"style": "hover", "amplitude": 0.07, "beats": 2.5}, "death": {"style": "spin_down", "parts": 3, "seconds": 0.45}},
	"dispatcher": {"color_role": "hazard", "shape": "cross", "sound": "none", "attacks": {"E26": ["warn_seconds"]},
		"idle": {"style": "tick", "amplitude": 0.03, "beats": 2.0}, "death": {"style": "collapse", "parts": 6, "seconds": 0.6}},
	"prop_crew": {"color_role": "hazard", "shape": "burst", "sound": "none", "attacks": {"E31": ["ROOF_WARN"]},
		"idle": {"style": "sway", "amplitude": 0.03, "beats": 3.0}, "death": {"style": "collapse", "parts": 6, "seconds": 0.6}},
	"pit_jaw": {"color_role": "hazard", "shape": "ring", "sound": "none", "attacks": {"E30": ["warn_seconds"]},
		"idle": {"style": "tick", "amplitude": 0.04, "beats": 2.0}, "death": {"style": "pop", "parts": 4, "seconds": 0.4}},
	"splitter": {"color_role": "hazard", "shape": "ring", "sound": "none", "attacks": {},
		"idle": {"style": "breathe", "amplitude": 0.05, "beats": 2.0}, "death": {"style": "pop", "parts": 3, "seconds": 0.4}},
	"splitter_pod": {"color_role": "hazard", "shape": "ring", "sound": "none", "attacks": {"E25": ["warn_seconds"]},
		"idle": {"style": "bob", "amplitude": 0.05, "beats": 1.5}, "death": {"style": "pop", "parts": 1, "seconds": 0.3}},
	"jolt_layer": {"color_role": "hazard", "shape": "ring", "sound": "jolt_layer_tell", "attacks": {"E27": ["warn_seconds"]},
		"idle": {"style": "sway", "amplitude": 0.04, "beats": 3.0}, "death": {"style": "scatter", "parts": 5, "seconds": 0.5}},
	"boom_tender": {"color_role": "hazard", "shape": "bar", "sound": "warn_reel", "attacks": {"E40": ["warn_seconds"]},
		"idle": {"style": "bob", "amplitude": 0.04, "beats": 3.0}, "death": {"style": "scatter", "parts": 7, "seconds": 0.6}},
	"ballast_heavy": {"color_role": "hazard", "shape": "burst", "sound": "none", "attacks": {"E32": ["warn_seconds"]},
		"idle": {"style": "breathe", "amplitude": 0.02, "beats": 3.0}, "death": {"style": "collapse", "parts": 8, "seconds": 0.7}},
	"gap_net": {"color_role": "hazard", "shape": "star", "sound": "none", "attacks": {"E33": ["warn_seconds"]},
		"idle": {"style": "sway", "amplitude": 0.04, "beats": 3.0}, "death": {"style": "scatter", "parts": 5, "seconds": 0.5}},
	"rogue_crane": {"color_role": "hazard", "shape": "wave", "sound": "none", "attacks": {"E34": ["wind_lane"], "E35": ["wind_ring"]},
		"idle": {"style": "tick", "amplitude": 0.02, "beats": 4.0}, "death": {"style": "spin_down", "parts": 8, "seconds": 0.7}},
	"rogue_skip": {"color_role": "hazard", "shape": "arrow", "sound": "none", "attacks": {"E36": ["wind_lane"], "E37": ["wind_ring"]},
		"idle": {"style": "tick", "amplitude": 0.02, "beats": 4.0}, "death": {"style": "collapse", "parts": 8, "seconds": 0.7}},
	"rogue_tender": {"color_role": "hazard", "shape": "bar", "sound": "none", "attacks": {"E38": ["wind_lane"], "E39": ["wind_ring"]},
		"idle": {"style": "tick", "amplitude": 0.02, "beats": 4.0}, "death": {"style": "spin_down", "parts": 8, "seconds": 0.7}},
}


static func row(kind: String, enemy: Object, attack: String) -> Dictionary:
	var spec: Dictionary = ROWS.get(kind, {})
	if spec.is_empty() or not spec.attacks.has(attack):
		return {}
	var actor: Object = enemy.get("swarm") if kind == "swarm_remnant" else enemy
	if actor == null and attack != EventKinds.NONE:
		return {}
	var lead := 0.0
	for field in spec.attacks[attack]:
		var value = actor.get(field)
		if not (value is float or value is int):
			return {}
		lead += float(value)
	var shape: String = EventKinds.attack_glyph(attack) if spec.attacks.size() > 1 else spec.shape
	return {"attack": attack, "phase": "none" if attack == EventKinds.NONE else "windup",
		"color_role": spec.color_role, "shape": shape, "lead_seconds": lead, "sound": spec.sound}


static func has_state_facts(kind: String) -> bool:
	return kind == "warden" or kind == "swarm_remnant"


static func state_facts(enemy: Object) -> Array[Dictionary]:
	var facts: Array[Dictionary] = []
	var kind: String = enemy.get("kind")
	if kind == "warden":
		if enemy.get("_charging"):
			var family: String = enemy.get("family")
			var attack := "W01" if family == "reactor" else ("W02" if family == "swarm" else "W04")
			facts.append({"row": attack, "phase": "windup", "progress": enemy.charge_fraction(), "at": enemy.global_position})
	elif kind == "swarm_remnant":
		var swarm = enemy.get("swarm")
		if swarm != null and swarm.state == swarm.State.LOCKED and swarm.lane() == enemy.telegraph():
			facts.append({"row": "E17", "phase": "windup", "progress": swarm.t / swarm.LOCK_WARN, "at": enemy.global_position})
	return facts
