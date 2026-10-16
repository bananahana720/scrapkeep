extends RefCounted

# Park recipe placement and registry (design-v3/PARK.md sections 2.2, 4 and 9). A park row's `recipe` places either a
# GLB recipe from assets/models/park/ or, for `greybox:<element>` and for a recipe whose GLB has not landed, a greybox
# primitive of the row's size. Either way the node carries a world collider and, when the row's ride fact is a
# WORLD_ROWS kind, a ride sensor that publishes it once each time the ball enters. Placement reads only the row; the
# visibility ranges come from the row's budget class in assets/asset_budgets.json, so retuning a range is one edit there.
#
# The origin conversion (KC-INT, 2026-10-11; PARK.md:77): a row's `at` is always the centre of its footprint, and its
# ride sensor, greybox and every footprint reader (bake stamps, holes, keep-out) stay centred there. A GLB recipe whose
# registry row (assets/registry.json, folded from registry.d) says `"origin": "entry_lip"` is authored with its origin
# on the entry lip and its ride along +Z, so ride_frame() puts that origin at at - forward * size[0] / 2 and the piece
# runs through at to at + forward * size[0] / 2. ride_frame() is the one owner of that rule: place_parts() offsets the
# GLB views and colliders by it and park_map.gd takes a kicker's lip from it. A row never carries a lip position.
#
# The seat fit (PARK-SEAT, coordinator ruling SE1, 2026-10-16): a row that says `"fit": "seat"` and names a GLB recipe
# puts the GLB's authored entry (its socket_entry, else its origin) on the ground at ride_frame's entry and its authored
# exit (its socket_exit, else the far end of its -col box on the centre line) on the ground at ride_frame's exit. The
# GLB stretches along its own Z only, to the row's length, and is pitched by a vertical shear, so its width, its height
# and its vertical edges stay as authored and its plan footprint is the row's (the bake's stamps and holes read that
# footprint). A stretch outside STRETCH_MIN to STRETCH_MAX of the GLB's authored length refuses the fit: the row stands
# in as its greybox and says why (seat_refusal). The views, the shells and the collider take the one fit transform.
# A row without `fit` places exactly as before.
#
# The tile fit (PARK-TILE, coordinator ruling TI1, 2026-10-16): a row that says `"fit": "tile"` and names a GLB recipe
# shorter than the row places N copies of it end to end along ride_frame's entry to exit, N = round(row length /
# authored length) and at least TILE_MIN, each copy stretched along its own Z by row length / (N x authored length) and
# seated like the seat fit on the ground at its own entry and exit, so the chain follows the ground piecewise and
# consecutive copies meet at one ground point. A recipe tiles only when its -col mesh's cross-section at its authored
# entry and at its exit match within TILE_MATCH_M in width and height (tile_ends); a recipe that does not, or a stretch
# outside STRETCH_MIN to STRETCH_MAX, refuses the fit and the row stands in as its greybox and says why (tile_refusal).
# Every copy carries its own base views, detail shells and collider faces, each view with the budget's ranges.

const EventKinds := preload("res://src/core/event_kinds.gd")
const RecipeProps := preload("res://src/presentation/recipe_props.gd")
const MaterialSlots := preload("res://src/presentation/material_slots.gd")
const Stamps := preload("res://src/world/park/park_stamps.gd")

const BUDGETS_PATH := "res://assets/asset_budgets.json"
const GLB_DIR := "res://assets/models/park/"
const REGISTRY_PATH := "res://assets/registry.json"
# A registry row's `origin`: where its GLB's origin sits on the footprint. Absent means ORIGIN_CENTRE.
const ORIGIN_CENTRE := "centre"
const ORIGIN_ENTRY_LIP := "entry_lip"
const ORIGINS := [ORIGIN_CENTRE, ORIGIN_ENTRY_LIP]
const GREYBOX := "greybox:"
# A recipe's collision mesh is the node named "<name>-col". Godot 4.7.2 keeps that node as a MeshInstance3D and adds a
# StaticBody3D child holding its ConcavePolygonShape3D (probed 2026-10-10); placement takes the shape and never draws it.
const COL_SUFFIX := "-col"
# The ball's body is on layer 2 and collides with layer 1 (rigid_ball.gd).
const WORLD_LAYER := 1
const BALL_LAYER := 2
# How far above a piece's top the ride sensor reaches, so a ball rolling or landing on it counts.
const SENSOR_ABOVE_M := 3.0
const GREYBOX_TINT := Color("8a8a84")
# The seat fit (header): the row field value, the stretch bounds and the GLB nodes that mark a ride's authored ends.
const FIT_SEAT := "seat"
const STRETCH_MIN := 0.75
const STRETCH_MAX := 1.5
const SOCKET_ENTRY := "socket_entry"
const SOCKET_EXIT := "socket_exit"
# The tile fit (header): the row field value, the fewest copies, how closely the entry and exit cross-sections must
# match, and how far inside each authored end the cross-section is cut (an end cap lying in the plane cuts to nothing).
const FIT_TILE := "tile"
const TILE_MIN := 2
const TILE_MATCH_M := 0.25
const TILE_SLICE_IN_M := 0.05

# The registry: every starting recipe id of section 4 and the six hero landmarks, with its family and budget class.
# park_schema.gd RECIPES names the same ids until the coordinator folds the GLBs into assets/registry.json.
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
}

# Each element's ride fact by its section 4 family; a row's own ride_fact wins. kicker_launch is the kicker's launch
# path, not a WORLD_ROWS kind, so a kicker gets no ride sensor; ground and anchor_field carry none.
const ELEMENT_FACTS := {
	"half_pipe": "ride_chute", "flow_line": "ride_chute", "tunnel": "ride_chute",
	"grind_line": "ride_grapple_line", "rail": "ride_grapple_line",
	"bowl": "ride_bowl", "terrace": "ride_bowl", "crater_bowl": "ride_bowl", "bank": "ride_bowl",
	"drop": "ride_drop", "flooded_cavern": "ride_drop",
	"elevated_line": "ride_ledge", "ledge": "ride_ledge",
	"sky_island": "ride_hop", "kicker": "kicker_launch",
	"anchor_field": "", "ground": "",
}

# Greybox wedges: +1 rises toward the facing end (a kicker's lip, park_map.gd), -1 falls by its height from start to end
# along the yaw (the drop convention of park/stages/1-park_dam.md). Every other element is a box.
const WEDGES := {"kicker": 1.0, "drop": -1.0}

# A greybox anchor field at runtime (PARK.md:430, the hoodoo forests; band "max anchor gap at most 40 m", PARK.md:519):
# square posts of the row's height on a staggered lattice, every second row shifted half a pitch, so a ball anywhere in
# the footprint has a post side within 40 m in one of the traversal probe's 12 directions (tools/traversal_line.gd
# _anchored). Posts keep out of every other built footprint (ANCHOR_RUNOUT_M back from its ends on its facing, where a
# ride enters and leaves; ANCHOR_SIDE_M from its sides, where a full run-out left a fixture point 41.1 m from any
# anchor), and out of a lane ROUTE_LANE_HALF_M each side of every route leg and
# of the waymarks chain (the line every pilot rides names the waymarks in order, park_schema.gd validate_lines), so a
# line through a field rolls clear. A lane is lined with edge posts every ANCHOR_EDGE_STEP_M on both sides inside the
# field, so a lane point keeps an anchor. The half width is bounded by the 40 m band where lanes overlap: two lanes
# that fork or run side by side clear one corridor, and its middle must stay within 40 m of an edge post. On the
# fixture 20 m holds every field point within 40 m (worst 33.3 m); 22 m leaves 3 points beyond reach and 26 m 90
# (tests/park_place_test.gd). An edge step of 12 m puts a post under one of the two spokes nearest square to the lane.
const ANCHOR_PITCH_M := 20.0
const ANCHOR_POST_M := 8.0
const ANCHOR_SINK_M := 1.0
const ANCHOR_RUNOUT_M := 10.0
const ANCHOR_SIDE_M := 6.0
const ROUTE_LANE_HALF_M := 20.0
const ANCHOR_EDGE_STEP_M := 12.0
# The waymark names that are no row: the spawn and the landmark (park_schema.gd DROP_IN and LANDMARK).
const DROP_IN := "drop_in"
const LANDMARK := "landmark"

static var _budgets := {}
static var _origins := {}
static var _origins_read := false
# authored_ends() of each recipe's base GLB, read once (stands_in and place ask before any part loads).
static var _ends := {}
# tile_ends() of each recipe's base GLB, read once.
static var _tiles := {}


# A budget class's visibility ranges from assets/asset_budgets.json: base_end and base_margin for the base views,
# shells as [[end, margin], ...] for detail shells 1 and 2, and for hero_landmark mid_end and mid_margin. {} when absent.
static func ranges(budget: String) -> Dictionary:
	if _budgets.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(BUDGETS_PATH))
		_budgets = parsed if parsed is Dictionary else {"classes": {}}
	return _budgets["classes"].get(budget, {}).get("ranges", {})


# A recipe id's registry `origin` (ORIGINS), ORIGIN_CENTRE when its row gives none or the id has no row.
static func origin(recipe: String) -> String:
	if not _origins_read:
		_origins_read = true
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(REGISTRY_PATH))
		if parsed is Dictionary:
			for a in parsed.get("assets", []):
				if a is Dictionary and a.get("id") is String and a.get("origin") is String:
					_origins[a["id"]] = a["origin"]
	return String(_origins.get(recipe, ORIGIN_CENTRE))


# The origin conversion, in the row's own space (y 0, +Z the facing turned by yaw_deg): "entry" and "exit" are the
# footprint's rear and far edges on its centre line, -size[0]/2 and +size[0]/2 along Z, and "origin" is where the
# recipe's GLB origin goes: the entry for an ORIGIN_ENTRY_LIP recipe, else the centre (a greybox, a centred GLB).
static func ride_frame(row: Dictionary) -> Dictionary:
	var half := float(row["size"][0]) * 0.5
	var recipe := String(row.get("recipe", ""))
	var lip := not recipe.begins_with(GREYBOX) and origin(recipe) == ORIGIN_ENTRY_LIP
	return {"entry": Vector3(0, 0, -half), "exit": Vector3(0, 0, half), "origin": Vector3(0, 0, -half if lip else 0.0)}


# The GLB paths a recipe id names: <id>.glb, its two detail shells, and the hero landmark's mid and far meshes.
static func paths(recipe: String, budget: String) -> Dictionary:
	var out := {"base": GLB_DIR + recipe + ".glb",
		"shells": [GLB_DIR + recipe + "_detail1.glb", GLB_DIR + recipe + "_detail2.glb"]}
	if budget == "hero_landmark":
		out["mid"] = GLB_DIR + recipe + "_mid.glb"
		out["far"] = GLB_DIR + recipe + "_far.glb"
	return out


# The row's place: at [x, z], on ground(x, z) or at its absolute y, turned by yaw_deg (0 faces +z, PARK.md 2.1).
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


# Whether a row opts in to the seat fit (header).
static func fits_seat(row: Dictionary) -> bool:
	return String(row.get("fit", "")) == FIT_SEAT


# A recipe scene's authored ride ends in its own space: "entry" is its socket_entry, else its origin for an entry-lip
# recipe or the near end of its -col box on the centre line for a centred one; "exit" is its socket_exit, else the
# far end of the -col box on the centre line at the entry's height; "length" is exit.z - entry.z. {} with no -col mesh.
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


# authored_ends() of a recipe's base GLB, cached; {} when the GLB is missing or has no -col mesh.
static func recipe_ends(recipe: String) -> Dictionary:
	if not _ends.has(recipe):
		var scenes := _load(GLB_DIR + recipe + ".glb")
		_ends[recipe] = authored_ends(scenes[0], origin(recipe) == ORIGIN_ENTRY_LIP) if not scenes.is_empty() else {}
		for scene: Node in scenes:
			scene.free()
	return _ends[recipe]


# Why a seat-fit row cannot fit its GLB, "" when it can: the stretch, row length over authored length, must lie in
# STRETCH_MIN to STRETCH_MAX. It reads no ground, so the stand-in decision is the same at bake and at runtime.
static func seat_refusal(row: Dictionary, ends: Dictionary) -> String:
	var authored := float(ends.get("length", 0.0))
	if authored <= 0.0:
		return "the GLB has no -col mesh or no length along +Z"
	var stretch := float(row["size"][0]) / authored
	if stretch < STRETCH_MIN or stretch > STRETCH_MAX:
		return "length ratio %.2f outside %.2f to %.2f (row %.1f m, GLB %.1f m)" % [stretch, STRETCH_MIN, STRETCH_MAX, float(row["size"][0]), authored]
	return ""


# The seat fit of a row whose GLB has authored ends: {"ok", "reason", "stretch", "lip_y", "exit_y", "transform"}, where
# transform takes the GLB's own space to the row node's (row_transform) and lip_y and exit_y are the ground under
# ride_frame's entry and exit, relative to the node. A row with an absolute y, or no ground, fits flat at the node.
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
	# z' = stretch * (z - e.z) - length / 2 and y' = y + a + shear * (z - e.z): the entry lands on (0, lip_y, -length / 2)
	# and the exit on (0, exit_y, length / 2), the authored fall kept and the ground's fall added.
	var a := lip_y - e.y
	var shear := (exit_y - lip_y - (x.y - e.y)) / authored
	var basis := Basis(Vector3.RIGHT, Vector3.UP, Vector3(0, shear, stretch))
	var xf := Transform3D(basis, Vector3(0, a - shear * e.z, -length * 0.5 - stretch * e.z))
	return {"ok": true, "reason": "", "stretch": stretch, "lip_y": lip_y, "exit_y": exit_y, "transform": xf}


# Whether a row opts in to the tile fit (header).
static func fits_tile(row: Dictionary) -> bool:
	return String(row.get("fit", "")) == FIT_TILE


# Every -col mesh's trimesh faces of a recipe scene, in the scene's own space.
static func col_faces(scene: Node) -> PackedVector3Array:
	var out := PackedVector3Array()
	for source: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if source.mesh != null and String(source.name).ends_with(COL_SUFFIX):
			out.append_array(_relative(source, scene) * _trimesh(source).get_faces())
	return out


# The cross-section of triangle faces on the plane z = z0: {"min": Vector2(x, y), "max": Vector2(x, y), "width",
# "height"} over every point where a triangle edge meets the plane, {} when none does.
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


# Whether a recipe scene tiles (header): {"entry": cross_section, "exit": cross_section, "tileable", "reason"}, the
# -col cross-sections cut TILE_SLICE_IN_M inside its authored entry and exit, tileable when both exist and their widths
# and heights each match within TILE_MATCH_M. {} with no -col mesh.
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


# tile_ends() of a recipe's base GLB, cached; {} when the GLB is missing or has no -col mesh.
static func recipe_tile(recipe: String) -> Dictionary:
	if not _tiles.has(recipe):
		var scenes := _load(GLB_DIR + recipe + ".glb")
		_tiles[recipe] = tile_ends(scenes[0], origin(recipe) == ORIGIN_ENTRY_LIP) if not scenes.is_empty() else {}
		for scene: Node in scenes:
			scene.free()
	return _tiles[recipe]


# How many copies tile a row of length over a GLB of authored length: round(length / authored), at least TILE_MIN.
static func tile_count(length: float, authored: float) -> int:
	return maxi(TILE_MIN, roundi(length / authored))


# Why a tile-fit row cannot tile its GLB, "" when it can: the GLB needs a length, the recipe must be tileable
# (tile_ends), and each copy's stretch, row length / (N x authored length), must lie in STRETCH_MIN to STRETCH_MAX.
# It reads no ground, so the stand-in decision is the same at bake and at runtime.
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


# The tile fit of a row whose GLB has authored ends: {"ok", "reason", "count", "stretch", "copies"}, each copy
# {"transform", "z0", "z1", "lip_y", "exit_y"}: transform takes the GLB's own space to the row node's, z0 and z1 are
# the copy's entry and exit along the node's Z (copy k runs from -L/2 + k L/N to -L/2 + (k + 1) L/N), and lip_y and
# exit_y are the ground under them relative to the node. Each copy is the seat fit's shear on its own ends. A row with
# an absolute y, or no ground, tiles flat at the node.
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


# Places a park row (or the landmark object) under parent and returns its node, or null when the recipe is "" or a
# greybox id names no element. publish(kind, at) is called when the ball enters the ride sensor; the stage passes
# its bus's world_fact.emit. A recipe whose base GLB is missing stands in as its element's greybox, with a warning.
static func place(row: Dictionary, parent: Node3D, ground := Callable(), publish := Callable()) -> Node3D:
	var recipe := String(row.get("recipe", ""))
	if recipe == "":
		return null
	if recipe.begins_with(GREYBOX):
		return place_greybox(row, recipe.trim_prefix(GREYBOX), parent, ground, publish)
	var budget := String(row.get("budget", ROWS.get(recipe, {}).get("budget", "landform")))
	var p := paths(recipe, budget)
	if not ResourceLoader.exists(p["base"]):
		push_warning("park_recipes: %s missing, %s stands in as greybox" % [p["base"], row.get("id", "")])
		return place_greybox(row, String(row.get("element", "")), parent, ground, publish)
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
	var node := place_parts(row, parts, parent, ground, publish)
	for key in parts:
		for scene: Node in parts[key]:
			scene.free()
	return node


# Places instantiated recipe scenes: parts is {"base": [Node], "shells": [Node, ...], "mid": [Node], "far": [Node]}.
# Every -col mesh becomes a trimesh on the node's one StaticBody3D and is never drawn; every other mesh is a view with
# the budget class's range. Views and colliders sit at the GLB origin ride_frame() gives, or for a seat-fit row on the
# seat fit transform (seat_fit, from the base scene's authored ends), with the colliders' faces moved by it so no
# collision shape carries a stretch or a shear; the node keeps that transform as meta "seat_fit". A seat-fit row whose
# fit is refused places unfitted here: place() stands it in before it gets here. A tile-fit row places every part once
# per copy on that copy's transform (tile_fit), views named <mesh>_tile<k>, and keeps the copies' transforms as meta
# "tile_fit"; a refused tile fit likewise places unfitted here. The caller keeps ownership of the part scenes.
static func place_parts(row: Dictionary, parts: Dictionary, parent: Node3D, ground := Callable(), publish := Callable()) -> Node3D:
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
	# Each placement of the parts: [GLB-to-node transform, view name suffix]. One, except for a tile fit's copies.
	var fits := [[at_origin, ""]]
	if fits_tile(row) and not (parts.get("base", []) as Array).is_empty():
		var lip := origin(String(row.get("recipe", ""))) == ORIGIN_ENTRY_LIP
		var tile := tile_fit(row, authored_ends(parts["base"][0], lip), tile_ends(parts["base"][0], lip), ground)
		if tile["ok"]:
			baked = true
			fits = []
			var xfs := []
			for k in (tile["copies"] as Array).size():
				var xf: Transform3D = tile["copies"][k]["transform"]
				fits.append([xf, "_tile%d" % k])
				xfs.append(xf)
			node.set_meta("tile_fit", xfs)
			node.set_meta("tile_count", tile["count"])
			node.set_meta("tile_stretch", tile["stretch"])
	var r :=ranges(String(row.get("budget", "landform")))
	var base_end := float(r.get("base_end", 0.0))
	var mid_end := float(r.get("mid_end", 0.0))
	for scene: Node in parts.get("base", []):
		for f: Array in fits:
			for view in _views(scene, node, body, f[0], baked, f[1]):
				_range(view, 0.0, base_end, float(r.get("base_margin", 0.0)))
				view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var shell_ranges: Array = r.get("shells", [])
	var shells: Array = parts.get("shells", [])
	for k in shells.size():
		var sr: Array = shell_ranges[k] if k < shell_ranges.size() else [0.0, 0.0]
		for f: Array in fits:
			for view in _views(shells[k], node, body, f[0], baked, f[1]):
				_range(view, 0.0, float(sr[0]), float(sr[1]))
				view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for scene: Node in parts.get("mid", []):
		for f: Array in fits:
			for view in _views(scene, node, body, f[0], baked, f[1]):
				_range(view, base_end, mid_end, float(r.get("mid_margin", 0.0)))
				view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for scene: Node in parts.get("far", []):
		for f: Array in fits:
			for view in _views(scene, node, body, f[0], baked, f[1]):
				_range(view, mid_end, 0.0, 0.0)
				view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_sensor(node, row, publish)
	return node


# A greybox primitive of the row's size ([length, height, width], length along the facing) sitting on its base, with
# a collider of the same extent: a box, or a wedge for the elements in WEDGES. null for an element that is no park element.
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


# One view per drawn mesh of scene under node, at its place in the scene moved to the GLB origin at_origin; each -col
# mesh goes to body as a trimesh. A surface whose GLB material names a material slot wears that slot (recipe_props.gd).
# baked (a seat fit): each trimesh is a new shape with its faces moved by xf and an identity transform, because a
# collision shape takes no stretch or shear. suffix ends each view's name (a tile fit's copy index).
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


# The importer's ConcavePolygonShape3D under a -col node, else a trimesh cooked from its mesh (a raw scene).
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


# The ride sensor: an Area3D over the footprint reaching SENSOR_ABOVE_M above the top, hearing only the ball's layer.
# Centred on the row's at for every recipe (ride_frame). None when the row's fact is no WORLD_ROWS kind or no publish
# callable is given.
static func _sensor(node: Node3D, row: Dictionary, publish: Callable) -> void:
	var fact := String(row.get("ride_fact", ""))
	if not publish.is_valid() or not EventKinds.WORLD_ROWS.has(fact):
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
	area.body_entered.connect(func(ball: Node3D) -> void: publish.call(fact, ball.global_position))


# A wedge's six corners in the node's space: extent is [width, height, length]; rise +1 puts the high edge at +z.
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


# --- Placement at runtime (K-UNITS KB9) ---
#
# A park stage places its rows when its ground is built (terrain.gd _on_park_built): every row whose recipe is not "",
# through place(), plus two runtime rules. A greybox stand-in (a greybox: id, or a recipe whose GLB is missing) of a
# stamped row places its node and ride sensor but no solid: the stamp replaces it (PARK.md section 4: a landform is
# "height stamp plus a recipe"; the stamp shapes the ground, and a greybox has no lip or rim to add). A greybox
# anchor_field becomes a post field (place_anchor_field). A GLB recipe stands where place() puts it, its -col mesh on
# top of the stamped ground. Only the park file's schema fields are read, never a stage's ids.


# The park rows that place something: recipe not "".
static func placed_rows(park: Dictionary) -> Array:
	return (park.get("park_rows", []) as Array).filter(func(row: Dictionary) -> bool: return String(row.get("recipe", "")) != "")


# Where anchor posts keep out: every built footprint ({"at", "size": [along, across], "yaw"}, the ground and anchor
# fields excepted, and the landmark), and a lane ({"a", "b", "half"}) along each leg of each route, from its `from`
# through its `via` rows to its `to`, and of the waymarks chain. A route leg joins its two places where they are
# nearest: a park row's place is either end of its footprint on its facing (ride_frame's entry and exit; a ball leaves a
# tube or a wash by an end, never its middle). A waymarks leg joins the places a pilot line aims at, a row's at
# (traversal_line.gd place_of). The drop-in is the spawn, the landmark its beacon, an activity its at.
static func clear_zones(park: Dictionary) -> Array:
	var out := []
	var places := {}
	var ends := {}
	for row: Dictionary in park.get("park_rows", []):
		var yaw := deg_to_rad(float(row.get("yaw_deg", 0.0)))
		var half := Vector2(sin(yaw), cos(yaw)) * float(row["size"][0]) * 0.5
		places[row["id"]] = [_v2(row["at"])]
		ends[row["id"]] = [_v2(row["at"]) - half, _v2(row["at"]) + half]
		if row["element"] != "ground" and row["element"] != "anchor_field":
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


static func _zone(row: Dictionary) -> Dictionary:
	return {"at": _v2(row["at"]), "size": Vector2(float(row["size"][0]), float(row["size"][2])), "yaw": deg_to_rad(float(row.get("yaw_deg", 0.0)))}


static func _v2(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


# Whether a disc of radius r at p touches a clear zone.
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


# An anchor field's post centres on the ground plane: rows every pitch along the facing, posts every pitch across,
# every second row shifted half a pitch, inside the footprint and clear of zones.
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
	for j in rows + 1:
		var lz := -rows * pitch * 0.5 + j * pitch
		var lx := -cols * pitch * 0.5 + (pitch * 0.5 if j % 2 == 1 else 0.0)
		while lx <= half_w + 0.001:
			var p := at + across * lx + along * lz
			if clear.call(p):
				out.append(p)
			lx += pitch
	# The lane edges: a post every ANCHOR_EDGE_STEP_M just outside each lane, on both sides, where it lands in the field.
	var inside := func(p: Vector2) -> bool:
		var d := p - at
		return absf(d.dot(along)) <= half_l and absf(d.dot(across)) <= half_w
	for lane: Dictionary in lanes:
		var a: Vector2 = lane["a"]
		var ab: Vector2 = (lane["b"] as Vector2) - a
		var length := ab.length()
		var dir := ab / length
		var side := Vector2(-dir.y, dir.x) * (float(lane["half"]) + r + 0.5)
		# Only the stretch of the lane whose edges can fall in this field.
		var reach := Vector2(half_l, half_w).length() + side.length()
		var t := (at - a).dot(dir)
		if absf((at - a).dot(Vector2(-dir.y, dir.x))) > reach or t < -reach or t > length + reach:
			continue
		var s := maxf(0.0, floorf((t - reach) / ANCHOR_EDGE_STEP_M) * ANCHOR_EDGE_STEP_M)
		var s_end := minf(length, t + reach)
		while s <= s_end + 0.001:
			for p: Vector2 in [a + dir * s + side, a + dir * s - side]:
				if inside.call(p) and clear.call(p):
					out.append(p)
			s += ANCHOR_EDGE_STEP_M
	return out


# A greybox anchor field: the row's node with one StaticBody3D of square posts (ANCHOR_POST_M across, the row's
# height above the ground under each, sunk ANCHOR_SINK_M) and one MultiMesh view of them, greybox tint.
# posts: the field's post centres when already worked out (Placer does that on a worker), else anchor_posts() here.
static func place_anchor_field(row: Dictionary, parent: Node3D, ground := Callable(), zones: Array = [], pitch := ANCHOR_PITCH_M, posts = null) -> Node3D:
	var node := _node(row, parent, ground)
	var body := _body(node)
	var tall := float(row["size"][1]) + ANCHOR_SINK_M
	var extent := Vector3(ANCHOR_POST_M, tall, ANCHOR_POST_M)
	var mesh := BoxMesh.new()
	mesh.size = extent
	if posts == null:
		posts = anchor_posts(row, zones, pitch)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = posts.size()
	var inv := node.transform.affine_inverse()
	var box := BoxShape3D.new()
	box.size = extent
	for k in posts.size():
		var p: Vector2 = posts[k]
		var base := float(ground.call(p.x, p.y)) if ground.is_valid() else node.position.y
		var local := inv * Vector3(p.x, base - ANCHOR_SINK_M + tall * 0.5, p.y)
		var shape := CollisionShape3D.new()
		shape.shape = box
		shape.position = local
		body.add_child(shape)
		multi.set_instance_transform(k, Transform3D(Basis.IDENTITY, local))
	var view := MultiMeshInstance3D.new()
	view.name = "Posts"
	view.multimesh = multi
	var material := StandardMaterial3D.new()
	material.albedo_color = GREYBOX_TINT
	view.material_override = material
	view.set_meta(RecipeProps.META_FADE, true)
	node.add_child(view)
	node.set_meta("anchor_posts", posts.size())
	return node


# One row at runtime: an anchor field's posts, or place(). A greybox stand-in of a stamped row keeps its node and ride
# sensor but drops its box and collider: the stamp is already its shape, and a box of the row's size on one height
# cannot follow the stamped ground (a 300 m bank box stood 8 m over the fixture's pool). Its node stands on the plain
# the stamp raised (seat), so the sensor spans the raise.
static func place_row(row: Dictionary, parent: Node3D, ground := Callable(), publish := Callable(), zones: Array = [], posts = null) -> Node3D:
	var recipe := String(row.get("recipe", ""))
	if recipe == GREYBOX + "anchor_field":
		return place_anchor_field(row, parent, ground, zones, ANCHOR_PITCH_M, posts)
	var node := place(row, parent, seat(row, ground), publish)
	if node != null and stamp_replaces(row):
		# PARK.md section 4's rows are "height stamp plus a recipe": for a greybox stand-in (the fixture's deck, lip and
		# apron) the stamp is the whole shape, so the row keeps no Collider of its own and the stamped ground collides.
		# park_place_test's collider-vs-stamp report records this reading per row.
		for part in ["Collider", "Greybox"]:
			var child := node.get_node_or_null(part)
			if child != null:
				node.remove_child(child)
				child.free()
		node.set_meta("stamp_replaces", true)
	return node


# Whether a row's stamp stands in for its greybox solid: a greybox stand-in with a stamp and no absolute y.
static func stamp_replaces(row: Dictionary) -> bool:
	return String(row.get("stamp", "")) != "" and row.get("y") == null and stands_in(row)


# The ground a row's node stands on: a stamp_replaces row stands on the ground less its own stamp's raise (the plain
# the stamp raised; a cut keeps its floor, so the sensor reaches into it); everything else on the ground itself.
static func seat(row: Dictionary, ground: Callable) -> Callable:
	if not ground.is_valid() or not stamp_replaces(row):
		return ground
	var f := Stamps.frame(row)
	return func(x: float, z: float) -> float: return float(ground.call(x, z)) - maxf(Stamps.offset(f, x, z), 0.0)


# Whether a row places as a greybox: a greybox id, a recipe whose base GLB has not landed, or a seat-fit row whose
# fit is refused (seat_refusal), or a tile-fit row whose fit is refused (tile_refusal).
static func stands_in(row: Dictionary) -> bool:
	var recipe := String(row.get("recipe", ""))
	if recipe == "" or recipe.begins_with(GREYBOX):
		return recipe != ""
	if not ResourceLoader.exists(paths(recipe, _budget(row))["base"]):
		return true
	if fits_tile(row):
		return tile_refusal(row, recipe_ends(recipe), recipe_tile(recipe)) != ""
	return fits_seat(row) and seat_refusal(row, recipe_ends(recipe)) != ""


static func _budget(row: Dictionary) -> String:
	return String(row.get("budget", ROWS.get(String(row.get("recipe", "")), {}).get("budget", "landform")))


# Every GLB a row's placement reads.
static func row_paths(row: Dictionary) -> Array:
	var recipe := String(row.get("recipe", ""))
	if recipe == "" or recipe.begins_with(GREYBOX):
		return []
	var p := paths(recipe, _budget(row))
	var out: Array = [p["base"]]
	out.append_array(p["shells"])
	for key in ["mid", "far"]:
		if p.has(key):
			out.append(p[key])
	return out.filter(func(path: String) -> bool: return ResourceLoader.exists(path))


# Starts placing a park's rows under parent (a "ParkRows" node it returns); threaded: the GLBs and slot materials load
# on the loader thread, then the main thread places a few rows a frame inside a budget. Else all now. The rows build on
# the main thread because a row makes server resources (meshes, multimeshes, shapes), and a mesh made on a worker
# raced the main thread's in the headless renderer ("Attempting to initialize the wrong RID", 2 of 10 park_swap_test
# runs, artifacts/local/alpha/push/w13/place/swap10/); scatter.gd keeps its worker to data for the same reason.
static func build_placed(parent: Node3D, park: Dictionary, ground: Callable, publish: Callable, threaded: bool) -> Node3D:
	var node := Placer.new()
	node.name = "ParkRows"
	parent.add_child(node)
	node.start(park, ground, publish, threaded)
	return node


class Placer extends Node3D:
	signal built

	const Self := preload("res://src/world/park/park_recipes.gd")
	const Slots := preload("res://src/presentation/material_slots.gd")
	const BUILD_BUDGET_USEC := 4000

	enum Phase { IDLE, LOADING, BUILDING, READY }

	var phase := Phase.IDLE
	# The longest main-thread step (start() or a _process step) and where, and the longest whole frame while placing.
	var slowest_usec := 0
	var slowest_step := ""
	var start_usec := 0
	var frame_usec_max := 0
	# Resources requested on the loader thread, and the frames the rows took to place (one when not threaded).
	var threaded_loads := 0
	# The headless dummy renderer's RID owners are not thread-safe, so there a threaded build loads on the main thread,
	# one resource a LOADING step, metered apart from slowest_usec (scatter.gd Chunked, HEADLESS-LOADER).
	var serial_loads := 0
	var serial_usec_max := 0
	var _serial := DisplayServer.get_name() == "headless"
	var _serial_usec := 0
	var build_frames := 0
	# The costliest single row on the main thread.
	var row_usec_max := 0
	var _last_frame_usec := 0
	var _rows: Array = []
	var _zones: Array = []
	var _ground: Callable
	var _publish: Callable
	var _pending: Array = []
	# Loaded resources held for the build, so its load() calls find them cached.
	var _held: Array = []
	var _next := 0
	var _threaded := false
	# Anchor-field post centres by row index, worked out on a worker (pure arithmetic, no server resources).
	var _posts := {}
	var _task := -1

	func is_ready() -> bool:
		return phase == Phase.READY

	func start(park: Dictionary, ground: Callable, publish: Callable, threaded: bool) -> void:
		var t0 := Time.get_ticks_usec()
		_rows = Self.placed_rows(park)
		_zones = Self.clear_zones(park)
		_ground = ground
		_publish = publish
		_threaded = threaded
		var wanted := []
		for row: Dictionary in _rows:
			for path: String in Self.row_paths(row):
				if not wanted.has(path):
					wanted.append(path)
		# A recipe surface naming a material slot wears it (recipe_props.gd); those slots are the resource ones.
		if not wanted.is_empty():
			for role: String in Slots.SLOTS:
				var slot: Dictionary = Slots.row(role)
				if String(slot.get("kind", "")) == "resource" and ResourceLoader.exists(String(slot["path"])) and not wanted.has(slot["path"]):
					wanted.append(String(slot["path"]))
		# Only a threaded build loads on the loader thread. A synchronous build (finish() below, in the same call) loads
		# on the main thread through place()'s load(): with requests in flight its main-thread meshes raced the loader's
		# RIDs ("Attempting to initialize the wrong RID" in place_greybox, and a null material on a part's free): 2 of 96
		# park_holes_test runs six at a time before, 0 of 216 after (artifacts/local/alpha/push/w13/place/rid_sync/).
		for path: String in (wanted if threaded else []):
			if _serial:
				_pending.append(path)
				serial_loads += 1
			elif ResourceLoader.load_threaded_request(path) == OK:
				_pending.append(path)
				threaded_loads += 1
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
		for i in _rows.size():
			if String(_rows[i].get("recipe", "")) == Self.GREYBOX + "anchor_field":
				_posts[i] = Self.anchor_posts(_rows[i], _zones)

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

	# A stage freed before its rows are placed (the next stage prepared, then the run ends) retrieves every threaded
	# request here, so none stays open on the loader.
	func _exit_tree() -> void:
		_wait_posts()
		for path: String in ([] if _serial else _pending):
			ResourceLoader.load_threaded_get(path)
		_pending.clear()
		_held.clear()

	func _process(_delta: float) -> void:
		var t0 := Time.get_ticks_usec()
		if _last_frame_usec > 0:
			frame_usec_max = maxi(frame_usec_max, t0 - _last_frame_usec)
		_last_frame_usec = t0
		var was := phase
		_serial_usec = 0
		match phase:
			Phase.LOADING:
				_poll_loading(false)
			Phase.BUILDING:
				if _task == -1 or WorkerThreadPool.is_task_completed(_task):
					_wait_posts()
					_build_step(t0 + BUILD_BUDGET_USEC)
		_meter(Time.get_ticks_usec() - t0 - _serial_usec, "%s row %d" % [Phase.keys()[was], _next])

	func _meter(spent: int, step: String) -> void:
		if spent > slowest_usec:
			slowest_usec = spent
			slowest_step = step

	func _poll_loading(block: bool) -> void:
		if _serial:
			while not _pending.is_empty():
				var t0 := Time.get_ticks_usec()
				var loaded := ResourceLoader.load(_pending.pop_front())
				if loaded != null:
					_held.append(loaded)
				var spent := Time.get_ticks_usec() - t0
				serial_usec_max = maxi(serial_usec_max, spent)
				_serial_usec += spent
				if not block:
					break
			if _pending.is_empty():
				phase = Phase.BUILDING
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

	# Main thread: place rows, at least one a step, until the budget is spent (deadline -1: all).
	func _build_step(deadline: int) -> void:
		build_frames += 1
		var added := 0
		var last := 0
		while _next < _rows.size():
			# Stop before a row that would likely end past the deadline (rows of one park cost alike).
			if deadline >= 0 and added > 0 and Time.get_ticks_usec() + last > deadline:
				return
			var r0 := Time.get_ticks_usec()
			# Built outside the tree, then added once.
			var holder := Node3D.new()
			var node := Self.place_row(_rows[_next], holder, _ground, _publish, _zones, _posts.get(_next))
			if node != null:
				holder.remove_child(node)
				add_child(node)
			holder.free()
			last = Time.get_ticks_usec() - r0
			row_usec_max = maxi(row_usec_max, last)
			_next += 1
			added += 1
		_held.clear()
		phase = Phase.READY
		set_process(false)
		built.emit()
