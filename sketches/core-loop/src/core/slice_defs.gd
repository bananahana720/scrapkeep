extends RefCounted

# The slice table: the Cable Reach played first and alone, ending the run at its gate.
# Same shape as stage_defs.gd. It repeats that file's two lookups because a base script's
# static functions would read the base's own DEFS, not this one's. The numbers are
# stage 1's from stage_defs.gd. The slice has no timed events and no vault, and its
# enemies arrive as the authored packs below, drawn by the director instead of its
# clock, its build tilt and its unlock rules.

const BOSS := ""

const COUNT := 1

# The named synergies this table keeps. Any other synergy and every unnamed tag rule is out.
const SYNERGIES := ["wrecking_ball", "tesla_pylon", "pinwheel", "shrapnel_bloom", "lightning_rod"]

const PACKS := [
	{"id": "run_down", "kinds": ["chaser", "chaser", "chaser", "lobber"]},
	{"id": "grounded", "kinds": ["mag_trapper", "lobber", "lobber"]},
	{"id": "rebound", "kinds": ["deflector", "chaser", "chaser"]},
]
const ELITE := {"id": "elite", "kinds": ["plated_brute", "winch_drone"]}
# The arrival of each stage that is the elite pack.
const ELITE_ARRIVAL := 3

const DEFS := [
	{"stage": 1, "name": "The Cable Reach", "map": "reach", "threat": 1.0,
		"event_mix": {}, "scrap_density": 1.0, "beacon_seconds": 25.0, "beacon_radius": 30.0,
		"warden_plating": 110.0, "warden_hp": 800.0, "warden_lesson": "plate", "warden_fight": "posture",
		"posture": {"curve": 2.0, "ram_shatters": false}, "warden_hint": "Break its guard, then smash the core."},
]


static func of(stage: int) -> Dictionary:
	return DEFS[clampi(stage, 1, COUNT) - 1]


static func is_last(stage: int) -> bool:
	return stage >= COUNT


static func synergy_in_play(synergy_id: String) -> bool:
	return synergy_id in SYNERGIES


static func packs() -> Array:
	return PACKS


static func elite() -> Dictionary:
	return ELITE


static func elite_arrival() -> int:
	return ELITE_ARRIVAL


static func has_vault() -> bool:
	return false
