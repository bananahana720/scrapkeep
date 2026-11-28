class_name EnemyBossCraft
extends RefCounted

const Palette := preload("res://src/core/palette.gd")
const PaletteMaterials := preload("res://src/presentation/palette_materials.gd")
const HeroSculptor := preload("res://src/presentation/craft/hero_kitbash_sculptor.gd")
const CraftLookdev := preload("res://src/presentation/craft/craft_lookdev.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")
const BakeLook := preload("res://src/presentation/bake_look.gd")

static var _mesh_cache: Dictionary = {}
static var _mat_cache: Dictionary = {}


static func reset_for_tests() -> void:
	_mesh_cache.clear()
	_mat_cache.clear()


static func _cached(key: String, builder: Callable) -> ArrayMesh:
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var mesh := ArrayMesh.new()
	var surfaces: Dictionary = {}
	var order: Array[String] = []
	builder.call(surfaces, order)
	for slot in order:
		var st: SurfaceTool = surfaces[slot]
		st.generate_tangents()
		var idx := mesh.get_surface_count()
		st.commit(mesh)
		mesh.surface_set_name(idx, slot)
	_mesh_cache[key] = mesh
	return mesh


static func _slot_st(surfaces: Dictionary, order: Array[String], slot: String) -> SurfaceTool:
	if not surfaces.has(slot):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		surfaces[slot] = st
		order.append(slot)
	return surfaces[slot]


static func _add_tri_uv(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3, uv0: Vector2, uv1: Vector2, uv2: Vector2, c0: Color, c1: Color, c2: Color) -> void:
	var nn := n.normalized()
	if nn.length_squared() < 0.0001:
		return
	var p1 := b
	var p2 := c
	var u1 := uv1
	var u2 := uv2
	var col1 := c1
	var col2 := c2
	if (p1 - a).cross(p2 - a).length_squared() < 1e-12:
		return
	if (p1 - a).cross(p2 - a).dot(nn) > 0.0:
		var tp := p1
		p1 = p2
		p2 = tp
		var tu := u1
		u1 = u2
		u2 = tu
		var tc := col1
		col1 = col2
		col2 = tc
	st.set_normal(nn)
	st.set_uv(uv0)
	st.set_color(c0)
	st.add_vertex(a)
	st.set_normal(nn)
	st.set_uv(u1)
	st.set_color(col1)
	st.add_vertex(p1)
	st.set_normal(nn)
	st.set_uv(u2)
	st.set_color(col2)
	st.add_vertex(p2)


static func _add_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, col: Color, uv_scale := 0.5) -> void:
	HeroSculptor.add_planar_tri(st, a, b, c, n, col, col, col, uv_scale)
	HeroSculptor.add_planar_tri(st, a, c, d, n, col, col, col, uv_scale)


static func _add_quad_uv(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, uv0: Vector2, uv1: Vector2, uv2: Vector2, uv3: Vector2, c0: Color, c1: Color, c2: Color, c3: Color) -> void:
	_add_tri_uv(st, a, b, c, n, uv0, uv1, uv2, c0, c1, c2)
	_add_tri_uv(st, a, c, d, n, uv0, uv2, uv3, c0, c2, c3)


static func _bevel_box(st: SurfaceTool, center: Vector3, size: Vector3, bevel := 0.04, uv_scale := 0.5, xf := Transform3D.IDENTITY, c_flat := Color(0.10, 0.14, 0.0, 1.0), c_edge := Color(0.88, 0.12, 0.0, 1.0), c_bot := Color(0.10, 0.78, 0.0, 1.0)) -> void:
	var h := size * 0.5
	var b := minf(bevel, minf(h.x, minf(h.y, h.z)) * 0.42)
	var xi := h.x - b
	var yi := h.y - b
	var zi := h.z - b
	var pt := func(x: float, y: float, z: float) -> Vector3:
		return xf * (center + Vector3(x, y, z))
	var nrm := func(v: Vector3) -> Vector3:
		return (xf.basis * v).normalized()

	_add_quad(st, pt.call(-xi, -yi, h.z), pt.call(xi, -yi, h.z), pt.call(xi, yi, h.z), pt.call(-xi, yi, h.z), nrm.call(Vector3.BACK), c_flat, uv_scale)
	_add_quad(st, pt.call(xi, -yi, -h.z), pt.call(-xi, -yi, -h.z), pt.call(-xi, yi, -h.z), pt.call(xi, yi, -h.z), nrm.call(Vector3.FORWARD), c_flat, uv_scale)
	_add_quad(st, pt.call(h.x, -yi, zi), pt.call(h.x, -yi, -zi), pt.call(h.x, yi, -zi), pt.call(h.x, yi, zi), nrm.call(Vector3.RIGHT), c_flat, uv_scale)
	_add_quad(st, pt.call(-h.x, -yi, -zi), pt.call(-h.x, -yi, zi), pt.call(-h.x, yi, zi), pt.call(-h.x, yi, -zi), nrm.call(Vector3.LEFT), c_flat, uv_scale)
	_add_quad(st, pt.call(-xi, h.y, zi), pt.call(xi, h.y, zi), pt.call(xi, h.y, -zi), pt.call(-xi, h.y, -zi), nrm.call(Vector3.UP), c_flat, uv_scale)
	_add_quad(st, pt.call(-xi, -h.y, -zi), pt.call(xi, -h.y, -zi), pt.call(xi, -h.y, zi), pt.call(-xi, -h.y, zi), nrm.call(Vector3.DOWN), c_bot, uv_scale)

	if b <= 0.0001:
		return

	for sy in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var n: Vector3 = (xf.basis * Vector3(0.0, sy, sz)).normalized()
			var col := c_edge if sy > 0.0 else c_bot
			_add_quad(st,
				xf * (center + Vector3(-xi, sy * h.y, sz * zi)),
				xf * (center + Vector3(xi, sy * h.y, sz * zi)),
				xf * (center + Vector3(xi, sy * yi, sz * h.z)),
				xf * (center + Vector3(-xi, sy * yi, sz * h.z)),
				n, col, uv_scale)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var n: Vector3 = (xf.basis * Vector3(sx, sy, 0.0)).normalized()
			var col := c_edge if sy > 0.0 else c_bot
			_add_quad(st,
				xf * (center + Vector3(sx * xi, sy * h.y, -zi)),
				xf * (center + Vector3(sx * xi, sy * h.y, zi)),
				xf * (center + Vector3(sx * h.x, sy * yi, zi)),
				xf * (center + Vector3(sx * h.x, sy * yi, -zi)),
				n, col, uv_scale)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var n: Vector3 = (xf.basis * Vector3(sx, 0.0, sz)).normalized()
			_add_quad(st,
				xf * (center + Vector3(sx * h.x, -yi, sz * zi)),
				xf * (center + Vector3(sx * h.x, yi, sz * zi)),
				xf * (center + Vector3(sx * xi, yi, sz * h.z)),
				xf * (center + Vector3(sx * xi, -yi, sz * h.z)),
				n, c_edge, uv_scale)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var n: Vector3 = (xf.basis * Vector3(sx, sy, sz)).normalized()
				var col := c_edge if sy > 0.0 else c_bot
				HeroSculptor.add_planar_tri(st,
					xf * (center + Vector3(sx * h.x, sy * yi, sz * zi)),
					xf * (center + Vector3(sx * xi, sy * h.y, sz * zi)),
					xf * (center + Vector3(sx * xi, sy * yi, sz * h.z)),
					n, col, col, col, uv_scale)


static func _bevel_cyl(st: SurfaceTool, center: Vector3, r_bot: float, r_top: float, height: float, segs := 12, bevel := 0.03, uv_scale := 0.5, xf := Transform3D.IDENTITY, c_body := Color(0.10, 0.14, 0.0, 1.0), c_edge := Color(0.88, 0.12, 0.0, 1.0), c_cap := Color(0.14, 0.22, 0.0, 1.0)) -> void:
	var hh := height * 0.5
	var b := minf(bevel, minf(hh * 0.4, minf(r_bot, r_top) * 0.35))
	var rings := [
		[-hh, maxf(0.002, r_bot - b)],
		[-hh + b, r_bot],
		[hh - b, r_top],
		[hh, maxf(0.002, r_top - b)],
	]
	if b <= 0.0001:
		rings = [[-hh, r_bot], [hh, r_top]]

	for i in segs:
		var a0 := TAU * float(i) / float(segs)
		var a1 := TAU * float(i + 1) / float(segs)
		var c0 := cos(a0)
		var s0 := sin(a0)
		var c1 := cos(a1)
		var s1 := sin(a1)
		var mid := Vector3(cos((a0 + a1) * 0.5), 0.0, sin((a0 + a1) * 0.5))
		for r in rings.size() - 1:
			var y0: float = rings[r][0]
			var rad0: float = rings[r][1]
			var y1: float = rings[r + 1][0]
			var rad1: float = rings[r + 1][1]
			var p00: Vector3 = xf * (center + Vector3(c0 * rad0, y0, s0 * rad0))
			var p10: Vector3 = xf * (center + Vector3(c1 * rad0, y0, s1 * rad0))
			var p11: Vector3 = xf * (center + Vector3(c1 * rad1, y1, s1 * rad1))
			var p01: Vector3 = xf * (center + Vector3(c0 * rad1, y1, s0 * rad1))
			var dy := y1 - y0
			var dr := rad0 - rad1
			var fn: Vector3 = (xf.basis * (mid * dy + Vector3.UP * dr)).normalized()
			var col := c_edge if (rings.size() == 4 and (r == 0 or r == 2)) else c_body
			_add_quad(st, p00, p10, p11, p01, fn, col, uv_scale)
		var top_r: float = rings[-1][1]
		var top_y: float = rings[-1][0]
		HeroSculptor.add_planar_tri(st,
			xf * (center + Vector3(0.0, top_y, 0.0)),
			xf * (center + Vector3(c0 * top_r, top_y, s0 * top_r)),
			xf * (center + Vector3(c1 * top_r, top_y, s1 * top_r)),
			(xf.basis * Vector3.UP).normalized(), c_cap, c_cap, c_cap, uv_scale)
		var bot_r: float = rings[0][1]
		var bot_y: float = rings[0][0]
		var bot_col := Color(c_cap.r, maxf(c_cap.g, 0.72), c_cap.b, 1.0)
		HeroSculptor.add_planar_tri(st,
			xf * (center + Vector3(0.0, bot_y, 0.0)),
			xf * (center + Vector3(c1 * bot_r, bot_y, s1 * bot_r)),
			xf * (center + Vector3(c0 * bot_r, bot_y, s0 * bot_r)),
			(xf.basis * Vector3.DOWN).normalized(), bot_col, bot_col, bot_col, uv_scale)


static func _bevel_ring(st: SurfaceTool, center: Vector3, r_in: float, r_out: float, height: float, segs := 16, bevel := 0.02, uv_scale := 0.5, xf := Transform3D.IDENTITY, c_body := Color(0.12, 0.22, 0.0, 1.0), c_edge := Color(0.88, 0.14, 0.0, 1.0)) -> void:
	var hh := height * 0.5
	var b := minf(bevel, minf(hh * 0.42, (r_out - r_in) * 0.25))
	var prof := [
		Vector2(r_in + b, hh),
		Vector2(r_out - b, hh),
		Vector2(r_out, hh - b),
		Vector2(r_out, -hh + b),
		Vector2(r_out - b, -hh),
		Vector2(r_in + b, -hh),
		Vector2(r_in, -hh + b),
		Vector2(r_in, hh - b),
	]
	if b <= 0.0001:
		prof = [
			Vector2(r_in, hh),
			Vector2(r_out, hh),
			Vector2(r_out, -hh),
			Vector2(r_in, -hh),
		]

	for i in segs:
		var a0 := TAU * float(i) / float(segs)
		var a1 := TAU * float(i + 1) / float(segs)
		var c0 := cos(a0)
		var s0 := sin(a0)
		var c1 := cos(a1)
		var s1 := sin(a1)
		var radial := Vector3(cos((a0 + a1) * 0.5), 0.0, sin((a0 + a1) * 0.5))
		for k in prof.size():
			var p0: Vector2 = prof[k]
			var p1: Vector2 = prof[(k + 1) % prof.size()]
			var dr := p1.x - p0.x
			var dy := p1.y - p0.y
			var out_r := -dy
			var out_y := dr
			var fn: Vector3 = (xf.basis * (radial * out_r + Vector3.UP * out_y)).normalized()
			var q0: Vector3 = xf * (center + Vector3(c0 * p0.x, p0.y, s0 * p0.x))
			var q1: Vector3 = xf * (center + Vector3(c1 * p0.x, p0.y, s1 * p0.x))
			var q2: Vector3 = xf * (center + Vector3(c1 * p1.x, p1.y, s1 * p1.x))
			var q3: Vector3 = xf * (center + Vector3(c0 * p1.x, p1.y, s0 * p1.x))
			var is_bevel := prof.size() == 8 and (k == 1 or k == 3 or k == 5 or k == 7)
			_add_quad(st, q0, q1, q2, q3, fn, c_edge if is_bevel else c_body, uv_scale)


static func _bolt_cyl() -> Callable:
	return _bevel_cyl.bind(CraftLookdev.encode_mask(0.24, 0.64), CraftLookdev.encode_mask(0.92, 0.14), CraftLookdev.encode_mask(0.74, 0.18))


static func _strut_xf(p0: Vector3, p1: Vector3) -> Transform3D:
	var d := p1 - p0
	var y := d.normalized()
	var ref := Vector3.RIGHT if absf(y.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var x := y.cross(ref).normalized()
	var z := x.cross(y).normalized()
	return Transform3D(Basis(x, y, z), (p0 + p1) * 0.5)


static func _add_strut(st: SurfaceTool, p0: Vector3, p1: Vector3, thickness: float, bevel := 0.014, c_flat := Color(0.12, 0.24, 0.0, 1.0), c_edge := Color(0.84, 0.16, 0.0, 1.0)) -> void:
	var length := p0.distance_to(p1)
	if length < 0.01:
		return
	_bevel_box(st, Vector3.ZERO, Vector3(thickness, length, thickness), bevel, 0.9, _strut_xf(p0, p1), c_flat, c_edge, CraftLookdev.encode_mask(0.14, 0.62))


static func craft_shader_material(key: String, preset_id: String, base_col: Color, secondary_col: Color, roughness := 0.68, metallic := 0.28, emissive_col := Palette.ARC, emissive_energy := 0.0) -> ShaderMaterial:
	var cache_key := "%s:%s:%s:%.2f" % [key, preset_id, base_col.to_html(false), emissive_energy]
	if _mat_cache.has(cache_key):
		var cached := _mat_cache[cache_key] as ShaderMaterial
		cached.set_shader_parameter("reduce_flashes", FlashGuard.on)
		return cached
	var base := CraftLookdev.preset_material(preset_id)
	var mat: ShaderMaterial = base.duplicate(false) as ShaderMaterial if base != null else ShaderMaterial.new()
	mat.resource_name = "enemy_boss_" + key
	mat.set_shader_parameter("use_world_space", false)
	mat.set_shader_parameter("use_vertex_masks", true)
	mat.set_shader_parameter("base_albedo", base_col)
	mat.set_shader_parameter("secondary_albedo", secondary_col)
	mat.set_shader_parameter("base_roughness", roughness)
	mat.set_shader_parameter("base_metallic", metallic)
	mat.set_shader_parameter("emissive_color", emissive_col)
	mat.set_shader_parameter("emissive_secondary_color", emissive_col.lightened(0.15))
	mat.set_shader_parameter("emissive_energy", emissive_energy)
	mat.set_shader_parameter("reduce_flashes", FlashGuard.on)
	_mat_cache[cache_key] = mat
	return mat


static func brindle_armour_material(base_color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.resource_name = "brindle_armour_plate"
	mat.albedo_color = base_color
	mat.roughness = 0.62
	mat.metallic = 0.34
	PaletteMaterials.surface_grain(mat)
	var plate := PaletteMaterials.look_texture("rusted-salvaged-plate-worn", true)
	if plate != null:
		mat.albedo_texture = plate
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3.ONE / 2.8
	mat.detail_enabled = true
	mat.detail_uv_layer = BaseMaterial3D.DETAIL_UV_2
	mat.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	mat.detail_albedo = BakeLook.ramp()
	mat.uv2_scale = Vector3(BakeLook.RAMP - 1.0, BakeLook.RAMP - 1.0, BakeLook.RAMP) / BakeLook.RAMP
	mat.uv2_offset = Vector3(0.5, 0.5, 0.0) / BakeLook.RAMP
	mat.next_pass = BakeLook.edge_lift()
	return mat


static func quench_vent_material() -> ShaderMaterial:
	var mat := craft_shader_material("quench_vent", "plasma_conduit_core", Palette.CHARCOAL, Palette.VERDIGRIS, 0.78, 0.32, Palette.ARC, 1.45)
	mat.set_shader_parameter("base_specular", 0.12)
	mat.set_shader_parameter("emissive_pulse_speed", 1.1)
	mat.set_shader_parameter("emissive_pulse_amount", 0.12)
	return mat


static func brindle_hull_mesh(size: Vector3) -> ArrayMesh:
	var key := "brindle_hull:%.2f:%.2f:%.2f" % [size.x, size.y, size.z]
	return _cached(key, func(surfaces: Dictionary, order: Array[String]):
		var st := _slot_st(surfaces, order, "hull_plating")
		_bevel_box(st, Vector3.ZERO, size, 0.28, 0.25, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.08, 0.16), CraftLookdev.encode_mask(0.88, 0.14), CraftLookdev.encode_mask(0.10, 0.86))
		_bevel_box(st, Vector3(0.0, -size.y * 0.42, 0.0), Vector3(size.x + 0.46, size.y * 0.20, size.z + 0.42), 0.14, 0.30, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.16, 0.72), CraftLookdev.encode_mask(0.92, 0.22), CraftLookdev.encode_mask(0.14, 0.92))
		_bevel_box(st, Vector3(0.0, size.y * 0.46, 0.0), Vector3(size.x + 0.28, 0.36, size.z + 0.28), 0.10, 0.32, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.14, 0.20), CraftLookdev.encode_mask(0.90, 0.14), CraftLookdev.encode_mask(0.12, 0.68))
		for z_frac in [-0.36, -0.12, 0.12, 0.36]:
			_bevel_box(st, Vector3(0.0, 0.0, size.z * z_frac), Vector3(size.x + 0.34, size.y * 0.84, 0.42), 0.08, 0.45, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.18, 0.28), CraftLookdev.encode_mask(0.90, 0.14), CraftLookdev.encode_mask(0.14, 0.78))
		_bevel_box(st, Vector3(0.0, -size.y * 0.18, -size.z * 0.50 - 0.32), Vector3(size.x * 0.76, size.y * 0.44, 0.64), 0.16, 0.40, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.24, 0.30), CraftLookdev.encode_mask(0.94, 0.12), CraftLookdev.encode_mask(0.18, 0.82))
		for sx in [-1.0, 1.0]:
			for rz in [-4.5, -1.5, 1.5, 4.5]:
				_bevel_cyl(st, Vector3.ZERO, 0.14, 0.12, 0.14, 6, 0.025, 1.2, Transform3D(Basis(Vector3.BACK, PI * 0.5 * sx), Vector3(sx * (size.x * 0.5 + 0.18), size.y * 0.32, rz)), CraftLookdev.encode_mask(0.22, 0.62), CraftLookdev.encode_mask(0.92, 0.14), CraftLookdev.encode_mask(0.76, 0.16))
	)


static func brindle_armour_plate(size: Vector3) -> ArrayMesh:
	var key := "brindle_armour_plate:%.2f:%.2f:%.2f" % [size.x, size.y, size.z]
	return _cached(key, func(surfaces: Dictionary, order: Array[String]):
		var st := _slot_st(surfaces, order, "hull_plating")
		_bevel_box(st, Vector3.ZERO, size, minf(0.10, size.x * 0.35), 0.45, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.08, 0.16), CraftLookdev.encode_mask(0.90, 0.14), CraftLookdev.encode_mask(0.12, 0.74))
		for sy in [-0.36, 0.36]:
			_bevel_box(st, Vector3(0.0, size.y * sy, 0.0), Vector3(size.x + 0.16, maxf(0.22, size.y * 0.10), size.z * 0.94), 0.04, 0.6, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.16, 0.32), CraftLookdev.encode_mask(0.92, 0.14), CraftLookdev.encode_mask(0.14, 0.72))
		for sz in [-0.38, 0.0, 0.38]:
			_bevel_box(st, Vector3(0.0, 0.0, size.z * sz), Vector3(size.x + 0.14, size.y * 0.84, 0.28), 0.04, 0.6, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.16, 0.34), CraftLookdev.encode_mask(0.90, 0.14), CraftLookdev.encode_mask(0.14, 0.70))
		for sy in [-0.36, 0.36]:
			for sz in [-0.38, 0.38]:
				_bevel_cyl(st, Vector3.ZERO, 0.10, 0.085, size.x + 0.24, 6, 0.02, 1.2, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.0, size.y * sy, size.z * sz)), CraftLookdev.encode_mask(0.24, 0.62), CraftLookdev.encode_mask(0.92, 0.14), CraftLookdev.encode_mask(0.78, 0.18))
	)


static func brindle_cockpit_canopy(size: Vector3) -> ArrayMesh:
	var key := "brindle_cockpit_canopy:%.2f:%.2f:%.2f" % [size.x, size.y, size.z]
	return _cached(key, func(surfaces: Dictionary, order: Array[String]):
		var st := _slot_st(surfaces, order, "emissive_core")
		_bevel_box(st, Vector3(0.0, -size.y * 0.40, 0.0), Vector3(size.x + 0.24, size.y * 0.22, size.z + 0.24), 0.08, 0.5, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.14, 0.58), CraftLookdev.encode_mask(0.88, 0.18), CraftLookdev.encode_mask(0.14, 0.82))
		_bevel_box(st, Vector3(0.0, 0.06, 0.0), Vector3(size.x * 0.92, size.y * 0.82, size.z * 0.92), 0.26, 0.5, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.18, 0.12, 0.25), CraftLookdev.encode_mask(0.82, 0.12, 0.35), CraftLookdev.encode_mask(0.12, 0.60))
		for sx in [-1.0, 1.0]:
			_bevel_box(st, Vector3(sx * size.x * 0.45, 0.06, 0.0), Vector3(0.18, size.y * 0.86, size.z * 0.82), 0.04, 0.8, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.20, 0.36), CraftLookdev.encode_mask(0.90, 0.14), CraftLookdev.encode_mask(0.14, 0.72))
		_bevel_box(st, Vector3(0.0, size.y * 0.44, 0.0), Vector3(size.x * 0.78, 0.20, size.z * 0.78), 0.06, 0.7, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.18, 0.22), CraftLookdev.encode_mask(0.90, 0.14), CraftLookdev.encode_mask(0.14, 0.68))
	)


static func brindle_cockpit_console(size: Vector3) -> ArrayMesh:
	var key := "brindle_cockpit_console:%.2f:%.2f:%.2f" % [size.x, size.y, size.z]
	return _cached(key, func(surfaces: Dictionary, order: Array[String]):
		var st := _slot_st(surfaces, order, "emissive_core")
		_bevel_box(st, Vector3.ZERO, size, 0.08, 0.8, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.14, 0.26), CraftLookdev.encode_mask(0.88, 0.14), CraftLookdev.encode_mask(0.12, 0.78))
		_bevel_box(st, Vector3(0.0, size.y * 0.18, -size.z * 0.46), Vector3(size.x * 0.68, size.y * 0.42, 0.14), 0.03, 1.2, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.22, 0.12, 0.92), CraftLookdev.encode_mask(0.86, 0.12, 0.75), CraftLookdev.encode_mask(0.16, 0.50, 0.40))
	)


static func brindle_vent_cap(radius: float, height: float) -> ArrayMesh:
	var key := "brindle_vent_cap:%.2f:%.2f" % [radius, height]
	return _cached(key, func(surfaces: Dictionary, order: Array[String]):
		var st := _slot_st(surfaces, order, "iron_frame")
		_bevel_cyl(st, Vector3(0.0, -height * 0.28, 0.0), radius * 1.06, radius * 0.98, height * 0.44, 12, 0.06, 0.5, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.12, 0.52), CraftLookdev.encode_mask(0.88, 0.16), CraftLookdev.encode_mask(0.18, 0.42))
		_bevel_cyl(st, Vector3(0.0, height * 0.10, 0.0), radius * 0.86, radius * 0.74, height * 0.58, 12, 0.07, 0.55, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.10, 0.22), CraftLookdev.encode_mask(0.90, 0.14), CraftLookdev.encode_mask(0.16, 0.30))
		_bevel_ring(st, Vector3(0.0, height * 0.36, 0.0), radius * 0.42, radius * 0.72, height * 0.24, 12, 0.04, 0.7, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.14, 0.36), CraftLookdev.encode_mask(0.92, 0.12))
		HeroSculptor.bolt_ring(st, Vector3(0.0, -height * 0.04, 0.0), radius * 0.94, 6, minf(0.11, radius * 0.10), 0.12, 0.86, 1.2, _bolt_cyl())
		for i in 3:
			var a := PI * float(i) / 3.0
			var xf := Transform3D(Basis(Vector3.UP, a), Vector3(0.0, height * 0.36, 0.0))
			_bevel_box(st, Vector3.ZERO, Vector3(radius * 1.18, 0.12, 0.16), 0.03, 0.8, xf, CraftLookdev.encode_mask(0.16, 0.34), CraftLookdev.encode_mask(0.92, 0.14), CraftLookdev.encode_mask(0.14, 0.70))
	)


static func brindle_crane_post(size: Vector3) -> ArrayMesh:
	var key := "brindle_crane_post:%.2f:%.2f:%.2f" % [size.x, size.y, size.z]
	return _cached(key, func(surfaces: Dictionary, order: Array[String]):
		var st := _slot_st(surfaces, order, "copper_coil")
		_bevel_box(st, Vector3(0.0, -size.y * 0.45, 0.0), Vector3(size.x * 1.55, size.y * 0.12, size.z * 1.55), 0.06, 0.5, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.16, 0.74), CraftLookdev.encode_mask(0.90, 0.18), CraftLookdev.encode_mask(0.12, 0.92))
		_bevel_box(st, Vector3.ZERO, size, 0.08, 0.45, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.10, 0.20), CraftLookdev.encode_mask(0.88, 0.14), CraftLookdev.encode_mask(0.12, 0.78))
		for yf in [-0.15, 0.22]:
			_bevel_box(st, Vector3(0.0, size.y * yf, 0.0), Vector3(size.x * 1.24, 0.22, size.z * 1.24), 0.04, 0.7, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.18, 0.38), CraftLookdev.encode_mask(0.92, 0.14), CraftLookdev.encode_mask(0.14, 0.74))
		_bevel_cyl(st, Vector3(0.0, size.y * 0.48, 0.0), size.x * 0.72, size.x * 0.56, 0.34, 8, 0.04, 0.8, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.18, 0.28), CraftLookdev.encode_mask(0.92, 0.14), CraftLookdev.encode_mask(0.22, 0.24))
		HeroSculptor.bolt_ring(st, Vector3(0.0, -size.y * 0.38, 0.0), size.x * 0.64, 4, 0.075, 0.08, 0.86, 1.2, _bolt_cyl())
	)


static func brindle_magnet_housing(radius: float, height: float) -> ArrayMesh:
	var key := "brindle_magnet_housing:%.2f:%.2f" % [radius, height]
	return _cached(key, func(surfaces: Dictionary, order: Array[String]):
		var st := _slot_st(surfaces, order, "iron_frame")
		_bevel_cyl(st, Vector3(0.0, -height * 0.06, 0.0), radius, radius * 0.90, height * 0.74, 14, 0.08, 0.45, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.12, 0.24), CraftLookdev.encode_mask(0.90, 0.14), CraftLookdev.encode_mask(0.18, 0.32))
		_bevel_ring(st, Vector3(0.0, height * 0.06, 0.0), radius * 0.76, radius * 1.07, height * 0.26, 14, 0.05, 0.55, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.16, 0.36), CraftLookdev.encode_mask(0.92, 0.14))
		_bevel_cyl(st, Vector3(0.0, -height * 0.40, 0.0), radius * 0.74, radius * 0.78, height * 0.16, 14, 0.03, 0.6, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.18, 0.22, 0.92), CraftLookdev.encode_mask(0.70, 0.14, 0.92), CraftLookdev.encode_mask(0.22, 0.18, 1.0))
		_bevel_cyl(st, Vector3(0.0, height * 0.38, 0.0), radius * 0.42, radius * 0.30, height * 0.32, 8, 0.04, 0.7, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.18, 0.34), CraftLookdev.encode_mask(0.90, 0.14), CraftLookdev.encode_mask(0.22, 0.24))
		_bevel_ring(st, Vector3(0.0, height * 0.62, 0.0), 0.18, 0.36, 0.14, 10, 0.03, 0.9, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), CraftLookdev.encode_mask(0.20, 0.30), CraftLookdev.encode_mask(0.92, 0.12))
		for i in 6:
			var a := TAU * float(i) / 6.0
			var xf := Transform3D(Basis(Vector3.UP, a), Vector3(cos(a) * radius * 0.88, 0.02, sin(a) * radius * 0.88))
			_bevel_box(st, Vector3.ZERO, Vector3(0.28, height * 0.62, 0.14), 0.03, 0.8, xf, CraftLookdev.encode_mask(0.16, 0.46), CraftLookdev.encode_mask(0.90, 0.14), CraftLookdev.encode_mask(0.16, 0.76))
		HeroSculptor.bolt_ring(st, Vector3(0.0, height * 0.32, 0.0), radius * 0.66, 8, 0.08, 0.07, 0.86, 1.2, _bolt_cyl())
	)


static func quench_vent_basin(radius: float) -> ArrayMesh:
	var key := "quench_vent_basin:%.2f" % radius
	return _cached(key, func(surfaces: Dictionary, order: Array[String]):
		var st := _slot_st(surfaces, order, "emissive_core")
		_bevel_ring(st, Vector3(0.0, 0.0, 0.0), radius * 0.82, radius, 0.10, 20, 0.024, 0.4, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.14, 0.46), CraftLookdev.encode_mask(0.90, 0.14))
		_bevel_ring(st, Vector3(0.0, -0.02, 0.0), radius * 0.72, radius * 0.86, 0.06, 20, 0.015, 0.45, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.10, 0.84), CraftLookdev.encode_mask(0.65, 0.42))
		_bevel_cyl(st, Vector3(0.0, -0.018, 0.0), radius * 0.78, radius * 0.75, 0.055, 20, 0.014, 0.38, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.12, 0.18, 0.96), CraftLookdev.encode_mask(0.45, 0.12, 1.0), CraftLookdev.encode_mask(0.16, 0.12, 1.0))
		HeroSculptor.bolt_ring(st, Vector3(0.0, 0.05, 0.0), radius * 0.91, 8, minf(0.14, radius * 0.048), 0.032, 0.86, 1.2, _bolt_cyl())
		for i in 8:
			var a := TAU * float(i) / 8.0 + PI / 8.0
			var xf := Transform3D(Basis(Vector3.UP, a), Vector3(cos(a) * radius * 0.80, 0.01, sin(a) * radius * 0.80))
			_bevel_box(st, Vector3.ZERO, Vector3(radius * 0.18, 0.07, 0.14), 0.016, 0.7, xf, CraftLookdev.encode_mask(0.16, 0.54), CraftLookdev.encode_mask(0.88, 0.14), CraftLookdev.encode_mask(0.14, 0.78))
	)


static func dispatch_mast_assembly(height: float, width: float, deck_size: Vector3) -> ArrayMesh:
	var key := "dispatch_mast:%.2f:%.2f:%.2f:%.2f:%.2f" % [height, width, deck_size.x, deck_size.y, deck_size.z]
	return _cached(key, func(surfaces: Dictionary, order: Array[String]):
		var st_iron := _slot_st(surfaces, order, "iron_frame")
		var st_oxide := _slot_st(surfaces, order, "patch_oxide")
		var leg_at := width * 0.5 - 0.12
		var leg_h := maxf(0.4, height - deck_size.y * 0.5)
		var leg_center_y := -deck_size.y * 0.5 - leg_h * 0.5

		for sx_v in [-1.0, 1.0]:
			var sx := float(sx_v)
			for sz_v in [-1.0, 1.0]:
				var sz := float(sz_v)
				var lx := sx * leg_at
				var lz := sz * leg_at
				_bevel_box(st_iron, Vector3(lx, -height + 0.10, lz), Vector3(0.44, 0.20, 0.44), 0.04, 0.8, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.14, 0.84), CraftLookdev.encode_mask(0.88, 0.22), CraftLookdev.encode_mask(0.12, 0.94))
				_bevel_box(st_iron, Vector3(lx, leg_center_y, lz), Vector3(0.20, leg_h, 0.20), 0.032, 0.6, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.12, 0.22), CraftLookdev.encode_mask(0.88, 0.14), CraftLookdev.encode_mask(0.12, 0.80))
				_bevel_box(st_iron, Vector3(lx + sx * 0.06, leg_center_y, lz), Vector3(0.08, leg_h * 0.96, 0.10), 0.016, 0.8, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.18, 0.34), CraftLookdev.encode_mask(0.90, 0.14), CraftLookdev.encode_mask(0.14, 0.76))
				_bevel_box(st_iron, Vector3(lx, leg_center_y, lz + sz * 0.06), Vector3(0.10, leg_h * 0.96, 0.08), 0.016, 0.8, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.18, 0.34), CraftLookdev.encode_mask(0.90, 0.14), CraftLookdev.encode_mask(0.14, 0.76))
				HeroSculptor.bolt_ring(st_iron, Vector3(lx, -height + 0.21, lz), 0.15, 4, 0.032, 0.035, 0.86, 1.2, _bolt_cyl())

		var bays := maxi(2, int(height / 1.6))
		var bay_h := (height - deck_size.y - 0.35) / float(bays)
		for b in bays:
			var y0 := -height + 0.28 + float(b) * bay_h
			var y1 := y0 + bay_h
			var ym := (y0 + y1) * 0.5
			for sz_v in [-1.0, 1.0]:
				var sz := float(sz_v)
				_bevel_box(st_oxide, Vector3(0.0, y1, sz * leg_at), Vector3(width * 0.96, 0.12, 0.12), 0.022, 0.8, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.14, 0.30), CraftLookdev.encode_mask(0.88, 0.14), CraftLookdev.encode_mask(0.14, 0.68))
				var pa := Vector3(-leg_at, y0, sz * leg_at) if b % 2 == 0 else Vector3(leg_at, y0, sz * leg_at)
				var pb := Vector3(leg_at, y1, sz * leg_at) if b % 2 == 0 else Vector3(-leg_at, y1, sz * leg_at)
				_add_strut(st_oxide, pa, pb, 0.095, 0.016, CraftLookdev.encode_mask(0.14, 0.32), CraftLookdev.encode_mask(0.86, 0.16))
			for sx_v in [-1.0, 1.0]:
				var sx := float(sx_v)
				_bevel_box(st_oxide, Vector3(sx * leg_at, y1, 0.0), Vector3(0.12, 0.12, width * 0.96), 0.022, 0.8, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.14, 0.30), CraftLookdev.encode_mask(0.88, 0.14), CraftLookdev.encode_mask(0.14, 0.68))
				var pc := Vector3(sx * leg_at, y0, -leg_at) if b % 2 == 0 else Vector3(sx * leg_at, y0, leg_at)
				var pd := Vector3(sx * leg_at, y1, leg_at) if b % 2 == 0 else Vector3(sx * leg_at, y1, -leg_at)
				_add_strut(st_oxide, pc, pd, 0.095, 0.016, CraftLookdev.encode_mask(0.14, 0.32), CraftLookdev.encode_mask(0.86, 0.16))
			for sx_v in [-1.0, 1.0]:
				var sx := float(sx_v)
				for sz_v in [-1.0, 1.0]:
					var sz := float(sz_v)
					_bevel_box(st_oxide, Vector3(sx * leg_at, y1, sz * leg_at), Vector3(0.28, 0.24, 0.28), 0.03, 1.0, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.20, 0.44), CraftLookdev.encode_mask(0.92, 0.14), CraftLookdev.encode_mask(0.16, 0.72))
			if b == 0:
				for sx_v in [-1.0, 1.0]:
					var sx := float(sx_v)
					_bevel_box(st_iron, Vector3(sx * leg_at, ym, 0.0), Vector3(0.14, 0.14, width * 0.82), 0.02, 0.9, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.16, 0.56), CraftLookdev.encode_mask(0.86, 0.18), CraftLookdev.encode_mask(0.14, 0.80))

		var deck_y := -deck_size.y * 0.5
		_bevel_box(st_iron, Vector3(0.0, deck_y, 0.0), deck_size, 0.055, 0.45, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.10, 0.24), CraftLookdev.encode_mask(0.90, 0.14), CraftLookdev.encode_mask(0.14, 0.76))
		_bevel_box(st_oxide, Vector3(0.0, -deck_size.y - 0.09, 0.0), Vector3(deck_size.x * 0.82, 0.18, deck_size.z * 0.82), 0.04, 0.55, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.14, 0.48), CraftLookdev.encode_mask(0.88, 0.16), CraftLookdev.encode_mask(0.14, 0.82))
		for sx_v in [-1.0, 1.0]:
			var sx := float(sx_v)
			_bevel_box(st_oxide, Vector3(sx * (deck_size.x * 0.5 - 0.08), 0.05, 0.0), Vector3(0.14, 0.16, deck_size.z * 0.92), 0.028, 0.8, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.18, 0.26), CraftLookdev.encode_mask(0.92, 0.14), CraftLookdev.encode_mask(0.14, 0.68))
		for sz_v in [-1.0, 1.0]:
			var sz := float(sz_v)
			_bevel_box(st_oxide, Vector3(0.0, 0.05, sz * (deck_size.z * 0.5 - 0.08)), Vector3(deck_size.x * 0.92, 0.16, 0.14), 0.028, 0.8, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.18, 0.26), CraftLookdev.encode_mask(0.92, 0.14), CraftLookdev.encode_mask(0.14, 0.68))
		for sx_v in [-1.0, 1.0]:
			var sx := float(sx_v)
			for sz_v in [-1.0, 1.0]:
				var sz := float(sz_v)
				var knee_bot := Vector3(sx * leg_at, -deck_size.y - 0.95, sz * leg_at)
				var knee_top := Vector3(sx * (deck_size.x * 0.42), -deck_size.y - 0.04, sz * (deck_size.z * 0.42))
				_add_strut(st_iron, knee_bot, knee_top, 0.12, 0.02, CraftLookdev.encode_mask(0.16, 0.44), CraftLookdev.encode_mask(0.90, 0.14))
				_bevel_cyl(st_iron, Vector3(sx * (deck_size.x * 0.44), 0.02, sz * (deck_size.z * 0.44)), 0.09, 0.075, 0.08, 6, 0.015, 1.2, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.24, 0.56), CraftLookdev.encode_mask(0.92, 0.14), CraftLookdev.encode_mask(0.76, 0.16))
	)


static func apply_dispatch_mast_materials(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance == null:
		return
	var iron := craft_shader_material("dispatch_mast_iron", "oil_slicked_iron", Palette.CHARCOAL.lightened(0.06), Palette.SLATE, 0.62, 0.48, Palette.AMBER, 0.0)
	var oxide := craft_shader_material("dispatch_mast_oxide", "oxidized_hull_plating", Palette.RUST, Palette.COPPER, 0.72, 0.26, Palette.AMBER, 0.0)
	mesh_instance.material_override = null
	mesh_instance.set_surface_override_material(0, iron)
	if mesh_instance.mesh != null and mesh_instance.mesh.get_surface_count() > 1:
		mesh_instance.set_surface_override_material(1, oxide)


static func dispatch_pod(radius: float, height: float) -> ArrayMesh:
	var key := "dispatch_pod:%.2f:%.2f" % [radius, height]
	return _cached(key, func(surfaces: Dictionary, order: Array[String]):
		var st_hull := _slot_st(surfaces, order, "patch_oxide")
		var st_brass := _slot_st(surfaces, order, "copper_coil")
		var body_h := height * 0.54
		_bevel_cyl(st_hull, Vector3(0.0, 0.0, 0.0), radius * 0.94, radius * 0.96, body_h, 12, 0.04, 0.7, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.10, 0.22), CraftLookdev.encode_mask(0.90, 0.14), CraftLookdev.encode_mask(0.16, 0.30))
		_bevel_cyl(st_hull, Vector3(0.0, body_h * 0.5 + height * 0.16, 0.0), radius * 0.90, radius * 0.28, height * 0.34, 12, 0.04, 0.75, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.14, 0.18), CraftLookdev.encode_mask(0.92, 0.12), CraftLookdev.encode_mask(0.72, 0.16))
		_bevel_cyl(st_hull, Vector3(0.0, -body_h * 0.5 - height * 0.10, 0.0), radius * 0.64, radius * 0.88, height * 0.22, 12, 0.035, 0.75, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.16, 0.58), CraftLookdev.encode_mask(0.86, 0.20), CraftLookdev.encode_mask(0.20, 0.72))
		_bevel_ring(st_hull, Vector3(0.0, -body_h * 0.5 - height * 0.18, 0.0), radius * 0.32, radius * 0.58, 0.10, 12, 0.02, 0.9, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.22, 0.14, 0.92), CraftLookdev.encode_mask(0.75, 0.12, 1.0))

		_bevel_ring(st_brass, Vector3(0.0, height * 0.04, 0.0), radius * 0.86, radius * 1.07, height * 0.16, 12, 0.03, 0.85, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.18, 0.24), CraftLookdev.encode_mask(0.94, 0.10))
		_bevel_ring(st_brass, Vector3(0.0, -body_h * 0.42, 0.0), radius * 0.82, radius * 1.02, 0.09, 12, 0.02, 0.9, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.18, 0.36), CraftLookdev.encode_mask(0.92, 0.12))
		HeroSculptor.bolt_ring(st_brass, Vector3(0.0, height * 0.12, 0.0), radius * 0.98, 6, 0.042, 0.04, 0.86, 1.2, _bolt_cyl())

		for i in 4:
			var a := PI * 0.25 + PI * 0.5 * float(i)
			var fin_xf := Transform3D(Basis(Vector3.UP, a), Vector3(cos(a) * radius * 0.98, -height * 0.22, sin(a) * radius * 0.98))
			_bevel_box(st_hull, Vector3.ZERO, Vector3(radius * 0.56, height * 0.36, 0.09), 0.024, 0.9, fin_xf, CraftLookdev.encode_mask(0.16, 0.32), CraftLookdev.encode_mask(0.92, 0.12), CraftLookdev.encode_mask(0.14, 0.72))
	)


static func apply_dispatch_pod_materials(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance == null:
		return
	var oxide := craft_shader_material("dispatch_pod_oxide", "oxidized_hull_plating", Palette.RUST, Palette.CHARCOAL, 0.64, 0.32, Palette.AMBER, 1.8)
	var brass := craft_shader_material("dispatch_pod_brass", "oxidized_hull_plating", Palette.BRASS, Palette.AMBER, 0.42, 0.72, Palette.AMBER, 0.6)
	mesh_instance.material_override = null
	mesh_instance.set_surface_override_material(0, oxide)
	if mesh_instance.mesh != null and mesh_instance.mesh.get_surface_count() > 1:
		mesh_instance.set_surface_override_material(1, brass)


static func reactor_spillway_chute(width: float, length: float) -> ArrayMesh:
	var key := "reactor_spillway_chute:%.2f:%.2f" % [width, length]
	return _cached(key, func(surfaces: Dictionary, order: Array[String]):
		var st := _slot_st(surfaces, order, "spillway_chute")
		var hw := width * 0.5
		var hl := length * 0.5
		var lip_w := minf(1.35, width * 0.11)
		var inner_w := hw - lip_w
		var step_w := lip_w * 0.52

		var profile: Array[Vector2] = [
			Vector2(-hw, -0.14),
			Vector2(hw, -0.14),
			Vector2(hw, 0.22),
			Vector2(hw - 0.10, 0.36),
			Vector2(hw - step_w, 0.36),
			Vector2(hw - step_w - 0.08, 0.22),
			Vector2(inner_w, 0.20),
			Vector2(inner_w - 0.18, 0.09),
			Vector2(inner_w * 0.45, 0.15),
			Vector2(-inner_w * 0.45, 0.15),
			Vector2(-inner_w + 0.18, 0.09),
			Vector2(-inner_w, 0.20),
			Vector2(-hw + step_w + 0.08, 0.22),
			Vector2(-hw + step_w, 0.36),
			Vector2(-hw + 0.10, 0.36),
			Vector2(-hw, 0.22),
		]
		var prof_colors: Array[Color] = [
			CraftLookdev.encode_mask(0.06, 0.90, 0.0),
			CraftLookdev.encode_mask(0.06, 0.90, 0.0),
			CraftLookdev.encode_mask(0.45, 0.62, 0.15),
			CraftLookdev.encode_mask(0.92, 0.16, 0.85),
			CraftLookdev.encode_mask(0.88, 0.18, 0.80),
			CraftLookdev.encode_mask(0.62, 0.52, 0.65),
			CraftLookdev.encode_mask(0.82, 0.26, 0.90),
			CraftLookdev.encode_mask(0.32, 0.78, 0.58),
			CraftLookdev.encode_mask(0.14, 0.12, 0.28),
			CraftLookdev.encode_mask(0.14, 0.12, 0.28),
			CraftLookdev.encode_mask(0.32, 0.78, 0.58),
			CraftLookdev.encode_mask(0.82, 0.26, 0.90),
			CraftLookdev.encode_mask(0.62, 0.52, 0.65),
			CraftLookdev.encode_mask(0.88, 0.18, 0.80),
			CraftLookdev.encode_mask(0.92, 0.16, 0.85),
			CraftLookdev.encode_mask(0.45, 0.62, 0.15),
		]

		var segs := 8
		var rings: Array = []
		var ring_cols: Array = []
		for s in segs + 1:
			var f := float(s) / float(segs)
			var z := lerpf(-hl, hl, f)
			var end_lip := 1.0 if (s == 0 or s == segs) else 0.0
			var y_mul := 0.78 if end_lip > 0.5 else 1.0
			var crown := 0.06 * sin(f * PI)
			var pts: Array[Vector3] = []
			var cols: Array[Color] = []
			for k in profile.size():
				var p2 := profile[k]
				var py := p2.y * y_mul + (crown if p2.y > 0.05 and absf(p2.x) < inner_w - 0.1 else 0.0)
				pts.append(Vector3(p2.x, py, z))
				var bc := prof_colors[k]
				var em := maxf(bc.b, 0.88) if end_lip > 0.5 and p2.y > 0.0 else bc.b
				cols.append(CraftLookdev.encode_mask(maxf(bc.r, 0.72 * end_lip), bc.g, em))
			rings.append(pts)
			ring_cols.append(cols)

		var n_prof := profile.size()
		for s in segs:
			var f0 := float(s) / float(segs)
			var f1 := float(s + 1) / float(segs)
			var r0: Array[Vector3] = rings[s]
			var r1: Array[Vector3] = rings[s + 1]
			var c0_arr: Array[Color] = ring_cols[s]
			var c1_arr: Array[Color] = ring_cols[s + 1]
			for k in n_prof:
				var kn := (k + 1) % n_prof
				var a := r0[k]
				var b := r0[kn]
				var c := r1[kn]
				var d := r1[k]
				var edge := b - a
				var outward := Vector3(edge.y, -edge.x, 0.0).normalized()
				var uv0 := Vector2((a.x + hw) / width, f0)
				var uv1 := Vector2((b.x + hw) / width, f0)
				var uv2 := Vector2((c.x + hw) / width, f1)
				var uv3 := Vector2((d.x + hw) / width, f1)
				_add_quad_uv(st, a, b, c, d, outward, uv0, uv1, uv2, uv3, c0_arr[k], c0_arr[kn], c1_arr[kn], c1_arr[k])

		var front_c := Vector3(0.0, 0.04, -hl)
		var front_r: Array[Vector3] = rings[0]
		var front_cols: Array[Color] = ring_cols[0]
		for k in n_prof:
			var kn := (k + 1) % n_prof
			var pa := front_r[k]
			var pb := front_r[kn]
			_add_tri_uv(st, front_c, pb, pa, Vector3.FORWARD,
				Vector2(0.5, 0.0), Vector2((pb.x + hw) / width, 0.0), Vector2((pa.x + hw) / width, 0.0),
				CraftLookdev.encode_mask(0.60, 0.35, 0.80), front_cols[kn], front_cols[k])

		var back_c := Vector3(0.0, 0.04, hl)
		var back_r: Array[Vector3] = rings[segs]
		var back_cols: Array[Color] = ring_cols[segs]
		for k in n_prof:
			var kn := (k + 1) % n_prof
			var pa := back_r[k]
			var pb := back_r[kn]
			_add_tri_uv(st, back_c, pa, pb, Vector3.BACK,
				Vector2(0.5, 1.0), Vector2((pa.x + hw) / width, 1.0), Vector2((pb.x + hw) / width, 1.0),
				CraftLookdev.encode_mask(0.60, 0.35, 0.80), back_cols[k], back_cols[kn])

		for sx in [-1.0, 1.0]:
			for rf in [-0.36, -0.12, 0.12, 0.36]:
				_bevel_box(st, Vector3(sx * (hw - step_w * 0.5), 0.34, length * rf), Vector3(step_w * 0.88, 0.16, 0.42), 0.03, 0.6, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.28, 0.46, 0.25), CraftLookdev.encode_mask(0.92, 0.14, 0.72), CraftLookdev.encode_mask(0.18, 0.78, 0.0))
	)


static func reward_canister_band(radius: float, height: float) -> ArrayMesh:
	var key := "reward_canister_band:%.3f:%.3f" % [radius, height]
	return _cached(key, func(surfaces: Dictionary, order: Array[String]):
		var st := _slot_st(surfaces, order, "hull_plating")
		_bevel_ring(st, Vector3.ZERO, radius * 0.90, radius, height, 14, 0.018, 1.2, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.18, 0.06), CraftLookdev.encode_mask(0.88, 0.04))
		HeroSculptor.bolt_ring(st, Vector3(0.0, 0.0, 0.0), radius * 0.99, 6, 0.022, 0.025, 0.86, 1.2, _bolt_cyl())
	)


static func reward_bone_band_material() -> StandardMaterial3D:
	var cache_key := "reward_bone_band_std"
	if _mat_cache.has(cache_key):
		return _mat_cache[cache_key] as StandardMaterial3D
	var mat := StandardMaterial3D.new()
	mat.resource_name = "enemy_boss_reward_bone_band"
	mat.albedo_color = Palette.SAND
	mat.roughness = 0.56
	mat.metallic = 0.08
	PaletteMaterials.surface_grain(mat)
	mat.next_pass = BakeLook.edge_lift()
	_mat_cache[cache_key] = mat
	return mat


static func reward_canister_shell(radius: float, height: float) -> ArrayMesh:
	var key := "reward_canister_shell:%.3f:%.3f" % [radius, height]
	return _cached(key, func(surfaces: Dictionary, order: Array[String]):
		var st := _slot_st(surfaces, order, "reward_canister")
		var c_body := Palette.AMBER
		var c_edge := Palette.AMBER.lightened(0.16)
		var c_cap := Palette.AMBER.darkened(0.08)
		_bevel_cyl(st, Vector3.ZERO, radius * 0.98, radius * 0.96, height, 14, 0.045, 0.85, Transform3D.IDENTITY, c_body, c_edge, c_cap)
		_bevel_ring(st, Vector3(0.0, height * 0.34, 0.0), radius * 0.84, radius * 1.03, height * 0.12, 14, 0.022, 1.0, Transform3D.IDENTITY, c_cap, c_edge)
		_bevel_ring(st, Vector3(0.0, -height * 0.34, 0.0), radius * 0.84, radius * 1.04, height * 0.12, 14, 0.022, 1.0, Transform3D.IDENTITY, c_cap, c_edge)
		for i in 4:
			var a := TAU * float(i) / 4.0
			var xf := Transform3D(Basis(Vector3.UP, a), Vector3(cos(a) * radius * 0.96, 0.0, sin(a) * radius * 0.96))
			_bevel_box(st, Vector3.ZERO, Vector3(0.06, height * 0.64, 0.06), 0.014, 1.2, xf, c_cap, c_edge, c_cap)
	)


static func reward_scrap_fallback(size: float) -> ArrayMesh:
	var key := "reward_scrap_fallback:%.3f" % size
	return _cached(key, func(surfaces: Dictionary, order: Array[String]):
		var st := _slot_st(surfaces, order, "field")
		var c_main := Palette.AMBER
		var c_hi := Palette.AMBER.lightened(0.14)
		var c_lo := Palette.AMBER.darkened(0.12)
		_bevel_box(st, Vector3.ZERO, Vector3(size * 0.82, size * 0.68, size * 0.82), size * 0.12, 0.9, Transform3D.IDENTITY, c_main, c_hi, c_lo)
		_bevel_ring(st, Vector3.ZERO, size * 0.24, size * 0.44, size * 0.20, 8, 0.025, 1.0, Transform3D(Basis(Vector3.RIGHT, 0.35), Vector3.ZERO), c_lo, c_hi)
	)


static func brindle_scooter_hull(size: Vector3) -> ArrayMesh:
	var key := "brindle_scooter_hull:%.2f:%.2f:%.2f" % [size.x, size.y, size.z]
	return _cached(key, func(surfaces: Dictionary, order: Array[String]):
		var st := _slot_st(surfaces, order, "hull_plating")
		_bevel_box(st, Vector3(0.0, 0.0, 0.0), Vector3(size.x * 0.92, size.y * 0.72, size.z * 0.92), 0.14, 0.6, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.12, 0.24), CraftLookdev.encode_mask(0.90, 0.14), CraftLookdev.encode_mask(0.14, 0.78))
		_bevel_box(st, Vector3(0.0, size.y * 0.22, -size.z * 0.28), Vector3(size.x * 0.68, size.y * 0.44, size.z * 0.44), 0.10, 0.7, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.16, 0.20), CraftLookdev.encode_mask(0.92, 0.12), CraftLookdev.encode_mask(0.14, 0.72))
		for sx_v in [-1.0, 1.0]:
			var sx := float(sx_v)
			_bevel_cyl(st, Vector3.ZERO, size.y * 0.24, size.y * 0.20, size.z * 0.48, 10, 0.04, 0.8, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(sx * size.x * 0.44, -size.y * 0.08, size.z * 0.26)), CraftLookdev.encode_mask(0.16, 0.42, 0.72), CraftLookdev.encode_mask(0.90, 0.14, 0.85), CraftLookdev.encode_mask(0.22, 0.24, 0.95))
	)


static func admirals_crest_badge(radius: float, height: float) -> ArrayMesh:
	var key := "admirals_crest_badge:%.3f:%.3f" % [radius, height]
	return _cached(key, func(surfaces: Dictionary, order: Array[String]):
		var st := _slot_st(surfaces, order, "copper_coil")
		_bevel_cyl(st, Vector3.ZERO, radius, radius * 0.94, height, 10, 0.024, 1.0, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.14, 0.24, 0.20), CraftLookdev.encode_mask(0.94, 0.10, 0.45), CraftLookdev.encode_mask(0.20, 0.18, 0.35))
		_bevel_ring(st, Vector3(0.0, height * 0.32, 0.0), radius * 0.64, radius * 0.92, height * 0.42, 10, 0.018, 1.1, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.18, 0.30, 0.30), CraftLookdev.encode_mask(0.94, 0.10, 0.60))
		_bevel_cyl(st, Vector3(0.0, height * 0.38, 0.0), radius * 0.34, radius * 0.22, height * 0.45, 5, 0.018, 1.2, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.22, 0.16, 0.85), CraftLookdev.encode_mask(0.94, 0.10, 0.95), CraftLookdev.encode_mask(0.30, 0.12, 1.0))
		HeroSculptor.bolt_ring(st, Vector3(0.0, height * 0.48, 0.0), radius * 0.78, 5, 0.036, 0.028, 0.86, 1.2, _bolt_cyl())
	)


static func dig_cable_coupler(radius: float) -> ArrayMesh:
	var key := "dig_cable_coupler:%.3f" % radius
	return _cached(key, func(surfaces: Dictionary, order: Array[String]):
		var st := _slot_st(surfaces, order, "emissive_core")
		_bevel_cyl(st, Vector3.ZERO, radius * 0.94, radius * 0.88, radius * 1.15, 8, radius * 0.14, 0.9, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.14, 0.34, 0.0), CraftLookdev.encode_mask(0.86, 0.18, 0.0), CraftLookdev.encode_mask(0.16, 0.42, 0.0))
		_bevel_ring(st, Vector3(0.0, radius * 0.34, 0.0), radius * 0.72, radius * 1.06, radius * 0.26, 8, radius * 0.06, 1.0, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.16, 0.44, 0.0), CraftLookdev.encode_mask(0.90, 0.14, 0.0))
		_bevel_ring(st, Vector3(0.0, -radius * 0.34, 0.0), radius * 0.72, radius * 1.06, radius * 0.26, 8, radius * 0.06, 1.0, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.16, 0.56, 0.0), CraftLookdev.encode_mask(0.90, 0.16, 0.0))
		_bevel_ring(st, Vector3.ZERO, radius * 0.84, radius * 1.02, radius * 0.30, 8, radius * 0.05, 1.0, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.18, 0.10, 0.96), CraftLookdev.encode_mask(0.42, 0.08, 1.0))
		HeroSculptor.bolt_ring(st, Vector3(0.0, radius * 0.58, 0.0), radius * 0.62, 4, radius * 0.12, radius * 0.12, 0.86, 1.2, _bolt_cyl())
	)


static func dig_cable_coupler_material() -> ShaderMaterial:
	var mat := craft_shader_material("dig_cable_coupler", "plasma_conduit_core", Palette.VERDIGRIS.darkened(0.24), Palette.CHARCOAL, 0.62, 0.34, Palette.ANCIENT, 2.4)
	mat.set_shader_parameter("emissive_pulse_speed", 1.8)
	mat.set_shader_parameter("emissive_pulse_amount", 0.18)
	return mat


static func dig_cable_segment(width: float, height: float, length: float) -> ArrayMesh:
	var key := "dig_cable_segment:%.3f:%.3f:%.3f" % [width, height, length]
	return _cached(key, func(surfaces: Dictionary, order: Array[String]):
		var st := _slot_st(surfaces, order, "iron_frame")
		_bevel_box(st, Vector3.ZERO, Vector3(width, height, length), minf(0.045, minf(width, height) * 0.28), 0.75, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.10, 0.30), CraftLookdev.encode_mask(0.84, 0.18), CraftLookdev.encode_mask(0.12, 0.82))
		for zf in [-0.34, 0.34]:
			_bevel_box(st, Vector3(0.0, 0.015, length * zf), Vector3(width * 1.16, height * 1.16, minf(0.14, length * 0.16)), 0.025, 0.95, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.16, 0.42), CraftLookdev.encode_mask(0.90, 0.14), CraftLookdev.encode_mask(0.14, 0.84))
	)


static func dig_conduit_material() -> ShaderMaterial:
	return craft_shader_material("dig_conduit", "oil_slicked_iron", Palette.VERDIGRIS.darkened(0.16), Palette.CHARCOAL, 0.66, 0.32, Palette.ANCIENT, 0.0)


static func dig_skylight_beam(top_r: float, bot_r: float, height: float, segs := 20) -> ArrayMesh:
	var key := "dig_skylight_beam:%.2f:%.2f:%.2f:%d" % [top_r, bot_r, height, segs]
	return _cached(key, func(surfaces: Dictionary, order: Array[String]):
		var st := _slot_st(surfaces, order, "skylight_beam")
		var hh := height * 0.5
		var bands := 4
		for b in bands:
			var f0 := float(b) / float(bands)
			var f1 := float(b + 1) / float(bands)
			var y0 := lerpf(hh, -hh, f0)
			var y1 := lerpf(hh, -hh, f1)
			var r0 := lerpf(top_r, bot_r, f0)
			var r1 := lerpf(top_r, bot_r, f1)
			for i in segs:
				var a0 := TAU * float(i) / float(segs)
				var a1 := TAU * float(i + 1) / float(segs)
				var u0 := float(i) / float(segs)
				var u1 := float(i + 1) / float(segs)
				var p00 := Vector3(cos(a0) * r0, y0, sin(a0) * r0)
				var p10 := Vector3(cos(a1) * r0, y0, sin(a1) * r0)
				var p11 := Vector3(cos(a1) * r1, y1, sin(a1) * r1)
				var p01 := Vector3(cos(a0) * r1, y1, sin(a0) * r1)
				var mid := Vector3(cos((a0 + a1) * 0.5), 0.0, sin((a0 + a1) * 0.5))
				var dy := y0 - y1
				var dr := r1 - r0
				var n := (mid * dy + Vector3.UP * dr).normalized()
				_add_quad_uv(st, p00, p10, p11, p01, n, Vector2(u0, f0), Vector2(u1, f0), Vector2(u1, f1), Vector2(u0, f1), Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE)
	)


static func dig_skylight_collar(top_r: float) -> ArrayMesh:
	var key := "dig_skylight_collar:%.2f" % top_r
	return _cached(key, func(surfaces: Dictionary, order: Array[String]):
		var st := _slot_st(surfaces, order, "iron_frame")
		var r_in := maxf(1.2, top_r * 0.94)
		var r_out := top_r * 1.18
		var col_h := clampf(top_r * 0.24, 0.9, 3.6)
		_bevel_ring(st, Vector3.ZERO, r_in, r_out, col_h, 16, minf(0.18, col_h * 0.2), 0.25, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.12, 0.44), CraftLookdev.encode_mask(0.88, 0.16))
		_bevel_ring(st, Vector3(0.0, -col_h * 0.46, 0.0), r_in * 0.98, r_out * 1.04, col_h * 0.34, 16, minf(0.10, col_h * 0.12), 0.28, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.14, 0.62), CraftLookdev.encode_mask(0.90, 0.14))
		var lugs := 8
		for i in lugs:
			var a := TAU * float(i) / float(lugs)
			var xf := Transform3D(Basis(Vector3.UP, a), Vector3(cos(a) * ((r_in + r_out) * 0.5), 0.0, sin(a) * ((r_in + r_out) * 0.5)))
			_bevel_box(st, Vector3.ZERO, Vector3((r_out - r_in) * 0.92, col_h * 1.12, maxf(0.45, top_r * 0.10)), 0.06, 0.4, xf, CraftLookdev.encode_mask(0.18, 0.50), CraftLookdev.encode_mask(0.92, 0.14), CraftLookdev.encode_mask(0.14, 0.80))
	)


static func dig_skylight_collar_material() -> ShaderMaterial:
	return craft_shader_material("dig_skylight_collar", "oil_slicked_iron", Palette.CHARCOAL.lightened(0.08), Palette.VERDIGRIS.darkened(0.28), 0.68, 0.44, Palette.ANCIENT, 0.0)


static func swarm_pool_disc(radius: float, thickness: float) -> ArrayMesh:
	var key := "swarm_pool_disc:%.2f:%.2f" % [radius, thickness]
	return _cached(key, func(surfaces: Dictionary, order: Array[String]):
		var st := _slot_st(surfaces, order, "swarm_pool")
		var segs := 32
		var hh := thickness * 0.5
		var lip := minf(1.2, radius * 0.04)
		var r_inner := maxf(1.0, radius - lip)
		var top_c := Vector3(0.0, hh, 0.0)
		var bot_c := Vector3(0.0, -hh, 0.0)
		for i in segs:
			var a0 := TAU * float(i) / float(segs)
			var a1 := TAU * float(i + 1) / float(segs)
			var c0 := cos(a0)
			var s0 := sin(a0)
			var c1 := cos(a1)
			var s1 := sin(a1)
			var ti0 := Vector3(c0 * r_inner, hh, s0 * r_inner)
			var ti1 := Vector3(c1 * r_inner, hh, s1 * r_inner)
			var to0 := Vector3(c0 * radius, hh - 0.12, s0 * radius)
			var to1 := Vector3(c1 * radius, hh - 0.12, s1 * radius)
			var bo0 := Vector3(c0 * radius, -hh + 0.10, s0 * radius)
			var bo1 := Vector3(c1 * radius, -hh + 0.10, s1 * radius)
			var bi0 := Vector3(c0 * r_inner, -hh, s0 * r_inner)
			var bi1 := Vector3(c1 * r_inner, -hh, s1 * r_inner)
			var radial := Vector3(cos((a0 + a1) * 0.5), 0.0, sin((a0 + a1) * 0.5))
			HeroSculptor.add_planar_tri(st, top_c, ti0, ti1, Vector3.UP, CraftLookdev.encode_mask(0.08, 0.12, 0.35), CraftLookdev.encode_mask(0.14, 0.18, 0.65), CraftLookdev.encode_mask(0.14, 0.18, 0.65), 0.08)
			var n_top_chamfer := (radial * 0.12 + Vector3.UP * lip).normalized()
			_add_quad(st, ti0, ti1, to1, to0, n_top_chamfer, CraftLookdev.encode_mask(0.86, 0.14, 0.88), 0.16)
			_add_quad(st, to0, to1, bo1, bo0, radial, CraftLookdev.encode_mask(0.24, 0.64, 0.25), 0.16)
			var n_bot_chamfer := (radial * 0.10 + Vector3.DOWN * lip).normalized()
			_add_quad(st, bo0, bo1, bi1, bi0, n_bot_chamfer, CraftLookdev.encode_mask(0.14, 0.86, 0.0), 0.16)
			HeroSculptor.add_planar_tri(st, bot_c, bi1, bi0, Vector3.DOWN, CraftLookdev.encode_mask(0.10, 0.90, 0.0), CraftLookdev.encode_mask(0.10, 0.90, 0.0), CraftLookdev.encode_mask(0.10, 0.90, 0.0), 0.08)
	)


static func swarm_pool_material() -> ShaderMaterial:
	var cache_key := "swarm_pool_mat:%s" % str(FlashGuard.on)
	if _mat_cache.has(cache_key):
		return _mat_cache[cache_key] as ShaderMaterial
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque;
uniform vec4 base_color : source_color = vec4(0.16, 0.36, 0.34, 0.72);
uniform vec4 foam_color : source_color = vec4(0.56, 0.88, 0.66, 1.0);
uniform float calm = 0.0;
void fragment() {
	float t = TIME * mix(1.2, 0.15, calm);
	vec2 p = UV * 6.0;
	float w1 = sin(p.x * 2.1 + t) * cos(p.y * 1.9 - t * 0.8);
	float w2 = sin((p.x + p.y) * 1.5 - t * 1.3);
	float ripple = clamp(0.5 + 0.28 * w1 + 0.22 * w2, 0.0, 1.0);
	float rim = clamp(COLOR.r, 0.0, 1.0);
	float seam = clamp(COLOR.b, 0.0, 1.0);
	vec3 col = mix(base_color.rgb * 0.78, base_color.rgb * 1.18, ripple);
	col = mix(col, foam_color.rgb * 0.82, rim * 0.45 + smoothstep(0.76, 0.96, ripple) * 0.22);
	ALBEDO = col;
	ROUGHNESS = mix(0.28, 0.56, rim);
	METALLIC = 0.12;
	EMISSION = foam_color.rgb * (seam * 0.14 + smoothstep(0.80, 0.98, ripple) * 0.10) * mix(1.0, 0.45, calm);
	ALPHA = clamp(mix(0.62, 0.92, rim), 0.0, 1.0);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.resource_name = "enemy_boss_swarm_pool"
	mat.set_shader_parameter("base_color", Color(Palette.VERDIGRIS, 0.72))
	mat.set_shader_parameter("foam_color", Palette.ANCIENT)
	mat.set_shader_parameter("calm", 1.0 if FlashGuard.on else 0.0)
	_mat_cache[cache_key] = mat
	return mat


static func waking_arena_pad(radius: float, thickness: float) -> ArrayMesh:
	var key := "waking_arena_pad:%.2f:%.2f" % [radius, thickness]
	return _cached(key, func(surfaces: Dictionary, order: Array[String]):
		var st := _slot_st(surfaces, order, "waking_pad")
		var segs := 48
		var hh := thickness * 0.5
		var bevel := 0.14
		var r_flat := maxf(1.0, radius - bevel)
		var r_skirt := maxf(1.0, radius - 0.55)
		var y_mid := -hh + 0.48
		var top_c := Vector3(0.0, hh, 0.0)
		var bot_c := Vector3(0.0, -hh, 0.0)
		for i in segs:
			var a0 := TAU * float(i) / float(segs)
			var a1 := TAU * float(i + 1) / float(segs)
			var c0 := cos(a0)
			var s0 := sin(a0)
			var c1 := cos(a1)
			var s1 := sin(a1)
			var radial := Vector3(cos((a0 + a1) * 0.5), 0.0, sin((a0 + a1) * 0.5))
			var t0 := Vector3(c0 * r_flat, hh, s0 * r_flat)
			var t1 := Vector3(c1 * r_flat, hh, s1 * r_flat)
			var e0 := Vector3(c0 * radius, hh - bevel, s0 * radius)
			var e1 := Vector3(c1 * radius, hh - bevel, s1 * radius)
			var m0 := Vector3(c0 * radius, y_mid, s0 * radius)
			var m1 := Vector3(c1 * radius, y_mid, s1 * radius)
			var b0 := Vector3(c0 * r_skirt, -hh, s0 * r_skirt)
			var b1 := Vector3(c1 * r_skirt, -hh, s1 * r_skirt)
			HeroSculptor.add_planar_tri(st, top_c, t0, t1, Vector3.UP, CraftLookdev.encode_mask(0.06, 0.10, 0.0), CraftLookdev.encode_mask(0.08, 0.14, 0.0), CraftLookdev.encode_mask(0.08, 0.14, 0.0), 0.12)
			var n_chamfer := (radial + Vector3.UP).normalized()
			_add_quad(st, t0, t1, e1, e0, n_chamfer, CraftLookdev.encode_mask(0.86, 0.14, 0.0), 0.25)
			_add_quad(st, e0, e1, m1, m0, radial, CraftLookdev.encode_mask(0.16, 0.42, 0.0), 0.25)
			var dy := y_mid - (-hh)
			var dr := radius - r_skirt
			var n_skirt := (radial * dy + Vector3.DOWN * dr).normalized()
			_add_quad(st, m0, m1, b1, b0, n_skirt, CraftLookdev.encode_mask(0.20, 0.72, 0.0), 0.25)
			HeroSculptor.add_planar_tri(st, bot_c, b1, b0, Vector3.DOWN, CraftLookdev.encode_mask(0.10, 0.90, 0.0), CraftLookdev.encode_mask(0.10, 0.90, 0.0), CraftLookdev.encode_mask(0.10, 0.90, 0.0), 0.12)
	)


static func pit_jaw_fallback_mesh(radius := 1.5, height := 0.12) -> ArrayMesh:
	var key := "pit_jaw_fallback:%.2f:%.2f" % [radius, height]
	return _cached(key, func(surfaces: Dictionary, order: Array[String]):
		var st := _slot_st(surfaces, order, "iron_frame")
		_bevel_cyl(st, Vector3.ZERO, radius, radius * 0.94, height, 16, 0.03, 0.6, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.12, 0.46), CraftLookdev.encode_mask(0.90, 0.14), CraftLookdev.encode_mask(0.14, 0.64))
		_bevel_ring(st, Vector3(0.0, height * 0.35, 0.0), radius * 0.74, radius * 0.98, 0.08, 16, 0.02, 0.8, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.16, 0.48), CraftLookdev.encode_mask(0.92, 0.12))
		for i in 8:
			var a := TAU * float(i) / 8.0
			var xf := Transform3D(Basis(Vector3.UP, a), Vector3(cos(a) * (radius * 0.86), 0.15, sin(a) * (radius * 0.86)))
			_bevel_box(st, Vector3.ZERO, Vector3(0.24, 0.32, 0.20), 0.04, 1.0, xf, CraftLookdev.encode_mask(0.22, 0.28, 0.65), CraftLookdev.encode_mask(0.92, 0.12, 0.85), CraftLookdev.encode_mask(0.16, 0.68, 0.0))
	)


static func burrow_marker_mesh(radius: float, height: float) -> ArrayMesh:
	var key := "burrow_marker:%.2f:%.2f" % [radius, height]
	return _cached(key, func(surfaces: Dictionary, order: Array[String]):
		var st := _slot_st(surfaces, order, "part_state")
		_bevel_cyl(st, Vector3.ZERO, radius, radius * 0.94, height, 20, minf(0.018, height * 0.35), 0.6, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.12, 0.56), CraftLookdev.encode_mask(0.88, 0.16), CraftLookdev.encode_mask(0.14, 0.52))
		_bevel_ring(st, Vector3(0.0, height * 0.35, 0.0), radius * 0.72, radius * 0.96, height * 0.8, 20, 0.012, 0.7, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.16, 0.44), CraftLookdev.encode_mask(0.90, 0.14))
		HeroSculptor.bolt_ring(st, Vector3(0.0, height * 0.55, 0.0), radius * 0.84, 6, 0.08, 0.03, 0.86, 1.2, _bolt_cyl())
	)


static func swarm_remnant_body(size: float, height: float) -> ArrayMesh:
	var key := "swarm_remnant_body:%.2f:%.2f" % [size, height]
	return _cached(key, func(surfaces: Dictionary, order: Array[String]):
		var st := _slot_st(surfaces, order, "ancient_enamel")
		_bevel_cyl(st, Vector3.ZERO, size, size * 0.92, height, 3, 0.035, 0.8, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.10, 0.18), CraftLookdev.encode_mask(0.86, 0.14), CraftLookdev.encode_mask(0.12, 0.22))
		_bevel_cyl(st, Vector3(0.0, height * 0.35, 0.0), size * 0.68, size * 0.56, height * 0.42, 3, 0.025, 0.9, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.14, 0.20), CraftLookdev.encode_mask(0.90, 0.12), CraftLookdev.encode_mask(0.16, 0.20))
	)


static func swarm_remnant_seam(size: float, height: float) -> ArrayMesh:
	var key := "swarm_remnant_seam:%.2f:%.2f" % [size, height]
	return _cached(key, func(surfaces: Dictionary, order: Array[String]):
		var st := _slot_st(surfaces, order, "ancient_light")
		_bevel_cyl(st, Vector3.ZERO, size, size * 0.88, height, 3, 0.025, 1.0, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.20, 0.10, 0.95), CraftLookdev.encode_mask(0.75, 0.08, 1.0), CraftLookdev.encode_mask(0.25, 0.08, 1.0))
	)


static func ramp_flipper_plate(size: Vector3) -> ArrayMesh:
	var key := "ramp_flipper_plate:%.2f:%.2f:%.2f" % [size.x, size.y, size.z]
	return _cached(key, func(surfaces: Dictionary, order: Array[String]):
		var st := _slot_st(surfaces, order, "working_tool")
		_bevel_box(st, Vector3.ZERO, size, minf(0.055, size.y * 0.32), 0.35, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.10, 0.24), CraftLookdev.encode_mask(0.90, 0.14), CraftLookdev.encode_mask(0.12, 0.82))
		for sx_v in [-0.42, 0.42]:
			var sx := float(sx_v)
			_bevel_box(st, Vector3(size.x * sx, size.y * 0.18, 0.0), Vector3(0.24, size.y * 0.68, size.z * 0.90), 0.028, 0.6, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.18, 0.36), CraftLookdev.encode_mask(0.92, 0.14), CraftLookdev.encode_mask(0.14, 0.76))
		for sz_v in [-0.36, 0.0, 0.36]:
			var sz := float(sz_v)
			_bevel_box(st, Vector3(0.0, -size.y * 0.22, size.z * sz), Vector3(size.x * 0.86, size.y * 0.56, 0.22), 0.026, 0.6, Transform3D.IDENTITY, CraftLookdev.encode_mask(0.16, 0.52), CraftLookdev.encode_mask(0.88, 0.16), CraftLookdev.encode_mask(0.14, 0.84))
	)


static func waking_enamel_material(base_mat: StandardMaterial3D, is_brass_override := false) -> StandardMaterial3D:
	var updated := base_mat.duplicate() as StandardMaterial3D if base_mat != null else StandardMaterial3D.new()
	if is_brass_override:
		updated.albedo_color = Palette.VERDIGRIS
		updated.metallic = 0.18
		updated.roughness = 0.58
	else:
		updated.roughness = 0.48
		updated.metallic = maxf(updated.metallic, 0.14)
	PaletteMaterials.surface_grain(updated)
	if updated.next_pass == null:
		updated.next_pass = BakeLook.edge_lift()
	return updated
