extends RefCounted

const Library := preload("res://src/world/pockets/pocket_library.gd")
const Graph := preload("res://src/world/park/park_graph.gd")
const FAMILIES := {
	"risk": ["blood_counter", "curse_counter", "sacrifice_counter", "scrap_counter"],
	"safe": ["ward_counter", "core_counter", "rivet_counter", "coil_counter"],
}
const BASE_CHANCE := 0.45
const CLEAR_M := 40.0
const POOL_FLOOR := 0.2
const CURSE_CHANCE := 1.0 / 7.0
const SACRIFICE_CHANCE := 1.0 / 7.0
const FULL_HEALTH_BUMP := 0.25

static func memory() -> Dictionary:
	return {"risk_taken": false, "last_appeared": -100, "last_seen": -100, "last_refused": -100, "seen": [], "offers": {}, "decisions": {}}

static func recency(age: int) -> float:
	return 0.25 if age == 1 else 0.5 if age == 2 else 1.0

static func odds(mem: Dictionary, stage: int) -> Dictionary:
	var recent := recency(stage - int(mem.last_appeared))
	var risk_weight := recency(stage - int(mem.last_refused))
	return {"chance": BASE_CHANCE * recent, "recency": recent,
		"safe_share": 0.0 if mem.risk_taken else 1.0 / (1.0 + risk_weight),
		"refusal_weight": risk_weight, "skip_time": 0.0}

static func draw(mem: Dictionary, stage: int, rng: RandomNumberGenerator, full_health: bool) -> Dictionary:
	var modifiers := odds(mem, stage)
	if rng.randf() >= float(modifiers.chance):
		return {}
	var family := "safe" if rng.randf() < float(modifiers.safe_share) else "risk"
	var id: String
	var sacrifice_odds := SACRIFICE_CHANCE + (FULL_HEALTH_BUMP if full_health else 0.0)
	if family == "risk":
		var roll := rng.randf()
		if roll < CURSE_CHANCE:
			id = "curse_counter"
		elif roll < CURSE_CHANCE + sacrifice_odds:
			id = "sacrifice_counter"
		else:
			id = "blood_counter" if rng.randf() < 0.5 else "scrap_counter"
	else:
		id = String(FAMILIES.safe[rng.randi_range(0, FAMILIES.safe.size() - 1)])
	return modifiers.merged({"stage": stage, "family": family, "interior_id": id,
		"curse": id == "curse_counter", "sacrifice": id == "sacrifice_counter",
		"sacrifice_chance": sacrifice_odds, "full_health_bump": full_health,
		"pool_floor": POOL_FLOOR if id == "curse_counter" else 0.0})

static func appear(mem: Dictionary, offer: Dictionary) -> void:
	mem.last_appeared = maxi(int(mem.last_appeared), int(offer.stage))

static func see(mem: Dictionary, offer: Dictionary) -> void:
	if (mem.seen as Array).any(func(row): return row.stage == offer.stage):
		return
	mem.seen.append(offer.duplicate(true))
	mem.last_seen = offer.stage

static func decide(mem: Dictionary, offer: Dictionary, took: bool) -> void:
	var key := str(offer.stage)
	if bool(mem.decisions.get(key, false)):
		return
	mem.decisions[key] = took
	if took and offer.family == "risk":
		mem.risk_taken = true
	elif not took:
		mem.last_refused = offer.stage

static func devices(offer: Dictionary) -> Array:
	var risk: bool = offer.family == "risk"
	return [{"device": "blood_shrine" if risk else "healing_ward", "tier": 1,
		"pay": "health" if risk else "cores"},
		{"device": "trade_chest", "tier": int(offer.get("tier", 1)), "pay": "health" if risk else "cogs"}]

# Curse lowers the rarer tier weights, but never below the sourced 0.2 floor.
static func curse_tier(rng: RandomNumberGenerator) -> int:
	var weights := [1.0, 0.5, POOL_FLOOR]
	var roll := rng.randf() * 1.7
	for i in weights.size():
		roll -= maxf(float(weights[i]), POOL_FLOOR)
		if roll <= 0.0:
			return i + 1
	return 3

static func doors(map) -> Array:
	var out := []
	for row in map.park.activity_rows:
		out.append({"id": String(row.id), "at": Vector2(row.at[0], row.at[1])})
	for row in map.park.contraption_rows:
		if row.has("door"):
			out.append({"id": String(row.id), "at": Vector2(row.door.at[0], row.door.at[1])})
	return out

static func candidates(graph, map) -> PackedInt32Array:
	var out := PackedInt32Array()
	var blocked: Array = doors(map)
	for spec in map.activity_sites:
		blocked.append({"at": spec.at})
	# Keep the entire largest interior off the route and outside the authored clear rings.
	var lines := {}
	for n in graph.node_count():
		if graph.flags(n) & Graph.LINE != 0:
			var p: Vector3 = graph.position(n)
			var cell := Vector2i(floori(p.x / CLEAR_M), floori(p.z / CLEAR_M))
			if not lines.has(cell):
				lines[cell] = []
			lines[cell].append(Vector2(p.x, p.z))
	for n in graph.node_count():
		var flags: int = graph.flags(n)
		if flags & Graph.DOOR_OK == 0 or flags & (Graph.LINE | Graph.WARDEN | Graph.DECK | Graph.UNDER) != 0:
			continue
		var p: Vector3 = graph.position(n)
		var at := Vector2(p.x, p.z)
		if blocked.any(func(row): return at.distance_to(row.at) <= CLEAR_M + 22.0):
			continue
		var near_line := false
		var cell := Vector2i(floori(p.x / CLEAR_M), floori(p.z / CLEAR_M))
		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				for q in lines.get(cell + Vector2i(dx, dz), []):
					if at.distance_to(q) <= CLEAR_M:
						near_line = true
		if not near_line and graph.d_spawn_node(n) < INF and graph.d_landmark_node(n) < INF:
			out.append(n)
	return out

static func place(graph, map, rng: RandomNumberGenerator, pool: PackedInt32Array) -> Dictionary:
	if graph == null or pool.is_empty():
		return {}
	var node := pool[rng.randi_range(0, pool.size() - 1)]
	var p: Vector3 = graph.position(node)
	return {"node": node, "at": Vector2(p.x, p.z)}

static func stage_site(graph, map, run, layout_seed: int, pool: PackedInt32Array) -> Dictionary:
	if graph == null:
		return {}
	var key := str(run.stage)
	if run.trade_memory.offers.has(key):
		return run.trade_memory.offers[key].duplicate(true)
	var rng := RandomNumberGenerator.new()
	# A named layout stream does not advance ctx.rng or any existing draw.
	rng.seed = hash([layout_seed, run.run_seed, run.stage, "trade_layout"])
	var offer := draw(run.trade_memory, run.stage, rng, run.hp >= run.max_hp)
	var spec := {}
	if not offer.is_empty():
		var spot := place(graph, map, rng, pool)
		if not spot.is_empty():
			var interior := Library.trade(String(offer.interior_id))
			offer["tier"] = curse_tier(rng) if offer.curse else 1
			spec = Library.site_spec(interior).merged(spot).merged({"id": "curse" if offer.curse else "sacrifice" if offer.sacrifice else "trade_" + String(offer.family), "trade": offer})
			appear(run.trade_memory, offer)
	run.trade_memory.offers[key] = spec.duplicate(true)
	return spec
