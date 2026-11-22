extends Node3D

const DigScenery := preload("res://src/presentation/dig_scenery.gd")
const Palette := preload("res://src/core/palette.gd")
const GraphicsPreset := preload("res://src/presentation/graphics_preset.gd")
const WorldLook := preload("res://src/presentation/world_look.gd")
const STONE_DIR := "res://assets/models/dig_stone/"
const MECH_DIR := "res://assets/models/dig_mechanical/"
static var stone_dir := STONE_DIR
static var mech_dir := MECH_DIR


static func reset_for_tests() -> void:
	stone_dir = STONE_DIR
	mech_dir = MECH_DIR
const STONE_FILES := ["cut_face_long.glb", "cut_face_scoop.glb"]
const MECH_FILES := ["lamp_curve_module.glb", "strut_tall.glb", "strut_bent.glb", "shell_crescent.glb", "shell_saddle.glb"]
const ENV_PROPERTIES := ["background_mode", "background_color", "ambient_light_source", "ambient_light_color", "ambient_light_energy", "reflected_light_source", "fog_enabled", "fog_density", "fog_light_color", "fog_light_energy", "fog_sun_scatter"]
const WARNING := "arena_waking_dress: assets missing or malformed; keeping greybox"
# The boss camera has a 12 m arm beyond the 36 m floor; rock and machines leave it room.
const WALL_RADIUS := 60.0
const WALL_SECTORS := 16
# One row per pit light (VX3): every builder and the readability test read these numbers.
# Light comes from lamps, the reactor and the key; the floor itself never glows.
# core_key_low is the low preset's trim: the key keeps its shadow on a tighter cone.
const LIGHTS := {
	"rim_pool": {"energy": 1.0, "range": 34.0, "radius": 28.0, "height": 6.0},
	"lamp_pool": {"energy": 1.2, "range": 24.0},
	"reactor": {"energy": 3.0, "range": 48.0},
	"core_key": {"energy": 2.8, "range": 55.0, "angle": 55.0},
	"core_key_low": {"angle": 30.0},
}
# The pit floor's plates: half the old 8 m pitch, so the top floor reads as tiled plate.
const FLOOR_PLATE_PITCH := 4.0
const FLOOR_SEAM_WIDTH := 0.12
# Pale zinc: a cool plate that is no state colour (not slate's "not yet") and lighter than the old sandstone,
# so the copper ball reads dark against it under the 0.16 ambient and the amber pools stay an accent.
const FLOOR_PLATE_COLOR := Color("c8cdcf")

var module
var _parts := {}
var _materials := {}
var _reactor_light: OmniLight3D
var _core_key: SpotLight3D
var _light_pool: Node3D
var _dress_lights := []
var _floor_pools := []
var _light_values := {}


static func attach(owner_module):
	var dress = new()
	if not dress._prepare():
		dress.free()
		push_warning(WARNING)
		return null
	dress.name = "ArenaWakingDress"
	dress.module = owner_module
	owner_module.add_child(dress)
	dress.global_position = owner_module._center
	dress._build()
	GraphicsPreset.register_dressing_host(dress)
	return dress


# The key casts on every preset; low narrows its cone so its one shadow map stays small.
func _sync_dressing() -> void:
	_core_key.shadow_enabled = true
	_core_key.spot_angle = LIGHTS.core_key_low.angle if GraphicsPreset.current == "low" else LIGHTS.core_key.angle


# Preflight is atomic: no floor, environment or scene change before every slot is valid.
func _prepare() -> bool:
	var stone := load(DigScenery.SLOTS["stone"]) as ShaderMaterial
	if stone == null or stone.shader == null or stone.get_shader_parameter("tex_tone") == null or stone.get_shader_parameter("tex_grain") == null:
		return false
	stone = stone.duplicate() as ShaderMaterial
	stone.set_shader_parameter("flat_color", Vector3(0.56, 0.50, 0.40))
	stone.set_shader_parameter("bed_tan", Vector3(0.63, 0.52, 0.38))
	stone.set_shader_parameter("bed_orange", Vector3(0.50, 0.40, 0.30))
	stone.set_shader_parameter("bed_cream", Vector3(0.72, 0.64, 0.51))
	stone.set_shader_parameter("bed_rust", Vector3(0.42, 0.33, 0.28))
	_materials["stone"] = stone
	var floor_material := ShaderMaterial.new()
	floor_material.shader = preload("res://src/presentation/arena_waking_floor.gdshader")
	floor_material.set_shader_parameter("tex_tone", stone.get_shader_parameter("tex_tone"))
	floor_material.set_shader_parameter("tex_grain", stone.get_shader_parameter("tex_grain"))
	floor_material.set_shader_parameter("base_color", FLOOR_PLATE_COLOR)
	floor_material.set_shader_parameter("seam_color", Palette.CHARCOAL)
	floor_material.set_shader_parameter("panel_pitch", FLOOR_PLATE_PITCH)
	floor_material.set_shader_parameter("seam_width", FLOOR_SEAM_WIDTH)
	_materials["floor"] = floor_material
	for slot in ["steel", "enamel", "glass"]:
		var material := StandardMaterial3D.new()
		material.resource_name = slot
		material.vertex_color_use_as_albedo = true
		material.roughness = 0.82 if slot == "steel" else 0.87
		material.metallic = 0.22 if slot == "steel" else 0.0
		if slot == "glass":
			material.roughness = 0.38
			material.emission_enabled = true
			material.emission = DigScenery.LAMP_LIGHT
			material.emission_energy_multiplier = 0.25
		_materials[slot] = material
	for file in STONE_FILES:
		if not _load_parts(stone_dir + file):
			return false
	for file in MECH_FILES:
		if not _load_parts(mech_dir + file):
			return false
	return true


func _load_parts(path: String) -> bool:
	if not ResourceLoader.exists(path):
		return false
	var packed := load(path) as PackedScene
	if packed == null:
		return false
	var scene := packed.instantiate()
	if scene == null:
		return false
	var parts := []
	var valid := true
	for view: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if view.mesh == null or view.mesh.get_surface_count() == 0:
			valid = false
			break
		var mesh := view.mesh.duplicate() as Mesh
		for surface in mesh.get_surface_count():
			var source := mesh.surface_get_material(surface)
			if source == null or not _materials.has(String(source.resource_name)):
				valid = false
				break
			mesh.surface_set_material(surface, _materials[String(source.resource_name)])
		parts.append({"mesh": mesh, "local": DigScenery._relative(view, scene)})
	scene.free()
	if not valid or parts.is_empty():
		return false
	_parts[path.get_file()] = parts
	return true


func _build() -> void:
	_light_pool = module.ctx.root.get_node_or_null("WakingLightPool") as Node3D
	if _light_pool == null:
		_light_pool = Node3D.new()
		_light_pool.name = "WakingLightPool"
		module.ctx.root.add_child(_light_pool)
	_floor(module.pad, "PitDressing")
	for k in module._floor_bodies:
		_floor(module._floor_bodies[k], "FloorDressing")
	var walls := Node3D.new()
	walls.name = "ShaftCutFaces"
	add_child(walls)
	var wall_batches := {}
	for band in 4:
		for i in WALL_SECTORS:
			var angle := i * TAU / WALL_SECTORS
			var scoop := (i + band) % 3 == 0
			var file := "cut_face_scoop.glb" if scoop else "cut_face_long.glb"
			var scale_ := Vector3(4.0 if scoop else 3.0, 3.5, 2.0)
			var radius := WALL_RADIUS + 0.6 * sin(float(i * 3 + band))
			var at := Vector3(sin(angle) * radius, -22.0 + band * 14.0, cos(angle) * radius)
			_put(wall_batches, file, Transform3D(Basis(Vector3.UP, angle).scaled(scale_), at))
	_flush(walls, wall_batches)
	_works()
	_reactor_light = _light_pool.get_node_or_null("ReactorBounce") as OmniLight3D
	if _reactor_light == null:
		_reactor_light = OmniLight3D.new()
		_reactor_light.name = "ReactorBounce"
		_light_pool.add_child(_reactor_light)
	_reactor_light.reparent(self, false)
	_reactor_light.light_color = Color("91b4ce")
	_reactor_light.light_energy = LIGHTS.reactor.energy
	_reactor_light.omni_range = LIGHTS.reactor.range
	_reactor_light.shadow_enabled = false
	_core_key = _light_pool.get_node_or_null("CoreKey") as SpotLight3D
	if _core_key == null:
		_core_key = SpotLight3D.new()
		_core_key.name = "CoreKey"
		_light_pool.add_child(_core_key)
	_core_key.reparent(self, false)
	_core_key.light_color = WorldLook.ARENAS.waking.key
	_core_key.light_energy = LIGHTS.core_key.energy
	_core_key.spot_range = LIGHTS.core_key.range
	_core_key.spot_angle = LIGHTS.core_key.angle
	_core_key.shadow_enabled = true
	_follow_reactor()
	var lights := []
	for light in find_children("*", "Light3D", true, false):
		_dress_lights.append(light)
		lights.append(_lighting_entry(light))
	for body in [module.pad] + module._floor_bodies.values():
		for light in body.find_children("RimPool*", "OmniLight3D", true, false):
			lights.append(_lighting_entry(light))
	for light in module.ctx.root.find_children("*", "DirectionalLight3D", true, false):
		lights.append({"object": light, "values": {"visible": false}})
	var look: Dictionary = WorldLook.ARENAS.waking
	GraphicsPreset.set_lighting(self, module.ctx.terrain.environment,
		WorldLook.environment(look, GraphicsPreset.PRESETS[GraphicsPreset.current].air), lights, "arena", look)


# The preset baseline is dark; the active arena alone supplies energy and visibility.
func _lighting_entry(light: Light3D) -> Dictionary:
	var values := {"light_energy": light.light_energy, "visible": true}
	_light_values[light.get_instance_id()] = values
	light.light_energy = 0.0
	light.visible = false
	return {"object": light, "values": values}


func _darken(light: Light3D) -> void:
	var values: Dictionary = _light_values.get(light.get_instance_id(), {})
	values["light_energy"] = 0.0
	values["visible"] = false
	light.light_energy = 0.0
	light.visible = false


# Return borrowed lights before the arena or a floor can destroy its children.
func release_lights() -> void:
	GraphicsPreset.release_lighting(get_instance_id())
	for pools in _floor_pools:
		_retire_floor(pools)
	for light: Light3D in _dress_lights:
		_darken(light)
		light.reparent(_light_pool, false)
	_floor_pools.clear()
	_dress_lights.clear()


func _retire_floor(pools: Node3D) -> void:
	if not is_instance_valid(_light_pool) or pools.get_parent() == _light_pool:
		return
	for light: Light3D in pools.get_children():
		_darken(light)
	pools.name = pools.get_meta("pool_name")
	pools.reparent(_light_pool, false)


func _floor(body: StaticBody3D, node_name: String) -> void:
	var skin := Node3D.new()
	skin.name = node_name
	# Body centre is one metre below its gameplay surface; no collider is touched.
	skin.position.y = module.PAD_THICK * 0.5 + 0.015
	body.add_child(skin)
	# Floor arcs had no gameplay state; the pit remains readable through its walls and lights.
	for child in body.get_children():
		if child is MeshInstance3D:
			child.material_override = _materials["floor"]
	var pools := _light_pool.get_node_or_null(String(body.name)) as Node3D
	if pools == null:
		pools = Node3D.new()
		pools.name = body.name
		pools.set_meta("pool_name", String(body.name))
		_light_pool.add_child(pools)
	pools.reparent(body, false)
	pools.name = "FloorLights"
	pools.position.y = skin.position.y
	_floor_pools.append(pools)
	body.tree_exiting.connect(_retire_floor.bind(pools), CONNECT_ONE_SHOT)
	for i in 4:
		var angle := i * TAU / 4.0 + PI / 4.0
		var light := pools.get_node_or_null("RimPool%d" % i) as OmniLight3D
		if light == null:
			light = OmniLight3D.new()
			light.name = "RimPool%d" % i
			pools.add_child(light)
		var pool: Dictionary = LIGHTS.rim_pool
		light.position = Vector3(sin(angle) * pool.radius, pool.height, cos(angle) * pool.radius)
		light.light_color = WorldLook.ARENAS.waking.floor_accent
		light.light_energy = pool.energy
		light.omni_range = pool.range
		light.shadow_enabled = false


func _works() -> void:
	var works := Node3D.new()
	works.name = "DescendingWorks"
	add_child(works)
	var batches := {}
	for tier in 4:
		var y := 14.0 - tier * 10.0
		for line in 8:
			var angle := line * TAU / 8.0 + tier * 0.10
			var wall := Vector3(sin(angle) * (WALL_RADIUS - 4.4), y, cos(angle) * (WALL_RADIUS - 4.4))
			var basis := Basis(Vector3.UP, angle)
			for link in 3:
				_put(batches, "lamp_curve_module.glb", Transform3D(basis, wall) * Transform3D(Basis.IDENTITY, Vector3((link - 1) * 3.0, 0, 0)))
			# One pool per line; deeper machinery recedes through the same fog as the cut faces.
			var light_name := "LampPool%d_%d" % [tier, line]
			var light := _light_pool.get_node_or_null(light_name) as OmniLight3D
			if light == null:
				light = OmniLight3D.new()
				light.name = light_name
				_light_pool.add_child(light)
			light.reparent(works, false)
			light.light_color = DigScenery.LAMP_LIGHT
			light.light_energy = LIGHTS.lamp_pool.energy
			light.omni_range = LIGHTS.lamp_pool.range
			light.shadow_enabled = false
			light.position = wall + basis * Vector3(0, -1.0, -1.0)
			var foot := Vector3(sin(angle) * (WALL_RADIUS - 4.2), y - 5.0, cos(angle) * (WALL_RADIUS - 4.2))
			_put(batches, "strut_bent.glb" if line % 3 == 0 else "strut_tall.glb", Transform3D(basis.scaled(Vector3.ONE * 1.4), foot))
			if line % 2 == 0:
				_put(batches, "shell_saddle.glb" if tier % 2 == 0 else "shell_crescent.glb", Transform3D(basis.scaled(Vector3.ONE * 1.3), foot + Vector3.DOWN * 2.0))
	_flush(works, batches)


func _put(batches: Dictionary, file: String, xf: Transform3D) -> void:
	if not batches.has(file):
		batches[file] = []
	batches[file].append(xf)


func _flush(parent: Node3D, batches: Dictionary) -> void:
	for file in batches:
		for part in _parts[file]:
			var multi := MultiMesh.new()
			multi.transform_format = MultiMesh.TRANSFORM_3D
			multi.mesh = part["mesh"]
			multi.instance_count = batches[file].size()
			var placements: Array[Transform3D] = []
			for i in multi.instance_count:
				var xf: Transform3D = batches[file][i] * part["local"]
				multi.set_instance_transform(i, xf)
				placements.append(xf)
			var view := MultiMeshInstance3D.new()
			view.name = file.get_basename()
			view.multimesh = multi
			view.set_meta("placements", placements)
			view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(view)


func _physics_process(_delta: float) -> void:
	_follow_reactor()


func _follow_reactor() -> void:
	if is_instance_valid(module.warden):
		var core: Vector3 = module.warden.family_point_at()
		_reactor_light.global_position = core
		_core_key.global_position = core + Vector3(10, 18, 12)
		_core_key.look_at(core)
	else:
		_reactor_light.light_energy = 0.0
		_core_key.light_energy = 0.0
