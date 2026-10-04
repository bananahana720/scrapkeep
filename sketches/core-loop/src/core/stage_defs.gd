extends RefCounted

const Worlds := preload("res://src/core/worlds.gd")

# World one uses the alpha's two posture rows and Brindle. Re-export the constants
# so row tuning cannot drift between the default and explicitly selected alpha.
const AlphaDefs := preload("res://src/core/alpha_defs.gd")
const BOSS := AlphaDefs.BOSS
const COUNT := AlphaDefs.COUNT
const DEFS := AlphaDefs.DEFS


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


static func synergy_in_play(_synergy_id: String) -> bool:
	return true


# Every part is in play on this table; parts_listed false keeps the loot rules as they were.
static func part_in_play(_part_id: String) -> bool:
	return true


static func parts_listed() -> bool:
	return false


# The slice table opens an upgrade pick on each new heft class (slice_defs.gd); this one does not.
const PICK_ON_CLASS_UP := false


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
