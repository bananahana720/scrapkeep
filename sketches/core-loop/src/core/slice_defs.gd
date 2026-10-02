extends RefCounted

# The slice table: the Cable Reach played first and alone, ending the run at its gate.
# Same shape as stage_defs.gd. It repeats that file's two lookups because a base script's
# static functions would read the base's own DEFS, not this one's. The numbers are
# stage 1's from stage_defs.gd; the event mix is the Reach's own.

const BOSS := ""

const COUNT := 1

# The named synergies this table keeps. Any other synergy and every unnamed tag rule is out.
const SYNERGIES := ["wrecking_ball", "tesla_pylon", "pinwheel", "shrapnel_bloom", "lightning_rod"]

const DEFS := [
	{"stage": 1, "name": "The Cable Reach", "map": "gorge", "threat": 1.0,
		"event_mix": {"flood": 1.0, "dust_squall": 0.6, "surge_run": 0.8, "cave_in": 1.0, "impact": 1.0}, "scrap_density": 1.0, "beacon_seconds": 25.0, "beacon_radius": 30.0,
		"warden_plating": 45.0, "warden_hp": 800.0, "warden_lesson": "plate", "warden_fight": "posture", "warden_hint": "Break its guard, then smash the core."},
]


static func of(stage: int) -> Dictionary:
	return DEFS[clampi(stage, 1, COUNT) - 1]


static func is_last(stage: int) -> bool:
	return stage >= COUNT


static func synergy_in_play(synergy_id: String) -> bool:
	return synergy_id in SYNERGIES
