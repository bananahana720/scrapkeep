extends RefCounted

const Threat := preload("res://src/combat/threat_grammar.gd")

const DIG_KINDS := ["burrower", "drill_crew", "lamp_swarm", "prop_crew", "pit_jaw"]
const DRAIN_BUDGET_USEC := 8000

const ROWS := {
	"burrower": {"faction": "fleet", "role": "punisher", "mechanic": "burrow_lane", "telegraph": Threat.Type.INSTANT, "holds": false,
		"breaks": ["speed", "smash"], "tag": "", "tests": "speed", "script": "res://src/combat/burrower.gd", "world": 2,
		"secondary": "wall_skim", "secondary_counter": "slam_airborne_pin",
		"line": "Hunts a slow ball on the floor and bursts up under it; carve the wall or take the air, or slam its marker from above."},
	"drill_crew": {"faction": "fleet", "role": "punisher", "mechanic": "bore_breach", "telegraph": Threat.Type.INSTANT, "holds": false,
		"breaks": ["smash"], "tag": "", "tests": "heft", "script": "res://src/combat/drill_crew.gd", "world": 2,
		"secondary": "core_jet", "secondary_counter": "bait_rubble_shortcut",
		"line": "Bores a breach where you will be and the floor caves in; smash the rig mid-bore to stop it."},
	"lamp_swarm": {"faction": "fleet", "role": "controller", "mechanic": "lure_bloom", "telegraph": Threat.Type.WAVE, "holds": false,
		"breaks": ["boost"], "tag": "", "tests": "steer", "script": "res://src/combat/lamp_swarm.gd", "world": 2,
		"secondary": "flash_beam", "secondary_counter": "boost_apex_warden_posture",
		"line": "Blooms a ring of lure lamps that bends your steering toward the light; boost straight through the wave."},
	"prop_crew": {"faction": "fleet", "role": "controller", "mechanic": "roof_drop", "telegraph": Threat.Type.INSTANT, "holds": false,
		"breaks": ["ram"], "tag": "", "tests": "contact", "script": "res://src/combat/prop_crew.gd", "world": 2,
		"secondary": "jack_hammer", "secondary_counter": "wall_ram_2x_collapse",
		"line": "Shores a cracked roof over its pack; ram the prop from the wall side and the roof comes down on them, and on you if you are on the floor."},
	"pit_jaw": {"faction": "fleet", "role": "controller", "mechanic": "floor_jaw", "telegraph": Threat.Type.INSTANT, "holds": true,
		"breaks": ["boost", "smash"], "tag": "", "hold": "", "tests": "steer", "script": "res://src/combat/pit_jaw.gd", "world": 2,
		"secondary": "spring_spit", "secondary_counter": "slam_clenched_cannon",
		"line": "A jaw in the floor that bites a ball rolling over it; carve round it on the wall, or slam it shut from above."},
}

static var _drain_index := 0
static var _shared_capsule: CapsuleShape3D = null


static func reset_drain() -> void:
	_drain_index = 0


static func shared_capsule_shape() -> CapsuleShape3D:
	if _shared_capsule == null:
		_shared_capsule = CapsuleShape3D.new()
		_shared_capsule.radius = 0.8
		_shared_capsule.height = 2.2
	return _shared_capsule


static func drain_complete() -> bool:
	return _drain_index >= DIG_KINDS.size()


static func tile_drain_step(budget_usec := DRAIN_BUDGET_USEC) -> Dictionary:
	var start := Time.get_ticks_usec()
	var warmed: Array[String] = []
	var cap := maxi(500, budget_usec)
	if _shared_capsule == null:
		shared_capsule_shape()
	while _drain_index < DIG_KINDS.size():
		var kind: String = DIG_KINDS[_drain_index]
		_drain_index += 1
		var path := String(ROWS[kind]["script"])
		if ResourceLoader.exists(path):
			var script_res = load(path)
			if script_res != null and script_res.has_method("_parts"):
				script_res._parts()
		warmed.append(kind)
		if Time.get_ticks_usec() - start >= cap:
			break
	return {"warmed": warmed, "done": drain_complete(), "elapsed_ms": (Time.get_ticks_usec() - start) / 1000.0}
