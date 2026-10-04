extends RefCounted

const EventKinds := preload("res://src/core/event_kinds.gd")

# One row per roster kind. Timing names read the actor's attack clock; no duration
# is copied here. A miniboss has two attacks.
# The committed telegraph already sounds, except the Lobber's uncommitted charge.
const ROWS := {
	"chaser": {"color_role": "hazard", "shape": "bar", "sound": "none", "attacks": {"E01": ["WINDUP"]}},
	"lobber": {"color_role": "hazard", "shape": "cross", "sound": "threat_whistle", "attacks": {"E02": ["TELEGRAPH"]}},
	"miniboss": {"color_role": "hazard", "shape": "burst", "sound": "none", "attacks": {"E03": ["SLAM_CROUCH", "SLAM_LEAP"], "E04": ["CHARGE_BRACE"]}},
	"vault": {"color_role": "neutral", "shape": "none", "sound": "none", "attacks": {"none": []}},
	"warden": {"color_role": "hazard", "shape": "ring", "sound": "none", "attacks": {"W01": ["PULSE_TELEGRAPH"], "W02": ["PULSE_TELEGRAPH"], "W04": ["PULSE_TELEGRAPH"]}},
	"mag_trapper": {"color_role": "hazard", "shape": "ring", "sound": "none", "attacks": {"E05": ["warn_seconds"]}},
	"hooker": {"color_role": "hazard", "shape": "bar", "sound": "none", "attacks": {"E06": ["warn_seconds"]}},
	"netcaster": {"color_role": "hazard", "shape": "star", "sound": "none", "attacks": {"E07": ["warn_seconds"]}},
	"bola_thrower": {"color_role": "hazard", "shape": "cross", "sound": "none", "attacks": {"E08": ["warn_seconds"]}},
	"plated_brute": {"color_role": "hazard", "shape": "burst", "sound": "none", "attacks": {"E09": ["warn_seconds"]}},
	"deflector": {"color_role": "hazard", "shape": "bar", "sound": "none", "attacks": {"E10": ["warn_seconds"]}},
	"winch_drone": {"color_role": "hazard", "shape": "bar", "sound": "none", "attacks": {"E11": ["warn_seconds"]}},
	"gyro_jammer": {"color_role": "hazard", "shape": "ring", "sound": "none", "attacks": {"E12": ["warn_seconds"]}},
	"swatter": {"color_role": "hazard", "shape": "chevron", "sound": "none", "attacks": {"E13": ["warn_seconds"]}},
	"ramp_flipper": {"color_role": "hazard", "shape": "ring", "sound": "none", "attacks": {"E14": ["warn_seconds"]}},
	"catch_trap": {"color_role": "hazard", "shape": "ring", "sound": "none", "attacks": {"E15": ["warn_seconds"]}},
	"reactor_relic": {"color_role": "hazard", "shape": "burst", "sound": "none", "attacks": {"E16": ["warn_seconds"]}},
	"swarm_remnant": {"color_role": "hazard", "shape": "arrow", "sound": "none", "attacks": {"E17": ["LOCK_WARN"]}},
	"mind_hand": {"color_role": "hazard", "shape": "bar", "sound": "none", "attacks": {"E18": ["warn_seconds"]}},
	# Declared world 2 and 3 kinds: reserved attack ids, live once each kind is built.
	"burrower": {"color_role": "hazard", "shape": "bar", "sound": "none", "attacks": {"E19": ["warn_seconds"]}},
	"drill_crew": {"color_role": "hazard", "shape": "square", "sound": "none", "attacks": {"E20": ["warn_seconds"]}},
	"lamp_swarm": {"color_role": "hazard", "shape": "wave", "sound": "none", "attacks": {"E21": ["warn_seconds"]}},
	"line_cutter": {"color_role": "hazard", "shape": "cross", "sound": "none", "attacks": {"E22": ["warn_seconds"]}},
	"anchor_crew": {"color_role": "hazard", "shape": "arrow", "sound": "none", "attacks": {"E23": ["warn_seconds"]}},
	"kite_drone": {"color_role": "hazard", "shape": "diamond", "sound": "none", "attacks": {"E24": ["warn_seconds"]}},
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
	# Multi-attack actors use the selected attack's existing glyph.
	var shape: String = EventKinds.attack_glyph(attack) if spec.attacks.size() > 1 else spec.shape
	return {"attack": attack, "phase": "none" if attack == EventKinds.NONE else "windup",
		"color_role": spec.color_role, "shape": shape, "lead_seconds": lead, "sound": spec.sound}


# These actors have no Enemy.attack_phase publication. Read their existing state,
# including the Warden pulse warning and the shared rack lane.
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
