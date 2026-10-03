extends RefCounted

const SliceDefs := preload("res://src/core/slice_defs.gd")
const Worlds := preload("res://src/core/worlds.gd")

# Unit TP's throwaway probe table: the slice table with the DEM-ground map (reach_probe) or the
# Meteor Crater control zone (crater_probe) as its one stage. game.gd selects the zone with
# use() before the terrain reads DEFS, and register_maps() adds the two probe maps to
# terrain.gd's MAPS in memory, so no existing file changes beyond game.gd's table line.

const BOSS := SliceDefs.BOSS
const COUNT := 1
const SYNERGIES := SliceDefs.SYNERGIES
const PARTS := SliceDefs.PARTS
const PICK_ON_CLASS_UP := SliceDefs.PICK_ON_CLASS_UP
const PACKS := SliceDefs.PACKS
const ELITE := SliceDefs.ELITE
const ELITE_ARRIVAL := SliceDefs.ELITE_ARRIVAL

static var DEFS: Array = _rows("reach_probe")


static func _rows(zone: String) -> Array:
	var row: Dictionary = (SliceDefs.DEFS[0] as Dictionary).duplicate(true)
	if zone == "crater_probe":
		row["map"] = "crater_probe"
		row["name"] = "Crater control"
		row["beacon_radius"] = 12.0
	else:
		row["map"] = "reach_probe"
		row["name"] = "The Cable Reach (DEM probe)"
	return [row]


static func use(zone: String) -> void:
	DEFS = _rows(zone)
	register_maps()


# terrain.gd's MAPS is a const; the probe maps are added to the loaded script's source once.
static func register_maps() -> void:
	var terrain := load("res://src/world/terrain.gd") as GDScript
	if terrain.source_code.contains("ReachProbe"):
		return
	var patched := terrain.source_code.replace("const MAPS := {",
		"const ReachProbe := preload(\"res://src/world/map_reach_probe.gd\")\nconst MAPS := {\"reach_probe\": ReachProbe, \"crater_probe\": ReachProbe.Crater, ")
	assert(patched != terrain.source_code, "probe_defs: terrain.gd's MAPS line moved")
	terrain.source_code = patched
	terrain.reload()


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
	return synergy_id in SYNERGIES


static func part_in_play(part_id: String) -> bool:
	return part_id in PARTS


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
