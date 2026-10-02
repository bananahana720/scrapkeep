extends RefCounted

# Three stages, named with the world's map titles (map_*.gd). A stage's shape (spawn,
# beacon, entry heading) belongs to the terrain, which writer D owns; this table holds the dials the
# rest of the run reads. threat scales the director, event_mix weights the events D
# may schedule, scrap_density scales the scrap build lays out, and beacon_seconds is
# how long the beacon takes to charge with the ball inside its ring on the unsealed
# path. The warden fields are the stage's one MUST (DEMO-SPEC): its plating and HP,
# the lesson it teaches and the hint the objective line gives, and an optional
# warden_fight, "plating" (the default, these rows) or "posture" (slice_defs.gd). Hints match the stage's
# Warden family (roster WARDEN_FAMILIES): stage 1's reactor is the one that vents, and
# stage 2's hive hides behind its guard rack. Every number here is a
# starting value; tuning edits this table, the heft constants and the part catalogue.

# The boss the run ends on after the last stage; "" is a table with no boss.
const BOSS := "brindle"

const COUNT := 3

const DEFS := [
	{"stage": 1, "name": "Spillway: the top shelf", "map": "spillway", "threat": 1.0,
		"event_mix": {"flood": 1.0, "scrap_stampede": 1.0}, "scrap_density": 1.0, "beacon_seconds": 25.0, "beacon_radius": 30.0,
		"warden_plating": 45.0, "warden_hp": 800.0, "warden_lesson": "plate", "warden_hint": "Ram it hard, right after it vents."},
	{"stage": 2, "name": "The Cable Reach", "map": "gorge", "threat": 1.25,
		"event_mix": {"flood": 1.0, "dust_squall": 0.6, "surge_run": 0.8, "cave_in": 1.0, "impact": 1.0}, "scrap_density": 1.2, "beacon_seconds": 30.0, "beacon_radius": 30.0,
		"warden_plating": 80.0, "warden_hp": 2200.0, "warden_lesson": "caps", "warden_hint": "Bowl through its guard rack and slam its caps."},
	{"stage": 3, "name": "The Weir", "map": "weir", "threat": 2.1,
		"event_mix": {"flood": 1.0, "dust_squall": 1.0, "surge_run": 1.0, "hold_the_relay": 1.0}, "scrap_density": 1.4, "beacon_seconds": 35.0, "beacon_radius": 28.0,
		"warden_plating": 140.0, "warden_hp": 7500.0, "warden_lesson": "magnet", "warden_hint": "In its ring, shoot the magnet while it pulls you."},
]


static func of(stage: int) -> Dictionary:
	return DEFS[clampi(stage, 1, COUNT) - 1]


static func is_last(stage: int) -> bool:
	return stage >= COUNT


static func synergy_in_play(_synergy_id: String) -> bool:
	return true


# The slice table authors its packs (slice_defs.gd); this table has none, so the
# director uses its own rules.
static func packs() -> Array:
	return []


static func elite() -> Dictionary:
	return {}


static func elite_arrival() -> int:
	return 0


static func has_vault() -> bool:
	return true
