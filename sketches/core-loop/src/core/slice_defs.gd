extends RefCounted

const Worlds := preload("res://src/core/worlds.gd")

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

# The twelve parts every source on this table offers, and the only ones. The five shown
# parts of the kept synergies, one carrier of each hidden tag they need (kinetic, speed, mass;
# arc comes from arc_coil, and the class mods carry it for the pylon pilot), the two class
# mods, and three heavy hitters so the shelf has a rare tier. A synergy completes from this
# list for every pilot (tests/slice_parts_test.gd). Generated recipes and milestone parts are out.
const PARTS := [
	"double_feed", "focus_lens", "spiral_wave", "cross_split", "arc_coil",
	"hot_rivets", "loose_trigger", "rivet_plating",
	"pylon_capacitor", "runner_overclock",
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
		"posture": {"curve": 2.0, "ram_shatters": false}, "pressure": {"elite_rate": 0.0}, "warden_hint": "Break its guard, then smash the core."},
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
