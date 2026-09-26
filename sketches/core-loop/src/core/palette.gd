extends RefCounted

# The Bible palette, so a greybox still reads as steam-cyberpunk Southwest.
const SAND := Color("d2c5a5")
const SANDSTONE := Color("c6a274")
const RUST := Color("9b513a")
const COPPER := Color("b77843")
const CHARCOAL := Color("242a28")
const VERDIGRIS := Color("365754")
const AMBER := Color("e5a044")
const ARC := Color("8bf0d3")
# Outside the greybox palette on purpose: a klaxon has to read as nothing else on screen.
const HAZARD := Color("ff5a3c")


static func checker_texture(a: Color, b: Color, cells := 8, size := 128) -> ImageTexture:
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var cell := size / cells
	for y in size:
		for x in size:
			var on := ((x / cell) + (y / cell)) % 2 == 0
			image.set_pixel(x, y, a if on else b)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


# The ground is tinted per vertex by which surface it is (shelf, chute, bypass),
# so one mesh carries three readable materials without a second surface.
static func ground_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = checker_texture(Color(1.0, 1.0, 1.0), Color(0.72, 0.72, 0.74))
	mat.vertex_color_use_as_albedo = true
	# Triplanar keeps the check square on slopes, which is what makes speed readable.
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.11, 0.11, 0.11)
	mat.roughness = 0.95
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return mat


static func ball_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = checker_texture(AMBER, CHARCOAL, 6, 96)
	mat.roughness = 0.5
	mat.metallic = 0.2
	return mat


static func solid(color: Color, emit := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	if emit > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emit
	return mat


static func striped(a: Color, b: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = checker_texture(a, b, 4, 64)
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.25, 0.25, 0.25)
	mat.roughness = 0.75
	return mat


static func water(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.62)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.12
	mat.metallic = 0.3
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.25
	return mat


static func unshaded(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat
