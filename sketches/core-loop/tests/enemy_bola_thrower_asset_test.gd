extends SceneTree

const Game := preload("res://src/game.gd")
const Palette := preload("res://src/core/palette.gd")

# C13 limits. The asset: 1,200 T / 3 D ceiling for the whole moving assembly (body plus the
# hoop), opaque; the crew inside the 0.8 m collider footprint and the 2.2 m capsule's height, the
# hoop centred 2.2 m over the origin (the base torus seat) within 1.12 m of its centre. The base
# contract: the thrower's collider, hitbox, throw timing, damage and projectile constants are the
# values bola_thrower.gd had before the dressing swap.
const CEILING_T := 4200  # polished 2026-10-18 (tools/blender/POLISH.md); was 1200
const CEILING_D := 3
const CREW_R := 0.8
const Y_BOTTOM := -1.1
const LOOP_Y := 2.2
const LOOP_REACH := 1.12
const BASE_CONSTS := {
	"FLIGHT": 1.3, "RING_RADIUS": 3.2, "RING_REACH": 5.0, "HEIGHT": 2.6, "WRAP": 1.3, "DRAG": 3.0,
	"DOWN": 16.0, "STING": 6.0, "HP": 40.0,
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
			var mat := mi.get_surface_override_material(s)
			if mat == null:
				mat = mi.material_override
			if mat == null:
				mat = mi.mesh.surface_get_material(s)
			if mat is BaseMaterial3D and (mat as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				alpha = true
	return {"tris": tris, "draws": draws, "alpha": alpha}


func _extent(mi: MeshInstance3D, node: Node3D) -> Dictionary:
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	var r := 0.0
	for s in mi.mesh.get_surface_count():
		for v in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
			var p: Vector3 = node.global_transform.affine_inverse() * (mi.global_transform * v)
			lo = lo.min(p)
			hi = hi.max(p)
			r = maxf(r, Vector2(p.x, p.z).length())
	return {"lo": lo, "hi": hi, "r": r}


func _run() -> void:
	var packed := load("res://assets/models/world_one/enemy_bola_thrower.glb") as PackedScene
	_check(packed != null, "enemy_bola_thrower.glb loads")
	if packed == null:
		quit(1)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	var m := _measure(scene)
	print("asset: %d T, %d D" % [m["tris"], m["draws"]])
	_check(m["tris"] <= CEILING_T and m["tris"] > 0, "asset triangles %d <= %d" % [m["tris"], CEILING_T])
	_check(m["draws"] <= CEILING_D, "asset draws %d <= %d" % [m["draws"], CEILING_D])
	_check(not m["alpha"], "asset has no alpha surface")
	scene.free()

	game.ctx.calm = true
	var bola: Node3D = game.ctx.spawner.spawn_enemy("bola_thrower", Vector3(0, 30, 0))
	await process_frame
	_check(bola != null, "a bola thrower spawns")
	if bola == null:
		quit(1)
		return
	var shapes := bola.find_children("*", "CollisionShape3D", true, false)
	_check(shapes.size() == 1, "one collision shape on the thrower (%d)" % shapes.size())
	var cap := (shapes[0] as CollisionShape3D).shape as CapsuleShape3D if shapes.size() > 0 else null
	_check(cap != null and is_equal_approx(cap.radius, 0.8) and is_equal_approx(cap.height, 2.2), "collider is the base capsule r 0.8, h 2.2")
	_check(shapes.size() > 0 and (shapes[0] as Node3D).position == Vector3.ZERO, "collider sits at the origin")
	_check(bola.find_children("*", "Area3D", true, false).is_empty() and bola.find_children("*", "CollisionObject3D", true, false).is_empty(),
		"the dressing adds no collision object")
	_check(bola.radius == 0.8 and bola.half_height == 1.1 and bola.weight == 1.0, "radius 0.8, half-height 1.1 and weight 1 unchanged")
	_check(is_equal_approx(bola.warn_seconds, 0.6) and is_equal_approx(bola.live_seconds, 2.6) and is_equal_approx(bola.rest_seconds, 3.2)
		and is_equal_approx(bola.attack_range, 30.0) and is_equal_approx(bola.keep_near, 14.0) and bola.scrap_value == 4,
		"warn 0.6, live 2.6, rest 3.2, range 30, keep-near 14 and scrap 4 unchanged")
	var consts: Dictionary = (bola.get_script() as Script).get_script_constant_map()
	var same := true
	for key in BASE_CONSTS:
		if not consts.has(key) or not is_equal_approx(float(consts[key]), float(BASE_CONSTS[key])):
			same = false
			print("  constant %s is %s, base %s" % [key, consts.get(key), BASE_CONSTS[key]])
	_check(same, "flight, ring, height, wrap, drag, pull, sting and health constants equal base")

	var live := _measure(bola)
	print("live assembly: %d T, %d D" % [live["tris"], live["draws"]])
	_check(live["draws"] > 0 and live["tris"] > 0, "the live measure saw meshes (%d T, %d D)" % [live["tris"], live["draws"]])
	_check(live["tris"] <= CEILING_T and live["draws"] <= CEILING_D, "live assembly %d T / %d D within %d / 3" % [live["tris"], live["draws"], CEILING_T])
	_check(not live["alpha"], "live assembly has no alpha")
	_check_shape(bola)
	_check_paint(bola)
	_check_pose(bola)
	print("enemy_bola_thrower_asset_test: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _check_shape(bola: Node3D) -> void:
	var body := bola.find_child("BolaThrowerBody", true, false) as MeshInstance3D
	var loop := bola.find_child("BolaLoop", true, false) as MeshInstance3D
	_check(body != null and loop != null, "the live thrower has BolaThrowerBody and BolaLoop")
	if body == null or loop == null:
		return
	var e := _extent(body, bola)
	var lo: Vector3 = e["lo"]
	var hi: Vector3 = e["hi"]
	print("body bounds: y %.3f..%.3f, radius %.3f" % [lo.y, hi.y, e["r"]])
	_check(e["r"] <= CREW_R + 0.001, "the crew stands inside the 0.8 m collider footprint")
	_check(lo.y >= Y_BOTTOM - 0.001, "the crew stands on the collider floor (y %.3f)" % lo.y)
	_check(hi.y <= LOOP_Y + 0.1, "the crew stays under the loop (top %.2f)" % hi.y)
	_check(is_equal_approx(loop.position.y, LOOP_Y) and absf(loop.position.x) < 0.001 and absf(loop.position.z) < 0.001,
		"the loop seats 2.2 m over the origin, as the base torus did")
	var reach := 0.0
	var wide := 0.0
	for v in loop.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
		reach = maxf(reach, v.length())
		wide = maxf(wide, absf(v.x))
	_check(reach <= LOOP_REACH, "loop reach %.3f <= %.2f" % [reach, LOOP_REACH])
	_check(wide >= 0.9, "the loop is large, weighted ends at %.2f m (base ring 0.9)" % wide)
	var ends := 0
	for v in loop.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
		if absf(v.x) > 0.95:
			ends += 1
	_check(ends > 0, "the two weighted ends stand proud of the ring")
	# Nothing crosses the opening: no vertex of the loop lies inside the ring's inner edge (0.65 m).
	var crossing := 0
	for v in loop.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
		if Vector2(v.x, v.z).length() < 0.6:
			crossing += 1
	_check(crossing == 0, "nothing crosses the loop's opening (%d vertices inside 0.6 m)" % crossing)


# The resting body is Fleet oxide (RUST); the hit flashes through the existing event
# (enemy.flash() sets _flash, _update_flash lerps _material from _base_color).
func _check_paint(bola: Node3D) -> void:
	var body := bola.find_child("BolaThrowerBody", true, false) as MeshInstance3D
	var found := false
	for s in body.mesh.get_surface_count():
		var mat := body.get_surface_override_material(s) as StandardMaterial3D
		if mat != null and mat == bola._material and mat.albedo_color.is_equal_approx(Palette.RUST):
			found = true
	_check(found, "the resting body surface is the Fleet oxide colour (RUST) on the enemy's own material")
	bola.flash()
	bola._update_flash(0.0)
	var hit: Color = bola._material.albedo_color
	_check(not hit.is_equal_approx(Palette.RUST) and bola._material.emission_enabled, "a hit flashes the body through the existing event")
	for i in 20:
		bola._update_flash(0.1)
	_check(bola._material.albedo_color.is_equal_approx(Palette.RUST) and not bola._material.emission_enabled, "the body returns to oxide after the flash")
	var second: Node3D = game.ctx.spawner.spawn_enemy("bola_thrower", Vector3(20, 30, 0))
	second.flash()
	second._update_flash(0.0)
	bola._update_flash(0.0)
	_check(second._material != bola._material and bola._material.albedo_color.is_equal_approx(Palette.RUST),
		"a second thrower's flash leaves this one's body unlit")


# Pose: the loop whirls faster through WARN, easing with the existing warning clock, about its
# own ring axis; that axis stays exposed (horizontal component on both the z and x view lines) at
# rest, through the wind-up and in flight, so the opening reads from front, side and rear cameras.
const OPEN_MIN := 0.45  # |axis.x| and |axis.z| at least this: the opening is >= 45% of face-on on each camera line


func _axis(loop: Node3D) -> Vector3:
	return (loop.global_transform.basis * Vector3.UP).normalized()


func _step(loop: Node3D, bola: Node3D) -> float:
	var before: Vector3 = loop.global_transform.basis.x
	bola._pose()
	return before.angle_to(loop.global_transform.basis.x)


func _open(loop: Node3D) -> bool:
	var a := _axis(loop).abs()
	return a.x >= OPEN_MIN and a.z >= OPEN_MIN


func _check_pose(bola: Node3D) -> void:
	var loop: MeshInstance3D = bola._bola
	var ring_y := 0.0
	for v in loop.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
		ring_y = maxf(ring_y, absf(v.y))
	_check(ring_y < 0.3, "the glb hoop lies in its local XZ plane, so its ring axis is local Y (max |y| %.3f)" % ring_y)
	_check(_open(loop), "the loop's ring axis is exposed at rest: |x| %.2f, |z| %.2f >= %.2f" % [_axis(loop).abs().x, _axis(loop).abs().z, OPEN_MIN])
	bola.phase = bola.Phase.ROAM
	var rest_step := _step(loop, bola)
	bola.phase = bola.Phase.WARN
	bola._t = bola.warn_seconds
	var wind_step := _step(loop, bola)
	_check(is_equal_approx(rest_step, 0.25) and wind_step > rest_step, "the loop whirls faster through WARN (%.3f vs %.3f rad/step)" % [wind_step, rest_step])
	var still_open := true
	for i in 40:
		bola._pose()
		if not _open(loop):
			still_open = false
	_check(still_open, "the ring axis stays exposed through 40 wind-up whirl steps")
	bola.phase = bola.Phase.ROAM
	# In flight the loop is top_level and keeps the enemy-frame seat it left with.
	bola._take_flight()
	for i in 10:
		bola._pose()
	_check(_open(loop), "the flying loop's ring axis stays exposed")
	loop.top_level = false
	bola._pose()
