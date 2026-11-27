extends RefCounted


const AppShell := preload("res://src/core/app_shell.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const RecipeProps := preload("res://src/presentation/recipe_props.gd")
const MaterialSlots := preload("res://src/presentation/material_slots.gd")
const Stamps := preload("res://src/world/park/park_stamps.gd")
const LandmarkProxy := preload("res://src/presentation/landmark_proxy.gd")
const LandmarkBeam := preload("res://src/presentation/landmark_beam.gd")
const WardenMind := preload("res://src/combat/warden_mind.gd")
const IsleRig := preload("res://src/world/park/isle_rig.gd")
const DamRig := preload("res://src/world/park/dam_rig.gd")
const Footings := preload("res://src/world/park/footings.gd")

const BUDGETS_PATH := "res://assets/asset_budgets.json"
const GLB_DIR := "res://assets/models/park/"
const REGISTRY_PATH := "res://assets/registry.json"
const ORIGIN_CENTRE := "centre"
const ORIGIN_ENTRY_LIP := "entry_lip"
const ORIGINS := [ORIGIN_CENTRE, ORIGIN_ENTRY_LIP]
const GREYBOX := "greybox:"
const LANDMARK_DRESSED := "landmark"
const MOVING_GROUP := "park_row_moving"
const SCATTER_DRESSED := "scatter"
const SENSOR_ONLY := [LANDMARK_DRESSED, SCATTER_DRESSED]
const COL_SUFFIX := "-col"
const WORLD_LAYER := 1
const BALL_LAYER := 2
const COVER_META := "cover_kind"
const COVER_HARD := "hard"
const COVER_SOFT := "soft"
const COVER_SURFACE := "surface"
const COVER_KINDS := [COVER_HARD, COVER_SOFT, COVER_SURFACE]
const COVER_HARD_M := 2.0
const SENSOR_ABOVE_M := 3.0
const ONCE_FACT_PREFIX := "layer_mind_quote_"
const RIDER_GROUP := "park_rider"
const RIDER_SWING_DEG := -75.0
const RIDER_SWING_S := 4.5
const GREYBOX_TINT := Color("8a8a84")
const FIT_SEAT := "seat"
const STRETCH_MIN := 0.75
const STRETCH_MAX := 1.5
const SOCKET_ENTRY := "socket_entry"
const SOCKET_EXIT := "socket_exit"
const FIT_TILE := "tile"
const FIT_DRAPE := "drape"
const TILE_MIN := 2
const TILE_MATCH_M := 0.25
const TILE_SLICE_IN_M := 0.05
const FOOTED := ["crib_wall_", "crib_pier_"]
const FOOT_MIN_M := 0.05
const FOOT_SAMPLE_M := 2.0
const FOOT_STRETCH_MAX := 2.0

const ROWS := {
	"half_pipe_concrete": {"family": "half_pipes", "budget": "landform"},
	"slot_canyon_flow": {"family": "half_pipes", "budget": "landform"},
	"wash_dropin_lip": {"family": "half_pipes", "budget": "landform"},
	"canal_lip": {"family": "grind_lines", "budget": "landform"},
	"flume_span": {"family": "grind_lines", "budget": "landform"},
	"penstock_run": {"family": "grind_lines", "budget": "landform"},
	"pipeline_rail": {"family": "grind_lines", "budget": "landform"},
	"bench_coping": {"family": "bowls", "budget": "landform"},
	"tailings_lip": {"family": "bowls", "budget": "landform"},
	"pit_haul_ramp": {"family": "bowls", "budget": "landform"},
	"pit_haul_lane": {"family": "bowls", "budget": "landform"},
	"lava_tube_run": {"family": "tunnels", "budget": "park_large"},
	"adit_mouth": {"family": "tunnels", "budget": "park_large"},
	"shaft_drop": {"family": "tunnels", "budget": "park_large"},
	"spillway_tunnel": {"family": "tunnels", "budget": "park_large"},
	"cenote_pool": {"family": "caverns", "budget": "park_large"},
	"flooded_shaft": {"family": "caverns", "budget": "park_large"},
	"cavern_shell": {"family": "caverns", "budget": "park_large"},
	"cliff_dwelling_row": {"family": "ledges", "budget": "landform"},
	"mesa_rim_ledge": {"family": "ledges", "budget": "landform"},
	"viga_pivot": {"family": "ledges", "budget": "landform"},
	"crater_event": {"family": "crater", "budget": "park_large"},
	"crater_ending": {"family": "crater", "budget": "park_large"},
	"mesa_lip_kicker": {"family": "sky_islands", "budget": "landform"},
	"net_deck": {"family": "sky_islands", "budget": "landform"},
	"floating_island": {"family": "sky_islands", "budget": "park_large"},
	"landmark_dam": {"family": "landmark", "budget": "hero_landmark"},
	"landmark_penstock_tower": {"family": "landmark", "budget": "hero_landmark"},
	"landmark_headframe": {"family": "landmark", "budget": "hero_landmark"},
	"landmark_sinkhole": {"family": "landmark", "budget": "hero_landmark"},
	"landmark_sky_island": {"family": "landmark", "budget": "hero_landmark"},
	"landmark_spire": {"family": "landmark", "budget": "hero_landmark"},
	"anchor_hoodoo": {"family": "anchors", "budget": "detail"},
	"anchor_basalt": {"family": "anchors", "budget": "detail"},
	"anchor_timber": {"family": "anchors", "budget": "detail"},
	"anchor_saguaro": {"family": "anchors", "budget": "detail"},
	"anchor_cairn": {"family": "anchors", "budget": "detail"},
	"ore_bin": {"family": "workings", "budget": "landform"},
	"ore_bin_row": {"family": "workings", "budget": "landform"},
	"timber_portal": {"family": "workings", "budget": "detail"},
	"lava_wash": {"family": "tunnels", "budget": "park_large"},
	"lava_wash_short": {"family": "tunnels", "budget": "park_large"},
	"gallery_wash": {"family": "caverns", "budget": "park_large"},
	"drift_wash": {"family": "tunnels", "budget": "park_large"},
	"skylight_lip": {"family": "tunnels", "budget": "park_large"},
	"tube_mouth_lip": {"family": "tunnels", "budget": "park_large"},
	"breach_lip": {"family": "tunnels", "budget": "park_large"},
	"miners_cap": {"family": "tunnels", "budget": "park_large"},
	"great_room_deck": {"family": "bowls", "budget": "park_large"},
	"haulage_bed": {"family": "grind_lines", "budget": "park_large"},
}

const DRAPED := ["lava_channel", "lava_wash", "lava_wash_short", "gallery_wash", "drift_wash"]

const ELEMENT_FACTS := {
	"half_pipe": "ride_chute", "flow_line": "ride_chute", "tunnel": "ride_chute",
	"grind_line": "ride_grapple_line", "rail": "ride_grapple_line",
	"bowl": "ride_bowl", "terrace": "ride_bowl", "crater_bowl": "ride_bowl", "bank": "ride_bowl",
	"drop": "ride_drop", "flooded_cavern": "ride_drop",
	"elevated_line": "ride_ledge", "ledge": "ride_ledge",
	"sky_island": "ride_hop", "kicker": "kicker_launch",
	"anchor_field": "", "ground": "",
}

const WEDGES := {"kicker": 1.0, "drop": -1.0}

const ANCHOR_PITCH_M := 20.0
const ANCHOR_POST_M := 8.0
const SURFACE_LAYER_M := 0.015
const SURFACE_MARGIN_M := 2.0
const ANCHOR_SINK_M := 1.0
const ANCHOR_RUNOUT_M := 10.0
const ANCHOR_SIDE_M := 6.0
const ROUTE_LANE_HALF_M := 20.0
const ANCHOR_EDGE_STEP_M := 12.0
const NATURAL_STANDS := ["hoodoo_field", "saguaro_stand"]
const ANCHOR_STAND_JITTER_M := 7.0
const ANCHOR_STAND_MIN_M := 60.0
const ANCHOR_STAND_GAP_M := 12.0
const ANCHOR_KITS := ["anchor_hoodoo", "anchor_basalt", "anchor_timber", "anchor_saguaro", "anchor_cairn"]
const ANCHOR_VARIANTS := ["a", "b", "c"]
const OVER_GREYBOX := ["isle_adit_portal", "isle_tram_head", "isle_keel_rib", "isle_ride_wash_west", "isle_ride_fin_chute"]
const ANCHOR_AUTHORED_M := 10.0
const DROP_IN := "drop_in"
const LANDMARK := "landmark"
const BEAM_ROOT := "beam_root"
const ANCIENT_BEAM := "ancient_beam"
const TIP_SUFFIX := "_tip"

static var _budgets := {}
static var _origins := {}
static var _origins_read := false
static var _origins_lock := Mutex.new()
static var _ends := {}
static var _tiles := {}
static var _anchor_meshes := {}
const ANCHOR_FIT_PATH := "res://src/world/park/anchors/anchor_fit.json"
static var _anchor_fit := {}
static var _anchor_fit_read := false
static var _anchor_fit_lock := Mutex.new()
static var _anchor_hulls := {}
static var _anchor_hull_lock := Mutex.new()
const ANCHOR_HULL_CAP := 64


static func ranges(budget: String) -> Dictionary:
	if _budgets.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(BUDGETS_PATH))
		_budgets = parsed if parsed is Dictionary else {"classes": {}}
	return _budgets["classes"].get(budget, {}).get("ranges", {})


static func origin(recipe: String) -> String:
	_origins_lock.lock()
	if not _origins_read:
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(REGISTRY_PATH))
		if parsed is Dictionary:
			for a in parsed.get("assets", []):
				if a is Dictionary and a.get("id") is String and a.get("origin") is String:
					_origins[a["id"]] = a["origin"]
		_origins_read = true
	var out := String(_origins.get(recipe, ORIGIN_CENTRE))
	_origins_lock.unlock()
	return out


static func ride_frame(row: Dictionary) -> Dictionary:
	var half := float(row["size"][0]) * 0.5
	var recipe := String(row.get("recipe", ""))
	var lip := not recipe.begins_with(GREYBOX) and origin(recipe) == ORIGIN_ENTRY_LIP
	return {"entry": Vector3(0, 0, -half), "exit": Vector3(0, 0, half), "origin": Vector3(0, 0, -half if lip else 0.0)}


static func paths(recipe: String, budget: String) -> Dictionary:
	var out := {"base": GLB_DIR + recipe + ".glb",
		"shells": [GLB_DIR + recipe + "_detail1.glb", GLB_DIR + recipe + "_detail2.glb"]}
	if budget == "hero_landmark":
		out["mid"] = GLB_DIR + recipe + "_mid.glb"
		out["far"] = GLB_DIR + recipe + "_far.glb"
	return out


static func row_transform(row: Dictionary, ground := Callable()) -> Transform3D:
	var at: Array = row["at"]
	var x := float(at[0])
	var z := float(at[1])
	var y := 0.0
	if row.get("y") != null:
		y = float(row["y"])
	elif ground.is_valid():
		y = float(ground.call(x, z))
	return Transform3D(Basis(Vector3.UP, deg_to_rad(float(row.get("yaw_deg", 0.0)))), Vector3(x, y, z))


static func fits_seat(row: Dictionary) -> bool:
	return String(row.get("fit", "")) == FIT_SEAT


static func authored_ends(scene: Node, lip: bool) -> Dictionary:
	var col = null
	var entry = null
	var exit = null
	for n: Node3D in scene.find_children("*", "Node3D", true, false):
		if n.name == SOCKET_ENTRY:
			entry = _relative(n, scene).origin
		elif n.name == SOCKET_EXIT:
			exit = _relative(n, scene).origin
		elif n is MeshInstance3D and String(n.name).ends_with(COL_SUFFIX) and (n as MeshInstance3D).mesh != null:
			var box: AABB = _relative(n, scene) * (n as MeshInstance3D).mesh.get_aabb()
			col = box if col == null else (col as AABB).merge(box)
	if col == null:
		return {}
	if entry == null:
		entry = Vector3.ZERO if lip else Vector3(0, 0, (col as AABB).position.z)
	if exit == null:
		exit = Vector3(0, (entry as Vector3).y, (col as AABB).end.z)
	return {"entry": entry, "exit": exit, "length": (exit as Vector3).z - (entry as Vector3).z}


static func recipe_ends(recipe: String) -> Dictionary:
	if not _ends.has(recipe):
		var scenes := _load(GLB_DIR + recipe + ".glb")
		_ends[recipe] = authored_ends(scenes[0], origin(recipe) == ORIGIN_ENTRY_LIP) if not scenes.is_empty() else {}
		for scene: Node in scenes:
			scene.free()
	return _ends[recipe]


static func seat_refusal(row: Dictionary, ends: Dictionary) -> String:
	var authored := float(ends.get("length", 0.0))
	if authored <= 0.0:
		return "the GLB has no -col mesh or no length along +Z"
	var stretch := float(row["size"][0]) / authored
	if stretch < STRETCH_MIN or stretch > STRETCH_MAX:
		return "length ratio %.2f outside %.2f to %.2f (row %.1f m, GLB %.1f m)" % [stretch, STRETCH_MIN, STRETCH_MAX, float(row["size"][0]), authored]
	return ""


static func seat_fit(row: Dictionary, ends: Dictionary, ground := Callable()) -> Dictionary:
	var reason := seat_refusal(row, ends)
	if reason != "":
		return {"ok": false, "reason": reason}
	var length := float(row["size"][0])
	var authored := float(ends["length"])
	var stretch := length / authored
	var frame := row_transform(row, ground)
	var lip_y := 0.0
	var exit_y := 0.0
	if row.get("y") == null and ground.is_valid():
		var lip_w := frame * Vector3(0, 0, -length * 0.5)
		var exit_w := frame * Vector3(0, 0, length * 0.5)
		lip_y = float(ground.call(lip_w.x, lip_w.z)) - frame.origin.y
		exit_y = float(ground.call(exit_w.x, exit_w.z)) - frame.origin.y
	var e: Vector3 = ends["entry"]
	var x: Vector3 = ends["exit"]
	var a := lip_y - e.y
	var shear := (exit_y - lip_y - (x.y - e.y)) / authored
	var basis := Basis(Vector3.RIGHT, Vector3.UP, Vector3(0, shear, stretch))
	var xf := Transform3D(basis, Vector3(0, a - shear * e.z, -length * 0.5 - stretch * e.z))
	return {"ok": true, "reason": "", "stretch": stretch, "lip_y": lip_y, "exit_y": exit_y, "transform": xf}


static func is_surface(row: Dictionary) -> bool:
	if fits_drape(row):
		return false
	return String(row.get("recipe", "")).begins_with("liner_") or String(row.get("element", "")) == "grind_line"


static func surface_lifts(rows: Array) -> Dictionary:
	var out := {}
	var placed: Array = []
	var order: Array[int] = []
	for i in rows.size():
		if is_surface(rows[i]) and rows[i].has("size"):
			order.append(i)
	var rank := func(i: int) -> float:
		var liner := 0.0 if String(rows[i].get("element", "")) == "grind_line" else 1.0e9
		return liner - float(rows[i]["size"][0]) * float(rows[i]["size"][2])
	order.sort_custom(func(a: int, b: int) -> bool: return rank.call(a) < rank.call(b) or (rank.call(a) == rank.call(b) and a < b))
	for i in order:
		var row: Dictionary = rows[i]
		var mine := _footprint(row, SURFACE_MARGIN_M)
		var taken := {}
		for other: Array in placed:
			if _rects_meet(mine, other[0]):
				taken[other[1]] = true
		var layer := 0
		while taken.has(layer):
			layer += 1
		placed.append([mine, layer])
		if layer > 0:
			out[i] = layer * SURFACE_LAYER_M
	return out


static func _footprint(row: Dictionary, margin: float) -> Array:
	var size: Array = row["size"]
	var yaw := deg_to_rad(float(row.get("yaw_deg", 0.0)))
	return [_v2(row["at"]), Vector2(float(size[2]) * 0.5 + margin, float(size[0]) * 0.5 + margin),
		Vector2(cos(yaw), -sin(yaw)), Vector2(sin(yaw), cos(yaw))]


static func _rects_meet(a: Array, b: Array) -> bool:
	var d: Vector2 = (b[0] as Vector2) - (a[0] as Vector2)
	for axis: Vector2 in [a[2], a[3], b[2], b[3]]:
		var ra := absf((a[2] as Vector2).dot(axis)) * (a[1] as Vector2).x + absf((a[3] as Vector2).dot(axis)) * (a[1] as Vector2).y
		var rb := absf((b[2] as Vector2).dot(axis)) * (b[1] as Vector2).x + absf((b[3] as Vector2).dot(axis)) * (b[1] as Vector2).y
		if absf(d.dot(axis)) > ra + rb:
			return false
	return true


static func _lift_drawn(node: Node, lift: float) -> void:
	for child: Node in node.get_children():
		if child is CollisionObject3D:
			continue
		if child is GeometryInstance3D:
			(child as Node3D).position.y += lift
		else:
			_lift_drawn(child, lift)


static func fits_drape(row: Dictionary) -> bool:
	return String(row.get("fit", "")) == FIT_DRAPE and String(row.get("stamp", "")) != ""


static func fits_tile(row: Dictionary) -> bool:
	return String(row.get("fit", "")) == FIT_TILE


static func footed(row: Dictionary) -> bool:
	var recipe := String(row.get("recipe", ""))
	return row.get("y") == null and String(row.get("fit", "")) == "" and FOOTED.any(func(k): return recipe.begins_with(k))


static func foot_fit(row: Dictionary, faces: PackedVector3Array, place: Transform3D, ground: Callable) -> Dictionary:
	var none := {"stretch": 1.0, "basis": Basis.IDENTITY, "shift": Vector3.ZERO}
	if faces.is_empty():
		return none
	var box := AABB(faces[0], Vector3.ZERO)
	for v in faces:
		box = box.expand(v)
	var lowest := INF
	var nx := maxi(1, ceili(box.size.x / FOOT_SAMPLE_M))
	var nz := maxi(1, ceili(box.size.z / FOOT_SAMPLE_M))
	for i in nx + 1:
		for k in nz + 1:
			var w := place * Vector3(box.position.x + box.size.x * i / nx, 0.0, box.position.z + box.size.z * k / nz)
			lowest = minf(lowest, float(ground.call(w.x, w.z)) - place.origin.y)
	var bottom := box.position.y
	var top := box.end.y
	if bottom - lowest <= FOOT_MIN_M or top - bottom <= 0.0:
		return none
	var stretch := minf((top - lowest) / (top - bottom), FOOT_STRETCH_MAX)
	if stretch * (top - bottom) < top - lowest:
		push_warning("park_recipes: %s foot fit capped at %.2f, %.2f m over its lowest ground" % [row.get("id", ""), FOOT_STRETCH_MAX, (top - lowest) - stretch * (top - bottom)])
	return {"stretch": stretch, "basis": Basis.from_scale(Vector3(1.0, stretch, 1.0)), "shift": Vector3.UP * top * (1.0 - stretch)}


static func col_faces(scene: Node) -> PackedVector3Array:
	var out := PackedVector3Array()
	for source: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if source.mesh != null and String(source.name).ends_with(COL_SUFFIX):
			out.append_array(_relative(source, scene) * _trimesh(source).get_faces())
	return out


static func cross_section(faces: PackedVector3Array, z0: float) -> Dictionary:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var hit := false
	for t in range(0, faces.size() - 2, 3):
		for k in 3:
			var a := faces[t + k]
			var b := faces[t + (k + 1) % 3]
			var da := a.z - z0
			var db := b.z - z0
			var p: Vector3
			if da == 0.0:
				p = a
			elif da * db < 0.0:
				p = a.lerp(b, da / (da - db))
			else:
				continue
			lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
			hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
			hit = true
	if not hit:
		return {}
	return {"min": lo, "max": hi, "width": hi.x - lo.x, "height": hi.y - lo.y}


static func tile_ends(scene: Node, lip: bool) -> Dictionary:
	var ends := authored_ends(scene, lip)
	if ends.is_empty():
		return {}
	var faces := col_faces(scene)
	var entry := cross_section(faces, (ends["entry"] as Vector3).z + TILE_SLICE_IN_M)
	var exit := cross_section(faces, (ends["exit"] as Vector3).z - TILE_SLICE_IN_M)
	var reason := ""
	if entry.is_empty() or exit.is_empty():
		reason = "the -col mesh has no cross-section at its %s" % ("entry" if entry.is_empty() else "exit")
	else:
		var dw := absf(float(exit["width"]) - float(entry["width"]))
		var dh := absf(float(exit["height"]) - float(entry["height"]))
		if dw > TILE_MATCH_M or dh > TILE_MATCH_M:
			reason = "entry %.2f x %.2f m and exit %.2f x %.2f m cross-sections differ by more than %.2f m" % [
				float(entry["width"]), float(entry["height"]), float(exit["width"]), float(exit["height"]), TILE_MATCH_M]
	return {"entry": entry, "exit": exit, "tileable": reason == "", "reason": reason}


static func recipe_tile(recipe: String) -> Dictionary:
	if not _tiles.has(recipe):
		var scenes := _load(GLB_DIR + recipe + ".glb")
		_tiles[recipe] = tile_ends(scenes[0], origin(recipe) == ORIGIN_ENTRY_LIP) if not scenes.is_empty() else {}
		for scene: Node in scenes:
			scene.free()
	return _tiles[recipe]


static func tile_count(length: float, authored: float) -> int:
	return maxi(TILE_MIN, roundi(length / authored))


static func tile_refusal(row: Dictionary, ends: Dictionary, tile: Dictionary) -> String:
	var authored := float(ends.get("length", 0.0))
	if authored <= 0.0 or tile.is_empty():
		return "the GLB has no -col mesh or no length along +Z"
	if not bool(tile["tileable"]):
		return "not tileable: " + String(tile["reason"])
	var length := float(row["size"][0])
	var n := tile_count(length, authored)
	var stretch := length / (n * authored)
	if stretch < STRETCH_MIN or stretch > STRETCH_MAX:
		return "%d copies stretch %.2f outside %.2f to %.2f (row %.1f m, GLB %.1f m)" % [n, stretch, STRETCH_MIN, STRETCH_MAX, length, authored]
	return ""


static func tile_fit(row: Dictionary, ends: Dictionary, tile: Dictionary, ground := Callable()) -> Dictionary:
	var reason := tile_refusal(row, ends, tile)
	if reason != "":
		return {"ok": false, "reason": reason}
	var length := float(row["size"][0])
	var authored := float(ends["length"])
	var n := tile_count(length, authored)
	var piece := length / n
	var stretch := piece / authored
	var frame := row_transform(row, ground)
	var on_ground := row.get("y") == null and ground.is_valid()
	var e: Vector3 = ends["entry"]
	var x: Vector3 = ends["exit"]
	var heights: Array[float] = []
	for k in n + 1:
		var y := 0.0
		if on_ground:
			var w := frame * Vector3(0, 0, -length * 0.5 + k * piece)
			y = float(ground.call(w.x, w.z)) - frame.origin.y
		heights.append(y)
	var copies := []
	for k in n:
		var z0 := -length * 0.5 + k * piece
		var z1 := -length * 0.5 + (k + 1) * piece
		var a := heights[k] - e.y
		var shear := (heights[k + 1] - heights[k] - (x.y - e.y)) / authored
		var basis := Basis(Vector3.RIGHT, Vector3.UP, Vector3(0, shear, stretch))
		var xf := Transform3D(basis, Vector3(0, a - shear * e.z, z0 - stretch * e.z))
		copies.append({"transform": xf, "z0": z0, "z1": z1, "lip_y": heights[k], "exit_y": heights[k + 1]})
	return {"ok": true, "reason": "", "count": n, "stretch": stretch, "copies": copies}


static func place(row: Dictionary, parent: Node3D, ground := Callable(), publish := Callable(), ridden := Callable()) -> Node3D:
	var recipe := String(row.get("recipe", ""))
	if recipe == "":
		return null
	if recipe.begins_with(GREYBOX):
		return place_greybox(row, recipe.trim_prefix(GREYBOX), parent, ground, publish)
	if SENSOR_ONLY.has(recipe):
		var dressed := _node(row, parent, ground)
		_sensor(dressed, row, publish)
		tag_cover(dressed, row)
		return dressed
	if ANCHOR_KITS.has(recipe):
		return place_anchor_field(row, parent, ground)
	var budget := String(row.get("budget", ROWS.get(recipe, {}).get("budget", "landform")))
	var p := paths(recipe, budget)
	if not ResourceLoader.exists(p["base"]):
		push_warning("park_recipes: %s missing, %s stands in as greybox" % [p["base"], row.get("id", "")])
		return place_greybox(row, String(row.get("element", "")), parent, ground, publish)
	if OVER_GREYBOX.has(recipe):
		return place_over_greybox(row, p, budget, parent, ground, publish)
	if fits_seat(row):
		var refusal := seat_refusal(row, recipe_ends(recipe))
		if refusal != "":
			push_warning("park_recipes: %s cannot seat %s (%s), stands in as greybox" % [row.get("id", ""), recipe, refusal])
			var stand := place_greybox(row, String(row.get("element", "")), parent, ground, publish)
			if stand != null:
				stand.set_meta("seat_refused", refusal)
			return stand
	if fits_tile(row):
		var refusal := tile_refusal(row, recipe_ends(recipe), recipe_tile(recipe))
		if refusal != "":
			push_warning("park_recipes: %s cannot tile %s (%s), stands in as greybox" % [row.get("id", ""), recipe, refusal])
			var stand := place_greybox(row, String(row.get("element", "")), parent, ground, publish)
			if stand != null:
				stand.set_meta("tile_refused", refusal)
			return stand
	var parts :={"base": _load(p["base"]), "shells": [], "mid": [], "far": []}
	for path: String in p["shells"]:
		parts["shells"].append_array(_load(path))
	for key in ["mid", "far"]:
		if p.has(key):
			parts[key] = _load(p[key])
	var node := place_parts(row, parts, parent, ground, publish, ridden)
	for key in parts:
		for scene: Node in parts[key]:
			scene.free()
	return node


static func landmark_row(park: Dictionary) -> Dictionary:
	var mark: Dictionary = park.get("landmark", {})
	if String(mark.get("recipe", "")) == "":
		return {}
	var row := mark.duplicate(true)
	row["y"] = landmark_datum(mark)
	return row


static func landmark_datum(mark: Dictionary) -> float:
	if mark.get("y") != null:
		return float(mark["y"])
	var kind := String(mark.get("kind", ""))
	var warden: Dictionary = mark.get("warden", {})
	match kind:
		"headframe":
			return float(mark["sight_top"][1]) - float(mark["size"][1])
		"spire":
			return float(warden.get("bowl_floor", 0.0))
		"sky_island":
			return float(mark["sight_top"][1]) - (float(mark["size"][1]) - WardenMind.PIVOT_HEIGHT)
	return 0.0


static func place_landmark(park: Dictionary, parent: Node3D, ground := Callable()) -> Node3D:
	var row := landmark_row(park)
	if row.is_empty():
		return null
	var kind := String(row.get("kind", ""))
	var p := paths(String(row["recipe"]), String(row.get("budget", "hero_landmark")))
	var node: Node3D = null
	var root = null
	if ResourceLoader.exists(p["base"]):
		node = place(row, parent, ground)
		root = _beam_root(p["base"])
		if root is Vector3:
			root = ride_frame(row)["origin"] + (root as Vector3)
	var warden: Dictionary = row.get("warden", {})
	var anchor_y := float(warden["anchor"][1]) if warden.get("anchor") is Array else -INF
	if node == null:
		node = _node(row, parent, ground)
		LandmarkProxy.build(kind, node, node.transform, ground, anchor_y)
		node.set_meta("landmark_proxy", true)
		tag_cover(node, row)
		root = LandmarkProxy.BEAM_ROOT.get(kind)
	node.name = "Landmark_%s" % String(row.get("id", "landmark"))
	node.set_meta("landmark_kind", kind)
	if String(row.get("light", "")) == ANCIENT_BEAM and root is Vector3:
		LandmarkBeam.make(node, node.transform * (root as Vector3), float(row["sight_top"][1]), anchor_y)
	if kind == "sky_island":
		IsleRig.attach(node, null if node.has_meta("landmark_proxy") else _tip_shape(row))
		node.add_to_group(MOVING_GROUP)
	if kind == "dam" and not node.has_meta("landmark_proxy"):
		DamRig.attach(node)
	return node


static func moves(node: Node) -> bool:
	while node != null:
		if node.is_in_group(MOVING_GROUP):
			return true
		node = node.get_parent()
	return false


static func _tip_shape(row: Dictionary) -> CollisionShape3D:
	var out: CollisionShape3D = null
	for scene: Node in _load(GLB_DIR + String(row["recipe"]) + TIP_SUFFIX + ".glb"):
		for source: MeshInstance3D in scene.find_children("*" + COL_SUFFIX, "MeshInstance3D", true, false):
			if out == null and source.mesh != null:
				out = CollisionShape3D.new()
				out.name = "TipShape"
				out.shape = _trimesh(source)
				out.transform = Transform3D(Basis.IDENTITY, ride_frame(row)["origin"]) * _relative(source, scene)
		scene.free()
	return out


static var _beam_roots := {}

static func _beam_root(path: String):
	if _beam_roots.has(path):
		return _beam_roots[path]
	var scenes := _load(path)
	var out = null
	for scene: Node in scenes:
		var found := scene.find_child(BEAM_ROOT, true, false)
		if out == null and found is Node3D:
			out = _relative(found, scene).origin
		scene.free()
	_beam_roots[path] = out
	return out


static func place_parts(row: Dictionary, parts: Dictionary, parent: Node3D, ground := Callable(), publish := Callable(), ridden := Callable()) -> Node3D:
	var node := _node(row, parent, ground)
	var body := _body(node)
	var at_origin := Transform3D(Basis.IDENTITY, ride_frame(row)["origin"])
	var baked := false
	if fits_seat(row) and not (parts.get("base", []) as Array).is_empty():
		var lip := origin(String(row.get("recipe", ""))) == ORIGIN_ENTRY_LIP
		var fit := seat_fit(row, authored_ends(parts["base"][0], lip), ground)
		if fit["ok"]:
			at_origin = fit["transform"]
			baked = true
			node.set_meta("seat_fit", at_origin)
			node.set_meta("seat_stretch", fit["stretch"])
	if not baked and footed(row) and ground.is_valid() and not (parts.get("base", []) as Array).is_empty():
		var foot := foot_fit(row, col_faces(parts["base"][0]), node.transform * at_origin, ground)
		if foot["stretch"] > 1.0:
			at_origin = Transform3D(foot["basis"], at_origin.origin + foot["shift"])
			baked = true
			node.set_meta("foot_stretch", foot["stretch"])
	var fits := [[at_origin, "", 0.0]]
	var tiles: Array[Transform3D] = []
	if fits_tile(row) and not (parts.get("base", []) as Array).is_empty():
		var lip := origin(String(row.get("recipe", ""))) == ORIGIN_ENTRY_LIP
		var tile := tile_fit(row, authored_ends(parts["base"][0], lip), tile_ends(parts["base"][0], lip), ground)
		if tile["ok"]:
			baked = true
			fits = []
			for k in (tile["copies"] as Array).size():
				var xf: Transform3D = tile["copies"][k]["transform"]
				fits.append([xf, "_tile%d" % k, 0.0])
				tiles.append(xf)
			node.set_meta("tile_fit", tiles)
			node.set_meta("tile_count", tile["count"])
			node.set_meta("tile_stretch", tile["stretch"])
	var r :=ranges(String(row.get("budget", "landform")))
	var base_end := float(r.get("base_end", 0.0))
	var footing := Footings.fit(row, node.transform, at_origin, tiles, ground, ridden)
	if not footing.is_empty():
		var footing_view := footing["view"] as MeshInstance3D
		_range(footing_view, 0.0, base_end, float(r.get("base_margin", 0.0)))
		footing_view.set_meta(RecipeProps.META_FADE, true)
		node.add_child(footing_view)
		body.add_child(footing["shape"])
	var mid_end := float(r.get("mid_end", 0.0))
	for scene: Node in parts.get("base", []):
		for f: Array in fits:
			for view in _views(scene, node, body, f[0], baked, f[1]):
				view.position.y += float(f[2])
				_range(view, 0.0, base_end, float(r.get("base_margin", 0.0)))
				view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var shell_ranges: Array = r.get("shells", [])
	var shells: Array = parts.get("shells", [])
	for k in shells.size():
		var sr: Array = shell_ranges[k] if k < shell_ranges.size() else [0.0, 0.0]
		for f: Array in fits:
			for view in _views(shells[k], node, body, f[0], baked, f[1]):
				view.position.y += float(f[2])
				_range(view, 0.0, float(sr[0]), float(sr[1]))
				view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for scene: Node in parts.get("mid", []):
		for f: Array in fits:
			for view in _views(scene, node, body, f[0], baked, f[1]):
				view.position.y += float(f[2])
				_range(view, base_end, mid_end, float(r.get("mid_margin", 0.0)))
				view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for scene: Node in parts.get("far", []):
		for f: Array in fits:
			for view in _views(scene, node, body, f[0], baked, f[1]):
				view.position.y += float(f[2])
				_range(view, mid_end, 0.0, 0.0)
				view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if baked and fits_seat(row) and DRAPED.has(String(row.get("recipe", ""))) and ground.is_valid():
		drape(node, row, at_origin, ground)
	if body.get_shape_owners().is_empty():
		body.collision_layer = 0
	_sensor(node, row, publish)
	tag_cover(node, row)
	return node


static func wash_profile(x: float, width: float, depth: float) -> float:
	var t := absf(2.0 * x / maxf(width, 0.001))
	if t >= 1.0:
		return depth
	if t <= 0.4:
		return 0.0
	var w := (t - 0.4) / 0.6
	return depth * w * w


static func drape(node: Node3D, row: Dictionary, at_origin: Transform3D, ground: Callable) -> void:
	var frame := row_transform(row, ground)
	var width := float(row["size"][2])
	var depth := float(row["size"][1])
	var back := at_origin.affine_inverse()
	for view: MeshInstance3D in node.find_children("*", "MeshInstance3D", false, false):
		var mesh := view.mesh
		if mesh == null:
			continue
		var out := ArrayMesh.new()
		for i in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(i)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for k in verts.size():
				var v := view.transform * verts[k]
				var p := back * v
				var w := frame * v
				v.y = float(ground.call(w.x, w.z)) - frame.origin.y + p.y - wash_profile(p.x, width, depth)
				verts[k] = v
			arrays[Mesh.ARRAY_VERTEX] = verts
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			out.surface_set_material(i, mesh.surface_get_material(i))
		var overrides := []
		for i in mesh.get_surface_count():
			overrides.append(view.get_surface_override_material(i))
		view.mesh = out
		for i in overrides.size():
			if overrides[i] != null:
				view.set_surface_override_material(i, overrides[i])
		view.transform = Transform3D.IDENTITY


static func place_greybox(row: Dictionary, element: String, parent: Node3D, ground := Callable(), publish := Callable()) -> Node3D:
	if not ELEMENT_FACTS.has(element):
		push_warning("park_recipes: greybox:%s names no park element (%s)" % [element, row.get("id", "")])
		return null
	var size: Array = row["size"]
	var extent := Vector3(float(size[2]), float(size[1]), float(size[0]))
	var node := _node(row, parent, ground)
	var body := _body(node)
	var view := MeshInstance3D.new()
	view.name = "Greybox"
	var shape := CollisionShape3D.new()
	if WEDGES.has(element):
		var points := _wedge(extent, float(WEDGES[element]))
		view.mesh = _wedge_mesh(points)
		var convex := ConvexPolygonShape3D.new()
		convex.points = points
		shape.shape = convex
	else:
		var box := BoxMesh.new()
		box.size = extent
		view.mesh = box
		view.position.y = extent.y * 0.5
		var box_shape := BoxShape3D.new()
		box_shape.size = extent
		shape.shape = box_shape
		shape.position.y = extent.y * 0.5
	var material := StandardMaterial3D.new()
	material.albedo_color = GREYBOX_TINT
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	view.material_override = material
	view.set_meta(RecipeProps.META_FADE, true)
	node.add_child(view)
	body.add_child(shape)
	_sensor(node, row, publish)
	tag_cover(node, row)
	return node


static func place_over_greybox(row: Dictionary, p: Dictionary, budget: String, parent: Node3D, ground := Callable(),
		publish := Callable()) -> Node3D:
	var node := place_greybox(row, String(row.get("element", "")), parent, ground, publish)
	if node == null:
		return null
	var grey := node.get_node("Greybox")
	node.remove_child(grey)
	grey.free()
	var body := _body(node)
	body.name = "PieceCollider"
	var r := ranges(budget)
	var shell_ranges: Array = r.get("shells", [])
	var parts: Array = [[p["base"], [0.0, float(r.get("base_end", 0.0)), float(r.get("base_margin", 0.0))], true]]
	for k in (p["shells"] as Array).size():
		var sr: Array = shell_ranges[k] if k < shell_ranges.size() else [0.0, 0.0]
		parts.append([p["shells"][k], [0.0, float(sr[0]), float(sr[1])], false])
	for part: Array in parts:
		for scene: Node in _load(part[0]):
			for view in _views(scene, node, body, Transform3D.IDENTITY):
				_range(view, part[1][0], part[1][1], part[1][2])
				view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if part[2] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			scene.free()
	if body.get_child_count() == 0:
		node.remove_child(body)
		body.free()
	node.set_meta("over_greybox", true)
	tag_cover(node, row)
	return node


static func _node(row: Dictionary, parent: Node3D, ground: Callable) -> Node3D:
	var node := Node3D.new()
	node.name = "Park_%s" % String(row.get("id", "row"))
	node.set_meta("park_recipe", String(row.get("recipe", "")))
	parent.add_child(node)
	node.transform = row_transform(row, ground)
	return node


static func _body(node: Node3D) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Collider"
	body.collision_layer = 0
	body.collision_mask = 0
	body.set_collision_layer_value(WORLD_LAYER, true)
	node.add_child(body)
	return body


static func _views(scene: Node, node: Node3D, body: StaticBody3D, at_origin: Transform3D, baked := false, suffix := "") -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for source: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if source.mesh == null:
			continue
		var xf := at_origin * _relative(source, scene)
		if String(source.name).ends_with(COL_SUFFIX):
			var shape := CollisionShape3D.new()
			var trimesh := _trimesh(source)
			if baked:
				var moved := ConcavePolygonShape3D.new()
				moved.backface_collision = trimesh.backface_collision
				moved.set_faces(xf * trimesh.get_faces())
				shape.shape = moved
			else:
				shape.shape = trimesh
				shape.transform = xf
			body.add_child(shape)
			continue
		var view := MeshInstance3D.new()
		view.name = String(source.name) + suffix
		view.mesh = source.mesh
		for i in source.mesh.get_surface_count():
			var original := source.mesh.surface_get_material(i)
			var slot := String(original.resource_name) if original != null else ""
			if RecipeProps.is_slot_role(slot):
				view.set_surface_override_material(i, RecipeProps.slot_material(slot))
		view.set_meta(RecipeProps.META_FADE, true)
		node.add_child(view)
		view.transform = xf
		out.append(view)
	return out


# Godot 4.7.2 imports "<name>-col" GLTF nodes as MeshInstance3D with a StaticBody3D child holding ConcavePolygonShape3D.
static func _trimesh(source: MeshInstance3D) -> ConcavePolygonShape3D:
	for child in source.find_children("*", "CollisionShape3D", true, false):
		if (child as CollisionShape3D).shape is ConcavePolygonShape3D:
			return (child as CollisionShape3D).shape
	return source.mesh.create_trimesh_shape()


static func _range(view: GeometryInstance3D, begin: float, end: float, margin: float) -> void:
	view.visibility_range_begin = begin
	view.visibility_range_end = end
	view.visibility_range_end_margin = margin
	view.visibility_range_begin_margin = margin if begin > 0.0 else 0.0
	view.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


static func _sensor(node: Node3D, row: Dictionary, publish: Callable) -> void:
	var facts := []
	for fact in [String(row.get("ride_fact", "")), String(row.get("music_layer", ""))]:
		if EventKinds.WORLD_ROWS.has(fact):
			facts.append(fact)
	if not publish.is_valid() or facts.is_empty():
		return
	var size: Array = row["size"]
	var area := Area3D.new()
	area.name = "Ride"
	area.collision_layer = 0
	area.collision_mask = 0
	area.set_collision_mask_value(BALL_LAYER, true)
	area.monitorable = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(float(size[2]), float(size[1]) + SENSOR_ABOVE_M, float(size[0]))
	shape.shape = box
	shape.position.y = box.size.y * 0.5
	area.add_child(shape)
	node.add_child(area)
	area.body_entered.connect(func(ball: Node3D) -> void:
		for fact: String in facts:
			_fire(area, fact, ball.global_position, publish))


static func _fire(area: Area3D, fact: String, at: Vector3, publish: Callable) -> void:
	if fact.begins_with(ONCE_FACT_PREFIX):
		if area.has_meta("fired"):
			return
		area.set_meta("fired", true)
		var rows := area.get_parent().get_parent()
		for rider: Node in rows.get_children() if rows != null else []:
			if rider.is_in_group(RIDER_GROUP) and rider.get_meta("on", "") == fact:
				swing(rider)
	publish.call(fact, at)


static func place_rider(row: Dictionary, parent: Node3D, ground := Callable()) -> Node3D:
	var rider: Dictionary = row["rider"]
	var piece := {"id": "%s_rider" % row["id"], "element": "ground", "at": rider["at"], "y": null, "size": [1.0, 1.0, 1.0],
		"yaw_deg": float(rider.get("yaw_deg", 0.0)), "ride_fact": "", "recipe": rider["recipe"], "budget": "landform", "stamp": ""}
	var node := place(piece, parent, ground)
	if node != null:
		node.set_meta("on", String(rider.get("on", "")))
		node.add_to_group(RIDER_GROUP)
	return node


static func swing(rider: Node) -> void:
	if rider.has_meta("swung"):
		return
	rider.set_meta("swung", true)
	for view: Node in rider.find_children("*_jib", "MeshInstance3D", true, false):
		var jib := view as MeshInstance3D
		var start := jib.transform
		var tween := jib.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_method(func(a: float) -> void: jib.transform = Transform3D(Basis(Vector3.UP, a), Vector3.ZERO) * start,
			0.0, deg_to_rad(RIDER_SWING_DEG), RIDER_SWING_S)


static func _wedge(extent: Vector3, rise: float) -> PackedVector3Array:
	var hw := extent.x * 0.5
	var hl := extent.z * 0.5
	var high := hl * rise
	return PackedVector3Array([
		Vector3(-hw, 0, -hl), Vector3(hw, 0, -hl), Vector3(hw, 0, hl), Vector3(-hw, 0, hl),
		Vector3(-hw, extent.y, high), Vector3(hw, extent.y, high),
	])


static func _wedge_mesh(p: PackedVector3Array) -> ArrayMesh:
	var low_edge := [p[0], p[1]] if p[4].z > 0.0 else [p[3], p[2]]
	var high_base := [p[3], p[2]] if p[4].z > 0.0 else [p[0], p[1]]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tris := [
		[p[0], p[1], p[2]], [p[0], p[2], p[3]],
		[low_edge[0], low_edge[1], p[5]], [low_edge[0], p[5], p[4]],
		[high_base[0], high_base[1], p[5]], [high_base[0], p[5], p[4]],
		[low_edge[0], p[4], high_base[0]], [low_edge[1], high_base[1], p[5]],
	]
	for tri in tris:
		for v: Vector3 in tri:
			st.add_vertex(v)
	st.generate_normals()
	return st.commit()


static func _load(path: String) -> Array:
	if not ResourceLoader.exists(path):
		return []
	var packed := load(path) as PackedScene
	return [packed.instantiate()] if packed != null else []


static func _relative(node: Node3D, top: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var walk: Node = node
	while walk != null and walk != top:
		if walk is Node3D:
			xf = (walk as Node3D).transform * xf
		walk = walk.get_parent()
	return xf


static func placed_rows(park: Dictionary) -> Array:
	return (park.get("park_rows", []) as Array).filter(func(row: Dictionary) -> bool: return String(row.get("recipe", "")) != "")


static func layer_rows(park: Dictionary) -> Array:
	return (park.get("park_rows", []) as Array).filter(func(row: Dictionary) -> bool:
		return String(row.get("recipe", "")) == "" and String(row.get("music_layer", "")) != "")


static func place_layer(row: Dictionary, parent: Node3D, ground := Callable(), publish := Callable()) -> Node3D:
	var node := _node(row, parent, ground)
	node.name = "Layer_" + String(row.get("id", ""))
	var layer := row.duplicate()
	layer["ride_fact"] = ""
	_sensor(node, layer, publish)
	tag_cover(node, row)
	return node


static func clear_zones(park: Dictionary) -> Array:
	var out := []
	var places := {}
	var ends := {}
	for row: Dictionary in park.get("park_rows", []):
		var yaw := deg_to_rad(float(row.get("yaw_deg", 0.0)))
		var half := Vector2(sin(yaw), cos(yaw)) * float(row["size"][0]) * 0.5
		places[row["id"]] = [_v2(row["at"])]
		ends[row["id"]] = [_v2(row["at"]) - half, _v2(row["at"]) + half]
		if row["element"] != "ground" and row["element"] != "anchor_field" and not spans_park(row, park):
			out.append(_zone(row))
	for row: Dictionary in park.get("activity_rows", []):
		places[row["id"]] = [_v2(row["at"])]
	var mark: Dictionary = park.get("landmark", {})
	if not mark.is_empty():
		out.append(_zone(mark))
		places[LANDMARK] = [_v2(mark["beacon"])]
	if park.has("spawn"):
		places[DROP_IN] = [_v2(park["spawn"]["at"])]
	var by_end := places.duplicate()
	by_end.merge(ends, true)
	var chains: Array = [[park.get("waymarks", []), places]]
	for route: Dictionary in park.get("routes", []):
		var chain: Array = [route["from"]]
		chain.append_array(route["via"])
		chain.append(route["to"])
		chains.append([chain, by_end])
	for pair: Array in chains:
		var chain: Array = pair[0]
		var at: Dictionary = pair[1]
		for k in range(1, chain.size()):
			if not at.has(chain[k - 1]) or not at.has(chain[k]) or chain[k - 1] == chain[k]:
				continue
			var best := INF
			var leg := []
			for pa: Vector2 in at[chain[k - 1]]:
				for pb: Vector2 in at[chain[k]]:
					if pa.distance_to(pb) < best:
						best = pa.distance_to(pb)
						leg = [pa, pb]
			if best > 0.001:
				out.append({"a": leg[0], "b": leg[1], "half": ROUTE_LANE_HALF_M})
	return out


static func spans_park(row: Dictionary, park: Dictionary) -> bool:
	if not park.has("play_rect") or not String(row.get("recipe", "")).begins_with(GREYBOX) \
			or String(row.get("stamp", "")) == "" or row.get("y") != null:
		return false
	var rect: Array = park["play_rect"]
	var yaw := deg_to_rad(float(row.get("yaw_deg", 0.0)))
	return float(row["size"][2]) >= absf(cos(yaw)) * float(rect[2]) + absf(sin(yaw)) * float(rect[3])


static func _zone(row: Dictionary) -> Dictionary:
	return {"at": _v2(row["at"]), "size": Vector2(float(row["size"][0]), float(row["size"][2])), "yaw": deg_to_rad(float(row.get("yaw_deg", 0.0)))}


static func _v2(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


static func in_clear(zones: Array, p: Vector2, r: float, side := -1.0) -> bool:
	for z: Dictionary in zones:
		if z.has("a"):
			var a: Vector2 = z["a"]
			var ab: Vector2 = (z["b"] as Vector2) - a
			var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
			if p.distance_to(a + ab * t) <= float(z["half"]) + r:
				return true
		else:
			var yaw: float = z["yaw"]
			var d: Vector2 = p - (z["at"] as Vector2)
			var size: Vector2 = z["size"]
			if absf(d.dot(Vector2(sin(yaw), cos(yaw)))) <= size.x * 0.5 + r and absf(d.dot(Vector2(cos(yaw), -sin(yaw)))) <= size.y * 0.5 + (r if side < 0.0 else side):
				return true
	return false


static func anchor_posts(row: Dictionary, zones: Array = [], pitch := ANCHOR_PITCH_M) -> PackedVector2Array:
	var out := PackedVector2Array()
	var size: Array = row["size"]
	var half_l := float(size[0]) * 0.5
	var half_w := float(size[2]) * 0.5
	var yaw := deg_to_rad(float(row.get("yaw_deg", 0.0)))
	var along := Vector2(sin(yaw), cos(yaw))
	var across := Vector2(cos(yaw), -sin(yaw))
	var at := _v2(row["at"])
	var rows := int(floor(2.0 * half_l / pitch))
	var cols := int(floor(2.0 * half_w / pitch))
	var lanes := zones.filter(func(z: Dictionary) -> bool: return z.has("a"))
	var footprints := zones.filter(func(z: Dictionary) -> bool: return not z.has("a"))
	var r := ANCHOR_POST_M * 0.5
	var clear := func(p: Vector2) -> bool: return not in_clear(lanes, p, r) and not in_clear(footprints, p, r + ANCHOR_RUNOUT_M, r + ANCHOR_SIDE_M)
	var inside := func(p: Vector2) -> bool:
		var d := p - at
		return absf(d.dot(along)) <= half_l and absf(d.dot(across)) <= half_w
	var stand := NATURAL_STANDS.has(String(row.get("landform", ""))) and minf(2.0 * half_l, 2.0 * half_w) >= ANCHOR_STAND_MIN_M
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(row.get("id", "")) + ":stand")
	var spots := {}
	var order: Array[Vector2i] = []
	for j in rows + 1:
		var lz := -rows * pitch * 0.5 + j * pitch
		var lx := -cols * pitch * 0.5 + (pitch * 0.5 if j % 2 == 1 else 0.0)
		var c := 0
		while lx <= half_w + 0.001:
			var p := at + across * lx + along * lz
			spots[Vector2i(j, c)] = [p, clear.call(p), minf(half_l - absf(lz), half_w - absf(lx))]
			order.append(Vector2i(j, c))
			lx += pitch
			c += 1
	var placed := {}
	for key: Vector2i in order:
		var spot: Array = spots[key]
		var p: Vector2 = spot[0]
		var turn := rng.randf() * TAU
		var reach := sqrt(rng.randf()) * ANCHOR_STAND_JITTER_M * clampf(float(spot[2]) / pitch, 0.0, 1.0)
		if not spot[1]:
			continue
		var moved := p + Vector2(cos(turn), sin(turn)) * reach
		var kept := moved if stand and _stand_neighbours(spots, key) and inside.call(moved) and clear.call(moved) and _stand_room(placed, moved) else p
		out.append(kept)
		if stand:
			var cell := Vector2i(floori(kept.x / ANCHOR_STAND_GAP_M), floori(kept.y / ANCHOR_STAND_GAP_M))
			placed[cell] = (placed.get(cell, []) as Array) + [kept]
	var room := {}
	for p: Vector2 in out:
		var cell := Vector2i(floori(p.x / ANCHOR_POST_M), floori(p.y / ANCHOR_POST_M))
		room[cell] = (room.get(cell, []) as Array) + [p]
	for lane: Dictionary in lanes:
		var a: Vector2 = lane["a"]
		var ab: Vector2 = (lane["b"] as Vector2) - a
		var length := ab.length()
		var dir := ab / length
		var side := Vector2(-dir.y, dir.x) * (float(lane["half"]) + r + 0.5)
		var reach := Vector2(half_l, half_w).length() + side.length()
		var t := (at - a).dot(dir)
		if absf((at - a).dot(Vector2(-dir.y, dir.x))) > reach or t < -reach or t > length + reach:
			continue
		var s := maxf(0.0, floorf((t - reach) / ANCHOR_EDGE_STEP_M) * ANCHOR_EDGE_STEP_M)
		var s_end := minf(length, t + reach)
		while s <= s_end + 0.001:
			for p: Vector2 in [a + dir * s + side, a + dir * s - side]:
				if inside.call(p) and clear.call(p) and _room(room, p, ANCHOR_POST_M):
					out.append(p)
					var cell := Vector2i(floori(p.x / ANCHOR_POST_M), floori(p.y / ANCHOR_POST_M))
					room[cell] = (room.get(cell, []) as Array) + [p]
			s += ANCHOR_EDGE_STEP_M
	return out


static func field_posts(rows: Array, zones: Array) -> Dictionary:
	var all := {}
	var order: Array[int] = []
	var rest: Array[int] = []
	for i in rows.size():
		if not is_anchor_field(rows[i]):
			continue
		all[i] = anchor_posts(rows[i], zones)
		if (all[i] as PackedVector2Array).size() == 1:
			order.append(i)
		else:
			rest.append(i)
	order.append_array(rest)
	var out := {}
	var kept := {}
	for i in order:
		var mine := {}
		var posts := PackedVector2Array()
		for p: Vector2 in all[i]:
			if _room(kept, p, ANCHOR_POST_M):
				posts.append(p)
				var cell := Vector2i(floori(p.x / ANCHOR_POST_M), floori(p.y / ANCHOR_POST_M))
				mine[cell] = (mine.get(cell, []) as Array) + [p]
		for cell: Vector2i in mine:
			kept[cell] = (kept.get(cell, []) as Array) + mine[cell]
		out[i] = posts
	var by_row := {}
	for i: int in all:
		by_row[i] = out[i]
	return by_row


static func _stand_neighbours(spots: Dictionary, key: Vector2i) -> bool:
	var shift := 0 if key.x % 2 == 1 else -1
	for n: Vector2i in [Vector2i(key.x, key.y - 1), Vector2i(key.x, key.y + 1), Vector2i(key.x - 1, key.y + shift),
			Vector2i(key.x - 1, key.y + shift + 1), Vector2i(key.x + 1, key.y + shift), Vector2i(key.x + 1, key.y + shift + 1)]:
		if spots.has(n) and not spots[n][1]:
			return false
	return true


static func _stand_room(placed: Dictionary, p: Vector2) -> bool:
	return _room(placed, p, ANCHOR_STAND_GAP_M)


static func _room(placed: Dictionary, p: Vector2, gap: float) -> bool:
	var cell := Vector2i(floori(p.x / gap), floori(p.y / gap))
	for dj in range(-1, 2):
		for di in range(-1, 2):
			for q: Vector2 in placed.get(cell + Vector2i(di, dj), []):
				if q.distance_to(p) < gap:
					return false
	return true


static func is_anchor_field(row: Dictionary) -> bool:
	var recipe := String(row.get("recipe", ""))
	return recipe == GREYBOX + "anchor_field" or ANCHOR_KITS.has(recipe)


static func anchor_paths(recipe: String) -> Array:
	if not ANCHOR_KITS.has(recipe):
		return []
	return ANCHOR_VARIANTS.map(func(v: String) -> String: return GLB_DIR + recipe + "_" + v + ".glb")


static func _add_shape(body: CollisionObject3D, shape: Shape3D, at: Transform3D) -> void:
	var owner_id := body.create_shape_owner(body)
	body.shape_owner_add_shape(owner_id, shape)
	body.shape_owner_set_transform(owner_id, at)


static func collider_shapes(root: Node) -> Array:
	var out: Array = []
	var bodies: Array = [root] if root is CollisionObject3D else []
	bodies.append_array(root.find_children("*", "CollisionObject3D", true, false))
	for body: CollisionObject3D in bodies:
		for owner_id in body.get_shape_owners():
			var at := body.shape_owner_get_transform(owner_id)
			var world := body.global_transform * at if body.is_inside_tree() else _chain(body) * at
			for i in body.shape_owner_get_shape_count(owner_id):
				out.append({"shape": body.shape_owner_get_shape(owner_id, i), "transform": at, "position": at.origin,
					"global_transform": world, "disabled": body.is_shape_owner_disabled(owner_id), "owner": owner_id, "body": body})
	return out


static func _chain(node: Node) -> Transform3D:
	var out := Transform3D.IDENTITY
	while node is Node3D:
		out = (node as Node3D).transform * out
		node = node.get_parent()
	return out


static func shape_aabb(shape: Shape3D) -> AABB:
	if shape is BoxShape3D:
		var sz := (shape as BoxShape3D).size
		return AABB(-sz * 0.5, sz)
	if shape is ConvexPolygonShape3D:
		var pts := (shape as ConvexPolygonShape3D).points
		if pts.is_empty():
			return AABB()
		var box := AABB(pts[0], Vector3.ZERO)
		for p in pts:
			box = box.expand(p)
		return box
	if shape is ConcavePolygonShape3D:
		var faces := (shape as ConcavePolygonShape3D).get_faces()
		if faces.is_empty():
			return AABB()
		var box := AABB(faces[0], Vector3.ZERO)
		for v in faces:
			box = box.expand(v)
		return box
	return shape.get_debug_mesh().get_aabb()


static func cover_height(node: Node3D, layer_mask := 1 << (WORLD_LAYER - 1), stop_at := 0.0) -> float:
	var lo := INF
	var hi := -INF
	var local_boxes := {}
	for entry: Dictionary in collider_shapes(node):
		if entry["disabled"] or entry["shape"] == null:
			continue
		var body: CollisionObject3D = entry["body"]
		if not body is StaticBody3D or (body.collision_layer & layer_mask) == 0:
			continue
		var shape: Shape3D = entry["shape"]
		var sid := shape.get_instance_id()
		var local_box: AABB
		if local_boxes.has(sid):
			local_box = local_boxes[sid]
		else:
			local_box = shape_aabb(shape)
			local_boxes[sid] = local_box
		var world_box: AABB = (entry["global_transform"] as Transform3D) * local_box
		lo = minf(lo, world_box.position.y)
		hi = maxf(hi, world_box.end.y)
		if stop_at > 0.0 and hi - lo >= stop_at:
			return hi - lo
	return maxf(hi - lo, 0.0) if hi >= lo else 0.0


static func cover_kind_of(node: Node3D, row: Dictionary = {}) -> String:
	if row.get("cover") is String:
		var explicit := String(row["cover"])
		if COVER_KINDS.has(explicit):
			return explicit
	var h := cover_height(node, 1 << (WORLD_LAYER - 1), COVER_HARD_M)
	if h >= COVER_HARD_M:
		return COVER_HARD
	if h > 0.0:
		return COVER_SURFACE
	return COVER_SOFT


static func tag_cover(node: Node3D, row: Dictionary = {}) -> String:
	var kind := cover_kind_of(node, row)
	assert(COVER_KINDS.has(kind), "park_recipes: invalid cover kind '%s'" % kind)
	node.set_meta(COVER_META, kind)
	return kind


static func cover_kind(node: Node) -> String:
	return String(node.get_meta(COVER_META, "")) if node != null else ""


static func anchor_kit_ready(recipe: String) -> bool:
	var p := anchor_paths(recipe)
	return not p.is_empty() and p.all(func(path: String) -> bool: return ResourceLoader.exists(path))


static func place_anchor_field(row: Dictionary, parent: Node3D, ground := Callable(), zones: Array = [], pitch := ANCHOR_PITCH_M, posts = null) -> Node3D:
	var node := _node(row, parent, ground)
	var body := _body(node)
	var tall := float(row["size"][1]) + ANCHOR_SINK_M
	var extent := Vector3(ANCHOR_POST_M, tall, ANCHOR_POST_M)
	if posts == null:
		posts = anchor_posts(row, zones, pitch)
	var inv := node.transform.affine_inverse()
	var box := BoxShape3D.new()
	box.size = extent
	var recipe := String(row.get("recipe", ""))
	var kit := anchor_kit_ready(recipe)
	if ANCHOR_KITS.has(recipe) and not kit:
		push_warning("park_recipes: %s variants missing, %s stands in as grey posts" % [recipe, row.get("id", "")])
	var fit := anchor_fit_boxes(row) if kit else []
	var hulls := anchor_hulls(row, fit) if not fit.is_empty() else []
	var fit_shapes := {}
	for k in posts.size():
		var p: Vector2 = posts[k]
		var base := float(ground.call(p.x, p.y)) if ground.is_valid() else node.position.y
		if not fit.is_empty():
			var turn := anchor_turn(row, k)
			var odd := anchor_quarters(row, k) % 2 == 1
			var origin := inv * Vector3(p.x, base, p.y)
			for i in fit.size():
				var b: Dictionary = fit[i]
				if i < hulls.size() and hulls[i] != null:
					_add_shape(body, hulls[i], Transform3D(turn, origin))
					continue
				var key := i * 2 + (1 if odd else 0)
				if not fit_shapes.has(key):
					var fitted := BoxShape3D.new()
					var sx := float(b["x"][1]) - float(b["x"][0])
					var sz := float(b["z"][1]) - float(b["z"][0])
					fitted.size = Vector3(sz, float(b["h"][1]) - float(b["h"][0]), sx) if odd else Vector3(sx, float(b["h"][1]) - float(b["h"][0]), sz)
					fit_shapes[key] = fitted
				_add_shape(body, fit_shapes[key], Transform3D(Basis.IDENTITY, origin + turn * Vector3((float(b["x"][0]) + float(b["x"][1])) * 0.5,
					(float(b["h"][0]) + float(b["h"][1])) * 0.5, (float(b["z"][0]) + float(b["z"][1])) * 0.5)))
			continue
		_add_shape(body, box, Transform3D(Basis.IDENTITY, inv * Vector3(p.x, base - ANCHOR_SINK_M + tall * 0.5, p.y)))
	var xfs := anchor_draws(row, posts, ground, node.transform, kit)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	var view := MultiMeshInstance3D.new()
	view.name = "Posts"
	if kit:
		var post := _anchor_mesh(anchor_paths(recipe)[anchor_variant(row)])
		multi.mesh = post[0]
		if post[1] != null:
			view.material_override = post[1]
	else:
		var mesh := BoxMesh.new()
		mesh.size = extent
		multi.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = GREYBOX_TINT
		view.material_override = material
	multi.instance_count = xfs.size()
	for k in xfs.size():
		multi.set_instance_transform(k, xfs[k])
	view.multimesh = multi
	var dense_field := kit and xfs.size() > 24
	view.visibility_range_begin = 0.0
	view.visibility_range_begin_margin = 0.0
	view.visibility_range_end = 115.0 if dense_field else 260.0
	view.visibility_range_end_margin = 12.0 if dense_field else 20.0
	view.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.set_meta(RecipeProps.META_FADE, true)
	node.add_child(view)
	if dense_field:
		var lod_multi := MultiMesh.new()
		lod_multi.transform_format = MultiMesh.TRANSFORM_3D
		lod_multi.mesh = _anchor_lod_mesh(multi.mesh)
		lod_multi.instance_count = xfs.size()
		for k in xfs.size():
			lod_multi.set_instance_transform(k, xfs[k])
		var lod_view := MultiMeshInstance3D.new()
		lod_view.name = "PostsLod"
		lod_view.multimesh = lod_multi
		if view.material_override != null:
			lod_view.material_override = view.material_override
		lod_view.visibility_range_begin = 115.0
		lod_view.visibility_range_begin_margin = 12.0
		lod_view.visibility_range_end = 260.0
		lod_view.visibility_range_end_margin = 20.0
		lod_view.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		lod_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lod_view.set_meta(RecipeProps.META_FADE, true)
		node.add_child(lod_view)
	if body.get_shape_owners().is_empty():
		body.collision_layer = 0
	node.set_meta("anchor_posts", posts.size())
	node.set_meta("anchor_kit", kit)
	tag_cover(node, row)
	return node


static var _anchor_lod_cache: Dictionary = {}


static func _anchor_lod_mesh(source: Mesh) -> ArrayMesh:
	var key := source.get_instance_id() if source != null else 0
	if _anchor_lod_cache.has(key):
		return _anchor_lod_cache[key] as ArrayMesh
	var box := source.get_aabb() if source != null else AABB(Vector3(-0.6, 0.0, -0.6), Vector3(1.2, 10.0, 1.2))
	var r := maxf(0.35, minf(box.size.x, box.size.z) * 0.45)
	var y0 := box.position.y
	var y1 := box.end.y
	var cx := box.position.x + box.size.x * 0.5
	var cz := box.position.z + box.size.z * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 4
	var bot: Array[Vector3] = []
	var top: Array[Vector3] = []
	for i in sides:
		var ang := TAU * float(i) / float(sides) + PI * 0.25
		bot.append(Vector3(cx + cos(ang) * r, y0, cz + sin(ang) * r))
		top.append(Vector3(cx + cos(ang) * r * 0.78, y1, cz + sin(ang) * r * 0.78))
	for i in sides:
		var ni := (i + 1) % sides
		var a := bot[i]
		var b := bot[ni]
		var c := top[ni]
		var d := top[i]
		var n := (d - a).cross(b - a).normalized()
		st.set_normal(n)
		st.set_color(Color(0.72, 0.68, 0.62, 1.0))
		st.add_vertex(a)
		st.add_vertex(b)
		st.add_vertex(c)
		st.add_vertex(a)
		st.add_vertex(c)
		st.add_vertex(d)
	st.set_normal(Vector3.UP)
	st.set_color(Color(0.78, 0.74, 0.68, 1.0))
	st.add_vertex(top[0])
	st.add_vertex(top[3])
	st.add_vertex(top[2])
	st.add_vertex(top[0])
	st.add_vertex(top[2])
	st.add_vertex(top[1])
	var mesh := st.commit()
	_anchor_lod_cache[key] = mesh
	return mesh


static func anchor_variant(row: Dictionary) -> int:
	return hash(String(row.get("id", ""))) % ANCHOR_VARIANTS.size()


static func anchor_turn(row: Dictionary, k: int) -> Basis:
	return Basis(Vector3.UP, PI * 0.5 * float(anchor_quarters(row, k)))


static func anchor_quarters(row: Dictionary, k: int) -> int:
	return hash("%s:%d" % [row.get("id", ""), k]) % 4


static func anchor_fit_table() -> Dictionary:
	_anchor_fit_lock.lock()
	if not _anchor_fit_read:
		_anchor_fit_read = true
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(ANCHOR_FIT_PATH)) if FileAccess.file_exists(ANCHOR_FIT_PATH) else null
		if parsed is Dictionary and parsed.get("fits") is Dictionary:
			_anchor_fit = parsed
		else:
			push_warning("park_recipes: %s missing or unreadable, anchor posts keep the %s m box" % [ANCHOR_FIT_PATH, ANCHOR_POST_M])
	var out := _anchor_fit
	_anchor_fit_lock.unlock()
	return out


static func anchor_fit_boxes(row: Dictionary) -> Array:
	var recipe := String(row.get("recipe", ""))
	if not ANCHOR_KITS.has(recipe):
		return []
	var fits: Dictionary = anchor_fit_table().get("fits", {})
	var key: String = anchor_paths(recipe)[anchor_variant(row)].get_file().get_basename()
	var tall := float(row["size"][1])
	for entry in fits.get(key, []):
		if is_equal_approx(float(entry["size"]), tall):
			return entry["boxes"]
	return []


static func anchor_hulls(row: Dictionary, fit: Array) -> Array:
	var path: String = anchor_paths(String(row.get("recipe", "")))[anchor_variant(row)]
	var key := "%s|%s" % [path, str(float(row["size"][1]))]
	_anchor_hull_lock.lock()
	if _anchor_hulls.has(key):
		var cached: Array = _anchor_hulls[key]
		_anchor_hull_lock.unlock()
		return cached
	var out := []
	var mesh: Mesh = _anchor_mesh(path)[0]
	if mesh == null:
		push_warning("park_recipes: %s has no readable render mesh, its fitted posts keep boxes" % path)
	else:
		var s := (float(row["size"][1]) + ANCHOR_SINK_M) / ANCHOR_AUTHORED_M
		var tris := PackedVector3Array()
		for si in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(si)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var index = arrays[Mesh.ARRAY_INDEX]
			var order: PackedInt32Array = index if index != null and index.size() > 0 else PackedInt32Array(range(verts.size()))
			for n in order.size():
				var v := verts[order[n]]
				tris.append(Vector3(v.x, (v.y + 1.0) * s - ANCHOR_SINK_M, v.z))
		var lows := PackedFloat64Array()
		var highs := PackedFloat64Array()
		_tri_spans(tris, lows, highs)
		for b: Dictionary in fit:
			out.append(_band_hull(tris, float(b["h"][0]), float(b["h"][1]), lows, highs))
	_anchor_hulls[key] = out
	_anchor_hull_lock.unlock()
	return out


static func _band_hull(tris: PackedVector3Array, lo: float, hi: float, lows := PackedFloat64Array(), highs := PackedFloat64Array()) -> ConvexPolygonShape3D:
	if lows.is_empty():
		_tri_spans(tris, lows, highs)
	var pts := PackedVector3Array()
	for t in tris.size() / 3:
		if highs[t] < lo or lows[t] > hi:
			continue
		if lows[t] >= lo and highs[t] <= hi:
			pts.append(tris[t * 3])
			pts.append(tris[t * 3 + 1])
			pts.append(tris[t * 3 + 2])
			continue
		var poly: Array = [tris[t * 3], tris[t * 3 + 1], tris[t * 3 + 2]]
		for plane in 2:
			var edge := lo if plane == 0 else hi
			var way := 1.0 if plane == 0 else -1.0
			var next := []
			for i in poly.size():
				var a: Vector3 = poly[i]
				var c: Vector3 = poly[(i + 1) % poly.size()]
				var da := (a.y - edge) * way
				var dc := (c.y - edge) * way
				if da >= 0.0:
					next.append(a)
				if (da >= 0.0) != (dc >= 0.0):
					var cut := a.lerp(c, da / (da - dc))
					cut.y = edge
					next.append(cut)
			poly = next
			if poly.is_empty():
				break
		pts.append_array(PackedVector3Array(poly))
	var distinct := {}
	for p in pts:
		distinct[p] = true
	if distinct.size() < 4:
		return null
	var cloud := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(distinct.keys())
	cloud.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, arrays)
	var hull := cloud.create_convex_shape(true, false)
	if hull == null or hull.points.size() < 4:
		return null
	if hull.points.size() > ANCHOR_HULL_CAP:
		hull.points = _farthest_points(hull.points, ANCHOR_HULL_CAP)
	return hull


static func _tri_spans(tris: PackedVector3Array, lows: PackedFloat64Array, highs: PackedFloat64Array) -> void:
	lows.resize(tris.size() / 3)
	highs.resize(tris.size() / 3)
	for t in lows.size():
		lows[t] = minf(tris[t * 3].y, minf(tris[t * 3 + 1].y, tris[t * 3 + 2].y))
		highs[t] = maxf(tris[t * 3].y, maxf(tris[t * 3 + 1].y, tris[t * 3 + 2].y))


static func _farthest_points(points: PackedVector3Array, count: int) -> PackedVector3Array:
	var first := 0
	for i in points.size():
		var a := points[i]
		var b := points[first]
		if a.x > b.x or (a.x == b.x and (a.z > b.z or (a.z == b.z and a.y > b.y))):
			first = i
	var near := PackedFloat64Array()
	near.resize(points.size())
	near.fill(INF)
	var kept := PackedVector3Array()
	var pick := first
	while kept.size() < count:
		var p := points[pick]
		kept.append(p)
		var best := -1.0
		for i in points.size():
			near[i] = minf(near[i], p.distance_squared_to(points[i]))
			if near[i] > best:
				best = near[i]
				pick = i
		if best <= 0.0:
			break
	return kept


static func anchor_draws(row: Dictionary, posts: PackedVector2Array, ground: Callable, node_xf: Transform3D, kit: bool) -> Array:
	var tall := float(row["size"][1]) + ANCHOR_SINK_M
	var inv := node_xf.affine_inverse()
	var out := []
	var stretch := Basis.IDENTITY.scaled(Vector3(1.0, tall / ANCHOR_AUTHORED_M, 1.0))
	for k in posts.size():
		var p: Vector2 = posts[k]
		var bottom := (float(ground.call(p.x, p.y)) if ground.is_valid() else node_xf.origin.y) - ANCHOR_SINK_M
		if not kit:
			out.append(inv * Transform3D(Basis.IDENTITY, Vector3(p.x, bottom + tall * 0.5, p.y)))
			continue
		var turn := anchor_turn(row, k)
		out.append(Transform3D(turn * stretch, inv * Vector3(p.x, bottom + tall / ANCHOR_AUTHORED_M, p.y)))
	return out


static func _anchor_mesh(path: String) -> Array:
	if _anchor_meshes.has(path):
		return _anchor_meshes[path]
	var scene := (load(path) as PackedScene).instantiate()
	var out: Array = [null, null]
	for source: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if source.mesh == null or String(source.name).ends_with(COL_SUFFIX):
			continue
		out[0] = source.mesh
		var original := source.mesh.surface_get_material(0)
		var slot := String(original.resource_name) if original != null else ""
		if RecipeProps.is_slot_role(slot):
			out[1] = RecipeProps.slot_material(slot)
		break
	scene.free()
	_anchor_meshes[path] = out
	return out


static func place_row(row: Dictionary, parent: Node3D, ground := Callable(), publish := Callable(), zones: Array = [], posts = null, lift := 0.0, ridden := Callable()) -> Node3D:
	var recipe := String(row.get("recipe", ""))
	if is_anchor_field(row):
		return place_anchor_field(row, parent, ground, zones, ANCHOR_PITCH_M, posts)
	var node := place(row, parent, seat(row, ground), publish, ridden)
	if node != null and lift > 0.0:
		_lift_drawn(node, lift)
	if node != null and row.has("rider"):
		place_rider(row, parent, ground)
	if node != null and stamp_replaces(row):
		for part in ["Collider", "Greybox"]:
			var child := node.get_node_or_null(part)
			if child != null:
				node.remove_child(child)
				child.free()
		node.set_meta("stamp_replaces", true)
		tag_cover(node, row)
	return node


static func stamp_replaces(row: Dictionary) -> bool:
	return String(row.get("stamp", "")) != "" and row.get("y") == null \
		and (stands_in(row) or OVER_GREYBOX.has(String(row.get("recipe", ""))))


static func seat(row: Dictionary, ground: Callable) -> Callable:
	if not ground.is_valid() or not (stamp_replaces(row) or fits_drape(row)):
		return ground
	var f := Stamps.frame(row)
	return func(x: float, z: float) -> float: return float(ground.call(x, z)) - maxf(Stamps.offset(f, x, z), 0.0)


static func stands_in(row: Dictionary) -> bool:
	var recipe := String(row.get("recipe", ""))
	if recipe == "" or recipe.begins_with(GREYBOX):
		return recipe != ""
	if SENSOR_ONLY.has(recipe):
		return false
	if ANCHOR_KITS.has(recipe):
		return not anchor_kit_ready(recipe)
	if not ResourceLoader.exists(paths(recipe, _budget(row))["base"]):
		return true
	if fits_tile(row):
		return tile_refusal(row, recipe_ends(recipe), recipe_tile(recipe)) != ""
	return fits_seat(row) and seat_refusal(row, recipe_ends(recipe)) != ""


static func _budget(row: Dictionary) -> String:
	return String(row.get("budget", ROWS.get(String(row.get("recipe", "")), {}).get("budget", "landform")))


static func row_paths(row: Dictionary) -> Array:
	var recipe := String(row.get("recipe", ""))
	if recipe == "" or SENSOR_ONLY.has(recipe) or recipe.begins_with(GREYBOX):
		return []
	if ANCHOR_KITS.has(recipe):
		return anchor_paths(recipe).filter(func(path: String) -> bool: return ResourceLoader.exists(path))
	var p := paths(recipe, _budget(row))
	var out: Array = [p["base"]]
	out.append_array(p["shells"])
	for key in ["mid", "far"]:
		if p.has(key):
			out.append(p[key])
	if row.get("rider") is Dictionary:
		var r := paths(String(row["rider"].get("recipe", "")), "landform")
		out.append(r["base"])
		out.append_array(r["shells"])
	return out.filter(func(path: String) -> bool: return ResourceLoader.exists(path))


static func build_placed(parent: Node3D, park: Dictionary, ground: Callable, publish: Callable, threaded: bool, ridden := Callable()) -> Node3D:
	var node := Placer.new()
	node.name = "ParkRows"
	parent.add_child(node)
	node.start(park, ground, publish, threaded, ridden)
	return node


class Placer extends Node3D:
	signal built

	const Self := preload("res://src/world/park/park_recipes.gd")
	const Slots := preload("res://src/presentation/material_slots.gd")
	const BUILD_BUDGET_USEC := 4000

	enum Phase { IDLE, LOADING, BUILDING, READY }

	var phase := Phase.IDLE
	var slowest_usec := 0
	var slowest_step := ""
	var start_usec := 0
	var frame_usec_max := 0
	var threaded_loads := 0
	var build_frames := 0
	var row_usec_max := 0
	var _last_frame_usec := 0
	var _rows: Array = []
	var _landmark: Dictionary = {}
	var _park: Dictionary = {}
	var landmark: Node3D = null
	var _layers: Array = []
	var _zones: Array = []
	var _ground: Callable
	var _publish: Callable
	var _ridden: Callable
	var _pending: Array = []
	var _held: Array = []
	var _main_loads: Array = []
	var _headless_loads := false
	var main_load_usec_max := 0
	var _next := 0
	var _threaded := false
	var _posts := {}
	var _lifts := {}
	var _task := -1

	func is_ready() -> bool:
		return phase == Phase.READY

	func start(park: Dictionary, ground: Callable, publish: Callable, threaded: bool, ridden := Callable()) -> void:
		var t0 := Time.get_ticks_usec()
		_rows = Self.placed_rows(park)
		_layers = Self.layer_rows(park)
		_zones = Self.clear_zones(park)
		_ground = ground
		_publish = publish
		_ridden = ridden
		_threaded = threaded
		_landmark = Self.landmark_row(park)
		_park = park
		var wanted := []
		for row: Dictionary in _rows + ([_landmark] if not _landmark.is_empty() else []):
			for path: String in Self.row_paths(row):
				if not wanted.has(path):
					wanted.append(path)
		if not wanted.is_empty():
			for role: String in Slots.SLOTS:
				var slot: Dictionary = Slots.row(role)
				if String(slot.get("kind", "")) == "resource" and ResourceLoader.exists(String(slot["path"])) and not wanted.has(slot["path"]):
					wanted.append(String(slot["path"]))
		# Godot's headless dummy rasterizer mesh RID owner is not thread-safe ("Attempting to initialize the wrong RID"); load on main thread when headless.
		var headless := AppShell.headless()
		for path: String in (wanted if threaded and not headless else []):
			if ResourceLoader.load_threaded_request(path) == OK:
				_pending.append(path)
				threaded_loads += 1
		if threaded and headless:
			_main_loads = wanted.duplicate()
			_headless_loads = true
		if threaded:
			_task = WorkerThreadPool.add_task(_work_posts, false, "park anchor posts")
		else:
			_work_posts()
		phase = Phase.LOADING
		start_usec = Time.get_ticks_usec() - t0
		_meter(start_usec, "START")
		if threaded:
			set_process(true)
		else:
			finish()

	func _work_posts() -> void:
		_posts = Self.field_posts(_rows, _zones)
		_lifts = Self.surface_lifts(_rows)

	func _wait_posts() -> void:
		if _task != -1:
			WorkerThreadPool.wait_for_task_completion(_task)
			_task = -1

	func finish() -> void:
		while phase == Phase.LOADING:
			_poll_loading(true)
		_wait_posts()
		while phase == Phase.BUILDING:
			_build_step(-1)

	func _ready() -> void:
		set_process(phase == Phase.LOADING or phase == Phase.BUILDING)

	func _exit_tree() -> void:
		_wait_posts()
		for path: String in _pending:
			ResourceLoader.load_threaded_get(path)
		_pending.clear()
		_main_loads.clear()
		_held.clear()

	func _process(_delta: float) -> void:
		var t0 := Time.get_ticks_usec()
		if _last_frame_usec > 0:
			frame_usec_max = maxi(frame_usec_max, t0 - _last_frame_usec)
		_last_frame_usec = t0
		var was := phase
		match phase:
			Phase.LOADING:
				_poll_loading(false)
			Phase.BUILDING:
				if _task == -1 or WorkerThreadPool.is_task_completed(_task):
					_wait_posts()
					_build_step(t0 + BUILD_BUDGET_USEC)
		if was == Phase.LOADING and _headless_loads:
			main_load_usec_max = maxi(main_load_usec_max, Time.get_ticks_usec() - t0)
		else:
			_meter(Time.get_ticks_usec() - t0, "%s row %d" % [Phase.keys()[was], _next])

	func _meter(spent: int, step: String) -> void:
		if spent > slowest_usec:
			slowest_usec = spent
			slowest_step = step

	func _poll_loading(block: bool) -> void:
		while not _main_loads.is_empty():
			var loaded := load(String(_main_loads.pop_front()))
			if loaded != null:
				_held.append(loaded)
			if not block and not _main_loads.is_empty():
				return
		var still := []
		for path: String in _pending:
			var status := ResourceLoader.load_threaded_get_status(path)
			if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS and not block:
				still.append(path)
				continue
			var res := ResourceLoader.load_threaded_get(path)
			if res != null:
				_held.append(res)
		_pending = still
		if _pending.is_empty():
			phase = Phase.BUILDING

	func _build_step(deadline: int) -> void:
		build_frames += 1
		var added := 0
		var last := 0
		while _next < _rows.size():
			if deadline >= 0 and added > 0 and Time.get_ticks_usec() + last > deadline:
				return
			var r0 := Time.get_ticks_usec()
			var holder := Node3D.new()
			Self.place_row(_rows[_next], holder, _ground, _publish, _zones, _posts.get(_next), float(_lifts.get(_next, 0.0)), _ridden)
			for node: Node in holder.get_children():
				holder.remove_child(node)
				add_child(node)
			holder.free()
			last = Time.get_ticks_usec() - r0
			row_usec_max = maxi(row_usec_max, last)
			_next += 1
			added += 1
		if not _landmark.is_empty() and landmark == null:
			if deadline >= 0 and added > 0:
				return
			var r0 := Time.get_ticks_usec()
			var holder := Node3D.new()
			landmark = Self.place_landmark(_park, holder, _ground)
			if landmark != null:
				holder.remove_child(landmark)
				add_child(landmark)
			holder.free()
			row_usec_max = maxi(row_usec_max, Time.get_ticks_usec() - r0)
		for row: Dictionary in _layers:
			Self.place_layer(row, self, _ground, _publish)
		_held.clear()
		phase = Phase.READY
		set_process(false)
		built.emit()
