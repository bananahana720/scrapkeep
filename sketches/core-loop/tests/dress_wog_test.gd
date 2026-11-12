extends "res://tests/dress_material_test.gd"

const Scenery := preload("res://src/presentation/spillway_scenery.gd")
const Reach := preload("res://src/world/map_reach.gd")
const PHYSICS_BASELINE := "res://tests/fixtures/dress_wog_physics.json"


func _boot() -> void:
	seed(1)
	game = Game.new()
	game.test_mode = true
	game.table = "alpha"
	root.add_child(game)
	for tick in 600:
		if game.flow != null:
			break
		await physics_frame
	_require(game.flow != null, "game initializes")
	if game.flow != null:
		game.process_mode = Node.PROCESS_MODE_DISABLED
		game.ctx.calm = true
		game.flow.press_start()
		game.flow.choose_class(0)


func _run() -> void:
	await _boot()
	var physics := []
	if game.flow != null:
		for stage in [1, 2]:
			game.flow.enter_stage(stage, Vector3.ZERO, false)
			await process_frame
			var stage_root: Node3D = game.ctx.terrain.geometry_root(stage)
			_require(stage_root != null and stage_root.visible, "Stage%d is built and visible" % stage)
			var counts := _counts(stage_root, stage)
			_require(counts.meshes > 0 and counts.greybox == 0 and counts.white == 0,
				"Stage%d has no material offenders: %s" % [stage, counts])
			_snapshot(stage_root, "Stage%d" % stage, physics)
			_signals(stage_root, stage)
			if stage == 2:
				game.world.contraptions[2].reset()
				counts = _counts(stage_root, stage)
				_require(counts.greybox == 0 and counts.white == 0, "reset cache walls stay dressed")
		if OS.get_environment("WOG_RECORD_BASELINE") == "1":
			var file := FileAccess.open(PHYSICS_BASELINE, FileAccess.WRITE)
			file.store_string(JSON.stringify(physics, "\t") + "\n")
		else:
			var expected = JSON.parse_string(FileAccess.get_file_as_string(PHYSICS_BASELINE))
			_require(expected is Array and not expected.is_empty(), "original physics fixture exists")
			_require(JSON.parse_string(JSON.stringify(physics)) == expected, "ordered bodies, shapes, layers and transforms match base 7a7b13b")
		print("wog physics: %d ordered collision nodes match base 7a7b13b" % physics.size())
	_require(error_log.errors == 0, "no engine or script errors")
	game.free()
	OS.remove_logger(error_log)
	print("dress_wog_test: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func _counts(stage_root: Node3D, stage: int) -> Dictionary:
	var counts := {"white": 0, "greybox": 0, "striped": 0, "solid_box": 0, "meshes": 0, "surfaces": 0}
	_walk(stage_root, "wog/%d" % stage, counts)
	print("wog Stage%d: white=%d greybox=%d meshes=%d surfaces=%d" % [stage, counts.white, counts.greybox, counts.meshes, counts.surfaces])
	return counts


func _finish(view: MeshInstance3D, role: String, color: Color, second: Color, emission := 0.0) -> void:
	var mat := view.material_override as ShaderMaterial
	_require(mat != null, "%s has a dressed material" % role)
	if mat == null:
		return
	_require(mat.get_shader_parameter("base_color") == color, "%s keeps authored colour %s" % [role, color.to_html()])
	if mat.shader.resource_path == Scenery.prop_shader_path:
		_require(mat.get_shader_parameter("secondary_color") == second, role + " keeps its second colour")
		_require(is_equal_approx(float(mat.get_shader_parameter("emission_energy")), emission), role + " keeps its emission")
		_require(mat.shader.get_shader_uniform_list().size() == 5, "Godot parses signal finish uniforms")


func _signals(stage_root: Node3D, stage: int) -> void:
	var pylons := 0
	var ancient := 0
	var caps := 0
	var pads := 0
	var shafts := 0
	for view: MeshInstance3D in stage_root.find_children("*", "MeshInstance3D", true, false):
		if view.mesh is BoxMesh and is_equal_approx(view.mesh.size.z, 1.6) and view.get_parent() is StaticBody3D:
			_finish(view, "pylon-biteable face", Palette.VERDIGRIS, Palette.CHARCOAL)
			pylons += 1
		if stage != 2:
			continue
		if view.mesh is BoxMesh and view.mesh.size == Vector3(18, 1, 10):
			_require(view.material_override is StandardMaterial3D and (view.material_override as StandardMaterial3D).albedo_color == Palette.VERDIGRIS,
				"spawn pad is plain verdigris deck")
			pads += 1
		if view.mesh is BoxMesh and view.mesh.size == Vector3(0.18, 0.06, 8.0):
			_require(view.material_override is StandardMaterial3D and (view.material_override as StandardMaterial3D).albedo_color == Reach.ANCIENT,
				"spawn deck carries the world's ancient-blue seam")
		if view.mesh is BoxMesh and is_equal_approx(view.mesh.size.x, 0.35) or view.mesh is SphereMesh and is_equal_approx(view.mesh.radius, 3.2):
			_finish(view, "ancient seam or landmark beacon", Palette.ANCIENT, Palette.CHARCOAL, 2.4)
			ancient += 1
		if view.mesh is SphereMesh and is_equal_approx(view.mesh.radius, 1.4):
			_finish(view, "grapple cap", Palette.AMBER, Palette.CHARCOAL, 1.2)
			caps += 1
		if view.mesh is CylinderMesh and is_equal_approx(view.mesh.top_radius, 0.9) and view.get_parent() is StaticBody3D:
			_finish(view, "grapple mast", Palette.COPPER, Palette.CHARCOAL)
			shafts += 1
	_require(pylons == (4 if stage == 1 else 2), "all pylon faces checked")
	print("wog signal Stage%d: %d pylon faces verdigris #365754" % [stage, pylons])
	if stage == 1:
		return
	_require(ancient == 13 and caps == Reach.POSTS.size() and shafts == caps and pads == 1, "all ancient lenses, copper masts, grapple caps and spawn pad checked")
	var lamps := stage_root.find_children("*", "OmniLight3D", true, false)
	_require(lamps.size() == 1 and lamps[0].light_color == Palette.ANCIENT and is_equal_approx(lamps[0].light_energy, 3.0), "landmark's blue light retains its hue and energy")
	var devices = game.world.contraptions[2]
	var grates := 0
	var safety := 0
	var dark_cracks := 0
	var plumes := 0
	var hooks := 0
	var cable_spans := 0
	var wheels := 0
	for view: MeshInstance3D in devices.find_children("*", "MeshInstance3D", true, false):
		var role: String = view.get_meta("spillway_finish", "")
		if role == "grate":
			_finish(view, "thermal grate", Palette.COPPER, Palette.CHARCOAL)
			grates += 1
		elif role == "safety":
			_finish(view, "valve stem", Palette.AMBER, Palette.CHARCOAL)
			safety += 1
		elif role == "recess" and view.mesh is BoxMesh:
			_finish(view, "wall crack or valve spoke", Palette.CHARCOAL, Palette.CHARCOAL)
			dark_cracks += 1
		if view.mesh is CylinderMesh and is_equal_approx(view.mesh.height, 40.0):
			_require(view.material_override.albedo_color == Color(Palette.SAND, 0.12), "thermal plume remains translucent bone, harmless")
			_require(view.material_override.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "thermal plume stays transparent")
			plumes += 1
		if view.mesh is TorusMesh and role == "lens":
			_finish(view, "cable hook", Palette.AMBER, Palette.CHARCOAL, 1.2)
			hooks += 1
		if view.mesh is CylinderMesh and is_equal_approx(view.mesh.top_radius, 0.18):
			_finish(view, "cable span", Palette.CHARCOAL, Palette.CHARCOAL)
			cable_spans += 1
		if view.mesh is TorusMesh and is_equal_approx(view.mesh.outer_radius, 1.9):
			_finish(view, "valve wheel", Palette.RUST, Palette.CHARCOAL)
			wheels += 1
		var mat := view.material_override as ShaderMaterial
		if mat != null:
			_require(mat.get_shader_parameter("base_color") != Palette.HAZARD, "harmless Reach devices do not acquire hostile red")
	var door: StaticBody3D = devices.valves[0].door
	# W1-23: the cache door is the valve door model, whose own ribs the greybox finish leaves alone.
	var door_view := door.get_child(1) as MeshInstance3D
	_require(door_view.name == "ValveDoor" and not door_view.mesh is PrimitiveMesh and not door_view.has_meta("spillway_finish"),
		"cache door is the riveted valve door model, left to its own finish")
	var wall: StaticBody3D = devices.walls[0].body
	_finish(wall.get_child(1), "breakable wall", Palette.SANDSTONE, Palette.VERDIGRIS)
	print("wog device counts: grates=%d safety=%d cracks=%d plumes=%d" % [grates, safety, dark_cracks, plumes])
	# 2026-10-09 swap-wave 12-F: the valve's torus wheel, amber stem and charcoal spoke are the authored recipe views
	# now (contraptions.gd _build_valve), which the greybox finish skips: wheels 1 -> 0, safety 1 -> 0, cracks 4 -> 3.
	_require(grates == 2 and safety == 0 and dark_cracks == 3 and plumes == 2 and hooks == 1 and cable_spans == 1 and wheels == 0, "all Reach contraption signals checked")
	var valve_views: Array = (devices.valves[0]["wheel"] as Node3D).find_children("valve_wheel_*", "MeshInstance3D", false, false)
	_require(valve_views.size() == 2 and valve_views.all(func(v): return v.material_override == null and not v.has_meta("spillway_finish")),
		"the valve wheel is the recipe's two base views, left to their slot materials")
	print("wog signal Stage2: spawn/valve amber #e5a044 + charcoal; 14 grapple caps and cable hook amber emit=1.2; 13 ancient lenses blue #3d8bff emit=2.4")
	print("wog signal contraptions: 2 copper/charcoal grates; copper shutter; sandstone/verdigris wall; 3 charcoal cracks; 2 bone plumes alpha=0.12; no hostile red")


func _snapshot(node: Node, at: String, rows: Array) -> void:
	if node is CollisionObject3D or node is CollisionShape3D:
		var row := {"path": at, "type": node.get_class(), "transform": var_to_str(node.transform)}
		if node is CollisionObject3D:
			row["layer"] = node.collision_layer
			row["mask"] = node.collision_mask
		if node is CollisionShape3D:
			row["disabled"] = node.disabled
			row["shape"] = node.shape.get_class()
			row["vertices"] = str(hash(node.shape.get_debug_mesh().get_faces()))
		rows.append(row)
	for k in node.get_child_count():
		_snapshot(node.get_child(k), at + "/" + str(k), rows)
