extends RefCounted

const Palette := preload("res://src/core/palette.gd")


const TIER_MIN := 1
const TIER_MAX := 5
const TRIANGLE_BUDGET := 3000
const SHARD_TRIANGLE_BUDGET := 100
const SHARD_MAX_M := 0.5

const FAMILIES := ["wood", "scrap", "masonry", "steel"]
const FAMILY_BY_TIER := {1: "wood", 2: "scrap", 3: "masonry", 4: "steel", 5: "steel"}
const SFX_PREFIX := "destructible_"

const CONCRETE := Color("9a8f7c")
const SEAM := Palette.CHARCOAL

const FORBIDDEN := {
	"HAZARD": Palette.HAZARD, "ANCIENT": Palette.ANCIENT, "MINT": Palette.ARC, "AMBER": Palette.AMBER,
	"STEEL": Palette.STEEL, "REDJAW_ASH": Palette.REDJAW_ASH, "BRASS": Palette.BRASS, "COPPER": Palette.COPPER,
}
const MIN_FORBIDDEN_DISTANCE := 0.12


static func seam_count(tier: int) -> int:
	return clampi(tier, TIER_MIN, TIER_MAX) - 1


static func family_of(tier: int) -> String:
	return String(FAMILY_BY_TIER.get(clampi(tier, TIER_MIN, TIER_MAX), "scrap"))


static func sfx_id(tier: int) -> String:
	return SFX_PREFIX + family_of(tier)


static func sfx_ids() -> Array[String]:
	var out: Array[String] = []
	for family in FAMILIES:
		out.append(SFX_PREFIX + String(family))
	return out


static func tier_color(tier: int) -> Color:
	match clampi(tier, TIER_MIN, TIER_MAX):
		1:
			return Palette.SAND
		2:
			return Palette.RUST
		3:
			return CONCRETE
		4:
			return _shade(CONCRETE, 0.95)
	return Palette.SANDSTONE


static func material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	mat.emission_enabled = false
	mat.roughness = 0.9
	return mat


static func triangle_count(mesh: Mesh) -> int:
	var n := 0
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var index: Variant = arrays[Mesh.ARRAY_INDEX]
		if index is PackedInt32Array and (index as PackedInt32Array).size() > 0:
			n += (index as PackedInt32Array).size() / 3
		else:
			n += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return n


static func piece_mesh(tier: int, size: Vector3) -> ArrayMesh:
	tier = clampi(tier, TIER_MIN, TIER_MAX)
	var b := _Build.new()
	var half := size * 0.5
	var relief := clampf(minf(size.x, size.z) * 0.06, 0.04, 0.16)
	relief = minf(relief, minf(half.x, half.z) * 0.3)
	var seams := seam_count(tier)
	var gap := clampf(size.y * 0.05, 0.07, 0.2) if seams > 0 else 0.0
	var slab_h := (size.y - seams * gap) / float(tier)
	var recess := clampf(minf(half.x, half.z) * 0.12, 0.06, 0.18)
	var base := tier_color(tier)
	var inner := Vector3(half.x - relief, 0.0, half.z - relief)
	var bevel := clampf(minf(minf(half.x, half.z), slab_h * 0.5) * 0.18, 0.03, 0.12)
	match tier:
		1:
			_crate(b, half, relief, base)
		2:
			_barricade(b, half, relief, slab_h, gap, recess, base)
		3:
			for i in tier:
				var y := _slab_y(i, size.y, slab_h, gap)
				b.chamfered(Vector3(0.0, y, 0.0), Vector3(half.x, slab_h * 0.5, half.z), bevel, base)
				if i < seams:
					_seam(b, y + slab_h * 0.5 + gap * 0.5, gap, Vector2(half.x, half.z), recess)
		4:
			_housing(b, half, relief, slab_h, gap, recess, bevel, base, inner)
		_:
			_trophy(b, half, relief, slab_h, gap, recess, bevel, base, inner)
	var mesh := b.commit()
	mesh.set_meta("tier", tier)
	mesh.set_meta("seam_bands", seams)
	mesh.set_meta("seam_thickness", gap)
	mesh.set_meta("triangles", triangle_count(mesh))
	return mesh


static func _slab_y(i: int, height: float, slab_h: float, gap: float) -> float:
	return -height * 0.5 + slab_h * 0.5 + float(i) * (slab_h + gap)


static func _seam(b: _Build, y: float, gap: float, footprint: Vector2, recess: float) -> void:
	b.box(Vector3(0.0, y, 0.0), Vector3(footprint.x - recess, gap * 0.5, footprint.y - recess), SEAM)


static func _crate(b: _Build, half: Vector3, relief: float, base: Color) -> void:
	var post := _shade(base, 0.82)
	b.box(Vector3.ZERO, Vector3(half.x - relief * 0.6, half.y - relief * 0.4, half.z - relief * 0.6), base)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			b.box(Vector3(sx * (half.x - relief), 0.0, sz * (half.z - relief)), Vector3(relief, half.y, relief), post)
	for sz in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			b.box(Vector3(0.0, sy * half.y * 0.55, sz * (half.z - relief * 0.6)),
				Vector3(half.x - relief * 2.0, relief * 0.5, relief * 0.6), post)


static func _barricade(b: _Build, half: Vector3, relief: float, slab_h: float, gap: float, recess: float, base: Color) -> void:
	var batten := _shade(base, 0.78)
	var body := Vector2(maxf(half.x - relief * 2.2, 0.1), half.z - relief * 0.6)
	var count := clampi(int(half.x * 2.0 / 0.9), 2, 5)
	for i in 2:
		var y := _slab_y(i, slab_h * 2.0 + gap, slab_h, gap)
		b.box(Vector3(0.0, y, 0.0), Vector3(body.x, slab_h * 0.5, body.y), base)
		for k in count:
			var x := lerpf(-half.x + relief * 3.0, half.x - relief * 3.0, (float(k) + 0.5) / float(count))
			for sz in [-1.0, 1.0]:
				b.box(Vector3(x, y, sz * (half.z - relief * 0.6)), Vector3(relief * 0.8, slab_h * 0.5 - 0.02, relief * 0.6), batten)
	_seam(b, 0.0, gap, Vector2(body.x + recess, body.y), recess)
	for sx in [-1.0, 1.0]:
		b.box(Vector3(sx * (half.x - relief * 1.1), 0.0, 0.0), Vector3(relief * 1.1, half.y, half.z - relief * 0.6), batten)


static func _housing(b: _Build, half: Vector3, relief: float, slab_h: float, gap: float, recess: float, bevel: float, base: Color, inner: Vector3) -> void:
	var flange := _shade(Palette.RUST, 0.82)
	var rivet := Palette.RUST
	var rivets := clampi(int(half.x * 2.0 / 0.7), 3, 8)
	for i in 4:
		var y := _slab_y(i, half.y * 2.0, slab_h, gap)
		var edge := i == 0 or i == 3
		if edge:
			b.chamfered(Vector3(0.0, y, 0.0), Vector3(half.x, slab_h * 0.5, half.z), bevel, flange)
		else:
			b.chamfered(Vector3(0.0, y, 0.0), Vector3(inner.x, slab_h * 0.5, inner.z), bevel * 0.6, base)
			for k in rivets:
				var margin := minf(0.25, inner.x * 0.5)
				var x := lerpf(-inner.x + margin, inner.x - margin, (float(k) + 0.5) / float(rivets))
				for sz in [-1.0, 1.0]:
					b.box(Vector3(x, y, sz * (half.z - relief * 0.5)), Vector3(0.06, 0.06, relief * 0.5), rivet)
		if i < 3:
			_seam(b, y + slab_h * 0.5 + gap * 0.5, gap, Vector2(inner.x, inner.z), recess)


static func _trophy(b: _Build, half: Vector3, relief: float, slab_h: float, gap: float, recess: float, bevel: float, base: Color, inner: Vector3) -> void:
	var trim := _shade(base, 0.78)
	var bolt := _shade(base, 0.62)
	for i in 5:
		var y := _slab_y(i, half.y * 2.0, slab_h, gap)
		var edge := i == 0 or i == 4
		if edge:
			b.chamfered(Vector3(0.0, y, 0.0), Vector3(half.x, slab_h * 0.5, half.z), bevel, trim)
		else:
			b.chamfered(Vector3(0.0, y, 0.0), Vector3(inner.x, slab_h * 0.5, inner.z), bevel * 0.6, base)
			var bx := maxf(inner.x - 0.3, inner.x * 0.5)
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					b.box(Vector3(sx * bx, y, sz * (half.z - relief * 0.5)), Vector3(0.09, 0.09, relief * 0.5), bolt)
		if i < 4:
			_seam(b, y + slab_h * 0.5 + gap * 0.5, gap, Vector2(inner.x, inner.z), recess)


static func shard_mesh(family: String) -> ArrayMesh:
	var b := _Build.new()
	match family:
		"wood":
			b.frustum(Vector3.ZERO, Vector2(0.07, 0.05), Vector2(0.015, 0.015), 0.5, Palette.SANDSTONE)
		"masonry":
			var c := CONCRETE
			b.hull([Vector3(-0.2, -0.15, -0.16), Vector3(0.2, -0.15, -0.14), Vector3(0.18, -0.15, 0.17), Vector3(-0.19, -0.15, 0.15),
				Vector3(-0.1, 0.16, -0.08), Vector3(0.14, 0.12, -0.12), Vector3(0.1, 0.17, 0.1), Vector3(-0.16, 0.08, 0.06)], c)
		"steel":
			var plate := Palette.CHARCOAL
			b.box(Vector3(0.0, -0.1, 0.0), Vector3(0.2, 0.025, 0.1), plate)
			b.box(Vector3(-0.175, 0.04, 0.0), Vector3(0.025, 0.14, 0.1), plate)
			b.box(Vector3(0.06, -0.06, 0.0), Vector3(0.03, 0.03, 0.03), _shade(Palette.RUST, 0.9))
		_:
			b.tilted_box(Vector3(-0.1, 0.0, 0.0), Vector3(0.12, 0.02, 0.16), Basis(Vector3.BACK, 0.45), Palette.RUST)
			b.tilted_box(Vector3(0.1, 0.0, 0.0), Vector3(0.12, 0.02, 0.16), Basis(Vector3.BACK, -0.45), _shade(Palette.RUST, 0.88))
	var mesh := b.commit()
	mesh.set_meta("family", family)
	mesh.set_meta("triangles", triangle_count(mesh))
	return mesh


static func puff_mesh() -> ArrayMesh:
	var b := _Build.new()
	b.box(Vector3.ZERO, Vector3(0.45, 0.25, 0.45), Palette.SAND)
	return b.commit()


static func _shade(c: Color, f: float) -> Color:
	return Color(clampf(c.r * f, 0.0, 1.0), clampf(c.g * f, 0.0, 1.0), clampf(c.b * f, 0.0, 1.0), 1.0)


static func color_distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


class _Build extends RefCounted:
	var tool := SurfaceTool.new()

	func _init() -> void:
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	func commit() -> ArrayMesh:
		tool.index()
		return tool.commit()

	func tri(a: Vector3, b: Vector3, c: Vector3, inside: Vector3, color: Color) -> void:
		var n := (b - a).cross(c - a)
		if n.length_squared() < 0.0000001:
			return
		n = n.normalized()
		if n.dot((a + b + c) / 3.0 - inside) < 0.0:
			var swap := b
			b = c
			c = swap
			n = -n
		tool.set_color(color)
		tool.set_normal(n)
		# Godot fronts clockwise winding (a, c, b).
		tool.add_vertex(a)
		tool.add_vertex(c)
		tool.add_vertex(b)

	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, inside: Vector3, color: Color) -> void:
		tri(a, b, c, inside, color)
		tri(a, c, d, inside, color)

	func box(centre: Vector3, half: Vector3, color: Color) -> void:
		chamfered(centre, half, 0.0, color)

	func chamfered(centre: Vector3, half: Vector3, bevel: float, color: Color, xf: Transform3D = Transform3D.IDENTITY) -> void:
		var inside := xf * centre
		var bv := minf(bevel, minf(half.x, minf(half.y, half.z)) * 0.45)
		var strip := Color(color.r * 0.93, color.g * 0.93, color.b * 0.93, 1.0)
		var facet := Color(color.r * 0.87, color.g * 0.87, color.b * 0.87, 1.0)
		for axis in 3:
			for sign_a in [-1.0, 1.0]:
				var pts: Array[Vector3] = []
				for corner in [Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, 1, -1), Vector3(-1, 1, -1)]:
					pts.append(xf * (centre + _face_point(half, bv, axis, sign_a, _on_face(corner, axis))))
				quad(pts[0], pts[1], pts[2], pts[3], inside, color)
		if bv <= 0.0:
			return
		for c_axis in 3:
			var a_axis := (c_axis + 1) % 3
			var b_axis := (c_axis + 2) % 3
			for sa in [-1.0, 1.0]:
				for sb in [-1.0, 1.0]:
					var p: Array[Vector3] = []
					for sc in [-1.0, 1.0]:
						p.append(xf * (centre + _face_point(half, bv, a_axis, sa, _axis_vec(a_axis, sa, b_axis, sb, c_axis, sc))))
					for sc in [1.0, -1.0]:
						p.append(xf * (centre + _face_point(half, bv, b_axis, sb, _axis_vec(a_axis, sa, b_axis, sb, c_axis, sc))))
					quad(p[0], p[1], p[2], p[3], inside, strip)
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					var corner := Vector3(sx, sy, sz)
					tri(xf * (centre + _face_point(half, bv, 0, sx, corner)), xf * (centre + _face_point(half, bv, 1, sy, corner)),
						xf * (centre + _face_point(half, bv, 2, sz, corner)), inside, facet)

	static func _on_face(corner: Vector3, axis: int) -> Vector3:
		match axis:
			0:
				return Vector3(1.0, corner.x, corner.y)
			1:
				return Vector3(corner.x, 1.0, corner.y)
		return Vector3(corner.x, corner.y, 1.0)

	static func _axis_vec(a_axis: int, sa: float, b_axis: int, sb: float, c_axis: int, sc: float) -> Vector3:
		var v := Vector3.ZERO
		v[a_axis] = sa
		v[b_axis] = sb
		v[c_axis] = sc
		return v

	static func _face_point(half: Vector3, bv: float, axis: int, sign_a: float, s: Vector3) -> Vector3:
		var p := Vector3.ZERO
		for k in 3:
			if k == axis:
				p[k] = sign_a * half[k]
			else:
				p[k] = s[k] * (half[k] - bv)
		return p

	func tilted_box(centre: Vector3, half: Vector3, basis: Basis, color: Color) -> void:
		chamfered(Vector3.ZERO, half, 0.0, color, Transform3D(basis, centre))

	func frustum(centre: Vector3, bottom: Vector2, top: Vector2, height: float, color: Color) -> void:
		var y0 := -height * 0.5
		var y1 := height * 0.5
		var pts: Array[Vector3] = []
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			pts.append(centre + Vector3(corner.x * bottom.x, y0, corner.y * bottom.y))
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			pts.append(centre + Vector3(corner.x * top.x, y1, corner.y * top.y))
		hull(pts, color)

	func hull(p: Array, color: Color) -> void:
		var inside := Vector3.ZERO
		for v in p:
			inside += v as Vector3
		inside /= float(p.size())
		quad(p[0], p[1], p[2], p[3], inside, color)
		quad(p[4], p[5], p[6], p[7], inside, color)
		for i in 4:
			var j := (i + 1) % 4
			quad(p[i], p[j], p[j + 4], p[i + 4], inside, color)
