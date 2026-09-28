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
# Cherenkov seams belong to awakened ancient machines.
const ANCIENT := Color("3d8bff")
# Outside the greybox palette on purpose: a klaxon has to read as nothing else on screen.
const HAZARD := Color("ff5a3c")
# Admiral Brindle's brass: every boss fact wears it.
const BRASS := Color("d9b44a")


static func checker_texture(a: Color, b: Color, cells := 8, size := 128) -> ImageTexture:
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var cell := size / cells
	for y in size:
		for x in size:
			var on := ((x / cell) + (y / cell)) % 2 == 0
			image.set_pixel(x, y, a if on else b)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


# Neutral painted value variation multiplies the existing surface-role vertex tint.
static var _painted_textures := {}


static func painted_texture(size := 256, ground := false) -> ImageTexture:
	var key := str(size) + ":" + str(ground)
	if _painted_textures.has(key):
		return _painted_textures[key]
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 270927
	noise.frequency = 0.014 if ground else 0.027
	noise.fractal_octaves = 1 if ground else 3
	for y in size:
		for x in size:
			var broad := noise.get_noise_2d(x, y)
			var value := 0.93 + broad * 0.10 + noise.get_noise_2d(x * 4.0, y * 13.0) * 0.025
			if not ground:
				var brush := noise.get_noise_2d(x * 1.8 + 73.0, y * 7.0)
				var grain := noise.get_noise_2d(x * 9.0, y * 9.0)
				value = 0.87 + broad * 0.16 + brush * 0.055 + grain * 0.025
			value = clampf(value, 0.66, 1.0)
			image.set_pixel(x, y, Color(value, value, value))
	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	_painted_textures[key] = texture
	return texture


static var _ground: StandardMaterial3D

static func ground_material() -> StandardMaterial3D:
	if _ground != null:
		return _ground
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = painted_texture(256, true)
	mat.vertex_color_use_as_albedo = true
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.14, 0.14, 0.14)
	mat.albedo_color = Color("f7e3c4")
	mat.roughness = 0.96
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_ground = mat
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


static var _sky_texture: ImageTexture

static func workshop_sky() -> PanoramaSkyMaterial:
	if _sky_texture == null:
		var image := Image.create_empty(1024, 512, false, Image.FORMAT_RGB8)
		var noise := FastNoiseLite.new()
		noise.seed = 280928
		noise.frequency = 1.0
		noise.fractal_octaves = 3
		for y in 512:
			var elevation := (0.5 - float(y) / 511.0) * PI
			for x in 1024:
				var angle := float(x) / 1024.0 * TAU
				var direction := Vector3(cos(angle) * cos(elevation), sin(elevation), sin(angle) * cos(elevation))
				var color := Color("b5cadb").lerp(Color("447cba"), clampf(elevation * 1.25, 0.0, 1.0))
				var ridge := 0.035 + 0.065 * noise.get_noise_2d(cos(angle) * 4.0, sin(angle) * 4.0)
				var far_ridge := ridge + 0.045 + 0.035 * noise.get_noise_2d(cos(angle) * 11.0, sin(angle) * 11.0)
				if elevation < far_ridge:
					color = Color("8aacc5")
				if elevation < ridge:
					color = Color("66869f")
				if elevation > 0.12:
					var cloud := noise.get_noise_3d(direction.x * 7.0, direction.y * 16.0, direction.z * 7.0)
					var coverage := smoothstep(0.1, 0.4, cloud) * smoothstep(0.12, 0.28, elevation)
					color = color.lerp(Color("f5eedc"), coverage * 0.88)
				image.set_pixel(x, y, color)
		image.generate_mipmaps()
		_sky_texture = ImageTexture.create_from_image(image)
	var material := PanoramaSkyMaterial.new()
	material.panorama = _sky_texture
	return material


static var _wear: ImageTexture
static var _oxide: ImageTexture

static func enamel_wear(mat: StandardMaterial3D) -> void:
	if _wear == null:
		var mask := Image.create_empty(128, 128, false, Image.FORMAT_RGB8)
		var oxide := Image.create_empty(8, 8, false, Image.FORMAT_RGB8)
		oxide.fill(COPPER.lerp(RUST, 0.55))
		var noise := FastNoiseLite.new()
		noise.seed = 81
		noise.frequency = 0.13
		for y in 128:
			for x in 128:
				var amount := smoothstep(0.18, 0.32, noise.get_noise_2d(x, y)) * 0.85
				mask.set_pixel(x, y, Color(amount, amount, amount))
		mask.generate_mipmaps()
		oxide.generate_mipmaps()
		_wear = ImageTexture.create_from_image(mask)
		_oxide = ImageTexture.create_from_image(oxide)
	mat.detail_enabled = true
	mat.detail_albedo = _oxide
	mat.detail_mask = _wear
	mat.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MIX
