extends RefCounted

# Wave 12 addon probe (P-ADDON). A visual-only Terrain3D region and one Proton Scatter rock
# layer built from the same map samples terrain.gd uses. The 2 m heightfield trimesh stays
# the collider; nothing here collides. Every addon class is looked up by name, so the game
# parses and runs when the addons are absent and the bridge reports itself unavailable.

const Terrain := preload("res://src/world/terrain.gd")
const Palette := preload("res://src/core/palette.gd")
const SpillwayScenery := preload("res://src/presentation/spillway_scenery.gd")
const SCATTER_SCRIPT := "res://addons/proton_scatter/src/scatter.gd"
const ITEM_SCRIPT := "res://addons/proton_scatter/src/scatter_item.gd"
const SHAPE_SCRIPT := "res://addons/proton_scatter/src/scatter_shape.gd"
const BOX_SCRIPT := "res://addons/proton_scatter/src/shapes/box_shape.gd"
const MOD := "res://addons/proton_scatter/src/modifiers/%s.gd"

# One row per scatter layer: what it scatters, how many over the whole map, its scale and
# slope limits, and its seed. The probe carries one layer.
const LAYERS := [
	{"id": "rubble", "count": 6000, "scale": Vector2(0.18, 0.55), "max_slope": 30.0, "seed": 1207},
]
const REGION := 256
const GROUND_TEXTURE := "packed-sand-floor"
const TEXTURE_UV_SCALE := 0.08


static func terrain_available() -> bool:
	return ClassDB.class_exists("Terrain3D")


static func scatter_available() -> bool:
	return ResourceLoader.exists(SCATTER_SCRIPT) and load(SCATTER_SCRIPT) != null


# The height and colour images for map m, one pixel per metre over the region-aligned square
# that holds the terrain.gd map. Terrain3D 1.0.2 imports pixels as unit-spaced vertices and
# snaps the import origin down to its region grid (measured: a -200 m origin lands at -256 m),
# so the image starts on that grid and samples the same map function the collider grid does.
static func sample_images(m: RefCounted) -> Array[Image]:
	var side := 2 * REGION
	var height := Image.create_empty(side, side, false, Image.FORMAT_RF)
	var color := Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
	for j in side:
		var z := float(j - REGION)
		for i in side:
			var x := float(i - REGION)
			var s: Array = m.sample(x, z)
			height.set_pixel(i, j, Color(s[0], 0.0, 0.0, 1.0))
			var tint: Color = s[1]
			tint.a = 1.0
			color.set_pixel(i, j, tint)
	return [height, color]


# A Terrain3D node holding map m's region, added under parent. Null when the addon is absent.
static func build_terrain(parent: Node3D, m: RefCounted) -> Node3D:
	if not terrain_available():
		return null
	var terrain: Node3D = ClassDB.instantiate("Terrain3D")
	terrain.name = "Terrain3DProbe"
	terrain.region_size = REGION
	parent.add_child(terrain)
	terrain.collision.mode = 0
	terrain.material.world_background = 0
	var tex: Object = ClassDB.instantiate("Terrain3DTextureAsset")
	tex.name = GROUND_TEXTURE
	tex.albedo_texture = Palette.look_texture(GROUND_TEXTURE)
	tex.uv_scale = TEXTURE_UV_SCALE
	var assets: Object = ClassDB.instantiate("Terrain3DAssets")
	assets.set_texture(0, tex)
	terrain.assets = assets
	var images := sample_images(m)
	terrain.data.import_images([images[0], null, images[1]], Vector3(-REGION, 0.0, -REGION), 0.0, 1.0)
	return terrain


# The native ground's visual mesh under a stage root (the collider stays live).
static func native_ground_view(stage_root: Node) -> MeshInstance3D:
	var body := stage_root.get_node_or_null("Ground")
	if body == null:
		return null
	for c in body.get_children():
		if c is MeshInstance3D:
			return c
	return null


# One Proton Scatter node per LAYERS row over the whole map, projected onto the live ground
# collider. Emits nothing itself; the caller awaits the node's build_completed signal.
static func build_scatter(parent: Node3D, row: Dictionary, ground_y: float) -> Node3D:
	if not scatter_available():
		return null
	var scatter: Node3D = load(SCATTER_SCRIPT).new()
	scatter.name = "ScatterProbe_" + row["id"]
	scatter.global_seed = row["seed"]
	scatter.position = Vector3(0.0, ground_y, 0.0)
	var template := MeshInstance3D.new()
	template.name = "Template"
	template.mesh = SpillwayScenery._eroded_rock()
	template.material_override = Palette.solid(Palette.SANDSTONE.lerp(Palette.CHARCOAL, 0.35))
	template.visible = false
	scatter.add_child(template)
	var item: Node3D = load(ITEM_SCRIPT).new()
	item.name = "Item"
	item.source = 0
	scatter.add_child(item)
	item.path = "../Template"
	var shape_node: Node3D = load(SHAPE_SCRIPT).new()
	shape_node.name = "Area"
	var box: Resource = load(BOX_SCRIPT).new()
	box.size = Vector3(2.0 * Terrain.HALF, 4.0, 2.0 * Terrain.HALF)
	shape_node.shape = box
	scatter.add_child(shape_node)
	var stack: Resource = load("res://addons/proton_scatter/src/stack/modifier_stack.gd").new()
	var create: Resource = load(MOD % "create_inside_random").new()
	create.amount = row["count"]
	stack.add(create)
	var jitter: Resource = load(MOD % "randomize_transforms").new()
	jitter.rotation = Vector3(25.0, 360.0, 25.0)
	jitter.scale = Vector3.ONE * (row["scale"].y / row["scale"].x - 1.0)
	stack.add(jitter)
	var scale: Resource = load(MOD % "offset_scale").new()
	scale.scale = Vector3.ONE * row["scale"].x
	stack.add(scale)
	var project: Resource = load(MOD % "project_on_geometry").new()
	project.ray_offset = 400.0
	project.ray_length = 800.0
	project.max_slope = row["max_slope"]
	project.align_with_collision_normal = true
	stack.add(project)
	scatter.modifier_stack = stack
	scatter.dbg_disable_thread = true
	parent.add_child(scatter)
	return scatter
