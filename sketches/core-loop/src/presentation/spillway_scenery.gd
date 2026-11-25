extends RefCounted

const Palette := preload("res://src/core/palette.gd")
const GraphicsPreset := preload("res://src/presentation/graphics_preset.gd")
const Spillway := preload("res://src/world/map_spillway.gd")
const StageMap := preload("res://src/world/stage_map.gd")
const RecipeProps := preload("res://src/presentation/recipe_props.gd")
const ParkSites := preload("res://src/presentation/park_sites.gd")

# The existing cast slabs keep their exact geometry. Their finishes share the workshop's
# concrete/paint/shutter kit; the signal insert adds directional safety paint, open grates
# and recessed ancient lenses. A missing insert leaves every original material intact.
const PROP_SHADER_PATH := "res://assets/materials/wog_signal.gdshader"
static var prop_shader_path := PROP_SHADER_PATH
static var _prop_shaders := {}
static var _prop_warnings := {}
static var _prop_materials := {}


static func reset_for_tests() -> void:
	prop_shader_path = PROP_SHADER_PATH
	set_water_calm(false)


static func dress_props(parent: Node, keep: Node = null) -> void:
	var shader := _prop_shader()
	if shader == null:
		return
	for view: MeshInstance3D in parent.find_children("*", "MeshInstance3D", true, false):
		var original := view.material_override as StandardMaterial3D
		if keep != null and keep.is_ancestor_of(view):
			continue
		if not view.mesh is PrimitiveMesh or original == null or original.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			continue
		# Transparent steam and the threat painter's committed geometry keep their own grammar.
		if original.shading_mode != BaseMaterial3D.SHADING_MODE_PER_PIXEL:
			continue
		var size := view.mesh.get_aabb().size
		var color := original.albedo_color
		var second := Palette.CHARCOAL
		var role := "paint"
		if original.get_meta("greybox_checker", false):
			var image := original.albedo_texture.get_image()
			if image == null:
				continue
			color = image.get_pixel(0, 0)
			second = image.get_pixel(image.get_width() / 4, 0)
			if color.is_equal_approx(Palette.AMBER):
				role = "safety"
			elif color.is_equal_approx(Palette.COPPER):
				role = "grate" if view.mesh is CylinderMesh else "shutter"
			elif second.is_equal_approx(Palette.SAND):
				role = "grate"
			elif color.is_equal_approx(Palette.SANDSTONE):
				role = "cracked_cast"
			else:
				role = "concrete"
				color = second
		elif original.albedo_texture != null:
			continue
		elif original.emission_enabled:
			role = "lens"
		elif color.is_equal_approx(Palette.CHARCOAL):
			role = "recess"
		view.material_override = _prop_material(shader, original, role, color, second, size)
		view.set_meta("spillway_finish", role)
		view.set_meta("spillway_role_color", color)


static func _prop_shader() -> Shader:
	if _prop_shaders.has(prop_shader_path):
		return _prop_shaders[prop_shader_path]
	var shader: Shader
	if ResourceLoader.exists(prop_shader_path, "Shader"):
		shader = load(prop_shader_path) as Shader
	if shader == null or shader.code.is_empty():
		if not _prop_warnings.has(prop_shader_path):
			_prop_warnings[prop_shader_path] = true
			push_warning("spillway_scenery: missing or invalid prop finish " + prop_shader_path + "; original greybox retained")
		return null
	_prop_shaders[prop_shader_path] = shader
	return shader


static func _prop_material(shader: Shader, original: StandardMaterial3D, role: String,
		color: Color, second: Color, size: Vector3) -> Material:
	var key := prop_shader_path + ":" + role + ":" + color.to_html() + ":" + second.to_html() + ":" + str(size) + ":" + str(original.emission_energy_multiplier)
	if _prop_materials.has(key):
		return _prop_materials[key]
	var mat: Material
	if role in ["paint", "concrete", "shutter", "recess"]:
		mat = StageMap.dressed_surface(color, 0 if role == "concrete" else (2 if role == "shutter" else 1), size, second, original)
	else:
		var insert := ShaderMaterial.new()
		insert.shader = shader
		insert.resource_name = "spillway_" + role
		insert.set_shader_parameter("base_color", color)
		insert.set_shader_parameter("secondary_color", second)
		insert.set_shader_parameter("half_extents", size * 0.5)
		insert.set_shader_parameter("finish_kind", ["lens", "safety", "grate", "cracked_cast"].find(role))
		insert.set_shader_parameter("emission_energy", original.emission_energy_multiplier if original.emission_enabled else 0.0)
		mat = insert
	_prop_materials[key] = mat
	return mat

# Rim crown families, CLIFF-R2 section 1. Each crown is one closed solid: 12 perimeter stations
# (six along the arena face, six along the back, both lists ordered by world Z) and five height
# rings: buried base, h0 (the highest terrain under the footprint), then .35, .70 and 1.0 of the
# local crest rise. C = broad crown, S = saddle, H = blunt headland (variant 0, 1, 2).
const RIM_WIDTH := [48.0, 36.0, 24.0]
const RIM_DEPTH := [16.0, 12.0, 14.0]
const RIM_ADD := [18.0, 6.0, 12.0]
const RIM_GULLY := 6.0
const RIM_FAMILY_PITCH := 126.0
const RIM_START_Z := -186.0
const RIM_WEST_X := -167.0
# East centres per variant, so every root lies on the terrain side of X=200.
const RIM_EAST_X := [192.0, 194.0, 193.0]
# Family order along increasing world Z. F2 is C/S/H on both sides.
const RIM_WEST_ORDER := [[0, 1, 2], [0, 2, 1], [0, 1, 2]]
const RIM_EAST_ORDER := [[2, 1, 0], [2, 0, 1], [0, 1, 2]]
# Fraction of the crest rise per ring.
const RIM_RING_Y := [0.0, 0.0, 0.35, 0.70, 1.0]
# Crest profile, u along the unit's world-Z interval : metres above h0, linear between.
const RIM_CREST := [
	[Vector2(0, 8), Vector2(0.20, 16), Vector2(0.38, 18), Vector2(0.64, 17), Vector2(0.85, 12), Vector2(1, 8)],
	[Vector2(0, 3), Vector2(0.20, 5), Vector2(0.40, 6), Vector2(0.60, 5.5), Vector2(0.85, 4), Vector2(1, 3)],
	[Vector2(0, 5), Vector2(0.20, 10), Vector2(0.38, 12), Vector2(0.64, 12), Vector2(0.85, 10), Vector2(1, 6)],
]
# CLIFF-R3 section 2: oblique plans. The proposal tables come from tools/cliff_gate_report.py (its
# gate passed on exactly these values). Crowns: 12 stations (x toward the arena, z along world Z,
# face list ascending then back list descending) and per-face batter (metres of inward lean per metre
# of rise); hulls: 10 (d outward from the arena, e along Z) stations at the bottom level and per-face
# batter. Corner lines are solved so every face stays planar. Crowns index by variant; hulls by
# (index in side + 2 on the east side) mod 4.
const RIM_PLAN := [
	{"plan": [Vector2(-3.8857, -21.8841), Vector2(6.0186, -20.1818), Vector2(4.6834, -3.8842), Vector2(7.4083, 7.5523), Vector2(2.5292, 20.1855), Vector2(8, 21.5691), Vector2(1.6873, 24), Vector2(-6.8807, 21.516), Vector2(-4.599, 11.216), Vector2(-8, -3.2799), Vector2(-6.4321, -10.1929), Vector2(-6.2417, -12.0995)],
	 "batter": [0.0778, 0.2858, 0.1053, 0.02, 0.1028, 0.2007, 0.2948, 0.0926, 0.0537, 0.272, 0.2475, 0.1651]},
	{"plan": [Vector2(-5.3384, -18), Vector2(5.0068, -7.8037), Vector2(4.0388, -1.4971), Vector2(6, 8.1457), Vector2(5.499, 11.9715), Vector2(-0.0322, 18), Vector2(-2.9332, 18), Vector2(-6, 9.5838), Vector2(-4.2738, 7.8286), Vector2(-5.5903, 1.2087), Vector2(-6, -8.7386), Vector2(-2.8077, -13.1506)],
	 "batter": [0.02, 0.2324, 0.1959, 0.0433, 0.1852, 0.2431, 0.2651, 0.3045, 0.3005, 0.048, 0.0768, 0.32]},
	{"plan": [Vector2(2.5445, -12), Vector2(7, -6.9406), Vector2(4.0358, -0.9369), Vector2(7, 4.372), Vector2(4.4128, 5.4377), Vector2(-1.2843, 12), Vector2(-6.4143, 9.2166), Vector2(-6.207, 1.4193), Vector2(-7, -2.7744), Vector2(-3.9308, -5.5223), Vector2(-4.4633, -6.6451), Vector2(-2.7144, -12)],
	 "batter": [0.02, 0.1009, 0.2302, 0.0529, 0.2369, 0.0261, 0.1525, 0.1863, 0.169, 0.0707, 0.2332, 0.2826]},
]
const HULL_PLAN := [
	{"plan": [Vector2(-4.332, -26), Vector2(-19.7882, -19.525), Vector2(-29.6859, -10.3039), Vector2(-27.946, 10.5188), Vector2(-13.0824, 22.1212), Vector2(0.4141, 26), Vector2(28.9284, 7.5273), Vector2(22.0613, -9.4136), Vector2(21.4312, -18.4303), Vector2(13.978, -20.3406)],
	 "batter": [0.1797, 0.3018, 0.1882, 0.073, 0.0669, 0.0222, 0.0197, 0.0209, 0.0125, 0.01]},
	{"plan": [Vector2(-9.4633, -25.6169), Vector2(-27.9152, -14.8311), Vector2(-31.1228, 0.0565), Vector2(-18.7477, 13.1224), Vector2(-2.2894, 25.6612), Vector2(20.3481, 19.6373), Vector2(35, 9.3607), Vector2(35, -9.6425), Vector2(25.5241, -26), Vector2(7.1036, -21.8069)],
	 "batter": [0.1778, 0.2965, 0.154, 0.1128, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01]},
	{"plan": [Vector2(-5.8695, -26), Vector2(-25.0628, -13.6264), Vector2(-29.6513, 0.8798), Vector2(-21.2899, 16.0649), Vector2(-14.8329, 25.8409), Vector2(7.7628, 24.3933), Vector2(32.0479, 10.0798), Vector2(27.4522, 3.8008), Vector2(21.164, -15.3955), Vector2(17.9963, -17.4291)],
	 "batter": [0.1325, 0.2552, 0.2846, 0.2816, 0.0507, 0.01, 0.01, 0.0137, 0.01, 0.01]},
	{"plan": [Vector2(-3.9122, -22.5991), Vector2(-26.4237, -9.3698), Vector2(-29.5856, 5.5511), Vector2(-18.2767, 17.5192), Vector2(-2.779, 21.7131), Vector2(15.7282, 23.8975), Vector2(35, 8.1077), Vector2(26.7593, -13.9213), Vector2(11.3319, -26), Vector2(6.89, -12.2567)],
	 "batter": [0.0826, 0.0818, 0.1351, 0.112, 0.085, 0.01, 0.01, 0.0459, 0.0145, 0.1785]},
]

# All instances stay outside the stage-1 play rectangle plus an 8 m apron. No collisions.
static func build(stage_root: Node3D) -> Node3D:
	var scenery := Node3D.new()
	scenery.name = "SpillwayScenery"
	stage_root.add_child(scenery)
	var stone: Array[Transform3D] = []
	var trim: Array[Transform3D] = []
	var recess: Array[Transform3D] = []
	var metal: Array[Transform3D] = []
	var rocks: Array[Transform3D] = []
	var banners: Array[Transform3D] = []
	var water: Array[Transform3D] = []
	var pools: Array[Transform3D] = []
	var mist: Array[Transform3D] = []
	var cables: Array[Transform3D] = []
	var cabins: Array[Transform3D] = []
	var lamps: Array[Transform3D] = []
	var glyphs: Array[Transform3D] = []

	# A downstream retaining wall with three valve towers above the existing rim.
	_place(stone, Vector3(0, 70, 247), Vector3(270, 100, 22))
	_place(trim, Vector3(0, 122, 247), Vector3(282, 5, 28))
	for x in [-112.0, -84.0, -56.0, -28.0, 0.0, 28.0, 56.0, 84.0, 112.0]:
		_place(trim, Vector3(x, 71, 230), Vector3(8, 94, 12))
		_place(recess, Vector3(x + 11, 109, 235.5), Vector3(10, 13, 1))
		_place(stone, Vector3(x, 128, 247), Vector3(7, 8, 25))
	for x in [-90.0, 0.0, 90.0]:
		_place(stone, Vector3(x, 138, 247), Vector3(27, 35, 32))
		_place(trim, Vector3(x, 157, 247), Vector3(33, 4, 38))
		_place(stone, Vector3(x, 165, 247), Vector3(19, 12, 23))
		_place(metal, Vector3(x, 173, 247), Vector3(24, 4, 28))
		for dx in [-7.0, 0.0, 7.0]:
			_place(recess, Vector3(x + dx, 143, 230.5), Vector3(3, 12, 1))
		_place(metal, Vector3(x, 94, 224), Vector3(3, 40, 3))

	# Lintels give the retaining wall scale.
	for x in [-90.0, 0.0, 90.0]:
		_place(banners, Vector3(x + 12, 106, 228), Vector3(7, 26, 0.25))
		_place(metal, Vector3(x + 12, 120, 228), Vector3(11, 0.7, 1.0))
		for floor_index in 3:
			_place(trim, Vector3(x, 132 + floor_index * 10, 229), Vector3(28, 1.0, 2.0))

	# All water is behind the existing southern rim, never on a traversable shelf.
	for x in [-103.0, -47.0, 37.0, 93.0]:
		# Spill mist: a small cluster of irregular, feathered patches per fall. Sizes, offsets and
		# in-plane rolls vary from a fixed seed, so no row or grid reads; alpha stays at the cap.
		var rng := RandomNumberGenerator.new()
		rng.seed = int(absf(x) * 31.0) + 7
		for j in 11:
			_place_mist(mist, Vector3(x + rng.randf_range(-15.0, 15.0), rng.randf_range(30.0, 42.0), 211.0 + rng.randf_range(0.0, 11.0)),
				Vector2(rng.randf_range(10.0, 22.0), rng.randf_range(6.0, 13.0)), rng.randf_range(-0.7, 0.7))
		# Ledge spray where the sheet strikes the visible dam face, above the rim line.
		for j in 8:
			_place_mist(mist, Vector3(x + rng.randf_range(-8.0, 8.0), rng.randf_range(38.0, 58.0), 222.0 + rng.randf_range(0.0, 3.0)),
				Vector2(rng.randf_range(8.0, 16.0), rng.randf_range(5.0, 11.0)), rng.randf_range(-1.0, 1.0))
	# G05: the four sheets and the tailrace are hand-broken meshes in world metres (water_edges.glb),
	# each inside the box it replaces, so they take one identity placement.
	_place(water, Vector3.ZERO, Vector3.ONE)
	_place(pools, Vector3.ZERO, Vector3.ONE)
	# Shoulders: 16 continuous hulls (below) replace the 64 shelves; 48 small scattered rocks keep their
	# transforms. The cottonwoods stand on the hull roots under the stage root (_cottonwoods).
	for side in [-1.0, 1.0]:
		for i in 8:
			var z := -176.0 + i * 56.0
			for j in 3:
				_place(rocks, Vector3(side * (206 + j * 2), 31, z + j * 2), Vector3(0.5, 0.3, 0.7), j)
	# The rim skyline is the crown, saddle and headland families of GEOMETRY.md section 3, baked
	# into the shoulder batch below. West crowns end at x=-158, east ones start at x=184.
	var rim := rim_plan(Spillway.new())
	# Service balconies, lanterns and ball-culture marks share existing batches.
	for x in [-90.0, 0.0, 90.0]:
		_place(metal, Vector3(x, 91, 221), Vector3(29, 1, 8))
		for dx in [-12.0, 12.0]:
			_place(metal, Vector3(x + dx, 99, 218), Vector3(0.7, 16, 0.7))
			_place(lamps, Vector3(x + dx, 104, 217), Vector3(1.1, 1.8, 1.1))
		_place(metal, Vector3(x, 107, 218), Vector3(26, 0.6, 0.6))
		_place(glyphs, Vector3(x + 12, 106, 227.6), Vector3(2.6, 2.6, 0.5))
		# Gyro rings are narrow segments around the sphere, no letters or warning bands.
		for k in 16:
			var a := k * TAU / 16.0
			var tr := Transform3D(Basis(Vector3.FORWARD, -a).scaled(Vector3(0.27, 1.3, 0.2)), Vector3(x + 12 + cos(a) * 2.5, 106 + sin(a) * 4.1, 227.3))
			cables.append(tr)
	for k in 36:
		var x := -250.0 + k * 14.0
		_place(cables, Vector3(x, 157 - 16 * (1.0 - pow(x / 260.0, 2)), 267), Vector3(14.2, 0.24, 0.24))
	for x in [-171.0, -24.0, 137.0]:
		var cable_y := 157 - 16 * (1.0 - pow(x / 260.0, 2))
		_place(cables, Vector3(x, cable_y - 4, 267), Vector3(0.3, 8, 0.3))
		_place(cabins, Vector3(x, cable_y - 11, 267), Vector3(8, 6, 6))
		_place(metal, Vector3(x, cable_y - 7.5, 267), Vector3(10, 0.7, 8))
		_place(recess, Vector3(x, cable_y - 10, 263.9), Vector3(6, 2.7, 0.2))

	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var rock := _eroded_rock()
	# One opaque cliff draw: the shoulder shelves and the rim crowns share the batch, so the
	# rim swap adds no draw. The cliff shader reads world position, not vertex colour.
	var cliff := SurfaceTool.new()
	cliff.begin(Mesh.PRIMITIVE_TRIANGLES)
	for placement in rocks:
		cliff.append_from(_placed_rock(rock, placement), 0, Transform3D.IDENTITY)
	for crown in rim:
		cliff.append_from(crown_mesh(crown), 0, crown_transform(crown))
	for hull in shoulder_plan():
		cliff.append_from(shoulder_mesh(hull), 0, Transform3D.IDENTITY)
	cliff.index()
	var canopy := SphereMesh.new()
	# Spray cards: a two-triangle quad facing the play area with a soft radial alpha edge,
	# so the shared triangle budget is not spent on spheres.
	var puff := QuadMesh.new()
	puff.size = Vector2(2, 2)
	puff.flip_faces = true
	canopy.radius = 1.0
	canopy.height = 2.0
	canopy.radial_segments = 6
	canopy.rings = 2
	_batch(scenery, "Masonry", box, stone, Color("b79468"))
	_batch(scenery, "LimestoneCaps", box, trim, Color("d5b785"))
	_batch(scenery, "Recesses", box, recess, Color("454943"))
	_batch(scenery, "CopperValves", box, metal, Color("885e43"))
	_batch(scenery, "SandstoneShoulders", cliff.commit(), [Transform3D.IDENTITY], Color("b37d50"))
	_dam_detail(scenery)
	_batch(scenery, "ValvePennants", box, banners, Color("6e8982"))
	var sheets := _water_edge_mesh("SpillSheets", box)
	var tailrace := _water_edge_mesh("Tailrace", box)
	_batch(scenery, "SpillSheets", sheets, water, Color.WHITE)
	_batch(scenery, "Tailrace", tailrace, pools, Color.WHITE)
	(scenery.get_node("Tailrace").material_override as ShaderMaterial).set_shader_parameter("drift", tailrace_drift(sheets, tailrace))
	_batch(scenery, "WaterMist", puff, mist, Color("bcd4da"))
	_batch(scenery, "CablesAndGyros", box, cables, Color("c7b18c"))
	_batch(scenery, "CableCars", box, cabins, Color("537b72"))
	_batch(scenery, "LanternLenses", box, lamps, Color("f2cc88"))
	_batch(scenery, "BallInsignia", canopy, glyphs, Color("e2ceb0"))
	_merge_opaque(scenery)
	_cottonwoods(stage_root)
	return scenery


# The park pass (park_dam, park_flume; the old map's build() is fixed to the stage-1 rim): game.gd
# builds the old map at boot, and this hook builds a Spillway park stage on the entry that builds its
# ground, again after a freed stage comes back. Visual only, nothing collides.
static func hook(ctx) -> void:
	ctx.events.stage_entered.connect(_on_stage_entered.bind(ctx))
	# The context owns the terrain, a RefCounted, so a handler on its signal bound to the context would
	# hold the context from the terrain: a cycle that outlives the game and keeps this script's statics
	# with it (scrapkeep#494). The handler takes the context through a weak reference.
	ctx.terrain.stage_built.connect(_on_stage_built_weak.bind(weakref(ctx)))


static func _on_stage_built_weak(stage: int, ctx_ref: WeakRef) -> void:
	var ctx = ctx_ref.get_ref()
	if ctx != null:
		_on_stage_built(stage, ctx)


# A Spillway park stage built ahead on worker threads (the flume, behind the dam) takes its park pass
# a step a frame from when its ground is done (ParkBuild), parked out of sight, while the current
# stage is calm, as dig_scenery.gd's does: the whole pass was 45 ms of the flume's entry tick on the
# cloud (scrapkeep#494). Entry finishes whatever is left. A bot run that builds stages whole, or a
# stage on show, keeps the entry build.
static func _on_stage_built(stage: int, ctx) -> void:
	if not ctx.terrain.built_threaded(stage):
		return
	for row in ctx.stages.DEFS:
		if int(row["stage"]) != stage:
			continue
		var root: Node3D = ctx.terrain.geometry_root(stage)
		var map = ctx.terrain.map_for(stage)
		if not ParkSites.is_park(map) or int(row.get("world", 0)) != 1 or root.visible or root.get_node_or_null("SpillwayScenery") != null:
			return
		var pass_ := ParkPass.new(root, map, ctx.terrain.ground_callable(stage), stage)
		var step := ParkBuild.new()
		step.name = "ParkBuild"
		step.pass_ = pass_
		step.flow = ctx.flow
		pass_.scenery.add_child(step)
		return


# Steps a park pass begun ahead, one step a frame, and leaves when it is done.
class ParkBuild extends Node:
	var pass_
	# Steps wait while this flow is not calm; without one (a test) they run every frame.
	var flow

	func _process(_delta: float) -> void:
		if flow != null and not flow.calm():
			return
		if not pass_.step():
			finish()

	func finish() -> void:
		while pass_.step():
			pass
		queue_free()
		set_process(false)


static func _on_stage_entered(stage: int, _retry: bool, ctx) -> void:
	for row in ctx.stages.DEFS:
		if int(row["stage"]) != stage:
			continue
		var map = ctx.terrain.map_for(stage)
		if ParkSites.is_park(map) and int(row.get("world", 0)) == 1:
			var root: Node3D = ctx.terrain.geometry_root(stage)
			var ahead := root.get_node_or_null("SpillwayScenery/ParkBuild")
			if ahead != null and not ahead.is_queued_for_deletion():
				ahead.finish()
			if root.get_node_or_null("SpillwayScenery") == null:
				build_park(root, map, ctx.terrain.ground_callable(stage), stage)
		return


# The water's edge of a park: cottonwood groves on the flanks of its washes, canals, canyons and
# the flume, and spill mist where its water drops: below each drop on a wet landform and at the
# foot of a dam face. The dam itself, the flume spans and the cable cars are park rows and
# landmark recipes, so the old rim's retaining wall, valve towers and gondolas stay on the old map.
const PARK_WET := ["river_canyon", "canal", "slot_canyon", "dry_wash", "arroyo", "flume", "dam_face"]
const PARK_TREES_MAX := 24
const PARK_MIST_ROWS_MAX := 10
const PARK_FACE_MIN_M := 20.0


static func build_park(stage_root: Node3D, map, ground: Callable, stage: int) -> Node3D:
	var pass_ := ParkPass.new(stage_root, map, ground, stage)
	while pass_.step():
		pass
	return pass_.scenery


# The park pass as steps, so it can run whole (build_park) or a step a frame (ParkBuild): the plan and
# the mist, the cottonwoods' base batches, their detail shells PARK_TREES_PER_STEP trees a step, the
# spillway effects, then the next stage's smoke on the horizon where the park names one (smoke_column.gd).
# Steps run in the same order either way, and only the plan draws from the seeded stream, so the result
# is the same.
const PARK_TREES_PER_STEP := 4


class ParkPass extends RefCounted:
	const Scenery := preload("res://src/presentation/spillway_scenery.gd")
	var scenery: Node3D
	var _stage_root: Node3D
	var _map
	var _sites
	var _trees := []
	var _group: Node3D
	var _next_tree := 0
	var _phase := 0

	func _init(stage_root: Node3D, map, ground: Callable, stage: int) -> void:
		_stage_root = stage_root
		_map = map
		scenery = Node3D.new()
		scenery.name = "SpillwayScenery"
		stage_root.add_child(scenery)
		_sites = ParkSites.new(map, ground, stage)

	# One step; false once the pass is done.
	func step() -> bool:
		match _phase:
			0:
				_trees = Scenery._plan(scenery, _sites, _map)
				_phase = 1 if not _trees.is_empty() else 3
			1:
				_group = Scenery._cottonwood_group(_stage_root, _trees)
				_phase = 2
			2:
				var to := mini(_next_tree + PARK_TREES_PER_STEP, _trees.size())
				Scenery._cottonwood_shells(_group, _trees, _next_tree, to)
				_next_tree = to
				if _next_tree >= _trees.size():
					_phase = 3
			3:
				preload("res://src/presentation/spillway_fx.gd").place(scenery, _stage_root, _map, _sites)
				_phase = 4
			4:
				preload("res://src/presentation/smoke_column.gd").place(scenery, _map, _sites.height)
				_phase = 5
		return _phase < 5


# The park's cottonwood seats and its mist batch (under scenery), from the map's own seeded stream.
static func _plan(scenery: Node3D, sites, map) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = ("spillway_scenery_" + String(map.park["map"])).hash()
	var rows: Array = sites.rows([], PARK_WET).filter(func(row): return row["element"] != "anchor_field")
	var trees := []
	for row in rows:
		for seat in sites.flank(row, 2, rng.randf_range(4.0, 12.0), rng):
			if trees.size() >= PARK_TREES_MAX:
				break
			var at: Vector2 = seat["at"]
			var low := INF
			var high := -INF
			for probe in [Vector2.ZERO, Vector2(3, 0), Vector2(-3, 0), Vector2(0, 3), Vector2(0, -3)]:
				var h: float = sites.height(at + probe)
				low = minf(low, h)
				high = maxf(high, h)
			if high - low <= 1.5:
				trees.append({"foot": Vector3(at.x, low, at.y), "size": rng.randf_range(0.6, 1.0)})
	var mist: Array[Transform3D] = []
	# Water falls off a drop, and down the dam's face (its tall bank row), not off the toe's ledges and ramps.
	var drops: Array = rows.filter(func(row): return row["element"] == "drop" \
		or (row["landform"] == "dam_face" and row["element"] == "bank" and float(row["size"][1]) >= PARK_FACE_MIN_M))
	for row in drops.slice(0, PARK_MIST_ROWS_MAX):
		var f := ParkSites.frame(row)
		var foot: Vector2 = f["at"] + f["run"] * float(f["half_length"])
		var y: float = sites.height(foot)
		var face := Basis(Vector3.UP, ParkSites.yaw_toward(-f["run"]))
		var across := clampf(float(f["half_width"]), 12.0, 180.0)
		for j in 9 * ceili(across / 60.0):
			var at := Vector3(foot.x, 0.0, foot.y) + face * Vector3(rng.randf_range(-across, across), 0.0, rng.randf_range(-2.0, 8.0))
			at.y = y + rng.randf_range(2.0, 12.0)
			mist.append(Transform3D(face * Basis(Vector3.BACK, rng.randf_range(-0.7, 0.7)).scaled(
				Vector3(rng.randf_range(8.0, 18.0), rng.randf_range(5.0, 11.0), 1.0)), at))
	if not mist.is_empty():
		var puff := QuadMesh.new()
		puff.size = Vector2(2, 2)
		puff.flip_faces = true
		_batch(scenery, "WaterMist", puff, mist, Color("bcd4da"))
	# A row that carries clear_view keeps the strip behind its rear edge free of trees, so the ball
	# arrives with the row and what lies past it in one view. Filter after seating so the other
	# trees and mist retain their seed.
	for row in map.park["park_rows"]:
		if row.has("clear_view"):
			var frame := ParkSites.frame(row)
			var view: Dictionary = row["clear_view"]
			trees = trees.filter(func(tree):
				var foot: Vector3 = tree["foot"]
				return not ParkSites.in_clear_view(frame, view, Vector2(foot.x, foot.z)))
	return trees


# SWAP-WAVE 12-F: the shoulder cottonwoods are the cottonwood recipe, one tree per hull root under the stage root (not the
# scenery batches, which bake and merge their children). The base trunk and crown are one MultiMesh per base view, an
# instance per tree, each surface in the loader's slot material; the detail shells hang per tree under a holder at the
# tree's frame, so each fades by its own distance. A park passes its own trees.
static func _cottonwoods(stage_root: Node3D, trees: Array = []) -> Node3D:
	if trees.is_empty():
		trees = cottonwood_trees()
	var group := _cottonwood_group(stage_root, trees)
	_cottonwood_shells(group, trees, 0, trees.size())
	return group


# The Cottonwoods group under the stage root with its base batches, one MultiMesh per base view.
static func _cottonwood_group(stage_root: Node3D, trees: Array) -> Node3D:
	var group := Node3D.new()
	group.name = "Cottonwoods"
	stage_root.add_child(group)
	var probe := Node3D.new()
	for view: GeometryInstance3D in RecipeProps.base("cottonwood", probe, Transform3D.IDENTITY):
		var source := view as MeshInstance3D
		var mesh := source.mesh.duplicate() as ArrayMesh
		for i in mesh.get_surface_count():
			mesh.surface_set_material(i, source.get_surface_override_material(i))
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = mesh
		multi.instance_count = trees.size()
		var origins := PackedVector3Array()
		for i in trees.size():
			var placed := cottonwood_frame(trees[i]) * source.transform
			multi.set_instance_transform(i, placed)
			origins.append(placed.origin)
		var batch := MultiMeshInstance3D.new()
		batch.name = source.name
		batch.multimesh = multi
		# A headless renderer keeps no instance buffer, so tests read the placements from here.
		batch.set_meta("origins", origins)
		batch.cast_shadow = source.cast_shadow
		group.add_child(batch)
		GraphicsPreset.register_scenery(batch)
	probe.free()
	return group


# Trees from..to-1's detail shells, each under a holder at the tree's frame.
static func _cottonwood_shells(group: Node3D, trees: Array, from: int, to: int) -> void:
	for i in range(from, to):
		var holder := Node3D.new()
		holder.name = "Cottonwood%02d" % i
		group.add_child(holder)
		holder.transform = cottonwood_frame(trees[i])
		for shell in RecipeProps.shells("cottonwood", holder, Transform3D.IDENTITY):
			GraphicsPreset.register_scenery(shell)


# The water runs (spill_water.gdshader): down the slope of each face, faster the steeper it is,
# and where a face is flat it drifts by the surface's drift uniform. flow_at is the shader's
# vertex flow in GDScript, so tests/water_flow_test.gd can check it on the built meshes.
const WATER_FALL_SPEED := 2.4
# Below WATER_LEVEL (sine of the slope) a face is level water and only drifts; the fall fades in
# up to WATER_SLOPED. Same values as LEVEL and SLOPED in the shader.
const WATER_LEVEL := 0.05
const WATER_SLOPED := 0.15
const WATER_VERTICAL := 0.98
# The tailrace's drift away from the falls, m/s: still water barely moves.
const TAILRACE_DRIFT := 0.35
# The water_flow_scale shader global under reduced motion: the water runs slower, never stops.
const CALM_FLOW := 0.35
static var flow_scale := 1.0


static func flow_at(normal: Vector3, drift: Vector2) -> Vector3:
	var n := normal.normalized()
	var steep := sqrt(maxf(0.0, 1.0 - n.y * n.y))
	var downhill := Vector3(n.x * n.y, n.y * n.y - 1.0, n.z * n.y)
	var sloped := smoothstep(WATER_LEVEL, WATER_SLOPED, steep)
	var fall_dir := downhill.lerp(Vector3.DOWN, smoothstep(0.95, WATER_VERTICAL, steep))
	return fall_dir * WATER_FALL_SPEED * sloped + Vector3(drift.x, 0.0, drift.y) * (1.0 - sloped)


# How far the shader's pattern has been carried at time_s.
static func flow_offset(normal: Vector3, drift: Vector2, time_s: float) -> Vector3:
	return flow_at(normal, drift) * time_s * flow_scale


# Away from the falls, level: from the spill sheets' middle to the tailrace's.
static func tailrace_drift(sheets: Mesh, tailrace: Mesh) -> Vector2:
	var from := sheets.get_aabb().get_center()
	var to := tailrace.get_aabb().get_center()
	var away := Vector2(to.x - from.x, to.z - from.z)
	return away.normalized() * TAILRACE_DRIFT if away.length() > 0.01 else Vector2.ZERO


# The one place reduced motion reaches the water. The dummy renderer a headless run uses
# stores no globals, so flow_scale keeps the value for tests and flow_offset.
static func set_water_calm(on: bool) -> void:
	flow_scale = CALM_FLOW if on else 1.0
	RenderingServer.global_shader_parameter_set("water_flow_scale", flow_scale)


static func _water_edge_mesh(node_name: String, fallback: Mesh) -> Mesh:
	var packed := load("res://assets/models/world_one/water_edges.glb") as PackedScene
	if packed == null:
		return fallback
	var scene := packed.instantiate()
	var found: Mesh = null
	for candidate in scene.find_children(node_name, "MeshInstance3D", true, false):
		found = (candidate as MeshInstance3D).mesh
	scene.free()
	return found if found != null else fallback


# I01: broad cast courses and repaired service frames from dam.glb, on the wall's front face
# (z 236, at most 1.2 m proud). One node with a surface per slot, so each slot keeps the sheet's
# roughness; no material_override, so _merge_opaque leaves it as its own three draws.
const DAM_PATH := "res://assets/models/world_one/dam.glb"
const DAM_FACE := Vector3(0, 0, 236)
const DAM_TINT := {"paint": Color.WHITE, "bare_metal": Color("7a7a70"), "rubber": Color("454943")}
const DAM_ROUGHNESS := {"paint": 0.8, "bare_metal": 0.45, "rubber": 0.95}


static func _dam_detail(parent: Node3D) -> void:
	var packed := load(DAM_PATH) as PackedScene
	if packed == null:
		push_warning("spillway_scenery: dam.glb missing, the dam face stays bare")
		return
	var scene := packed.instantiate()
	var mesh := ArrayMesh.new()
	for view: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		for surface in view.mesh.get_surface_count():
			var arrays := view.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for i in vertices.size():
				vertices[i] += DAM_FACE
			arrays[Mesh.ARRAY_VERTEX] = vertices
			var slot: String = view.mesh.surface_get_material(surface).resource_name
			var material := StandardMaterial3D.new()
			material.resource_name = slot
			material.albedo_color = DAM_TINT.get(slot, Color.WHITE)
			material.roughness = DAM_ROUGHNESS.get(slot, 1.0)
			material.vertex_color_use_as_albedo = true
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			mesh.surface_set_material(mesh.get_surface_count() - 1, material)
	scene.free()
	var node := MeshInstance3D.new()
	node.name = "DamDetail"
	node.mesh = mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	GraphicsPreset.register_scenery(node)


static func _place(into: Array[Transform3D], at: Vector3, size: Vector3, turn := 0.0) -> void:
	into.append(Transform3D(Basis(Vector3.UP, turn).scaled(size), at))


static func _place_mist(into: Array[Transform3D], at: Vector3, half: Vector2, roll: float) -> void:
	into.append(Transform3D(Basis(Vector3.BACK, roll).scaled(Vector3(half.x, half.y, 1.0)), at))


static func _merge_opaque(parent: Node3D) -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var material: StandardMaterial3D
	for child in parent.get_children():
		var mat = child.material_override
		if not mat is StandardMaterial3D or mat.emission_enabled or mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			continue
		var arrays: Array = child.mesh.surface_get_arrays(0)
		var offset := vertices.size()
		vertices.append_array(arrays[Mesh.ARRAY_VERTEX])
		normals.append_array(arrays[Mesh.ARRAY_NORMAL])
		for color in arrays[Mesh.ARRAY_COLOR]:
			colors.append(color * mat.albedo_color.srgb_to_linear())
		for index in arrays[Mesh.ARRAY_INDEX]:
			indices.append(index + offset)
		if material == null:
			material = mat.duplicate()
			material.albedo_color = Color.WHITE
		child.free()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var importer := ImporterMesh.new()
	importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
	importer.generate_lods(60.0, 0.0, [])
	var view := MeshInstance3D.new()
	view.name = "DamAndLedgeDressing"
	view.mesh = importer.get_mesh()
	view.material_override = material
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(view)
	GraphicsPreset.register_scenery(view)


static func _batch(parent: Node3D, label: String, mesh: Mesh, placements: Array[Transform3D], tint: Color) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 1.0
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = Palette.look_texture("sandstone-strata")
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.uv1_triplanar = true
	material.uv1_scale = Vector3.ONE / 6.0
	var source := mesh.surface_get_arrays(0)
	var source_vertices: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
	var source_normals: PackedVector3Array = source[Mesh.ARRAY_NORMAL]
	var source_indices: PackedInt32Array = source[Mesh.ARRAY_INDEX]
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for placement in placements:
		var offset := vertices.size()
		if label == "WaterMist":
			uvs.append_array(source[Mesh.ARRAY_TEX_UV])
		var variation := 0.91 + 0.09 * sin(placement.origin.x * 4.7 + placement.origin.z * 2.3 + placement.origin.y)
		var normal_basis := placement.basis.inverse().transposed()
		for i in source_vertices.size():
			vertices.append(placement * source_vertices[i])
			var shade := variation * (0.84 + 0.16 * clampf(source_vertices[i].y + 0.5, 0.0, 1.0))
			colors.append(Color(shade, shade, shade))
			normals.append((normal_basis * source_normals[i]).normalized())
		for index in source_indices:
			indices.append(offset + index)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	if label == "WaterMist":
		arrays[Mesh.ARRAY_TEX_UV] = uvs
	var view := MeshInstance3D.new()
	view.name = label
	var importer := ImporterMesh.new()
	importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
	importer.generate_lods(60.0, 0.0, [])
	view.mesh = importer.get_mesh()
	view.material_override = material
	if label == "SandstoneShoulders":
		view.material_override = Palette.rock_material()
	elif label in ["SpillSheets", "Tailrace"]:
		var flowing := ShaderMaterial.new()
		flowing.shader = preload("res://src/presentation/spill_water.gdshader")
		flowing.set_shader_parameter("falling", label == "SpillSheets")
		view.material_override = flowing
	elif label == "WaterMist":
		# Spill mist at the four falls only (LIGHTING-TARGETS: #BCD4DA); the scenery test caps
		# its alpha at 0.12, so bigger cards and a cooler tint carry it, not more opacity.
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color("bcd4da", 0.12)
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var soft := Gradient.new()
		# Card UVs, not triplanar, so each card carries one falloff.
		material.uv1_triplanar = false
		material.uv1_scale = Vector3.ONE
		soft.offsets = PackedFloat32Array([0.0, 0.3, 0.6, 0.85, 1.0])
		soft.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.7), Color(1, 1, 1, 0.3), Color(1, 1, 1, 0.06), Color(1, 1, 1, 0)])
		var falloff := GradientTexture2D.new()
		falloff.gradient = soft
		falloff.fill = GradientTexture2D.FILL_RADIAL
		falloff.fill_from = Vector2(0.5, 0.5)
		falloff.fill_to = Vector2(1.0, 0.5)
		material.albedo_texture = falloff
	elif label == "LanternLenses":
		material.emission_enabled = true
		material.emission = tint
		material.emission_energy_multiplier = 1.1
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(view)
	GraphicsPreset.register_scenery(view)


# Bakes one shelf with the base _batch rule: positions by the placement, normals by its
# inverse transpose, so non-uniform scale keeps the lit normals the base had.
static func _placed_rock(rock: ArrayMesh, placement: Transform3D) -> ArrayMesh:
	var source := rock.surface_get_arrays(0)
	var vertices: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = source[Mesh.ARRAY_NORMAL]
	var normal_basis := placement.basis.inverse().transposed()
	var out_vertices := PackedVector3Array()
	var out_normals := PackedVector3Array()
	for i in vertices.size():
		out_vertices.append(placement * vertices[i])
		out_normals.append((normal_basis * normals[i]).normalized())
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = out_vertices
	arrays[Mesh.ARRAY_NORMAL] = out_normals
	arrays[Mesh.ARRAY_INDEX] = source[Mesh.ARRAY_INDEX]
	var baked := ArrayMesh.new()
	baked.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return baked


static func _eroded_rock() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array] = []
	for row in 5:
		var ring := PackedVector3Array()
		var y := -1.0 + row / 2.0
		for col in 8:
			var a := col * TAU / 8.0
			var lip := 1.0 if row % 2 == 0 else 0.92
			var r := (0.91 + 0.09 * sin(col * 2.7 + row * 0.4)) * lip * (1.0 - maxf(y, 0.0) * 0.12)
			ring.append(Vector3(cos(a) * r, y + sin(col * 2.1) * 0.05, sin(a) * r))
		rings.append(ring)
	for row in 4:
		for col in 8:
			var j := (col + 1) % 8
			for v in [rings[row][col], rings[row][j], rings[row + 1][col], rings[row][j], rings[row + 1][j], rings[row + 1][col]]:
				st.add_vertex(v)
	for col in 8:
		for v in [Vector3(0, 1, 0), rings[4][(col + 1) % 8], rings[4][col], Vector3(0, -1, 0), rings[0][col], rings[0][(col + 1) % 8]]:
			st.add_vertex(v)
	st.generate_normals()
	st.index()
	return st.commit()


# The one cottonwood table: a tree per shoulder hull root, {foot, size}; size is the round 1 crown factor, 0.2 to 1.0.
static func cottonwood_trees() -> Array:
	var trees := []
	for hull in shoulder_plan():
		for j in 4:
			trees.append({"foot": hull["roots"][j], "size": 0.6 + 0.4 * sin(j * 2.3 + hull["i"])})
	return trees


# A tree's frame: the recipe GLB origin on the root, scaled by the tree's size.
static func cottonwood_frame(tree: Dictionary) -> Transform3D:
	return Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * float(tree["size"])), tree["foot"])


# The cottonwood placements on the shoulder stacks, unchanged from round 1.
static func cottonwood_transforms() -> Dictionary:
	var trunks: Array[Transform3D] = []
	var leaves: Array[Transform3D] = []
	for tree in cottonwood_trees():
		var foot: Vector3 = tree["foot"]
		var size: float = tree["size"]
		_place(trunks, foot + Vector3(0, 3, 0), Vector3(0.55, 3, 0.55))
		_place(leaves, foot + Vector3(-2, 6, 0), Vector3(5, 4, 4) * size)
		_place(leaves, foot + Vector3(2, 8, 1), Vector3(4, 5, 4) * size)
	return {"trunks": trunks, "leaves": leaves}


# The 16 shoulder stations: side, index, centre, height h, and the four root points.
static func shoulder_plan() -> Array:
	var plan := []
	for side in [-1.0, 1.0]:
		for i in 8:
			var z := -176.0 + i * 56.0
			var h := 74.0 + 15.0 * sin(i * 1.8 + side)
			var x: float = side * (246.0 + 8.0 * sin(i * 2.1))
			var roots := []
			for j in 4:
				roots.append(Vector3(x + side * 15 + j * 3, h * 0.75 + h * 0.18 + 12, z - 15 + j * 7))
			plan.append({"side": side, "i": i, "x": x, "z": z, "h": h, "roots": roots})
	return plan


# The four old shelf placements of one station, for the envelope the hull must stay inside.
static func shelf_placements(hull: Dictionary) -> Array[Transform3D]:
	var shelves: Array[Transform3D] = []
	for shelf in 4:
		var width := 36.0 - shelf * 4.0
		_place(shelves, Vector3(hull["x"] + hull["side"] * shelf * 5, hull["h"] * 0.25 * shelf + 12, hull["z"]), Vector3(width, hull["h"] * 0.20, 32), hull["i"] * 0.27)
	return shelves


# The old shelves' union AABB in world metres.
static func shoulder_envelope(hull: Dictionary) -> AABB:
	var rock := _eroded_rock()
	var box := AABB()
	var first := true
	for placement in shelf_placements(hull):
		var baked := _placed_rock(rock, placement)
		for v in baked.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			if first:
				box = AABB(v, Vector3.ZERO)
				first = false
			else:
				box = box.expand(v)
	return box


# Heights of the four levels at station k: bottom of the old stack, two irregular mid levels,
# and an upper surface at least 0.15 m over the root height, never above the old top.
static func hull_levels_y(hull: Dictionary, k: int) -> Array:
	var h: float = hull["h"]
	var bottom := 12.0 - h * 0.2 + 0.2
	var root_y: float = hull["roots"][0].y
	var top := root_y + 0.15 + 0.4 + 0.4 * sin(k * 2.7 + hull["i"])
	var span := top - bottom
	return [bottom, bottom + span * 0.34 + 1.2 * sin(k * 2.1 + hull["i"]), bottom + span * 0.68 + 1.2 * sin(k * 1.7 + hull["side"]), top]


static func hull_variant(hull: Dictionary) -> int:
	return (int(hull["i"]) + (0 if hull["side"] < 0 else 2)) % 4


# Per-vertex plan lean (metres of plan movement per metre of height): the corner line where face j-1
# and face j meet, so both faces stay planar. Face i runs from station i to i+1.
static func corner_slopes(plan: Array, batter: Array) -> Array:
	var n := plan.size()
	var area := 0.0
	for i in n:
		var a: Vector2 = plan[i]
		var b: Vector2 = plan[(i + 1) % n]
		area += a.x * b.y - b.x * a.y
	var wind := 1.0 if area > 0.0 else -1.0
	var normals := []
	for i in n:
		var e: Vector2 = plan[(i + 1) % n] - plan[i]
		normals.append(Vector2(e.y, -e.x).normalized() * wind)
	var slopes := []
	for j in n:
		var n0: Vector2 = normals[(j - 1 + n) % n]
		var n1: Vector2 = normals[j]
		var r0: float = -batter[(j - 1 + n) % n]
		var r1: float = -batter[j]
		var det := n0.x * n1.y - n0.y * n1.x
		slopes.append(Vector2((r0 * n1.y - n0.y * r1) / det, (n0.x * r1 - n1.x * r0) / det))
	return slopes


static func hull_rings(hull: Dictionary) -> Array[PackedVector3Array]:
	var table: Dictionary = HULL_PLAN[hull_variant(hull)]
	var plan: Array = table["plan"]
	var slopes := corner_slopes(plan, table["batter"])
	var rings: Array[PackedVector3Array] = []
	for level in 4:
		rings.append(PackedVector3Array())
	for k in plan.size():
		var ys := hull_levels_y(hull, k)
		var d: Vector2 = plan[k]
		var m: Vector2 = slopes[k]
		for level in 4:
			var t: float = ys[level] - ys[0]
			rings[level].append(Vector3(hull["x"] + hull["side"] * (d.x + m.x * t), ys[level], hull["z"] + d.y + m.y * t))
	return rings


# One closed hull in world metres: 10 stations, three planar-faced bands, fan caps. No folds.
static func shoulder_mesh(hull: Dictionary) -> ArrayMesh:
	var rings := hull_rings(hull)
	var tris := PackedVector3Array()
	for band in 3:
		_wall(tris, rings[band], rings[band + 1])
	_fan_cap(tris, rings[3], Vector3.UP)
	_fan_cap(tris, rings[0], Vector3.DOWN)
	return _solid(tris)


# Bands between two same-length rings, outward by the ring's winding in plan.
static func _wall(tris: PackedVector3Array, ring_a: PackedVector3Array, ring_b: PackedVector3Array) -> void:
	var n := ring_a.size()
	var area := 0.0
	for i in n:
		var a := ring_a[i]
		var b := ring_a[(i + 1) % n]
		area += a.x * b.z - b.x * a.z
	var wind := 1.0 if area > 0.0 else -1.0
	for i in n:
		var j := (i + 1) % n
		var e := ring_a[j] - ring_a[i]
		var hint := Vector3(e.z, 0.0, -e.x) * wind
		if hint.length() < 0.000001:
			e = ring_b[j] - ring_b[i]
			hint = Vector3(e.z, 0.0, -e.x) * wind
		_oriented_tri(tris, ring_a[i], ring_a[j], ring_b[i], hint)
		_oriented_tri(tris, ring_a[j], ring_b[j], ring_b[i], hint)


static func _oriented_tri(tris: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, hint: Vector3) -> void:
	if (b - a).cross(c - a).dot(hint) < 0.0:
		tris.append_array([a, c, b])
	else:
		tris.append_array([a, b, c])


static func _fan_cap(tris: PackedVector3Array, ring: PackedVector3Array, up: Vector3) -> void:
	var centre := Vector3.ZERO
	for p in ring:
		centre += p / ring.size()
	for i in ring.size():
		_oriented_tri(tris, centre, ring[i], ring[(i + 1) % ring.size()], up)


# Flat-shaded mesh from a triangle soup, indexed.
static func _solid(tris: PackedVector3Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for p in tris:
		st.add_vertex(p)
	st.generate_normals()
	st.index()
	return st.commit()


# The crown records: where each crown stands and how tall it is over the sampled solid crest.
# `crest` is h0, the highest terrain under the final footprint (boundary included), `root` how far
# the base reaches below h0: down to 5 m under the lowest terrain of that footprint.
static func rim_plan(map: RefCounted) -> Array:
	var plan := []
	for side in [-1, 1]:
		var orders: Array = RIM_WEST_ORDER if side < 0 else RIM_EAST_ORDER
		for f in 3:
			var z := RIM_START_Z + f * RIM_FAMILY_PITCH
			for v in orders[f]:
				var width: float = RIM_WIDTH[v]
				var cx: float = RIM_WEST_X if side < 0 else RIM_EAST_X[v]
				var entry := {"side": side, "variant": v, "family": f, "width": width, "depth": RIM_DEPTH[v], "add": RIM_ADD[v],
					"x": cx, "z": z + width * 0.5, "yaw": 0.0 if side < 0 else PI}
				var hi := -INF
				var lo := INF
				for xi in footprint_steps(RIM_DEPTH[v]):
					for zi in footprint_steps(width):
						var h: float = map.sample(cx + xi, entry["z"] + zi)[0]
						hi = maxf(hi, h)
						lo = minf(lo, h)
				entry["crest"] = hi
				entry["root"] = hi - lo + 5.0
				plan.append(entry)
				z += width + RIM_GULLY
	return plan


# Offsets from the centre at 2 m spacing over [-length/2, length/2], boundary points included.
static func footprint_steps(length: float) -> Array:
	var steps := []
	var at := -length * 0.5
	while at < length * 0.5 - 0.001:
		steps.append(at)
		at += 2.0
	steps.append(length * 0.5)
	return steps


static func crown_transform(crown: Dictionary) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, crown["yaw"]), Vector3(crown["x"], crown["crest"], crown["z"]))


static func crest_rise(variant: int, u: float) -> float:
	var keys: Array = RIM_CREST[variant]
	u = clampf(u, 0.0, 1.0)
	for i in keys.size() - 1:
		var a: Vector2 = keys[i]
		var b: Vector2 = keys[i + 1]
		if u <= b.x:
			return lerpf(a.y, b.y, (u - a.x) / (b.x - a.x))
	return keys[keys.size() - 1].y


# Crown-local rings: origin at h0, +x toward the arena, z along the crest (mirrored under the east
# yaw so the plan's z always runs along increasing world Z). Five rings of 12 stations. Ring 0 is
# the buried base; the upper rings lean inward per face by the batter and take the crest rise at
# the station's own final z, so a sloped face keeps its height ceiling.
static func crown_rings(crown: Dictionary) -> Array[PackedVector3Array]:
	var v: int = crown["variant"]
	var table: Dictionary = RIM_PLAN[v]
	var plan: Array = table["plan"]
	var slopes := corner_slopes(plan, table["batter"])
	var zsign := 1.0 if crown["side"] < 0 else -1.0
	var rings: Array[PackedVector3Array] = []
	for k in 5:
		var ring := PackedVector3Array()
		for j in plan.size():
			var p: Vector2 = plan[j]
			var m: Vector2 = slopes[j]
			if k == 0:
				ring.append(Vector3(p.x, -crown["root"], zsign * p.y))
				continue
			var y := 0.0
			for _i in 8:
				y = crest_rise(v, (p.y + m.y * y) / crown["width"] + 0.5) * RIM_RING_Y[k]
			ring.append(Vector3(p.x + m.x * y, y, zsign * (p.y + m.y * y)))
		rings.append(ring)
	return rings


# A closed solid: four bands of 12 quads and zipped caps. No folds.
static func crown_mesh(crown: Dictionary) -> ArrayMesh:
	var rings := crown_rings(crown)
	var tris := PackedVector3Array()
	for k in 4:
		_wall(tris, rings[k], rings[k + 1])
	var zsign := 1.0 if crown["side"] < 0 else -1.0
	_zip_cap(tris, rings[4], zsign, Vector3.UP)
	_zip_cap(tris, rings[0], zsign, Vector3.DOWN)
	return _solid(tris)


# Triangulates a ring as a strip between its six face stations and six back stations, merged by
# world Z (`zsign` undoes the east mirror), so no radial fan shows.
static func _zip_cap(tris: PackedVector3Array, ring: PackedVector3Array, zsign: float, up: Vector3) -> void:
	var faces := ring.size() / 2
	var fi := 0
	var bi := ring.size() - 1
	while fi < faces - 1 or bi > faces:
		var next_f: float = zsign * ring[fi + 1].z if fi < faces - 1 else INF
		var next_b: float = zsign * ring[bi - 1].z if bi > faces else INF
		if next_f <= next_b:
			_oriented_tri(tris, ring[fi], ring[fi + 1], ring[bi], up)
			fi += 1
		else:
			_oriented_tri(tris, ring[fi], ring[bi - 1], ring[bi], up)
			bi -= 1
