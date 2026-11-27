extends SceneTree


const OffscreenWindow := preload("res://tools/offscreen_window.gd")
const Palette := preload("res://src/core/palette.gd")
const HeroKitbashSculptor := preload("res://src/presentation/craft/hero_kitbash_sculptor.gd")
const AppShell := preload("res://src/core/app_shell.gd")

const SIZE := Vector2i(1600, 900)

const PREVIEW_SHADED_CODE := """
shader_type spatial;
render_mode cull_back;

uniform vec3 base_albedo : source_color = vec3(0.24, 0.35, 0.34);
uniform vec3 edge_albedo : source_color = vec3(0.82, 0.77, 0.65);
uniform vec3 grime_albedo : source_color = vec3(0.11, 0.12, 0.11);
uniform vec3 emit_albedo : source_color = vec3(0.55, 0.94, 0.83);
uniform float base_roughness = 0.78;
uniform float base_metallic = 0.18;
uniform float edge_metallic = 0.72;
uniform float emit_energy = 2.8;

varying vec3 v_world_pos;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453123);
}

float smooth_noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	float n000 = hash3(i + vec3(0.0, 0.0, 0.0));
	float n100 = hash3(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash3(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash3(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash3(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash3(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash3(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash3(i + vec3(1.0, 1.0, 1.0));
	return mix(
		mix(mix(n000, n100, u.x), mix(n010, n110, u.x), u.y),
		mix(mix(n001, n101, u.x), mix(n011, n111, u.x), u.y),
		u.z
	);
}

void fragment() {
	float wear = clamp(COLOR.r, 0.0, 1.0);
	float grime = clamp(COLOR.g, 0.0, 1.0);
	float emit_mask = clamp(COLOR.b, 0.0, 1.0);

	// Smooth multi-octave brushed paint / weathered patina break-up (zero blocky noise).
	float macro_n = smooth_noise3(v_world_pos * 1.8) * 0.65 + smooth_noise3(v_world_pos * 6.5) * 0.35;
	float grain = (macro_n - 0.5) * 0.085;

	vec3 col = base_albedo + vec3(grain);
	col = mix(col, grime_albedo, grime * 0.74);
	col = mix(col, edge_albedo, smoothstep(0.42, 0.92, wear) * 0.60);
	col = mix(col, emit_albedo * 0.35, emit_mask);

	ALBEDO = col;
	// Satin weathered industrial finish (SIGHT-PERSONA.md 2010: "Satin, never glossy")
	ROUGHNESS = clamp(mix(max(base_roughness, 0.78), 0.44, smoothstep(0.45, 0.92, wear)) + grime * 0.14 + grain * 0.35, 0.36, 0.96);
	METALLIC = mix(base_metallic, min(edge_metallic, 0.62), smoothstep(0.50, 0.92, wear)) * (1.0 - grime * 0.7);
	SPECULAR = 0.34;
	EMISSION = emit_albedo * emit_mask * emit_energy;
}
"""

const MASK_DEBUG_CODE := """
shader_type spatial;
render_mode unshaded, cull_back;

void fragment() {
	// Direct RGB visualization of vertex-color masks:
	// R = edge wear, G = cavity grime / AO, B = emissive mask
	ALBEDO = COLOR.rgb;
}
"""

var _out := ""
var _shaded_shader: Shader
var _mask_shader: Shader
var _stage: Node3D
var _cam: Camera3D


func _initialize() -> void:
	OffscreenWindow.apply(root)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	if _out.is_empty() or AppShell.headless():
		printerr("craft_sculptor_capture: needs Metal display and -- --out=<absolute dir>")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	if DisplayServer.get_name().to_lower() != "embedded":
		root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_run.call_deferred()


func _make_slot_material(slot: String, hero_id: StringName) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _shaded_shader
	var emit_col := Palette.AMBER if hero_id == HeroKitbashSculptor.HERO_EM_CRANE else Palette.ARC
	match slot:
		"hull_plating":
			mat.set_shader_parameter("base_albedo", Palette.VERDIGRIS.lerp(Palette.SAND, 0.22) if hero_id == HeroKitbashSculptor.HERO_CONDUIT_PYLON else Palette.STEEL.lerp(Palette.SAND, 0.35))
			mat.set_shader_parameter("base_roughness", 0.72)
			mat.set_shader_parameter("base_metallic", 0.24)
		"iron_frame":
			mat.set_shader_parameter("base_albedo", Palette.CHARCOAL.lerp(Palette.STEEL, 0.36))
			mat.set_shader_parameter("base_roughness", 0.68)
			mat.set_shader_parameter("base_metallic", 0.36)
		"copper_coil":
			mat.set_shader_parameter("base_albedo", Palette.COPPER)
			mat.set_shader_parameter("edge_albedo", Palette.SAND.lerp(Palette.COPPER, 0.30))
			mat.set_shader_parameter("base_roughness", 0.50)
			mat.set_shader_parameter("base_metallic", 0.62)
			mat.set_shader_parameter("edge_metallic", 0.85)
		"patch_oxide":
			mat.set_shader_parameter("base_albedo", Palette.RUST)
			mat.set_shader_parameter("base_roughness", 0.82)
			mat.set_shader_parameter("base_metallic", 0.12)
		"concrete_plinth":
			mat.set_shader_parameter("base_albedo", Palette.SAND.darkened(0.26))
			mat.set_shader_parameter("base_roughness", 0.90)
			mat.set_shader_parameter("base_metallic", 0.04)
			mat.set_shader_parameter("edge_metallic", 0.14)
		"cable_rubber":
			mat.set_shader_parameter("base_albedo", Palette.CABLE)
			mat.set_shader_parameter("edge_albedo", Palette.STEEL.darkened(0.25))
			mat.set_shader_parameter("base_roughness", 0.84)
			mat.set_shader_parameter("base_metallic", 0.08)
			mat.set_shader_parameter("edge_metallic", 0.18)
		"emissive_core":
			mat.set_shader_parameter("base_albedo", emit_col)
			mat.set_shader_parameter("emit_albedo", emit_col)
			mat.set_shader_parameter("emit_energy", 3.1)
			mat.set_shader_parameter("base_roughness", 0.28)
			mat.set_shader_parameter("base_metallic", 0.05)
		_:
			mat.set_shader_parameter("base_albedo", Palette.STEEL)
	if slot != "emissive_core":
		mat.set_shader_parameter("emit_albedo", emit_col)
		mat.set_shader_parameter("emit_energy", 2.4)
	return mat


func _apply_shaded_materials(inst: MeshInstance3D, hero_id: StringName) -> void:
	inst.material_override = null
	var m := inst.mesh as ArrayMesh
	for s in m.get_surface_count():
		inst.set_surface_override_material(s, _make_slot_material(m.surface_get_name(s), hero_id))


func _apply_mask_material(inst: MeshInstance3D, mask_mat: ShaderMaterial) -> void:
	inst.material_override = mask_mat


func _build_stage() -> void:
	_stage = Node3D.new()
	root.add_child(_stage)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("5d6163")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Palette.DAWN_VIOLET.lerp(Palette.SAND, 0.45)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.05
	env.tonemap_agx_white = 16.29
	env.tonemap_agx_contrast = 1.22
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.glow_enabled = true
	env.glow_intensity = 0.36
	env.glow_bloom = 0.14
	env.glow_hdr_threshold = 1.25
	var we := WorldEnvironment.new()
	we.environment = env
	_stage.add_child(we)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42.0, 36.0, 0.0)
	key.light_color = Palette.APRICOT.lerp(Color.WHITE, 0.55)
	key.light_energy = 1.85
	key.shadow_enabled = true
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	_stage.add_child(key)

	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-24.0, -142.0, 0.0)
	rim.light_color = Palette.TURQUOISE.lerp(Color.WHITE, 0.35)
	rim.light_energy = 0.72
	rim.shadow_enabled = false
	_stage.add_child(rim)

	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(90.0, 90.0)
	var floor_inst := MeshInstance3D.new()
	floor_inst.mesh = floor_mesh
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color("56595b")
	floor_mat.roughness = 0.94
	floor_mat.metallic = 0.0
	floor_inst.material_override = floor_mat
	_stage.add_child(floor_inst)

	_cam = Camera3D.new()
	_cam.near = 0.1
	_cam.far = 200.0
	_cam.fov = 34.0
	_stage.add_child(_cam)
	_cam.make_current()


func _shot(filename: String, eye: Vector3, target: Vector3, fov_deg: float = 34.0) -> void:
	_cam.fov = fov_deg
	_cam.look_at_from_position(eye, target)
	for _i in 10:
		await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := _out.path_join(filename)
	if img.save_png(path) != OK:
		printerr("craft_sculptor_capture: failed to save ", path)
		quit(3)


func _run() -> void:
	_shaded_shader = Shader.new()
	_shaded_shader.code = PREVIEW_SHADED_CODE
	_mask_shader = Shader.new()
	_mask_shader.code = MASK_DEBUG_CODE
	var mask_mat := ShaderMaterial.new()
	mask_mat.shader = _mask_shader

	_build_stage()

	var crane_mesh := HeroKitbashSculptor.build_em_crane_gantry()
	var press_mesh := HeroKitbashSculptor.build_salvage_press_beacon()
	var pylon_mesh := HeroKitbashSculptor.build_conduit_pylon()

	var crane := MeshInstance3D.new()
	crane.name = "EMCraneGantry"
	crane.mesh = crane_mesh
	crane.position = Vector3(-7.4, 0.0, 0.0)
	crane.rotation_degrees.y = -28.0
	_apply_shaded_materials(crane, HeroKitbashSculptor.HERO_EM_CRANE)
	_stage.add_child(crane)

	var press := MeshInstance3D.new()
	press.name = "SalvagePressBeacon"
	press.mesh = press_mesh
	press.position = Vector3(0.4, 0.0, 0.0)
	press.rotation_degrees.y = -26.0
	_apply_shaded_materials(press, HeroKitbashSculptor.HERO_SALVAGE_PRESS)
	_stage.add_child(press)

	var pylon := MeshInstance3D.new()
	pylon.name = "ConduitPylon"
	pylon.mesh = pylon_mesh
	pylon.position = Vector3(6.8, 0.0, 0.0)
	pylon.rotation_degrees.y = -24.0
	_apply_shaded_materials(pylon, HeroKitbashSculptor.HERO_CONDUIT_PYLON)
	_stage.add_child(pylon)

	await _shot("hero_lineup_shaded.png", Vector3(0.2, 7.6, 17.8), Vector3(0.1, 2.75, 0.0), 31.0)

	press.visible = false
	pylon.visible = false
	crane.position = Vector3(-1.3, 0.0, 0.0)
	crane.rotation_degrees.y = -24.0
	await _shot("em_crane_gantry_hero.png", Vector3(-0.6, 5.5, 11.4), Vector3(0.4, 2.75, 0.0), 33.0)

	crane.visible = false
	press.visible = true
	press.position = Vector3.ZERO
	press.rotation_degrees.y = -24.0
	await _shot("salvage_press_beacon_hero.png", Vector3(1.2, 5.6, 10.6), Vector3(0.0, 2.70, 0.0), 33.0)

	press.visible = false
	pylon.visible = true
	pylon.position = Vector3.ZERO
	pylon.rotation_degrees.y = -24.0
	await _shot("conduit_pylon_hero.png", Vector3(1.1, 7.6, 11.4), Vector3(0.0, 3.05, 0.0), 33.0)

	crane.visible = true
	press.visible = true
	pylon.visible = true
	crane.position = Vector3(-7.4, 0.0, 0.0)
	crane.rotation_degrees.y = -28.0
	press.position = Vector3(0.4, 0.0, 0.0)
	press.rotation_degrees.y = -26.0
	pylon.position = Vector3(6.8, 0.0, 0.0)
	pylon.rotation_degrees.y = -24.0
	_apply_mask_material(crane, mask_mat)
	_apply_mask_material(press, mask_mat)
	_apply_mask_material(pylon, mask_mat)
	await _shot("hero_vertex_masks.png", Vector3(0.2, 7.6, 17.8), Vector3(0.1, 2.75, 0.0), 31.0)

	var summary := {
		"em_crane_gantry": HeroKitbashSculptor.inspect_mesh_stats(crane_mesh),
		"salvage_press_beacon": HeroKitbashSculptor.inspect_mesh_stats(press_mesh),
		"conduit_pylon": HeroKitbashSculptor.inspect_mesh_stats(pylon_mesh),
	}
	print("CRAFT_SCULPTOR_CAPTURE ", JSON.stringify(summary))
	quit(0)
