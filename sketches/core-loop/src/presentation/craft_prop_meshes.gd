class_name CraftPropMeshes
extends RefCounted


const Palette := preload("res://src/core/palette.gd")

static var _mesh_cache: Dictionary = {}
static var _mat_cache: Dictionary = {}
static var _wear_shader: Shader = null


static func reset_for_tests() -> void:
	_mesh_cache.clear()
	_mat_cache.clear()
	_wear_shader = null



static func weathered_material(color: Color, roughness := 0.74, metallic := 0.24, emission_energy := 0.0, tag := "", use_plate := true, tile_m := 3.2) -> StandardMaterial3D:
	var key := "mat:%s:%.2f:%.2f:%.2f:%s:%s:%.2f" % [color.to_html(true), roughness, metallic, emission_energy, tag, str(use_plate), tile_m]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var mat := StandardMaterial3D.new()
	mat.resource_name = "craft_" + (tag if tag != "" else color.to_html(false))
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	Palette.surface_grain(mat)
	if use_plate:
		var plate := Palette.look_texture("rusted-salvaged-plate-worn", true)
		if plate != null:
			mat.albedo_texture = plate
			mat.uv1_triplanar = true
			mat.uv1_scale = Vector3.ONE / tile_m
	if emission_energy > 0.0:
		mat.emission_enabled = true
		mat.emission = Color(color.r, color.g, color.b, 1.0)
		mat.emission_energy_multiplier = emission_energy
		if roughness >= 0.9:
			mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_mat_cache[key] = mat
	return mat



static func _cached(key: String, builder: Callable) -> ArrayMesh:
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	builder.call(st)
	st.generate_tangents()
	var mesh: ArrayMesh = st.commit()
	_mesh_cache[key] = mesh
	return mesh


static func _uv_for(p: Vector3, n: Vector3, uv_scale: float) -> Vector2:
	var an := Vector3(absf(n.x), absf(n.y), absf(n.z))
	if an.y >= an.x and an.y >= an.z:
		return Vector2(p.x, p.z) * uv_scale
	if an.x >= an.z:
		return Vector2(p.z, p.y) * uv_scale
	return Vector2(p.x, p.y) * uv_scale


static func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3, uv_scale := 0.5) -> void:
	var nn := n.normalized()
	if nn.length_squared() < 0.0001:
		return
	var p1 := b
	var p2 := c
	if (p1 - a).cross(p2 - a).dot(nn) > 0.0:
		var tmp := p1
		p1 = p2
		p2 = tmp
	for v in [a, p1, p2]:
		st.set_normal(nn)
		st.set_uv(_uv_for(v, nn, uv_scale))
		st.add_vertex(v)


static func _add_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, uv_scale := 0.5) -> void:
	_add_tri(st, a, b, c, n, uv_scale)
	_add_tri(st, a, c, d, n, uv_scale)


static func _bevel_box(st: SurfaceTool, center: Vector3, size: Vector3, bevel := 0.04, uv_scale := 0.5, xf := Transform3D.IDENTITY) -> void:
	var h := size * 0.5
	var b := minf(bevel, minf(h.x, minf(h.y, h.z)) * 0.42)
	var xi := h.x - b
	var yi := h.y - b
	var zi := h.z - b
	var pt := func(x: float, y: float, z: float) -> Vector3:
		return xf * (center + Vector3(x, y, z))
	var nrm := func(v: Vector3) -> Vector3:
		return (xf.basis * v).normalized()

	_add_quad(st, pt.call(-xi, -yi, h.z), pt.call(xi, -yi, h.z), pt.call(xi, yi, h.z), pt.call(-xi, yi, h.z), nrm.call(Vector3.BACK), uv_scale)
	_add_quad(st, pt.call(xi, -yi, -h.z), pt.call(-xi, -yi, -h.z), pt.call(-xi, yi, -h.z), pt.call(xi, yi, -h.z), nrm.call(Vector3.FORWARD), uv_scale)
	_add_quad(st, pt.call(h.x, -yi, zi), pt.call(h.x, -yi, -zi), pt.call(h.x, yi, -zi), pt.call(h.x, yi, zi), nrm.call(Vector3.RIGHT), uv_scale)
	_add_quad(st, pt.call(-h.x, -yi, -zi), pt.call(-h.x, -yi, zi), pt.call(-h.x, yi, zi), pt.call(-h.x, yi, -zi), nrm.call(Vector3.LEFT), uv_scale)
	_add_quad(st, pt.call(-xi, h.y, zi), pt.call(xi, h.y, zi), pt.call(xi, h.y, -zi), pt.call(-xi, h.y, -zi), nrm.call(Vector3.UP), uv_scale)
	_add_quad(st, pt.call(-xi, -h.y, -zi), pt.call(xi, -h.y, -zi), pt.call(xi, -h.y, zi), pt.call(-xi, -h.y, zi), nrm.call(Vector3.DOWN), uv_scale)

	if b <= 0.0001:
		return

	for sy in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var n: Vector3 = (xf.basis * Vector3(0.0, sy, sz)).normalized()
			_add_quad(st,
				xf * (center + Vector3(-xi, sy * h.y, sz * zi)),
				xf * (center + Vector3(xi, sy * h.y, sz * zi)),
				xf * (center + Vector3(xi, sy * yi, sz * h.z)),
				xf * (center + Vector3(-xi, sy * yi, sz * h.z)),
				n, uv_scale)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var n: Vector3 = (xf.basis * Vector3(sx, sy, 0.0)).normalized()
			_add_quad(st,
				xf * (center + Vector3(sx * xi, sy * h.y, -zi)),
				xf * (center + Vector3(sx * xi, sy * h.y, zi)),
				xf * (center + Vector3(sx * h.x, sy * yi, zi)),
				xf * (center + Vector3(sx * h.x, sy * yi, -zi)),
				n, uv_scale)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var n: Vector3 = (xf.basis * Vector3(sx, 0.0, sz)).normalized()
			_add_quad(st,
				xf * (center + Vector3(sx * h.x, -yi, sz * zi)),
				xf * (center + Vector3(sx * h.x, yi, sz * zi)),
				xf * (center + Vector3(sx * xi, yi, sz * h.z)),
				xf * (center + Vector3(sx * xi, -yi, sz * h.z)),
				n, uv_scale)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var n: Vector3 = (xf.basis * Vector3(sx, sy, sz)).normalized()
				_add_tri(st,
					xf * (center + Vector3(sx * h.x, sy * yi, sz * zi)),
					xf * (center + Vector3(sx * xi, sy * h.y, sz * zi)),
					xf * (center + Vector3(sx * xi, sy * yi, sz * h.z)),
					n, uv_scale)


static func _bevel_cyl(st: SurfaceTool, center: Vector3, r_bot: float, r_top: float, height: float, segs := 12, bevel := 0.03, uv_scale := 0.5, xf := Transform3D.IDENTITY) -> void:
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
			_add_quad(st, p00, p10, p11, p01, fn, uv_scale)
		var top_r: float = rings[-1][1]
		var top_y: float = rings[-1][0]
		_add_tri(st,
			xf * (center + Vector3(0.0, top_y, 0.0)),
			xf * (center + Vector3(c0 * top_r, top_y, s0 * top_r)),
			xf * (center + Vector3(c1 * top_r, top_y, s1 * top_r)),
			(xf.basis * Vector3.UP).normalized(), uv_scale)
		var bot_r: float = rings[0][1]
		var bot_y: float = rings[0][0]
		_add_tri(st,
			xf * (center + Vector3(0.0, bot_y, 0.0)),
			xf * (center + Vector3(c1 * bot_r, bot_y, s1 * bot_r)),
			xf * (center + Vector3(c0 * bot_r, bot_y, s0 * bot_r)),
			(xf.basis * Vector3.DOWN).normalized(), uv_scale)


static func _bevel_ring(st: SurfaceTool, center: Vector3, r_in: float, r_out: float, height: float, segs := 16, bevel := 0.02, uv_scale := 0.5, xf := Transform3D.IDENTITY) -> void:
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
			_add_quad(st, q0, q1, q2, q3, fn, uv_scale)


static func _bolt_ring(st: SurfaceTool, center: Vector3, ring_r: float, count: int, bolt_r: float, bolt_h: float, xf := Transform3D.IDENTITY) -> void:
	for i in count:
		var a := TAU * float(i) / float(count)
		var pos := center + Vector3(cos(a) * ring_r, 0.0, sin(a) * ring_r)
		_bevel_cyl(st, pos, bolt_r, bolt_r * 0.88, bolt_h, 6, bolt_r * 0.2, 1.0, xf)



static func stake_chest_body() -> ArrayMesh:
	return _cached("stake_chest_body", func(st: SurfaceTool):
		_bevel_box(st, Vector3(0.0, 0.07, 0.0), Vector3(2.36, 0.14, 1.66), 0.035, 0.5)
		_bevel_box(st, Vector3(0.0, 0.72, 0.0), Vector3(2.20, 1.16, 1.50), 0.055, 0.5)
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				_bevel_box(st, Vector3(sx * 1.08, 0.72, sz * 0.73), Vector3(0.12, 1.12, 0.12), 0.02, 0.8)
		for sx in [-1.0, 1.0]:
			_bevel_box(st, Vector3(sx * 1.12, 0.88, 0.0), Vector3(0.08, 0.12, 0.72), 0.02, 0.8)
			_bevel_box(st, Vector3(sx * 1.12, 0.44, 0.0), Vector3(0.08, 0.12, 0.72), 0.02, 0.8)
		_bevel_box(st, Vector3(0.0, 1.27, 0.0), Vector3(2.28, 0.08, 1.58), 0.02, 0.6)
		for hx in [-0.62, 0.62]:
			_bevel_cyl(st, Vector3.ZERO, 0.055, 0.055, 0.24, 8, 0.01, 1.0, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(hx, 1.28, -0.77)))
		_bevel_box(st, Vector3(0.0, 1.20, 0.76), Vector3(0.32, 0.18, 0.08), 0.02, 1.0)
	)


static func stake_chest_lid() -> ArrayMesh:
	return _cached("stake_chest_lid", func(st: SurfaceTool):
		_bevel_box(st, Vector3(0.0, -0.09, 0.0), Vector3(2.34, 0.11, 1.64), 0.025, 0.6)
		_bevel_box(st, Vector3(0.0, 0.05, 0.0), Vector3(2.18, 0.19, 1.46), 0.06, 0.6)
		for rx in [-0.76, 0.0, 0.76]:
			_bevel_box(st, Vector3(rx, 0.06, 0.0), Vector3(0.16, 0.23, 1.56), 0.025, 0.8)
		_bevel_box(st, Vector3(0.0, -0.06, 0.82), Vector3(0.24, 0.22, 0.08), 0.02, 1.0)
	)


static func stake_shrine_body() -> ArrayMesh:
	return _cached("stake_shrine_body", func(st: SurfaceTool):
		_bevel_box(st, Vector3(0.0, 0.10, 0.0), Vector3(1.88, 0.20, 1.88), 0.045, 0.5)
		_bevel_box(st, Vector3(0.0, 0.24, 0.0), Vector3(1.72, 0.12, 1.72), 0.03, 0.5)
		_bevel_box(st, Vector3(0.0, 1.32, 0.0), Vector3(1.60, 2.08, 1.60), 0.055, 0.45)
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				_bevel_box(st, Vector3(sx * 0.78, 1.24, sz * 0.78), Vector3(0.14, 1.92, 0.14), 0.025, 0.7)
		for sx in [-1.0, 1.0]:
			_bevel_box(st, Vector3(sx * 0.83, 1.35, 0.0), Vector3(0.08, 1.40, 0.44), 0.02, 0.7)
		_bevel_box(st, Vector3(0.0, 2.34, 0.0), Vector3(1.76, 0.16, 1.76), 0.04, 0.5)
	)


static func stake_shrine_basin() -> ArrayMesh:
	return _cached("stake_shrine_basin", func(st: SurfaceTool):
		_bevel_ring(st, Vector3(0.0, 0.02, 0.0), 0.36, 0.58, 0.28, 8, 0.035, 0.8)
		_bevel_cyl(st, Vector3(0.0, -0.02, 0.0), 0.38, 0.40, 0.18, 8, 0.02, 0.8)
		for i in 4:
			var a := PI * 0.25 + PI * 0.5 * float(i)
			_bevel_box(st, Vector3(cos(a) * 0.56, -0.06, sin(a) * 0.56), Vector3(0.16, 0.18, 0.16), 0.02, 1.0)
	)


static func stake_ward_pillar() -> ArrayMesh:
	return _cached("stake_ward_pillar", func(st: SurfaceTool):
		_bevel_cyl(st, Vector3(0.0, 0.10, 0.0), 0.76, 0.68, 0.20, 8, 0.035, 0.5)
		_bolt_ring(st, Vector3(0.0, 0.21, 0.0), 0.58, 8, 0.045, 0.04)
		_bevel_cyl(st, Vector3(0.0, 0.30, 0.0), 0.52, 0.44, 0.22, 8, 0.03, 0.5)
		_bevel_cyl(st, Vector3(0.0, 1.50, 0.0), 0.38, 0.28, 2.24, 8, 0.02, 0.5)
		for y in [0.78, 1.48, 2.18]:
			var r := lerpf(0.42, 0.34, (y - 0.5) / 2.0)
			_bevel_ring(st, Vector3(0.0, y, 0.0), r - 0.08, r + 0.06, 0.12, 8, 0.02, 0.8)
		for i in 4:
			var a := PI * 0.5 * float(i)
			_bevel_box(st, Vector3(cos(a) * 0.36, 1.32, sin(a) * 0.36), Vector3(0.09, 1.76, 0.09), 0.015, 0.8)
		_bevel_cyl(st, Vector3(0.0, 2.70, 0.0), 0.32, 0.58, 0.22, 8, 0.03, 0.6)
	)


static func stake_ward_lantern() -> ArrayMesh:
	return _cached("stake_ward_lantern", func(st: SurfaceTool):
		_bevel_cyl(st, Vector3(0.0, 0.02, 0.0), 0.46, 0.42, 0.26, 8, 0.04, 0.8)
		_bevel_ring(st, Vector3(0.0, 0.15, 0.0), 0.26, 0.56, 0.07, 8, 0.015, 0.9)
		_bevel_ring(st, Vector3(0.0, -0.11, 0.0), 0.32, 0.58, 0.07, 8, 0.015, 0.9)
		_bevel_cyl(st, Vector3(0.0, 0.24, 0.0), 0.34, 0.12, 0.14, 8, 0.02, 0.9)
	)


static func stake_tier_rivet() -> ArrayMesh:
	return _cached("stake_tier_rivet", func(st: SurfaceTool):
		var face_xf := Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO)
		_bevel_cyl(st, Vector3.ZERO, 0.12, 0.10, 0.08, 6, 0.018, 1.5, face_xf)
		_bevel_cyl(st, Vector3(0.0, 0.04, 0.0), 0.065, 0.055, 0.04, 6, 0.01, 1.5, face_xf)
	)



static func radio_mast() -> ArrayMesh:
	return _cached("radio_mast", func(st: SurfaceTool):
		_bevel_cyl(st, Vector3(0.0, -1.14, 0.0), 0.34, 0.26, 0.12, 6, 0.02, 0.8)
		_bolt_ring(st, Vector3(0.0, -1.07, 0.0), 0.24, 6, 0.028, 0.03)
		_bevel_cyl(st, Vector3(0.0, -0.78, 0.0), 0.13, 0.10, 0.68, 8, 0.015, 0.8)
		_bevel_box(st, Vector3(0.0, -0.72, 0.11), Vector3(0.22, 0.30, 0.14), 0.02, 1.2)
		_bevel_cyl(st, Vector3(0.0, 0.34, 0.0), 0.095, 0.058, 1.66, 8, 0.012, 0.8)
		for y in [-0.30, 0.28, 0.86]:
			_bevel_ring(st, Vector3(0.0, y, 0.0), 0.06, 0.125, 0.08, 8, 0.015, 1.2)
		_bevel_box(st, Vector3(0.0, 1.15, 0.0), Vector3(0.22, 0.10, 0.16), 0.018, 1.2)
	)


static func radio_dish() -> ArrayMesh:
	return _cached("radio_dish", func(st: SurfaceTool):
		_bevel_cyl(st, Vector3(0.0, -0.10, 0.0), 0.16, 0.22, 0.14, 10, 0.02, 1.0)
		_bevel_ring(st, Vector3(0.0, -0.02, 0.0), 0.12, 0.36, 0.07, 12, 0.015, 0.9)
		_bevel_ring(st, Vector3(0.0, 0.06, 0.0), 0.32, 0.52, 0.07, 12, 0.015, 0.9)
		_bevel_ring(st, Vector3(0.0, 0.14, 0.0), 0.48, 0.58, 0.08, 12, 0.018, 0.9)
		_bevel_cyl(st, Vector3(0.0, 0.12, 0.0), 0.06, 0.04, 0.30, 6, 0.01, 1.2)
		for i in 3:
			var a := TAU * float(i) / 3.0
			var strut_xf := Transform3D(Basis(Vector3(-sin(a), 0.0, cos(a)), 0.72), Vector3(cos(a) * 0.26, 0.18, sin(a) * 0.26))
			_bevel_box(st, Vector3.ZERO, Vector3(0.035, 0.38, 0.035), 0.008, 1.2, strut_xf)
	)


static func radio_lamp_housing() -> ArrayMesh:
	return _cached("radio_lamp_housing", func(st: SurfaceTool):
		_bevel_cyl(st, Vector3.ZERO, 0.11, 0.11, 0.22, 8, 0.04, 1.5)
		_bevel_ring(st, Vector3(0.0, -0.07, 0.0), 0.07, 0.14, 0.05, 8, 0.01, 1.5)
	)


static func radio_pulse_ring() -> ArrayMesh:
	return _cached("radio_pulse_ring", func(st: SurfaceTool):
		_bevel_ring(st, Vector3.ZERO, 0.88, 1.02, 0.08, 24, 0.02, 0.8)
	)



static func dial_needle() -> ArrayMesh:
	return _cached("dial_needle", func(st: SurfaceTool):
		var face_xf := Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO)
		_bevel_cyl(st, Vector3.ZERO, 0.11, 0.09, 0.052, 8, 0.012, 1.5, face_xf)
		_bevel_box(st, Vector3(0.0, 0.20, 0.0), Vector3(0.11, 0.34, 0.038), 0.012, 1.5)
		_bevel_box(st, Vector3(0.0, 0.42, 0.0), Vector3(0.06, 0.18, 0.032), 0.01, 1.5)
		_bevel_box(st, Vector3(0.0, -0.18, 0.0), Vector3(0.14, 0.22, 0.04), 0.012, 1.5)
		_bevel_box(st, Vector3(0.0, -0.34, 0.0), Vector3(0.19, 0.12, 0.044), 0.015, 1.5)
	)


static func dial_post() -> ArrayMesh:
	return _cached("dial_post", func(st: SurfaceTool):
		_bevel_cyl(st, Vector3(0.0, -1.42, 0.0), 0.44, 0.36, 0.16, 8, 0.03, 0.6)
		_bolt_ring(st, Vector3(0.0, -1.33, 0.0), 0.32, 6, 0.035, 0.03)
		_bevel_cyl(st, Vector3(0.0, 0.0, 0.0), 0.22, 0.18, 2.86, 8, 0.02, 0.6)
		for y in [-0.75, 0.15, 0.95]:
			_bevel_ring(st, Vector3(0.0, y, 0.0), 0.16, 0.26, 0.10, 8, 0.02, 0.8)
		_bevel_box(st, Vector3(0.0, 1.44, 0.0), Vector3(0.56, 0.16, 0.28), 0.025, 0.8)
	)


static func dial_bezel() -> ArrayMesh:
	return _cached("dial_bezel", func(st: SurfaceTool):
		_bevel_cyl(st, Vector3(0.0, -0.02, 0.0), 1.12, 1.08, 0.14, 16, 0.025, 0.5)
		_bevel_ring(st, Vector3(0.0, 0.06, 0.0), 0.96, 1.16, 0.09, 16, 0.02, 0.7)
		_bolt_ring(st, Vector3(0.0, 0.10, 0.0), 1.06, 8, 0.04, 0.03)
	)


static func dial_redline() -> ArrayMesh:
	return _cached("dial_redline", func(st: SurfaceTool):
		_bevel_box(st, Vector3.ZERO, Vector3(0.22, 0.52, 0.055), 0.015, 1.2)
	)


static func thermal_grate(radius: float) -> ArrayMesh:
	var key := "thermal_grate:%.2f" % radius
	return _cached(key, func(st: SurfaceTool):
		_bevel_ring(st, Vector3.ZERO, radius * 0.76, radius, 0.22, 16, 0.03, 0.4)
		_bolt_ring(st, Vector3(0.0, 0.11, 0.0), radius * 0.88, 8, minf(0.14, radius * 0.055), 0.04)
		_bevel_cyl(st, Vector3(0.0, -0.02, 0.0), radius * 0.22, radius * 0.20, 0.16, 8, 0.02, 0.5)
		for i in 6:
			var a := TAU * float(i) / 6.0
			var xf := Transform3D(Basis(Vector3.UP, a), Vector3(cos(a) * radius * 0.48, -0.01, sin(a) * radius * 0.48))
			_bevel_box(st, Vector3.ZERO, Vector3(radius * 0.58, 0.10, maxf(0.16, radius * 0.07)), 0.02, 0.5, xf)
	)


static func sluice_wheel() -> ArrayMesh:
	return _cached("sluice_wheel", func(st: SurfaceTool):
		_bevel_ring(st, Vector3.ZERO, 0.78, 1.04, 0.18, 16, 0.035, 0.7)
		_bevel_cyl(st, Vector3.ZERO, 0.24, 0.22, 0.24, 8, 0.03, 0.9)
		_bevel_cyl(st, Vector3(0.0, -0.22, 0.0), 0.125, 0.125, 0.42, 8, 0.018, 1.0)
		_bevel_ring(st, Vector3(0.0, -0.16, 0.0), 0.11, 0.19, 0.08, 8, 0.015, 1.0)
		for i in 4:
			var a := PI * 0.5 * float(i)
			var xf := Transform3D(Basis(Vector3.UP, a), Vector3(cos(a) * 0.50, 0.0, sin(a) * 0.50))
			_bevel_box(st, Vector3.ZERO, Vector3(0.64, 0.12, 0.12), 0.02, 0.9, xf)
	)


static func sluice_post() -> ArrayMesh:
	return _cached("sluice_post", func(st: SurfaceTool):
		_bevel_cyl(st, Vector3(0.0, -0.82, 0.0), 0.46, 0.36, 0.16, 8, 0.03, 0.6)
		_bolt_ring(st, Vector3(0.0, -0.73, 0.0), 0.34, 6, 0.036, 0.03)
		_bevel_cyl(st, Vector3(0.0, -0.06, 0.0), 0.23, 0.19, 1.56, 8, 0.025, 0.6)
		_bevel_ring(st, Vector3(0.0, 0.32, 0.0), 0.17, 0.28, 0.10, 8, 0.02, 0.8)
		_bevel_box(st, Vector3(0.0, 0.78, 0.0), Vector3(0.42, 0.34, 0.40), 0.04, 0.8)
		_bevel_cyl(st, Vector3.ZERO, 0.165, 0.155, 0.16, 8, 0.02, 1.0, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.0, 0.80, 0.20)))
	)


static func valve_door_slab(size: Vector3) -> ArrayMesh:
	var key := "valve_door_slab:%.2f:%.2f:%.2f" % [size.x, size.y, size.z]
	return _cached(key, func(st: SurfaceTool):
		_bevel_box(st, Vector3.ZERO, size, minf(0.12, minf(size.x, minf(size.y, size.z)) * 0.18), 0.35)
		var rib_z := size.z + 0.14
		_bevel_box(st, Vector3(0.0, size.y * 0.34, 0.0), Vector3(size.x * 0.92, maxf(0.28, size.y * 0.09), rib_z), 0.04, 0.45)
		_bevel_box(st, Vector3(0.0, -size.y * 0.34, 0.0), Vector3(size.x * 0.92, maxf(0.28, size.y * 0.09), rib_z), 0.04, 0.45)
		_bevel_box(st, Vector3(0.0, 0.0, 0.0), Vector3(size.x * 0.88, maxf(0.24, size.y * 0.08), rib_z), 0.04, 0.45)
		for sx in [-0.36, 0.36]:
			_bevel_box(st, Vector3(size.x * sx, 0.0, 0.0), Vector3(maxf(0.24, size.x * 0.08), size.y * 0.82, rib_z * 0.96), 0.035, 0.45)
	)


static func cracked_wall_slab(size: Vector3) -> ArrayMesh:
	var key := "cracked_wall_slab:%.2f:%.2f:%.2f" % [size.x, size.y, size.z]
	return _cached(key, func(st: SurfaceTool):
		_bevel_box(st, Vector3.ZERO, size, minf(0.14, minf(size.x, minf(size.y, size.z)) * 0.2), 0.3)
		_bevel_box(st, Vector3(0.0, -size.y * 0.44, 0.0), Vector3(size.x + 0.24, maxf(0.32, size.y * 0.12), size.z + 0.22), 0.05, 0.35)
		_bevel_box(st, Vector3(0.0, size.y * 0.44, 0.0), Vector3(size.x + 0.16, maxf(0.24, size.y * 0.10), size.z + 0.14), 0.04, 0.35)
	)


static func lift_deck(radius: float) -> ArrayMesh:
	var key := "lift_deck:%.2f" % radius
	return _cached(key, func(st: SurfaceTool):
		_bevel_cyl(st, Vector3(0.0, 0.04, 0.0), radius * 0.96, radius, 0.92, 12, 0.08, 0.35)
		_bevel_ring(st, Vector3(0.0, 0.26, 0.0), radius * 0.86, radius + 0.12, 0.28, 12, 0.04, 0.4)
		_bevel_cyl(st, Vector3(0.0, -0.34, 0.0), radius * 0.72, radius * 0.84, 0.32, 12, 0.05, 0.4)
	)


static func lift_piston() -> ArrayMesh:
	return _cached("lift_piston", func(st: SurfaceTool):
		_bevel_cyl(st, Vector3.ZERO, 0.92, 0.82, 12.0, 10, 0.06, 0.3)
		for y in [-4.0, -1.5, 1.5, 4.0]:
			_bevel_ring(st, Vector3(0.0, y, 0.0), 0.78, 1.06, 0.34, 10, 0.04, 0.4)
	)


static func barge_hull(size: Vector3) -> ArrayMesh:
	var key := "barge_hull:%.2f:%.2f:%.2f" % [size.x, size.y, size.z]
	return _cached(key, func(st: SurfaceTool):
		_bevel_box(st, Vector3(0.0, 0.0, 0.0), size, minf(0.14, size.y * 0.25), 0.25)
		_bevel_box(st, Vector3(0.0, -size.y * 0.55, 0.0), Vector3(size.x * 0.86, size.y * 0.65, size.z * 0.86), 0.12, 0.28)
		_bevel_box(st, Vector3(0.0, -0.05, 0.0), Vector3(size.x + 0.32, size.y * 0.42, size.z + 0.32), 0.08, 0.32)
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				_bevel_box(st, Vector3(sx * size.x * 0.48, -0.04, sz * size.z * 0.48), Vector3(0.85, size.y * 0.72, 0.85), 0.10, 0.4)
	)


static func grapple_hook_anchor() -> ArrayMesh:
	return _cached("grapple_hook_anchor", func(st: SurfaceTool):
		var rot_xf := Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO)
		_bevel_ring(st, Vector3.ZERO, 0.52, 0.86, 0.28, 12, 0.05, 0.7, rot_xf)
		_bevel_cyl(st, Vector3(0.0, 0.88, 0.0), 0.24, 0.30, 0.38, 8, 0.04, 0.8)
		_bevel_box(st, Vector3(0.0, -0.78, 0.0), Vector3(0.36, 0.28, 0.32), 0.04, 0.8)
	)



static func quench_vent_pad(radius: float) -> ArrayMesh:
	var key := "quench_vent_pad:%.2f" % radius
	return _cached(key, func(st: SurfaceTool):
		_bevel_cyl(st, Vector3(0.0, -0.015, 0.0), radius * 0.88, radius * 0.84, 0.07, 16, 0.018, 0.35)
	)


static func quench_vent_grate(radius: float) -> ArrayMesh:
	var key := "quench_vent_grate:%.2f" % radius
	return _cached(key, func(st: SurfaceTool):
		_bevel_ring(st, Vector3(0.0, 0.01, 0.0), radius * 0.74, radius, 0.11, 16, 0.025, 0.4)
		_bolt_ring(st, Vector3(0.0, 0.065, 0.0), radius * 0.88, 8, minf(0.16, radius * 0.055), 0.035)
		_bevel_cyl(st, Vector3(0.0, 0.02, 0.0), radius * 0.22, radius * 0.19, 0.08, 8, 0.02, 0.5)
		for i in 4:
			var a := PI * 0.25 * float(i)
			var xf := Transform3D(Basis(Vector3.UP, a), Vector3(0.0, 0.032, 0.0))
			_bevel_box(st, Vector3.ZERO, Vector3(radius * 1.66, 0.05, maxf(0.16, radius * 0.055)), 0.014, 0.5, xf)
	)


static func crane_mast(height: float) -> ArrayMesh:
	var key := "crane_mast:%.2f" % height
	return _cached(key, func(st: SurfaceTool):
		var hh := height * 0.5
		_bevel_cyl(st, Vector3(0.0, -hh + 0.35, 0.0), 1.65, 1.38, 0.70, 8, 0.08, 0.25)
		_bevel_cyl(st, Vector3(0.0, 0.0, 0.0), 1.18, 0.94, height - 0.6, 8, 0.06, 0.25)
		for i in 4:
			var a := PI * 0.25 + PI * 0.5 * float(i)
			_bevel_box(st, Vector3(cos(a) * 1.06, 0.0, sin(a) * 1.06), Vector3(0.32, height * 0.92, 0.32), 0.05, 0.3)
		for f in [-0.32, 0.0, 0.32, 0.46]:
			_bevel_ring(st, Vector3(0.0, height * f, 0.0), 0.86, 1.34, 0.34, 8, 0.05, 0.3)
	)


static func crane_boom(size: Vector3) -> ArrayMesh:
	var key := "crane_boom:%.2f:%.2f:%.2f" % [size.x, size.y, size.z]
	return _cached(key, func(st: SurfaceTool):
		_bevel_box(st, Vector3.ZERO, size, 0.08, 0.3)
		for f in [-0.45, -0.22, 0.0, 0.22, 0.45]:
			_bevel_box(st, Vector3(size.x * f, 0.0, 0.0), Vector3(0.24, size.y + 0.22, size.z + 0.22), 0.04, 0.4)
	)


static func vent_nozzle() -> ArrayMesh:
	return _cached("vent_nozzle", func(st: SurfaceTool):
		_bevel_cyl(st, Vector3(0.0, -1.32, 0.0), 1.18, 1.02, 0.36, 10, 0.05, 0.35)
		_bolt_ring(st, Vector3(0.0, -1.12, 0.0), 1.06, 8, 0.08, 0.06)
		_bevel_cyl(st, Vector3(0.0, 0.0, 0.0), 0.90, 0.72, 2.76, 10, 0.05, 0.35)
		for y in [-0.55, 0.25, 0.95]:
			_bevel_ring(st, Vector3(0.0, y, 0.0), 0.70, 1.04, 0.18, 10, 0.03, 0.4)
		_bevel_ring(st, Vector3(0.0, 1.38, 0.0), 0.56, 0.94, 0.26, 10, 0.04, 0.4)
	)



static func lore_plate_rim(radius: float, h: float) -> ArrayMesh:
	var key := "lore_plate_rim:%.3f:%.3f" % [radius, h]
	return _cached(key, func(st: SurfaceTool):
		var r_out := radius * 1.08
		var r_in := radius * 0.74
		_bevel_ring(st, Vector3.ZERO, r_in, r_out, h, 16, minf(0.025, h * 0.35), 0.5)
		_bevel_cyl(st, Vector3(0.0, -h * 0.22, 0.0), r_out * 0.96, r_in + 0.04, h * 0.52, 16, h * 0.1, 0.5)
		_bolt_ring(st, Vector3(0.0, h * 0.32, 0.0), (r_in + r_out) * 0.52, 8, 0.075, h * 0.32)
	)


static func lore_plate_face(face_radius: float, h: float) -> ArrayMesh:
	var key := "lore_plate_face:%.3f:%.3f" % [face_radius, h]
	return _cached(key, func(st: SurfaceTool):
		_bevel_cyl(st, Vector3.ZERO, face_radius, face_radius * 0.94, h, 16, minf(0.02, h * 0.3), 0.6)
		_bevel_ring(st, Vector3(0.0, h * 0.32, 0.0), face_radius * 0.44, face_radius * 0.62, h * 0.34, 16, 0.008, 0.8)
	)


static func mend_ward_ring(radius: float, h: float) -> ArrayMesh:
	var key := "mend_ward_ring:%.2f:%.3f" % [radius, h]
	return _cached(key, func(st: SurfaceTool):
		_bevel_cyl(st, Vector3(0.0, -h * 0.1, 0.0), radius * 0.96, radius * 0.92, h * 0.72, 24, h * 0.2, 0.25)
		_bevel_ring(st, Vector3(0.0, h * 0.05, 0.0), radius * 0.86, radius, h * 0.92, 24, h * 0.25, 0.3)
		_bolt_ring(st, Vector3(0.0, h * 0.34, 0.0), radius * 0.93, 12, 0.14, h * 0.32)
	)


static func mend_ward_fill(radius: float, h: float) -> ArrayMesh:
	var key := "mend_ward_fill:%.2f:%.3f" % [radius, h]
	return _cached(key, func(st: SurfaceTool):
		_bevel_cyl(st, Vector3.ZERO, radius * 0.95, radius * 0.92, h, 24, h * 0.28, 0.3)
	)


static func door_clock_casing(size_m: float) -> ArrayMesh:
	var key := "door_clock_casing:%.2f" % size_m
	return _cached(key, func(st: SurfaceTool):
		var face_xf := Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO)
		_bevel_cyl(st, Vector3.ZERO, size_m * 0.56, size_m * 0.54, 0.12, 8, 0.03, 0.8, face_xf)
		_bevel_ring(st, Vector3(0.0, 0.06, 0.0), size_m * 0.42, size_m * 0.54, 0.07, 12, 0.018, 1.0, face_xf)
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				_bevel_box(st, Vector3(sx * size_m * 0.37, sy * size_m * 0.37, -0.02), Vector3(0.24, 0.24, 0.09), 0.028, 1.2)
				_bevel_cyl(st, Vector3.ZERO, 0.045, 0.038, 0.04, 6, 0.008, 1.5, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(sx * size_m * 0.40, sy * size_m * 0.40, 0.035)))
		_bevel_cyl(st, Vector3(0.0, size_m * 0.53, 0.0), 0.24, 0.12, 0.16, 8, 0.025, 1.2)
	)


static func door_clock_face(size_m: float) -> ArrayMesh:
	var key := "door_clock_face:%.2f" % size_m
	return _cached(key, func(st: SurfaceTool):
		var face_xf := Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO)
		_bevel_cyl(st, Vector3.ZERO, size_m * 0.44, size_m * 0.43, 0.06, 16, 0.012, 1.0, face_xf)
		for i in 12:
			var a := TAU * float(i) / 12.0
			var major := (i % 3 == 0)
			var r := size_m * (0.355 if major else 0.37)
			var tick_xf := Transform3D(Basis(Vector3.BACK, a), Vector3(sin(a) * r, cos(a) * r, 0.036))
			_bevel_box(st, Vector3.ZERO, Vector3(0.035 if major else 0.022, 0.10 if major else 0.065, 0.024), 0.006, 2.0, tick_xf)
	)


static func door_clock_hand(width: float, length: float) -> ArrayMesh:
	var key := "door_clock_hand:%.3f:%.3f" % [width, length]
	return _cached(key, func(st: SurfaceTool):
		_bevel_box(st, Vector3(0.0, 0.0, 0.0), Vector3(width, length, 0.042), minf(0.014, width * 0.25), 1.8)
		_bevel_box(st, Vector3(0.0, length * 0.36, 0.0), Vector3(width * 0.55, length * 0.28, 0.036), 0.01, 1.8)
	)


static func work_glove_leather() -> ArrayMesh:
	return _cached("work_glove_leather", func(st: SurfaceTool):
		_bevel_box(st, Vector3(0.0, 0.0, 0.0), Vector3(0.64, 0.21, 0.68), 0.055, 1.4)
		_bevel_box(st, Vector3(0.0, 0.055, -0.22), Vector3(0.62, 0.12, 0.22), 0.035, 1.6)
		for k in 4:
			var f_len := 0.50 - absf(float(k) - 1.5) * 0.075
			var x := -0.23 + float(k) * 0.155
			var yaw := (float(k) - 1.5) * 0.09
			var base_xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(x, -0.015, -0.28))
			_bevel_box(st, Vector3(0.0, 0.0, -f_len * 0.24), Vector3(0.145, 0.15, f_len * 0.64), 0.042, 1.8, base_xf)
			_bevel_box(st, Vector3(0.0, -0.012, -f_len * 0.68), Vector3(0.125, 0.13, f_len * 0.54), 0.040, 1.8, base_xf)
		var thumb_xf := Transform3D(Basis(Vector3.UP, 0.85), Vector3(-0.24, -0.015, 0.04))
		_bevel_box(st, Vector3(0.0, 0.0, -0.14), Vector3(0.165, 0.155, 0.34), 0.045, 1.8, thumb_xf)
		_bevel_box(st, Vector3(0.0, -0.01, -0.34), Vector3(0.135, 0.13, 0.24), 0.040, 1.8, thumb_xf)
	)


static func work_glove_cuff() -> ArrayMesh:
	return _cached("work_glove_cuff", func(st: SurfaceTool):
		_bevel_box(st, Vector3(0.0, 0.01, 0.42), Vector3(0.72, 0.24, 0.28), 0.045, 1.5)
		_bevel_box(st, Vector3(0.0, 0.01, 0.30), Vector3(0.68, 0.22, 0.06), 0.018, 1.8)
	)


static func work_glove_peg() -> ArrayMesh:
	return _cached("work_glove_peg", func(st: SurfaceTool):
		_bevel_cyl(st, Vector3(0.0, 0.0, 0.50), 0.038, 0.032, 0.46, 6, 0.01, 2.0)
		_bevel_cyl(st, Vector3(0.0, 0.22, 0.50), 0.062, 0.055, 0.06, 6, 0.012, 2.0)
	)


static func chalk_stroke(width: float, length: float) -> ArrayMesh:
	var key := "chalk_stroke:%.3f:%.3f" % [width, length]
	return _cached(key, func(st: SurfaceTool):
		_bevel_box(st, Vector3.ZERO, Vector3(width, length, 0.024), minf(0.008, width * 0.25), 2.0)
	)


static func bevel_prop_box(size: Vector3) -> ArrayMesh:
	var key := "bevel_prop_box:%.2f:%.2f:%.2f" % [size.x, size.y, size.z]
	return _cached(key, func(st: SurfaceTool):
		var b := clampf(minf(size.x, minf(size.y, size.z)) * 0.14, 0.015, 0.12)
		_bevel_box(st, Vector3.ZERO, size, b, 0.4)
	)


static func bevel_prop_post(size: Vector3) -> ArrayMesh:
	var key := "bevel_prop_post:%.2f:%.2f:%.2f" % [size.x, size.y, size.z]
	return _cached(key, func(st: SurfaceTool):
		var b := clampf(minf(size.x, size.z) * 0.18, 0.02, 0.08)
		_bevel_box(st, Vector3.ZERO, size, b, 0.5)
		_bevel_box(st, Vector3(0.0, -size.y * 0.46, 0.0), Vector3(size.x + 0.14, size.y * 0.10, size.z + 0.14), b * 0.7, 0.6)
		_bevel_box(st, Vector3(0.0, size.y * 0.46, 0.0), Vector3(size.x + 0.10, size.y * 0.08, size.z + 0.10), b * 0.7, 0.6)
	)



const _WEAR_SHADER_CODE := """
shader_type spatial;
render_mode diffuse_toon, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.6, 0.35, 0.2, 1.0);
uniform vec4 edge_color : source_color = vec4(0.85, 0.65, 0.42, 1.0);
uniform vec4 emit_color : source_color = vec4(0.3, 0.85, 0.95, 1.0);
uniform float base_roughness : hint_range(0.05, 1.0) = 0.68;
uniform float base_metallic : hint_range(0.0, 1.0) = 0.38;
uniform float emit_energy : hint_range(0.0, 8.0) = 1.2;
uniform float tile_scale = 0.42;
uniform float has_plate = 0.0;
uniform sampler2D plate_tex : source_color, filter_linear_mipmap, repeat_enable;

varying vec3 v_world_pos;
varying vec3 v_world_nrm;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_nrm = normalize((MODEL_NORMAL_MATRIX * NORMAL));
}

void fragment() {
	float wear = clamp(COLOR.r, 0.0, 1.0);
	float grime = clamp(COLOR.g, 0.0, 1.0);
	float glow = clamp(COLOR.b, 0.0, 1.0);
	vec3 col = base_color.rgb;
	if (has_plate > 0.5) {
		vec3 w = abs(v_world_nrm);
		w = pow(w, vec3(4.0));
		w /= max(w.x + w.y + w.z, 0.0001);
		vec3 p = v_world_pos * tile_scale;
		vec3 tri = texture(plate_tex, p.zy).rgb * w.x + texture(plate_tex, p.xz).rgb * w.y + texture(plate_tex, p.xy).rgb * w.z;
		float lum = dot(tri, vec3(0.299, 0.587, 0.114));
		col *= mix(0.82, 1.18, lum);
	}
	col = mix(col, edge_color.rgb, wear * 0.58);
	col = mix(col, vec3(0.065, 0.058, 0.052), grime * 0.56);
	float ndv = abs(dot(NORMAL, VIEW));
	float ink = smoothstep(0.26, 0.05, ndv);
	ALBEDO = mix(col, vec3(0.055, 0.055, 0.065), ink * 0.72);
	ROUGHNESS = clamp(base_roughness - wear * 0.22 + grime * 0.20, 0.08, 0.98);
	METALLIC = clamp(base_metallic + wear * 0.24 - grime * 0.16, 0.0, 0.95);
	EMISSION = emit_color.rgb * (glow * emit_energy);
}
"""


static func salvage_wear_material(base_color: Color, edge_color: Color, emit_color: Color, roughness := 0.66, metallic := 0.38, emit_energy := 0.0, tag := "", tile_m := 2.4) -> ShaderMaterial:
	var key := "wear:%s:%s:%s:%.2f:%.2f:%.2f:%s:%.2f" % [
		base_color.to_html(false), edge_color.to_html(false), emit_color.to_html(false),
		roughness, metallic, emit_energy, tag, tile_m
	]
	if _mat_cache.has(key):
		return _mat_cache[key]
	if _wear_shader == null:
		_wear_shader = Shader.new()
		_wear_shader.code = _WEAR_SHADER_CODE
	var mat := ShaderMaterial.new()
	mat.resource_name = "craft_wear_" + (tag if tag != "" else base_color.to_html(false))
	mat.shader = _wear_shader
	mat.set_shader_parameter("base_color", base_color)
	mat.set_shader_parameter("edge_color", edge_color)
	mat.set_shader_parameter("emit_color", emit_color)
	mat.set_shader_parameter("base_roughness", roughness)
	mat.set_shader_parameter("base_metallic", metallic)
	mat.set_shader_parameter("emit_energy", emit_energy)
	mat.set_shader_parameter("tile_scale", 1.0 / maxf(0.25, tile_m))
	var plate := Palette.look_texture("rusted-salvaged-plate-worn", true)
	if plate != null:
		mat.set_shader_parameter("plate_tex", plate)
		mat.set_shader_parameter("has_plate", 1.0)
	_mat_cache[key] = mat
	return mat


static func _add_tri_col(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3, col: Color, uv_scale := 0.5) -> void:
	var nn := n.normalized()
	if nn.length_squared() < 0.0001:
		return
	var p1 := b
	var p2 := c
	if (p1 - a).cross(p2 - a).dot(nn) > 0.0:
		var tmp := p1
		p1 = p2
		p2 = tmp
	for v in [a, p1, p2]:
		st.set_color(col)
		st.set_normal(nn)
		st.set_uv(_uv_for(v, nn, uv_scale))
		st.add_vertex(v)


static func _add_quad_col(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, col: Color, uv_scale := 0.5) -> void:
	_add_tri_col(st, a, b, c, n, col, uv_scale)
	_add_tri_col(st, a, c, d, n, col, uv_scale)


static func _bevel_box_masked(st: SurfaceTool, center: Vector3, size: Vector3, bevel := 0.04, face_mask := Color(0.14, 0.24, 0.0, 1.0), edge_mask := Color(0.88, 0.06, 0.0, 1.0), uv_scale := 0.5, xf := Transform3D.IDENTITY) -> void:
	var h := size * 0.5
	var b := minf(bevel, minf(h.x, minf(h.y, h.z)) * 0.42)
	var xi := h.x - b
	var yi := h.y - b
	var zi := h.z - b
	var pt := func(x: float, y: float, z: float) -> Vector3:
		return xf * (center + Vector3(x, y, z))
	var nrm := func(v: Vector3) -> Vector3:
		return (xf.basis * v).normalized()
	var cav_mask := Color(face_mask.r * 0.5, clampf(face_mask.g + 0.45, 0.0, 1.0), face_mask.b, 1.0)

	_add_quad_col(st, pt.call(-xi, -yi, h.z), pt.call(xi, -yi, h.z), pt.call(xi, yi, h.z), pt.call(-xi, yi, h.z), nrm.call(Vector3.BACK), face_mask, uv_scale)
	_add_quad_col(st, pt.call(xi, -yi, -h.z), pt.call(-xi, -yi, -h.z), pt.call(-xi, yi, -h.z), pt.call(xi, yi, -h.z), nrm.call(Vector3.FORWARD), face_mask, uv_scale)
	_add_quad_col(st, pt.call(h.x, -yi, zi), pt.call(h.x, -yi, -zi), pt.call(h.x, yi, -zi), pt.call(h.x, yi, zi), nrm.call(Vector3.RIGHT), face_mask, uv_scale)
	_add_quad_col(st, pt.call(-h.x, -yi, -zi), pt.call(-h.x, -yi, zi), pt.call(-h.x, yi, zi), pt.call(-h.x, yi, -zi), nrm.call(Vector3.LEFT), face_mask, uv_scale)
	_add_quad_col(st, pt.call(-xi, h.y, zi), pt.call(xi, h.y, zi), pt.call(xi, h.y, -zi), pt.call(-xi, h.y, -zi), nrm.call(Vector3.UP), face_mask, uv_scale)
	_add_quad_col(st, pt.call(-xi, -h.y, -zi), pt.call(xi, -h.y, -zi), pt.call(xi, -h.y, zi), pt.call(-xi, -h.y, zi), nrm.call(Vector3.DOWN), cav_mask, uv_scale)

	if b <= 0.0001:
		return
	for sy in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var n: Vector3 = (xf.basis * Vector3(0.0, sy, sz)).normalized()
			_add_quad_col(st, xf * (center + Vector3(-xi, sy * h.y, sz * zi)), xf * (center + Vector3(xi, sy * h.y, sz * zi)), xf * (center + Vector3(xi, sy * yi, sz * h.z)), xf * (center + Vector3(-xi, sy * yi, sz * h.z)), n, edge_mask, uv_scale)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var n: Vector3 = (xf.basis * Vector3(sx, sy, 0.0)).normalized()
			_add_quad_col(st, xf * (center + Vector3(sx * xi, sy * h.y, -zi)), xf * (center + Vector3(sx * xi, sy * h.y, zi)), xf * (center + Vector3(sx * h.x, sy * yi, zi)), xf * (center + Vector3(sx * h.x, sy * yi, -zi)), n, edge_mask, uv_scale)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var n: Vector3 = (xf.basis * Vector3(sx, 0.0, sz)).normalized()
			_add_quad_col(st, xf * (center + Vector3(sx * h.x, -yi, sz * zi)), xf * (center + Vector3(sx * h.x, yi, sz * zi)), xf * (center + Vector3(sx * xi, yi, sz * h.z)), xf * (center + Vector3(sx * xi, -yi, sz * h.z)), n, edge_mask, uv_scale)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var n: Vector3 = (xf.basis * Vector3(sx, sy, sz)).normalized()
				_add_tri_col(st, xf * (center + Vector3(sx * h.x, sy * yi, sz * zi)), xf * (center + Vector3(sx * xi, sy * h.y, sz * zi)), xf * (center + Vector3(sx * xi, sy * yi, sz * h.z)), n, edge_mask, uv_scale)


static func _bevel_cyl_masked(st: SurfaceTool, center: Vector3, r_bot: float, r_top: float, height: float, segs := 12, bevel := 0.03, body_mask := Color(0.16, 0.26, 0.0, 1.0), rim_mask := Color(0.90, 0.08, 0.0, 1.0), uv_scale := 0.5, xf := Transform3D.IDENTITY) -> void:
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
	var cav_mask := Color(body_mask.r * 0.5, clampf(body_mask.g + 0.48, 0.0, 1.0), body_mask.b, 1.0)
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
			var band_col := body_mask if (rings.size() == 2 or r == 1) else rim_mask
			_add_quad_col(st, p00, p10, p11, p01, fn, band_col, uv_scale)
		var top_r: float = rings[-1][1]
		var top_y: float = rings[-1][0]
		_add_tri_col(st, xf * (center + Vector3(0.0, top_y, 0.0)), xf * (center + Vector3(c0 * top_r, top_y, s0 * top_r)), xf * (center + Vector3(c1 * top_r, top_y, s1 * top_r)), (xf.basis * Vector3.UP).normalized(), body_mask, uv_scale)
		var bot_r: float = rings[0][1]
		var bot_y: float = rings[0][0]
		_add_tri_col(st, xf * (center + Vector3(0.0, bot_y, 0.0)), xf * (center + Vector3(c1 * bot_r, bot_y, s1 * bot_r)), xf * (center + Vector3(c0 * bot_r, bot_y, s0 * bot_r)), (xf.basis * Vector3.DOWN).normalized(), cav_mask, uv_scale)


static func _bevel_ring_masked(st: SurfaceTool, center: Vector3, r_in: float, r_out: float, height: float, segs := 16, bevel := 0.02, body_mask := Color(0.24, 0.34, 0.0, 1.0), rim_mask := Color(0.88, 0.08, 0.0, 1.0), uv_scale := 0.5, xf := Transform3D.IDENTITY) -> void:
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
		prof = [Vector2(r_in, hh), Vector2(r_out, hh), Vector2(r_out, -hh), Vector2(r_in, -hh)]
	var inner_cav := Color(body_mask.r * 0.4, clampf(body_mask.g + 0.46, 0.0, 1.0), body_mask.b, 1.0)
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
			var fn: Vector3 = (xf.basis * (radial * (-dy) + Vector3.UP * dr)).normalized()
			var seg_col := rim_mask if (prof.size() == 8 and (k % 2 == 1)) else (inner_cav if k >= 4 else body_mask)
			_add_quad_col(st,
				xf * (center + Vector3(c0 * p0.x, p0.y, s0 * p0.x)),
				xf * (center + Vector3(c1 * p0.x, p0.y, s1 * p0.x)),
				xf * (center + Vector3(c1 * p1.x, p1.y, s1 * p1.x)),
				xf * (center + Vector3(c0 * p1.x, p1.y, s0 * p1.x)),
				fn, seg_col, uv_scale)



static func sable_stake_body() -> ArrayMesh:
	return _cached("sable_stake_body", func(st: SurfaceTool):
		var hull := Color(0.18, 0.24, 0.0, 1.0)
		var worn := Color(0.92, 0.06, 0.0, 1.0)
		var grime := Color(0.12, 0.78, 0.0, 1.0)
		var arc_vein := Color(0.35, 0.05, 1.0, 1.0)
		_bevel_cyl_masked(st, Vector3(0.0, -0.34, 0.0), 0.055, 0.21, 0.22, 8, 0.018, grime, worn, 1.4)
		_bevel_ring_masked(st, Vector3(0.0, -0.22, 0.0), 0.14, 0.235, 0.075, 8, 0.016, grime, worn, 1.5)
		_bevel_cyl_masked(st, Vector3(0.0, 0.06, 0.0), 0.185, 0.115, 0.54, 8, 0.022, hull, worn, 1.2)
		_bevel_ring_masked(st, Vector3(0.0, 0.18, 0.0), 0.095, 0.175, 0.065, 8, 0.014, grime, worn, 1.5)
		_bevel_cyl_masked(st, Vector3(0.0, 0.39, 0.0), 0.145, 0.115, 0.12, 6, 0.022, hull, worn, 1.6)
		for i in 4:
			var a := PI * 0.5 * float(i)
			var xf := Transform3D(Basis(Vector3.UP, a), Vector3(cos(a) * 0.145, 0.02, sin(a) * 0.145))
			_bevel_box_masked(st, Vector3.ZERO, Vector3(0.055, 0.40, 0.042), 0.01, hull, worn, 1.8, xf)
			var vxf := Transform3D(Basis(Vector3.UP, a + PI * 0.25), Vector3(cos(a + PI * 0.25) * 0.148, 0.02, sin(a + PI * 0.25) * 0.148))
			_bevel_box_masked(st, Vector3.ZERO, Vector3(0.026, 0.30, 0.028), 0.006, arc_vein, arc_vein, 2.0, vxf)
		var shackle_xf := Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.0, 0.26, 0.135))
		_bevel_ring_masked(st, Vector3.ZERO, 0.038, 0.072, 0.036, 8, 0.008, hull, worn, 2.0, shackle_xf)
		for i in 6:
			var a := TAU * float(i) / 6.0
			_bevel_cyl_masked(st, Vector3(cos(a) * 0.19, -0.175, sin(a) * 0.19), 0.018, 0.015, 0.026, 6, 0.004, grime, worn, 2.2)
	)


static func sable_stake_ring() -> ArrayMesh:
	return _cached("sable_stake_ring", func(st: SurfaceTool):
		_bevel_ring(st, Vector3.ZERO, 0.235, 0.305, 0.062, 16, 0.016, 1.4)
		for i in 4:
			var a := PI * 0.5 * float(i)
			var xf := Transform3D(Basis(Vector3.UP, a), Vector3(cos(a) * 0.285, 0.0, sin(a) * 0.285))
			_bevel_box(st, Vector3.ZERO, Vector3(0.075, 0.048, 0.055), 0.012, 1.8, xf)
	)



static func activity_column_spire(width: float, height: float) -> ArrayMesh:
	var key := "activity_column_spire:%.2f:%.2f" % [width, height]
	return _cached(key, func(st: SurfaceTool):
		var r := width * 0.5
		_bevel_cyl(st, Vector3.ZERO, r, r * 0.88, height, 12, minf(0.08, r * 0.18), 0.2)
	)


static func activity_glyph_cross(size_m: float) -> ArrayMesh:
	var key := "activity_glyph_cross:%.2f" % size_m
	return _cached(key, func(st: SurfaceTool):
		var bar := size_m * 0.30
		var b := bar * 0.22
		_bevel_box(st, Vector3.ZERO, Vector3(size_m, bar, bar), b, 0.5)
		_bevel_box(st, Vector3.ZERO, Vector3(bar, size_m, bar), b, 0.5)
		_bevel_box(st, Vector3.ZERO, Vector3(bar, bar, size_m), b, 0.5)
		_bevel_box(st, Vector3.ZERO, Vector3.ONE * (bar * 1.42), b * 0.9, 0.6)
	)


static func activity_glyph_diamond(size_m: float) -> ArrayMesh:
	var key := "activity_glyph_diamond:%.2f" % size_m
	return _cached(key, func(st: SurfaceTool):
		var r := size_m * 0.55
		var hh := size_m * 0.55
		var rings := [
			[-hh, r * 0.08],
			[-hh * 0.88, r * 0.22],
			[-hh * 0.08, r],
			[hh * 0.08, r],
			[hh * 0.88, r * 0.22],
			[hh, r * 0.08],
		]
		var segs := 8
		for i in segs:
			var a0 := TAU * float(i) / float(segs)
			var a1 := TAU * float(i + 1) / float(segs)
			var c0 := cos(a0)
			var s0 := sin(a0)
			var c1 := cos(a1)
			var s1 := sin(a1)
			var mid := Vector3(cos((a0 + a1) * 0.5), 0.0, sin((a0 + a1) * 0.5))
			for k in rings.size() - 1:
				var y0: float = rings[k][0]
				var rad0: float = rings[k][1]
				var y1: float = rings[k + 1][0]
				var rad1: float = rings[k + 1][1]
				var fn := (mid * (y1 - y0) + Vector3.UP * (rad0 - rad1)).normalized()
				_add_quad(st,
					Vector3(c0 * rad0, y0, s0 * rad0),
					Vector3(c1 * rad0, y0, s1 * rad0),
					Vector3(c1 * rad1, y1, s1 * rad1),
					Vector3(c0 * rad1, y1, s0 * rad1),
					fn, 0.5)
			var top_r: float = rings[-1][1]
			var top_y: float = rings[-1][0]
			_add_tri(st, Vector3(0.0, top_y, 0.0), Vector3(c0 * top_r, top_y, s0 * top_r), Vector3(c1 * top_r, top_y, s1 * top_r), Vector3.UP, 0.5)
			var bot_r: float = rings[0][1]
			var bot_y: float = rings[0][0]
			_add_tri(st, Vector3(0.0, bot_y, 0.0), Vector3(c1 * bot_r, bot_y, s1 * bot_r), Vector3(c0 * bot_r, bot_y, s0 * bot_r), Vector3.DOWN, 0.5)
		_bevel_ring(st, Vector3.ZERO, r * 0.72, r * 1.08, size_m * 0.09, 8, 0.02, 0.6)
	)


static func activity_glyph_cube(size_m: float) -> ArrayMesh:
	var key := "activity_glyph_cube:%.2f" % size_m
	return _cached(key, func(st: SurfaceTool):
		var s := size_m * 0.80
		_bevel_box(st, Vector3.ZERO, Vector3.ONE * s, s * 0.14, 0.5)
		_bevel_ring(st, Vector3.ZERO, s * 0.38, s * 0.58, s * 0.18, 8, 0.03, 0.6)
	)


static func activity_ring_dash(arc_len: float) -> ArrayMesh:
	var key := "activity_ring_dash:%.3f" % arc_len
	return _cached(key, func(st: SurfaceTool):
		var z_len := maxf(0.18, arc_len)
		_bevel_box(st, Vector3.ZERO, Vector3(0.45, 0.10, z_len), 0.024, 0.8)
		for sz in [-1.0, 1.0]:
			_bevel_cyl(st, Vector3(0.0, 0.055, sz * z_len * 0.34), 0.055, 0.048, 0.03, 6, 0.008, 1.4)
	)


static func activity_pay_beam(width: float, height: float) -> ArrayMesh:
	var key := "activity_pay_beam:%.2f:%.2f" % [width, height]
	return _cached(key, func(st: SurfaceTool):
		_bevel_cyl(st, Vector3.ZERO, width * 0.52, width * 0.38, height, 8, 0.03, 0.3)
	)



static func rescue_ring_dash(arc_len: float) -> ArrayMesh:
	var key := "rescue_ring_dash:%.3f" % arc_len
	return _cached(key, func(st: SurfaceTool):
		var z_len := maxf(0.16, arc_len)
		_bevel_box(st, Vector3.ZERO, Vector3(0.36, 0.085, z_len), 0.02, 1.0)
		for sz in [-1.0, 1.0]:
			_bevel_cyl(st, Vector3(0.0, 0.046, sz * z_len * 0.32), 0.045, 0.038, 0.024, 6, 0.006, 1.6)
	)


static func rescue_cage_bar(edge: float, height: float) -> ArrayMesh:
	var key := "rescue_cage_bar:%.3f:%.2f" % [edge, height]
	return _cached(key, func(st: SurfaceTool):
		var hull := Color(0.18, 0.30, 0.0, 1.0)
		var worn := Color(0.86, 0.08, 0.0, 1.0)
		var grime := Color(0.10, 0.76, 0.0, 1.0)
		var r := edge * 0.44
		_bevel_cyl_masked(st, Vector3.ZERO, r, r, height, 8, minf(0.012, r * 0.28), hull, worn, 0.8)
		for sy in [-1.0, 1.0]:
			_bevel_cyl_masked(st, Vector3(0.0, sy * (height * 0.5 - 0.09), 0.0), r * 1.38, r * 1.32, 0.14, 8, 0.012, grime, worn, 1.2)
		_bevel_ring_masked(st, Vector3.ZERO, r * 0.85, r * 1.35, 0.10, 8, 0.012, grime, worn, 1.2)
	)


static func rescue_cage_rail(length: float, edge: float) -> ArrayMesh:
	var key := "rescue_cage_rail:%.2f:%.3f" % [length, edge]
	return _cached(key, func(st: SurfaceTool):
		var hull := Color(0.18, 0.32, 0.0, 1.0)
		var worn := Color(0.88, 0.08, 0.0, 1.0)
		var grime := Color(0.12, 0.78, 0.0, 1.0)
		_bevel_box_masked(st, Vector3.ZERO, Vector3(length, edge * 1.0, edge * 1.0), edge * 0.22, hull, worn, 0.6)
		for sx in [-0.38, -0.14, 0.14, 0.38]:
			_bevel_box_masked(st, Vector3(length * sx, 0.0, 0.0), Vector3(edge * 1.3, edge * 1.18, edge * 1.18), edge * 0.18, grime, worn, 1.2)
	)


static func rescue_cage_post(width: float, height: float) -> ArrayMesh:
	var key := "rescue_cage_post:%.2f:%.2f" % [width, height]
	return _cached(key, func(st: SurfaceTool):
		var hull := Color(0.20, 0.28, 0.0, 1.0)
		var worn := Color(0.88, 0.08, 0.0, 1.0)
		var grime := Color(0.12, 0.80, 0.0, 1.0)
		_bevel_box_masked(st, Vector3.ZERO, Vector3(width, height, width), width * 0.18, hull, worn, 0.5)
		_bevel_box_masked(st, Vector3(0.0, -height * 0.46, 0.0), Vector3(width * 1.38, 0.20, width * 1.38), 0.03, grime, worn, 0.8)
		_bevel_box_masked(st, Vector3(0.0, height * 0.47, 0.0), Vector3(width * 1.28, 0.16, width * 1.28), 0.028, hull, worn, 0.8)
	)


static func rescue_cage_lockbox(size: Vector3) -> ArrayMesh:
	var key := "rescue_cage_lockbox:%.2f:%.2f:%.2f" % [size.x, size.y, size.z]
	return _cached(key, func(st: SurfaceTool):
		_bevel_box(st, Vector3.ZERO, size, minf(0.04, size.z * 0.22), 1.0)
		_bevel_ring(st, Vector3.ZERO, size.x * 0.16, size.x * 0.28, size.z * 0.55, 10, 0.015, 1.4, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.0, size.y * 0.52, 0.0)))
	)



static func launcher_mouth_ring(radius: float) -> ArrayMesh:
	var key := "launcher_mouth_ring:%.2f" % radius
	return _cached(key, func(st: SurfaceTool):
		var r_in := maxf(0.4, radius - 0.60)
		_bevel_ring(st, Vector3.ZERO, r_in, radius, 0.34, 24, 0.065, 0.35)
		for i in 8:
			var a := TAU * float(i) / 8.0
			var r_mid := (r_in + radius) * 0.52
			var xf := Transform3D(Basis(Vector3.UP, a), Vector3(cos(a) * r_mid, 0.04, sin(a) * r_mid))
			_bevel_box(st, Vector3.ZERO, Vector3(0.48, 0.34, 0.36), 0.05, 0.6, xf)
			_bevel_cyl(st, Vector3(cos(a) * r_mid, 0.22, sin(a) * r_mid), 0.085, 0.075, 0.06, 6, 0.012, 1.2)
	)


static func fluted_plume_column(r_bot: float, r_top: float, height: float) -> ArrayMesh:
	var key := "fluted_plume_column:%.2f:%.2f:%.2f" % [r_bot, r_top, height]
	return _cached(key, func(st: SurfaceTool):
		_bevel_cyl(st, Vector3.ZERO, r_bot, r_top, height, 14, minf(0.18, minf(r_bot, r_top) * 0.22), 0.18)
	)


static func cannon_band_collar() -> ArrayMesh:
	return _cached("cannon_band_collar", func(st: SurfaceTool):
		_bevel_ring(st, Vector3.ZERO, 2.18, 2.92, 0.48, 16, 0.07, 0.35)
		_bolt_ring(st, Vector3(0.0, 0.25, 0.0), 2.58, 8, 0.11, 0.06)
	)


static func grapple_cable_span(length: float) -> ArrayMesh:
	var key := "grapple_cable_span:%.2f" % length
	return _cached(key, func(st: SurfaceTool):
		var span := maxf(0.5, length)
		_bevel_cyl(st, Vector3.ZERO, 0.18, 0.18, span, 8, 0.025, 0.35)
		if span > 1.8:
			for sy in [-1.0, 1.0]:
				_bevel_ring(st, Vector3(0.0, sy * (span * 0.5 - 0.38), 0.0), 0.14, 0.30, 0.38, 8, 0.035, 0.7)
	)


static func grapple_target_ring(radius: float) -> ArrayMesh:
	var key := "grapple_target_ring:%.2f" % radius
	return _cached(key, func(st: SurfaceTool):
		var r_in := maxf(0.4, radius - 0.50)
		_bevel_ring(st, Vector3.ZERO, r_in, radius, 0.30, 20, 0.055, 0.4)
		for i in 4:
			var a := PI * 0.5 * float(i)
			var r_mid := (r_in + radius) * 0.5
			var xf := Transform3D(Basis(Vector3.UP, a), Vector3(cos(a) * r_mid, 0.0, sin(a) * r_mid))
			_bevel_box(st, Vector3.ZERO, Vector3(0.44, 0.36, 0.30), 0.045, 0.7, xf)
	)


static func sluice_pay_ring() -> ArrayMesh:
	return _cached("sluice_pay_ring", func(st: SurfaceTool):
		_bevel_ring(st, Vector3.ZERO, 0.64, 0.86, 0.14, 16, 0.03, 0.8)
		for i in 4:
			var a := PI * 0.5 * float(i)
			var xf := Transform3D(Basis(Vector3.UP, a), Vector3(cos(a) * 0.76, 0.02, sin(a) * 0.76))
			_bevel_box(st, Vector3.ZERO, Vector3(0.18, 0.16, 0.14), 0.025, 1.2, xf)
	)


static func steam_puff_cloud() -> ArrayMesh:
	return _cached("steam_puff_cloud", func(st: SurfaceTool):
		_bevel_cyl(st, Vector3.ZERO, 0.82, 0.76, 1.48, 10, 0.26, 0.5)
		_bevel_cyl(st, Vector3(0.24, 0.12, 0.16), 0.54, 0.48, 0.96, 8, 0.18, 0.6)
		_bevel_cyl(st, Vector3(-0.22, -0.10, -0.14), 0.52, 0.46, 0.92, 8, 0.18, 0.6)
	)


static func vent_dash_segment(arc_len: float) -> ArrayMesh:
	var key := "vent_dash_segment:%.3f" % arc_len
	return _cached(key, func(st: SurfaceTool):
		_bevel_box(st, Vector3.ZERO, Vector3(0.32, 0.08, maxf(0.16, arc_len)), 0.02, 1.0)
	)



static func launch_flight_ring(radius: float) -> ArrayMesh:
	var key := "launch_flight_ring:%.2f" % radius
	return _cached(key, func(st: SurfaceTool):
		var r_in := maxf(0.4, radius - 0.45)
		_bevel_ring(st, Vector3.ZERO, r_in, radius, 0.26, 24, 0.055, 0.4)
		for i in 4:
			var a := PI * 0.25 + PI * 0.5 * float(i)
			var xf := Transform3D(Basis(Vector3.UP, a), Vector3(cos(a) * (r_in + 0.12), 0.0, sin(a) * (r_in + 0.12)))
			_bevel_box(st, Vector3.ZERO, Vector3(0.42, 0.20, 0.22), 0.035, 0.8, xf)
	)


static func launch_landing_pad(radius: float) -> ArrayMesh:
	var key := "launch_landing_pad:%.2f" % radius
	return _cached(key, func(st: SurfaceTool):
		_bevel_cyl(st, Vector3(0.0, -0.02, 0.0), radius, radius * 0.96, 0.16, 24, 0.035, 0.2)
		_bevel_ring(st, Vector3(0.0, 0.05, 0.0), radius * 0.82, radius * 0.96, 0.10, 24, 0.022, 0.3)
		_bevel_ring(st, Vector3(0.0, 0.05, 0.0), radius * 0.38, radius * 0.48, 0.09, 16, 0.02, 0.4)
	)



static func scrap_beacon_column(r_bot: float, r_top: float, height: float) -> ArrayMesh:
	var key := "scrap_beacon_column:%.3f:%.3f:%.2f" % [r_bot, r_top, height]
	return _cached(key, func(st: SurfaceTool):
		_bevel_cyl(st, Vector3.ZERO, r_bot, r_top, height, 12, minf(0.035, r_top * 0.4), 0.5)
		_bevel_ring(st, Vector3(0.0, -height * 0.5 + 0.06, 0.0), r_bot * 0.65, r_bot * 1.32, 0.09, 8, 0.018, 1.2)
	)


static func weather_existing_material(mat: Material, tile_m := 3.4) -> Material:
	if not (mat is StandardMaterial3D):
		return mat
	var sm := mat as StandardMaterial3D
	if sm.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
		return sm
	Palette.surface_grain(sm)
	if sm.albedo_texture == null:
		var plate := Palette.look_texture("rusted-salvaged-plate-worn", true)
		if plate != null:
			sm.albedo_texture = plate
			sm.uv1_triplanar = true
			sm.uv1_scale = Vector3.ONE / maxf(0.4, tile_m)
	return sm


static func weather_node_materials(root: Node, tile_m := 3.4) -> void:
	if root == null:
		return
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is MeshInstance3D:
			var mi := cur as MeshInstance3D
			if mi.material_override is StandardMaterial3D:
				weather_existing_material(mi.material_override, tile_m)
			elif mi.mesh != null:
				for s in mi.mesh.get_surface_count():
					var active := mi.get_active_material(s)
					if active is StandardMaterial3D and (active as StandardMaterial3D).albedo_texture == null:
						var dup := (active as StandardMaterial3D).duplicate() as StandardMaterial3D
						weather_existing_material(dup, tile_m)
						mi.set_surface_override_material(s, dup)
		for ch in cur.get_children():
			stack.append(ch)


static func air_cue_ring(outer_radius: float) -> ArrayMesh:
	var key := "air_cue_ring:%.3f" % outer_radius
	return _cached(key, func(st: SurfaceTool):
		var r_in := maxf(0.1, outer_radius * 0.84)
		_bevel_ring(st, Vector3.ZERO, r_in, outer_radius, 0.055, 24, 0.014, 1.2)
	)


static func mend_ward_monolith(size: Vector3) -> ArrayMesh:
	var key := "mend_ward_monolith:%.2f:%.2f:%.2f" % [size.x, size.y, size.z]
	return _cached(key, func(st: SurfaceTool):
		var hh := size.y * 0.5
		var r_base := minf(size.x, size.z) * 0.54
		_bevel_cyl(st, Vector3(0.0, -hh + 0.16, 0.0), r_base * 1.24, r_base * 1.12, 0.32, 8, 0.04, 0.6)
		_bevel_ring(st, Vector3(0.0, -hh + 0.36, 0.0), r_base * 0.72, r_base * 1.16, 0.12, 8, 0.025, 0.8)
		_bevel_cyl(st, Vector3(0.0, 0.02, 0.0), r_base * 0.92, r_base * 0.74, size.y * 0.68, 8, 0.045, 0.5)
		_bevel_ring(st, Vector3(0.0, hh * 0.36, 0.0), r_base * 0.62, r_base * 0.98, 0.14, 8, 0.028, 0.8)
		_bevel_cyl(st, Vector3(0.0, hh - 0.18, 0.0), r_base * 0.86, r_base * 0.62, 0.32, 8, 0.04, 0.7)
		for i in 4:
			var a := PI * 0.5 * float(i)
			var xf := Transform3D(Basis(Vector3.UP, a), Vector3(cos(a) * r_base * 0.84, -0.04, sin(a) * r_base * 0.84))
			_bevel_box(st, Vector3.ZERO, Vector3(0.14, size.y * 0.54, 0.12), 0.024, 0.9, xf)
	)


static func survey_stake_pole(height: float) -> ArrayMesh:
	var key := "survey_stake_pole:%.2f" % height
	return _cached(key, func(st: SurfaceTool):
		var body_col := Palette.RUST.lerp(Palette.CHARCOAL, 0.35)
		var band_col := Palette.AMBER
		var tip_col := Palette.STEEL
		var hh := height * 0.5
		_bevel_cyl_masked(st, Vector3(0.0, -hh + 0.22, 0.0), 0.10, 0.21, 0.44, 8, 0.022, body_col, tip_col, 0.8)
		_bevel_cyl_masked(st, Vector3(0.0, 0.04, 0.0), 0.18, 0.145, height - 0.56, 8, 0.022, body_col, band_col, 0.6)
		_bevel_ring_masked(st, Vector3(0.0, hh - 0.95, 0.0), 0.12, 0.20, 0.14, 8, 0.02, band_col, tip_col, 1.0)
		_bevel_cyl_masked(st, Vector3(0.0, hh - 0.12, 0.0), 0.17, 0.12, 0.24, 8, 0.024, band_col, tip_col, 1.0)
	)


static func survey_pennant_plate() -> ArrayMesh:
	return _cached("survey_pennant_plate", func(st: SurfaceTool):
		_bevel_box(st, Vector3(-0.36, 0.0, 0.0), Vector3(0.56, 0.68, 0.055), 0.014, 1.0)
		_bevel_box(st, Vector3(0.14, 0.0, 0.0), Vector3(0.52, 0.44, 0.045), 0.012, 1.0)
		_bevel_box(st, Vector3(0.48, 0.0, 0.0), Vector3(0.28, 0.22, 0.036), 0.010, 1.2)
		_bevel_box(st, Vector3(-0.62, 0.0, 0.0), Vector3(0.08, 0.78, 0.085), 0.016, 1.2)
	)


static func weighbridge_plate(size: Vector3) -> ArrayMesh:
	var key := "weighbridge_plate:%.2f:%.2f:%.2f" % [size.x, size.y, size.z]
	return _cached(key, func(st: SurfaceTool):
		_bevel_box(st, Vector3.ZERO, size, minf(0.03, size.y * 0.32), 0.35)
		for sz in [-1.0, 1.0]:
			_bevel_box(st, Vector3(0.0, size.y * 0.45, sz * (size.z * 0.5 - 0.14)), Vector3(size.x * 0.96, size.y * 0.75, 0.22), 0.025, 0.5)
		for i in 5:
			var x := lerpf(-size.x * 0.38, size.x * 0.38, float(i) / 4.0)
			_bevel_box(st, Vector3(x, size.y * 0.52, 0.0), Vector3(0.22, 0.035, size.z * 0.82), 0.008, 0.6)
	)


static func furnace_smoke_wisp() -> ArrayMesh:
	return _cached("furnace_smoke_wisp", func(st: SurfaceTool):
		var segs := 14
		var rings := [
			[-0.48, 0.14],
			[-0.24, 0.38],
			[0.02, 0.48],
			[0.26, 0.42],
			[0.48, 0.16],
		]
		for i in segs:
			var a0 := TAU * float(i) / float(segs)
			var a1 := TAU * float(i + 1) / float(segs)
			var m0 := 1.0 + 0.14 * sin(a0 * 3.0 + 0.4) + 0.08 * cos(a0 * 2.0)
			var m1 := 1.0 + 0.14 * sin(a1 * 3.0 + 0.4) + 0.08 * cos(a1 * 2.0)
			var c0 := cos(a0) * m0
			var s0 := sin(a0) * m0
			var c1 := cos(a1) * m1
			var s1 := sin(a1) * m1
			var mid := Vector3(cos((a0 + a1) * 0.5), 0.0, sin((a0 + a1) * 0.5))
			for k in rings.size() - 1:
				var y0: float = rings[k][0]
				var r0: float = rings[k][1]
				var y1: float = rings[k + 1][0]
				var r1: float = rings[k + 1][1]
				var fn := (mid * (y1 - y0) + Vector3.UP * (r0 - r1)).normalized()
				_add_quad(st,
					Vector3(c0 * r0, y0, s0 * r0),
					Vector3(c1 * r0, y0, s1 * r0),
					Vector3(c1 * r1, y1, s1 * r1),
					Vector3(c0 * r1, y1, s0 * r1),
					fn, 0.6)
			var top_r: float = rings[-1][1]
			var top_y: float = rings[-1][0]
			_add_tri(st, Vector3(0.0, top_y, 0.0), Vector3(c0 * top_r, top_y, s0 * top_r), Vector3(c1 * top_r, top_y, s1 * top_r), Vector3.UP, 0.6)
			var bot_r: float = rings[0][1]
			var bot_y: float = rings[0][0]
			_add_tri(st, Vector3(0.0, bot_y, 0.0), Vector3(c1 * bot_r, bot_y, s1 * bot_r), Vector3(c0 * bot_r, bot_y, s0 * bot_r), Vector3.DOWN, 0.6)
	)


const _SMOKE_SHADER_CODE := """
shader_type spatial;
render_mode unshaded, fog_disabled, cull_back, depth_draw_never;

uniform vec4 soot_base : source_color = vec4(0.24, 0.21, 0.19, 0.24);
uniform vec4 soot_warm : source_color = vec4(0.38, 0.29, 0.22, 0.24);

varying float v_local_y;
varying vec3 v_world_p;

void vertex() {
	v_local_y = VERTEX.y;
	v_world_p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float ndv = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	float rim_fade = pow(smoothstep(0.12, 0.92, ndv), 1.65);
	float y_fade = smoothstep(-0.48, -0.05, v_local_y) * (1.0 - smoothstep(0.05, 0.48, v_local_y));
	float wisp = 0.72 + 0.28 * sin(v_world_p.x * 0.09 + v_world_p.y * 0.06 - TIME * 0.8) * cos(v_world_p.z * 0.08 + v_world_p.y * 0.05);
	float lift = clamp(v_local_y + 0.5, 0.0, 1.0);
	ALBEDO = mix(soot_warm.rgb, soot_base.rgb, smoothstep(0.0, 0.8, lift));
	ALPHA = clamp(soot_base.a * rim_fade * y_fade * wisp * 2.1, 0.0, 0.42);
}
"""


static func furnace_smoke_material() -> ShaderMaterial:
	var key := "mat:furnace_smoke_plume"
	if _mat_cache.has(key):
		return _mat_cache[key]
	var sh := Shader.new()
	sh.code = _SMOKE_SHADER_CODE
	var mat := ShaderMaterial.new()
	mat.resource_name = "craft_furnace_smoke"
	mat.shader = sh
	_mat_cache[key] = mat
	return mat


static func bay_bell_mesh() -> ArrayMesh:
	return _cached("bay_bell_mesh", func(st: SurfaceTool):
		_bevel_cyl(st, Vector3(0.0, 0.12, 0.0), 0.88, 0.48, 1.12, 14, 0.08, 0.5)
		_bevel_ring(st, Vector3(0.0, -0.46, 0.0), 0.72, 1.02, 0.22, 14, 0.045, 0.6)
		_bevel_cyl(st, Vector3(0.0, 0.72, 0.0), 0.26, 0.20, 0.22, 8, 0.035, 0.8)
	)


static func bay_mug_mesh(r_bot: float, r_top: float, height: float) -> ArrayMesh:
	var key := "bay_mug_mesh:%.2f:%.2f:%.2f" % [r_bot, r_top, height]
	return _cached(key, func(st: SurfaceTool):
		_bevel_cyl(st, Vector3.ZERO, r_bot, r_top, height, 12, minf(0.04, r_top * 0.2), 0.8)
		_bevel_ring(st, Vector3(0.0, height * 0.44, 0.0), r_top * 0.76, r_top * 1.08, height * 0.14, 12, 0.018, 1.0)
	)


static func bay_marble_orb(radius: float) -> ArrayMesh:
	var key := "bay_marble_orb:%.3f" % radius
	return _cached(key, func(st: SurfaceTool):
		_bevel_cyl(st, Vector3.ZERO, radius * 0.92, radius * 0.92, radius * 1.75, 12, radius * 0.34, 1.2)
		_bevel_ring(st, Vector3.ZERO, radius * 0.68, radius * 1.02, radius * 0.32, 12, radius * 0.08, 1.4)
	)


static func bay_pin_mesh() -> ArrayMesh:
	return _cached("bay_pin_mesh", func(st: SurfaceTool):
		_bevel_cyl(st, Vector3(0.0, -0.26, 0.0), 0.28, 0.30, 0.92, 10, 0.045, 0.7)
		_bevel_ring(st, Vector3(0.0, 0.18, 0.0), 0.16, 0.27, 0.12, 10, 0.025, 0.9)
		_bevel_cyl(st, Vector3(0.0, 0.48, 0.0), 0.19, 0.16, 0.50, 10, 0.04, 0.8)
	)


static func bay_part_trophy() -> ArrayMesh:
	return _cached("bay_part_trophy", func(st: SurfaceTool):
		_bevel_box(st, Vector3.ZERO, Vector3(0.46, 0.46, 0.46), 0.065, 1.0)
		_bevel_ring(st, Vector3.ZERO, 0.18, 0.32, 0.14, 8, 0.025, 1.2)
	)


static func gantry_column_mesh(width: float, height: float, depth: float) -> ArrayMesh:
	var key := "gantry_column_mesh:%.2f:%.2f:%.2f" % [width, height, depth]
	return _cached(key, func(st: SurfaceTool):
		var wear := Color(0.86, 0.08, 0.0, 1.0)
		var base_grime := Color(0.16, 0.84, 0.0, 1.0)
		var mid_hull := Color(0.18, 0.24, 0.0, 1.0)
		var top_hull := Color(0.20, 0.12, 0.0, 1.0)
		_bevel_box_masked(st, Vector3(0.0, 0.55, 0.0), Vector3(width * 1.24, 1.1, depth * 1.24), 0.08, base_grime, wear, 0.35)
		var tiers := 4
		var span := (height - 1.0) / float(tiers)
		for i in tiers:
			var y_c := 1.0 + (float(i) + 0.5) * span
			var t := float(i) / float(tiers - 1)
			var col := base_grime.lerp(mid_hull, clampf(t * 1.6, 0.0, 1.0)).lerp(top_hull, clampf((t - 0.4) * 1.5, 0.0, 1.0))
			_bevel_box_masked(st, Vector3(0.0, y_c, 0.0), Vector3(width, span + 0.04, depth), 0.075, col, wear, 0.3)
			if i < tiers - 1:
				_bevel_box_masked(st, Vector3(0.0, 1.0 + float(i + 1) * span, 0.0), Vector3(width * 1.10, 0.24, depth * 1.10), 0.04, col, wear, 0.4)
	)


static func cantilever_gusset_bracket() -> ArrayMesh:
	return _cached("cantilever_gusset_bracket", func(st: SurfaceTool):
		var hull := Color(0.20, 0.36, 0.0, 1.0)
		var wear := Color(0.88, 0.08, 0.0, 1.0)
		_bevel_box_masked(st, Vector3(0.0, -0.12, 0.0), Vector3(3.4, 0.28, 0.42), 0.04, hull, wear, 0.5)
		_bevel_box_masked(st, Vector3(-1.45, -1.15, 0.0), Vector3(0.36, 2.2, 0.46), 0.04, hull, wear, 0.5)
		var brace_xf := Transform3D(Basis(Vector3.BACK, deg_to_rad(34.0)), Vector3(-0.15, -1.05, 0.0))
		_bevel_box_masked(st, Vector3.ZERO, Vector3(3.1, 0.30, 0.34), 0.04, hull, wear, 0.5, brace_xf)
	)

