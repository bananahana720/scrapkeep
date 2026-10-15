extends RefCounted
# Where the park's pockets may stand: the placement rules (PARK.md 2.12) and the graph-side index
# they read. The game's pocket draw and tools/park_graph.gd share this file, so the shipped game
# never reaches into tools/ (the release export leaves tools/* out).

const ParkSchema := preload("res://src/world/park/park_schema.gd")
const ParkGraph := preload("res://src/world/park/park_graph.gd")
const Parts := preload("res://src/build/parts.gd")

const SIDE := ParkGraph.SIDE

# Pockets (PARK.md 2.12, park starting values, and its readings fixed 2026-10-11).
const DOOR_SPAWN_M := 240.0
const DOOR_BEACON_M := 320.0
const DOOR_DOOR_M := 200.0
const RING_M := 40.0
const DETOUR_MIN_M := 150.0
const DETOUR_MAX_M := 600.0
const HIDDEN_ROUTES := 3
# SR15 (K-UNITS KB8 round two), all start values. The beacon sits on an objective-fit node: every
# ground node of a disc round it, radius reach_m (the Warden engage ring, PARK.md 2.12) times
# BEACON_DISC_SHARE, is open and within BEACON_FLAT_M of the beacon's height. The fight is held
# inside the ring, so the whole ring is the disc; the flat limit is half CLIMB_M, so the fight
# floor never needs a climb. Comps note: comps/ror2/stage-anatomy.md:112 (the idea of an
# objective-fit test only; its constants are not copied, Scrapkeep derives its own).
const BEACON_DISC_SHARE := 1.0
const BEACON_FLAT_M := 2.5
# comps/isaac/floor-generation.md:107: the median spawn-to-reward walk is at least 1.5 times the
# median spawn-to-objective walk. Reported, not gated (K-UNITS.md:138).
const REWARD_RATIO_MIN := 1.5
# comps/roboquest/stage-anatomy.md:125: the full-visit ratio is at most 3.0. Reported, not gated.
const FULL_VISIT_RATIO_MAX := 3.0
const ONLINE_KINDS := ["enemy_camp", "surge_run"]
const REWARD_KINDS := ["cracked_cache"]
const RISK_KINDS := ["ambush_altar", "hauler_bounty"]
const HIDDEN_KINDS := ["valve", "cracked_wall"]
# Readings rule 4: destructive event sites count, a flood or a drain does not. `impact` is read as
# destructive beside cave_in (both are terrain_event.gd's ground breaks).
const DESTRUCTIVE_EVENTS := ["cave_in", "collapse", "impact", "boiler_burst", "reactor_blow", "machine_eruption"]
# Contraptions are momentum tools, never stops (contraptions.gd:9-13); the one that throws
# whatever stands on it when it fires is the hazard a door keeps clear of.
const HAZARD_CONTRAPTIONS := ["launcher"]
# Readings rule 3: a breach of these moves the pocket; a detour or sightline miss is logged.
const MOVE_RULES := ["clear_ring", "door_to_door"]
const LOG_RULES := ["detour", "detour_order", "sight"]
# The pay ladder (PARK.md 2.12): the on-line part is common only, the off-line pocket with the
# smaller detour rolls today's common or rare (activities.gd PAY_RARITIES), the one with the
# larger detour rare only. A named part the parts table knows wins over the roll
# (activities.gd _finish), so its rarity is the row's.
const PAY_ONLINE := ["common"]
const PAY_NEAR := ["common", "rare"]
const PAY_FAR := ["rare"]


# Graph-side lookups the ruling needs, rebuilt from a loaded graph (decks by node_row).
class Index:
	var g: ParkGraph
	var park: Dictionary
	var row_index := {}
	var deck_start := PackedInt32Array()
	var deck_count := PackedInt32Array()
	var _cache := {}

	func _init(graph: ParkGraph, p: Dictionary) -> void:
		g = graph
		park = p
		var rows: Array = park["park_rows"]
		for k in rows.size():
			row_index[String(rows[k]["id"])] = k
			deck_start.append(0)
			deck_count.append(0)
		for o in range(SIDE * SIDE, g.node_count()):
			var k: int = row_index.get(g.node_row(o), -1)
			if k < 0:
				continue
			if deck_count[k] == 0:
				deck_start[k] = o
			deck_count[k] += 1

	func row_nodes(id: String) -> PackedInt32Array:
		if _cache.has(id):
			return _cache[id]
		var out := PackedInt32Array()
		if row_index.has(id):
			var k: int = row_index[id]
			out = g.footprint_nodes(park["park_rows"][k], deck_start[k], deck_count[k])
		_cache[id] = out
		return out

	func place_nodes(id: String) -> PackedInt32Array:
		if id == ParkSchema.DROP_IN:
			return PackedInt32Array([g.spawn_node])
		if id == ParkSchema.LANDMARK:
			var b: Array = park["landmark"]["beacon"]
			return g.disc_nodes(Vector2(float(b[0]), float(b[1])), float(park["landmark"]["reach_m"]))
		if row_index.has(id):
			return row_nodes(id)
		for act in park["activity_rows"]:
			if act["id"] == id:
				return PackedInt32Array([door(act["at"], String(act["site"]))])
		return PackedInt32Array()

	func door(at: Array, site: String) -> int:
		return g.site_node(park, row_index, deck_start, deck_count, Vector2(float(at[0]), float(at[1])), site)


# A row's pay as the activity pays it: {"rarities", "named"}. A named part the parts table
# knows wins over the roll; rarities is [] when the row carries neither that nor pay.rarities.
static func _pay(pay: Dictionary) -> Dictionary:
	if pay.has("named"):
		var named := String(pay["named"])
		if Parts.rows().has(named):
			return {"rarities": [String(Parts.rows()[named]["rarity"])], "named": named}
	var out := []
	if pay.get("rarities") is Array:
		for r in pay["rarities"]:
			out.append(String(r))
	return {"rarities": out, "named": ""}


static func _within(rarities: Array, allowed: Array) -> bool:
	if rarities.is_empty():
		return false
	for r in rarities:
		if not allowed.has(r):
			return false
	return true
