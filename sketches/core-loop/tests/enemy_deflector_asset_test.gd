extends SceneTree

const Game := preload("res://src/game.gd")
const Palette := preload("res://src/core/palette.gd")

# C17 limits. The asset: 1,200 T / 3 D ceiling for the whole moving assembly (the deflector has no
# runtime mesh besides the glb), opaque, inside the envelope of the base crew and dish: the dish's
# rim outer radius is 1.95 m and its face reaches 1.68 m out, the crew stands 0.8 m either way.
# The base contract: the deflector's collider, lane, rebound, timing and damage constants are the
# values deflector.gd had before the dressing swap.
const CEILING_T := 3200  # polished 2026-10-18 (tools/blender/POLISH.md); was 1200
const CEILING_D := 3
const X_MIN := -2.0
const X_MAX := 2.0
const Z_MIN := -0.95
const Z_MAX := 1.75
const Y_BOTTOM := -1.1
const Y_TOP := 2.3
const RIM_R := 1.95
const BASE_CONSTS := {
	"RESTITUTION": 0.9, "FACE_LENGTH": 6.0, "FACE_WIDTH": 5.0, "MIN_CLOSING": 3.0, "VAULT_WINDOW": 0.45,
	"VAULT_LIFT": 0.35, "HP": 60.0,
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


func _measure(node: Node) -> Dictionary:
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
			if mat is BaseMaterial3D and (mat as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				alpha = true
	return {"tris": tris, "draws": draws, "alpha": alpha}


# Every vertex of every mesh under `node`, in `node`'s local frame.
func _points(node: Node3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	for m in node.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var xf: Transform3D = node.global_transform.affine_inverse() * mi.global_transform
		for s in mi.mesh.get_surface_count():
			for v in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
				out.append(xf * v)
	return out


func _run() -> void:
	var packed := load("res://assets/models/world_one/enemy_deflector.glb") as PackedScene
	_check(packed != null, "enemy_deflector.glb loads")
	if packed == null:
		quit(1)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	for entry in [["DeflectorBody", ["fleet_paint", "paint"]], ["DishWall", ["paint"]]]:
		var part := scene.find_child(entry[0], true, false) as MeshInstance3D
		_check(part != null, "asset node " + entry[0])
		if part != null:
			var names := []
			for surface in part.mesh.get_surface_count():
				names.append(part.mesh.surface_get_material(surface).resource_name)
			_check(names == entry[1], "asset surfaces %s: %s" % [entry[0], names])
	var m := _measure(scene)
	print("asset: %d T, %d D" % [m["tris"], m["draws"]])
	_check(m["tris"] >= 2966 * 0.9 and m["tris"] <= 2966 * 1.1, "WF-8 triangles within 10 percent of 2966 (polished; was 844)")
	_check(m["tris"] <= CEILING_T and m["tris"] > 0, "asset triangles %d <= %d" % [m["tris"], CEILING_T])
	_check(m["draws"] <= CEILING_D, "asset draws %d <= %d" % [m["draws"], CEILING_D])
	_check(not m["alpha"], "asset has no alpha surface")
	scene.free()

	game.ctx.calm = true
	var dish: Node3D = game.ctx.spawner.spawn_enemy("deflector", Vector3(0, 30, 0))
	await process_frame
	_check(dish != null, "a deflector spawns")
	if dish == null:
		quit(1)
		return
	var shapes := dish.find_children("*", "CollisionShape3D", true, false)
	_check(shapes.size() == 1, "one collision shape on the deflector (%d)" % shapes.size())
	var cap := (shapes[0] as CollisionShape3D).shape as CapsuleShape3D if shapes.size() > 0 else null
	_check(cap != null and is_equal_approx(cap.radius, 0.8) and is_equal_approx(cap.height, 2.2), "collider is the base capsule r 0.8 h 2.2")
	_check(shapes.size() > 0 and (shapes[0] as Node3D).position == Vector3.ZERO, "collider sits at the origin")
	_check(dish.find_children("*", "Area3D", true, false).is_empty() and dish.find_children("*", "CollisionObject3D", true, false).is_empty(),
		"the dressing adds no collision object")
	_check(dish.radius == 0.8 and dish.half_height == 1.1 and is_equal_approx(dish.weight, 2.0), "radius 0.8, half-height 1.1 and weight 2.0 unchanged")
	_check(is_equal_approx(dish.warn_seconds, 0.9) and is_equal_approx(dish.live_seconds, 2.6) and is_equal_approx(dish.rest_seconds, 2.5)
		and is_equal_approx(dish.attack_range, 16.0) and is_equal_approx(dish.keep_near, 7.0) and is_equal_approx(dish.keep_far, 14.4) and is_equal_approx(dish.walk_speed, 2.6)
		and dish.scrap_value == 5, "warn 0.9, live 2.6, rest 2.5, range 16, keep-near 7, keep-far 20 clamped to 14.4 by counter.gd, walk 2.6 and scrap 5 unchanged")
	var consts: Dictionary = (dish.get_script() as Script).get_script_constant_map()
	var same := true
	for key in BASE_CONSTS:
		if not consts.has(key) or not is_equal_approx(float(consts[key]), float(BASE_CONSTS[key])):
			same = false
			print("  constant %s is %s, base %s" % [key, consts.get(key), BASE_CONSTS[key]])
	_check(same, "restitution, face length and width, closing speed, vault window and lift and health constants equal base")

	var live := _measure(dish)
	print("live assembly: %d T, %d D" % [live["tris"], live["draws"]])
	_check(dish.find_child("DeflectorBody", true, false) != null, "the live Deflector carries its DeflectorBody dressing")
	_check(live["draws"] > 0 and live["tris"] > 0, "the live measure saw meshes (%d T, %d D)" % [live["tris"], live["draws"]])
	_check(live["tris"] <= CEILING_T and live["draws"] <= CEILING_D, "live assembly %d T / %d D within %d / 3" % [live["tris"], live["draws"], CEILING_T])
	_check(not live["alpha"], "live assembly has no alpha surface")
	# The original dish footprint is the released wall; the carried angle deliberately swings out.
	dish.phase = dish.Phase.LIVE
	dish._pose()
	var pts := _points(dish)
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for p in pts:
		lo = lo.min(p)
		hi = hi.max(p)
	print("bounds: x %.3f..%.3f, y %.3f..%.3f, z %.3f..%.3f" % [lo.x, hi.x, lo.y, hi.y, lo.z, hi.z])
	_check(lo.x >= X_MIN - 0.001 and hi.x <= X_MAX + 0.001 and lo.z >= Z_MIN - 0.001 and hi.z <= Z_MAX + 0.001,
		"inside the footprint x %.1f..%.1f, z %.2f..%.2f" % [X_MIN, X_MAX, Z_MIN, Z_MAX])
	_check(lo.y >= Y_BOTTOM - 0.001 and hi.y <= Y_TOP + 0.001, "between y %.1f and %.1f (the dish no longer sinks below the floor)" % [Y_BOTTOM, Y_TOP])
	_check_dish(dish, pts)
	_check_facing(dish)
	_check_paint(dish)
	print("enemy_deflector_asset_test: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


# The dish is the biggest shape: a full-width plate ahead of the crew whose rim reaches the base
# torus's 1.95 m outer radius, forward of the crew's 0.8 m radius.
func _check_dish(_dish: Node3D, pts: PackedVector3Array) -> void:
	var rim := 0
	var front := -INF
	var width := 0.0
	for p in pts:
		if p.z > 1.0:
			front = maxf(front, p.z)
			width = maxf(width, absf(p.x))
			if Vector2(p.x, p.y - 0.2).length() > RIM_R - 0.05 and p.y >= 0.2:
				rim += 1
	print("dish: front %.3f, half width %.3f, rim vertices %d" % [front, width, rim])
	_check(front >= 1.6 and front <= Z_MAX, "the dish face stands %.2f m ahead of the origin, past the crew's 0.8 m" % front)
	_check(width >= RIM_R - 0.06 and width <= RIM_R + 0.001, "the dish rim reaches the 1.95 m outer radius (%.3f)" % width)
	_check(rim >= 16, "the rebound rim has a bead at the outer radius (%d vertices)" % rim)


# The dish turns with the enemy's existing facing (counter.gd _facing, set at commit): its
# forward-most points lie on the ball's side, whatever the bearing, at full wall pose.
func _check_facing(dish: Node3D) -> void:
	var body := dish.find_child("Body", true, false) as Node3D
	_check(body.position.is_equal_approx(Vector3(0, -0.165, 0)) and body.scale.is_equal_approx(Vector3(1, 0.85, 1)), "the crew braces behind the released wall")
	for bearing in [Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(-0.6, 0, 0.8)]:
		dish._facing(bearing)
		var centre := Vector3.ZERO
		var n := 0
		for p in _points(dish):
			if (dish.global_transform * p).dot(bearing.normalized()) > 1.4 + dish.global_position.dot(bearing.normalized()):
				centre += dish.global_transform * p - dish.global_position
				n += 1
		var lean: float = 0.0 if n == 0 else (centre / n).normalized().dot(bearing.normalized())
		_check(n >= 16 and lean > 0.9, "facing %s: the dish stands ball-side (%d vertices, lean %.2f)" % [bearing, n, lean])
	dish.rotation = Vector3.ZERO


# The resting body is Fleet oxide (RUST); a hit flashes through the existing event.
func _check_paint(dish: Node3D) -> void:
	var body := dish.find_child("Body", true, false) as MeshInstance3D
	var mat: StandardMaterial3D = null
	for s in body.mesh.get_surface_count():
		var o := body.get_surface_override_material(s) as StandardMaterial3D
		if o != null and o == dish._material:
			mat = o
			var arrays := body.mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var ok := true
			for v in vs:
				ok = ok and v.z < 0.9 and v.y < 1.6
			_check(ok, "the flashing surface is the crew, not the dish")
	_check(mat != null, "the body's paint surface is the enemy's flashing material")
	_check(dish._base_color.is_equal_approx(Palette.RUST) and dish._material.albedo_color.is_equal_approx(Palette.RUST),
		"resting state: the body is Fleet oxide (RUST)")
	dish.flash()
	dish._update_flash(0.0)
	var want: Color = Palette.RUST.lerp(Color(1.0, 1.0, 0.85), 1.0)
	_check(dish._material.albedo_color.is_equal_approx(want) and dish._material.emission_enabled, "hit state: the existing flash lerps the body toward cream with amber emission")
	for i in 20:
		dish._update_flash(0.1)
	_check(dish._material.albedo_color.is_equal_approx(Palette.RUST) and not dish._material.emission_enabled, "recovery state: the body returns to oxide")
