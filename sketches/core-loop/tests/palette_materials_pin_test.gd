extends SceneTree

# Pixel digests hold on macOS only, where they were recorded: the painted noise and sky run float work that may
# differ in the last bit on the Linux build.

const T := preload("res://tests/support/t.gd")
const Palette := preload("res://src/core/palette.gd")
const PaletteMaterials := preload("res://src/presentation/palette_materials.gd")
const Slots := preload("res://src/presentation/material_slots.gd")

const PINS := {
	"ball_material": ["6e775fa79e147dd8", "e1407fd99135c510"],
	"brass_finish": ["48ebcae25c282718", "e3b0c44298fc1c14"],
	"checker_amber_charcoal_6_96": ["529bfc2ecc735305", "e1407fd99135c510"],
	"checker_arc_cable_4_64": ["05985ecf9c159764", "49839a58824eff3f"],
	"checker_sand_rust_default": ["8e112b21cac4c5b6", "24ff82b430b98b4e"],
	"enamel_wear": ["b981193233afc79d", "4accd45e02710495"],
	"ground_material": ["7e2b0f5a4542fae1", "e3b0c44298fc1c14"],
	"hazard_stripe": ["baaecf87d4d4d863", "482b42c685d76cf4"],
	"hdri_sky": ["a13fac4825cb69a7", "e3b0c44298fc1c14"],
	"is_slot_resource": ["c51c4d23c8e2bcee", "e3b0c44298fc1c14"],
	"look_plate_neutral": ["d0ecfe8386a01400", "93930aff72f2c5ea"],
	"look_plate_worn_neutral": ["d0ecfe8386a01400", "c73dca01fe302e29"],
	"look_sandstone_strata": ["85533c8f2eb1a708", "e3b0c44298fc1c14"],
	"nosing_material": ["89f765915b5f3e80", "62f99de6cc08e409"],
	"painted_128": ["8e112b21cac4c5b6", "9fc8a1d2de1489d2"],
	"painted_256": ["59d437db935c7bbd", "e06e8d966d26614d"],
	"painted_256_ground": ["59d437db935c7bbd", "6d5c06f8396a7cd5"],
	"painted_64_ground": ["05985ecf9c159764", "c34fa52ab5f73174"],
	"rock_material": ["7fa2f759aa693fae", "e3b0c44298fc1c14"],
	"slot_air": ["ed2bec058857da41", "e3b0c44298fc1c14"],
	"slot_ancient_lens": ["1087306d272bfacc", "e3b0c44298fc1c14"],
	"slot_cable": ["14df8dffc5218944", "e3b0c44298fc1c14"],
	"slot_clutter": ["6fcd1fc6d7f19883", "e3b0c44298fc1c14"],
	"slot_concrete": ["19b2a93630a9a7ab", "e3b0c44298fc1c14"],
	"slot_dam": ["64cd0051d274e696", "e3b0c44298fc1c14"],
	"slot_dressing": ["eaf9857f5cf324eb", "e3b0c44298fc1c14"],
	"slot_elastomer": ["69fe38d6b8c4e1c4", "e3b0c44298fc1c14"],
	"slot_enamel": ["689995d454af1cb4", "e3b0c44298fc1c14"],
	"slot_glass": ["b25add517f09185d", "e3b0c44298fc1c14"],
	"slot_ground": ["7e2b0f5a4542fae1", "e3b0c44298fc1c14"],
	"slot_hazard_stripe": ["baaecf87d4d4d863", "482b42c685d76cf4"],
	"slot_nosing": ["89f765915b5f3e80", "62f99de6cc08e409"],
	"slot_rock": ["7fa2f759aa693fae", "e3b0c44298fc1c14"],
	"slot_steel": ["bec633c2c42e40a5", "e3b0c44298fc1c14"],
	"slot_stone": ["bcda078b41ac6f8f", "e3b0c44298fc1c14"],
	"smooth_solid": ["a0b58aececd873b0", "e3b0c44298fc1c14"],
	"solid_amber_emit_2": ["abe00f0ccbc49745", "0f1cd1b43df5bc56"],
	"solid_brass": ["4d6e728596b6048b", "0f1cd1b43df5bc56"],
	"solid_brass_emit_flat": ["51ab7d78848cd509", "e3b0c44298fc1c14"],
	"solid_hazard_alpha": ["6eddc62524ef052a", "0f1cd1b43df5bc56"],
	"solid_rust_flat": ["c1fc5177d5ba16b4", "e3b0c44298fc1c14"],
	"solid_sand": ["2ffe4d897eab13bf", "0f1cd1b43df5bc56"],
	"stripe_texture_32": ["552eb80dbb64f1bf", "36c56d11eb9926e9"],
	"stripe_texture_default": ["05985ecf9c159764", "482b42c685d76cf4"],
	"striped_hazard_ledger": ["911b6c9bd6566323", "20eefb2e067caea5"],
	"striped_sand_charcoal": ["911b6c9bd6566323", "b67892cdb179867d"],
	"surface_grain": ["c812aa11c452a117", "0f1cd1b43df5bc56"],
	"target_clutter": ["76772734b4283f44", "e3b0c44298fc1c14"],
	"target_surface_concrete": ["9b703880cee2eb7f", "e3b0c44298fc1c14"],
	"target_surface_dam": ["c77fe5f196ecb9d0", "e3b0c44298fc1c14"],
	"target_surface_dam_mapped": ["639b4142cbd861e6", "e1407fd99135c510"],
	"target_surface_ground": ["7e2b0f5a4542fae1", "e3b0c44298fc1c14"],
	"time_sky_checker": ["add9be4564726377", "24ff82b430b98b4e"],
	"unshaded_amber_alpha": ["e47bf7341e85cd42", "e3b0c44298fc1c14"],
	"unshaded_arc": ["354ac5c7f4ca9a96", "e3b0c44298fc1c14"],
	"warm_look_gyro_true": ["d0ecfe8386a01400", "ebce46906ce0f9be"],
	"water_cobalt": ["b3fd928d70879b9a", "e3b0c44298fc1c14"],
	"water_verdigris": ["5b808c271670a7f0", "e3b0c44298fc1c14"],
	"workshop_sky": ["933adb43a41d34ef", "4f021d1f88b1afa3"],
	"workshop_sky_again": ["933adb43a41d34ef", "4f021d1f88b1afa3"],
	"workshop_sky_later_first": ["12bdb64dea836c66", "0c725a8b1ee60ea5"],
}


func _initialize() -> void:
	var t := T.new("palette_materials_pin_test")
	var got := _cases()
	var names := got.keys()
	names.sort()
	var want := PINS.keys()
	want.sort()
	t.eq("the cases built equal exactly the pinned list", names, want)
	var mac := OS.get_name() == "macOS"
	if not mac:
		t.skip("pixel digests", "pinned on macOS only")
	for name in names:
		var digest: Array = got[name]
		var pin: Array = PINS.get(name, ["", ""])
		t.check("%s shape" % name, digest[0] == pin[0], "got %s, want %s" % [digest[0], pin[0]])
		if mac:
			t.check("%s pixels" % name, digest[1] == pin[1], "got %s, want %s" % [digest[1], pin[1]])
	quit(t.verdict())


func _cases() -> Dictionary:
	var out := {}
	out["checker_amber_charcoal_6_96"] = _resource(PaletteMaterials.checker_texture(Palette.AMBER, Palette.CHARCOAL, 6, 96))
	out["checker_sand_rust_default"] = _resource(PaletteMaterials.checker_texture(Palette.SAND, Palette.RUST))
	out["checker_arc_cable_4_64"] = _resource(PaletteMaterials.checker_texture(Palette.ARC, Palette.CABLE, 4, 64))
	out["painted_256"] = _resource(PaletteMaterials.painted_texture())
	out["painted_128"] = _resource(PaletteMaterials.painted_texture(128))
	out["painted_256_ground"] = _resource(PaletteMaterials.painted_texture(256, true))
	out["painted_64_ground"] = _resource(PaletteMaterials.painted_texture(64, true))
	out["look_sandstone_strata"] = _resource(PaletteMaterials.look_texture("sandstone-strata"))
	out["look_plate_worn_neutral"] = _resource(PaletteMaterials.look_texture("rusted-salvaged-plate-worn", true))
	out["look_plate_neutral"] = _resource(PaletteMaterials.look_texture("rusted-salvaged-plate", true))
	var warmed := false
	for i in 4096:
		if PaletteMaterials.warm_look("riveted-gyro-metal"):
			warmed = true
			break
	out["warm_look_gyro_" + str(warmed)] = _resource(PaletteMaterials.look_texture("riveted-gyro-metal", true))
	var roles := Slots.SLOTS.keys()
	roles.sort()
	for role in roles:
		out["slot_" + role] = _resource(PaletteMaterials.slot_material(role))
	out["ground_material"] = _resource(PaletteMaterials.ground_material())
	out["nosing_material"] = _resource(PaletteMaterials.nosing_material())
	out["rock_material"] = _resource(PaletteMaterials.rock_material())
	out["hazard_stripe"] = _resource(PaletteMaterials.hazard_stripe())
	out["ball_material"] = _resource(PaletteMaterials.ball_material())
	out["solid_sand"] = _resource(PaletteMaterials.solid(Palette.SAND))
	out["solid_brass"] = _resource(PaletteMaterials.solid(Palette.BRASS))
	out["solid_amber_emit_2"] = _resource(PaletteMaterials.solid(Palette.AMBER, 2.0))
	out["solid_rust_flat"] = _resource(PaletteMaterials.solid(Palette.RUST, 0.0, false))
	out["solid_brass_emit_flat"] = _resource(PaletteMaterials.solid(Palette.BRASS, 1.5, false))
	out["solid_hazard_alpha"] = _resource(PaletteMaterials.solid(Color(Palette.HAZARD, 0.4), 0.5))
	var finished := StandardMaterial3D.new()
	PaletteMaterials.brass_finish(finished)
	out["brass_finish"] = _resource(finished)
	out["striped_sand_charcoal"] = _resource(PaletteMaterials.striped(Palette.SAND, Palette.CHARCOAL))
	out["striped_hazard_ledger"] = _resource(PaletteMaterials.striped(Palette.HAZARD, Palette.LEDGER))
	out["stripe_texture_default"] = _resource(PaletteMaterials.stripe_texture(Palette.HAZARD, Palette.CHARCOAL))
	out["stripe_texture_32"] = _resource(PaletteMaterials.stripe_texture(Palette.AMBER, Palette.SLATE, 32))
	out["water_verdigris"] = _resource(PaletteMaterials.water(Palette.VERDIGRIS))
	out["water_cobalt"] = _resource(PaletteMaterials.water(Palette.COBALT))
	out["unshaded_arc"] = _resource(PaletteMaterials.unshaded(Palette.ARC))
	out["unshaded_amber_alpha"] = _resource(PaletteMaterials.unshaded(Color(Palette.AMBER, 0.55)))
	var later := PaletteMaterials.workshop_sky_later()
	out["workshop_sky_later_first"] = _resource(later)
	out["workshop_sky"] = _resource(PaletteMaterials.workshop_sky())
	out["workshop_sky_again"] = _resource(PaletteMaterials.workshop_sky_later())
	out["hdri_sky"] = _resource(PaletteMaterials.hdri_sky())
	out["time_sky_checker"] = _resource(PaletteMaterials.time_sky_material(PaletteMaterials.checker_texture(Palette.SAND, Palette.RUST)))
	var grained := StandardMaterial3D.new()
	grained.albedo_color = Palette.COPPER
	PaletteMaterials.surface_grain(grained)
	out["surface_grain"] = _resource(grained)
	var smoothed := PaletteMaterials.solid(Palette.STEEL)
	PaletteMaterials.smooth(smoothed)
	out["smooth_solid"] = _resource(smoothed)
	var worn := PaletteMaterials.solid(Palette.VERDIGRIS)
	PaletteMaterials.enamel_wear(worn)
	out["enamel_wear"] = _resource(worn)
	var plain := StandardMaterial3D.new()
	plain.albedo_color = Palette.SANDSTONE
	plain.resource_name = "plain"
	out["target_clutter"] = _resource(PaletteMaterials.target_clutter_material(plain))
	var surface_roles := ["dam", "concrete", "stone", "steel", "ground"]
	for role in surface_roles:
		if Slots.SLOTS.has(role) and Slots.SLOTS[role].get("shader", "") != "":
			out["target_surface_" + role] = _resource(PaletteMaterials.target_surface_material(role, plain))
	var mapped := StandardMaterial3D.new()
	mapped.albedo_texture = PaletteMaterials.checker_texture(Palette.AMBER, Palette.CHARCOAL, 6, 96)
	mapped.roughness = 0.3
	out["target_surface_dam_mapped"] = _resource(PaletteMaterials.target_surface_material("dam", mapped))
	var resource_roles := []
	for role in roles:
		if Slots.SLOTS[role].kind == "resource":
			resource_roles.append(role)
	var flags := resource_roles.map(func(role): return PaletteMaterials.is_slot_resource(PaletteMaterials.slot_material(role)))
	out["is_slot_resource"] = [_hash(str(resource_roles) + str(flags) + str(PaletteMaterials.is_slot_resource(plain))), _hash("")]
	return out


func _resource(resource: Resource) -> Array:
	var shape := PackedStringArray()
	var pixels := PackedStringArray()
	_walk(resource, shape, pixels, 0)
	return [_hash("\n".join(shape)), _hash("\n".join(pixels))]


func _walk(value: Variant, shape: PackedStringArray, pixels: PackedStringArray, depth: int) -> void:
	if value == null:
		shape.append("null")
		return
	if not (value is Object):
		shape.append(var_to_str(value))
		return
	var resource := value as Resource
	shape.append("%s path=%s name=%s" % [resource.get_class(), resource.resource_path, resource.resource_name])
	if depth > 3:
		return
	if resource is Texture2D:
		var texture := resource as Texture2D
		shape.append("size=%dx%d" % [texture.get_width(), texture.get_height()])
		if resource is ImageTexture or resource is PlaceholderTexture2D:
			var image := texture.get_image()
			if image != null:
				shape.append("format=%d mipmaps=%s" % [image.get_format(), image.has_mipmaps()])
				pixels.append(_hash_bytes(image.get_data()))
		return
	if resource is Shader:
		shape.append(_hash((resource as Shader).code))
		return
	if resource is ShaderMaterial:
		var shader_mat := resource as ShaderMaterial
		_walk(shader_mat.shader, shape, pixels, depth + 1)
		if shader_mat.shader != null:
			for uniform in shader_mat.shader.get_shader_uniform_list():
				shape.append("param " + uniform.name)
				_walk(shader_mat.get_shader_parameter(uniform.name), shape, pixels, depth + 1)
	for property in resource.get_property_list():
		if not (property.usage & PROPERTY_USAGE_STORAGE):
			continue
		if String(property.name).begins_with("shader_parameter/"):
			continue
		shape.append("prop " + property.name)
		_walk(resource.get(property.name), shape, pixels, depth + 1)
	for key in resource.get_meta_list():
		shape.append("meta %s=%s" % [key, var_to_str(resource.get_meta(key))])


func _hash(text: String) -> String:
	return text.sha256_text().substr(0, 16)


func _hash_bytes(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode().substr(0, 16)
