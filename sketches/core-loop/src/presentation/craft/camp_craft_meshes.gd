class_name CampCraftMeshes
extends RefCounted

const Palette := preload("res://src/core/palette.gd")
const HeroSculptor := preload("res://src/presentation/craft/hero_kitbash_sculptor.gd")
const CraftLookdev := preload("res://src/presentation/craft/craft_lookdev.gd")
const FlashGuard := preload("res://src/core/flash_guard.gd")

static var _mesh_cache: Dictionary = {}
static var _mat_cache: Dictionary = {}


static func reset_for_tests() -> void:
	_mesh_cache.clear()
	_mat_cache.clear()


static func _add_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, c0: Color, c1: Color, c2: Color, c3: Color, uv_scale := 0.25) -> void:
	HeroSculptor.add_planar_tri(st, a, b, c, n, c0, c1, c2, uv_scale)
	HeroSculptor.add_planar_tri(st, a, c, d, n, c0, c2, c3, uv_scale)


static func add_bevel_box(st: SurfaceTool, center: Vector3, size: Vector3, bevel: float, uv_scale: float, xf: Transform3D, c_flat: Color, c_edge: Color, c_bot: Color) -> void:
	var h := size * 0.5
	var b := minf(bevel, minf(h.x, minf(h.y, h.z)) * 0.42)
	var xi := h.x - b
	var yi := h.y - b
	var zi := h.z - b
	var pt := func(x: float, y: float, z: float) -> Vector3:
		return xf * (center + Vector3(x, y, z))
	var nrm := func(v: Vector3) -> Vector3:
		return (xf.basis * v).normalized()

	_add_quad(st, pt.call(-xi, -yi, h.z), pt.call(xi, -yi, h.z), pt.call(xi, yi, h.z), pt.call(-xi, yi, h.z), nrm.call(Vector3.BACK), c_bot, c_bot, c_flat, c_flat, uv_scale)
	_add_quad(st, pt.call(xi, -yi, -h.z), pt.call(-xi, -yi, -h.z), pt.call(-xi, yi, -h.z), pt.call(xi, yi, -h.z), nrm.call(Vector3.FORWARD), c_bot, c_bot, c_flat, c_flat, uv_scale)
	_add_quad(st, pt.call(h.x, -yi, zi), pt.call(h.x, -yi, -zi), pt.call(h.x, yi, -zi), pt.call(h.x, yi, zi), nrm.call(Vector3.RIGHT), c_bot, c_bot, c_flat, c_flat, uv_scale)
	_add_quad(st, pt.call(-h.x, -yi, -zi), pt.call(-h.x, -yi, zi), pt.call(-h.x, yi, zi), pt.call(-h.x, yi, -zi), nrm.call(Vector3.LEFT), c_bot, c_bot, c_flat, c_flat, uv_scale)
	_add_quad(st, pt.call(-xi, h.y, zi), pt.call(xi, h.y, zi), pt.call(xi, h.y, -zi), pt.call(-xi, h.y, -zi), nrm.call(Vector3.UP), c_flat, c_flat, c_flat, c_flat, uv_scale)
	_add_quad(st, pt.call(-xi, -h.y, -zi), pt.call(xi, -h.y, -zi), pt.call(xi, -h.y, zi), pt.call(-xi, -h.y, zi), nrm.call(Vector3.DOWN), c_bot, c_bot, c_bot, c_bot, uv_scale)

	_add_quad(st, pt.call(-xi, yi, h.z), pt.call(xi, yi, h.z), pt.call(xi, h.y, zi), pt.call(-xi, h.y, zi), nrm.call(Vector3(0.0, 1.0, 1.0)), c_edge, c_edge, c_edge, c_edge, uv_scale)
	_add_quad(st, pt.call(xi, yi, -h.z), pt.call(-xi, yi, -h.z), pt.call(-xi, h.y, -zi), pt.call(xi, h.y, -zi), nrm.call(Vector3(0.0, 1.0, -1.0)), c_edge, c_edge, c_edge, c_edge, uv_scale)
	_add_quad(st, pt.call(h.x, yi, zi), pt.call(h.x, yi, -zi), pt.call(xi, h.y, -zi), pt.call(xi, h.y, zi), nrm.call(Vector3(1.0, 1.0, 0.0)), c_edge, c_edge, c_edge, c_edge, uv_scale)
	_add_quad(st, pt.call(-h.x, yi, -zi), pt.call(-h.x, yi, zi), pt.call(-xi, h.y, zi), pt.call(-xi, h.y, -zi), nrm.call(Vector3(-1.0, 1.0, 0.0)), c_edge, c_edge, c_edge, c_edge, uv_scale)

	_add_quad(st, pt.call(-xi, -h.y, zi), pt.call(xi, -h.y, zi), pt.call(xi, -yi, h.z), pt.call(-xi, -yi, h.z), nrm.call(Vector3(0.0, -1.0, 1.0)), c_bot, c_bot, c_bot, c_bot, uv_scale)
	_add_quad(st, pt.call(xi, -h.y, -zi), pt.call(-xi, -h.y, -zi), pt.call(-xi, -yi, -h.z), pt.call(xi, -yi, -h.z), nrm.call(Vector3(0.0, -1.0, -1.0)), c_bot, c_bot, c_bot, c_bot, uv_scale)
	_add_quad(st, pt.call(xi, -h.y, zi), pt.call(xi, -h.y, -zi), pt.call(h.x, -yi, -zi), pt.call(h.x, -yi, zi), nrm.call(Vector3(1.0, -1.0, 0.0)), c_bot, c_bot, c_bot, c_bot, uv_scale)
	_add_quad(st, pt.call(-xi, -h.y, -zi), pt.call(-xi, -h.y, zi), pt.call(-h.x, -yi, zi), pt.call(-h.x, -yi, -zi), nrm.call(Vector3(-1.0, -1.0, 0.0)), c_bot, c_bot, c_bot, c_bot, uv_scale)

	_add_quad(st, pt.call(xi, -yi, h.z), pt.call(h.x, -yi, zi), pt.call(h.x, yi, zi), pt.call(xi, yi, h.z), nrm.call(Vector3(1.0, 0.0, 1.0)), c_edge, c_edge, c_edge, c_edge, uv_scale)
	_add_quad(st, pt.call(h.x, -yi, -zi), pt.call(xi, -yi, -h.z), pt.call(xi, yi, -h.z), pt.call(h.x, yi, -zi), nrm.call(Vector3(1.0, 0.0, -1.0)), c_edge, c_edge, c_edge, c_edge, uv_scale)
	_add_quad(st, pt.call(-xi, -yi, -h.z), pt.call(-h.x, -yi, -zi), pt.call(-h.x, yi, -zi), pt.call(-xi, yi, -h.z), nrm.call(Vector3(-1.0, 0.0, -1.0)), c_edge, c_edge, c_edge, c_edge, uv_scale)
	_add_quad(st, pt.call(-h.x, -yi, zi), pt.call(-xi, -yi, h.z), pt.call(-xi, yi, h.z), pt.call(-h.x, yi, zi), nrm.call(Vector3(-1.0, 0.0, 1.0)), c_edge, c_edge, c_edge, c_edge, uv_scale)

	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var cn: Vector3 = nrm.call(Vector3(sx, sy, sz))
				var col := c_edge if sy > 0.0 else c_bot
				HeroSculptor.add_planar_tri(
					st,
					pt.call(sx * h.x, sy * yi, sz * zi),
					pt.call(sx * xi, sy * h.y, sz * zi),
					pt.call(sx * xi, sy * yi, sz * h.z),
					cn,
					col,
					col,
					col,
					uv_scale,
				)


static func _add_lathe(st: SurfaceTool, profile: Array, segments: int, uv_scale: float, xf: Transform3D) -> void:
	var rings := profile.size()
	for r_idx in range(rings - 1):
		var p0: Array = profile[r_idx]
		var p1: Array = profile[r_idx + 1]
		var y0: float = float(p0[0])
		var rad0: float = float(p0[1])
		var col0: Color = p0[2]
		var y1: float = float(p1[0])
		var rad1: float = float(p1[1])
		var col1: Color = p1[2]
		for s in segments:
			var a0 := TAU * float(s) / float(segments)
			var a1 := TAU * float((s + 1) % segments) / float(segments)
			var c0 := cos(a0)
			var s0 := sin(a0)
			var c1 := cos(a1)
			var s1 := sin(a1)
			var v00 := xf * Vector3(c0 * rad0, y0, s0 * rad0)
			var v10 := xf * Vector3(c1 * rad0, y0, s1 * rad0)
			var v11 := xf * Vector3(c1 * rad1, y1, s1 * rad1)
			var v01 := xf * Vector3(c0 * rad1, y1, s0 * rad1)
			var am := 0.5 * (a0 + a1)
			var radial := Vector3(cos(am), 0.0, sin(am))
			var dy := y1 - y0
			var dr := rad1 - rad0
			var out_n := Vector3(radial.x * dy, -dr, radial.z * dy)
			if out_n.length_squared() < 1e-8:
				out_n = Vector3.UP if y1 >= y0 else Vector3.DOWN
			out_n = (xf.basis * out_n).normalized()
			if rad0 < 1e-5 and rad1 >= 1e-5:
				HeroSculptor.add_planar_tri(st, v00, v01, v11, out_n, col0, col1, col1, uv_scale)
			elif rad1 < 1e-5 and rad0 >= 1e-5:
				HeroSculptor.add_planar_tri(st, v00, v01, v10, out_n, col0, col1, col0, uv_scale)
			elif rad0 >= 1e-5 and rad1 >= 1e-5:
				_add_quad(st, v00, v10, v11, v01, out_n, col0, col0, col1, col1, uv_scale)


static func _commit_surfaces(surfaces: Dictionary, order: Array[String]) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for slot in order:
		var st: SurfaceTool = surfaces[slot]
		st.generate_tangents()
		var idx := mesh.get_surface_count()
		st.commit(mesh)
		mesh.surface_set_name(idx, slot)
	return mesh


static func sandstone_plaza_mesh(radius: float, thickness: float, segments := 96) -> ArrayMesh:
	var key := "plaza_%.2f_%.2f_%d" % [radius, thickness, segments]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_t := thickness * 0.5
	var bevel_r := maxf(radius - 0.55, radius * 0.96)
	var bevel_y := half_t - 0.35
	var profile := [
		[-half_t, 0.0, CraftLookdev.encode_mask(0.06, 0.72)],
		[-half_t, radius, CraftLookdev.encode_mask(0.08, 0.76)],
		[bevel_y, radius, CraftLookdev.encode_mask(0.18, 0.42)],
		[half_t, bevel_r, CraftLookdev.encode_mask(0.54, 0.14)],
		[half_t, 0.0, CraftLookdev.encode_mask(0.12, 0.16)],
	]
	_add_lathe(st, profile, segments, 0.04, Transform3D.IDENTITY)
	var mesh := _commit_surfaces({"sandstone_plaza": st}, ["sandstone_plaza"])
	_mesh_cache[key] = mesh
	return mesh


static func turntable_pedestal_mesh(top_r: float, bottom_r: float, height: float, segments := 48) -> ArrayMesh:
	var key := "turntable_%.2f_%.2f_%.2f_%d" % [top_r, bottom_r, height, segments]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_h := height * 0.5
	var bevel := minf(0.06, height * 0.25)
	var lip := half_h - bevel * 1.6
	var profile := [
		[-half_h, 0.0, CraftLookdev.encode_mask(0.06, 0.78)],
		[-half_h, bottom_r - bevel, CraftLookdev.encode_mask(0.10, 0.74)],
		[-half_h + bevel, bottom_r, CraftLookdev.encode_mask(0.62, 0.30)],
		[lip - bevel, top_r + bevel * 0.5, CraftLookdev.encode_mask(0.22, 0.46)],
		[lip, top_r + bevel, CraftLookdev.encode_mask(0.70, 0.18)],
		[half_h - bevel, top_r, CraftLookdev.encode_mask(0.58, 0.16)],
		[half_h, top_r - bevel, CraftLookdev.encode_mask(0.66, 0.12)],
		[half_h, 0.0, CraftLookdev.encode_mask(0.18, 0.20)],
	]
	_add_lathe(st, profile, segments, 0.6, Transform3D.IDENTITY)
	var mesh := _commit_surfaces({"turntable_pedestal": st}, ["turntable_pedestal"])
	_mesh_cache[key] = mesh
	return mesh


static func turntable_material() -> ShaderMaterial:
	return _sandstone_shader_mat(
		"customize_turntable",
		Palette.RUST.darkened(0.35),
		Palette.CHARCOAL.lerp(Palette.RUST, 0.3),
		1.4,
		0.08,
	)


static func perimeter_berm_mesh(ground_r: float, segments: int, height: float, depth: float, stagger_m: float) -> ArrayMesh:
	var key := "berm_%.1f_%d_%.2f_%.2f_%.2f" % [ground_r, segments, height, depth, stagger_m]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var chord := TAU * ground_r / float(segments) * 1.08
	var c_flat := CraftLookdev.encode_mask(0.14, 0.22)
	var c_edge := CraftLookdev.encode_mask(0.66, 0.12)
	var c_bot := CraftLookdev.encode_mask(0.08, 0.76)
	for i in segments:
		var angle := TAU * float(i) / float(segments)
		var tall := height + stagger_m * float(i % 2)
		var at := Vector3(sin(angle) * (ground_r - depth * 0.5), tall * 0.5, -cos(angle) * (ground_r - depth * 0.5))
		var xf := Transform3D(Basis(Vector3.UP, -angle), at)
		add_bevel_box(st, Vector3.ZERO, Vector3(chord, tall, depth), 0.72, 0.12, xf, c_flat, c_edge, c_bot)
	var mesh := _commit_surfaces({"sandstone_berm": st}, ["sandstone_berm"])
	_mesh_cache[key] = mesh
	return mesh


static func ring_post_mesh(height := 2.2) -> ArrayMesh:
	var key := "ring_post_%.2f" % height
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var profile := [
		[0.0, 0.0, CraftLookdev.encode_mask(0.08, 0.80)],
		[0.0, 0.30, CraftLookdev.encode_mask(0.10, 0.76)],
		[0.14, 0.30, CraftLookdev.encode_mask(0.55, 0.35)],
		[0.24, 0.20, CraftLookdev.encode_mask(0.24, 0.44)],
		[height - 0.18, 0.14, CraftLookdev.encode_mask(0.20, 0.22)],
		[height - 0.12, 0.21, CraftLookdev.encode_mask(0.76, 0.16)],
		[height, 0.18, CraftLookdev.encode_mask(0.72, 0.14)],
		[height, 0.0, CraftLookdev.encode_mask(0.30, 0.20)],
	]
	_add_lathe(st, profile, 8, 0.8, Transform3D.IDENTITY)
	var mesh := _commit_surfaces({"iron_frame": st}, ["iron_frame"])
	_mesh_cache[key] = mesh
	return mesh


static func signal_lantern_mesh(radius := 0.34) -> ArrayMesh:
	var key := "signal_lantern_%.3f" % radius
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var st_cage := SurfaceTool.new()
	st_cage.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_bulb := SurfaceTool.new()
	st_bulb.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := radius
	var base_profile := [
		[-r * 1.15, 0.0, CraftLookdev.encode_mask(0.10, 0.75)],
		[-r * 1.15, r * 0.78, CraftLookdev.encode_mask(0.16, 0.70)],
		[-r * 0.85, r * 0.86, CraftLookdev.encode_mask(0.78, 0.22)],
		[-r * 0.70, r * 0.66, CraftLookdev.encode_mask(0.50, 0.32)],
		[-r * 0.70, 0.0, CraftLookdev.encode_mask(0.20, 0.50)],
	]
	_add_lathe(st_cage, base_profile, 8, 1.4, Transform3D.IDENTITY)
	var cap_profile := [
		[r * 0.72, 0.0, CraftLookdev.encode_mask(0.18, 0.52)],
		[r * 0.72, r * 1.05, CraftLookdev.encode_mask(0.76, 0.24)],
		[r * 0.88, r * 1.02, CraftLookdev.encode_mask(0.84, 0.16)],
		[r * 1.16, r * 0.44, CraftLookdev.encode_mask(0.72, 0.18)],
		[r * 1.24, 0.0, CraftLookdev.encode_mask(0.42, 0.22)],
	]
	_add_lathe(st_cage, cap_profile, 8, 1.4, Transform3D.IDENTITY)
	var c_flat := CraftLookdev.encode_mask(0.22, 0.36)
	var c_edge := CraftLookdev.encode_mask(0.82, 0.14)
	var c_bot := CraftLookdev.encode_mask(0.12, 0.66)
	for i in 4:
		var a := TAU * float(i) / 4.0 + PI * 0.25
		var xf := Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a) * r * 0.86, 0.0, sin(a) * r * 0.86))
		add_bevel_box(st_cage, Vector3.ZERO, Vector3(r * 0.16, r * 1.62, r * 0.16), r * 0.03, 1.8, xf, c_flat, c_edge, c_bot)
	var bulb_r := r * 0.82
	var bulb_profile := [
		[-bulb_r * 0.92, 0.0, CraftLookdev.encode_mask(0.10, 0.10, 1.0)],
		[-bulb_r * 0.78, bulb_r * 0.58, CraftLookdev.encode_mask(0.15, 0.08, 1.0)],
		[-bulb_r * 0.34, bulb_r * 0.94, CraftLookdev.encode_mask(0.25, 0.04, 1.0)],
		[bulb_r * 0.34, bulb_r * 0.94, CraftLookdev.encode_mask(0.25, 0.04, 1.0)],
		[bulb_r * 0.78, bulb_r * 0.58, CraftLookdev.encode_mask(0.15, 0.08, 1.0)],
		[bulb_r * 0.92, 0.0, CraftLookdev.encode_mask(0.10, 0.10, 1.0)],
	]
	_add_lathe(st_bulb, bulb_profile, 10, 1.2, Transform3D.IDENTITY)
	var mesh := _commit_surfaces({"iron_frame": st_cage, "bulb_glass": st_bulb}, ["iron_frame", "bulb_glass"])
	_mesh_cache[key] = mesh
	return mesh


static func ghost_sphere_mesh(radius := 1.0) -> ArrayMesh:
	var key := "ghost_sphere_%.2f" % radius
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var profile: Array = []
	var lat_steps := 8
	for i in range(lat_steps + 1):
		var phi := -PI * 0.5 + PI * float(i) / float(lat_steps)
		var r := maxf(0.0, cos(phi) * radius)
		if i == 0 or i == lat_steps:
			r = 0.0
		profile.append([sin(phi) * radius, r, CraftLookdev.encode_mask(0.2, 0.1, 1.0)])
	_add_lathe(st, profile, 16, 0.5, Transform3D.IDENTITY)
	var mesh := _commit_surfaces({"ghost_shell": st}, ["ghost_shell"])
	_mesh_cache[key] = mesh
	return mesh


static func guide_pip_mesh(radius := 0.16) -> ArrayMesh:
	var key := "guide_pip_%.3f" % radius
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var profile := [
		[-radius, 0.0, CraftLookdev.encode_mask(0.2, 0.1, 1.0)],
		[0.0, radius, CraftLookdev.encode_mask(0.5, 0.05, 1.0)],
		[radius, 0.0, CraftLookdev.encode_mask(0.2, 0.1, 1.0)],
	]
	_add_lathe(st, profile, 6, 1.5, Transform3D.IDENTITY)
	var mesh := _commit_surfaces({"guide_pip": st}, ["guide_pip"])
	_mesh_cache[key] = mesh
	return mesh


static func _sandstone_shader_mat(key: String, base_col: Color, secondary_col: Color, tile_m: float, foot_h: float) -> ShaderMaterial:
	if _mat_cache.has(key):
		var cached := _mat_cache[key] as ShaderMaterial
		cached.set_shader_parameter("reduce_flashes", FlashGuard.on)
		return cached
	var preset := CraftLookdev.preset_material("scorched_concrete")
	var mat := preset.duplicate(false) as ShaderMaterial
	mat.resource_name = key
	mat.set_shader_parameter("base_albedo", Vector3(base_col.r, base_col.g, base_col.b))
	mat.set_shader_parameter("secondary_albedo", Vector3(secondary_col.r, secondary_col.g, secondary_col.b))
	mat.set_shader_parameter("macro_color_mix", 0.18)
	mat.set_shader_parameter("base_roughness", 0.92)
	mat.set_shader_parameter("base_metallic", 0.0)
	mat.set_shader_parameter("edge_wear_albedo", Vector3(Palette.LEDGER.r, Palette.LEDGER.g, Palette.LEDGER.b))
	mat.set_shader_parameter("edge_wear_strength", 0.65)
	mat.set_shader_parameter("edge_wear_metallic", 0.02)
	mat.set_shader_parameter("edge_wear_roughness", 0.82)
	mat.set_shader_parameter("grime_strength", 0.62)
	mat.set_shader_parameter("rust_mix", 0.25)
	mat.set_shader_parameter("foot_grime_height", foot_h)
	mat.set_shader_parameter("foot_grime_strength", 0.35)
	mat.set_shader_parameter("detail_tile_metres", tile_m)
	mat.set_shader_parameter("normal_relief", 0.42)
	mat.set_shader_parameter("emissive_energy", 0.0)
	mat.set_shader_parameter("reduce_flashes", FlashGuard.on)
	_mat_cache[key] = mat
	return mat


static func sandstone_material() -> ShaderMaterial:
	return _sandstone_shader_mat(
		"camp_sandstone_plaza",
		Palette.SANDSTONE,
		Palette.SANDSTONE.darkened(0.05),
		5.2,
		0.4,
	)


static func berm_material() -> ShaderMaterial:
	return _sandstone_shader_mat(
		"camp_sandstone_berm",
		Palette.SANDSTONE.darkened(0.18),
		Palette.SANDSTONE.darkened(0.28),
		3.6,
		1.4,
	)


static func iron_material() -> ShaderMaterial:
	return CraftLookdev.preset_material("oil_slicked_iron")


static func lantern_bulb_material(tint: Color, energy: float, key := "") -> StandardMaterial3D:
	if key != "" and _mat_cache.has(key):
		return _mat_cache[key] as StandardMaterial3D
	var mat := StandardMaterial3D.new()
	mat.resource_name = key if key != "" else "camp_lantern_bulb"
	mat.albedo_color = tint.darkened(0.55)
	mat.roughness = 0.26
	mat.metallic = 0.08
	mat.emission_enabled = true
	mat.emission = tint
	mat.emission_energy_multiplier = energy
	if key != "":
		_mat_cache[key] = mat
	return mat
