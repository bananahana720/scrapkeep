extends RefCounted


static func checker_texture(a: Color, b: Color, cells := 8, size := 128) -> ImageTexture:
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var cell := size / cells
	for y in size:
		for x in size:
			var on := ((x / cell) + (y / cell)) % 2 == 0
			image.set_pixel(x, y, a if on else b)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


static func ground_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = checker_texture(Color(0.30, 0.34, 0.38), Color(0.40, 0.45, 0.50))
	# Triplanar keeps the check square on slopes, which is what makes speed readable.
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.09, 0.09, 0.09)
	mat.roughness = 0.95
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return mat


static func ball_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = checker_texture(Color(0.95, 0.72, 0.18), Color(0.16, 0.18, 0.22), 6, 96)
	mat.roughness = 0.5
	mat.metallic = 0.15
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
