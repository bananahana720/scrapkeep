extends "res://src/world/stage_map.gd"

# A stage map read from a park file (design-v3/PARK.md 2.1 and 2.9). It loads the JSON once,
# validates it with park_schema.gd, and fills the fields today's systems already read, so the
# bay, flow, director, reward gates, activities and contraptions keep their interfaces. A park
# that fails the schema fills nothing: errors holds the schema's rows and ok stays false.
# Heights stay the base plain's until the bake (tools/park_bake.gd) lands.

const ParkSchema := preload("res://src/world/park/park_schema.gd")
const ParkRecipes := preload("res://src/world/park/park_recipes.gd")

const FIXTURE := "res://src/world/park/park_test.json"
# Andrew's "Ride lips only" ruling (2026-10-17 06:16Z): a plain bank, drop, ground shelf or sky island whose height
# stamp is its whole shape is terrain, not a placeholder, so scatter lands on it as on the open ground. The same rows
# as scripts/placeholder-gate.mjs PLAIN_SLOPES and isPlainSlope.
const PLAIN_SLOPES := ["bank", "drop", "ground", "sky_island"]
# Andrew's "Edges are ground" (2026-10-17 22:29Z): a stamped kicker that spans the whole play rect across its facing
# (the Highdraft's mesa step lips, 18 rows and 28.8 km on park_islands) is a mesa edge, ground like a plain slope.
const MESA_EDGE := "kicker"

var path := ""
var ok := false
var errors: Array = []
# The parsed park file, kept for the readers that come later (bake, event director, sight test).
var park := {}
# The landmark's light, the one point every layer finds (terrain.gd landmark_point): sight_top.
var landmark := Vector3.INF
# Contraption specs for contraptions.gd: the park rows with arrays turned into vectors.
var contraptions: Array = []
# Where Moss's bay docks after the break: {"at": Vector2, "facing": Vector3}.
var bay_dock := {}
# The engage ring's radius (alpha_defs beacon_radius today).
var reach_m := 0.0
var time_of_day := ""
# The stage's caged pilots for rescue_site.gd, from the park file's optional rescue_rows: {id, quest, prompt, pilot,
# at: Vector2, face: Vector2}.
var rescue_sites: Array = []


func _init(park_path := FIXTURE) -> void:
	path = park_path
	var read := ParkSchema.load_park(path)
	errors = read["errors"]
	if not errors.is_empty():
		push_warning("park_map: %s fails the park schema: %s" % [path, ParkSchema.describe(errors)])
		return
	park = read["data"]
	_fill()
	ok = true


func warden_spec() -> Dictionary:
	return park["landmark"]["warden"].duplicate(true) if ok else {}


func _fill() -> void:
	title = String(park["map"])
	time_of_day = String(park["time_of_day"])
	spawn = _v2(park["spawn"]["at"])
	heading = facing(float(park["spawn"]["heading_deg"]))
	var r: Array = park["play_rect"]
	play_rect = Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))

	var mark: Dictionary = park["landmark"]
	beacon = _v2(mark["beacon"])
	reach_m = float(mark["reach_m"])
	landmark = _v3(mark["sight_top"])
	bay_dock = {"at": _v2(mark["bay_dock"]["at"]), "facing": facing(float(mark["bay_dock"]["facing_deg"]))}
	gate_slots = []
	for slot in mark["gate_slots"]:
		gate_slots.append({"at": _v2(slot["at"]), "facing": facing(float(slot["facing_deg"]))})

	kickers = []
	for row in park["park_rows"]:
		if row["element"] != "kicker":
			continue
		kickers.append(kicker_lip(row))

	contraptions = []
	for row in park["contraption_rows"]:
		contraptions.append(vectors(row))

	activity_sites = []
	for row in park["activity_rows"]:
		# activities.gd keys its rule by the activity kind; an empty pack or pay keeps the rule's own.
		var site := {"id": row["activity"], "row": row["id"], "site": row["site"], "at": _v2(row["at"])}
		if not (row["pack"] as Array).is_empty():
			site["pack"] = row["pack"].duplicate()
		if not (row["pay"] as Dictionary).is_empty():
			site["pay"] = row["pay"].duplicate(true)
		activity_sites.append(site)

	rescue_sites = []
	for row in park.get("rescue_rows", []):
		rescue_sites.append({"id": row["id"], "quest": row["quest"], "prompt": row["prompt"], "pilot": row["pilot"],
			"at": _v2(row["at"]), "face": _v2(row["face"]).normalized()})

	# Scatter keeps out of every built footprint (PARK.md 2.9) but the ground, the plain slopes, the mesa
	# edges and a row the scatter itself dresses; the kit rows come with KB5.
	scatter = scatter.duplicate(true)
	var keep_out := []
	for row in park["park_rows"]:
		if row["element"] == "ground" or row["recipe"] == ParkRecipes.SCATTER_DRESSED or plain_slope(row) or mesa_edge(row, play_rect):
			continue
		keep_out.append(_footprint(row))
	keep_out.append(_footprint(mark))
	scatter["keep_out"] = keep_out
	# Coordinator ruling 5, 2026-10-19 (issue #149): a scatter-dressed row a route names in from, to or via is
	# ridden, so the kit pieces taller than the ghost-solid band stay out of it (scatter.gd, LANE_BAND_M);
	# the flat ones keep landing there, as does everything off the routes.
	var routed := {}
	for route: Dictionary in park.get("routes", []):
		for id in [route.get("from", "")] + Array(route.get("via", [])) + [route.get("to", "")]:
			routed[String(id)] = true
	var lane_out := []
	for row in park["park_rows"]:
		if row["recipe"] == ParkRecipes.SCATTER_DRESSED and routed.has(String(row["id"])):
			lane_out.append(_footprint(row))
	scatter["lane_out"] = lane_out


# A stamped plain slope: a PLAIN_SLOPES greybox whose stamp shapes the ground and that has no absolute y, so
# park_recipes.gd stamp_replaces draws no box for it and the stamped ground is the whole piece.
static func plain_slope(row: Dictionary) -> bool:
	var element := String(row.get("element", ""))
	return element in PLAIN_SLOPES and String(row.get("recipe", "")) == ParkRecipes.GREYBOX + element \
		and String(row.get("stamp", "")) != "" and row.get("y") == null


# A mesa edge: a stamped MESA_EDGE greybox (stamp_replaces, as plain_slope) whose cross size reaches across the
# whole of rect, measured along the row's cross axis.
static func mesa_edge(row: Dictionary, rect: Rect2) -> bool:
	if String(row.get("element", "")) != MESA_EDGE or String(row.get("recipe", "")) != ParkRecipes.GREYBOX + MESA_EDGE \
			or String(row.get("stamp", "")) == "" or row.get("y") != null:
		return false
	var dir := _dir(float(row["yaw_deg"]))
	return float(row["size"][2]) >= absf(dir.y) * rect.size.x + absf(dir.x) * rect.size.y


# One kicker row's lip: the ride's exit, the footprint's far end along the facing, which park_recipes.gd ride_frame (the
# one owner of the origin rule) gives for a greybox and a GLB recipe alike; width is the piece's cross size.
static func kicker_lip(row: Dictionary) -> Dictionary:
	var dir := _dir(float(row["yaw_deg"]))
	var exit: Vector3 = ParkRecipes.ride_frame(row)["exit"]
	return {"id": row["id"], "at": _v2(row["at"]) + dir * exit.z, "dir": dir, "width": float(row["size"][2])}


# The ground-plane direction a yaw faces: 0 faces +z, turning toward +x (PARK.md 2.1).
static func _dir(yaw_deg: float) -> Vector2:
	var a := deg_to_rad(yaw_deg)
	return Vector2(sin(a), cos(a))


static func facing(yaw_deg: float) -> Vector3:
	var d := _dir(yaw_deg)
	return Vector3(d.x, 0.0, d.y)


# PARK size is [length, height, width]; place_greybox runs length along local +Z.
static func footprint_half_extents(row: Dictionary) -> Vector2:
	return Vector2(float(row["size"][2]), float(row["size"][0])).abs() * 0.5


# Closed rectangle in world XZ. An optional endpoint checks the whole segment;
# explicit event footprints supply their already-resolved local X/Z half-extents.
static func footprint_contains(row: Dictionary, world_xz: Vector2, margin := 0.0,
		end_xz := Vector2.INF, half_extents := Vector2.INF) -> bool:
	var half := footprint_half_extents(row) if half_extents == Vector2.INF else half_extents
	half += Vector2.ONE * maxf(0.0, margin)
	var centre := _v2(row["at"])
	var yaw := deg_to_rad(float(row["yaw_deg"]))
	var point := (world_xz - centre).rotated(yaw)
	if end_xz == Vector2.INF:
		return absf(point.x) <= half.x and absf(point.y) <= half.y
	var end := (end_xz - centre).rotated(yaw)
	var enter := 0.0
	var leave := 1.0
	for axis in 2:
		var delta: float = end[axis] - point[axis]
		if absf(delta) < 0.00000001:
			if absf(point[axis]) > half[axis]:
				return false
		else:
			var near: float = (-half[axis] - point[axis]) / delta
			var far: float = (half[axis] - point[axis]) / delta
			enter = maxf(enter, minf(near, far))
			leave = minf(leave, maxf(near, far))
			if enter > leave:
				return false
	return true


static func _footprint(row: Dictionary) -> Dictionary:
	return {"id": row["id"], "at": _v2(row["at"]), "size": Vector2(float(row["size"][0]), float(row["size"][2])),
		"yaw": deg_to_rad(float(row["yaw_deg"]))}


# A JSON value with every [x, z] turned into a Vector2 and every [x, y, z] into a Vector3,
# through nested objects and lists (PARK.md 2.6: arrays become vectors in park_map.gd).
static func vectors(value):
	if value is Dictionary:
		var out := {}
		for key in value:
			out[key] = vectors(value[key])
		return out
	if value is Array:
		if ParkSchema._is_vec(value, 2):
			return _v2(value)
		if ParkSchema._is_vec(value, 3):
			return _v3(value)
		return value.map(func(v): return vectors(v))
	return value


static func _v2(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


static func _v3(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))
