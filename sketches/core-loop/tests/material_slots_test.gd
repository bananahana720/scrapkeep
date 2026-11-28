extends SceneTree

const Palette := preload("res://src/core/palette.gd")
const PaletteMaterials := preload("res://src/presentation/palette_materials.gd")
const Slots := preload("res://src/presentation/material_slots.gd")
const ROLES := ["nosing", "ground", "rock", "dam", "clutter", "dressing", "air", "hazard_stripe", "concrete", "stone", "steel", "enamel", "cable"]
var failed := false


func check(ok: bool, what: String) -> void:
	failed = failed or not ok
	print(what, " -> ", "PASS" if ok else "FAIL")


func _initialize() -> void:
	var roles_ok := true
	for role in ROLES:
		roles_ok = roles_ok and Slots.SLOTS.has(role)
	check(roles_ok, "the registry carries the required roles (the twelve named plus nosing)")
	check(Slots.SLOTS.size() == Slots.SLOTS.keys().size() and Slots.SLOTS.keys().size() == _unique(Slots.SLOTS.keys()).size(), "no duplicate role")
	var resolved := 0
	for role in Slots.SLOTS:
		var row: Dictionary = Slots.SLOTS[role]
		var material := PaletteMaterials.slot_material(role)
		var ok := material != null and material.resource_name != "" and material == PaletteMaterials.slot_material(role)
		match row.kind:
			"shader", "resource":
				if material is ShaderMaterial:
					var shader: Shader = (material as ShaderMaterial).shader
					ok = ok and shader != null and shader.code.length() > 20 and shader.get_shader_uniform_list() is Array
					ok = ok and (row.kind != "shader" or shader.resource_path == row.shader)
				else:
					ok = ok and row.kind == "resource" and material is StandardMaterial3D
				for key in row.textures:
					ok = ok and (material as ShaderMaterial).get_shader_parameter(key) is Texture2D
			_:
				ok = ok and material is StandardMaterial3D
		check(ok, "role " + role + " resolves to one shared, compiled material")
		resolved += 1 if ok else 0
	check(resolved == Slots.SLOTS.size() and resolved >= 13, "every role resolved (%d)" % resolved)
	var stripe := PaletteMaterials.hazard_stripe()
	var image := stripe.albedo_texture.get_image()
	var one := image.get_pixel(0, 0)
	var two := image.get_pixel(image.get_width() / 4, 0)
	check(stripe == PaletteMaterials.slot_material("hazard_stripe") and stripe.get_meta("greybox_checker", false) and one != two and one.is_equal_approx(Palette.HAZARD) and two.is_equal_approx(Palette.CHARCOAL), "hazard stripe is one cached material with the greybox_checker meta and two sampleable colours")
	check(Palette.ANCIENT.to_html(false) == "9dff3c", "ANCIENT is uranium-glass green #9dff3c")
	var ancient_ok := not Slots.ancient_roles().is_empty()
	for role in Slots.ancient_roles():
		ancient_ok = ancient_ok and String(Slots.SLOTS[role].get("pattern", "")) != ""
	check(ancient_ok, "every ancient slot has a pattern cue")
	var code := (PaletteMaterials.slot_material("ancient_lens") as ShaderMaterial).shader.code
	check(code.contains("float chevron") and code.contains("glow = lens * (1.0 - chevron"), "the ancient lens shader carries the chevron term the pattern field names")
	var ground := PaletteMaterials.ground_material()
	var rock := PaletteMaterials.rock_material()
	check(ground != rock and ground.get_shader_parameter("cliff_only") == false and rock.get_shader_parameter("cliff_only") == true and ground.shader == rock.shader, "ground and rock share the sandstone shader and differ by the cliff flag")
	var floor_map := ground.get_shader_parameter("floor_map") as Texture2D
	var probe := floor_map.get_image()
	if probe.is_compressed():
		probe.decompress()
	probe.resize(1, 1, Image.INTERPOLATE_BILINEAR)
	var mean := probe.get_pixel(0, 0)
	check(mean.h > 0.07 and mean.h < 0.14 and mean.s > 0.3 and mean.s < 0.65, "the floor map's mean hue stays in the sand band (h %.3f s %.3f)" % [mean.h, mean.s])
	print("material_slots_test: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)


func _unique(items: Array) -> Dictionary:
	var seen := {}
	for item in items:
		seen[item] = true
	return seen
