extends RefCounted

const Threat := preload("res://src/combat/threat_grammar.gd")

const IDS := ["stamp", "rail", "rearblast"]
const PLATED := "plated"
const ROWS := {
	"stamp": {"name": "Target-stamp Fast Plated Brute", "behaviour": "target_stamp", "stat": "walk_speed",
		"stats": {"walk_speed": [3.8, 4.4, 5.0]}, "cap": 5.0,
		"telegraph": Threat.Type.INSTANT, "warn_seconds": 0.8, "mechanic_tag": "klaxon",
		"radius": 2.8, "reach": 2.2, "damage": 10.0},
	"rail": {"name": "Rail-strike Quick-rest Plated Brute", "behaviour": "rail_strike", "stat": "rest_seconds",
		"stats": {"rest_seconds": [2.4, 2.1, 1.8]}, "cap": 2.4,
		"telegraph": Threat.Type.LANE, "warn_seconds": 0.7, "mechanic_tag": "build_riser",
		"length": 14.0, "width": 2.4, "reach": 2.2, "damage": 10.0},
	"rearblast": {"name": "Rear-blast Heavy-shove Plated Brute", "behaviour": "rear_blast", "stat": "slam_shove",
		"stats": {"slam_shove": [11.0, 13.0, 15.0]}, "cap": 15.0,
		"telegraph": Threat.Type.INSTANT, "warn_seconds": 0.9, "mechanic_tag": "shatter",
		"radius": 4.0, "offset": 5.0, "reach": 2.2, "damage": 10.0},
}


static func row(id: String) -> Dictionary:
	return ROWS.get(id, {})


static func for_arrival(serial: int) -> String:
	return IDS[posmod(serial, IDS.size())]
