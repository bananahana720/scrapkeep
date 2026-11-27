extends SceneTree


const Lookdev := preload("res://src/presentation/craft/craft_lookdev.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")
const Palette := preload("res://src/core/palette.gd")
const T := preload("res://tests/support/t.gd")

const EXPECTED_PRESETS := [
	"oxidized_hull_plating",
	"oil_slicked_iron",
	"scorched_concrete",
	"plasma_conduit_core",
	"combat_floor_apron",
]

const MASTER_UNIFORMS := [
	"use_world_space",
	"use_vertex_masks",
	"detail_tile_metres",
	"has_detail_tex",
	"detail_tex",
	"base_albedo",
	"base_roughness",
	"base_metallic",
	"edge_wear_albedo",
	"edge_wear_metallic",
	"edge_wear_roughness",
	"auto_curvature_weight",
	"grime_albedo",
	"grime_roughness",
	"grime_metallic",
	"foot_grime_height",
	"dust_albedo",
	"dust_strength",
	"emissive_color",
	"emissive_energy",
	"reduce_flashes",
]

const FLOOR_UNIFORMS := [
	"floor_albedo",
	"value_clamp_min",
	"value_clamp_max",
	"saturation_cap",
	"has_detail_tex",
	"detail_tex",
	"slab_metres",
	"dry_roughness",
	"oil_roughness",
	"oil_patch_strength",
	"normal_relief",
]

var _t := T.new("craft_lookdev_shader_test")


func _initialize() -> void:
	Lookdev.reset_for_tests()
	FlashGuard.on = false
	_check_shader_sources()
	_check_presets()
	_check_binder_and_masks()
	_check_flash_guard_and_fallback()
	Lookdev.reset_for_tests()
	FlashGuard.on = false
	quit(_t.verdict())


func _check_shader_sources() -> void:
	_t.check("triplanar include exists", FileAccess.file_exists(Lookdev.DETAIL_INC_PATH), Lookdev.DETAIL_INC_PATH)
	var inc_text := FileAccess.get_file_as_string(Lookdev.DETAIL_INC_PATH)
	_t.check("triplanar include has stochastic anti-tiling", inc_text.contains("craft_stochastic_sample") and inc_text.contains("textureGrad"), "stochastic + textureGrad")
	_t.check("triplanar include has curvature + bump helpers", inc_text.contains("craft_curvature") and inc_text.contains("craft_bump_normal"), "curvature + bump")

	var master := load(Lookdev.MASTER_SHADER_PATH) as Shader
	_t.check("master weathering shader loads", master != null and master.code.length() > 200, Lookdev.MASTER_SHADER_PATH)
	if master != null:
		var uniforms := _uniform_names(master)
		for u in MASTER_UNIFORMS:
			_t.check("master shader exposes uniform " + u, uniforms.has(u), u)
		_t.check("master shader reads COLOR.r/g/b vertex masks",
			master.code.contains("craft_vcolor.r") and master.code.contains("craft_vcolor.g") and master.code.contains("craft_vcolor.b"),
			"R=edge, G=grime, B=emissive")
		_t.check("master shader has zero vertex displacement", not _assigns_vertex(master.code), "no VERTEX = assignment")

	var floor_shader := load(Lookdev.FLOOR_SHADER_PATH) as Shader
	_t.check("combat floor shader loads", floor_shader != null and floor_shader.code.length() > 200, Lookdev.FLOOR_SHADER_PATH)
	if floor_shader != null:
		var funiforms := _uniform_names(floor_shader)
		for u in FLOOR_UNIFORMS:
			_t.check("combat floor shader exposes uniform " + u, funiforms.has(u), u)
		_t.check("combat floor shader is strictly geometrically flat", not _assigns_vertex(floor_shader.code), "zero vertex displacement")
		_t.check("combat floor shader compresses value and saturation",
			floor_shader.code.contains("compress_combat_lane_color") and floor_shader.code.contains("saturation_cap"),
			"mid-tone discipline")


func _check_presets() -> void:
	var ids := Lookdev.preset_ids()
	_t.eq("exact 5 craft presets registered", ids.size(), EXPECTED_PRESETS.size())
	for id in EXPECTED_PRESETS:
		var path := Lookdev.preset_path(id)
		_t.check("preset file exists " + id, FileAccess.file_exists(path), path)
		var mat := Lookdev.preset_material(id)
		_t.check("preset loads as ShaderMaterial " + id, mat is ShaderMaterial, id)
		if mat == null:
			continue
		_t.eq("preset is cached singleton " + id, Lookdev.preset_material(id), mat)
		_t.check("preset uses decoupled .gdshader file " + id,
			mat.shader != null and mat.shader.resource_path.begins_with("res://assets/shaders/craft_"),
			mat.shader.resource_path if mat.shader != null else "null")
		var tex := mat.get_shader_parameter("detail_tex") as Texture2D
		_t.check("preset has imported detail texture " + id,
			mat.get_shader_parameter("has_detail_tex") == true and tex != null and tex.get_width() >= 256,
			"%dx%d" % [tex.get_width() if tex != null else 0, tex.get_height() if tex != null else 0])

	var hull := Lookdev.preset_material("oxidized_hull_plating")
	_t.check("oxidized_hull_plating matte oxide base -> worn steel bevel",
		float(hull.get_shader_parameter("base_roughness")) >= 0.80
		and float(hull.get_shader_parameter("base_metallic")) <= 0.15
		and float(hull.get_shader_parameter("edge_wear_metallic")) >= 0.85
		and float(hull.get_shader_parameter("edge_wear_roughness")) <= 0.30
		and float(hull.get_shader_parameter("grime_roughness")) >= 0.85,
		"oxide->steel contrast")

	var iron := Lookdev.preset_material("oil_slicked_iron")
	_t.check("oil_slicked_iron has oil sheen roughness contrast + bright worn bevels",
		float(iron.get_shader_parameter("oil_sheen_strength")) >= 0.5
		and float(iron.get_shader_parameter("oil_sheen_roughness")) <= 0.30
		and float(iron.get_shader_parameter("edge_wear_metallic")) >= 0.88
		and float(iron.get_shader_parameter("grime_roughness")) >= 0.85,
		"oil sheen + bevels")

	var concrete := Lookdev.preset_material("scorched_concrete")
	_t.check("scorched_concrete stays matte mineral with strong foot grime",
		float(concrete.get_shader_parameter("base_roughness")) >= 0.88
		and float(concrete.get_shader_parameter("base_metallic")) <= 0.05
		and float(concrete.get_shader_parameter("foot_grime_strength")) >= 0.5
		and float(concrete.get_shader_parameter("grime_roughness")) >= 0.90,
		"mineral concrete")

	var plasma := Lookdev.preset_material("plasma_conduit_core")
	var p_col := plasma.get_shader_parameter("emissive_color") as Color
	var p_sec := plasma.get_shader_parameter("emissive_secondary_color") as Color
	_t.check("plasma_conduit_core uses Palette.ARC and Palette.AMBER above bloom threshold",
		p_col.is_equal_approx(Palette.ARC)
		and p_sec.is_equal_approx(Palette.AMBER)
		and float(plasma.get_shader_parameter("emissive_energy")) > 1.5,
		"ARC=%s AMBER=%s energy=%s" % [p_col.to_html(false), p_sec.to_html(false), str(plasma.get_shader_parameter("emissive_energy"))])

	var apron := Lookdev.preset_material("combat_floor_apron")
	_t.eq("combat_floor_apron uses combat floor shader", apron.shader.resource_path, Lookdev.FLOOR_SHADER_PATH)
	_t.check("combat_floor_apron enforces mid-tone value and saturation compression",
		float(apron.get_shader_parameter("value_clamp_min")) >= 0.20
		and float(apron.get_shader_parameter("value_clamp_max")) <= 0.52
		and float(apron.get_shader_parameter("saturation_cap")) <= 0.20
		and float(apron.get_shader_parameter("dry_roughness")) >= 0.80
		and float(apron.get_shader_parameter("oil_roughness")) <= 0.40,
		"compressed combat floor")

	for id in EXPECTED_PRESETS:
		var mat := Lookdev.preset_material(id)
		var no_hazard := true
		for u in mat.shader.get_shader_uniform_list():
			var val = mat.get_shader_parameter(String(u.name))
			if val is Color and (val as Color).is_equal_approx(Palette.HAZARD):
				no_hazard = false
		_t.check("no HAZARD colour leaked in preset " + id, no_hazard, id)


func _check_binder_and_masks() -> void:
	var encoded := Lookdev.encode_mask(0.9, 0.2, 1.0)
	_t.near("encode_mask R=edge_wear", encoded.r, 0.9, 0.001)
	_t.near("encode_mask G=cavity_grime", encoded.g, 0.2, 0.001)
	_t.near("encode_mask B=emissive", encoded.b, 1.0, 0.001)
	_t.near("encode_mask A=weight", encoded.a, 1.0, 0.001)

	var mesh := ArrayMesh.new()
	var st0 := SurfaceTool.new()
	st0.begin(Mesh.PRIMITIVE_TRIANGLES)
	st0.set_normal(Vector3.UP)
	st0.set_color(Lookdev.encode_mask(0.85, 0.1, 0.0))
	st0.add_vertex(Vector3(0, 0, 0))
	st0.add_vertex(Vector3(1, 0, 0))
	st0.add_vertex(Vector3(0, 0, 1))
	st0.commit(mesh)
	mesh.surface_set_name(0, "hull_plate")

	var st1 := SurfaceTool.new()
	st1.begin(Mesh.PRIMITIVE_TRIANGLES)
	st1.set_normal(Vector3.UP)
	st1.add_vertex(Vector3(0, 1, 0))
	st1.add_vertex(Vector3(1, 1, 0))
	st1.add_vertex(Vector3(0, 1, 1))
	st1.commit(mesh)
	mesh.surface_set_name(1, "conduit_housing")

	_t.check("surface 0 detected as vertex-colored", Lookdev.has_vertex_color_masks(mesh, 0), "ARRAY_FORMAT_COLOR set")
	_t.check("surface 1 detected as uncolored", not Lookdev.has_vertex_color_masks(mesh, 1), "ARRAY_FORMAT_COLOR unset")

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var count := Lookdev.bind_mesh_surfaces(mi, {
		"hull_plate": "hull",
		"conduit_housing": "conduit",
	})
	_t.eq("bind_mesh_surfaces bound both surfaces", count, 2)
	var m0 := mi.get_surface_override_material(0) as ShaderMaterial
	var m1 := mi.get_surface_override_material(1) as ShaderMaterial
	_t.eq("vertex-colored surface uses exact shared .tres preset", m0, Lookdev.preset_material("oxidized_hull_plating"))
	_t.check("uncolored surface safely binds unmasked variant", m1 != null and m1.get_shader_parameter("use_vertex_masks") == false, "prevents white-vertex glow")

	var group_root := Node3D.new()
	var child_a := MeshInstance3D.new()
	child_a.mesh = mesh
	child_a.set_meta("craft_preset", "iron")
	group_root.add_child(child_a)
	var bound_tree := Lookdev.bind_tree(group_root)
	_t.eq("bind_tree binds metadata-tagged mesh", bound_tree, 1)
	_t.eq("bind_tree resolved alias 'iron' -> oil_slicked_iron", child_a.get_surface_override_material(0), Lookdev.preset_material("oil_slicked_iron"))

	var hero_mesh := ArrayMesh.new()
	var hero_slots := ["hull_plating", "iron_frame", "concrete_plinth", "emissive_core"]
	for idx in hero_slots.size():
		var sth := SurfaceTool.new()
		sth.begin(Mesh.PRIMITIVE_TRIANGLES)
		sth.set_normal(Vector3.UP)
		sth.set_color(Lookdev.encode_mask(0.85, 0.1, 1.0 if idx == 3 else 0.0))
		sth.add_vertex(Vector3(0, idx, 0))
		sth.add_vertex(Vector3(1, idx, 0))
		sth.add_vertex(Vector3(0, idx, 1))
		sth.commit(hero_mesh)
		hero_mesh.surface_set_name(idx, hero_slots[idx])
	var hero_mi := MeshInstance3D.new()
	hero_mi.mesh = hero_mesh
	_t.eq("bind_hero_mesh maps all HeroKitbashSculptor slots", Lookdev.bind_hero_mesh(hero_mi), hero_slots.size())
	_t.eq("hero emissive_core slot -> plasma_conduit_core", hero_mi.get_surface_override_material(3), Lookdev.preset_material("plasma_conduit_core"))
	_t.eq("hero concrete_plinth slot -> scorched_concrete", hero_mi.get_surface_override_material(2), Lookdev.preset_material("scorched_concrete"))
	hero_mi.free()

	mi.free()
	group_root.free()


func _check_flash_guard_and_fallback() -> void:
	var plasma := Lookdev.preset_material("plasma_conduit_core")
	_t.eq("reduce_flashes starts false", plasma.get_shader_parameter("reduce_flashes"), false)
	FlashGuard.on = true
	Lookdev.sync_flash_guard()
	_t.eq("sync_flash_guard propagates FlashGuard.on=true", plasma.get_shader_parameter("reduce_flashes"), true)
	FlashGuard.on = false
	Lookdev.sync_flash_guard()
	_t.eq("sync_flash_guard restores FlashGuard.on=false", plasma.get_shader_parameter("reduce_flashes"), false)

	var fallback := plasma.duplicate(false) as ShaderMaterial
	fallback.set_shader_parameter("has_detail_tex", false)
	fallback.set_shader_parameter("detail_tex", null)
	_t.check("shader material remains valid with detail_tex unset",
		fallback.shader == plasma.shader and fallback.get_shader_parameter("has_detail_tex") == false,
		"procedural fallback")


func _uniform_names(shader: Shader) -> Dictionary:
	var out := {}
	for entry in shader.get_shader_uniform_list():
		out[String(entry.name)] = true
	return out


func _assigns_vertex(code: String) -> bool:
	var re := RegEx.new()
	re.compile("(?m)\\bVERTEX\\s*([+\\-*/]?=)(?!=)")
	return re.search(code) != null
