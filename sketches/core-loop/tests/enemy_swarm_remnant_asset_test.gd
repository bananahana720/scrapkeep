extends SceneTree

const Game := preload("res://src/game.gd")
const Remnant := preload("res://src/combat/swarm_remnant.gd")
const Roster := preload("res://src/combat/roster.gd")
const GLB := "res://assets/models/world_one/enemy_swarm_remnant.glb"
const BASE_LOGIC_SHA := "b8a3fcbb32a8fa80a31d9092c079a9b71f5310a08f8310ea6f018c92016a8194"

var failures := 0
var game


func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
	print("%s -> %s" % [label, "PASS" if ok else "FAIL"])


func _finish() -> void:
	print("enemy_swarm_remnant_asset_test: %s" % ("PASS" if failures == 0 else "FAIL"))
	if game != null:
		game.free()
	quit(0 if failures == 0 else 1)


func _measure(node: Node3D) -> Dictionary:
	var tris := 0
	var vertices := 0
	var draws := 0
	var primitive := 0
	var opaque := true
	var low := Vector3(INF, INF, INF)
	var high := -low
	var meshes := node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		meshes.append(node)
	for found in meshes:
		var mi := found as MeshInstance3D
		if mi.mesh == null:
			opaque = false
			continue
		if mi.mesh is PrimitiveMesh:
			primitive += 1
		var xf := mi.transform
		var ancestor := mi.get_parent()
		while ancestor != node and ancestor is Node3D:
			xf = ancestor.transform * xf
			ancestor = ancestor.get_parent()
		if mi == node:
			xf = Transform3D.IDENTITY
		for s in mi.mesh.get_surface_count():
			draws += 1
			var arrays := mi.mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var ix = arrays[Mesh.ARRAY_INDEX]
			vertices += vs.size()
			tris += (ix.size() if ix != null else vs.size()) / 3
			for v in vs:
				var p: Vector3 = xf * v
				low = low.min(p)
				high = high.max(p)
			var mat := mi.get_surface_override_material(s) as BaseMaterial3D
			if mat == null:
				mat = mi.material_override as BaseMaterial3D
			if mat == null:
				mat = mi.mesh.surface_get_material(s) as BaseMaterial3D
			opaque = opaque and mat != null
			if mat != null:
				opaque = opaque and mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and mat.albedo_color.a >= 0.999
			if arrays[Mesh.ARRAY_COLOR] != null:
				for c in arrays[Mesh.ARRAY_COLOR] as PackedColorArray:
					opaque = opaque and c.a >= 0.999
	return {"tris": tris, "vertices": vertices, "draws": draws, "primitive": primitive,
		"opaque": opaque, "low": low, "high": high}


func _budget(node: Node3D, label: String) -> Dictionary:
	var m := _measure(node)
	print("%s: %d T / %d V / %d D" % [label, m.tris, m.vertices, m.draws])
	_check(m.tris > 0 and m.tris <= 1100 and m.vertices <= 2100 and m.draws > 0 and m.draws <= 3, label + " D3 budget")
	_check(m.opaque, label + " opaque materials")
	return m


func _named(node: Node, expected: Array) -> void:
	var names := []
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		names.append(String(mi.name))
	names.sort()
	_check(names == expected, "exact named mesh parts")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load(GLB) as PackedScene if ResourceLoader.exists(GLB) else null
	_check(packed != null, "GLB loads")
	if packed == null:
		_finish()
		return
	var scene := packed.instantiate()
	_budget(scene, "asset")
	_named(scene, ["RemnantBody", "RemnantSeam"])
	scene.free()
	game = Game.new()
	game.test_mode = true
	root.add_child(game)
	game.ctx.calm = true
	var drone = game.ctx.spawner.spawn_enemy("swarm_remnant", Vector3(0, 30, 0))
	for d in drone.swarm.alive():
		d.set_physics_process(false)
	var live := _budget(drone, "live")
	_check(live.primitive == 0, "primitive triangle no longer builds")
	_named(drone, ["RemnantBody", "RemnantSeam"])
	var body := drone.find_child("RemnantBody", true, false) as MeshInstance3D
	var seam := drone.find_child("RemnantSeam", true, false) as MeshInstance3D
	_check(body != null and seam != null and drone._body == body and drone._seam == seam, "cached GLB drives body and seam")
	_check(live.low.y >= -0.301 and live.high.y <= 0.301 and live.low.x >= -0.751 and live.high.x <= 0.751
		and live.low.z >= -0.751 and live.high.z <= 0.751, "flat casting fits existing collision box")
	var shapes: Array = drone.find_children("*", "CollisionShape3D", true, false)
	var box := shapes[0].shape as BoxShape3D if shapes.size() == 1 else null
	_check(box != null and box.size.is_equal_approx(Vector3(1.5, 0.6, 1.5))
		and shapes[0].transform.is_equal_approx(Transform3D.IDENTITY), "unchanged box collider")
	_check(drone.find_children("*", "CollisionObject3D", true, false).is_empty(), "no model physics bodies")
	_check(drone.hp == 12.0 and drone.scrap_value == 1 and drone.weight == 0.4 and drone.radius == 0.75
		and drone.half_height == 0.3 and drone.collision_layer == 4 and drone.collision_mask == 1, "base gameplay values")
	if body != null and seam != null:
		_check(body.get_surface_override_material(0) == drone._material or body.get_surface_override_material(1) == drone._material,
			"instance body flash registered")
		var mat := seam.mesh.surface_get_material(0) as StandardMaterial3D
		_check(mat != null and mat.emission_enabled and mat.albedo_color.is_equal_approx(Roster.ANCIENT_LIGHT), "blue ancient seam")
		var first = drone.swarm.alive()[1]
		var other_body := first.find_child("RemnantBody", true, false) as MeshInstance3D
		_check(other_body != null and other_body.mesh == body.mesh and first._material != drone._material,
			"identical drones share mesh and own flash materials")
		drone.swarm.scatter(drone.global_position)
		_check(not drone.seam_lit() and seam.visible and body.visible, "seam dims while scattered, casting remains")
		drone.swarm._reform()
		_check(drone.seam_lit(), "seam returns on reform")
	var source := FileAccess.get_file_as_string("res://src/combat/swarm_remnant.gd")
	var logic := source.get_slice("func _build_body()", 0)
	logic = logic.replace("static var _shared: Array = []\n", "").replace("static var _asset_warned := false\n", "")
	_check(logic.sha256_text() == BASE_LOGIC_SHA, "base HP, movement, AI, damage, timing and scrap source unchanged")
	_finish()
