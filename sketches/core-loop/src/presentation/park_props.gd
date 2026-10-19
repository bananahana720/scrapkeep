extends Node3D

# Park prop dressing (Dressing lane, design-v3/park/DRESSING-KITS.md). Each park has a kit of GLB props
# (assets/models/park/props/<park>/manifest.json) and a vignette file (src/world/park/props/park_<park>.json):
# templates of props, spots that place a template on the ground, and a sparse litter layer walked along the
# authored lines. expand() turns the file into seated instances, validate() judges them against the contract's
# placement rules, and build_nodes() batches them into MultiMesh views with visibility ranges. Both are static
# and pure, so a test or tool runs them without a game. Nothing here collides or moves a run.
#
# Vignette file (scrapkeep-park-props/1):
#   {"schema", "map": "park_dam", "kit": "res://.../manifest.json",
#    "templates": {"<tid>": {"story", "props": [{"kind", "v": "a" or "*", "at": [dx, dz], "yaw_deg", "scale", "tilt_deg"}]}},
#    "spots": [{"id", "template", "at": [x, z], "yaw_deg", "near"}],
#    "litter": {"kinds": [{"kind", "weight"}], "spacing_m", "band_m": [near, far], "seed"}}
# Kit manifest (scrapkeep-park-props-kit/1): kinds -> {class, tags, story, variants -> {lod [3 GLBs], tris [3], radius, height}}.

const ParkSites := preload("res://src/presentation/park_sites.gd")
const SetDressing := preload("res://src/presentation/set_dressing.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const ParkTerrain := preload("res://src/world/park/park_terrain.gd")
const Terrain := preload("res://src/world/terrain.gd")
const Preset := preload("res://src/presentation/graphics_preset.gd")

const FILE_SCHEMA := "scrapkeep-park-props/1"
const KIT_SCHEMA := "scrapkeep-park-props-kit/1"
const FILE_DIR := "res://src/world/park/props/"
const LINES_PATH := "res://assets/park/%s/lines.json"
# Stage numbers of the park table (park_dressing_pin_test's order), for the stage's device keepouts.
const PARKS := ["park_dam", "park_flume", "park_pit", "park_sinkhole", "park_islands", "park_crown"]
const HERO := "dress_hero"
const PROP := "dress_prop"
const GROUP := "park_props"
const LOW_PRESET := "low"

# Placement minimums (the contract's "Placement" rules), in metres and degrees.
const LINE_CLEAR_M := 15.0
const LINE_CLEAR_TALL_M := 30.0
const TALL_HEIGHT_M := 3.0
const NEAR_LINE_M := 30.0
const NEAR_LINE_MAX_HEIGHT_M := 1.5
const HOME_CLEAR_M := 25.0
const SLOPE_MAX_DEG := 25.0
const SEAT_FLOAT_MAX_M := 0.15
const SMALL_RADIUS_M := 0.6
const ALIGN_MAX_DEG := 12.0
const LINE_REACH_M := 64.0
const LITTER_CHUNK_M := 160.0
const LITTER_GAP_RATIO := 0.5
const CAMP_ACTIVITIES := ["enemy_camp"]

# Visibility ranges by class, LOD0 to LOD2: [begin, end] metres (the contract's "Frame cost").
const HERO_RANGES := [[0.0, 70.0], [70.0, 180.0], [180.0, 450.0]]
const PROP_RANGES := [[0.0, 35.0], [35.0, 90.0], [90.0, 200.0]]
const LITTER_RANGE := [0.0, 70.0]
const HERO_MARGIN_M := 8.0
const PROP_MARGIN_M := 3.0
const LOW_RANGE_SCALE := 0.5
const BUILD_SLICE_USEC := 3000

static var file_overrides := {}
static var _meshes := {}
static var _cache_owner := ""

var ctx
var map_id := ""
var instances: Array = []
var views: Array[GeometryInstance3D] = []
# The main-thread time of the last stage entry's build, for stage_entry_budget_test.
var last_entry_usec := 0
var _built_for := []
var _pending := false
var _task := -1
var _out := {}
var _jobs: Array = []
var _kit := {}
var _low := false


# What the placement rules read of a park, built once: the lines' legs, the route lanes, the keepouts
# (ParkSites), the homes and camps.
class Context:
	extends RefCounted
	var map
	var map_id := ""
	var ground: Callable
	var rect := Rect2()
	var sites
	var lanes: Array = []
	# name -> PackedVector2Array of a line's points, floor last.
	var lines := {}
	var homes: Array = []
	var camps: Array[Vector2] = []
	var spawn := Vector2.ZERO
	# Home sites and line waypoints that resolve to no place: file_errors-style rows, surfaced by --check and the test.
	var unresolved: Array = []
	var _cells := {}

	func line_distance(p: Vector2) -> float:
		var best := INF
		for leg: Vector4 in _cells.get(_cell(p), []):
			var a := Vector2(leg.x, leg.y)
			var b := Vector2(leg.z, leg.w)
			best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)))
		return best

	func add_leg(a: Vector2, b: Vector2) -> void:
		var low := _cell(Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2.ONE * LINE_REACH_M)
		var high := _cell(Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2.ONE * LINE_REACH_M)
		for x in range(low.x, high.x + 1):
			for y in range(low.y, high.y + 1):
				var key := Vector2i(x, y)
				if not _cells.has(key):
					_cells[key] = []
				_cells[key].append(Vector4(a.x, a.y, b.x, b.y))

	static func _cell(p: Vector2) -> Vector2i:
		return Vector2i(floori(p.x / LINE_REACH_M), floori(p.y / LINE_REACH_M))


# --- Worlds, contexts and files -----------------------------------------------------------------

# The stage number of a park map id (1 to 6), 0 when it is not on the park table.
static func stage_of(id: String) -> int:
	return PARKS.find(id) + 1


# A park without a running game: {"map", "ground", "stage"} from its park file and committed bake.
# The ground is terrain.gd's park ground over the bake (ground.bin, holes.bin, under.bin), as the game reads it.
static func world_for(id: String) -> Dictionary:
	var map := ParkMap.new("res://src/world/park/%s.json" % id)
	var dir := ParkTerrain.bake_dir(id)
	var heights := ParkTerrain._read_zstd(dir + "/ground.bin", ParkTerrain.SIDE * ParkTerrain.SIDE * 4).to_float32_array()
	var holes := FileAccess.get_file_as_bytes(dir + "/holes.bin")
	var floors := FileAccess.get_file_as_bytes(dir + "/under.bin").to_float32_array()
	var under := PackedFloat32Array()
	under.resize(ParkTerrain.CELLS * ParkTerrain.CELLS)
	var n := 0
	for k in holes.size():
		if holes[k] == 1:
			under[k] = floors[n]
			n += 1
	return {"map": map, "ground": Terrain._park_ground_at.bind(heights, holes, under), "stage": stage_of(id)}


static func file_path(id: String) -> String:
	return String(file_overrides.get(id, FILE_DIR + id + ".json"))


static func load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


static func context(park_map, ground: Callable, stage := -1) -> Context:
	var c := Context.new()
	c.map = park_map
	c.ground = ground
	c.map_id = String(park_map.park.get("map", ""))
	c.rect = park_map.play_rect
	c.spawn = park_map.spawn
	var st: int = stage_of(c.map_id) if stage < 0 else stage
	c.sites = ParkSites.new(park_map, ground, st)
	c.lanes = ParkRecipes.clear_zones(park_map.park).filter(func(z: Dictionary) -> bool: return z.has("a"))
	var lines := load_json(LINES_PATH % c.map_id)
	var named: Dictionary = (lines.get("pilots", {}) as Dictionary).duplicate()
	var keys := named.keys()
	keys.sort()
	var ordered := {}
	for key in keys:
		ordered[key] = named[key]
	ordered["floor"] = lines.get("floor", {})
	for key in ordered:
		var pts := PackedVector2Array()
		for point in ordered[key].get("waypoints", []):
			var at := _place(park_map.park, point) if point is String else _pair(point)
			if at != Vector2.INF:
				pts.append(at)
			else:
				c.unresolved.append("lines.json %s waypoint %s resolves to no place" % [key, str(point)])
		if pts.size() > 1:
			c.lines[key] = pts
			for i in range(1, pts.size()):
				c.add_leg(pts[i - 1], pts[i])
	for home: Dictionary in park_map.park.get("home_rows", []):
		var site := String(home.get("site", ""))
		var found := {}
		for row: Dictionary in park_map.park.get("park_rows", []):
			if row["id"] == site:
				found = row
				break
		if found.is_empty():
			for row: Dictionary in park_map.park.get("activity_rows", []):
				if row["id"] == site:
					found = {"at": row["at"], "point": true}
					break
		if not found.is_empty():
			c.homes.append({"id": String(home.get("id", site)), "row": found})
		else:
			c.unresolved.append("home_rows site %s (home %s) names no park or activity row" % [site, String(home.get("id", site))])
	for row: Dictionary in park_map.park.get("activity_rows", []):
		if String(row.get("activity", "")) in CAMP_ACTIVITIES:
			c.camps.append(_pair(row["at"]))
	return c


static func _pair(value) -> Vector2:
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.INF


# traversal_line.gd place_of: drop_in is the spawn, landmark its beacon, other ids a park row's or activity's at.
static func _place(park: Dictionary, id: String) -> Vector2:
	if id == "drop_in":
		return _pair(park.get("spawn", {}).get("at"))
	if id == "landmark":
		return _pair(park.get("landmark", {}).get("beacon"))
	for table in ["park_rows", "activity_rows"]:
		for row in park.get(table, []):
			if row is Dictionary and row.get("id") == id:
				return _pair(row.get("at"))
	return Vector2.INF


# --- Schema ---------------------------------------------------------------------------------------

# Rows of text for a vignette file that breaks its schema or names a kind or variant the kit lacks.
static func file_errors(file: Dictionary, kit: Dictionary) -> Array:
	var errors := []
	if file.get("schema") != FILE_SCHEMA:
		errors.append("schema is not " + FILE_SCHEMA)
	if not file.get("map") is String or not String(file.get("map", "")).begins_with("park_"):
		errors.append("map is not a park id")
	if not file.get("kit") is String:
		errors.append("kit is not a path")
	var kinds: Dictionary = kit.get("kinds", {}) if kit.get("kinds") is Dictionary else {}
	var templates = file.get("templates")
	if not templates is Dictionary or (templates as Dictionary).is_empty():
		errors.append("templates is empty")
		templates = {}
	for tid in templates:
		var props = templates[tid].get("props") if templates[tid] is Dictionary else null
		if not props is Array or (props as Array).is_empty():
			errors.append("template %s has no props" % tid)
			continue
		for i in (props as Array).size():
			var prop = props[i]
			var label := "template %s prop %d" % [tid, i]
			if not prop is Dictionary:
				errors.append(label + " is not an object")
				continue
			errors.append_array(_kind_errors(label, kinds, prop.get("kind"), prop.get("v")))
			if _pair(prop.get("at")) == Vector2.INF:
				errors.append(label + " has no at [dx, dz]")
			for key in ["yaw_deg", "scale", "tilt_deg"]:
				if prop.has(key) and not (prop[key] is float or prop[key] is int):
					errors.append("%s %s is not a number" % [label, key])
			if prop.has("scale") and float(prop["scale"]) <= 0.0:
				errors.append(label + " scale is not positive")
	var spots = file.get("spots")
	if not spots is Array or (spots as Array).is_empty():
		errors.append("spots is empty")
		spots = []
	var seen := {}
	for spot in spots:
		if not spot is Dictionary or not spot.get("id") is String or String(spot.get("id")).is_empty():
			errors.append("a spot has no id")
			continue
		var id := String(spot["id"])
		if seen.has(id):
			errors.append("spot id %s repeats" % id)
		seen[id] = true
		if not templates.has(spot.get("template", "")):
			errors.append("spot %s names no template" % id)
		if _pair(spot.get("at")) == Vector2.INF:
			errors.append("spot %s has no at [x, z]" % id)
	var litter = file.get("litter")
	if litter is Dictionary:
		if not (litter.get("spacing_m") is float or litter.get("spacing_m") is int) or float(litter.get("spacing_m", 0.0)) <= 0.0:
			errors.append("litter spacing_m is not positive")
		var band = litter.get("band_m")
		if not band is Array or (band as Array).size() != 2 or float(band[0]) < 0.0 or float(band[1]) < float(band[0]):
			errors.append("litter band_m is not [near, far]")
		if not litter.get("seed") is float and not litter.get("seed") is int:
			errors.append("litter seed is not a number")
		if not litter.get("kinds") is Array or (litter.get("kinds") as Array).is_empty():
			errors.append("litter kinds is empty")
		else:
			for row in litter["kinds"]:
				errors.append_array(_kind_errors("litter", kinds, row.get("kind") if row is Dictionary else null, "*"))
				if not row is Dictionary or float(row.get("weight", 0.0)) <= 0.0:
					errors.append("litter kind weight is not positive")
	elif file.has("litter"):
		errors.append("litter is not an object")
	return errors


static func _kind_errors(label: String, kinds: Dictionary, kind, v) -> Array:
	if not kind is String or not kinds.has(kind):
		return ["%s names kind %s, which the kit lacks" % [label, str(kind)]]
	if String(v) != "*" and not (kinds[kind].get("variants", {}) as Dictionary).has(String(v)):
		return ["%s names variant %s of %s, which the kit lacks" % [label, str(v), kind]]
	return []


# Rows of text for a kit manifest that breaks its schema: class, tags, three existing LODs, tris, radius, height.
static func kit_errors(kit: Dictionary, min_kinds := 0, min_variants := 1) -> Array:
	var errors := []
	if kit.get("schema") != KIT_SCHEMA:
		errors.append("kit schema is not " + KIT_SCHEMA)
	var kinds = kit.get("kinds")
	if not kinds is Dictionary:
		return errors + ["kit has no kinds"]
	if (kinds as Dictionary).size() < min_kinds:
		errors.append("kit has %d kinds, want at least %d" % [(kinds as Dictionary).size(), min_kinds])
	for kind in kinds:
		var def = kinds[kind]
		if not def is Dictionary or not def.get("class") in [HERO, PROP]:
			errors.append("kind %s has no class dress_hero or dress_prop" % kind)
			continue
		if not def.get("tags") is Array:
			errors.append("kind %s has no tags" % kind)
		var variants = def.get("variants")
		if not variants is Dictionary or (variants as Dictionary).size() < min_variants:
			errors.append("kind %s has fewer than %d variants" % [kind, min_variants])
			continue
		for v in variants:
			var row = variants[v]
			var label := "%s/%s" % [kind, v]
			if not row is Dictionary or not row.get("lod") is Array or (row["lod"] as Array).size() != 3 or not row.get("tris") is Array or (row["tris"] as Array).size() != 3:
				errors.append(label + " lacks three lod paths and three tris")
				continue
			for path in row["lod"]:
				if not ResourceLoader.exists(String(path)):
					errors.append("%s lod %s does not exist" % [label, str(path)])
			if float(row.get("radius", 0.0)) <= 0.0 or float(row.get("height", 0.0)) <= 0.0:
				errors.append(label + " has no radius or height")
	return errors


# --- Expand ---------------------------------------------------------------------------------------

# The instances of a vignette file on a park: every spot's template props, then the litter. Each is
# {vignette, kind, v, class, tags, pos (the foot on the ground), basis (rotation), scale, radius, height (both scaled),
# litter, float_m (how far the lowest rim sample stands above the ground), slope_deg}. Pure and deterministic:
# a spot's variant picks are seeded from its id, the litter from litter.seed. Vignette props are kept as authored;
# litter is dropped when it fails validate().
static func expand(file: Dictionary, kit: Dictionary, park_map, ground: Callable, c: Context = null) -> Array:
	if c == null:
		c = context(park_map, ground)
	var out := []
	var id := String(file.get("map", ""))
	var templates: Dictionary = file.get("templates", {})
	var spots: Array = file.get("spots", [])
	for spot: Dictionary in spots:
		var template = templates.get(spot.get("template", ""))
		if not template is Dictionary:
			continue
		var origin := _pair(spot["at"])
		var spot_yaw := deg_to_rad(float(spot.get("yaw_deg", 0.0)))
		var props: Array = template.get("props", [])
		for i in props.size():
			var prop: Dictionary = props[i]
			var variants: Dictionary = kit["kinds"][prop["kind"]]["variants"]
			var rng := RandomNumberGenerator.new()
			rng.seed = hash("%s|%s|%d" % [id, spot["id"], i])
			var v := String(prop.get("v", "*"))
			if v == "*":
				var keys := variants.keys()
				keys.sort()
				v = String(keys[rng.randi() % keys.size()])
			var offset := Vector3(_pair(prop["at"]).x, 0.0, _pair(prop["at"]).y)
			var flat := Basis(Vector3.UP, spot_yaw) * offset
			out.append(_instance(String(spot["id"]), String(prop["kind"]), v, kit, Vector2(origin.x + flat.x, origin.y + flat.z),
				spot_yaw + deg_to_rad(float(prop.get("yaw_deg", 0.0))), float(prop.get("scale", 1.0)), deg_to_rad(float(prop.get("tilt_deg", 0.0))), ground, false))
	var litter = file.get("litter")
	if litter is Dictionary:
		out.append_array(_litter(litter, id, kit, c, ground))
	return out


static func _instance(vignette: String, kind: String, v: String, kit: Dictionary, at: Vector2, yaw: float, scale: float, tilt: float, ground: Callable, litter: bool) -> Dictionary:
	var def: Dictionary = kit["kinds"][kind]
	var row: Dictionary = def["variants"][v]
	var radius := float(row["radius"]) * scale
	var height := float(row["height"]) * scale
	var y := _height(ground, at)
	if radius > SMALL_RADIUS_M:
		for k in 4:
			y = minf(y, _height(ground, at + Vector2.from_angle(k * TAU / 4.0) * radius))
	var up := Vector3.UP
	if radius <= SMALL_RADIUS_M:
		var n := _normal(ground, at, 0.5)
		var lean := minf(acos(clampf(n.y, -1.0, 1.0)), deg_to_rad(ALIGN_MAX_DEG))
		var axis := Vector3.UP.cross(n)
		if lean > 0.0001 and axis.length() > 0.0001:
			up = Vector3.UP.rotated(axis.normalized(), lean)
	var basis := Basis(Vector3.UP, yaw)
	if absf(tilt) > 0.0:
		basis = basis * Basis(Vector3.RIGHT, tilt)
	if up != Vector3.UP:
		var axis := Vector3.UP.cross(up).normalized()
		basis = Basis(axis, acos(clampf(up.y, -1.0, 1.0))) * basis
	var floating := 0.0
	var steepest := rad_to_deg(acos(clampf(_normal(ground, at, clampf(radius * 0.5, 0.5, 2.0)).y, -1.0, 1.0)))
	var span := clampf(radius * 0.5, 0.5, 2.0)
	if radius > SMALL_RADIUS_M:
		for k in 8:
			var rim := at + Vector2.from_angle(k * TAU / 8.0) * radius
			floating = maxf(floating, y - _height(ground, rim))
			steepest = maxf(steepest, rad_to_deg(acos(clampf(_normal(ground, rim, span).y, -1.0, 1.0))))
	return {"vignette": vignette, "kind": kind, "v": v, "class": String(def["class"]), "tags": (def.get("tags", []) as Array).duplicate(),
		"pos": Vector3(at.x, y, at.y), "basis": basis, "scale": scale, "radius": radius, "height": height, "litter": litter,
		"float_m": floating, "slope_deg": steepest}


static func _height(ground: Callable, at: Vector2) -> float:
	return (ground.call(at.x, at.y, 0.0) as Vector3).y


static func _normal(ground: Callable, at: Vector2, span: float) -> Vector3:
	var dx := _height(ground, at + Vector2(span, 0.0)) - _height(ground, at - Vector2(span, 0.0))
	var dz := _height(ground, at + Vector2(0.0, span)) - _height(ground, at - Vector2(0.0, span))
	return Vector3(-dx, 2.0 * span, -dz).normalized()


# Litter: walk every line (pilots in name order, then the floor line); every spacing_m place one item at a seeded
# lateral offset inside band_m on a seeded side, a weighted kind. Every draw is made before the item is judged, so a
# drop never moves the next item. An item that fails validate() is dropped, as is one within spacing_m * 0.5 of a
# litter item already placed (seven lines share most of their way).
static func _litter(litter: Dictionary, id: String, kit: Dictionary, c: Context, ground: Callable) -> Array:
	var out := []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|litter|%d" % [id, int(litter.get("seed", 0))])
	var spacing := float(litter["spacing_m"])
	var band: Array = litter["band_m"]
	var kinds: Array = litter["kinds"]
	var total := 0.0
	for row: Dictionary in kinds:
		total += float(row["weight"])
	var placed: Array[Vector2] = []
	for key in c.lines:
		var pts: PackedVector2Array = c.lines[key]
		var carried := rng.randf_range(0.0, spacing)
		for i in range(1, pts.size()):
			var along := (pts[i] - pts[i - 1])
			var length := along.length()
			if length < 0.001:
				continue
			var dir := along / length
			var side_dir := Vector2(-dir.y, dir.x)
			var d := spacing - carried if carried > 0.0 else spacing
			while d <= length:
				var side := -1.0 if rng.randf() < 0.5 else 1.0
				var lateral := rng.randf_range(float(band[0]), float(band[1]))
				var pick := rng.randf() * total
				var vr := rng.randi()
				var yaw := rng.randf_range(0.0, TAU)
				var scale := rng.randf_range(0.9, 1.15)
				var at := pts[i - 1] + dir * d + side_dir * side * lateral
				d += spacing
				var kind := String((kinds[0] as Dictionary)["kind"])
				var acc := 0.0
				for row: Dictionary in kinds:
					acc += float(row["weight"])
					if pick <= acc:
						kind = String(row["kind"])
						break
				if placed.any(func(other: Vector2) -> bool: return other.distance_to(at) < spacing * LITTER_GAP_RATIO):
					continue
				var variants: Dictionary = kit["kinds"][kind]["variants"]
				var names := variants.keys()
				names.sort()
				var inst := _instance("litter", kind, String(names[vr % names.size()]), kit, at, yaw, scale, 0.0, ground, true)
				if not check_one(inst, c).is_empty():
					continue
				placed.append(at)
				out.append(inst)
			carried = fmod(carried + length, spacing)
	return out


# --- Validate -------------------------------------------------------------------------------------

# Violations {vignette, kind, pos, rule, detail} of the placement rules: line_clear, route_lane, keepout, home_clear,
# play_rect, slope, seat. Empty means every instance is placeable.
static func validate(list: Array, park_map, ground: Callable, stage := -1, c: Context = null) -> Array:
	if c == null:
		c = context(park_map, ground, stage)
	var out := []
	for inst: Dictionary in list:
		out.append_array(check_one(inst, c))
	return out


static func check_one(inst: Dictionary, c: Context) -> Array:
	var out := []
	var pos: Vector3 = inst["pos"]
	var p := Vector2(pos.x, pos.z)
	var r: float = inst["radius"]
	var height: float = inst["height"]
	var hero: bool = inst["class"] == HERO
	var tall: bool = hero or height > TALL_HEIGHT_M or "tall" in inst["tags"]
	var fail := func(rule: String, detail: String) -> void:
		out.append({"vignette": inst["vignette"], "kind": inst["kind"], "pos": pos, "rule": rule, "detail": detail})
	var edge := c.line_distance(p) - r
	if edge < LINE_CLEAR_M:
		fail.call("line_clear", "%.1f m from a line, want %.0f" % [edge, LINE_CLEAR_M])
	elif tall and edge < LINE_CLEAR_TALL_M:
		fail.call("line_clear", "tall or hero, %.1f m from a line, want %.0f" % [edge, LINE_CLEAR_TALL_M])
	elif edge < NEAR_LINE_M and height > NEAR_LINE_MAX_HEIGHT_M:
		fail.call("line_clear", "%.1f m tall at %.1f m from a line, want under %.1f m tall inside %.0f" % [height, edge, NEAR_LINE_MAX_HEIGHT_M, NEAR_LINE_M])
	if ParkRecipes.in_clear(c.lanes, p, r):
		fail.call("route_lane", "inside a route lane")
	if not c.rect.grow(-r).has_point(p):
		fail.call("play_rect", "outside the play rect")
	else:
		var margin := clampf(r + ParkSites.MARGIN, ParkSites.MARGIN, ParkSites.MARGIN_MAX)
		if not c.sites.clear(p, margin):
			var what := SetDressing.blocked(c.sites._keepouts, p, margin)
			fail.call("keepout", "within %.1f m of %s" % [margin, what if what != "" else "a built row footprint"])
	for home: Dictionary in c.homes:
		var row: Dictionary = home["row"]
		var near := false
		if row.has("point"):
			near = _pair(row["at"]).distance_to(p) < HOME_CLEAR_M + r
		else:
			near = ParkMap.footprint_contains(row, p, HOME_CLEAR_M + r)
		if near:
			fail.call("home_clear", "within %.0f m of home %s" % [HOME_CLEAR_M, home["id"]])
	for camp in c.camps:
		if camp.distance_to(p) < HOME_CLEAR_M + r:
			fail.call("home_clear", "within %.0f m of an enemy camp" % HOME_CLEAR_M)
	var slope := float(inst["slope_deg"])
	if slope > SLOPE_MAX_DEG:
		fail.call("slope", "%.1f degrees under the footprint, want at most %.0f" % [slope, SLOPE_MAX_DEG])
	var floating := float(inst["float_m"])
	if floating > SEAT_FLOAT_MAX_M:
		fail.call("seat", "%.2f m floats off the ground, want at most %.2f" % [floating, SEAT_FLOAT_MAX_M])
	return out


# A hash of the instances' kinds, variants and exact placements, for the determinism pins.
static func fingerprint(list: Array) -> int:
	var parts := []
	for inst: Dictionary in list:
		parts.append([inst["vignette"], inst["kind"], inst["v"], inst["pos"], inst["basis"], inst["scale"]])
	return hash(var_to_bytes(parts))


# --- Build ----------------------------------------------------------------------------------------

# The finished nodes for a list of instances: a Node3D per vignette, a MultiMeshInstance3D per (mesh, LOD) for props, a
# MeshInstance3D per LOD for each hero, litter batched per LITTER_CHUNK_M chunk on LOD1. low is the lowest preset: no
# litter and the props' LOD0 and LOD1 ends halved.
static func build_nodes(list: Array, kit: Dictionary, low := false) -> Node3D:
	var root := Node3D.new()
	root.name = "Content"
	for job: Dictionary in jobs(list, low):
		build_job(root, job, kit, low)
	return root


# The build in pieces a node can spread over frames: one job per vignette, then one for the litter (none on low).
static func jobs(list: Array, low := false) -> Array:
	var by_vignette := {}
	var out := []
	var litter := []
	for inst: Dictionary in list:
		if inst["litter"]:
			litter.append(inst)
			continue
		if not by_vignette.has(inst["vignette"]):
			by_vignette[inst["vignette"]] = {"name": "Vignette_" + String(inst["vignette"]), "members": [], "litter": false}
			out.append(by_vignette[inst["vignette"]])
		by_vignette[inst["vignette"]]["members"].append(inst)
	if not litter.is_empty() and not low:
		out.append({"name": "Litter", "members": litter, "litter": true})
	return out


# Builds one job's holder under parent and returns it.
static func build_job(parent: Node3D, job: Dictionary, kit: Dictionary, low: bool) -> Node3D:
	var holder := Node3D.new()
	holder.name = job["name"]
	parent.add_child(holder)
	var groups := {}
	var keys := []
	for inst: Dictionary in job["members"]:
		if inst["class"] == HERO:
			_hero(holder, inst, kit)
			continue
		var pos: Vector3 = inst["pos"]
		var key := "%s_%s" % [inst["kind"], inst["v"]]
		if job["litter"]:
			key = "%d_%d_%s" % [floori(pos.x / LITTER_CHUNK_M), floori(pos.z / LITTER_CHUNK_M), key]
		if not groups.has(key):
			groups[key] = []
			keys.append(key)
		groups[key].append(inst)
	for key in keys:
		var first: Dictionary = groups[key][0]
		var lods := _lod_paths(kit, first)
		if job["litter"]:
			_batch(holder, "Litter_" + String(key), _mesh(lods[1]), groups[key], first, 1, LITTER_RANGE, PROP_MARGIN_M, true)
			continue
		for lod in 3:
			_batch(holder, "%s_L%d" % [key, lod], _mesh(lods[lod]), groups[key], first, lod, _range(PROP_RANGES[lod], low, lod), PROP_MARGIN_M, false)
	return holder


# Loads every mesh a list needs into the cache (safe on a worker: the node reads it only after the worker is done).
static func warm(list: Array, kit: Dictionary, low: bool) -> void:
	for inst: Dictionary in list:
		var lods := _lod_paths(kit, inst)
		if inst["litter"]:
			if not low:
				_mesh(lods[1])
			continue
		for path in lods:
			_mesh(path)


# Everything a stage needs before it can build nodes, pure so a worker can draw it: the file, its kit, the schema
# errors (empty when usable) and the instances. {} when the park has no file.
static func prepare(id: String, park_map, ground: Callable, stage: int, low: bool) -> Dictionary:
	var file := load_json(file_path(id))
	if file.is_empty():
		return {}
	var kit := load_json(String(file.get("kit", "")))
	var errors := kit_errors(kit) + file_errors(file, kit)
	if not errors.is_empty():
		return {"errors": errors}
	var list := expand(file, kit, park_map, ground, context(park_map, ground, stage))
	warm(list, kit, low)
	return {"kit": kit, "list": list, "errors": []}


# The lowest preset halves LOD0 and LOD1; LOD2 begins where the halved LOD1 ends, so no gap opens.
static func _range(base: Array, low: bool, lod: int) -> Array:
	if not low:
		return base
	if lod < 2:
		return [float(base[0]) * LOW_RANGE_SCALE, float(base[1]) * LOW_RANGE_SCALE]
	return [float(PROP_RANGES[1][1]) * LOW_RANGE_SCALE, base[1]]


static func _lod_paths(kit: Dictionary, inst: Dictionary) -> Array:
	return kit["kinds"][inst["kind"]]["variants"][inst["v"]]["lod"]


static func _hero(holder: Node3D, inst: Dictionary, kit: Dictionary) -> void:
	var lods := _lod_paths(kit, inst)
	var tr := _transform(inst)
	for lod in 3:
		var mesh := _mesh(lods[lod])
		if mesh == null:
			continue
		var view := MeshInstance3D.new()
		view.name = "%s_%d_L%d" % [inst["kind"], holder.get_child_count(), lod]
		view.mesh = mesh
		view.transform = tr
		_ranges(view, HERO_RANGES[lod], HERO_MARGIN_M)
		_tag(view, inst, lod, lod == 0)
		holder.add_child(view)


static func _batch(holder: Node3D, label: String, mesh: Mesh, members: Array, first: Dictionary, lod: int, begin_end: Array, margin: float, litter: bool) -> void:
	if mesh == null:
		return
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = members.size()
	var centre := Vector3.ZERO
	for i in members.size():
		multi.set_instance_transform(i, _transform(members[i]))
		centre += (members[i]["pos"] as Vector3) / members.size()
	var view := MultiMeshInstance3D.new()
	view.name = label
	view.multimesh = multi
	# A visibility range is measured to the batch's bounds centre (set_dressing.gd, _batch): a chunk's end reaches past
	# its farthest member so none vanishes while the camera stands beside it.
	var spread := 0.0
	if litter:
		for member: Dictionary in members:
			spread = maxf(spread, (member["pos"] as Vector3).distance_to(centre))
	_ranges(view, [begin_end[0], float(begin_end[1]) + spread], margin)
	_tag(view, first, lod, false)
	view.set_meta("dress_count", members.size())
	holder.add_child(view)


static func _ranges(view: GeometryInstance3D, begin_end: Array, margin: float) -> void:
	view.visibility_range_begin = begin_end[0]
	view.visibility_range_end = begin_end[1]
	view.visibility_range_begin_margin = 0.0 if float(begin_end[0]) <= 0.0 else margin
	view.visibility_range_end_margin = margin
	view.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


static func _tag(view: GeometryInstance3D, inst: Dictionary, lod: int, shadow: bool) -> void:
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.add_to_group(GROUP)
	view.set_meta("dress_kind", inst["kind"])
	view.set_meta("dress_class", inst["class"])
	view.set_meta("dress_lod", lod)


static func _transform(inst: Dictionary) -> Transform3D:
	return Transform3D((inst["basis"] as Basis).scaled_local(Vector3.ONE * float(inst["scale"])), inst["pos"])


# A GLB's one mesh, read once per path.
static func _mesh(path: String) -> Mesh:
	if _meshes.has(path):
		return _meshes[path]
	var mesh: Mesh = null
	var packed = load(path)
	if packed is PackedScene:
		var scene: Node = (packed as PackedScene).instantiate()
		var view: MeshInstance3D = scene as MeshInstance3D
		if view == null:
			var found := scene.find_children("*", "MeshInstance3D", true, false)
			view = found[0] if not found.is_empty() else null
		if view != null:
			mesh = view.mesh
		scene.free()
	_meshes[path] = mesh
	return mesh


# Teardown: the cached meshes go with the park, and with the Game (activities.gd _exit_tree calls this).
static func release_shared() -> void:
	_meshes.clear()
	_cache_owner = ""


# --- Node lifecycle ---------------------------------------------------------------------------------

# A stage's file, kit and instances are drawn on a worker (prepare) and its nodes are built a vignette at a time
# within BUILD_SLICE_USEC a frame, so entering a park hitches on neither. finish() does both at once, for tests.

func setup(context_in) -> void:
	ctx = context_in
	name = "ParkProps"
	ctx.events.stage_entered.connect(_stage_entered)
	ctx.events.stage_content_cleared.connect(_clear_stage)
	if ctx.terrain.is_ready(ctx.terrain.stage):
		_build_stage()
	else:
		_pending = true


func _process(_delta: float) -> void:
	if _pending and ctx.terrain.is_ready(ctx.terrain.stage):
		_build_stage()
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		_take()
	if not _jobs.is_empty():
		_slice(BUILD_SLICE_USEC)


# True once the stage's nodes are all built (or it has none).
func is_built() -> bool:
	return _task < 0 and _jobs.is_empty() and not _pending


# Waits for the worker and builds every remaining job.
func finish() -> void:
	if _pending and ctx.terrain.is_ready(ctx.terrain.stage):
		_build_stage()
	if _task >= 0:
		_take()
	_slice(1 << 40)


func _stage_entered(_stage: int, _retry: bool) -> void:
	var started := Time.get_ticks_usec()
	_build_stage()
	last_entry_usec = Time.get_ticks_usec() - started


func _clear_stage(_reason: String) -> void:
	visible = false


func _exit_tree() -> void:
	_free_views()


func _free_views() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	_out = {}
	_jobs = []
	for child in get_children():
		child.free()
	views.clear()
	instances = []
	_built_for = []
	map_id = ""


func _build_stage() -> void:
	_pending = false
	var stage: int = ctx.terrain.stage
	var map = ctx.terrain.map_for(stage)
	if not ParkSites.is_park(map) or not FileAccess.file_exists(file_path(String(map.park.get("map", "")))):
		_free_views()
		return
	var id := String(map.park["map"])
	var low: bool = Preset.current == LOW_PRESET
	# A pure function of the park, its ground and the preset: the same key keeps what is built (retries).
	var key := [stage, id, low, ctx.terrain.geometry_root(stage).get_instance_id()]
	visible = true
	if key == _built_for:
		return
	_free_views()
	if _cache_owner != id:
		_meshes.clear()
		_cache_owner = id
	map_id = id
	_built_for = key
	_low = low
	var out := {}
	_out = out
	var ground: Callable = ctx.terrain.ground_callable(stage)
	_task = WorkerThreadPool.add_task(func(): out.merge(prepare(id, map, ground, stage, low)), false, "park props plan")


# The worker's result: keep the instances and queue the nodes.
func _take() -> void:
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	var out := _out
	_out = {}
	if out.is_empty() or not out["errors"].is_empty():
		push_warning("park_props: %s has no usable vignette file or kit: %s" % [map_id, str(out.get("errors", []))])
		return
	instances = out["list"]
	_kit = out["kit"]
	_jobs = jobs(instances, _low)


func _slice(budget_usec: int) -> void:
	var started := Time.get_ticks_usec()
	while not _jobs.is_empty():
		var holder := build_job(self, _jobs.pop_front(), _kit, _low)
		for view: GeometryInstance3D in holder.find_children("*", "GeometryInstance3D", true, false):
			views.append(view)
		if Time.get_ticks_usec() - started >= budget_usec:
			break
