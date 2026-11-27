@tool
class_name HeroKitbashSculptor
extends RefCounted


const CraftLookdev := preload("res://src/presentation/craft/craft_lookdev.gd")

const HERO_EM_CRANE := &"em_crane_gantry"
const HERO_SALVAGE_PRESS := &"salvage_press_beacon"
const HERO_CONDUIT_PYLON := &"conduit_pylon"

const HERO_IDS: Array[StringName] = [
	HERO_EM_CRANE,
	HERO_SALVAGE_PRESS,
	HERO_CONDUIT_PYLON,
]

const SURFACE_SLOTS := {
	"hull_plating": "oil_slicked_iron",
	"iron_frame": "oil_slicked_iron",
	"copper_coil": "oxidized_hull_plating",
	"patch_oxide": "oxidized_hull_plating",
	"concrete_plinth": "scorched_concrete",
	"emissive_core": "plasma_conduit_core",
	"cable_rubber": "oil_slicked_iron",
}

const VERTEX_COLOR_CONTRACT := {
	"r": "edge_wear",
	"g": "cavity_grime",
	"b": "emissive_mask",
	"a": "blend_weight",
}

const FOOT_GRIME_HEIGHT_M := 0.52
const FOOT_GRIME_STRENGTH := 0.86



class KitbashCanvas extends RefCounted:
	var _tools: Dictionary = {}
	var _order: Array[String] = []
	var ground_foot_grime := true

	func _tool_for(slot: String) -> SurfaceTool:
		if not _tools.has(slot):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			_tools[slot] = st
			_order.append(slot)
		return _tools[slot]

	func _apply_foot_grime(pos: Vector3, color: Color) -> Color:
		if not ground_foot_grime or color.b > 0.5:
			return color
		if pos.y < FOOT_GRIME_HEIGHT_M:
			var t := clampf(1.0 - maxf(pos.y, 0.0) / FOOT_GRIME_HEIGHT_M, 0.0, 1.0)
			var grime := maxf(color.g, t * t * FOOT_GRIME_STRENGTH)
			return Color(color.r, grime, color.b, color.a)
		return color

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
		c2: Color,
		n0: Vector3 = Vector3.ZERO,
		n1: Vector3 = Vector3.ZERO,
		n2: Vector3 = Vector3.ZERO
	) -> void:
		var geo := (p2 - p0).cross(p1 - p0)
		if geo.length_squared() < 1e-12:
			return
		var target := expected_normal.normalized() if expected_normal.length_squared() > 1e-12 else geo.normalized()
		var a := p0
		var b := p1
		var c := p2
		var uva := uv0
		var uvb := uv1
		var uvc := uv2
		var ca := _apply_foot_grime(a, c0)
		var cb := _apply_foot_grime(b, c1)
		var cc := _apply_foot_grime(c, c2)
		var na := n0.normalized() if n0.length_squared() > 1e-12 else target
		var nb := n1.normalized() if n1.length_squared() > 1e-12 else target
		var nc := n2.normalized() if n2.length_squared() > 1e-12 else target
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
			var tn := nb
			nb = nc
			nc = tn
		var st := _tool_for(slot)
		st.set_normal(na)
		st.set_uv(uva)
		st.set_color(ca)
		st.add_vertex(a)
		st.set_normal(nb)
		st.set_uv(uvb)
		st.set_color(cb)
		st.add_vertex(b)
		st.set_normal(nc)
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
		c3: Color,
		n0: Vector3 = Vector3.ZERO,
		n1: Vector3 = Vector3.ZERO,
		n2: Vector3 = Vector3.ZERO,
		n3: Vector3 = Vector3.ZERO
	) -> void:
		var u_axis := (p1 - p0)
		var u_len := u_axis.length()
		if u_len < 1e-6:
			u_axis = Vector3.RIGHT
		else:
			u_axis /= u_len
		var n := outward.normalized() if outward.length_squared() > 1e-12 else (p3 - p0).cross(p1 - p0).normalized()
		var v_axis := n.cross(u_axis)
		if v_axis.length_squared() < 1e-12:
			v_axis = Vector3.UP
		else:
			v_axis = v_axis.normalized()
		var uv0 := Vector2(p0.dot(u_axis), p0.dot(v_axis))
		var uv1 := Vector2(p1.dot(u_axis), p1.dot(v_axis))
		var uv2 := Vector2(p2.dot(u_axis), p2.dot(v_axis))
		var uv3 := Vector2(p3.dot(u_axis), p3.dot(v_axis))
		add_tri(slot, p0, p1, p2, n, uv0, uv1, uv2, c0, c1, c2, n0, n1, n2)
		add_tri(slot, p0, p2, p3, n, uv0, uv2, uv3, c0, c2, c3, n0, n2, n3)

	func commit(hero_meta: Dictionary = {}) -> ArrayMesh:
		var mesh := ArrayMesh.new()
		for slot in _order:
			var st: SurfaceTool = _tools[slot]
			st.index()
			st.generate_tangents()
			var idx := mesh.get_surface_count()
			st.commit(mesh)
			mesh.surface_set_name(idx, slot)
		for key in hero_meta:
			mesh.set_meta(key, hero_meta[key])
		return mesh


static func create_canvas() -> KitbashCanvas:
	return KitbashCanvas.new()



static func _frame_from_dir(dir: Vector3) -> Basis:
	var y_axis := dir.normalized()
	var ref := Vector3.FORWARD if absf(y_axis.dot(Vector3.FORWARD)) < 0.92 else Vector3.RIGHT
	var x_axis := ref.cross(y_axis).normalized()
	var z_axis := x_axis.cross(y_axis).normalized()
	return Basis(x_axis, y_axis, z_axis)


static func add_chamfered_plate(
	canvas: KitbashCanvas,
	slot: String,
	xform: Transform3D,
	size: Vector3,
	bevel: float = 0.04,
	base_wear: float = 0.09,
	base_grime: float = 0.10,
	emissive: float = 0.0,
	edge_wear: float = 0.88
) -> void:
	var hx := maxf(size.x * 0.5, 0.004)
	var hy := maxf(size.y * 0.5, 0.004)
	var hz := maxf(size.z * 0.5, 0.004)
	var b := clampf(bevel, 0.002, minf(minf(hx, hy), hz) * 0.42)
	var ix := hx - b
	var iy := hy - b
	var iz := hz - b
	var c_flat := CraftLookdev.encode_mask(base_wear, base_grime, emissive)
	var edge_g := base_grime * 0.88 if base_grime > 0.5 else minf(base_grime * 0.65, 0.12)
	var c_edge := CraftLookdev.encode_mask(edge_wear if emissive < 0.5 else 0.35, edge_g, emissive)
	var c_bot := CraftLookdev.encode_mask(base_wear, maxf(base_grime, 0.62), emissive)

	var px0 := xform * Vector3(hx, iy, iz)
	var px1 := xform * Vector3(hx, iy, -iz)
	var px2 := xform * Vector3(hx, -iy, -iz)
	var px3 := xform * Vector3(hx, -iy, iz)

	var nx0 := xform * Vector3(-hx, iy, -iz)
	var nx1 := xform * Vector3(-hx, iy, iz)
	var nx2 := xform * Vector3(-hx, -iy, iz)
	var nx3 := xform * Vector3(-hx, -iy, -iz)

	var py0 := xform * Vector3(-ix, hy, -iz)
	var py1 := xform * Vector3(ix, hy, -iz)
	var py2 := xform * Vector3(ix, hy, iz)
	var py3 := xform * Vector3(-ix, hy, iz)

	var ny0 := xform * Vector3(-ix, -hy, iz)
	var ny1 := xform * Vector3(ix, -hy, iz)
	var ny2 := xform * Vector3(ix, -hy, -iz)
	var ny3 := xform * Vector3(-ix, -hy, -iz)

	var pz0 := xform * Vector3(-ix, iy, hz)
	var pz1 := xform * Vector3(ix, iy, hz)
	var pz2 := xform * Vector3(ix, -iy, hz)
	var pz3 := xform * Vector3(-ix, -iy, hz)

	var nz0 := xform * Vector3(ix, iy, -hz)
	var nz1 := xform * Vector3(-ix, iy, -hz)
	var nz2 := xform * Vector3(-ix, -iy, -hz)
	var nz3 := xform * Vector3(ix, -iy, -hz)

	var rx := (xform.basis * Vector3.RIGHT).normalized()
	var ry := (xform.basis * Vector3.UP).normalized()
	var rz := (xform.basis * Vector3.BACK).normalized()

	canvas.add_quad(slot, px0, px1, px2, px3, rx, c_flat, c_flat, c_flat, c_flat)
	canvas.add_quad(slot, nx0, nx1, nx2, nx3, -rx, c_flat, c_flat, c_flat, c_flat)
	canvas.add_quad(slot, py0, py1, py2, py3, ry, c_flat, c_flat, c_flat, c_flat)
	canvas.add_quad(slot, ny0, ny1, ny2, ny3, -ry, c_bot, c_bot, c_bot, c_bot)
	canvas.add_quad(slot, pz0, pz1, pz2, pz3, rz, c_flat, c_flat, c_flat, c_flat)
	canvas.add_quad(slot, nz0, nz1, nz2, nz3, -rz, c_flat, c_flat, c_flat, c_flat)

	canvas.add_quad(slot, py1, py2, px0, px1, (ry + rx).normalized(), c_edge, c_edge, c_edge, c_edge)
	canvas.add_quad(slot, py3, py0, nx0, nx1, (ry - rx).normalized(), c_edge, c_edge, c_edge, c_edge)
	canvas.add_quad(slot, py2, py3, pz0, pz1, (ry + rz).normalized(), c_edge, c_edge, c_edge, c_edge)
	canvas.add_quad(slot, py0, py1, nz0, nz1, (ry - rz).normalized(), c_edge, c_edge, c_edge, c_edge)

	canvas.add_quad(slot, px2, px3, ny1, ny2, (rx - ry).normalized(), c_edge, c_edge, c_edge, c_edge)
	canvas.add_quad(slot, nx2, nx3, ny3, ny0, (-rx - ry).normalized(), c_edge, c_edge, c_edge, c_edge)
	canvas.add_quad(slot, pz3, pz2, ny1, ny0, (rz - ry).normalized(), c_edge, c_edge, c_edge, c_edge)
	canvas.add_quad(slot, nz3, nz2, ny3, ny2, (-rz - ry).normalized(), c_edge, c_edge, c_edge, c_edge)

	canvas.add_quad(slot, pz1, px0, px3, pz2, (rx + rz).normalized(), c_edge, c_edge, c_edge, c_edge)
	canvas.add_quad(slot, nx1, pz0, pz3, nx2, (-rx + rz).normalized(), c_edge, c_edge, c_edge, c_edge)
	canvas.add_quad(slot, px1, nz0, nz3, px2, (rx - rz).normalized(), c_edge, c_edge, c_edge, c_edge)
	canvas.add_quad(slot, nz1, nx0, nx3, nz2, (-rx - rz).normalized(), c_edge, c_edge, c_edge, c_edge)

	var c_cnr := CraftLookdev.encode_mask(minf(edge_wear + 0.07, 1.0) if emissive < 0.5 else 0.35, edge_g, emissive)
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
		var a: Vector3 = item[0]
		var bv: Vector3 = item[1]
		var cv: Vector3 = item[2]
		var n: Vector3 = (item[3] as Vector3).normalized()
		canvas.add_tri(slot, a, bv, cv, n, Vector2(0, 0), Vector2(0.1, 0), Vector2(0.05, 0.1), c_cnr, c_cnr, c_cnr)


static func add_chamfered_prism(
	canvas: KitbashCanvas,
	slot: String,
	xform: Transform3D,
	sides: int,
	r_bot: float,
	r_top: float,
	height: float,
	bevel_h: float = 0.05,
	bevel_r: float = 0.05,
	base_wear: float = 0.10,
	base_grime: float = 0.11,
	emissive: float = 0.0,
	phase_angle: float = 0.0,
	edge_wear: float = 0.88
) -> void:
	var n_sides := maxi(sides, 3)
	var hy := maxf(height * 0.5, 0.005)
	var bh := clampf(bevel_h, 0.002, hy * 0.45)
	var rb := maxf(r_bot, 0.006)
	var rt := maxf(r_top, 0.006)
	var br_bot := clampf(bevel_r, 0.002, rb * 0.42)
	var br_top := clampf(bevel_r, 0.002, rt * 0.42)

	var rings := [
		{"y": -hy, "r": rb - br_bot, "c": CraftLookdev.encode_mask(base_wear, maxf(base_grime, 0.72), emissive)},
		{"y": -hy + bh, "r": rb, "c": CraftLookdev.encode_mask(edge_wear if emissive < 0.5 else 0.35, maxf(base_grime, 0.45), emissive)},
		{"y": hy - bh, "r": rt, "c": CraftLookdev.encode_mask(edge_wear if emissive < 0.5 else 0.35, minf(base_grime, 0.14), emissive)},
		{"y": hy, "r": rt - br_top, "c": CraftLookdev.encode_mask(base_wear, minf(base_grime, 0.12), emissive)},
	]

	var pts: Array = []
	for ring in rings:
		var row: Array[Vector3] = []
		for i in n_sides:
			var ang := phase_angle + TAU * float(i) / float(n_sides)
			row.append(xform * Vector3(cos(ang) * float(ring.r), float(ring.y), sin(ang) * float(ring.r)))
		pts.append(row)

	var center := xform * Vector3.ZERO
	var up := (xform.basis * Vector3.UP).normalized()
	var top_center := xform * Vector3(0.0, hy, 0.0)
	var bot_center := xform * Vector3(0.0, -hy, 0.0)
	var c_flat_top := CraftLookdev.encode_mask(base_wear, minf(base_grime, 0.12), emissive)
	var c_flat_bot := CraftLookdev.encode_mask(base_wear, maxf(base_grime, 0.76), emissive)
	var c_side_mid := CraftLookdev.encode_mask(base_wear, base_grime, emissive)

	for i in n_sides:
		var ni := (i + 1) % n_sides
		var mid_ang := phase_angle + TAU * (float(i) + 0.5) / float(n_sides)
		var local_radial := Vector3(cos(mid_ang), 0.0, sin(mid_ang))
		var world_radial := (xform.basis * local_radial).normalized()

		var n_bot_bev := (world_radial - up * 0.65).normalized()
		canvas.add_quad(
			slot, pts[0][i], pts[0][ni], pts[1][ni], pts[1][i], n_bot_bev,
			rings[0].c, rings[0].c, rings[1].c, rings[1].c
		)
		var slope_y := (rb - rt) / maxf(height - 2.0 * bh, 0.01)
		var n_wall := (xform.basis * Vector3(local_radial.x, slope_y, local_radial.z)).normalized()
		canvas.add_quad(
			slot, pts[1][i], pts[1][ni], pts[2][ni], pts[2][i], n_wall,
			c_side_mid, c_side_mid, c_side_mid, c_side_mid
		)
		var n_top_bev := (world_radial + up * 0.65).normalized()
		var c_bev := CraftLookdev.encode_mask(edge_wear if emissive < 0.5 else 0.35, minf(base_grime * 0.6, 0.12), emissive)
		canvas.add_quad(
			slot, pts[2][i], pts[2][ni], pts[3][ni], pts[3][i], n_top_bev,
			c_bev, c_bev, c_bev, c_bev
		)
		canvas.add_tri(
			slot, top_center, pts[3][i], pts[3][ni], up,
			Vector2(0.5, 0.5),
			Vector2(0.5 + 0.5 * cos(mid_ang), 0.5 + 0.5 * sin(mid_ang)),
			Vector2(0.5 + 0.5 * cos(mid_ang + TAU / float(n_sides)), 0.5 + 0.5 * sin(mid_ang + TAU / float(n_sides))),
			c_flat_top, c_flat_top, c_flat_top
		)
		var bot_out := (bot_center - center).normalized()
		if bot_out.length_squared() < 1e-6:
			bot_out = -up
		canvas.add_tri(
			slot, bot_center, pts[0][ni], pts[0][i], bot_out,
			Vector2(0.5, 0.5),
			Vector2(0.5 + 0.5 * cos(mid_ang), 0.5 + 0.5 * sin(mid_ang)),
			Vector2(0.5 + 0.5 * cos(mid_ang + TAU / float(n_sides)), 0.5 + 0.5 * sin(mid_ang + TAU / float(n_sides))),
			c_flat_bot, c_flat_bot, c_flat_bot
		)


static func add_recessed_seam(
	canvas: KitbashCanvas,
	slot: String,
	xform: Transform3D,
	width: float,
	height: float,
	depth: float,
	frame_w: float = 0.08,
	cavity_grime: float = 0.88,
	emissive_slot: String = ""
) -> void:
	var fw := clampf(frame_w, 0.02, minf(width, height) * 0.35)
	var bev := minf(fw * 0.28, depth * 0.35)
	add_chamfered_plate(
		canvas, slot,
		xform * Transform3D(Basis.IDENTITY, Vector3(0.0, (height - fw) * 0.5, 0.0)),
		Vector3(width, fw, depth), bev, 0.11, 0.14
	)
	add_chamfered_plate(
		canvas, slot,
		xform * Transform3D(Basis.IDENTITY, Vector3(0.0, -(height - fw) * 0.5, 0.0)),
		Vector3(width, fw, depth), bev, 0.11, 0.22
	)
	var inner_h := maxf(height - fw * 2.0, 0.02)
	add_chamfered_plate(
		canvas, slot,
		xform * Transform3D(Basis.IDENTITY, Vector3(-(width - fw) * 0.5, 0.0, 0.0)),
		Vector3(fw, inner_h, depth), bev, 0.11, 0.16
	)
	add_chamfered_plate(
		canvas, slot,
		xform * Transform3D(Basis.IDENTITY, Vector3((width - fw) * 0.5, 0.0, 0.0)),
		Vector3(fw, inner_h, depth), bev, 0.11, 0.16
	)
	var inner_w := maxf(width - fw * 1.85, 0.02)
	var back_slot := emissive_slot if emissive_slot != "" else slot
	var is_emit := 1.0 if emissive_slot != "" else 0.0
	var back_wear := 0.08 if is_emit < 0.5 else 0.15
	var back_grime := cavity_grime if is_emit < 0.5 else 0.05
	add_chamfered_plate(
		canvas, back_slot,
		xform * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -depth * 0.28)),
		Vector3(inner_w, inner_h + 0.01, depth * 0.42), minf(bev * 0.6, 0.02),
		back_wear, back_grime, is_emit, 0.25 if is_emit < 0.5 else 0.3
	)


static func add_truss_rib(
	canvas: KitbashCanvas,
	slot: String,
	p_start: Vector3,
	p_end: Vector3,
	thickness: float = 0.09,
	bevel: float = 0.022
) -> void:
	var delta := p_end - p_start
	var length := delta.length()
	if length < 0.01:
		return
	var basis := _frame_from_dir(delta)
	var mid := (p_start + p_end) * 0.5
	add_chamfered_plate(
		canvas, slot, Transform3D(basis, mid),
		Vector3(thickness, length, thickness), minf(bevel, thickness * 0.26),
		0.10, 0.14, 0.0, 0.88
	)
	var collar_h := minf(thickness * 0.85, length * 0.18)
	if length > thickness * 2.6:
		var dir := delta / length
		add_chamfered_plate(
			canvas, slot, Transform3D(basis, p_start + dir * (collar_h * 0.6)),
			Vector3(thickness * 1.24, collar_h, thickness * 1.24), minf(bevel * 0.7, collar_h * 0.25),
			0.12, 0.78, 0.0, 0.82
		)
		add_chamfered_plate(
			canvas, slot, Transform3D(basis, p_end - dir * (collar_h * 0.6)),
			Vector3(thickness * 1.24, collar_h, thickness * 1.24), minf(bevel * 0.7, collar_h * 0.25),
			0.12, 0.78, 0.0, 0.82
		)


static func add_louver_vent(
	canvas: KitbashCanvas,
	slot: String,
	xform: Transform3D,
	width: float,
	height: float,
	depth: float,
	slat_count: int = 5,
	emissive_back: bool = false
) -> void:
	var fw := clampf(minf(width, height) * 0.11, 0.03, 0.10)
	add_recessed_seam(
		canvas, slot, xform, width, height, depth, fw, 0.90,
		"emissive_core" if emissive_back else ""
	)
	var count := maxi(slat_count, 2)
	var inner_w := maxf(width - fw * 2.05, 0.04)
	var inner_h := maxf(height - fw * 2.1, 0.04)
	var step := inner_h / float(count)
	var slat_thick := clampf(step * 0.34, 0.015, 0.055)
	var slat_depth := depth * 0.82
	for i in count:
		var y := -inner_h * 0.5 + (float(i) + 0.5) * step
		var slat_xf := xform * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(30.0)), Vector3(0.0, y, depth * 0.12))
		add_chamfered_plate(
			canvas, slot, slat_xf,
			Vector3(inner_w, slat_thick, slat_depth), minf(slat_thick * 0.28, 0.014),
			0.12, 0.78, 0.0, 0.90
		)


static func add_rivet_strip(
	canvas: KitbashCanvas,
	slot: String,
	p_start: Vector3,
	p_end: Vector3,
	outward_normal: Vector3,
	count: int,
	rivet_radius: float = 0.04,
	rivet_height: float = 0.032
) -> void:
	var n := maxi(count, 1)
	var out_n := outward_normal.normalized()
	var basis := _frame_from_dir(out_n)
	for i in n:
		var t := 0.5 if n == 1 else float(i) / float(n - 1)
		var pos := p_start.lerp(p_end, t)
		var washer_xf := Transform3D(basis, pos + out_n * (rivet_height * 0.18))
		add_chamfered_prism(
			canvas, slot, washer_xf, 6,
			rivet_radius * 1.28, rivet_radius * 1.22, rivet_height * 0.36,
			rivet_height * 0.1, rivet_radius * 0.12,
			0.14, 0.86, 0.0, 0.0, 0.52
		)
		var head_xf := Transform3D(basis, pos + out_n * (rivet_height * 0.62))
		add_chamfered_prism(
			canvas, slot, head_xf, 6,
			rivet_radius, rivet_radius * 0.88, rivet_height * 0.75,
			rivet_height * 0.22, rivet_radius * 0.22,
			0.45, 0.22, 0.0, 0.0, 0.94
		)


static func add_hydraulic_pipe(
	canvas: KitbashCanvas,
	slot: String,
	p_start: Vector3,
	p_end: Vector3,
	radius: float = 0.14,
	collar_count: int = 5,
	collar_radius: float = 0.21,
	collar_span_start: float = 0.14,
	collar_span_end: float = 0.66
) -> void:
	var delta := p_end - p_start
	var length := delta.length()
	if length < 0.02:
		return
	var basis := _frame_from_dir(delta)
	var mid := (p_start + p_end) * 0.5
	add_chamfered_prism(
		canvas, slot, Transform3D(basis, mid), 12,
		radius, radius, length, minf(radius * 0.22, length * 0.08), radius * 0.16,
		0.14, 0.18, 0.0, 0.0, 0.86
	)
	add_chamfered_prism(
		canvas, slot, Transform3D(basis, p_start.lerp(p_end, 0.05)), 12,
		collar_radius * 1.16, collar_radius * 1.06, length * 0.11,
		0.025, 0.025, 0.10, 0.82, 0.0, 0.0, 0.88
	)
	var n := maxi(collar_count, 0)
	if n > 0:
		var span := maxf(collar_span_end - collar_span_start, 0.05)
		var ring_h := (length * span) / (float(n) * 1.48)
		for i in n:
			var t := collar_span_start + span * (float(i) + 0.5) / float(n)
			var c_pos := p_start.lerp(p_end, t)
			add_chamfered_prism(
				canvas, slot, Transform3D(basis, c_pos), 12,
				collar_radius, collar_radius * 0.96, ring_h,
				minf(ring_h * 0.32, 0.028), minf(collar_radius * 0.14, 0.03),
				0.18, 0.72, 0.0, 0.0, 0.90
			)


static func add_cable_catenary(
	canvas: KitbashCanvas,
	slot: String,
	p_start: Vector3,
	p_end: Vector3,
	sag: float = 0.65,
	radius: float = 0.048,
	segments: int = 14,
	radial_sides: int = 8,
	sag_dir: Vector3 = Vector3.DOWN
) -> void:
	var segs := maxi(segments, 4)
	var sides := maxi(radial_sides, 5)
	var drop := sag_dir.normalized()
	var spine: Array[Vector3] = []
	for i in range(segs + 1):
		var t := float(i) / float(segs)
		var droop := 4.0 * t * (1.0 - t) * sag
		spine.append(p_start.lerp(p_end, t) + drop * droop)

	var tangents: Array[Vector3] = []
	for i in range(segs + 1):
		var prev := spine[maxi(i - 1, 0)]
		var next := spine[mini(i + 1, segs)]
		var tan_v := (next - prev).normalized()
		if tan_v.length_squared() < 1e-8:
			tan_v = Vector3.RIGHT
		tangents.append(tan_v)

	var normals: Array[Vector3] = []
	var binormals: Array[Vector3] = []
	var ref := Vector3.UP if absf(tangents[0].dot(Vector3.UP)) < 0.9 else Vector3.FORWARD
	var n0 := ref.cross(tangents[0]).normalized()
	var b0 := tangents[0].cross(n0).normalized()
	normals.append(n0)
	binormals.append(b0)
	for i in range(1, segs + 1):
		var t_prev := tangents[i - 1]
		var t_cur := tangents[i]
		var axis := t_prev.cross(t_cur)
		var n_cur := normals[i - 1]
		if axis.length_squared() > 1e-10:
			var angle := atan2(axis.length(), clampf(t_prev.dot(t_cur), -1.0, 1.0))
			n_cur = n_cur.rotated(axis.normalized(), angle).normalized()
		n_cur = (n_cur - t_cur * n_cur.dot(t_cur)).normalized()
		var b_cur := t_cur.cross(n_cur).normalized()
		normals.append(n_cur)
		binormals.append(b_cur)

	var rings: Array = []
	var ring_cols: Array[Color] = []
	for i in range(segs + 1):
		var t := float(i) / float(segs)
		var end_grime := smoothstep(0.22, 0.0, minf(t, 1.0 - t)) * 0.78
		var belly_wear := 4.0 * t * (1.0 - t) * 0.58
		ring_cols.append(CraftLookdev.encode_mask(0.12 + belly_wear, 0.14 + end_grime, 0.0))
		var row: Array[Vector3] = []
		for j in sides:
			var ang := TAU * float(j) / float(sides)
			var offset := (normals[i] * cos(ang) + binormals[i] * sin(ang)) * radius
			row.append(spine[i] + offset)
		rings.append(row)

	for i in segs:
		for j in sides:
			var nj := (j + 1) % sides
			var p00: Vector3 = rings[i][j]
			var p01: Vector3 = rings[i][nj]
			var p11: Vector3 = rings[i + 1][nj]
			var p10: Vector3 = rings[i + 1][j]
			var out_n := ((p00 + p01 + p11 + p10) * 0.25 - (spine[i] + spine[i + 1]) * 0.5).normalized()
			canvas.add_quad(
				slot, p00, p01, p11, p10, out_n,
				ring_cols[i], ring_cols[i], ring_cols[i + 1], ring_cols[i + 1],
				(p00 - spine[i]).normalized(), (p01 - spine[i]).normalized(),
				(p11 - spine[i + 1]).normalized(), (p10 - spine[i + 1]).normalized()
			)

	for j in sides:
		var nj := (j + 1) % sides
		canvas.add_tri(slot, spine[0], rings[0][nj], rings[0][j], -tangents[0], Vector2(0.5, 0.5), Vector2(1, 0), Vector2(0, 1), ring_cols[0], ring_cols[0], ring_cols[0])
		canvas.add_tri(slot, spine[segs], rings[segs][j], rings[segs][nj], tangents[segs], Vector2(0.5, 0.5), Vector2(1, 0), Vector2(0, 1), ring_cols[segs], ring_cols[segs], ring_cols[segs])

	add_chamfered_prism(canvas, "iron_frame", Transform3D(_frame_from_dir(tangents[0]), spine[0]), 8, radius * 1.55, radius * 1.35, radius * 1.8, radius * 0.25, radius * 0.18, 0.14, 0.84, 0.0, 0.0, 0.84)
	add_chamfered_prism(canvas, "iron_frame", Transform3D(_frame_from_dir(tangents[segs]), spine[segs]), 8, radius * 1.55, radius * 1.35, radius * 1.8, radius * 0.25, radius * 0.18, 0.14, 0.84, 0.0, 0.0, 0.84)


static func add_asymmetric_patch(
	canvas: KitbashCanvas,
	slot: String,
	xform: Transform3D,
	size: Vector3,
	tilt_deg: float = 4.5,
	bolt_count: int = 6
) -> void:
	var tilted := xform * Transform3D(Basis(Vector3.BACK, deg_to_rad(tilt_deg)), Vector3.ZERO)
	add_chamfered_plate(
		canvas, "iron_frame",
		tilted * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -size.z * 0.35)),
		Vector3(size.x * 1.05, size.y * 1.05, size.z * 0.45),
		minf(size.z * 0.25, 0.018), 0.10, 0.90, 0.0, 0.42
	)
	add_chamfered_plate(
		canvas, slot,
		tilted * Transform3D(Basis.IDENTITY, Vector3(-size.x * 0.08, size.y * 0.14, 0.0)),
		Vector3(size.x * 0.86, size.y * 0.68, size.z),
		minf(size.z * 0.32, 0.032), 0.11, 0.16, 0.0, 0.92
	)
	add_chamfered_plate(
		canvas, slot,
		tilted * Transform3D(Basis.IDENTITY, Vector3(size.x * 0.16, -size.y * 0.18, size.z * 0.08)),
		Vector3(size.x * 0.64, size.y * 0.56, size.z * 0.92),
		minf(size.z * 0.30, 0.028), 0.12, 0.20, 0.0, 0.92
	)
	var out_n := (tilted.basis * Vector3.BACK).normalized()
	var z_face := size.z * 0.5
	var top_n := maxi(int(floor(float(bolt_count) * 0.5)), 2)
	var bot_n := maxi(bolt_count - top_n, 2)
	add_rivet_strip(
		canvas, "iron_frame",
		tilted * Vector3(-size.x * 0.38, size.y * 0.36, z_face),
		tilted * Vector3(size.x * 0.24, size.y * 0.36, z_face),
		out_n, top_n, minf(size.z * 0.42, 0.038), minf(size.z * 0.36, 0.032)
	)
	add_rivet_strip(
		canvas, "iron_frame",
		tilted * Vector3(-size.x * 0.12, -size.y * 0.34, z_face),
		tilted * Vector3(size.x * 0.36, -size.y * 0.34, z_face),
		out_n, bot_n, minf(size.z * 0.42, 0.038), minf(size.z * 0.36, 0.032)
	)


static func add_valve_wheel(
	canvas: KitbashCanvas,
	slot: String,
	xform: Transform3D,
	radius: float = 0.36,
	tube_radius: float = 0.042,
	spoke_count: int = 4
) -> void:
	var segs := 18
	var sides := 8
	var rings: Array = []
	var centers: Array[Vector3] = []
	for i in segs:
		var ang := TAU * float(i) / float(segs)
		var radial := Vector3(cos(ang), sin(ang), 0.0)
		var c_pt := xform * (radial * radius)
		centers.append(c_pt)
		var row: Array[Vector3] = []
		for j in sides:
			var phi := TAU * float(j) / float(sides)
			var local_off := radial * (cos(phi) * tube_radius) + Vector3(0.0, 0.0, sin(phi) * tube_radius)
			row.append(xform * (radial * radius + local_off))
		rings.append(row)

	var c_grip := CraftLookdev.encode_mask(0.92, 0.12, 0.0)
	var c_inner := CraftLookdev.encode_mask(0.32, 0.45, 0.0)
	for i in segs:
		var ni := (i + 1) % segs
		for j in sides:
			var nj := (j + 1) % sides
			var p00: Vector3 = rings[i][j]
			var p01: Vector3 = rings[i][nj]
			var p11: Vector3 = rings[ni][nj]
			var p10: Vector3 = rings[ni][j]
			var out_n := ((p00 + p01 + p11 + p10) * 0.25 - (centers[i] + centers[ni]) * 0.5).normalized()
			var c_j := c_grip if (j <= 2 or j >= sides - 2) else c_inner
			canvas.add_quad(
				slot, p00, p01, p11, p10, out_n,
				c_j, c_j, c_j, c_j,
				(p00 - centers[i]).normalized(), (p01 - centers[i]).normalized(),
				(p11 - centers[ni]).normalized(), (p10 - centers[ni]).normalized()
			)

	var spokes := maxi(spoke_count, 3)
	for k in spokes:
		var ang := TAU * float(k) / float(spokes) + PI * 0.25
		var p_a := xform * Vector3.ZERO
		var p_b := xform * (Vector3(cos(ang), sin(ang), 0.0) * (radius - tube_radius * 0.5))
		add_truss_rib(canvas, slot, p_a, p_b, tube_radius * 1.15, tube_radius * 0.28)

	var stem_basis := xform.basis * Basis(Vector3.RIGHT, PI * 0.5)
	add_chamfered_prism(
		canvas, "iron_frame", Transform3D(stem_basis, xform * Vector3(0.0, 0.0, 0.03)), 6,
		tube_radius * 2.1, tube_radius * 1.75, tube_radius * 2.2,
		0.015, 0.015, 0.30, 0.35, 0.0, 0.0, 0.94
	)
	add_chamfered_prism(
		canvas, "iron_frame", Transform3D(stem_basis, xform * Vector3(0.0, 0.0, -radius * 0.36)), 10,
		tube_radius * 1.65, tube_radius * 2.35, radius * 0.65,
		0.025, 0.025, 0.12, 0.84, 0.0, 0.0, 0.82
	)


static func add_coil_winding(
	canvas: KitbashCanvas,
	slot: String,
	xform: Transform3D,
	radius: float = 0.24,
	height: float = 0.92,
	turns: int = 8,
	wire_radius: float = 0.042
) -> void:
	add_chamfered_prism(
		canvas, "iron_frame", xform, 10,
		radius * 0.84, radius * 0.84, height,
		0.02, 0.02, 0.10, 0.88, 0.0, 0.0, 0.40
	)
	for s: float in [-1.0, 1.0]:
		add_chamfered_prism(
			canvas, "iron_frame",
			xform * Transform3D(Basis.IDENTITY, Vector3(0.0, s * (height * 0.5 - 0.045), 0.0)),
			10, radius * 1.08, radius * 1.08, 0.09,
			0.02, 0.02, 0.14, 0.72, 0.0, 0.0, 0.86
		)
	var n_turns := maxi(turns, 3)
	var usable_h := maxf(height - 0.18, 0.12)
	var step := usable_h / float(n_turns)
	var ring_h := minf(wire_radius * 1.72, step * 0.82)
	for i in n_turns:
		var y := -usable_h * 0.5 + (float(i) + 0.5) * step
		add_chamfered_prism(
			canvas, slot,
			xform * Transform3D(Basis.IDENTITY, Vector3(0.0, y, 0.0)),
			12, radius, radius * 0.98, ring_h,
			ring_h * 0.34, minf(wire_radius * 0.42, radius * 0.18),
			0.22, 0.72, 0.0, 0.0, 0.88
		)


static func add_service_ladder(
	canvas: KitbashCanvas,
	slot: String,
	p_bottom: Vector3,
	p_top: Vector3,
	outward_normal: Vector3,
	width: float = 0.38,
	rung_count: int = 5
) -> void:
	var up := (p_top - p_bottom).normalized()
	var out_n := outward_normal.normalized()
	var right := up.cross(out_n).normalized()
	var half_w := width * 0.5
	var offset := out_n * 0.11
	for s: float in [-1.0, 1.0]:
		var rail_bot := p_bottom + right * (s * half_w) + offset
		var rail_top := p_top + right * (s * half_w) + offset
		add_truss_rib(canvas, slot, rail_bot, rail_top, 0.036, 0.009)
		add_truss_rib(canvas, slot, p_bottom + right * (s * half_w), rail_bot, 0.034, 0.008)
		add_truss_rib(canvas, slot, p_top + right * (s * half_w), rail_top, 0.034, 0.008)
	var n := maxi(rung_count, 2)
	for i in n:
		var t := (float(i) + 0.5) / float(n)
		var c := p_bottom.lerp(p_top, t) + offset
		var rung_xf := Transform3D(_frame_from_dir(right), c)
		add_chamfered_prism(
			canvas, slot, rung_xf, 8,
			0.022, 0.022, width, 0.008, 0.006,
			0.58, 0.22, 0.0, 0.0, 0.94
		)



static func build_em_crane_gantry() -> ArrayMesh:
	var c := create_canvas()
	var oct_phase := PI / 8.0

	add_chamfered_prism(
		c, "iron_frame", Transform3D(Basis.IDENTITY, Vector3(0.0, 0.17, 0.0)),
		8, 1.36, 1.48, 0.34, 0.07, 0.07, 0.10, 0.26, 0.0, oct_phase, 0.90
	)
	add_chamfered_prism(
		c, "hull_plating", Transform3D(Basis.IDENTITY, Vector3(0.0, 0.36, 0.0)),
		8, 1.42, 1.32, 0.10, 0.025, 0.03, 0.12, 0.72, 0.0, oct_phase, 0.86
	)
	for i in 8:
		var ang := oct_phase + TAU * float(i) / 8.0
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		var cleat_xf := Transform3D(Basis(Vector3.UP, -ang), dir * 1.41 + Vector3(0.0, 0.20, 0.0))
		add_chamfered_plate(c, "iron_frame", cleat_xf, Vector3(0.18, 0.26, 0.20), 0.028, 0.12, 0.42)

	add_chamfered_prism(
		c, "emissive_core", Transform3D(Basis.IDENTITY, Vector3(0.0, 0.88, 0.0)),
		12, 0.56, 0.56, 0.94, 0.05, 0.05, 0.20, 0.05, 1.0, 0.0, 0.35
	)
	for ring_y: float in [0.64, 0.88, 1.12]:
		add_chamfered_prism(
			c, "iron_frame", Transform3D(Basis.IDENTITY, Vector3(0.0, ring_y, 0.0)),
			12, 0.63, 0.63, 0.06, 0.015, 0.015, 0.14, 0.78, 0.0, 0.0, 0.86
		)

	for i in 6:
		var ang := TAU * float(i) / 6.0 + PI / 6.0
		var pos := Vector3(cos(ang) * 0.96, 0.88, sin(ang) * 0.96)
		add_coil_winding(c, "copper_coil", Transform3D(Basis.IDENTITY, pos), 0.24, 0.96, 8, 0.044)
	for i in 8:
		var ang := oct_phase + TAU * float(i) / 8.0
		var p_bot := Vector3(cos(ang) * 1.32, 0.36, sin(ang) * 1.32)
		var p_top := Vector3(cos(ang) * 1.38, 1.40, sin(ang) * 1.38)
		add_truss_rib(c, "iron_frame", p_bot, p_top, 0.095, 0.022)

	add_chamfered_prism(
		c, "hull_plating", Transform3D(Basis.IDENTITY, Vector3(0.0, 1.66, 0.0)),
		8, 1.56, 1.58, 0.60, 0.07, 0.065, 0.09, 0.14, 0.0, oct_phase, 0.90
	)
	add_chamfered_prism(
		c, "iron_frame", Transform3D(Basis.IDENTITY, Vector3(0.0, 1.98, 0.0)),
		8, 1.52, 1.50, 0.10, 0.02, 0.02, 0.10, 0.86, 0.0, oct_phase, 0.65
	)
	add_chamfered_prism(
		c, "hull_plating", Transform3D(Basis.IDENTITY, Vector3(0.0, 2.38, 0.0)),
		8, 1.56, 0.94, 0.76, 0.065, 0.065, 0.09, 0.12, 0.0, oct_phase, 0.90
	)
	var slope_angle := atan2(1.56 - 0.94, 0.76)
	for i in 8:
		var face_ang := TAU * float(i) / 8.0
		var normal_h := Vector3(cos(face_ang), 0.0, sin(face_ang))
		var face_rot := Basis(Vector3.UP, -face_ang + PI * 0.5) * Basis(Vector3.RIGHT, -slope_angle)
		var vent_pos := normal_h * 1.18 + Vector3(0.0, 2.39, 0.0)
		add_louver_vent(c, "iron_frame", Transform3D(face_rot, vent_pos), 0.68, 0.48, 0.12, 4, false)
		var rib_ang := face_ang + oct_phase
		var rib_dir := Vector3(cos(rib_ang), 0.0, sin(rib_ang))
		var rib_xf := Transform3D(Basis(Vector3.UP, -rib_ang), rib_dir * 1.54 + Vector3(0.0, 1.66, 0.0))
		add_chamfered_plate(c, "iron_frame", rib_xf, Vector3(0.14, 0.62, 0.14), 0.025, 0.11, 0.36)

	add_chamfered_prism(
		c, "hull_plating", Transform3D(Basis.IDENTITY, Vector3(0.0, 2.90, 0.0)),
		8, 0.86, 0.78, 0.32, 0.05, 0.05, 0.10, 0.18, 0.0, oct_phase, 0.90
	)
	for i in 8:
		var ang := TAU * float(i) / 8.0
		var p := Vector3(cos(ang) * 0.66, 3.06, sin(ang) * 0.66)
		add_rivet_strip(c, "iron_frame", p, p, Vector3.UP, 1, 0.044, 0.036)

	add_hydraulic_pipe(c, "iron_frame", Vector3(0.0, 3.02, 0.0), Vector3(0.0, 3.88, 0.0), 0.22, 3, 0.33, 0.16, 0.56)
	add_chamfered_plate(c, "hull_plating", Transform3D(Basis.IDENTITY, Vector3(0.0, 3.92, 0.0)), Vector3(1.18, 0.24, 1.12), 0.04, 0.10, 0.24)
	for sz: float in [-0.46, 0.46]:
		add_chamfered_plate(c, "iron_frame", Transform3D(Basis.IDENTITY, Vector3(0.0, 3.68, sz)), Vector3(0.76, 0.42, 0.12), 0.025, 0.11, 0.38)
		add_rivet_strip(
			c, "iron_frame",
			Vector3(-0.26, 3.68, sz + signf(sz) * 0.06), Vector3(0.26, 3.68, sz + signf(sz) * 0.06),
			Vector3(0.0, 0.0, signf(sz)), 3, 0.036, 0.028
		)

	var bays := 6
	var x_nose := -1.65
	var x_tail := 5.45
	var y_bot := 4.06
	var y_top := 5.22
	var z_bot := 0.56
	var z_top := 0.34

	var b_l: Array[Vector3] = []
	var b_r: Array[Vector3] = []
	var t_l: Array[Vector3] = []
	var t_r: Array[Vector3] = []
	for i in range(bays + 1):
		var frac := float(i) / float(bays)
		var x := lerpf(x_nose, x_tail, frac)
		var nose_taper := 0.58 if i == 0 else 1.0
		var y_t := lerpf(y_bot + 0.62, y_top, 0.0 if i == 0 else 1.0)
		b_l.append(Vector3(x, y_bot, -z_bot * nose_taper))
		b_r.append(Vector3(x, y_bot, z_bot * nose_taper))
		t_l.append(Vector3(x, y_t, -z_top * nose_taper))
		t_r.append(Vector3(x, y_t, z_top * nose_taper))

	for i in bays:
		add_truss_rib(c, "hull_plating", b_l[i], b_l[i + 1], 0.13, 0.032)
		add_truss_rib(c, "hull_plating", b_r[i], b_r[i + 1], 0.13, 0.032)
		add_truss_rib(c, "hull_plating", t_l[i], t_l[i + 1], 0.12, 0.030)
		add_truss_rib(c, "hull_plating", t_r[i], t_r[i + 1], 0.12, 0.030)

	for i in range(bays + 1):
		add_truss_rib(c, "iron_frame", b_l[i], b_r[i], 0.095, 0.022)
		add_truss_rib(c, "iron_frame", t_l[i], t_r[i], 0.090, 0.022)
		add_truss_rib(c, "iron_frame", b_l[i], t_l[i], 0.095, 0.022)
		add_truss_rib(c, "iron_frame", b_r[i], t_r[i], 0.095, 0.022)
		if i < bays:
			var even := (i % 2 == 0)
			add_truss_rib(c, "iron_frame", b_l[i] if even else t_l[i], t_l[i + 1] if even else b_l[i + 1], 0.082, 0.018)
			add_truss_rib(c, "iron_frame", b_r[i] if even else t_r[i], t_r[i + 1] if even else b_r[i + 1], 0.082, 0.018)
			add_truss_rib(c, "iron_frame", t_l[i] if even else t_r[i], t_r[i + 1] if even else t_l[i + 1], 0.075, 0.016)
			add_truss_rib(c, "iron_frame", b_l[i] if even else b_r[i], b_r[i + 1] if even else b_l[i + 1], 0.075, 0.016)

	add_chamfered_plate(
		c, "hull_plating",
		Transform3D(Basis(Vector3.BACK, deg_to_rad(-16.0)), Vector3(x_nose - 0.12, y_bot + 0.34, 0.0)),
		Vector3(0.24, 0.72, 0.72), 0.045, 0.10, 0.08
	)
	add_chamfered_plate(c, "iron_frame", Transform3D(Basis.IDENTITY, Vector3(x_tail + 0.08, y_bot, 0.0)), Vector3(0.18, 0.18, z_bot * 2.0 + 0.18), 0.032, 0.10, 0.36)
	add_chamfered_plate(c, "iron_frame", Transform3D(Basis.IDENTITY, Vector3(x_tail + 0.08, y_top, 0.0)), Vector3(0.18, 0.18, z_top * 2.0 + 0.18), 0.032, 0.10, 0.36)
	add_truss_rib(c, "iron_frame", Vector3(x_tail + 0.08, y_bot, -z_bot), Vector3(x_tail + 0.08, y_top, -z_top), 0.14, 0.03)
	add_truss_rib(c, "iron_frame", Vector3(x_tail + 0.08, y_bot, z_bot), Vector3(x_tail + 0.08, y_top, z_top), 0.14, 0.03)
	add_rivet_strip(c, "iron_frame", Vector3(x_tail + 0.17, y_bot, -0.46), Vector3(x_tail + 0.17, y_bot, 0.46), Vector3.RIGHT, 4, 0.038, 0.028)
	add_rivet_strip(c, "iron_frame", Vector3(x_tail + 0.17, y_top, -0.26), Vector3(x_tail + 0.17, y_top, 0.26), Vector3.RIGHT, 3, 0.038, 0.028)

	var patch_side_xf := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-10.0)), Vector3(1.92, 4.68, 0.48))
	add_asymmetric_patch(c, "patch_oxide", patch_side_xf, Vector3(1.32, 0.96, 0.10), -5.0, 6)
	var patch_top_xf := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(1.92, 5.28, 0.04))
	add_asymmetric_patch(c, "patch_oxide", patch_top_xf, Vector3(1.18, 0.82, 0.09), 3.0, 4)

	add_cable_catenary(c, "cable_rubber", Vector3(0.32, 3.65, 0.26), Vector3(3.15, 4.08, 0.40), 0.98, 0.056, 16, 8)
	add_cable_catenary(c, "cable_rubber", Vector3(0.28, 3.55, -0.24), Vector3(4.35, 4.08, -0.34), 1.32, 0.052, 16, 8)
	add_cable_catenary(c, "cable_rubber", Vector3(1.45, 4.10, 0.48), Vector3(4.95, 4.10, 0.44), 1.15, 0.044, 14, 8)
	add_cable_catenary(c, "cable_rubber", Vector3(3.65, 4.06, 0.22), Vector3(3.45, 2.28, 0.28), 0.14, 0.042, 10, 7, Vector3(0.35, -0.9, 0.25))
	add_chamfered_prism(c, "copper_coil", Transform3D(Basis.IDENTITY, Vector3(3.45, 2.18, 0.28)), 6, 0.055, 0.025, 0.16, 0.02, 0.012, 0.45, 0.20, 0.0, 0.0, 0.90)

	add_service_ladder(
		c, "iron_frame",
		Vector3(1.12, 0.42, 1.06), Vector3(1.12, 1.72, 1.06),
		Vector3(1.0, 0.0, 1.0).normalized(), 0.36, 4
	)
	add_chamfered_plate(
		c, "iron_frame",
		Transform3D(Basis(Vector3.UP, PI * 0.25), Vector3(1.12, 1.88, 1.06)),
		Vector3(0.46, 0.14, 0.22), 0.025, 0.12, 0.42
	)

	return c.commit({
		"hero_id": HERO_EM_CRANE,
		"pivot_top": Vector3(5.45, 4.65, 0.0),
		"scale_cue": "service_rungs_0.36m",
	})



static func build_salvage_press_beacon() -> ArrayMesh:
	var c := create_canvas()
	var oct_phase := PI / 8.0

	add_chamfered_prism(
		c, "concrete_plinth", Transform3D(Basis.IDENTITY, Vector3(0.0, 0.24, 0.0)),
		8, 2.22, 2.08, 0.48, 0.075, 0.08, 0.09, 0.24, 0.0, oct_phase, 0.86
	)
	add_chamfered_prism(
		c, "hull_plating", Transform3D(Basis.IDENTITY, Vector3(0.0, 0.68, 0.0)),
		8, 1.88, 1.66, 0.46, 0.07, 0.07, 0.09, 0.16, 0.0, oct_phase, 0.90
	)

	for i in 4:
		var ang := PI * 0.25 + PI * 0.5 * float(i)
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		var rot := Basis(Vector3.UP, -ang)
		add_chamfered_plate(c, "concrete_plinth", Transform3D(rot, dir * 1.68 + Vector3(0.0, 0.30, 0.0)), Vector3(1.16, 0.60, 0.86), 0.07, 0.09, 0.28)
		var slope_rot := rot * Basis(Vector3.BACK, deg_to_rad(26.0))
		add_chamfered_plate(c, "hull_plating", Transform3D(slope_rot, dir * 1.46 + Vector3(0.0, 0.98, 0.0)), Vector3(0.78, 1.24, 0.68), 0.065, 0.10, 0.18)
		var toe_p0 := dir * 2.18 + (rot * Vector3(0.0, 0.60, -0.26))
		var toe_p1 := dir * 2.18 + (rot * Vector3(0.0, 0.60, 0.26))
		add_rivet_strip(c, "iron_frame", toe_p0, toe_p1, Vector3.UP, 3, 0.044, 0.036)

	add_chamfered_plate(
		c, "hull_plating", Transform3D(Basis.IDENTITY, Vector3(0.0, 1.76, 0.0)),
		Vector3(2.58, 1.74, 2.38), 0.16, 0.09, 0.12, 0.0, 0.92
	)
	for sx: float in [-1.0, 1.0]:
		add_chamfered_plate(
			c, "hull_plating", Transform3D(Basis.IDENTITY, Vector3(sx * 1.28, 1.64, 0.0)),
			Vector3(0.56, 1.44, 1.72), 0.09, 0.10, 0.16, 0.0, 0.90
		)
		var pocket_rot := Basis(Vector3.UP, sx * PI * 0.5)
		add_recessed_seam(
			c, "iron_frame",
			Transform3D(pocket_rot, Vector3(sx * 1.54, 1.48, -0.28)),
			0.78, 0.92, 0.16, 0.09, 0.88
		)

	add_recessed_seam(
		c, "iron_frame",
		Transform3D(Basis.IDENTITY, Vector3(0.0, 1.62, 1.18)),
		1.06, 1.12, 0.24, 0.12, 0.86
	)
	add_chamfered_prism(
		c, "emissive_core", Transform3D(Basis.IDENTITY, Vector3(0.0, 1.62, 1.04)),
		10, 0.38, 0.38, 0.90, 0.04, 0.04, 0.18, 0.04, 1.0, 0.0, 0.30
	)
	for sx: float in [-0.34, 0.34]:
		add_truss_rib(c, "iron_frame", Vector3(sx, 1.12, 1.26), Vector3(sx, 2.12, 1.26), 0.068, 0.016)

	add_chamfered_prism(
		c, "copper_coil", Transform3D(Basis.IDENTITY, Vector3(0.0, 2.26, 0.92)),
		12, 0.82, 0.78, 0.24, 0.04, 0.04, 0.12, 0.24, 0.0, 0.0, 0.92
	)
	for k in 7:
		var ang := lerpf(0.20, PI - 0.20, float(k) / 6.0)
		var out_v := Vector3(cos(ang), 0.0, sin(ang))
		var r_pos := Vector3(0.0, 2.26, 0.92) + out_v * 0.80
		add_rivet_strip(c, "iron_frame", r_pos, r_pos, out_v, 1, 0.046, 0.038)

	var well_segs := 12
	var well_r := 0.84
	for i in well_segs:
		var ang := TAU * float(i) / float(well_segs)
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		var seg_rot := Basis(Vector3.UP, -ang + PI * 0.5)
		add_chamfered_plate(
			c, "iron_frame",
			Transform3D(seg_rot, dir * well_r + Vector3(0.0, 2.74, 0.0)),
			Vector3(0.50, 0.28, 0.24), 0.042, 0.11, 0.24, 0.0, 0.90
		)
	add_chamfered_prism(
		c, "emissive_core", Transform3D(Basis.IDENTITY, Vector3(0.0, 2.66, 0.0)),
		12, 0.72, 0.72, 0.18, 0.025, 0.025, 0.20, 0.04, 1.0, 0.0, 0.32
	)

	var vent_rot := Basis(Vector3.UP, deg_to_rad(-90.0)) * Basis(Vector3.RIGHT, deg_to_rad(-76.0))
	add_louver_vent(c, "iron_frame", Transform3D(vent_rot, Vector3(-1.14, 2.58, 0.44)), 0.72, 0.56, 0.10, 6, false)

	var left_base := Vector3(-0.98, 2.60, -0.34)
	var left_top := Vector3(-0.98, 5.16, -0.34)
	add_hydraulic_pipe(c, "iron_frame", left_base, left_top, 0.17, 7, 0.31, 0.08, 0.60)
	add_chamfered_prism(
		c, "hull_plating", Transform3D(Basis.IDENTITY, Vector3(-0.98, 5.24, -0.34)),
		6, 0.34, 0.30, 0.42, 0.065, 0.06, 0.12, 0.14, 0.0, 0.0, 0.94
	)

	var right_base := Vector3(0.92, 2.60, -0.22)
	var right_top := Vector3(0.92, 4.78, -0.22)
	add_hydraulic_pipe(c, "iron_frame", right_base, right_top, 0.18, 6, 0.33, 0.08, 0.56)
	add_chamfered_plate(c, "hull_plating", Transform3D(Basis.IDENTITY, Vector3(0.92, 4.98, -0.58)), Vector3(0.74, 0.54, 1.38), 0.085, 0.10, 0.14, 0.0, 0.92)
	add_chamfered_plate(
		c, "hull_plating",
		Transform3D(Basis(Vector3.RIGHT, deg_to_rad(10.0)), Vector3(0.92, 3.74, -1.12)),
		Vector3(0.70, 2.38, 0.68), 0.085, 0.10, 0.18, 0.0, 0.90
	)
	add_recessed_seam(
		c, "iron_frame",
		Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(1.25, 3.84, -1.06)),
		0.46, 1.38, 0.12, 0.08, 0.88
	)
	add_rivet_strip(c, "iron_frame", Vector3(1.29, 4.98, -0.38), Vector3(1.29, 4.98, -0.86), Vector3.RIGHT, 2, 0.065, 0.052)

	var wheel_xf := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(1.80, 1.54, 0.56))
	add_valve_wheel(c, "patch_oxide", wheel_xf, 0.36, 0.044, 4)

	add_asymmetric_patch(
		c, "patch_oxide",
		Transform3D(Basis(Vector3.UP, PI), Vector3(-0.32, 1.66, -1.24)),
		Vector3(1.18, 0.86, 0.10), 4.0, 6
	)
	add_cable_catenary(c, "cable_rubber", Vector3(-1.32, 1.38, -0.82), Vector3(0.58, 2.75, -1.24), 0.42, 0.048, 12, 7)

	return c.commit({
		"hero_id": HERO_SALVAGE_PRESS,
		"core_anchor": Vector3(0.0, 2.72, 0.0),
		"scale_cue": "service_valve_wheel_0.72m",
	})



static func build_conduit_pylon() -> ArrayMesh:
	var c := create_canvas()
	var oct_phase := PI / 8.0

	add_chamfered_prism(
		c, "concrete_plinth", Transform3D(Basis.IDENTITY, Vector3(0.0, 0.22, 0.0)),
		8, 1.48, 1.36, 0.44, 0.065, 0.07, 0.09, 0.28, 0.0, oct_phase, 0.86
	)
	add_chamfered_prism(
		c, "iron_frame", Transform3D(Basis.IDENTITY, Vector3(0.0, 1.65, 0.0)),
		8, 0.96, 0.82, 2.50, 0.06, 0.05, 0.10, 0.26, 0.0, oct_phase, 0.84
	)
	add_chamfered_prism(
		c, "iron_frame", Transform3D(Basis.IDENTITY, Vector3(0.0, 4.15, 0.0)),
		8, 0.78, 0.64, 2.65, 0.06, 0.05, 0.10, 0.20, 0.0, oct_phase, 0.86
	)

	for i in 4:
		var ang := PI * 0.25 + PI * 0.5 * float(i)
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		var rot := Basis(Vector3.UP, -ang)
		add_chamfered_plate(c, "hull_plating", Transform3D(rot, dir * 1.18 + Vector3(0.0, 0.34, 0.0)), Vector3(0.76, 0.68, 0.46), 0.055, 0.09, 0.26)
		var slope_rot := rot * Basis(Vector3.BACK, deg_to_rad(18.0))
		add_chamfered_plate(c, "hull_plating", Transform3D(slope_rot, dir * 0.98 + Vector3(0.0, 1.24, 0.0)), Vector3(0.52, 1.54, 0.44), 0.055, 0.09, 0.18)
		add_chamfered_plate(c, "hull_plating", Transform3D(rot, dir * 0.82 + Vector3(0.0, 2.92, 0.0)), Vector3(0.46, 1.98, 0.42), 0.055, 0.09, 0.14)
		add_chamfered_plate(c, "hull_plating", Transform3D(rot, dir * 0.66 + Vector3(0.0, 4.62, 0.0)), Vector3(0.38, 1.62, 0.34), 0.05, 0.10, 0.12)
		var r_bot := dir * 1.05 + Vector3(0.0, 2.15, 0.0)
		var r_top := dir * 1.05 + Vector3(0.0, 3.68, 0.0)
		add_rivet_strip(c, "iron_frame", r_bot, r_top, dir, 5, 0.034, 0.026)

	for i in 4:
		var ang := PI * 0.5 * float(i)
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		var rot := Basis(Vector3.UP, -ang + PI * 0.5)
		add_recessed_seam(
			c, "iron_frame",
			Transform3D(rot, dir * 0.84 + Vector3(0.0, 1.88, 0.0)),
			0.44, 1.72, 0.18, 0.08, 0.90
		)
		add_chamfered_prism(
			c, "emissive_core",
			Transform3D(rot, dir * 0.88 + Vector3(0.0, 1.88, 0.0)),
			8, 0.11, 0.11, 1.56, 0.025, 0.02, 0.18, 0.04, 1.0, 0.0, 0.30
		)
		var knee_rot := rot * Basis(Vector3.RIGHT, deg_to_rad(-28.0))
		add_recessed_seam(
			c, "iron_frame",
			Transform3D(knee_rot, dir * 1.01 + Vector3(0.0, 0.80, 0.0)),
			0.42, 0.82, 0.16, 0.075, 0.90
		)
		add_chamfered_prism(
			c, "emissive_core",
			Transform3D(knee_rot, dir * 1.05 + Vector3(0.0, 0.80, 0.0)),
			8, 0.10, 0.10, 0.68, 0.025, 0.02, 0.18, 0.04, 1.0, 0.0, 0.30
		)
		add_chamfered_plate(
			c, "iron_frame", Transform3D(rot, dir * 1.22 + Vector3(0.0, 0.44, 0.0)),
			Vector3(0.46, 0.24, 0.34), 0.035, 0.10, 0.68
		)
		for cy: float in [1.14, 2.54]:
			add_chamfered_plate(
				c, "iron_frame", Transform3D(rot, dir * 0.94 + Vector3(0.0, cy, 0.0)),
				Vector3(0.42, 0.12, 0.22), 0.024, 0.12, 0.48
			)

	for band_y: float in [2.88, 3.32, 3.74]:
		add_chamfered_prism(
			c, "iron_frame", Transform3D(Basis.IDENTITY, Vector3(0.0, band_y, 0.0)),
			8, 0.94, 0.92, 0.18, 0.03, 0.03, 0.12, 0.68, 0.0, oct_phase, 0.88
		)

	for i in 4:
		var ang := PI * 0.5 * float(i)
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		var rot := Basis(Vector3.UP, -ang + PI * 0.5)
		for f in 6:
			var fy := 4.02 + float(f) * 0.22
			var taper := 1.0 - float(f) * 0.035
			add_chamfered_plate(
				c, "copper_coil", Transform3D(rot, dir * (0.76 * taper) + Vector3(0.0, fy, 0.0)),
				Vector3(0.58 * taper, 0.115, 0.42 * taper), 0.026,
				0.14, 0.68, 0.0, 0.90
			)

	var crown_y := 5.75
	var crown_h := 0.86
	var half_span := 0.48
	var wall_t := 0.16
	for i in 4:
		var ang := PI * 0.5 * float(i)
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		var rot := Basis(Vector3.UP, -ang + PI * 0.5)
		add_chamfered_plate(
			c, "hull_plating", Transform3D(rot, dir * half_span + Vector3(0.0, crown_y, 0.0)),
			Vector3(half_span * 1.72, crown_h, wall_t), 0.04, 0.10, 0.24, 0.0, 0.92
		)
		var c_ang := ang + PI * 0.25
		var c_dir := Vector3(cos(c_ang), 0.0, sin(c_ang))
		add_chamfered_plate(
			c, "iron_frame", Transform3D(Basis(Vector3.UP, -c_ang), c_dir * (half_span * 1.24) + Vector3(0.0, crown_y, 0.0)),
			Vector3(0.22, crown_h + 0.04, 0.22), 0.038, 0.12, 0.34, 0.0, 0.92
		)
	add_chamfered_prism(
		c, "iron_frame", Transform3D(Basis.IDENTITY, Vector3(0.0, 5.42, 0.0)),
		8, 0.42, 0.42, 0.16, 0.02, 0.02, 0.06, 0.95, 0.0, oct_phase, 0.22
	)

	var jbox_xf := Transform3D(Basis(Vector3.UP, deg_to_rad(32.0)), Vector3(0.92, 3.44, 0.54))
	add_chamfered_plate(c, "iron_frame", jbox_xf, Vector3(0.76, 0.92, 0.46), 0.055, 0.10, 0.22, 0.0, 0.90)
	add_recessed_seam(c, "hull_plating", jbox_xf * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 0.22)), 0.62, 0.78, 0.08, 0.065, 0.86)
	var j_out := (jbox_xf.basis * Vector3.BACK).normalized()
	add_rivet_strip(c, "iron_frame", jbox_xf * Vector3(-0.24, 0.30, 0.26), jbox_xf * Vector3(0.24, 0.30, 0.26), j_out, 2, 0.036, 0.030)
	add_rivet_strip(c, "iron_frame", jbox_xf * Vector3(-0.24, -0.30, 0.26), jbox_xf * Vector3(0.24, -0.30, 0.26), j_out, 2, 0.036, 0.030)
	add_asymmetric_patch(
		c, "patch_oxide",
		Transform3D(Basis(Vector3.UP, deg_to_rad(-145.0)), Vector3(-0.84, 3.24, -0.58)),
		Vector3(0.72, 0.64, 0.08), -4.0, 4
	)

	for sx: float in [-1.0, 1.0]:
		var horn_root := Vector3(sx * 0.88, 3.12, 0.0)
		var horn_tip := Vector3(sx * 2.18, 3.62, 0.08 * sx)
		add_truss_rib(c, "iron_frame", horn_root, horn_tip, 0.10, 0.025)
		add_truss_rib(c, "iron_frame", Vector3(sx * 0.92, 2.52, 0.0), Vector3(sx * 1.72, 3.44, 0.05 * sx), 0.075, 0.018)
		add_chamfered_prism(c, "copper_coil", Transform3D(Basis.IDENTITY, horn_tip + Vector3(0.0, 0.08, 0.0)), 8, 0.11, 0.08, 0.22, 0.03, 0.025, 0.20, 0.35, 0.0, 0.0, 0.88)
		add_cable_catenary(c, "cable_rubber", Vector3(sx * 0.92, 2.86, 0.24), horn_tip + Vector3(0.0, -0.02, 0.08), 0.82, 0.054, 16, 8)
		add_cable_catenary(c, "cable_rubber", Vector3(sx * 0.92, 2.68, -0.18), horn_tip + Vector3(-sx * 0.16, -0.06, -0.08), 1.08, 0.048, 16, 8)
		add_cable_catenary(c, "cable_rubber", Vector3(sx * 0.94, 3.26, 0.12), horn_tip + Vector3(-sx * 0.34, -0.10, 0.0), 0.62, 0.042, 14, 7)

	add_service_ladder(
		c, "iron_frame",
		Vector3(-0.74, 0.62, 0.74), Vector3(-0.74, 2.98, 0.74),
		Vector3(-1.0, 0.0, 1.0).normalized(), 0.36, 7
	)

	return c.commit({
		"hero_id": HERO_CONDUIT_PYLON,
		"vent_top": Vector3(0.0, 6.18, 0.0),
		"scale_cue": "service_rungs_0.36m",
	})


static func build_hero(hero_id: StringName) -> ArrayMesh:
	match hero_id:
		HERO_EM_CRANE:
			return build_em_crane_gantry()
		HERO_SALVAGE_PRESS:
			return build_salvage_press_beacon()
		HERO_CONDUIT_PYLON:
			return build_conduit_pylon()
	push_error("HeroKitbashSculptor: unknown hero_id '%s'" % String(hero_id))
	return ArrayMesh.new()


static func inspect_mesh_stats(mesh: ArrayMesh) -> Dictionary:
	var surfaces: Array[String] = []
	var vertex_count := 0
	var triangle_count := 0
	var finite_verts := true
	var finite_unit_normals := true
	var valid_uvs := true
	var valid_tangents := true
	var outward_aligned := 0
	var checked_tris := 0
	var r_low := 0
	var r_high := 0
	var g_low := 0
	var g_high := 0
	var b_zero := 0
	var b_high := 0
	var a_min := 1.0
	var r_min := 1.0
	var r_max := 0.0
	var g_min := 1.0
	var g_max := 0.0
	var b_min := 1.0
	var b_max := 0.0

	for s in mesh.get_surface_count():
		surfaces.append(mesh.surface_get_name(s))
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]

		var n_v := verts.size()
		vertex_count += n_v
		if norms.size() != n_v or uvs.size() != n_v or cols.size() != n_v:
			finite_unit_normals = false
			valid_uvs = false
		if tangents.size() != n_v * 4:
			valid_tangents = false
		else:
			for t_val in tangents:
				if not is_finite(t_val):
					valid_tangents = false
					break

		for i in n_v:
			var v := verts[i]
			if not v.is_finite():
				finite_verts = false
			if i < norms.size():
				var n := norms[i]
				if not n.is_finite() or absf(n.length() - 1.0) > 0.025:
					finite_unit_normals = false
			if i < uvs.size():
				if not uvs[i].is_finite():
					valid_uvs = false
			if i < cols.size():
				var col := cols[i]
				r_min = minf(r_min, col.r)
				r_max = maxf(r_max, col.r)
				g_min = minf(g_min, col.g)
				g_max = maxf(g_max, col.g)
				b_min = minf(b_min, col.b)
				b_max = maxf(b_max, col.b)
				a_min = minf(a_min, col.a)
				if col.r <= 0.20:
					r_low += 1
				if col.r >= 0.72:
					r_high += 1
				if col.g <= 0.22:
					g_low += 1
				if col.g >= 0.65:
					g_high += 1
				if col.b <= 0.01:
					b_zero += 1
				if col.b >= 0.90:
					b_high += 1

		var tri_n := int(floor(float(indices.size()) / 3.0)) if indices.size() > 0 else int(floor(float(n_v) / 3.0))
		triangle_count += tri_n
		for ti in tri_n:
			var i0 := indices[ti * 3] if indices.size() > 0 else ti * 3
			var i1 := indices[ti * 3 + 1] if indices.size() > 0 else ti * 3 + 1
			var i2 := indices[ti * 3 + 2] if indices.size() > 0 else ti * 3 + 2
			var geo := (verts[i2] - verts[i0]).cross(verts[i1] - verts[i0])
			if geo.length_squared() < 1e-12:
				continue
			var avg_n := (norms[i0] + norms[i1] + norms[i2]).normalized()
			checked_tris += 1
			if geo.dot(avg_n) > 0.0:
				outward_aligned += 1

	var vf := maxf(float(vertex_count), 1.0)
	return {
		"surface_count": mesh.get_surface_count(),
		"surfaces": surfaces,
		"vertex_count": vertex_count,
		"triangle_count": triangle_count,
		"aabb": mesh.get_aabb(),
		"finite_verts": finite_verts,
		"finite_unit_normals": finite_unit_normals,
		"valid_uvs": valid_uvs,
		"valid_tangents": valid_tangents,
		"outward_ratio": float(outward_aligned) / maxf(float(checked_tris), 1.0),
		"r_range": Vector2(r_min, r_max),
		"g_range": Vector2(g_min, g_max),
		"b_range": Vector2(b_min, b_max),
		"a_min": a_min,
		"r_low_ratio": float(r_low) / vf,
		"r_high_ratio": float(r_high) / vf,
		"g_low_ratio": float(g_low) / vf,
		"g_high_ratio": float(g_high) / vf,
		"b_zero_ratio": float(b_zero) / vf,
		"b_high_ratio": float(b_high) / vf,
	}
