extends RefCounted

# Three stages on the Spillway terrain for now. A stage's shape (spawn, beacon, entry
# heading) belongs to the terrain, which writer D owns; this table holds the dials the
# rest of the run reads. threat scales the director, event_mix weights the events D
# may schedule, scrap_density scales the scrap build lays out, and beacon_seconds is
# how long the beacon takes to charge with the ball inside its ring.

const COUNT := 3

const DEFS := [
	{"stage": 1, "name": "Spillway: the top shelf", "threat": 1.0,
		"event_mix": {"flood": 1.0}, "scrap_density": 1.0, "beacon_seconds": 25.0, "beacon_radius": 30.0},
	{"stage": 2, "name": "Spillway: the basin", "threat": 1.5,
		"event_mix": {"flood": 1.0, "dust_squall": 0.6, "surge_run": 0.8}, "scrap_density": 1.2, "beacon_seconds": 30.0, "beacon_radius": 30.0},
	{"stage": 3, "name": "Spillway: the long drop", "threat": 2.1,
		"event_mix": {"flood": 1.0, "dust_squall": 1.0, "surge_run": 1.0, "hold_the_relay": 1.0}, "scrap_density": 1.4, "beacon_seconds": 35.0, "beacon_radius": 28.0},
]


static func of(stage: int) -> Dictionary:
	return DEFS[clampi(stage, 1, COUNT) - 1]


static func is_last(stage: int) -> bool:
	return stage >= COUNT
