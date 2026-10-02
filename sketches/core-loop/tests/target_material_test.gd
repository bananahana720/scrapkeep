extends SceneTree

const Game := preload("res://src/game.gd")
const Preset := preload("res://src/presentation/graphics_preset.gd")
const Palette := preload("res://src/core/palette.gd")
const Capture := preload("res://tools/target_capture.gd")
const WorldPrompt := preload("res://src/ui/world_prompt.gd")
const Intent := preload("res://src/movement/intent.gd")
var failed := false

func check(ok: bool, what: String) -> void:
	failed = failed or not ok
	print(what, " -> ", "PASS" if ok else "FAIL")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	check(not _colour_source_valid("ALBEDO = vec3(-0.1, 1e-2, 0.5);"), "source scan rejects signed and exponential colour literals")
	check(_colour_source_valid("uniform vec4 base : source_color = vec4(1.0);"), "source scan permits uniform defaults")
	check(_shader_colour_scan(), "target shaders contain no colour literals outside uniform defaults")
	Preset.apply("high")
	var game := Game.new()
	game.test_mode = true
	game.table = "default"
	root.add_child(game)
	await process_frame
	await process_frame
	game.ctx.calm = true
	game.flow.force_warden = true
	game.flow.press_start()
	game.flow.choose_class(0)
	game.run.set_max_hp(999999.0)
	game.player.source = Intent.Scripted.new()
	game.ctx.spawner.spawn_enemy("chaser", game.ctx.terrain.drop_point(-70, -90, 1.2))
	for i in 120:
		await physics_frame
	paused = true
	var views := game.find_children("*", "MeshInstance3D", true, false)
	var before := []
	var surface_count := 0
	for view: MeshInstance3D in views:
		if view.mesh == null:
			continue
		var materials := []
		var material_values := []
		for i in view.mesh.get_surface_count():
			var material := view.get_active_material(i)
			materials.append(material)
			material_values.append(_values(material))
			surface_count += 1
		before.append({"view": view, "mesh": view.mesh, "cast_shadow": view.cast_shadow,
			"materials": materials, "values": material_values})
	check(Preset.apply("low") and _matches(before), "fresh high to low keeps every active material and its values")
	check(Preset.apply("target"), "target applies to the built game")
	var roles := {"ground": 0, "rock": 0, "dam": 0}
	for binding in Preset._materials:
		var view := binding.view.get_ref() as MeshInstance3D
		if view == null:
			continue
		for i in view.mesh.get_surface_count():
			var material := view.get_active_material(i) as ShaderMaterial
			check(material != null and material.resource_name == "target_" + binding.role, "target binds " + binding.role + " on " + str(view.name))
			if material != null:
				var expected: Color = Palette.SAND if binding.role == "ground" else Palette.SANDSTONE
				if binding.role == "dam":
					expected = binding.originals[i].albedo_color
				check(material.get_shader_parameter("base_color") == expected, "target base uniform matches high palette/source colour for " + binding.role)
				if binding.role == "ground":
					check(material.get_shader_parameter("rock_color") == Palette.SANDSTONE, "ground slope uses sandstone palette uniform")
				if binding.role == "dam":
					check(material.get_shader_parameter("base_map") == binding.originals[i].albedo_texture, "dam keeps high source map and its rust hue")
				roles[binding.role] += 1
				check(material.get_shader_parameter("detail_enabled") == true and material.get_shader_parameter("relief_enabled") == true, "target detail and relief enabled")
				var parameters := material.shader.get_shader_uniform_list()
				check(parameters.any(func(p): return p.name == "detail_enabled"), "engine parses target shader uniforms and include")
	check(roles.ground == 3 and roles.rock >= 1 and roles.dam >= 4, "three terrain grounds, rock and merged/imported dam surfaces use target materials")
	for row in before:
		check(row.view.mesh == row.mesh and row.view.cast_shadow == row.cast_shadow, "target keeps mesh and shadow-caster state for " + str(row.view.name))
		if not Preset._materials.any(func(binding): return binding.view.get_ref() == row.view):
			check(_matches([row]), "target keeps actor, prop and effect materials for " + str(row.view.name))
	check(Preset.apply("high") and _matches(before), "target to high restores every original material resource and value")
	check(Preset.apply("target") and Preset.apply("low") and _matches(before), "target to low restores every original material resource and value")
	check(Preset.apply("target") and Preset.apply("target") and Preset.apply("high") and _matches(before), "repeated target preserves original material bindings")
	check(Palette.ground_material().shader.resource_path == "res://src/presentation/sandstone.gdshader", "established ground construction remains original")
	var layer := CanvasLayer.new()
	var label := WorldPrompt.new()
	var spatial := Label3D.new()
	root.add_child(layer)
	root.add_child(label)
	root.add_child(spatial)
	label.visible = true
	Capture.hide_labels(root)
	check(not layer.visible and layer.process_mode == Node.PROCESS_MODE_DISABLED and not label.visible and not spatial.visible, "capture hides standalone WorldPrompt, HUD layers and Label3D")
	var samples: Array[float] = []
	for i in 240:
		samples.append(float(240 - i))
	var summary := Capture._summary(samples)
	check(summary.sample_count == 240 and summary.median_ms == 120.5 and summary.p95_ms == 228.0, "render-time summary uses median and nearest-rank p95 over 240 samples")
	var unavailable := Capture._summary([0.0, 0.0])
	check(not unavailable.available, "zero engine timestamps are marked unavailable")
	layer.free()
	label.free()
	spatial.free()
	game.free()
	Preset.apply("high")
	print("Checked ", before.size(), " mesh instances and ", surface_count, " active material slots")
	print("target_material_test: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _values(material: Material) -> Dictionary:
	var values := {}
	if material == null:
		return values
	for property in material.get_property_list():
		if property.usage & PROPERTY_USAGE_STORAGE:
			values[property.name] = material.get(property.name)
	return values

func _matches(before: Array) -> bool:
	for row in before:
		var view: MeshInstance3D = row.view
		if view.mesh != row.mesh:
			return false
		for i in row.materials.size():
			var material := view.get_active_material(i)
			if material != row.materials[i] or _values(material) != row.values[i]:
				return false
	return true


func _shader_colour_scan() -> bool:
	for file in DirAccess.get_files_at("res://assets/shaders"):
		if not file.begins_with("target_") or not (file.ends_with(".gdshader") or file.ends_with(".gdshaderinc")):
			continue
		if not _colour_source_valid(FileAccess.get_file_as_string("res://assets/shaders/" + file)):
			print("Colour literal outside uniform: ", file)
			return false
	return true

func _colour_source_valid(source: String) -> bool:
	var vector := RegEx.new()
	vector.compile("vec[34]\\([^)]*\\)")
	for line in source.split("\n"):
		var code := line.split("//")[0].strip_edges()
		for match in vector.search_all(code):
			var body: String = match.get_string().split("(")[1].trim_suffix(")")
			var numeric := true
			for token in body.split(","):
				numeric = numeric and token.strip_edges().is_valid_float()
			if numeric and not (code.begins_with("uniform ") and code.contains("=")):
				return false
	return true
