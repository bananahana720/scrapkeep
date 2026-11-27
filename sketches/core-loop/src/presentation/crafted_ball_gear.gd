extends RefCounted


const CHUNK_VARIANTS := ["hull_patch", "press_canister", "gusset_bracket", "copper_spool"]

static var _mesh_cache := {}


static func clear_cache() -> void:
	_mesh_cache.clear()


static func chunk_variant(index: int) -> String:
	var n := CHUNK_VARIANTS.size()
	return CHUNK_VARIANTS[posmod(index, n)]


static func chunk_mesh(index: int) -> ArrayMesh:
	var kind := chunk_variant(index)
	var key := "chunk:" + kind
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var mesh: ArrayMesh
	match kind:
		"hull_patch":
			mesh = _build_hull_patch()
		"press_canister":
			mesh = _build_press_canister()
		"gusset_bracket":
			mesh = _build_gusset_bracket()
		_:
			mesh = _build_copper_spool()
	mesh.resource_name = "CraftChunk_" + kind
	_mesh_cache[key] = mesh
	return mesh


static func part_mesh(part_id: String, family: String) -> ArrayMesh:
	var kind := family
	if part_id in ["cross_split", "spiral_wave", "chain_arc"]:
		kind = part_id
	elif kind not in ["weapon", "mobility", "class", "milestone"]:
		kind = "stat"
	var key := "part:" + kind
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var mesh: ArrayMesh
	match kind:
		"cross_split":
			mesh = _build_cross_split()
		"spiral_wave":
			mesh = _build_spiral_wave()
		"chain_arc":
			mesh = _build_chain_arc()
		"weapon":
			mesh = _build_weapon_fitting()
		"mobility":
			mesh = _build_mobility_vane()
		"class":
			mesh = _build_class_relay()
		"milestone":
			mesh = _build_milestone_crest()
		_:
			mesh = _build_stat_disc()
	mesh.resource_name = "CraftPart_" + kind
	_mesh_cache[key] = mesh
	return mesh


static func synergy_ring_mesh(inner_radius: float, outer_radius: float, sides := 28) -> ArrayMesh:
	var key := "ring:%.3f:%.3f:%d" % [inner_radius, outer_radius, sides]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var st := _begin()
	var major := (inner_radius + outer_radius) * 0.5
	var minor := maxf((outer_radius - inner_radius) * 0.5, 0.015)
	add_torus(st, Transform3D.IDENTITY, major, minor, sides, 8, Color(0.95, 0.94, 0.90), Color(0.76, 0.78, 0.80))
	var mesh := _finish(st, "CraftSynergyRing")
	_mesh_cache[key] = mesh
	return mesh


static func bolt_dart_mesh() -> ArrayMesh:
	var key := "bolt:fluted_dart"
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var st := _begin()
	st.set_smooth_group(0)
	var segs := 24
	var stations := [
		[-0.45, 0.12, 0.05],
		[-0.36, 0.28, 0.14],
		[-0.27, 0.44, 0.23],
		[-0.22, 0.50, 0.28],
		[-0.18, 0.40, 0.32],
		[-0.13, 0.47, 0.37],
		[0.02, 0.41, 0.52],
		[0.20, 0.30, 0.70],
		[0.36, 0.18, 0.86],
		[0.45, 0.08, 0.95],
	]
	var nose := Vector3(0.0, 0.0, -0.50)
	var tail := Vector3(0.0, 0.0, 0.50)
	var rings: Array = []
	for s in stations:
		var z: float = s[0]
		var r: float = s[1]
		var u: float = s[2]
		var ring: Array = []
		for k in segs:
			var ang := float(k) * TAU / float(segs)
			var pos := Vector3(cos(ang) * r, sin(ang) * r, z)
			var v := float(k) / float(segs)
			ring.append({"p": pos, "uv": Vector2(u, v), "c": Color.WHITE})
		rings.append(ring)
	var first_ring: Array = rings[0]
	for k in segs:
		var next_k := (k + 1) % segs
		_tri_uv(st, nose, Vector2(0.0, float(k) / float(segs)), Color.WHITE,
			first_ring[k].p, first_ring[k].uv, first_ring[k].c,
			first_ring[next_k].p, first_ring[next_k].uv, first_ring[next_k].c)
	for i in rings.size() - 1:
		var r0: Array = rings[i]
		var r1: Array = rings[i + 1]
		for k in segs:
			var next_k := (k + 1) % segs
			_quad_uv(st,
				r0[k].p, r0[k].uv, r0[k].c,
				r1[k].p, r1[k].uv, r1[k].c,
				r1[next_k].p, r1[next_k].uv, r1[next_k].c,
				r0[next_k].p, r0[next_k].uv, r0[next_k].c)
	var last_ring: Array = rings[rings.size() - 1]
	for k in segs:
		var next_k := (k + 1) % segs
		_tri_uv(st, tail, Vector2(1.0, float(k) / float(segs)), Color.WHITE,
			last_ring[next_k].p, last_ring[next_k].uv, last_ring[next_k].c,
			last_ring[k].p, last_ring[k].uv, last_ring[k].c)
	st.index()
	var mesh := _finish(st, "CraftBoltDart")
	_mesh_cache[key] = mesh
	return mesh



static func _build_hull_patch() -> ArrayMesh:
	var st := _begin()
	var body := Color(0.92, 0.90, 0.87)
	var edge := Color(1.0, 0.97, 0.90)
	var recess := Color(0.68, 0.67, 0.66)
	var rivet := Color(0.98, 0.94, 0.84)
	add_beveled_box(st, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.012, 0.0)), Vector3(0.32, 0.12, 0.36), 0.022, body, edge)
	add_beveled_box(st, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.075, 0.0)), Vector3(0.21, 0.05, 0.25), 0.014, recess, edge)
	add_beveled_box(st, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.102, 0.0)), Vector3(0.27, 0.036, 0.08), 0.010, body, edge)
	for sx in [-0.11, 0.11]:
		for sz in [-0.13, 0.13]:
			add_cylinder(st, Transform3D(Basis.IDENTITY, Vector3(sx, 0.082, sz)), 0.022, 0.026, 0.038, 6, rivet, edge)
	return _finish(st, "CraftChunk_hull_patch")


static func _build_press_canister() -> ArrayMesh:
	var st := _begin()
	var tank := Color(0.94, 0.91, 0.86)
	var strap := Color(0.66, 0.66, 0.68)
	var brass := Color(1.0, 0.94, 0.82)
	var rot_z := Basis(Vector3.FORWARD, PI * 0.5)
	add_beveled_box(st, Transform3D(Basis.IDENTITY, Vector3(0.0, -0.005, 0.0)), Vector3(0.30, 0.08, 0.20), 0.014, strap, tank)
	add_cylinder(st, Transform3D(rot_z, Vector3(0.0, 0.085, 0.0)), 0.095, 0.095, 0.27, 12, tank, brass)
	for sx in [-0.15, 0.15]:
		var cap_basis := Basis(Vector3.FORWARD, PI * 0.5 if sx > 0.0 else -PI * 0.5)
		add_cylinder(st, Transform3D(cap_basis, Vector3(sx, 0.085, 0.0)), 0.06, 0.092, 0.04, 12, brass, tank)
	for sx in [-0.075, 0.075]:
		add_cylinder(st, Transform3D(rot_z, Vector3(sx, 0.085, 0.0)), 0.106, 0.106, 0.038, 12, strap, brass)
	add_cylinder(st, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.19, 0.0)), 0.028, 0.036, 0.048, 8, brass, tank)
	return _finish(st, "CraftChunk_press_canister")


static func _build_gusset_bracket() -> ArrayMesh:
	var st := _begin()
	var plate := Color(0.88, 0.87, 0.85)
	var rib := Color(0.72, 0.72, 0.74)
	var wear := Color(1.0, 0.96, 0.88)
	add_beveled_box(st, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.004, 0.0)), Vector3(0.32, 0.092, 0.34), 0.016, plate, wear)
	add_beveled_box(st, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.098, -0.108)), Vector3(0.29, 0.165, 0.082), 0.016, plate, wear)
	for sx in [-0.092, 0.0, 0.092]:
		var tilt := Basis(Vector3.RIGHT, 0.58)
		add_beveled_box(st, Transform3D(tilt, Vector3(sx, 0.074, 0.008)), Vector3(0.036, 0.135, 0.145), 0.009, rib, wear)
	for sx in [-0.105, 0.105]:
		add_cylinder(st, Transform3D(Basis.IDENTITY, Vector3(sx, 0.056, 0.108)), 0.024, 0.028, 0.034, 6, wear, plate)
	return _finish(st, "CraftChunk_gusset_bracket")


static func _build_copper_spool() -> ArrayMesh:
	var st := _begin()
	var steel := Color(0.74, 0.76, 0.78)
	var coil := Color(1.0, 0.93, 0.82)
	var lip := Color(0.98, 0.96, 0.90)
	add_cylinder(st, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.002, 0.0)), 0.165, 0.175, 0.072, 12, steel, lip)
	add_cylinder(st, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.072, 0.0)), 0.115, 0.115, 0.10, 12, coil, lip)
	for dy in [0.048, 0.096]:
		add_cylinder(st, Transform3D(Basis.IDENTITY, Vector3(0.0, dy, 0.0)), 0.13, 0.13, 0.02, 12, lip, coil)
	add_cylinder(st, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.14, 0.0)), 0.155, 0.165, 0.046, 12, steel, lip)
	add_cylinder(st, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.18, 0.0)), 0.044, 0.056, 0.042, 6, lip, steel)
	return _finish(st, "CraftChunk_copper_spool")



static func _build_cross_split() -> ArrayMesh:
	var st := _begin()
	var body := Color(0.92, 0.90, 0.86)
	var edge := Color(1.0, 0.97, 0.90)
	var dark := Color(0.56, 0.56, 0.58)
	add_cylinder(st, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.07, 0.0)), 0.11, 0.14, 0.14, 8, dark, edge)
	for yaw in [0.0, PI * 0.5]:
		var b := Basis(Vector3.UP, yaw)
		add_beveled_box(st, Transform3D(b, Vector3(0.0, 0.125, 0.0)), Vector3(0.42, 0.075, 0.10), 0.015, body, edge)
		for side in [-0.21, 0.21]:
			var tip := b * Vector3(side, 0.125, 0.0)
			var nozzle_b := b * Basis(Vector3.FORWARD, PI * 0.5)
			add_cylinder(st, Transform3D(nozzle_b, tip), 0.044, 0.058, 0.056, 8, edge, dark)
	add_cylinder(st, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.175, 0.0)), 0.052, 0.068, 0.048, 6, edge, body)
	return _finish(st, "CraftPart_cross_split")


static func _build_spiral_wave() -> ArrayMesh:
	var st := _begin()
	var body := Color(0.95, 0.93, 0.88)
	var dark := Color(0.68, 0.70, 0.72)
	add_cylinder(st, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.035, 0.0)), 0.14, 0.17, 0.08, 10, dark, body)
	var ring_xf := Transform3D(Basis(Vector3.RIGHT, 0.36), Vector3(0.0, 0.185, 0.0))
	add_torus(st, ring_xf, 0.185, 0.046, 18, 8, body, dark)
	for sx in [-0.105, 0.105]:
		add_beveled_box(st, Transform3D(Basis(Vector3.FORWARD, sx * -1.4), Vector3(sx, 0.11, 0.0)),
			Vector3(0.044, 0.13, 0.06), 0.010, dark, body)
	return _finish(st, "CraftPart_spiral_wave")


static func _build_chain_arc() -> ArrayMesh:
	var st := _begin()
	var copper := Color(0.98, 0.93, 0.84)
	var dark := Color(0.64, 0.66, 0.70)
	add_cylinder(st, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.04, 0.0)), 0.13, 0.16, 0.09, 8, dark, copper)
	add_cylinder(st, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.175, 0.0)), 0.052, 0.082, 0.24, 10, copper, dark)
	for dy in [0.115, 0.185, 0.255]:
		add_cylinder(st, Transform3D(Basis.IDENTITY, Vector3(0.0, dy, 0.0)), 0.105, 0.112, 0.028, 10, dark, copper)
	add_faceted_orb(st, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.335, 0.0)), 0.095, 10, 6, copper, dark)
	return _finish(st, "CraftPart_chain_arc")


static func _build_weapon_fitting() -> ArrayMesh:
	var st := _begin()
	var steel := Color(0.90, 0.90, 0.88)
	var dark := Color(0.64, 0.66, 0.68)
	var edge := Color(1.0, 0.97, 0.90)
	add_beveled_box(st, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.045, 0.0)), Vector3(0.20, 0.10, 0.21), 0.018, dark, edge)
	add_cylinder(st, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.19, 0.0)), 0.06, 0.084, 0.25, 10, steel, edge)
	for dy in [0.135, 0.20, 0.265]:
		add_cylinder(st, Transform3D(Basis.IDENTITY, Vector3(0.0, dy, 0.0)), 0.098, 0.098, 0.024, 8, edge, dark)
	add_cylinder(st, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.325, 0.0)), 0.086, 0.068, 0.055, 8, edge, steel)
	return _finish(st, "CraftPart_weapon")


static func _build_mobility_vane() -> ArrayMesh:
	var st := _begin()
	var body := Color(0.93, 0.92, 0.88)
	var dark := Color(0.66, 0.68, 0.70)
	var edge := Color(1.0, 0.97, 0.90)
	add_beveled_box(st, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.04, 0.0)), Vector3(0.16, 0.085, 0.32), 0.014, dark, edge)
	var sweep := Basis(Vector3.RIGHT, -0.24)
	add_beveled_box(st, Transform3D(sweep, Vector3(0.0, 0.19, -0.015)), Vector3(0.075, 0.28, 0.34), 0.018, body, edge)
	add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.0, 0.10, 0.165)), 0.056, 0.074, 0.08, 8, edge, dark)
	return _finish(st, "CraftPart_mobility")


static func _build_class_relay() -> ArrayMesh:
	var st := _begin()
	var body := Color(0.95, 0.94, 0.90)
	var dark := Color(0.68, 0.70, 0.73)
	add_cylinder(st, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.045, 0.0)), 0.14, 0.17, 0.09, 8, dark, body)
	add_cylinder(st, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.165, 0.0)), 0.088, 0.118, 0.17, 8, body, dark)
	add_faceted_orb(st, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.295, 0.0)), 0.095, 8, 5, Color.WHITE, body)
	return _finish(st, "CraftPart_class")


static func _build_milestone_crest() -> ArrayMesh:
	var st := _begin()
	var gold := Color(1.0, 0.96, 0.86)
	var dark := Color(0.70, 0.68, 0.66)
	add_cylinder(st, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.045, 0.0)), 0.14, 0.18, 0.09, 8, dark, gold)
	add_faceted_orb(st, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.24, 0.0)), 0.17, 6, 4, gold, dark)
	for yaw in [0.0, PI * 0.5]:
		add_beveled_box(st, Transform3D(Basis(Vector3.UP, yaw), Vector3(0.0, 0.24, 0.0)),
			Vector3(0.40, 0.075, 0.075), 0.016, gold, dark)
	return _finish(st, "CraftPart_milestone")


static func _build_stat_disc() -> ArrayMesh:
	var st := _begin()
	var body := Color(0.90, 0.89, 0.86)
	var dark := Color(0.66, 0.68, 0.70)
	var edge := Color(1.0, 0.96, 0.88)
	add_cylinder(st, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.036, 0.0)), 0.22, 0.25, 0.072, 12, body, edge)
	add_cylinder(st, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.082, 0.0)), 0.135, 0.16, 0.038, 8, dark, edge)
	for k in 6:
		var a := float(k) * TAU / 6.0
		add_cylinder(st, Transform3D(Basis.IDENTITY, Vector3(cos(a) * 0.175, 0.082, sin(a) * 0.175)),
			0.018, 0.024, 0.026, 6, edge, dark)
	return _finish(st, "CraftPart_stat")



static func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


static func _finish(st: SurfaceTool, mesh_name: String) -> ArrayMesh:
	st.generate_normals()
	st.generate_tangents()
	var mesh := st.commit()
	mesh.resource_name = mesh_name
	return mesh


static func _tri_uv(st: SurfaceTool, p0: Vector3, uv0: Vector2, c0: Color,
		p1: Vector3, uv1: Vector2, c1: Color, p2: Vector3, uv2: Vector2, c2: Color) -> void:
	st.set_color(c0)
	st.set_uv(uv0)
	st.add_vertex(p0)
	st.set_color(c1)
	st.set_uv(uv1)
	st.add_vertex(p1)
	st.set_color(c2)
	st.set_uv(uv2)
	st.add_vertex(p2)


static func _quad_uv(st: SurfaceTool, p0: Vector3, uv0: Vector2, c0: Color,
		p1: Vector3, uv1: Vector2, c1: Color, p2: Vector3, uv2: Vector2, c2: Color,
		p3: Vector3, uv3: Vector2, c3: Color) -> void:
	_tri_uv(st, p0, uv0, c0, p1, uv1, c1, p2, uv2, c2)
	_tri_uv(st, p0, uv0, c0, p2, uv2, c2, p3, uv3, c3)


static func add_beveled_box(st: SurfaceTool, xf: Transform3D, size: Vector3, bevel: float,
		body_col: Color, bevel_col: Color) -> void:
	var hx := maxf(size.x * 0.5, 0.005)
	var hy := maxf(size.y * 0.5, 0.005)
	var hz := maxf(size.z * 0.5, 0.005)
	var b := minf(bevel, minf(hx, minf(hy, hz)) * 0.42)
	var rings := [
		[-hy, hx - b, hz - b, bevel_col],
		[-hy + b, hx, hz, body_col],
		[hy - b, hx, hz, body_col],
		[hy, hx - b, hz - b, bevel_col],
	]
	var loops: Array = []
	for r in rings:
		var y: float = r[0]
		var rx: float = r[1]
		var rz: float = r[2]
		var col: Color = r[3]
		var cx := maxf(rx - b * 0.7, 0.001)
		var cz := maxf(rz - b * 0.7, 0.001)
		var pts := [
			Vector3(cx, y, rz), Vector3(rx, y, cz),
			Vector3(rx, y, -cz), Vector3(cx, y, -rz),
			Vector3(-cx, y, -rz), Vector3(-rx, y, -cz),
			Vector3(-rx, y, cz), Vector3(-cx, y, rz),
		]
		var wpts: Array[Vector3] = []
		for p in pts:
			wpts.append(xf * p)
		loops.append({"pts": wpts, "c": col, "v": (y + hy) / maxf(size.y, 0.001)})
	for i in loops.size() - 1:
		var l0: Dictionary = loops[i]
		var l1: Dictionary = loops[i + 1]
		var p0s: Array = l0.pts
		var p1s: Array = l1.pts
		var n := p0s.size()
		for k in n:
			var nk := (k + 1) % n
			var u0 := float(k) / float(n)
			var u1 := float(k + 1) / float(n)
			_quad_uv(st,
				p0s[k], Vector2(u0, l0.v), l0.c,
				p1s[k], Vector2(u0, l1.v), l1.c,
				p1s[nk], Vector2(u1, l1.v), l1.c,
				p0s[nk], Vector2(u1, l0.v), l0.c)
	var bot: Array = loops[0].pts
	var bot_c := xf * Vector3(0.0, -hy, 0.0)
	for k in bot.size():
		var nk := (k + 1) % bot.size()
		_tri_uv(st, bot_c, Vector2(0.5, 0.5), bevel_col,
			bot[k], Vector2(1.0, 0.0), bevel_col,
			bot[nk], Vector2(0.0, 0.0), bevel_col)
	var top: Array = loops[loops.size() - 1].pts
	var top_c := xf * Vector3(0.0, hy, 0.0)
	for k in top.size():
		var nk := (k + 1) % top.size()
		_tri_uv(st, top_c, Vector2(0.5, 0.5), bevel_col,
			top[nk], Vector2(1.0, 1.0), bevel_col,
			top[k], Vector2(0.0, 1.0), bevel_col)


static func add_cylinder(st: SurfaceTool, xf: Transform3D, top_r: float, bot_r: float,
		height: float, sides: int, body_col: Color, rim_col: Color) -> void:
	var n := maxi(sides, 6)
	var hy := maxf(height * 0.5, 0.005)
	var b := minf(height * 0.14, minf(top_r, bot_r) * 0.22)
	var stations := [
		[-hy, maxf(bot_r - b * 0.65, 0.003), rim_col, 0.0],
		[-hy + b, bot_r, body_col, 0.15],
		[hy - b, top_r, body_col, 0.85],
		[hy, maxf(top_r - b * 0.65, 0.003), rim_col, 1.0],
	]
	var loops: Array = []
	for s in stations:
		var pts: Array[Vector3] = []
		for k in n:
			var a := float(k) * TAU / float(n)
			pts.append(xf * Vector3(cos(a) * float(s[1]), float(s[0]), sin(a) * float(s[1])))
		loops.append({"pts": pts, "c": s[2], "v": float(s[3])})
	for i in loops.size() - 1:
		var l0: Dictionary = loops[i]
		var l1: Dictionary = loops[i + 1]
		for k in n:
			var nk := (k + 1) % n
			var u0 := float(k) / float(n)
			var u1 := float(k + 1) / float(n)
			_quad_uv(st,
				l0.pts[k], Vector2(u0, l0.v), l0.c,
				l0.pts[nk], Vector2(u1, l0.v), l0.c,
				l1.pts[nk], Vector2(u1, l1.v), l1.c,
				l1.pts[k], Vector2(u0, l1.v), l1.c)
	var bot: Array = loops[0].pts
	var bot_c := xf * Vector3(0.0, -hy, 0.0)
	for k in n:
		var nk := (k + 1) % n
		_tri_uv(st, bot_c, Vector2(0.5, 0.5), rim_col,
			bot[nk], Vector2(1.0, 0.0), rim_col,
			bot[k], Vector2(0.0, 0.0), rim_col)
	var top: Array = loops[loops.size() - 1].pts
	var top_c := xf * Vector3(0.0, hy, 0.0)
	for k in n:
		var nk := (k + 1) % n
		_tri_uv(st, top_c, Vector2(0.5, 0.5), rim_col,
			top[k], Vector2(0.0, 1.0), rim_col,
			top[nk], Vector2(1.0, 1.0), rim_col)


static func add_torus(st: SurfaceTool, xf: Transform3D, major_r: float, minor_r: float,
		major_seg: int, minor_seg: int, outer_col: Color, inner_col: Color) -> void:
	var maj := maxi(major_seg, 8)
	var mn := maxi(minor_seg, 6)
	var grid: Array = []
	for i in maj:
		var theta := float(i) * TAU / float(maj)
		var dir := Vector3(cos(theta), 0.0, sin(theta))
		var ring: Array = []
		for j in mn:
			var phi := float(j) * TAU / float(mn)
			var c_phi := cos(phi)
			var s_phi := sin(phi)
			var p := dir * (major_r + c_phi * minor_r) + Vector3.UP * (s_phi * minor_r)
			var col := inner_col.lerp(outer_col, clampf(c_phi * 0.5 + 0.5, 0.0, 1.0))
			ring.append({"p": xf * p, "c": col})
		grid.append(ring)
	for i in maj:
		var ni := (i + 1) % maj
		var u0 := float(i) / float(maj)
		var u1 := float(i + 1) / float(maj)
		for j in mn:
			var nj := (j + 1) % mn
			var v0 := float(j) / float(mn)
			var v1 := float(j + 1) / float(mn)
			_quad_uv(st,
				grid[i][j].p, Vector2(u0, v0), grid[i][j].c,
				grid[ni][j].p, Vector2(u1, v0), grid[ni][j].c,
				grid[ni][nj].p, Vector2(u1, v1), grid[ni][nj].c,
				grid[i][nj].p, Vector2(u0, v1), grid[i][nj].c)


static func add_faceted_orb(st: SurfaceTool, xf: Transform3D, radius: float,
		lon: int, lat: int, top_col: Color, bot_col: Color) -> void:
	var n_lon := maxi(lon, 6)
	var n_lat := maxi(lat, 3)
	var north := xf * Vector3(0.0, radius, 0.0)
	var south := xf * Vector3(0.0, -radius, 0.0)
	var rings: Array = []
	for i in range(1, n_lat):
		var v := float(i) / float(n_lat)
		var phi := v * PI
		var y := cos(phi) * radius
		var r := sin(phi) * radius
		var col := top_col.lerp(bot_col, v)
		var ring: Array = []
		for k in n_lon:
			var a := float(k) * TAU / float(n_lon)
			ring.append({"p": xf * Vector3(cos(a) * r, y, sin(a) * r), "c": col, "v": v})
		rings.append(ring)
	var first: Array = rings[0]
	for k in n_lon:
		var nk := (k + 1) % n_lon
		_tri_uv(st, north, Vector2(0.5, 0.0), top_col,
			first[k].p, Vector2(0.0, first[k].v), first[k].c,
			first[nk].p, Vector2(1.0, first[nk].v), first[nk].c)
	for i in rings.size() - 1:
		var r0: Array = rings[i]
		var r1: Array = rings[i + 1]
		for k in n_lon:
			var nk := (k + 1) % n_lon
			var u0 := float(k) / float(n_lon)
			var u1 := float(k + 1) / float(n_lon)
			_quad_uv(st,
				r0[k].p, Vector2(u0, r0[k].v), r0[k].c,
				r1[k].p, Vector2(u0, r1[k].v), r1[k].c,
				r1[nk].p, Vector2(u1, r1[nk].v), r1[nk].c,
				r0[nk].p, Vector2(u1, r0[nk].v), r0[nk].c)
	var last: Array = rings[rings.size() - 1]
	for k in n_lon:
		var nk := (k + 1) % n_lon
		_tri_uv(st, south, Vector2(0.5, 1.0), bot_col,
			last[nk].p, Vector2(1.0, last[nk].v), last[nk].c,
			last[k].p, Vector2(0.0, last[k].v), last[k].c)
