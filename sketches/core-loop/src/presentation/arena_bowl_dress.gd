extends RefCounted

const Palette := preload("res://src/core/palette.gd")
const Arena := preload("res://src/boss/arena.gd")
const RecipeProps := preload("res://src/presentation/recipe_props.gd")
const ASSET_DIR := "res://assets/models/bosses"
const SPILLWAY_DIR := "res://assets/models/world_one"
const FOUNDRY_PARTS := ["RimRepairs", "CraneRails", "PourSpouts", "CooledSlagPools", "CastFloorSeams", "MastCollars", "BankCopperCourses"]
const SPILLWAY_PARTS := ["rock_a", "rock_c", "slab_a", "slab_b"]
const SLOTS := {
	"foundry_steel": Vector2(0.87, 0.18), "foundry_copper": Vector2(0.76, 0.28),
	"cooled_slag": Vector2(0.97, 0.04), "paint": Vector2(0.95, 0.0),
	"bare_metal": Vector2(0.8, 0.15), "rubber": Vector2(0.98, 0.0),
}

# Tests can redirect either folder. Nothing is loaded or built until the bowl enters.
static var asset_dir := ASSET_DIR
static var spillway_dir := SPILLWAY_DIR


# Each kit's parts read ahead by warm(), by file path until build takes them.
static var _ahead := {}


# Reads one kit's parts a call, on the main thread, while the world's last stage runs (boss.gd's
# warm_arena); true once both are read. Reading them took 10 ms of the boss-entry frame.
static func warm() -> bool:
	for kit in _kits():
		if not _ahead.has(kit[0]):
			_ahead[kit[0]] = new()._parts(kit[0], kit[1])
			return false
	return true


static func _kits() -> Array:
	return [[asset_dir.path_join("arena_bowl_foundry.glb"), FOUNDRY_PARTS], [spillway_dir.path_join("clutter_kit.glb"), SPILLWAY_PARTS]]


static func build(arena: Node3D) -> Node3D:
	var builder := new()
	var kits := _kits()
	var foundry: Dictionary = _ahead[kits[0][0]] if _ahead.has(kits[0][0]) else builder._parts(kits[0][0], kits[0][1])
	var stone: Dictionary = _ahead[kits[1][0]] if _ahead.has(kits[1][0]) else builder._parts(kits[1][0], kits[1][1])
	_ahead.clear()
	if foundry.is_empty() or stone.is_empty():
		push_warning("arena_bowl_dress: missing or malformed foundry/Spillway kit; Slag Bowl keeps its greybox")
		return null
	var dressing := Node3D.new()
	dressing.name = "ArenaBowlDress"
	for part in FOUNDRY_PARTS:
		builder._view(dressing, part, foundry[part].mesh, foundry[part].local)
	var rubble := Node3D.new()
	rubble.name = "SpillwayRimStone"
	dressing.add_child(rubble)
	for i in 16:
		var angle := float(i) * TAU / 16.0 + 0.09 * sin(float(i) * 2.7)
		var size := 4.5 + 1.5 * sin(float(i) * 1.9)
		var at := Vector3(cos(angle), 0, sin(angle)) * (65.0 + 2.0 * sin(float(i) * 1.3))
		at.y = 9.0 + 0.4 * sin(float(i))
		var part: String = SPILLWAY_PARTS[i % SPILLWAY_PARTS.size()]
		var placement := Transform3D(Basis(Vector3.UP, angle).scaled(Vector3(size, size * 0.7, size)), at)
		builder._view(rubble, "RimStone_%d" % i, stone[part].mesh, placement * stone[part].local)
	arena.add_child(dressing)
	builder._surfaces(arena)
	return dressing


func _parts(path: String, required: Array) -> Dictionary:
	if not ResourceLoader.exists(path):
		return {}
	var packed := load(path) as PackedScene
	if packed == null:
		return {}
	var scene := packed.instantiate()
	var result := {}
	if not scene.find_children("*", "CollisionObject3D", true, false).is_empty():
		scene.free()
		return {}
	for view: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if String(view.name) not in required:
			continue
		if view.mesh == null or view.mesh.get_surface_count() == 0:
			continue
		var mesh := view.mesh.duplicate() as ArrayMesh
		if mesh == null:
			continue
		var valid := true
		for surface in mesh.get_surface_count():
			var source := view.mesh.surface_get_material(surface)
			if source == null or not SLOTS.has(String(source.resource_name)):
				valid = false
				break
			var arrays := mesh.surface_get_arrays(surface)
			if arrays[Mesh.ARRAY_COLOR] == null or arrays[Mesh.ARRAY_COLOR].size() != arrays[Mesh.ARRAY_VERTEX].size():
				valid = false
				break
			mesh.surface_set_material(surface, _slot_material(String(source.resource_name)))
		if valid:
			result[String(view.name)] = {"mesh": mesh, "local": _relative(view, scene)}
	scene.free()
	return result if result.size() == required.size() else {}


static func _relative(node: Node3D, top: Node) -> Transform3D:
	var transform := Transform3D.IDENTITY
	var walk: Node = node
	while walk != null and walk != top:
		if walk is Node3D:
			transform = walk.transform * transform
		walk = walk.get_parent()
	return transform


func _slot_material(slot: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = slot
	material.vertex_color_use_as_albedo = true
	material.roughness = SLOTS[slot].x
	material.metallic = SLOTS[slot].y
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if slot in ["foundry_steel", "foundry_copper"]:
		material.albedo_texture = Palette.look_texture("rusted-salvaged-plate-worn", true)
		material.uv1_triplanar = true
		material.uv1_scale = Vector3.ONE / 4.0
	return material


func _view(parent: Node3D, label: String, mesh: Mesh, transform: Transform3D) -> void:
	var view := MeshInstance3D.new()
	view.name = label
	view.mesh = mesh
	view.transform = transform
	parent.add_child(view)


func _surfaces(arena: Node3D) -> void:
	var floor_mat := _slot_material("foundry_steel")
	floor_mat.resource_name = "bowl_cast_floor"
	floor_mat.albedo_color = Color("56594f")
	floor_mat.albedo_texture = Palette.look_texture("riveted-gyro-metal", true)
	floor_mat.roughness = 0.93
	floor_mat.uv1_scale = Vector3.ONE / 9.0
	var bank_mat := Palette.ground_material().duplicate() as ShaderMaterial
	bank_mat.resource_name = "bowl_sandstone_bank"
	bank_mat.set_shader_parameter("cliff_only", true)
	bank_mat.set_shader_parameter("local_pattern", true)
	var wall_mat := _slot_material("foundry_steel")
	wall_mat.resource_name = "bowl_rusted_rim"
	wall_mat.albedo_color = Color("84604b")
	var ramp_mat := _slot_material("foundry_copper")
	ramp_mat.resource_name = "bowl_cast_ramps"
	ramp_mat.albedo_color = Palette.COPPER
	var mast_mat := _slot_material("foundry_copper")
	mast_mat.resource_name = "bowl_crane_masts"
	mast_mat.albedo_color = Palette.COPPER
	# Only arena-owned views carry this metadata. Combat/hazards and vent pads stay live.
	for view: MeshInstance3D in arena.get_children().filter(func(n): return n is MeshInstance3D):
		match view.get_meta("bowl_surface", ""):
			"Floor": view.material_override = floor_mat
			"Bank": view.material_override = bank_mat
			"RimWall": view.material_override = wall_mat
			"Ramp": view.material_override = ramp_mat
			"Kicker":
				view.material_override = ramp_mat
				_kicker(arena, view)
			"Mast", "Crossbar": view.material_override = mast_mat


# The authored kicker replaces the greybox view where the collider stands: one holder per kicker at the wedge's own
# frame (arena.gd _wedge), its base views and detail shells at the holder's origin, so the recipe's riding face lies on
# the collider plane. The greybox view stays in the tree, hidden, and the collider is untouched.
func _kicker(arena: Node3D, view: MeshInstance3D) -> void:
	var holder := Node3D.new()
	holder.name = "KickerWedge"
	holder.transform = view.transform * (view.get_meta(Arena.WEDGE_FRAME) as Transform3D)
	arena.add_child(holder, true)
	RecipeProps.base("kicker_wedge", holder, Transform3D.IDENTITY)
	RecipeProps.shells("kicker_wedge", holder, Transform3D.IDENTITY)
	view.visible = false
