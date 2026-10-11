extends RefCounted

# Park recipe placement and registry (design-v3/PARK.md sections 2.2, 4 and 9). A park row's `recipe` places either a
# GLB recipe from assets/models/park/ or, for `greybox:<element>` and for a recipe whose GLB has not landed, a greybox
# primitive of the row's size. Either way the node carries a world collider and, when the row's ride fact is a
# WORLD_ROWS kind, a ride sensor that publishes it once each time the ball enters. Placement reads only the row; the
# visibility ranges come from the row's budget class in tools/asset_budgets.json, so retuning a range is one edit there.

const EventKinds := preload("res://src/core/event_kinds.gd")
const RecipeProps := preload("res://src/presentation/recipe_props.gd")

const BUDGETS_PATH := "res://tools/asset_budgets.json"
const GLB_DIR := "res://assets/models/park/"
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

static var _budgets := {}


# A budget class's visibility ranges from tools/asset_budgets.json: base_end and base_margin for the base views,
# shells as [[end, margin], ...] for detail shells 1 and 2, and for hero_landmark mid_end and mid_margin. {} when absent.
static func ranges(budget: String) -> Dictionary:
	if _budgets.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(BUDGETS_PATH))
		_budgets = parsed if parsed is Dictionary else {"classes": {}}
	return _budgets["classes"].get(budget, {}).get("ranges", {})


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
# the budget class's range. The caller keeps ownership of the part scenes.
static func place_parts(row: Dictionary, parts: Dictionary, parent: Node3D, ground := Callable(), publish := Callable()) -> Node3D:
	var node := _node(row, parent, ground)
	var body := _body(node)
	var r := ranges(String(row.get("budget", "landform")))
	var base_end := float(r.get("base_end", 0.0))
	var mid_end := float(r.get("mid_end", 0.0))
	for scene: Node in parts.get("base", []):
		for view in _views(scene, node, body):
			_range(view, 0.0, base_end, float(r.get("base_margin", 0.0)))
			view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var shell_ranges: Array = r.get("shells", [])
	var shells: Array = parts.get("shells", [])
	for k in shells.size():
		var sr: Array = shell_ranges[k] if k < shell_ranges.size() else [0.0, 0.0]
		for view in _views(shells[k], node, body):
			_range(view, 0.0, float(sr[0]), float(sr[1]))
			view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for scene: Node in parts.get("mid", []):
		for view in _views(scene, node, body):
			_range(view, base_end, mid_end, float(r.get("mid_margin", 0.0)))
			view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for scene: Node in parts.get("far", []):
		for view in _views(scene, node, body):
			_range(view, mid_end, 0.0, 0.0)
			view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_sensor(node, row, publish, true)
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
	_sensor(node, row, publish, false)
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


# One view per drawn mesh of scene under node, at its place in the scene; each -col mesh goes to body as a trimesh.
# A surface whose GLB material names a material slot wears that slot (recipe_props.gd); others keep their own.
static func _views(scene: Node, node: Node3D, body: StaticBody3D) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for source: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if source.mesh == null:
			continue
		var xf := _relative(source, scene)
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
# entry_origin is true for a GLB recipe (origin at the entry lip). None when the row's fact is no WORLD_ROWS kind or no publish callable is given.
static func _sensor(node: Node3D, row: Dictionary, publish: Callable, entry_origin: bool) -> void:
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
	# A GLB recipe's origin is its entry lip, so its footprint runs 0..length along +z; a greybox is centred.
	if entry_origin:
		shape.position.z = box.size.z * 0.5
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
