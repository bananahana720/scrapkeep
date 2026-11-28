extends "res://src/combat/enemy.gd"

const HALF_HEIGHT := 1.3
const RADIUS := 1.7
const SIZE := Vector3(3.2, 2.6, 3.2)
static var _shared: Array = []
static var _asset_warned := false
var _lamp_material: StandardMaterial3D
var _hatches: Array[Node3D] = []
var _hatch_model: MeshInstance3D
var _opened := false


func setup(target_ref, terrain_ref, root_ref, live_ref: Callable, _threat: float, spec_ref := {}) -> void:
	_setup_common(target_ref, terrain_ref, root_ref, live_ref, spec_ref)
	kind = "vault"
	var stage: int = spec.get("stage", 1)
	plating = spec.get("plating", 60.0)
	_set_health(spec.get("hp", 400.0 * stage))
	scrap_value = 10 * stage
	weight = 1000.0
	radius = RADIUS
	half_height = HALF_HEIGHT
	global_position = Vector3(global_position.x, terrain.height(global_position.x, global_position.z) + HALF_HEIGHT, global_position.z)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = SIZE
	shape.shape = box
	add_child(shape)
	_base_color = Palette.COPPER
	_material = PaletteMaterials.solid(_base_color, 0.2)
	_build_visual()


func _build_visual() -> void:
	var parts := _parts()
	if not parts.is_empty():
		_base_color = Color.WHITE
		_material.albedo_color = _base_color
		_material.emission_enabled = false
		_material.vertex_color_use_as_albedo = true
		var band_mat := _plate_material()
		for part in parts:
			var mi := MeshInstance3D.new()
			mi.name = part.name
			mi.mesh = part.mesh
			mi.transform = part.xform
			if part.name == "VaultBody":
				mi.set_surface_override_material(0, _material)
			elif part.name == "VaultPlating":
				mi.material_override = band_mat
			elif part.name == "VaultLamp":
				_lamp_material = PaletteMaterials.solid(Palette.AMBER, 1.4)
				mi.material_override = _lamp_material
			_visual_parent().add_child(mi)
		_add_hatches()
		return
	var body := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = SIZE * 0.9
	body.mesh = mesh
	body.material_override = _material
	_visual_parent().add_child(body)
	var band_mat := _plate_material()
	for y in [-0.6, 0.6]:
		var band := MeshInstance3D.new()
		var ring := BoxMesh.new()
		ring.size = Vector3(SIZE.x, 0.35, SIZE.z)
		band.mesh = ring
		band.material_override = band_mat
		band.position = Vector3.UP * y
		_visual_parent().add_child(band)
	var post := CylinderMesh.new()
	post.top_radius = 0.12
	post.bottom_radius = 0.16
	post.height = 1.8
	_accent(post, Palette.CHARCOAL, 0.0, Vector3.UP * (HALF_HEIGHT + 0.9))
	var lamp := SphereMesh.new()
	lamp.radius = 0.6
	lamp.height = 1.2
	var lamp_view := _accent(lamp, Palette.AMBER, 1.4, Vector3.UP * (HALF_HEIGHT + 2.0))
	_lamp_material = lamp_view.material_override as StandardMaterial3D
	_add_hatches()


func _add_hatches() -> void:
	var torus := TorusMesh.new()
	torus.rings = 8
	torus.ring_segments = 6
	torus.inner_radius = 0.42
	torus.outer_radius = 0.54
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in 4:
		var ring := Node3D.new()
		ring.name = "VaultHatch%d" % side
		match side:
			0:
				ring.position = Vector3(0.0, 0.0, -SIZE.z * 0.46)
				ring.rotation.x = PI * 0.5
			1:
				ring.position = Vector3(0.0, 0.0, SIZE.z * 0.46)
				ring.rotation.x = PI * 0.5
			2:
				ring.position = Vector3(-SIZE.x * 0.46, 0.0, 0.0)
				ring.rotation.z = PI * 0.5
			3:
				ring.position = Vector3(SIZE.x * 0.46, 0.0, 0.0)
				ring.rotation.z = PI * 0.5
		surface.append_from(torus, 0, Transform3D(ring.basis, ring.position))
		_visual_parent().add_child(ring)
		_hatches.append(ring)
	_hatch_model = MeshInstance3D.new()
	_hatch_model.name = "VaultHatches"
	_hatch_model.mesh = surface.commit()
	_hatch_model.material_override = PaletteMaterials.solid(Palette.CHARCOAL)
	_visual_parent().add_child(_hatch_model)


func _die() -> void:
	_opened = true
	if _lamp_material != null:
		_lamp_material.emission_energy_multiplier = 0.0
	for hatch in _hatches:
		hatch.position.y -= 0.55
	if _hatch_model != null:
		_hatch_model.position.y -= 0.55
	super._die()


static func _parts() -> Array:
	if not _shared.is_empty():
		return _shared
	var path := "res://assets/models/world_one/enemy_vault.glb"
	var packed := load(path) as PackedScene if ResourceLoader.exists(path) else null
	if packed == null:
		_asset_warning()
		return []
	var scene := packed.instantiate()
	var parts: Array = []
	var names := []
	var valid := scene != null
	var expected := {"VaultBody": "fleet_paint", "VaultPlating": "part_state", "VaultLamp": "working_tool"}
	if scene != null:
		for node in scene.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			if mi.mesh == null or mi.mesh.get_surface_count() != 1:
				valid = false
				continue
			var source := mi.mesh.surface_get_material(0)
			if source == null or source.resource_name != expected.get(String(mi.name), ""):
				valid = false
				continue
			var mesh: Mesh = mi.mesh.duplicate()
			var mat := PaletteMaterials.solid(Palette.SAND, 0.35) if mi.name == "VaultLamp" else PaletteMaterials.solid(Color.WHITE)
			mat.vertex_color_use_as_albedo = mi.name == "VaultBody"
			mesh.surface_set_material(0, mat)
			var xform := mi.transform
			var ancestor := mi.get_parent()
			while ancestor != scene and ancestor is Node3D:
				xform = ancestor.transform * xform
				ancestor = ancestor.get_parent()
			names.append(String(mi.name))
			parts.append({"name": mi.name, "mesh": mesh, "xform": xform})
		scene.free()
	names.sort()
	if not valid or names != ["VaultBody", "VaultLamp", "VaultPlating"]:
		_asset_warning()
		return []
	_shared = parts
	return _shared


static func _asset_warning() -> void:
	if not _asset_warned:
		_asset_warned = true
		push_warning("vault: missing or malformed model; using cache fallback")


func knock(_direction: Vector3, _force: float) -> void:
	pass


func _physics_process(delta: float) -> void:
	_update_flash(delta)
