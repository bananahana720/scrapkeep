extends RefCounted

# Park recipe placement and registry (design-v3/PARK.md sections 2.2, 4 and 9). A park row's `recipe` places either a
# GLB recipe from assets/models/park/ or, for `greybox:<element>` and for a recipe whose GLB has not landed, a greybox
# primitive of the row's size. Either way the node carries a world collider and, when the row's ride fact is a
# WORLD_ROWS kind, a ride sensor that publishes it once each time the ball enters. Placement reads only the row; the
# visibility ranges come from the row's budget class in tools/asset_budgets.json, so retuning a range is one edit there.
#
# The origin conversion (KC-INT, 2026-10-11; PARK.md:77): a row's `at` is always the centre of its footprint, and its
# ride sensor, greybox and every footprint reader (bake stamps, holes, keep-out) stay centred there. A GLB recipe whose
# registry row (assets/registry.json, folded from registry.d) says `"origin": "entry_lip"` is authored with its origin
# on the entry lip and its ride along +Z, so ride_frame() puts that origin at at - forward * size[0] / 2 and the piece
# runs through at to at + forward * size[0] / 2. ride_frame() is the one owner of that rule: place_parts() offsets the
# GLB views and colliders by it and park_map.gd takes a kicker's lip from it. A row never carries a lip position.

const EventKinds := preload("res://src/core/event_kinds.gd")
const RecipeProps := preload("res://src/presentation/recipe_props.gd")
const MaterialSlots := preload("res://src/presentation/material_slots.gd")
const Stamps := preload("res://src/world/park/park_stamps.gd")

const BUDGETS_PATH := "res://tools/asset_budgets.json"
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
# _anchored). Posts keep out of every other built footprint and of a lane along each route, so a line through a field
# rolls clear, and stand ANCHOR_RUNOUT_M back from a footprint so a ride's entry and exit keep their run-out: the
# fixture's Sable bot strays up to about 46 m off a route's straight legs after the kicker and leaves the tube along
# its side (artifacts/local/alpha/push/w13/place/), so the lane is 50 m each side. Starting values, probed by
# tests/park_place_test.gd.
const ANCHOR_PITCH_M := 20.0
const ANCHOR_POST_M := 8.0
const ANCHOR_SINK_M := 1.0
const ANCHOR_RUNOUT_M := 10.0
const ROUTE_LANE_HALF_M := 50.0

static var _budgets := {}
static var _origins := {}
static var _origins_read := false


# A budget class's visibility ranges from tools/asset_budgets.json: base_end and base_margin for the base views,
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
	var parts := {"base": _load(p["base"]), "shells": [], "mid": [], "far": []}
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
# the budget class's range. Views and colliders sit at the GLB origin ride_frame() gives. The caller keeps ownership of
# the part scenes.
static func place_parts(row: Dictionary, parts: Dictionary, parent: Node3D, ground := Callable(), publish := Callable()) -> Node3D:
	var node := _node(row, parent, ground)
	var body := _body(node)
	var at_origin := Transform3D(Basis.IDENTITY, ride_frame(row)["origin"])
	var r := ranges(String(row.get("budget", "landform")))
	var base_end := float(r.get("base_end", 0.0))
	var mid_end := float(r.get("mid_end", 0.0))
	for scene: Node in parts.get("base", []):
		for view in _views(scene, node, body, at_origin):
			_range(view, 0.0, base_end, float(r.get("base_margin", 0.0)))
			view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var shell_ranges: Array = r.get("shells", [])
	var shells: Array = parts.get("shells", [])
	for k in shells.size():
		var sr: Array = shell_ranges[k] if k < shell_ranges.size() else [0.0, 0.0]
		for view in _views(shells[k], node, body, at_origin):
			_range(view, 0.0, float(sr[0]), float(sr[1]))
			view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for scene: Node in parts.get("mid", []):
		for view in _views(scene, node, body, at_origin):
			_range(view, base_end, mid_end, float(r.get("mid_margin", 0.0)))
			view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for scene: Node in parts.get("far", []):
		for view in _views(scene, node, body, at_origin):
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
static func _views(scene: Node, node: Node3D, body: StaticBody3D, at_origin: Transform3D) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for source: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if source.mesh == null:
			continue
		var xf := at_origin * _relative(source, scene)
		if String(source.name).ends_with(COL_SUFFIX):
			var shape := CollisionShape3D.new()
			shape.shape = _trimesh(source)
			shape.transform = xf
			body.add_child(shape)
			continue
		var view := MeshInstance3D.new()
		view.name = source.name
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
# through its `via` rows to its `to` (the drop-in is the spawn, the landmark its beacon, an activity its at).
static func clear_zones(park: Dictionary) -> Array:
	var out := []
	var places := {}
	for row: Dictionary in park.get("park_rows", []):
		places[row["id"]] = _v2(row["at"])
		if row["element"] != "ground" and row["element"] != "anchor_field":
			out.append(_zone(row))
	for row: Dictionary in park.get("activity_rows", []):
		places[row["id"]] = _v2(row["at"])
	var mark: Dictionary = park.get("landmark", {})
	if not mark.is_empty():
		out.append(_zone(mark))
		places["landmark"] = _v2(mark["beacon"])
	if park.has("spawn"):
		places["drop_in"] = _v2(park["spawn"]["at"])
	for route: Dictionary in park.get("routes", []):
		var chain: Array = [route["from"]]
		chain.append_array(route["via"])
		chain.append(route["to"])
		for k in range(1, chain.size()):
			if places.has(chain[k - 1]) and places.has(chain[k]) and chain[k - 1] != chain[k]:
				out.append({"a": places[chain[k - 1]], "b": places[chain[k]], "half": ROUTE_LANE_HALF_M})
	return out


static func _zone(row: Dictionary) -> Dictionary:
	return {"at": _v2(row["at"]), "size": Vector2(float(row["size"][0]), float(row["size"][2])), "yaw": deg_to_rad(float(row.get("yaw_deg", 0.0)))}


static func _v2(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


# Whether a disc of radius r at p touches a clear zone.
static func in_clear(zones: Array, p: Vector2, r: float) -> bool:
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
			if absf(d.dot(Vector2(sin(yaw), cos(yaw)))) <= size.x * 0.5 + r and absf(d.dot(Vector2(cos(yaw), -sin(yaw)))) <= size.y * 0.5 + r:
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
	for j in rows + 1:
		var lz := -rows * pitch * 0.5 + j * pitch
		var lx := -cols * pitch * 0.5 + (pitch * 0.5 if j % 2 == 1 else 0.0)
		while lx <= half_w + 0.001:
			var p := at + across * lx + along * lz
			if not in_clear(lanes, p, ANCHOR_POST_M * 0.5) and not in_clear(footprints, p, ANCHOR_POST_M * 0.5 + ANCHOR_RUNOUT_M):
				out.append(p)
			lx += pitch
	return out


# A greybox anchor field: the row's node with one StaticBody3D of square posts (ANCHOR_POST_M across, the row's
# height above the ground under each, sunk ANCHOR_SINK_M) and one MultiMesh view of them, greybox tint.
static func place_anchor_field(row: Dictionary, parent: Node3D, ground := Callable(), zones: Array = [], pitch := ANCHOR_PITCH_M) -> Node3D:
	var node := _node(row, parent, ground)
	var body := _body(node)
	var tall := float(row["size"][1]) + ANCHOR_SINK_M
	var extent := Vector3(ANCHOR_POST_M, tall, ANCHOR_POST_M)
	var box := BoxShape3D.new()
	box.size = extent
	var mesh := BoxMesh.new()
	mesh.size = extent
	var posts := anchor_posts(row, zones, pitch)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = posts.size()
	var inv := node.transform.affine_inverse()
	for k in posts.size():
		var p := posts[k]
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
static func place_row(row: Dictionary, parent: Node3D, ground := Callable(), publish := Callable(), zones: Array = []) -> Node3D:
	var recipe := String(row.get("recipe", ""))
	if recipe == GREYBOX + "anchor_field":
		return place_anchor_field(row, parent, ground, zones)
	var node := place(row, parent, seat(row, ground), publish)
	if node != null and stamp_replaces(row):
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


# Whether a row places as a greybox: a greybox id, or a recipe whose base GLB has not landed.
static func stands_in(row: Dictionary) -> bool:
	var recipe := String(row.get("recipe", ""))
	if recipe == "" or recipe.begins_with(GREYBOX):
		return recipe != ""
	return not ResourceLoader.exists(paths(recipe, _budget(row))["base"])


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
# on the loader thread, the rows build on a worker, and the main thread adds a few finished rows a frame. Else all now.
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
	const ATTACH_BUDGET_USEC := 4000

	enum Phase { IDLE, LOADING, BUILDING, ATTACHING, READY }

	var phase := Phase.IDLE
	# The longest main-thread step (start() or a _process step) and where, and the longest whole frame while placing.
	var slowest_usec := 0
	var slowest_step := ""
	var start_usec := 0
	var frame_usec_max := 0
	# Resources requested on the loader thread, and rows built on a thread other than the main one.
	var threaded_loads := 0
	var worker_rows := 0
	var _last_frame_usec := 0
	var _rows: Array = []
	var _zones: Array = []
	var _ground: Callable
	var _publish: Callable
	var _pending: Array = []
	# Loaded resources held for the build, so its load() calls find them cached.
	var _held: Array = []
	var _built: Array = []
	var _next := 0
	var _task := -1
	var _threaded := false

	func is_ready() -> bool:
		return phase == Phase.READY

	func start(park: Dictionary, ground: Callable, publish: Callable, threaded: bool) -> void:
		var t0 := Time.get_ticks_usec()
		# The static tables the build reads fill here, on the main thread, before any worker reads them.
		Self.ranges("landform")
		Self.origin("")
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
		for path: String in wanted:
			if ResourceLoader.load_threaded_request(path) == OK:
				_pending.append(path)
				threaded_loads += 1
		phase = Phase.LOADING
		start_usec = Time.get_ticks_usec() - t0
		_meter(start_usec, "START")
		if threaded:
			set_process(true)
		else:
			finish()

	func finish() -> void:
		while phase == Phase.LOADING:
			_poll_loading(true)
		if phase == Phase.BUILDING:
			if _task != -1:
				WorkerThreadPool.wait_for_task_completion(_task)
				_task = -1
			phase = Phase.ATTACHING
		while phase == Phase.ATTACHING:
			_attach_step(-1)

	func _ready() -> void:
		set_process(phase == Phase.LOADING or phase == Phase.BUILDING or phase == Phase.ATTACHING)

	func _exit_tree() -> void:
		if _task != -1:
			WorkerThreadPool.wait_for_task_completion(_task)
			_task = -1

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
				if WorkerThreadPool.is_task_completed(_task):
					WorkerThreadPool.wait_for_task_completion(_task)
					_task = -1
					phase = Phase.ATTACHING
			Phase.ATTACHING:
				_attach_step(t0 + ATTACH_BUDGET_USEC)
		_meter(Time.get_ticks_usec() - t0, "%s row %d" % [Phase.keys()[was], _next])

	func _meter(spent: int, step: String) -> void:
		if spent > slowest_usec:
			slowest_usec = spent
			slowest_step = step

	func _poll_loading(block: bool) -> void:
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
			if _threaded:
				_task = WorkerThreadPool.add_task(_build, false, "park rows")
			else:
				_build()

	# Worker side: each row builds under a holder outside the tree; the main thread adds it.
	func _build() -> void:
		for row: Dictionary in _rows:
			var holder := Node3D.new()
			var node := Self.place_row(row, holder, _ground, _publish, _zones)
			if node != null:
				holder.remove_child(node)
				_built.append(node)
			holder.free()
		if OS.get_thread_caller_id() != OS.get_main_thread_id():
			worker_rows = _rows.size()

	# Main thread: add finished rows, at least one a frame, until the budget is spent (deadline -1: all).
	func _attach_step(deadline: int) -> void:
		var added := 0
		while _next < _built.size():
			if deadline >= 0 and added > 0 and Time.get_ticks_usec() > deadline:
				return
			add_child(_built[_next])
			_next += 1
			added += 1
		_built.clear()
		_held.clear()
		phase = Phase.READY
		set_process(false)
		built.emit()
