extends SceneTree

const Contraptions := preload("res://src/world/contraptions.gd")
const Gorge := preload("res://src/world/map_gorge.gd")
const Palette := preload("res://src/core/palette.gd")
const PaletteMaterials := preload("res://src/presentation/palette_materials.gd")
const Terrain := preload("res://src/world/terrain.gd")
const VARIANTS := [[Palette.SAND, 0.0], [Palette.CHARCOAL, 0.0], [Palette.RUST, 0.0],
	[Palette.COPPER, 0.0], [Palette.AMBER, 0.6], [Palette.AMBER, 0.8], [Palette.AMBER, 1.2]]
var failures := 0
var attributes_ok := true


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL", label])


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var terrain := Terrain.new()
	terrain.build(world)
	terrain.use(2)
	var reference = Contraptions
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--reference="):
			reference = load(arg.trim_prefix("--reference="))
			_check(reference != null, "baseline script loads")
			if reference == null:
				world.free()
				quit(1)
				return
	var a = Contraptions.new()
	var b = reference.new()
	terrain.geometry_root(2).add_child(a)
	terrain.geometry_root(2).add_child(b)
	a.setup(Gorge.new(), terrain.ground_callable(2), 14.0, 26.0)
	b.setup(Gorge.new(), terrain.ground_callable(2), 14.0, 26.0)
	var groups := {}
	_collect(a, groups)
	_check(attributes_ok, "all solid surfaces retain authored attributes")
	# 2026-10-09 swap-wave 12-F barge: the gorge barges wear the recipe, so their amber 0.6 edge bands (the only
	# AMBER 0.6 solid) are gone; six of the seven VARIANTS remain in use.
	_check(groups.size() == 6, "six exact solid color/emission variants")
	var shared := true
	for ids in groups.values():
		shared = shared and ids.size() == 1
	_check(shared, "matching immutable solids share one resource per owner")
	_check(a._gauge_mat != b._gauge_mat and a._needle_mat != b._needle_mat, "owners have independent materials")
	var fresh := PaletteMaterials.solid(Palette.SAND)
	var other := PaletteMaterials.solid(Palette.SAND)
	fresh.albedo_color = Palette.HAZARD
	fresh.emission_enabled = true
	fresh.emission_energy_multiplier = 9.0
	_check(fresh != other and other.albedo_color == Palette.SAND and not other.emission_enabled
		and a._gauge_mat.albedo_color == Palette.SAND, "fresh mutable caller cannot tint sibling or prop material")
	_check(_state(a) == _state(b), "initial meshes, colliders, transforms and material attributes match reference")
	var animation_matches := true
	var far := Vector3(500, 500, 500)
	for tick in 90:
		var ball := a.valves[0]["at"] as Vector3 if tick == 0 else far
		var velocity := Vector3(20, 0, 0)
		animation_matches = animation_matches and a.step(0.05, ball, velocity, null, false) == b.step(0.05, ball, velocity, null, false)
		animation_matches = animation_matches and _poses(a) == _poses(b)
	_check(animation_matches, "4.5 seconds of barge/lift/needle/valve animation and facts match reference")
	_check(a.valves[0]["open"] and a.valves[0]["sink"] == 1.0, "valve opens and door completes its sink")
	a.reset()
	b.reset()
	_check(_state(a) == _state(b) and not a.valves[0]["open"], "reset preserves reference geometry and restores valve collision pose")
	terrain.use(1)
	_check(not a.is_visible_in_tree() and a.global_position.y == -Terrain.PARK_DEPTH, "stage change hides and parks owner")
	terrain.use(2)
	_check(a.is_visible_in_tree(), "stage return restores owner")
	terrain.park_all()
	_check(not a.is_visible_in_tree() and not a.can_process(), "arena parking disables owner")
	world.free()
	print("contraptions_materials_test: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _collect(node: Node, groups: Dictionary) -> void:
	if node is MeshInstance3D:
		var mat: StandardMaterial3D = node.material_override
		if mat != null and mat.albedo_texture == null and mat.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL:
			var energy := mat.emission_energy_multiplier if mat.emission_enabled else 0.0
			var key := -1
			for i in VARIANTS.size():
				if mat.albedo_color == VARIANTS[i][0] and is_equal_approx(energy, VARIANTS[i][1]):
					key = i
			attributes_ok = attributes_ok and key >= 0 and is_equal_approx(mat.roughness, 0.8) and mat.metallic == 0.0
			attributes_ok = attributes_ok and mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED
			if not groups.has(key):
				groups[key] = {}
			groups[key][mat.get_instance_id()] = true
	for child in node.get_children():
		_collect(child, groups)


func _poses(node: Node) -> Array:
	var result: Array = [node.get_class()]
	if node is Node3D:
		result.append(node.transform)
		result.append(node.visible)
	for child in node.get_children():
		result.append(_poses(child))
	return result


func _state(node: Node) -> Array:
	var result: Array = [node.get_class()]
	if node is Node3D:
		result.append(node.transform)
		result.append(node.visible)
	# 2026-10-09 swap-wave 12-F (merge of the barge and valve re-pins): recipe views carry surface overrides
	# and no material_override; hash their slots instead of skipping them. The recipe barge's deck
	# keeps its node but no mesh, so a mesh-less view is skipped.
	if node is MeshInstance3D and node.mesh != null:
		result.append(hash(node.mesh.get_faces()))
		var mat: StandardMaterial3D = node.material_override
		if mat == null:
			result.append(range(node.mesh.get_surface_count()).map(func(i): return node.get_surface_override_material(i)))
		else:
			result.append([mat.albedo_color, mat.roughness, mat.metallic, mat.emission_enabled, mat.emission,
				mat.emission_energy_multiplier, mat.transparency, mat.shading_mode, mat.cull_mode, mat.no_depth_test,
				mat.uv1_triplanar, mat.uv1_scale])
			if mat.albedo_texture != null:
				result.append([mat.albedo_texture.get_width(), mat.albedo_texture.get_height()])
	if node is CollisionShape3D:
		result.append([node.disabled, hash(node.shape.get_debug_mesh().get_faces())])
	if node is CollisionObject3D:
		result.append([node.collision_layer, node.collision_mask])
	for child in node.get_children():
		result.append(_state(child))
	return result
