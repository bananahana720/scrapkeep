extends RefCounted


const ParkRecipes := preload("res://src/world/park/park_recipes.gd")

const RANGE_M := 40.0
const PERCH_MIN := 6.0
const PERCH_MAX := 10.0
const DECK_CLEAR := 2.5
const STAND_OFF := 12.0


static func derive(park: Dictionary, ground: Callable) -> Array:
	var tops: Array = []
	var rows: Array = ParkRecipes.placed_rows(park)
	var posts := ParkRecipes.field_posts(rows, ParkRecipes.clear_zones(park))
	for i: int in posts:
		var row: Dictionary = rows[i]
		var rise := float(row["size"][1])
		if rise < PERCH_MIN or rise > PERCH_MAX:
			continue
		for post: Vector2 in posts[i]:
			tops.append(Vector3(post.x, float(ground.call(post.x, post.y)) + rise, post.y))
	tops.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.x < b.x or (a.x == b.x and a.z < b.z))
	return tops


static func blockers(park: Dictionary) -> Array:
	return ParkRecipes.clear_zones(park).filter(func(z: Dictionary) -> bool: return not z.has("a"))


static func valid(top: Vector3, ground: Callable, blocked: Array) -> bool:
	var rise := top.y - float(ground.call(top.x, top.z))
	if rise < PERCH_MIN - 0.001 or rise > PERCH_MAX + 0.001:
		return false
	return not ParkRecipes.in_clear(blocked, Vector2(top.x, top.z), DECK_CLEAR)


static func pick(tops: Array, near: Vector3, ground: Callable, blocked: Array, salt := 0, ledges: Array = []) -> Vector3:
	var far: Array = []
	var close: Array = []
	var from := Vector2(near.x, near.z)
	for top: Vector3 in tops:
		var d := Vector2(top.x, top.z).distance_to(from)
		if d > RANGE_M or not valid(top, ground, blocked):
			continue
		(far if d >= STAND_OFF else close).append(top)
	for ledge: Vector4 in ledges:
		var d := Vector2(ledge.x, ledge.z).distance_to(from)
		if d > RANGE_M or not valid_ledge(ledge):
			continue
		(far if d >= STAND_OFF else close).append(Vector3(ledge.x, ledge.y, ledge.z))
	var pool := far if not far.is_empty() else close
	if pool.is_empty():
		return Vector3.INF
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([salt, roundi(near.x), roundi(near.z)])
	return pool[rng.randi_range(0, pool.size() - 1)]


const Stamps := preload("res://src/world/park/park_stamps.gd")

const RINGS := [8.0, 14.0, 24.0]
const RING_STEPS := 8
const LEVEL_M := 1.5
const DECK_HALF := 1.8
const PITCH_M := 10.0
const MIN_STAMP_M := 4.0
const SMALL_M := 90.0
const BELT_M := 6.0
const ZONE_CELL_M := 32.0
const BELT_STEP_M := 16.0
const SPACING_M := 14.0
const PLAY_INSET_M := 10.0
const LEDGE_ELEMENTS := ["ledge"]
const LEDGE_FIT_M := 5.0


static func valid_ledge(ledge: Vector4) -> bool:
	var rise := ledge.y - ledge.w
	return rise >= PERCH_MIN - 0.001 and rise <= PERCH_MAX + 0.001


static func ledge_zones(park: Dictionary) -> Array:
	var out: Array = []
	for zone: Dictionary in ParkRecipes.clear_zones(park):
		if zone.has("a"):
			out.append(["", zone])
	for row: Dictionary in park.get("park_rows", []):
		if row["element"] == "ground" or row["element"] == "anchor_field" or String(row.get("stamp", "")) != "":
			continue
		out.append([String(row["id"]), _rect_zone(row)])
	var mark: Dictionary = park.get("landmark", {})
	if not mark.is_empty():
		out.append(["", _rect_zone(mark)])
	return out


static func _rect_zone(row: Dictionary) -> Dictionary:
	return {"at": Vector2(float(row["at"][0]), float(row["at"][1])), "size": Vector2(float(row["size"][0]), float(row["size"][2])), "yaw": deg_to_rad(float(row.get("yaw_deg", 0.0)))}


static func ledge_clear(zones: Array, p: Vector2, own := "") -> bool:
	return not ParkRecipes.in_clear(_zone_list(zones, own), p, DECK_CLEAR)


static func _zone_list(zones: Array, own := "") -> Array:
	var hit: Array = []
	for entry: Array in zones:
		if own == "" or entry[0] != own:
			hit.append(entry[1])
	return hit


static func _zone_grid(zones: Array, r: float) -> Dictionary:
	var grid := {}
	for z: Dictionary in zones:
		var c: Vector2
		var reach: float
		if z.has("a"):
			var a: Vector2 = z["a"]
			var b: Vector2 = z["b"]
			c = (a + b) * 0.5
			reach = a.distance_to(b) * 0.5 + float(z["half"]) + r
		else:
			c = z["at"]
			reach = (z["size"] as Vector2).length() * 0.5 + r * 1.5
		for x in range(floori((c.x - reach) / ZONE_CELL_M), floori((c.x + reach) / ZONE_CELL_M) + 1):
			for y in range(floori((c.y - reach) / ZONE_CELL_M), floori((c.y + reach) / ZONE_CELL_M) + 1):
				var cell := Vector2i(x, y)
				if not grid.has(cell):
					grid[cell] = []
				grid[cell].append(z)
	return grid


static func _zone_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / ZONE_CELL_M), floori(p.y / ZONE_CELL_M))


static func ledges(park: Dictionary, ground: Callable) -> Array:
	return thin(found(park, ground))


const REACH_M := 24.0 + DECK_HALF * 1.5


static func patched_ledges(park: Dictionary, ground: Callable, bare_found: Array, discs: Array) -> Array:
	var near := func(p: Vector2) -> bool:
		for disc: Vector3 in discs:
			if p.distance_to(Vector2(disc.x, disc.y)) <= disc.z + REACH_M:
				return true
		return false
	var out := bare_found.filter(func(top: Vector4) -> bool: return not near.call(Vector2(top.x, top.z)))
	out.append_array(found(park, ground, func(p: Vector2) -> bool: return not near.call(p)))
	return thin(out)


static func found(park: Dictionary, ground: Callable, skip := Callable()) -> Array:
	var zones := ledge_zones(park)
	var r: Array = park.get("play_rect", [-100000.0, -100000.0, 200000.0, 200000.0])
	var play := Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])).grow(-PLAY_INSET_M)
	var found: Array = []
	var near := _zone_grid(_zone_list(zones), DECK_CLEAR)
	for row: Dictionary in park.get("park_rows", []):
		if String(row.get("stamp", "")) != "":
			if absf(float(row["size"][1])) < MIN_STAMP_M:
				continue
			for p: Vector2 in _samples(row):
				if skip.is_valid() and skip.call(p):
					continue
				if play.has_point(p) and not ParkRecipes.in_clear(near.get(_zone_cell(p), []), p, DECK_CLEAR):
					var top := _ring_top(p, ground)
					if top.x != INF:
						found.append(top)
		elif LEDGE_ELEMENTS.has(String(row["element"])) and String(row.get("stamp", "")) == "" and row.get("y") == null:
			var size: Array = row["size"]
			var rise := float(size[1])
			var at := Vector2(float(row["at"][0]), float(row["at"][1]))
			if skip.is_valid() and skip.call(at):
				continue
			if rise >= PERCH_MIN and rise <= PERCH_MAX and minf(float(size[0]), float(size[2])) >= LEDGE_FIT_M \
					and play.has_point(at) and ledge_clear(zones, at, String(row["id"])):
				var base := float(ground.call(at.x, at.y))
				found.append(Vector4(at.x, base + rise, at.y, base))
	return found


static func thin(found: Array) -> Array:
	found = found.duplicate()
	found.sort_custom(func(a: Vector4, b: Vector4) -> bool: return a.x < b.x or (a.x == b.x and a.z < b.z))
	var kept: Array = []
	var cells := {}
	for top: Vector4 in found:
		var cell := Vector2i(floori(top.x / SPACING_M), floori(top.z / SPACING_M))
		var crowded := false
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				for other: Vector4 in cells.get(cell + Vector2i(dx, dz), []):
					if Vector2(top.x, top.z).distance_to(Vector2(other.x, other.z)) < SPACING_M:
						crowded = true
		if not crowded:
			kept.append(top)
			if not cells.has(cell):
				cells[cell] = []
			cells[cell].append(top)
	return kept


static func _ring_top(p: Vector2, ground: Callable) -> Vector4:
	var none := Vector4(INF, INF, INF, INF)
	var c := float(ground.call(p.x, p.y))
	var base := c
	for radius in RINGS:
		var low := c
		for k in RING_STEPS:
			var a := TAU * k / RING_STEPS
			low = minf(low, float(ground.call(p.x + cos(a) * radius, p.y + sin(a) * radius)))
		if c - low > PERCH_MAX:
			return none
		if c - low >= PERCH_MIN:
			base = low
			break
	if c - base < PERCH_MIN:
		return none
	var lo := c
	var hi := c
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var g := float(ground.call(p.x + corner.x * DECK_HALF, p.y + corner.y * DECK_HALF))
		lo = minf(lo, g)
		hi = maxf(hi, g)
	if hi - lo > LEVEL_M:
		return none
	return Vector4(p.x, c, p.y, base)


static func _samples(row: Dictionary) -> Array:
	var f := Stamps.frame(row)
	var length: float = f["length"]
	var width: float = f["width"]
	var at: Vector2 = f["at"]
	var along: Vector2 = f["along"]
	var across: Vector2 = f["across"]
	var out: Array = [at]
	if maxf(length, width) <= SMALL_M:
		var nl := int((length * 0.5 + BELT_M) / PITCH_M)
		var nw := int((width * 0.5 + BELT_M) / PITCH_M)
		for i in range(-nl, nl + 1):
			for j in range(-nw, nw + 1):
				if i != 0 or j != 0:
					out.append(at + along * (i * PITCH_M) + across * (j * PITCH_M))
		return out
	for belt: float in [-BELT_M, BELT_M]:
		var hl := length * 0.5 + belt
		var hw := width * 0.5 + belt
		if hl <= 0.0 or hw <= 0.0:
			continue
		if f["ellipse"]:
			var steps := maxi(8, int(TAU * maxf(hl, hw) / BELT_STEP_M))
			for k in steps:
				var a := TAU * k / steps
				out.append(at + along * (cos(a) * hl) + across * (sin(a) * hw))
			continue
		for i in range(int(2.0 * hl / BELT_STEP_M) + 1):
			var a := -hl + i * BELT_STEP_M
			for sign_w in [-1.0, 1.0]:
				out.append(at + along * a + across * (sign_w * hw))
		for j in range(int(2.0 * hw / BELT_STEP_M) + 1):
			var b := -hw + j * BELT_STEP_M
			for sign_l in [-1.0, 1.0]:
				out.append(at + along * (sign_l * hl) + across * b)
	return out
