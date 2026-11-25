extends RefCounted

const Library := preload("res://src/world/pockets/pocket_library.gd")
const Graph := preload("res://src/world/park/park_graph.gd")
const Park := preload("res://src/core/park_defs.gd")
const Trade := preload("res://src/world/trade_pockets.gd")
const Placement := preload("res://src/world/park/park_placement.gd")
const Modifier := preload("res://src/world/events/stage_modifier.gd")
const RogueDirector := preload("res://src/world/rogue_director.gd")
const Secrets := preload("res://src/core/secrets.gd")
const CREDITS := 150
const CHANCE := 0.25
# World 1's parks hold a drawn pocket to rules the door rules do not carry: level ground, and clear
# of the rescue cage and the rogue sites (2026-11-09, with the dam's first draw, ruling bu). Worlds 2 and 3 are not listed: the level rule alone would cut the
# islands' pockets from 1,116 to 487 over 400 run seeds, which is a call for their own pass (ruling at).
const TIDY := ["park_dam", "park_flume"]
# Level ground: the graph nodes under the footprint, and one step round it, rise no more than this.
# An open node says only that nothing roofs it, so an anchor can sit on a dome's flank or a canyon
# wall. Measured over 400 run seeds a park with no such rule: 190 of the dam's 438 pockets and 244 of
# the flume's 435 stood across more than 5 m of rise (the flume's worst 111 m, down a canyon wall),
# while every spot on a floor or bench rose 4.5 m or less.
const LEVEL_M := 5.0
# W50 W2/W3 level-ground safety tolerances, tuned per park so steep pit walls and floating island
# cliffs are rejected without starving valid anchors:
#   park_pit:      1648 / 1946 anchors <= 5.0 m (85%)
#   park_sinkhole: 1446 / 1770 anchors <= 5.0 m (82%)
#   park_islands:  >= 613 / 847 anchors <= 8.5 m (72%, vs 147 at 5.0 m)
#   park_crown:    468 / 672 anchors <= 8.0 m (70%)
# Kept beside TIDY (accessed via prepare_world / prepare(..., true)) so existing W1-W3 no-modifier
# golden hashes stay intact until w50-final-sync re-pins them.
const TIDY_W2W3 := {
	"park_pit": 5.0,
	"park_sinkhole": 5.0,
	"park_islands": 8.5,
	"park_crown": 8.0,
}


static func tidy_level_m(map_id: String, include_w2w3 := false) -> float:
	if map_id in TIDY:
		return LEVEL_M
	if include_w2w3 and TIDY_W2W3.has(map_id):
		return float(TIDY_W2W3[map_id])
	return -1.0


static func cost(entry: Dictionary) -> int:
	var side: float = Library.FOOTPRINTS[entry.footprint]
	return ceili(side * side / Library.FOOTPRINTS.small)

static func entries(map, world := 0) -> Array:
	var assigned := {}
	for spec in map.activity_sites:
		var entry := Library.for_site(map.park.map, spec.row)
		if not entry.is_empty():
			assigned[entry.id] = true
	var source: Array = Library.rows_for_world(world) if world > 0 else Library.rows()
	return source.filter(func(entry): return entry.kind != "trade" and not assigned.has(entry.id))


static func entries_for_world(map, world: int) -> Array:
	return entries(map, world)


static func prepare_world(graph, map) -> Dictionary:
	return prepare(graph, map, true)

static func _path(graph, sources: PackedInt32Array, targets: PackedInt32Array) -> PackedInt32Array:
	var prev := PackedInt32Array()
	prev.resize(graph.node_count())
	prev.fill(-1)
	var end := {}
	for n in targets:
		end[n] = true
	var queue := sources.duplicate()
	for n in sources:
		prev[n] = n
	var head := 0
	while head < queue.size():
		var n := queue[head]
		head += 1
		if end.has(n):
			var out := PackedInt32Array([n])
			while prev[n] != n:
				n = prev[n]
				out.append(n)
			return out
		for e in range(graph.off[n], graph.off[n + 1]):
			var to: int = graph.to[e]
			if prev[to] < 0:
				prev[to] = n
				queue.append(to)
	return PackedInt32Array()

static func prepare(graph, map, include_w2w3 := false) -> Dictionary:
	var out := {"anchors": [], "fits": {}, "routes": PackedByteArray(), "from_line": PackedFloat32Array()}
	if graph == null or map == null or map.park.is_empty():
		return out
	var line := PackedInt32Array()
	var routes := PackedByteArray()
	routes.resize(graph.node_count())
	for n in graph.node_count():
		if graph.flags(n) & Graph.LINE != 0:
			line.append(n)
			routes[n] = 1
	# Keep a connected path for every authored route step, including ride edges.
	var index := Placement.Index.new(graph, map.park)
	var steps := {}
	for route in map.park.routes:
		var seq := Graph.route_sequence(route)
		for i in range(1, seq.size()):
			var key := [seq[i - 1], seq[i]]
			if not steps.has(key):
				steps[key] = _path(graph, index.place_nodes(seq[i - 1]), index.place_nodes(seq[i]))
			for n in steps[key]:
				routes[n] = 1
	out.routes = routes
	out.from_line = graph.search(line)
	var hazards := PackedInt32Array()
	for home in map.park.home_rows:
		hazards.append_array(index.row_nodes(home.site))
	for event in map.park.event_rows:
		if event.kind in Placement.DESTRUCTIVE_EVENTS:
			hazards.append_array(index.row_nodes(event.site))
	for c in map.park.contraption_rows:
		if c.kind in Placement.HAZARD_CONTRAPTIONS:
			hazards.append_array(graph.disc_nodes(Vector2(c.at[0], c.at[1]), float(c.get("radius", 0.0))))
	var hazard_out: PackedFloat32Array = graph.search(hazards, false, Placement.RING_M)
	var hazard_in: PackedFloat32Array = graph.search(hazards, true, Placement.RING_M)
	var doors := Trade.doors(map)
	var level_limit: float = tidy_level_m(String(map.park.map), include_w2w3)
	var tidy: bool = level_limit >= 0.0
	# Clear of a rescue cage and of every secret's spot by the door ring, and outside every rogue site's
	# disc: without these the dam's spot at (72, -584) stood 16 m from Rivet's cage, (144, 64) reached
	# into the mid rogue site and a pocket at (-248, 192) covered the west rim bench's cracked face.
	var keep_out := []
	if tidy:
		for row in map.park.get("rescue_rows", []):
			keep_out.append({"at": Vector2(row.at[0], row.at[1]), "radius": Placement.RING_M})
		for at in secret_spots(String(map.park.map)):
			keep_out.append({"at": at, "radius": Placement.RING_M})
		for site in RogueDirector.read_sites(String(map.park.map)).get("miniboss_sites", []):
			keep_out.append({"at": Vector2(site.at[0], site.at[1]), "radius": float(site.radius_m)})
	for n in range(Graph.SIDE * Graph.SIDE):
		var f: int = graph.flags(n)
		if f & Graph.DOOR_OK == 0 or f & (Graph.LINE | Graph.WARDEN | Graph.GUARDED | Graph.UNDER | Graph.DECK) != 0:
			continue
		if out.from_line[n] < Placement.DETOUR_MIN_M or out.from_line[n] > Placement.DETOUR_MAX_M:
			continue
		var p: Vector3 = graph.position(n)
		var at := Vector2(p.x, p.z)
		var sizes := {}
		var footprint_ok := {}
		for turn in 4:
			for size in Library.FOOTPRINTS:
				var half: float = Library.FOOTPRINTS[size] * 0.5
				var door := at + Vector2(0, half).rotated(turn * PI * 0.5)
				var dn: int = graph.nearest(door)
				var df: int = graph.flags(dn)
				if df & (Graph.OPEN | Graph.DOOR_OK | Graph.SIGHT_OK) != (Graph.OPEN | Graph.DOOR_OK | Graph.SIGHT_OK) or df & (Graph.LINE | Graph.WARDEN | Graph.GUARDED | Graph.UNDER | Graph.DECK) != 0:
					continue
				if graph.d_spawn_node(dn) < Placement.DOOR_SPAWN_M or graph.d_landmark_node(dn) < Placement.DOOR_BEACON_M or graph.d_spawn_node(dn) == INF or graph.d_landmark_node(dn) == INF:
					continue
				if hazard_out[dn] <= Placement.RING_M or hazard_in[dn] <= Placement.RING_M:
					continue
				var box := Rect2(at - Vector2.ONE * half, Vector2.ONE * half * 2.0)
				if doors.any(func(d): return _box_distance(box, d.at) <= Placement.RING_M or door.distance_to(d.at) < Placement.DOOR_DOOR_M):
					continue
				if not footprint_ok.has(size):
					var fits: bool = map.play_rect.encloses(box)
					var low := INF
					var high := -INF
					for k in graph.box_nodes(box.position - Vector2.ONE * Graph.STEP_M, box.end + Vector2.ONE * Graph.STEP_M):
						if routes[k] == 1 or graph.flags(k) & Graph.OPEN == 0 or graph.flags(k) & (Graph.UNDER | Graph.DECK | Graph.GUARDED | Graph.WARDEN) != 0:
							fits = false
							break
						low = minf(low, graph.py[k])
						high = maxf(high, graph.py[k])
					if tidy:
						fits = fits and high - low <= level_limit and not keep_out.any(func(k): return _box_distance(box, k.at) <= k.radius)
					footprint_ok[size] = fits
				if footprint_ok[size]:
					sizes.get_or_add(size, []).append(turn)
		if not sizes.is_empty():
			out.anchors.append({"node": n, "at": at})
			out.fits[n] = sizes
	out.anchors.sort_custom(func(a, b): return out.from_line[a.node] < out.from_line[b.node])
	return out

# Every spot a secret can stand on in this park, whether or not this run or profile opens it: the
# field finds' spots, the first-win and stage rooms, and the timed door.
static func secret_spots(map_id: String) -> Array:
	var out := []
	for find in Secrets.FINDS.values():
		if find.map == map_id:
			for spot in find.spots:
				out.append(Vector2(spot.at[0], spot.at[1]))
	for row in Secrets.all_rooms().values() + [Secrets.DOOR]:
		if row.map == map_id:
			out.append(Vector2(row.at[0], row.at[1]))
	return out

static func _box_distance(box: Rect2, at: Vector2) -> float:
	var nearest := Vector2(clampf(at.x, box.position.x, box.end.x), clampf(at.y, box.position.y, box.end.y))
	return nearest.distance_to(at)

static func _fits(prepared: Dictionary, entry: Dictionary, spot: Dictionary, placed: Array, trade: Dictionary) -> bool:
	if not spot.get("turn", 0) in prepared.fits.get(spot.node, {}).get(entry.footprint, []):
		return false
	var half: float = Library.FOOTPRINTS[entry.footprint] * 0.5
	var door: Vector2 = spot.at + Vector2(0, half).rotated(spot.get("turn", 0) * PI * 0.5)
	var box := Rect2(spot.at - Vector2.ONE * half, Vector2.ONE * half * 2.0)
	if not trade.is_empty():
		var trade_half: float = Library.FOOTPRINTS[trade.interior.footprint] * 0.5
		var other := Rect2(trade.at - Vector2.ONE * trade_half, Vector2.ONE * trade_half * 2.0)
		if spot.node == trade.node or box.grow(Placement.RING_M).intersects(other, true) or door.distance_to(trade.at) < Placement.DOOR_DOOR_M + trade_half:
			return false
	for spec in placed:
		var other_door: Vector2 = spec.at + Vector2(spec.interior.entrances[0].at[0], spec.interior.entrances[0].at[1]).rotated(spec.get("turn", 0) * PI * 0.5)
		if door.distance_to(other_door) < Placement.DOOR_DOOR_M or _box_distance(box, other_door) <= Placement.RING_M:
			return false
	return true

# A drawn pocket pays what its activity's rule pays, kept to the far ladder (rare). A rule that pays
# the on-line common roll (the camp, PARK.md 2.12) keeps it: the far filter would leave it nothing.
static func _owned_pay(entry: Dictionary) -> Dictionary:
	var pay: Dictionary = load("res://src/world/activities.gd").RULES[entry.activity].pay.duplicate(true)
	if not pay.has("named") and not Placement._within(pay.rarities, Placement.PAY_ONLINE):
		pay.rarities = pay.rarities.filter(func(r): return r in Placement.PAY_FAR)
	return pay

# A pocket whose pay is common only (the camp): never the only pocket drawn, the first picked, or
# the owner of the greatest detour.
static func _common_pay(entry: Dictionary) -> bool:
	var pay := _owned_pay(entry)
	return not Placement._within(Placement._pay(pay).rarities, Placement.PAY_FAR)

# modifier is the stage's SI3 row (stage_modifier.gd), {} for none; {} draws exactly as before.
static func draw(prepared: Dictionary, map, stage: int, rng: RandomNumberGenerator, trade := {}, anchors: Array = [], modifier := {}, world := 0) -> Dictionary:
	var result := {"sites": [], "metrics": {"initial_credits": CREDITS, "remaining_credits": CREDITS, "failed_placements": 0, "refunded_credits": 0, "chance_opportunities": 0, "chance_hits": 0, "anchors": prepared.anchors.size()}}
	if stage < 1 or stage > Park.COUNT or map.park.map != Park.of(stage).map:
		return result
	var slots := Modifier.slots(modifier, stage, Modifier.authored(map))
	if slots == 0:
		return result
	var pool := entries(map, world)
	var picked := []
	var available := CREDITS
	while picked.size() < slots:
		var affordable: Array = pool.filter(func(entry): return cost(entry) <= available and (slots > 1 or not _common_pay(entry)) and (not picked.is_empty() or not _common_pay(entry)))
		if affordable.is_empty():
			break
		var total := 0.0
		for entry in affordable:
			total += float(entry.weight)
		var roll := rng.randf() * total
		var chosen: Dictionary = affordable.back()
		for entry in affordable:
			roll -= float(entry.weight)
			if roll < 0.0:
				chosen = entry
				break
		picked.append(chosen)
		available -= cost(chosen)
		pool.erase(chosen)
	picked.sort_custom(func(a, b): return cost(a) > cost(b) or (cost(a) == cost(b) and a.id < b.id))
	# Far Haul tries every one of the farthest few anchors, farthest first.
	var far_haul: bool = anchors.is_empty() and modifier.get("far", false)
	var chance := 1.0 if far_haul else CHANCE
	var candidates: Array = anchors.duplicate() if not anchors.is_empty() else prepared.anchors.duplicate()
	if far_haul:
		candidates = Modifier.far_anchors(prepared)
	# Alternate near-first and far-first traversals on the private stage stream.
	elif anchors.is_empty() and rng.randi_range(0, 1) == 1:
		candidates.reverse()
	var pending := false
	for spot in candidates:
		if picked.is_empty():
			break
		if not pending:
			result.metrics.chance_opportunities += 1
			if rng.randf() >= chance:
				continue
			result.metrics.chance_hits += 1
			pending = true
		var entry: Dictionary = picked.front()
		var price := cost(entry)
		result.metrics.remaining_credits -= price
		var oriented := {}
		for turn in prepared.fits.get(spot.node, {}).get(entry.footprint, []):
			var candidate: Dictionary = spot.merged({"turn": turn})
			if _fits(prepared, entry, candidate, result.sites, trade):
				oriented = candidate
				break
		if oriented.is_empty():
			result.metrics.failed_placements += 1
			result.metrics.remaining_credits += price
			result.metrics.refunded_credits += price
			continue
		var spec := Library.site_spec(entry).merged(oriented).merged({"id": entry.activity, "drawn": true, "pay": _owned_pay(entry)})
		result.sites.append(spec)
		picked.pop_front()
		pending = false
	# A common reward cannot own the greatest detour, even when rolls allow rare.
	var far := -INF
	for spec in result.sites:
		if not _common_pay(spec.interior):
			far = maxf(far, prepared.from_line[spec.node])
	for spec in result.sites.duplicate():
		if _common_pay(spec.interior) and prepared.from_line[spec.node] >= far:
			result.sites.erase(spec)
			result.metrics.failed_placements += 1
			result.metrics.remaining_credits += cost(spec.interior)
			result.metrics.refunded_credits += cost(spec.interior)
			for spot in candidates:
				if prepared.from_line[spot.node] >= far:
					continue
				result.metrics.remaining_credits -= cost(spec.interior)
				var replacement := {}
				for turn in prepared.fits.get(spot.node, {}).get(spec.interior.footprint, []):
					var candidate: Dictionary = spot.merged({"turn": turn})
					if _fits(prepared, spec.interior, candidate, result.sites, trade):
						replacement = spec.merged(candidate, true)
						break
				if not replacement.is_empty():
					result.sites.append(replacement)
					break
				result.metrics.failed_placements += 1
				result.metrics.remaining_credits += cost(spec.interior)
				result.metrics.refunded_credits += cost(spec.interior)
	result.sites.sort_custom(func(a, b): return cost(a.interior) > cost(b.interior) or (cost(a.interior) == cost(b.interior) and a.interior.id < b.interior.id))
	return result

static func draw_for_world(prepared: Dictionary, map, stage: int, rng: RandomNumberGenerator, trade := {}, anchors: Array = [], modifier := {}) -> Dictionary:
	return draw(prepared, map, stage, rng, trade, anchors, modifier, Park.world_of(stage))


static func stage_sites(graph, map, run, layout_seed: int, trade := {}, prepared := {}, modifier := {}, world_aware := false) -> Array:
	if graph == null or map == null or map.park.is_empty() or run.stage < 1 or run.stage > Park.COUNT or map.park.map != Park.of(run.stage).map:
		return []
	var key := str(run.stage)
	if run.pocket_draw_cache.has(key):
		return run.pocket_draw_cache[key].sites.duplicate(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([layout_seed, run.run_seed, run.stage, "pocket_draw"])
	var layout: Dictionary = prepared
	if layout.is_empty():
		layout = prepare_world(graph, map) if world_aware else prepare(graph, map)
	var result := draw_for_world(layout, map, run.stage, rng, trade, [], modifier) if world_aware else draw(layout, map, run.stage, rng, trade, [], modifier)
	run.pocket_draw_cache[key] = {"sites": result.sites.duplicate(true)}
	return result.sites

static func to_doc(cache: Dictionary) -> Dictionary:
	var doc := {}
	for key in cache:
		var sites := []
		for spec in cache[key].sites:
			sites.append({"interior": spec.interior.id, "node": spec.node, "at": [spec.at.x, spec.at.y], "turn": spec.get("turn", 0)})
		doc[key] = {"sites": sites}
	return doc

static func from_doc(doc: Dictionary) -> Dictionary:
	var cache := {}
	var library := {}
	for entry in Library.all_rows():
		library[entry.id] = entry
	for key in doc:
		# A save from before the dam drew (2026-11-09, ruling bu) holds an empty stage 1 draw. It is dropped,
		# so a Continue on the dam draws the pocket its stage modifier acts on.
		if key == "1" and doc[key].sites.is_empty():
			continue
		var sites := []
		for saved in doc[key].sites:
			var entry: Dictionary = library[saved.interior]
			sites.append(Library.site_spec(entry).merged({"id": entry.activity, "drawn": true, "node": int(saved.node), "turn": int(saved.get("turn", 0)), "at": Vector2(saved.at[0], saved.at[1]), "pay": _owned_pay(entry)}))
		cache[key] = {"sites": sites}
	return cache

static func _integer(value) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(value) and value == floorf(value)

static func validate_doc(doc, entrance: int) -> String:
	if not doc is Dictionary:
		return "invalid pocket draw cache"
	var library := {}
	for entry in Library.all_rows():
		if entry.kind != "trade":
			library[entry.id] = entry
	for key in doc:
		if not key is String or not key.is_valid_int() or key != str(int(key)) or int(key) < 1 or int(key) > mini(entrance, Park.COUNT):
			return "invalid pocket draw stage"
		var row = doc[key]
		if not row is Dictionary or not row.get("sites") is Array or row.sites.size() > Modifier.max_slots(int(key), 3):
			return "invalid pocket draw sites"
		var seen := {}
		var spent := 0
		for spec in row.sites:
			if not spec is Dictionary or not spec.get("interior") is String or not library.has(spec.interior) or seen.has(spec.interior):
				return "invalid pocket draw interior"
			var entry: Dictionary = library[spec.interior]
			if entry.get("assigned", {}).get("map", "") == Park.of(int(key)).map:
				return "assigned pocket draw interior"
			seen[spec.interior] = true
			spent += cost(entry)
			if not _integer(spec.get("turn", 0)) or spec.get("turn", 0) < 0 or spec.get("turn", 0) > 3:
				return "invalid pocket draw orientation"
			if not _integer(spec.get("node")) or spec.node < 0 or spec.node >= Graph.SIDE * Graph.SIDE:
				return "invalid pocket draw node"
			if not spec.get("at") is Array or spec.at.size() != 2:
				return "invalid pocket draw position"
			for value in spec.at:
				if not (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) or not is_finite(value) or absf(value) > Graph.HALF_M:
					return "invalid pocket draw position"
			if Graph.lattice_index(spec.at[0], spec.at[1]) != int(spec.node):
				return "pocket draw position differs from node"
		if spent > CREDITS:
			return "pocket draw credit exceeded"
	return ""
