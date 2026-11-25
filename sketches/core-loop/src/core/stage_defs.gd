extends RefCounted

const Worlds := preload("res://src/core/worlds.gd")

const AlphaDefs := preload("res://src/core/alpha_defs.gd")
const BOSS := AlphaDefs.BOSS
const COUNT := AlphaDefs.COUNT
const DEFS := AlphaDefs.DEFS

const RUN_TIER_DIAL_STEPS := {"damage": 0.1, "aggression": 0.1}


static func of(stage: int) -> Dictionary:
	return DEFS[clampi(stage, 1, COUNT) - 1]


static func is_last(stage: int) -> bool:
	return stage >= COUNT


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
	return AlphaDefs.synergy_in_play(synergy_id)


static func part_in_play(part_id: String) -> bool:
	return AlphaDefs.part_in_play(part_id)


static func parts_listed() -> bool:
	return AlphaDefs.parts_listed()


const PICK_ON_CLASS_UP := AlphaDefs.PICK_ON_CLASS_UP


static func packs() -> Array:
	return AlphaDefs.packs()


static func elite() -> Dictionary:
	return AlphaDefs.elite()


static func elite_arrival() -> int:
	return AlphaDefs.elite_arrival()


static func has_vault() -> bool:
	return AlphaDefs.has_vault()
