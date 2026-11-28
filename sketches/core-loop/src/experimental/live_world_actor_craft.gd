extends RefCounted

const CampCraftMeshes := preload("res://src/presentation/craft/camp_craft_meshes.gd")
const CraftLookdev := preload("res://src/presentation/craft/craft_lookdev.gd")
const EnemyBossCraft := preload("res://src/presentation/craft/enemy_boss_craft.gd")
const FlashGuard := preload("res://src/core/flash_guard.gd")
const Palette := preload("res://src/core/palette.gd")

const RIG_BONE := Palette.LEDGER_CREAM
const RIG_BONE_SHADE := Palette.LEDGER
const RIG_CHEVRON := Color("ffd27a")
const RIG_BEACON := Color("ffcb94")
const RIG_CORE := Palette.ARC
const RIG_TRIM: Array[Color] = [RIG_BONE, RIG_BONE_SHADE, RIG_CHEVRON, RIG_BEACON, RIG_CORE]

var _mesh_cache: Dictionary = {}
var _fx_mats: Dictionary = {}


func flash_material() -> Material:
	var key := "flash_soft" if FlashGuard.on else "flash"
	if _fx_mats.has(key):
		return _fx_mats[key]
	var mat := StandardMaterial3D.new()
	mat.resource_name = "exp_live_" + key
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(Palette.SODIUM, 0.18 if FlashGuard.on else 0.5)
	_fx_mats[key] = mat
	return mat


func ring_material(tag: StringName) -> Material:
	var key := "ring_" + String(tag)
	if _fx_mats.has(key):
		return _fx_mats[key]
	var tint := Palette.HAZARD
	match tag:
		&"coolant_brittle":
			tint = Palette.ICE
		&"electrified":
			tint = Palette.ARC
		&"magnetic":
			tint = Palette.COBALT
	var mat := StandardMaterial3D.new()
	mat.resource_name = "exp_live_" + key
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(tint, 0.7)
	mat.emission_enabled = true
	mat.emission = tint
	_fx_mats[key] = mat
	return mat


func _streak_material() -> Material:
	if _fx_mats.has("streak"):
		return _fx_mats["streak"]
	var mat := StandardMaterial3D.new()
	mat.resource_name = "exp_live_streak"
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(Palette.SAND, 0.38)
	_fx_mats["streak"] = mat
	return mat


static func _mat(role: String) -> Material:
	match role:
		"iron":
			return EnemyBossCraft.craft_shader_material("exp_live_iron", "oil_slicked_iron", Palette.CHARCOAL, Palette.STEEL)
		"hull":
			return EnemyBossCraft.craft_shader_material("exp_live_hull", "oxidized_hull_plating", Palette.RUST, Palette.COPPER)
		"fleet":
			return EnemyBossCraft.craft_shader_material("exp_live_fleet", "oxidized_hull_plating", Palette.VERDIGRIS, Palette.COPPER)
		"frost":
			return EnemyBossCraft.craft_shader_material("exp_live_frost", "oxidized_hull_plating", Palette.ICE, Palette.COBALT, 0.45, 0.4, Palette.ICE, 0.9)
		"fuel":
			return EnemyBossCraft.craft_shader_material("exp_live_fuel", "oxidized_hull_plating", Palette.HAZARD, Palette.RUST, 0.6, 0.3, Palette.AMBER, 0.6)
		"amber_core":
			return EnemyBossCraft.craft_shader_material("exp_live_amber", "plasma_conduit_core", Palette.CABLE, Palette.AMBER, 0.4, 0.2, Palette.AMBER, 2.2)
		"bone":
			return EnemyBossCraft.craft_shader_material("exp_live_bone", "oil_slicked_iron", RIG_BONE, RIG_BONE_SHADE, 0.5, 0.12)
		"chevron":
			return EnemyBossCraft.craft_shader_material("exp_live_chevron", "oxidized_hull_plating", RIG_CHEVRON, RIG_CHEVRON, 0.46, 0.1, RIG_CHEVRON, 0.35)
		"rig_core":
			return EnemyBossCraft.craft_shader_material("exp_live_rig_core", "plasma_conduit_core", RIG_CORE, RIG_CORE, 0.3, 0.1, RIG_CORE, 3.0)
		"rig_beacon":
			return EnemyBossCraft.craft_shader_material("exp_live_rig_beacon", "plasma_conduit_core", RIG_BEACON, RIG_BEACON, 0.3, 0.1, RIG_BEACON, 2.8)
	return EnemyBossCraft.craft_shader_material("exp_live_arc", "plasma_conduit_core", Palette.CABLE, Palette.ARC, 0.4, 0.2, Palette.ARC, 2.0)


static func _c(wear: float, grime: float, emissive := 0.0) -> Color:
	return CraftLookdev.encode_mask(wear, grime, emissive)


static func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


static func _commit(mesh: ArrayMesh, st: SurfaceTool, mat: Material) -> void:
	st.generate_tangents()
	st.commit(mesh)
	mesh.surface_set_material(mesh.get_surface_count() - 1, mat)


func _keep(key: String, mesh: ArrayMesh) -> ArrayMesh:
	mesh.resource_name = "exp_live_" + key
	_mesh_cache[key] = mesh
	return mesh


static func _box(st: SurfaceTool, at: Vector3, size: Vector3, bevel: float, yaw := 0.0, emissive := 0.0) -> void:
	CampCraftMeshes.add_bevel_box(st, Vector3.ZERO, size, bevel, 0.3, Transform3D(Basis(Vector3.UP, yaw), at),
		_c(0.2, 0.32, emissive), _c(0.7, 0.14, emissive), _c(0.1, 0.72, emissive * 0.5))


static func _plate(st: SurfaceTool, xf: Transform3D, size: Vector3, bevel: float, emissive := 0.0) -> void:
	CampCraftMeshes.add_bevel_box(st, Vector3.ZERO, size, bevel, 0.3, xf, _c(0.12, 0.06, emissive), _c(0.4, 0.04, emissive), _c(0.1, 0.2, emissive * 0.5))


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3, col: Color) -> void:
	var nn := n.normalized()
	var cr := (b - a).cross(c - a)
	if cr.length_squared() < 1e-12 or nn.length_squared() < 1e-6:
		return
	if cr.dot(nn) > 0.0:
		var swap := b
		b = c
		c = swap
	for p: Vector3 in [a, b, c]:
		st.set_normal(nn)
		st.set_color(col)
		st.set_uv(Vector2(p.x + p.z, p.y) * 0.35)
		st.add_vertex(p)


static func _lathe(st: SurfaceTool, profile: PackedVector2Array, segments: int, xf: Transform3D, col: Color, closed := false) -> void:
	var count := profile.size()
	var spans := count if closed else count - 1
	for i in spans:
		var a: Vector2 = profile[i]
		var b: Vector2 = profile[(i + 1) % count]
		var d := b - a
		if d.length_squared() < 1e-10:
			continue
		var n2 := Vector2(d.y, -d.x).normalized()
		for s in segments:
			var t0 := TAU * float(s) / float(segments)
			var t1 := TAU * float(s + 1) / float(segments)
			var r0 := Vector3(cos(t0), 0.0, sin(t0))
			var r1 := Vector3(cos(t1), 0.0, sin(t1))
			var rm := (r0 + r1).normalized()
			var n := xf.basis * (rm * n2.x + Vector3.UP * n2.y)
			var p00: Vector3 = xf * (r0 * a.x + Vector3.UP * a.y)
			var p01: Vector3 = xf * (r1 * a.x + Vector3.UP * a.y)
			var p10: Vector3 = xf * (r0 * b.x + Vector3.UP * b.y)
			var p11: Vector3 = xf * (r1 * b.x + Vector3.UP * b.y)
			_tri(st, p00, p01, p11, n, col)
			_tri(st, p00, p11, p10, n, col)


static func _orb(radius: float, rings := 6) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in rings + 1:
		var a := -PI * 0.5 + PI * float(i) / float(rings)
		pts.append(Vector2(cos(a) * radius, sin(a) * radius))
	pts[0] = Vector2(0.0, -radius)
	pts[rings] = Vector2(0.0, radius)
	return pts


static func _loop(major: float, minor: float, steps := 10) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps:
		var a := TAU * float(i) / float(steps)
		pts.append(Vector2(major + cos(a) * minor, sin(a) * minor))
	return pts


func beacon_pad_mesh() -> ArrayMesh:
	if _mesh_cache.has("beacon_pad"):
		return _mesh_cache["beacon_pad"]
	var mesh := ArrayMesh.new()
	var st := _begin()
	_lathe(st, PackedVector2Array([Vector2(0.0, 0.0), Vector2(2.6, 0.0), Vector2(2.6, 0.12), Vector2(2.25, 0.24), Vector2(0.0, 0.24)]), 28, Transform3D.IDENTITY, _c(0.5, 0.4))
	for i in 4:
		var a := TAU * float(i) / 4.0 + PI * 0.25
		_box(st, Vector3(cos(a) * 1.75, 0.46, sin(a) * 1.75), Vector3(0.62, 0.48, 0.62), 0.1, -a)
	_commit(mesh, st, _mat("iron"))
	st = _begin()
	_lathe(st, _loop(2.05, 0.09, 8), 32, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.3, 0.0)), _c(0.2, 0.1, 1.0), true)
	_commit(mesh, st, _mat("amber_core"))
	return _keep("beacon_pad", mesh)


func beacon_core_mesh() -> ArrayMesh:
	if _mesh_cache.has("beacon_core"):
		return _mesh_cache["beacon_core"]
	var mesh := ArrayMesh.new()
	var st := _begin()
	_lathe(st, PackedVector2Array([Vector2(0.0, 0.2), Vector2(0.46, 0.2), Vector2(0.36, 1.5), Vector2(0.5, 1.7), Vector2(0.2, 2.15), Vector2(0.0, 2.2)]), 12, Transform3D.IDENTITY, _c(0.1, 0.1, 1.0))
	_commit(mesh, st, _mat("amber_core"))
	st = _begin()
	for i in 3:
		var a := TAU * float(i) / 3.0
		_box(st, Vector3(cos(a) * 0.62, 1.1, sin(a) * 0.62), Vector3(0.16, 1.4, 0.34), 0.05, -a)
	_commit(mesh, st, _mat("hull"))
	return _keep("beacon_core", mesh)


func foreman_body_mesh() -> ArrayMesh:
	if _mesh_cache.has("foreman_body"):
		return _mesh_cache["foreman_body"]
	var mesh := ArrayMesh.new()
	var st := _begin()
	for side: float in [-1.0, 1.0]:
		_box(st, Vector3(side * 1.95, 0.56, 0.0), Vector3(1.1, 1.12, 5.4), 0.24)
		_lathe(st, PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.36, 0.0), Vector2(0.36, 2.6), Vector2(0.46, 2.7), Vector2(0.46, 3.0), Vector2(0.0, 3.0)]), 12,
			Transform3D(Basis.IDENTITY, Vector3(side * 1.45, 2.1, 1.9)), _c(0.55, 0.3))
	_box(st, Vector3(0.0, 3.36, -0.7), Vector3(2.6, 1.7, 2.4), 0.2)
	_commit(mesh, st, _mat("iron"))
	st = _begin()
	_plate(st, Transform3D(Basis.IDENTITY, Vector3(0.0, 1.78, 0.0)), Vector3(3.8, 1.5, 4.4), 0.22)
	_plate(st, Transform3D(Basis.IDENTITY, Vector3(0.0, 5.2, 1.9)), Vector3(3.7, 0.56, 0.92), 0.14)
	for side: float in [-1.0, 1.0]:
		_plate(st, Transform3D(Basis.IDENTITY, Vector3(side * 2.02, 0.95, 0.0)), Vector3(0.14, 0.62, 4.9), 0.05)
		_plate(st, Transform3D(Basis.IDENTITY, Vector3(side * 1.36, 3.36, -0.7)), Vector3(0.12, 1.2, 1.9), 0.04)
		for end: float in [-1.0, 1.0]:
			_plate(st, Transform3D(Basis.IDENTITY, Vector3(side * 1.42, 3.4, -0.7 + end * 1.26)), Vector3(0.24, 2.2, 0.24), 0.06)
		_plate(st, Transform3D(Basis.IDENTITY, Vector3(side * 1.42, 4.56, -0.7)), Vector3(0.24, 0.24, 2.76), 0.06)
	for end: float in [-1.0, 1.0]:
		_plate(st, Transform3D(Basis.IDENTITY, Vector3(0.0, 4.56, -0.7 + end * 1.26)), Vector3(3.08, 0.24, 0.24), 0.06)
	_commit(mesh, st, _mat("bone"))
	st = _begin()
	for end: float in [-1.0, 1.0]:
		_plate(st, Transform3D(Basis.IDENTITY, Vector3(0.0, 1.0, end * 2.86)), Vector3(4.2, 0.72, 0.42), 0.1, 0.4)
	_plate(st, Transform3D(Basis.IDENTITY, Vector3(0.0, 2.7, 2.35)), Vector3(3.2, 0.9, 0.3), 0.08, 0.4)
	_commit(mesh, st, _mat("chevron"))
	st = _begin()
	for end: float in [-1.0, 1.0]:
		for i in 4:
			var x := -1.5 + float(i) * 1.0
			_plate(st, Transform3D(Basis(Vector3.BACK, 0.62 * end), Vector3(x, 1.0, end * 3.09)), Vector3(0.22, 0.86, 0.06), 0.02)
	_commit(mesh, st, _mat("iron"))
	st = _begin()
	_lathe(st, _orb(0.64, 8), 14, Transform3D(Basis.IDENTITY, Vector3(0.0, 3.5, 0.8)), _c(0.1, 0.1, 1.0))
	_lathe(st, _loop(0.82, 0.08, 8), 18, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.0, 3.5, 0.95)), _c(0.1, 0.1, 1.0), true)
	_commit(mesh, st, _mat("rig_core"))
	st = _begin()
	_lathe(st, PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.42, 0.0), Vector2(0.42, 0.18), Vector2(0.34, 0.5), Vector2(0.18, 0.7), Vector2(0.0, 0.74)]), 14,
		Transform3D(Basis.IDENTITY, Vector3(0.0, 4.68, -0.7)), _c(0.1, 0.1, 1.0))
	_commit(mesh, st, _mat("rig_beacon"))
	return _keep("foreman_body", mesh)


func foreman_plate_mesh() -> ArrayMesh:
	if _mesh_cache.has("foreman_plate"):
		return _mesh_cache["foreman_plate"]
	var mesh := ArrayMesh.new()
	var st := _begin()
	_plate(st, Transform3D.IDENTITY, Vector3(1.7, 2.2, 0.32), 0.1)
	_commit(mesh, st, _mat("bone"))
	st = _begin()
	_plate(st, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 0.2)), Vector3(1.3, 0.24, 0.1), 0.03, 1.0)
	_commit(mesh, st, _mat("chevron"))
	return _keep("foreman_plate", mesh)


func defender_mesh(shielded: bool) -> ArrayMesh:
	var key := "defender_shield" if shielded else "defender"
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var mesh := ArrayMesh.new()
	var st := _begin()
	_lathe(st, PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.95, 0.0), Vector2(0.95, 0.24), Vector2(0.7, 0.46), Vector2(0.0, 0.46)]), 16, Transform3D.IDENTITY, _c(0.5, 0.45))
	_commit(mesh, st, _mat("iron"))
	st = _begin()
	_box(st, Vector3(0.0, 0.95, 0.0), Vector3(1.3, 0.8, 1.5), 0.16)
	_commit(mesh, st, _mat("fleet"))
	st = _begin()
	_plate(st, Transform3D(Basis.IDENTITY, Vector3(0.0, 1.4, 0.0)), Vector3(1.38, 0.14, 1.58), 0.04)
	if shielded:
		_plate(st, Transform3D(Basis.IDENTITY, Vector3(0.0, 1.0, 0.92)), Vector3(1.8, 1.3, 0.22), 0.06)
	_commit(mesh, st, _mat("bone"))
	st = _begin()
	_lathe(st, _orb(0.26, 6), 10, Transform3D(Basis.IDENTITY, Vector3(0.0, 1.05, 0.74)), _c(0.1, 0.1, 1.0))
	_commit(mesh, st, _mat("arc_core"))
	return _keep(key, mesh)


func elite_body_mesh() -> ArrayMesh:
	if _mesh_cache.has("elite_body"):
		return _mesh_cache["elite_body"]
	var mesh := ArrayMesh.new()
	var st := _begin()
	for side: float in [-1.0, 1.0]:
		_lathe(st, PackedVector2Array([Vector2(0.0, -0.5), Vector2(0.24, -0.5), Vector2(0.34, -0.3), Vector2(0.34, 0.4), Vector2(0.0, 0.5)]), 12,
			Transform3D(Basis.IDENTITY, Vector3(side * 0.9, -0.75, -0.6)), _c(0.5, 0.35))
	_box(st, Vector3(0.0, -0.72, 0.2), Vector3(0.5, 0.3, 2.2), 0.08)
	_commit(mesh, st, _mat("iron"))
	st = _begin()
	_box(st, Vector3.ZERO, Vector3(2.0, 1.3, 2.4), 0.22)
	_box(st, Vector3(0.0, 0.2, 1.3), Vector3(1.2, 0.7, 0.4), 0.1)
	_commit(mesh, st, _mat("hull"))
	st = _begin()
	_lathe(st, _orb(0.36, 6), 12, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.22, 1.55)), _c(0.1, 0.1, 1.0))
	_commit(mesh, st, _mat("rig_beacon"))
	st = _begin()
	for side: float in [-1.0, 1.0]:
		_plate(st, Transform3D(Basis.IDENTITY, Vector3(side * 0.7, 0.72, 0.0)), Vector3(0.18, 0.14, 2.3), 0.04)
	_commit(mesh, st, _mat("bone"))
	return _keep("elite_body", mesh)


func elite_plate_mesh() -> ArrayMesh:
	if _mesh_cache.has("elite_plate"):
		return _mesh_cache["elite_plate"]
	var mesh := ArrayMesh.new()
	var st := _begin()
	_plate(st, Transform3D.IDENTITY, Vector3(0.26, 1.2, 1.7), 0.07)
	_commit(mesh, st, _mat("bone"))
	return _keep("elite_plate", mesh)


func hauler_body_mesh() -> ArrayMesh:
	if _mesh_cache.has("hauler_body"):
		return _mesh_cache["hauler_body"]
	var mesh := ArrayMesh.new()
	var st := _begin()
	_box(st, Vector3.ZERO, Vector3(2.0, 0.8, 1.4), 0.14)
	_box(st, Vector3(0.0, -0.6, 0.0), Vector3(1.4, 0.5, 1.0), 0.1)
	_commit(mesh, st, _mat("hull"))
	st = _begin()
	for r in 4:
		var at := Vector3(-1.15 if r % 2 == 0 else 1.15, 0.2, -0.85 if r < 2 else 0.85)
		_box(st, at * Vector3(0.5, 1.0, 0.5), Vector3(1.1, 0.12, 0.14), 0.03, atan2(at.x, at.z) + PI * 0.5)
		_lathe(st, PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.14, 0.0), Vector2(0.14, 0.22), Vector2(0.0, 0.22)]), 8, Transform3D(Basis.IDENTITY, at), _c(0.5, 0.4))
	_commit(mesh, st, _mat("iron"))
	st = _begin()
	_lathe(st, _orb(0.15, 4), 8, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.05, 0.76)), _c(0.1, 0.1, 1.0))
	_commit(mesh, st, _mat("amber_core"))
	return _keep("hauler_body", mesh)


func hauler_rotor_mesh() -> ArrayMesh:
	if _mesh_cache.has("hauler_rotor"):
		return _mesh_cache["hauler_rotor"]
	var mesh := ArrayMesh.new()
	var st := _begin()
	for i in 3:
		_box(st, Vector3.ZERO, Vector3(1.05, 0.05, 0.16), 0.02, TAU * float(i) / 3.0)
	_commit(mesh, st, _mat("iron"))
	return _keep("hauler_rotor", mesh)


func prop_mesh(kind: StringName) -> ArrayMesh:
	var key := "prop_" + String(kind)
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var mesh := ArrayMesh.new()
	var st := _begin()
	match kind:
		&"coolant_tank":
			_lathe(st, PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.82, 0.0), Vector2(0.95, 0.16), Vector2(0.95, 1.9), Vector2(0.8, 2.14), Vector2(0.34, 2.3), Vector2(0.0, 2.3)]), 18, Transform3D.IDENTITY, _c(0.3, 0.3, 0.25))
			_commit(mesh, st, _mat("frost"))
			st = _begin()
			for y: float in [0.55, 1.5]:
				_lathe(st, _loop(0.97, 0.07, 8), 20, Transform3D(Basis.IDENTITY, Vector3(0.0, y, 0.0)), _c(0.6, 0.3), true)
			_lathe(st, PackedVector2Array([Vector2(0.0, 2.25), Vector2(0.12, 2.25), Vector2(0.12, 2.6), Vector2(0.22, 2.64), Vector2(0.22, 2.72), Vector2(0.0, 2.72)]), 8, Transform3D.IDENTITY, _c(0.6, 0.3))
			_commit(mesh, st, _mat("iron"))
		&"slag_drum":
			_lathe(st, PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.72, 0.0), Vector2(0.75, 0.08), Vector2(0.75, 0.45), Vector2(0.8, 0.5), Vector2(0.75, 0.55),
				Vector2(0.75, 0.85), Vector2(0.8, 0.9), Vector2(0.75, 0.95), Vector2(0.75, 1.32), Vector2(0.72, 1.4), Vector2(0.0, 1.4)]), 18, Transform3D.IDENTITY, _c(0.45, 0.4, 0.2))
			_commit(mesh, st, _mat("fuel"))
			st = _begin()
			_lathe(st, PackedVector2Array([Vector2(0.0, 1.38), Vector2(0.14, 1.38), Vector2(0.14, 1.52), Vector2(0.0, 1.52)]), 8, Transform3D(Basis.IDENTITY, Vector3(0.38, 0.0, 0.0)), _c(0.6, 0.3))
			_commit(mesh, st, _mat("iron"))
		_:
			_box(st, Vector3(0.0, 0.25, 0.0), Vector3(1.3, 0.5, 1.3), 0.1)
			_commit(mesh, st, _mat("iron"))
			st = _begin()
			var coil := PackedVector2Array([Vector2(0.0, 0.5), Vector2(0.36, 0.5)])
			for i in 6:
				var y := 0.6 + float(i) * 0.32
				coil.append(Vector2(0.36, y))
				coil.append(Vector2(0.27, y + 0.1))
				coil.append(Vector2(0.36, y + 0.2))
			coil.append(Vector2(0.2, 2.5))
			coil.append(Vector2(0.0, 2.55))
			_lathe(st, coil, 14, Transform3D.IDENTITY, _c(0.1, 0.1, 1.0))
			_commit(mesh, st, _mat("arc_core"))
			st = _begin()
			for side: float in [-1.0, 1.0]:
				_box(st, Vector3(side * 0.56, 1.4, 0.0), Vector3(0.12, 1.8, 0.5), 0.04)
			_commit(mesh, st, _mat("hull"))
	return _keep(key, mesh)


func shock_ring_mesh() -> ArrayMesh:
	if _mesh_cache.has("shock_ring"):
		return _mesh_cache["shock_ring"]
	var mesh := ArrayMesh.new()
	var st := _begin()
	_lathe(st, _loop(1.0, 0.07, 8), 32, Transform3D.IDENTITY, _c(0.0, 0.0, 1.0), true)
	st.generate_tangents()
	st.commit(mesh)
	return _keep("shock_ring", mesh)


func streak_mesh() -> ArrayMesh:
	if _mesh_cache.has("streak"):
		return _mesh_cache["streak"]
	var mesh := ArrayMesh.new()
	var st := _begin()
	_lathe(st, PackedVector2Array([Vector2(0.0, -1.6), Vector2(0.05, -1.1), Vector2(0.075, 0.0), Vector2(0.05, 1.1), Vector2(0.0, 1.6)]), 6, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), _c(0.0, 0.0))
	_commit(mesh, st, _streak_material())
	return _keep("streak", mesh)
