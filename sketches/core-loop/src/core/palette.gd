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
# Fleet-grade cobalt, the item ladder's blue rung (23 Oct 19:28Z): the Cherenkov blue measured on
# 9 Oct at dE 31 or more from every palette colour in all vision types, free since ANCIENT moved.
const COBALT := Color("3d8bff")
# Uranium-glass green: the ancients' light (Andrew, 2026-10-09, over Cherenkov blue). Deuteranopes
# read it as Brindle's BRASS, so every ancient seam also carries a pattern cue (material_slots.gd,
# the `pattern` field).
const ANCIENT := Color("9dff3c")
# Cable runs and hoses: darker than CHARCOAL's panels so a coil never reads as white plastic.
const CABLE := Color("2a3231")
# Outside the greybox palette on purpose: a klaxon has to read as nothing else on screen.
const HAZARD := Color("ff5a3c")
# Admiral Brindle's brass: every boss fact wears it.
const BRASS := Color("d9b44a")
# Tally's ledger-paper cream: a pilot's colour, kept off the hostile hues.
const LEDGER := Color("e6d9b8")
# "Not yet": out of range, a glancing hit, a locked thing. Cool, so no warm colour shares it.
const SLATE := Color("6f7f8f")
# Slate as a word on the moving world (the event warning line): the same cool hue, light enough to
# hold 4.5 to 1 inside the HUD's dark outline, which SLATE (5.1 to 1 against pure black) cannot (UA-04).
const SLATE_INK := Color("a3b3c3")
# Worn steel: the cog, the money, and the grey panels' hardware (W1-21). Neutral and light, so it is
# neither Brindle's brass nor the relic's amber to any eye, nor slate's cool "not yet".
const STEEL := Color("9aa0a0")
# Weathered steel uprights, warmer and lighter than STEEL: the Slag Bowl's crane masts against its copper ramps.
const MAST_STEEL := Color("b7b6a3")
# Frost and ice reads in models and icons (VISUAL-LANGUAGE section 2 extension).
const ICE := Color("c8f0ff")
# Icon-only inks (tools/icons/generate_icons.py): ash for Redjaw, the ledger page's light, and the older verdigris.
const REDJAW_ASH := Color("5e5a54")
const LEDGER_CREAM := Color("f7f1e3")
const OLD_VERDIGRIS := Color("4f7f7a")


# The colour of "your verb works on this right now". Mint for every pilot until a swatch
# card lets Rivet and Kest have their own; the pilot's class colour stays for identity.
static func live(_class_def = null) -> Color:
	return ARC


# One shared texture per checker: drawing one pixel by pixel cost 4 ms of the boss-entry frame.
static var _checkers := {}


static func drop_checkers() -> void:
	_checkers.clear()


static func checker_texture(a: Color, b: Color, cells := 8, size := 128) -> ImageTexture:
	var key := [a, b, cells, size]
	if _checkers.has(key):
		return _checkers[key]
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var cell := size / cells
	for y in size:
		for x in size:
			var on := ((x / cell) + (y / cell)) % 2 == 0
			image.set_pixel(x, y, a if on else b)
	image.generate_mipmaps()
	_checkers[key] = ImageTexture.create_from_image(image)
	return _checkers[key]


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
	_look_jobs.erase(key)
	var source := load("res://assets/textures/%s.webp" % id) as Texture2D
	if source == null:
		push_warning("palette: missing look texture " + id)
		return painted_texture(128)
	if not neutral:
		_look_textures[key] = source
		return source
	var job := _neutral_job(source)
	if job.is_empty():
		push_warning("palette: unreadable look texture " + id)
		return painted_texture(128)
	_neutral_rows(job, job.image.get_height())
	return _neutral_done(key, job)


# A neutral look texture a few rows a call, so a warm can make one off the frame that first draws it:
# the whole 512 px map takes a 60-80 ms call on the cloud. True once look_texture(id, true) is ready.
const LOOK_ROWS_PER_CALL := 32
static var _look_jobs := {}


static func warm_look(id: String) -> bool:
	var key := id + ":neutral"
	if _look_textures.has(key):
		return true
	if not _look_jobs.has(key):
		var source := load("res://assets/textures/%s.webp" % id) as Texture2D
		var job := _neutral_job(source) if source != null else {}
		if job.is_empty():
			# Missing or unreadable: the fallback stands in, warned once, not re-read every warm tick.
			_look_textures[key] = look_texture(id, true)
			return true
		_look_jobs[key] = job
		return false
	var job: Dictionary = _look_jobs[key]
	if job.row < job.image.get_height():
		_neutral_rows(job, LOOK_ROWS_PER_CALL)
		return false
	_look_jobs.erase(key)
	_neutral_done(key, job)
	return true


static func _neutral_job(source: Texture2D) -> Dictionary:
	var image := source.get_image()
	if image == null:
		return {}
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGB8)
	var probe := image.duplicate() as Image
	probe.resize(1, 1, Image.INTERPOLATE_BILINEAR)
	var mean := probe.get_pixel(0, 0).get_luminance()
	return {"image": image, "gain": 0.85 / maxf(mean, 0.05), "row": 0}


static func _neutral_rows(job: Dictionary, rows: int) -> void:
	var image: Image = job.image
	var gain: float = job.gain
	var end := mini(job.row + rows, image.get_height())
	for y in range(job.row, end):
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			var l := c.get_luminance()
			var grey := Color(l, l, l).lerp(c, 0.35)
			image.set_pixel(x, y, Color(minf(grey.r * gain, 1.0), minf(grey.g * gain, 1.0), minf(grey.b * gain, 1.0)))
	job.row = end


static func _neutral_done(key: String, job: Dictionary) -> Texture2D:
	var image: Image = job.image
	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	_look_textures[key] = texture
	return texture


const SLOT_TABLE := preload("res://src/presentation/material_slots.gd")
static var _slot_materials := {}


# A slot param that names a palette constant ("HAZARD") resolves to its Color.
static func _slot_value(value):
	if value is String:
		var constants: Dictionary = (load("res://src/core/palette.gd") as GDScript).get_script_constant_map()
		if constants.get(value) is Color:
			return constants[value]
	return value


# The role's shared material, built once from its material_slots.gd row.
static func slot_material(role: String) -> Material:
	if _slot_materials.has(role):
		return _slot_materials[role]
	var row: Dictionary = SLOT_TABLE.row(role)
	if row.is_empty():
		push_warning("palette: unknown material slot " + role)
		return null
	var mat: Material
	match row.kind:
		"resource":
			mat = load(row.path) as Material
		"standard":
			mat = _standard_slot(row)
		_:
			var shader_mat := ShaderMaterial.new()
			shader_mat.shader = load(row.shader) as Shader
			for key in row.params:
				shader_mat.set_shader_parameter(key, _slot_value(row.params[key]))
			if row.triplanar_scale > 0.0:
				shader_mat.set_shader_parameter("strata_metres", row.triplanar_scale)
			for key in row.textures:
				shader_mat.set_shader_parameter(key, look_texture(row.textures[key]))
			mat = shader_mat
	if mat != null:
		mat.resource_name = role
	_slot_materials[role] = mat
	return mat


static func _standard_slot(row: Dictionary) -> StandardMaterial3D:
	var params: Dictionary = row.params
	var mat := StandardMaterial3D.new()
	mat.roughness = params.get("roughness", 0.8)
	mat.metallic = params.get("metallic", 0.0)
	if params.has("stripe_a"):
		if params.get("checker_meta", false):
			mat.set_meta("greybox_checker", true)
		mat.albedo_texture = stripe_texture(_slot_value(params.stripe_a), _slot_value(params.stripe_b))
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3.ONE / row.triplanar_scale
	else:
		mat.albedo_color = _slot_value(params.albedo)
	return mat


# terrain.gd:351 calls this: the ground role (sand floor, rock on steep faces).
static func ground_material() -> ShaderMaterial:
	return slot_material("ground") as ShaderMaterial


# The Highdraft's padded net edge: amber on charcoal bands, so it reads against the cream catch floor
# by value as well as hue. highdraft_scenery.net_edge_material returns it.
static func nosing_material() -> StandardMaterial3D:
	return slot_material("nosing") as StandardMaterial3D


# Rock only, no sand: cliff and mesa batches that must not take the floor's vertex tint.
static func rock_material() -> ShaderMaterial:
	return slot_material("rock") as ShaderMaterial


static func ball_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = checker_texture(AMBER, CHARCOAL, 6, 96)
	mat.roughness = 0.5
	mat.metallic = 0.2
	return mat


# `grain` false for a material that maps its own UV1 texture (a mask, an icon) or draws a flat
# read (an unshaded line): the grain's world-triplanar UVs would re-map that texture.
static func solid(color: Color, emit := 0.0, grain := true) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	# The flat-colour signature dress_material_test counts on a box, whatever surface it wears.
	mat.set_meta("palette_solid", true)
	if grain:
		surface_grain(mat)
	if emit > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emit
	return mat


static func striped(a: Color, b: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.set_meta("greybox_checker", true)
	mat.albedo_texture = checker_texture(a, b, 4, 64)
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.25, 0.25, 0.25)
	mat.roughness = 0.75
	return mat


# 45 degree bands, `a` at pixel (0, 0) and `b` at (size / 4, 0), the two places dress_props samples.
static func stripe_texture(a: Color, b: Color, size := 64) -> ImageTexture:
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var band := size / 4
	for y in size:
		for x in size:
			image.set_pixel(x, y, a if ((x + y) / band) % 2 == 0 else b)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


# Hostile means HAZARD plus 45 degree stripes (VISUAL-LANGUAGE.md): one material, shared by every
# hazard surface, so the stripe pitch and the two colours cannot drift between props.
static func hazard_stripe() -> StandardMaterial3D:
	return slot_material("hazard_stripe") as StandardMaterial3D


# The colour of water: verdigris leaning mint. Plain mint is kept for "your verb works here"
# and the common reward (colour_meanings.gd), so standing water never borrows it.
static func water_tone() -> Color:
	return VERDIGRIS.lerp(ARC, 0.35)


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
static var _sky_task := -1
static var _sky_out := {}
static var _sky_waiting: Array[PanoramaSkyMaterial] = []

# The painted panorama: the ending's sky, and the sky every stage shows until its look sets its own.
# Painting it takes 0.4 to 0.5 s of GDScript (cloud, exported build), so the boot (terrain.gd
# _build_sky) asks for it with paint_later: the material comes back bare and the worker's image
# fills it on the main thread when done. workshop_sky waits for a paint already running.
static func workshop_sky() -> PanoramaSkyMaterial:
	if _sky_texture == null:
		if _sky_task >= 0:
			WorkerThreadPool.wait_for_task_completion(_sky_task)
			_sky_task = -1
			_sky_texture = ImageTexture.create_from_image(_sky_out["image"])
		else:
			_sky_texture = ImageTexture.create_from_image(_paint_workshop_sky())
	return _sky_material(_sky_texture)


static func workshop_sky_later() -> PanoramaSkyMaterial:
	if _sky_texture != null:
		return workshop_sky()
	# Until the paint lands the sky is the panorama's horizon colour, not black.
	var horizon := Image.create_empty(1, 1, false, Image.FORMAT_RGB8)
	horizon.fill(Color("e6c898"))
	var material := _sky_material(ImageTexture.create_from_image(horizon))
	_sky_waiting.append(material)
	if _sky_task < 0:
		var out := {}
		_sky_out = out
		# High priority: queued behind the band's renders it could land seconds into play (PR #386; the 4080 hitch is inferred).
		_sky_task = WorkerThreadPool.add_task(func():
			out["image"] = _paint_workshop_sky()
			_fill_waiting_skies.call_deferred(), true, "workshop sky")
	return material


# A paint left unwaited when the engine quits aborts the process: the node that shows the sky (terrain.gd's
# WorldEnvironment) finishes it as it leaves the tree, which a quit does.
static func settle_sky_on_exit(owner: Node) -> void:
	owner.tree_exiting.connect(func():
		if _sky_task >= 0:
			workshop_sky(), CONNECT_ONE_SHOT)


static func _fill_waiting_skies() -> void:
	var texture := workshop_sky().panorama
	for material in _sky_waiting:
		material.panorama = texture
	_sky_waiting.clear()


static func _sky_material(texture: Texture2D) -> PanoramaSkyMaterial:
	var material := PanoramaSkyMaterial.new()
	material.panorama = texture
	material.energy_multiplier = 1.0
	return material


static func _paint_workshop_sky() -> Image:
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
	return image


const HDRI_SKY := "res://assets/sky/kloofendal_48d_partly_cloudy_puresky_2k.hdr"
const TIME_SKY := preload("res://src/presentation/time_sky.gdshader")
static var _hdri_sky: Sky

# The Poly Haven partly cloudy sky, one Sky for every world row that names "hdri". Its material is
# the time-of-day sky (time_sky.gdshader): the stage's time row sets its grade through the lighting
# stack (world_look.gd sky_rows), and its defaults draw the panorama unchanged.
static func hdri_sky() -> Sky:
	if _hdri_sky == null:
		_hdri_sky = Sky.new()
		_hdri_sky.sky_material = time_sky_material(load(HDRI_SKY))
	return _hdri_sky


static func time_sky_material(panorama: Texture2D) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = TIME_SKY
	material.set_shader_parameter("panorama", panorama)
	return material


static var _wear: ImageTexture
static var _oxide: ImageTexture
static var _grain_normal: ImageTexture
static var _grain_rough: ImageTexture
static var _grime: ImageTexture

# How a painted solid answers light, without touching its colour role: a fine hammered grain in
# the normals and roughness (so highlights break up instead of sliding across a flat face) and
# broad grime blotches a few shades darker (so no two faces of one prop share a value, as
# VISUAL-LANGUAGE "Scrappy" asks). World triplanar, so the grain is the same size on a bolt and
# a barge, and props with no UVs still wear it. One set of textures serves every solid.
const GRAIN_METRES := 0.5
const GRIME_METRES := 3.5

static func surface_grain(mat: StandardMaterial3D) -> void:
	if _grain_normal == null:
		var noise := FastNoiseLite.new()
		noise.seed = 4127
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.045
		noise.fractal_octaves = 3
		var bump := noise.get_seamless_image(128, 128, false, false, 0.1, false)
		var rough := bump.duplicate() as Image
		bump.bump_map_to_normal_map(8.0)
		bump.generate_mipmaps(true)
		_grain_normal = ImageTexture.create_from_image(bump)
		rough.convert(Image.FORMAT_L8)
		for y in rough.get_height():
			for x in rough.get_width():
				var v := rough.get_pixel(x, y).r
				rough.set_pixel(x, y, Color.from_hsv(0.0, 0.0, lerpf(0.72, 1.0, v)))
		rough.generate_mipmaps()
		_grain_rough = ImageTexture.create_from_image(rough)
		var blotch := FastNoiseLite.new()
		blotch.seed = 911
		blotch.frequency = 0.02
		blotch.fractal_octaves = 4
		var grime := blotch.get_seamless_image(128, 128, false, false, 0.1, false)
		grime.convert(Image.FORMAT_L8)
		for y in grime.get_height():
			for x in grime.get_width():
				var v := grime.get_pixel(x, y).r
				grime.set_pixel(x, y, Color.from_hsv(0.0, 0.0, lerpf(0.8, 1.0, smoothstep(0.25, 0.7, v))))
		grime.generate_mipmaps()
		_grime = ImageTexture.create_from_image(grime)
	mat.normal_enabled = true
	mat.normal_texture = _grain_normal
	mat.normal_scale = 0.6
	mat.roughness_texture = _grain_rough
	mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE / GRAIN_METRES
	mat.detail_enabled = true
	mat.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	mat.detail_albedo = _grime
	mat.detail_uv_layer = BaseMaterial3D.DETAIL_UV_2
	mat.uv2_triplanar = true
	mat.uv2_world_triplanar = true
	mat.uv2_scale = Vector3.ONE / GRIME_METRES


# Takes surface_grain off again, for a model that brings its own surface (BakeLook).
static func smooth(mat: StandardMaterial3D) -> void:
	if mat.normal_texture != _grain_normal or _grain_normal == null:
		return
	mat.normal_enabled = false
	mat.normal_texture = null
	mat.roughness_texture = null
	mat.uv1_triplanar = false
	mat.uv1_world_triplanar = false
	mat.uv1_scale = Vector3.ONE
	mat.detail_enabled = false
	mat.detail_albedo = null
	mat.uv2_triplanar = false
	mat.uv2_world_triplanar = false
	mat.uv2_scale = Vector3.ONE


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


static var _target_surfaces := {}
static var _target_clutter := {}

# The clutter kit's slots carry their colour in vertex colours (the paint slot) and the
# slot's albedo. The target copy is the clutter shader: albedo times vertex colour, fully
# rough, a contact shade at the foot, and the screen-space protection every other dressing
# piece has. It keeps the slot name; the kit's own resources stay untouched, and one copy
# serves every instance.
static func target_clutter_material(original: Material) -> ShaderMaterial:
	var key := original.get_instance_id()
	if _target_clutter.has(key):
		return _target_clutter[key]
	var mat := ShaderMaterial.new()
	mat.shader = load(SLOT_TABLE.row("clutter").shader) as Shader
	mat.set_shader_parameter("albedo", (original as StandardMaterial3D).albedo_color if original is StandardMaterial3D else Color.WHITE)
	mat.resource_name = original.resource_name
	_target_clutter[key] = mat
	return mat

# The shipped look per role. Ground and rock are the slot materials themselves (the sandstone
# shader); a role whose slot is a prebuilt resource (the Dig's stone) keeps its original; the dam
# wraps its imported surface. The role string is the contract with GraphicsPreset._apply_material.
static func target_surface_material(role: String, original: Material) -> ShaderMaterial:
	if is_slot_resource(original):
		return original as ShaderMaterial
	if role in SLOT_TABLE.SHIPPED_AS_SLOT:
		return slot_material(role) as ShaderMaterial
	var key := role + ":" + str(original.get_instance_id())
	if _target_surfaces.has(key):
		return _target_surfaces[key]
	var mat := ShaderMaterial.new()
	mat.shader = load(SLOT_TABLE.row(role).shader) as Shader
	if original is StandardMaterial3D:
		mat.set_shader_parameter("base_color", original.albedo_color)
		mat.set_shader_parameter("base_roughness", original.roughness)
		mat.set_shader_parameter("has_base_map", original.albedo_texture != null)
		if original.albedo_texture != null:
			mat.set_shader_parameter("base_map", original.albedo_texture)
	mat.resource_name = "target_" + role
	_target_surfaces[key] = mat
	return mat


# True for a prebuilt slot resource (the Dig stone and mechanicals): GraphicsPreset should keep these.
static func is_slot_resource(original: Material) -> bool:
	for role in SLOT_TABLE.SLOTS:
		var row: Dictionary = SLOT_TABLE.SLOTS[role]
		if row.kind == "resource" and original.resource_path == row.path:
			return true
	return false
