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
# "Not yet": out of range, a glancing hit, a locked thing. Cool, so no warm colour shares it.
const SLATE := Color("6f7f8f")


# The colour of "your verb works on this right now". Mint for every pilot until a swatch
# card lets Rivet and Kest have their own; the pilot's class colour stays for identity.
static func live(_class_def = null) -> Color:
	return ARC


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


# Look pass 3 albedo maps live in assets/textures as small webp files and load once at
# as imported resources (the committed .import files turn mipmaps on), so exports carry them.
static var _look_textures := {}

# neutral: keeps the map's value pattern but mutes its hue and lifts its mean to about
# 0.85, for surfaces whose colour already comes from vertex colours (no double tint).
static func look_texture(id: String, neutral := false) -> Texture2D:
	var key := id + (":neutral" if neutral else "")
	if _look_textures.has(key):
		return _look_textures[key]
	var source := load("res://assets/textures/%s.webp" % id) as Texture2D
	if source == null:
		push_warning("palette: missing look texture " + id)
		return painted_texture(128)
	if not neutral:
		_look_textures[key] = source
		return source
	var image := source.get_image()
	if image == null:
		push_warning("palette: unreadable look texture " + id)
		return painted_texture(128)
	if image.is_compressed():
		image.decompress()
	if neutral:
		image.convert(Image.FORMAT_RGB8)
		var probe := image.duplicate() as Image
		probe.resize(1, 1, Image.INTERPOLATE_BILINEAR)
		var mean := probe.get_pixel(0, 0).get_luminance()
		var gain := 0.85 / maxf(mean, 0.05)
		for y in image.get_height():
			for x in image.get_width():
				var c := image.get_pixel(x, y)
				var l := c.get_luminance()
				var grey := Color(l, l, l).lerp(c, 0.35)
				image.set_pixel(x, y, Color(minf(grey.r * gain, 1.0), minf(grey.g * gain, 1.0), minf(grey.b * gain, 1.0)))
	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	_look_textures[key] = texture
	return texture


static var _ground: ShaderMaterial

static func ground_material() -> ShaderMaterial:
	if _ground == null:
		_ground = ShaderMaterial.new()
		_ground.shader = preload("res://src/presentation/sandstone.gdshader")
		_ground.set_shader_parameter("strata_map", look_texture("sandstone-strata"))
		_ground.set_shader_parameter("floor_map", look_texture("packed-sand-floor"))
	return _ground


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
				var color := Color("e6c898").lerp(Color("4a78a8"), clampf(elevation * 1.6, 0.0, 1.0))
				var ridge := 0.035 + 0.065 * noise.get_noise_2d(cos(angle) * 4.0, sin(angle) * 4.0)
				var far_ridge := ridge + 0.045 + 0.035 * noise.get_noise_2d(cos(angle) * 11.0, sin(angle) * 11.0)
				if elevation < far_ridge:
					color = Color("93aecb")
				if elevation < ridge:
					color = Color("7d9dc0")
				if elevation > 0.12:
					var cloud := noise.get_noise_3d(direction.x * 7.0, direction.y * 16.0, direction.z * 7.0)
					var coverage := smoothstep(0.22, 0.5, cloud) * smoothstep(0.14, 0.34, elevation)
					color = color.lerp(Color("ebe1cb"), coverage * 0.8)
				image.set_pixel(x, y, color)
		image.generate_mipmaps()
		_sky_texture = ImageTexture.create_from_image(image)
	var material := PanoramaSkyMaterial.new()
	material.panorama = _sky_texture
	material.energy_multiplier = 1.0
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
