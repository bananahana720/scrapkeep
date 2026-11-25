extends RefCounted

const ParkSchema := preload("res://src/world/park/park_schema.gd")
const ParkGraph := preload("res://src/world/park/park_graph.gd")
const Parts := preload("res://src/build/parts.gd")

const SIDE := ParkGraph.SIDE

const DOOR_SPAWN_M := 240.0
const DOOR_BEACON_M := 320.0
const DOOR_DOOR_M := 200.0
const RING_M := 40.0
const DETOUR_MIN_M := 150.0
const DETOUR_MAX_M := 600.0
const HIDDEN_ROUTES := 3
const BEACON_DISC_SHARE := 1.0
const BEACON_FLAT_M := 2.5
const FULL_VISIT_RATIO_MAX := 3.0
const ONLINE_KINDS := ["enemy_camp", "surge_run"]
const REWARD_KINDS := ["cracked_cache"]
const RISK_KINDS := ["ambush_altar", "hauler_bounty"]
const HIDDEN_KINDS := ["valve", "cracked_wall"]
const DESTRUCTIVE_EVENTS := ["cave_in", "collapse", "impact", "boiler_burst", "reactor_blow", "machine_eruption"]
const HAZARD_CONTRAPTIONS := ["launcher"]
const MOVE_RULES := ["clear_ring", "door_to_door"]
const LOG_RULES := ["detour", "detour_order", "sight"]
const PAY_ONLINE := ["common"]
const PAY_NEAR := ["common", "rare"]
const PAY_FAR := ["rare"]


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
