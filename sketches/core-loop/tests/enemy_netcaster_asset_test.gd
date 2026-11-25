extends SceneTree

const Game := preload("res://src/game.gd")
const Palette := preload("res://src/core/palette.gd")

# C16 limits. The asset: 1,200 T / 3 D ceiling for the whole moving assembly (body plus the
# runtime net box), opaque except the net plane itself, inside the envelope of the base masts
# and crew, widened for the outward stays and the mast insulators.
# The base contract: the netcaster's collider, net geometry, timing and field constants are the
# values netcaster.gd had before the dressing swap. The net window (the hostile plane, 2.4 x 1.6 m
# at y 0.8..2.4, z -0.3) stays clear of decorative mesh: masts stand at x +-1.2 with radius
# <= 0.1, so the clear span is |x| < 1.09 (1.1 less a rounding margin), and the slab is z -0.4..-0.2.
const CEILING_T := 7600  # polished 2026-10-18 (tools/blender/POLISH.md); was 1200
const CEILING_D := 3
const X_MIN := -1.7
const X_MAX := 1.7
const Z_MIN := -0.95
const Z_MAX := 0.95
const Y_BOTTOM := -1.1
const Y_TOP := 3.2
const WINDOW_LO := Vector3(-1.09, 0.8, -0.4)
const WINDOW_HI := Vector3(1.09, 2.4, -0.2)
const BASE_CONSTS := {
	"FIELD_RADIUS": 5.5, "FIELD_TOP": 10.0, "NET_FLOOR": 1.2, "LEAD": 0.6, "HANG": 5.0, "MAX_HOLD": 1.6,
	"HP": 45.0, "MAST_HEIGHT": 3.6,
}
var failures := 0
var game


func _initialize() -> void:
	game = Game.new()
	game.test_mode = true
	root.add_child(game)
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL", label])


func _mat_of(mi: MeshInstance3D, s: int) -> Material:
	var mat := mi.get_surface_override_material(s)
	if mat == null:
		mat = mi.material_override
	if mat == null:
		mat = mi.mesh.surface_get_material(s)
	return mat


# Tris, draws, and alpha found on any mesh other than `net` (the actual hostile plane).
func _measure(node: Node, net: Node = null) -> Dictionary:
	var tris := 0
	var draws := 0
	var alpha := false
	for m in node.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			draws += 1
			var arrays := mi.mesh.surface_get_arrays(s)
			var idx = arrays[Mesh.ARRAY_INDEX]
			var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			tris += (idx.size() if idx != null else vs.size()) / 3
			var mat := _mat_of(mi, s)
			if mi != net and mat is BaseMaterial3D and (mat as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				alpha = true
	return {"tris": tris, "draws": draws, "alpha": alpha}


func _bounds(node: Node3D, skip: Node = null) -> Dictionary:
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for m in node.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null or mi == skip:
			continue
		for s in mi.mesh.get_surface_count():
			for v in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
				var p: Vector3 = node.global_transform.affine_inverse() * (mi.global_transform * v)
				lo = lo.min(p)
				hi = hi.max(p)
	return {"lo": lo, "hi": hi}


# Decorative triangles whose bounding box overlaps the net window (conservative).
func _window_hits(node: Node3D, net: Node) -> int:
	var hits := 0
	for m in node.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null or mi == net:
			continue
		var xf: Transform3D = node.global_transform.affine_inverse() * mi.global_transform
		for s in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var idx = arrays[Mesh.ARRAY_INDEX]
			var n: int = idx.size() if idx != null else vs.size()
			for t in range(0, n, 3):
				var a: Vector3 = xf * vs[idx[t] if idx != null else t]
				var b: Vector3 = xf * vs[idx[t + 1] if idx != null else t + 1]
				var c: Vector3 = xf * vs[idx[t + 2] if idx != null else t + 2]
				var lo := a.min(b).min(c)
				var hi := a.max(b).max(c)
				if lo.x < WINDOW_HI.x and hi.x > WINDOW_LO.x and lo.y < WINDOW_HI.y and hi.y > WINDOW_LO.y and lo.z < WINDOW_HI.z and hi.z > WINDOW_LO.z:
					hits += 1
	return hits


func _run() -> void:
	var packed := load("res://assets/models/world_one/enemy_netcaster.glb") as PackedScene
	_check(packed != null, "enemy_netcaster.glb loads")
	if packed == null:
		quit(1)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	var m := _measure(scene)
	print("asset: %d T, %d D" % [m["tris"], m["draws"]])
	_check(m["tris"] <= CEILING_T and m["tris"] > 0, "asset triangles %d <= %d" % [m["tris"], CEILING_T])
	_check(m["draws"] <= CEILING_D - 1, "asset draws %d <= %d (the runtime net is the third)" % [m["draws"], CEILING_D - 1])
	_check(not m["alpha"], "asset has no alpha surface")
	_check(_window_hits(scene as Node3D, null) == 0, "no asset triangle enters the 2.4 x 1.6 m net window")
	scene.free()

	game.ctx.calm = true
	var caster: Node3D = game.ctx.spawner.spawn_enemy("netcaster", Vector3(0, 30, 0))
	await process_frame
	_check(caster != null, "a netcaster spawns")
	if caster == null:
		quit(1)
		return
	var shapes := caster.find_children("*", "CollisionShape3D", true, false)
	_check(shapes.size() == 1, "one collision shape on the netcaster (%d)" % shapes.size())
	var cap := (shapes[0] as CollisionShape3D).shape as CapsuleShape3D if shapes.size() > 0 else null
	_check(cap != null and is_equal_approx(cap.radius, 0.8) and is_equal_approx(cap.height, 2.2), "collider is the base capsule r 0.8 h 2.2")
	_check(shapes.size() > 0 and (shapes[0] as Node3D).position == Vector3.ZERO, "collider sits at the origin")
	_check(caster.find_children("*", "Area3D", true, false).is_empty() and caster.find_children("*", "CollisionObject3D", true, false).is_empty(),
		"the dressing adds no collision object")
	_check(caster.radius == 0.8 and caster.half_height == 1.1 and is_equal_approx(caster.weight, 1.1), "radius 0.8, half-height 1.1 and weight 1.1 unchanged")
	_check(caster.warn_seconds == 1.2 and caster.live_seconds == 2.6 and caster.rest_seconds == 3.5 and caster.attack_range == 24.0
		and caster.scrap_value == 4, "warn 1.2, live 2.6, rest 3.5, range 24 and scrap 4 unchanged")
	var consts: Dictionary = (caster.get_script() as Script).get_script_constant_map()
	var same := true
	for key in BASE_CONSTS:
		if not consts.has(key) or not is_equal_approx(float(consts[key]), float(BASE_CONSTS[key])):
			same = false
			print("  constant %s is %s, base %s" % [key, consts.get(key), BASE_CONSTS[key]])
	_check(same, "field radius, field top, net floor, lead, hang, hold, health and mast height constants equal base")

	var net := caster._net as MeshInstance3D
	_check(net != null and net.mesh is BoxMesh and (net.mesh as BoxMesh).size.is_equal_approx(Vector3(2.4, 1.6, 0.04))
		and net.position.is_equal_approx(Vector3(0.0, 1.6, -0.3)), "the net is the base 2.4 x 1.6 x 0.04 box at (0, 1.6, -0.3)")
	var nmat := net.material_override as ShaderMaterial
	_check(nmat != null and nmat.shader != null
		and (nmat.get_shader_parameter("hazard_col") as Color).is_equal_approx(Palette.HAZARD)
		and (nmat.get_shader_parameter("brass_col") as Color).is_equal_approx(Palette.BRASS)
		and (nmat.get_shader_parameter("ink_col") as Color).is_equal_approx(Palette.CHARCOAL),
		"the net wears its cel-inked animated hazard/brass cross-hatch shader")

	var live := _measure(caster, net)
	print("live assembly: %d T, %d D" % [live["tris"], live["draws"]])
	_check(caster.find_child("NetcasterBody", true, false) != null, "the live Netcaster carries its NetcasterBody dressing")
	_check(live["draws"] > 0 and live["tris"] > 0, "the live measure saw meshes (%d T, %d D)" % [live["tris"], live["draws"]])
	_check(live["tris"] <= CEILING_T and live["draws"] <= CEILING_D, "live assembly %d T / %d D within %d / 3" % [live["tris"], live["draws"], CEILING_T])
	_check(not live["alpha"], "live assembly has no alpha outside the net plane")
	var hits := _window_hits(caster, net)
	_check(hits == 0, "no decorative triangle enters the net window (%d)" % hits)
	var b := _bounds(caster, net)
	var lo: Vector3 = b["lo"]
	var hi: Vector3 = b["hi"]
	print("decor bounds: x %.3f..%.3f, y %.3f..%.3f, z %.3f..%.3f" % [lo.x, hi.x, lo.y, hi.y, lo.z, hi.z])
	_check(lo.x >= X_MIN - 0.001 and hi.x <= X_MAX + 0.001 and lo.z >= Z_MIN - 0.001 and hi.z <= Z_MAX + 0.001,
		"decor inside the footprint x %.1f..%.1f, z %.1f..%.1f" % [X_MIN, X_MAX, Z_MIN, Z_MAX])
	_check(lo.y >= Y_BOTTOM - 0.001 and hi.y <= Y_TOP + 0.001, "decor between y %.1f and %.1f" % [Y_BOTTOM, Y_TOP])
	_check(hi.y >= 2.5, "the masts stand 3.6 m tall (top %.2f >= 2.5 over the origin)" % hi.y)
	_check_masts(caster)
	_check_pose(caster, net)
	_check_paint(caster)
	print("enemy_netcaster_asset_test: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


# Two separated masts 2.4 m apart: the decor reaches at least 2.5 m at both mast axes (x +-1.2).
# Intrusion into the gap between them is caught separately, inside the net window, by _window_hits.
func _check_masts(caster: Node3D) -> void:
	var left := _decor_top(caster, -1.2)
	var right := _decor_top(caster, 1.2)
	_check(left >= 2.5 and right >= 2.5, "a mast stands at x -1.2 and x +1.2 to 2.5 m over the origin (%.2f, %.2f)" % [left, right])


func _decor_top(caster: Node3D, x: float) -> float:
	var top := -INF
	for m in caster.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi == caster._net or mi.mesh == null:
			continue
		var xf: Transform3D = caster.global_transform.affine_inverse() * mi.global_transform
		for s in mi.mesh.get_surface_count():
			for v in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
				var p: Vector3 = xf * v
				if absf(p.x - x) < 0.12 and absf(p.z + 0.3) < 0.12:
					top = maxf(top, p.y)
	return top


# The only pose is the existing one: the net shows while roaming and warning, and hides in the
# live phase (the raised field is the net). It adds no clock, and the decor never moves.
func _check_pose(caster: Node3D, net: Node3D) -> void:
	var body := caster.find_child("Body", true, false) as Node3D
	var rest: Transform3D = body.transform
	caster.phase = caster.Phase.WARN
	caster._pose()
	_check(net.visible, "warn: the net plane shows")
	caster.phase = caster.Phase.LIVE
	caster._pose()
	_check(not net.visible, "live: the net plane hides as the field takes over")
	caster.phase = caster.Phase.ROAM
	caster._pose()
	_check(net.visible and body.transform.is_equal_approx(rest) and rest.is_equal_approx(Transform3D.IDENTITY),
		"roam: the net shows again and the body never moved")


# The resting body is Fleet oxide (RUST); a hit flashes through the existing event.
func _check_paint(caster: Node3D) -> void:
	var body := caster.find_child("Body", true, false) as MeshInstance3D
	var mat: StandardMaterial3D = null
	for s in body.mesh.get_surface_count():
		var o := body.get_surface_override_material(s) as StandardMaterial3D
		if o != null and o == caster._material:
			mat = o
	_check(mat != null, "the body's paint surface is the enemy's flashing material")
	_check(caster._base_color.is_equal_approx(Palette.RUST) and caster._material.albedo_color.is_equal_approx(Palette.RUST),
		"resting state: the body is Fleet oxide (RUST)")
	caster.flash()
	caster._update_flash(0.0)
	var want: Color = Palette.RUST.lerp(Color(1.0, 1.0, 0.85), 1.0)
	_check(caster._material.albedo_color.is_equal_approx(want) and caster._material.emission_enabled, "hit state: the existing flash lerps the body toward cream with amber emission")
	for i in 20:
		caster._update_flash(0.1)
	_check(caster._material.albedo_color.is_equal_approx(Palette.RUST) and not caster._material.emission_enabled, "recovery state: the body returns to oxide")
