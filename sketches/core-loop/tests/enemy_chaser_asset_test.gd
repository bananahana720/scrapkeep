extends SceneTree

const Game := preload("res://src/game.gd")

# C10 limits. The asset: 1,200 T / 3 D ceiling for the whole moving assembly, opaque, inside the
# 2 x 3 m core (radius 1 m, half-height 1.5 m). The base contract: the chaser's collider and its
# committed lunge lane, timing and damage are the values chaser.gd had before the dressing swap.
const CEILING_T := 1200
const CEILING_D := 3
const CORE_RADIUS := 1.0
const CORE_HALF_HEIGHT := 1.5
const BASE_CONSTS := {
	"SPEED": 4.8, "LUNGE_RANGE": 10.0, "WINDUP": 0.6, "LUNGE_TIME": 0.34, "LUNGE_LENGTH": 11.0,
	"LUNGE_WIDTH": 2.8, "RECOVER": 0.9, "REST": 0.8, "DAMAGE": 9.0, "SHOVE": 6.0, "INTERRUPT": 10.0,
	"HP": 60.0, "SCRAP": 3,
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
	var worst_r := 0.0
	var worst_y := 0.0
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
			var basis_to_node: Transform3D = node.global_transform.affine_inverse() * mi.global_transform
			for v in vs:
				var p: Vector3 = basis_to_node * v
				worst_r = maxf(worst_r, Vector2(p.x, p.z).length())
				worst_y = maxf(worst_y, absf(p.y))
	return {"tris": tris, "draws": draws, "alpha": alpha, "r": worst_r, "y": worst_y}


func _run() -> void:
	var packed := load("res://assets/models/world_one/enemy_chaser.glb") as PackedScene
	_check(packed != null, "enemy_chaser.glb loads")
	if packed == null:
		quit(1)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	var m := _measure(scene)
	print("asset: %d T, %d D, radius %.3f, half-height %.3f" % [m["tris"], m["draws"], m["r"], m["y"]])
	_check(m["tris"] <= CEILING_T and m["tris"] > 0, "asset triangles %d <= %d" % [m["tris"], CEILING_T])
	_check(m["draws"] <= CEILING_D, "asset draws %d <= %d" % [m["draws"], CEILING_D])
	_check(not m["alpha"], "asset has no alpha surface")
	_check(m["r"] <= CORE_RADIUS + 0.001, "asset radius %.3f <= %.1f m core" % [m["r"], CORE_RADIUS])
	_check(m["y"] <= CORE_HALF_HEIGHT + 0.001, "asset half-height %.3f <= %.1f m core" % [m["y"], CORE_HALF_HEIGHT])
	scene.free()

	game.ctx.calm = true
	var chaser: Node3D = game.ctx.spawner.spawn_enemy("chaser", Vector3(0, 30, 0))
	await process_frame
	_check(chaser != null, "a chaser spawns")
	if chaser == null:
		quit(1)
		return
	var shapes := chaser.find_children("*", "CollisionShape3D", true, false)
	_check(shapes.size() == 1, "one collision shape on the chaser (%d)" % shapes.size())
	var capsule := (shapes[0] as CollisionShape3D).shape as CapsuleShape3D if shapes.size() > 0 else null
	_check(capsule != null and is_equal_approx(capsule.radius, 1.0) and is_equal_approx(capsule.height, 3.0),
		"collider is the base capsule, radius 1.0 height 3.0")
	_check(chaser.find_children("*", "Area3D", true, false).is_empty() and chaser.find_children("*", "CollisionObject3D", true, false).is_empty(),
		"the dressing adds no collision object")
	_check(chaser.radius == 1.0 and chaser.half_height == 1.5, "radius 1 and half-height 1.5 unchanged")
	var consts: Dictionary = (chaser.get_script() as Script).get_script_constant_map()
	var same := true
	for key in BASE_CONSTS:
		if not consts.has(key) or not is_equal_approx(float(consts[key]), float(BASE_CONSTS[key])):
			same = false
			print("  constant %s is %s, base %s" % [key, consts.get(key), BASE_CONSTS[key]])
	_check(same, "lunge lane (11 x 2.8), timing and damage constants equal base")

	var live := _measure(chaser)
	print("live assembly: %d T, %d D, radius %.3f, half-height %.3f" % [live["tris"], live["draws"], live["r"], live["y"]])
	_check(chaser.find_child("ChaserBody", true, false) != null, "the live Chaser carries its ChaserBody dressing")
	_check(live["tris"] <= CEILING_T and live["draws"] <= CEILING_D, "live assembly %d T / %d D within 1200 / 3" % [live["tris"], live["draws"]])
	_check(not live["alpha"], "live assembly has no alpha")
	_check(live["r"] <= CORE_RADIUS + 0.001 and live["y"] <= CORE_HALF_HEIGHT + 0.001, "live assembly inside the 2 x 3 m core at rest")
	print("enemy_chaser_asset_test: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
