@tool
class_name PilotGearKit
extends RefCounted


const Palette := preload("res://src/core/palette.gd")
const PaletteMaterials := preload("res://src/presentation/palette_materials.gd")
const CraftLookdev := preload("res://src/presentation/craft/craft_lookdev.gd")

const GEAR_GOGGLES := &"riveted_goggles"
const GEAR_HARNESS := &"shoulder_harness"
const GEAR_BELT := &"utility_belt"
const GEAR_YOKE := &"cockpit_yoke"
const GEAR_GAUGES := &"gauge_cluster"
const GEAR_PEDAL := &"cockpit_pedal"

const GEAR_IDS: Array[StringName] = [
	GEAR_GOGGLES,
	GEAR_HARNESS,
	GEAR_BELT,
	GEAR_YOKE,
	GEAR_GAUGES,
	GEAR_PEDAL,
]

const CANONICAL_HAND_L := Vector3(-0.320, 0.050, -0.400)
const CANONICAL_HAND_R := Vector3(0.320, 0.050, -0.400)
const CANONICAL_YOKE_PIVOT := Vector3(0.0, -0.175, -0.422)
const CANONICAL_DASH_ORIGIN := Vector3(0.0, -0.045, -0.560)
const YOKE_GRIP_LOCAL_L := Vector3(-0.320, 0.215, 0.020)
const YOKE_GRIP_LOCAL_R := Vector3(0.320, 0.215, 0.020)

const WELD_QUANT := 10000.0



class ManifoldCanvas extends RefCounted:
	var _tools: Dictionary = {}
	var _order: Array[String] = []

	func _tool_for(slot: String) -> SurfaceTool:
		if not _tools.has(slot):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			_tools[slot] = st
			_order.append(slot)
		return _tools[slot]

	func add_tri(
		slot: String,
		p0: Vector3,
		p1: Vector3,
		p2: Vector3,
		expected_normal: Vector3,
		uv0: Vector2,
		uv1: Vector2,
		uv2: Vector2,
		c0: Color,
		c1: Color,
		c2: Color
	) -> void:
		var geo := (p2 - p0).cross(p1 - p0)
		if geo.length_squared() < 1e-13:
			return
		var target := expected_normal.normalized() if expected_normal.length_squared() > 1e-12 else geo.normalized()
		var a := p0
		var b := p1
		var c := p2
		var uva := uv0
		var uvb := uv1
		var uvc := uv2
		var ca := c0
		var cb := c1
		var cc := c2
		if geo.dot(target) < 0.0:
			var tp := b
			b = c
			c = tp
			var tuv := uvb
			uvb = uvc
			uvc = tuv
			var tc := cb
			cb = cc
			cc = tc
		var st := _tool_for(slot)
		st.set_normal(target)
		st.set_uv(uva)
		st.set_color(ca)
		st.add_vertex(a)
		st.set_normal(target)
		st.set_uv(uvb)
		st.set_color(cb)
		st.add_vertex(b)
		st.set_normal(target)
		st.set_uv(uvc)
		st.set_color(cc)
		st.add_vertex(c)

	func add_quad(
		slot: String,
		p0: Vector3,
		p1: Vector3,
		p2: Vector3,
		p3: Vector3,
		outward: Vector3,
		c0: Color,
		c1: Color,
		c2: Color,
		c3: Color
	) -> void:
		var u_axis := p1 - p0
		if u_axis.length_squared() < 1e-10:
			u_axis = Vector3.RIGHT
		else:
			u_axis = u_axis.normalized()
		var n := outward.normalized() if outward.length_squared() > 1e-12 else (p3 - p0).cross(p1 - p0).normalized()
		var v_axis := n.cross(u_axis)
		if v_axis.length_squared() < 1e-10:
			v_axis = Vector3.UP
		else:
			v_axis = v_axis.normalized()
		var uv0 := Vector2(p0.dot(u_axis), p0.dot(v_axis)) * 4.0
		var uv1 := Vector2(p1.dot(u_axis), p1.dot(v_axis)) * 4.0
		var uv2 := Vector2(p2.dot(u_axis), p2.dot(v_axis)) * 4.0
		var uv3 := Vector2(p3.dot(u_axis), p3.dot(v_axis)) * 4.0
		add_tri(slot, p0, p1, p2, n, uv0, uv1, uv2, c0, c1, c2)
		add_tri(slot, p0, p2, p3, n, uv0, uv2, uv3, c0, c2, c3)

	func commit(meta_dict: Dictionary = {}) -> ArrayMesh:
		var mesh := ArrayMesh.new()
		for slot in _order:
			var st: SurfaceTool = _tools[slot]
			st.index()
			st.generate_tangents()
			var idx := mesh.get_surface_count()
			st.commit(mesh)
			mesh.surface_set_name(idx, slot)
		for k in meta_dict:
			mesh.set_meta(k, meta_dict[k])
		return mesh


static func _frame_from_dir(dir: Vector3) -> Basis:
	var y_axis := dir.normalized()
	var ref := Vector3.FORWARD if absf(y_axis.dot(Vector3.FORWARD)) < 0.92 else Vector3.RIGHT
	var x_axis := ref.cross(y_axis).normalized()
	var z_axis := x_axis.cross(y_axis).normalized()
	return Basis(x_axis, y_axis, z_axis)


static func _add_chamfered_box(
	c: ManifoldCanvas,
	slot: String,
	xf: Transform3D,
	size: Vector3,
	bevel: float = 0.008,
	wear: float = 0.09,
	grime: float = 0.10,
	emit: float = 0.0,
	edge_wear: float = 0.88
) -> void:
	var hx := maxf(size.x * 0.5, 0.002)
	var hy := maxf(size.y * 0.5, 0.002)
	var hz := maxf(size.z * 0.5, 0.002)
	var b := clampf(bevel, 0.001, minf(minf(hx, hy), hz) * 0.40)
	var ix := hx - b
	var iy := hy - b
	var iz := hz - b

	var c_flat := CraftLookdev.encode_mask(wear, grime, emit)
	var edge_g := grime * 0.85 if grime > 0.5 else minf(grime * 0.65, 0.12)
	var c_edge := CraftLookdev.encode_mask(edge_wear if emit < 0.5 else 0.30, edge_g, emit)
	var c_bot := CraftLookdev.encode_mask(wear, maxf(grime, 0.72), emit)

	var px0 := xf * Vector3(hx, iy, iz)
	var px1 := xf * Vector3(hx, iy, -iz)
	var px2 := xf * Vector3(hx, -iy, -iz)
	var px3 := xf * Vector3(hx, -iy, iz)

	var nx0 := xf * Vector3(-hx, iy, -iz)
	var nx1 := xf * Vector3(-hx, iy, iz)
	var nx2 := xf * Vector3(-hx, -iy, iz)
	var nx3 := xf * Vector3(-hx, -iy, -iz)

	var py0 := xf * Vector3(-ix, hy, -iz)
	var py1 := xf * Vector3(ix, hy, -iz)
	var py2 := xf * Vector3(ix, hy, iz)
	var py3 := xf * Vector3(-ix, hy, iz)

	var ny0 := xf * Vector3(-ix, -hy, iz)
	var ny1 := xf * Vector3(ix, -hy, iz)
	var ny2 := xf * Vector3(ix, -hy, -iz)
	var ny3 := xf * Vector3(-ix, -hy, -iz)

	var pz0 := xf * Vector3(-ix, iy, hz)
	var pz1 := xf * Vector3(ix, iy, hz)
	var pz2 := xf * Vector3(ix, -iy, hz)
	var pz3 := xf * Vector3(-ix, -iy, hz)

	var nz0 := xf * Vector3(ix, iy, -hz)
	var nz1 := xf * Vector3(-ix, iy, -hz)
	var nz2 := xf * Vector3(-ix, -iy, -hz)
	var nz3 := xf * Vector3(ix, -iy, -hz)

	var rx := (xf.basis * Vector3.RIGHT).normalized()
	var ry := (xf.basis * Vector3.UP).normalized()
	var rz := (xf.basis * Vector3.BACK).normalized()

	c.add_quad(slot, px0, px1, px2, px3, rx, c_flat, c_flat, c_flat, c_flat)
	c.add_quad(slot, nx0, nx1, nx2, nx3, -rx, c_flat, c_flat, c_flat, c_flat)
	c.add_quad(slot, py0, py1, py2, py3, ry, c_flat, c_flat, c_flat, c_flat)
	c.add_quad(slot, ny0, ny1, ny2, ny3, -ry, c_bot, c_bot, c_bot, c_bot)
	c.add_quad(slot, pz0, pz1, pz2, pz3, rz, c_flat, c_flat, c_flat, c_flat)
	c.add_quad(slot, nz0, nz1, nz2, nz3, -rz, c_flat, c_flat, c_flat, c_flat)

	c.add_quad(slot, py1, py2, px0, px1, (ry + rx).normalized(), c_edge, c_edge, c_edge, c_edge)
	c.add_quad(slot, py3, py0, nx0, nx1, (ry - rx).normalized(), c_edge, c_edge, c_edge, c_edge)
	c.add_quad(slot, py2, py3, pz0, pz1, (ry + rz).normalized(), c_edge, c_edge, c_edge, c_edge)
	c.add_quad(slot, py0, py1, nz0, nz1, (ry - rz).normalized(), c_edge, c_edge, c_edge, c_edge)

	c.add_quad(slot, px2, px3, ny1, ny2, (rx - ry).normalized(), c_edge, c_edge, c_edge, c_edge)
	c.add_quad(slot, nx2, nx3, ny3, ny0, (-rx - ry).normalized(), c_edge, c_edge, c_edge, c_edge)
	c.add_quad(slot, pz3, pz2, ny1, ny0, (rz - ry).normalized(), c_edge, c_edge, c_edge, c_edge)
	c.add_quad(slot, nz3, nz2, ny3, ny2, (-rz - ry).normalized(), c_edge, c_edge, c_edge, c_edge)

	c.add_quad(slot, pz1, px0, px3, pz2, (rx + rz).normalized(), c_edge, c_edge, c_edge, c_edge)
	c.add_quad(slot, nx1, pz0, pz3, nx2, (-rx + rz).normalized(), c_edge, c_edge, c_edge, c_edge)
	c.add_quad(slot, px1, nz0, nz3, px2, (rx - rz).normalized(), c_edge, c_edge, c_edge, c_edge)
	c.add_quad(slot, nz1, nx0, nx3, nz2, (-rx - rz).normalized(), c_edge, c_edge, c_edge, c_edge)

	var c_cnr := CraftLookdev.encode_mask(minf(edge_wear + 0.06, 1.0) if emit < 0.5 else 0.30, edge_g, emit)
	var corners := [
		[py2, px0, pz1, rx + ry + rz],
		[py3, pz0, nx1, -rx + ry + rz],
		[py1, nz0, px1, rx + ry - rz],
		[py0, nx0, nz1, -rx + ry - rz],
		[ny1, pz2, px3, rx - ry + rz],
		[ny0, nx2, pz3, -rx - ry + rz],
		[ny2, px2, nz3, rx - ry - rz],
		[ny3, nz2, nx3, -rx - ry - rz],
	]
	for item in corners:
		c.add_tri(slot, item[0], item[1], item[2], (item[3] as Vector3).normalized(), Vector2.ZERO, Vector2(0.1, 0.0), Vector2(0.05, 0.1), c_cnr, c_cnr, c_cnr)


static func _add_chamfered_prism(
	c: ManifoldCanvas,
	slot: String,
	xf: Transform3D,
	sides: int,
	r_bot: float,
	r_top: float,
	height: float,
	bev_h: float = 0.008,
	bev_r: float = 0.008,
	wear: float = 0.10,
	grime: float = 0.11,
	emit: float = 0.0,
	edge_wear: float = 0.88
) -> void:
	var n := maxi(sides, 3)
	var hy := maxf(height * 0.5, 0.002)
	var bh := clampf(bev_h, 0.001, hy * 0.42)
	var rb := maxf(r_bot, 0.003)
	var rt := maxf(r_top, 0.003)
	var brb := clampf(bev_r, 0.001, rb * 0.40)
	var brt := clampf(bev_r, 0.001, rt * 0.40)

	var edge_g := grime * 0.85 if grime > 0.5 else minf(grime * 0.6, 0.12)
	var c_flat := CraftLookdev.encode_mask(0.0 if emit > 0.5 else wear, 0.0 if emit > 0.5 else grime, emit)
	var c_bot := CraftLookdev.encode_mask(0.0 if emit > 0.5 else wear, 0.0 if emit > 0.5 else maxf(grime, 0.76), emit)
	var c_bev := CraftLookdev.encode_mask(0.0 if emit > 0.5 else edge_wear, 0.0 if emit > 0.5 else edge_g, emit)

	var rings := [
		{"y": -hy, "r": rb - brb},
		{"y": -hy + bh, "r": rb},
		{"y": hy - bh, "r": rt},
		{"y": hy, "r": rt - brt},
	]
	var pts: Array = []
	for ring in rings:
		var row: Array[Vector3] = []
		for i in n:
			var ang := TAU * float(i) / float(n)
			row.append(xf * Vector3(cos(ang) * float(ring.r), float(ring.y), sin(ang) * float(ring.r)))
		pts.append(row)

	var up := (xf.basis * Vector3.UP).normalized()
	var top_c := xf * Vector3(0.0, hy, 0.0)
	var bot_c := xf * Vector3(0.0, -hy, 0.0)
	for i in n:
		var ni := (i + 1) % n
		var mid := TAU * (float(i) + 0.5) / float(n)
		var l_rad := Vector3(cos(mid), 0.0, sin(mid))
		var w_rad := (xf.basis * l_rad).normalized()
		c.add_quad(slot, pts[0][i], pts[0][ni], pts[1][ni], pts[1][i], (w_rad - up * 0.6).normalized(), c_bot, c_bot, c_bev, c_bev)
		c.add_quad(slot, pts[1][i], pts[1][ni], pts[2][ni], pts[2][i], w_rad, c_flat, c_flat, c_flat, c_flat)
		c.add_quad(slot, pts[2][i], pts[2][ni], pts[3][ni], pts[3][i], (w_rad + up * 0.6).normalized(), c_bev, c_bev, c_bev, c_bev)
		c.add_tri(slot, top_c, pts[3][i], pts[3][ni], up, Vector2(0.5, 0.5), Vector2(0.5 + 0.5 * cos(mid), 0.5 + 0.5 * sin(mid)), Vector2(0.5 + 0.5 * cos(mid + TAU / float(n)), 0.5 + 0.5 * sin(mid + TAU / float(n))), c_flat, c_flat, c_flat)
		c.add_tri(slot, bot_c, pts[0][ni], pts[0][i], -up, Vector2(0.5, 0.5), Vector2(0.5 + 0.5 * cos(mid), 0.5 + 0.5 * sin(mid)), Vector2(0.5 + 0.5 * cos(mid + TAU / float(n)), 0.5 + 0.5 * sin(mid + TAU / float(n))), c_bot, c_bot, c_bot)


static func _add_bezel_ring(
	c: ManifoldCanvas,
	slot: String,
	xf: Transform3D,
	sides: int,
	r_inner: float,
	r_outer: float,
	height: float,
	wear: float = 0.14,
	grime: float = 0.16,
	edge_wear: float = 0.90
) -> void:
	var n := maxi(sides, 6)
	var hy := maxf(height * 0.5, 0.003)
	var ri := maxf(r_inner, 0.004)
	var ro := maxf(r_outer, ri + 0.005)
	var c_flat := CraftLookdev.encode_mask(wear, grime, 0.0)
	var c_edge := CraftLookdev.encode_mask(edge_wear, minf(grime * 0.7, 0.14), 0.0)
	var c_in := CraftLookdev.encode_mask(0.18, maxf(grime, 0.82), 0.0)

	var o_bot: Array[Vector3] = []
	var o_top: Array[Vector3] = []
	var i_bot: Array[Vector3] = []
	var i_top: Array[Vector3] = []
	for k in n:
		var ang := TAU * float(k) / float(n)
		var ca := cos(ang)
		var sa := sin(ang)
		o_bot.append(xf * Vector3(ca * ro, -hy, sa * ro))
		o_top.append(xf * Vector3(ca * ro, hy, sa * ro))
		i_bot.append(xf * Vector3(ca * ri, -hy, sa * ri))
		i_top.append(xf * Vector3(ca * ri, hy, sa * ri))

	var up := (xf.basis * Vector3.UP).normalized()
	for k in n:
		var nk := (k + 1) % n
		var mid := TAU * (float(k) + 0.5) / float(n)
		var w_rad := (xf.basis * Vector3(cos(mid), 0.0, sin(mid))).normalized()
		c.add_quad(slot, o_bot[k], o_bot[nk], o_top[nk], o_top[k], w_rad, c_flat, c_flat, c_edge, c_edge)
		c.add_quad(slot, i_bot[nk], i_bot[k], i_top[k], i_top[nk], -w_rad, c_in, c_in, c_in, c_in)
		c.add_quad(slot, o_top[k], o_top[nk], i_top[nk], i_top[k], up, c_edge, c_edge, c_in, c_in)
		c.add_quad(slot, i_bot[k], i_bot[nk], o_bot[nk], o_bot[k], -up, c_in, c_in, c_flat, c_flat)


static func _add_closed_tube(
	c: ManifoldCanvas,
	slot: String,
	pts: Array[Vector3],
	radius_x: float,
	radius_y: float,
	sides: int = 8,
	wear: float = 0.22,
	grime: float = 0.16,
	edge_wear: float = 0.88
) -> void:
	if pts.size() < 2:
		return
	var segs := pts.size() - 1
	var ns := maxi(sides, 6)
	var tangents: Array[Vector3] = []
	for i in pts.size():
		var a := pts[maxi(i - 1, 0)]
		var b := pts[mini(i + 1, segs)]
		var t := (b - a).normalized()
		tangents.append(t if t.length_squared() > 1e-8 else Vector3.RIGHT)

	var normals: Array[Vector3] = []
	var binormals: Array[Vector3] = []
	var ref := Vector3.UP if absf(tangents[0].dot(Vector3.UP)) < 0.9 else Vector3.FORWARD
	var n0 := ref.cross(tangents[0]).normalized()
	normals.append(n0)
	binormals.append(tangents[0].cross(n0).normalized())
	for i in range(1, pts.size()):
		var tp := tangents[i - 1]
		var tc := tangents[i]
		var ax := tp.cross(tc)
		var nc := normals[i - 1]
		if ax.length_squared() > 1e-10:
			nc = nc.rotated(ax.normalized(), atan2(ax.length(), clampf(tp.dot(tc), -1.0, 1.0))).normalized()
		nc = (nc - tc * nc.dot(tc)).normalized()
		normals.append(nc)
		binormals.append(tc.cross(nc).normalized())

	var rings: Array = []
	for i in pts.size():
		var row: Array[Vector3] = []
		for j in ns:
			var ang := TAU * float(j) / float(ns)
			row.append(pts[i] + normals[i] * (cos(ang) * radius_x) + binormals[i] * (sin(ang) * radius_y))
		rings.append(row)

	var c_main := CraftLookdev.encode_mask(wear, grime, 0.0)
	var c_edge := CraftLookdev.encode_mask(edge_wear, minf(grime * 0.8, 0.16), 0.0)
	var c_end := CraftLookdev.encode_mask(wear, maxf(grime, 0.78), 0.0)
	for i in segs:
		for j in ns:
			var nj := (j + 1) % ns
			var p00: Vector3 = rings[i][j]
			var p01: Vector3 = rings[i][nj]
			var p11: Vector3 = rings[i + 1][nj]
			var p10: Vector3 = rings[i + 1][j]
			var out_n := ((p00 + p01 + p11 + p10) * 0.25 - (pts[i] + pts[i + 1]) * 0.5).normalized()
			var col := c_edge if (j % 2 == 0) else c_main
			c.add_quad(slot, p00, p01, p11, p10, out_n, col, col, col, col)

	for j in ns:
		var nj := (j + 1) % ns
		c.add_tri(slot, pts[0], rings[0][nj], rings[0][j], -tangents[0], Vector2(0.5, 0.5), Vector2(1, 0), Vector2(0, 1), c_end, c_end, c_end)
		c.add_tri(slot, pts[segs], rings[segs][j], rings[segs][nj], tangents[segs], Vector2(0.5, 0.5), Vector2(1, 0), Vector2(0, 1), c_end, c_end, c_end)


static func _add_rivet(c: ManifoldCanvas, slot: String, pos: Vector3, normal: Vector3, radius: float = 0.009, height: float = 0.007) -> void:
	var n := normal.normalized()
	var basis := _frame_from_dir(n)
	_add_chamfered_prism(c, slot, Transform3D(basis, pos + n * (height * 0.2)), 6, radius * 1.25, radius * 1.18, height * 0.4, height * 0.12, radius * 0.15, 0.14, 0.86, 0.0, 0.55)
	_add_chamfered_prism(c, slot, Transform3D(basis, pos + n * (height * 0.65)), 6, radius, radius * 0.85, height * 0.72, height * 0.22, radius * 0.22, 0.45, 0.20, 0.0, 0.94)



static func build_riveted_goggles_mesh() -> ArrayMesh:
	var c := ManifoldCanvas.new()
	var lens_rot := Basis(Vector3.RIGHT, PI * 0.5)
	for sx: float in [-1.0, 1.0]:
		var eye_pos := Vector3(sx * 0.082, 0.0, -0.036)
		var cup_xf := Transform3D(Basis(Vector3.UP, -sx * deg_to_rad(14.0)) * lens_rot, eye_pos)
		_add_bezel_ring(c, "brass_trim", cup_xf, 12, 0.042, 0.062, 0.052, 0.18, 0.16, 0.92)
		_add_bezel_ring(c, "strap_leather", cup_xf * Transform3D(Basis.IDENTITY, Vector3(0.0, -0.030, 0.0)), 12, 0.044, 0.066, 0.022, 0.10, 0.84, 0.45)
		_add_chamfered_prism(c, "emissive_dial", cup_xf * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.012, 0.0)), 12, 0.042, 0.041, 0.012, 0.002, 0.002, 0.0, 0.0, 1.0, 0.0)
		for k in 4:
			var ang := PI * 0.25 + PI * 0.5 * float(k)
			var r_off := Vector3(cos(ang) * 0.054, sin(ang) * 0.054, -0.028)
			_add_rivet(c, "iron_hardware", eye_pos + r_off, Vector3.FORWARD, 0.007, 0.006)
		var knob_xf := Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(sx * 0.146, 0.0, -0.016))
		_add_chamfered_prism(c, "iron_hardware", knob_xf, 8, 0.018, 0.016, 0.022, 0.003, 0.003, 0.24, 0.42, 0.0, 0.92)

	_add_chamfered_box(c, "iron_hardware", Transform3D(Basis.IDENTITY, Vector3(0.0, 0.010, -0.046)), Vector3(0.052, 0.026, 0.020), 0.004, 0.12, 0.24, 0.0, 0.90)
	_add_rivet(c, "brass_trim", Vector3(0.0, 0.010, -0.057), Vector3.FORWARD, 0.008, 0.006)

	var strap_pts: Array[Vector3] = [
		Vector3(0.144, 0.0, -0.016),
		Vector3(0.160, 0.002, 0.022),
		Vector3(0.164, 0.003, 0.072),
		Vector3(0.136, 0.004, 0.124),
		Vector3(0.074, 0.004, 0.156),
		Vector3(0.0, 0.004, 0.166),
		Vector3(-0.074, 0.004, 0.156),
		Vector3(-0.136, 0.004, 0.124),
		Vector3(-0.164, 0.003, 0.072),
		Vector3(-0.160, 0.002, 0.022),
		Vector3(-0.144, 0.0, -0.016),
	]
	_add_closed_tube(c, "strap_leather", strap_pts, 0.012, 0.020, 8, 0.16, 0.34, 0.82)

	return c.commit({"gear_id": GEAR_GOGGLES, "bone": "head"})



static func build_shoulder_harness_mesh() -> ArrayMesh:
	var c := ManifoldCanvas.new()
	for sx: float in [-1.0, 1.0]:
		var pts: Array[Vector3] = [
			Vector3(sx * 0.068, -0.045, -0.212),
			Vector3(sx * 0.148, 0.030, -0.195),
			Vector3(sx * 0.182, 0.112, -0.075),
			Vector3(sx * 0.175, 0.108, 0.068),
			Vector3(sx * 0.128, 0.015, 0.190),
			Vector3(sx * 0.068, -0.055, 0.205),
		]
		_add_closed_tube(c, "strap_leather", pts, 0.014, 0.032, 8, 0.15, 0.22, 0.86)
		var cinch_xf := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-28.0)), Vector3(sx * 0.168, 0.078, -0.145))
		_add_chamfered_box(c, "brass_trim", cinch_xf, Vector3(0.062, 0.042, 0.022), 0.006, 0.16, 0.32, 0.0, 0.92)
		_add_rivet(c, "iron_hardware", Vector3(sx * 0.168, 0.078, -0.158), Vector3.FORWARD, 0.007, 0.006)

	_add_chamfered_box(c, "iron_hardware", Transform3D(Basis.IDENTITY, Vector3(0.0, -0.042, -0.218)), Vector3(0.142, 0.092, 0.030), 0.009, 0.11, 0.30, 0.0, 0.90)
	_add_chamfered_box(c, "brass_trim", Transform3D(Basis.IDENTITY, Vector3(0.0, -0.042, -0.234)), Vector3(0.082, 0.054, 0.018), 0.006, 0.16, 0.18, 0.0, 0.94)
	for sx: float in [-0.052, 0.052]:
		for sy: float in [-0.028, 0.028]:
			_add_rivet(c, "iron_hardware", Vector3(sx, -0.042 + sy, -0.233), Vector3.FORWARD, 0.0075, 0.006)

	_add_chamfered_box(c, "iron_hardware", Transform3D(Basis.IDENTITY, Vector3(0.0, -0.045, 0.206)), Vector3(0.135, 0.082, 0.026), 0.008, 0.10, 0.72, 0.0, 0.86)
	return c.commit({"gear_id": GEAR_HARNESS, "bone": "spine_02"})



static func build_utility_belt_mesh() -> ArrayMesh:
	var c := ManifoldCanvas.new()
	_add_bezel_ring(c, "strap_leather", Transform3D(Basis.IDENTITY, Vector3.ZERO), 16, 0.212, 0.238, 0.072, 0.14, 0.28, 0.84)
	_add_chamfered_box(c, "brass_trim", Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -0.244)), Vector3(0.112, 0.086, 0.028), 0.008, 0.18, 0.22, 0.0, 0.94)
	_add_chamfered_box(c, "iron_hardware", Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -0.258)), Vector3(0.058, 0.042, 0.016), 0.005, 0.12, 0.80, 0.0, 0.75)
	for sx: float in [-0.040, 0.040]:
		_add_rivet(c, "iron_hardware", Vector3(sx, 0.0, -0.258), Vector3.FORWARD, 0.007, 0.0055)
	for sx: float in [-1.0, 1.0]:
		var p_xf := Transform3D(Basis(Vector3.UP, sx * deg_to_rad(14.0)), Vector3(sx * 0.250, -0.012, -0.024))
		_add_chamfered_box(c, "strap_leather", p_xf, Vector3(0.056, 0.104, 0.098), 0.009, 0.12, 0.34, 0.0, 0.86)
		_add_chamfered_box(c, "brass_trim", p_xf * Transform3D(Basis.IDENTITY, Vector3(sx * 0.018, 0.024, 0.0)), Vector3(0.028, 0.040, 0.088), 0.006, 0.16, 0.24, 0.0, 0.92)
		_add_rivet(c, "iron_hardware", p_xf * Vector3(sx * 0.032, 0.020, 0.0), Vector3(sx, 0.0, 0.0), 0.0075, 0.006)
	return c.commit({"gear_id": GEAR_BELT, "bone": "pelvis"})



static func build_cockpit_yoke_mesh() -> ArrayMesh:
	var c := ManifoldCanvas.new()
	_add_chamfered_prism(c, "iron_hardware", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.0, 0.0, 0.0)), 10, 0.052, 0.048, 0.090, 0.010, 0.008, 0.12, 0.78, 0.0, 0.88)
	_add_chamfered_prism(c, "iron_hardware", Transform3D(Basis.IDENTITY, Vector3(0.0, 0.085, 0.008)), 10, 0.034, 0.030, 0.165, 0.008, 0.006, 0.14, 0.28, 0.0, 0.88)
	_add_chamfered_box(c, "brass_trim", Transform3D(Basis.IDENTITY, Vector3(0.0, 0.172, 0.012)), Vector3(0.145, 0.068, 0.054), 0.010, 0.16, 0.22, 0.0, 0.92)
	for sx: float in [-0.048, 0.048]:
		_add_rivet(c, "iron_hardware", Vector3(sx, 0.172, 0.039), Vector3.BACK, 0.008, 0.006)

	for sx: float in [-1.0, 1.0]:
		var arm_pts: Array[Vector3] = [
			Vector3(sx * 0.065, 0.168, 0.012),
			Vector3(sx * 0.185, 0.155, 0.018),
			Vector3(sx * 0.295, 0.168, 0.020),
			Vector3(sx * 0.320, 0.195, 0.020),
		]
		_add_closed_tube(c, "iron_hardware", arm_pts, 0.020, 0.022, 8, 0.14, 0.22, 0.90)
		var grip_pos := Vector3(sx * 0.320, 0.215, 0.020)
		_add_chamfered_prism(c, "strap_leather", Transform3D(Basis(Vector3.BACK, -sx * deg_to_rad(8.0)), grip_pos), 10, 0.028, 0.026, 0.135, 0.012, 0.006, 0.42, 0.18, 0.0, 0.94)
		for gy: float in [-0.042, 0.0, 0.042]:
			_add_chamfered_prism(c, "iron_hardware", Transform3D(Basis.IDENTITY, grip_pos + Vector3(0.0, gy, 0.0)), 10, 0.031, 0.031, 0.012, 0.003, 0.003, 0.35, 0.68, 0.0, 0.90)
		_add_chamfered_box(c, "brass_trim", Transform3D(Basis.IDENTITY, grip_pos + Vector3(-sx * 0.016, 0.074, 0.0)), Vector3(0.036, 0.024, 0.032), 0.005, 0.25, 0.20, 0.0, 0.94)
		_add_chamfered_box(c, "brass_trim", Transform3D(Basis(Vector3.RIGHT, deg_to_rad(18.0)), grip_pos + Vector3(0.0, 0.012, -0.036)), Vector3(0.018, 0.048, 0.016), 0.004, 0.30, 0.28, 0.0, 0.92)

	return c.commit({"gear_id": GEAR_YOKE, "hand_l": CANONICAL_HAND_L, "hand_r": CANONICAL_HAND_R})



static func build_gauge_cluster_mesh() -> ArrayMesh:
	var c := ManifoldCanvas.new()
	var face_rot := Basis(Vector3.RIGHT, deg_to_rad(72.0))
	_add_chamfered_box(c, "iron_hardware", Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-18.0)), Vector3(0.0, 0.0, 0.0)), Vector3(0.360, 0.145, 0.115), 0.014, 0.10, 0.22, 0.0, 0.90)
	_add_chamfered_box(c, "brass_trim", Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-12.0)), Vector3(0.0, 0.072, 0.024)), Vector3(0.375, 0.024, 0.125), 0.006, 0.15, 0.18, 0.0, 0.94)

	var dials := [
		{"x": -0.098, "r": 0.048},
		{"x": 0.098, "r": 0.048},
		{"x": 0.0, "r": 0.030},
	]
	for d in dials:
		var dp := Vector3(float(d.x), 0.006, 0.068)
		var r := float(d.r)
		var dxf := Transform3D(face_rot, dp)
		_add_bezel_ring(c, "brass_trim", dxf, 12, r * 0.78, r, 0.026, 0.18, 0.20, 0.94)
		_add_chamfered_prism(c, "emissive_dial", dxf * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.003, 0.0)), 12, r * 0.77, r * 0.77, 0.009, 0.002, 0.002, 0.0, 0.0, 1.0, 0.0)
		_add_chamfered_box(c, "iron_hardware", dxf * Transform3D(Basis(Vector3.UP, deg_to_rad(35.0)), Vector3(0.0, 0.011, 0.0)), Vector3(r * 1.12, 0.005, 0.007), 0.001, 0.30, 0.20, 0.0, 0.92)

	_add_chamfered_box(c, "brass_trim", Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-18.0)), Vector3(0.0, 0.018, -0.062)), Vector3(0.285, 0.038, 0.016), 0.004, 0.16, 0.28, 0.0, 0.92)
	for sy: float in [-0.024, -0.046]:
		_add_chamfered_box(c, "iron_hardware", Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-18.0)), Vector3(0.0, sy, -0.064)), Vector3(0.240, 0.014, 0.018), 0.003, 0.14, 0.76, 0.0, 0.88)
	for sx: float in [-0.150, 0.150]:
		_add_rivet(c, "iron_hardware", Vector3(sx, 0.018, -0.071), Vector3.FORWARD, 0.0075, 0.006)

	for sx: float in [-0.155, 0.155]:
		for sy: float in [-0.048, 0.048]:
			_add_rivet(c, "iron_hardware", Vector3(sx, sy, 0.064), Vector3.BACK, 0.007, 0.006)
	for sx: float in [-0.045, 0.0, 0.045]:
		_add_chamfered_prism(c, "brass_trim", Transform3D(face_rot, Vector3(sx, -0.048, 0.072)), 6, 0.008, 0.006, 0.026, 0.003, 0.002, 0.32, 0.35, 0.0, 0.92)

	return c.commit({"gear_id": GEAR_GAUGES})



static func build_cockpit_pedal_mesh() -> ArrayMesh:
	var c := ManifoldCanvas.new()
	_add_chamfered_prism(c, "iron_hardware", Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3.ZERO), 8, 0.022, 0.022, 0.068, 0.005, 0.004, 0.14, 0.84, 0.0, 0.86)
	_add_chamfered_box(c, "iron_hardware", Transform3D(Basis.IDENTITY, Vector3(0.0, -0.075, 0.015)), Vector3(0.028, 0.150, 0.026), 0.005, 0.12, 0.42, 0.0, 0.88)
	_add_chamfered_box(c, "iron_hardware", Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-22.0)), Vector3(0.0, -0.155, 0.032)), Vector3(0.115, 0.088, 0.022), 0.007, 0.16, 0.36, 0.0, 0.92)
	for ry: float in [-0.024, 0.0, 0.024]:
		_add_chamfered_box(c, "brass_trim", Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-22.0)), Vector3(0.0, -0.155 + ry, 0.045)), Vector3(0.092, 0.011, 0.010), 0.0025, 0.38, 0.28, 0.0, 0.94)
	return c.commit({"gear_id": GEAR_PEDAL})


static func build_gear(gear_id: StringName) -> ArrayMesh:
	match gear_id:
		GEAR_GOGGLES:
			return build_riveted_goggles_mesh()
		GEAR_HARNESS:
			return build_shoulder_harness_mesh()
		GEAR_BELT:
			return build_utility_belt_mesh()
		GEAR_YOKE:
			return build_cockpit_yoke_mesh()
		GEAR_GAUGES:
			return build_gauge_cluster_mesh()
		GEAR_PEDAL:
			return build_cockpit_pedal_mesh()
	push_error("PilotGearKit: unknown gear_id '%s'" % String(gear_id))
	return ArrayMesh.new()



static func slot_material(slot: String, accent_color: Color = Palette.ARC) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.78
	mat.metallic = 0.18
	PaletteMaterials.surface_grain(mat)
	var plate := PaletteMaterials.look_texture("rusted-salvaged-plate-worn", true)
	if plate != null:
		mat.albedo_texture = plate
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3.ONE * 2.4
	match slot:
		"brass_trim":
			mat.albedo_color = Palette.COPPER.lerp(Palette.BRASS, 0.35)
			PaletteMaterials.brass_finish(mat)
		"iron_hardware":
			mat.albedo_color = Palette.CHARCOAL.lerp(Palette.STEEL, 0.38)
			mat.roughness = 0.66
			mat.metallic = 0.42
		"strap_leather":
			mat.albedo_color = Palette.RUST.darkened(0.32)
			mat.roughness = 0.88
			mat.metallic = 0.04
		"emissive_dial":
			mat.albedo_color = accent_color
			mat.roughness = 0.26
			mat.metallic = 0.05
			mat.emission_enabled = true
			mat.emission = accent_color
			mat.emission_energy_multiplier = 2.0
		_:
			mat.albedo_color = Palette.STEEL
	return mat


static func apply_materials(inst: MeshInstance3D, accent_color: Color = Palette.ARC) -> void:
	if inst == null or not (inst.mesh is ArrayMesh):
		return
	var am := inst.mesh as ArrayMesh
	for s in am.get_surface_count():
		inst.set_surface_override_material(s, slot_material(am.surface_get_name(s), accent_color))


static func mount_pilot_wearables(pilot: Node, accent_color: Color = Palette.ARC, skip_existing_goggles := false) -> Dictionary:
	var out := {}
	if pilot == null:
		return out
	var skels := pilot.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		return out
	var skel := skels[0] as Skeleton3D
	var specs := [
		{"key": "goggles", "bone": "head", "fallback": "goggles", "gear": GEAR_GOGGLES, "offset": Vector3(0.0, 0.195, -0.152), "rot_deg": Vector3(34.0, 0.0, 0.0), "scale": 0.94},
		{"key": "harness", "bone": "spine_02", "fallback": "spine_01", "gear": GEAR_HARNESS, "offset": Vector3(0.0, 0.008, 0.018), "rot_deg": Vector3.ZERO, "scale": 0.88},
		{"key": "belt", "bone": "pelvis", "fallback": "root", "gear": GEAR_BELT, "offset": Vector3(0.0, 0.055, 0.0), "rot_deg": Vector3.ZERO, "scale": 1.04},
	]
	for spec in specs:
		if skip_existing_goggles and String(spec.key) == "goggles" and skel.find_bone("goggles") >= 0:
			continue
		var bn: String = spec.bone
		var bi := skel.find_bone(bn)
		if bi < 0:
			bn = spec.fallback
			bi = skel.find_bone(bn)
		if bi < 0:
			continue
		var attach_name := "CraftGear_" + String(spec.key)
		var existing := skel.get_node_or_null(attach_name) as BoneAttachment3D
		if existing != null:
			out[String(spec.key)] = existing
			continue
		var ba := BoneAttachment3D.new()
		ba.name = attach_name
		ba.bone_name = bn
		skel.add_child(ba)
		var bone_rest_inv := skel.get_bone_global_rest(bi).basis.orthonormalized().inverse()
		var skel_euler := Vector3(deg_to_rad(spec.rot_deg.x), deg_to_rad(spec.rot_deg.y), deg_to_rad(spec.rot_deg.z))
		var mi := MeshInstance3D.new()
		mi.name = "Mesh"
		mi.mesh = build_gear(spec.gear)
		mi.transform = Transform3D(
			(bone_rest_inv * Basis.from_euler(skel_euler)).scaled(Vector3.ONE * float(spec.scale)),
			bone_rest_inv * (spec.offset as Vector3)
		)
		apply_materials(mi, accent_color)
		ba.add_child(mi)
		out[String(spec.key)] = ba
	return out


static func mount_cockpit_rig(parent_pod: Node3D, accent_color: Color = Palette.ARC) -> Dictionary:
	var out := {}
	if parent_pod == null:
		return out
	var root_rig := parent_pod.get_node_or_null("CraftCockpitRig") as Node3D
	if root_rig == null:
		root_rig = Node3D.new()
		root_rig.name = "CraftCockpitRig"
		parent_pod.add_child(root_rig)

	var yoke := MeshInstance3D.new()
	yoke.name = "YokeRig"
	yoke.mesh = build_cockpit_yoke_mesh()
	yoke.position = CANONICAL_YOKE_PIVOT
	apply_materials(yoke, accent_color)
	root_rig.add_child(yoke)
	out["yoke"] = yoke

	var gauges := MeshInstance3D.new()
	gauges.name = "GaugeCluster"
	gauges.mesh = build_gauge_cluster_mesh()
	gauges.position = CANONICAL_DASH_ORIGIN
	apply_materials(gauges, accent_color)
	root_rig.add_child(gauges)
	out["gauges"] = gauges

	var throttle := MeshInstance3D.new()
	throttle.name = "ThrottleLever"
	throttle.mesh = build_cockpit_pedal_mesh()
	throttle.position = Vector3(-0.38, -0.05, -0.44)
	throttle.scale = Vector3(0.55, 0.72, 0.55)
	throttle.rotation_degrees = Vector3(180.0, 0.0, 0.0)
	apply_materials(throttle, accent_color)
	root_rig.add_child(throttle)
	out["throttle"] = throttle

	var pedal_l := MeshInstance3D.new()
	pedal_l.name = "PedalL"
	pedal_l.mesh = build_cockpit_pedal_mesh()
	pedal_l.position = Vector3(-0.16, -0.25, -0.48)
	pedal_l.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	apply_materials(pedal_l, accent_color)
	root_rig.add_child(pedal_l)
	out["pedal_l"] = pedal_l

	var pedal_r := MeshInstance3D.new()
	pedal_r.name = "PedalR"
	pedal_r.mesh = build_cockpit_pedal_mesh()
	pedal_r.position = Vector3(0.16, -0.25, -0.48)
	pedal_r.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	apply_materials(pedal_r, accent_color)
	root_rig.add_child(pedal_r)
	out["pedal_r"] = pedal_r

	out["root"] = root_rig
	return out


static func inspect_mesh_watertight(mesh: ArrayMesh) -> Dictionary:
	var vert_count := 0
	var tri_count := 0
	var shared_edges := 0
	var boundary_edges := 0
	var non_manifold_edges := 0
	var degenerate_tris := 0
	var outward_ok := 0
	var checked_tris := 0
	var finite_ok := true
	var uv_ok := true
	var tangent_ok := true
	var r_low := 0
	var r_high := 0
	var g_low := 0
	var g_high := 0
	var b_high := 0
	var b_zero := 0

	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
		var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR]
		var tans: PackedFloat32Array = arr[Mesh.ARRAY_TANGENT]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var nv := verts.size()
		vert_count += nv
		if norms.size() != nv or uvs.size() != nv or cols.size() != nv:
			finite_ok = false
			uv_ok = false
		if tans.size() != nv * 4:
			tangent_ok = false
		for i in nv:
			if not verts[i].is_finite() or not norms[i].is_finite() or absf(norms[i].length() - 1.0) > 0.03:
				finite_ok = false
			if not uvs[i].is_finite():
				uv_ok = false
			var col := cols[i]
			if col.r <= 0.25:
				r_low += 1
			if col.r >= 0.72:
				r_high += 1
			if col.g <= 0.35:
				g_low += 1
			if col.g >= 0.65:
				g_high += 1
			if col.b >= 0.90:
				b_high += 1
			if col.b <= 0.01:
				b_zero += 1

		var tn := int(floor(float(idx.size()) / 3.0)) if idx.size() > 0 else int(floor(float(nv) / 3.0))
		tri_count += tn
		var edge_counts := {}
		for ti in tn:
			var i0 := idx[ti * 3] if idx.size() > 0 else ti * 3
			var i1 := idx[ti * 3 + 1] if idx.size() > 0 else ti * 3 + 1
			var i2 := idx[ti * 3 + 2] if idx.size() > 0 else ti * 3 + 2
			var v0 := verts[i0]
			var v1 := verts[i1]
			var v2 := verts[i2]
			var geo := (v2 - v0).cross(v1 - v0)
			if geo.length_squared() < 1e-13:
				degenerate_tris += 1
				continue
			checked_tris += 1
			if geo.dot((norms[i0] + norms[i1] + norms[i2]).normalized()) > 0.0:
				outward_ok += 1
			var k0 := _qk(v0)
			var k1 := _qk(v1)
			var k2 := _qk(v2)
			for pair in [[k0, k1], [k1, k2], [k2, k0]]:
				var a: String = pair[0]
				var b: String = pair[1]
				if a == b:
					continue
				var ek := (a + "|" + b) if a < b else (b + "|" + a)
				edge_counts[ek] = int(edge_counts.get(ek, 0)) + 1
		for ek in edge_counts:
			var cnt: int = edge_counts[ek]
			if cnt == 2:
				shared_edges += 1
			elif cnt == 1:
				boundary_edges += 1
			else:
				non_manifold_edges += 1

	var vf := maxf(float(vert_count), 1.0)
	return {
		"surfaces": mesh.get_surface_count(),
		"vertices": vert_count,
		"triangles": tri_count,
		"degenerate_tris": degenerate_tris,
		"shared_edges": shared_edges,
		"boundary_edges": boundary_edges,
		"non_manifold_edges": non_manifold_edges,
		"watertight": boundary_edges == 0 and non_manifold_edges == 0 and shared_edges > 0,
		"outward_ratio": float(outward_ok) / maxf(float(checked_tris), 1.0),
		"finite_ok": finite_ok,
		"uv_ok": uv_ok,
		"tangent_ok": tangent_ok,
		"r_low_ratio": float(r_low) / vf,
		"r_high_ratio": float(r_high) / vf,
		"g_low_ratio": float(g_low) / vf,
		"g_high_ratio": float(g_high) / vf,
		"b_high_ratio": float(b_high) / vf,
		"b_zero_ratio": float(b_zero) / vf,
	}


static func _qk(v: Vector3) -> String:
	return "%d,%d,%d" % [int(round(v.x * WELD_QUANT)), int(round(v.y * WELD_QUANT)), int(round(v.z * WELD_QUANT))]
