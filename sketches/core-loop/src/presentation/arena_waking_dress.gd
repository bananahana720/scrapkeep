extends Node3D

const DigScenery := preload("res://src/presentation/dig_scenery.gd")
const Palette := preload("res://src/core/palette.gd")
const GraphicsPreset := preload("res://src/presentation/graphics_preset.gd")
const WorldLook := preload("res://src/presentation/world_look.gd")
const WeakPoints := preload("res://src/boss/weak_points.gd")
const STONE_DIR := "res://assets/models/dig_stone/"
const MECH_DIR := "res://assets/models/dig_mechanical/"
const BOSS_DIR := "res://assets/models/bosses/"
static var stone_dir := STONE_DIR
static var mech_dir := MECH_DIR
static var boss_dir := BOSS_DIR


static func reset_for_tests() -> void:
	stone_dir = STONE_DIR
	mech_dir = MECH_DIR
	boss_dir = BOSS_DIR
const STONE_FILES := ["cut_face_long.glb", "cut_face_scoop.glb"]
const MECH_FILES := ["lamp_curve_module.glb", "strut_tall.glb", "strut_bent.glb", "shell_crescent.glb", "shell_saddle.glb"]
const RIM_COPING_FILE := "waking_rim_coping.glb"
const HATCH_FRAME_FILE := "waking_hatch_frame.glb"
const RIM_BANK_SHADER_CODE := """
shader_type spatial;
render_mode diffuse_burley, cull_disabled;

uniform sampler2D tex_tone : source_color, repeat_enable;
uniform sampler2D tex_grain : source_color, repeat_enable;
uniform vec4 base_color : source_color;
uniform vec4 seam_color : source_color;
uniform vec4 petrol_color : source_color;
uniform vec4 bone_color : source_color;
uniform vec4 amber_color : source_color;
uniform float panel_pitch = 4.0;
uniform float seam_width = 0.12;
varying vec3 local_at;

void vertex() {
	local_at = VERTEX;
}

void fragment() {
	vec2 p = local_at.xz;
	float angle = atan(p.y, p.x);
	float tone = texture(tex_tone, p * 0.035).r;
	float grain = texture(tex_grain, p * 0.4).r;
	// Quarter-pipe vertical rib plates (24 orthogonal sectors around the 36 m shaft rim, y = 1.0..7.0).
	float sector = mod(angle + 3.14159265, 6.28318530 / 24.0) / (6.28318530 / 24.0);
	float rib_edge = min(sector, 1.0 - sector);
	float rib_seam = 1.0 - smoothstep(0.035, 0.075, rib_edge);
	float rib_bevel = smoothstep(0.07, 0.14, rib_edge) * (1.0 - smoothstep(0.14, 0.24, rib_edge));
	float horiz_seam = 1.0 - smoothstep(0.045, 0.10, abs(fract(local_at.y * 0.5) - 0.5));
	float bank_mask = smoothstep(1.15, 2.05, local_at.y);
	float datum_band = smoothstep(1.25, 1.55, local_at.y) * (1.0 - smoothstep(1.75, 2.15, local_at.y));
	float coping_band = smoothstep(5.80, 6.22, local_at.y);
	// Orthogonal coping bays: charcoal plate, bone lip, central amber marker — never 45-deg hazard stripes.
	float amber_bay = step(0.30, sector) * step(sector, 0.70);
	float bone_bay = step(0.12, sector) * step(sector, 0.88) * (1.0 - amber_bay);
	vec3 floor_col = base_color.rgb * (0.78 + tone * 0.18 + grain * 0.08);
	vec3 cast_wall = mix(seam_color.rgb * 1.12, petrol_color.rgb * 0.94, 0.48) * (0.78 + tone * 0.18 + grain * 0.08);
	cast_wall += bone_color.rgb * rib_bevel * 0.10;
	cast_wall = mix(cast_wall, seam_color.rgb * 0.42, max(rib_seam * 0.86, horiz_seam * 0.64));
	cast_wall = mix(cast_wall, seam_color.rgb * 0.65, datum_band * 0.55);
	vec3 coping_col = mix(seam_color.rgb * 0.85, bone_color.rgb * 0.94, bone_bay);
	coping_col = mix(coping_col, amber_color.rgb * 1.02, amber_bay);
	vec3 bank_col = mix(cast_wall, coping_col, coping_band);
	ALBEDO = mix(floor_col, bank_col, bank_mask);
	ROUGHNESS = mix(0.92, 0.64, bank_mask);
	METALLIC = mix(0.0, 0.28, bank_mask);
}
"""
const ENV_PROPERTIES := ["background_mode", "background_color", "ambient_light_source", "ambient_light_color", "ambient_light_energy", "reflected_light_source", "fog_enabled", "fog_density", "fog_light_color", "fog_light_energy", "fog_sun_scatter"]
const WARNING := "arena_waking_dress: assets missing or malformed; keeping greybox"
const WALL_RADIUS := 60.0
const WALL_SECTORS := 16
const LIGHTS := {
	"rim_pool": {"energy": 1.0, "range": 34.0, "radius": 28.0, "height": 6.0},
	"lamp_pool": {"energy": 1.2, "range": 26.0},
	"reactor": {"energy": 3.1, "range": 52.0},
	"core_key": {"energy": 2.9, "range": 58.0, "angle": 55.0},
	"core_key_low": {"angle": 30.0},
}
const FLOOR_PLATE_PITCH := 4.0
const FLOOR_SEAM_WIDTH := 0.12
const FLOOR_PLATE_COLOR := Color("c8cdcf")

var module
var _parts := {}
var _materials := {}
var _coping_ring_mesh: ArrayMesh
var _reactor_light: OmniLight3D
var _core_key: SpotLight3D
var _light_pool: Node3D
var _dress_lights := []
var _floor_pools := []
var _light_values := {}
var _dressed_parts := {}


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


func _sync_dressing() -> void:
	_core_key.shadow_enabled = true
	_core_key.spot_angle = LIGHTS.core_key_low.angle if GraphicsPreset.current == "low" else LIGHTS.core_key.angle


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
	var rim_shader := Shader.new()
	rim_shader.code = RIM_BANK_SHADER_CODE
	var rim_material := ShaderMaterial.new()
	rim_material.shader = rim_shader
	rim_material.set_shader_parameter("tex_tone", stone.get_shader_parameter("tex_tone"))
	rim_material.set_shader_parameter("tex_grain", stone.get_shader_parameter("tex_grain"))
	rim_material.set_shader_parameter("base_color", FLOOR_PLATE_COLOR)
	rim_material.set_shader_parameter("seam_color", Palette.CHARCOAL)
	rim_material.set_shader_parameter("petrol_color", Palette.VERDIGRIS)
	rim_material.set_shader_parameter("bone_color", Palette.SAND)
	rim_material.set_shader_parameter("amber_color", Palette.AMBER)
	rim_material.set_shader_parameter("panel_pitch", FLOOR_PLATE_PITCH)
	rim_material.set_shader_parameter("seam_width", FLOOR_SEAM_WIDTH)
	_materials["rim_bank"] = rim_material
	for slot in ["steel", "enamel", "glass", "ancient_enamel", "ancient_light"]:
		var material := StandardMaterial3D.new()
		material.resource_name = slot
		material.vertex_color_use_as_albedo = slot != "ancient_light"
		material.roughness = 0.68 if slot == "steel" else (0.56 if slot == "ancient_enamel" else 0.87)
		material.metallic = 0.34 if slot == "steel" else (0.24 if slot == "ancient_enamel" else 0.0)
		if slot == "glass":
			material.roughness = 0.32
			material.emission_enabled = true
			material.emission = DigScenery.LAMP_LIGHT
			material.emission_energy_multiplier = 0.95
		elif slot == "ancient_light":
			material.albedo_color = Palette.ANCIENT
			material.roughness = 0.28
			material.emission_enabled = true
			material.emission = Palette.ANCIENT
			material.emission_energy_multiplier = 3.0
		_materials[slot] = material
	for file in STONE_FILES:
		if not _load_parts(stone_dir + file):
			return false
	for file in MECH_FILES:
		if not _load_parts(mech_dir + file):
			return false
	if _load_parts(boss_dir + RIM_COPING_FILE):
		_coping_ring_mesh = _build_coping_ring_mesh()
	_load_parts(boss_dir + HATCH_FRAME_FILE)
	return true


func _build_coping_ring_mesh() -> ArrayMesh:
	var parts: Array = _parts.get(RIM_COPING_FILE, [])
	if parts.is_empty():
		return null
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for sector in 24:
		var rot := Transform3D(Basis(Vector3.UP, sector * TAU / 24.0), Vector3.ZERO)
		for part in parts:
			var mesh: Mesh = part["mesh"]
			var xf: Transform3D = rot * (part["local"] as Transform3D)
			for s in mesh.get_surface_count():
				st.append_from(mesh, s, xf)
	var ring := st.commit()
	if ring != null and ring.get_surface_count() > 0:
		ring.surface_set_material(0, _materials["steel"])
	return ring


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
	_reactor_light.light_color = Color("82b8d8")
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
	_core_key.light_specular = 1.35
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
	skin.position.y = module.PAD_THICK * 0.5 + 0.015
	body.add_child(skin)
	for child in body.get_children():
		if child is MeshInstance3D:
			child.material_override = _materials["rim_bank"] if child.name == "RimBankMesh" else _materials["floor"]
	if _coping_ring_mesh != null:
		var coping := MeshInstance3D.new()
		coping.name = "RimCopingRing"
		coping.mesh = _coping_ring_mesh
		coping.material_override = _materials["steel"]
		coping.position = Vector3(0.0, 5.95, 0.0)
		coping.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		skin.add_child(coping)
	if node_name == "PitDressing":
		_add_pit_abyss_glow(skin)
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
	for arch in 8:
		var angle := arch * TAU / 8.0
		var basis := Basis(Vector3.UP, angle)
		var crown := Vector3(sin(angle) * (WALL_RADIUS - 4.2), 20.0, cos(angle) * (WALL_RADIUS - 4.2))
		_put(batches, "strut_tall.glb", Transform3D(basis.scaled(Vector3(1.4, 1.5, 1.4)), crown))
		_put(batches, "shell_crescent.glb", Transform3D(basis.scaled(Vector3.ONE * 1.3), crown + Vector3.UP * 2.5))
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
	_dress_weak_parts()


func _add_pit_abyss_glow(skin: Node3D) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(96.0, 96.0)
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
uniform vec4 glow_color : source_color;
void fragment() {
	vec2 d = UV * 2.0 - 1.0;
	float r = length(d);
	float core = smoothstep(1.0, 0.08, r);
	float ring = smoothstep(0.68, 0.52, r) * smoothstep(0.26, 0.42, r);
	ALBEDO = glow_color.rgb * (0.58 + 0.72 * core + 0.35 * ring);
	ALPHA = clamp(core * core * 0.44 + ring * 0.14, 0.0, 0.52);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("glow_color", Palette.AMBER)
	var glow := MeshInstance3D.new()
	glow.name = "PitAbyssGlow"
	glow.mesh = quad
	glow.material_override = mat
	glow.rotation.x = -PI * 0.5
	glow.position = Vector3(0.0, -18.0, 0.0)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	skin.add_child(glow)


func _dress_weak_parts() -> void:
	var hatch_parts: Array = _parts.get(HATCH_FRAME_FILE, [])
	if hatch_parts.is_empty() or module == null or not is_instance_valid(module):
		return
	var nodes = module.get("_part_nodes")
	if not (nodes is Dictionary):
		return
	for id in nodes:
		var part = nodes[id]
		if not is_instance_valid(part):
			_dressed_parts.erase(id)
			continue
		var holder := part.get_node_or_null("SculptedHatchFrame") as Node3D
		if holder == null:
			holder = Node3D.new()
			holder.name = "SculptedHatchFrame"
			for p in hatch_parts:
				var mi := MeshInstance3D.new()
				var mesh: Mesh = p["mesh"]
				mi.mesh = mesh
				mi.transform = p["local"]
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				var src := mesh.surface_get_material(0) if mesh.get_surface_count() > 0 else null
				var is_seam := src != null and String(src.resource_name) == "ancient_light"
				mi.name = "HatchSeams" if is_seam else "HatchSurround"
				mi.material_override = _materials["ancient_light"] if is_seam else _materials["ancient_enamel"]
				holder.add_child(mi)
			part.add_child(holder)
			_dressed_parts[id] = holder
		var broken: bool = int(part.state) == WeakPoints.BROKEN
		var open: bool = int(part.state) == WeakPoints.OPEN
		holder.visible = not broken
		var seams := holder.get_node_or_null("HatchSeams") as MeshInstance3D
		if seams != null:
			seams.visible = open
		for edge_name in ["FrameTop", "FrameBottom", "FrameLeft", "FrameRight"]:
			var box := part.get_node_or_null(edge_name) as MeshInstance3D
			if box != null:
				box.visible = broken and edge_name != "FrameRight"


func _follow_reactor() -> void:
	if is_instance_valid(module.warden):
		var core: Vector3 = module.warden.family_point_at()
		_reactor_light.global_position = core
		_core_key.global_position = core + Vector3(10, 18, 12)
		_core_key.look_at(core)
	else:
		_reactor_light.light_energy = 0.0
		_core_key.light_energy = 0.0
