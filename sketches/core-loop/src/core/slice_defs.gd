extends RefCounted

const Worlds := preload("res://src/core/worlds.gd")

# The slice table: the Cable Reach played first and alone, ending the run at its gate.
# Same shape as stage_defs.gd. It repeats that file's two lookups because a base script's
# static functions would read the base's own DEFS, not this one's. The Warden's plating,
# hp and posture are the slice's own, tuned against ball size by a bot sweep
# (posture_bands_test pins them). Health and plating match the alpha's Cable Reach,
# stage 2; the slice owns its contact-gain separation. It has no timed events or vault, and its
# enemies arrive as the authored packs below, drawn by the director instead of its
# clock, its build tilt and its unlock rules.

const BOSS := ""

const COUNT := 1

# The maker tricks (synergies.gd) this table keeps: the five named synergies and the five
# former three-part sets. Any other trick is out.
const SYNERGIES := ["wrecking_ball", "tesla_pylon", "pinwheel", "shrapnel_bloom", "lightning_rod",
	"ballast_rig", "shatter_crew", "live_wire", "hair_trigger", "storm_front"]

# The twelve parts every source on this table offers, and the only ones: the two parts each of
# the five named tricks' makers that its callout names (Fleet Surplus, Mind-glass, Highdraft,
# Redjaw, Moss), so every named trick wakes from this list for every pilot, and two heavy
# hitters so the shelf has a rare tier (tests/slice_parts_test.gd). Generated recipes and
# milestone parts are out.
const PARTS := [
	"double_feed", "hot_rivets", "focus_lens", "live_line", "loose_trigger", "long_barrel",
	"cross_split", "pin_setter", "arc_coil", "drop_weight",
	"sunforged_core", "gatling_heart",
]

# A rise to a heft class the run has not been rewarded for opens one upgrade tree pick.
const PICK_ON_CLASS_UP := true

const PACKS := [
	{"id": "run_down", "kinds": ["chaser", "chaser", "chaser", "lobber"]},
	{"id": "grounded", "kinds": ["mag_trapper", "lobber", "lobber"]},
	{"id": "rebound", "kinds": ["deflector", "chaser", "chaser"]},
]
const ELITE := {"id": "elite", "kinds": ["plated_brute", "winch_drone"]}
# The arrival of each stage that is the elite pack.
const ELITE_ARRIVAL := 3

const DEFS := [
	{"stage": 1, "world": 1, "music": {"theme": 0, "ace": "spillway"}, "warden_family": "reactor", "name": "The Cable Reach", "map": "reach", "threat": 1.0,
		"unlock_base": 2, "ancient": "reactor_relic",
		"event_mix": {}, "scrap_density": 1.0, "kill_scrap": 4.0, "beacon_seconds": 25.0, "beacon_radius": 30.0,
		"warden_plating": 110.0, "warden_hp": 800.0, "warden_lesson": "",
		"posture": {"curve": 2.0, "ram_shatters": false, "base": {"ram": 25.0},
			"contact_gain_scale": 4.0 / 7.0, "contact_gain_floor": 0.65}, "pressure": {"elite_rate": 0.0}, "warden_hint": "Break its guard, then smash the core."},
]


static func of(stage: int) -> Dictionary:
	return DEFS[clampi(stage, 1, COUNT) - 1]


static func is_last(stage: int) -> bool:
	return stage >= COUNT


# World helpers (worlds.gd): which world a stage belongs to and where it ends.
static func world_of(stage: int) -> int:
	return Worlds.world_of(DEFS, stage)


static func local(stage: int) -> int:
	return Worlds.local(DEFS, stage)


static func first_of(world: int) -> int:
	return Worlds.first_of(DEFS, world)


static func last_of(world: int) -> int:
	return Worlds.last_of(DEFS, world)


static func worlds() -> Array:
	return Worlds.worlds(DEFS)


static func is_world_last(stage: int) -> bool:
	return Worlds.is_world_last(DEFS, stage)


static func is_run_last(stage: int) -> bool:
	return Worlds.is_run_last(DEFS, stage)


static func synergy_in_play(synergy_id: String) -> bool:
	return synergy_id in SYNERGIES


static func part_in_play(part_id: String) -> bool:
	return part_id in PARTS


# True when part_in_play restricts what sources offer (the pool, the generated share and
# the shop's fallback all read it).
static func parts_listed() -> bool:
	return true


static func packs() -> Array:
	return PACKS


static func elite() -> Dictionary:
	return ELITE


static func elite_arrival() -> int:
	return ELITE_ARRIVAL


static func has_vault() -> bool:
	return false
