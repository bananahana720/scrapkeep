extends SceneTree

const Game := preload("res://src/game.gd")
const Harness := preload("res://tests/doubles/module_harness.gd")
const Dress := preload("res://src/presentation/arena_waking_dress.gd")
const GraphicsPreset := preload("res://src/presentation/graphics_preset.gd")
const ChaseCamera := preload("res://src/movement/chase_camera.gd")
const T := preload("res://tests/support/t.gd")
const MISSING := "res://assets/models/__missing_waking_arena__/"

var _t := T.new("arena_waking_dress_test")
var _game


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	await physics_frame
	_game.ctx.calm = true
	Harness.boot(_game)
	var mod = Harness.module(_game, 2)
	_t.check("arena dressing is absent before entry", mod._arena_dress == null)
	# Same real arena without dressing supplies the collider and material baseline.
	Dress.stone_dir = MISSING
	Harness.enter_world(_game, 2)
	mod = Harness.module(_game, 2)
	var bare := _colliders(mod)
	_fallback(mod)
	mod.exit_arena()
	Dress.stone_dir = Dress.STONE_DIR
	Dress.mech_dir = MISSING
	Harness.enter_world(_game, 2)
	mod = Harness.module(_game, 2)
	_fallback(mod)
	mod.exit_arena()
	Dress.mech_dir = Dress.MECH_DIR
	await process_frame
	var env: Environment = _game.ctx.terrain.environment
	var before := _environment(env)
	var daylight := _daylight()
	Harness.enter_world(_game, 2)
	mod = Harness.module(_game, 2)
	_t.eq("gameplay collider count, shapes and transforms match greybox", _colliders(mod), bare)
	var dress = mod._arena_dress
	if _t.check("dressing builds on the real Waking entry", dress != null):
		_t.check("shaft and descending machinery exist", dress.get_node_or_null("ShaftCutFaces") != null and dress.get_node_or_null("DescendingWorks") != null)
		_t.eq("dressing adds no physics bodies", dress.find_children("*", "CollisionObject3D", true, false).size(), 0)
		_t.eq("dressing adds no collision shapes", dress.find_children("*", "CollisionShape3D", true, false).size(), 0)
		_surfaces(dress)
		_t.check("daylight and sky are absent in the pit", env.background_mode == Environment.BG_COLOR and env.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR and _all_daylight_off())
		_t.check("boss and lamps light the pit", dress.get_node_or_null("ReactorBounce") != null and dress.find_children("LampPool*", "OmniLight3D", true, false).size() == 32)
		# The headless server returns identity for instance reads. Check the setter inputs
		# together with the live scene transforms; rendered placement needs the GPU capture.
		var walls: Node3D = dress.get_node("ShaftCutFaces")
		for view in walls.get_children():
			for placement: Transform3D in view.get_meta("placements", []):
				var xf: Transform3D = Transform3D(Basis.IDENTITY, -mod._center) * view.global_transform * placement
				var local_bounds: AABB = view.multimesh.mesh.get_aabb()
				var radial := Vector2(xf.origin.x, xf.origin.z).normalized()
				var outside := true
				for corner in 8:
					var at: Vector3 = xf * local_bounds.get_endpoint(corner)
					outside = outside and Vector2(at.x, at.z).dot(radial) > mod.PAD_RADIUS
				_t.check("cut face stays outside the gameplay radius", outside)
		var camera_radius: float = mod.PAD_RADIUS + ChaseCamera.PROFILES["boss"]["arm"] + 2.0
		for view: MultiMeshInstance3D in dress.find_children("*", "MultiMeshInstance3D", true, false):
			for placement: Transform3D in view.get_meta("placements", []):
				var xf: Transform3D = Transform3D(Basis.IDENTITY, -mod._center) * view.global_transform * placement
				var bounds: AABB = view.multimesh.mesh.get_aabb()
				var radial := Vector2(xf.origin.x, xf.origin.z).normalized()
				var clear := true
				var nearest := INF
				for corner in 8:
					var at: Vector3 = xf * bounds.get_endpoint(corner)
					nearest = minf(nearest, Vector2(at.x, at.z).dot(radial))
					clear = clear and nearest > camera_radius
				_t.check("shaft dressing clears the boss camera arm and 2 m margin", clear, "%s at %.2f m, need > %.2f m" % [view.name, nearest, camera_radius])
	for body in _bodies(mod):
		var skin: Node = body.get_node_or_null("PitDressing" if body == mod.pad else "FloorDressing")
		_t.check("floor has its own release rim", skin != null)
		if skin != null:
			_surfaces(skin)
			_t.eq("floor dressing has no collider", skin.find_children("*", "CollisionShape3D", true, false).size(), 0)
			for view: MultiMeshInstance3D in skin.get_children():
				_t.eq("floor has 24 separate curved rim keys", view.multimesh.instance_count, 24)
				var faces := view.multimesh.mesh.get_faces()
				_t.check("rim sector fits the prop triangle budget", faces.size() / 3 <= 270)
				var fits := true
				for at: Vector3 in faces:
					fits = fits and Vector2(at.x, at.z).length() <= mod.PAD_RADIUS + 0.001 and at.y <= 0.001
				_t.check("curved rim fits the existing floor surface", fits)
		for child in body.get_children():
			if child is MeshInstance3D:
				_t.check("greybox floor is textured stone", child.material_override is ShaderMaterial and _material_valid(child.material_override))
	if dress != null:
		var top: StaticBody3D = mod._floor_bodies[1]
		var top_skin := top.get_node_or_null("FloorDressing")
		mod._dropping = 1
		mod._drop_left = 0.0
		await physics_frame
		await process_frame
		_t.check("forced floor drop frees its dressing", not is_instance_valid(top) and not is_instance_valid(top_skin) and not mod._floor_bodies.has(1))
		_t.check("lower floors and shaft survive the drop", is_instance_valid(mod._floor_bodies[2]) and mod._floor_bodies[2].has_node("FloorDressing") and is_instance_valid(dress))
		await physics_frame
		_t.near("reactor light follows the actual core after a drop", dress._reactor_light.global_position.distance_to(mod.warden.family_point_at()), 0.0, 0.001)
	mod.exit_arena()
	_t.eq("exit restores environment immediately", _environment(env), before)
	_t.eq("exit restores daylight immediately", _daylight(), daylight)
	await process_frame
	_t.check("exit removes all arena dressing", mod.get_node_or_null("ArenaWakingDress") == null and mod._arena_dress == null)
	# A preset change inside the arena must not restore stale lighting on exit.
	var old_preset := GraphicsPreset.current
	GraphicsPreset.apply("low")
	var low := _environment(env)
	GraphicsPreset.apply("high")
	Harness.enter_world(_game, 2)
	mod = Harness.module(_game, 2)
	GraphicsPreset.apply("low")
	_t.check("preset changes keep pit lighting", is_equal_approx(env.ambient_light_energy, 0.16) and _all_daylight_off())
	mod.exit_arena()
	_t.eq("exit restores the preset selected during the fight", _environment(env), low)
	GraphicsPreset.apply(old_preset)
	_game.free()
	quit(_t.verdict())


func _fallback(mod) -> void:
	_t.check("missing asset folder leaves the complete greybox", mod._arena_dress == null and mod.get_node_or_null("ArenaWakingDress") == null)
	for body in _bodies(mod):
		_t.check("fallback attaches no floor dressing", not body.has_node("FloorDressing") and not body.has_node("PitDressing"))
		for child in body.get_children():
			if child is MeshInstance3D:
				_t.check("fallback floor remains visible and unchanged", child.visible and child.material_override == null)


func _bodies(mod) -> Array:
	return [mod.pad] + mod._floor_bodies.values()


func _colliders(mod) -> Array:
	var result := []
	for body in _bodies(mod) + [mod.warden]:
		var shapes := []
		for collider: CollisionShape3D in body.find_children("*", "CollisionShape3D", true, false):
			var shape := {"type": collider.shape.get_class(), "transform": collider.transform, "disabled": collider.disabled}
			if collider.shape is CylinderShape3D or collider.shape is CapsuleShape3D:
				shape["radius"] = collider.shape.radius
				shape["height"] = collider.shape.height
			elif collider.shape is SphereShape3D:
				shape["radius"] = collider.shape.radius
			shapes.append(shape)
		result.append({"name": "Warden" if body == mod.warden else String(body.name), "transform": body.global_transform, "layer": body.collision_layer, "mask": body.collision_mask, "shapes": shapes})
	return result


func _surfaces(top: Node) -> void:
	var views := top.find_children("*", "MultiMeshInstance3D", true, false)
	_t.check("dressing contains reused kit meshes", not views.is_empty())
	for view: MultiMeshInstance3D in views:
		for surface in view.multimesh.mesh.get_surface_count():
			_t.check("dressing surface uses vertex colour or an explicit texture", _material_valid(view.multimesh.mesh.surface_get_material(surface)))


func _material_valid(material: Material) -> bool:
	if material is BaseMaterial3D:
		return material.vertex_color_use_as_albedo or material.albedo_texture != null
	if material is ShaderMaterial:
		return material.get_shader_parameter("tex_tone") is Texture2D and material.get_shader_parameter("tex_grain") is Texture2D
	return false


func _environment(env: Environment) -> Dictionary:
	var result := {}
	for property in Dress.ENV_PROPERTIES:
		result[property] = env.get(property)
	return result


func _daylight() -> Array:
	var result := []
	for light in _game.find_children("*", "DirectionalLight3D", true, false):
		result.append(light.visible)
	return result


func _all_daylight_off() -> bool:
	for shown in _daylight():
		if shown:
			return false
	return true
